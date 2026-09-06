import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/data/device_identity.dart';
import '../../iot/models/nearby_connection_state.dart';
import '../../iot/models/nearby_device.dart';
import '../../iot/providers/nearby_provider.dart';
import '../data/repositories/chat_repository.dart';
import '../data/transport/nearby_transport.dart';
import '../models/message_models.dart';
import '../models/message_packet.dart';

/// Provides the singleton [NearbyTransport], bridging the Nearby service and
/// the typed messaging layer through the multi-hop mesh relay.
///
/// It also keeps the transport's neighbour set in sync with the Nearby
/// controller: as devices connect and disconnect, the transport learns and
/// forgets direct endpoints (and exchanges device ids via a hello handshake).
final Provider<NearbyTransport> nearbyTransportProvider =
    Provider<NearbyTransport>((Ref ref) {
  final NearbyTransport transport = NearbyTransport(
    ref.watch(nearbyServiceProvider),
    localDeviceId: ref.watch(deviceIdProvider),
  );

  // Keep neighbour set in sync with connection state.
  Set<String> previous = <String>{};
  ref.listen<List<NearbyDevice>>(
    connectedDevicesProvider,
    (List<NearbyDevice>? _, List<NearbyDevice> devices) {
      final Set<String> current =
          devices.map((NearbyDevice d) => d.endpointId).toSet();
      for (final String added in current.difference(previous)) {
        transport.onEndpointConnected(added);
      }
      for (final String removed in previous.difference(current)) {
        transport.onEndpointDisconnected(removed);
      }
      previous = current;
    },
    fireImmediately: true,
  );

  ref.onDispose(transport.dispose);
  return transport;
});

/// Immutable state for a single direct (peer-to-peer) chat.
class NearbyChatState {
  const NearbyChatState({
    this.messages = const <ChatMessage>[],
    this.isLoading = true,
    this.isConnected = false,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isConnected;

  NearbyChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isConnected,
  }) {
    return NearbyChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

/// Orchestrates direct messaging with one connected [endpointId]:
/// loads history from SQLite, sends outgoing messages over Nearby, and appends
/// inbound messages received on the transport stream.
class NearbyChatController extends StateNotifier<NearbyChatState> {
  NearbyChatController(
    this._ref, {
    required this.endpointId,
    required this.localDeviceName,
  }) : super(const NearbyChatState()) {
    _init();
  }

  final Ref _ref;
  final String endpointId;
  final String localDeviceName;

  /// Device id of the peer, resolved from the transport's hello handshake.
  /// Falls back to the endpoint id until the handshake completes.
  String? _peerDeviceId;

  late String _conversationId =
      ChatRepository.conversationIdForEndpoint(endpointId);

  StreamSubscription<IncomingPacket>? _incomingSub;

  String get conversationId => _conversationId;

  /// The mesh destination for outgoing messages: the peer device id once known,
  /// otherwise the endpoint id (direct neighbour) as a fallback.
  String get _destination => _peerDeviceId ?? endpointId;

  int _counter = 0;

  ChatRepository get _repository => _ref.read(chatRepositoryProvider);
  NearbyTransport get _transport => _ref.read(nearbyTransportProvider);

  Future<void> _init() async {
    // Listen for inbound packets on the transport stream.
    _incomingSub = _transport.incoming.listen(_onIncoming);

    // Track live connection status and resolve the peer device id.
    _resolvePeerDevice();
    _updateConnectionStatus();
    _ref.listen(nearbyProvider, (_, __) {
      _resolvePeerDevice();
      _updateConnectionStatus();
    });

    await _load();
  }

  /// Resolves the peer's mesh device id from the transport's hello handshake.
  /// Once known, the conversation is re-keyed to the stable device id so the
  /// thread survives reconnects and multi-hop paths.
  void _resolvePeerDevice() {
    if (_peerDeviceId != null) return;
    final String? resolved = _transport.deviceIdForEndpoint(endpointId);
    if (resolved == null) return;
    _peerDeviceId = resolved;
    final String newConversation =
        ChatRepository.conversationIdForEndpoint(resolved);
    if (newConversation != _conversationId) {
      _conversationId = newConversation;
      _load();
    }
  }

  void _updateConnectionStatus() {
    final NearbyConnectionState nearby = _ref.read(nearbyProvider);
    // Directly connected to this endpoint, or reachable across the mesh while
    // at least one neighbour is connected.
    final bool directNeighbour = nearby.connectedDevices
        .any((NearbyDevice d) => d.endpointId == endpointId);
    final bool meshReachable =
        _peerDeviceId != null && nearby.connectedDevices.isNotEmpty;
    final bool connected = directNeighbour || meshReachable;
    if (connected != state.isConnected) {
      state = state.copyWith(isConnected: connected);
    }
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    final List<ChatMessage> history =
        await _repository.messagesFor(_conversationId);
    state = state.copyWith(messages: history, isLoading: false);
  }

  /// Sends a text message to the connected peer.
  Future<void> send(String body) async {
    final String trimmed = body.trim();
    if (trimmed.isEmpty) return;

    final ChatMessage message = ChatMessage(
      id: 'nearby-${DateTime.now().millisecondsSinceEpoch}-${_counter++}',
      conversationId: _conversationId,
      senderName: localDeviceName,
      body: trimmed,
      sentAt: DateTime.now(),
      isMine: true,
      status: DeliveryStatus.sending,
      priority: PriorityLevel.normal,
      transport: LinkMode.mesh,
    );

    // Optimistically show the message, then persist and transmit.
    _append(message);
    await _repository.saveMessage(message);

    try {
      await _transport.sendMessage(_destination, message);
      await _setStatus(message.id, DeliveryStatus.delivered);
    } catch (error) {
      debugPrint('NearbyChat: send failed: $error');
      await _setStatus(message.id, DeliveryStatus.failed);
    }
  }

  Future<void> _onIncoming(IncomingPacket incoming) async {
    // If we haven't resolved the peer's device id yet, adopt the origin of the
    // first packet that matches this endpoint's neighbour.
    _resolvePeerDevice();

    // Only handle packets originating from the peer this chat is bound to.
    if (_peerDeviceId != null && incoming.originId != _peerDeviceId) return;

    final MessagePacket packet = incoming.packet;

    // Ignore community-chat broadcasts; those belong to the community thread.
    if (packet.conversationId == ChatRepository.communityConversationId) {
      return;
    }

    // Acknowledgement for one of our sent messages.
    if (packet.kind == PacketKind.ack) {
      await _setStatus(packet.messageId, DeliveryStatus.delivered);
      return;
    }

    // A chat message: drop duplicates, persist (with mesh metadata), append,
    // and acknowledge back toward the origin.
    if (await _repository.exists(packet.messageId)) return;

    final ChatMessage message = packet.toIncomingMessage(
      _conversationId,
      hopCount: incoming.hopCount,
      wasRelayed: incoming.wasRelayed,
      meshPath: incoming.path,
    );
    await _repository.saveMessage(message);
    _append(message);

    try {
      await _transport.sendAck(
        incoming.originId,
        messageId: packet.messageId,
        senderName: localDeviceName,
      );
    } catch (error) {
      debugPrint('NearbyChat: ack failed: $error');
    }
  }

  void _append(ChatMessage message) {
    state = state.copyWith(messages: <ChatMessage>[...state.messages, message]);
  }

  Future<void> _setStatus(String messageId, DeliveryStatus status) async {
    await _repository.updateStatus(messageId, status);
    state = state.copyWith(
      messages: state.messages
          .map((ChatMessage m) =>
              m.id == messageId ? m.copyWith(status: status) : m)
          .toList(),
    );
  }

  /// Clears the on-screen and stored history for this conversation.
  Future<void> clearHistory() async {
    await _repository.clearConversation(_conversationId);
    state = state.copyWith(messages: const <ChatMessage>[]);
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    super.dispose();
  }
}

/// Arguments identifying which peer chat to open.
class NearbyChatArgs {
  const NearbyChatArgs({required this.endpointId, required this.deviceName});

  final String endpointId;
  final String deviceName;
}

/// Family provider keyed by endpoint id, so each connected peer has its own
/// independent chat controller and state.
final nearbyChatProvider = StateNotifierProvider.family<NearbyChatController,
    NearbyChatState, NearbyChatArgs>((Ref ref, NearbyChatArgs args) {
  final String localName = ref.read(nearbyProvider).localDeviceName;
  return NearbyChatController(
    ref,
    endpointId: args.endpointId,
    localDeviceName: localName,
  );
});
