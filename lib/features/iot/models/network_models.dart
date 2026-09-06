import '../../../core/constants/app_enums.dart';

/// An ESP32 gateway or LoRa repeater participating in the network.
class MeshNode {
  const MeshNode({
    required this.id,
    required this.label,
    required this.location,
    required this.status,
    required this.rssi,
    required this.batteryPercent,
    required this.hopCount,
    required this.connectedClients,
    required this.lastSeen,
    required this.isGateway,
    required this.firmware,
  });

  final String id;
  final String label;
  final String location;
  final NodeStatus status;
  final int rssi;
  final double batteryPercent;
  final int hopCount;
  final int connectedClients;
  final DateTime lastSeen;
  final bool isGateway;
  final String firmware;

  factory MeshNode.fromJson(Map<String, dynamic> json) {
    return MeshNode(
      id: json['id'] as String,
      label: json['label'] as String,
      location: json['location'] as String,
      status: NodeStatus.values.byName(json['status'] as String),
      rssi: json['rssi'] as int,
      batteryPercent: (json['batteryPercent'] as num).toDouble(),
      hopCount: json['hopCount'] as int,
      connectedClients: json['connectedClients'] as int,
      lastSeen: DateTime.now().subtract(
        Duration(minutes: json['lastSeenMinutesAgo'] as int),
      ),
      isGateway: json['isGateway'] as bool,
      firmware: json['firmware'] as String,
    );
  }
}

/// Aggregate snapshot of the local network as seen by this handset.
class NetworkStatus {
  const NetworkStatus({
    required this.linkMode,
    required this.gatewayId,
    required this.gatewayLabel,
    required this.rssi,
    required this.hopCount,
    required this.meshActive,
    required this.meshPeers,
    required this.loRaActive,
    required this.internetAvailable,
    required this.queuedPackets,
    required this.lastSync,
    required this.linkQualityPercent,
  });

  final LinkMode linkMode;
  final String gatewayId;
  final String gatewayLabel;
  final int rssi;
  final int hopCount;
  final bool meshActive;
  final int meshPeers;
  final bool loRaActive;
  final bool internetAvailable;
  final int queuedPackets;
  final DateTime lastSync;
  final double linkQualityPercent;

  bool get isOffline => linkMode == LinkMode.offline;

  String get qualityLabel {
    if (linkQualityPercent >= 80) return 'Excellent';
    if (linkQualityPercent >= 60) return 'Good';
    if (linkQualityPercent >= 35) return 'Fair';
    return 'Weak';
  }

  NetworkStatus copyWith({
    LinkMode? linkMode,
    String? gatewayId,
    String? gatewayLabel,
    int? rssi,
    int? hopCount,
    bool? meshActive,
    int? meshPeers,
    bool? loRaActive,
    bool? internetAvailable,
    int? queuedPackets,
    DateTime? lastSync,
    double? linkQualityPercent,
  }) {
    return NetworkStatus(
      linkMode: linkMode ?? this.linkMode,
      gatewayId: gatewayId ?? this.gatewayId,
      gatewayLabel: gatewayLabel ?? this.gatewayLabel,
      rssi: rssi ?? this.rssi,
      hopCount: hopCount ?? this.hopCount,
      meshActive: meshActive ?? this.meshActive,
      meshPeers: meshPeers ?? this.meshPeers,
      loRaActive: loRaActive ?? this.loRaActive,
      internetAvailable: internetAvailable ?? this.internetAvailable,
      queuedPackets: queuedPackets ?? this.queuedPackets,
      lastSync: lastSync ?? this.lastSync,
      linkQualityPercent: linkQualityPercent ?? this.linkQualityPercent,
    );
  }

  factory NetworkStatus.fromJson(Map<String, dynamic> json) {
    return NetworkStatus(
      linkMode: LinkMode.values.byName(json['linkMode'] as String),
      gatewayId: json['gatewayId'] as String,
      gatewayLabel: json['gatewayLabel'] as String,
      rssi: json['rssi'] as int,
      hopCount: json['hopCount'] as int,
      meshActive: json['meshActive'] as bool,
      meshPeers: json['meshPeers'] as int,
      loRaActive: json['loRaActive'] as bool,
      internetAvailable: json['internetAvailable'] as bool,
      queuedPackets: json['queuedPackets'] as int,
      lastSync: DateTime.now().subtract(
        Duration(minutes: json['lastSyncMinutesAgo'] as int),
      ),
      linkQualityPercent: (json['linkQualityPercent'] as num).toDouble(),
    );
  }
}

/// A single entry in the transmission diagnostics log.
class PacketLogEntry {
  const PacketLogEntry({
    required this.id,
    required this.description,
    required this.transport,
    required this.status,
    required this.timestamp,
    required this.sizeBytes,
  });

  final String id;
  final String description;
  final LinkMode transport;
  final DeliveryStatus status;
  final DateTime timestamp;
  final int sizeBytes;

  factory PacketLogEntry.fromJson(Map<String, dynamic> json) {
    return PacketLogEntry(
      id: json['id'] as String,
      description: json['description'] as String,
      transport: LinkMode.values.byName(json['transport'] as String),
      status: DeliveryStatus.values.byName(json['status'] as String),
      timestamp: DateTime.now().subtract(
        Duration(minutes: json['minutesAgo'] as int),
      ),
      sizeBytes: json['sizeBytes'] as int,
    );
  }
}
