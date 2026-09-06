import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/info_widgets.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../../authentication/models/app_user.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';

/// Resident profile with personal, medical and contact information.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppUser user = ref.watch(currentUserProvider);
    final AppSettings settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: SumpayAppBar(
        showBack: false,
        title: 'My profile',
        subtitle: 'Information shared with responders',
        actions: <Widget>[
          RoundIconButton(
            icon: Symbols.history_rounded,
            tooltip: 'My SOS history',
            onPressed: () => context.push(AppRoutes.history),
          ),
          RoundIconButton(
            icon: Symbols.settings_rounded,
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
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
              28,
            ),
            children: <Widget>[
              AppCard(
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          height: 72,
                          width: 72,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Center(
                            child: Text(
                              Formatters.initials(user.fullName),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                user.fullName,
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.id,
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              StatusChip(
                                label: user.role.label,
                                color: theme.colorScheme.primary,
                                icon: user.role.icon,
                                dense: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: theme.dividerColor, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: InfoTile(
                            icon: Symbols.smartphone_rounded,
                            label: 'Device',
                            value: user.deviceId,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              SectionHeader(
                title: 'Personal information',
                actionLabel: 'Edit',
                onAction: () => AppDialogs.info(
                  context,
                  title: 'Editing profile',
                  message:
                      'Profile edits will write to the barangay resident database once the backend is connected.',
                  icon: Symbols.edit_rounded,
                ),
              ),
              AppCard(
                child: Column(
                  children: <Widget>[
                    DetailRow(
                      label: 'Mobile number',
                      value: user.phone,
                      icon: Symbols.call_rounded,
                    ),
                    DetailRow(
                      label: 'Email',
                      value: user.email,
                      icon: Symbols.mail_rounded,
                    ),
                    DetailRow(
                      label: 'Household size',
                      value: '${user.householdSize} persons',
                      icon: Symbols.family_restroom_rounded,
                    ),
                    DetailRow(
                      label: 'Preferred language',
                      value: settings.language,
                      icon: Symbols.translate_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              const SectionHeader(title: 'Barangay and address'),
              AppCard(
                child: Column(
                  children: <Widget>[
                    DetailRow(
                      label: 'Barangay',
                      value: user.barangay,
                      icon: Symbols.location_city_rounded,
                    ),
                    DetailRow(
                      label: 'Purok / Sitio',
                      value: user.purok,
                      icon: Symbols.home_pin_rounded,
                    ),
                    DetailRow(
                      label: 'Municipality',
                      value: user.municipality,
                      icon: Symbols.map_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              SectionHeader(
                title: 'Medical information',
                subtitle: 'Transmitted with your SOS when sharing is enabled.',
                actionLabel: 'Edit',
                onAction: () => _editMedical(context, ref, user),
              ),
              AppCard(
                color: AppColors.dangerSoft,
                borderColor: AppColors.danger.withValues(alpha: 0.22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(
                          Symbols.bloodtype_rounded,
                          size: 26,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Blood type ${user.medical.bloodType}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ChipGroup(
                      label: 'Allergies',
                      values: user.medical.allergies,
                      emptyLabel: 'No known allergies',
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 12),
                    _ChipGroup(
                      label: 'Conditions',
                      values: user.medical.conditions,
                      emptyLabel: 'No recorded conditions',
                      color: AppColors.warning,
                    ),
                    const SizedBox(height: 12),
                    _ChipGroup(
                      label: 'Medications',
                      values: user.medical.medications,
                      emptyLabel: 'No maintenance medication',
                      color: AppColors.info,
                    ),
                    if (user.medical.notes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      Text('Responder notes', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 5),
                      Text(
                        user.medical.notes,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              SectionHeader(
                title: 'Emergency contacts',
                subtitle: '${user.emergencyContacts.length} contacts saved',
                actionLabel: 'Add',
                onAction: () => _addContact(context, ref, user),
              ),
              ...user.emergencyContacts.map(
                (EmergencyContact c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: <Widget>[
                        InitialsAvatar(
                          name: c.name,
                          size: 44,
                          radius: 13,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(c.name, style: theme.textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                '${c.relationship} • ${c.phone}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Symbols.more_vert_rounded),
                          tooltip: 'Contact actions',
                          onSelected: (String action) {
                            switch (action) {
                              case 'edit':
                                _editContact(context, ref, user, c);
                              case 'delete':
                                _deleteContact(context, ref, user, c);
                              case 'call':
                                AppDialogs.snack(
                                  context,
                                  'Calling ${c.name} requires cellular service.',
                                  icon: Symbols.call_rounded,
                                );
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                                value: 'edit', child: Text('Edit')),
                            const PopupMenuItem<String>(
                                value: 'delete', child: Text('Delete')),
                            const PopupMenuItem<String>(
                                value: 'call', child: Text('Call')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => AppDialogs.info(
                  context,
                  title: 'Add emergency contact',
                  message:
                      'Contact management writes to local storage once the persistence layer is connected.',
                  icon: Symbols.person_add_rounded,
                ),
                icon: const Icon(Symbols.person_add_rounded),
                label: const Text('Add emergency contact'),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              OutlinedButton.icon(
                onPressed: () async {
                  final bool ok = await AppDialogs.confirm(
                    context,
                    title: 'Sign out?',
                    message:
                        'You will need your credentials to sign back in. Queued messages remain stored on this device.',
                    confirmLabel: 'Sign out',
                    icon: Symbols.logout_rounded,
                    destructive: true,
                  );
                  if (!ok || !context.mounted) return;
                  await ref.read(authProvider.notifier).signOut();
                  if (!context.mounted) return;
                  context.go(AppRoutes.login);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 1.4),
                ),
                icon: const Icon(Symbols.logout_rounded),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Editing: medical info and emergency contacts -------------------------

  Future<void> _editMedical(
      BuildContext context, WidgetRef ref, AppUser user) async {
    final TextEditingController blood =
        TextEditingController(text: user.medical.bloodType);
    final TextEditingController allergies =
        TextEditingController(text: user.medical.allergies.join(', '));
    final TextEditingController conditions =
        TextEditingController(text: user.medical.conditions.join(', '));

    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) =>
          _EditSheet(title: 'Edit medical information', fields: <Widget>[
        _SheetField(label: 'Blood type', controller: blood),
        _SheetField(
            label: 'Allergies (comma separated)', controller: allergies),
        _SheetField(
            label: 'Conditions (comma separated)', controller: conditions),
      ]),
    );
    if (saved != true) return;

    List<String> split(String s) => s
        .split(',')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();

    final MedicalProfile updated = MedicalProfile(
      bloodType: blood.text.trim().isEmpty ? 'Unknown' : blood.text.trim(),
      allergies: split(allergies.text),
      conditions: split(conditions.text),
      medications: user.medical.medications,
      notes: user.medical.notes,
    );
    await ref
        .read(authProvider.notifier)
        .persistProfile(user.copyWith(medical: updated));
  }

  Future<void> _addContact(
      BuildContext context, WidgetRef ref, AppUser user) async {
    final EmergencyContact? result = await _contactSheet(context, null);
    if (result == null) return;
    final List<EmergencyContact> next = <EmergencyContact>[
      ...user.emergencyContacts,
      result,
    ];
    await ref
        .read(authProvider.notifier)
        .persistProfile(user.copyWith(emergencyContacts: next));
  }

  Future<void> _editContact(BuildContext context, WidgetRef ref, AppUser user,
      EmergencyContact contact) async {
    final EmergencyContact? result = await _contactSheet(context, contact);
    if (result == null) return;
    final List<EmergencyContact> next = user.emergencyContacts
        .map((EmergencyContact c) => c.id == contact.id ? result : c)
        .toList();
    await ref
        .read(authProvider.notifier)
        .persistProfile(user.copyWith(emergencyContacts: next));
  }

  Future<void> _deleteContact(BuildContext context, WidgetRef ref,
      AppUser user, EmergencyContact contact) async {
    final bool ok = await AppDialogs.confirm(
      context,
      title: 'Delete contact?',
      message: 'Remove ${contact.name} from your emergency contacts?',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
      icon: Symbols.delete_rounded,
      destructive: true,
    );
    if (!ok) return;
    final List<EmergencyContact> next = user.emergencyContacts
        .where((EmergencyContact c) => c.id != contact.id)
        .toList();
    await ref
        .read(authProvider.notifier)
        .persistProfile(user.copyWith(emergencyContacts: next));
  }

  Future<EmergencyContact?> _contactSheet(
      BuildContext context, EmergencyContact? existing) async {
    final TextEditingController name =
        TextEditingController(text: existing?.name ?? '');
    final TextEditingController relationship =
        TextEditingController(text: existing?.relationship ?? '');
    final TextEditingController phone =
        TextEditingController(text: existing?.phone ?? '');

    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _EditSheet(
        title: existing == null ? 'Add emergency contact' : 'Edit contact',
        fields: <Widget>[
          _SheetField(label: 'Name', controller: name),
          _SheetField(label: 'Relationship', controller: relationship),
          _SheetField(
              label: 'Contact number',
              controller: phone,
              keyboardType: TextInputType.phone),
        ],
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return null;

    return EmergencyContact(
      id: existing?.id ??
          'ec-${DateTime.now().millisecondsSinceEpoch}',
      name: name.text.trim(),
      relationship: relationship.text.trim().isEmpty
          ? 'Contact'
          : relationship.text.trim(),
      phone: phone.text.trim(),
    );
  }
}

/// A simple modal editor sheet with a title, fields, and Save/Cancel.
class _EditSheet extends StatelessWidget {
  const _EditSheet({required this.title, required this.fields});

  final String title;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          ...fields,
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.label,
    required this.values,
    required this.emptyLabel,
    required this.color,
  });

  final String label;
  final List<String> values;
  final String emptyLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 7),
        if (values.isEmpty)
          Text(emptyLabel, style: theme.textTheme.bodySmall)
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: values
                .map((String v) => StatusChip(label: v, color: color, dense: true))
                .toList(),
          ),
      ],
    );
  }
}
