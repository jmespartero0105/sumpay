import 'dart:convert';

import '../../../core/constants/app_enums.dart';

/// Emergency contact attached to a resident profile.
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
  });

  final String id;
  final String name;
  final String relationship;
  final String phone;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      relationship: (json['relationship'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'relationship': relationship,
        'phone': phone,
      };
}

/// Medical information surfaced to responders during an SOS.
class MedicalProfile {
  const MedicalProfile({
    required this.bloodType,
    required this.allergies,
    required this.conditions,
    required this.medications,
    this.notes = '',
  });

  final String bloodType;
  final List<String> allergies;
  final List<String> conditions;
  final List<String> medications;
  final String notes;

  factory MedicalProfile.fromJson(Map<String, dynamic> json) {
    return MedicalProfile(
      bloodType: (json['bloodType'] as String?) ?? 'Unknown',
      allergies: json['allergies'] is List
          ? List<String>.from(json['allergies'] as List<dynamic>)
          : <String>[],
      conditions: json['conditions'] is List
          ? List<String>.from(json['conditions'] as List<dynamic>)
          : <String>[],
      medications: json['medications'] is List
          ? List<String>.from(json['medications'] as List<dynamic>)
          : <String>[],
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'bloodType': bloodType,
        'allergies': allergies,
        'conditions': conditions,
        'medications': medications,
        'notes': notes,
      };
}

/// The signed-in account.
class AppUser {
  const AppUser({
    required this.id,
    required this.surname,
    required this.firstName,
    this.middleName = '',
    required this.role,
    required this.phone,
    required this.email,
    required this.barangay,
    required this.purok,
    required this.municipality,
    required this.householdSize,
    required this.language,
    required this.deviceId,
    required this.emergencyContacts,
    required this.medical,
    this.status = AccountStatus.active,
  });

  final String id;
  final String surname;
  final String firstName;
  final String middleName;
  final UserRole role;
  final String phone;
  final String email;
  final String barangay;
  final String purok;
  final String municipality;
  final int householdSize;
  final String language;
  final String deviceId;
  final List<EmergencyContact> emergencyContacts;
  final MedicalProfile medical;

  /// Account approval state, managed by an administrator.
  final AccountStatus status;

  /// Display name in the adviser-specified convention: "Surname, First Middle"
  /// (middle name optional). Kept as a getter so existing display code that
  /// reads `fullName` continues to work after the name was split into parts.
  String get fullName {
    final String given =
        middleName.trim().isEmpty ? firstName : '$firstName $middleName';
    return '$surname, $given';
  }

  /// Natural order ("First Middle Surname"), for contexts that prefer it.
  String get displayName {
    final String mid = middleName.trim().isEmpty ? '' : '$middleName ';
    return '$firstName $mid$surname';
  }

  String get address => '$purok, Barangay $barangay, $municipality';

  AppUser copyWith({
    String? surname,
    String? firstName,
    String? middleName,
    UserRole? role,
    String? phone,
    String? email,
    String? barangay,
    String? purok,
    String? municipality,
    int? householdSize,
    String? language,
    List<EmergencyContact>? emergencyContacts,
    MedicalProfile? medical,
    AccountStatus? status,
  }) {
    return AppUser(
      id: id,
      surname: surname ?? this.surname,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      barangay: barangay ?? this.barangay,
      purok: purok ?? this.purok,
      municipality: municipality ?? this.municipality,
      householdSize: householdSize ?? this.householdSize,
      language: language ?? this.language,
      deviceId: deviceId,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      medical: medical ?? this.medical,
      status: status ?? this.status,
    );
  }

  /// Builds an [AppUser] from a SQLite `users` table row. Centralised here so
  /// the auth service and registration repository share one mapping.
  factory AppUser.fromDbRow(Map<String, Object?> row) {
    final Object? rawContacts = row['emergency_contacts'];
    final List<dynamic> contacts = rawContacts is String
        ? (rawContacts.isEmpty
            ? <dynamic>[]
            : jsonDecode(rawContacts) as List<dynamic>)
        : (rawContacts is List ? rawContacts : <dynamic>[]);
    final Object? rawMedical = row['medical'];
    final Map<String, dynamic> medical = rawMedical is String
        ? (rawMedical.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(rawMedical) as Map<String, dynamic>)
        : (rawMedical is Map ? Map<String, dynamic>.from(rawMedical) : <String, dynamic>{});
    final Object? rawStatus = row['status'];
    final Object? rawRole = row['role'];
    return AppUser(
      id: (row['id'] as String?) ?? '',
      surname: (row['surname'] as String?) ?? '',
      firstName: (row['first_name'] as String?) ?? '',
      middleName: (row['middle_name'] as String?) ?? '',
      role: UserRole.fromName(rawRole is String ? rawRole : null),
      phone: (row['phone'] as String?) ?? '',
      email: (row['email'] as String?) ?? '',
      barangay: (row['barangay'] as String?) ?? '',
      purok: (row['purok'] as String?) ?? '',
      municipality: (row['municipality'] as String?) ?? '',
      householdSize: (row['household_size'] as int?) ?? 1,
      language: (row['language'] as String?) ?? 'English',
      deviceId: (row['device_id'] as String?) ?? '',
      emergencyContacts: contacts
          .map((dynamic e) =>
              EmergencyContact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      medical: MedicalProfile.fromJson(medical),
      status: rawStatus is String
          ? AccountStatus.values.byName(rawStatus)
          : AccountStatus.active,
    );
  }

  /// Serialises to a SQLite `users` table row (excludes password_hash, which is
  /// managed by the auth service).
  Map<String, Object?> toDbRow() => <String, Object?>{
        'id': id,
        'surname': surname,
        'first_name': firstName,
        'middle_name': middleName,
        'role': role.name,
        'phone': phone,
        'email': email,
        'barangay': barangay,
        'purok': purok,
        'municipality': municipality,
        'household_size': householdSize,
        'language': language,
        'device_id': deviceId,
        'blood_type': medical.bloodType,
        'emergency_contacts': jsonEncode(
          emergencyContacts.map((EmergencyContact c) => c.toJson()).toList(),
        ),
        'medical': jsonEncode(medical.toJson()),
        'status': status.name,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      surname: (json['surname'] as String?) ?? '',
      firstName: (json['firstName'] as String?) ?? '',
      middleName: (json['middleName'] as String?) ?? '',
      role: UserRole.fromName(json['role'] as String?),
      phone: json['phone'] as String,
      email: json['email'] as String,
      barangay: json['barangay'] as String,
      purok: json['purok'] as String,
      municipality: json['municipality'] as String,
      householdSize: json['householdSize'] as int,
      language: json['language'] as String,
      deviceId: json['deviceId'] as String,
      emergencyContacts: (json['emergencyContacts'] as List<dynamic>)
          .map((dynamic e) =>
              EmergencyContact.fromJson(e as Map<String, dynamic>))
          .toList(),
      medical: MedicalProfile.fromJson(
        json['medical'] as Map<String, dynamic>,
      ),
      status: json['status'] == null
          ? AccountStatus.active
          : AccountStatus.values.byName(json['status'] as String),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'surname': surname,
        'firstName': firstName,
        'middleName': middleName,
        'role': role.name,
        'phone': phone,
        'email': email,
        'barangay': barangay,
        'purok': purok,
        'municipality': municipality,
        'householdSize': householdSize,
        'language': language,
        'deviceId': deviceId,
        'emergencyContacts':
            emergencyContacts.map((EmergencyContact e) => e.toJson()).toList(),
        'medical': medical.toJson(),
        'status': status.name,
      };
}
