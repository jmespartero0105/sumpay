import 'dart:convert';

import '../../../core/constants/app_enums.dart';
import 'broadcast_models.dart';

/// A broadcast (evacuation notice / barangay emergency alert) serialized for
/// transmission across the mesh + internet, mirroring how [SosPacket] carries
/// SOS data. Officials originate these; every device that receives one surfaces
/// it in the broadcast feed and relays it onward.
class BroadcastPacket {
  const BroadcastPacket({
    required this.id,
    required this.title,
    required this.body,
    required this.severity,
    required this.issuedBy,
    required this.issuedAt,
    this.areas = const <String>[],
  });

  final String id;
  final String title;
  final String body;
  final BroadcastSeverity severity;
  final String issuedBy;
  final DateTime issuedAt;
  final List<String> areas;

  /// Priority used for mesh routing: alerts jump the queue.
  PriorityLevel get priority => switch (severity) {
        BroadcastSeverity.alert => PriorityLevel.critical,
        BroadcastSeverity.warning => PriorityLevel.high,
        BroadcastSeverity.advisory => PriorityLevel.normal,
      };

  BroadcastMessage toMessage() => BroadcastMessage(
        id: id,
        title: title,
        body: body,
        severity: severity,
        issuedBy: issuedBy,
        issuedAt: issuedAt,
        reach: 0,
        acknowledged: 0,
        transport: LinkMode.mesh,
        areas: areas,
        isPinned: severity == BroadcastSeverity.alert,
      );

  factory BroadcastPacket.fromMessage(BroadcastMessage m) => BroadcastPacket(
        id: m.id,
        title: m.title,
        body: m.body,
        severity: m.severity,
        issuedBy: m.issuedBy,
        issuedAt: m.issuedAt,
        areas: m.areas,
      );

  /// Marker field distinguishing a broadcast payload from SOS/chat payloads.
  static const String _marker = 'brd';

  String encode() => jsonEncode(<String, dynamic>{
        't': _marker,
        'id': id,
        'title': title,
        'body': body,
        'sev': severity.name,
        'by': issuedBy,
        'ts': issuedAt.millisecondsSinceEpoch,
        'areas': areas,
      });

  /// Parses a broadcast payload, or returns null if it is not one.
  static BroadcastPacket? tryDecode(String payload) {
    try {
      final Map<String, dynamic> j =
          jsonDecode(payload) as Map<String, dynamic>;
      if (j['t'] != _marker || j['id'] is! String) return null;
      return BroadcastPacket(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        severity:
            BroadcastSeverity.values.byName(j['sev'] as String? ?? 'advisory'),
        issuedBy: j['by'] as String? ?? 'Barangay',
        issuedAt: DateTime.fromMillisecondsSinceEpoch(
            (j['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
        areas: (j['areas'] as List<dynamic>?)
                ?.map((dynamic e) => e as String)
                .toList() ??
            const <String>[],
      );
    } catch (_) {
      return null;
    }
  }
}

/// A lightweight delivery acknowledgement for a broadcast: sent automatically
/// by every device that receives a [BroadcastPacket], back to the network, so
/// the issuing official can count how many devices the broadcast reached.
class BroadcastAckPacket {
  const BroadcastAckPacket({
    required this.broadcastId,
    required this.deviceId,
  });

  final String broadcastId;
  final String deviceId;

  static const String _marker = 'brdack';

  String encode() => jsonEncode(<String, dynamic>{
        't': _marker,
        'id': broadcastId,
        'dev': deviceId,
      });

  /// Parses a broadcast-ack payload, or returns null if it is not one.
  static BroadcastAckPacket? tryDecode(String payload) {
    try {
      final Map<String, dynamic> j =
          jsonDecode(payload) as Map<String, dynamic>;
      if (j['t'] != _marker || j['id'] is! String) return null;
      return BroadcastAckPacket(
        broadcastId: j['id'] as String,
        deviceId: j['dev'] as String? ?? 'unknown',
      );
    } catch (_) {
      return null;
    }
  }
}
