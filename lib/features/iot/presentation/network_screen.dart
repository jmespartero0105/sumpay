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
import '../../../core/widgets/info_widgets.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/signal_bars.dart';
import '../../../core/widgets/state_views.dart';
import '../models/mesh_manager_state.dart';
import '../models/nearby_device.dart';
import '../providers/network_view_provider.dart';
import '../providers/mesh_manager_provider.dart';
import '../providers/packet_reliability_provider.dart';

/// Diagnostics view of the LoRa / mesh network.
class NetworkScreen extends ConsumerWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final NetworkView view = ref.watch(networkViewProvider);

    final Color modeColor = switch (view.mode) {
      ConnectionMode.onlineGateway => AppColors.success,
      ConnectionMode.offlineMesh => AppColors.warning,
      ConnectionMode.none => AppColors.danger,
    };
    final IconData modeIcon = switch (view.mode) {
      ConnectionMode.onlineGateway => Symbols.cloud_done_rounded,
      ConnectionMode.offlineMesh => Symbols.hub_rounded,
      ConnectionMode.none => Symbols.cloud_off_rounded,
    };

    return Scaffold(
      appBar: SumpayAppBar(
        showBack: false,
        title: 'Network status',
        subtitle: 'How your device is connected',
        actions: <Widget>[
          RoundIconButton(
            icon: Symbols.devices_other_rounded,
            tooltip: 'Nearby devices',
            onPressed: () => context.push(AppRoutes.nearby),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ContentContainer(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageInset,
              6,
              context.pageInset,
              26,
            ),
            children: <Widget>[
              // Primary, honest status: online gateway vs offline mesh vs none.
              AppCard(
                color: modeColor.withValues(alpha: 0.07),
                borderColor: modeColor.withValues(alpha: 0.25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          height: 54,
                          width: 54,
                          decoration: BoxDecoration(
                            color: modeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(modeIcon, color: modeColor, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                view.mode.label,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: modeColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                view.mode == ConnectionMode.onlineGateway
                                    ? 'Internet connection'
                                    : view.mode == ConnectionMode.offlineMesh
                                        ? '${view.connectedCount} nearby device(s)'
                                        : 'Waiting for a connection',
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
                    const SizedBox(height: 14),
                    Text(
                      view.mode.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.75),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),

              // Real mesh formation state (auto-discovery / connection).
              const _MeshFormationCard(),
              const SizedBox(height: AppConstants.sectionGap),

              // Simplified "This device" — only real, measured facts.
              const SectionHeader(title: 'This device'),
              AppCard(
                child: Column(
                  children: <Widget>[
                    _InfoRow(
                      label: 'Internet',
                      value: view.internetConnected
                          ? 'Connected'
                          : 'Not available',
                      color: view.internetConnected
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                    _InfoRow(
                      label: 'Nearby mesh',
                      value: view.meshActive
                          ? '${view.connectedCount} connected'
                          : 'No devices connected',
                      color: view.meshActive
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                    _InfoRow(
                      label: 'Updated',
                      value: Formatters.dateTime(view.updatedAt),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),

              // Real recent activity, or a clean empty state.
              const SectionHeader(title: 'Recent activity'),
              _ActivityLog(devices: view.connectedDevices),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple label/value row for the "This device" card.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows currently connected mesh devices as recent activity, or an empty
/// state when none are connected. Purely real data.
class _ActivityLog extends StatelessWidget {
  const _ActivityLog({required this.devices});

  final List<NearbyDevice> devices;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (devices.isEmpty) {
      return const AppCard(
        child: EmptyState(
          icon: Symbols.wifi_tethering_off_rounded,
          title: 'No recent activity',
          message:
              'When you connect to nearby SUMPAY devices, they will appear here.',
        ),
      );
    }
    return AppCard(
      child: Column(
        children: <Widget>[
          for (final NearbyDevice d in devices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: <Widget>[
                  const Icon(Symbols.smartphone_rounded,
                      size: 20, color: AppColors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      d.name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    'Connected',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: AppColors.success),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


/// Automatic mesh formation status: overall mesh status, discovery status,
/// connected device count, and signal (link) quality.
class _MeshFormationCard extends ConsumerWidget {
  const _MeshFormationCard();

  Color _statusColor(MeshStatus status) => switch (status) {
        MeshStatus.connected => AppColors.success,
        MeshStatus.searching => AppColors.info,
        MeshStatus.starting => AppColors.warning,
        MeshStatus.error => AppColors.emergency,
        MeshStatus.disabled => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final MeshManagerState mesh = ref.watch(meshManagerProvider);
    final Color color = _statusColor(mesh.status);

    return AppCard(
      color: color.withValues(alpha: 0.07),
      borderColor: color.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Symbols.wifi_tethering_rounded,
                    color: color, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Mesh status', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 2),
                    Text(mesh.status.label,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: color, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              SignalBars(strength: mesh.overallQuality.bars, color: color),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _MeshStat(
                  icon: Symbols.hub_rounded,
                  label: 'Connected',
                  value: '${mesh.connectedCount}/${mesh.maxConnections}',
                ),
              ),
              Expanded(
                child: _MeshStat(
                  icon: Symbols.travel_explore_rounded,
                  label: 'Discovery',
                  value: mesh.isDiscovering ? 'Scanning' : 'Idle',
                ),
              ),
              Expanded(
                child: _MeshStat(
                  icon: Symbols.network_check_rounded,
                  label: 'Quality',
                  value: mesh.overallQuality.label,
                ),
              ),
            ],
          ),
          if (mesh.connectedDevices.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
          ],
          if (mesh.connectedDevices.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Divider(color: theme.dividerColor, height: 1),
            const SizedBox(height: 10),
            Text('Connected devices', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            ...mesh.connectedDevices.map((NearbyDevice d) {
              final LinkHealth? health = mesh.linkHealth[d.endpointId];
              final ConnectionQuality quality =
                  health?.quality ?? ConnectionQuality.unknown;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    const Icon(Symbols.smartphone_rounded, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(d.name,
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (health?.lastRttMs != null) ...<Widget>[
                      Text('${health!.lastRttMs} ms',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          )),
                      const SizedBox(width: 8),
                    ],
                    SignalBars(strength: quality.bars, height: 14, barWidth: 3),
                  ],
                ),
              );
            }),
          ],
          if (mesh.autoConnectEnabled &&
              mesh.status != MeshStatus.connected &&
              mesh.status != MeshStatus.searching) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    ref.read(meshManagerProvider.notifier).retry(),
                icon: const Icon(Symbols.refresh_rounded, size: 18),
                label: const Text('Start mesh'),
              ),
            ),
          ],
          if (!mesh.autoConnectEnabled) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Icon(Symbols.info_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Auto-connect is off. Enable it in Settings to form the mesh automatically.',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MeshStat extends StatelessWidget {
  const _MeshStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Icon(icon, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// Compact reliability indicators: Pending, Forwarded, Delivered, Failed.
/// Reuses the existing DeliveryStatus colours/labels rather than inventing new
/// indicators.
class _ReliabilityRow extends ConsumerWidget {
  const _ReliabilityRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ReliabilityStats s = ref.watch(reliabilityStatsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Packet delivery', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            _ReliabilityStat(
              label: 'Pending',
              value: s.pending,
              color: DeliveryStatus.queued.color,
              icon: DeliveryStatus.queued.icon,
            ),
            _ReliabilityStat(
              label: 'Forwarded',
              value: s.forwarded,
              color: DeliveryStatus.relayed.color,
              icon: DeliveryStatus.relayed.icon,
            ),
            _ReliabilityStat(
              label: 'Delivered',
              value: s.delivered,
              color: DeliveryStatus.delivered.color,
              icon: DeliveryStatus.delivered.icon,
            ),
            _ReliabilityStat(
              label: 'Failed',
              value: s.failed,
              color: DeliveryStatus.failed.color,
              icon: DeliveryStatus.failed.icon,
            ),
          ],
        ),
      ],
    );
  }
}

class _ReliabilityStat extends StatelessWidget {
  const _ReliabilityStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 3),
          Text('$value',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700, color: color)),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
