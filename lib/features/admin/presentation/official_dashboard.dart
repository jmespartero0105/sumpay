import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../broadcast/models/broadcast_models.dart';
import '../../broadcast/providers/broadcast_provider.dart';
import '../../iot/models/mesh_manager_state.dart';
import '../../iot/models/nearby_device.dart';
import '../../iot/models/network_models.dart';
import '../../iot/providers/mesh_manager_provider.dart';
import '../../iot/providers/network_provider.dart';
import '../../messaging/models/message_models.dart';
import '../../messaging/providers/community_chat_provider.dart';
import '../../sos/models/sos_request.dart';
import '../../sos/providers/sos_provider.dart';
import '../models/command_models.dart';
import '../providers/command_provider.dart';

/// Redesigned Barangay Official dashboard, optimized for 8" and 10" Android
/// tablets in both orientations, with an adaptive layout that also works on
/// phones. Material 3 throughout.
///
/// The dashboard is composed from independent section widgets, arranged by one
/// of three layout builders selected from the screen size and orientation:
///   - phone: a single scrolling column,
///   - tablet portrait: a two-column masonry,
///   - tablet landscape: a main area plus a fixed side rail.
///
/// Automatic mesh formation is unaffected by this screen: it runs app-wide from
/// startup, so the tablet keeps discovering and connecting to nearby devices
/// while this dashboard is shown. The Network Status and Mesh Health sections
/// surface that live state.
class OfficialDashboard extends ConsumerWidget {
  const OfficialDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String name = ref.watch(currentUserProvider).fullName;

    return Scaffold(
      appBar: SumpayAppBar(
        title: 'Command dashboard',
        subtitle: '$name • Barangay Official',
        showBack: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isTablet =
                constraints.maxWidth >= AppConstants.tabletBreakpoint;
            final bool isLandscape =
                constraints.maxWidth > constraints.maxHeight;

            if (isTablet && isLandscape) {
              return const _TabletLandscapeLayout();
            }
            if (isTablet) {
              return const _TabletPortraitLayout();
            }
            return const _PhoneLayout();
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Layout builders
// ---------------------------------------------------------------------------

/// Phone: a single scrolling column, most urgent information first.
class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
          context.pageInset, 12, context.pageInset, 24),
      children: const <Widget>[
        _StatisticsSection(),
        SizedBox(height: 16),
        _NetworkStatusSection(),
        SizedBox(height: 16),
        _CurrentIncidentsSection(),
        SizedBox(height: 16),
        _RecentSosSection(),
        SizedBox(height: 16),
        _MeshHealthSection(),
        SizedBox(height: 16),
        _ConnectedMeshDevicesSection(),
        SizedBox(height: 16),
        _OnlineVolunteersSection(),
        SizedBox(height: 16),
        _MapPlaceholderSection(),
        SizedBox(height: 16),
        _BroadcastPanelSection(),
        SizedBox(height: 16),
        _RecentBroadcastsSection(),
        SizedBox(height: 16),
        _CommunityChatSection(),
      ],
    );
  }
}

/// Tablet portrait: two balanced columns so more fits above the fold.
class _TabletPortraitLayout extends StatelessWidget {
  const _TabletPortraitLayout();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
          context.pageInset, 16, context.pageInset, 28),
      children: <Widget>[
        const _StatisticsSection(),
        const SizedBox(height: 18),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    _NetworkStatusSection(),
                    SizedBox(height: 16),
                    _CurrentIncidentsSection(),
                    SizedBox(height: 16),
                    _RecentSosSection(),
                    SizedBox(height: 16),
                    _MapPlaceholderSection(),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: <Widget>[
                    _MeshHealthSection(),
                    SizedBox(height: 16),
                    _ConnectedMeshDevicesSection(),
                    SizedBox(height: 16),
                    _OnlineVolunteersSection(),
                    SizedBox(height: 16),
                    _BroadcastPanelSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _RecentBroadcastsSection(),
        const SizedBox(height: 16),
        const _CommunityChatSection(),
      ],
    );
  }
}

/// Tablet landscape: a wide main area (operational focus) plus a fixed side
/// rail (situational awareness and comms).
class _TabletLandscapeLayout extends StatelessWidget {
  const _TabletLandscapeLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Main operational area.
        Expanded(
          flex: 3,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                context.pageInset, 16, 8, 24),
            children: const <Widget>[
              _StatisticsSection(),
              SizedBox(height: 16),
              _CurrentIncidentsSection(),
              SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: _RecentSosSection()),
                  SizedBox(width: 16),
                  Expanded(child: _MapPlaceholderSection()),
                ],
              ),
              SizedBox(height: 16),
              _BroadcastPanelSection(),
            ],
          ),
        ),
        // Situational side rail.
        SizedBox(
          width: 340,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                8, 16, context.pageInset, 24),
            children: const <Widget>[
              _NetworkStatusSection(),
              SizedBox(height: 16),
              _MeshHealthSection(),
              SizedBox(height: 16),
              _ConnectedMeshDevicesSection(),
              SizedBox(height: 16),
              _OnlineVolunteersSection(),
              SizedBox(height: 16),
              _RecentBroadcastsSection(),
              SizedBox(height: 16),
              _CommunityChatSection(),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section widgets (each reused across all three layouts)
// ---------------------------------------------------------------------------

/// Statistics cards — an adaptive grid whose column count scales with width.
class _StatisticsSection extends ConsumerWidget {
  const _StatisticsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CommandStatistics stats = ref.watch(commandStatisticsProvider);
    final int columns = context.gridColumns(phone: 2, tablet: 3, desktop: 4);

    final List<_Stat> items = <_Stat>[
      _Stat('Active incidents', '${stats.activeIncidents}',
          Symbols.emergency_rounded, AppColors.emergency),
      _Stat('Residents online', Formatters.count(stats.residentsOnline),
          Symbols.groups_rounded, AppColors.info),
      _Stat('Connected devices', '${stats.connectedNodes}/${stats.totalNodes}',
          Symbols.hub_rounded, AppColors.success),
      _Stat('Volunteers', '${stats.volunteersDeployed}',
          Symbols.volunteer_activism_rounded, AppColors.warning),
      _Stat('Evacuees', Formatters.count(stats.evacuees),
          Symbols.night_shelter_rounded, AppColors.info),
      _Stat('Avg response', Formatters.duration(stats.averageResponse),
          Symbols.timer_rounded, AppColors.success),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: items.map((_Stat s) => _StatCard(stat: s)).toList(),
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});
  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(stat.icon, color: stat.color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(stat.value,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(stat.label,
                  style: theme.textTheme.labelSmall, maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

/// Network status — overall connectivity headline (reads mesh manager state).
class _NetworkStatusSection extends ConsumerWidget {
  const _NetworkStatusSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final MeshManagerState mesh = ref.watch(meshManagerProvider);
    final Color color = mesh.status == MeshStatus.connected
        ? AppColors.success
        : mesh.status == MeshStatus.error
            ? AppColors.emergency
            : AppColors.warning;

    return AppCard(
      color: color.withValues(alpha: 0.06),
      borderColor: color.withValues(alpha: 0.22),
      child: Row(
        children: <Widget>[
          Icon(Symbols.lan_rounded, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Network status', style: theme.textTheme.labelMedium),
                Text(mesh.status.label,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: color, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          StatusChip(
            label: mesh.isDiscovering ? 'Scanning' : 'Idle',
            color: mesh.isDiscovering ? AppColors.info : AppColors.textSecondary,
            dense: true,
          ),
        ],
      ),
    );
  }
}

/// Current incidents — active SOS requests with quick resolve.
class _CurrentIncidentsSection extends ConsumerWidget {
  const _CurrentIncidentsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SosRequest> incidents = ref.watch(activeIncidentsProvider);
    return _SectionCard(
      title: 'Current incidents',
      icon: Symbols.emergency_rounded,
      child: incidents.isEmpty
          ? const EmptyState(
              title: 'No active incidents',
              message: 'Active emergencies will appear here.',
              icon: Symbols.check_circle_rounded,
            )
          : Column(
              children: incidents
                  .take(5)
                  .map((SosRequest i) => _IncidentRow(incident: i))
                  .toList(),
            ),
    );
  }
}

class _IncidentRow extends ConsumerWidget {
  const _IncidentRow({required this.incident});
  final SosRequest incident;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(incident.type.icon, color: incident.type.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${incident.type.label} • ${incident.requesterName}',
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(Formatters.relative(incident.createdAt),
                    style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          StatusChip(
            label: incident.priority.label,
            color: incident.priority.color,
            dense: true,
          ),
        ],
      ),
    );
  }
}

/// Recent SOS — the latest SOS log entries (history).
class _RecentSosSection extends ConsumerWidget {
  const _RecentSosSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<SosRequest> log = ref.watch(sosLogProvider);
    return _SectionCard(
      title: 'Recent SOS',
      icon: Symbols.history_rounded,
      child: log.isEmpty
          ? const EmptyState(
              title: 'No SOS yet',
              message: 'Recent SOS requests will be listed here.',
              icon: Symbols.sos_rounded,
            )
          : Column(
              children: log.take(5).map((SosRequest s) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: <Widget>[
                      Icon(s.type.icon, size: 18, color: s.type.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${s.type.label} • ${s.requesterName}',
                            style: theme.textTheme.bodySmall,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Text(Formatters.relative(s.createdAt),
                          style: theme.textTheme.labelSmall),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

/// Network health — this device's live mesh formation state.
class _MeshHealthSection extends ConsumerWidget {
  const _MeshHealthSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final MeshManagerState mesh = ref.watch(meshManagerProvider);
    return _SectionCard(
      title: 'Network health',
      icon: Symbols.vital_signs_rounded,
      child: Column(
        children: <Widget>[
          _kv('Status', mesh.status.label, theme),
          _kv('Connected', '${mesh.connectedCount}/${mesh.maxConnections}',
              theme),
          _kv('Quality', mesh.overallQuality.label, theme),
          _kv('Discovery', mesh.isDiscovering ? 'Scanning' : 'Idle', theme),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, ThemeData theme) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(k, style: theme.textTheme.bodySmall),
            Text(v,
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

/// Connected devices — this device's directly-connected peers.
class _ConnectedMeshDevicesSection extends ConsumerWidget {
  const _ConnectedMeshDevicesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final MeshManagerState mesh = ref.watch(meshManagerProvider);
    return _SectionCard(
      title: 'Connected devices',
      icon: Symbols.devices_rounded,
      child: mesh.connectedDevices.isEmpty
          ? const EmptyState(
              title: 'No devices connected',
              message: 'Nearby SUMPAY devices will connect automatically.',
              icon: Symbols.wifi_tethering_off_rounded,
            )
          : Column(
              children: mesh.connectedDevices.map((NearbyDevice d) {
                final LinkHealth? health = mesh.linkHealth[d.endpointId];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: <Widget>[
                      const Icon(Symbols.smartphone_rounded, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(d.name,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Text((health?.quality ?? ConnectionQuality.unknown).label,
                          style: theme.textTheme.labelSmall),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

/// Online volunteers — mesh nodes acting as volunteer/relay points that are up.
class _OnlineVolunteersSection extends ConsumerWidget {
  const _OnlineVolunteersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final CommandStatistics stats = ref.watch(commandStatisticsProvider);
    final List<MeshNode> online = ref.watch(onlineNodesProvider);
    return _SectionCard(
      title: 'Online volunteers',
      icon: Symbols.diversity_3_rounded,
      trailing: Text('${stats.volunteersDeployed} deployed',
          style: theme.textTheme.labelSmall),
      child: online.isEmpty
          ? const EmptyState(
              title: 'No one online',
              message: 'Volunteers and nearby devices will appear here.',
              icon: Symbols.person_off_rounded,
            )
          : Column(
              children: online.take(5).map((MeshNode n) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: <Widget>[
                      const Icon(Symbols.person_pin_circle_rounded, size: 18,
                          color: AppColors.success),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(n.label,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Text('${n.connectedClients} clients',
                          style: theme.textTheme.labelSmall),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

/// Map placeholder — the seam for the future precached offline map.
class _MapPlaceholderSection extends StatelessWidget {
  const _MapPlaceholderSection();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _SectionCard(
      title: 'Map',
      icon: Symbols.map_rounded,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 180,
          width: double.infinity,
          color: AppColors.info.withValues(alpha: 0.08),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Symbols.map_rounded, size: 34, color: AppColors.info),
              const SizedBox(height: 6),
              Text('Barangay map',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: AppColors.info)),
              Text('Precached offline map integrates here',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.45))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Broadcast panel — quick entry to issue a barangay-wide broadcast.
class _BroadcastPanelSection extends ConsumerWidget {
  const _BroadcastPanelSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return _SectionCard(
      title: 'Broadcast panel',
      icon: Symbols.campaign_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Issue an alert or advisory to the whole barangay.',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BroadcastSeverity.values.map((BroadcastSeverity s) {
              return FilledButton.tonalIcon(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: s.softColor,
                  foregroundColor: s.color,
                ),
                icon: const Icon(Symbols.campaign_rounded, size: 18),
                label: Text(s.label),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Recent broadcasts — the latest issued broadcasts.
class _RecentBroadcastsSection extends ConsumerWidget {
  const _RecentBroadcastsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<BroadcastMessage> broadcasts = ref.watch(broadcastsProvider);
    return _SectionCard(
      title: 'Recent broadcasts',
      icon: Symbols.podcasts_rounded,
      child: broadcasts.isEmpty
          ? const EmptyState(
              title: 'No broadcasts',
              message: 'Issued broadcasts will appear here.',
              icon: Symbols.campaign_rounded,
            )
          : Column(
              children: broadcasts.take(4).map((BroadcastMessage b) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: <Widget>[
                      Container(
                        height: 8, width: 8,
                        decoration: BoxDecoration(
                            color: b.severity.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(b.title,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Text(Formatters.relative(b.issuedAt),
                          style: theme.textTheme.labelSmall),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

/// Community chat — a compact preview of the latest community messages.
class _CommunityChatSection extends ConsumerWidget {
  const _CommunityChatSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<ChatMessage> messages =
        ref.watch(communityChatProvider).messages;
    return _SectionCard(
      title: 'Community chat',
      icon: Symbols.forum_rounded,
      child: messages.isEmpty
          ? const EmptyState(
              title: 'No messages',
              message: 'Community messages will appear here.',
              icon: Symbols.forum_rounded,
            )
          : Column(
              children: messages.reversed.take(4).map((ChatMessage m) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(m.senderName,
                          style: theme.textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text(m.body,
                          style: theme.textTheme.bodySmall,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared section scaffold
// ---------------------------------------------------------------------------

/// A titled card wrapper used by every section for a consistent Material 3 look.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
