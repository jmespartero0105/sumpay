import 'package:flutter/material.dart';

import '../utils/formatters.dart';

/// A rounded avatar showing the two-letter initials of a name.
///
/// Extracted from the message list and profile screens, where the same
/// coloured initials circle was hand-built. Centralising it keeps the styling
/// consistent and removes the duplication.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 52,
    this.radius = 16,
    this.color,
    this.icon,
  });

  final String name;
  final double size;
  final double radius;
  final Color? color;

  /// Optional icon shown instead of initials (e.g. for groups or channels).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = color ?? theme.colorScheme.primary;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, size: size * 0.5, color: accent)
            : Text(
                Formatters.initials(name),
                style: theme.textTheme.titleMedium?.copyWith(color: accent),
              ),
      ),
    );
  }
}
