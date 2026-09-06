import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../iot/providers/packet_reliability_provider.dart';
import '../../messaging/data/transport/nearby_transport.dart';
import '../../messaging/models/mesh_packet.dart';
import '../../messaging/providers/nearby_chat_provider.dart';
import '../data/repositories/sos_repository.dart';
import '../data/repositories/sos_store.dart';
import '../data/services/sos_history_service.dart';
import '../models/sos_location_model.dart';
import '../models/sos_packet.dart';
import '../models/sos_request.dart';
import 'resident_sos_notification_provider.dart';
import 'responder_response_provider.dart';

/// Builds and submits the SOS draft.
class SosDraftController extends StateNotifier<SosDraft> {
  SosDraftController() : super(const SosDraft());

  /// Select/deselect a type. First selected becomes main by default; the
  /// resident can change the main via [setMainType]. Tapping the main while
  /// extras remain promotes the first extra to main.
  void toggleType(EmergencyType type) {
    final SosDraft d = state;

    // Nothing selected yet -> this becomes the main.
    if (d.type == null) {
      state = d.copyWith(type: type, priority: type.defaultPriority);
      return;
    }

    final bool isMain = d.type == type;
    final bool isAdditional = d.additionalTypes.contains(type);

    // Newly selected -> add as an additional category (main stays as-is).
    if (!isMain && !isAdditional) {
      state = d.copyWith(
        additionalTypes: <EmergencyType>[...d.additionalTypes, type],
      );
      return;
    }

    // Deselect an additional category.
    if (isAdditional) {
      state = d.copyWith(
        additionalTypes:
            d.additionalTypes.where((EmergencyType t) => t != type).toList(),
      );
      return;
    }

    // Tapped the MAIN type -> deselect it.
    if (d.additionalTypes.isEmpty) {
      // No extras -> clear selection entirely (back to nothing selected).
      state = d.copyWith(clearType: true);
      return;
    }
    // Promote the first extra to main.
    final EmergencyType newMain = d.additionalTypes.first;
    state = d.copyWith(
      type: newMain,
      additionalTypes: d.additionalTypes.skip(1).toList(),
      priority: newMain.defaultPriority,
    );
  }

  /// Explicitly set which selected type is the main emergency. The previous main
  /// is demoted into the additional list; [type] must already be selected.
  void setMainType(EmergencyType type) {
    final SosDraft d = state;
    final EmergencyType? currentMain = d.type;
    if (currentMain == null) return; // nothing selected yet
    if (currentMain == type) return; // already main
    if (!d.additionalTypes.contains(type)) return; // not selected
    state = d.copyWith(
      type: type,
      additionalTypes: <EmergencyType>[
        currentMain,
        ...d.additionalTypes.where((EmergencyType t) => t != type),
      ],
      priority: type.defaultPriority,
    );
  }

  void setType(EmergencyType type) => state = state.copyWith(
        type: type,
        // Priority is predefined per category; residents never choose it.
        priority: type.defaultPriority,
      );

  void setPriority(PriorityLevel priority) =>
      state = state.copyWith(priority: priority);

  void setDescription(String value) =>
      state = state.copyWith(description: value);

  void setPeopleAffected(int value) =>
      state = state.copyWith(peopleAffected: value.clamp(1, 99));

  void toggleMedicalSharing(bool value) =>
      state = state.copyWith(shareMedicalProfile: value);

  void reset() => state = const SosDraft();
}

final StateNotifierProvider<SosDraftController, SosDraft> sosDraftProvider =
    StateNotifierProvider<SosDraftController, SosDraft>(
  (Ref ref) => SosDraftController(),
);

/// Repository of SOS records with SQLite-backed submission.
class SosLogController extends StateNotifier<List<SosRequest>> {
  SosLogController(SosRepository repository, this._store, this._ref)
      : super(repository.seed) {
    _restore();
  }

  final SosStore _store;
  final Ref _ref;
  final SosHistoryService _history = const SosHistoryService();

  /// Loads persisted SOS history and merges it ahead of the seed data. When the
  /// resident is signed in and online, also pulls their history from Supabase so
  /// it appears even on a device where the SOS was never created locally.
  Future<void> _restore() async {
    try {
      final List<SosRequest> stored = await _store.loadAll();
      final Set<String> storedIds = stored.map((SosRequest r) => r.id).toSet();
      if (stored.isNotEmpty) {
        // Persisted records take precedence; keep seed items not already stored.
        state = <SosRequest>[
          ...stored,
          ...state.where((SosRequest r) => !storedIds.contains(r.id)),
        ];
      }
      // Pull this resident's history from the backend (best-effort) and merge.
      // The backend is the source of truth for the LATEST status: if a SOS was
      // resolved/cancelled on another device (or its resolution synced but the
      // local copy is stale), the remote record must win. We merge by id,
      // preferring the remote status when it is terminal or the local copy is
      // still active.
      final String residentId = _currentResidentId();
      if (residentId.isNotEmpty) {
        final List<SosRequest> remote =
            await _history.fetchForResident(residentId);
        if (remote.isNotEmpty) {
          final Map<String, SosRequest> byId = <String, SosRequest>{
            for (final SosRequest r in state) r.id: r,
          };
          for (final SosRequest rem in remote) {
            final SosRequest? local = byId[rem.id];
            if (local == null) {
              byId[rem.id] = rem;
            } else {
              // Prefer whichever is terminal; if the remote is terminal and the
              // local is still active/responding, take the remote (resolution
              // that happened elsewhere). Otherwise keep local.
              final bool remoteTerminal =
                  rem.status == IncidentStatus.resolved ||
                      rem.status == IncidentStatus.cancelled;
              final bool localActive =
                  local.status == IncidentStatus.active ||
                      local.status == IncidentStatus.responding;
              if (remoteTerminal && localActive) {
                byId[rem.id] = rem;
                unawaited(_store.update(rem));
              }
            }
          }
          final List<SosRequest> merged = byId.values.toList()
            ..sort((SosRequest a, SosRequest b) =>
                b.createdAt.compareTo(a.createdAt));
          state = merged;
        }
      }
    } catch (_) {
      // Non-fatal: fall back to seed data already in state.
    }
  }

  /// The signed-in resident's account id, or empty when not available.
  String _currentResidentId() {
    try {
      return _ref.read(currentUserProvider).id;
    } catch (_) {
      return '';
    }
  }

  /// Resolves the resident id to file a record under: the record's own
  /// requesterId when present, otherwise the signed-in resident.
  String _residentIdFor(SosRequest r) {
    if (r.requesterId.isNotEmpty) return r.requesterId;
    return _currentResidentId();
  }

  /// Converts a draft into a transmitted request, persists it (with any
  /// captured location), and prepends it to the log.
  SosRequest submit(
    SosDraft draft, {
    required String requesterName,
    String requesterId = '',
    SosLocationModel? location,
    String? locationLabel,
  }) {
    // Globally-unique id: combine the sender's account id with the full
    // millisecond timestamp so two residents can never collide (the old
    // `% 1000000` truncation cycled every ~16 minutes and let a different
    // resident's ack match this device's SOS).
    final String uniqueSuffix = requesterId.isEmpty
        ? '${DateTime.now().microsecondsSinceEpoch}'
        : '$requesterId-${DateTime.now().millisecondsSinceEpoch}';
    final SosRequest request = SosRequest(
      id: 'SOS-$uniqueSuffix',
      type: draft.type ?? EmergencyType.medical,
      additionalTypes: draft.additionalTypes,
      priority: draft.priority,
      description: draft.description.trim().isEmpty
          ? 'No additional details provided.'
          : draft.description.trim(),
      locationLabel: locationLabel?.isNotEmpty == true
          ? locationLabel!
          : draft.locationLabel,
      latitude: location?.latitude ?? draft.latitude,
      longitude: location?.longitude ?? draft.longitude,
      createdAt: DateTime.now(),
      status: IncidentStatus.active,
      delivery: DeliveryStatus.sending,
      hopCount: 2,
      peopleAffected: draft.peopleAffected,
      requesterName: requesterName,
      requesterId: requesterId,
      accuracy: location?.accuracy,
      locationCapturedAt: location?.capturedAt,
    );

    state = <SosRequest>[request, ...state];
    _store.save(request);
    unawaited(_history.upsert(request, requesterId));
    _transmit(request, requesterName, location);
    _startNoResponderTimeout(request.id);
    return request;
  }

  /// Global "no available responders" timeout. If no responder accepts within
  /// this window, the resident is told there are no responders available (their
  /// SOS stays active). Replaces the older "all responders rejected" rule, which
  /// no longer applies now that a decline only dismisses locally.
  static const Duration kNoResponderTimeout = Duration(minutes: 5);
  final Map<String, Timer> _noResponderTimers = <String, Timer>{};

  void _startNoResponderTimeout(String sosId) {
    _noResponderTimers[sosId]?.cancel();
    _noResponderTimers[sosId] = Timer(kNoResponderTimeout, () {
      _noResponderTimers.remove(sosId);
      // Only fire if the SOS is still active and unaccepted.
      final int idx = state.indexWhere((SosRequest r) => r.id == sosId);
      if (idx < 0) return;
      final SosRequest r = state[idx];
      if (r.status == IncidentStatus.active &&
          (r.respondingUnit == null || r.respondingUnit!.isEmpty)) {
        try {
          _ref.read(residentSosNotificationProvider.notifier).state =
              SosStatusUpdate(
            sosId: sosId,
            status: SosStatus.rejected,
            actorName: null,
            at: DateTime.now(),
          );
        } catch (_) {
          // Non-fatal.
        }
      }
    });
  }

  void _cancelNoResponderTimeout(String sosId) {
    _noResponderTimers[sosId]?.cancel();
    _noResponderTimers.remove(sosId);
  }

  @override
  void dispose() {
    for (final Timer t in _noResponderTimers.values) {
      t.cancel();
    }
    _noResponderTimers.clear();
    super.dispose();
  }

  /// Sends the SOS across the mesh at emergency priority, through the
  /// reliability layer (queue + retry + offline resend). SOS always uses a
  /// high/critical priority, so it outranks normal messages.
  void _transmit(
    SosRequest request,
    String requesterName,
    SosLocationModel? location,
  ) {
    try {
      final NearbyTransport transport = _ref.read(nearbyTransportProvider);
      final String residentId = _ref.read(currentUserProvider).id;
      final SosPacket sos = SosPacket(
        kind: SosPacketKind.alert,
        sosId: request.id,
        residentId: residentId,
        residentName: requesterName,
        emergencyType: request.type,
        additionalTypes: request.additionalTypes,
        priority: request.priority,
        status: SosStatus.sent,
        createdAt: request.createdAt,
        note: request.description,
        locationLabel: request.locationLabel,
        latitude: location?.latitude ?? request.latitude,
        longitude: location?.longitude ?? request.longitude,
        accuracy: location?.accuracy,
      );
      final MeshPacket packet = MeshPacket.origin(
        senderId: residentId,
        destinationId: kMeshBroadcastDestination,
        payload: sos.encode(),
        priority: request.priority,
        transport: LinkMode.mesh,
      );
      // Route through the reliability layer for queue/retry/offline resend.
      unawaited(
          _ref.read(packetReliabilityProvider.notifier).enqueue(packet));
    } catch (error) {
      debugPrint('SOS transmit failed: $error');
    }
  }

  /// Advances the delivery indicator to mimic mesh acknowledgement.
  void markDelivered(String id) {
    state = state.map((SosRequest r) {
      if (r.id != id) return r;
      // Delivery only means the SOS reached the network — it does NOT mean a
      // responder accepted. Do not set a responding unit or flip to
      // "responding" here, or the resident would get a false sense that help is
      // already on the way. The status only advances when a real responder
      // accepts (applyStatusUpdate).
      final SosRequest updated = r.copyWith(
        delivery: DeliveryStatus.delivered,
      );
      _store.update(updated);
      unawaited(_history.upsert(updated, _residentIdFor(updated)));
      return updated;
    }).toList();
  }

  void cancel(String id) {
    SosRequest? cancelled;
    state = state.map((SosRequest r) {
      if (r.id != id) return r;
      final SosRequest updated =
          r.copyWith(status: IncidentStatus.cancelled);
      _store.update(updated);
      unawaited(_history.upsert(updated, _residentIdFor(updated)));
      cancelled = updated;
      return updated;
    }).toList();
    // Notify the barangay/responders so the incident shows cancelled on their
    // side too, and clear the resident's floating responder card.
    if (cancelled != null) {
      _cancelNoResponderTimeout(id);
      _transmitStatus(cancelled!, SosStatus.cancelled);
    }
    _ref.read(responderResponseProvider.notifier).state = null;
  }

  /// The resident marks their OWN emergency as fully resolved. Only the
  /// resident can do this — a responder may have arrived, but the resident is
  /// the one who confirms the situation is actually over. This updates local
  /// state and broadcasts the resolved status so responders/officials see it.
  void resolve(String id) {
    SosRequest? resolved;
    state = state.map((SosRequest r) {
      if (r.id != id) return r;
      final SosRequest updated =
          r.copyWith(status: IncidentStatus.resolved);
      _store.update(updated);
      unawaited(_history.upsert(updated, _residentIdFor(updated)));
      resolved = updated;
      return updated;
    }).toList();
    if (resolved != null) {
      _cancelNoResponderTimeout(id);
      _transmitStatus(resolved!, SosStatus.resolved);
    }
    // Dismiss the floating responder-progress card on the resident's own device
    // — resolving locally does not round-trip a packet back to us, so clear it
    // here.
    _ref.read(responderResponseProvider.notifier).state = null;
  }

  /// Broadcasts a status change for one of the resident's own SOS across the
  /// mesh + internet, so responders and officials receive the update.
  void _transmitStatus(SosRequest request, SosStatus status) {
    try {
      final String residentId = _ref.read(currentUserProvider).id;
      final SosPacket sos = SosPacket(
        kind: SosPacketKind.statusUpdate,
        sosId: request.id,
        residentId: residentId,
        residentName: request.requesterName,
        emergencyType: request.type,
        additionalTypes: request.additionalTypes,
        priority: request.priority,
        status: status,
        createdAt: request.createdAt,
        note: request.description,
        latitude: request.latitude,
        longitude: request.longitude,
        // The resident is not a responder — do not send their name as the
        // acting party, or the official/responder views would show the
        // resident's name in the "Responder" column. Preserve any responder
        // already assigned to the incident instead.
        actorName: request.respondingUnit,
      );
      final MeshPacket packet = MeshPacket.origin(
        senderId: residentId,
        destinationId: kMeshBroadcastDestination,
        payload: sos.encode(),
        priority: request.priority,
        transport: LinkMode.mesh,
      );
      unawaited(
          _ref.read(packetReliabilityProvider.notifier).enqueue(packet));
    } catch (error) {
      debugPrint('SOS status transmit failed: $error');
    }
  }

  /// Applies a status update that arrived over the mesh (from a responder or
  /// official) to the resident's own SOS, so the resident sees live progress.
  /// Records a human-readable note for the in-app notification.
  void applyMeshStatus(String sosId, SosStatus status, String? actorName) {
    // A responder has engaged (accepted / en route / on scene) — cancel the
    // no-responder timeout so the resident is never wrongly told nobody came.
    if (status == SosStatus.responderAccepted ||
        status == SosStatus.responderEnRoute ||
        status == SosStatus.arrived) {
      _cancelNoResponderTimeout(sosId);
    }
    final IncidentStatus incident = switch (status) {
      SosStatus.resolved => IncidentStatus.resolved,
      SosStatus.cancelled => IncidentStatus.cancelled,
      SosStatus.rejected => IncidentStatus.active,
      SosStatus.responderAccepted ||
      SosStatus.responderEnRoute ||
      SosStatus.arrived =>
        IncidentStatus.responding,
      _ => IncidentStatus.active,
    };
    bool matched = false;
    bool updatedNonTerminal = false;
    state = state.map((SosRequest r) {
      if (r.id != sosId) return r;
      // NEVER downgrade a terminal incident. Once the resident has resolved or
      // cancelled their SOS, a replayed old packet (e.g. the original alert or a
      // delivery ack coming back through catch-up on app restart) must NOT flip
      // it back to active/responding — and must not be re-persisted. This is the
      // root cause of "resolved SOS shows active again after restart".
      if (r.status == IncidentStatus.resolved ||
          r.status == IncidentStatus.cancelled) {
        matched = true;
        return r;
      }
      matched = true;
      updatedNonTerminal = true;
      // Only a genuine responder action (accepted / en route / on scene) names
      // a responding unit. Delivery acks and official acks also carry an
      // actorName (the relaying device / official), but they must NOT populate
      // respondingUnit, or the resident sees a "responder" before anyone
      // actually accepted.
      final bool isResponderAction =
          status == SosStatus.responderAccepted ||
              status == SosStatus.responderEnRoute ||
              status == SosStatus.arrived;
      final SosRequest updated = r.copyWith(
        status: incident,
        respondingUnit:
            isResponderAction ? (actorName ?? r.respondingUnit) : r.respondingUnit,
      );
      _store.update(updated);
      unawaited(_history.upsert(updated, _residentIdFor(updated)));
      return updated;
    }).toList();
    if (matched && updatedNonTerminal) {
      _lastUpdate = SosStatusUpdate(
        sosId: sosId,
        status: status,
        actorName: actorName,
        at: DateTime.now(),
      );
    }
  }

  /// The most recent mesh status update for one of this resident's SOS, for the
  /// UI to surface as a notification. Null until one arrives.
  SosStatusUpdate? _lastUpdate;
  SosStatusUpdate? get lastUpdate => _lastUpdate;

  void clearLastUpdate() => _lastUpdate = null;
}

final StateNotifierProvider<SosLogController, List<SosRequest>> sosLogProvider =
    StateNotifierProvider<SosLogController, List<SosRequest>>(
  (Ref ref) => SosLogController(
    ref.watch(sosRepositoryProvider),
    ref.watch(sosStoreProvider),
    ref,
  ),
);

/// Currently unresolved incidents, newest first.
final Provider<List<SosRequest>> activeIncidentsProvider =
    Provider<List<SosRequest>>((Ref ref) {
  return ref
      .watch(sosLogProvider)
      .where((SosRequest r) =>
          r.status == IncidentStatus.active ||
          r.status == IncidentStatus.responding)
      .toList();
});

/// The most recently submitted request, used by the confirmation screen.
final Provider<SosRequest?> latestSosProvider =
    Provider<SosRequest?>((Ref ref) {
  final List<SosRequest> log = ref.watch(sosLogProvider);
  return log.isEmpty ? null : log.first;
});
