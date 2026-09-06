import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../data/repositories/volunteer_task_repository.dart';
import '../models/assignment.dart';

/// Manages the volunteer's assignment queue.
class AssignmentController extends StateNotifier<List<Assignment>> {
  AssignmentController(VolunteerTaskRepository repository)
      : super(repository.seed);

  void updateStatus(String id, TaskStatus status) {
    state = state
        .map((Assignment a) => a.id == id ? a.copyWith(status: status) : a)
        .toList();
  }

  void accept(String id) => updateStatus(id, TaskStatus.accepted);

  void start(String id) => updateStatus(id, TaskStatus.inProgress);

  void complete(String id) => updateStatus(id, TaskStatus.completed);
}

final StateNotifierProvider<AssignmentController, List<Assignment>>
    assignmentsProvider =
    StateNotifierProvider<AssignmentController, List<Assignment>>(
  (Ref ref) =>
      AssignmentController(ref.watch(volunteerTaskRepositoryProvider)),
);

/// Assignments that still require action.
final Provider<List<Assignment>> openAssignmentsProvider =
    Provider<List<Assignment>>((Ref ref) {
  return ref
      .watch(assignmentsProvider)
      .where((Assignment a) => a.status != TaskStatus.completed)
      .toList();
});

/// Total number of people currently waiting across open assignments.
final Provider<int> peopleWaitingProvider = Provider<int>((Ref ref) {
  return ref.watch(openAssignmentsProvider).fold<int>(
        0,
        (int sum, Assignment a) => sum + a.peopleWaiting,
      );
});

/// The single highest-priority task, used for the navigation card.
final Provider<Assignment?> focusAssignmentProvider =
    Provider<Assignment?>((Ref ref) {
  final List<Assignment> open = ref.watch(openAssignmentsProvider);
  if (open.isEmpty) return null;

  final List<Assignment> sorted = <Assignment>[...open]..sort(
      (Assignment a, Assignment b) {
        final int byPriority =
            b.priority.index.compareTo(a.priority.index);
        if (byPriority != 0) return byPriority;
        return a.distanceMetres.compareTo(b.distanceMetres);
      },
    );
  return sorted.first;
});

/// Completed task count for the summary strip.
final Provider<int> completedTaskCountProvider = Provider<int>((Ref ref) {
  return ref
      .watch(assignmentsProvider)
      .where((Assignment a) => a.status == TaskStatus.completed)
      .length;
});
