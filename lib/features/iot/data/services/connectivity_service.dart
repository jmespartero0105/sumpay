import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A tri-state used for each independent connectivity dimension. Kept separate
/// per dimension so the UI never shows a single misleading combined status.
enum LinkState { connected, unavailable, connecting }

/// Snapshot of every connectivity dimension SUMPAY cares about. These are kept
/// deliberately independent: "internet down, mesh up" and "internet up, mesh
/// down" are both valid, first-class states.
@immutable
class ConnectivitySnapshot {
  const ConnectivitySnapshot({
    this.internet = LinkState.unavailable,
    this.wifi = LinkState.unavailable,
    this.bluetooth = LinkState.unavailable,
    this.mesh = LinkState.unavailable,
    this.gateway = LinkState.unavailable,
  });

  /// True internet reachability through the backend (set by the internet
  /// transport, not merely by having a Wi-Fi/mobile link).
  final LinkState internet;

  /// Whether the device has a Wi-Fi or mobile data link (transport medium
  /// present, which does not by itself guarantee backend reachability).
  final LinkState wifi;

  /// Whether Bluetooth is available for the local mesh.
  final LinkState bluetooth;

  /// Whether the local BLE/Wi-Fi Direct mesh currently has peers.
  final LinkState mesh;

  /// Future ESP32/LoRa gateway availability. Always unavailable for now.
  final LinkState gateway;

  bool get internetConnected => internet == LinkState.connected;
  bool get meshConnected => mesh == LinkState.connected;

  ConnectivitySnapshot copyWith({
    LinkState? internet,
    LinkState? wifi,
    LinkState? bluetooth,
    LinkState? mesh,
    LinkState? gateway,
  }) {
    return ConnectivitySnapshot(
      internet: internet ?? this.internet,
      wifi: wifi ?? this.wifi,
      bluetooth: bluetooth ?? this.bluetooth,
      mesh: mesh ?? this.mesh,
      gateway: gateway ?? this.gateway,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ConnectivitySnapshot &&
      other.internet == internet &&
      other.wifi == wifi &&
      other.bluetooth == bluetooth &&
      other.mesh == mesh &&
      other.gateway == gateway;

  @override
  int get hashCode => Object.hash(internet, wifi, bluetooth, mesh, gateway);
}

/// Watches OS-level connectivity (Wi-Fi / mobile / bluetooth medium) and merges
/// it with SUMPAY's own transport signals (backend reachability, mesh peers)
/// into a single [ConnectivitySnapshot]. Note that `connectivity_plus` reports
/// the *medium*, not real internet reachability, so true internet state is fed
/// in from the internet transport via [setInternet].
class ConnectivityController extends StateNotifier<ConnectivitySnapshot> {
  ConnectivityController() : super(const ConnectivitySnapshot()) {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> _init() async {
    try {
      final List<ConnectivityResult> initial =
          await _connectivity.checkConnectivity();
      _applyMedium(initial);
      _sub = _connectivity.onConnectivityChanged.listen(_applyMedium);
    } catch (error) {
      debugPrint('ConnectivityController: init failed: $error');
    }
  }

  void _applyMedium(List<ConnectivityResult> results) {
    final bool hasWifiOrMobile = results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.ethernet);
    final bool hasBluetooth = results.contains(ConnectivityResult.bluetooth);
    state = state.copyWith(
      wifi: hasWifiOrMobile ? LinkState.connected : LinkState.unavailable,
      bluetooth: hasBluetooth ? LinkState.connected : LinkState.unavailable,
    );
  }

  /// Fed by the internet transport: real backend reachability.
  void setInternet(LinkState value) {
    if (state.internet == value) return;
    state = state.copyWith(internet: value);
  }

  /// Fed by the mesh manager: whether the local mesh has peers.
  void setMesh(LinkState value) {
    if (state.mesh == value) return;
    state = state.copyWith(mesh: value);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// App-wide connectivity snapshot.
final StateNotifierProvider<ConnectivityController, ConnectivitySnapshot>
    connectivityProvider =
    StateNotifierProvider<ConnectivityController, ConnectivitySnapshot>(
  (Ref ref) => ConnectivityController(),
);
