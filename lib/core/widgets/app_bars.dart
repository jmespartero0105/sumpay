import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Standard SUMPAY app bar with optional subtitle and actions.
class SumpayAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SumpayAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBack = true,
    this.onBack,
    this.bottom,
    this.backgroundColor,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canPop = Navigator.of(context).canPop();

    return AppBar(
      backgroundColor: backgroundColor,
      automaticallyImplyLeading: false,
      titleSpacing: showBack && canPop ? 4 : 20,
      leading: showBack && canPop
          ? IconButton(
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Symbols.arrow_back_rounded),
              tooltip: 'Back',
              iconSize: 26,
            )
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleLarge),
          if (subtitle != null)
            Text(subtitle!, style: theme.textTheme.bodySmall),
        ],
      ),
      actions: <Widget>[
        ...?actions,
        const SizedBox(width: 8),
      ],
      bottom: bottom,
    );
  }
}

/// Circular icon button used inside app bars and cards.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badgeCount = 0,
    this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final int badgeCount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Widget button = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: 25,
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: color ?? theme.colorScheme.onSurface,
        minimumSize: const Size(46, 46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: theme.dividerColor),
        ),
      ),
      icon: Icon(icon),
    );

    if (badgeCount <= 0) return button;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        button,
        Positioned(
          right: 4,
          top: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            constraints: const BoxConstraints(minWidth: 18),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: theme.colorScheme.surface, width: 1.5),
            ),
            child: Text(
              badgeCount > 99 ? '99+' : '$badgeCount',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
