import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../messaging/data/transport/nearby_transport.dart';
import '../../messaging/data/manager/transport_manager.dart';
import '../../messaging/data/manager/transport_manager_provider.dart';
import '../../messaging/providers/nearby_chat_provider.dart';
import '../data/mesh/relay_service.dart';
import '../data/services/connectivity_service.dart';
import '../../messaging/models/mesh_packet.dart';
import '../models/nearby_connection_state.dart';
import 'nearby_provider.dart';

/// A packet being tracked for reliable delivery by the reliability layer.
///
/// This wraps a [MeshPacket] with the bookkeeping the routing engine itself does
/// not keep: how many send attempts have been made, when the last attempt was,
/// and the current delivery status shown to the user. The routing engine
/// (RelayService/RoutingCache) is not modified; this layer sits around it.
class TrackedPacket {
  TrackedPacket({
    required this.packet,
    this.status = DeliveryStatus.queued,
    this.attempts = 0,
    this.lastAttemptAt,
    this.forwardedTo = const <String>[],
  });

  final MeshPacket packet;
  DeliveryStatus status;
  int attempts;
  DateTime? lastAttemptAt;
  List<String> forwardedTo;

  String get id => packet.uuid;
}

/// Aggregate counts for the reliability indicators (Pending / Forwarded /
/// Delivered / Failed).
class ReliabilityStats {
  const ReliabilityStats({
    this.pending = 0,
    this.forwarded = 0,
    this.delivered = 0,
    this.failed = 0,
  });

  final int pending;
  final int forwarded;
  final int delivered;
  final int failed;

  int get total => pending + forwarded + delivered + failed;
}

/// Adds delivery reliability around the existing mesh routing engine.
///
/// Responsibilities (none of which change the routing architecture):
///  - a packet queue for outgoing packets,
///  - an offline queue: when no peers are connected, packets are held and
///    automatically resent once the mesh is reachable again,
///  - automatic retry/resend with capped backoff on failed attempts,
///  - delivery confirmation: acknowledgements mark a packet delivered, and the
///    relay's own forward outcomes mark it forwarded,
///  - status tracking exposed as Pending / Forwarded / Delivered / Failed.
///
/// The actual sending, duplicate suppression, TTL expiration and hop counting
/// remain the responsibility of the unmodified [MeshPacket] / relay engine; this
/// class only decides *when* to (re)hand a packet to that engine and records the
/// resulting status.
class PacketReliabilityController extends StateNotifier<List<TrackedPacket>> {
  PacketReliabilityController({
    required Future<bool> Function(MeshPacket packet) send,
    required bool Function() hasPeers,
    this.maxAttempts = 5,
    this.retryInterval = const Duration(seconds: 6),
  })  : _send = send,
        _hasPeers = hasPeers,
        super(<TrackedPacket>[]) {
    _ticker = Timer.periodic(retryInterval, (_) => _tick());
  }

  final Future<bool> Function(MeshPacket packet) _send;
  final bool Function() _hasPeers;
  final int maxAttempts;
  final Duration retryInterval;

  Timer? _ticker;

  /// Enqueues [packet] for reliable delivery and attempts a first send.
  Future<void> enqueue(MeshPacket packet) async {
    final TrackedPacket tracked = TrackedPacket(packet: packet);
    state = <TrackedPacket>[...state, tracked];
    await _attempt(tracked);
  }

  /// Marks a packet delivered when its acknowledgement arrives.
  void confirmDelivered(String packetId) {
    _update(packetId, (TrackedPacket t) {
      t.status = DeliveryStatus.delivered;
    });
  }

  /// Marks a packet forwarded when the relay reports it was passed onward.
  void markForwarded(String packetId, List<String> forwardedTo) {
    _update(packetId, (TrackedPacket t) {
      // Delivered is a stronger state than forwarded; don't downgrade.
      if (t.status == DeliveryStatus.delivered) return;
      t.status = DeliveryStatus.relayed;
      t.forwardedTo = forwardedTo;
    });
  }

  /// Called when peers connect, to immediately flush the offline queue.
  void onPeersAvailable() {
    if (!_hasPeers()) return;
    for (final TrackedPacket t in _queuedByPriority()) {
      unawaited(_attempt(t));
    }
  }

  /// Queued packets ordered by descending priority, so emergency (SOS) traffic
  /// is (re)sent before normal messages.
  List<TrackedPacket> _queuedByPriority() {
    final List<TrackedPacket> queued = state
        .where((TrackedPacket t) => t.status == DeliveryStatus.queued)
        .toList();
    queued.sort((TrackedPacket a, TrackedPacket b) =>
        b.packet.priority.index.compareTo(a.packet.priority.index));
    return queued;
  }

  /// Clears delivered/failed packets from the tracked list.
  void clearCompleted() {
    state = state
        .where((TrackedPacket t) =>
            t.status != DeliveryStatus.delivered &&
            t.status != DeliveryStatus.failed)
        .toList();
  }

  ReliabilityStats get stats {
    int pending = 0;
    int forwarded = 0;
    int delivered = 0;
    int failed = 0;
    for (final TrackedPacket t in state) {
      switch (t.status) {
        case DeliveryStatus.queued:
        case DeliveryStatus.sending:
          pending++;
        case DeliveryStatus.relayed:
          forwarded++;
        case DeliveryStatus.delivered:
          delivered++;
        case DeliveryStatus.failed:
          failed++;
      }
    }
    return ReliabilityStats(
      pending: pending,
      forwarded: forwarded,
      delivered: delivered,
      failed: failed,
    );
  }

  // --- internals -------------------------------------------------------------

  Future<void> _attempt(TrackedPacket tracked) async {
    // Offline queue: if there are no peers, keep the packet queued and wait for
    // reconnection (handled by onPeersAvailable / the periodic tick).
    if (!_hasPeers()) {
      _update(tracked.id, (TrackedPacket t) => t.status = DeliveryStatus.queued);
      return;
    }

    _update(tracked.id, (TrackedPacket t) {
      t.status = DeliveryStatus.sending;
      t.attempts += 1;
      t.lastAttemptAt = DateTime.now();
    });

    bool ok;
    try {
      ok = await _send(tracked.packet);
    } catch (error) {
      debugPrint('Reliability: send failed for ${tracked.id}: $error');
      ok = false;
    }

    if (!ok) {
      _update(tracked.id, (TrackedPacket t) {
        if (t.attempts >= maxAttempts) {
          t.status = DeliveryStatus.failed;
        } else {
          t.status = DeliveryStatus.queued; // will be retried by the ticker
        }
      });
    }
    // On success the packet stays 'sending' until a forward outcome or an
    // acknowledgement upgrades it to relayed/delivered.
  }

  /// Periodic retry/resend pass: retries queued packets (offline queue and
  /// failed attempts) with the retry interval acting as backoff.
  void _tick() {
    if (!_hasPeers()) return;
    for (final TrackedPacket t in _queuedByPriority()) {
      if (t.attempts >= maxAttempts) {
        _update(t.id, (TrackedPacket p) => p.status = DeliveryStatus.failed);
        continue;
      }
      unawaited(_attempt(t));
    }
  }

  void _update(String id, void Function(TrackedPacket) mutate) {
    bool changed = false;
    for (final TrackedPacket t in state) {
      if (t.id == id) {
        final DeliveryStatus before = t.status;
        mutate(t);
        if (t.status != before) changed = true;
      }
    }
    // Only emit a new state list when a status actually changed, so steady
    // packets never churn listeners or trigger needless rebuilds.
    if (changed) {
      state = <TrackedPacket>[...state];
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// Wires the reliability controller to the mesh transport and nearby state.
///
/// - send: hands the packet to the unmodified relay engine to originate,
/// - hasPeers: true when at least one device is connected,
/// - forward outcomes from the relay upgrade tracked packets to "forwarded".
final StateNotifierProvider<PacketReliabilityController, List<TrackedPacket>>
    packetReliabilityProvider = StateNotifierProvider<
        PacketReliabilityController, List<TrackedPacket>>((Ref ref) {
  final NearbyTransport transport = ref.watch(nearbyTransportProvider);
  final TransportManager transportManager =
      ref.watch(transportManagerProvider);

  final PacketReliabilityController controller = PacketReliabilityController(
    send: (MeshPacket packet) async {
      // Transport-independent send: the manager delivers over the internet
      // (when connected) and the mesh, sharing one packet and de-duplicating
      // across paths. This replaces the direct mesh-only originate so SOS and
      // messages can travel over whichever path is available.
      await transportManager.send(packet);
      return true;
    },
    // A packet is sendable if EITHER the mesh has peers OR the internet is
    // connected, so an SOS still goes out over the internet with no nearby
    // devices, and over the mesh with no internet.
    hasPeers: () =>
        ref.read(nearbyProvider).connectedDevices.isNotEmpty ||
        ref.read(connectivityProvider).internetConnected,
  );

  // Relay forward outcomes mark tracked packets as forwarded.
  final StreamSubscription<RelayOutcome> outcomeSub =
      transport.relayOutcomes.listen((RelayOutcome outcome) {
    if (outcome.wasForwarded) {
      controller.markForwarded(outcome.packet.uuid, outcome.forwardedTo);
    }
  });

  // Flush the offline queue whenever peers become available.
  ref.listen<NearbyConnectionState>(nearbyProvider, (
    NearbyConnectionState? prev,
    NearbyConnectionState next,
  ) {
    final bool wasEmpty = prev?.connectedDevices.isEmpty ?? true;
    if (wasEmpty && next.connectedDevices.isNotEmpty) {
      controller.onPeersAvailable();
    }
  });

  // Also flush when the internet transitions to connected, so queued SOS and
  // messages go out over the backend as soon as it is reachable.
  ref.listen<ConnectivitySnapshot>(connectivityProvider, (
    ConnectivitySnapshot? prev,
    ConnectivitySnapshot next,
  ) {
    final bool wasDown = !(prev?.internetConnected ?? false);
    if (wasDown && next.internetConnected) {
      controller.onPeersAvailable();
    }
  });

  ref.onDispose(outcomeSub.cancel);
  return controller;
});

/// Aggregate Pending / Forwarded / Delivered / Failed counts for the UI.
final Provider<ReliabilityStats> reliabilityStatsProvider =
    Provider<ReliabilityStats>((Ref ref) {
  ref.watch(packetReliabilityProvider);
  return ref.read(packetReliabilityProvider.notifier).stats;
});
