import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/repository.dart';
import '../../models/assignment.dart';
import '../dummy_assignments.dart';

/// Data-layer access point for volunteer [Assignment] (task) records.
abstract interface class VolunteerTaskRepository
    implements ReadableRepository<Assignment> {
  /// Synchronous seed used by controllers to initialise their state.
  List<Assignment> get seed;

  /// Preset quick-report messages surfaced on the volunteer dashboard.
  Future<List<String>> quickReports();
}

/// Dummy implementation backed by [DummyAssignments].
class DummyVolunteerTaskRepository implements VolunteerTaskRepository {
  const DummyVolunteerTaskRepository();

  @override
  String get name => 'DummyVolunteerTaskRepository';

  @override
  List<Assignment> get seed => const <Assignment>[];

  @override
  Future<List<Assignment>> fetchAll() async => const <Assignment>[];

  @override
  Future<List<String>> quickReports() async => DummyAssignments.quickReports;
}

/// Provides the active [VolunteerTaskRepository] implementation.
final Provider<VolunteerTaskRepository> volunteerTaskRepositoryProvider =
    Provider<VolunteerTaskRepository>(
  (Ref ref) => const DummyVolunteerTaskRepository(),
);
