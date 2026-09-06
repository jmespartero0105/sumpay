import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../iot/data/mesh/relay_service.dart';
import '../../../iot/data/mesh/mesh_membership.dart';
import '../../../iot/data/services/nearby_service.dart';
import '../../models/mesh_packet.dart';
import '../../models/message_models.dart';
import '../../models/message_packet.dart';
import '../../../sos/models/sos_packet.dart';
import '../../../broadcast/models/broadcast_packet.dart';

/// An inbound application message delivered to this device by the mesh, together
/// with the routing metadata needed to display hop count, relay status and the
/// An SOS packet delivered to this device from across the mesh.
class IncomingSos {
  const IncomingSos({
    required this.sos,
    required this.originId,
    required this.hopCount,
    required this.wasRelayed,
    required this.path,
  });

  final SosPacket sos;
  final String originId;
  final int hopCount;
  final bool wasRelayed;
  final List<String> path;
}

/// packet path.
class IncomingPacket {
  const IncomingPacket({
    required this.originId,
    required this.packet,
    required this.hopCount,
    required this.wasRelayed,
    required this.path,
  });

  /// Device id of the original sender (not necessarily a direct neighbour).
  final String originId;

  /// The decoded application-level message packet.
  final MessagePacket packet;

  /// Number of hops this packet travelled to reach us.
  final int hopCount;

  /// Whether the packet was relayed by at least one intermediate node.
  final bool wasRelayed;

  /// Ordered device-id path the packet travelled, origin first.
  final List<String> path;
}

/// Bridges the raw byte transport ([NearbyService]) and the typed messaging
/// layer, routing everything through the multi-hop mesh ([RelayService]).
///
/// Outgoing messages are wrapped in a [MeshPacket] addressed to the peer's
/// device id and flooded into the mesh; the relay handles forwarding and
/// duplicate suppression. Incoming packets addressed to this device are decoded
/// back into [MessagePacket]s and surfaced on [incoming].
class NearbyTransport {
  NearbyTransport(this._service, {required this.localDeviceId}) {
    _relay = RelayService(
      localDeviceId: localDeviceId,
      connectedEndpoints: () => _connectedEndpoints.toList(),
      sendBytes: _service.sendBytes,
    );
    _payloadSub = _service.onPayloadReceived.listen(_onRawPayload);
    _deliverySub = _relay.localDeliveries.listen(_onLocalDelivery);
  }

  final NearbyService _service;
  final String localDeviceId;

  late final RelayService _relay;
  late final StreamSubscription<ReceivedPayload> _payloadSub;
  late final StreamSubscription<MeshPacket> _deliverySub;

  /// Directly connected neighbour endpoints (Nearby endpoint ids).
  final Set<String> _connectedEndpoints = <String>{};

  /// Maps a peer device id -> the endpoint we can reach it through directly.
  /// Learned from the hello handshake; used only for diagnostics since the mesh
  /// itself floods rather than requiring a direct endpoint.
  final Map<String, String> _deviceToEndpoint = <String, String>{};

  /// Maps a direct endpoint -> that neighbour's device id, learned from hello.
  final Map<String, String> _endpointToDevice = <String, String>{};

  /// Verifies mesh membership on handshake; admits only genuine SUMPAY devices.
  final MembershipVerifier _membership = MembershipVerifier();

  final StreamController<IncomingPacket> _incomingController =
      StreamController<IncomingPacket>.broadcast();

  final StreamController<IncomingSos> _incomingSosController =
      StreamController<IncomingSos>.broadcast();

  final StreamController<BroadcastPacket> _incomingBroadcastController =
      StreamController<BroadcastPacket>.broadcast();

  final StreamController<BroadcastAckPacket> _incomingBroadcastAckController =
      StreamController<BroadcastAckPacket>.broadcast();

  /// Stream of application messages addressed to (or broadcast to) this device.
  Stream<IncomingPacket> get incoming => _incomingController.stream;

  /// Stream of SOS packets delivered from across the mesh.
  Stream<IncomingSos> get incomingSos => _incomingSosController.stream;

  /// Stream of official broadcasts (evacuation notices / emergency alerts)
  /// received from across the network.
  Stream<BroadcastPacket> get incomingBroadcast =>
      _incomingBroadcastController.stream;

  /// Stream of broadcast delivery acknowledgements received from other devices,
  /// used by the issuing official to count reach.
  Stream<BroadcastAckPacket> get incomingBroadcastAck =>
      _incomingBroadcastAckController.stream;

  /// Relay diagnostics stream (outcomes per processed packet).
  Stream<RelayOutcome> get relayOutcomes => _relay.outcomes;

  RelayService get relay => _relay;

  /// Registers a newly connected neighbour and exchanges device ids so both
  /// ends can address each other across the mesh.
  Future<void> onEndpointConnected(String endpointId) async {
    _connectedEndpoints.add(endpointId);
    await _sendHello(endpointId);
  }

  /// Removes a disconnected neighbour and clears its learned routes.
  void onEndpointDisconnected(String endpointId) {
    _connectedEndpoints.remove(endpointId);
    final String? deviceId = _endpointToDevice.remove(endpointId);
    if (deviceId != null) {
      _deviceToEndpoint.remove(deviceId);
      _membership.release(deviceId);
    }
    _relay.onEndpointDisconnected(endpointId);
  }

  /// Broadcasts an SOS acknowledgement / status update across the mesh at the
  /// SOS's priority, so responders' and officials' updates reach the resident
  /// and other nodes. Reuses the emergency priority so it outranks chat.
  Future<void> sendSosUpdate(SosPacket update) async {
    await _relay.originate(MeshPacket.origin(
      senderId: localDeviceId,
      destinationId: kMeshBroadcastDestination,
      payload: update.encode(),
      priority: update.priority,
      transport: LinkMode.mesh,
    ));
  }

  /// Builds the broadcast [MeshPacket] for an SOS [update] without sending it,
  /// so the transport manager can route it over both mesh and internet — the
  /// same pattern used for community-chat broadcasts. This lets SOS reach
  /// responders/officials on other networks, not just physically-nearby peers.
  MeshPacket sosPacketFor(SosPacket update) {
    return MeshPacket.origin(
      senderId: localDeviceId,
      destinationId: kMeshBroadcastDestination,
      payload: update.encode(),
      priority: update.priority,
      transport: LinkMode.mesh,
    );
  }

  /// Sends an official [broadcast] (evacuation notice / emergency alert) to the
  /// whole network. Uses the broadcast destination and the relay's originate
  /// path, so it reaches every connected device over mesh and, when available,
  /// the internet gateway — the same reach as SOS updates.
  Future<void> sendBroadcast(BroadcastPacket broadcast) async {
    await _relay.originate(MeshPacket.origin(
      senderId: localDeviceId,
      destinationId: kMeshBroadcastDestination,
      payload: broadcast.encode(),
      priority: broadcast.priority,
      transport: LinkMode.mesh,
    ));
  }

  /// Sends a delivery acknowledgement for a received broadcast back to the
  /// network, so the issuing official can count how many devices were reached.
  Future<void> sendBroadcastAck(BroadcastAckPacket ack) async {
    await _relay.originate(MeshPacket.origin(
      senderId: localDeviceId,
      destinationId: kMeshBroadcastDestination,
      payload: ack.encode(),
      priority: PriorityLevel.low,
      transport: LinkMode.mesh,
    ));
  }

  /// Sends [message] to the whole mesh as a community-chat broadcast.
  ///
  /// Uses the broadcast destination so every connected device delivers it
  /// Builds the broadcast [MeshPacket] for [message] without sending it, so a
  /// caller (the transport manager) can route it over multiple transports.
  MeshPacket broadcastPacketFor(ChatMessage message) {
    final MessagePacket app = MessagePacket.fromMessage(message);
    return MeshPacket.origin(
      senderId: localDeviceId,
      destinationId: kMeshBroadcastDestination,
      payload: String.fromCharCodes(app.encode()),
      priority: message.priority,
      transport: message.transport,
    );
  }

  /// locally and relays it onward. No acknowledgement is expected, since this
  /// is one-to-many rather than a directed message.
  Future<void> sendBroadcastMessage(ChatMessage message) async {
    final MessagePacket app = MessagePacket.fromMessage(message);
    await _relay.originate(MeshPacket.origin(
      senderId: localDeviceId,
      destinationId: kMeshBroadcastDestination,
      payload: String.fromCharCodes(app.encode()),
      priority: message.priority,
      transport: message.transport,
    ));
  }

  /// Sends [message] toward [destinationDeviceId] across the mesh.
  Future<void> sendMessage(
    String destinationDeviceId,
    ChatMessage message,
  ) async {
    final MessagePacket app = MessagePacket.fromMessage(message);
    await _relay.originate(MeshPacket.origin(
      senderId: localDeviceId,
      destinationId: destinationDeviceId,
      payload: String.fromCharCodes(app.encode()),
      priority: message.priority,
      transport: message.transport,
    ));
  }

  /// Sends a delivery acknowledgement toward [destinationDeviceId].
  Future<void> sendAck(
    String destinationDeviceId, {
    required String messageId,
    required String senderName,
  }) async {
    final MessagePacket ack = MessagePacket.ack(
      messageId: messageId,
      senderName: senderName,
    );
    await _relay.originate(MeshPacket.origin(
      senderId: localDeviceId,
      destinationId: destinationDeviceId,
      payload: String.fromCharCodes(ack.encode()),
    ));
  }

  // ---------------------------------------------------------------------------
  // Internal handling
  // ---------------------------------------------------------------------------

  Future<void> _onRawPayload(ReceivedPayload payload) async {
    // A hello handshake is a bare mesh packet whose app payload is a control
    // message; detect it before the relay so we can learn the device mapping.
    final MeshPacket? probe = MeshPacket.decode(payload.bytes);
    if (probe != null && _tryHandleHello(payload.endpointId, probe)) {
      return;
    }
    await _relay.handleIncoming(payload.endpointId, payload.bytes);
  }

  void _onLocalDelivery(MeshPacket packet) {
    // An SOS payload is delivered on its own stream so responders/officials can
    // handle emergencies separately from chat. Try SOS first.
    final SosPacket? sos = SosPacket.tryDecode(packet.payload);
    if (sos != null) {
      _incomingSosController.add(IncomingSos(
        sos: sos,
        originId: packet.senderId,
        hopCount: packet.hopCount,
        wasRelayed: packet.wasRelayed,
        path: packet.path,
      ));
      return;
    }

    // A broadcast delivery acknowledgement is surfaced on its own stream, ahead
    // of the broadcast decode (the ack marker is more specific).
    final BroadcastAckPacket? brdAck =
        BroadcastAckPacket.tryDecode(packet.payload);
    if (brdAck != null) {
      _incomingBroadcastAckController.add(brdAck);
      return;
    }

    // A broadcast payload (official evacuation notice / emergency alert) is
    // surfaced on its own stream, before chat decoding.
    final BroadcastPacket? broadcast =
        BroadcastPacket.tryDecode(packet.payload);
    if (broadcast != null) {
      _incomingBroadcastController.add(broadcast);
      return;
    }

    final MessagePacket? app =
        MessagePacket.decode(packet.payload.codeUnits);
    if (app == null) {
      debugPrint('NearbyTransport: undecodable app payload from '
          '${packet.senderId}');
      return;
    }
    _incomingController.add(IncomingPacket(
      originId: packet.senderId,
      packet: app,
      hopCount: packet.hopCount,
      wasRelayed: packet.wasRelayed,
      path: packet.path,
    ));
  }

  // --- Hello handshake: exchange device ids with a direct neighbour ---------

  static const String _helloSender = '__hello__';

  Future<void> _sendHello(String endpointId) async {
    final MeshHandshake handshake = MeshHandshake.local(
      deviceId: localDeviceId,
      appVersion: AppConstants.appVersion,
    );
    final MeshPacket hello = MeshPacket(
      uuid: 'hello-$localDeviceId-$endpointId',
      senderId: _helloSender,
      destinationId: _helloSender,
      hopCount: 0,
      ttl: 1,
      priority: PriorityLevel.low,
      timestamp: DateTime.now(),
      payload: handshake.encode(),
      transport: LinkMode.mesh,
      path: <String>[localDeviceId],
    );
    try {
      await _service.sendBytes(endpointId, hello.encode());
    } catch (error) {
      debugPrint('NearbyTransport: hello to $endpointId failed: $error');
    }
  }

  bool _tryHandleHello(String endpointId, MeshPacket packet) {
    if (packet.senderId != _helloSender) return false;

    // Verify mesh membership before admitting the peer. Unknown applications,
    // wrong mesh id, incompatible versions, invalid handshakes, and duplicate
    // devices are rejected (debug-logged) and the endpoint is disconnected.
    final MembershipResult result =
        _membership.verify(endpointId, packet.payload);
    if (!result.isAccepted) {
      // Drop the link to a non-member; do not learn any route from it.
      unawaited(_service.disconnect(endpointId));
      _connectedEndpoints.remove(endpointId);
      return true;
    }

    final String peerDeviceId = result.handshake!.deviceId;
    _endpointToDevice[endpointId] = peerDeviceId;
    _deviceToEndpoint[peerDeviceId] = endpointId;
    _relay.cache.learnRoute(peerDeviceId, endpointId);
    debugPrint('NearbyTransport: hello — endpoint $endpointId is '
        'device $peerDeviceId');
    return true;
  }

  /// The device id of a directly connected neighbour, if known.
  String? deviceIdForEndpoint(String endpointId) =>
      _endpointToDevice[endpointId];

  Future<void> dispose() async {
    await _payloadSub.cancel();
    await _deliverySub.cancel();
    await _relay.dispose();
    await _incomingController.close();
    await _incomingSosController.close();
    await _incomingBroadcastController.close();
    await _incomingBroadcastAckController.close();
  }
}
