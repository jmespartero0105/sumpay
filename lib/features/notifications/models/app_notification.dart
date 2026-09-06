import '../../../core/constants/app_enums.dart';

/// An entry in the notification centre.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.receivedAt,
    required this.isRead,
  });

  final String id;
  final String title;
  final String body;
  final NotificationKind kind;
  final DateTime receivedAt;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      kind: kind,
      receivedAt: receivedAt,
      isRead: isRead ?? this.isRead,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      kind: NotificationKind.values.byName(json['kind'] as String),
      receivedAt: DateTime.now().subtract(
        Duration(minutes: json['minutesAgo'] as int),
      ),
      isRead: json['isRead'] as bool,
    );
  }
}
