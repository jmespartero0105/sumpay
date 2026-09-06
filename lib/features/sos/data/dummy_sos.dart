import '../models/sos_request.dart';

/// Historical and active SOS records used across dashboards and history.
class DummySos {
  const DummySos._();

  static const List<Map<String, dynamic>> requestsJson = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'SOS-4471',
      'type': 'medical',
      'priority': 'critical',
      'description':
          'Elderly resident collapsed and is unresponsive. Needs immediate medical assistance.',
      'locationLabel': 'Purok 4, Sitio Bagong Silang',
      'latitude': 9.30684,
      'longitude': 123.30193,
      'minutesAgo': 14,
      'status': 'responding',
      'delivery': 'delivered',
      'hopCount': 2,
      'peopleAffected': 1,
      'requesterName': 'Maria Liza Fernandez',
      'respondingUnit': 'Rescue Team Bravo',
    },
    <String, dynamic>{
      'id': 'SOS-4468',
      'type': 'rescue',
      'priority': 'critical',
      'description':
          'Family of six trapped on the second floor. Floodwater rising rapidly.',
      'locationLabel': 'Purok 2, Riverside',
      'latitude': 9.30401,
      'longitude': 123.29877,
      'minutesAgo': 38,
      'status': 'active',
      'delivery': 'relayed',
      'hopCount': 3,
      'peopleAffected': 6,
      'requesterName': 'Danilo Ocampo',
      'respondingUnit': null,
    },
    <String, dynamic>{
      'id': 'SOS-4462',
      'type': 'supply',
      'priority': 'normal',
      'description':
          'Evacuation centre running low on drinking water and infant formula.',
      'locationLabel': 'Talay Elementary School',
      'latitude': 9.30912,
      'longitude': 123.30455,
      'minutesAgo': 96,
      'status': 'responding',
      'delivery': 'delivered',
      'hopCount': 1,
      'peopleAffected': 120,
      'requesterName': 'Centre Marshal',
      'respondingUnit': 'Logistics Team',
    },
    <String, dynamic>{
      'id': 'SOS-4455',
      'type': 'fire',
      'priority': 'high',
      'description': 'Kitchen fire contained by neighbours. Smoke inhalation checked.',
      'locationLabel': 'Purok 5, Mabini Street',
      'latitude': 9.30215,
      'longitude': 123.30021,
      'minutesAgo': 320,
      'status': 'resolved',
      'delivery': 'delivered',
      'hopCount': 2,
      'peopleAffected': 3,
      'requesterName': 'Maria Liza Fernandez',
      'respondingUnit': 'BFP Dumaguete',
    },
    <String, dynamic>{
      'id': 'SOS-4440',
      'type': 'rescue',
      'priority': 'high',
      'description':
          'Requested transport assistance for two persons with disability.',
      'locationLabel': 'Purok 4, Sitio Bagong Silang',
      'latitude': 9.30699,
      'longitude': 123.30188,
      'minutesAgo': 1450,
      'status': 'resolved',
      'delivery': 'delivered',
      'hopCount': 2,
      'peopleAffected': 2,
      'requesterName': 'Maria Liza Fernandez',
      'respondingUnit': 'Volunteer Team Alpha',
    },
    <String, dynamic>{
      'id': 'SOS-4431',
      'type': 'custom',
      'priority': 'low',
      'description': 'Reported a fallen electric post blocking the access road.',
      'locationLabel': 'Purok 6, Shoreline Road',
      'latitude': 9.29988,
      'longitude': 123.30512,
      'minutesAgo': 2880,
      'status': 'resolved',
      'delivery': 'delivered',
      'hopCount': 3,
      'peopleAffected': 0,
      'requesterName': 'Maria Liza Fernandez',
      'respondingUnit': 'NORECO II',
    },
    <String, dynamic>{
      'id': 'SOS-4419',
      'type': 'medical',
      'priority': 'normal',
      'description': 'Requested maintenance medicine refill for hypertension.',
      'locationLabel': 'Purok 4, Sitio Bagong Silang',
      'latitude': 9.30684,
      'longitude': 123.30193,
      'minutesAgo': 5760,
      'status': 'cancelled',
      'delivery': 'failed',
      'hopCount': 0,
      'peopleAffected': 1,
      'requesterName': 'Maria Liza Fernandez',
      'respondingUnit': null,
    },
  ];

  static List<SosRequest> get all => requestsJson
      .map((Map<String, dynamic> json) => SosRequest.fromJson(json))
      .toList();

  /// Quick suggestions offered on the SOS description field.
  static const List<String> descriptionSuggestions = <String>[
    'Need immediate medical assistance',
    'Trapped and cannot evacuate',
    'Requesting drinking water and food',
    'Structure damaged and unsafe',
    'Person missing since the storm',
  ];
}
