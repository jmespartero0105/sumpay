
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/data/app_database.dart';
import '../../../../core/data/database_provider.dart';
import '../../../../core/data/database_schema.dart';
import '../../../authentication/models/app_user.dart';

/// Administrator-facing data access for user accounts.
///
/// Reads and writes the `users` table directly (including the `status` column
/// added for admin approval), so approvals, rejections, role changes and newly
/// registered accounts persist across restarts. This is separate from the
/// authentication `UserRepository`, which only seeds login personas.
class UserManagementRepository {
  const UserManagementRepository(this._db);

  final AppDatabase _db;

  /// Loads every account, newest-looking order preserved by insertion.
  Future<List<AppUser>> fetchAll() async {
    if (!_db.isAvailable) return <AppUser>[];
    final List<Map<String, Object?>> rows =
        await _db.database.query(DatabaseSchema.tableUsers);
    return rows.map(AppUser.fromDbRow).toList();
  }

  /// Loads only accounts awaiting approval.
  Future<List<AppUser>> fetchPending() async {
    if (!_db.isAvailable) return <AppUser>[];
    final List<Map<String, Object?>> rows = await _db.database.query(
      DatabaseSchema.tableUsers,
      where: 'status = ?',
      whereArgs: <Object?>[AccountStatus.pending.name],
    );
    return rows.map(AppUser.fromDbRow).toList();
  }

  /// Persists a new account. Officials and volunteers are stored as pending;
  /// residents and admins are active immediately.
  Future<void> register(AppUser user) async {
    if (!_db.isAvailable) return;
    final AccountStatus status = user.role.requiresApproval
        ? AccountStatus.pending
        : AccountStatus.active;
    await _db.database.insert(
      DatabaseSchema.tableUsers,
      user.copyWith(status: status).toDbRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates an account's approval status.
  Future<void> setStatus(String userId, AccountStatus status) async {
    if (!_db.isAvailable) return;
    await _db.database.update(
      DatabaseSchema.tableUsers,
      <String, Object?>{'status': status.name},
      where: 'id = ?',
      whereArgs: <Object?>[userId],
    );
  }

  Future<void> approve(String userId) =>
      setStatus(userId, AccountStatus.active);

  Future<void> reject(String userId) =>
      setStatus(userId, AccountStatus.rejected);

  Future<void> deactivate(String userId) =>
      setStatus(userId, AccountStatus.deactivated);

  /// Changes a user's role. If the new role requires approval and the account
  /// is active, it is left active (an admin making the change is the approval).
  Future<void> setRole(String userId, UserRole role) async {
    if (!_db.isAvailable) return;
    await _db.database.update(
      DatabaseSchema.tableUsers,
      <String, Object?>{'role': role.name},
      where: 'id = ?',
      whereArgs: <Object?>[userId],
    );
  }

  Future<void> delete(String userId) async {
    if (!_db.isAvailable) return;
    await _db.database.delete(
      DatabaseSchema.tableUsers,
      where: 'id = ?',
      whereArgs: <Object?>[userId],
    );
  }
}


/// Provides the [UserManagementRepository], wired to the initialised database.
final Provider<UserManagementRepository> userManagementRepositoryProvider =
    Provider<UserManagementRepository>((Ref ref) {
  return UserManagementRepository(ref.watch(appDatabaseProvider));
});
