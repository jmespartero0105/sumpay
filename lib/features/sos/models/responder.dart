import '../../../core/constants/app_enums.dart';

/// The state of a single responder relative to one SOS.
enum ResponderState {
  accepted('Accepted'),
  enRoute('En route'),
  onScene('On scene');

  const ResponderState(this.label);
  final String label;

  static ResponderState fromName(String? raw) {
    switch (raw) {
      case 'enRoute':
        return ResponderState.enRoute;
      case 'onScene':
        return ResponderState.onScene;
      case 'accepted':
      default:
        return ResponderState.accepted;
    }
  }
}

/// One responder who has accepted a given SOS. Multiple responders can respond
/// to a single SOS, so each incident tracks a list of these.
class Responder {
  const Responder({
    required this.id,
    required this.name,
    this.state = ResponderState.accepted,
    this.latitude,
    this.longitude,
    this.updatedAt,
  });

  final String id;
  final String name;
  final ResponderState state;
  final double? latitude;
  final double? longitude;
  final DateTime? updatedAt;

  Responder copyWith({
    ResponderState? state,
    double? latitude,
    double? longitude,
    DateTime? updatedAt,
  }) {
    return Responder(
      id: id,
      name: name,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'state': state.name,
        if (latitude != null) 'lat': latitude,
        if (longitude != null) 'lng': longitude,
        if (updatedAt != null) 'at': updatedAt!.toIso8601String(),
      };

  factory Responder.fromMap(Map<String, dynamic> m) => Responder(
        id: (m['id'] as String?) ?? '',
        name: (m['name'] as String?) ?? 'Responder',
        state: ResponderState.fromName(m['state'] as String?),
        latitude: (m['lat'] as num?)?.toDouble(),
        longitude: (m['lng'] as num?)?.toDouble(),
        updatedAt: m['at'] is String
            ? DateTime.tryParse(m['at'] as String)
            : null,
      );
}
