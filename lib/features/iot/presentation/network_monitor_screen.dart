import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../models/mesh_manager_state.dart';
import '../models/nearby_device.dart';
import '../providers/mesh_manager_provider.dart';
import '../providers/network_view_provider.dart';
import '../providers/packet_reliability_provider.dart';

/// Detailed network monitoring for administrators and barangay officials.
///
/// Shows only real, measured mesh data: overall status, connected and
/// discovered peers, per-link health (round-trip latency and missed
/// heartbeats), and packet reliability counts. No simulated values.
class NetworkMonitorScreen extends ConsumerWidget {
  const NetworkMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final NetworkView view = ref.watch(networkViewProvider);
    final MeshManagerState mesh = ref.watch(meshManagerProvider);
    final ReliabilityStats reliability = ref.watch(reliabilityStatsProvider);

    return Scaffold(
      appBar: const SumpayAppBar(
        title: 'Network monitoring',
        subtitle: 'Live network diagnostics',
      ),
      body: SafeArea(
        top: false,
        child: ContentContainer(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageInset,
              8,
              context.pageInset,
              26,
            ),
            children: <Widget>[
              // Overall status summary.
              AppCard(
                child: Column(
                  children: <Widget>[
                    _StatRow(
                      label: 'Connection mode',
                      value: view.mode.label,
                    ),
                    _StatRow(
                      label: 'Network status',
                      value: _meshStatusLabel(mesh.status),
                    ),
                    _StatRow(
                      label: 'Internet connection',
                      value: view.internetConnected ? 'Online' : 'Offline',
                    ),
                    _StatRow(
                      label: 'Connected peers',
                      value: '${mesh.connectedDevices.length}'
                          ' / ${mesh.maxConnections}',
                    ),
                    _StatRow(
                      label: 'Discovered peers',
                      value: '${mesh.discoveredDevices.length}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Message reliability (real counts).
              const SectionHeader(
                title: 'Message reliability',
                subtitle: 'Message delivery across the SUMPAY Network.',
              ),
              AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    _Metric(
                      label: 'Pending',
                      value: reliability.pending,
                      color: AppColors.warning,
                    ),
                    _Metric(
                      label: 'Forwarded',
                      value: reliability.forwarded,
                      color: AppColors.info,
                    ),
                    _Metric(
                      label: 'Delivered',
                      value: reliability.delivered,
                      color: AppColors.success,
                    ),
                    _Metric(
                      label: 'Failed',
                      value: reliability.failed,
                      color: AppColors.danger,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Connected devices with per-link health.
              SectionHeader(
                title: 'Connected devices',
                subtitle: '${mesh.connectedDevices.length} active link(s).',
              ),
              if (mesh.connectedDevices.isEmpty)
                const AppCard(
                  child: EmptyState(
                    icon: Symbols.wifi_tethering_off_rounded,
                    title: 'No connected devices',
                    message:
                        'Devices appear here once connected to nearby '
                        'SUMPAY phones.',
                  ),
                )
              else
                ...mesh.connectedDevices.map((NearbyDevice d) {
                  final LinkHealth? health = mesh.linkHealth[d.endpointId];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Row(
                        children: <Widget>[
                          const Icon(Symbols.smartphone_rounded,
                              color: AppColors.success),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  d.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _healthLabel(health),
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
                  );
                }),

              // Discovered-but-not-connected devices.
              if (mesh.discoveredDevices.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                SectionHeader(
                  title: 'Discovered nearby',
                  subtitle:
                      '${mesh.discoveredDevices.length} device(s) in range.',
                ),
                AppCard(
                  child: Column(
                    children: <Widget>[
                      for (final NearbyDevice d in mesh.discoveredDevices)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: <Widget>[
                              const Icon(Symbols.radar_rounded,
                                  size: 20, color: AppColors.info),
                              const SizedBox(width: 10),
                              Expanded(child: Text(d.name)),
                              Text(
                                'In range',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.info),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              if (mesh.errorMessage != null) ...<Widget>[
                const SizedBox(height: 16),
                AppCard(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderColor: AppColors.danger.withValues(alpha: 0.25),
                  child: Row(
                    children: <Widget>[
                      const Icon(Symbols.error_rounded,
                          color: AppColors.danger, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(mesh.errorMessage!)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _meshStatusLabel(MeshStatus status) => switch (status) {
        MeshStatus.disabled => 'Disabled',
        MeshStatus.starting => 'Starting',
        MeshStatus.searching => 'Searching for devices',
        MeshStatus.connected => 'Connected',
        MeshStatus.error => 'Error',
      };

  String _healthLabel(LinkHealth? health) {
    if (health == null) return 'Link healthy';
    final List<String> parts = <String>[];
    if (health.lastRttMs != null) {
      parts.add('${health.lastRttMs} ms round-trip');
    }
    if (health.missedBeats > 0) {
      parts.add('${health.missedBeats} missed heartbeat(s)');
    }
    if (health.lastHeartbeatAt != null) {
      parts.add('last beat ${Formatters.relative(health.lastHeartbeatAt!)}');
    }
    return parts.isEmpty ? 'Link healthy' : parts.join(' · ');
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

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
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(
          '$value',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
