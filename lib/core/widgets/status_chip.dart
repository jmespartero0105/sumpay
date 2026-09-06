import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Compact, colour-coded label used for statuses, priorities and link modes.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.background,
    this.dense = false,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final Color? background;
  final bool dense;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color surface =
        background ?? (filled ? color : color.withValues(alpha: 0.12));
    final Color foreground = filled ? Colors.white : color;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 11,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 13 : 15, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: (dense
                    ? theme.textTheme.labelSmall
                    : theme.textTheme.labelMedium)
                ?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
