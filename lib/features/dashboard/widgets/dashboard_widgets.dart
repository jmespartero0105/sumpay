import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../../broadcast/models/broadcast_models.dart';

/// A tappable quick action tile.
class QuickAction {
  const QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int badge;
}

/// Responsive grid of dashboard shortcuts.
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({
    super.key,
    required this.actions,
    required this.columns,
  });

  final List<QuickAction> actions;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (BuildContext context, int index) {
        return _QuickActionTile(action: actions[index]);
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      onTap: action.onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, size: 22, color: action.color),
              ),
              if (action.badge > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    action.badge > 99 ? '99+' : '${action.badge}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            action.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

/// Compact preview of the most recent barangay broadcast.
class RecentBroadcastCard extends StatelessWidget {
  const RecentBroadcastCard({
    super.key,
    required this.broadcast,
    this.onTap,
  });

  final BroadcastMessage broadcast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      color: broadcast.severity.softColor,
      borderColor: broadcast.severity.color.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              StatusChip(
                label: broadcast.severity.label.toUpperCase(),
                color: broadcast.severity.color,
                icon: Symbols.campaign_rounded,
                filled: true,
                dense: true,
              ),
              const Spacer(),
              Text(
                Formatters.relative(broadcast.issuedAt),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            broadcast.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            broadcast.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Icon(
                Symbols.account_balance_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  broadcast.issuedBy,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
              Text(
                'Read more',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: broadcast.severity.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(
                Symbols.chevron_right_rounded,
                size: 16,
                color: broadcast.severity.color,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rotating preparedness tip.
class EmergencyTipCard extends StatelessWidget {
  const EmergencyTipCard({super.key, required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Symbols.lightbulb_rounded,
            size: 22,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Preparedness tip',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(tip, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
