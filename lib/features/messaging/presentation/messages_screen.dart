import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_inputs.dart';
import '../../../core/widgets/info_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../iot/models/network_models.dart';
import '../../iot/providers/network_provider.dart';
import '../models/message_models.dart';
import '../providers/messaging_provider.dart';
import '../providers/community_chat_provider.dart';
import '../../authentication/models/app_user.dart';
import '../../authentication/providers/auth_provider.dart';

/// List of message threads with search and filtering.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  int _filter = 0;

  static const List<String> _filters = <String>[
    'All',
    'Unread',
    'Official',
    'Groups',
    'Queued',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Conversation> _apply(List<Conversation> source) {
    Iterable<Conversation> result = source;

    result = switch (_filter) {
      1 => result.where((Conversation c) => c.unreadCount > 0),
      2 => result.where((Conversation c) => c.isOfficial),
      3 => result.where((Conversation c) => c.isGroup),
      4 => result.where((Conversation c) => c.transport == LinkMode.offline),
      _ => result,
    };

    if (_query.trim().isNotEmpty) {
      final String q = _query.toLowerCase();
      result = result.where((Conversation c) =>
          c.title.toLowerCase().contains(q) ||
          c.lastMessage.toLowerCase().contains(q));
    }

    return result.toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<Conversation> all = ref.watch(conversationsProvider);
    final NetworkStatus network = ref.watch(networkStatusProvider);
    final List<Conversation> visible = _apply(all);

    return Scaffold(
      appBar: SumpayAppBar(
        showBack: false,
        title: 'Messages',
        subtitle: 'Sent over the SUMPAY Network',
        actions: <Widget>[
          RoundIconButton(
            icon: Symbols.edit_square_rounded,
            tooltip: 'New message',
            onPressed: () => AppDialogs.info(
              context,
              title: 'New conversation',
              message:
                  'Directory search will be available once the barangay resident database is connected.',
              icon: Symbols.person_search_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
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
                child: Column(
                  children: <Widget>[
                    if (network.isOffline) ...<Widget>[
                      OfflineBanner(
                        message:
                            'Offline — new messages are stored and sent when a connection is available.',
                        color: AppColors.danger,
                        onTap: () => context.go(AppRoutes.network),
                      ),
                      const SizedBox(height: 12),
                    ],
                    AppSearchBar(
                      hint: 'Search conversations',
                      controller: _search,
                      onChanged: (String v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 12),
                    FilterChipRow(
                      labels: _filters,
                      selectedIndex: _filter,
                      onSelected: (int i) => setState(() => _filter = i),
                    ),
                    const SizedBox(height: 12),
                    _CommunityChatCard(
                      onTap: () => context.push(AppRoutes.communityChat),
                    ),
                    const SizedBox(height: 10),
                    _AreaChatCard(
                      onTap: () => context.push(AppRoutes.areaChat),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const EmptyState(
                        title: 'No conversations',
                        message:
                            'Messages from your barangay and neighbours will appear here.',
                        icon: Symbols.forum_rounded,
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          context.pageInset,
                          0,
                          context.pageInset,
                          20,
                        ),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          return _ConversationTile(
                            conversation: visible[index],
                            onTap: () {
                              ref
                                  .read(conversationsProvider.notifier)
                                  .markRead(visible[index].id);
                              context.push(
                                '${AppRoutes.conversation}?id=${visible[index].id}',
                              );
                            },
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

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasUnread = conversation.unreadCount > 0;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            children: <Widget>[
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: conversation.isOfficial
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: conversation.isGroup
                      ? Icon(
                          Symbols.groups_rounded,
                          size: 26,
                          color: AppColors.info,
                        )
                      : conversation.isOfficial
                          ? Icon(
                              Symbols.shield_person_rounded,
                              size: 26,
                              color: theme.colorScheme.primary,
                            )
                          : Text(
                              Formatters.initials(conversation.title),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.info,
                              ),
                            ),
                ),
              ),
              if (conversation.isOfficial)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Symbols.verified_rounded,
                      size: 15,
                      color: AppColors.info,
                      fill: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight:
                              hasUnread ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Formatters.listTimestamp(conversation.lastActivity),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  conversation.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        conversation.lastMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: hasUnread
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (hasUnread) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${conversation.unreadCount}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    StatusChip(
                      label: conversation.transport.label,
                      color: conversation.transport.color,
                      icon: conversation.transport.icon,
                      dense: true,
                    ),
                    if (conversation.priority == PriorityLevel.critical ||
                        conversation.priority == PriorityLevel.high) ...<Widget>[
                      const SizedBox(width: 6),
                      StatusChip(
                        label: conversation.priority.label,
                        color: conversation.priority.color,
                        dense: true,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned entry point to the mesh-wide community chat, shown above the list of
/// direct conversations so every role can reach the group chat.
class _CommunityChatCard extends ConsumerWidget {
  const _CommunityChatCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final int unread = ref.watch(communityChatProvider).unreadCount;
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F8B8D).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Symbols.groups_rounded,
                    color: Color(0xFF0F8B8D), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Community chat', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Group chat with everyone in the barangay',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (unread > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.emergency,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Icon(Symbols.chevron_right_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entry point to the resident's area-specific (barangay + purok) chat.
class _AreaChatCard extends ConsumerWidget {
  const _AreaChatCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppUser user = ref.watch(currentUserProvider);
    final int unread = ref.watch(areaChatProvider).unreadCount;
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Symbols.location_city_rounded,
                    color: AppColors.info, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Area chat', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Barangay ${user.barangay} – Purok ${user.purok}',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (unread > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.emergency,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Icon(Symbols.chevron_right_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
