import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../messaging/models/mesh_packet.dart';
import 'routing_cache.dart';

/// The result of the relay processing an inbound packet, surfaced for the UI
/// and diagnostics (e.g. the packet log).
class RelayOutcome {
  const RelayOutcome({
    required this.packet,
    required this.deliveredLocally,
    required this.forwardedTo,
    required this.dropped,
    required this.dropReason,
  });

  final MeshPacket packet;

  /// Whether this packet was addressed to this device (or broadcast) and so was
  /// delivered up to the messaging layer.
  final bool deliveredLocally;

  /// Endpoint ids this packet was forwarded to (empty if not forwarded).
  final List<String> forwardedTo;

  /// Whether the packet was dropped without delivery or forwarding.
  final bool dropped;

  /// Human-readable reason when [dropped] is true (duplicate, ttl, etc.).
  final String? dropReason;

  bool get wasForwarded => forwardedTo.isNotEmpty;
}

/// Implements the store-and-forward logic of the multi-hop mesh.
///
/// For every packet received from a directly connected neighbour it:
///  1. drops duplicates (already-seen UUID) to prevent loops and floods,
///  2. learns a route hint back toward the sender,
///  3. delivers locally if addressed to this device or broadcast,
///  4. forwards onward (TTL-1, hop+1) to other neighbours if the packet still
///     has life and is not solely for this device.
///
/// It is transport-agnostic: it is given the current neighbour list and a
/// send function, so it never imports the Nearby plugin directly.
class RelayService {
  RelayService({
    required this.localDeviceId,
    required List<String> Function() connectedEndpoints,
    required Future<void> Function(String endpointId, List<int> bytes) sendBytes,
    RoutingCache? cache,
  })  : _connectedEndpoints = connectedEndpoints,
        _sendBytes = sendBytes,
        _cache = cache ?? RoutingCache();

  final String localDeviceId;
  final List<String> Function() _connectedEndpoints;
  final Future<void> Function(String endpointId, List<int> bytes) _sendBytes;
  final RoutingCache _cache;

  RoutingCache get cache => _cache;

  final StreamController<RelayOutcome> _outcomes =
      StreamController<RelayOutcome>.broadcast();

  /// Stream of relay outcomes for diagnostics / packet log.
  Stream<RelayOutcome> get outcomes => _outcomes.stream;

  final StreamController<MeshPacket> _localDeliveries =
      StreamController<MeshPacket>.broadcast();

  /// Packets addressed to this device (or broadcast), delivered up to the app.
  Stream<MeshPacket> get localDeliveries => _localDeliveries.stream;

  /// Originates a new [packet] from this device and floods it to all
  /// neighbours (the mesh finds the path to the destination).
  Future<MeshPacket> originate(MeshPacket packet) async {
    _cache.markSeen(packet.uuid); // never forward our own packet back.
    final List<String> forwarded =
        await _floodExcept(packet, exceptEndpoint: null);
    _outcomes.add(RelayOutcome(
      packet: packet,
      deliveredLocally: false,
      forwardedTo: forwarded,
      dropped: false,
      dropReason: null,
    ));
    return packet;
  }

  /// Handles a packet [bytes] received from directly connected [fromEndpoint].
  Future<void> handleIncoming(String fromEndpoint, List<int> bytes) async {
    final MeshPacket? packet = MeshPacket.decode(bytes);
    if (packet == null) {
      debugPrint('RelayService: dropped malformed packet from $fromEndpoint');
      return;
    }

    // Duplicate detection — the core of loop prevention. If we've seen this
    // UUID before, drop it entirely.
    final bool duplicate = _cache.markSeen(packet.uuid);
    if (duplicate) {
      _outcomes.add(RelayOutcome(
        packet: packet,
        deliveredLocally: false,
        forwardedTo: const <String>[],
        dropped: true,
        dropReason: 'duplicate',
      ));
      return;
    }

    // Learn a route back toward the origin via the neighbour we heard it from.
    _cache.learnRoute(packet.senderId, fromEndpoint);

    final bool forMe =
        packet.destinationId == localDeviceId || packet.isBroadcast;

    if (forMe) {
      _localDeliveries.add(packet);
    }

    // Decide whether to forward. A packet is forwarded if it still has TTL and
    // it is either broadcast or not solely addressed to this device.
    final bool shouldForward = packet.canForward &&
        (packet.isBroadcast || packet.destinationId != localDeviceId);

    List<String> forwardedTo = const <String>[];
    if (shouldForward) {
      final MeshPacket next = packet.relayedThrough(localDeviceId);
      forwardedTo = await _floodExcept(next, exceptEndpoint: fromEndpoint);
    }

    _outcomes.add(RelayOutcome(
      packet: packet,
      deliveredLocally: forMe,
      forwardedTo: forwardedTo,
      dropped: !forMe && forwardedTo.isEmpty,
      dropReason: !forMe && forwardedTo.isEmpty
          ? (packet.canForward ? 'no neighbours' : 'ttl expired')
          : null,
    ));
  }

  /// Sends [packet] to every connected neighbour except [exceptEndpoint]
  /// (the one we received it from) and any endpoint already on the path.
  Future<List<String>> _floodExcept(
    MeshPacket packet, {
    required String? exceptEndpoint,
  }) async {
    final List<String> targets = <String>[];
    final List<int> bytes = packet.encode();

    for (final String endpoint in _connectedEndpoints()) {
      if (endpoint == exceptEndpoint) continue;
      try {
        await _sendBytes(endpoint, bytes);
        targets.add(endpoint);
      } catch (error) {
        debugPrint('RelayService: forward to $endpoint failed: $error');
      }
    }
    return targets;
  }

  /// Notifies the cache that a neighbour disconnected so stale routes drop.
  void onEndpointDisconnected(String endpointId) {
    _cache.forgetEndpoint(endpointId);
  }

  Future<void> dispose() async {
    await _outcomes.close();
    await _localDeliveries.close();
  }
}
