import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../authentication/data/services/auth_service.dart';
import '../../authentication/models/app_user.dart';
import '../data/repositories/user_management_repository.dart';

/// Immutable state for the administrator's user-management screen.
class UserManagementState {
  const UserManagementState({
    this.users = const <AppUser>[],
    this.isLoading = true,
  });

  final List<AppUser> users;
  final bool isLoading;

  List<AppUser> get pending =>
      users.where((AppUser u) => u.status.isPending).toList();

  List<AppUser> get active =>
      users.where((AppUser u) => u.status.isActive).toList();

  int get pendingCount => pending.length;

  UserManagementState copyWith({List<AppUser>? users, bool? isLoading}) {
    return UserManagementState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Drives the administrator's user-management workflows: listing accounts,
/// approving or rejecting pending ones, changing roles, and registering new
/// accounts. All changes persist through [UserManagementRepository].
class UserManagementController extends StateNotifier<UserManagementState> {
  UserManagementController(this._repository, this._authService)
      : super(const UserManagementState()) {
    _load();
  }

  final UserManagementRepository _repository;
  final AuthService _authService;

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    // Admin views accounts from Supabase (all roles + pending residents).
    final List<AppUser> users = await _authService.fetchAccounts();
    state = state.copyWith(users: users, isLoading: false);
  }

  Future<void> refresh() => _load();

  Future<void> approve(String userId) async {
    await _authService.updateStatus(userId, 'active');
    await _load();
  }

  Future<void> reject(String userId) async {
    await _authService.updateStatus(userId, 'rejected');
    await _load();
  }

  Future<void> deactivate(String userId) async {
    await _authService.updateStatus(userId, 'inactive');
    await _load();
  }

  Future<void> reactivate(String userId) async {
    await _authService.updateStatus(userId, 'active');
    await _load();
  }

  Future<void> changeRole(String userId, UserRole role) async {
    await _authService.updateRole(userId, role.name);
    await _load();
  }

  /// Updates a user's editable profile fields (admin edit action).
  Future<void> updateProfile(
    String userId, {
    String? surname,
    String? firstName,
    String? middleName,
    String? phone,
    String? email,
    String? barangay,
    String? purok,
    String? municipality,
    int? householdSize,
  }) async {
    await _authService.updateProfile(
      userId,
      surname: surname,
      firstName: firstName,
      middleName: middleName,
      phone: phone,
      email: email,
      barangay: barangay,
      purok: purok,
      municipality: municipality,
      householdSize: householdSize,
    );
    await _load();
  }

  /// Registers a new account and reloads. Returns whether the new account is
  /// pending approval (officials and volunteers) so the UI can message it.
  /// An initial [password] is set so the created staff member can sign in.
  Future<bool> register(AppUser user, {required String password}) async {
    try {
      // Admin-created officials/responders are written to Supabase (online,
      // server-authoritative). createAccount stores the hashed password too.
      final AuthResult result = await _authService.createAccount(user, password);
      if (!result.ok) {
        throw StateError(result.error ?? 'Account creation failed.');
      }
      await _load();
      return user.role.requiresApproval;
    } catch (error) {
      debugPrint('UserManagement: register failed: $error');
      rethrow;
    }
  }
}

final StateNotifierProvider<UserManagementController, UserManagementState>
    userManagementProvider =
    StateNotifierProvider<UserManagementController, UserManagementState>(
  (Ref ref) => UserManagementController(
    ref.watch(userManagementRepositoryProvider),
    AuthService(),
  ),
);
