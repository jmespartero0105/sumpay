import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_inputs.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../authentication/models/app_user.dart';
import '../providers/user_management_provider.dart';
import 'edit_user_sheet.dart';
import '../widgets/register_user_sheet.dart';

/// Administrator-only screen for managing user accounts: confirming pending
/// registrations (especially officials and volunteers), changing roles, and
/// deactivating accounts.
class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState
    extends ConsumerState<UserManagementScreen> {
  bool _tableView = false;
  int _roleFilter = 0;

  static const List<String> _roleFilters = <String>[
    'All',
    'Members',
    'Officials',
    'Admins',
  ];

  List<AppUser> _applyRoleFilter(List<AppUser> source) {
    return switch (_roleFilter) {
      1 => source
          .where((AppUser u) => u.role == UserRole.user)
          .toList(),
      2 => source
          .where((AppUser u) => u.role == UserRole.official)
          .toList(),
      3 => source.where((AppUser u) => u.role == UserRole.admin).toList(),
      _ => source,
    };
  }

  @override
  Widget build(BuildContext context) {
    final UserManagementState state = ref.watch(userManagementProvider);
    final UserManagementController controller =
        ref.read(userManagementProvider.notifier);

    return Scaffold(
      appBar: SumpayAppBar(
        title: 'User management',
        subtitle: 'Administrator',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRegister(context, ref),
        icon: const Icon(Symbols.person_add_rounded),
        label: const Text('Register user'),
      ),
      body: SafeArea(
        child: state.isLoading
            ? const LoadingState(message: 'Loading accounts…')
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(userManagementProvider.notifier).refresh(),
                child: ContentContainer(
                  child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    context.pageInset,
                    8,
                    context.pageInset,
                    96,
                  ),
                  children: <Widget>[
                    _SummaryCard(state: state),
                    const SizedBox(height: 20),
                    SectionHeader(
                      title: 'Pending approval',
                      subtitle:
                          '${state.pendingCount} account(s) awaiting confirmation',
                    ),
                    if (state.pending.isEmpty)
                      _InlineEmpty(
                        icon: Symbols.task_alt_rounded,
                        message: 'No accounts are waiting for approval.',
                      )
                    else
                      ...state.pending.map(
                        (AppUser u) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _UserTile(
                            user: u,
                            onApprove: () => controller.approve(u.id),
                            onReject: () => _confirmReject(context, controller, u),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    SectionHeader(
                      title: 'All accounts',
                      subtitle: '${_applyRoleFilter(state.users).length} shown',
                    ),
                    FilterChipRow(
                      labels: _roleFilters,
                      selectedIndex: _roleFilter,
                      onSelected: (int i) => setState(() => _roleFilter = i),
                    ),
                    const SizedBox(height: 10),
                    if (_tableView)
                      _AccountsTable(
                        users: _applyRoleFilter(state.users),
                        onEditRole: (AppUser u) =>
                            _editRole(context, controller, u),
                        onEditInfo: (AppUser u) =>
                            _editInfo(context, controller, u),
                      )
                    else
                      ..._applyRoleFilter(state.users).map(
                        (AppUser u) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _UserTile(
                            user: u,
                            onApprove: u.status.isPending
                                ? () => controller.approve(u.id)
                                : null,
                            onReject: u.status.isPending
                                ? () => _confirmReject(context, controller, u)
                                : null,
                            onDeactivate: u.status.isActive
                                ? () => _confirmDeactivate(context, controller, u)
                                : null,
                            onReactivate: (!u.status.isActive &&
                                    !u.status.isPending)
                                ? () => controller.reactivate(u.id)
                                : null,
                            onEditRole: () => _editRole(context, controller, u),
                            onEditInfo: () => _editInfo(context, controller, u),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Future<void> _openRegister(BuildContext context, WidgetRef ref) async {
    final NewStaffAccount? created = await showModalBottomSheet<NewStaffAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RegisterUserSheet(),
    );
    if (created == null) return;
    final bool pending = await ref
        .read(userManagementProvider.notifier)
        .register(created.user, password: created.password);
    if (!context.mounted) return;
    AppDialogs.snack(
      context,
      pending
          ? '${created.user.fullName} registered — pending your approval.'
          : '${created.user.fullName} registered and active.',
      icon: Symbols.person_add_rounded,
    );
  }

  /// Opens the edit-info sheet and applies profile changes (writes to Supabase).
  Future<void> _editInfo(
    BuildContext context,
    UserManagementController controller,
    AppUser user,
  ) async {
    final EditUserResult? result = await showModalBottomSheet<EditUserResult>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => EditUserSheet(user: user),
    );
    if (result == null || !context.mounted) return;
    await controller.updateProfile(
      user.id,
      surname: result.surname,
      firstName: result.firstName,
      middleName: result.middleName,
      phone: result.phone,
      email: result.email,
      barangay: result.barangay,
      purok: result.purok,
      municipality: result.municipality,
      householdSize: result.householdSize,
    );
    if (context.mounted) {
      AppDialogs.snack(context, 'Account details updated.',
          icon: Symbols.check_circle_rounded);
    }
  }

  /// Opens a role picker and applies the change (writes to Supabase).
  Future<void> _editRole(
    BuildContext context,
    UserManagementController controller,
    AppUser user,
  ) async {
    final UserRole? picked = await showModalBottomSheet<UserRole>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text('Change role for ${user.fullName}',
                    style: Theme.of(sheetContext).textTheme.titleMedium),
              ),
              ...UserRole.values.map(
                (UserRole r) => RadioListTile<UserRole>(
                  value: r,
                  groupValue: user.role,
                  onChanged: (UserRole? v) =>
                      Navigator.of(sheetContext).pop(v),
                  secondary: Icon(r.icon),
                  title: Text(r.label),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null || picked == user.role) return;
    if (!context.mounted) return;

    final bool ok = await AppDialogs.confirm(
      context,
      title: 'Change role?',
      message:
          'Set ${user.fullName}\'s role to ${picked.label}. They will have the '
          'permissions of that role the next time they sign in.',
      confirmLabel: 'Change role',
      icon: Symbols.badge_rounded,
    );
    if (!ok) return;
    await controller.changeRole(user.id, picked);
    if (context.mounted) {
      AppDialogs.snack(context, 'Role updated to ${picked.label}.',
          icon: Symbols.check_circle_rounded);
    }
  }

  Future<void> _confirmReject(
    BuildContext context,
    UserManagementController controller,
    AppUser user,
  ) async {
    final bool ok = await AppDialogs.confirm(
      context,
      title: 'Reject ${user.fullName}?',
      message:
          'Their account will be marked rejected and they will not gain access.',
      confirmLabel: 'Reject',
      icon: Symbols.cancel_rounded,
      destructive: true,
    );
    if (ok) await controller.reject(user.id);
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    UserManagementController controller,
    AppUser user,
  ) async {
    final bool ok = await AppDialogs.confirm(
      context,
      title: 'Deactivate ${user.fullName}?',
      message: 'They will lose access until reactivated.',
      confirmLabel: 'Deactivate',
      icon: Symbols.block_rounded,
      destructive: true,
    );
    if (ok) await controller.deactivate(user.id);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});

  final UserManagementState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      color: AppColors.primary.withValues(alpha: 0.06),
      borderColor: AppColors.primary.withValues(alpha: 0.20),
      child: Row(
        children: <Widget>[
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Symbols.admin_panel_settings_rounded,
                color: Colors.white, size: 27),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Account overview', style: theme.textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  '${state.active.length} active · ${state.pendingCount} pending',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (state.pendingCount > 0)
            StatusChip(
              label: '${state.pendingCount} to review',
              color: AppColors.warning,
              icon: Symbols.hourglass_top_rounded,
              dense: true,
            ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    this.onApprove,
    this.onReject,
    this.onDeactivate,
    this.onReactivate,
    this.onEditRole,
    this.onEditInfo,
  });

  final AppUser user;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onDeactivate;
  final VoidCallback? onReactivate;
  final VoidCallback? onEditRole;
  final VoidCallback? onEditInfo;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool needsOfficialNote =
        user.status.isPending && user.role == UserRole.official;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              InitialsAvatar(name: user.fullName, size: 46, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Icon(user.role.icon,
                            size: 14,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text(user.role.label, style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: user.status.label,
                color: user.status.color,
                icon: user.status.icon,
                dense: true,
              ),
            ],
          ),
          if (needsOfficialNote) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Symbols.shield_person_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Official account — requires administrator confirmation.',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _DetailLine(
              icon: Symbols.call_rounded,
              label: 'Phone',
              value: user.phone.isNotEmpty ? user.phone : '—'),
          _DetailLine(
              icon: Symbols.mail_rounded,
              label: 'Email',
              value: user.email.isNotEmpty ? user.email : '—'),
          _DetailLine(
              icon: Symbols.location_on_rounded,
              label: 'Location',
              value: <String>[
                if (user.purok.isNotEmpty) 'Purok ${user.purok}',
                if (user.barangay.isNotEmpty) user.barangay,
                if (user.municipality.isNotEmpty) user.municipality,
              ].isEmpty
                  ? '—'
                  : <String>[
                      if (user.purok.isNotEmpty) 'Purok ${user.purok}',
                      if (user.barangay.isNotEmpty) user.barangay,
                      if (user.municipality.isNotEmpty) user.municipality,
                    ].join(', ')),
          _DetailLine(
              icon: Symbols.groups_rounded,
              label: 'Household',
              value: '${user.householdSize} member'
                  '${user.householdSize == 1 ? '' : 's'}'),
          ..._actions(),
        ],
      ),
    );
  }

  List<Widget> _actions() {
    final List<Widget> statusButtons = <Widget>[];

    if (onApprove != null) {
      statusButtons.add(Expanded(
        child: FilledButton.icon(
          onPressed: onApprove,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            backgroundColor: AppColors.success,
          ),
          icon: const Icon(Symbols.check_rounded, size: 20),
          label: const Text('Approve'),
        ),
      ));
    }
    if (onReject != null) {
      if (statusButtons.isNotEmpty) statusButtons.add(const SizedBox(width: 10));
      statusButtons.add(Expanded(
        child: OutlinedButton.icon(
          onPressed: onReject,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
          ),
          icon: const Icon(Symbols.close_rounded, size: 20),
          label: const Text('Reject'),
        ),
      ));
    }
    if (onDeactivate != null) {
      statusButtons.add(Expanded(
        child: OutlinedButton.icon(
          onPressed: onDeactivate,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
          icon: const Icon(Symbols.block_rounded, size: 20),
          label: const Text('Deactivate'),
        ),
      ));
    }
    if (onReactivate != null) {
      statusButtons.add(Expanded(
        child: FilledButton.icon(
          onPressed: onReactivate,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
          icon: const Icon(Symbols.restart_alt_rounded, size: 20),
          label: const Text('Reactivate'),
        ),
      ));
    }

    final List<Widget> result = <Widget>[];
    if (statusButtons.isNotEmpty) {
      result.add(const SizedBox(height: 12));
      result.add(Row(children: <Widget>[
        for (int i = 0; i < statusButtons.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 10),
          statusButtons[i],
        ],
      ]));
    }
    if (onEditRole != null || onEditInfo != null) {
      result.add(const SizedBox(height: 10));
      result.add(Row(
        children: <Widget>[
          if (onEditInfo != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEditInfo,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                icon: const Icon(Symbols.edit_rounded, size: 20),
                label: const Text('Edit info'),
              ),
            ),
          if (onEditInfo != null && onEditRole != null)
            const SizedBox(width: 10),
          if (onEditRole != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEditRole,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: AppColors.info,
                  side: const BorderSide(color: AppColors.info),
                ),
                icon: const Icon(Symbols.badge_rounded, size: 20),
                label: const Text('Edit role'),
              ),
            ),
        ],
      ));
    }
    return result;
  }
}

/// A small labelled detail line (icon • label • value) for the account tile.
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon,
              size: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          SizedBox(
            width: 66,
            child: Text(label,
                style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.55))),
          ),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: <Widget>[
            Icon(icon,
                size: 30,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Compact table view of all accounts for the administrator, with an inline
/// edit-role action per row.
class _AccountsTable extends StatelessWidget {
  const _AccountsTable(
      {required this.users,
      required this.onEditRole,
      required this.onEditInfo});

  final List<AppUser> users;
  final void Function(AppUser) onEditRole;
  final void Function(AppUser) onEditInfo;

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
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Phone')),
          DataColumn(label: Text('Purok')),
          DataColumn(label: Text('Actions')),
        ],
        rows: users.map((AppUser u) {
          return DataRow(
            cells: <DataCell>[
              DataCell(ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(u.fullName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              )),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(u.role.icon, size: 15),
                  const SizedBox(width: 5),
                  Text(u.role.label),
                ],
              )),
              DataCell(StatusChip(
                  label: u.status.label,
                  color: u.status.color,
                  dense: true)),
              DataCell(Text(u.phone.isNotEmpty ? u.phone : '—')),
              DataCell(Text(u.purok.isNotEmpty ? u.purok : '—')),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Edit info',
                    icon: const Icon(Symbols.edit_rounded, size: 20),
                    onPressed: () => onEditInfo(u),
                  ),
                  IconButton(
                    tooltip: 'Edit role',
                    icon: const Icon(Symbols.badge_rounded, size: 20),
                    color: AppColors.info,
                    onPressed: () => onEditRole(u),
                  ),
                ],
              )),
            ],
          );
        }).toList(),
      ),
    );
  }
}
