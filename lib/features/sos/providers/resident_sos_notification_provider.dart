import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/responder.dart';
import '../models/sos_packet.dart';

/// The latest incoming status update for one of this resident's SOS, for the
/// UI to surface as an in-app notification. Null when there is nothing new.
///
/// Lives in its own file so both the mesh controller (which sets it on incoming
/// responder updates) and the resident SOS log (which sets it on the
/// no-responder timeout) can import it without a circular dependency.
final StateProvider<SosStatusUpdate?> residentSosNotificationProvider =
    StateProvider<SosStatusUpdate?>((Ref ref) => null);

/// Responders per SOS id, tracked independently of the mesh SOS list so the
/// resident (whose own SOS may not live in [sosMeshProvider]) can still see the
/// full, stacking list of everyone who has accepted their SOS.
final StateProvider<Map<String, List<Responder>>> respondersBySosProvider =
    StateProvider<Map<String, List<Responder>>>(
        (Ref ref) => <String, List<Responder>>{});
