import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User-configurable application preferences.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.textScale = 1.0,
    this.highContrast = false,
    this.reduceMotion = false,
    this.hapticFeedback = true,
    this.sosConfirmationRequired = true,
    this.shareLocationOnSos = true,
    this.shareMedicalOnSos = true,
    this.autoRelayMessages = true,
    this.offlineQueueEnabled = true,
    this.syncOnWifiOnly = true,
    this.broadcastNotifications = true,
    this.messageNotifications = true,
    this.networkNotifications = false,
    this.autoConnect = true,
    this.language = 'English',
  });

  final ThemeMode themeMode;
  final double textScale;
  final bool highContrast;
  final bool reduceMotion;
  final bool hapticFeedback;
  final bool sosConfirmationRequired;
  final bool shareLocationOnSos;
  final bool shareMedicalOnSos;
  final bool autoRelayMessages;
  final bool offlineQueueEnabled;
  final bool syncOnWifiOnly;
  final bool broadcastNotifications;
  final bool messageNotifications;
  final bool networkNotifications;

  /// When true (default), the device automatically forms the mesh on startup:
  /// advertising, discovering, connecting, and reconnecting without any manual
  /// action. Users can turn this off to connect manually.
  final bool autoConnect;

  final String language;

  bool get isDarkMode => themeMode == ThemeMode.dark;

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? textScale,
    bool? highContrast,
    bool? reduceMotion,
    bool? hapticFeedback,
    bool? sosConfirmationRequired,
    bool? shareLocationOnSos,
    bool? shareMedicalOnSos,
    bool? autoRelayMessages,
    bool? offlineQueueEnabled,
    bool? syncOnWifiOnly,
    bool? broadcastNotifications,
    bool? messageNotifications,
    bool? networkNotifications,
    bool? autoConnect,
    String? language,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      textScale: textScale ?? this.textScale,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      sosConfirmationRequired:
          sosConfirmationRequired ?? this.sosConfirmationRequired,
      shareLocationOnSos: shareLocationOnSos ?? this.shareLocationOnSos,
      shareMedicalOnSos: shareMedicalOnSos ?? this.shareMedicalOnSos,
      autoRelayMessages: autoRelayMessages ?? this.autoRelayMessages,
      offlineQueueEnabled: offlineQueueEnabled ?? this.offlineQueueEnabled,
      syncOnWifiOnly: syncOnWifiOnly ?? this.syncOnWifiOnly,
      broadcastNotifications:
          broadcastNotifications ?? this.broadcastNotifications,
      messageNotifications: messageNotifications ?? this.messageNotifications,
      networkNotifications: networkNotifications ?? this.networkNotifications,
      autoConnect: autoConnect ?? this.autoConnect,
      language: language ?? this.language,
    );
  }
}

/// Settings controller. Persist to secure storage during integration.
class SettingsController extends StateNotifier<AppSettings> {
  SettingsController() : super(const AppSettings());

  static const List<String> languages = <String>[
    'English',
    'Filipino',
    'Cebuano',
    'Hiligaynon',
  ];

  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);

  void toggleDarkMode(bool enabled) => state = state.copyWith(
        themeMode: enabled ? ThemeMode.dark : ThemeMode.light,
      );

  void setTextScale(double value) =>
      state = state.copyWith(textScale: value.clamp(0.9, 1.5));

  void toggleHighContrast(bool value) =>
      state = state.copyWith(highContrast: value);

  void toggleReduceMotion(bool value) =>
      state = state.copyWith(reduceMotion: value);

  void toggleHaptics(bool value) => state = state.copyWith(hapticFeedback: value);

  /// Enables or disables automatic mesh formation on startup.
  void setAutoConnect(bool value) =>
      state = state.copyWith(autoConnect: value);

  void toggleSosConfirmation(bool value) =>
      state = state.copyWith(sosConfirmationRequired: value);

  void toggleShareLocation(bool value) =>
      state = state.copyWith(shareLocationOnSos: value);

  void toggleShareMedical(bool value) =>
      state = state.copyWith(shareMedicalOnSos: value);

  void toggleAutoRelay(bool value) =>
      state = state.copyWith(autoRelayMessages: value);

  void toggleOfflineQueue(bool value) =>
      state = state.copyWith(offlineQueueEnabled: value);

  void toggleWifiOnlySync(bool value) =>
      state = state.copyWith(syncOnWifiOnly: value);

  void toggleBroadcastNotifications(bool value) =>
      state = state.copyWith(broadcastNotifications: value);

  void toggleMessageNotifications(bool value) =>
      state = state.copyWith(messageNotifications: value);

  void toggleNetworkNotifications(bool value) =>
      state = state.copyWith(networkNotifications: value);

  void setLanguage(String value) => state = state.copyWith(language: value);

  void resetToDefaults() => state = const AppSettings();
}

final StateNotifierProvider<SettingsController, AppSettings> settingsProvider =
    StateNotifierProvider<SettingsController, AppSettings>(
  (Ref ref) => SettingsController(),
);
