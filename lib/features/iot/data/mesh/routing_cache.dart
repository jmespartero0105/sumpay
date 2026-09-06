/// In-memory routing state for the mesh relay.
///
/// Holds two things:
///  - a set of recently seen packet UUIDs, so a node forwards each packet at
///    most once (duplicate detection / loop prevention), and
///  - a hint map of `destinationId -> endpointId`, recording which directly
///    connected neighbour a given device was last heard from, so unicast
///    traffic can be sent toward it instead of flooded blindly.
///
/// Entries expire so the cache cannot grow without bound during a long session.
class RoutingCache {
  RoutingCache({
    this.seenRetention = const Duration(minutes: 10),
    this.routeRetention = const Duration(minutes: 5),
    this.maxSeen = 2000,
  });

  /// How long a seen-UUID entry is remembered.
  final Duration seenRetention;

  /// How long a learned next-hop hint is trusted.
  final Duration routeRetention;

  /// Hard cap on remembered UUIDs, guarding memory on very busy meshes.
  final int maxSeen;

  final Map<String, DateTime> _seen = <String, DateTime>{};
  final Map<String, _RouteHint> _routes = <String, _RouteHint>{};

  /// Records [uuid] as seen. Returns `true` if it was already known (i.e. this
  /// is a duplicate that should NOT be processed or forwarded again).
  bool markSeen(String uuid) {
    _evictExpired();
    final bool duplicate = _seen.containsKey(uuid);
    _seen[uuid] = DateTime.now();
    if (_seen.length > maxSeen) {
      _trimSeen();
    }
    return duplicate;
  }

  /// Whether [uuid] has been seen recently, without recording it.
  bool hasSeen(String uuid) {
    final DateTime? at = _seen[uuid];
    if (at == null) return false;
    if (DateTime.now().difference(at) > seenRetention) {
      _seen.remove(uuid);
      return false;
    }
    return true;
  }

  /// Learns that [deviceId] is reachable via the directly connected
  /// [endpointId] (the neighbour we just received a packet from).
  void learnRoute(String deviceId, String endpointId) {
    _routes[deviceId] = _RouteHint(endpointId, DateTime.now());
  }

  /// Returns the last known next-hop endpoint for [deviceId], or `null` if
  /// unknown or expired.
  String? nextHopFor(String deviceId) {
    final _RouteHint? hint = _routes[deviceId];
    if (hint == null) return null;
    if (DateTime.now().difference(hint.learnedAt) > routeRetention) {
      _routes.remove(deviceId);
      return null;
    }
    return hint.endpointId;
  }

  /// Drops route hints that point at an endpoint that has disconnected.
  void forgetEndpoint(String endpointId) {
    _routes.removeWhere(
      (String _, _RouteHint hint) => hint.endpointId == endpointId,
    );
  }

  /// Number of live route hints (diagnostics).
  int get knownRoutes => _routes.length;

  /// Number of remembered packet UUIDs (diagnostics).
  int get seenCount => _seen.length;

  void clear() {
    _seen.clear();
    _routes.clear();
  }

  void _evictExpired() {
    final DateTime now = DateTime.now();
    _seen.removeWhere(
      (String _, DateTime at) => now.difference(at) > seenRetention,
    );
    _routes.removeWhere(
      (String _, _RouteHint hint) =>
          now.difference(hint.learnedAt) > routeRetention,
    );
  }

  void _trimSeen() {
    // Remove the oldest entries until back under the cap.
    final List<MapEntry<String, DateTime>> entries = _seen.entries.toList()
      ..sort((MapEntry<String, DateTime> a, MapEntry<String, DateTime> b) =>
          a.value.compareTo(b.value));
    final int removeCount = _seen.length - maxSeen;
    for (int i = 0; i < removeCount; i++) {
      _seen.remove(entries[i].key);
    }
  }
}

class _RouteHint {
  const _RouteHint(this.endpointId, this.learnedAt);

  final String endpointId;
  final DateTime learnedAt;
}
