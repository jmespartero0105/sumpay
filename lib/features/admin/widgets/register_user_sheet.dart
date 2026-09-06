import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_inputs.dart';
import '../../authentication/models/app_user.dart';

/// Result of the admin create-account sheet: the built user plus the initial
/// password the admin assigned, so the caller can persist credentials.
class NewStaffAccount {
  const NewStaffAccount({required this.user, required this.password});

  final AppUser user;
  final String password;
}

/// A compact registration form the administrator uses to create a new account.
///
/// Returns the built [AppUser] (with role) via `Navigator.pop`; the caller
/// persists it. Officials and volunteers will be stored as pending; residents
/// become active immediately (handled by the repository).
class RegisterUserSheet extends StatefulWidget {
  const RegisterUserSheet({super.key});

  @override
  State<RegisterUserSheet> createState() => _RegisterUserSheetState();
}

class _RegisterUserSheetState extends State<RegisterUserSheet> {
  final TextEditingController _surname = TextEditingController();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _middleName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _purok = TextEditingController();
  final TextEditingController _password = TextEditingController();

  UserRole _role = UserRole.user;
  String? _error;

  @override
  void dispose() {
    _surname.dispose();
    _firstName.dispose();
    _middleName.dispose();
    _phone.dispose();
    _email.dispose();
    _purok.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_surname.text.trim().isEmpty) {
      setState(() => _error = 'Surname is required.');
      return;
    }
    if (_firstName.text.trim().isEmpty) {
      setState(() => _error = 'First name is required.');
      return;
    }
    final String email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'A valid email is required.');
      return;
    }
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'Phone number is required.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    final String prefix = switch (_role) {
      UserRole.user => 'USR',
      UserRole.official => 'OFF',
      UserRole.admin => 'ADM',
    };
    final String id =
        '$prefix-${DateTime.now().millisecondsSinceEpoch % 100000}';

    final AppUser user = AppUser(
      id: id,
      surname: _surname.text.trim(),
      firstName: _firstName.text.trim(),
      middleName: _middleName.text.trim(),
      role: _role,
      phone: _phone.text.trim(),
      email: email,
      barangay: 'Talay',
      purok: _purok.text.trim().isEmpty ? 'Unassigned' : _purok.text.trim(),
      municipality: 'Dumaguete City, Negros Oriental',
      householdSize: 1,
      language: 'English',
      deviceId: 'SUMPAY-$id',
      emergencyContacts: const <EmergencyContact>[],
      medical: const MedicalProfile(
        bloodType: 'Unknown',
        allergies: <String>[],
        conditions: <String>[],
        medications: <String>[],
      ),
      // Repository sets the real status; default active here.
      status: AccountStatus.active,
    );

    Navigator.of(context)
        .pop(NewStaffAccount(user: user, password: _password.text));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool willBePending = _role.requiresApproval;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Register user', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Officials and volunteers require your approval before they can access the network.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              AppTextField(
                label: 'Surname',
                hint: 'e.g. Dela Cruz',
                controller: _surname,
                prefixIcon: Symbols.badge_rounded,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'First name',
                hint: 'e.g. Juan',
                controller: _firstName,
                prefixIcon: Symbols.person_rounded,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Middle name (optional)',
                hint: 'e.g. Santos',
                controller: _middleName,
                prefixIcon: Symbols.person_outline_rounded,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Phone',
                hint: '+63 9XX XXX XXXX',
                controller: _phone,
                prefixIcon: Symbols.call_rounded,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Email',
                hint: 'name@example.com',
                controller: _email,
                prefixIcon: Symbols.mail_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Purok (optional)',
                hint: 'e.g. Purok 3',
                controller: _purok,
                prefixIcon: Symbols.location_on_rounded,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Initial password',
                hint: 'At least 6 characters',
                controller: _password,
                obscureText: true,
                prefixIcon: Symbols.lock_rounded,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 18),
              Text('Role', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: UserRole.values.map((UserRole role) {
                  final bool selected = role == _role;
                  return ChoiceChip(
                    label: Text(role.label),
                    avatar: Icon(
                      role.icon,
                      size: 18,
                      color: selected ? Colors.white : null,
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _role = role),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: willBePending
                      ? AppColors.warningSoft
                      : AppColors.successSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      willBePending
                          ? Symbols.hourglass_top_rounded
                          : Symbols.check_circle_rounded,
                      size: 18,
                      color:
                          willBePending ? AppColors.warning : AppColors.success,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        willBePending
                            ? 'This account will be pending until you approve it.'
                            : 'This account will be active immediately.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      icon: const Icon(Symbols.person_add_rounded),
                      label: const Text('Register'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
