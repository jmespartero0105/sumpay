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
import '../../../core/widgets/app_inputs.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/info_widgets.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../authentication/models/app_user.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../broadcast/models/broadcast_models.dart';
import '../../broadcast/providers/broadcast_provider.dart';
import '../../iot/models/network_models.dart';
import '../../iot/models/nearby_device.dart';
import '../../iot/providers/mesh_manager_provider.dart';
import '../../sos/models/sos_request.dart';
import '../../sos/models/sos_packet.dart';
import '../../sos/models/responder.dart';
import '../../sos/providers/sos_provider.dart';
import '../../sos/providers/sos_mesh_provider.dart';
import '../models/command_models.dart';
import '../providers/command_provider.dart';

/// Command-centre overview for barangay officials.
class OfficialScreen extends ConsumerWidget {
  const OfficialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppUser user = ref.watch(currentUserProvider);
    final List<SystemAlert> alerts = ref.watch(systemAlertsProvider);

    return Scaffold(
      appBar: SumpayAppBar(
        title: 'Command centre',
        subtitle: '${user.fullName} • Barangay ${user.barangay}',
        actions: <Widget>[
          RoundIconButton(
            icon: Symbols.insert_chart_rounded,
            tooltip: 'Situation overview',
            onPressed: () => context.push(AppRoutes.situationOverview),
          ),
          RoundIconButton(
            icon: Symbols.campaign_rounded,
            tooltip: 'New broadcast',
            onPressed: () => context.go(AppRoutes.broadcast),
          ),
        ],
      ),
      body: SafeArea(
        child: ContentContainer(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageInset,
              6,
              context.pageInset,
              26,
            ),
            children: <Widget>[
              const _SosReportsSection(),
              const SizedBox(height: AppConstants.sectionGap),
              _QuickBroadcastPanel(issuedBy: user.fullName),
              const SizedBox(height: AppConstants.sectionGap),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.barangayMap),
                  icon: const Icon(Symbols.map_rounded),
                  label: const Text('Open barangay map'),
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              _AlertsSection(alerts: alerts),
              const SizedBox(height: 6),
              const SectionHeader(title: 'Connected devices'),
              const _ConnectedDevicesCard(),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            Text(
              '${value.round()}%',
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 9,
            backgroundColor: theme.dividerColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 5),
        Text(detail, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident, required this.onResolve});

  final SosRequest incident;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: incident.type.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  incident.type.icon,
                  size: 22,
                  color: incident.type.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${incident.type.label} • ${incident.id}',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${incident.requesterName} • ${Formatters.relative(incident.createdAt)}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: incident.status.label,
                color: incident.status.color,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            incident.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(
                incident.hasCapturedLocation
                    ? Symbols.my_location_rounded
                    : Symbols.location_off_rounded,
                size: 15,
                color: incident.hasCapturedLocation
                    ? AppColors.info
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  incident.hasCapturedLocation
                      ? incident.coordinates
                      : 'No coordinates attached',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
              Text(
                'Received ${Formatters.time(incident.createdAt)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              StatusChip(
                label: incident.priority.label,
                color: incident.priority.color,
                dense: true,
              ),
              StatusChip(
                label: incident.locationLabel,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                icon: Symbols.location_on_rounded,
                dense: true,
              ),
              StatusChip(
                label: '${incident.peopleAffected} affected',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                icon: Symbols.groups_rounded,
                dense: true,
              ),
              StatusChip(
                label: incident.respondingUnit ?? 'Unassigned',
                color: incident.respondingUnit == null
                    ? AppColors.warning
                    : AppColors.success,
                icon: Symbols.local_shipping_rounded,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: onResolve,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: AppColors.success,
                  ),
                  icon: const Icon(Symbols.check_rounded, size: 20),
                  label: const Text('Resolve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Incoming SOS received across the mesh, with their live status and official
/// acknowledgement actions. Renders nothing when there are no mesh SOS.
class _IncomingMeshSosSection extends ConsumerStatefulWidget {
  const _IncomingMeshSosSection();

  @override
  ConsumerState<_IncomingMeshSosSection> createState() =>
      _IncomingMeshSosSectionState();
}

class _IncomingMeshSosSectionState
    extends ConsumerState<_IncomingMeshSosSection> {
  int _filter = 0;
  bool _tableView = false;
  String _query = '';

  static const List<String> _filters = <String>[
    'All',
    'New',
    'Responding',
    'Resolved',
  ];

  List<TrackedSos> _apply(List<TrackedSos> source) {
    List<TrackedSos> result = switch (_filter) {
      1 => source
          .where((TrackedSos t) =>
              t.status == SosStatus.sent ||
              t.status == SosStatus.relayed ||
              t.status == SosStatus.delivered)
          .toList(),
      2 => source
          .where((TrackedSos t) =>
              t.status == SosStatus.responderAccepted ||
              t.status == SosStatus.responderEnRoute ||
              t.status == SosStatus.arrived)
          .toList(),
      3 => source
          .where((TrackedSos t) => t.status == SosStatus.resolved)
          .toList(),
      _ => source,
    };
    final String q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((TrackedSos t) {
        final bool typeMatch =
            t.packet.typesSummary.toLowerCase().contains(q);
        final bool initiatorMatch =
            t.packet.residentName.toLowerCase().contains(q);
        final bool responderMatch = t.responders
            .any((Responder r) => r.name.toLowerCase().contains(q));
        return typeMatch || initiatorMatch || responderMatch;
      }).toList();
    }
    return result;
  }

  /// Opens a detail sheet for one incident showing who initiated it and the
  /// full list of responders with their individual states.
  void _showSosDetail(BuildContext context, TrackedSos t) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        final SosPacket p = t.packet;
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 4, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(p.emergencyType.icon,
                      color: p.emergencyType.color, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${p.typesSummary} emergency',
                        style: theme.textTheme.titleLarge),
                  ),
                  StatusChip(label: t.status.label, color: p.emergencyType.color),
                ],
              ),
              const SizedBox(height: 16),
              _DetailLine(
                  icon: Symbols.person_rounded,
                  label: 'Initiated by',
                  value: p.residentName),
              _DetailLine(
                  icon: Symbols.location_on_rounded,
                  label: 'Location',
                  value: p.locationLabel?.isNotEmpty == true
                      ? p.locationLabel!
                      : (p.latitude != null && p.longitude != null)
                          ? '${p.latitude!.toStringAsFixed(5)}, ${p.longitude!.toStringAsFixed(5)}'
                          : 'No location shared'),
              if (p.note != null && p.note!.isNotEmpty)
                _DetailLine(
                    icon: Symbols.notes_rounded,
                    label: 'Note',
                    value: p.note!),
              const SizedBox(height: 16),
              Text('Responders (${t.responderCount})',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (t.responders.isEmpty)
                Text('No responders yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6)))
              else
                ...t.responders.map((Responder r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            r.state == ResponderState.onScene
                                ? Symbols.pin_drop_rounded
                                : r.state == ResponderState.enRoute
                                    ? Symbols.directions_run_rounded
                                    : Symbols.check_circle_rounded,
                            size: 18,
                            color: r.state == ResponderState.onScene
                                ? AppColors.success
                                : AppColors.info,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(r.name)),
                          Text(r.state.label,
                              style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6))),
                        ],
                      ),
                    )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<TrackedSos> tracked = ref.watch(sosMeshProvider);
    if (tracked.isEmpty) return const SizedBox.shrink();
    final List<TrackedSos> visible = _apply(tracked);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: SectionHeader(
                title: 'Incoming SOS',
                subtitle: 'Emergencies received over the SUMPAY Network.',
              ),
            ),
            IconButton(
              tooltip: _tableView ? 'Card view' : 'Table view',
              onPressed: () => setState(() => _tableView = !_tableView),
              icon: Icon(_tableView
                  ? Symbols.view_agenda_rounded
                  : Symbols.table_rows_rounded),
            ),
          ],
        ),
        FilterChipRow(
          labels: _filters,
          selectedIndex: _filter,
          onSelected: (int i) => setState(() => _filter = i),
        ),
        const SizedBox(height: 10),
        AppSearchBar(
          hint: 'Search by type, resident, or responder',
          onChanged: (String v) => setState(() => _query = v),
        ),
        const SizedBox(height: 10),
        if (visible.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Symbols.filter_alt_off_rounded,
              title: 'None match this filter',
              message: 'Try a different status filter.',
            ),
          )
        else if (_tableView)
          _MeshSosTable(
            incidents: visible,
            onTap: (TrackedSos t) => _showSosDetail(context, t),
          )
        else
          ...visible.map((TrackedSos t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MeshSosCard(tracked: t),
              )),
        const SizedBox(height: AppConstants.sectionGap),
      ],
    );
  }
}

/// Compact table view of incoming SOS for officials.
class _MeshSosTable extends StatelessWidget {
  const _MeshSosTable({required this.incidents, required this.onTap});

  final List<TrackedSos> incidents;
  final void Function(TrackedSos) onTap;

  Color _statusColor(SosStatus status) => switch (status) {
        SosStatus.resolved => AppColors.success,
        SosStatus.rejected => AppColors.textSecondary,
        SosStatus.cancelled => AppColors.textSecondary,
        SosStatus.responderAccepted ||
        SosStatus.responderEnRoute ||
        SosStatus.arrived =>
          AppColors.info,
        _ => AppColors.emergency,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        horizontalMargin: 10,
        showCheckboxColumn: false,
        headingRowColor: WidgetStateProperty.all(
            theme.colorScheme.surfaceContainerHighest),
        columns: const <DataColumn>[
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Initiated by')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Responders')),
          DataColumn(label: Text('Location')),
        ],
        rows: incidents.map((TrackedSos t) {
          final SosPacket p = t.packet;
          return DataRow(
            onSelectChanged: (_) => onTap(t),
            cells: <DataCell>[
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(p.emergencyType.icon,
                      size: 16, color: p.emergencyType.color),
                  const SizedBox(width: 6),
                  Text(p.emergencyType.label),
                ],
              )),
              DataCell(Text(p.residentName)),
              DataCell(StatusChip(
                  label: t.status.label,
                  color: _statusColor(t.status),
                  dense: true)),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (t.responderCount > 0) ...<Widget>[
                    Icon(Symbols.groups_rounded,
                        size: 15,
                        color:
                            t.anyOnScene ? AppColors.success : AppColors.info),
                    const SizedBox(width: 4),
                  ],
                  Text(t.responderCount == 0
                      ? '—'
                      : '${t.responderCount}'
                          '${t.anyOnScene ? ' • on scene' : ''}'),
                ],
              )),
              DataCell(ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  p.locationLabel?.isNotEmpty == true
                      ? p.locationLabel!
                      : (p.latitude != null && p.longitude != null)
                          ? '${p.latitude!.toStringAsFixed(4)}, ${p.longitude!.toStringAsFixed(4)}'
                          : 'No location',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MeshSosCard extends ConsumerWidget {
  const _MeshSosCard({required this.tracked});

  final TrackedSos tracked;

  Color _statusColor(SosStatus status) => switch (status) {
        SosStatus.sent => AppColors.textSecondary,
        SosStatus.relayed => AppColors.warning,
        SosStatus.delivered => AppColors.info,
        SosStatus.responderAccepted => AppColors.info,
        SosStatus.rejected => AppColors.danger,
        SosStatus.cancelled => AppColors.textSecondary,
        SosStatus.responderEnRoute => AppColors.warning,
        SosStatus.arrived => AppColors.info,
        SosStatus.resolved => AppColors.success,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final SosPacket sos = tracked.packet;
    final Color color = _statusColor(tracked.status);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: sos.emergencyType.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(sos.emergencyType.icon,
                    color: sos.emergencyType.color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(sos.residentName, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${sos.typesSummary} • ${Formatters.relative(sos.createdAt)}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: tracked.status.label,
                color: color,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(Symbols.badge_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text('ID ${sos.sosId} • Resident ${sos.residentId}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  )),
            ],
          ),
          if (tracked.responderCount > 0) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(Symbols.groups_rounded,
                    size: 15,
                    color: tracked.anyOnScene
                        ? AppColors.success
                        : AppColors.info),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${tracked.responderCount} responding: '
                    '${tracked.responders.map((Responder r) => r.name).join(', ')}'
                    '${tracked.anyOnScene ? ' • on scene' : ''}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: AppColors.info),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (sos.latitude != null && sos.longitude != null) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                const Icon(Symbols.my_location_rounded,
                    size: 14, color: AppColors.info),
                const SizedBox(width: 6),
                Text(
                  '${sos.latitude!.toStringAsFixed(5)}, ${sos.longitude!.toStringAsFixed(5)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
          ],
          // Command Centre is monitoring-only: no resolve/acknowledge actions.
          // Residents own resolution of their own SOS; officials observe.
        ],
      ),
    );
  }
}

/// Displays official emergency alerts (evacuation notices and barangay
/// warnings). High-priority alerts are always shown and pinned on top; the
/// remaining lower-priority alerts are collapsed behind a "Show all" toggle so
/// the feed does not overwhelm the screen.
class _AlertsSection extends StatefulWidget {
  const _AlertsSection({required this.alerts});

  final List<SystemAlert> alerts;

  @override
  State<_AlertsSection> createState() => _AlertsSectionState();
}

class _AlertsSectionState extends State<_AlertsSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final List<SystemAlert> alerts = widget.alerts;
    if (alerts.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'Emergency alerts',
            subtitle: 'Evacuation notices and barangay warnings.',
          ),
          AppCard(
            child: EmptyState(
              icon: Symbols.campaign_rounded,
              title: 'No active alerts',
              message:
                  'Evacuation notices and emergency alerts you issue will '
                  'appear here.',
            ),
          ),
        ],
      );
    }

    final List<SystemAlert> high =
        alerts.where(isHighPriorityAlert).toList();
    final List<SystemAlert> rest =
        alerts.where((SystemAlert a) => !isHighPriorityAlert(a)).toList();

    // Always show high-priority (pinned). Show the rest only when expanded.
    final List<SystemAlert> visible = <SystemAlert>[
      ...high,
      if (_showAll) ...rest,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Emergency alerts',
          subtitle: high.isNotEmpty
              ? '${high.length} high-priority'
              : '${alerts.length} active',
        ),
        ...visible.map(
          (SystemAlert alert) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AlertCard(
              alert: alert,
              pinned: isHighPriorityAlert(alert),
            ),
          ),
        ),
        if (rest.isNotEmpty)
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () => setState(() => _showAll = !_showAll),
              icon: Icon(_showAll
                  ? Symbols.expand_less_rounded
                  : Symbols.expand_more_rounded),
              label: Text(_showAll
                  ? 'Show fewer'
                  : 'Show all alerts (${rest.length} more)'),
            ),
          ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.pinned});

  final SystemAlert alert;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      color: alert.severity.softColor,
      borderColor: alert.severity.color.withValues(alpha: pinned ? 0.5 : 0.28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            pinned ? Symbols.priority_high_rounded : Symbols.campaign_rounded,
            size: 22,
            color: alert.severity.color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (pinned) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: alert.severity.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          alert.severity.label.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        alert.title,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      Formatters.relative(alert.raisedAt),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  alert.detail,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Predefined broadcast templates for one-tap sending. Each severity has a
/// ready-to-send advisory so officials can push urgent notices without typing.
class _QuickBroadcastTemplate {
  const _QuickBroadcastTemplate({
    required this.severity,
    required this.title,
    required this.body,
    required this.icon,
  });

  final BroadcastSeverity severity;
  final String title;
  final String body;
  final IconData icon;
}

const List<_QuickBroadcastTemplate> _kQuickTemplates = <_QuickBroadcastTemplate>[
  _QuickBroadcastTemplate(
    severity: BroadcastSeverity.advisory,
    title: 'Community Advisory',
    body:
        'Please stay alert and monitor official channels for updates. Prepare '
        'your emergency kit and keep phones charged.',
    icon: Symbols.info_rounded,
  ),
  _QuickBroadcastTemplate(
    severity: BroadcastSeverity.warning,
    title: 'Weather Warning',
    body:
        'Hazardous conditions are expected in our area. Avoid low-lying and '
        'flood-prone areas and be ready to move to higher ground.',
    icon: Symbols.warning_rounded,
  ),
  _QuickBroadcastTemplate(
    severity: BroadcastSeverity.alert,
    title: 'EVACUATION ALERT',
    body:
        'Immediate evacuation is advised. Proceed calmly to the nearest '
        'designated evacuation center. Assist elderly and children first.',
    icon: Symbols.emergency_home_rounded,
  ),
];

/// One-tap broadcast panel on the official home: predefined advisory, warning,
/// and alert messages that publish (and transmit over mesh + internet) after a
/// short confirmation.
class _QuickBroadcastPanel extends ConsumerWidget {
  const _QuickBroadcastPanel({required this.issuedBy});

  final String issuedBy;

  Future<void> _send(
    BuildContext context,
    WidgetRef ref,
    _QuickBroadcastTemplate template,
  ) async {
    final bool ok = await AppDialogs.confirm(
      context,
      title: 'Send ${template.severity.label.toLowerCase()}?',
      message:
          'This broadcasts "${template.title}" to all residents in the '
          'barangay immediately.',
      confirmLabel: 'Send now',
      icon: template.icon,
      accent: template.severity.color,
      destructive: template.severity == BroadcastSeverity.alert,
    );
    if (!ok || !context.mounted) return;

    ref.read(broadcastsProvider.notifier).publish(
          BroadcastDraft(
            title: template.title,
            body: template.body,
            severity: template.severity,
          ),
          issuedBy: issuedBy,
        );
    if (context.mounted) {
      AppDialogs.snack(context, '${template.title} broadcast sent',
          icon: Symbols.check_circle_rounded);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Quick broadcast',
          subtitle: 'Send a predefined notice to all residents.',
          actionLabel: 'Custom',
          onAction: () => context.go(AppRoutes.broadcast),
        ),
        ..._kQuickTemplates.map(
          (_QuickBroadcastTemplate t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => _send(context, ref, t),
              borderRadius: BorderRadius.circular(14),
              child: AppCard(
                color: t.severity.softColor,
                borderColor: t.severity.color.withValues(alpha: 0.3),
                child: Row(
                  children: <Widget>[
                    Icon(t.icon, color: t.severity.color, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: t.severity.color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  t.severity.label.toUpperCase(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(t.title,
                                    style: theme.textTheme.titleSmall),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Symbols.send_rounded,
                        size: 18, color: t.severity.color),
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

/// A small labelled detail line (icon • label • value) for the SOS detail sheet.
class _DetailLine extends StatelessWidget {
  const _DetailLine({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: Text(label,
                style: theme.textTheme.labelMedium?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.55))),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Previous incidents (from Supabase) so the Command Centre can monitor every
/// SOS — past and present — with its status. Filterable by status.
class _SosReportsSection extends ConsumerStatefulWidget {
  const _SosReportsSection();

  @override
  ConsumerState<_SosReportsSection> createState() =>
      _SosReportsSectionState();
}

class _SosReportsSectionState
    extends ConsumerState<_SosReportsSection> {
  int _filter = 0;
  String _query = '';
  EmergencyType? _typeFilter; // null = all types
  bool _tableView = false;
  int _page = 0;
  static const int _pageSize = 10;

  static const List<String> _filters = <String>[
    'All',
    'Active',
    'Resolved',
    'Cancelled',
  ];

  List<SosRequest> _apply(List<SosRequest> source) {
    List<SosRequest> result = switch (_filter) {
      1 => source
          .where((SosRequest r) =>
              r.status == IncidentStatus.active ||
              r.status == IncidentStatus.responding)
          .toList(),
      2 => source
          .where((SosRequest r) => r.status == IncidentStatus.resolved)
          .toList(),
      3 => source
          .where((SosRequest r) => r.status == IncidentStatus.cancelled)
          .toList(),
      _ => source,
    };
    // Emergency-type filter (matches primary or any additional type).
    if (_typeFilter != null) {
      result = result
          .where((SosRequest r) =>
              r.type == _typeFilter ||
              r.additionalTypes.contains(_typeFilter))
          .toList();
    }
    final String q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result
          .where((SosRequest r) =>
              r.typesSummary.toLowerCase().contains(q) ||
              r.requesterName.toLowerCase().contains(q) ||
              (r.respondingUnit ?? '').toLowerCase().contains(q))
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<SosRequest>> history =
        ref.watch(allSosHistoryProvider);
    // Live incidents received this session, merged with cloud history so this
    // one section shows every report — live + past — with no separate list.
    final List<TrackedSos> live = ref.watch(sosMeshProvider);

    List<SosRequest> mergeLive(List<SosRequest> cloud) {
      final Map<String, SosRequest> byId = <String, SosRequest>{
        for (final SosRequest r in cloud) r.id: r,
      };
      for (final TrackedSos t in live) {
        final SosPacket p = t.packet;
        final IncidentStatus incident = switch (t.status) {
          SosStatus.resolved => IncidentStatus.resolved,
          SosStatus.cancelled => IncidentStatus.cancelled,
          SosStatus.responderAccepted ||
          SosStatus.responderEnRoute ||
          SosStatus.arrived =>
            IncidentStatus.responding,
          _ => IncidentStatus.active,
        };
        final SosRequest? existing = byId[t.sosId];
        final bool cloudTerminal = existing != null &&
            (existing.status == IncidentStatus.resolved ||
                existing.status == IncidentStatus.cancelled);
        if (cloudTerminal) continue;
        byId[t.sosId] = SosRequest(
          id: t.sosId,
          type: p.emergencyType,
          additionalTypes: p.additionalTypes,
          priority: p.priority,
          description: p.note ?? '',
          locationLabel: p.locationLabel ?? '',
          latitude: p.latitude ?? 0,
          longitude: p.longitude ?? 0,
          createdAt: p.createdAt,
          status: incident,
          delivery: DeliveryStatus.delivered,
          hopCount: 0,
          peopleAffected: 1,
          requesterName: p.residentName,
          requesterId: p.residentId,
          respondingUnit: t.responderSummary,
        );
      }
      final List<SosRequest> merged = byId.values.toList()
        ..sort((SosRequest a, SosRequest b) =>
            b.createdAt.compareTo(a.createdAt));
      return merged;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: SectionHeader(
                title: 'SOS reports',
                subtitle: 'All barangay SOS — live and past.',
              ),
            ),
            IconButton(
              tooltip: _tableView ? 'Card view' : 'Table view',
              onPressed: () => setState(() => _tableView = !_tableView),
              icon: Icon(_tableView
                  ? Symbols.view_agenda_rounded
                  : Symbols.table_rows_rounded),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(allSosHistoryProvider),
              icon: const Icon(Symbols.refresh_rounded),
            ),
          ],
        ),
        FilterChipRow(
          labels: _filters,
          selectedIndex: _filter,
          onSelected: (int i) => setState(() {
            _filter = i;
            _page = 0;
          }),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: DropdownButton<EmergencyType?>(
            value: _typeFilter,
            hint: const Text('All emergency types'),
            underline: const SizedBox.shrink(),
            items: <DropdownMenuItem<EmergencyType?>>[
              const DropdownMenuItem<EmergencyType?>(
                value: null,
                child: Text('All emergency types'),
              ),
              ...EmergencyType.residentSelectable.map(
                (EmergencyType t) => DropdownMenuItem<EmergencyType?>(
                  value: t,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(t.icon, size: 16, color: t.color),
                      const SizedBox(width: 6),
                      Text(t.label),
                    ],
                  ),
                ),
              ),
            ],
            onChanged: (EmergencyType? v) => setState(() {
              _typeFilter = v;
              _page = 0;
            }),
          ),
        ),
        const SizedBox(height: 10),
        AppSearchBar(
          hint: 'Search by type, resident, or responder',
          onChanged: (String v) => setState(() {
            _query = v;
            _page = 0;
          }),
        ),
        const SizedBox(height: 10),
        history.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object e, StackTrace s) => AppCard(
            child: Text('Could not load history.',
                style: theme.textTheme.bodyMedium),
          ),
          data: (List<SosRequest> all) {
            final List<SosRequest> visible = _apply(mergeLive(all));
            if (visible.isEmpty) {
              return const AppCard(
                child: EmptyState(
                  icon: Symbols.history_rounded,
                  title: 'No previous incidents',
                  message: 'Resolved and past SOS will appear here.',
                ),
              );
            }
            final int totalPages = (visible.length / _pageSize).ceil();
            final int page = _page.clamp(0, totalPages - 1);
            final int start = page * _pageSize;
            final int end = (start + _pageSize).clamp(0, visible.length);
            final List<SosRequest> pageItems = visible.sublist(start, end);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_tableView)
                  _PreviousIncidentsTable(items: pageItems)
                else
                  ...pageItems.map((SosRequest r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PreviousIncidentTile(request: r),
                      )),
                const SizedBox(height: 8),
                _PaginationBar(
                  page: page,
                  totalPages: totalPages,
                  totalItems: visible.length,
                  onPrev: page > 0
                      ? () => setState(() => _page = page - 1)
                      : null,
                  onNext: page < totalPages - 1
                      ? () => setState(() => _page = page + 1)
                      : null,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PreviousIncidentTile extends StatelessWidget {
  const _PreviousIncidentTile({required this.request});

  final SosRequest request;

  Color _statusColor(IncidentStatus s) => s.color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(request.type.icon, color: request.type.color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(request.typesSummary,
                    style: theme.textTheme.titleSmall),
              ),
              StatusChip(
                  label: request.status.label,
                  color: _statusColor(request.status),
                  dense: true),
            ],
          ),
          const SizedBox(height: 6),
          _MetaRow(
              icon: Symbols.person_rounded,
              text: 'Resident: ${request.requesterName}'),
          _MetaRow(
              icon: Symbols.volunteer_activism_rounded,
              text: request.respondingUnit != null &&
                      request.respondingUnit!.isNotEmpty
                  ? 'Responder: ${request.respondingUnit}'
                  : 'No responder recorded'),
          _MetaRow(
              icon: Symbols.location_on_rounded,
              text: request.locationLabel),
          _MetaRow(
              icon: Symbols.schedule_rounded,
              text: Formatters.dateTime(request.createdAt)),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: <Widget>[
          Icon(icon,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: theme.textTheme.bodySmall, maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// Real connected devices from the mesh manager. Shows an empty state when none
/// are connected (e.g. on web, where the mesh is disabled). No mock data.
class _ConnectedDevicesCard extends ConsumerWidget {
  const _ConnectedDevicesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<NearbyDevice> devices =
        ref.watch(meshManagerProvider).connectedDevices;

    if (devices.isEmpty) {
      return const AppCard(
        child: EmptyState(
          icon: Symbols.devices_off_rounded,
          title: 'No devices connected',
          message:
              'Nearby devices on the SUMPAY Network will appear here. On the web '
              'version the app runs over the internet only.',
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: devices
            .map((NearbyDevice d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: <Widget>[
                      Container(
                        height: 10,
                        width: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          d.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontSize: 13.5),
                        ),
                      ),
                      const Icon(Symbols.link_rounded,
                          size: 18, color: AppColors.success),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

/// Table view of previous incidents with a responder column.
class _PreviousIncidentsTable extends StatelessWidget {
  const _PreviousIncidentsTable({required this.items});

  final List<SosRequest> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        horizontalMargin: 10,
        headingRowColor: WidgetStateProperty.all(
            theme.colorScheme.surfaceContainerHighest),
        columns: const <DataColumn>[
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Resident')),
          DataColumn(label: Text('Responder')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Date')),
        ],
        rows: items.map((SosRequest r) {
          return DataRow(
            cells: <DataCell>[
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(r.type.icon, size: 16, color: r.type.color),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(r.typesSummary,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              )),
              DataCell(Text(r.requesterName)),
              DataCell(Text(
                  r.respondingUnit != null && r.respondingUnit!.isNotEmpty
                      ? r.respondingUnit!
                      : '—')),
              DataCell(StatusChip(
                  label: r.status.label, color: r.status.color, dense: true)),
              DataCell(Text(Formatters.dateTime(r.createdAt))),
            ],
          );
        }).toList(),
      ),
    );
  }
}

/// Simple prev/next pagination bar with a page indicator.
class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.totalItems,
    this.onPrev,
    this.onNext,
  });

  final int page;
  final int totalPages;
  final int totalItems;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('$totalItems total',
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        Row(
          children: <Widget>[
            IconButton(
              onPressed: onPrev,
              icon: const Icon(Symbols.chevron_left_rounded),
              tooltip: 'Previous page',
            ),
            Text('Page ${page + 1} of $totalPages',
                style: theme.textTheme.bodyMedium),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Symbols.chevron_right_rounded),
              tooltip: 'Next page',
            ),
          ],
        ),
      ],
    );
  }
}
