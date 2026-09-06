import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Exposes the initialised [AppDatabase] to the widget and repository layers.
///
/// The instance is created and opened during app start-up (see `main.dart`)
/// and overridden into the [ProviderScope], so this provider simply surfaces
/// the ready singleton. It throws if read before initialisation, which never
/// happens in normal start-up because the splash flow gates on readiness.
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((Ref ref) {
  throw UnimplementedError(
    'appDatabaseProvider must be overridden in ProviderScope after '
    'AppDatabase.initialize() completes.',
  );
});
