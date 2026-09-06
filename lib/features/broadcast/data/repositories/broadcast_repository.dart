import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/repository.dart';
import '../../models/broadcast_models.dart';
import '../dummy_broadcasts.dart';

/// Data-layer access point for barangay [BroadcastMessage] records.
abstract interface class BroadcastRepository
    implements ReadableRepository<BroadcastMessage> {
  /// Synchronous seed used by controllers to initialise their state.
  List<BroadcastMessage> get seed;

  /// Rotating preparedness tips shown on the dashboard.
  Future<List<String>> preparednessTips();

  /// Synchronous access to preparedness tips for derived providers.
  List<String> get tips;

  /// Selectable target areas for a new broadcast.
  Future<List<String>> areaOptions();
}

/// Dummy implementation backed by [DummyBroadcasts].
class DummyBroadcastRepository implements BroadcastRepository {
  const DummyBroadcastRepository();

  @override
  String get name => 'DummyBroadcastRepository';

  @override
  List<BroadcastMessage> get seed => const <BroadcastMessage>[];

  @override
  List<String> get tips => DummyBroadcasts.emergencyTips;

  @override
  Future<List<BroadcastMessage>> fetchAll() async => const <BroadcastMessage>[];

  @override
  Future<List<String>> preparednessTips() async =>
      DummyBroadcasts.emergencyTips;

  @override
  Future<List<String>> areaOptions() async => DummyBroadcasts.areaOptions;
}

/// Provides the active [BroadcastRepository] implementation.
final Provider<BroadcastRepository> broadcastRepositoryProvider =
    Provider<BroadcastRepository>(
  (Ref ref) => const DummyBroadcastRepository(),
);
