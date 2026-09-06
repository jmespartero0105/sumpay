import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../data/dummy_network.dart';
import '../models/network_models.dart';

/// Holds the simulated live network snapshot.
///
/// During integration replace the mutators with a stream subscription to the
/// BLE / Wi-Fi Direct bridge that talks to the ESP32 gateway.
class NetworkController extends StateNotifier<NetworkStatus> {
  NetworkController() : super(DummyNetwork.status);

  bool _isScanning = false;

  bool get isScanning => _isScanning;

  /// Simulates a gateway rescan.
  Future<void> rescan() async {
    if (_isScanning) return;
    _isScanning = true;
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    state = state.copyWith(
      rssi: state.rssi + 4 > -60 ? -74 : state.rssi + 4,
      linkQualityPercent: (state.linkQualityPercent + 5).clamp(0, 100),
      lastSync: DateTime.now(),
    );
    _isScanning = false;
  }

  /// Cycles the transport for demonstration during the defence presentation.
  void cycleLinkMode() {
    final LinkMode next = switch (state.linkMode) {
      LinkMode.loRa => LinkMode.mesh,
      LinkMode.mesh => LinkMode.offline,
      LinkMode.offline => LinkMode.internet,
      LinkMode.internet => LinkMode.loRa,
    };

    state = state.copyWith(
      linkMode: next,
      loRaActive: next == LinkMode.loRa,
      meshActive: next == LinkMode.mesh || next == LinkMode.loRa,
      internetAvailable: next == LinkMode.internet,
      hopCount: switch (next) {
        LinkMode.loRa => 2,
        LinkMode.mesh => 3,
        LinkMode.internet => 1,
        LinkMode.offline => 0,
      },
      rssi: switch (next) {
        LinkMode.loRa => -78,
        LinkMode.mesh => -95,
        LinkMode.internet => -58,
        LinkMode.offline => -120,
      },
      linkQualityPercent: switch (next) {
        LinkMode.loRa => 82,
        LinkMode.mesh => 54,
        LinkMode.internet => 94,
        LinkMode.offline => 0,
      },
    );
  }

  /// Simulates flushing the offline outbox once connectivity returns.
  void flushQueue() {
    state = state.copyWith(queuedPackets: 0, lastSync: DateTime.now());
  }
}

final StateNotifierProvider<NetworkController, NetworkStatus>
    networkStatusProvider =
    StateNotifierProvider<NetworkController, NetworkStatus>(
  (Ref ref) => NetworkController(),
);

final Provider<List<MeshNode>> meshNodesProvider =
    Provider<List<MeshNode>>((Ref ref) => DummyNetwork.nodes);

final Provider<List<MeshNode>> onlineNodesProvider =
    Provider<List<MeshNode>>((Ref ref) {
  return ref
      .watch(meshNodesProvider)
      .where((MeshNode node) => node.status == NodeStatus.online)
      .toList();
});

final Provider<List<PacketLogEntry>> packetLogProvider =
    Provider<List<PacketLogEntry>>((Ref ref) => DummyNetwork.packetLog);
