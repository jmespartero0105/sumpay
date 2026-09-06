import '../models/broadcast_models.dart';

/// Seeded barangay announcements.
class DummyBroadcasts {
  const DummyBroadcasts._();

  static const List<Map<String, dynamic>> broadcastsJson =
      <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'BRD-2210',
      'title': 'Mandatory evacuation — Riverside and Shoreline',
      'body':
          'Water levels along the Banica River have breached the second alert mark. All households in Purok 2 and Purok 6 must proceed to Talay Elementary School immediately. Bring identification, maintenance medicine and three days of essentials.',
      'severity': 'alert',
      'issuedBy': 'Barangay Talay Office',
      'minutesAgo': 18,
      'reach': 412,
      'acknowledged': 287,
      'transport': 'loRa',
      'areas': <String>['Purok 2', 'Purok 6'],
      'isPinned': true,
    },
    <String, dynamic>{
      'id': 'BRD-2209',
      'title': 'Power interruption advisory',
      'body':
          'NORECO II has de-energised the Talay feeder line as a safety measure. Restoration is targeted once winds drop below 60 kph. Charge devices sparingly and rely on the mesh network for messaging.',
      'severity': 'warning',
      'issuedBy': 'Kagawad Elena Rubio',
      'minutesAgo': 74,
      'reach': 412,
      'acknowledged': 233,
      'transport': 'loRa',
      'areas': <String>['All Puroks'],
      'isPinned': false,
    },
    <String, dynamic>{
      'id': 'BRD-2208',
      'title': 'Relief distribution schedule',
      'body':
          'Family food packs will be distributed at the barangay hall starting 08:00 tomorrow. Distribution follows purok order. One representative per household only.',
      'severity': 'advisory',
      'issuedBy': 'Barangay Talay Office',
      'minutesAgo': 190,
      'reach': 412,
      'acknowledged': 301,
      'transport': 'loRa',
      'areas': <String>['All Puroks'],
      'isPinned': false,
    },
    <String, dynamic>{
      'id': 'BRD-2207',
      'title': 'Road closure — Mabini Street',
      'body':
          'A fallen electric post has blocked Mabini Street near the chapel. Use the Sitio Riverside detour until clearing operations finish.',
      'severity': 'warning',
      'issuedBy': 'Volunteer Team Alpha',
      'minutesAgo': 420,
      'reach': 210,
      'acknowledged': 158,
      'transport': 'mesh',
      'areas': <String>['Purok 5'],
      'isPinned': false,
    },
    <String, dynamic>{
      'id': 'BRD-2205',
      'title': 'Storm signal number 2 raised',
      'body':
          'PAGASA has raised Tropical Cyclone Wind Signal No. 2 over Negros Oriental. Secure loose roofing, prepare go-bags and monitor this channel for updates.',
      'severity': 'alert',
      'issuedBy': 'City DRRMO relay',
      'minutesAgo': 900,
      'reach': 412,
      'acknowledged': 380,
      'transport': 'loRa',
      'areas': <String>['All Puroks'],
      'isPinned': false,
    },
  ];

  static List<BroadcastMessage> get all => broadcastsJson
      .map((Map<String, dynamic> json) => BroadcastMessage.fromJson(json))
      .toList();

  /// Rotating preparedness tips shown on the home dashboard.
  static const List<String> emergencyTips = <String>[
    'Keep your go-bag within reach: water, medicine, flashlight, whistle and photocopies of your IDs.',
    'Conserve battery during outages — SUMPAY keeps working over LoRa even without mobile data.',
    'Agree on a family meeting point in advance so you can regroup if you are separated.',
    'Never wade through floodwater deeper than your knees; currents and debris are hard to judge.',
    'Send short messages during emergencies. Shorter payloads travel further on the mesh network.',
  ];

  /// Available broadcast target areas.
  static const List<String> areaOptions = <String>[
    'All Puroks',
    'Purok 1',
    'Purok 2',
    'Purok 3',
    'Purok 4',
    'Purok 5',
    'Purok 6',
    'Evacuation Centres',
  ];
}
