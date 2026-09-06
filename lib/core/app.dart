import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'constants/app_constants.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import '../features/settings/providers/settings_provider.dart';

/// Root application widget wiring theme, routing and responsive breakpoints.
class SumpayApp extends ConsumerWidget {
  const SumpayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    final AppSettings settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        final Widget responsive = ResponsiveBreakpoints.builder(
          child: child!,
          breakpoints: const <Breakpoint>[
            Breakpoint(start: 0, end: 480, name: MOBILE),
            Breakpoint(start: 481, end: 719, name: 'MOBILE_LARGE'),
            Breakpoint(start: 720, end: 1099, name: TABLET),
            Breakpoint(start: 1100, end: double.infinity, name: DESKTOP),
          ],
        );

        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(settings.textScale),
          ),
          child: responsive,
        );
      },
    );
  }
}
