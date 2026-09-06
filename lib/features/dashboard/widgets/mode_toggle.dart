import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/user_mode_provider.dart';

/// A Grab-style segmented toggle (like Delivery / Pick-Up) that switches a
/// community member between Resident Mode (get help) and Responder Mode (give
/// help). Placed at the top of the home screen.
class ModeToggle extends ConsumerWidget {
  const ModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserMode mode = ref.watch(userModeProvider);
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          _ModeSegment(
            selected: mode == UserMode.resident,
            icon: Symbols.sos_rounded,
            title: 'Resident',
            subtitle: 'Get help',
            activeColor: AppColors.emergency,
            onTap: () =>
                ref.read(userModeProvider.notifier).set(UserMode.resident),
          ),
          _ModeSegment(
            selected: mode == UserMode.responder,
            icon: Symbols.volunteer_activism_rounded,
            title: 'Responder',
            subtitle: 'Give help',
            activeColor: AppColors.info,
            onTap: () =>
                ref.read(userModeProvider.notifier).set(UserMode.responder),
          ),
        ],
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.activeColor,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 22,
                color: selected ? Colors.white : theme.disabledColor,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: selected ? Colors.white : theme.disabledColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.85)
                          : theme.disabledColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
