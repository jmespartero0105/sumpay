import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/device_identity.dart';
import '../../../iot/data/services/connectivity_service.dart';
import '../../../iot/models/mesh_manager_state.dart';
import '../../../iot/providers/mesh_manager_provider.dart';
import '../../providers/nearby_chat_provider.dart';
import '../transport/internet_transport.dart';
import '../manager/transport_manager.dart';

/// The app's single [InternetTransport], keyed to this device's id.
final Provider<InternetTransport> internetTransportProvider =
    Provider<InternetTransport>((Ref ref) {
  final String deviceId = ref.watch(deviceIdProvider);
  final InternetTransport transport = InternetTransport(deviceId: deviceId);
  ref.onDispose(transport.dispose);
  return transport;
});

/// The app's [TransportManager], which routes packets across the mesh and the
/// internet. Kept alive for the whole session so both paths stay available.
final Provider<TransportManager> transportManagerProvider =
    Provider<TransportManager>((Ref ref) {
  final ConnectivityController connectivity =
      ref.watch(connectivityProvider.notifier);

  // Mirror mesh connection state into the connectivity snapshot so the home
  // network icon can reflect "mesh active" (internet state is mirrored by the
  // manager itself).
  ref.listen<MeshManagerState>(meshManagerProvider, (
    MeshManagerState? prev,
    MeshManagerState next,
  ) {
    connectivity.setMesh(
      next.connectedCount > 0 ? LinkState.connected : LinkState.unavailable,
    );
  }, fireImmediately: true);

  final TransportManager manager = TransportManager(
    mesh: ref.watch(nearbyTransportProvider),
    internet: ref.watch(internetTransportProvider),
    connectivity: connectivity,
  );
  ref.onDispose(manager.dispose);
  return manager;
});
