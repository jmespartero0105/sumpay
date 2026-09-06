import '../models/app_user.dart';

/// Dummy account payloads. Replace with API responses during integration.
class DummyUsers {
  const DummyUsers._();

  static const Map<String, dynamic> residentJson = <String, dynamic>{
    'id': 'RES-2041',
    'fullName': 'Maria Liza Fernandez',
    'role': 'resident',
    'phone': '+63 917 442 8810',
    'email': 'maria.fernandez@example.ph',
    'barangay': 'Talay',
    'purok': 'Purok 4, Sitio Bagong Silang',
    'municipality': 'Dumaguete City, Negros Oriental',
    'householdSize': 5,
    'language': 'English',
    'deviceId': 'SUMPAY-NODE-A19F',
    'emergencyContacts': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'EC-1',
        'name': 'Roberto Fernandez',
        'relationship': 'Spouse',
        'phone': '+63 918 220 1145',
      },
      <String, dynamic>{
        'id': 'EC-2',
        'name': 'Ana Fernandez',
        'relationship': 'Daughter',
        'phone': '+63 995 771 3320',
      },
      <String, dynamic>{
        'id': 'EC-3',
        'name': 'Barangay Talay Hotline',
        'relationship': 'Barangay Office',
        'phone': '+63 35 225 0117',
      },
    ],
    'medical': <String, dynamic>{
      'bloodType': 'O+',
      'allergies': <String>['Penicillin', 'Shellfish'],
      'conditions': <String>['Hypertension'],
      'medications': <String>['Losartan 50mg'],
      'notes': 'Requires assistance during evacuation. Uses a walking cane.',
    },
  };

  static const Map<String, dynamic> volunteerJson = <String, dynamic>{
    'id': 'VOL-0117',
    'fullName': 'Jomar Delos Santos',
    'role': 'volunteer',
    'phone': '+63 926 118 4402',
    'email': 'jomar.ds@example.ph',
    'barangay': 'Talay',
    'purok': 'Purok 2, Sitio Riverside',
    'municipality': 'Dumaguete City, Negros Oriental',
    'householdSize': 3,
    'language': 'Cebuano',
    'deviceId': 'SUMPAY-NODE-B03C',
    'emergencyContacts': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'EC-4',
        'name': 'Cristina Delos Santos',
        'relationship': 'Mother',
        'phone': '+63 917 664 2201',
      },
    ],
    'medical': <String, dynamic>{
      'bloodType': 'A-',
      'allergies': <String>[],
      'conditions': <String>[],
      'medications': <String>[],
      'notes': 'Certified in basic life support and water rescue.',
    },
  };

  static const Map<String, dynamic> officialJson = <String, dynamic>{
    'id': 'OFF-0004',
    'fullName': 'Kagawad Elena Rubio',
    'role': 'official',
    'phone': '+63 920 553 7781',
    'email': 'elena.rubio@barangaytalay.gov.ph',
    'barangay': 'Talay',
    'purok': 'Barangay Hall',
    'municipality': 'Dumaguete City, Negros Oriental',
    'householdSize': 4,
    'language': 'English',
    'deviceId': 'SUMPAY-CMD-0001',
    'emergencyContacts': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'EC-5',
        'name': 'City DRRMO',
        'relationship': 'Agency',
        'phone': '+63 35 522 0000',
      },
    ],
    'medical': <String, dynamic>{
      'bloodType': 'B+',
      'allergies': <String>[],
      'conditions': <String>[],
      'medications': <String>[],
      'notes': '',
    },
  };

  static const Map<String, dynamic> adminJson = <String, dynamic>{
    'id': 'ADM-0001',
    'fullName': 'Admin Marisol Vega',
    'role': 'admin',
    'phone': '+63 917 100 2003',
    'email': 'admin@barangaytalay.gov.ph',
    'barangay': 'Talay',
    'purok': 'Barangay Hall',
    'municipality': 'Dumaguete City, Negros Oriental',
    'householdSize': 3,
    'language': 'English',
    'deviceId': 'SUMPAY-ADMIN-0001',
    'status': 'active',
    'emergencyContacts': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'EC-9',
        'name': 'City DRRMO',
        'relationship': 'Agency',
        'phone': '+63 35 522 0000',
      },
    ],
    'medical': <String, dynamic>{
      'bloodType': 'O+',
      'allergies': <String>[],
      'conditions': <String>[],
      'medications': <String>[],
      'notes': '',
    },
  };

  /// A pending official awaiting administrator confirmation.
  static const Map<String, dynamic> pendingOfficialJson = <String, dynamic>{
    'id': 'OFF-0007',
    'fullName': 'Kagawad Ramon Diaz',
    'role': 'official',
    'phone': '+63 921 447 9902',
    'email': 'ramon.diaz@barangaytalay.gov.ph',
    'barangay': 'Talay',
    'purok': 'Purok 3',
    'municipality': 'Dumaguete City, Negros Oriental',
    'householdSize': 5,
    'language': 'English',
    'deviceId': 'SUMPAY-CMD-0007',
    'status': 'pending',
    'emergencyContacts': <Map<String, dynamic>>[],
    'medical': <String, dynamic>{
      'bloodType': 'A+',
      'allergies': <String>[],
      'conditions': <String>[],
      'medications': <String>[],
      'notes': '',
    },
  };

  /// A pending volunteer awaiting administrator confirmation.
  static const Map<String, dynamic> pendingVolunteerJson = <String, dynamic>{
    'id': 'VOL-0011',
    'fullName': 'Jonathan Cruz',
    'role': 'volunteer',
    'phone': '+63 918 662 5540',
    'email': 'jonathan.cruz@example.com',
    'barangay': 'Talay',
    'purok': 'Purok 5',
    'municipality': 'Dumaguete City, Negros Oriental',
    'householdSize': 2,
    'language': 'Cebuano',
    'deviceId': 'SUMPAY-VOL-0011',
    'status': 'pending',
    'emergencyContacts': <Map<String, dynamic>>[],
    'medical': <String, dynamic>{
      'bloodType': 'O-',
      'allergies': <String>[],
      'conditions': <String>[],
      'medications': <String>[],
      'notes': '',
    },
  };

  static AppUser get resident => AppUser.fromJson(residentJson);
  static AppUser get volunteer => AppUser.fromJson(volunteerJson);
  static AppUser get official => AppUser.fromJson(officialJson);
  static AppUser get admin => AppUser.fromJson(adminJson);
  static AppUser get pendingOfficial => AppUser.fromJson(pendingOfficialJson);
  static AppUser get pendingVolunteer => AppUser.fromJson(pendingVolunteerJson);

  static List<AppUser> get all => <AppUser>[
        resident,
        volunteer,
        official,
        admin,
        pendingOfficial,
        pendingVolunteer,
      ];
}
