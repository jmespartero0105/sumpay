import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';

/// Thin wrapper around the on-device SQLite database.
///
/// Phase 1 responsibilities are intentionally limited to *initialising* the
/// database and creating the schema. Repositories may read from and write to it
/// through [database]; communication and real synchronisation arrive in a later
/// phase. A single shared instance is exposed via [AppDatabase.instance] and is
/// also provided through Riverpod for the widget layer.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  /// Whether [initialize] has completed successfully.
  bool get isReady => _db != null;

  /// The open database handle. Call [initialize] before accessing this.
  /// Whether a local database is available. False on web (internet-only, no
  /// local SQLite). Repositories check this before touching the database.
  bool get isAvailable => !kIsWeb && _db != null;

  Database get database {
    final Database? db = _db;
    if (db == null) {
      throw StateError(
        'AppDatabase has not been initialised. Call initialize() first.',
      );
    }
    return db;
  }

  /// Shared schema-migration logic, used by both the native (mobile) and the
  /// IndexedDB-backed (web) database factories.
  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
        // v1 -> v2: add the mesh metadata key-value table for the persistent
        // device id introduced with multi-hop mesh routing.
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE ${DatabaseSchema.tableMeshMeta} (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
          // Mesh routing metadata on persisted messages.
          await db.execute(
            'ALTER TABLE ${DatabaseSchema.tableMessages} '
            'ADD COLUMN hop_count INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE ${DatabaseSchema.tableMessages} '
            'ADD COLUMN was_relayed INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE ${DatabaseSchema.tableMessages} '
            'ADD COLUMN mesh_path TEXT',
          );
        }
        // v2 -> v3: add account approval status to users (admin RBAC).
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE ${DatabaseSchema.tableUsers} '
            "ADD COLUMN status TEXT NOT NULL DEFAULT 'active'",
          );
        }
        // v3 -> v4: add sender role to messages (community chat shows role),
        // and captured-location fields to SOS requests (emergency location).
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE ${DatabaseSchema.tableMessages} '
            'ADD COLUMN sender_role TEXT',
          );
          await db.execute(
            'ALTER TABLE ${DatabaseSchema.tableSos} '
            'ADD COLUMN accuracy REAL',
          );
          await db.execute(
            'ALTER TABLE ${DatabaseSchema.tableSos} '
            'ADD COLUMN location_captured_at INTEGER',
          );
        }

        // v4 -> v5: reply metadata plus local-only read/pinned flags on
        // community-chat messages.
        if (oldVersion < 5) {
          const String t = DatabaseSchema.tableMessages;
          await db.execute('ALTER TABLE $t ADD COLUMN reply_to_id TEXT');
          await db.execute('ALTER TABLE $t ADD COLUMN reply_to_name TEXT');
          await db.execute('ALTER TABLE $t ADD COLUMN reply_to_preview TEXT');
          await db.execute(
              'ALTER TABLE $t ADD COLUMN is_read INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE $t ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0');
        }

        // v5 -> v6: local authentication. Add a password hash column to users
        // so accounts can be verified locally (SHA-256). Structured so a
        // backend (Supabase) auth check can replace the local one later without
        // touching the schema.
        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE ${DatabaseSchema.tableUsers} '
            'ADD COLUMN password_hash TEXT',
          );
        }

        // v6 -> v7: split full_name into surname/first_name/middle_name to
        // match the standard registration convention (Surname, First Middle).
        if (oldVersion < 7) {
          await db.execute(
              "ALTER TABLE ${DatabaseSchema.tableUsers} ADD COLUMN surname TEXT NOT NULL DEFAULT ''");
          await db.execute(
              "ALTER TABLE ${DatabaseSchema.tableUsers} ADD COLUMN first_name TEXT NOT NULL DEFAULT ''");
          await db.execute(
              "ALTER TABLE ${DatabaseSchema.tableUsers} ADD COLUMN middle_name TEXT NOT NULL DEFAULT ''");
        }
        // v7 -> v8: track the requesting resident's id on each SOS so history
        // can be synced per-resident to the backend and viewed from any device.
        if (oldVersion < 8) {
          await db.execute(
              "ALTER TABLE ${DatabaseSchema.tableSos} ADD COLUMN requester_id TEXT");
        }
        // v8 -> v9: store extra emergency categories chosen for one SOS.
        if (oldVersion < 9) {
          await db.execute(
              "ALTER TABLE ${DatabaseSchema.tableSos} ADD COLUMN additional_types TEXT");
        }
  }

  /// Opens the database, creating the schema on first launch.
  ///
  /// Safe to call multiple times; subsequent calls are no-ops once open.
  Future<Database> initialize() async {
    if (_db != null) return _db!;

    // Web has no local SQLite. The web app is internet-only (Supabase is the
    // source of truth), so we skip local persistence entirely and never open a
    // database. Repositories guard their DB calls with `kIsWeb` and read/write
    // through Supabase instead. Callers must not invoke this on web.
    if (kIsWeb) {
      throw StateError('Local database is not used on web.');
    }

    final String databasesPath = await getDatabasesPath();
    final String path = p.join(databasesPath, DatabaseSchema.databaseName);

    _db = await openDatabase(
      path,
      version: DatabaseSchema.databaseVersion,
      onConfigure: (Database db) async {
        // Enforce foreign keys for when relations are added in later phases.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int version) async {
        final Batch batch = db.batch();
        for (final String statement in DatabaseSchema.createStatements) {
          batch.execute(statement);
        }
        await batch.commit(noResult: true);
      },
      onUpgrade: _onUpgrade,
    );

    return _db!;
  }

  /// Returns the number of rows currently stored in [table].
  Future<int> count(String table) async {
    final List<Map<String, Object?>> rows =
        await database.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Replaces every row in [table] with [rows] inside a single transaction.
  ///
  /// Used to seed dummy data on first launch without duplicating records on
  /// subsequent launches.
  Future<void> replaceAll(
    String table,
    List<Map<String, Object?>> rows,
  ) async {
    await database.transaction((Transaction txn) async {
      await txn.delete(table);
      final Batch batch = txn.batch();
      for (final Map<String, Object?> row in rows) {
        batch.insert(
          table,
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Closes the database. Primarily useful for tests.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
