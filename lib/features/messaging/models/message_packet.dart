import 'dart:convert';

import '../../../core/constants/app_enums.dart';
import 'message_models.dart';

/// The serialisable envelope exchanged between two connected devices.
///
/// A [MessagePacket] is what actually travels across the Nearby Connections
/// link as bytes. It is deliberately small and self-describing so the receiver
/// can reconstruct a [ChatMessage] without any shared state beyond the app
/// itself. Phase 3 carries plain text chat; the [kind] field leaves room for
/// acknowledgements and future payload types.
enum PacketKind {
  /// A chat message.
  message,

  /// A delivery acknowledgement for a previously received message.
  ack,
}

class MessagePacket {
  const MessagePacket({
    required this.kind,
    required this.messageId,
    required this.senderName,
    required this.body,
    required this.sentAt,
    required this.priority,
    this.conversationId,
    this.senderRole,
    this.replyToId,
    this.replyToName,
    this.replyToPreview,
  });

  /// Wire protocol version, bumped if the format changes.
  static const int protocolVersion = 1;

  final PacketKind kind;
  final String messageId;
  final String senderName;
  final String body;
  final DateTime sentAt;
  final PriorityLevel priority;
  final String? conversationId;

  /// Sender's role, carried so group contexts (community chat) can show it.
  final UserRole? senderRole;

  /// If this message is a reply, the id of the message being replied to, plus a
  /// short preview (sender + text snippet) so the quote renders even if the
  /// original has not reached this device. All optional and null for normal
  /// messages, so older packets remain compatible.
  final String? replyToId;
  final String? replyToName;
  final String? replyToPreview;

  /// Builds a message packet from a locally composed [ChatMessage].
  factory MessagePacket.fromMessage(ChatMessage message) {
    return MessagePacket(
      kind: PacketKind.message,
      messageId: message.id,
      senderName: message.senderName,
      body: message.body,
      sentAt: message.sentAt,
      priority: message.priority,
      conversationId: message.conversationId,
      senderRole: message.senderRole,
      replyToId: message.replyToId,
      replyToName: message.replyToName,
      replyToPreview: message.replyToPreview,
    );
  }

  /// Builds an acknowledgement packet for a received [messageId].
  factory MessagePacket.ack({
    required String messageId,
    required String senderName,
  }) {
    return MessagePacket(
      kind: PacketKind.ack,
      messageId: messageId,
      senderName: senderName,
      body: '',
      sentAt: DateTime.now(),
      priority: PriorityLevel.normal,
    );
  }

  /// Converts an inbound packet into a persisted [ChatMessage].
  ///
  /// [conversationId] is supplied by the transport (the local conversation key
  /// for the connected endpoint), and [isMine] is always false for received
  /// messages.
  ChatMessage toIncomingMessage(
    String conversationId, {
    int hopCount = 0,
    bool wasRelayed = false,
    List<String> meshPath = const <String>[],
  }) {
    return ChatMessage(
      id: messageId,
      conversationId: conversationId,
      senderName: senderName,
      body: body,
      sentAt: sentAt,
      isMine: false,
      status: DeliveryStatus.delivered,
      priority: priority,
      transport: LinkMode.mesh,
      hopCount: hopCount,
      wasRelayed: wasRelayed,
      meshPath: meshPath,
      senderRole: senderRole,
      replyToId: replyToId,
      replyToName: replyToName,
      replyToPreview: replyToPreview,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': protocolVersion,
        'kind': kind.name,
        'messageId': messageId,
        'senderName': senderName,
        'body': body,
        'sentAt': sentAt.millisecondsSinceEpoch,
        'priority': priority.name,
        'conversationId': conversationId,
        'senderRole': senderRole?.name,
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToName != null) 'replyToName': replyToName,
        if (replyToPreview != null) 'replyToPreview': replyToPreview,
      };

  factory MessagePacket.fromJson(Map<String, dynamic> json) {
    return MessagePacket(
      kind: PacketKind.values.byName(json['kind'] as String),
      messageId: json['messageId'] as String,
      senderName: json['senderName'] as String,
      body: json['body'] as String? ?? '',
      sentAt: DateTime.fromMillisecondsSinceEpoch(json['sentAt'] as int),
      priority: PriorityLevel.values.byName(json['priority'] as String),
      conversationId: json['conversationId'] as String?,
      senderRole: json['senderRole'] is String
          ? UserRole.values.byName(json['senderRole'] as String)
          : null,
      replyToId: json['replyToId'] as String?,
      replyToName: json['replyToName'] as String?,
      replyToPreview: json['replyToPreview'] as String?,
    );
  }

  /// Encodes the packet to a UTF-8 byte list for transmission.
  List<int> encode() => utf8.encode(jsonEncode(toJson()));

  /// Decodes a received byte list back into a packet, or `null` if malformed.
  static MessagePacket? decode(List<int> bytes) {
    try {
      final Object? decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) {
        return MessagePacket.fromJson(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
