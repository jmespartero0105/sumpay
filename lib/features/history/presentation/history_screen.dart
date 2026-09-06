import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_inputs.dart';
import '../../../core/widgets/info_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../sos/models/sos_request.dart';
import '../../sos/providers/sos_provider.dart';

/// Chronological record of every SOS raised from this device.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  int _filter = 0;
  bool _tableView = false;
  EmergencyType? _typeFilter;

  static const List<String> _filters = <String>[
    'All',
    'Active',
    'Resolved',
    'Cancelled',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SosRequest> _apply(List<SosRequest> source) {
    Iterable<SosRequest> result = source;

    result = switch (_filter) {
      1 => result.where((SosRequest r) =>
          r.status == IncidentStatus.active ||
          r.status == IncidentStatus.responding),
      2 => result.where((SosRequest r) => r.status == IncidentStatus.resolved),
      3 => result.where((SosRequest r) => r.status == IncidentStatus.cancelled),
      _ => result,
    };

    if (_typeFilter != null) {
      result = result.where((SosRequest r) =>
          r.type == _typeFilter || r.additionalTypes.contains(_typeFilter));
    }

    if (_query.trim().isNotEmpty) {
      final String q = _query.toLowerCase();
      result = result.where((SosRequest r) =>
          r.id.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.locationLabel.toLowerCase().contains(q));
    }

    return result.toList();
  }

  void _showDetail(SosRequest request) {
    AppDialogs.sheet<void>(
      context,
      title: '${request.typesSummary} emergency',
      subtitle: request.id,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            request.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
          ),
          const SizedBox(height: 14),
          DetailRow(
            label: 'Status',
            value: request.status.label,
            icon: Symbols.flag_rounded,
          ),
          DetailRow(
            label: 'Priority',
            value: request.priority.label,
            icon: Symbols.priority_high_rounded,
          ),
          DetailRow(
            label: 'Submitted',
            value: Formatters.dateTime(request.createdAt),
            icon: Symbols.schedule_rounded,
          ),
          DetailRow(
            label: 'Location',
            value: request.locationLabel,
            icon: Symbols.location_on_rounded,
          ),
          DetailRow(
            label: 'Coordinates',
            value: request.coordinates,
            icon: Symbols.my_location_rounded,
          ),
          DetailRow(
            label: 'People affected',
            value: '${request.peopleAffected}',
            icon: Symbols.groups_rounded,
          ),
          DetailRow(
            label: 'Delivery',
            value: '${request.delivery.label} • ${Formatters.hops(request.hopCount)}',
            icon: request.delivery.icon,
          ),
          DetailRow(
            label: 'Responding unit',
            value: request.respondingUnit ?? 'Not assigned',
            icon: Symbols.local_shipping_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context, List<SosRequest> rows) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(context.pageInset, 0, context.pageInset, 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 18,
          horizontalMargin: 10,
          showCheckboxColumn: false,
          headingRowColor: WidgetStateProperty.all(
              theme.colorScheme.surfaceContainerHighest),
          columns: const <DataColumn>[
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Responder')),
            DataColumn(label: Text('Priority')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Location')),
          ],
          rows: rows.map((SosRequest r) {
            return DataRow(
              onSelectChanged: (_) => _showDetail(r),
              cells: <DataCell>[
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(r.type.icon, size: 16, color: r.type.color),
                    const SizedBox(width: 6),
                    Text(r.typesSummary),
                  ],
                )),
                DataCell(StatusChip(
                    label: r.status.label, color: r.status.color, dense: true)),
                DataCell(Text(
                    r.respondingUnit != null && r.respondingUnit!.isNotEmpty
                        ? r.respondingUnit!
                        : '—')),
                DataCell(Text(r.priority.label)),
                DataCell(Text(Formatters.dateTime(r.createdAt))),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(r.locationLabel,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<SosRequest> all = ref.watch(sosLogProvider);
    final List<SosRequest> visible = _apply(all);

    final int resolved = all
        .where((SosRequest r) => r.status == IncidentStatus.resolved)
        .length;

    return Scaffold(
      appBar: SumpayAppBar(
        title: 'Emergency history',
        subtitle: '${all.length} records • $resolved resolved',
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
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.pageInset,
                  4,
                  context.pageInset,
                  12,
                ),
                child: Column(
                  children: <Widget>[
                    AppSearchBar(
                      hint: 'Search by reference, place or detail',
                      controller: _search,
                      onChanged: (String v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 12),
                    FilterChipRow(
                      labels: _filters,
                      selectedIndex: _filter,
                      onSelected: (int i) => setState(() => _filter = i),
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
                            (EmergencyType t) =>
                                DropdownMenuItem<EmergencyType?>(
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
                        onChanged: (EmergencyType? v) =>
                            setState(() => _typeFilter = v),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const EmptyState(
                        title: 'No records found',
                        message:
                            'Emergency requests you send will be archived here for reference.',
                        icon: Symbols.history_rounded,
                      )
                    : _tableView
                        ? _buildTable(context, visible)
                        : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          context.pageInset,
                          0,
                          context.pageInset,
                          24,
                        ),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          final SosRequest r = visible[index];
                          return AppCard(
                            onTap: () => _showDetail(r),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  height: 46,
                                  width: 46,
                                  decoration: BoxDecoration(
                                    color: r.type.color
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    r.type.icon,
                                    size: 23,
                                    color: r.type.color,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              '${r.typesSummary} • ${r.id}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  theme.textTheme.titleSmall,
                                            ),
                                          ),
                                          Text(
                                            Formatters.relative(r.createdAt),
                                            style: theme.textTheme.labelSmall,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        r.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(height: 1.45),
                                      ),
                                      const SizedBox(height: 9),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: <Widget>[
                                          StatusChip(
                                            label: r.status.label,
                                            color: r.status.color,
                                            dense: true,
                                          ),
                                          StatusChip(
                                            label: r.priority.label,
                                            color: r.priority.color,
                                            dense: true,
                                          ),
                                          StatusChip(
                                            label: r.delivery.label,
                                            color: r.delivery.color,
                                            icon: r.delivery.icon,
                                            dense: true,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
