import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/connectivity_service.dart';
import '../models/mesh_manager_state.dart';
import '../models/nearby_device.dart';
import 'mesh_manager_provider.dart';

/// How this device is currently reaching the wider SUMPAY network.
enum ConnectionMode {
  /// Online: reachable through the internet gateway (Supabase backend).
  onlineGateway,

  /// Offline mesh: connected to nearby SUMPAY devices only, no internet.
  offlineMesh,

  /// Neither internet nor mesh peers right now.
  none,
}

extension ConnectionModeInfo on ConnectionMode {
  String get label => switch (this) {
        ConnectionMode.onlineGateway => 'Online',
        ConnectionMode.offlineMesh => 'Offline mesh extension',
        ConnectionMode.none => 'No connection',
      };

  String get description => switch (this) {
        ConnectionMode.onlineGateway =>
          'Your messages and SOS reach the barangay through the internet.',
        ConnectionMode.offlineMesh =>
          'No internet. You are connected to nearby SUMPAY devices, which relay '
              'your messages and SOS across the SUMPAY Network.',
        ConnectionMode.none =>
          'Not connected to the internet or any nearby SUMPAY device. Messages '
              'and SOS will be queued and sent once a connection is available.',
      };
}

/// A real, measured snapshot of this device's network state, derived entirely
/// from the live mesh manager and connectivity service (no simulated values).
class NetworkView {
  const NetworkView({
    required this.mode,
    required this.internetConnected,
    required this.meshStatus,
    required this.connectedDevices,
    required this.discoveredDevices,
    required this.maxConnections,
    required this.updatedAt,
  });

  final ConnectionMode mode;
  final bool internetConnected;
  final MeshStatus meshStatus;
  final List<NearbyDevice> connectedDevices;
  final List<NearbyDevice> discoveredDevices;
  final int maxConnections;
  final DateTime updatedAt;

  int get connectedCount => connectedDevices.length;
  bool get meshActive =>
      meshStatus == MeshStatus.connected || connectedDevices.isNotEmpty;

  /// Whether this device can currently reach the network at all.
  bool get isConnected => mode != ConnectionMode.none;
}

/// The single source of truth for the network screens. Reactively combines the
/// live mesh manager state and the connectivity snapshot into one real view.
final Provider<NetworkView> networkViewProvider = Provider<NetworkView>((
  Ref ref,
) {
  final MeshManagerState mesh = ref.watch(meshManagerProvider);
  final ConnectivitySnapshot conn = ref.watch(connectivityProvider);

  final bool internet = conn.internetConnected;
  final bool hasPeers = mesh.connectedDevices.isNotEmpty;

  final ConnectionMode mode = internet
      ? ConnectionMode.onlineGateway
      : (hasPeers ? ConnectionMode.offlineMesh : ConnectionMode.none);

  return NetworkView(
    mode: mode,
    internetConnected: internet,
    meshStatus: mesh.status,
    connectedDevices: mesh.connectedDevices,
    discoveredDevices: mesh.discoveredDevices,
    maxConnections: mesh.maxConnections,
    updatedAt: DateTime.now(),
  );
});
