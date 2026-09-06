import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../broadcast/models/broadcast_models.dart';
import '../../broadcast/providers/broadcast_provider.dart';
import '../../sos/models/sos_request.dart';
import '../../sos/providers/sos_provider.dart';
import '../models/app_notification.dart';

/// Tracks which notification ids the user has read/dismissed. Held in memory so
/// the derived feed (below) can mark items read without needing a separate
/// store. Ids are stable (broadcast id, sos id) so read state survives rebuilds.
class NotificationReadState extends StateNotifier<Set<String>> {
  NotificationReadState() : super(<String>{});

  void markRead(String id) => state = <String>{...state, id};

  void markAllRead(Iterable<String> ids) => state = <String>{...state, ...ids};

  void clear() => state = <String>{};
}

final StateNotifierProvider<NotificationReadState, Set<String>>
    notificationReadProvider =
    StateNotifierProvider<NotificationReadState, Set<String>>(
  (Ref ref) => NotificationReadState(),
);

/// The notification feed, derived entirely from real system events: issued
/// broadcasts and SOS incidents. No simulated notifications — each item maps to
/// something that actually happened in the system.
final Provider<List<AppNotification>> notificationsProvider =
    Provider<List<AppNotification>>((Ref ref) {
  final List<BroadcastMessage> broadcasts = ref.watch(broadcastsProvider);
  final List<SosRequest> sosLog = ref.watch(sosLogProvider);
  final Set<String> readIds = ref.watch(notificationReadProvider);

  final List<AppNotification> items = <AppNotification>[];

  // Broadcasts → notifications.
  for (final BroadcastMessage b in broadcasts) {
    final String id = 'broadcast:${b.id}';
    items.add(AppNotification(
      id: id,
      title: b.title,
      body: b.body,
      kind: NotificationKind.broadcast,
      receivedAt: b.issuedAt,
      isRead: readIds.contains(id),
    ));
  }

  // SOS incidents → notifications.
  for (final SosRequest s in sosLog) {
    final String id = 'sos:${s.id}';
    final String statusText = switch (s.status) {
      IncidentStatus.active => 'New emergency reported',
      IncidentStatus.responding => 'Responder is on the way',
      IncidentStatus.resolved => 'Incident resolved',
      IncidentStatus.cancelled => 'Incident cancelled',
    };
    items.add(AppNotification(
      id: id,
      title: '${s.type.label} — ${s.requesterName}',
      body: statusText,
      kind: NotificationKind.sos,
      receivedAt: s.createdAt,
      isRead: readIds.contains(id),
    ));
  }

  // Newest first.
  items.sort((AppNotification a, AppNotification b) =>
      b.receivedAt.compareTo(a.receivedAt));
  return items;
});

final Provider<int> unreadNotificationCountProvider = Provider<int>((Ref ref) {
  return ref
      .watch(notificationsProvider)
      .where((AppNotification n) => !n.isRead)
      .length;
});
