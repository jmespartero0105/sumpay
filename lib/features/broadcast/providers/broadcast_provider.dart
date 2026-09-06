import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../messaging/data/transport/nearby_transport.dart';
import '../../messaging/providers/nearby_chat_provider.dart';
import '../data/repositories/broadcast_repository.dart';
import '../models/broadcast_models.dart';
import '../models/broadcast_packet.dart';

/// Stores published broadcasts and transmits/receives them across the network.
///
/// Publishing an official broadcast sends it over the mesh + internet gateway
/// (via [NearbyTransport.sendBroadcast]), and incoming broadcasts from other
/// devices are surfaced into the same feed — so residents actually receive the
/// evacuation notices and emergency alerts officials issue.
class BroadcastController extends StateNotifier<List<BroadcastMessage>> {
  BroadcastController(this._ref, BroadcastRepository repository)
      : super(repository.seed) {
    _listen();
  }

  final Ref _ref;
  StreamSubscription<BroadcastPacket>? _sub;
  StreamSubscription<BroadcastAckPacket>? _ackSub;

  // Per-broadcast set of device ids that have acknowledged delivery, so reach
  // counts each device once even if its ack is relayed multiple times.
  final Map<String, Set<String>> _reachByBroadcast = <String, Set<String>>{};

  NearbyTransport get _transport => _ref.read(nearbyTransportProvider);

  void _listen() {
    _sub = _transport.incomingBroadcast.listen(_onIncoming);
    _ackSub = _transport.incomingBroadcastAck.listen(_onIncomingAck);
  }

  /// Adds a broadcast received from the network to the feed (newest first),
  /// ignoring duplicates already seen (e.g. relayed copies). Also sends a
  /// delivery acknowledgement back so the issuing official can count reach.
  void _onIncoming(BroadcastPacket packet) {
    if (state.any((BroadcastMessage m) => m.id == packet.id)) return;
    state = _sorted(<BroadcastMessage>[packet.toMessage(), ...state]);
    // Acknowledge delivery back to the network (best-effort).
    unawaited(_transport.sendBroadcastAck(BroadcastAckPacket(
      broadcastId: packet.id,
      deviceId: _transport.localDeviceId,
    )));
  }

  /// Records a delivery acknowledgement and updates the broadcast's reach count
  /// with the number of unique devices that received it.
  void _onIncomingAck(BroadcastAckPacket ack) {
    final Set<String> devices =
        _reachByBroadcast.putIfAbsent(ack.broadcastId, () => <String>{});
    final bool added = devices.add(ack.deviceId);
    if (!added) return; // already counted this device
    state = <BroadcastMessage>[
      for (final BroadcastMessage m in state)
        if (m.id == ack.broadcastId) m.copyWith(reach: devices.length) else m,
    ];
  }

  /// Publishes a draft as a new broadcast: adds it to the local feed and
  /// transmits it to every device on the network.
  BroadcastMessage publish(BroadcastDraft draft, {required String issuedBy}) {
    final BroadcastMessage message = BroadcastMessage(
      id: 'BRD-${DateTime.now().millisecondsSinceEpoch}',
      title: draft.title.trim(),
      body: draft.body.trim(),
      severity: draft.severity,
      issuedBy: issuedBy,
      issuedAt: DateTime.now(),
      reach: 0,
      acknowledged: 0,
      transport: LinkMode.mesh,
      areas: draft.areas,
      isPinned: draft.severity == BroadcastSeverity.alert,
    );

    state = _sorted(<BroadcastMessage>[message, ...state]);
    // Transmit over mesh + internet. Fire-and-forget; delivery is best-effort.
    unawaited(_transport.sendBroadcast(BroadcastPacket.fromMessage(message)));
    return message;
  }

  /// Marks a broadcast inactive (the official's "delete / make inactive"
  /// action). It stays in the list as a record but is unpinned and sorted to
  /// the bottom, and no longer counts as an active alert.
  void deactivate(String id) {
    state = _sorted(<BroadcastMessage>[
      for (final BroadcastMessage m in state)
        if (m.id == id) m.copyWith(isActive: false, isPinned: false) else m,
    ]);
  }

  /// Sort order: active high-priority pinned alerts first (always on top while
  /// active), then other active broadcasts newest-first, then inactive ones.
  List<BroadcastMessage> _sorted(List<BroadcastMessage> items) {
    final List<BroadcastMessage> copy = <BroadcastMessage>[...items];
    copy.sort((BroadcastMessage a, BroadcastMessage b) {
      // Inactive always sinks below active.
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      // Among active, pinned high-priority alerts rise to the top.
      final bool aPin = a.isActive && a.isPinned;
      final bool bPin = b.isActive && b.isPinned;
      if (aPin != bPin) return aPin ? -1 : 1;
      // Otherwise newest first.
      return b.issuedAt.compareTo(a.issuedAt);
    });
    return copy;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ackSub?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<BroadcastController, List<BroadcastMessage>>
    broadcastsProvider =
    StateNotifierProvider<BroadcastController, List<BroadcastMessage>>(
  (Ref ref) =>
      BroadcastController(ref, ref.watch(broadcastRepositoryProvider)),
);

/// The newest broadcast, surfaced on the home dashboard.
final Provider<BroadcastMessage?> latestBroadcastProvider =
    Provider<BroadcastMessage?>((Ref ref) {
  final List<BroadcastMessage> all = ref.watch(broadcastsProvider);
  return all.isEmpty ? null : all.first;
});

/// Draft state for the official composer.
class BroadcastDraftController extends StateNotifier<BroadcastDraft> {
  BroadcastDraftController() : super(const BroadcastDraft());

  void setTitle(String value) => state = state.copyWith(title: value);

  void setBody(String value) => state = state.copyWith(body: value);

  void setSeverity(BroadcastSeverity value) =>
      state = state.copyWith(severity: value);

  void toggleArea(String area) {
    final List<String> next = List<String>.from(state.areas);
    if (area == 'All Puroks') {
      state = state.copyWith(areas: <String>['All Puroks']);
      return;
    }
    next.remove('All Puroks');
    if (next.contains(area)) {
      next.remove(area);
    } else {
      next.add(area);
    }
    state = state.copyWith(
      areas: next.isEmpty ? <String>['All Puroks'] : next,
    );
  }

  void toggleAcknowledgement(bool value) =>
      state = state.copyWith(requireAcknowledgement: value);

  void reset() => state = const BroadcastDraft();
}

final StateNotifierProvider<BroadcastDraftController, BroadcastDraft>
    broadcastDraftProvider =
    StateNotifierProvider<BroadcastDraftController, BroadcastDraft>(
  (Ref ref) => BroadcastDraftController(),
);

/// Rotating preparedness tip keyed to the day of the year.
final Provider<String> emergencyTipProvider = Provider<String>((Ref ref) {
  final int day = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
  final List<String> tips = ref.watch(broadcastRepositoryProvider).tips;
  return tips[day % tips.length];
});
