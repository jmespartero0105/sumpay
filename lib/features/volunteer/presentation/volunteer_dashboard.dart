import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_inputs.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../sos/models/responder.dart';
import '../../sos/models/sos_location_model.dart';
import '../../sos/models/sos_packet.dart';
import '../../sos/presentation/sos_location_map_screen.dart';
import '../../dashboard/widgets/mode_toggle.dart';
import '../../sos/providers/sos_mesh_provider.dart';
import '../../sos/widgets/map_preview_placeholder.dart';

/// Dedicated Volunteer (responder) dashboard: the incoming SOS queue with
/// priority sorting, resident information, a dummy map, and the full set of
/// response actions (Accept, Reject, En Route, Arrived, Resolved). Status
/// changes are broadcast across the mesh, which notifies the resident.
class VolunteerDashboard extends ConsumerStatefulWidget {
  const VolunteerDashboard({super.key});

  @override
  ConsumerState<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends ConsumerState<VolunteerDashboard> {
  int _filter = 0;
  bool _tableView = false;

  static const List<String> _filters = <String>[
    'All',
    'New',
    'Accepted',
    'En route',
    'Arrived',
    'Resolved',
  ];

  List<TrackedSos> _apply(List<TrackedSos> source) {
    return switch (_filter) {
      1 => source
          .where((TrackedSos t) =>
              t.status == SosStatus.sent ||
              t.status == SosStatus.relayed ||
              t.status == SosStatus.delivered)
          .toList(),
      2 => source
          .where((TrackedSos t) => t.status == SosStatus.responderAccepted)
          .toList(),
      3 => source
          .where((TrackedSos t) => t.status == SosStatus.responderEnRoute)
          .toList(),
      4 => source
          .where((TrackedSos t) => t.status == SosStatus.arrived)
          .toList(),
      5 => source
          .where((TrackedSos t) => t.status == SosStatus.resolved)
          .toList(),
      _ => source,
    };
  }

  @override
  Widget build(BuildContext context) {
    final List<TrackedSos> incidents = ref.watch(sortedIncomingSosProvider);
    final String name = ref.watch(currentUserProvider).fullName;
    final bool isCommunityMember =
        ref.watch(currentUserProvider).role == UserRole.user;

    final int active =
        incidents.where((TrackedSos t) => !t.status.isTerminal).length;
    final List<TrackedSos> visible = _apply(incidents);

    return Scaffold(
      appBar: SumpayAppBar(
        title: 'Responder dashboard',
        subtitle: '$name • Volunteer',
        showBack: false,
        actions: <Widget>[
          IconButton(
            tooltip: _tableView ? 'Card view' : 'Table view',
            onPressed: () => setState(() => _tableView = !_tableView),
            icon: Icon(_tableView
                ? Symbols.view_agenda_rounded
                : Symbols.table_rows_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ContentContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (isCommunityMember) ...<Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      context.pageInset, 12, context.pageInset, 0),
                  child: const ModeToggle(),
                ),
                const SizedBox(height: 12),
              ],
              Padding(
                padding: EdgeInsets.fromLTRB(context.pageInset, 12,
                    context.pageInset, 0),
                child: _SummaryBar(active: active, total: incidents.length),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: SectionHeader(
                  title: 'Incoming SOS',
                  subtitle: 'Sorted by priority. Highest urgency first.',
                ),
              ),
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: context.pageInset),
                child: FilterChipRow(
                  labels: _filters,
                  selectedIndex: _filter,
                  onSelected: (int i) => setState(() => _filter = i),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: visible.isEmpty
                    ? const EmptyState(
                        title: 'No emergencies',
                        message:
                            'Incoming SOS will appear here, most urgent first.',
                        icon: Symbols.sos_rounded,
                      )
                    : _tableView
                        ? _IncidentTable(incidents: visible)
                        : ListView(
                            padding: EdgeInsets.fromLTRB(context.pageInset, 4,
                                context.pageInset, 24),
                            children: <Widget>[
                              ...visible.map((TrackedSos t) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 12),
                                    child: _IncidentCard(tracked: t),
                                  )),
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

/// Compact table view of incoming SOS for responders, toggled from the card
/// view. Tapping a row opens the same incident detail as the card.
class _IncidentTable extends ConsumerWidget {
  const _IncidentTable({required this.incidents});

  final List<TrackedSos> incidents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(context.pageInset, 0, context.pageInset, 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 18,
          horizontalMargin: 10,
          headingRowColor: WidgetStateProperty.all(
              theme.colorScheme.surfaceContainerHighest),
          columns: const <DataColumn>[
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Resident')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Priority')),
            DataColumn(label: Text('Location')),
          ],
          rows: incidents.map((TrackedSos t) {
            final SosPacket p = t.packet;
            return DataRow(
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
                DataCell(Text(p.priority.label)),
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
      ),
    );
  }
}

Color _statusColor(SosStatus status) => switch (status) {
      SosStatus.resolved => AppColors.success,
      SosStatus.rejected => AppColors.textSecondary,
      SosStatus.responderAccepted ||
      SosStatus.responderEnRoute ||
      SosStatus.arrived =>
        AppColors.info,
      _ => AppColors.emergency,
    };

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.active, required this.total});

  final int active;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      color: AppColors.emergency.withValues(alpha: 0.06),
      borderColor: AppColors.emergency.withValues(alpha: 0.20),
      child: Row(
        children: <Widget>[
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: AppColors.emergency,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Symbols.emergency_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('$active active emergenc${active == 1 ? 'y' : 'ies'}',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('$total total in your area',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns the current user's own responder state for [tracked], or null if
/// they have not accepted this SOS. Used to gate the response buttons per-user
/// so multiple responders can each accept independently.
ResponderState? _myResponderState(WidgetRef ref, TrackedSos tracked) {
  final user = ref.watch(currentUserOrNullProvider);
  if (user == null) return null;
  for (final Responder r in tracked.responders) {
    if (r.id == user.id) return r.state;
  }
  return null;
}

class _IncidentCard extends ConsumerWidget {
  const _IncidentCard({required this.tracked});

  final TrackedSos tracked;

  Color _statusColor(SosStatus s) => switch (s) {
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
    final SosMeshController ctrl = ref.read(sosMeshProvider.notifier);
    final SosLocationModel? loc = (sos.latitude != null && sos.longitude != null)
        ? SosLocationModel(
            latitude: sos.latitude!,
            longitude: sos.longitude!,
            accuracy: sos.accuracy ?? 0,
            capturedAt: sos.createdAt,
          )
        : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: type, priority, status.
          Row(
            children: <Widget>[
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: sos.emergencyType.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(sos.emergencyType.icon,
                    color: sos.emergencyType.color, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(sos.typesSummary,
                            style: theme.textTheme.titleSmall),
                        const SizedBox(width: 8),
                        StatusChip(
                          label: sos.priority.label,
                          color: sos.priority.color,
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(Formatters.relative(sos.createdAt),
                        style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              StatusChip(
                label: tracked.status.label,
                color: _statusColor(tracked.status),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Resident information.
          _ResidentInfo(sos: sos),
          const SizedBox(height: 12),

          // Real OSM location preview + actions to open a fullscreen map.
          MapPreviewPlaceholder(location: loc, label: sos.residentName),
          const SizedBox(height: 10),
          MapActionButtons(
            location: loc,
            onOpenMap: loc == null
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SosLocationMapScreen(
                          location: loc!,
                          label: sos.residentName,
                        ),
                      ),
                    ),
            onNavigate: loc == null
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SosLocationMapScreen(
                          location: loc!,
                          label: sos.residentName,
                        ),
                      ),
                    ),
          ),

          if (sos.note != null && sos.note!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(sos.note!,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
          ],

          if (tracked.responderCount > 0 && !tracked.status.isTerminal) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.infoSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Symbols.groups_rounded,
                      size: 18, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${tracked.responderCount} responder'
                      '${tracked.responderCount == 1 ? '' : 's'} responding'
                      '${tracked.anyOnScene ? ' • someone is on scene' : ''}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          // Response actions, gated by THIS user's own participation (not the
          // global status), so multiple responders can each accept independently.
          _ResponseActions(
            status: tracked.status,
            sosId: sos.sosId,
            ctrl: ctrl,
            myState: _myResponderState(ref, tracked),
          ),
        ],
      ),
    );
  }
}

class _ResidentInfo extends StatelessWidget {
  const _ResidentInfo({required this.sos});

  final SosPacket sos;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _InfoRow(
              icon: Symbols.person_rounded,
              label: 'Resident',
              value: sos.residentName),
          const SizedBox(height: 6),
          _InfoRow(
              icon: Symbols.badge_rounded,
              label: 'Resident ID',
              value: sos.residentId),
          const SizedBox(height: 6),
          _InfoRow(
            icon: Symbols.location_on_rounded,
            label: 'Location',
            value: sos.locationLabel?.isNotEmpty == true
                ? sos.locationLabel!
                : (sos.latitude != null && sos.longitude != null)
                    ? 'Near ${sos.latitude!.toStringAsFixed(4)}, ${sos.longitude!.toStringAsFixed(4)}'
                    : 'Not shared',
          ),
          const SizedBox(height: 6),
          _InfoRow(
            icon: Symbols.my_location_rounded,
            label: 'Coordinates',
            value: (sos.latitude != null && sos.longitude != null)
                ? '${sos.latitude!.toStringAsFixed(5)}, ${sos.longitude!.toStringAsFixed(5)}'
                : 'Not shared',
          ),
          const SizedBox(height: 6),
          _InfoRow(
            icon: Symbols.straighten_rounded,
            label: 'Distance',
            value: '—', // Placeholder until the map SDK provides geodistance.
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
    return Row(
      children: <Widget>[
        Icon(icon,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text('$label: ',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        Expanded(
          child: Text(value,
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _ResponseActions extends StatelessWidget {
  const _ResponseActions({
    required this.status,
    required this.sosId,
    required this.ctrl,
    required this.myState,
  });

  final SosStatus status;
  final String sosId;
  final SosMeshController ctrl;

  /// This user's own responder state for the SOS, or null if they have not
  /// accepted it yet. Gating on this (rather than the global status) lets
  /// multiple responders each accept the same SOS independently.
  final ResponderState? myState;

  @override
  Widget build(BuildContext context) {
    // Terminal incident (resolved / cancelled): no actions for anyone.
    if (status.isTerminal) {
      return Row(
        children: <Widget>[
          Icon(
            status == SosStatus.resolved
                ? Symbols.check_circle_rounded
                : Symbols.cancel_rounded,
            size: 18,
            color: status == SosStatus.resolved
                ? AppColors.success
                : AppColors.danger,
          ),
          const SizedBox(width: 8),
          Text(status == SosStatus.resolved
              ? 'Resolved'
              : status == SosStatus.cancelled
                  ? 'Cancelled by resident'
                  : 'Dismissed from your list'),
        ],
      );
    }

    // If THIS user has not accepted yet, show Accept / Dismiss — regardless of
    // whether other responders have already accepted.
    if (myState == null) {
      return Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => ctrl.responderReject(sosId),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Symbols.close_rounded, size: 18),
              label: const Text('Dismiss'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => ctrl.responderAccept(sosId),
              icon: const Icon(Symbols.handshake_rounded, size: 18),
              label: const Text('Accept'),
            ),
          ),
        ],
      );
    }

    // This user has accepted: show THEIR own progress (En route -> On scene),
    // based on their personal state, independent of other responders.
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: myState == ResponderState.enRoute ||
                        myState == ResponderState.onScene
                    ? null
                    : () => ctrl.responderEnRoute(sosId),
                icon: const Icon(Symbols.directions_run_rounded, size: 18),
                label: const Text('En route'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: myState == ResponderState.onScene
                    ? null
                    : () => ctrl.responderOnScene(sosId),
                icon: const Icon(Symbols.pin_drop_rounded, size: 18),
                label: const Text('On scene'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.infoSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Symbols.info_rounded, size: 18, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'The resident confirms when their emergency is fully '
                  'resolved.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.info),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
