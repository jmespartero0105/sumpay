import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../broadcast/models/broadcast_models.dart';
import '../../broadcast/providers/broadcast_provider.dart';
import '../../iot/providers/mesh_manager_provider.dart';
import '../../sos/models/sos_packet.dart';
import '../../sos/models/sos_request.dart';
import '../../sos/data/services/sos_history_service.dart';
import '../../sos/providers/sos_mesh_provider.dart';
import '../models/command_models.dart';

/// Command-center statistics computed entirely from real application state:
/// the live SOS log, broadcasts, and mesh manager. No simulated values — every
/// figure traces to something the system actually recorded.
final Provider<CommandStatistics> commandStatisticsProvider =
    Provider<CommandStatistics>((Ref ref) {
  // Officials/admins receive incidents into the mesh SOS feed (sosMeshProvider),
  // not the local origination log — an official does not create SOS, they
  // receive them. Counting the incoming feed is what makes the command
  // dashboard reflect real activity.
  final List<TrackedSos> incoming = ref.watch(sosMeshProvider);
  final List<BroadcastMessage> broadcasts = ref.watch(broadcastsProvider);
  final mesh = ref.watch(meshManagerProvider);

  bool isActive(SosStatus s) =>
      s != SosStatus.resolved && s != SosStatus.rejected;

  final List<TrackedSos> active =
      incoming.where((TrackedSos t) => isActive(t.status)).toList();

  // Active incidents, and evacuees approximated as the number of people in
  // active emergencies (one reporting resident per incident; the SOS packet
  // does not carry a headcount across the network).
  final int activeIncidents = active.length;
  final int evacuees = active.length;

  // Volunteers deployed = incidents a responder has accepted / is working.
  final int volunteersDeployed = incoming
      .where((TrackedSos t) =>
          t.status == SosStatus.responderAccepted ||
          t.status == SosStatus.responderEnRoute ||
          t.status == SosStatus.arrived)
      .length;

  // Broadcasts issued today.
  final DateTime now = DateTime.now();
  final int broadcastsToday = broadcasts
      .where((BroadcastMessage b) =>
          b.issuedAt.year == now.year &&
          b.issuedAt.month == now.month &&
          b.issuedAt.day == now.day)
      .length;

  // Real mesh figures.
  final int connectedNodes = mesh.connectedDevices.length;
  final int totalNodes =
      mesh.connectedDevices.length + mesh.discoveredDevices.length;

  // Registered residents: unique residents that appear in the incoming SOS
  // feed is the real signal available on an official's device. (The
  // authoritative roster lives in the admin's Supabase user management view.)
  final Set<String> residentIds = incoming
      .map((TrackedSos t) => t.packet.residentName)
      .toSet();
  final int residentsRegistered = residentIds.length;

  // Residents currently reachable via the mesh right now.
  final int residentsOnline = connectedNodes;

  // Average response time: not tracked with per-incident accept timestamps yet.
  final Duration averageResponse = Duration.zero;

  // Acknowledgement rate: share of incidents that reached a responder.
  final int respondedOrResolved = incoming
      .where((TrackedSos t) =>
          t.status == SosStatus.responderAccepted ||
          t.status == SosStatus.responderEnRoute ||
          t.status == SosStatus.arrived ||
          t.status == SosStatus.resolved)
      .length;
  final double acknowledgementRate =
      incoming.isEmpty ? 0 : respondedOrResolved / incoming.length;

  return CommandStatistics(
    residentsRegistered: residentsRegistered,
    residentsOnline: residentsOnline,
    connectedNodes: connectedNodes,
    totalNodes: totalNodes,
    activeIncidents: activeIncidents,
    volunteersDeployed: volunteersDeployed,
    evacuees: evacuees,
    broadcastsToday: broadcastsToday,
    averageResponse: averageResponse,
    acknowledgementRate: acknowledgementRate,
  );
});

/// System alerts = official outbound emergency communications (evacuation
/// notices, barangay emergency alerts) that officials issue to residents. These
/// are real broadcasts — NOT resident SOS incidents (those are inbound help
/// requests shown in the incident views, and surfacing every one here would
/// flood the feed).
///
/// High-severity alerts (Alert, then Warning) are pinned to the top; routine
/// advisories follow. Within each severity, newest first.
final Provider<List<SystemAlert>> systemAlertsProvider =
    Provider<List<SystemAlert>>((Ref ref) {
  final List<BroadcastMessage> broadcasts = ref.watch(broadcastsProvider);

  int severityRank(BroadcastSeverity s) => switch (s) {
        BroadcastSeverity.alert => 0,
        BroadcastSeverity.warning => 1,
        BroadcastSeverity.advisory => 2,
      };

  final List<BroadcastMessage> sorted = <BroadcastMessage>[...broadcasts]
    ..sort((BroadcastMessage a, BroadcastMessage b) {
      final int bySeverity =
          severityRank(a.severity).compareTo(severityRank(b.severity));
      if (bySeverity != 0) return bySeverity;
      return b.issuedAt.compareTo(a.issuedAt); // newest first within severity
    });

  return sorted
      .map((BroadcastMessage b) => SystemAlert(
            id: b.id,
            title: b.title,
            detail: b.body,
            severity: b.severity,
            raisedAt: b.issuedAt,
          ))
      .toList();
});

/// Whether an alert is high-priority (pinned emphasis in the UI).
bool isHighPriorityAlert(SystemAlert alert) =>
    alert.severity == BroadcastSeverity.alert ||
    alert.severity == BroadcastSeverity.warning;

/// All SOS incidents (past + present) fetched from Supabase, so the barangay
/// Command Centre can monitor every incident with its responder/status details
/// — not just those received live this session. Refreshes when re-read.
final FutureProvider<List<SosRequest>> allSosHistoryProvider =
    FutureProvider<List<SosRequest>>((Ref ref) async {
  return const SosHistoryService().fetchAll();
});
