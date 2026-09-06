import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../iot/providers/mesh_manager_provider.dart';
import '../../messaging/data/manager/transport_manager_provider.dart';
import '../../messaging/data/transport/nearby_transport.dart';
import '../../messaging/models/mesh_packet.dart';
import '../../messaging/providers/nearby_chat_provider.dart';
import '../data/services/location_service.dart';
import '../data/services/sos_responder_sync.dart';
import '../models/responder.dart';
import 'resident_sos_notification_provider.dart';
import '../models/sos_packet.dart';
import '../models/sos_request.dart';
import 'location_provider.dart';
import 'responder_response_provider.dart';
import 'sos_provider.dart';

/// A tracked SOS as seen on this device, with its current lifecycle status.
class TrackedSos {
  const TrackedSos({
    required this.packet,
    required this.status,
    required this.updatedAt,
    this.responderName,
    this.responders = const <Responder>[],
    this.hopCount = 0,
    this.wasRelayed = false,
  });

  final SosPacket packet;
  final SosStatus status;
  final DateTime updatedAt;
  final String? responderName;

  /// All responders who have accepted this SOS. Multiple responders can respond
  /// to a single incident; this is the source of truth for who is responding.
  final List<Responder> responders;

  final int hopCount;
  final bool wasRelayed;

  String get sosId => packet.sosId;

  /// Convenience: a short summary of who is responding, for compact UI. Falls
  /// back to the legacy single [responderName] when the list is empty.
  String? get responderSummary {
    if (responders.isEmpty) return responderName;
    if (responders.length == 1) return responders.first.name;
    return '${responders.first.name} +${responders.length - 1} more';
  }

  int get responderCount => responders.length;

  bool get anyOnScene =>
      responders.any((Responder r) => r.state == ResponderState.onScene);

  TrackedSos copyWith({
    SosStatus? status,
    DateTime? updatedAt,
    String? responderName,
    List<Responder>? responders,
  }) {
    return TrackedSos(
      packet: packet,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      responderName: responderName ?? this.responderName,
      responders: responders ?? this.responders,
      hopCount: hopCount,
      wasRelayed: wasRelayed,
    );
  }
}

/// Receives SOS packets from the mesh and tracks their lifecycle, and lets
/// responders/officials acknowledge them (which broadcasts status updates back
/// across the mesh at emergency priority).
///
/// Status lifecycle: Sent -> Relayed -> Delivered -> Responder Accepted ->
/// Responder En Route -> Resolved.
class SosMeshController extends StateNotifier<List<TrackedSos>> {
  SosMeshController(this._ref) : super(<TrackedSos>[]) {
    _sub = _transport.incomingSos.listen(_onIncomingSos);
  }

  final Ref _ref;
  StreamSubscription<IncomingSos>? _sub;

  /// When this controller (app session) started. Used to distinguish live
  /// status updates from catch-up replays of pre-session packets, so stale
  /// acknowledgments don't re-raise notifications on restart.
  final DateTime _sessionStart = DateTime.now();

  NearbyTransport get _transport => _ref.read(nearbyTransportProvider);

  void _onIncomingSos(IncomingSos incoming) {
    final SosPacket sos = incoming.sos;

    // If this device's user dismissed this SOS, keep it hidden — later status
    // updates (from other responders, etc.) must not make it reappear on their
    // screen. The SOS stays active for everyone else.
    if (_locallyDismissed.contains(sos.sosId)) return;

    switch (sos.kind) {
      case SosPacketKind.alert:
        _upsertAlert(sos, incoming);
      case SosPacketKind.deliveryAck:
        _applyStatus(sos.sosId, SosStatus.delivered, sos.actorName,
            residentId: sos.residentId);
      case SosPacketKind.responderAck:
        _applyStatus(sos.sosId, SosStatus.responderAccepted, sos.actorName,
            residentId: sos.residentId);
        _upsertResponder(sos, ResponderState.accepted);
        _captureResponse(sos);
      case SosPacketKind.officialAck:
        _applyStatus(sos.sosId, SosStatus.delivered, sos.actorName,
            residentId: sos.residentId);
      case SosPacketKind.statusUpdate:
        if (sos.status == SosStatus.rejected) {
          // A single responder declining just dismisses the alert from their
          // own screen (handled locally in responderReject); a rejection packet
          // here is treated as informational. "No available responders" is
          // decided by the 5-minute timeout / empty pool, not by rejections.
          _handleRejection(sos);
        } else {
          _applyStatus(sos.sosId, sos.status, sos.actorName,
              residentId: sos.residentId);
          // Map the incoming status to this responder's per-SOS state so the
          // multi-responder list stays current.
          if (sos.status == SosStatus.responderEnRoute) {
            _upsertResponder(sos, ResponderState.enRoute);
          } else if (sos.status == SosStatus.arrived) {
            _upsertResponder(sos, ResponderState.onScene);
          }
          // Responder progress updates (en route / on-scene / resolved) also
          // refresh the resident's response card.
          if (sos.responseId != null || sos.actorRole != null) {
            _captureResponse(sos);
          }
        }
    }
  }

  /// Adds or updates a responder in an SOS's responder list, keyed by the
  /// responder's account id (actorId). Multiple responders accumulate; each
  /// responder's own state (accepted / en route / on scene) is tracked. Also
  /// persists the updated list to Supabase (best-effort) for cross-device truth.
  void _upsertResponder(SosPacket sos, ResponderState respState) {
    final String? actorId = sos.actorId;
    final String actorName = sos.actorName ?? 'Responder';
    if (actorId == null || actorId.isEmpty) return;

    // Always update the standalone responders map (so the resident — whose own
    // SOS may not be in sosMeshProvider — still sees the full stacking list).
    _mergeResponderIntoMap(
      sos.sosId,
      Responder(
        id: actorId,
        name: actorName,
        state: respState,
        latitude: sos.actorLat,
        longitude: sos.actorLng,
        updatedAt: DateTime.now(),
      ),
    );

    // If the SOS is also tracked in the mesh list (responder/official view),
    // mirror the list onto that TrackedSos too.
    final int idx = state.indexWhere((TrackedSos t) => t.sosId == sos.sosId);
    if (idx >= 0) {
      final TrackedSos tracked = state[idx];
      final List<TrackedSos> next = <TrackedSos>[...state];
      next[idx] = tracked.copyWith(
          responders: _ref.read(respondersBySosProvider)[sos.sosId]);
      state = next;
    }

    // Persist to Supabase (best-effort, non-blocking).
    unawaited(_ref.read(sosResponderSyncProvider).saveResponders(
        sos.sosId, _ref.read(respondersBySosProvider)[sos.sosId] ?? <Responder>[]));
  }

  /// Merges one responder into the standalone [respondersBySosProvider] map,
  /// keyed by SOS id and deduplicated by responder id.
  void _mergeResponderIntoMap(String sosId, Responder responder) {
    final Map<String, List<Responder>> map =
        <String, List<Responder>>{..._ref.read(respondersBySosProvider)};
    final List<Responder> list = <Responder>[...(map[sosId] ?? <Responder>[])];
    final int i = list.indexWhere((Responder r) => r.id == responder.id);
    if (i >= 0) {
      list[i] = list[i].copyWith(
        state: responder.state,
        latitude: responder.latitude,
        longitude: responder.longitude,
        updatedAt: responder.updatedAt,
      );
    } else {
      list.add(responder);
    }
    map[sosId] = list;
    _ref.read(respondersBySosProvider.notifier).state = map;
  }

  // Tracks the distinct responders who have rejected each SOS (keyed by SOS id),
  // used to decide when there are genuinely no responders available.
  final Map<String, Set<String>> _rejectionsBySos = <String, Set<String>>{};

  /// Handles a responder rejection for the resident who originated the SOS.
  /// Rejections are invisible individually; only when the number of distinct
  /// responders who rejected reaches the number of online responders do we tell
  /// the resident that no responder is available right now.
  void _handleRejection(SosPacket sos) {
    // Declines are now handled locally on each responder's device
    // (responderReject dismisses the alert for that user only). "No available
    // responders" is decided by the 5-minute global timeout in the resident's
    // SOS flow, not by counting rejections. This handler is retained as a safe
    // no-op for any legacy rejection packets still in flight.
    return;
  }

  /// Records a responder response for the resident's green response card, but
  /// only when it concerns one of this resident's own SOS requests.
  void _captureResponse(SosPacket sos) {
    try {
      // The responder-response card ("a responder accepted your SOS") is only
      // for the resident who ORIGINATED this SOS. The packet carries the
      // originator's account id (residentId), preserved through every ack, so
      // compare it against the current user directly. This is definitive and
      // does not depend on local log contents (which caused the card to leak
      // to other residents).
      final user = _ref.read(currentUserOrNullProvider);
      if (user == null) return;
      if (sos.residentId != user.id) return;

      // Once the incident is resolved (or the responder rejected/stood down),
      // dismiss the floating responder card instead of keeping it on screen.
      if (sos.status == SosStatus.resolved ||
          sos.status == SosStatus.rejected ||
          sos.status == SosStatus.cancelled) {
        _ref.read(responderResponseProvider.notifier).state = null;
        return;
      }
      _ref.read(responderResponseProvider.notifier).state =
          ResponderResponse.fromPacket(sos);
    } catch (_) {
      // Non-fatal.
    }
  }

  void _upsertAlert(SosPacket sos, IncomingSos incoming) {
    final int existing = state.indexWhere((TrackedSos t) => t.sosId == sos.sosId);

    // If we already have this SOS in a terminal state (resolved/rejected), a
    // re-delivered alert (e.g. from the catch-up fetch or a relayed copy) must
    // NOT downgrade it back to active/delivered. Keep the resolved state.
    if (existing >= 0) {
      final TrackedSos current = state[existing];
      if (current.status == SosStatus.resolved ||
          current.status == SosStatus.rejected ||
          current.status == SosStatus.cancelled) {
        return;
      }
    }

    // An alert that reached us has been delivered locally; if it was relayed on
    // the way, reflect that it travelled the mesh.
    final SosStatus status =
        incoming.wasRelayed ? SosStatus.relayed : SosStatus.delivered;
    final TrackedSos tracked = TrackedSos(
      packet: sos,
      status: status == SosStatus.relayed ? SosStatus.delivered : status,
      updatedAt: DateTime.now(),
      hopCount: incoming.hopCount,
      wasRelayed: incoming.wasRelayed,
    );
    if (existing >= 0) {
      final List<TrackedSos> next = <TrackedSos>[...state];
      next[existing] = tracked;
      state = next;
    } else {
      // Before treating this as a brand-new incident, check whether it is THIS
      // resident's OWN SOS that they have already resolved/cancelled. On app
      // restart, catch-up replays the original alert; without this guard we
      // would auto-send a delivery ack that flips the resident's resolved SOS
      // back to active. Skip entirely in that case.
      final user = _ref.read(currentUserOrNullProvider);
      if (user != null && sos.residentId == user.id) {
        final List<SosRequest> myLog = _ref.read(sosLogProvider);
        final bool alreadyTerminal = myLog.any((SosRequest r) =>
            r.id == sos.sosId &&
            (r.status == IncidentStatus.resolved ||
                r.status == IncidentStatus.cancelled));
        if (alreadyTerminal) return;
      }
      state = <TrackedSos>[tracked, ...state];
      // Acknowledge delivery back toward the resident.
      unawaited(_broadcast(sos, SosPacketKind.deliveryAck, SosStatus.delivered));
    }
  }

  void _applyStatus(String sosId, SosStatus status, String? actor,
      {String? residentId}) {
    state = <TrackedSos>[
      for (final TrackedSos t in state)
        if (t.sosId == sosId)
          // Never downgrade a terminal (resolved/rejected) incident back to an
          // earlier state. During catch-up replay, an older progress packet
          // (e.g. "arrived") can arrive after "resolved"; the resolution wins.
          (t.status == SosStatus.resolved ||
                      t.status == SosStatus.rejected ||
                      t.status == SosStatus.cancelled) &&
                  status != SosStatus.resolved &&
                  status != SosStatus.rejected &&
                  status != SosStatus.cancelled
              ? t
              : t.copyWith(
                  status: status,
                  updatedAt: DateTime.now(),
                  // Only overwrite the responder name when the incoming update
                  // actually names a responder. A resident-initiated resolve
                  // sends no actor, so we keep whoever was already assigned.
                  responderName: actor ?? t.responderName)
        else
          t,
    ];

    // Resident-facing side effects (the "your SOS" progress notification and
    // the resident's own SOS-log bridge) must only fire on the device of the
    // resident who ORIGINATED this SOS — otherwise a responder testing on the
    // same or another device sees resident notifications for their own actions.
    try {
      final user = _ref.read(currentUserOrNullProvider);
      final bool isOriginator =
          user != null && residentId != null && residentId == user.id;
      if (!isOriginator) return;

      _ref.read(sosLogProvider.notifier).applyMeshStatus(sosId, status, actor);

      // Only surface an in-app "your SOS" notification for LIVE updates. During
      // catch-up on app restart, old packets are replayed; we must not re-show
      // acknowledgments for SOS that are already resolved/cancelled, or for SOS
      // whose alert was created before this app session started (stale replays).
      final bool isTerminalStatus = status == SosStatus.resolved ||
          status == SosStatus.cancelled ||
          status == SosStatus.rejected;
      final int idx =
          state.indexWhere((TrackedSos t) => t.sosId == sosId);
      final bool sosIsTerminal =
          idx >= 0 && state[idx].status.isTerminal;
      // The SOS packet's creation time; if it predates this session, the update
      // is a catch-up replay and must not raise a fresh banner.
      final bool isStaleReplay =
          idx >= 0 && state[idx].packet.createdAt.isBefore(_sessionStart);
      if (isTerminalStatus || sosIsTerminal || isStaleReplay) return;

      _ref.read(residentSosNotificationProvider.notifier).state =
          SosStatusUpdate(
        sosId: sosId,
        status: status,
        actorName: actor,
        at: DateTime.now(),
      );
    } catch (_) {
      // Non-fatal.
    }
  }

  // --- Acknowledgements (responder / official actions) ----------------------

  Future<void> responderAccept(String sosId) =>
      _ackFor(sosId, SosPacketKind.responderAck, SosStatus.responderAccepted);

  /// A single responder declining just dismisses the alert from THEIR OWN
  /// screen. With multiple responders it must not cancel the SOS for everyone,
  /// and it must never register the dismisser as a responder on the resident's
  /// side. Dismiss is purely local: no packet is broadcast.
  Future<void> responderReject(String sosId) async {
    _locallyDismissed.add(sosId);
    state = <TrackedSos>[
      for (final TrackedSos t in state)
        if (t.sosId != sosId) t,
    ];
  }

  Future<void> responderEnRoute(String sosId) =>
      _ackFor(sosId, SosPacketKind.statusUpdate, SosStatus.responderEnRoute);

  /// Responder marks they have arrived on-scene. This broadcasts to the Command
  /// Center and the other responders (they receive the "arrived" status update).
  Future<void> responderOnScene(String sosId) =>
      _ackFor(sosId, SosPacketKind.statusUpdate, SosStatus.arrived);

  // Kept for backward compatibility with any existing callers.
  Future<void> responderArrived(String sosId) => responderOnScene(sosId);

  /// SOS ids this device's user has locally dismissed (declined). They are
  /// filtered out of this device's incoming list but remain active elsewhere.
  final Set<String> _locallyDismissed = <String>{};

  bool isLocallyDismissed(String sosId) => _locallyDismissed.contains(sosId);

  Future<void> officialAcknowledge(String sosId) =>
      _ackFor(sosId, SosPacketKind.officialAck, SosStatus.delivered);

  Future<void> resolve(String sosId) =>
      _ackFor(sosId, SosPacketKind.statusUpdate, SosStatus.resolved);

  Future<void> _ackFor(
    String sosId,
    SosPacketKind kind,
    SosStatus status,
  ) async {
    final int idx = state.indexWhere((TrackedSos t) => t.sosId == sosId);
    if (idx < 0) return;
    final TrackedSos tracked = state[idx];
    _applyStatus(sosId, status, _actorName());

    // When THIS device's user is the responder acting (accept / en route / on
    // scene), add/update themselves in the local responders list immediately —
    // otherwise their own card never reflects that they accepted (the list is
    // only built from INCOMING packets, which don't echo back to the sender).
    final ResponderState? selfState = switch (status) {
      SosStatus.responderAccepted => ResponderState.accepted,
      SosStatus.responderEnRoute => ResponderState.enRoute,
      SosStatus.arrived => ResponderState.onScene,
      _ => null,
    };
    if (selfState != null) {
      _upsertResponderSelf(sosId, selfState);
    }

    await _broadcast(tracked.packet, kind, status);
  }

  /// Adds/updates the CURRENT user as a responder on their own device (mirrors
  /// what other devices do when they receive this responder's packet).
  void _upsertResponderSelf(String sosId, ResponderState respState) {
    final user = _ref.read(currentUserOrNullProvider);
    if (user == null) return;

    _mergeResponderIntoMap(
      sosId,
      Responder(
        id: user.id,
        name: user.fullName,
        state: respState,
        updatedAt: DateTime.now(),
      ),
    );

    final int idx = state.indexWhere((TrackedSos t) => t.sosId == sosId);
    if (idx >= 0) {
      final TrackedSos tracked = state[idx];
      final List<TrackedSos> next = <TrackedSos>[...state];
      next[idx] = tracked.copyWith(
          responders: _ref.read(respondersBySosProvider)[sosId]);
      state = next;
    }

    unawaited(_ref.read(sosResponderSyncProvider).saveResponders(
        sosId, _ref.read(respondersBySosProvider)[sosId] ?? <Responder>[]));
  }

  String _actorName() {
    try {
      return _ref.read(currentUserProvider).fullName;
    } catch (_) {
      return 'Responder';
    }
  }

  Future<void> _broadcast(
    SosPacket base,
    SosPacketKind kind,
    SosStatus status,
  ) async {
    try {
      // Attach responder role and a dedicated response id so the resident can
      // render a distinct, attributable response event.
      UserRole? actorRole;
      String? responseId;
      String? actorId;
      double? actorLat;
      double? actorLng;
      try {
        final user = _ref.read(currentUserProvider);
        actorRole = user.role;
        actorId = user.id;
        responseId =
            'resp-${user.id}-${DateTime.now().millisecondsSinceEpoch}';
      } catch (_) {
        // No current user available; leave responder fields null.
      }

      // Capture the responder's current location so the resident can track
      // them. Non-blocking: if permission is denied or capture fails, the
      // acceptance still goes out with null location.
      try {
        final LocationResult loc =
            await _ref.read(locationServiceProvider).capture();
        if (loc.location != null) {
          actorLat = loc.location!.latitude;
          actorLng = loc.location!.longitude;
        }
      } catch (_) {
        // Location unavailable; proceed without it.
      }

      final SosPacket update = base.copyWith(
        kind: kind,
        status: status,
        actorName: _actorName(),
        actorId: actorId,
        actorRole: actorRole,
        responseId: responseId,
        actorLat: actorLat,
        actorLng: actorLng,
      );
      // Route over both mesh and internet via the transport manager, so the
      // SOS reaches responders/officials on other networks — not only devices
      // in physical mesh range. The mesh path is unchanged; the internet path
      // carries it through the Supabase gateway when connected.
      final MeshPacket packet = _transport.sosPacketFor(update);
      await _ref.read(transportManagerProvider).send(packet);
    } catch (error) {
      debugPrint('SOS ack broadcast failed: $error');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<SosMeshController, List<TrackedSos>>
    sosMeshProvider =
    StateNotifierProvider<SosMeshController, List<TrackedSos>>(
  (Ref ref) => SosMeshController(ref),
);

/// Incoming mesh SOS sorted for responders: highest priority first, then most
/// recent. Terminal (resolved/rejected) incidents sink to the bottom.
final Provider<List<TrackedSos>> sortedIncomingSosProvider =
    Provider<List<TrackedSos>>((Ref ref) {
  // A responder must never see (or be able to accept) their OWN SOS. Exclude any
  // incident this signed-in user originated, matched by the residentId carried
  // on the packet.
  final user = ref.watch(currentUserOrNullProvider);
  final String? myId = user?.id;
  final List<TrackedSos> all = <TrackedSos>[
    for (final TrackedSos t in ref.watch(sosMeshProvider))
      if (myId == null || t.packet.residentId != myId) t,
  ];
  all.sort((TrackedSos a, TrackedSos b) {
    // Active incidents before terminal ones.
    final bool aTerm = a.status.isTerminal;
    final bool bTerm = b.status.isTerminal;
    if (aTerm != bTerm) return aTerm ? 1 : -1;
    // Higher priority first (critical has the highest index).
    final int byPriority =
        b.packet.priority.index.compareTo(a.packet.priority.index);
    if (byPriority != 0) return byPriority;
    // Then most recent first.
    return b.packet.createdAt.compareTo(a.packet.createdAt);
  });
  return all;
});
