import '../models/network_models.dart';

/// Static network telemetry standing in for the LoRa / ESP32 bridge.
class DummyNetwork {
  const DummyNetwork._();

  static const Map<String, dynamic> statusJson = <String, dynamic>{
    'linkMode': 'loRa',
    'gatewayId': 'ESP32-GW-04',
    'gatewayLabel': 'Talay Elementary School',
    'rssi': -78,
    'hopCount': 2,
    'meshActive': true,
    'meshPeers': 3,
    'loRaActive': true,
    'internetAvailable': false,
    'queuedPackets': 2,
    'lastSyncMinutesAgo': 46,
    'linkQualityPercent': 82.0,
  };

  static const List<Map<String, dynamic>> nodesJson = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'ESP32-GW-04',
      'label': 'Talay Elementary School',
      'location': 'Purok 4 — Evacuation Centre',
      'status': 'online',
      'rssi': -78,
      'batteryPercent': 88.0,
      'hopCount': 1,
      'connectedClients': 24,
      'lastSeenMinutesAgo': 0,
      'isGateway': true,
      'firmware': 'v2.4.1',
    },
    <String, dynamic>{
      'id': 'LORA-RPT-11',
      'label': 'Riverside Repeater',
      'location': 'Purok 2 — Bridge Approach',
      'status': 'online',
      'rssi': -91,
      'batteryPercent': 64.0,
      'hopCount': 2,
      'connectedClients': 11,
      'lastSeenMinutesAgo': 1,
      'isGateway': false,
      'firmware': 'v2.4.1',
    },
    <String, dynamic>{
      'id': 'ESP32-GW-07',
      'label': 'Barangay Hall',
      'location': 'Barangay Talay Hall',
      'status': 'online',
      'rssi': -66,
      'batteryPercent': 100.0,
      'hopCount': 1,
      'connectedClients': 39,
      'lastSeenMinutesAgo': 0,
      'isGateway': true,
      'firmware': 'v2.5.0',
    },
    <String, dynamic>{
      'id': 'LORA-RPT-15',
      'label': 'Upland Repeater',
      'location': 'Sitio Bagong Silang Ridge',
      'status': 'degraded',
      'rssi': -108,
      'batteryPercent': 27.0,
      'hopCount': 3,
      'connectedClients': 4,
      'lastSeenMinutesAgo': 8,
      'isGateway': false,
      'firmware': 'v2.3.9',
    },
    <String, dynamic>{
      'id': 'ESP32-GW-09',
      'label': 'Coastal Gateway',
      'location': 'Purok 6 — Shoreline Outpost',
      'status': 'offline',
      'rssi': -125,
      'batteryPercent': 6.0,
      'hopCount': 4,
      'connectedClients': 0,
      'lastSeenMinutesAgo': 132,
      'isGateway': true,
      'firmware': 'v2.3.9',
    },
  ];

  static const List<Map<String, dynamic>> packetLogJson = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'PKT-9921',
      'description': 'SOS beacon — Medical, Purok 4',
      'transport': 'loRa',
      'status': 'delivered',
      'minutesAgo': 12,
      'sizeBytes': 128,
    },
    <String, dynamic>{
      'id': 'PKT-9920',
      'description': 'Broadcast relay — Evacuation advisory',
      'transport': 'loRa',
      'status': 'delivered',
      'minutesAgo': 26,
      'sizeBytes': 214,
    },
    <String, dynamic>{
      'id': 'PKT-9918',
      'description': 'Direct message to the barangay',
      'transport': 'mesh',
      'status': 'relayed',
      'minutesAgo': 41,
      'sizeBytes': 96,
    },
    <String, dynamic>{
      'id': 'PKT-9915',
      'description': 'Household headcount report',
      'transport': 'offline',
      'status': 'queued',
      'minutesAgo': 58,
      'sizeBytes': 74,
    },
    <String, dynamic>{
      'id': 'PKT-9911',
      'description': 'Cloud sync — history backlog',
      'transport': 'internet',
      'status': 'failed',
      'minutesAgo': 96,
      'sizeBytes': 1840,
    },
  ];

  static NetworkStatus get status => NetworkStatus.fromJson(statusJson);

  static List<MeshNode> get nodes => nodesJson
      .map((Map<String, dynamic> json) => MeshNode.fromJson(json))
      .toList();

  static List<PacketLogEntry> get packetLog => packetLogJson
      .map((Map<String, dynamic> json) => PacketLogEntry.fromJson(json))
      .toList();
}
