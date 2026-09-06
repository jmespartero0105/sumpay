import '../../../core/constants/app_enums.dart';

/// Attachment reference carried by a message.
class MessageAttachment {
  const MessageAttachment({
    required this.id,
    required this.name,
    required this.kind,
    required this.sizeLabel,
  });

  final String id;
  final String name;

  /// One of `image`, `voice`, `document`, `location`.
  final String kind;
  final String sizeLabel;

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: json['kind'] as String,
      sizeLabel: json['sizeLabel'] as String,
    );
  }
}

/// A single chat message transported over LoRa or the local mesh.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderName,
    required this.body,
    required this.sentAt,
    required this.isMine,
    required this.status,
    required this.priority,
    required this.transport,
    this.attachment,
    this.hopCount = 0,
    this.wasRelayed = false,
    this.meshPath = const <String>[],
    this.senderRole,
    this.replyToId,
    this.replyToName,
    this.replyToPreview,
    this.isRead = false,
    this.isPinned = false,
  });

  final String id;
  final String conversationId;
  final String senderName;
  final String body;
  final DateTime sentAt;
  final bool isMine;
  final DeliveryStatus status;
  final PriorityLevel priority;
  final LinkMode transport;
  final MessageAttachment? attachment;

  /// Role of the sender, shown in group contexts like the community chat.
  /// Null for older or direct messages where role is not displayed.
  final UserRole? senderRole;

  /// If this message replies to another, the target id and a cached preview
  /// (sender name + text snippet) so the quote renders without needing the
  /// original message present. These travel with the message over the mesh.
  final String? replyToId;
  final String? replyToName;
  final String? replyToPreview;

  /// Local-only: whether this device has read the message. Never transmitted,
  /// so it adds no mesh traffic (read state is per-device by design).
  final bool isRead;

  /// Local-only: whether this message is pinned as an announcement on this
  /// device.
  final bool isPinned;

  /// Number of mesh hops this message travelled (0 for direct / local).
  final int hopCount;

  /// Whether the message was relayed by at least one intermediate node.
  final bool wasRelayed;

  /// Ordered device-id path the message travelled, origin first.
  final List<String> meshPath;

  ChatMessage copyWith({
    String? conversationId,
    String? senderName,
    String? body,
    DateTime? sentAt,
    bool? isMine,
    DeliveryStatus? status,
    PriorityLevel? priority,
    LinkMode? transport,
    MessageAttachment? attachment,
    int? hopCount,
    bool? wasRelayed,
    List<String>? meshPath,
    UserRole? senderRole,
    String? replyToId,
    String? replyToName,
    String? replyToPreview,
    bool? isRead,
    bool? isPinned,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId ?? this.conversationId,
      senderName: senderName ?? this.senderName,
      body: body ?? this.body,
      sentAt: sentAt ?? this.sentAt,
      isMine: isMine ?? this.isMine,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      transport: transport ?? this.transport,
      attachment: attachment ?? this.attachment,
      hopCount: hopCount ?? this.hopCount,
      wasRelayed: wasRelayed ?? this.wasRelayed,
      meshPath: meshPath ?? this.meshPath,
      senderRole: senderRole ?? this.senderRole,
      replyToId: replyToId ?? this.replyToId,
      replyToName: replyToName ?? this.replyToName,
      replyToPreview: replyToPreview ?? this.replyToPreview,
      isRead: isRead ?? this.isRead,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderName: json['senderName'] as String,
      body: json['body'] as String,
      sentAt: DateTime.now().subtract(
        Duration(minutes: json['minutesAgo'] as int),
      ),
      isMine: json['isMine'] as bool,
      status: DeliveryStatus.values.byName(json['status'] as String),
      priority: PriorityLevel.values.byName(json['priority'] as String),
      transport: LinkMode.values.byName(json['transport'] as String),
      attachment: json['attachment'] == null
          ? null
          : MessageAttachment.fromJson(
              json['attachment'] as Map<String, dynamic>,
            ),
    );
  }

  /// Maps to a SQLite row for the `messages` table.
  Map<String, Object?> toDbRow() => <String, Object?>{
        'id': id,
        'conversation_id': conversationId,
        'sender_name': senderName,
        'body': body,
        'sent_at': sentAt.millisecondsSinceEpoch,
        'is_mine': isMine ? 1 : 0,
        'status': status.name,
        'priority': priority.name,
        'transport': transport.name,
        'attachment': attachment == null
            ? null
            : '${attachment!.id}|${attachment!.kind}|${attachment!.name}|${attachment!.sizeLabel}',
        'hop_count': hopCount,
        'was_relayed': wasRelayed ? 1 : 0,
        'mesh_path': meshPath.isEmpty ? null : meshPath.join(','),
        'sender_role': senderRole?.name,
        'reply_to_id': replyToId,
        'reply_to_name': replyToName,
        'reply_to_preview': replyToPreview,
        'is_read': isRead ? 1 : 0,
        'is_pinned': isPinned ? 1 : 0,
      };

  /// Reconstructs a [ChatMessage] from a SQLite row.
  factory ChatMessage.fromDbRow(Map<String, Object?> row) {
    final Object? rawAttachment = row['attachment'];
    MessageAttachment? attachment;
    if (rawAttachment is String && rawAttachment.isNotEmpty) {
      final List<String> parts = rawAttachment.split('|');
      if (parts.length == 4) {
        attachment = MessageAttachment(
          id: parts[0],
          kind: parts[1],
          name: parts[2],
          sizeLabel: parts[3],
        );
      }
    }
    final Object? rawPath = row['mesh_path'];
    return ChatMessage(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      senderName: row['sender_name'] as String,
      body: row['body'] as String,
      sentAt: DateTime.fromMillisecondsSinceEpoch(row['sent_at'] as int),
      isMine: (row['is_mine'] as int) == 1,
      status: DeliveryStatus.values.byName(row['status'] as String),
      priority: PriorityLevel.values.byName(row['priority'] as String),
      transport: LinkMode.values.byName(row['transport'] as String),
      attachment: attachment,
      hopCount: (row['hop_count'] as int?) ?? 0,
      wasRelayed: ((row['was_relayed'] as int?) ?? 0) == 1,
      meshPath: rawPath is String && rawPath.isNotEmpty
          ? rawPath.split(',')
          : const <String>[],
      senderRole: row['sender_role'] is String
          ? UserRole.values.byName(row['sender_role'] as String)
          : null,
      replyToId: row['reply_to_id'] as String?,
      replyToName: row['reply_to_name'] as String?,
      replyToPreview: row['reply_to_preview'] as String?,
      isRead: ((row['is_read'] as int?) ?? 0) == 1,
      isPinned: ((row['is_pinned'] as int?) ?? 0) == 1,
    );
  }
}

/// A conversation thread with a person, team or command node.
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.lastMessage,
    required this.lastActivity,
    required this.unreadCount,
    required this.priority,
    required this.transport,
    required this.isOfficial,
    required this.isGroup,
    required this.participants,
  });

  final String id;
  final String title;
  final String subtitle;
  final String lastMessage;
  final DateTime lastActivity;
  final int unreadCount;
  final PriorityLevel priority;
  final LinkMode transport;
  final bool isOfficial;
  final bool isGroup;
  final int participants;

  Conversation copyWith({
    String? lastMessage,
    DateTime? lastActivity,
    int? unreadCount,
  }) {
    return Conversation(
      id: id,
      title: title,
      subtitle: subtitle,
      lastMessage: lastMessage ?? this.lastMessage,
      lastActivity: lastActivity ?? this.lastActivity,
      unreadCount: unreadCount ?? this.unreadCount,
      priority: priority,
      transport: transport,
      isOfficial: isOfficial,
      isGroup: isGroup,
      participants: participants,
    );
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      lastMessage: json['lastMessage'] as String,
      lastActivity: DateTime.now().subtract(
        Duration(minutes: json['minutesAgo'] as int),
      ),
      unreadCount: json['unreadCount'] as int,
      priority: PriorityLevel.values.byName(json['priority'] as String),
      transport: LinkMode.values.byName(json['transport'] as String),
      isOfficial: json['isOfficial'] as bool,
      isGroup: json['isGroup'] as bool,
      participants: json['participants'] as int,
    );
  }
}
