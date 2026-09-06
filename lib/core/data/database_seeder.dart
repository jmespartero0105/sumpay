import 'dart:convert';

import '../../features/authentication/models/app_user.dart';
import '../../features/broadcast/models/broadcast_models.dart';
import '../../features/iot/models/packet.dart';
import '../../features/messaging/models/message_models.dart';
import '../../features/sos/models/sos_request.dart';
import '../../features/volunteer/models/assignment.dart';
import 'app_database.dart';
import 'database_schema.dart';

/// Populates the local database with seed data on first launch.
///
/// Phase 1 keeps the app fully driven by in-memory dummy data for the UI, while
/// still persisting a mirror of that data into SQLite so the database layer is
/// real and testable. Seeding is idempotent: each table is only filled when it
/// is empty, so relaunching never duplicates rows.
class DatabaseSeeder {
  const DatabaseSeeder(this._db);

  final AppDatabase _db;

  /// Seeds every table that is currently empty.
  Future<void> seedIfEmpty({
    required List<AppUser> users,
    required List<Conversation> conversations,
    required Map<String, List<ChatMessage>> threads,
    required List<Packet> packets,
    required List<BroadcastMessage> broadcasts,
    required List<SosRequest> sosRequests,
    required List<Assignment> tasks,
  }) async {
    await _seedUsers(users);
    await _seedMessages(threads);
    await _seedPackets(packets);
    await _seedBroadcasts(broadcasts);
    await _seedSos(sosRequests);
    await _seedTasks(tasks);
  }

  Future<void> _seedUsers(List<AppUser> users) async {
    if (await _db.count(DatabaseSchema.tableUsers) > 0) return;
    await _db.replaceAll(
      DatabaseSchema.tableUsers,
      users
          .map((AppUser u) => <String, Object?>{
                'id': u.id,
                'full_name': u.fullName,
                'role': u.role.name,
                'phone': u.phone,
                'email': u.email,
                'barangay': u.barangay,
                'purok': u.purok,
                'municipality': u.municipality,
                'household_size': u.householdSize,
                'language': u.language,
                'device_id': u.deviceId,
                'blood_type': u.medical.bloodType,
                'emergency_contacts': jsonEncode(
                  u.emergencyContacts
                      .map((EmergencyContact c) => c.toJson())
                      .toList(),
                ),
                'medical': jsonEncode(u.medical.toJson()),
                'status': u.status.name,
              })
          .toList(),
    );
  }

  Future<void> _seedMessages(Map<String, List<ChatMessage>> threads) async {
    if (await _db.count(DatabaseSchema.tableMessages) > 0) return;
    final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
    for (final List<ChatMessage> thread in threads.values) {
      for (final ChatMessage m in thread) {
        rows.add(<String, Object?>{
          'id': m.id,
          'conversation_id': m.conversationId,
          'sender_name': m.senderName,
          'body': m.body,
          'sent_at': m.sentAt.millisecondsSinceEpoch,
          'is_mine': m.isMine ? 1 : 0,
          'status': m.status.name,
          'priority': m.priority.name,
          'transport': m.transport.name,
          'attachment': m.attachment == null
              ? null
              : jsonEncode(<String, Object?>{
                  'id': m.attachment!.id,
                  'name': m.attachment!.name,
                  'kind': m.attachment!.kind,
                  'sizeLabel': m.attachment!.sizeLabel,
                }),
        });
      }
    }
    await _db.replaceAll(DatabaseSchema.tableMessages, rows);
  }

  Future<void> _seedPackets(List<Packet> packets) async {
    if (await _db.count(DatabaseSchema.tablePackets) > 0) return;
    await _db.replaceAll(
      DatabaseSchema.tablePackets,
      packets.map((Packet p) => p.toDbRow()).toList(),
    );
  }

  Future<void> _seedBroadcasts(List<BroadcastMessage> broadcasts) async {
    if (await _db.count(DatabaseSchema.tableBroadcasts) > 0) return;
    await _db.replaceAll(
      DatabaseSchema.tableBroadcasts,
      broadcasts
          .map((BroadcastMessage b) => <String, Object?>{
                'id': b.id,
                'title': b.title,
                'body': b.body,
                'severity': b.severity.name,
                'issued_by': b.issuedBy,
                'issued_at': b.issuedAt.millisecondsSinceEpoch,
                'reach': b.reach,
                'acknowledged': b.acknowledged,
                'transport': b.transport.name,
                'areas': jsonEncode(b.areas),
                'is_pinned': b.isPinned ? 1 : 0,
              })
          .toList(),
    );
  }

  Future<void> _seedSos(List<SosRequest> requests) async {
    if (await _db.count(DatabaseSchema.tableSos) > 0) return;
    await _db.replaceAll(
      DatabaseSchema.tableSos,
      requests
          .map((SosRequest s) => <String, Object?>{
                'id': s.id,
                'type': s.type.name,
                'priority': s.priority.name,
                'description': s.description,
                'location_label': s.locationLabel,
                'latitude': s.latitude,
                'longitude': s.longitude,
                'created_at': s.createdAt.millisecondsSinceEpoch,
                'status': s.status.name,
                'delivery': s.delivery.name,
                'hop_count': s.hopCount,
                'people_affected': s.peopleAffected,
                'requester_name': s.requesterName,
                'responding_unit': s.respondingUnit,
              })
          .toList(),
    );
  }

  Future<void> _seedTasks(List<Assignment> tasks) async {
    if (await _db.count(DatabaseSchema.tableVolunteerTasks) > 0) return;
    await _db.replaceAll(
      DatabaseSchema.tableVolunteerTasks,
      tasks
          .map((Assignment a) => <String, Object?>{
                'id': a.id,
                'title': a.title,
                'description': a.description,
                'type': a.type.name,
                'priority': a.priority.name,
                'status': a.status.name,
                'location_label': a.locationLabel,
                'distance_metres': a.distanceMetres,
                'assigned_at': a.assignedAt.millisecondsSinceEpoch,
                'people_waiting': a.peopleWaiting,
                'team_name': a.teamName,
                'linked_sos_id': a.linkedSosId,
              })
          .toList(),
    );
  }
}
