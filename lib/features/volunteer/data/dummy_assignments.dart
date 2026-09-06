import '../models/assignment.dart';

/// Seeded volunteer assignments.
class DummyAssignments {
  const DummyAssignments._();

  static const List<Map<String, dynamic>> assignmentsJson =
      <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'TSK-8801',
      'title': 'Medical evacuation — unresponsive elder',
      'description':
          'Assist Rescue Team Bravo in extracting an unresponsive elderly resident. Bring the spine board and oxygen kit.',
      'type': 'medical',
      'priority': 'critical',
      'status': 'inProgress',
      'locationLabel': 'Purok 4, Sitio Bagong Silang',
      'distanceMetres': 420.0,
      'minutesAgo': 12,
      'peopleWaiting': 1,
      'teamName': 'Volunteer Team Alpha',
      'linkedSosId': 'SOS-4471',
    },
    <String, dynamic>{
      'id': 'TSK-8799',
      'title': 'Water rescue — family trapped on second floor',
      'description':
          'Six persons stranded as floodwater rises. Coordinate with the boat crew before approaching.',
      'type': 'rescue',
      'priority': 'critical',
      'status': 'accepted',
      'locationLabel': 'Purok 2, Riverside',
      'distanceMetres': 1180.0,
      'minutesAgo': 36,
      'peopleWaiting': 6,
      'teamName': 'Volunteer Team Alpha',
      'linkedSosId': 'SOS-4468',
    },
    <String, dynamic>{
      'id': 'TSK-8795',
      'title': 'Deliver drinking water to evacuation centre',
      'description':
          'Transport twenty containers of potable water and infant formula to the centre marshal.',
      'type': 'supply',
      'priority': 'normal',
      'status': 'pending',
      'locationLabel': 'Talay Elementary School',
      'distanceMetres': 760.0,
      'minutesAgo': 58,
      'peopleWaiting': 120,
      'teamName': 'Logistics Team',
      'linkedSosId': 'SOS-4462',
    },
    <String, dynamic>{
      'id': 'TSK-8790',
      'title': 'Household headcount sweep — Purok 3',
      'description':
          'Verify occupancy for every household and report persons with disability requiring transport.',
      'type': 'custom',
      'priority': 'normal',
      'status': 'pending',
      'locationLabel': 'Purok 3',
      'distanceMetres': 2100.0,
      'minutesAgo': 120,
      'peopleWaiting': 0,
      'teamName': 'Volunteer Team Alpha',
      'linkedSosId': null,
    },
    <String, dynamic>{
      'id': 'TSK-8781',
      'title': 'Clear debris on Mabini Street',
      'description':
          'Support NORECO II crew in cordoning the fallen post and rerouting foot traffic.',
      'type': 'custom',
      'priority': 'low',
      'status': 'completed',
      'locationLabel': 'Purok 5, Mabini Street',
      'distanceMetres': 640.0,
      'minutesAgo': 380,
      'peopleWaiting': 0,
      'teamName': 'Volunteer Team Alpha',
      'linkedSosId': 'SOS-4431',
    },
    <String, dynamic>{
      'id': 'TSK-8774',
      'title': 'Escort persons with disability to shelter',
      'description':
          'Two residents required wheelchair transport to the evacuation centre.',
      'type': 'rescue',
      'priority': 'high',
      'status': 'completed',
      'locationLabel': 'Purok 4, Sitio Bagong Silang',
      'distanceMetres': 480.0,
      'minutesAgo': 1420,
      'peopleWaiting': 0,
      'teamName': 'Volunteer Team Alpha',
      'linkedSosId': 'SOS-4440',
    },
  ];

  static List<Assignment> get all => assignmentsJson
      .map((Map<String, dynamic> json) => Assignment.fromJson(json))
      .toList();

  /// Quick report presets used by the volunteer dashboard.
  static const List<String> quickReports = <String>[
    'Area cleared — no casualties',
    'Additional responders needed',
    'Route impassable',
    'Supplies delivered',
    'Casualty transported to centre',
  ];
}
