import '../../../core/constants/app_enums.dart';

/// A unit of data transmitted across the SUMPAY network.
///
/// This is the persistent, transport-level representation of traffic — every
/// SOS beacon, chat message, broadcast relay and headcount report is ultimately
/// carried as one or more [Packet]s. The lighter-weight `PacketLogEntry` used by
/// the diagnostics screen is a view over the same concept; [Packet] is the model
/// the data layer stores and, in a later phase, the communication stack emits.
class Packet {
  const Packet({
    required this.id,
    required this.description,
    required this.transport,
    required this.status,
    required this.createdAt,
    required this.sizeBytes,
    required this.hopCount,
    this.sourceId,
    this.destinationId,
  });

  final String id;
  final String description;
  final LinkMode transport;
  final DeliveryStatus status;
  final DateTime createdAt;
  final int sizeBytes;
  final int hopCount;
  final String? sourceId;
  final String? destinationId;

  Packet copyWith({
    LinkMode? transport,
    DeliveryStatus? status,
    int? hopCount,
    String? sourceId,
    String? destinationId,
  }) {
    return Packet(
      id: id,
      description: description,
      transport: transport ?? this.transport,
      status: status ?? this.status,
      createdAt: createdAt,
      sizeBytes: sizeBytes,
      hopCount: hopCount ?? this.hopCount,
      sourceId: sourceId ?? this.sourceId,
      destinationId: destinationId ?? this.destinationId,
    );
  }

  factory Packet.fromJson(Map<String, dynamic> json) {
    return Packet(
      id: json['id'] as String,
      description: json['description'] as String,
      transport: LinkMode.values.byName(json['transport'] as String),
      status: DeliveryStatus.values.byName(json['status'] as String),
      createdAt: json['minutesAgo'] != null
          ? DateTime.now().subtract(Duration(minutes: json['minutesAgo'] as int))
          : DateTime.parse(json['createdAt'] as String),
      sizeBytes: json['sizeBytes'] as int,
      hopCount: json['hopCount'] as int? ?? 0,
      sourceId: json['sourceId'] as String?,
      destinationId: json['destinationId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'description': description,
        'transport': transport.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'sizeBytes': sizeBytes,
        'hopCount': hopCount,
        'sourceId': sourceId,
        'destinationId': destinationId,
      };

  /// Maps to a SQLite row for the `packets` table.
  Map<String, Object?> toDbRow() => <String, Object?>{
        'id': id,
        'description': description,
        'transport': transport.name,
        'status': status.name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'size_bytes': sizeBytes,
        'hop_count': hopCount,
        'source_id': sourceId,
        'destination_id': destinationId,
      };

  /// Reconstructs a [Packet] from a SQLite row.
  factory Packet.fromDbRow(Map<String, Object?> row) {
    return Packet(
      id: row['id'] as String,
      description: row['description'] as String,
      transport: LinkMode.values.byName(row['transport'] as String),
      status: DeliveryStatus.values.byName(row['status'] as String),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      sizeBytes: row['size_bytes'] as int,
      hopCount: row['hop_count'] as int,
      sourceId: row['source_id'] as String?,
      destinationId: row['destination_id'] as String?,
    );
  }
}
