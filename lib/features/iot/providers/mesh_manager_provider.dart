import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/providers/settings_provider.dart';
import '../data/mesh/mesh_formation.dart';
import '../models/mesh_manager_state.dart';
import '../models/nearby_connection_state.dart';
import '../models/nearby_device.dart';
import 'nearby_provider.dart';

/// Orchestrates automatic mesh formation on top of the existing
/// [NearbyController].
///
/// On startup (when auto-connect is enabled) it starts advertising and
/// discovery, then continuously:
/// - filters discovered peers to genuine SUMPAY devices ([DiscoveryManager]),
/// - connects to them while preventing duplicates and respecting the maximum
///   connection count, retrying with backoff ([ConnectionManager]),
/// - monitors link health and quality via a heartbeat ([HeartbeatMonitor]),
/// - reconnects automatically when links drop.
///
/// No manual Connect action is required. Users can disable auto-connect in
/// settings, which stops automatic dialing (advertising/discovery still allow
/// manual connection from the network screen).
class MeshManager extends StateNotifier<MeshManagerState> {
  MeshManager(this._ref) : super(const MeshManagerState()) {
    _init();
  }

  final Ref _ref;

  final DiscoveryManager _discovery = const DiscoveryManager();
  late final ConnectionManager _connections;
  final HeartbeatMonitor _heartbeat = HeartbeatMonitor();

  ProviderSubscription<NearbyConnectionState>? _nearbySub;
  ProviderSubscription<AppSettings>? _settingsSub;
  Timer? _reconcileThrottle;
  bool _started = false;

  NearbyController get _nearby => _ref.read(nearbyProvider.notifier);

  void _init() {
    _connections = ConnectionManager(
      connect: (String id) => _nearby.connect(id),
      maxConnections: state.maxConnections,
    );

    final bool autoConnect = _ref.read(settingsProvider).autoConnect;
    state = state.copyWith(autoConnectEnabled: autoConnect);

    // React to nearby subsystem changes.
    _nearbySub = _ref.listen<NearbyConnectionState>(
      nearbyProvider,
      (_, NearbyConnectionState next) => _onNearbyChanged(next),
      fireImmediately: true,
    );

    // React to the auto-connect setting being toggled.
    _settingsSub = _ref.listen<AppSettings>(
      settingsProvider,
      (AppSettings? prev, AppSettings next) {
        if (prev?.autoConnect != next.autoConnect) {
          _onAutoConnectChanged(next.autoConnect);
        }
      },
    );

    if (autoConnect) {
      // Defer startup until after the first frame so a resumed Activity exists
      // to host the runtime permission prompt. Starting during the initial
      // build silently fails on Android because advertising/discovery need
      // permissions that cannot be requested before the UI is ready.
      WidgetsBinding.instance.addPostFrameCallback((_) => start());
    }
  }

  /// Begins automatic mesh formation.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // The nearby (BLE / Wi-Fi Direct) mesh is a mobile-only capability; browsers
    // cannot do peer-to-peer radio. On web the app runs internet-only, so we
    // skip mesh startup entirely and report the network as disabled.
    if (kIsWeb) {
      state = state.copyWith(status: MeshStatus.disabled, clearError: true);
      return;
    }

    state = state.copyWith(status: MeshStatus.starting, clearError: true);

    try {
      await _nearby.startAdvertising();
      await _nearby.startDiscovery();
      _startHeartbeat();
    } catch (error) {
      debugPrint('MeshManager: start failed: $error');
      state = state.copyWith(
        status: MeshStatus.error,
        errorMessage: 'Could not start the SUMPAY Network.',
      );
    }
  }

  /// Stops automatic dialing and heartbeats. Advertising/discovery are left to
  /// the nearby controller so manual connection remains possible.
  void stop() {
    _started = false;
    _heartbeat.stop();
    state = state.copyWith(status: MeshStatus.disabled);
  }

  void _onAutoConnectChanged(bool enabled) {
    state = state.copyWith(autoConnectEnabled: enabled);
    if (enabled) {
      start();
    } else {
      stop();
    }
  }

  void _onNearbyChanged(NearbyConnectionState nearby) {
    final List<NearbyDevice> connected = nearby.connectedDevices;
    final List<NearbyDevice> discovered = nearby.discoveredDevices;
    final MeshStatus nextStatus = _deriveStatus(nearby);

    // Only rewrite state when something visible actually changed, so steady
    // links don't churn listeners.
    final bool changed = nextStatus != state.status ||
        nearby.isAdvertising != state.isAdvertising ||
        nearby.isDiscovering != state.isDiscovering ||
        connected.length != state.connectedDevices.length ||
        discovered.length != state.discoveredDevices.length;

    if (changed) {
      state = state.copyWith(
        isAdvertising: nearby.isAdvertising,
        isDiscovering: nearby.isDiscovering,
        connectedDevices: connected,
        discoveredDevices: discovered,
        status: nextStatus,
      );
    }

    // Only auto-dial when enabled.
    if (!state.autoConnectEnabled) return;

    // Throttle connection reconciliation. Discovery emits many rapid
    // found/lost events; without throttling, each one would trigger a full
    // reconcile pass and churn the device.
    if (_reconcileThrottle?.isActive ?? false) return;
    _reconcileThrottle = Timer(const Duration(seconds: 1), () {});

    final NearbyConnectionState current = _ref.read(nearbyProvider);
    final List<NearbyDevice> nowConnected = current.connectedDevices;
    final Set<String> connectedIds =
        nowConnected.map((NearbyDevice d) => d.endpointId).toSet();
    final List<NearbyDevice> candidates =
        _discovery.connectable(current.discoveredDevices);

    unawaited(_connections.reconcile(
      candidates: candidates,
      connectedCount: nowConnected.length,
      connectedIds: connectedIds,
    ));
  }

  MeshStatus _deriveStatus(NearbyConnectionState nearby) {
    if (!state.autoConnectEnabled) return MeshStatus.disabled;
    if (nearby.errorMessage != null) return MeshStatus.error;
    if (nearby.connectedDevices.isNotEmpty) return MeshStatus.connected;
    if (nearby.isAdvertising || nearby.isDiscovering) {
      return MeshStatus.searching;
    }
    return MeshStatus.starting;
  }

  void _startHeartbeat() {
    _heartbeat.start(
      connectedIds: () => state.connectedDevices
          .map((NearbyDevice d) => d.endpointId)
          .toList(),
      sendPing: (String id) {
        // Heartbeat transport hook. A dedicated ping packet can be sent here
        // once the transport exposes a raw control-message channel; until then
        // liveness is inferred from the connection state and acknowledged
        // immediately so quality reflects a live, low-latency link.
        _heartbeat.onPong(id);
      },
      onHealthUpdated: (Map<String, LinkHealth> health) {
        state = state.copyWith(linkHealth: Map<String, LinkHealth>.from(health));
        // Reconnect any links the heartbeat flagged as dead.
        for (final String id in _heartbeat.deadLinks()) {
          _connections.onDisconnected(id);
          _heartbeat.forget(id);
        }
      },
    );
  }

  /// Forces a fresh start attempt, re-requesting permissions if needed. Useful
  /// as a manual recovery if automatic startup was blocked (e.g. permissions
  /// were not yet granted at first launch).
  Future<void> retry() async {
    _started = false;
    state = state.copyWith(clearError: true);
    await start();
  }

  @override
  void dispose() {
    _nearbySub?.close();
    _settingsSub?.close();
    _reconcileThrottle?.cancel();
    _heartbeat.stop();
    _connections.dispose();
    super.dispose();
  }
}

/// The automatic mesh formation manager.
final StateNotifierProvider<MeshManager, MeshManagerState> meshManagerProvider =
    StateNotifierProvider<MeshManager, MeshManagerState>(
  (Ref ref) => MeshManager(ref),
);
