import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../data/services/nearby_service.dart';
import '../models/nearby_connection_state.dart';
import '../models/nearby_device.dart';

/// Provides the singleton [NearbyService] instance.
final Provider<NearbyService> nearbyServiceProvider =
    Provider<NearbyService>((Ref ref) {
  final NearbyService service = NearbyService();
  ref.onDispose(service.shutdown);
  return service;
});

/// Orchestrates Nearby Connections and exposes an immutable
/// [NearbyConnectionState] to the UI.
///
/// The controller owns the device list and translates the service's callbacks
/// into state transitions. Phase 2 stops at connection management — no payloads
/// are exchanged.
class NearbyController extends StateNotifier<NearbyConnectionState> {
  NearbyController(this._service) : super(const NearbyConnectionState());

  final NearbyService _service;

  /// Endpoints for which [acceptConnection] has already been issued, so the
  /// plugin is never asked to accept the same handshake twice (which triggers
  /// STATUS_OUT_OF_ORDER_API_CALL).
  final Set<String> _accepted = <String>{};

  /// Sets the name this device advertises to peers.
  void setLocalDeviceName(String name) {
    if (name.trim().isEmpty) return;
    state = state.copyWith(localDeviceName: name.trim());
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Checks current permission status without prompting.
  Future<void> refreshPermissions() async {
    final bool granted = await _service.hasPermissions();
    state = state.copyWith(permissionsGranted: granted);
  }

  /// Requests all runtime permissions Nearby Connections needs.
  Future<bool> requestPermissions() async {
    state = state.copyWith(isRequestingPermissions: true, clearError: true);
    try {
      final bool granted = await _service.requestPermissions();
      state = state.copyWith(
        permissionsGranted: granted,
        isRequestingPermissions: false,
        errorMessage: granted
            ? null
            : 'Some permissions were denied. Nearby discovery needs Bluetooth, '
                'Wi-Fi and location access to work.',
        clearError: granted,
      );
      return granted;
    } catch (error) {
      state = state.copyWith(
        isRequestingPermissions: false,
        errorMessage: 'Could not request permissions: $error',
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Advertising & discovery
  // ---------------------------------------------------------------------------

  /// Starts advertising this device to nearby discoverers.
  Future<void> startAdvertising() async {
    if (!await _ensurePermissions()) return;
    try {
      final bool started = await _service.startAdvertising(
        deviceName: state.localDeviceName,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      state = state.copyWith(
        isAdvertising: started,
        errorMessage: started ? null : 'Advertising did not start.',
        clearError: started,
      );
      _syncEngineState();
    } catch (error) {
      state = state.copyWith(
        isAdvertising: false,
        errorMessage: 'Failed to start advertising: $error',
      );
    }
  }

  /// Stops advertising.
  Future<void> stopAdvertising() async {
    await _service.stopAdvertising();
    state = state.copyWith(isAdvertising: false);
    _syncEngineState();
  }

  /// Starts discovering nearby advertisers.
  Future<void> startDiscovery() async {
    if (!await _ensurePermissions()) return;
    try {
      final bool started = await _service.startDiscovery(
        deviceName: state.localDeviceName,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
      );
      state = state.copyWith(
        isDiscovering: started,
        errorMessage: started ? null : 'Discovery did not start.',
        clearError: started,
      );
      _syncEngineState();
    } catch (error) {
      state = state.copyWith(
        isDiscovering: false,
        errorMessage: 'Failed to start discovery: $error',
      );
    }
  }

  /// Stops discovery.
  Future<void> stopDiscovery() async {
    await _service.stopDiscovery();
    state = state.copyWith(isDiscovering: false);
    _syncEngineState();
  }

  /// Convenience: advertise and discover at the same time.
  Future<void> startAll() async {
    await startAdvertising();
    await startDiscovery();
  }

  /// Convenience: stop everything and clear discovered (non-connected) peers.
  Future<void> stopAll() async {
    await _service.stopAdvertising();
    await _service.stopDiscovery();
    state = state.copyWith(
      isAdvertising: false,
      isDiscovering: false,
      devices: state.connectedDevices,
    );
    _syncEngineState();
  }

  // ---------------------------------------------------------------------------
  // Connection management
  // ---------------------------------------------------------------------------

  /// Requests a connection to a discovered peer.
  Future<void> connect(String endpointId) async {
    final NearbyDevice? device = _deviceById(endpointId);
    if (device == null) return;

    // Fresh handshake: clear any stale accept guard for this endpoint.
    _accepted.remove(endpointId);

    _upsert(device.copyWith(
      state: PeerConnectionState.requesting,
      lastUpdated: DateTime.now(),
    ));

    try {
      await _service.requestConnection(
        deviceName: state.localDeviceName,
        endpointId: endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (error) {
      _upsert(device.copyWith(
        state: PeerConnectionState.error,
        lastUpdated: DateTime.now(),
      ));
      state = state.copyWith(errorMessage: 'Connection request failed: $error');
    }
  }

  /// Accepts an incoming connection request.
  ///
  /// Guarded so accepting the same endpoint twice cannot happen (which the
  /// plugin rejects with STATUS_OUT_OF_ORDER_API_CALL). In normal operation the
  /// connection is auto-accepted; this remains as a manual fallback.
  Future<void> acceptConnection(String endpointId) async {
    if (_accepted.contains(endpointId)) return;
    _accepted.add(endpointId);
    try {
      await _service.acceptConnection(endpointId);
    } catch (error) {
      _accepted.remove(endpointId);
      state = state.copyWith(errorMessage: 'Could not accept: $error');
    }
  }

  /// Rejects an incoming connection request.
  Future<void> rejectConnection(String endpointId) async {
    _accepted.remove(endpointId);
    try {
      await _service.rejectConnection(endpointId);
      final NearbyDevice? device = _deviceById(endpointId);
      if (device != null) {
        _upsert(device.copyWith(
          state: PeerConnectionState.rejected,
          lastUpdated: DateTime.now(),
        ));
      }
    } catch (error) {
      state = state.copyWith(errorMessage: 'Could not reject: $error');
    }
  }

  /// Disconnects from a connected peer.
  Future<void> disconnect(String endpointId) async {
    _accepted.remove(endpointId);
    await _service.disconnect(endpointId);
    final NearbyDevice? device = _deviceById(endpointId);
    if (device != null) {
      _upsert(device.copyWith(
        state: PeerConnectionState.disconnected,
        lastUpdated: DateTime.now(),
      ));
    }
  }

  /// Disconnects from every connected peer.
  Future<void> disconnectAll() async {
    _accepted.clear();
    await _service.disconnectAll();
    final List<NearbyDevice> updated = state.devices
        .map((NearbyDevice d) => d.isConnected
            ? d.copyWith(
                state: PeerConnectionState.disconnected,
                lastUpdated: DateTime.now(),
              )
            : d)
        .toList();
    state = state.copyWith(devices: updated);
  }

  /// Removes disconnected / rejected peers from the visible list.
  void clearInactive() {
    final List<NearbyDevice> kept = state.devices
        .where((NearbyDevice d) =>
            d.state != PeerConnectionState.disconnected &&
            d.state != PeerConnectionState.rejected &&
            d.state != PeerConnectionState.error)
        .toList();
    state = state.copyWith(devices: kept);
  }

  /// Dismisses the current error banner.
  void clearError() => state = state.copyWith(clearError: true);

  // ---------------------------------------------------------------------------
  // Service callbacks
  // ---------------------------------------------------------------------------

  void _onEndpointFound(String id, String name, String serviceId) {
    debugPrint('Nearby: endpoint FOUND id=$id name=$name service=$serviceId');
    final NearbyDevice? existing = _deviceById(id);
    if (existing != null) {
      _upsert(existing.copyWith(
        name: name,
        serviceId: serviceId,
        lastUpdated: DateTime.now(),
      ));
      return;
    }
    _upsert(NearbyDevice(
      endpointId: id,
      name: name,
      serviceId: serviceId,
      state: PeerConnectionState.found,
      discoveredAt: DateTime.now(),
      lastUpdated: DateTime.now(),
    ));
  }

  void _onEndpointLost(String id) {
    final NearbyDevice? device = _deviceById(id);
    if (device == null || device.isConnected) return;
    _remove(id);
  }

  void _onConnectionInitiated(
    String id,
    String name,
    String authToken,
    bool isIncoming,
  ) {
    final NearbyDevice? existing = _deviceById(id);
    final NearbyDevice device = (existing ??
            NearbyDevice(
              endpointId: id,
              name: name,
              state: PeerConnectionState.pending,
              discoveredAt: DateTime.now(),
            ))
        .copyWith(
      name: name,
      state: PeerConnectionState.pending,
      isIncoming: isIncoming,
      authenticationToken: authToken,
      lastUpdated: DateTime.now(),
    );
    _upsert(device);

    // Both peers must accept for the connection to establish. For a trusted
    // same-app mesh we auto-accept as soon as the handshake is initiated, on
    // both the requesting and receiving sides. Accepting exactly once per
    // endpoint (guarded by [_accepted]) avoids STATUS_OUT_OF_ORDER_API_CALL.
    _autoAccept(id);
  }

  Future<void> _autoAccept(String id) async {
    if (_accepted.contains(id)) return;
    _accepted.add(id);
    try {
      await _service.acceptConnection(id);
    } catch (error) {
      _accepted.remove(id);
      debugPrint('Nearby: auto-accept failed for $id: $error');
    }
  }

  void _onConnectionResult(String id, bool accepted) {
    // Once the handshake resolves, a rejected/failed endpoint may be retried
    // later, so drop it from the accepted guard. A connected endpoint keeps its
    // guard until it disconnects.
    if (!accepted) _accepted.remove(id);
    final NearbyDevice? device = _deviceById(id);
    if (device == null) return;
    _upsert(device.copyWith(
      state:
          accepted ? PeerConnectionState.connected : PeerConnectionState.rejected,
      lastUpdated: DateTime.now(),
    ));
  }

  void _onDisconnected(String id) {
    _accepted.remove(id);
    final NearbyDevice? device = _deviceById(id);
    if (device == null) return;
    _upsert(device.copyWith(
      state: PeerConnectionState.disconnected,
      lastUpdated: DateTime.now(),
    ));
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<bool> _ensurePermissions() async {
    if (state.permissionsGranted) return true;
    final bool granted = await requestPermissions();
    return granted;
  }

  NearbyDevice? _deviceById(String id) {
    for (final NearbyDevice d in state.devices) {
      if (d.endpointId == id) return d;
    }
    return null;
  }

  void _upsert(NearbyDevice device) {
    final List<NearbyDevice> next = List<NearbyDevice>.from(state.devices);
    final int index =
        next.indexWhere((NearbyDevice d) => d.endpointId == device.endpointId);
    if (index >= 0) {
      next[index] = device;
    } else {
      next.add(device);
    }
    state = state.copyWith(devices: next);
  }

  void _remove(String id) {
    state = state.copyWith(
      devices: state.devices
          .where((NearbyDevice d) => d.endpointId != id)
          .toList(),
    );
  }

  void _syncEngineState() {
    state = state.copyWith(engineState: state.resolveEngineState());
  }
}

/// The Nearby Connections controller/provider.
final StateNotifierProvider<NearbyController, NearbyConnectionState>
    nearbyProvider =
    StateNotifierProvider<NearbyController, NearbyConnectionState>(
  (Ref ref) => NearbyController(ref.watch(nearbyServiceProvider)),
);

/// Derived: only the connected peers.
final Provider<List<NearbyDevice>> connectedDevicesProvider =
    Provider<List<NearbyDevice>>((Ref ref) {
  return ref.watch(nearbyProvider).connectedDevices;
});

/// Derived: only the discovered (not yet connected) peers.
final Provider<List<NearbyDevice>> discoveredDevicesProvider =
    Provider<List<NearbyDevice>>((Ref ref) {
  return ref.watch(nearbyProvider).discoveredDevices;
});
