import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_config.dart';
import '../../models/responder.dart';

/// Persists the responder list for each SOS to Supabase so that "who is
/// responding" survives app restarts and is visible across devices (the Command
/// Center on another device sees the same responders).
///
/// Uses one row per SOS with a JSON array of responders, upserted on change.
/// Best-effort: silently no-ops when Supabase is unconfigured or offline.
class SosResponderSync {
  const SosResponderSync();

  static const String _table = 'sos_responders';

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> saveResponders(
      String sosId, List<Responder> responders) async {
    if (!SupabaseConfig.isConfigured || sosId.isEmpty) return;
    try {
      await _client.from(_table).upsert(<String, Object?>{
        'sos_id': sosId,
        'responders': jsonEncode(
            responders.map((Responder r) => r.toMap()).toList()),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      debugPrint('SosResponderSync: save failed: $error');
    }
  }

  /// Fetches the responder list for one SOS (used to hydrate on load).
  Future<List<Responder>> fetchResponders(String sosId) async {
    if (!SupabaseConfig.isConfigured || sosId.isEmpty) {
      return <Responder>[];
    }
    try {
      final dynamic response = await _client
          .from(_table)
          .select()
          .eq('sos_id', sosId)
          .maybeSingle();
      if (response == null) return <Responder>[];
      final Map<String, dynamic> row = response as Map<String, dynamic>;
      final Object? raw = row['responders'];
      if (raw is! String || raw.isEmpty) return <Responder>[];
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((dynamic e) =>
              Responder.fromMap((e as Map<String, dynamic>)))
          .toList();
    } catch (error) {
      debugPrint('SosResponderSync: fetch failed: $error');
      return <Responder>[];
    }
  }
}

final Provider<SosResponderSync> sosResponderSyncProvider =
    Provider<SosResponderSync>((Ref ref) => const SosResponderSync());
