/// Central definition of the SUMPAY local SQLite schema.
///
/// Keeping the table names, versions and DDL in one place means the database
/// service and every repository refer to the same identifiers, and the schema
/// can evolve through numbered migrations without hunting through the codebase.
class DatabaseSchema {
  const DatabaseSchema._();

  static const String databaseName = 'sumpay.db';
  static const int databaseVersion = 9;

  // Table names.
  static const String tableUsers = 'users';
  static const String tableMessages = 'messages';
  static const String tablePackets = 'packets';
  static const String tableBroadcasts = 'broadcasts';
  static const String tableSos = 'sos_requests';
  static const String tableVolunteerTasks = 'volunteer_tasks';

  /// Key-value store for mesh metadata (e.g. the persistent device id).
  static const String tableMeshMeta = 'mesh_meta';

  /// Ordered list of `CREATE TABLE` statements executed on first open.
  static const List<String> createStatements = <String>[
    '''
    CREATE TABLE $tableUsers (
      id TEXT PRIMARY KEY,
      surname TEXT NOT NULL DEFAULT '',
      first_name TEXT NOT NULL DEFAULT '',
      middle_name TEXT NOT NULL DEFAULT '',
      role TEXT NOT NULL,
      phone TEXT NOT NULL,
      email TEXT NOT NULL,
      barangay TEXT NOT NULL,
      purok TEXT NOT NULL,
      municipality TEXT NOT NULL,
      household_size INTEGER NOT NULL,
      language TEXT NOT NULL,
      device_id TEXT NOT NULL,
      blood_type TEXT NOT NULL,
      emergency_contacts TEXT NOT NULL,
      medical TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active',
      password_hash TEXT
    )
    ''',
    '''
    CREATE TABLE $tableMessages (
      id TEXT PRIMARY KEY,
      conversation_id TEXT NOT NULL,
      sender_name TEXT NOT NULL,
      body TEXT NOT NULL,
      sent_at INTEGER NOT NULL,
      is_mine INTEGER NOT NULL,
      status TEXT NOT NULL,
      priority TEXT NOT NULL,
      transport TEXT NOT NULL,
      attachment TEXT,
      hop_count INTEGER NOT NULL DEFAULT 0,
      was_relayed INTEGER NOT NULL DEFAULT 0,
      mesh_path TEXT,
      sender_role TEXT,
      reply_to_id TEXT,
      reply_to_name TEXT,
      reply_to_preview TEXT,
      is_read INTEGER NOT NULL DEFAULT 0,
      is_pinned INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE TABLE $tablePackets (
      id TEXT PRIMARY KEY,
      description TEXT NOT NULL,
      transport TEXT NOT NULL,
      status TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      size_bytes INTEGER NOT NULL,
      hop_count INTEGER NOT NULL,
      source_id TEXT,
      destination_id TEXT
    )
    ''',
    '''
    CREATE TABLE $tableBroadcasts (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      severity TEXT NOT NULL,
      issued_by TEXT NOT NULL,
      issued_at INTEGER NOT NULL,
      reach INTEGER NOT NULL,
      acknowledged INTEGER NOT NULL,
      transport TEXT NOT NULL,
      areas TEXT NOT NULL,
      is_pinned INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE $tableSos (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      priority TEXT NOT NULL,
      description TEXT NOT NULL,
      location_label TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      created_at INTEGER NOT NULL,
      status TEXT NOT NULL,
      delivery TEXT NOT NULL,
      hop_count INTEGER NOT NULL,
      people_affected INTEGER NOT NULL,
      requester_name TEXT NOT NULL,
      requester_id TEXT,
      additional_types TEXT,
      responding_unit TEXT,
      accuracy REAL,
      location_captured_at INTEGER
    )
    ''',
    '''
    CREATE TABLE $tableVolunteerTasks (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      type TEXT NOT NULL,
      priority TEXT NOT NULL,
      status TEXT NOT NULL,
      location_label TEXT NOT NULL,
      distance_metres REAL NOT NULL,
      assigned_at INTEGER NOT NULL,
      people_waiting INTEGER NOT NULL,
      team_name TEXT NOT NULL,
      linked_sos_id TEXT
    )
    ''',
    '''
    CREATE TABLE $tableMeshMeta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
  ];
}
