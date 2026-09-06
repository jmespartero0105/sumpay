import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/responsive.dart';
import '../../authentication/models/app_user.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../messaging/providers/messaging_provider.dart';

/// Persistent scaffold hosting the primary tabbed destinations.
///
/// Uses a [NavigationBar] on phones and a [NavigationRail] on tablets so the
/// prototype adapts cleanly to both target form factors.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read null-safely: if the shell is built before authentication settles,
    // fall back to the resident layout rather than throwing. The router gates
    // real navigation behind login.
    final AppUser? currentUser = ref.watch(currentUserOrNullProvider);
    final UserRole role = currentUser?.role ?? UserRole.user;
    final int unread = ref.watch(unreadMessageCountProvider);

    final List<_Destination> destinations = <_Destination>[
      const _Destination(
        route: AppRoutes.home,
        icon: Symbols.home_rounded,
        label: 'Home',
      ),
      _Destination(
        route: AppRoutes.messages,
        icon: Symbols.forum_rounded,
        label: 'Messages',
        badge: unread,
      ),
      const _Destination(
        route: AppRoutes.broadcast,
        icon: Symbols.campaign_rounded,
        label: 'Broadcast',
      ),
      const _Destination(
        route: AppRoutes.network,
        icon: Symbols.router_rounded,
        label: 'Network',
      ),
      _Destination(
        route: AppRoutes.profile,
        icon: role.icon,
        label: 'Me',
      ),
    ];

    if (context.isWide) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            _AdaptiveRail(
              destinations: destinations,
              selectedIndex: navigationShell.currentIndex,
              onSelected: _goBranch,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: destinations
            .map((_Destination d) => NavigationDestination(
                  icon: _BadgedIcon(icon: d.icon, badge: d.badge, filled: false),
                  selectedIcon:
                      _BadgedIcon(icon: d.icon, badge: d.badge, filled: true),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}

class _AdaptiveRail extends StatelessWidget {
  const _AdaptiveRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelType: NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: <Widget>[
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Symbols.emergency_share_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text('SUMPAY', style: theme.textTheme.labelSmall),
          ],
        ),
      ),
      destinations: destinations
          .map((_Destination d) => NavigationRailDestination(
                icon: _BadgedIcon(icon: d.icon, badge: d.badge, filled: false),
                selectedIcon:
                    _BadgedIcon(icon: d.icon, badge: d.badge, filled: true),
                label: Text(d.label),
              ))
          .toList(),
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({
    required this.icon,
    required this.badge,
    required this.filled,
  });

  final IconData icon;
  final int badge;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = Icon(icon, fill: filled ? 1 : 0);
    if (badge <= 0) return iconWidget;

    final ThemeData theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        iconWidget,
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 17),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: theme.colorScheme.surface, width: 1.5),
            ),
            child: Text(
              badge > 99 ? '99+' : '$badge',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Destination {
  const _Destination({
    required this.route,
    required this.icon,
    required this.label,
    this.badge = 0,
  });

  final String route;
  final IconData icon;
  final String label;
  final int badge;
}
