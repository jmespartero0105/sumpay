import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../authentication/models/app_user.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../broadcast/providers/broadcast_provider.dart';
import '../../iot/providers/mesh_manager_provider.dart';
import '../../messaging/data/manager/transport_manager_provider.dart';
import '../../sos/providers/sos_mesh_provider.dart';

/// Branded bootstrap screen shown while local services initialise.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppConstants.longAnim,
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.86,
    end: 1.0,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(AppConstants.bootstrapDelay);
    if (!mounted) return;

    // Restore the previously signed-in user (session pointer), if any. Guarded
    // so any failure here can never leave the app stuck on the splash.
    AppUser? restored;
    try {
      restored = await ref.read(authProvider.notifier).restoreSession();
    } catch (error) {
      debugPrint('Splash: session restore failed: $error');
      restored = null;
    }

    if (!mounted) return;
    if (restored != null) {
      _startBackgroundServices();
      if (!mounted) return;
      context.go(AppRoutes.home);
      return;
    }

    _startBackgroundServices();

    final AuthState auth = ref.read(authProvider);
    if (!mounted) return;
    if (auth.isAuthenticated) {
      context.go(AppRoutes.home);
    } else if (auth.hasSeenOnboarding) {
      context.go(AppRoutes.login);
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  /// Instantiates the app-lifetime background services (automatic mesh
  /// formation and the SOS mesh receiver) once, after startup. Guarded so a
  /// failure in either cannot block navigation or freeze the splash.
  void _startBackgroundServices() {
    try {
      ref.read(meshManagerProvider);
      ref.read(sosMeshProvider);
      // Pre-warm the broadcast controller so it subscribes to incoming
      // broadcasts immediately — otherwise it only starts listening when a
      // screen first opens the broadcast feed, and any broadcast that arrives
      // before then (live or via catch-up) is missed.
      ref.read(broadcastsProvider);
      // Start the transport manager so the internet path connects (when
      // configured) alongside the mesh. Mesh-only if no backend is set.
      ref.read(transportManagerProvider).start();
    } catch (error) {
      debugPrint('Splash: background services failed to start: $error');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.primary, Color(0xFFB80102)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Column(
                    children: <Widget>[
                      Hero(
                        tag: 'sumpay-logo',
                        child: Container(
                          height: 116,
                          width: 116,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Symbols.emergency_share_rounded,
                            size: 58,
                            color: AppColors.primary,
                            weight: 600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        AppConstants.appName,
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: Colors.white,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 44),
                        child: Text(
                          AppConstants.appFullName,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 56),
              FadeTransition(
                opacity: _fade,
                child: Column(
                  children: <Widget>[
                    const SizedBox(
                      height: 30,
                      width: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Initialising SUMPAY',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      AppConstants.organisation,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
