import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_config.dart';
import '../../models/app_user.dart';

/// Result of an authentication attempt.
class AuthResult {
  const AuthResult._({this.user, this.error});

  const AuthResult.success(AppUser user) : this._(user: user);
  const AuthResult.failure(String error) : this._(error: error);

  final AppUser? user;
  final String? error;

  bool get ok => user != null;
}

/// Online authentication service backed by the Supabase `users` table.
///
/// For this phase all roles authenticate online: login looks up the account by
/// phone in Supabase, verifies a SHA-256 password hash, checks approval status,
/// and returns the account with its stored role (the app routes by that role).
/// Account creation (admin-created officials/responders, and resident
/// self-registration) writes to the same table.
///
/// The surface is intentionally small (`login`, `createAccount`, `setPassword`,
/// `phoneExists`, `updateStatus`, `pendingResidents`) so a stricter backend
/// (Supabase Auth + RLS) can replace the internals later without changing
/// callers. Passwords are never stored in plaintext.
class AuthService {
  const AuthService();

  static const String _table = 'users';

  SupabaseClient get _client => Supabase.instance.client;

  /// Hashes a password with SHA-256. (A future backend upgrade can move to
  /// salted, server-side hashing; this keeps stored values non-plaintext.)
  static String hash(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Maps a Supabase row (snake_case columns) to the shape [AppUser.fromDbRow]
  /// expects. jsonb columns arrive as decoded objects, so re-encode the nested
  /// ones to strings for the shared mapper.
  AppUser _userFromSupabase(Map<String, dynamic> row) {
    final Map<String, Object?> normalised = <String, Object?>{
      'id': row['id'],
      'surname': row['surname'] ?? '',
      'first_name': row['first_name'] ?? '',
      'middle_name': row['middle_name'] ?? '',
      'role': row['role'],
      'phone': row['phone'],
      'email': row['email'] ?? '',
      'barangay': row['barangay'] ?? '',
      'purok': row['purok'] ?? '',
      'municipality': row['municipality'] ?? '',
      'household_size': row['household_size'] ?? 1,
      'language': row['language'] ?? 'English',
      'device_id': row['device_id'] ?? '',
      'emergency_contacts': row['emergency_contacts'] is String
          ? row['emergency_contacts']
          : jsonEncode(row['emergency_contacts'] ?? <dynamic>[]),
      'medical': row['medical'] is String
          ? row['medical']
          : jsonEncode(row['medical'] ?? <String, dynamic>{}),
      'status': row['status'] ?? 'active',
    };
    return AppUser.fromDbRow(normalised);
  }

  /// Attempts to sign in with [phone] + [password] against Supabase.
  Future<AuthResult> login(String phone, String password) async {
    final String trimmedPhone = phone.trim();
    if (trimmedPhone.isEmpty || password.isEmpty) {
      return const AuthResult.failure(
          'Enter your mobile number and password to continue.');
    }
    if (!SupabaseConfig.isConfigured) {
      return const AuthResult.failure(
          'No connection to the server. Please check your internet and try again.');
    }

    try {
      final dynamic response = await _client
          .from(_table)
          .select()
          .eq('phone', trimmedPhone)
          .limit(1);
      final List<Map<String, dynamic>> rows =
          (response as List<dynamic>).cast<Map<String, dynamic>>();

      if (rows.isEmpty) {
        return const AuthResult.failure(
            'No account found for that mobile number.');
      }

      final Map<String, dynamic> row = rows.first;
      final String? storedHash = row['password_hash'] as String?;
      if (storedHash == null || storedHash.isEmpty) {
        return const AuthResult.failure(
            'This account has no password set. Contact your barangay admin.');
      }
      if (storedHash != hash(password)) {
        return const AuthResult.failure(
            'Incorrect password. Please try again.');
      }

      final String status = (row['status'] as String?) ?? 'active';
      if (status == 'pending') {
        return const AuthResult.failure(
            'Your account is awaiting administrator approval.');
      }
      if (status == 'rejected' || status == 'inactive') {
        return const AuthResult.failure(
            'This account is not active. Contact your barangay admin.');
      }

      return AuthResult.success(_userFromSupabase(row));
    } catch (error) {
      return AuthResult.failure('Could not reach the server. ($error)');
    }
  }

  /// Whether an account already exists for [phone].
  Future<bool> phoneExists(String phone) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      final dynamic response = await _client
          .from(_table)
          .select('id')
          .eq('phone', phone.trim())
          .limit(1);
      final List<dynamic> rows = response as List<dynamic>;
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Creates an account in Supabase with the given [password]. Used by admin
  /// staff creation and resident self-registration. The [user]'s status is
  /// honored (active for admin-created staff, pending for residents).
  Future<AuthResult> createAccount(AppUser user, String password) async {
    if (!SupabaseConfig.isConfigured) {
      return const AuthResult.failure(
          'No connection to the server. Please check your internet and try again.');
    }
    try {
      final Map<String, Object?> row = user.toDbRow()
        ..remove('blood_type') // not a column in Supabase users
        ..['password_hash'] = hash(password)
        ..['emergency_contacts'] = jsonDecode(
            (user.toDbRow()['emergency_contacts'] as String?) ?? '[]')
        ..['medical'] =
            jsonDecode((user.toDbRow()['medical'] as String?) ?? '{}');
      await _client.from(_table).insert(row);
      return AuthResult.success(user);
    } catch (error) {
      return AuthResult.failure('Could not create the account. ($error)');
    }
  }

  /// Sets/updates the password hash for [userId] in Supabase.
  Future<void> setPassword(String userId, String password) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      await _client
          .from(_table)
          .update(<String, Object?>{'password_hash': hash(password)}).eq(
              'id', userId);
    } catch (_) {
      // Non-fatal for the demo; surfaced elsewhere if needed.
    }
  }

  /// Updates the account [status] (approve/reject residents).
  Future<void> updateStatus(String userId, String status) async {
    if (!SupabaseConfig.isConfigured) return;
    await _client
        .from(_table)
        .update(<String, Object?>{'status': status}).eq('id', userId);
  }

  /// Updates a user's [role] in the backend (admin action).
  Future<void> updateRole(String userId, String role) async {
    if (!SupabaseConfig.isConfigured) return;
    await _client
        .from(_table)
        .update(<String, Object?>{'role': role}).eq('id', userId);
  }

  /// Updates editable profile fields for a user (admin edit action).
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
    if (!SupabaseConfig.isConfigured) return;
    final Map<String, Object?> updates = <String, Object?>{
      if (surname != null) 'surname': surname,
      if (firstName != null) 'first_name': firstName,
      if (middleName != null) 'middle_name': middleName,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (barangay != null) 'barangay': barangay,
      if (purok != null) 'purok': purok,
      if (municipality != null) 'municipality': municipality,
      if (householdSize != null) 'household_size': householdSize,
    };
    if (updates.isEmpty) return;
    await _client.from(_table).update(updates).eq('id', userId);
  }

  /// Fetches all accounts (optionally by [role] and/or [status]).
  Future<List<AppUser>> fetchAccounts({String? role, String? status}) async {
    if (!SupabaseConfig.isConfigured) return <AppUser>[];
    try {
      var query = _client.from(_table).select();
      if (role != null) query = query.eq('role', role);
      if (status != null) query = query.eq('status', status);
      final dynamic response = await query;
      final List<Map<String, dynamic>> rows =
          (response as List<dynamic>).cast<Map<String, dynamic>>();
      return rows.map(_userFromSupabase).toList();
    } catch (error, stack) {
      // Surface the reason instead of silently returning empty, which would
      // make the admin roster look empty for no visible reason.
      debugPrint('AuthService.fetchAccounts failed: $error\n$stack');
      return <AppUser>[];
    }
  }
}
