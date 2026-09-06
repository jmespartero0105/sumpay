import '../../../core/constants/app_enums.dart';

/// Aggregate operational figures rendered on the official dashboard.
class CommandStatistics {
  const CommandStatistics({
    required this.residentsRegistered,
    required this.residentsOnline,
    required this.connectedNodes,
    required this.totalNodes,
    required this.activeIncidents,
    required this.volunteersDeployed,
    required this.evacuees,
    required this.broadcastsToday,
    required this.averageResponse,
    required this.acknowledgementRate,
  });

  final int residentsRegistered;
  final int residentsOnline;
  final int connectedNodes;
  final int totalNodes;
  final int activeIncidents;
  final int volunteersDeployed;
  final int evacuees;
  final int broadcastsToday;
  final Duration averageResponse;
  final double acknowledgementRate;

  double get onlineRate =>
      residentsRegistered == 0 ? 0 : (residentsOnline / residentsRegistered) * 100;

  factory CommandStatistics.fromJson(Map<String, dynamic> json) {
    return CommandStatistics(
      residentsRegistered: json['residentsRegistered'] as int,
      residentsOnline: json['residentsOnline'] as int,
      connectedNodes: json['connectedNodes'] as int,
      totalNodes: json['totalNodes'] as int,
      activeIncidents: json['activeIncidents'] as int,
      volunteersDeployed: json['volunteersDeployed'] as int,
      evacuees: json['evacuees'] as int,
      broadcastsToday: json['broadcastsToday'] as int,
      averageResponse: Duration(minutes: json['averageResponseMinutes'] as int),
      acknowledgementRate: (json['acknowledgementRate'] as num).toDouble(),
    );
  }
}

/// System-level alert displayed to officials.
class SystemAlert {
  const SystemAlert({
    required this.id,
    required this.title,
    required this.detail,
    required this.severity,
    required this.raisedAt,
  });

  final String id;
  final String title;
  final String detail;
  final BroadcastSeverity severity;
  final DateTime raisedAt;

  factory SystemAlert.fromJson(Map<String, dynamic> json) {
    return SystemAlert(
      id: json['id'] as String,
      title: json['title'] as String,
      detail: json['detail'] as String,
      severity: BroadcastSeverity.values.byName(json['severity'] as String),
      raisedAt: DateTime.now().subtract(
        Duration(minutes: json['minutesAgo'] as int),
      ),
    );
  }
}
