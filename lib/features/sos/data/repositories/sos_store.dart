import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/data/app_database.dart';
import '../../../../core/data/database_provider.dart';
import '../../../../core/data/database_schema.dart';
import '../../models/sos_request.dart';

/// SQLite-backed store for SOS history, including any captured location.
///
/// Persists every submitted SOS so the resident's history and the responder /
/// official views survive restarts. Location fields (accuracy and capture time,
/// alongside the existing latitude/longitude) are stored on the same row.
class SosStore {
  const SosStore(this._db);

  final AppDatabase _db;

  /// Inserts or replaces an SOS record.
  Future<void> save(SosRequest request) async {
    if (!_db.isAvailable) return; // web: no local DB, Supabase is source of truth
    await _db.database.insert(
      DatabaseSchema.tableSos,
      request.toDbRow(),
      // Replace so status/delivery updates persist for the same id.
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Loads all persisted SOS records, newest first.
  Future<List<SosRequest>> loadAll() async {
    if (!_db.isAvailable) return <SosRequest>[]; // web: no local DB
    final List<Map<String, Object?>> rows = await _db.database.query(
      DatabaseSchema.tableSos,
      orderBy: 'created_at DESC',
    );
    return rows.map(SosRequest.fromDbRow).toList();
  }

  /// Updates the stored copy of an existing SOS (e.g. after status changes).
  Future<void> update(SosRequest request) => save(request);
}

final Provider<SosStore> sosStoreProvider = Provider<SosStore>((Ref ref) {
  return SosStore(ref.watch(appDatabaseProvider));
});
