import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../models/sos_packet.dart';

/// A responder's response to a resident's SOS, as received over the mesh. This
/// is a dedicated, SOS-associated event (not a chat message), rendered as the
/// green "responder accepted / responding" card on the resident's home.
class ResponderResponse {
  const ResponderResponse({
    required this.responseId,
    required this.sosId,
    required this.responderName,
    required this.status,
    required this.receivedAt,
    this.responderId,
    this.responderRole,
    this.responderLat,
    this.responderLng,
  });

  final String responseId;
  final String sosId;
  final String responderName;
  final SosStatus status;
  final DateTime receivedAt;
  final String? responderId;
  final UserRole? responderRole;
  final double? responderLat;
  final double? responderLng;

  /// Builds a response from an incoming SOS responder packet.
  factory ResponderResponse.fromPacket(SosPacket p) {
    return ResponderResponse(
      responseId: p.responseId ??
          'resp-${p.sosId}-${DateTime.now().millisecondsSinceEpoch}',
      sosId: p.sosId,
      responderName: p.actorName ?? 'Responder',
      status: p.status,
      receivedAt: DateTime.now(),
      responderRole: p.actorRole,
      responderLat: p.actorLat,
      responderLng: p.actorLng,
    );
  }
}

/// The latest responder response for one of this resident's own SOS requests.
/// Null until a responder accepts/responds. Drives the green response card.
final StateProvider<ResponderResponse?> responderResponseProvider =
    StateProvider<ResponderResponse?>((Ref ref) => null);
