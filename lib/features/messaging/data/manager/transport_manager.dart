import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../iot/data/services/connectivity_service.dart';
import '../../models/mesh_packet.dart';
import '../transport/internet_transport.dart';
import '../transport/nearby_transport.dart';
import '../transport/sumpay_transport.dart';

/// Routes SUMPAY packets across all available transports without the
/// application layer needing to know which one is used.
///
/// Policy:
/// - Send over the internet transport when it is connected (long range,
///   cross-network), AND always also hand the packet to the mesh so nearby
///   devices without internet still receive it. This dual-send is deliberate:
///   the existing [RelayService] de-duplicates by packet uuid, so a device that
///   hears the same packet on both paths keeps only the first. Emergency
///   delivery is maximised without duplicate display.
/// - When the internet is unavailable, packets simply flow over the mesh, and
///   internet-destined packets are queued and flushed on reconnect.
/// - The mesh is never disabled by internet state.
///
/// Inbound internet packets are fed straight into the existing mesh relay's
/// [RelayService.handleIncoming], so decoding, duplicate-prevention and local
/// delivery reuse the proven engine rather than a parallel path.
class TransportManager {
  TransportManager({
    required NearbyTransport mesh,
    required InternetTransport internet,
    required ConnectivityController connectivity,
  })  : _mesh = mesh,
        _internet = internet,
        _connectivity = connectivity;

  final NearbyTransport _mesh;
  final InternetTransport _internet;
  final ConnectivityController _connectivity;

  StreamSubscription<TransportInbound>? _internetInboundSub;
  StreamSubscription<TransportStatus>? _internetStatusSub;

  /// Packets awaiting internet delivery while it is disconnected. Bounded so a
  /// long offline period cannot grow memory without limit.
  final List<MeshPacket> _internetQueue = <MeshPacket>[];
  static const int _maxQueue = 500;

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Feed internet-received packets into the existing relay so they are
    // decoded, de-duplicated and delivered exactly like mesh packets.
    _internetInboundSub = _internet.inbound.listen((TransportInbound event) {
      unawaited(_mesh.relay.handleIncoming(
        'internet',
        event.packet.encode(),
      ));
    });

    // Track internet transport state, mirror it into connectivity, and flush
    // the queue when it comes up.
    _internetStatusSub = _internet.statusStream.listen((TransportStatus s) {
      _connectivity.setInternet(switch (s) {
        TransportStatus.connected => LinkState.connected,
        TransportStatus.connecting => LinkState.connecting,
        TransportStatus.disconnected => LinkState.unavailable,
      });
      if (s == TransportStatus.connected) {
        unawaited(_flushQueue());
      }
    });

    await _internet.start();
  }

  /// Sends a packet over all appropriate transports.
  ///
  /// The [MeshPacket] is the single shared representation across transports.
  /// The mesh send goes through the existing relay; the internet send is
  /// best-effort with queue-on-failure.
  Future<void> send(MeshPacket packet) async {
    // Always attempt mesh (nearby devices, works offline). This uses the
    // existing routing engine unchanged.
    try {
      await _mesh.relay.originate(packet);
    } catch (error) {
      debugPrint('TransportManager: mesh send failed: $error');
    }

    // Also send over the internet when available, else queue it.
    if (_internet.isAvailable) {
      try {
        await _internet.send(packet);
      } catch (error) {
        debugPrint('TransportManager: internet send failed, queueing: $error');
        _enqueue(packet);
      }
    } else {
      _enqueue(packet);
    }
  }

  void _enqueue(MeshPacket packet) {
    // Avoid unbounded growth; drop oldest when full.
    if (_internetQueue.length >= _maxQueue) {
      _internetQueue.removeAt(0);
    }
    _internetQueue.add(packet);
  }

  Future<void> _flushQueue() async {
    if (_internetQueue.isEmpty || !_internet.isAvailable) return;
    final List<MeshPacket> pending = List<MeshPacket>.from(_internetQueue);
    _internetQueue.clear();
    for (final MeshPacket packet in pending) {
      try {
        await _internet.send(packet);
      } catch (error) {
        debugPrint('TransportManager: re-queue on flush failure: $error');
        _enqueue(packet);
      }
    }
  }

  int get queuedCount => _internetQueue.length;

  Future<void> dispose() async {
    await _internetInboundSub?.cancel();
    await _internetStatusSub?.cancel();
    // Note: the InternetTransport lifecycle is owned by its provider
    // (internetTransportProvider), which disposes it. We only cancel our
    // subscriptions here to avoid a double-dispose.
  }
}
