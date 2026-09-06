import '../../../core/constants/app_enums.dart';

/// A barangay-wide announcement pushed from the command node.
class BroadcastMessage {
  const BroadcastMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.severity,
    required this.issuedBy,
    required this.issuedAt,
    required this.reach,
    required this.acknowledged,
    required this.transport,
    required this.areas,
    this.isPinned = false,
    this.isActive = true,
  });

  final String id;
  final String title;
  final String body;
  final BroadcastSeverity severity;
  final String issuedBy;
  final DateTime issuedAt;
  final int reach;
  final int acknowledged;
  final LinkMode transport;
  final List<String> areas;
  final bool isPinned;
  final bool isActive;

  BroadcastMessage copyWith({
    int? reach,
    int? acknowledged,
    bool? isPinned,
    bool? isActive,
  }) {
    return BroadcastMessage(
      id: id,
      title: title,
      body: body,
      severity: severity,
      issuedBy: issuedBy,
      issuedAt: issuedAt,
      reach: reach ?? this.reach,
      acknowledged: acknowledged ?? this.acknowledged,
      transport: transport,
      areas: areas,
      isPinned: isPinned ?? this.isPinned,
      isActive: isActive ?? this.isActive,
    );
  }

  double get acknowledgementRate =>
      reach == 0 ? 0 : (acknowledged / reach) * 100;

  factory BroadcastMessage.fromJson(Map<String, dynamic> json) {
    return BroadcastMessage(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      severity: BroadcastSeverity.values.byName(json['severity'] as String),
      issuedBy: json['issuedBy'] as String,
      issuedAt: DateTime.now().subtract(
        Duration(minutes: json['minutesAgo'] as int),
      ),
      reach: json['reach'] as int,
      acknowledged: json['acknowledged'] as int,
      transport: LinkMode.values.byName(json['transport'] as String),
      areas: List<String>.from(json['areas'] as List<dynamic>),
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }
}

/// Draft composed by an official before dispatching a broadcast.
class BroadcastDraft {
  const BroadcastDraft({
    this.title = '',
    this.body = '',
    this.severity = BroadcastSeverity.advisory,
    this.areas = const <String>['All Puroks'],
    this.requireAcknowledgement = true,
  });

  final String title;
  final String body;
  final BroadcastSeverity severity;
  final List<String> areas;
  final bool requireAcknowledgement;

  bool get isValid => title.trim().isNotEmpty && body.trim().isNotEmpty;

  BroadcastDraft copyWith({
    String? title,
    String? body,
    BroadcastSeverity? severity,
    List<String>? areas,
    bool? requireAcknowledgement,
  }) {
    return BroadcastDraft(
      title: title ?? this.title,
      body: body ?? this.body,
      severity: severity ?? this.severity,
      areas: areas ?? this.areas,
      requireAcknowledgement:
          requireAcknowledgement ?? this.requireAcknowledgement,
    );
  }
}
