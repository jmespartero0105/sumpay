import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_config.dart';
import '../../models/mesh_packet.dart';
import 'sumpay_transport.dart';

/// Internet transport for SUMPAY, backed by Supabase Realtime (broadcast) for
/// low-latency delivery plus a Postgres table for durability and admin
/// oversight. Implements the same [SumpayTransport] contract as the mesh
/// transport, so the routing/application layers treat internet and mesh
/// identically.
///
/// Design notes:
/// - Uses a Realtime *broadcast* channel as the fast path: packets are sent as
///   broadcast events and received by all other subscribed SUMPAY clients,
///   mirroring the mesh's flood model with the same [MeshPacket].
/// - Also inserts each outbound packet into a `packets` table so a device that
///   was offline can fetch what it missed on reconnect, and so the backend has
///   an authoritative record (used later by admin oversight).
/// - Degrades gracefully: if Supabase has not been initialised (the team has
///   not configured the backend yet), the transport simply reports
///   disconnected and never throws, so the app and the mesh keep working.
class InternetTransport implements SumpayTransport {
  InternetTransport({
    required this.deviceId,
    this.channelName = 'sumpay-mesh',
    this.broadcastEvent = 'packet',
  });

  /// This device's stable id, sent with packets and used to ignore our own
  /// broadcasts echoed back.
  final String deviceId;

  /// Realtime channel all SUMPAY clients share for broadcast delivery.
  final String channelName;

  /// Broadcast event name used for packet delivery on the channel.
  final String broadcastEvent;

  /// How far back the catch-up fetch looks for missed packets on connect.
  /// Bounded so resolved/stale incidents are not resurrected.
  static const Duration _catchUpWindow = Duration(minutes: 30);

  /// Maximum number of packets to replay on catch-up.
  static const int _catchUpLimit = 200;

  RealtimeChannel? _channel;

  final StreamController<TransportInbound> _inboundController =
      StreamController<TransportInbound>.broadcast();
  final StreamController<TransportStatus> _statusController =
      StreamController<TransportStatus>.broadcast();

  TransportStatus _status = TransportStatus.disconnected;

  @override
  TransportKind get kind => TransportKind.internet;

  @override
  TransportStatus get status => _status;

  @override
  Stream<TransportStatus> get statusStream => _statusController.stream;

  @override
  Stream<TransportInbound> get inbound => _inboundController.stream;

  @override
  bool get isAvailable => _status == TransportStatus.connected;

  void _setStatus(TransportStatus next) {
    if (_status == next) return;
    _status = next;
    _statusController.add(next);
  }

  /// Whether Supabase has been initialised by the app. If not, this transport
  /// stays dormant (disconnected) without error.
  bool get _supabaseReady {
    try {
      // Accessing the instance throws if initialize() was never called.
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> start() async {
    if (!_supabaseReady) {
      debugPrint(
          'InternetTransport: Supabase not initialised; internet path dormant.');
      _setStatus(TransportStatus.disconnected);
      return;
    }
    await _connect();
  }

  Future<void> _connect() async {
    _setStatus(TransportStatus.connecting);
    try {
      final SupabaseClient client = Supabase.instance.client;

      // Ensure the Realtime WebSocket carries an auth token. Without this the
      // channel handshake can be rejected (HTTP 401) even though REST/auth
      // requests succeed. Use the current session's token when signed in,
      // otherwise fall back to the anon key so the connection authorises.
      final String? token = client.auth.currentSession?.accessToken;
      client.realtime.setAuth(token ?? SupabaseConfig.anonKey);

      final RealtimeChannel channel = client.channel(channelName);

      channel.onBroadcast(
        event: broadcastEvent,
        callback: _onBroadcast,
      );

      channel.subscribe((RealtimeSubscribeStatus status, Object? error) {
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            _setStatus(TransportStatus.connected);
            // Catch-up: fetch recent packets this device may have missed while
            // it was offline / before it opened the app, and replay them
            // through the same inbound path. The relay de-duplicates by uuid,
            // so anything already processed is dropped harmlessly.
            unawaited(_fetchMissed());
          case RealtimeSubscribeStatus.closed:
          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
            _setStatus(TransportStatus.disconnected);
        }
      });

      _channel = channel;
    } catch (error) {
      debugPrint('InternetTransport: connect failed: $error');
      _setStatus(TransportStatus.disconnected);
    }
  }

  void _onBroadcast(Map<String, dynamic> payload) {
    try {
      // Supabase broadcast payloads can arrive either flat (the map we sent,
      // with 'packet' at top level) or nested under a 'payload' key depending
      // on client version. Handle both so a version difference can't silently
      // drop messages.
      Object? raw = payload['packet'];
      if (raw == null && payload['payload'] is Map) {
        final Map<String, dynamic> inner =
            Map<String, dynamic>.from(payload['payload'] as Map);
        raw = inner['packet'];
      }
      if (raw is! Map) {
        return;
      }
      final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
      if (json['senderId'] == deviceId) {
        return;
      }
      final MeshPacket packet = MeshPacket.fromJson(json);
      _inboundController.add(
        TransportInbound(packet: packet, via: TransportKind.internet),
      );
    } catch (error) {
      debugPrint('InternetTransport: bad inbound packet: $error');
    }
  }

  /// Fetches recent packets from the durability table and replays any this
  /// device has not already processed, so a device that connects late still
  /// receives SOS alerts and broadcasts it missed. Bounded to a recent window
  /// so resolved/stale incidents are not resurrected, and ordered oldest-first
  /// so state transitions (e.g. sent -> accepted -> resolved) replay in order.
  Future<void> _fetchMissed() async {
    try {
      final DateTime since =
          DateTime.now().toUtc().subtract(_catchUpWindow);
      final dynamic response = await Supabase.instance.client
          .from('packets')
          .select('payload, created_at, sender_id')
          .gte('created_at', since.toIso8601String())
          .order('created_at', ascending: true)
          .limit(_catchUpLimit);
      final List<Map<String, dynamic>> rows =
          (response as List<dynamic>).cast<Map<String, dynamic>>();
      for (final Map<String, dynamic> row in rows) {
        // Skip our own packets, mirroring the live broadcast path.
        if (row['sender_id'] == deviceId) continue;
        final Object? payload = row['payload'];
        if (payload is! Map) continue;
        try {
          final MeshPacket packet =
              MeshPacket.fromJson(Map<String, dynamic>.from(payload));
          if (packet.senderId == deviceId) continue;
          _inboundController.add(
            TransportInbound(packet: packet, via: TransportKind.internet),
          );
        } catch (_) {
          // Skip any single undecodable row without aborting the catch-up.
        }
      }
    } catch (error) {
      // Non-fatal: live delivery still works; catch-up may fail if the packets
      // table lacks a select policy or is unreachable.
      debugPrint('InternetTransport: catch-up fetch skipped: $error');
    }
  }

  @override
  Future<void> send(MeshPacket packet) async {
    if (!isAvailable || _channel == null) {
      // Not connected: signal failure so the caller can fall back / queue.
      throw StateError('InternetTransport not connected');
    }
    final Map<String, dynamic> json = packet.toJson();
    // Fast path: broadcast to all subscribed clients.
    await _channel!.sendBroadcastMessage(
      event: broadcastEvent,
      payload: <String, dynamic>{'packet': json},
    );
    // Durability path: best-effort insert for offline catch-up + oversight.
    try {
      await Supabase.instance.client.from('packets').insert(<String, dynamic>{
        'uuid': packet.uuid,
        'sender_id': packet.senderId,
        'destination_id': packet.destinationId,
        'priority': packet.priority.name,
        'ttl': packet.ttl,
        'hop_count': packet.hopCount,
        'payload': json,
        'created_at': packet.timestamp.toIso8601String(),
      });
    } catch (error) {
      // Non-fatal: the broadcast already went out. Insert may fail due to RLS
      // or a duplicate uuid (unique) — both are safe to ignore here.
      debugPrint('InternetTransport: durability insert skipped: $error');
    }
  }

  @override
  Future<void> dispose() async {
    try {
      final RealtimeChannel? channel = _channel;
      if (channel != null && _supabaseReady) {
        await Supabase.instance.client.removeChannel(channel);
      }
    } catch (_) {
      // ignore teardown errors
    }
    _channel = null;
    await _inboundController.close();
    await _statusController.close();
  }
}
