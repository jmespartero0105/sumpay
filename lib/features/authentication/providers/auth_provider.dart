import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../data/services/auth_service.dart';
import '../data/repositories/resident_registration_repository.dart';
import '../models/app_user.dart';

/// Authentication state.
class AuthState {
  const AuthState({
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
    this.hasSeenOnboarding = false,
  });

  final AppUser? user;
  final bool isSubmitting;
  final String? errorMessage;
  final bool hasSeenOnboarding;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AppUser? user,
    bool? isSubmitting,
    String? errorMessage,
    bool? hasSeenOnboarding,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
    );
  }
}

/// Authentication controller backed by real local credentials.
///
/// Sign-in validates a phone + password against the SQLite `users` table via
/// [AuthService] (SHA-256 hashed passwords). There is no fictional fallback
/// user: an unauthenticated session has `user == null` and the app routes to
/// login. The service surface is small so a backend (Supabase) auth check can
/// replace the local one later without touching the UI.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState());

  final Ref _ref;

  AuthService get _auth => AuthService();
  ResidentRegistrationRepository get _registration =>
      _ref.read(residentRegistrationRepositoryProvider);

  /// Signs in with a mobile number and password, validating against stored
  /// accounts. On success the session pointer is persisted so login survives
  /// restarts.
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    final AuthResult result = await _auth.login(identifier, password);
    if (!result.ok) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: result.error,
      );
      return;
    }

    // Cache the authenticated account locally so the session can be restored
    // on restart and so the app works offline after login (mesh/SOS). Online
    // Supabase remains the source of truth for auth itself.
    await _registration.upsertUser(result.user!);
    await _registration.setActiveUser(result.user!.id);
    state = state.copyWith(
      isSubmitting: false,
      user: result.user,
      hasSeenOnboarding: true,
      clearError: true,
    );
  }

  /// Restores a previously signed-in user on app start, if any.
  Future<AppUser?> restoreSession() async {
    try {
      final AppUser? user = await _registration.loadActiveUser();
      if (user != null) {
        state = state.copyWith(user: user, hasSeenOnboarding: true);
      }
      return user;
    } catch (error) {
      debugPrint('Auth: restoreSession failed: $error');
      return null;
    }
  }

  void updateProfile(AppUser updated) {
    state = state.copyWith(user: updated);
  }

  /// Persists profile edits (medical info, emergency contacts, etc.) to the
  /// user's stored account so they survive restarts.
  Future<void> persistProfile(AppUser updated) async {
    state = state.copyWith(user: updated);
    try {
      await _registration.upsertUser(updated);
    } catch (error) {
      debugPrint('Auth: persistProfile failed: $error');
    }
  }

  void completeOnboarding() {
    state = state.copyWith(hasSeenOnboarding: true);
  }

  Future<void> signOut() async {
    await _registration.clearActiveUser();
    state = state.copyWith(clearUser: true, clearError: true);
  }
}

final StateNotifierProvider<AuthController, AuthState> authProvider =
    StateNotifierProvider<AuthController, AuthState>(
  (Ref ref) => AuthController(ref),
);

/// The signed-in user, or null when unauthenticated. Screens behind the login
/// gate always have a real user; callers that read this before login should
/// handle null.
final Provider<AppUser?> currentUserOrNullProvider =
    Provider<AppUser?>((Ref ref) {
  return ref.watch(authProvider).user;
});

/// The signed-in user. Only valid behind the login gate (the router routes
/// unauthenticated sessions to login), so this is safe to read on authed
/// screens. Throws if read while unauthenticated, surfacing misuse instead of
/// silently returning a fictional person.
final Provider<AppUser> currentUserProvider = Provider<AppUser>((Ref ref) {
  final AppUser? user = ref.watch(authProvider).user;
  if (user == null) {
    throw StateError(
        'currentUserProvider read while unauthenticated. Gate the screen '
        'behind login or use currentUserOrNullProvider.');
  }
  return user;
});

final Provider<UserRole> currentRoleProvider = Provider<UserRole>((Ref ref) {
  return ref.watch(currentUserProvider).role;
});
