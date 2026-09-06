import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/repository.dart';
import '../../models/message_models.dart';

/// Data-layer access point for conversations and their message threads.
abstract interface class MessageRepository
    implements ReadableRepository<Conversation> {
  /// Synchronous seed of conversations used by controllers.
  List<Conversation> get conversationSeed;

  /// Synchronous seed of message threads keyed by conversation id.
  Map<String, List<ChatMessage>> get threadSeed;

  /// Returns the ordered message thread for [conversationId].
  Future<List<ChatMessage>> threadFor(String conversationId);

  /// Returns every thread keyed by conversation id.
  Future<Map<String, List<ChatMessage>>> allThreads();
}

/// Dummy implementation backed by [DummyMessages].
class DummyMessageRepository implements MessageRepository {
  const DummyMessageRepository();

  @override
  String get name => 'DummyMessageRepository';

  @override
  List<Conversation> get conversationSeed => const <Conversation>[];

  @override
  Map<String, List<ChatMessage>> get threadSeed => const <String, List<ChatMessage>>{};

  @override
  Future<List<Conversation>> fetchAll() async => const <Conversation>[];

  @override
  Future<Map<String, List<ChatMessage>>> allThreads() async =>
      const <String, List<ChatMessage>>{};

  @override
  Future<List<ChatMessage>> threadFor(String conversationId) async =>
      const <ChatMessage>[];
}

/// Provides the active [MessageRepository] implementation.
final Provider<MessageRepository> messageRepositoryProvider =
    Provider<MessageRepository>((Ref ref) => const DummyMessageRepository());
