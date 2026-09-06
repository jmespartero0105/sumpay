import '../../../core/constants/app_enums.dart';
import 'nearby_device.dart';

/// Immutable snapshot of the Nearby Connections subsystem.
///
/// This is the single object the [NearbyProvider] exposes to the UI. It bundles
/// permission status, whether the device is advertising and/or discovering, the
/// list of discovered peers, the list of established connections and the most
/// recent error, so the Nearby Device screen can render everything from one
/// watch.
class NearbyConnectionState {
  const NearbyConnectionState({
    this.engineState = NearbyEngineState.idle,
    this.isAdvertising = false,
    this.isDiscovering = false,
    this.permissionsGranted = false,
    this.isRequestingPermissions = false,
    this.localDeviceName = 'SUMPAY device',
    this.devices = const <NearbyDevice>[],
    this.errorMessage,
  });

  final NearbyEngineState engineState;
  final bool isAdvertising;
  final bool isDiscovering;
  final bool permissionsGranted;
  final bool isRequestingPermissions;
  final String localDeviceName;

  /// Every peer the engine currently knows about, in discovery order.
  final List<NearbyDevice> devices;

  final String? errorMessage;

  /// Peers that are discovered but not yet connected (or that dropped).
  List<NearbyDevice> get discoveredDevices => devices
      .where((NearbyDevice d) => !d.isConnected)
      .toList(growable: false);

  /// Peers with an established connection.
  List<NearbyDevice> get connectedDevices => devices
      .where((NearbyDevice d) => d.isConnected)
      .toList(growable: false);

  /// Peers awaiting the user's or peer's acceptance decision.
  List<NearbyDevice> get pendingDevices => devices
      .where((NearbyDevice d) => d.isBusy)
      .toList(growable: false);

  int get connectedCount => connectedDevices.length;

  int get discoveredCount => discoveredDevices.length;

  bool get hasError => errorMessage != null;

  NearbyConnectionState copyWith({
    NearbyEngineState? engineState,
    bool? isAdvertising,
    bool? isDiscovering,
    bool? permissionsGranted,
    bool? isRequestingPermissions,
    String? localDeviceName,
    List<NearbyDevice>? devices,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NearbyConnectionState(
      engineState: engineState ?? this.engineState,
      isAdvertising: isAdvertising ?? this.isAdvertising,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      permissionsGranted: permissionsGranted ?? this.permissionsGranted,
      isRequestingPermissions:
          isRequestingPermissions ?? this.isRequestingPermissions,
      localDeviceName: localDeviceName ?? this.localDeviceName,
      devices: devices ?? this.devices,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Recomputes [engineState] from the advertising / discovering flags.
  NearbyEngineState resolveEngineState() {
    if (isAdvertising && isDiscovering) return NearbyEngineState.active;
    if (isAdvertising) return NearbyEngineState.advertising;
    if (isDiscovering) return NearbyEngineState.discovering;
    return NearbyEngineState.idle;
  }
}
