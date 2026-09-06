import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app.dart';
import 'core/data/app_database.dart';
import 'core/data/database_provider.dart';
import 'core/data/device_identity.dart';
import 'core/data/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SUMPAY targets portrait-first handsets and tablets in landscape.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialise local persistence. On mobile the database starts empty; all data
  // comes from real user actions. On WEB there is no local database — the app is
  // internet-only (Supabase is the source of truth), so we skip DB init and
  // repositories read/write through Supabase.
  final AppDatabase database = AppDatabase.instance;
  String deviceId;
  if (kIsWeb) {
    deviceId = 'web-${DateTime.now().millisecondsSinceEpoch}';
  } else {
    await database.initialize();
    // Resolve (or create) this device's persistent mesh id before the app runs,
    // so routing has a stable Sender ID available synchronously.
    final DeviceIdentity identity = DeviceIdentity(database);
    deviceId = await identity.ensure();
  }

  // Initialise the Supabase backend for the internet transport if configured.
  await SupabaseConfig.initIfConfigured();

  runApp(
    ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        deviceIdProvider.overrideWithValue(deviceId),
      ],
      child: const SumpayApp(),
    ),
  );
}
