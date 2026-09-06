import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_config.dart';
import '../../../../core/constants/app_enums.dart';
import '../../models/sos_request.dart';

/// Parses a comma-separated list of [EmergencyType] names, skipping blanks and
/// unknown entries.
List<EmergencyType> _decodeTypes(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <EmergencyType>[];
  final Map<String, EmergencyType> byName = EmergencyType.values.asNameMap();
  return raw
      .split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty && byName.containsKey(s))
      .map((String s) => byName[s]!)
      .toList();
}

/// Syncs each resident's SOS history to Supabase so it can be viewed from any
/// device they sign in on. History is scoped by `requester_id`, so a resident
/// only ever sees their own past SOS.
///
/// The table is best-effort: if Supabase is not configured or the network is
/// down, calls silently no-op and the local SQLite history is used instead.
class SosHistoryService {
  const SosHistoryService();

  static const String _table = 'sos_history';

  SupabaseClient get _client => Supabase.instance.client;

  /// Upserts one SOS record for [requesterId] (called on create and on every
  /// status change).
  Future<void> upsert(SosRequest sos, String requesterId) async {
    if (!SupabaseConfig.isConfigured || requesterId.isEmpty) return;
    try {
      await _client.from(_table).upsert(<String, Object?>{
        'id': sos.id,
        'requester_id': requesterId,
        'requester_name': sos.requesterName,
        'type': sos.type.name,
        'additional_types':
            sos.additionalTypes.map((EmergencyType t) => t.name).join(','),
        'priority': sos.priority.name,
        'description': sos.description,
        'location_label': sos.locationLabel,
        'latitude': sos.latitude,
        'longitude': sos.longitude,
        'created_at': sos.createdAt.toIso8601String(),
        'status': sos.status.name,
        'people_affected': sos.peopleAffected,
        'responding_unit': sos.respondingUnit,
      });
    } catch (error) {
      debugPrint('SosHistoryService: upsert failed: $error');
    }
  }

  /// Fetches the SOS history for [requesterId], newest first. Returns an empty
  /// list when offline or unconfigured.
  /// Fetches ALL residents' SOS history (for the barangay Command Centre to
  /// monitor every incident, past and present, with responder/status details).
  /// Deduplicated by id, preferring the latest/terminal record.
  Future<List<SosRequest>> fetchAll({int limit = 200}) async {
    if (!SupabaseConfig.isConfigured) return <SosRequest>[];
    try {
      final dynamic response = await _client
          .from(_table)
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      final List<Map<String, dynamic>> rows =
          (response as List<dynamic>).cast<Map<String, dynamic>>();
      final List<SosRequest> parsed = rows.map(_fromRow).toList();
      // Dedupe by id, preferring a terminal (resolved/cancelled) record over a
      // stale active duplicate.
      final Map<String, SosRequest> byId = <String, SosRequest>{};
      for (final SosRequest r in parsed) {
        final SosRequest? existing = byId[r.id];
        if (existing == null) {
          byId[r.id] = r;
          continue;
        }
        final bool existingTerminal =
            existing.status == IncidentStatus.resolved ||
                existing.status == IncidentStatus.cancelled;
        final bool newTerminal = r.status == IncidentStatus.resolved ||
            r.status == IncidentStatus.cancelled;
        if (newTerminal && !existingTerminal) byId[r.id] = r;
      }
      final List<SosRequest> list = byId.values.toList()
        ..sort((SosRequest a, SosRequest b) =>
            b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (error) {
      debugPrint('SosHistoryService: fetchAll failed: $error');
      return <SosRequest>[];
    }
  }

  Future<List<SosRequest>> fetchForResident(String requesterId) async {
    if (!SupabaseConfig.isConfigured || requesterId.isEmpty) {
      return <SosRequest>[];
    }
    try {
      final dynamic response = await _client
          .from(_table)
          .select()
          .eq('requester_id', requesterId)
          .order('created_at', ascending: false);
      final List<Map<String, dynamic>> rows =
          (response as List<dynamic>).cast<Map<String, dynamic>>();
      final List<SosRequest> parsed =
          rows.map(_fromRow).toList();
      // Guard against duplicate rows for the same SOS id (which occur if the
      // table's id is not a unique/primary key, so upserts inserted instead of
      // replaced). Keep ONE record per id, preferring a terminal status
      // (resolved/cancelled) so a stale "active" duplicate never wins.
      final Map<String, SosRequest> byId = <String, SosRequest>{};
      for (final SosRequest r in parsed) {
        final SosRequest? existing = byId[r.id];
        if (existing == null) {
          byId[r.id] = r;
          continue;
        }
        final bool existingTerminal =
            existing.status == IncidentStatus.resolved ||
                existing.status == IncidentStatus.cancelled;
        final bool newTerminal = r.status == IncidentStatus.resolved ||
            r.status == IncidentStatus.cancelled;
        // Prefer a terminal record; if both same, keep the first (newest by the
        // query's created_at desc ordering).
        if (newTerminal && !existingTerminal) {
          byId[r.id] = r;
        }
      }
      return byId.values.toList();
    } catch (error) {
      debugPrint('SosHistoryService: fetch failed: $error');
      return <SosRequest>[];
    }
  }

  SosRequest _fromRow(Map<String, dynamic> row) {
    return SosRequest(
      id: row['id'] as String,
      type: EmergencyType.values.asNameMap()[row['type'] as String? ?? ''] ??
          EmergencyType.custom,
      additionalTypes: _decodeTypes(row['additional_types'] as String?),
      priority: PriorityLevel.values
              .asNameMap()[row['priority'] as String? ?? ''] ??
          PriorityLevel.normal,
      description: row['description'] as String? ?? '',
      locationLabel: row['location_label'] as String? ?? '',
      latitude: (row['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (row['longitude'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      status: IncidentStatus.values
              .asNameMap()[row['status'] as String? ?? ''] ??
          IncidentStatus.active,
      delivery: DeliveryStatus.delivered,
      hopCount: 0,
      peopleAffected: (row['people_affected'] as int?) ?? 1,
      requesterName: row['requester_name'] as String? ?? 'You',
      requesterId: row['requester_id'] as String? ?? '',
      respondingUnit: row['responding_unit'] as String?,
    );
  }
}
