import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/db.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:sqlite3/sqlite3.dart';

/// Moves BMC configuration out of `server` into standalone `bmc_target` and
/// `bmc_target_tag` tables so BMCs can exist independently in the Status tab
/// or remain linked to a host via `server_id`.
///
/// Rebuilds `server` without `bmc_addr`, `bmc_cert_sha256`, and `bmc_cred_id`,
/// copying every configured server's BMC (and its tags) into `bmc_target`.
class BmcTargetMigration extends SchemaMigration {
  const BmcTargetMigration();

  static const appliedAt = 43;

  @override
  int get from => appliedAt;

  static const _bmcTargetTable = '''
CREATE TABLE IF NOT EXISTS bmc_target (
  "updated_at" INTEGER NOT NULL DEFAULT 0,
  "rev" INTEGER NOT NULL DEFAULT 0,
  "id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "addr" TEXT NOT NULL,
  "cred_id" TEXT NULL REFERENCES bmc_credential (id) ON DELETE SET NULL,
  "cert_sha256" TEXT NULL,
  "server_id" TEXT NULL REFERENCES server (id) ON DELETE SET NULL,
  PRIMARY KEY ("id")
) WITHOUT ROWID;
''';

  static const _bmcTargetTagTable = '''
CREATE TABLE IF NOT EXISTS bmc_target_tag (
  "target_id" TEXT NOT NULL REFERENCES bmc_target (id) ON DELETE CASCADE,
  "tag" TEXT NOT NULL,
  PRIMARY KEY ("target_id", "tag")
) WITHOUT ROWID;
''';

  /// `server` as Drift creates it on a fresh install at v44: v43 without the
  /// three BMC columns.
  static const _serverColumns = '''
    "updated_at" INTEGER NOT NULL DEFAULT 0,
    "rev" INTEGER NOT NULL DEFAULT 0,
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "auto_connect" INTEGER NOT NULL DEFAULT 1 CHECK ("auto_connect" IN (0, 1)),
    "system_type" TEXT NULL,
    "ssh_ip" TEXT NULL,
    "ssh_port" INTEGER NULL,
    "ssh_user" TEXT NULL,
    "ssh_pwd" TEXT NULL,
    "ssh_key_id" TEXT NULL REFERENCES private_key (id) ON DELETE SET NULL,
    "ssh_key_path" TEXT NULL,
    "ssh_alter_url" TEXT NULL,
    "ssh_proxy_command" TEXT NULL,
    "ssh_file_transport" TEXT NULL,
    "ssh_allow_legacy_algorithms" INTEGER NOT NULL DEFAULT 0
      CHECK ("ssh_allow_legacy_algorithms" IN (0, 1)),
    "preferred_transport" TEXT NULL,
    "ssh_enabled" INTEGER NOT NULL DEFAULT 1 CHECK ("ssh_enabled" IN (0, 1)),
    "monitor_enabled" INTEGER NOT NULL DEFAULT 1
      CHECK ("monitor_enabled" IN (0, 1)),
    "is_local" INTEGER NOT NULL DEFAULT 0 CHECK ("is_local" IN (0, 1)),
    "monitor_addr" TEXT NULL,
    "monitor_user" TEXT NULL,
    "monitor_pwd" TEXT NULL,
    "monitor_cert_sha256" TEXT NULL,
    "monitor_allow_insecure" INTEGER NULL
      CHECK ("monitor_allow_insecure" IN (0, 1)),
    "wol_mac" TEXT NULL,
    "wol_ip" TEXT NULL,
    "wol_pwd" TEXT NULL,
    "prefer_temp_dev" TEXT NULL,
    "temp_is_celsius" INTEGER NOT NULL DEFAULT 1
      CHECK ("temp_is_celsius" IN (0, 1)),
    "logo_url" TEXT NULL,
    "net_dev" TEXT NULL,
    "script_dir" TEXT NULL,
    "geo_lat" REAL NULL,
    "geo_lon" REAL NULL,
    "disk_counts_network" INTEGER NOT NULL DEFAULT 0
      CHECK ("disk_counts_network" IN (0, 1)),
    "ssh_identity_agent" TEXT NULL,
    "ssh_forward_agent" INTEGER NOT NULL DEFAULT 0
      CHECK ("ssh_forward_agent" IN (0, 1)),
    "ssh_control_path" TEXT NULL,
    "monitor_fallback_addr" TEXT NULL,
    PRIMARY KEY ("id"),
    CHECK (ssh_ip IS NOT NULL OR monitor_addr IS NOT NULL OR is_local = 1),
    CHECK (ssh_port IS NULL OR ssh_port BETWEEN 1 AND 65535)
''';

  static const _copied = '''
    updated_at, rev, id, name, auto_connect, system_type,
    ssh_ip, ssh_port, ssh_user, ssh_pwd, ssh_key_id, ssh_key_path,
    ssh_alter_url, ssh_proxy_command, ssh_file_transport,
    ssh_allow_legacy_algorithms, preferred_transport,
    ssh_enabled, monitor_enabled, is_local,
    monitor_addr, monitor_user, monitor_pwd, monitor_cert_sha256,
    monitor_allow_insecure,
    wol_mac, wol_ip, wol_pwd,
    prefer_temp_dev, temp_is_celsius, logo_url, net_dev, script_dir,
    geo_lat, geo_lon, disk_counts_network,
    ssh_identity_agent, ssh_forward_agent, ssh_control_path,
    monitor_fallback_addr
''';

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;

    final columns = db
        .select('PRAGMA table_info(server);')
        .map((row) => row['name'] as String)
        .toSet();
    if (columns.contains('bmc_addr')) {
      _moveOut(db);
    } else {
      db.execute(_bmcTargetTable);
      db.execute(_bmcTargetTagTable);
      AppDb.restoreIndexes();
    }

    // Seed op-log records when `sync_record` already exists so migrated BMC
    // targets propagate on the next incremental sync.
    final hasSyncRecord = db
        .select(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'sync_record';",
        )
        .isNotEmpty;
    if (hasSyncRecord) {
      SyncRecorder.seedRecords('bmc_target', [
        for (final row in db.select('SELECT id, updated_at FROM bmc_target;'))
          (row['id'] as String, row['updated_at'] as int),
      ]);
    }
  }

  static void _moveOut(Database db) {
    // Same pattern as m030: drop `server` with foreign keys off so CASCADE
    // children stay intact, and `legacy_alter_table` so children's FKs stay
    // pointing at `server` rather than the temp name.
    db.execute('PRAGMA foreign_keys = OFF;');
    db.execute('PRAGMA legacy_alter_table = ON;');
    try {
      SqliteStore.transact(() {
        db.execute(_bmcTargetTable);
        db.execute(_bmcTargetTagTable);

        db.execute('''
          INSERT OR IGNORE INTO bmc_target (
            updated_at, rev, id, name, addr, cred_id, cert_sha256, server_id
          )
          SELECT
            s.updated_at,
            CASE WHEN s.rev > 0 THEN s.rev ELSE 1 END,
            'bmc_' || s.id,
            s.name,
            s.bmc_addr,
            CASE
              WHEN s.bmc_cred_id IS NOT NULL
                AND EXISTS (SELECT 1 FROM bmc_credential c WHERE c.id = s.bmc_cred_id)
              THEN s.bmc_cred_id
              ELSE NULL
            END,
            s.bmc_cert_sha256,
            s.id
          FROM server s
          WHERE s.bmc_addr IS NOT NULL AND TRIM(s.bmc_addr) != '';
        ''');

        db.execute('''
          INSERT OR IGNORE INTO bmc_target_tag (target_id, tag)
          SELECT 'bmc_' || st.server_id, st.tag
          FROM server_tag st
          INNER JOIN bmc_target bt ON bt.id = 'bmc_' || st.server_id;
        ''');

        db.execute('DROP TABLE IF EXISTS server_m043;');
        db.execute(
          'CREATE TABLE server_m043 ($_serverColumns) WITHOUT ROWID;',
        );
        db.execute(
          'INSERT INTO server_m043 ($_copied) SELECT $_copied FROM server;',
        );
        db.execute('DROP TABLE server;');
        db.execute('ALTER TABLE server_m043 RENAME TO server;');
        AppDb.restoreIndexes();
      });
    } finally {
      db.execute('PRAGMA legacy_alter_table = OFF;');
      db.execute('PRAGMA foreign_keys = ON;');
    }

    final broken = db.select('PRAGMA foreign_key_check;');
    if (broken.isNotEmpty) {
      Loggers.app.warning(
        'm043 left ${broken.length} foreign key violation(s)',
      );
    }
  }
}
