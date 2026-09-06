import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/info_widgets.dart';
import '../../../core/widgets/section_header.dart';
import '../../authentication/models/app_user.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../admin/presentation/admin_dashboard.dart';
import '../../admin/presentation/official_screen.dart';
import '../../volunteer/presentation/volunteer_dashboard.dart';
import '../../sos/models/sos_packet.dart';
import '../../sos/models/responder.dart';
import '../../sos/providers/resident_sos_notification_provider.dart';
import '../../sos/providers/sos_mesh_provider.dart';
import '../../broadcast/models/broadcast_models.dart';
import '../../broadcast/providers/broadcast_provider.dart';
import '../../iot/data/services/connectivity_service.dart';
import '../../iot/widgets/network_glyph.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../sos/providers/sos_provider.dart';
import '../providers/user_mode_provider.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/mode_toggle.dart';
import '../widgets/sos_button.dart';
import '../../sos/providers/responder_response_provider.dart';
import '../../sos/widgets/floating_responder_status.dart';
import '../../sos/models/sos_request.dart';

/// Primary landing screen for every role.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppUser user = ref.watch(currentUserProvider);

    // Surface incoming SOS status updates (from responders/officials over the
    // mesh) to the resident as an in-app notification.
    ref.listen<SosStatusUpdate?>(residentSosNotificationProvider,
        (SosStatusUpdate? prev, SosStatusUpdate? next) {
      if (next == null) return;
      // Colour by meaning: positive progress (delivered, accepted, en route,
      // arrived, resolved) is GREEN so the resident reads it as reassurance, not
      // an error. Only a genuine setback (rejected) uses a cautionary colour.
      final Color bg = next.status == SosStatus.rejected
          ? AppColors.warning
          : AppColors.success;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: bg,
        ),
      );
      ref.read(residentSosNotificationProvider.notifier).state = null;
    });

    // Administrators get a dedicated management dashboard; officials get the
    // command screen. Community members ("user" role) get a unified home with a
    // Grab-style Resident/Responder toggle.
    if (user.role == UserRole.admin) {
      return const AdminDashboard();
    }
    if (user.role == UserRole.official) {
      return const OfficialScreen();
    }

    // Community member: in Responder Mode, show the responder dashboard (receive
    // and act on SOS). In Resident Mode, fall through to the resident home.
    final UserMode mode = ref.watch(userModeProvider);
    if (mode == UserMode.responder) {
      return const VolunteerDashboard();
    }

    final BroadcastMessage? broadcast = ref.watch(latestBroadcastProvider);
    final int unreadNotifications = ref.watch(unreadNotificationCountProvider);
    final NetworkGlyphState netState =
        resolveNetworkGlyphState(ref.watch(connectivityProvider));
    final ResponderResponse? responderResponse =
        ref.watch(responderResponseProvider);
    final AppSettings settings = ref.watch(settingsProvider);
    final String tip = ref.watch(emergencyTipProvider);
    final DateTime now = DateTime.now();

    return Scaffold(
      appBar: SumpayAppBar(
        showBack: false,
        title: Formatters.greeting(now),
        subtitle: Formatters.fullDate(now),
        actions: <Widget>[
          RoundIconButton(
            icon: networkGlyphFor(netState).icon,
            color: networkGlyphFor(netState).color,
            tooltip: 'Network: ${networkGlyphFor(netState).label}',
            onPressed: () => context.go(AppRoutes.network),
          ),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: Symbols.notifications_rounded,
            badgeCount: unreadNotifications,
            tooltip: 'Notifications',
            onPressed: () => context.push(AppRoutes.notifications),
          ),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: Symbols.settings_rounded,
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: <Widget>[
            RefreshIndicator(
              onRefresh: () async {
                // Refresh the real home data sources.
                ref.invalidate(latestBroadcastProvider);
                ref.invalidate(activeIncidentsProvider);
                await Future<void>.delayed(const Duration(milliseconds: 300));
              },
              child: ContentContainer(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                context.pageInset,
                8,
                context.pageInset,
                28,
              ),
              children: <Widget>[
                if (user.role == UserRole.user) ...<Widget>[
                  const ModeToggle(),
                  const SizedBox(height: 16),
                ],
                if (netState == NetworkGlyphState.offline) ...<Widget>[
                  OfflineBanner(
                    message:
                        'You are offline. Messages will be queued and relayed automatically.',
                    color: AppColors.danger,
                    onTap: () => context.go(AppRoutes.network),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  'Need help right now?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Hold nothing back — responders receive your location instantly.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                SosButton(
                  reduceMotion: settings.reduceMotion,
                  onPressed: () => context.push(AppRoutes.sos),
                ),
                const SizedBox(height: 6),
                const _ActiveIncidentStrip(),
                const SizedBox(height: AppConstants.sectionGap),
                if (broadcast != null) ...<Widget>[
                  SectionHeader(
                    title: 'Latest broadcast',
                    actionLabel: 'View all',
                    onAction: () => context.go(AppRoutes.broadcast),
                  ),
                  RecentBroadcastCard(
                    broadcast: broadcast,
                    onTap: () => context.go(AppRoutes.broadcast),
                  ),
                  const SizedBox(height: AppConstants.sectionGap),
                ] else ...<Widget>[
                  const SectionHeader(title: 'Latest broadcast'),
                  AppCard(
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Symbols.campaign_rounded,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.35),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'No latest broadcasts',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Barangay advisories and alerts will appear here.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.sectionGap),
                ],
                EmergencyTipCard(tip: tip),
              ],
            ),
          ),
            ),
            if (responderResponse != null)
              Positioned(
                left: context.pageInset,
                right: context.pageInset,
                bottom: 16,
                child: FloatingResponderStatus(
                  response: responderResponse,
                  sosType: _sosTypeFor(ref, responderResponse.sosId),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Resolves the emergency type of the resident's own SOS for display on the
  /// floating card. Returns null if the SOS isn't in the local log.
  EmergencyType? _sosTypeFor(WidgetRef ref, String sosId) {
    final List<SosRequest> log = ref.read(sosLogProvider);
    for (final SosRequest r in log) {
      if (r.id == sosId) return r.type;
    }
    return null;
  }
}

/// Shows the resident's own in-flight emergency, if any.
/// Shows the resident's OWN active SOS (if any) directly on the home screen so
/// they can see its live status and open it even before a responder accepts.
class _ActiveIncidentStrip extends ConsumerWidget {
  const _ActiveIncidentStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<SosRequest> active = ref
        .watch(sosLogProvider)
        .where((SosRequest r) =>
            r.status == IncidentStatus.active ||
            r.status == IncidentStatus.responding)
        .toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Your active SOS',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        ...active.map(
          (SosRequest r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () =>
                  context.push('${AppRoutes.sosConfirmation}?id=${r.id}'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.emergency.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Symbols.emergency_home_rounded,
                        size: 22, color: AppColors.emergency),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(r.type.label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Builder(builder: (BuildContext context) {
                            final List<Responder> resps = ref.watch(
                                    respondersBySosProvider)[r.id] ??
                                <Responder>[];
                            if (resps.isEmpty) {
                              return Text(
                                'Waiting for a responder to accept…',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '${resps.length} responder'
                                  '${resps.length == 1 ? '' : 's'} responding:',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.75),
                                  ),
                                ),
                                ...resps.map((Responder resp) => Text(
                                      '• ${resp.name} (${resp.state.label})',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    )),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(label: r.status.label, color: r.status.color),
                    const Icon(Symbols.chevron_right_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
