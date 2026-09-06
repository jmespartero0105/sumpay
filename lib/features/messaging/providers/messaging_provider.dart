import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../iot/providers/network_provider.dart';
import '../data/repositories/message_repository.dart';
import '../models/message_models.dart';

/// Holds the conversation list.
class ConversationController extends StateNotifier<List<Conversation>> {
  ConversationController(MessageRepository repository)
      : super(repository.conversationSeed);

  void markRead(String conversationId) {
    state = state
        .map((Conversation c) =>
            c.id == conversationId ? c.copyWith(unreadCount: 0) : c)
        .toList();
  }

  void bumpWithMessage(String conversationId, String body) {
    state = <Conversation>[
      ...state.map((Conversation c) => c.id == conversationId
          ? c.copyWith(
              lastMessage: body,
              lastActivity: DateTime.now(),
              unreadCount: 0,
            )
          : c),
    ]..sort((Conversation a, Conversation b) =>
        b.lastActivity.compareTo(a.lastActivity));
  }
}

final StateNotifierProvider<ConversationController, List<Conversation>>
    conversationsProvider =
    StateNotifierProvider<ConversationController, List<Conversation>>(
  (Ref ref) => ConversationController(ref.watch(messageRepositoryProvider)),
);

final Provider<int> unreadMessageCountProvider = Provider<int>((Ref ref) {
  return ref.watch(conversationsProvider).fold<int>(
        0,
        (int sum, Conversation c) => sum + c.unreadCount,
      );
});

final conversationByIdProvider =
    Provider.family<Conversation?, String>((Ref ref, String id) {
  final List<Conversation> all = ref.watch(conversationsProvider);
  for (final Conversation c in all) {
    if (c.id == id) return c;
  }
  return null;
});

/// Holds every message thread, keyed by conversation id.
class ThreadController extends StateNotifier<Map<String, List<ChatMessage>>> {
  ThreadController(this._ref)
      : super(_ref.read(messageRepositoryProvider).threadSeed);

  final Ref _ref;

  int _counter = 0;

  /// Appends an outgoing message and simulates mesh acknowledgement.
  Future<void> send(
    String conversationId,
    String body, {
    PriorityLevel priority = PriorityLevel.normal,
    MessageAttachment? attachment,
  }) async {
    final String trimmed = body.trim();
    if (trimmed.isEmpty && attachment == null) return;

    final LinkMode transport = _ref.read(networkStatusProvider).linkMode;
    final bool offline = transport == LinkMode.offline;
    final String id = 'MSG-LOCAL-${_counter++}';

    final ChatMessage message = ChatMessage(
      id: id,
      conversationId: conversationId,
      senderName: 'You',
      body: trimmed,
      sentAt: DateTime.now(),
      isMine: true,
      status: offline ? DeliveryStatus.queued : DeliveryStatus.sending,
      priority: priority,
      transport: transport,
      attachment: attachment,
    );

    _append(conversationId, message);
    _ref.read(conversationsProvider.notifier).bumpWithMessage(
          conversationId,
          trimmed.isEmpty ? (attachment?.name ?? 'Attachment') : trimmed,
        );

    if (offline) return;

    await Future<void>.delayed(const Duration(milliseconds: 700));
    _updateStatus(conversationId, id, DeliveryStatus.relayed);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _updateStatus(conversationId, id, DeliveryStatus.delivered);
  }

  void _append(String conversationId, ChatMessage message) {
    final Map<String, List<ChatMessage>> next =
        Map<String, List<ChatMessage>>.from(state);
    next[conversationId] = <ChatMessage>[
      ...?next[conversationId],
      message,
    ];
    state = next;
  }

  void _updateStatus(
    String conversationId,
    String messageId,
    DeliveryStatus status,
  ) {
    final List<ChatMessage>? thread = state[conversationId];
    if (thread == null) return;

    final Map<String, List<ChatMessage>> next =
        Map<String, List<ChatMessage>>.from(state);
    next[conversationId] = thread
        .map((ChatMessage m) => m.id == messageId ? m.copyWith(status: status) : m)
        .toList();
    state = next;
  }

  /// Retries every queued message once a transport becomes available.
  void retryQueued() {
    final Map<String, List<ChatMessage>> next =
        Map<String, List<ChatMessage>>.from(state);
    next.updateAll(
      (String key, List<ChatMessage> value) => value
          .map((ChatMessage m) => m.status == DeliveryStatus.queued
              ? m.copyWith(status: DeliveryStatus.delivered)
              : m)
          .toList(),
    );
    state = next;
  }
}

final StateNotifierProvider<ThreadController, Map<String, List<ChatMessage>>>
    threadsProvider =
    StateNotifierProvider<ThreadController, Map<String, List<ChatMessage>>>(
  (Ref ref) => ThreadController(ref),
);

final threadByIdProvider =
    Provider.family<List<ChatMessage>, String>((Ref ref, String id) {
  return ref.watch(threadsProvider)[id] ?? const <ChatMessage>[];
});
