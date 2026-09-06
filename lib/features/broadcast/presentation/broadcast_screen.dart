import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_inputs.dart';
import '../../../core/widgets/info_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../authentication/models/app_user.dart';
import '../../authentication/providers/auth_provider.dart';
import '../data/dummy_broadcasts.dart';
import '../models/broadcast_models.dart';
import '../providers/broadcast_provider.dart';

/// Feed of barangay announcements, with a composer for officials.
class BroadcastScreen extends ConsumerStatefulWidget {
  const BroadcastScreen({super.key});

  @override
  ConsumerState<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends ConsumerState<BroadcastScreen> {
  int _filter = 0;

  static const List<String> _filters = <String>[
    'All',
    'Alerts',
    'Warnings',
    'Advisories',
  ];

  List<BroadcastMessage> _apply(List<BroadcastMessage> source) {
    return switch (_filter) {
      1 => source
          .where((BroadcastMessage b) => b.severity == BroadcastSeverity.alert)
          .toList(),
      2 => source
          .where((BroadcastMessage b) => b.severity == BroadcastSeverity.warning)
          .toList(),
      3 => source
          .where(
              (BroadcastMessage b) => b.severity == BroadcastSeverity.advisory)
          .toList(),
      _ => source,
    };
  }

  Future<void> _openComposer() async {
    await AppDialogs.sheet<void>(
      context,
      title: 'New broadcast',
      subtitle: 'Sent to every registered device over the SUMPAY Network.',
      child: const _BroadcastComposer(),
    );
  }

  Future<void> _confirmDeactivate(BroadcastMessage broadcast) async {
    final bool ok = await AppDialogs.confirm(
      context,
      title: 'Make this broadcast inactive?',
      message:
          'It will no longer be pinned or shown as an active alert. This does '
          'not remove it from residents who already received it.',
      confirmLabel: 'Make inactive',
      icon: Symbols.notifications_off_rounded,
      destructive: true,
    );
    if (!ok || !mounted) return;
    ref.read(broadcastsProvider.notifier).deactivate(broadcast.id);
    if (mounted) {
      AppDialogs.snack(context, 'Broadcast set to inactive.',
          icon: Symbols.check_circle_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppUser user = ref.watch(currentUserProvider);
    final List<BroadcastMessage> all = ref.watch(broadcastsProvider);
    final List<BroadcastMessage> visible = _apply(all);

    return Scaffold(
      appBar: SumpayAppBar(
        showBack: false,
        title: 'Barangay broadcast',
        subtitle: 'Official announcements for Barangay ${user.barangay}',
      ),
      floatingActionButton: user.role.canBroadcast
          ? FloatingActionButton.extended(
              onPressed: _openComposer,
              icon: const Icon(Symbols.campaign_rounded),
              label: const Text('New broadcast'),
            )
          : null,
      body: SafeArea(
        top: false,
        child: ContentContainer(
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.pageInset,
                  4,
                  context.pageInset,
                  12,
                ),
                child: FilterChipRow(
                  labels: _filters,
                  selectedIndex: _filter,
                  onSelected: (int i) => setState(() => _filter = i),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const EmptyState(
                        title: 'No announcements',
                        message:
                            'Barangay advisories and alerts will appear here as they are issued.',
                        icon: Symbols.campaign_rounded,
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          context.pageInset,
                          0,
                          context.pageInset,
                          96,
                        ),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (BuildContext context, int index) {
                          return _BroadcastCard(
                            broadcast: visible[index],
                            showMetrics: user.role.canBroadcast,
                            onDeactivate: user.role.canBroadcast
                                ? () => _confirmDeactivate(visible[index])
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BroadcastCard extends StatelessWidget {
  const _BroadcastCard(
      {required this.broadcast,
      required this.showMetrics,
      this.onDeactivate});

  final BroadcastMessage broadcast;
  final bool showMetrics;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      borderColor: broadcast.isPinned
          ? broadcast.severity.color.withValues(alpha: 0.4)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              StatusChip(
                label: broadcast.severity.label.toUpperCase(),
                color: broadcast.severity.color,
                icon: broadcast.severity == BroadcastSeverity.alert
                    ? Symbols.emergency_rounded
                    : Symbols.campaign_rounded,
                filled: true,
                dense: true,
              ),
              if (broadcast.isPinned) ...<Widget>[
                const SizedBox(width: 7),
                Icon(
                  Symbols.push_pin_rounded,
                  size: 17,
                  color: broadcast.severity.color,
                  fill: 1,
                ),
              ],
              const Spacer(),
              Text(
                Formatters.relative(broadcast.issuedAt),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(broadcast.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            broadcast.body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: broadcast.areas
                .map((String a) => StatusChip(
                      label: a,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      icon: Symbols.location_on_rounded,
                      dense: true,
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          Divider(color: theme.dividerColor, height: 1),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Icon(
                Symbols.account_balance_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  broadcast.issuedBy,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
              StatusChip(
                label: broadcast.transport.label,
                color: broadcast.transport.color,
                icon: broadcast.transport.icon,
                dense: true,
              ),
            ],
          ),
          if (showMetrics) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: InfoTile(
                    icon: Symbols.groups_rounded,
                    label: 'Reach',
                    value: '${Formatters.count(broadcast.reach)} device'
                        '${broadcast.reach == 1 ? '' : 's'} received',
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (showMetrics && onDeactivate != null && broadcast.isActive) ...<Widget>[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onDeactivate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  icon: const Icon(Symbols.notifications_off_rounded, size: 18),
                  label: const Text('Make inactive'),
                ),
              ),
            ],
            if (!broadcast.isActive) ...<Widget>[
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Icon(Symbols.do_not_disturb_on_rounded,
                      size: 16, color: theme.disabledColor),
                  const SizedBox(width: 6),
                  Text('Inactive — no longer shown as an active alert',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.disabledColor)),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _BroadcastComposer extends ConsumerWidget {
  const _BroadcastComposer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final BroadcastDraft draft = ref.watch(broadcastDraftProvider);
    final BroadcastDraftController controller =
        ref.read(broadcastDraftProvider.notifier);
    final AppUser user = ref.watch(currentUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Severity', style: theme.textTheme.labelLarge),
        const SizedBox(height: 10),
        Row(
          children: BroadcastSeverity.values.map((BroadcastSeverity s) {
            final bool selected = s == draft.severity;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: s == BroadcastSeverity.values.last ? 0 : 8,
                ),
                child: GestureDetector(
                  onTap: () => controller.setSeverity(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? s.softColor : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? s.color : theme.dividerColor,
                        width: selected ? 1.8 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        s.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: selected
                              ? s.color
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        AppTextField(
          label: 'Title',
          hint: 'Short, clear headline',
          onChanged: controller.setTitle,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Message',
          hint: 'What should residents do right now?',
          maxLines: 5,
          minLines: 4,
          onChanged: controller.setBody,
          helperText: 'Keep under 200 characters for fastest LoRa delivery.',
        ),
        const SizedBox(height: 18),
        Text('Target areas', style: theme.textTheme.labelLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DummyBroadcasts.areaOptions.map((String area) {
            final bool selected = draft.areas.contains(area);
            return FilterChip(
              label: Text(area),
              selected: selected,
              onSelected: (_) => controller.toggleArea(area),
              showCheckmark: false,
              backgroundColor: theme.colorScheme.surface,
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.13),
              side: BorderSide(
                color: selected ? theme.colorScheme.primary : theme.dividerColor,
              ),
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: draft.isValid
              ? () {
                  ref
                      .read(broadcastsProvider.notifier)
                      .publish(draft, issuedBy: user.fullName);
                  controller.reset();
                  Navigator.of(context).pop();
                  AppDialogs.snack(
                    context,
                    'Broadcast dispatched to all connected nodes.',
                    icon: Symbols.check_circle_rounded,
                  );
                }
              : null,
          icon: const Icon(Symbols.send_rounded),
          label: const Text('Dispatch broadcast'),
        ),
      ],
    );
  }
}
