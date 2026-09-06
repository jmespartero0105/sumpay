import 'nearby_device.dart';

/// Overall state of automatic mesh formation.
enum MeshStatus {
  /// Auto-connect is off; the mesh is not being formed automatically.
  disabled,

  /// Starting up (permissions, advertising, discovery coming online).
  starting,

  /// Advertising and discovering, but no peers connected yet.
  searching,

  /// At least one peer is connected.
  connected,

  /// Something prevents formation (permissions denied, radios off, error).
  error,
}

extension MeshStatusInfo on MeshStatus {
  String get label => switch (this) {
        MeshStatus.disabled => 'Auto-connect off',
        MeshStatus.starting => 'Starting mesh',
        MeshStatus.searching => 'Searching for devices',
        MeshStatus.connected => 'Mesh active',
        MeshStatus.error => 'Mesh unavailable',
      };
}

/// Qualitative connection quality for a link.
///
/// Nearby Connections does not expose radio signal strength (RSSI), so quality
/// is inferred from heartbeat behaviour: round-trip latency and how recently a
/// heartbeat was acknowledged. This is an honest proxy, not a dBm reading.
enum ConnectionQuality { unknown, poor, fair, good, excellent }

extension ConnectionQualityInfo on ConnectionQuality {
  String get label => switch (this) {
        ConnectionQuality.unknown => 'Unknown',
        ConnectionQuality.poor => 'Poor',
        ConnectionQuality.fair => 'Fair',
        ConnectionQuality.good => 'Good',
        ConnectionQuality.excellent => 'Excellent',
      };

  /// A 0-4 bar count for signal-style indicators.
  int get bars => switch (this) {
        ConnectionQuality.unknown => 0,
        ConnectionQuality.poor => 1,
        ConnectionQuality.fair => 2,
        ConnectionQuality.good => 3,
        ConnectionQuality.excellent => 4,
      };

  /// Derives quality from a heartbeat round-trip time in milliseconds.
  static ConnectionQuality fromLatency(int? rttMs) {
    if (rttMs == null) return ConnectionQuality.unknown;
    if (rttMs < 150) return ConnectionQuality.excellent;
    if (rttMs < 400) return ConnectionQuality.good;
    if (rttMs < 900) return ConnectionQuality.fair;
    return ConnectionQuality.poor;
  }
}

/// Per-link health tracked by the heartbeat monitor.
class LinkHealth {
  const LinkHealth({
    required this.endpointId,
    this.lastRttMs,
    this.lastHeartbeatAt,
    this.missedBeats = 0,
  });

  final String endpointId;

  /// Most recent heartbeat round-trip time, in milliseconds.
  final int? lastRttMs;

  /// When the last heartbeat acknowledgement arrived.
  final DateTime? lastHeartbeatAt;

  /// Consecutive heartbeats with no reply (drives dead-link detection).
  final int missedBeats;

  ConnectionQuality get quality =>
      ConnectionQualityInfo.fromLatency(lastRttMs);

  LinkHealth copyWith({
    int? lastRttMs,
    DateTime? lastHeartbeatAt,
    int? missedBeats,
  }) {
    return LinkHealth(
      endpointId: endpointId,
      lastRttMs: lastRttMs ?? this.lastRttMs,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
      missedBeats: missedBeats ?? this.missedBeats,
    );
  }
}

/// Immutable snapshot of automatic mesh formation, exposed to the UI.
class MeshManagerState {
  const MeshManagerState({
    this.status = MeshStatus.disabled,
    this.autoConnectEnabled = true,
    this.isAdvertising = false,
    this.isDiscovering = false,
    this.connectedDevices = const <NearbyDevice>[],
    this.discoveredDevices = const <NearbyDevice>[],
    this.linkHealth = const <String, LinkHealth>{},
    this.maxConnections = 8,
    this.errorMessage,
  });

  final MeshStatus status;
  final bool autoConnectEnabled;
  final bool isAdvertising;
  final bool isDiscovering;
  final List<NearbyDevice> connectedDevices;
  final List<NearbyDevice> discoveredDevices;

  /// Health per connected endpoint id.
  final Map<String, LinkHealth> linkHealth;

  final int maxConnections;
  final String? errorMessage;

  int get connectedCount => connectedDevices.length;

  bool get atCapacity => connectedCount >= maxConnections;

  /// Best-known quality across all links (for a single headline indicator).
  ConnectionQuality get overallQuality {
    if (linkHealth.isEmpty) return ConnectionQuality.unknown;
    final List<int> bars = linkHealth.values
        .map((LinkHealth h) => h.quality.bars)
        .where((int b) => b > 0)
        .toList();
    if (bars.isEmpty) return ConnectionQuality.unknown;
    final double avg = bars.reduce((int a, int b) => a + b) / bars.length;
    return switch (avg.round()) {
      >= 4 => ConnectionQuality.excellent,
      3 => ConnectionQuality.good,
      2 => ConnectionQuality.fair,
      _ => ConnectionQuality.poor,
    };
  }

  MeshManagerState copyWith({
    MeshStatus? status,
    bool? autoConnectEnabled,
    bool? isAdvertising,
    bool? isDiscovering,
    List<NearbyDevice>? connectedDevices,
    List<NearbyDevice>? discoveredDevices,
    Map<String, LinkHealth>? linkHealth,
    int? maxConnections,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MeshManagerState(
      status: status ?? this.status,
      autoConnectEnabled: autoConnectEnabled ?? this.autoConnectEnabled,
      isAdvertising: isAdvertising ?? this.isAdvertising,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      connectedDevices: connectedDevices ?? this.connectedDevices,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      linkHealth: linkHealth ?? this.linkHealth,
      maxConnections: maxConnections ?? this.maxConnections,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
