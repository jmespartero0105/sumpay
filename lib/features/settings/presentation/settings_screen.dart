import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/section_header.dart';
import '../providers/settings_provider.dart';

/// Accessibility, emergency, offline and notification preferences.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppSettings settings = ref.watch(settingsProvider);
    final SettingsController controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: const SumpayAppBar(
        title: 'Settings',
        subtitle: 'Accessibility, emergency and offline preferences',
      ),
      body: SafeArea(
        child: ContentContainer(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageInset,
              6,
              context.pageInset,
              28,
            ),
            children: <Widget>[
              const SectionHeader(title: 'Accessibility'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      value: settings.isDarkMode,
                      onChanged: controller.toggleDarkMode,
                      secondary: const Icon(Symbols.dark_mode_rounded),
                      title: Text('Dark mode', style: theme.textTheme.titleSmall),
                      subtitle: Text(
                        'Reduces glare and saves battery on OLED screens.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    SwitchListTile(
                      value: settings.highContrast,
                      onChanged: controller.toggleHighContrast,
                      secondary: const Icon(Symbols.contrast_rounded),
                      title: Text(
                        'High contrast',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'Stronger borders and text separation.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    SwitchListTile(
                      value: settings.reduceMotion,
                      onChanged: controller.toggleReduceMotion,
                      secondary: const Icon(Symbols.animation_rounded),
                      title: Text(
                        'Reduce motion',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'Disables pulsing and sliding animations.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    SwitchListTile(
                      value: settings.hapticFeedback,
                      onChanged: controller.toggleHaptics,
                      secondary: const Icon(Symbols.vibration_rounded),
                      title: Text(
                        'Haptic feedback',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'Vibrate on critical actions such as sending an SOS.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(Symbols.format_size_rounded, size: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Text size',
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              Text(
                                '${(settings.textScale * 100).round()}%',
                                style: theme.textTheme.titleSmall,
                              ),
                            ],
                          ),
                          Slider(
                            value: settings.textScale,
                            min: 0.9,
                            max: 1.5,
                            divisions: 6,
                            label: '${(settings.textScale * 100).round()}%',
                            onChanged: controller.setTextScale,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              const SectionHeader(title: 'Emergency preferences'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      value: settings.sosConfirmationRequired,
                      onChanged: controller.toggleSosConfirmation,
                      secondary: const Icon(Symbols.verified_user_rounded),
                      title: Text(
                        'Confirm before sending SOS',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'Prevents accidental emergency transmissions.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    SwitchListTile(
                      value: settings.shareLocationOnSos,
                      onChanged: controller.toggleShareLocation,
                      secondary: const Icon(Symbols.my_location_rounded),
                      title: Text(
                        'Share location with SOS',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'Attaches your last known GPS fix to every request.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    SwitchListTile(
                      value: settings.shareMedicalOnSos,
                      onChanged: controller.toggleShareMedical,
                      secondary: const Icon(Symbols.medical_information_rounded),
                      title: Text(
                        'Share medical profile',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'Blood type, allergies and conditions reach responders.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              const SectionHeader(title: 'Offline and network'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      value: settings.autoConnect,
                      onChanged: controller.setAutoConnect,
                      secondary: const Icon(Symbols.wifi_tethering_rounded),
                      title: Text(
                        'Automatic connection',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'Automatically finds and connects to nearby SUMPAY devices. Turn off to connect manually.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    SwitchListTile(
                      value: settings.offlineQueueEnabled,
                      onChanged: controller.toggleOfflineQueue,
                      secondary: const Icon(Symbols.schedule_send_rounded),
                      title: Text(
                        'Queue messages offline',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'Stores outgoing messages until a connection is available.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    SwitchListTile(
                      value: settings.autoRelayMessages,
                      onChanged: controller.toggleAutoRelay,
                      secondary: const Icon(Symbols.hub_rounded),
                      title: Text(
                        'Relay for neighbours',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'Allows this device to forward nearby traffic over the mesh.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    SwitchListTile(
                      value: settings.syncOnWifiOnly,
                      onChanged: controller.toggleWifiOnlySync,
                      secondary: const Icon(Symbols.wifi_rounded),
                      title: Text(
                        'Cloud sync on Wi-Fi only',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'Saves mobile data when connectivity returns.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Symbols.router_rounded),
                      title: Text(
                        'Network diagnostics',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'SUMPAY Network status',
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: const Icon(Symbols.chevron_right_rounded),
                      onTap: () => context.go(AppRoutes.network),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              const SectionHeader(title: 'Notifications'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      value: settings.broadcastNotifications,
                      onChanged: controller.toggleBroadcastNotifications,
                      secondary: const Icon(Symbols.campaign_rounded),
                      title: Text(
                        'Barangay broadcasts',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'Alerts always override silent mode.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    SwitchListTile(
                      value: settings.messageNotifications,
                      onChanged: controller.toggleMessageNotifications,
                      secondary: const Icon(Symbols.forum_rounded),
                      title: Text(
                        'Direct messages',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'Notify when someone messages you.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    SwitchListTile(
                      value: settings.networkNotifications,
                      onChanged: controller.toggleNetworkNotifications,
                      secondary: const Icon(Symbols.wifi_tethering_rounded),
                      title: Text(
                        'Network changes',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'Notify when a connection starts or drops.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              const SectionHeader(title: 'Language'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: SettingsController.languages
                      .map((String lang) => RadioListTile<String>(
                            value: lang,
                            groupValue: settings.language,
                            onChanged: (String? v) =>
                                controller.setLanguage(v ?? lang),
                            title: Text(lang, style: theme.textTheme.titleSmall),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              const SectionHeader(title: 'About'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Symbols.info_rounded),
                      title: Text(
                        'About ${AppConstants.appName}',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'Version ${AppConstants.appVersion}',
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: const Icon(Symbols.chevron_right_rounded),
                      onTap: () => context.push(AppRoutes.about),
                    ),
                    ListTile(
                      leading: const Icon(Symbols.restart_alt_rounded),
                      title: Text(
                        'Reset to defaults',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'Restores every preference on this screen.',
                        style: theme.textTheme.bodySmall,
                      ),
                      onTap: () async {
                        final bool ok = await AppDialogs.confirm(
                          context,
                          title: 'Reset settings?',
                          message:
                              'All accessibility, emergency and notification preferences return to their defaults.',
                          confirmLabel: 'Reset',
                          icon: Symbols.restart_alt_rounded,
                        );
                        if (!ok || !context.mounted) return;
                        controller.resetToDefaults();
                        if (!context.mounted) return;
                        AppDialogs.snack(
                          context,
                          'Settings restored to defaults.',
                          icon: Symbols.check_circle_rounded,
                        );
                      },
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
}
