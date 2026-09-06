import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_routes.dart';
import '../../features/about/presentation/about_screen.dart';
import '../../features/admin/presentation/barangay_map_screen.dart';
import '../../features/admin/presentation/situation_overview_screen.dart';
import '../../features/admin/presentation/official_screen.dart';
import '../../features/admin/presentation/user_management_screen.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/register_screen.dart';
import '../../features/broadcast/presentation/broadcast_screen.dart';
import '../../features/dashboard/presentation/home_screen.dart';
import '../../features/dashboard/presentation/main_shell.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/iot/presentation/network_screen.dart';
import '../../features/iot/presentation/network_monitor_screen.dart';
import '../../features/iot/presentation/nearby_device_screen.dart';
import '../../features/messaging/presentation/nearby_chat_screen.dart';
import '../../features/messaging/presentation/community_chat_screen.dart';
import '../../features/messaging/providers/community_chat_provider.dart';
import '../../features/authentication/models/app_user.dart';
import '../../features/authentication/providers/auth_provider.dart';
import '../../features/messaging/presentation/conversation_screen.dart';
import '../../features/messaging/presentation/messages_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/sos/presentation/sos_confirmation_screen.dart';
import '../../features/sos/presentation/sos_screen.dart';
import '../../features/tracking/presentation/tracking_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/volunteer/presentation/volunteer_screen.dart';

/// Root navigator key for full-screen routes above the shell.
final GlobalKey<NavigatorState> _rootKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final GlobalKey<NavigatorState> _homeKey =
    GlobalKey<NavigatorState>(debugLabel: 'home');
final GlobalKey<NavigatorState> _messagesKey =
    GlobalKey<NavigatorState>(debugLabel: 'messages');
final GlobalKey<NavigatorState> _broadcastKey =
    GlobalKey<NavigatorState>(debugLabel: 'broadcast');
final GlobalKey<NavigatorState> _networkKey =
    GlobalKey<NavigatorState>(debugLabel: 'network');
final GlobalKey<NavigatorState> _profileKey =
    GlobalKey<NavigatorState>(debugLabel: 'profile');

/// Shared fade-through transition for full-screen pushes.
CustomTransitionPage<void> _fadeThrough(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    child: child,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
  );
}

/// Application router.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoutes.splash,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.nameSplash,
        builder: (BuildContext context, GoRouterState state) =>
            const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: AppRoutes.nameOnboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.nameLogin,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRoutes.nameRegister,
        parentNavigatorKey: _rootKey,
        builder: (BuildContext context, GoRouterState state) =>
            const RegisterScreen(),
      ),

      // Full-screen routes presented above the tab shell.
      GoRoute(
        path: AppRoutes.sos,
        name: AppRoutes.nameSos,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeThrough(const SosScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.sosConfirmation,
        name: AppRoutes.nameSosConfirmation,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) {
          final String id = state.uri.queryParameters['id'] ?? '';
          return _fadeThrough(SosConfirmationScreen(requestId: id), state);
        },
      ),
      GoRoute(
        path: AppRoutes.conversation,
        name: AppRoutes.nameConversation,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) {
          final String id = state.uri.queryParameters['id'] ?? '';
          return _fadeThrough(ConversationScreen(conversationId: id), state);
        },
      ),
      GoRoute(
        path: AppRoutes.volunteer,
        name: AppRoutes.nameVolunteer,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeThrough(const VolunteerScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.official,
        name: AppRoutes.nameOfficial,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeThrough(const OfficialScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.userManagement,
        name: AppRoutes.nameUserManagement,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeThrough(const UserManagementScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.nearby,
        name: AppRoutes.nameNearby,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeThrough(const NearbyDeviceScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.networkMonitor,
        name: AppRoutes.nameNetworkMonitor,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeThrough(const NetworkMonitorScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.barangayMap,
        name: AppRoutes.nameBarangayMap,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeThrough(const BarangayMapScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.situationOverview,
        name: AppRoutes.nameSituationOverview,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeThrough(const SituationOverviewScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.nearbyChat,
        name: AppRoutes.nameNearbyChat,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) {
          final String endpointId =
              state.uri.queryParameters['endpointId'] ?? '';
          final String deviceName =
              state.uri.queryParameters['name'] ?? 'Device';
          return _fadeThrough(
            NearbyChatScreen(endpointId: endpointId, deviceName: deviceName),
            state,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.communityChat,
        name: AppRoutes.nameCommunityChat,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeThrough(const CommunityChatScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.areaChat,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeThrough(
          Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              final AppUser user = ref.watch(currentUserProvider);
              return CommunityChatScreen(
                provider: areaChatProvider,
                title: 'Area chat',
                subtitle: 'Barangay ${user.barangay} – Purok ${user.purok}',
              );
            },
          ),
          state,
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: AppRoutes.nameNotifications,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeThrough(const NotificationsScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.tracking,
        name: AppRoutes.nameTracking,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeThrough(const TrackingScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.history,
        name: AppRoutes.nameHistory,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeThrough(const HistoryScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: AppRoutes.nameSettings,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeThrough(const SettingsScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.about,
        name: AppRoutes.nameAbout,
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeThrough(const AboutScreen(), state),
      ),

      // Bottom-navigation shell with independent branch stacks.
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: _homeKey,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                name: AppRoutes.nameHome,
                builder: (BuildContext context, GoRouterState state) =>
                    const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _messagesKey,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.messages,
                name: AppRoutes.nameMessages,
                builder: (BuildContext context, GoRouterState state) =>
                    const MessagesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _broadcastKey,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.broadcast,
                name: AppRoutes.nameBroadcast,
                builder: (BuildContext context, GoRouterState state) =>
                    const BroadcastScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _networkKey,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.network,
                name: AppRoutes.nameNetwork,
                builder: (BuildContext context, GoRouterState state) =>
                    const NetworkScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileKey,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.profile,
                name: AppRoutes.nameProfile,
                builder: (BuildContext context, GoRouterState state) =>
                    const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
