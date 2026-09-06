import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/data/repository.dart';
import '../../models/app_user.dart';
import '../dummy_users.dart';

/// Data-layer access point for [AppUser] records.
///
/// Phase 1 sources every account from [DummyUsers]. When the backend and
/// SQLite-backed sync arrive, only this class changes — the auth controller and
/// screens continue to depend on the interface, not the data source.
abstract interface class UserRepository implements ReadableRepository<AppUser> {
  /// Returns the seeded persona for a given [role].
  Future<AppUser> userForRole(UserRole role);

  /// Resolves a user by id, or `null` when not found.
  Future<AppUser?> findById(String id);
}

/// Dummy implementation backed by in-memory seed data.
class DummyUserRepository implements UserRepository {
  const DummyUserRepository();

  @override
  String get name => 'DummyUserRepository';

  @override
  Future<List<AppUser>> fetchAll() async => DummyUsers.all;

  @override
  Future<AppUser> userForRole(UserRole role) async => switch (role) {
        UserRole.user => DummyUsers.resident,
        UserRole.official => DummyUsers.official,
        UserRole.admin => DummyUsers.admin,
      };

  @override
  Future<AppUser?> findById(String id) async {
    for (final AppUser user in DummyUsers.all) {
      if (user.id == id) return user;
    }
    return null;
  }
}

/// Provides the active [UserRepository] implementation.
final Provider<UserRepository> userRepositoryProvider =
    Provider<UserRepository>((Ref ref) => const DummyUserRepository());
