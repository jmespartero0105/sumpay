import 'dart:convert';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/uuid.dart';

/// Special destination meaning "every node" — used for broadcast-style traffic
/// that should flood the whole mesh rather than target one device.
const String kMeshBroadcastDestination = 'broadcast';

/// A self-contained unit of data routed across the multi-hop mesh.
///
/// Every packet carries its own routing header so any relay can decide what to
/// do with it using only the packet itself — no shared routing tables required.
/// The [payload] is an opaque string (the messaging layer puts an encoded
/// [MessagePacket] JSON in here), keeping the mesh layer agnostic to what it
/// carries.
class MeshPacket {
  const MeshPacket({
    required this.uuid,
    required this.senderId,
    required this.destinationId,
    required this.hopCount,
    required this.ttl,
    required this.priority,
    required this.timestamp,
    required this.payload,
    required this.transport,
    required this.path,
  });

  /// Wire protocol version for the mesh header.
  static const int protocolVersion = 1;

  /// Default number of hops a packet may travel before being dropped.
  static const int defaultTtl = 8;

  /// Globally unique id for this packet, used for duplicate detection.
  final String uuid;

  /// Originating device id.
  final String senderId;

  /// Target device id, or [kMeshBroadcastDestination] for flood traffic.
  final String destinationId;

  /// Number of hops the packet has already travelled (0 at the origin).
  final int hopCount;

  /// Remaining time-to-live; decremented at each relay, dropped at 0.
  final int ttl;

  final PriorityLevel priority;

  /// When the packet was first created at the origin.
  final DateTime timestamp;

  /// Opaque application payload (an encoded [MessagePacket] for chat).
  final String payload;

  final LinkMode transport;

  /// Ordered list of device ids the packet has passed through, origin first.
  /// Used to display the packet path and to avoid immediately looping back.
  final List<String> path;

  /// True once this packet has been forwarded by at least one relay.
  bool get wasRelayed => hopCount > 0;

  /// Whether this packet is addressed to the whole mesh.
  bool get isBroadcast => destinationId == kMeshBroadcastDestination;

  /// Creates a fresh packet at the origin device.
  factory MeshPacket.origin({
    required String senderId,
    required String destinationId,
    required String payload,
    PriorityLevel priority = PriorityLevel.normal,
    int ttl = defaultTtl,
    LinkMode transport = LinkMode.mesh,
  }) {
    return MeshPacket(
      uuid: Uuid.v4(),
      senderId: senderId,
      destinationId: destinationId,
      hopCount: 0,
      ttl: ttl,
      priority: priority,
      timestamp: DateTime.now(),
      payload: payload,
      transport: transport,
      path: <String>[senderId],
    );
  }

  /// Produces the next-hop copy of this packet for forwarding through
  /// [relayId]: hop count up, TTL down, relay appended to the path.
  MeshPacket relayedThrough(String relayId) {
    return MeshPacket(
      uuid: uuid,
      senderId: senderId,
      destinationId: destinationId,
      hopCount: hopCount + 1,
      ttl: ttl - 1,
      priority: priority,
      timestamp: timestamp,
      payload: payload,
      transport: transport,
      path: <String>[...path, relayId],
    );
  }

  /// Whether this packet may still be forwarded (has hops left to give).
  bool get canForward => ttl > 1;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': protocolVersion,
        'uuid': uuid,
        'senderId': senderId,
        'destinationId': destinationId,
        'hopCount': hopCount,
        'ttl': ttl,
        'priority': priority.name,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'payload': payload,
        'transport': transport.name,
        'path': path,
      };

  factory MeshPacket.fromJson(Map<String, dynamic> json) {
    return MeshPacket(
      uuid: json['uuid'] as String,
      senderId: json['senderId'] as String,
      destinationId: json['destinationId'] as String,
      hopCount: json['hopCount'] as int,
      ttl: json['ttl'] as int,
      priority: PriorityLevel.values.byName(json['priority'] as String),
      timestamp:
          DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      payload: json['payload'] as String,
      transport: LinkMode.values.byName(json['transport'] as String),
      path: (json['path'] as List<dynamic>).cast<String>(),
    );
  }

  /// Encodes to UTF-8 bytes for transmission over the transport.
  List<int> encode() => utf8.encode(jsonEncode(toJson()));

  /// Decodes received bytes into a [MeshPacket], or `null` if malformed.
  static MeshPacket? decode(List<int> bytes) {
    try {
      final Object? decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) {
        return MeshPacket.fromJson(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
