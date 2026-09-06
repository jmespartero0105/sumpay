import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_inputs.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/registration_provider.dart';

/// Three-step household registration flow.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _surname = TextEditingController();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _middleName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _purok = TextEditingController();
  final TextEditingController _household = TextEditingController(text: '1');
  final TextEditingController _contactName = TextEditingController();
  final TextEditingController _contactPhone = TextEditingController();
  final TextEditingController _password = TextEditingController();

  String _barangay = 'Talay';
  String _bloodType = 'O+';
  int _step = 0;
  String? _stepError;
  bool _consent = false;

  static const List<String> _barangays = <String>[
    'Talay',
    'Bagacay',
    'Banilad',
    'Batinguel',
    'Cadawinonan',
    'Camanjac',
    'Junob',
    'Looc',
    'Motong',
    'Piapi',
  ];

  static const List<String> _bloodTypes = <String>[
    'O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'Unknown',
  ];

  @override
  void dispose() {
    _surname.dispose();
    _firstName.dispose();
    _middleName.dispose();
    _phone.dispose();
    _email.dispose();
    _purok.dispose();
    _household.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Persist the resident locally with a unique resident id (Phase 2.1 user
    // identity management). No authentication is involved.
    final EmergencyContact? contact = _contactName.text.trim().isEmpty
        ? null
        : EmergencyContact(
            id: 'EC-${DateTime.now().millisecondsSinceEpoch % 100000}',
            name: _contactName.text.trim(),
            relationship: 'Contact',
            phone: _contactPhone.text.trim(),
          );

    final AppUser? resident =
        await ref.read(registrationProvider.notifier).registerResident(
              surname: _surname.text,
              firstName: _firstName.text,
              middleName: _middleName.text,
              email: _email.text,
              barangay: _barangay,
              password: _password.text,
              phone: _phone.text,
              purok: _purok.text,
              householdSize: int.tryParse(_household.text.trim()) ?? 1,
              bloodType: _bloodType,
              emergencyContacts:
                  contact == null ? const <EmergencyContact>[] : <EmergencyContact>[contact],
            );

    if (resident == null) {
      if (!mounted) return;
      final String? error = ref.read(registrationProvider).errorMessage;
      await AppDialogs.info(
        context,
        title: 'Registration incomplete',
        message: error ?? 'Please complete the required fields and try again.',
        icon: Symbols.error_rounded,
        closeLabel: 'Back',
      );
      return;
    }

    if (!mounted) return;
    await AppDialogs.info(
      context,
      title: 'Registration submitted',
      message:
          'Your account has been submitted for barangay admin approval. '
          'You can sign in once an administrator approves it. '
          'Your resident ID is ${resident.id}.',
      icon: Symbols.hourglass_top_rounded,
      closeLabel: 'Back to sign in',
    );

    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  /// Validates the required fields on the current step. Returns an error
  /// message to show, or null if the step is complete.
  String? _validateStep(int step) {
    switch (step) {
      case 0:
        if (_surname.text.trim().isEmpty) return 'Surname is required.';
        if (_firstName.text.trim().isEmpty) return 'First name is required.';
        if (_phone.text.trim().isEmpty) {
          return 'Mobile number is required.';
        }
        final String email = _email.text.trim();
        if (email.isEmpty || !email.contains('@')) {
          return 'A valid email address is required.';
        }
        if (_password.text.length < 6) {
          return 'Password must be at least 6 characters.';
        }
        return null;
      case 1:
        if (_barangay.trim().isEmpty) return 'Please select your barangay.';
        final int? household = int.tryParse(_household.text.trim());
        if (household == null || household < 1) {
          return 'Enter a valid number of household members.';
        }
        return null;
      default:
        return null;
    }
  }

  void _next() {
    final String? error = _validateStep(_step);
    if (error != null) {
      setState(() => _stepError = error);
      return;
    }
    setState(() => _stepError = null);
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final ThemeData theme = Theme.of(context);

    final List<String> labels = <String>[
      'Personal details',
      'Household location',
      'Safety information',
    ];

    return Scaffold(
      appBar: SumpayAppBar(
        title: 'Create account',
        subtitle: 'Step ${_step + 1} of 3 — ${labels[_step]}',
      ),
      body: SafeArea(
        child: ContentContainer(
          maxWidth: 620,
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.pageInset),
                child: Row(
                  children: List<Widget>.generate(3, (int i) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
                        child: AnimatedContainer(
                          duration: AppConstants.shortAnim,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i <= _step
                                ? theme.colorScheme.primary
                                : theme.dividerColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    context.pageInset,
                    22,
                    context.pageInset,
                    20,
                  ),
                  children: <Widget>[
                    if (_step == 0) ..._personalStep(),
                    if (_step == 1) ..._locationStep(),
                    if (_step == 2) ..._safetyStep(theme),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.pageInset,
                  0,
                  context.pageInset,
                  18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_stepError != null) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(Symbols.error_rounded,
                                color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_stepError!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: <Widget>[
                    if (_step > 0) ...<Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() {
                                _stepError = null;
                                _step--;
                              }),
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: auth.isSubmitting ||
                                (_step == 2 && !_consent)
                            ? null
                            : _next,
                        child: auth.isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(_step == 2 ? 'Complete registration' : 'Continue'),
                      ),
                    ),
                  ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _personalStep() {
    return <Widget>[
      AppTextField(
        label: 'Surname',
        hint: 'Dela Cruz',
        controller: _surname,
        prefixIcon: Symbols.badge_rounded,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 18),
      AppTextField(
        label: 'First name',
        hint: 'Juan',
        controller: _firstName,
        prefixIcon: Symbols.person_rounded,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 18),
      AppTextField(
        label: 'Middle name (optional)',
        hint: 'Santos',
        controller: _middleName,
        prefixIcon: Symbols.person_outline_rounded,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 18),
      AppTextField(
        label: 'Mobile number',
        hint: '+63 9XX XXX XXXX',
        controller: _phone,
        prefixIcon: Symbols.smartphone_rounded,
        keyboardType: TextInputType.phone,
        helperText: 'Used to identify you on the mesh network.',
      ),
      const SizedBox(height: 18),
      AppTextField(
        label: 'Email address',
        hint: 'juan@example.ph',
        controller: _email,
        prefixIcon: Symbols.mail_rounded,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 18),
      AppTextField(
        label: 'Password',
        hint: 'At least 8 characters',
        controller: _password,
        prefixIcon: Symbols.lock_rounded,
        obscureText: true,
      ),
    ];
  }

  List<Widget> _locationStep() {
    return <Widget>[
      Text('Barangay', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _barangay,
        items: _barangays
            .map((String b) => DropdownMenuItem<String>(
                  value: b,
                  child: Text('Barangay $b'),
                ))
            .toList(),
        onChanged: (String? v) => setState(() => _barangay = v ?? _barangay),
        decoration: const InputDecoration(
          prefixIcon: Icon(Symbols.location_city_rounded, size: 22),
        ),
      ),
      const SizedBox(height: 18),
      AppTextField(
        label: 'Purok / Sitio and street',
        hint: 'Purok 4, Sitio Bagong Silang',
        controller: _purok,
        prefixIcon: Symbols.home_pin_rounded,
      ),
      const SizedBox(height: 18),
      AppTextField(
        label: 'Number of household members',
        hint: '5',
        controller: _household,
        prefixIcon: Symbols.family_restroom_rounded,
        keyboardType: TextInputType.number,
        helperText: 'Helps responders plan evacuation transport.',
      ),
      const SizedBox(height: 18),
      const AppCard(
        child: Row(
          children: <Widget>[
            Icon(Symbols.my_location_rounded, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your GPS coordinates will be captured automatically the first time you send an SOS.',
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _safetyStep(ThemeData theme) {
    return <Widget>[
      AppTextField(
        label: 'Emergency contact name',
        hint: 'Maria Dela Cruz',
        controller: _contactName,
        prefixIcon: Symbols.contact_emergency_rounded,
      ),
      const SizedBox(height: 18),
      AppTextField(
        label: 'Emergency contact number',
        hint: '+63 9XX XXX XXXX',
        controller: _contactPhone,
        prefixIcon: Symbols.call_rounded,
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 18),
      Text('Blood type', style: theme.textTheme.labelLarge),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _bloodType,
        items: _bloodTypes
            .map((String b) =>
                DropdownMenuItem<String>(value: b, child: Text(b)))
            .toList(),
        onChanged: (String? v) => setState(() => _bloodType = v ?? _bloodType),
        decoration: const InputDecoration(
          prefixIcon: Icon(Symbols.bloodtype_rounded, size: 22),
        ),
      ),
      const SizedBox(height: 22),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: CheckboxListTile(
          value: _consent,
          onChanged: (bool? v) => setState(() => _consent = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(
            'I consent to sharing this information with barangay responders during an emergency.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    ];
  }
}
