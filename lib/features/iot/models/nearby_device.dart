import '../../../core/constants/app_enums.dart';

/// A single peer endpoint discovered or connected over Nearby Connections.
///
/// Holds the identifying and status information the Nearby Device screen shows
/// for each device. It is transport-agnostic: Phase 2 only discovers and
/// connects peers; sending data across them arrives in a later phase.
class NearbyDevice {
  const NearbyDevice({
    required this.endpointId,
    required this.name,
    required this.state,
    required this.discoveredAt,
    this.serviceId,
    this.isIncoming = false,
    this.authenticationToken,
    this.lastUpdated,
  });

  /// Stable endpoint identifier assigned by the Nearby Connections engine.
  final String endpointId;

  /// Human-readable device name advertised by the peer.
  final String name;

  /// Current lifecycle state of this peer.
  final PeerConnectionState state;

  /// When this endpoint was first discovered (or the request received).
  final DateTime discoveredAt;

  /// The advertised service id, when reported by the engine.
  final String? serviceId;

  /// Whether the connection request originated from the remote peer.
  final bool isIncoming;

  /// Short authentication token surfaced during connection initiation, used to
  /// let both users visually confirm they are pairing with the right device.
  final String? authenticationToken;

  /// When the peer's state last changed.
  final DateTime? lastUpdated;

  bool get isConnected => state.isConnected;

  bool get isBusy => state.isBusy;

  NearbyDevice copyWith({
    String? name,
    PeerConnectionState? state,
    String? serviceId,
    bool? isIncoming,
    String? authenticationToken,
    DateTime? lastUpdated,
  }) {
    return NearbyDevice(
      endpointId: endpointId,
      name: name ?? this.name,
      state: state ?? this.state,
      discoveredAt: discoveredAt,
      serviceId: serviceId ?? this.serviceId,
      isIncoming: isIncoming ?? this.isIncoming,
      authenticationToken: authenticationToken ?? this.authenticationToken,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyDevice && other.endpointId == endpointId;

  @override
  int get hashCode => endpointId.hashCode;
}
