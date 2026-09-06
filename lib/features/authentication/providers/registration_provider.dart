import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../data/services/auth_service.dart';
import '../data/repositories/resident_registration_repository.dart';
import '../models/app_user.dart';

/// State of the resident registration workflow.
class RegistrationState {
  const RegistrationState({
    this.isSubmitting = false,
    this.registered,
    this.errorMessage,
  });

  final bool isSubmitting;

  /// The resident registered on this device, once known (either freshly
  /// registered or restored from storage on launch).
  final AppUser? registered;

  final String? errorMessage;

  bool get hasRegistered => registered != null;

  RegistrationState copyWith({
    bool? isSubmitting,
    AppUser? registered,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RegistrationState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      registered: registered ?? this.registered,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Drives resident self-registration (Phase 2.1 user identity management).
///
/// Collects the resident's details, generates a unique resident id, and
/// persists the account locally through [ResidentRegistrationRepository]. No
/// authentication is involved. On construction it restores any resident already
/// registered on this device so identity survives restarts.
class RegistrationController extends StateNotifier<RegistrationState> {
  RegistrationController(this._repository, this._authService)
      : super(const RegistrationState()) {
    _restore();
  }

  final ResidentRegistrationRepository _repository;
  final AuthService _authService;

  Future<void> _restore() async {
    final AppUser? existing = await _repository.loadRegisteredResident();
    if (existing != null) {
      state = state.copyWith(registered: existing);
    }
  }

  /// Registers a resident from the collected form fields and returns the stored
  /// [AppUser]. Full name and barangay are required; phone is optional.
  Future<AppUser?> registerResident({
    required String surname,
    required String firstName,
    required String email,
    required String barangay,
    required String password,
    String middleName = '',
    String phone = '',
    String purok = '',
    int householdSize = 1,
    String language = 'English',
    String bloodType = 'Unknown',
    List<EmergencyContact> emergencyContacts = const <EmergencyContact>[],
  }) async {
    final String surnameTrimmed = surname.trim();
    final String firstNameTrimmed = firstName.trim();
    final String middleTrimmed = middleName.trim();
    final String emailTrimmed = email.trim();
    final String brgy = barangay.trim();
    final String phoneTrimmed = phone.trim();
    if (surnameTrimmed.isEmpty) {
      state = state.copyWith(errorMessage: 'Surname is required.');
      return null;
    }
    if (firstNameTrimmed.isEmpty) {
      state = state.copyWith(errorMessage: 'First name is required.');
      return null;
    }
    if (emailTrimmed.isEmpty || !emailTrimmed.contains('@')) {
      state = state.copyWith(errorMessage: 'A valid email is required.');
      return null;
    }
    if (brgy.isEmpty) {
      state = state.copyWith(errorMessage: 'Barangay is required.');
      return null;
    }
    if (phoneTrimmed.isEmpty) {
      state = state.copyWith(
          errorMessage: 'Mobile number is required to sign in later.');
      return null;
    }
    if (password.length < 6) {
      state = state.copyWith(
          errorMessage: 'Password must be at least 6 characters.');
      return null;
    }
    // Prevent duplicate accounts on the same mobile number.
    if (await _authService.phoneExists(phoneTrimmed)) {
      state = state.copyWith(
          errorMessage: 'An account already exists for that mobile number.');
      return null;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final String id = _repository.generateResidentId();
      final AppUser resident = AppUser(
        id: id,
        surname: surnameTrimmed,
        firstName: firstNameTrimmed,
        middleName: middleTrimmed,
        role: UserRole.user,
        phone: phoneTrimmed,
        email: emailTrimmed,
        barangay: brgy,
        purok: purok.trim(),
        municipality: 'Dumaguete City, Negros Oriental',
        householdSize: householdSize,
        language: language,
        deviceId: 'SUMPAY-$id',
        emergencyContacts: emergencyContacts,
        medical: MedicalProfile(
          bloodType: bloodType,
          allergies: const <String>[],
          conditions: const <String>[],
          medications: const <String>[],
        ),
        // Residents self-register and must be approved by an admin before
        // they can sign in.
        status: AccountStatus.pending,
      );

      // Residents self-register into Supabase as 'pending'; an admin approves
      // them online before they can sign in. createAccount stores the hash.
      final AuthResult result =
          await _authService.createAccount(resident, password);
      if (!result.ok) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: result.error ?? 'Could not complete registration.',
        );
        return null;
      }
      state = state.copyWith(
        isSubmitting: false,
        registered: resident,
        clearError: true,
      );
      return resident;
    } catch (error) {
      debugPrint('Registration failed: $error');
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Could not complete registration. Please try again.',
      );
      return null;
    }
  }
}

final StateNotifierProvider<RegistrationController, RegistrationState>
    registrationProvider =
    StateNotifierProvider<RegistrationController, RegistrationState>(
  (Ref ref) => RegistrationController(
    ref.watch(residentRegistrationRepositoryProvider),
    AuthService(),
  ),
);

/// Current User Service: the registered resident on this device, if any.
///
/// Formalizes identity access for the registered-resident path. Screens that
/// need the active resident specifically can watch this; the broader
/// `currentUserProvider` still resolves the active persona (including demo
/// accounts) for role-based navigation.
final Provider<AppUser?> registeredResidentProvider =
    Provider<AppUser?>((Ref ref) {
  return ref.watch(registrationProvider).registered;
});
