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
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_inputs.dart';
import '../../../core/widgets/info_widgets.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../authentication/models/app_user.dart';
import '../../authentication/providers/auth_provider.dart';
import '../data/dummy_assignments.dart';
import '../models/assignment.dart';
import '../providers/volunteer_provider.dart';
import '../../sos/models/sos_location_model.dart';
import '../../sos/models/sos_packet.dart';
import '../../sos/models/sos_request.dart';
import '../../sos/providers/sos_provider.dart';
import '../../sos/providers/sos_mesh_provider.dart';
import '../../sos/widgets/map_preview_placeholder.dart';

/// Operational dashboard for deployed volunteers.
class VolunteerScreen extends ConsumerStatefulWidget {
  const VolunteerScreen({super.key});

  @override
  ConsumerState<VolunteerScreen> createState() => _VolunteerScreenState();
}

class _VolunteerScreenState extends ConsumerState<VolunteerScreen> {
  int _filter = 0;

  static const List<String> _filters = <String>[
    'All',
    'Pending',
    'Active',
    'Completed',
  ];

  List<Assignment> _apply(List<Assignment> source) {
    return switch (_filter) {
      1 => source
          .where((Assignment a) => a.status == TaskStatus.pending)
          .toList(),
      2 => source
          .where((Assignment a) =>
              a.status == TaskStatus.accepted ||
              a.status == TaskStatus.inProgress)
          .toList(),
      3 => source
          .where((Assignment a) => a.status == TaskStatus.completed)
          .toList(),
      _ => source,
    };
  }

  Future<void> _quickReport() async {
    await AppDialogs.sheet<void>(
      context,
      title: 'Quick report',
      subtitle: 'Sent to the barangay over the SUMPAY Network.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ...DummyAssignments.quickReports.map(
            (String report) => ListTile(
              onTap: () {
                Navigator.of(context).pop();
                AppDialogs.snack(
                  context,
                  'Report sent: $report',
                  icon: Symbols.check_circle_rounded,
                );
              },
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Symbols.bolt_rounded, size: 22),
              title: Text(report, style: Theme.of(context).textTheme.bodyLarge),
              trailing: const Icon(Symbols.chevron_right_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          const AppTextField(
            label: 'Custom report',
            hint: 'Describe the situation on the ground…',
            maxLines: 3,
            minLines: 2,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              AppDialogs.snack(
                context,
                'Custom report transmitted.',
                icon: Symbols.check_circle_rounded,
              );
            },
            icon: const Icon(Symbols.send_rounded),
            label: const Text('Send report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppUser user = ref.watch(currentUserProvider);
    final List<Assignment> all = ref.watch(assignmentsProvider);
    final List<Assignment> open = ref.watch(openAssignmentsProvider);
    final Assignment? focus = ref.watch(focusAssignmentProvider);
    final int waiting = ref.watch(peopleWaitingProvider);
    final int completed = ref.watch(completedTaskCountProvider);
    final List<Assignment> visible = _apply(all);

    return Scaffold(
      appBar: SumpayAppBar(
        title: 'Volunteer dashboard',
        subtitle: '${user.fullName} • Volunteer Team Alpha',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _quickReport,
        icon: const Icon(Symbols.bolt_rounded),
        label: const Text('Quick report'),
      ),
      body: SafeArea(
        child: ContentContainer(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageInset,
              6,
              context.pageInset,
              96,
            ),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: MetricTile(
                      value: '${open.length}',
                      label: 'Open assignments',
                      icon: Symbols.assignment_rounded,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricTile(
                      value: '$waiting',
                      label: 'People waiting',
                      icon: Symbols.groups_rounded,
                      color: AppColors.emergency,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricTile(
                      value: '$completed',
                      label: 'Completed today',
                      icon: Symbols.task_alt_rounded,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.sectionGap),
              const _ResponderMeshSosSection(),
              const SectionHeader(
                title: 'Incoming SOS',
                subtitle: 'Emergencies with the resident\'s shared location.',
              ),
              Consumer(
                builder: (BuildContext context, WidgetRef ref, _) {
                  final List<SosRequest> incidents =
                      ref.watch(activeIncidentsProvider);
                  if (incidents.isEmpty) {
                    return const EmptyState(
                      title: 'No active SOS',
                      message: 'Incoming emergencies will appear here.',
                      icon: Symbols.sos_rounded,
                    );
                  }
                  return Column(
                    children: <Widget>[
                      for (final SosRequest sos in incidents)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ResponderSosCard(sos: sos),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppConstants.sectionGap),
              if (focus != null) ...<Widget>[
                const SectionHeader(
                  title: 'Next priority',
                  subtitle: 'Highest urgency task nearest to you.',
                ),
                _NavigationCard(assignment: focus),
                const SizedBox(height: AppConstants.sectionGap),
              ],
              SectionHeader(
                title: 'Assignments',
                subtitle: '${all.length} total tasks dispatched to your team',
              ),
              FilterChipRow(
                labels: _filters,
                selectedIndex: _filter,
                onSelected: (int i) => setState(() => _filter = i),
              ),
              const SizedBox(height: 14),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: EmptyState(
                    title: 'Nothing here',
                    message: 'No assignments match this filter right now.',
                    icon: Symbols.assignment_turned_in_rounded,
                  ),
                )
              else
                ...visible.map(
                  (Assignment a) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AssignmentCard(
                      assignment: a,
                      onAccept: () =>
                          ref.read(assignmentsProvider.notifier).accept(a.id),
                      onStart: () =>
                          ref.read(assignmentsProvider.notifier).start(a.id),
                      onComplete: () async {
                        final bool ok = await AppDialogs.confirm(
                          context,
                          title: 'Mark as completed?',
                          message:
                              'Confirm that ${a.title.toLowerCase()} has been fully resolved.',
                          confirmLabel: 'Mark completed',
                          icon: Symbols.task_alt_rounded,
                        );
                        if (!ok) return;
                        ref.read(assignmentsProvider.notifier).complete(a.id);
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                'Assignments are coordinated by the barangay over the SUMPAY Network.',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      color: assignment.priority.softColor,
      borderColor: assignment.priority.color.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: assignment.type.color,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(assignment.type.icon, size: 26, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(assignment.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      assignment.locationLabel,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: InfoTile(
                  icon: Symbols.near_me_rounded,
                  label: 'Distance',
                  value: Formatters.distance(assignment.distanceMetres),
                  color: assignment.priority.color,
                ),
              ),
              Expanded(
                child: InfoTile(
                  icon: Symbols.groups_rounded,
                  label: 'Waiting',
                  value: '${assignment.peopleWaiting} person(s)',
                  color: assignment.priority.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go(AppRoutes.messages),
                  icon: const Icon(Symbols.forum_rounded),
                  label: const Text('Team chat'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.onAccept,
    required this.onStart,
    required this.onComplete,
  });

  final Assignment assignment;
  final VoidCallback onAccept;
  final VoidCallback onStart;
  final VoidCallback onComplete;

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
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: assignment.type.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  assignment.type.icon,
                  size: 21,
                  color: assignment.type.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      assignment.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${assignment.id} • ${Formatters.relative(assignment.assignedAt)}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: assignment.status.label,
                color: assignment.status.color,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            assignment.description,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              StatusChip(
                label: assignment.priority.label,
                color: assignment.priority.color,
                dense: true,
              ),
              StatusChip(
                label: Formatters.distance(assignment.distanceMetres),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                icon: Symbols.near_me_rounded,
                dense: true,
              ),
              StatusChip(
                label: assignment.locationLabel,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                icon: Symbols.location_on_rounded,
                dense: true,
              ),
              if (assignment.linkedSosId != null)
                StatusChip(
                  label: assignment.linkedSosId!,
                  color: AppColors.emergency,
                  icon: Symbols.sos_rounded,
                  dense: true,
                ),
            ],
          ),
          if (assignment.status != TaskStatus.completed) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                if (assignment.status == TaskStatus.pending)
                  Expanded(
                    child: FilledButton(
                      onPressed: onAccept,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                if (assignment.status == TaskStatus.accepted)
                  Expanded(
                    child: FilledButton(
                      onPressed: onStart,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: const Text('Start task'),
                    ),
                  ),
                if (assignment.status == TaskStatus.inProgress)
                  Expanded(
                    child: FilledButton(
                      onPressed: onComplete,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        backgroundColor: AppColors.success,
                      ),
                      child: const Text('Mark completed'),
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

/// Responder view of an incoming SOS: resident name, emergency type,
/// coordinates, a distance placeholder, a map preview, and open-map /
/// navigation placeholders. Map actions are inert until a mapping SDK is added.
class _ResponderSosCard extends StatelessWidget {
  const _ResponderSosCard({required this.sos});

  final SosRequest sos;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SosLocationModel? loc = sos.capturedLocation;

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
                  color: sos.type.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(sos.type.icon, color: sos.type.color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(sos.requesterName, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${sos.type.label} • ${Formatters.relative(sos.createdAt)}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: sos.priority.label,
                color: sos.priority.color,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          MapPreviewPlaceholder(location: loc, label: sos.requesterName),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Icon(Symbols.my_location_rounded,
                  size: 15, color: AppColors.info),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  loc != null ? loc.coordinateLabel : 'No coordinates attached',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
              // Distance placeholder — computed once a map SDK / geodistance
              // utility is integrated.
              Text(
                'Distance: —',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MapActionButtons(location: loc),
        ],
      ),
    );
  }
}

/// SOS received over the mesh, with responder acknowledgement actions
/// (Accept, En Route). Renders nothing when there are no mesh SOS.
class _ResponderMeshSosSection extends ConsumerWidget {
  const _ResponderMeshSosSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TrackedSos> tracked = ref.watch(sosMeshProvider);
    if (tracked.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Incoming SOS',
          subtitle: 'Emergencies received over the SUMPAY Network.',
        ),
        ...tracked.map((TrackedSos t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ResponderMeshSosCard(tracked: t),
            )),
        const SizedBox(height: AppConstants.sectionGap),
      ],
    );
  }
}

class _ResponderMeshSosCard extends ConsumerWidget {
  const _ResponderMeshSosCard({required this.tracked});

  final TrackedSos tracked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final SosPacket sos = tracked.packet;

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
                      '${sos.emergencyType.label} • ${Formatters.relative(sos.createdAt)}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: tracked.status.label,
                color: sos.priority.color,
                dense: true,
              ),
            ],
          ),
          if (sos.latitude != null && sos.longitude != null) ...<Widget>[
            const SizedBox(height: 10),
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
          const SizedBox(height: 12),
          if (tracked.status != SosStatus.resolved)
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: tracked.status == SosStatus.responderAccepted ||
                            tracked.status == SosStatus.responderEnRoute
                        ? null
                        : () => ref
                            .read(sosMeshProvider.notifier)
                            .responderAccept(sos.sosId),
                    icon: const Icon(Symbols.handshake_rounded, size: 16),
                    label: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: tracked.status == SosStatus.responderEnRoute
                        ? null
                        : () => ref
                            .read(sosMeshProvider.notifier)
                            .responderEnRoute(sos.sosId),
                    icon: const Icon(Symbols.directions_run_rounded, size: 16),
                    label: const Text('En route'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
