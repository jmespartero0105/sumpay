import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/data/app_database.dart';
import '../../../../core/data/database_provider.dart';
import '../../../../core/data/database_schema.dart';
import '../../models/message_models.dart';

/// Persists and retrieves direct chat messages from the local SQLite database.
///
/// This is the persistence half of Phase 3 direct messaging. It owns no
/// transport or UI logic — the provider composes it with [NearbyTransport].
/// Messages are stored in the existing `messages` table (created in Phase 1),
/// keyed by conversation id.
class ChatRepository {
  const ChatRepository(this._db);

  final AppDatabase _db;

  /// Deterministic conversation id for a direct chat with a Nearby endpoint.
  ///
  /// Using a stable prefix keeps direct-chat threads separate from the seeded
  /// demo conversations and lets a reconnecting peer resume the same thread.
  /// Fixed conversation id for the mesh-wide community chat that every
  /// connected device shares.
  static const String communityConversationId = 'community';

  /// Conversation id for a resident's area (barangay + purok) group chat.
  /// Messages tagged with this id are shown only to users in the same area,
  /// reusing the existing mesh broadcast + conversationId filtering (no separate
  /// network). Extensible for future LoRa area-group addressing.
  static String areaConversationId(String barangay, String purok) =>
      'area:${barangay.trim().toLowerCase()}:${purok.trim().toLowerCase()}';

  static String conversationIdForEndpoint(String endpointId) =>
      'nearby:$endpointId';

  /// Inserts or replaces a single message.
  Future<void> saveMessage(ChatMessage message) async {
    if (!_db.isAvailable) return;
    await _db.database.insert(
      DatabaseSchema.tableMessages,
      message.toDbRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates only the delivery status of a stored message.
  Future<void> updateStatus(String messageId, DeliveryStatus status) async {
    if (!_db.isAvailable) return;
    await _db.database.update(
      DatabaseSchema.tableMessages,
      <String, Object?>{'status': status.name},
      where: 'id = ?',
      whereArgs: <Object?>[messageId],
    );
  }

  /// Loads every message for [conversationId], oldest first.
  Future<List<ChatMessage>> messagesFor(String conversationId) async {
    if (!_db.isAvailable) return <ChatMessage>[];
    final List<Map<String, Object?>> rows = await _db.database.query(
      DatabaseSchema.tableMessages,
      where: 'conversation_id = ?',
      whereArgs: <Object?>[conversationId],
      orderBy: 'sent_at ASC',
    );
    return rows.map(ChatMessage.fromDbRow).toList();
  }

  /// Whether a message with [messageId] already exists — used to drop
  /// duplicates when the same packet is received more than once.
  Future<bool> exists(String messageId) async {
    if (!_db.isAvailable) return false;
    final List<Map<String, Object?>> rows = await _db.database.query(
      DatabaseSchema.tableMessages,
      columns: <String>['id'],
      where: 'id = ?',
      whereArgs: <Object?>[messageId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Deletes every message in a conversation.
  Future<void> clearConversation(String conversationId) async {
    await _db.database.delete(
      DatabaseSchema.tableMessages,
      where: 'conversation_id = ?',
      whereArgs: <Object?>[conversationId],
    );
  }
}

/// Provides the [ChatRepository], wired to the initialised database.
final Provider<ChatRepository> chatRepositoryProvider =
    Provider<ChatRepository>((Ref ref) {
  return ChatRepository(ref.watch(appDatabaseProvider));
});
