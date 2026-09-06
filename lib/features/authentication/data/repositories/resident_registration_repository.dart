import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/data/app_database.dart';
import '../../../../core/data/database_provider.dart';
import '../../../../core/data/database_schema.dart';
import '../../../../core/utils/uuid.dart';
import '../../models/app_user.dart';

/// Persists the resident who registers on this device.
///
/// User identity management for residents is local and server-free: on first
/// launch the resident registers, a unique resident id is generated, and the
/// account is written to the SQLite `users` table. A pointer to that resident
/// is kept in the `mesh_meta` store so the same resident is restored on every
/// subsequent launch. There is no authentication.
class ResidentRegistrationRepository {
  const ResidentRegistrationRepository(this._db);

  static const String _registeredResidentKey = 'registered_resident_id';
  static const String _activeUserKey = 'active_user_id';

  final AppDatabase _db;

  /// Generates a unique resident id, e.g. `RES-3F2A9C`.
  String generateResidentId() =>
      'RES-${Uuid.v4().replaceAll('-', '').substring(0, 6).toUpperCase()}';

  /// Inserts or updates any user account (used by registration and admin
  /// account creation). Preserves an existing password_hash if the row already
  /// has one, since [AppUser.toDbRow] does not carry it.
  Future<AppUser> upsertUser(AppUser user) async {
    if (!_db.isAvailable) return user;
    final Map<String, Object?> row = user.toDbRow();
    // Don't clobber an existing password when updating a profile.
    final List<Map<String, Object?>> existing = await _db.database.query(
      DatabaseSchema.tableUsers,
      columns: <String>['password_hash'],
      where: 'id = ?',
      whereArgs: <Object?>[user.id],
      limit: 1,
    );
    if (existing.isNotEmpty && existing.first['password_hash'] != null) {
      row['password_hash'] = existing.first['password_hash'];
    }
    await _db.database.insert(
      DatabaseSchema.tableUsers,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return user;
  }

  /// Marks [userId] as the active (signed-in) user for session restoration.
  Future<void> setActiveUser(String userId) async {
    if (!_db.isAvailable) return;
    await _db.database.insert(
      DatabaseSchema.tableMeshMeta,
      <String, Object?>{'key': _activeUserKey, 'value': userId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Clears the active-user pointer (sign out).
  Future<void> clearActiveUser() async {
    if (!_db.isAvailable) return;
    await _db.database.delete(
      DatabaseSchema.tableMeshMeta,
      where: 'key = ?',
      whereArgs: <Object?>[_activeUserKey],
    );
  }

  /// Loads the active (signed-in) user, or null if none/session cleared.
  Future<AppUser?> loadActiveUser() async {
    if (!_db.isAvailable) return null;
    final List<Map<String, Object?>> pointer = await _db.database.query(
      DatabaseSchema.tableMeshMeta,
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[_activeUserKey],
      limit: 1,
    );
    if (pointer.isEmpty) return null;
    final String userId = pointer.first['value'] as String;
    final List<Map<String, Object?>> rows = await _db.database.query(
      DatabaseSchema.tableUsers,
      where: 'id = ?',
      whereArgs: <Object?>[userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromDbRow(rows.first);
  }

  /// Registers [resident], persisting it and marking it as this device's
  /// registered resident. Returns the stored user.
  Future<AppUser> registerResident(AppUser resident) async {
    await _db.database.insert(
      DatabaseSchema.tableUsers,
      resident.toDbRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _db.database.insert(
      DatabaseSchema.tableMeshMeta,
      <String, Object?>{'key': _registeredResidentKey, 'value': resident.id},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return resident;
  }

  /// Whether a resident has already registered on this device.
  Future<bool> hasRegisteredResident() async {
    return (await loadRegisteredResident()) != null;
  }

  /// Loads this device's registered resident, or `null` if none.
  Future<AppUser?> loadRegisteredResident() async {
    final List<Map<String, Object?>> pointer = await _db.database.query(
      DatabaseSchema.tableMeshMeta,
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[_registeredResidentKey],
      limit: 1,
    );
    if (pointer.isEmpty) return null;

    final String residentId = pointer.first['value'] as String;
    final List<Map<String, Object?>> rows = await _db.database.query(
      DatabaseSchema.tableUsers,
      where: 'id = ?',
      whereArgs: <Object?>[residentId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromDbRow(rows.first);
  }
}

/// Provides the [ResidentRegistrationRepository].
final Provider<ResidentRegistrationRepository>
    residentRegistrationRepositoryProvider =
    Provider<ResidentRegistrationRepository>((Ref ref) {
  return ResidentRegistrationRepository(ref.watch(appDatabaseProvider));
});
