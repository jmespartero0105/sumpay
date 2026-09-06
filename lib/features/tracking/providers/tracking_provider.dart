import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../sos/models/sos_request.dart';
import '../../sos/providers/responder_response_provider.dart';
import '../../sos/providers/sos_provider.dart';
import '../models/tracking_state.dart';

/// Builds the [TrackingState] for the resident's active responder-tracking
/// session by combining the latest responder response (name, role, status,
/// responder location) with the resident's own SOS record (their location and
/// the SOS incident location). Returns null when there is no active response to
/// track, which the UI uses to decide whether to show tracking at all.
final Provider<TrackingState?> trackingStateProvider =
    Provider<TrackingState?>((Ref ref) {
  final ResponderResponse? response = ref.watch(responderResponseProvider);
  if (response == null) return null;

  // Find the resident's own SOS that this response refers to, for its location.
  final List<SosRequest> log = ref.watch(sosLogProvider);
  SosRequest? own;
  for (final SosRequest r in log) {
    if (r.id == response.sosId) {
      own = r;
      break;
    }
  }

  final LatLng? residentPoint = own != null
      ? LatLng(own.latitude, own.longitude)
      : null;
  final LatLng? responderPoint =
      (response.responderLat != null && response.responderLng != null)
          ? LatLng(response.responderLat!, response.responderLng!)
          : null;

  return TrackingState(
    sosId: response.sosId,
    responderName: response.responderName,
    status: response.status,
    responderRole: response.responderRole,
    resident: residentPoint,
    responder: responderPoint,
    // The SOS incident location is the resident's location for a self-report.
    sosLocation: residentPoint,
    lastUpdated: response.receivedAt,
  );
});
