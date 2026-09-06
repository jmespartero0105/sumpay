import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/section_header.dart';
import '../../authentication/models/app_user.dart';
import '../../authentication/providers/auth_provider.dart';
import '../providers/user_management_provider.dart';
import '../widgets/register_user_sheet.dart';

/// Management-focused landing screen for the Administrator.
///
/// Surfaces the administrator's use-case functions in one place: an account
/// summary, a pending-approvals callout, and shortcuts to register a user,
/// approve or reject accounts, assign roles, and manage all accounts.
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser admin = ref.watch(currentUserProvider);
    final UserManagementState state = ref.watch(userManagementProvider);

    return Scaffold(
      appBar: SumpayAppBar(
        title: 'Admin dashboard',
        subtitle: '${admin.fullName} • Administrator',
        showBack: false,
      ),
      body: SafeArea(
        child: ContentContainer(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageInset,
              12,
              context.pageInset,
              24,
            ),
            children: <Widget>[
              _SummaryCard(state: state),
              if (state.pendingCount > 0) ...<Widget>[
                const SizedBox(height: 14),
                _PendingCallout(
                  count: state.pendingCount,
                  onReview: () => context.push(AppRoutes.userManagement),
                ),
              ],
              const SizedBox(height: 22),
              const SectionHeader(
                title: 'Management',
                subtitle: 'Administer users and accounts',
              ),
              const SizedBox(height: 4),
              _AdminAction(
                icon: Symbols.person_add_rounded,
                color: AppColors.primary,
                label: 'Register user',
                description:
                    'Create a new account; officials and volunteers need approval.',
                onTap: () => _openRegister(context, ref),
              ),
              _AdminAction(
                icon: Symbols.manage_accounts_rounded,
                color: const Color(0xFF0F8B8D),
                label: 'Manage accounts',
                description:
                    'Approve or reject registrations, edit roles, and deactivate or reactivate users.',
                badge: state.pendingCount,
                onTap: () => context.push(AppRoutes.userManagement),
              ),
              _AdminAction(
                icon: Symbols.lan_rounded,
                color: const Color(0xFF2563EB),
                label: 'Network monitoring',
                description: 'Live network diagnostics and status.',
                onTap: () => context.push(AppRoutes.networkMonitor),
              ),
            ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Symbols.admin_panel_settings_rounded,
                    color: Colors.white, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Account overview',
                    style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              _Stat(label: 'Total', value: state.users.length),
              _Stat(label: 'Active', value: state.active.length),
              _Stat(label: 'Pending', value: state.pendingCount),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: <Widget>[
          Text('$value',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _PendingCallout extends StatelessWidget {
  const _PendingCallout({required this.count, required this.onReview});

  final int count;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      color: AppColors.warningSoft,
      borderColor: AppColors.warning.withValues(alpha: 0.35),
      child: Row(
        children: <Widget>[
          const Icon(Symbols.hourglass_top_rounded,
              color: AppColors.warning, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$count account${count == 1 ? '' : 's'} awaiting approval',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Confirm officials and volunteers before they gain access.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onReview,
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }
}

class _AdminAction extends StatelessWidget {
  const _AdminAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.description,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String description;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(label, style: theme.textTheme.titleSmall),
                          if (badge > 0) ...<Widget>[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$badge',
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(description, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(Symbols.chevron_right_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
