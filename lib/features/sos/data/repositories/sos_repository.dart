import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/repository.dart';
import '../../models/sos_request.dart';
import '../dummy_sos.dart';

/// Data-layer access point for [SosRequest] records.
abstract interface class SosRepository
    implements ReadableRepository<SosRequest> {
  /// Synchronous seed used by controllers to initialise their state.
  ///
  /// Kept synchronous so the presentation layer's `StateNotifier`s can seed in
  /// their constructors without becoming asynchronous. Phase 2 can migrate
  /// callers to [fetchAll] once a real async source exists.
  List<SosRequest> get seed;

  /// Quick description presets offered on the SOS composer.
  Future<List<String>> descriptionSuggestions();
}

/// Dummy implementation backed by [DummySos].
class DummySosRepository implements SosRepository {
  const DummySosRepository();

  @override
  String get name => 'DummySosRepository';

  @override
  List<SosRequest> get seed => const <SosRequest>[];

  @override
  Future<List<SosRequest>> fetchAll() async => const <SosRequest>[];

  @override
  Future<List<String>> descriptionSuggestions() async =>
      DummySos.descriptionSuggestions;
}

/// Provides the active [SosRepository] implementation.
final Provider<SosRepository> sosRepositoryProvider =
    Provider<SosRepository>((Ref ref) => const DummySosRepository());
