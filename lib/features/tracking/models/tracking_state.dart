import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_enums.dart';
import '../../sos/models/sos_packet.dart';

/// A single point on the map with an associated role, used to render markers.
class TrackingMarker {
  const TrackingMarker({
    required this.id,
    required this.point,
    required this.kind,
    this.label,
  });

  final String id;
  final LatLng point;
  final TrackingMarkerKind kind;
  final String? label;
}

/// The kinds of markers the tracking map can display.
enum TrackingMarkerKind { resident, responder, sos }

/// Immutable snapshot of a responder-tracking session for one SOS. Designed so
/// that future periodic responder-location updates simply produce a new
/// [TrackingState] with an updated [responder] point and [lastUpdated] time;
/// no other part of the app needs to change to support live tracking later.
class TrackingState {
  const TrackingState({
    required this.sosId,
    required this.responderName,
    required this.status,
    this.responderRole,
    this.resident,
    this.responder,
    this.sosLocation,
    this.lastUpdated,
  });

  final String sosId;
  final String responderName;
  final SosStatus status;
  final UserRole? responderRole;

  /// The resident's location (origin of the SOS).
  final LatLng? resident;

  /// The responder's most recently known location. Updated over time in future
  /// iterations; for now it is the location captured at acceptance.
  final LatLng? responder;

  /// The SOS incident location (may equal [resident] for a self-report).
  final LatLng? sosLocation;

  /// When the responder location was last refreshed.
  final DateTime? lastUpdated;

  /// Builds the marker list for the map from whatever points are available.
  List<TrackingMarker> get markers {
    final List<TrackingMarker> out = <TrackingMarker>[];
    if (resident != null) {
      out.add(TrackingMarker(
        id: 'resident',
        point: resident!,
        kind: TrackingMarkerKind.resident,
        label: 'Your Location',
      ));
    }
    if (responder != null) {
      out.add(TrackingMarker(
        id: 'responder',
        point: responder!,
        kind: TrackingMarkerKind.responder,
        label: 'Responder',
      ));
    }
    if (sosLocation != null) {
      out.add(TrackingMarker(
        id: 'sos',
        point: sosLocation!,
        kind: TrackingMarkerKind.sos,
        label: 'Emergency Location',
      ));
    }
    return out;
  }

  /// Straight-line (great-circle) distance in meters between the resident and
  /// the responder, or null if either location is unknown. Uses latlong2's
  /// [Distance] so it needs no network. This is an as-the-crow-flies estimate,
  /// not a routed travel distance.
  double? get distanceMeters {
    if (resident == null || responder == null) return null;
    return const Distance().as(LengthUnit.Meter, resident!, responder!);
  }

  /// Human-friendly distance string (e.g. "1.2 km" or "340 m"), or null.
  String? get distanceLabel {
    final double? m = distanceMeters;
    if (m == null) return null;
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
    return '${m.round()} m';
  }

  /// Human-readable responder status for the tracking panel.
  String get statusLabel => switch (status) {
        SosStatus.responderAccepted => 'On the way',
        SosStatus.responderEnRoute => 'On the way',
        SosStatus.arrived => 'Arrived',
        SosStatus.resolved => 'Resolved',
        SosStatus.rejected => 'Could not respond',
        _ => 'Responding',
      };

  TrackingState copyWith({
    SosStatus? status,
    UserRole? responderRole,
    LatLng? resident,
    LatLng? responder,
    LatLng? sosLocation,
    DateTime? lastUpdated,
  }) {
    return TrackingState(
      sosId: sosId,
      responderName: responderName,
      status: status ?? this.status,
      responderRole: responderRole ?? this.responderRole,
      resident: resident ?? this.resident,
      responder: responder ?? this.responder,
      sosLocation: sosLocation ?? this.sosLocation,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Abstraction over the mapping implementation so the concrete map package can
/// be swapped later without touching the rest of the app. The current
/// implementation ([OsmMapService]) uses OpenStreetMap raster tiles via
/// flutter_map, but any provider that can supply a tile-URL template and a
/// sensible default view would satisfy this contract.
abstract class MapService {
  /// The tile URL template (XYZ scheme) used to render the base map.
  String get tileUrlTemplate;

  /// A User-Agent / package identifier required by OSM tile usage policy.
  String get userAgentPackageName;

  /// Attribution text that must be shown over the map.
  String get attribution;

  /// A reasonable fallback centre when no locations are known yet.
  LatLng get defaultCenter;

  /// A reasonable default zoom level for emergency tracking.
  double get defaultZoom;
}

/// OpenStreetMap-backed [MapService]. No API key required. Tiles require
/// network access to load, but this is kept entirely separate from SOS/mesh
/// communication: if tiles fail to load, messaging continues to function.
class OsmMapService implements MapService {
  const OsmMapService();

  @override
  String get tileUrlTemplate =>
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  String get userAgentPackageName => 'com.sumpay.app';

  @override
  String get attribution => '© OpenStreetMap contributors';

  @override
  // Centre of the Philippines as a neutral fallback.
  LatLng get defaultCenter => const LatLng(12.8797, 121.7740);

  @override
  double get defaultZoom => 15;
}
