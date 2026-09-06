import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../models/message_models.dart';

/// Chat bubble with delivery status, priority and attachment support.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.showSender,
  });

  final ChatMessage message;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool mine = message.isMine;
    final bool urgent = message.priority == PriorityLevel.critical ||
        message.priority == PriorityLevel.high;

    final Color bubbleColor = mine
        ? theme.colorScheme.primary
        : theme.colorScheme.surface;
    final Color textColor =
        mine ? Colors.white : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          if (showSender && !mine)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    message.senderName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (message.senderRole != null) ...<Widget>[
                    const SizedBox(width: 6),
                    _RoleTag(role: message.senderRole!),
                  ],
                ],
              ),
            ),
          // For own messages in a group context, still surface the role.
          if (mine && message.senderRole != null)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 4),
              child: _RoleTag(role: message.senderRole!),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 5),
                  bottomRight: Radius.circular(mine ? 5 : 18),
                ),
                border: mine
                    ? null
                    : Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (message.replyToPreview != null) ...<Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: mine
                            ? Colors.white.withValues(alpha: 0.18)
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: mine
                                ? Colors.white
                                : theme.colorScheme.primary,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            message.replyToName ?? 'Reply',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: mine
                                  ? Colors.white
                                  : theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            message.replyToPreview!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: mine
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (urgent) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: mine
                            ? Colors.white.withValues(alpha: 0.22)
                            : message.priority.softColor,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Symbols.priority_high_rounded,
                            size: 13,
                            color: mine ? Colors.white : message.priority.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${message.priority.label} priority',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  mine ? Colors.white : message.priority.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (message.attachment != null) ...<Widget>[
                    _AttachmentPreview(
                      attachment: message.attachment!,
                      mine: mine,
                    ),
                    if (message.body.isNotEmpty) const SizedBox(height: 9),
                  ],
                  if (message.body.isNotEmpty)
                    Text(
                      message.body,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        Formatters.time(message.sentAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: mine
                              ? Colors.white.withValues(alpha: 0.78)
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.55),
                          fontSize: 10.5,
                        ),
                      ),
                      if (mine) ...<Widget>[
                        const SizedBox(width: 6),
                        Icon(
                          message.status.icon,
                          size: 14,
                          color: message.status == DeliveryStatus.failed
                              ? AppColors.warningSoft
                              : Colors.white.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          message.status.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                      if (message.wasRelayed) ...<Widget>[
                        const SizedBox(width: 6),
                        Icon(
                          Symbols.route_rounded,
                          size: 13,
                          color: mine
                              ? Colors.white.withValues(alpha: 0.85)
                              : AppColors.info,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${message.hopCount} hop${message.hopCount == 1 ? '' : 's'}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: mine
                                ? Colors.white.withValues(alpha: 0.78)
                                : AppColors.info,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (message.wasRelayed && message.meshPath.length > 1) ...<Widget>[
                    const SizedBox(height: 5),
                    _MeshPathRow(path: message.meshPath, mine: mine),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.attachment, required this.mine});

  final MessageAttachment attachment;
  final bool mine;

  IconData get _icon => switch (attachment.kind) {
        'voice' => Symbols.graphic_eq_rounded,
        'image' => Symbols.image_rounded,
        'location' => Symbols.location_on_rounded,
        _ => Symbols.description_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color fg = mine ? Colors.white : theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: mine
            ? Colors.white.withValues(alpha: 0.16)
            : theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(_icon, size: 22, color: fg),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                attachment.name,
                style: theme.textTheme.titleSmall?.copyWith(color: fg),
              ),
              const SizedBox(height: 1),
              Text(
                attachment.sizeLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fg.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact visualisation of the device path a relayed packet travelled.
///
/// Renders the ordered hops as short id chips joined by arrows, e.g.
/// `a1b2 → c3d4 → me`, so the recipient can see how a message reached them
/// across the mesh.
class _MeshPathRow extends StatelessWidget {
  const _MeshPathRow({required this.path, required this.mine});

  final List<String> path;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = mine
        ? Colors.white.withValues(alpha: 0.70)
        : theme.colorScheme.onSurface.withValues(alpha: 0.55);

    final List<Widget> hops = <Widget>[];
    for (int i = 0; i < path.length; i++) {
      hops.add(
        Text(
          _shortId(path[i]),
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 10,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      );
      if (i < path.length - 1) {
        hops.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Icon(Symbols.arrow_forward_rounded, size: 11, color: color),
        ));
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Symbols.lan_rounded, size: 11, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: hops,
          ),
        ),
      ],
    );
  }

  /// Shortens a device id (`dev-<uuid>`) to a readable 4-char tag.
  static String _shortId(String id) {
    final String core = id.startsWith('dev-') ? id.substring(4) : id;
    final String cleaned = core.replaceAll('-', '');
    if (cleaned.length <= 4) return cleaned;
    return cleaned.substring(0, 4);
  }
}

/// Small coloured tag showing a sender's role, used in group chats.
class _RoleTag extends StatelessWidget {
  const _RoleTag({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = switch (role) {
      UserRole.official => AppColors.info,
      UserRole.admin => AppColors.primary,
      UserRole.user => AppColors.success,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
