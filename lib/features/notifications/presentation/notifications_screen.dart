import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_inputs.dart';
import '../../../core/widgets/state_views.dart';
import '../models/app_notification.dart';
import '../providers/notification_provider.dart';

/// Notification centre with category filtering.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _filter = 0;

  static const List<String> _filters = <String>[
    'All',
    'Unread',
    'Broadcasts',
    'SOS',
    'Network',
  ];

  List<AppNotification> _apply(List<AppNotification> source) {
    return switch (_filter) {
      1 => source.where((AppNotification n) => !n.isRead).toList(),
      2 => source
          .where((AppNotification n) => n.kind.label == 'Broadcast')
          .toList(),
      3 => source
          .where((AppNotification n) => n.kind.label == 'SOS Update')
          .toList(),
      4 => source
          .where((AppNotification n) => n.kind.label == 'Network')
          .toList(),
      _ => source,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<AppNotification> all = ref.watch(notificationsProvider);
    final int unread = ref.watch(unreadNotificationCountProvider);
    final List<AppNotification> visible = _apply(all);

    return Scaffold(
      appBar: SumpayAppBar(
        title: 'Notifications',
        subtitle: unread == 0 ? 'You are all caught up' : '$unread unread',
        actions: <Widget>[
          RoundIconButton(
            icon: Symbols.mark_email_read_rounded,
            tooltip: 'Mark all as read',
            onPressed: () {
              ref.read(notificationReadProvider.notifier).markAllRead(
                    ref
                        .read(notificationsProvider)
                        .map((AppNotification n) => n.id),
                  );
              AppDialogs.snack(
                context,
                'All notifications marked as read.',
                icon: Symbols.check_circle_rounded,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ContentContainer(
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.pageInset,
                  4,
                  context.pageInset,
                  12,
                ),
                child: FilterChipRow(
                  labels: _filters,
                  selectedIndex: _filter,
                  onSelected: (int i) => setState(() => _filter = i),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const EmptyState(
                        title: 'Nothing to show',
                        message:
                            'Alerts, messages and network events will appear here.',
                        icon: Symbols.notifications_rounded,
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          context.pageInset,
                          0,
                          context.pageInset,
                          24,
                        ),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          final AppNotification n = visible[index];
                          return AppCard(
                            onTap: () => ref
                                .read(notificationReadProvider.notifier)
                                .markRead(n.id),
                            padding: const EdgeInsets.all(14),
                            color: n.isRead
                                ? null
                                : n.kind.color.withValues(alpha: 0.05),
                            borderColor: n.isRead
                                ? null
                                : n.kind.color.withValues(alpha: 0.25),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  height: 44,
                                  width: 44,
                                  decoration: BoxDecoration(
                                    color:
                                        n.kind.color.withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    n.kind.icon,
                                    size: 22,
                                    color: n.kind.color,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              n.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: n.isRead
                                                    ? FontWeight.w600
                                                    : FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (!n.isRead)
                                            Container(
                                              height: 9,
                                              width: 9,
                                              decoration: BoxDecoration(
                                                color: n.kind.color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n.body,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(height: 1.45),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: <Widget>[
                                          Text(
                                            n.kind.label,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: n.kind.color,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            Formatters.relative(n.receivedAt),
                                            style: theme.textTheme.labelSmall,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
