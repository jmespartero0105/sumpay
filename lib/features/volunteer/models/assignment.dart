import '../../../core/constants/app_enums.dart';

/// A task dispatched to a volunteer by the barangay command node.
class Assignment {
  const Assignment({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.status,
    required this.locationLabel,
    required this.distanceMetres,
    required this.assignedAt,
    required this.peopleWaiting,
    required this.teamName,
    this.linkedSosId,
  });

  final String id;
  final String title;
  final String description;
  final EmergencyType type;
  final PriorityLevel priority;
  final TaskStatus status;
  final String locationLabel;
  final double distanceMetres;
  final DateTime assignedAt;
  final int peopleWaiting;
  final String teamName;
  final String? linkedSosId;

  Assignment copyWith({TaskStatus? status}) {
    return Assignment(
      id: id,
      title: title,
      description: description,
      type: type,
      priority: priority,
      status: status ?? this.status,
      locationLabel: locationLabel,
      distanceMetres: distanceMetres,
      assignedAt: assignedAt,
      peopleWaiting: peopleWaiting,
      teamName: teamName,
      linkedSosId: linkedSosId,
    );
  }

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      type: EmergencyType.values.byName(json['type'] as String),
      priority: PriorityLevel.values.byName(json['priority'] as String),
      status: TaskStatus.values.byName(json['status'] as String),
      locationLabel: json['locationLabel'] as String,
      distanceMetres: (json['distanceMetres'] as num).toDouble(),
      assignedAt: DateTime.now().subtract(
        Duration(minutes: json['minutesAgo'] as int),
      ),
      peopleWaiting: json['peopleWaiting'] as int,
      teamName: json['teamName'] as String,
      linkedSosId: json['linkedSosId'] as String?,
    );
  }
}
