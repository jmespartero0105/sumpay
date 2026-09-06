import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Backend (Supabase) configuration for SUMPAY's internet transport.
///
/// Fill these in with your Supabase project's values (Project Settings -> API).
/// Until they are set, SUMPAY runs in mesh-only mode: the internet transport
/// stays dormant and nothing crashes. This keeps the offline-first behaviour
/// working out of the box and makes the backend strictly additive.
class SupabaseConfig {
  const SupabaseConfig._();

  /// Your project URL, e.g. https://abcdefgh.supabase.co
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Your project's anon/public key.
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Whether valid-looking config is present.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Initialises Supabase if configured. Safe to call unconditionally: when the
  /// project values are absent, it does nothing and the app continues in
  /// mesh-only mode. Never throws out of [main].
  static Future<void> initIfConfigured() async {
    if (!isConfigured) {
      debugPrint(
          'SupabaseConfig: no backend configured; running in mesh-only mode.');
      return;
    }
    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
      debugPrint('SupabaseConfig: Supabase initialised.');
    } catch (error) {
      debugPrint('SupabaseConfig: init failed, mesh-only mode: $error');
    }
  }
}
