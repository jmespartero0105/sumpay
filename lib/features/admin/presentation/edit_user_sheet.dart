import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app_inputs.dart';
import '../../authentication/models/app_user.dart';

/// The edited profile fields returned from [EditUserSheet].
class EditUserResult {
  const EditUserResult({
    required this.surname,
    required this.firstName,
    required this.middleName,
    required this.phone,
    required this.email,
    required this.barangay,
    required this.purok,
    required this.municipality,
    required this.householdSize,
  });

  final String surname;
  final String firstName;
  final String middleName;
  final String phone;
  final String email;
  final String barangay;
  final String purok;
  final String municipality;
  final int householdSize;
}

/// Bottom sheet for an administrator to edit a user's editable profile details.
class EditUserSheet extends StatefulWidget {
  const EditUserSheet({super.key, required this.user});

  final AppUser user;

  @override
  State<EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<EditUserSheet> {
  late final TextEditingController _surname;
  late final TextEditingController _firstName;
  late final TextEditingController _middleName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _barangay;
  late final TextEditingController _purok;
  late final TextEditingController _municipality;
  late final TextEditingController _household;
  String? _error;

  @override
  void initState() {
    super.initState();
    final AppUser u = widget.user;
    _surname = TextEditingController(text: u.surname);
    _firstName = TextEditingController(text: u.firstName);
    _middleName = TextEditingController(text: u.middleName);
    _phone = TextEditingController(text: u.phone);
    _email = TextEditingController(text: u.email);
    _barangay = TextEditingController(text: u.barangay);
    _purok = TextEditingController(text: u.purok);
    _municipality = TextEditingController(text: u.municipality);
    _household = TextEditingController(text: u.householdSize.toString());
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _surname,
      _firstName,
      _middleName,
      _phone,
      _email,
      _barangay,
      _purok,
      _municipality,
      _household,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_surname.text.trim().isEmpty || _firstName.text.trim().isEmpty) {
      setState(() => _error = 'Surname and first name are required.');
      return;
    }
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'Phone number is required.');
      return;
    }
    final int household = int.tryParse(_household.text.trim()) ?? 1;
    Navigator.of(context).pop(EditUserResult(
      surname: _surname.text.trim(),
      firstName: _firstName.text.trim(),
      middleName: _middleName.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      barangay: _barangay.text.trim(),
      purok: _purok.text.trim(),
      municipality: _municipality.text.trim(),
      householdSize: household < 1 ? 1 : household,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
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
            Text('Edit account', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Update this user\'s details.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            AppTextField(
                controller: _surname,
                label: 'Surname',
                prefixIcon: Symbols.badge_rounded),
            const SizedBox(height: 10),
            AppTextField(
                controller: _firstName,
                label: 'First name',
                prefixIcon: Symbols.person_rounded),
            const SizedBox(height: 10),
            AppTextField(
                controller: _middleName,
                label: 'Middle name (optional)',
                prefixIcon: Symbols.person_outline_rounded),
            const SizedBox(height: 10),
            AppTextField(
                controller: _phone,
                label: 'Phone',
                prefixIcon: Symbols.call_rounded,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 10),
            AppTextField(
                controller: _email,
                label: 'Email',
                prefixIcon: Symbols.mail_rounded,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 10),
            AppTextField(
                controller: _purok,
                label: 'Purok',
                prefixIcon: Symbols.home_rounded),
            const SizedBox(height: 10),
            AppTextField(
                controller: _barangay,
                label: 'Barangay',
                prefixIcon: Symbols.location_city_rounded),
            const SizedBox(height: 10),
            AppTextField(
                controller: _municipality,
                label: 'Municipality',
                prefixIcon: Symbols.map_rounded),
            const SizedBox(height: 10),
            AppTextField(
                controller: _household,
                label: 'Household size',
                prefixIcon: Symbols.groups_rounded,
                keyboardType: TextInputType.number),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(_error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Symbols.save_rounded),
                label: const Text('Save changes'),
                style:
                    FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
