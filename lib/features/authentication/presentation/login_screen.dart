import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_inputs.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../providers/auth_provider.dart';

/// Credential entry screen with a demo role switcher for adviser review.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _identifier = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _obscure = true;
  bool _remember = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref.read(authProvider.notifier).signIn(
          identifier: _identifier.text,
          password: _password.text,
        );

    if (!mounted) return;
    final AuthState state = ref.read(authProvider);
    if (state.isAuthenticated) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthState auth = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: ContentContainer(
          maxWidth: 560,
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: context.pageInset,
              vertical: 20,
            ),
            children: <Widget>[
              const SizedBox(height: 10),
              Hero(
                tag: 'sumpay-logo',
                child: Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Symbols.emergency_share_rounded,
                    size: 38,
                    color: Colors.white,
                    weight: 600,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text('Welcome back', style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                'Sign in to connect with your barangay, even without internet access.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 30),
              AppTextField(
                label: 'Mobile number',
                hint: '+63 9XX XXX XXXX',
                controller: _identifier,
                prefixIcon: Symbols.smartphone_rounded,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 18),
              AppTextField(
                label: 'Password',
                hint: 'Enter your password',
                controller: _password,
                prefixIcon: Symbols.lock_rounded,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Symbols.visibility_rounded
                        : Symbols.visibility_off_rounded,
                    size: 22,
                  ),
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Checkbox(
                    value: _remember,
                    onChanged: (bool? v) =>
                        setState(() => _remember = v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'Keep me signed in on this device',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              if (auth.errorMessage != null) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Symbols.error_rounded,
                        color: AppColors.danger,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          auth.errorMessage!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: auth.isSubmitting ? null : _submit,
                child: auth.isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Sign in'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => AppDialogs.info(
                  context,
                  title: 'Password recovery',
                  message:
                      'Visit the barangay hall with a valid ID to have your SUMPAY password reset by an authorised official.',
                  icon: Symbols.support_agent_rounded,
                ),
                child: const Text('Forgot your password?'),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              Row(
                children: <Widget>[
                  Expanded(child: Divider(color: theme.dividerColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('New to SUMPAY?',
                        style: theme.textTheme.bodySmall),
                  ),
                  Expanded(child: Divider(color: theme.dividerColor)),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.register),
                icon: const Icon(Symbols.person_add_rounded),
                label: const Text('Register your household'),
              ),
              const SizedBox(height: 26),
              Center(
                child: Text(
                  '${AppConstants.appName} v${AppConstants.appVersion} • ${AppConstants.organisation}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
