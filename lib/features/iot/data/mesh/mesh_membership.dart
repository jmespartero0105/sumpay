import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Constants that define SUMPAY mesh membership.
///
/// These identify the SUMPAY network so that only genuine SUMPAY devices join.
/// The service id is the Nearby Connections service (the first gate: devices
/// advertising a different service are never even discovered). The mesh id and
/// membership token are exchanged and verified in the handshake (the second
/// gate).
class MeshMembership {
  const MeshMembership._();

  /// Nearby Connections service id. Only devices advertising this exact id are
  /// discoverable as SUMPAY peers.
  static const String serviceId = 'com.sumpay.app';

  /// Logical mesh identifier. Both peers must present the same mesh id, so a
  /// device configured for a different SUMPAY mesh is rejected.
  static const String meshId = 'sumpay-mesh-ph';

  /// Shared membership token proving the peer is running SUMPAY.
  ///
  /// This is a shared secret, not a cryptographic attestation: it stops other
  /// applications and casual impostors, but a determined attacker who extracted
  /// it from the app could replay it. Unforgeable attestation would require a
  /// signed key exchange, which is future work.
  static const String membershipToken = 'SUMPAY-MESH-7F3A-2C9E';

  /// Handshake protocol version. Peers must be compatible (see
  /// [MeshHandshake.isVersionCompatible]).
  static const int protocolVersion = 1;

  /// The lowest protocol version this build will still accept, so minor version
  /// bumps do not immediately partition the mesh.
  static const int minCompatibleVersion = 1;
}

/// The membership handshake a device presents when a link is established.
///
/// Carries everything needed to verify the peer is a genuine, compatible SUMPAY
/// device: the membership token (application verification), the protocol version
/// (version checking), the mesh id, and the sender's device id.
class MeshHandshake {
  const MeshHandshake({
    required this.token,
    required this.meshId,
    required this.protocolVersion,
    required this.deviceId,
    required this.appVersion,
  });

  final String token;
  final String meshId;
  final int protocolVersion;
  final String deviceId;
  final String appVersion;

  /// Builds the local device's handshake.
  factory MeshHandshake.local({
    required String deviceId,
    required String appVersion,
  }) {
    return MeshHandshake(
      token: MeshMembership.membershipToken,
      meshId: MeshMembership.meshId,
      protocolVersion: MeshMembership.protocolVersion,
      deviceId: deviceId,
      appVersion: appVersion,
    );
  }

  /// Whether the peer's protocol version is compatible with this build.
  bool get isVersionCompatible =>
      protocolVersion >= MeshMembership.minCompatibleVersion &&
      protocolVersion <= MeshMembership.protocolVersion;

  String encode() => jsonEncode(<String, dynamic>{
        't': token,
        'm': meshId,
        'v': protocolVersion,
        'd': deviceId,
        'a': appVersion,
      });

  /// Parses a handshake, or returns null if the payload is malformed.
  static MeshHandshake? tryDecode(String payload) {
    try {
      final Map<String, dynamic> json =
          jsonDecode(payload) as Map<String, dynamic>;
      final Object? token = json['t'];
      final Object? meshId = json['m'];
      final Object? version = json['v'];
      final Object? deviceId = json['d'];
      if (token is! String ||
          meshId is! String ||
          version is! int ||
          deviceId is! String) {
        return null;
      }
      return MeshHandshake(
        token: token,
        meshId: meshId,
        protocolVersion: version,
        deviceId: deviceId,
        appVersion: json['a'] is String ? json['a'] as String : 'unknown',
      );
    } catch (_) {
      return null;
    }
  }
}

/// Why a peer was refused mesh membership.
enum MembershipRejection {
  /// Payload could not be parsed as a handshake.
  invalidHandshake,

  /// Wrong or missing membership token (an unknown/foreign application).
  unknownApplication,

  /// Handshake was for a different mesh id.
  wrongMesh,

  /// Protocol version is not compatible.
  incompatibleVersion,

  /// This device is already a member via another endpoint (duplicate).
  duplicateDevice,
}

extension MembershipRejectionInfo on MembershipRejection {
  String get reason => switch (this) {
        MembershipRejection.invalidHandshake => 'invalid handshake packet',
        MembershipRejection.unknownApplication => 'unknown application',
        MembershipRejection.wrongMesh => 'different mesh id',
        MembershipRejection.incompatibleVersion => 'incompatible version',
        MembershipRejection.duplicateDevice => 'duplicate device',
      };
}

/// Outcome of verifying a peer's handshake.
class MembershipResult {
  const MembershipResult._({this.handshake, this.rejection});

  factory MembershipResult.accepted(MeshHandshake handshake) =>
      MembershipResult._(handshake: handshake);

  factory MembershipResult.rejected(MembershipRejection rejection) =>
      MembershipResult._(rejection: rejection);

  final MeshHandshake? handshake;
  final MembershipRejection? rejection;

  bool get isAccepted => handshake != null;
}

/// Verifies membership handshakes and admits only genuine SUMPAY devices.
///
/// Rejections are surfaced through debug logs only, as required; there is no
/// user-facing UI for rejected devices.
class MembershipVerifier {
  MembershipVerifier();

  /// Device ids currently admitted, to detect duplicates.
  final Set<String> _admitted = <String>{};

  /// Verifies [payload] received from [endpointId].
  MembershipResult verify(String endpointId, String payload) {
    final MeshHandshake? handshake = MeshHandshake.tryDecode(payload);

    if (handshake == null) {
      return _reject(endpointId, MembershipRejection.invalidHandshake);
    }
    if (handshake.token != MeshMembership.membershipToken) {
      return _reject(endpointId, MembershipRejection.unknownApplication);
    }
    if (handshake.meshId != MeshMembership.meshId) {
      return _reject(endpointId, MembershipRejection.wrongMesh);
    }
    if (!handshake.isVersionCompatible) {
      return _reject(endpointId, MembershipRejection.incompatibleVersion);
    }
    if (_admitted.contains(handshake.deviceId)) {
      return _reject(endpointId, MembershipRejection.duplicateDevice);
    }

    _admitted.add(handshake.deviceId);
    debugPrint('MeshMembership: admitted device ${handshake.deviceId} '
        '(app ${handshake.appVersion}, v${handshake.protocolVersion}) '
        'on endpoint $endpointId');
    return MembershipResult.accepted(handshake);
  }

  /// Releases a device's membership when its link drops, so it can rejoin.
  void release(String deviceId) => _admitted.remove(deviceId);

  MembershipResult _reject(String endpointId, MembershipRejection rejection) {
    // Rejected devices are surfaced in debug logs only.
    debugPrint('MeshMembership: REJECTED endpoint $endpointId — '
        '${rejection.reason}');
    return MembershipResult.rejected(rejection);
  }
}
