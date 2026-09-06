import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/info_widgets.dart';
import '../../iot/models/network_models.dart';
import '../../iot/providers/network_provider.dart';
import '../models/command_models.dart';
import '../providers/command_provider.dart';

/// The barangay situation overview: at-a-glance metrics and coverage. Moved off
/// the main Command Centre so the dashboard stays focused on live incidents;
/// reached via the chart icon in the Command Centre app bar.
class SituationOverviewScreen extends ConsumerWidget {
  const SituationOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final CommandStatistics stats = ref.watch(commandStatisticsProvider);
    final List<MeshNode> nodes = ref.watch(meshNodesProvider);
    final List<MeshNode> online = ref.watch(onlineNodesProvider);
    final double deviceAvailability =
        nodes.isEmpty ? 0 : (online.length / nodes.length) * 100;

    return Scaffold(
      appBar: const SumpayAppBar(
        title: 'Situation overview',
        subtitle: 'Barangay status at a glance',
      ),
      body: SafeArea(
        child: ContentContainer(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                context.pageInset, 12, context.pageInset, 26),
            children: <Widget>[
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount:
                    context.gridColumns(phone: 2, tablet: 3, desktop: 4),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: <Widget>[
                  MetricTile(
                    value: '${stats.activeIncidents}',
                    label: 'Active incidents',
                    icon: Symbols.emergency_home_rounded,
                    color: AppColors.emergency,
                  ),
                  MetricTile(
                    value: Formatters.count(stats.residentsOnline),
                    label: 'Residents online',
                    icon: Symbols.wifi_tethering_rounded,
                    color: AppColors.success,
                  ),
                  MetricTile(
                    value: '${stats.connectedNodes}/${stats.totalNodes}',
                    label: 'Devices connected',
                    icon: Symbols.router_rounded,
                    color: AppColors.info,
                  ),
                  MetricTile(
                    value: '${stats.volunteersDeployed}',
                    label: 'Responders deployed',
                    icon: Symbols.volunteer_activism_rounded,
                    color: const Color(0xFF0F8B8D),
                  ),
                  MetricTile(
                    value: Formatters.count(stats.evacuees),
                    label: 'Evacuees sheltered',
                    icon: Symbols.night_shelter_rounded,
                    color: const Color(0xFF7B5AC6),
                  ),
                  MetricTile(
                    value: Formatters.duration(stats.averageResponse),
                    label: 'Avg. response time',
                    icon: Symbols.timer_rounded,
                    color: AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.sectionGap),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Coverage', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    _ProgressRow(
                      label: 'Residents reachable',
                      value: stats.onlineRate,
                      color: AppColors.success,
                      detail:
                          '${stats.residentsOnline} of ${stats.residentsRegistered} registered',
                    ),
                    const SizedBox(height: 16),
                    _ProgressRow(
                      label: 'Broadcast reach',
                      value: stats.acknowledgementRate,
                      color: AppColors.warning,
                      detail: '${stats.broadcastsToday} broadcasts issued today',
                    ),
                    const SizedBox(height: 16),
                    _ProgressRow(
                      label: 'Device availability',
                      value: deviceAvailability,
                      color: AppColors.info,
                      detail: '${online.length} of ${nodes.length} devices online',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.color,
    required this.detail,
  });

  final String label;
  final double value;
  final Color color;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double clamped = (value.isNaN ? 0 : value).clamp(0, 100).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label, style: theme.textTheme.bodyMedium),
            Text('${clamped.round()}%',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: clamped / 100,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(detail,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
      ],
    );
  }
}
