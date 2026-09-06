import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/data/device_identity.dart';
import '../../authentication/models/app_user.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../iot/models/nearby_connection_state.dart';
import '../../iot/providers/nearby_provider.dart';
import '../data/repositories/chat_repository.dart';
import '../data/transport/nearby_transport.dart';
import '../data/manager/transport_manager_provider.dart';
import '../models/mesh_packet.dart';
import '../models/message_models.dart';
import '../models/message_packet.dart';
import 'nearby_chat_provider.dart';

/// State for the mesh-wide community chat.
class CommunityChatState {
  const CommunityChatState({
    this.messages = const <ChatMessage>[],
    this.isLoading = true,
    this.connectedCount = 0,
  });

  final List<ChatMessage> messages;
  final bool isLoading;

  /// Number of directly connected devices (for the header).
  final int connectedCount;

  bool get isConnected => connectedCount > 0;

  /// Unread messages from others on this device (local-only read tracking).
  int get unreadCount =>
      messages.where((ChatMessage m) => !m.isMine && !m.isRead).length;

  /// Messages pinned as announcements, most recent first.
  List<ChatMessage> get pinnedMessages =>
      messages.where((ChatMessage m) => m.isPinned).toList().reversed.toList();

  CommunityChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    int? connectedCount,
  }) {
    return CommunityChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      connectedCount: connectedCount ?? this.connectedCount,
    );
  }
}

/// Drives the community chat: a single shared thread broadcast across the whole
/// mesh. Any connected device can post, every device receives it (relayed
/// multi-hop), and messages are persisted locally so they survive restarts.
class CommunityChatController extends StateNotifier<CommunityChatState> {
  CommunityChatController(this._ref, {String? conversationId})
      : _conversationId =
            conversationId ?? ChatRepository.communityConversationId,
        super(const CommunityChatState()) {
    _init();
  }

  final Ref _ref;

  final String _conversationId;

  StreamSubscription<IncomingPacket>? _incomingSub;
  int _counter = 0;

  ChatRepository get _repository => _ref.read(chatRepositoryProvider);
  NearbyTransport get _transport => _ref.read(nearbyTransportProvider);
  String get _localDeviceId => _ref.read(deviceIdProvider);
  AppUser get _me => _ref.read(currentUserProvider);

  Future<void> _init() async {
    _incomingSub = _transport.incoming.listen(_onIncoming);
    _updateConnectedCount();
    _ref.listen(nearbyProvider, (_, __) => _updateConnectedCount());
    await _load();
  }

  void _updateConnectedCount() {
    final NearbyConnectionState nearby = _ref.read(nearbyProvider);
    final int count = nearby.connectedDevices.length;
    if (count != state.connectedCount) {
      state = state.copyWith(connectedCount: count);
    }
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    final List<ChatMessage> history =
        await _repository.messagesFor(_conversationId);
    state = state.copyWith(messages: history, isLoading: false);
  }

  /// Sends a community message to the whole mesh, optionally as a reply to
  /// [replyTo].
  Future<void> send(String text, {ChatMessage? replyTo}) async {
    final String body = text.trim();
    if (body.isEmpty) return;

    String? replyPreview;
    if (replyTo != null) {
      final String snippet = replyTo.body.length > 80
          ? '${replyTo.body.substring(0, 80)}…'
          : replyTo.body;
      replyPreview = snippet;
    }

    final ChatMessage message = ChatMessage(
      id: 'community-${_localDeviceId}-${DateTime.now().millisecondsSinceEpoch}-${_counter++}',
      conversationId: _conversationId,
      senderName: _me.fullName,
      body: body,
      sentAt: DateTime.now(),
      isMine: true,
      status: DeliveryStatus.sending,
      priority: PriorityLevel.normal,
      transport: LinkMode.mesh,
      senderRole: _me.role,
      replyToId: replyTo?.id,
      replyToName: replyTo?.senderName,
      replyToPreview: replyPreview,
      isRead: true, // own messages are read by definition
    );

    await _repository.saveMessage(message);
    _append(message);

    try {
      // Send over all available transports (mesh + internet) via the manager,
      // using the same broadcast packet. The mesh path is unchanged; the
      // internet path carries it to users on other networks when connected.
      final MeshPacket packet = _transport.broadcastPacketFor(message);
      await _ref.read(transportManagerProvider).send(packet);
      await _setStatus(message.id, DeliveryStatus.delivered);
    } catch (error) {
      debugPrint('CommunityChat: send failed: $error');
      await _setStatus(message.id, DeliveryStatus.failed);
    }
  }

  /// Marks every message as read on this device (local-only; not transmitted).
  void markAllRead() {
    if (state.messages.every((ChatMessage m) => m.isRead)) return;
    state = state.copyWith(
      messages: state.messages
          .map((ChatMessage m) => m.isRead ? m : m.copyWith(isRead: true))
          .toList(),
    );
  }

  /// Toggles the pinned state of a message (local-only announcement pin).
  void togglePin(String messageId) {
    state = state.copyWith(
      messages: state.messages
          .map((ChatMessage m) =>
              m.id == messageId ? m.copyWith(isPinned: !m.isPinned) : m)
          .toList(),
    );
  }

  Future<void> _onIncoming(IncomingPacket incoming) async {
    final MessagePacket packet = incoming.packet;

    // Only handle community-tagged chat messages (not peer chats or acks).
    if (packet.kind != PacketKind.message) return;
    if (packet.conversationId != _conversationId) return;

    // Ignore our own broadcast echoed back, and drop duplicates.
    if (incoming.originId == _localDeviceId) return;
    if (await _repository.exists(packet.messageId)) return;

    final ChatMessage message = packet.toIncomingMessage(
      _conversationId,
      hopCount: incoming.hopCount,
      wasRelayed: incoming.wasRelayed,
      meshPath: incoming.path,
    );
    await _repository.saveMessage(message);
    _append(message);
  }

  Future<void> _setStatus(String id, DeliveryStatus status) async {
    await _repository.updateStatus(id, status);
    state = state.copyWith(
      messages: <ChatMessage>[
        for (final ChatMessage m in state.messages)
          if (m.id == id) m.copyWith(status: status) else m,
      ],
    );
  }

  void _append(ChatMessage message) {
    state = state.copyWith(
      messages: <ChatMessage>[...state.messages, message],
    );
  }

  Future<void> clear() async {
    await _repository.clearConversation(_conversationId);
    state = state.copyWith(messages: const <ChatMessage>[]);
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<CommunityChatController, CommunityChatState>
    communityChatProvider =
    StateNotifierProvider<CommunityChatController, CommunityChatState>(
  (Ref ref) => CommunityChatController(ref),
);

/// The resident's area (barangay + purok) group chat. Reuses the community chat
/// controller and the existing mesh broadcast + conversationId filtering, scoped
/// to an area-specific conversation id, so no separate networking is introduced.
final StateNotifierProvider<CommunityChatController, CommunityChatState>
    areaChatProvider =
    StateNotifierProvider<CommunityChatController, CommunityChatState>(
  (Ref ref) {
    // Read the user null-safely: this provider may be instantiated before the
    // user logs in (e.g. while a pre-login screen warms up). When there is no
    // user yet, fall back to an unscoped controller instead of throwing.
    final AppUser? user = ref.watch(currentUserOrNullProvider);
    if (user == null) {
      return CommunityChatController(ref);
    }
    return CommunityChatController(
      ref,
      conversationId:
          ChatRepository.areaConversationId(user.barangay, user.purok),
    );
  },
);
