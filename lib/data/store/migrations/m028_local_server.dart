import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/db.dart';
import 'package:server_box/data/store/schema.dart';

/// Lets a server be this device: `server.is_local`, and the CHECK that a row
/// is reached somehow relaxed to accept it.
///
/// The column alone would be an `ALTER TABLE`. The CHECK is why this is a
/// rebuild: SQLite cannot drop or replace a table constraint, so the table is
/// created under a new name with the constraint the app now wants, the rows
/// copied, the old one dropped and the new one renamed — the same documented
/// sequence as `m017`, with the same two pragmas and for the same reasons.
/// `server` is the parent of six `ON DELETE CASCADE` tables, so `foreign_keys`
/// is off across the drop and on again after; `legacy_alter_table` stops the
/// rename rewriting the children's foreign keys towards a table about to be
/// dropped.
class LocalServerMigration implements SchemaMigration {
  const LocalServerMigration();

  @override
  int get from => 28;

  /// The table as Drift creates it on a fresh install at v29, copied from
  /// `sqlite_master` rather than derived from the old table: the copy is the
  /// point where an upgraded install takes the fresh install's shape,
  /// including the `IN (0, 1)` checks the earlier `ADD COLUMN` steps left off.
  static const _columns = '''
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
    "monitor_ignore_cert" INTEGER NULL CHECK ("monitor_ignore_cert" IN (0, 1)),
    "monitor_allow_insecure" INTEGER NULL
      CHECK ("monitor_allow_insecure" IN (0, 1)),
    "wol_mac" TEXT NULL,
    "wol_ip" TEXT NULL,
    "wol_pwd" TEXT NULL,
    "bmc_addr" TEXT NULL,
    "bmc_cert_sha256" TEXT NULL,
    "bmc_cred_id" TEXT NULL REFERENCES bmc_credential (id) ON DELETE SET NULL,
    "pve_addr" TEXT NULL,
    "pve_ignore_cert" INTEGER NOT NULL DEFAULT 0
      CHECK ("pve_ignore_cert" IN (0, 1)),
    "pve_pwd" TEXT NULL,
    "prefer_temp_dev" TEXT NULL,
    "temp_is_celsius" INTEGER NOT NULL DEFAULT 1
      CHECK ("temp_is_celsius" IN (0, 1)),
    "logo_url" TEXT NULL,
    "net_dev" TEXT NULL,
    "script_dir" TEXT NULL,
    "geo_lat" REAL NULL,
    "geo_lon" REAL NULL,
    PRIMARY KEY ("id"),
    CHECK (ssh_ip IS NOT NULL OR monitor_addr IS NOT NULL OR is_local = 1),
    CHECK (ssh_port IS NULL OR ssh_port BETWEEN 1 AND 65535)
''';

  /// Every column of the v28 table: the above minus the one being added.
  static const _copied = '''
    updated_at, rev, id, name, auto_connect, system_type,
    ssh_ip, ssh_port, ssh_user, ssh_pwd, ssh_key_id, ssh_key_path,
    ssh_alter_url, ssh_proxy_command, ssh_file_transport,
    ssh_allow_legacy_algorithms, preferred_transport,
    ssh_enabled, monitor_enabled,
    monitor_addr, monitor_user, monitor_pwd, monitor_ignore_cert,
    monitor_allow_insecure,
    wol_mac, wol_ip, wol_pwd,
    bmc_addr, bmc_cert_sha256, bmc_cred_id,
    pve_addr, pve_ignore_cert, pve_pwd,
    prefer_temp_dev, temp_is_celsius, logo_url, net_dev, script_dir,
    geo_lat, geo_lon
''';

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;

    final columns = db
        .select('PRAGMA table_info(server);')
        .map((row) => row['name'] as String)
        .toSet();
    // Guarded, so the step is safe to run again after a process stopped
    // partway: the version is recorded only once every statement has run, and
    // the rename is the last of them.
    if (columns.contains('is_local')) return;

    // Outside the transaction, and restored whatever happens: both pragmas
    // are no-ops inside one, and `foreign_keys` left off disarms every cascade
    // for the rest of this connection's life.
    db.execute('PRAGMA foreign_keys = OFF;');
    db.execute('PRAGMA legacy_alter_table = ON;');
    try {
      db.execute('BEGIN;');
      try {
        db.execute('DROP TABLE IF EXISTS server_m028;');
        db.execute('CREATE TABLE server_m028 ($_columns) WITHOUT ROWID;');
        db.execute(
          'INSERT INTO server_m028 ($_copied) SELECT $_copied FROM server;',
        );
        db.execute('DROP TABLE server;');
        db.execute('ALTER TABLE server_m028 RENAME TO server;');
        // `DROP TABLE` took the indexes with it, and Drift creates them only
        // on `onCreate`. See `m017` for why the whole list.
        for (final statement in AppDb.indexStatements) {
          db.execute(statement);
        }
        db.execute('COMMIT;');
      } catch (_) {
        db.execute('ROLLBACK;');
        rethrow;
      }
      final broken = db.select('PRAGMA foreign_key_check;');
      if (broken.isNotEmpty) {
        Loggers.app.warning(
          'm028 left ${broken.length} foreign key violations',
        );
      }
    } finally {
      db.execute('PRAGMA legacy_alter_table = OFF;');
      db.execute('PRAGMA foreign_keys = ON;');
    }
  }
}
