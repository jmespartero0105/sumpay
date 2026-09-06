/// A single captured GPS fix attached to an SOS.
///
/// This is a plain value object with no dependency on the location plugin, so
/// it can be persisted, sent across the mesh, and later handed to a mapping SDK
/// without coupling those layers to `geolocator`. Location is captured once, at
/// the moment the SOS is created; it is never continuously updated.
class SosLocationModel {
  const SosLocationModel({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
  });

  /// Latitude in decimal degrees.
  final double latitude;

  /// Longitude in decimal degrees.
  final double longitude;

  /// Horizontal accuracy of the fix, in metres (smaller is better).
  final double accuracy;

  /// When the fix was captured.
  final DateTime capturedAt;

  /// A short human-readable coordinate string, e.g. `9.30765, 123.30543`.
  String get coordinateLabel =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  /// A short accuracy label, e.g. `±12 m`.
  String get accuracyLabel => '±${accuracy.round()} m';

  SosLocationModel copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? capturedAt,
  }) {
    return SosLocationModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lat': latitude,
        'lng': longitude,
        'acc': accuracy,
        'ts': capturedAt.millisecondsSinceEpoch,
      };

  factory SosLocationModel.fromJson(Map<String, dynamic> json) {
    return SosLocationModel(
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      accuracy: (json['acc'] as num).toDouble(),
      capturedAt:
          DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
    );
  }
}
