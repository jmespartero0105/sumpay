import 'dart:convert';

import '../../../core/constants/app_enums.dart';

/// Parses a comma-separated list of [EmergencyType] names from a packet,
/// skipping unknown/blank entries.
List<EmergencyType> _decodePacketTypes(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <EmergencyType>[];
  final Map<String, EmergencyType> byName = EmergencyType.values.asNameMap();
  return raw
      .split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty && byName.containsKey(s))
      .map((String s) => byName[s]!)
      .toList();
}

/// A status update for a resident's own SOS, surfaced as an in-app notification.
class SosStatusUpdate {
  const SosStatusUpdate({
    required this.sosId,
    required this.status,
    required this.at,
    this.actorName,
  });

  final String sosId;
  final SosStatus status;
  final DateTime at;
  final String? actorName;

  String get message {
    final String who = actorName != null ? ' by $actorName' : '';
    return switch (status) {
      SosStatus.responderAccepted => 'Your SOS was accepted$who.',
      SosStatus.rejected =>
        'There are no available responders right now. Your SOS is still active '
            'and will reach the next responder who comes online.',
      SosStatus.responderEnRoute => 'A responder is on the way$who.',
      SosStatus.arrived => 'A responder has arrived$who.',
      SosStatus.resolved => 'Your SOS has been resolved$who.',
      SosStatus.cancelled => 'This SOS was cancelled by the resident.',
      SosStatus.delivered => 'Your SOS was delivered to responders.',
      _ => 'Your SOS status: ${status.label}.',
    };
  }
}

/// Lifecycle status of an SOS as it travels and is handled across the mesh.
///
/// Sent -> Relayed -> Delivered are transport milestones; Responder Accepted and
/// Responder En Route come from a responder's acknowledgements; Resolved closes
/// the incident.
enum SosStatus {
  sent('Sent'),
  relayed('Relayed'),
  delivered('Delivered'),
  responderAccepted('Responder Accepted'),
  rejected('Rejected'),
  responderEnRoute('Responder En Route'),
  arrived('Arrived'),
  resolved('Resolved'),
  cancelled('Cancelled');

  const SosStatus(this.label);

  final String label;

  bool get isTerminal =>
      this == SosStatus.resolved ||
      this == SosStatus.rejected ||
      this == SosStatus.cancelled;
}

/// Kinds of SOS-related control packets exchanged over the mesh.
enum SosPacketKind {
  /// The original emergency alert from a resident.
  alert,

  /// Delivery acknowledgement from a command node / official device.
  deliveryAck,

  /// A responder (volunteer) accepted the emergency.
  responderAck,

  /// An official acknowledged / is coordinating the emergency.
  officialAck,

  /// A status update (e.g. en route, resolved).
  statusUpdate,
}

/// The application-level SOS payload carried inside a mesh packet.
///
/// The transport fields required by the spec map to the enclosing [MeshPacket]:
/// Packet ID = mesh uuid, Hop Count and TTL = mesh hop/ttl, Priority = mesh
/// priority, Timestamp = mesh timestamp. The resident-facing and lifecycle
/// fields (Resident ID/Name, Emergency Type, Current Status) live here in the
/// payload.
class SosPacket {
  const SosPacket({
    required this.kind,
    required this.sosId,
    required this.residentId,
    required this.residentName,
    required this.emergencyType,
    this.additionalTypes = const <EmergencyType>[],
    required this.priority,
    required this.status,
    required this.createdAt,
    this.note,
    this.locationLabel,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.actorName,
    this.actorId,
    this.actorRole,
    this.responseId,
    this.actorLat,
    this.actorLng,
  });

  final SosPacketKind kind;

  /// Stable SOS id, shared by the alert and all its acknowledgements.
  final String sosId;
  final String residentId;
  final String residentName;
  final EmergencyType emergencyType;

  /// Extra emergency categories chosen for this SOS (beyond [emergencyType]),
  /// transmitted so monitoring roles see the full list.
  final List<EmergencyType> additionalTypes;

  /// A readable summary of all categories, e.g. "Medical + Fire + Flood".
  /// Falls back to just the primary type when there are no extras.
  String get typesSummary => additionalTypes.isEmpty
      ? emergencyType.label
      : <String>[emergencyType.label, ...additionalTypes.map((EmergencyType t) => t.label)]
          .join(' + ');
  final PriorityLevel priority;
  final SosStatus status;
  final DateTime createdAt;

  /// Optional free-text note (e.g. resident description, responder message).
  final String? note;

  /// Human-readable address of the SOS location (reverse-geocoded), so logs and
  /// the map show the exact place, not only coordinates.
  final String? locationLabel;

  final double? latitude;
  final double? longitude;
  final double? accuracy;

  /// Who produced an acknowledgement (responder/official name), when relevant.
  final String? actorName;

  /// The acknowledging responder's account id, so multiple responders can be
  /// tracked per SOS (keyed by id). Optional so older packets still decode.
  final String? actorId;

  /// The acknowledging responder's role (volunteer/official), for the resident
  /// response card. Optional so older packets still decode.
  final UserRole? actorRole;

  /// A dedicated id for a responder response event, associating it with this
  /// SOS. Optional; present on responder acknowledgements.
  final String? responseId;

  /// The responder's location at the time of the response, when available.
  final double? actorLat;
  final double? actorLng;

  SosPacket copyWith({
    SosPacketKind? kind,
    SosStatus? status,
    String? actorName,
    String? actorId,
    String? note,
    String? locationLabel,
    UserRole? actorRole,
    String? responseId,
    double? actorLat,
    double? actorLng,
  }) {
    return SosPacket(
      kind: kind ?? this.kind,
      sosId: sosId,
      residentId: residentId,
      residentName: residentName,
      emergencyType: emergencyType,
      additionalTypes: additionalTypes,
      priority: priority,
      status: status ?? this.status,
      createdAt: createdAt,
      note: note ?? this.note,
      locationLabel: locationLabel ?? this.locationLabel,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      actorName: actorName ?? this.actorName,
      actorId: actorId ?? this.actorId,
      actorRole: actorRole ?? this.actorRole,
      responseId: responseId ?? this.responseId,
      actorLat: actorLat ?? this.actorLat,
      actorLng: actorLng ?? this.actorLng,
    );
  }

  String encode() => jsonEncode(<String, dynamic>{
        'k': kind.name,
        'sos': sosId,
        'rid': residentId,
        'rname': residentName,
        'etype': emergencyType.name,
        if (additionalTypes.isNotEmpty)
          'aetypes': additionalTypes.map((EmergencyType t) => t.name).join(','),
        'prio': priority.name,
        'st': status.name,
        'ts': createdAt.millisecondsSinceEpoch,
        if (note != null) 'note': note,
        if (locationLabel != null) 'loc': locationLabel,
        if (latitude != null) 'lat': latitude,
        if (longitude != null) 'lng': longitude,
        if (accuracy != null) 'acc': accuracy,
        if (actorName != null) 'actor': actorName,
        if (actorId != null) 'aid': actorId,
        if (actorRole != null) 'arole': actorRole!.name,
        if (responseId != null) 'respid': responseId,
        if (actorLat != null) 'alat': actorLat,
        if (actorLng != null) 'alng': actorLng,
      });

  /// Parses an SOS payload, or returns null if it is not a valid SOS packet.
  static SosPacket? tryDecode(String payload) {
    try {
      final Map<String, dynamic> j =
          jsonDecode(payload) as Map<String, dynamic>;
      if (j['sos'] is! String || j['k'] is! String) return null;
      return SosPacket(
        kind: SosPacketKind.values.byName(j['k'] as String),
        sosId: j['sos'] as String,
        residentId: j['rid'] as String? ?? 'unknown',
        residentName: j['rname'] as String? ?? 'Unknown resident',
        emergencyType:
            EmergencyType.values.byName(j['etype'] as String? ?? 'custom'),
        additionalTypes: _decodePacketTypes(j['aetypes'] as String?),
        priority: PriorityLevel.values.byName(j['prio'] as String? ?? 'high'),
        status: SosStatus.values.byName(j['st'] as String? ?? 'sent'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (j['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
        note: j['note'] as String?,
        locationLabel: j['loc'] as String?,
        latitude: (j['lat'] as num?)?.toDouble(),
        longitude: (j['lng'] as num?)?.toDouble(),
        accuracy: (j['acc'] as num?)?.toDouble(),
        actorName: j['actor'] as String?,
        actorId: j['aid'] as String?,
        actorRole: j['arole'] is String
            ? UserRole.fromName(j['arole'] as String)
            : null,
        responseId: j['respid'] as String?,
        actorLat: (j['alat'] as num?)?.toDouble(),
        actorLng: (j['alng'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
