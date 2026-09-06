import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/nearby_device.dart';
import '../../models/mesh_manager_state.dart';

/// SUMPAY's Nearby Connections service id. Only devices advertising this exact
/// id are treated as SUMPAY peers and considered for connection.
const String kSumpayServiceId = 'com.sumpay.app';

/// Filters discovered peers down to genuine SUMPAY devices.
///
/// Discovery already runs on a SUMPAY service id, but this manager double-checks
/// each peer's advertised service id so a stray endpoint can never be connected
/// to by mistake.
class DiscoveryManager {
  const DiscoveryManager();

  /// Whether [device] is advertising the SUMPAY service.
  bool isSumpayPeer(NearbyDevice device) =>
      device.serviceId == kSumpayServiceId;

  /// The subset of [devices] that are SUMPAY peers not yet connected.
  List<NearbyDevice> connectable(List<NearbyDevice> devices) => devices
      .where((NearbyDevice d) => isSumpayPeer(d) && !d.isConnected && !d.isBusy)
      .toList(growable: false);
}

/// Decides which discovered peers to connect to and handles retry/backoff.
///
/// Responsibilities:
/// - prevent duplicate connections (never dial an endpoint already connected,
///   pending, or currently being retried),
/// - enforce a maximum number of simultaneous connections,
/// - retry failed connections with capped exponential backoff,
/// - drive automatic reconnection when a link drops.
class ConnectionManager {
  ConnectionManager({
    required Future<void> Function(String endpointId) connect,
    this.maxConnections = 8,
    this.maxRetries = 4,
  }) : _connect = connect;

  final Future<void> Function(String endpointId) _connect;
  final int maxConnections;
  final int maxRetries;

  /// Endpoints we are currently dialing, so we never dial the same one twice.
  final Set<String> _inFlight = <String>{};

  /// Retry counters per endpoint.
  final Map<String, int> _retries = <String, int>{};

  /// Pending backoff timers per endpoint.
  final Map<String, Timer> _timers = <String, Timer>{};

  /// For jittered backoff, to de-synchronise simultaneous reconnect attempts.
  final Random _random = Random();

  /// Attempts to connect to [candidates] without exceeding [maxConnections].
  ///
  /// [connectedCount] is the number of links already established. Duplicate and
  /// in-flight endpoints are skipped.
  Future<void> reconcile({
    required List<NearbyDevice> candidates,
    required int connectedCount,
    required Set<String> connectedIds,
  }) async {
    int budget = maxConnections - connectedCount;
    if (budget <= 0) return;

    for (final NearbyDevice device in candidates) {
      if (budget <= 0) break;
      final String id = device.endpointId;
      if (connectedIds.contains(id)) continue; // already connected
      if (_inFlight.contains(id)) continue; // already dialing
      if (_timers.containsKey(id)) continue; // waiting on a backoff retry

      budget--;
      await _dial(id);
    }
  }

  Future<void> _dial(String id) async {
    _inFlight.add(id);
    try {
      await _connect(id);
      _retries.remove(id);
    } catch (error) {
      debugPrint('ConnectionManager: connect to $id failed: $error');
      _scheduleRetry(id);
    } finally {
      _inFlight.remove(id);
    }
  }

  void _scheduleRetry(String id) {
    final int attempt = (_retries[id] ?? 0) + 1;
    if (attempt > maxRetries) {
      _retries.remove(id);
      return;
    }
    _retries[id] = attempt;
    // Capped exponential backoff with jitter. Jitter is important: when two
    // devices discover each other simultaneously they can collide on
    // requestConnection (STATUS_ENDPOINT_IO_ERROR, 8012); differing retry delays
    // break the symmetry so one side connects cleanly.
    final int base = (1 << (attempt - 1)).clamp(1, 15);
    final int jitterMs = _random.nextInt(1000);
    _timers[id]?.cancel();
    _timers[id] = Timer(
      Duration(milliseconds: base * 1000 + jitterMs),
      () {
        _timers.remove(id);
        // Actually re-attempt the connection, unless we connected meanwhile.
        if (!_inFlight.contains(id)) {
          unawaited(_dial(id));
        }
      },
    );
  }

  /// Called when an endpoint disconnects, so it becomes eligible to redial.
  void onDisconnected(String id) {
    _inFlight.remove(id);
    _timers[id]?.cancel();
    _timers.remove(id);
    _retries.remove(id);
  }

  void dispose() {
    for (final Timer t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }
}

/// Periodically pings connected peers to measure link liveness and latency.
///
/// Each tick updates [LinkHealth] for every connected endpoint. Because Nearby
/// Connections gives no radio signal metric, round-trip time is used as an
/// honest proxy for connection quality, and consecutive missed beats mark a
/// link as dead so the [ConnectionManager] can reconnect.
class HeartbeatMonitor {
  HeartbeatMonitor({
    this.interval = const Duration(seconds: 5),
    this.deadAfterMissed = 3,
  });

  final Duration interval;
  final int deadAfterMissed;

  Timer? _timer;
  final Map<String, LinkHealth> _health = <String, LinkHealth>{};
  final Map<String, DateTime> _pendingPings = <String, DateTime>{};

  Map<String, LinkHealth> get health => Map<String, LinkHealth>.unmodifiable(_health);

  /// Starts the periodic heartbeat. [onTick] is invoked with the connected
  /// endpoint ids each interval so the caller can send pings; [onHealthUpdated]
  /// is invoked whenever health changes.
  void start({
    required List<String> Function() connectedIds,
    required void Function(String endpointId) sendPing,
    required void Function(Map<String, LinkHealth> health) onHealthUpdated,
  }) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      final List<String> ids = connectedIds();
      bool changed = false;

      // Drop health for endpoints no longer connected.
      final int before = _health.length;
      _health.removeWhere((String id, _) => !ids.contains(id));
      if (_health.length != before) changed = true;

      for (final String id in ids) {
        // If a previous ping was never answered, count a missed beat.
        if (_pendingPings.containsKey(id)) {
          final LinkHealth current =
              _health[id] ?? LinkHealth(endpointId: id);
          _health[id] =
              current.copyWith(missedBeats: current.missedBeats + 1);
          changed = true;
        }
        if (!_health.containsKey(id)) {
          _health[id] = LinkHealth(endpointId: id);
          changed = true;
        }
        _pendingPings[id] = DateTime.now();
        sendPing(id);
      }

      // Only notify when something actually changed, so state is not churned
      // every tick when links are steady.
      if (changed) onHealthUpdated(health);
    });
  }

  /// Records a heartbeat acknowledgement from [endpointId], updating latency.
  void onPong(String endpointId) {
    final DateTime? sentAt = _pendingPings.remove(endpointId);
    final int? rtt =
        sentAt == null ? null : DateTime.now().difference(sentAt).inMilliseconds;
    final LinkHealth current =
        _health[endpointId] ?? LinkHealth(endpointId: endpointId);
    _health[endpointId] = current.copyWith(
      lastRttMs: rtt,
      lastHeartbeatAt: DateTime.now(),
      missedBeats: 0,
    );
  }

  /// Endpoints considered dead (too many consecutive missed beats).
  List<String> deadLinks() => _health.values
      .where((LinkHealth h) => h.missedBeats >= deadAfterMissed)
      .map((LinkHealth h) => h.endpointId)
      .toList(growable: false);

  void forget(String endpointId) {
    _health.remove(endpointId);
    _pendingPings.remove(endpointId);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _pendingPings.clear();
  }
}
