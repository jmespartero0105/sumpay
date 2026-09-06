import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/uuid.dart';
import 'app_database.dart';
import 'database_provider.dart';
import 'database_schema.dart';

/// Provides this device's stable mesh identifier.
///
/// Every phone in the mesh needs a unique, persistent id so packets can be
/// addressed and de-duplicated regardless of the human-readable device name
/// (which can collide or change). The id is generated once on first launch and
/// stored in the [DatabaseSchema.tableMeshMeta] key-value table, so it survives
/// restarts and reconnections.
class DeviceIdentity {
  DeviceIdentity(this._db);

  static const String _deviceIdKey = 'device_id';

  final AppDatabase _db;

  String? _cached;

  /// The current device id, if already loaded this session.
  String? get currentOrNull => _cached;

  /// Returns the persistent device id, creating and storing one if absent.
  Future<String> ensure() async {
    if (_cached != null) return _cached!;

    final List<Map<String, Object?>> rows = await _db.database.query(
      DatabaseSchema.tableMeshMeta,
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[_deviceIdKey],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      _cached = rows.first['value'] as String;
      return _cached!;
    }

    final String id = 'dev-${Uuid.v4()}';
    await _db.database.insert(
      DatabaseSchema.tableMeshMeta,
      <String, Object?>{'key': _deviceIdKey, 'value': id},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _cached = id;
    return id;
  }
}

/// Provides the [DeviceIdentity]. The id itself is resolved once at startup and
/// exposed synchronously via [deviceIdProvider].
final Provider<DeviceIdentity> deviceIdentityProvider =
    Provider<DeviceIdentity>((Ref ref) {
  return DeviceIdentity(ref.watch(appDatabaseProvider));
});

/// Holds the resolved device id. Overridden in `ProviderScope` at startup after
/// [DeviceIdentity.ensure] completes, mirroring how the database is provided.
final Provider<String> deviceIdProvider = Provider<String>((Ref ref) {
  throw UnimplementedError(
    'deviceIdProvider must be overridden in ProviderScope after '
    'DeviceIdentity.ensure() completes.',
  );
});
