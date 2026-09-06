import '../../../core/constants/app_enums.dart';
import 'sos_location_model.dart';

/// Parses a comma-separated list of [EmergencyType] names (as stored for
/// additional SOS categories), skipping any unknown/blank entries.
List<EmergencyType> _decodeTypes(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <EmergencyType>[];
  final Map<String, EmergencyType> byName = EmergencyType.values.asNameMap();
  return raw
      .split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty && byName.containsKey(s))
      .map((String s) => byName[s]!)
      .toList();
}

/// A distress signal raised by a resident and relayed over the mesh/LoRa link.
class SosRequest {
  const SosRequest({
    required this.id,
    required this.type,
    this.additionalTypes = const <EmergencyType>[],
    required this.priority,
    required this.description,
    required this.locationLabel,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.status,
    required this.delivery,
    required this.hopCount,
    required this.peopleAffected,
    this.requesterName = 'You',
    this.requesterId = '',
    this.respondingUnit,
    this.accuracy,
    this.locationCapturedAt,
  });

  final String id;
  final EmergencyType type;

  /// Extra emergency categories selected alongside the primary [type].
  final List<EmergencyType> additionalTypes;

  /// A readable summary of all categories, e.g. "Medical + Fire".
  String get typesSummary => additionalTypes.isEmpty
      ? type.label
      : <String>[type.label, ...additionalTypes.map((EmergencyType t) => t.label)]
          .join(' + ');

  final PriorityLevel priority;
  final String description;
  final String locationLabel;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final IncidentStatus status;
  final DeliveryStatus delivery;
  final int hopCount;
  final int peopleAffected;
  final String requesterName;
  final String requesterId;
  final String? respondingUnit;

  /// Horizontal accuracy of the captured GPS fix, in metres. Null when the SOS
  /// was created without a device location (e.g. permission denied).
  final double? accuracy;

  /// When the GPS fix was captured. Null when no device location was attached.
  final DateTime? locationCapturedAt;

  /// Whether a real device-captured location is attached to this SOS.
  bool get hasCapturedLocation => accuracy != null;

  String get coordinates =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  SosRequest copyWith({
    EmergencyType? type,
    List<EmergencyType>? additionalTypes,
    PriorityLevel? priority,
    String? description,
    String? locationLabel,
    IncidentStatus? status,
    DeliveryStatus? delivery,
    int? hopCount,
    int? peopleAffected,
    String? respondingUnit,
  }) {
    return SosRequest(
      id: id,
      type: type ?? this.type,
      additionalTypes: additionalTypes ?? this.additionalTypes,
      priority: priority ?? this.priority,
      description: description ?? this.description,
      locationLabel: locationLabel ?? this.locationLabel,
      latitude: latitude,
      longitude: longitude,
      createdAt: createdAt,
      status: status ?? this.status,
      delivery: delivery ?? this.delivery,
      hopCount: hopCount ?? this.hopCount,
      peopleAffected: peopleAffected ?? this.peopleAffected,
      requesterName: requesterName,
      respondingUnit: respondingUnit ?? this.respondingUnit,
      accuracy: accuracy,
      locationCapturedAt: locationCapturedAt,
    );
  }

  factory SosRequest.fromJson(Map<String, dynamic> json) {
    return SosRequest(
      id: json['id'] as String,
      type: EmergencyType.values.byName(json['type'] as String),
      additionalTypes: _decodeTypes(json['additionalTypes'] as String?),
      priority: PriorityLevel.values.byName(json['priority'] as String),
      description: json['description'] as String,
      locationLabel: json['locationLabel'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      createdAt: DateTime.now().subtract(
        Duration(minutes: json['minutesAgo'] as int),
      ),
      status: IncidentStatus.values.byName(json['status'] as String),
      delivery: DeliveryStatus.values.byName(json['delivery'] as String),
      hopCount: json['hopCount'] as int,
      peopleAffected: json['peopleAffected'] as int,
      requesterName: json['requesterName'] as String? ?? 'You',
      requesterId: json['requesterId'] as String? ?? '',
      respondingUnit: json['respondingUnit'] as String?,
    );
  }

  /// Serialises to a SQLite row for the `sos_requests` table.
  Map<String, Object?> toDbRow() => <String, Object?>{
        'id': id,
        'type': type.name,
        'additional_types': additionalTypes.map((EmergencyType t) => t.name).join(','),
        'priority': priority.name,
        'description': description,
        'location_label': locationLabel,
        'latitude': latitude,
        'longitude': longitude,
        'created_at': createdAt.millisecondsSinceEpoch,
        'status': status.name,
        'delivery': delivery.name,
        'hop_count': hopCount,
        'people_affected': peopleAffected,
        'requester_name': requesterName,
        'requester_id': requesterId,
        'responding_unit': respondingUnit,
        'accuracy': accuracy,
        'location_captured_at': locationCapturedAt?.millisecondsSinceEpoch,
      };

  /// Reconstructs a [SosRequest] from a SQLite row.
  factory SosRequest.fromDbRow(Map<String, Object?> row) {
    final Object? capturedAt = row['location_captured_at'];
    return SosRequest(
      id: row['id'] as String,
      type: EmergencyType.values.byName(row['type'] as String),
      additionalTypes: _decodeTypes(row['additional_types'] as String?),
      priority: PriorityLevel.values.byName(row['priority'] as String),
      description: row['description'] as String,
      locationLabel: row['location_label'] as String,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      status: IncidentStatus.values.byName(row['status'] as String),
      delivery: DeliveryStatus.values.byName(row['delivery'] as String),
      hopCount: row['hop_count'] as int,
      peopleAffected: row['people_affected'] as int,
      requesterName: row['requester_name'] as String,
      requesterId: (row['requester_id'] as String?) ?? '',
      respondingUnit: row['responding_unit'] as String?,
      accuracy: (row['accuracy'] as num?)?.toDouble(),
      locationCapturedAt: capturedAt is int
          ? DateTime.fromMillisecondsSinceEpoch(capturedAt)
          : null,
    );
  }

  /// The attached captured location, if any, as a [SosLocationModel].
  SosLocationModel? get capturedLocation => accuracy == null
      ? null
      : SosLocationModel(
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy!,
          capturedAt: locationCapturedAt ?? createdAt,
        );
}

/// Draft state assembled on the SOS composer before confirmation.
class SosDraft {
  const SosDraft({
    this.type,
    this.additionalTypes = const <EmergencyType>[],
    this.priority = PriorityLevel.critical,
    this.description = '',
    this.peopleAffected = 1,
    this.shareMedicalProfile = true,
    this.locationLabel = 'Purok 4, Sitio Bagong Silang',
    this.latitude = 9.30684,
    this.longitude = 123.30193,
  });

  /// The main emergency type. Null until the resident selects one — there is no
  /// pre-selected default; the user must explicitly pick.
  final EmergencyType? type;

  /// Extra emergency categories the resident selected beyond the primary [type].
  /// The primary drives the icon/colour; these are shown as an additional list.
  final List<EmergencyType> additionalTypes;

  final PriorityLevel priority;
  final String description;
  final int peopleAffected;
  final bool shareMedicalProfile;
  final String locationLabel;
  final double latitude;
  final double longitude;

  String get coordinates =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  /// Whether the resident has selected at least one emergency type.
  bool get hasSelection => type != null;

  SosDraft copyWith({
    EmergencyType? type,
    bool clearType = false,
    List<EmergencyType>? additionalTypes,
    PriorityLevel? priority,
    String? description,
    int? peopleAffected,
    bool? shareMedicalProfile,
    String? locationLabel,
  }) {
    return SosDraft(
      type: clearType ? null : (type ?? this.type),
      additionalTypes: additionalTypes ?? this.additionalTypes,
      priority: priority ?? this.priority,
      description: description ?? this.description,
      peopleAffected: peopleAffected ?? this.peopleAffected,
      shareMedicalProfile: shareMedicalProfile ?? this.shareMedicalProfile,
      locationLabel: locationLabel ?? this.locationLabel,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
