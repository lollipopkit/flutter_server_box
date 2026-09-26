import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/db.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:sqlite3/sqlite3.dart';

/// PVE moves out of `server` into `server_pve`, and into the Virtualization
/// tab.
///
/// **The table.** One row per server with PVE configured, cascading with the
/// server — see `ServerPves` in `db.dart`. Created by hand for `m020`'s reason:
/// Drift writes DDL only for a database being created.
///
/// **The copy.** Every row with a `pve_addr` becomes a `password` login: that
/// is the only way in any earlier build offered. `pve_pwd` comes along only
/// for a server whose SSH login uses a stored key (`ssh_key_id`), since only
/// there did an earlier build send it — with a password SSH login it sent
/// that instead, and hid the field while still saving whatever it held. A
/// leftover copied there would be a second password that nothing uses (see
/// `PveConfig.loginPassword`).
/// No certificate is pinned, whatever `pve_ignore_cert` said. A row that had it
/// set accepted any certificate unseen, so there is nothing to carry over, and
/// no pin means the next connection shows the certificate for confirmation;
/// a row that had it clear was validated by a CA and still is.
///
/// **The columns.** `pve_addr`, `pve_ignore_cert` and `pve_pwd` are dropped
/// from `server`. `pve_ignore_cert` carries a CHECK, which SQLite cannot drop
/// in place, so this is `m028`'s rebuild — create under a new name, copy,
/// drop, rename — with the same two pragmas for the same reasons: `server` is
/// the parent of every `ON DELETE CASCADE` child, `server_pve` now among them,
/// so `foreign_keys` is off across the drop and on again after, and
/// `legacy_alter_table` stops the rename rewriting the children's foreign keys
/// towards a table about to be dropped.
///
/// **The tab.** When any row was copied, `virt` is appended to the stored home
/// bar, since that is where PVE now is. The bar is the user's arrangement, so
/// nothing in it moves:
///
/// - Already there: nothing to add.
/// - Never arranged (no stored value): left alone. The bar is then
///   `AppTab.defaultOrder`, which is where a new tab arrives for everyone, and
///   writing a snapshot of today's default would freeze that user's bar
///   against every later change to it.
/// - [barRoom] tabs or more: left alone, so the tab is behind "more" — every
///   tab not in the stored list is. Four is where the phone bar stops fitting
///   its labels (see `AppTab.defaultOrder`); nothing enforces it, so a fifth
///   is the user's to add, not this step's.
///
/// The tab is written by name as a literal, not through `AppTab`: this step
/// has to mean the same thing after the enum changes, and the parser drops a
/// name it does not know. The write is not a user edit, so it does not stamp
/// the sync clock — otherwise the migrated device would win the next merge for
/// every setting.
///
/// Safe to run again after a process stopped partway: the version is recorded
/// only once `apply` returns, the copy and the rebuild are one transaction
/// guarded by the old column still being there, and the tab is appended only
/// if absent.
class PveVirtMigration implements SchemaMigration {
  const PveVirtMigration();

  static const appliedAt = 30;
  static const homeTabsKey = 'homeTabs';
  static const virtTab = 'virt';
  static const barRoom = 4;

  @override
  int get from => appliedAt;

  /// `server_pve` as Drift creates it on a fresh install at v31.
  static const _pveTable = '''
CREATE TABLE IF NOT EXISTS server_pve (
  "server_id" TEXT NOT NULL REFERENCES server (id) ON DELETE CASCADE,
  "addr" TEXT NOT NULL,
  "auth" TEXT NOT NULL,
  "pwd" TEXT NULL,
  "token_id" TEXT NULL,
  "token_secret" TEXT NULL,
  "cert_sha256" TEXT NULL,
  PRIMARY KEY ("server_id"),
  CHECK (auth IN ('password', 'token'))
) WITHOUT ROWID;
''';

  /// `server` as Drift creates it on a fresh install at v31: `m028`'s table
  /// without the three PVE columns.
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

  /// Every column the v30 table keeps.
  static const _copied = '''
    updated_at, rev, id, name, auto_connect, system_type,
    ssh_ip, ssh_port, ssh_user, ssh_pwd, ssh_key_id, ssh_key_path,
    ssh_alter_url, ssh_proxy_command, ssh_file_transport,
    ssh_allow_legacy_algorithms, preferred_transport,
    ssh_enabled, monitor_enabled, is_local,
    monitor_addr, monitor_user, monitor_pwd, monitor_ignore_cert,
    monitor_allow_insecure,
    wol_mac, wol_ip, wol_pwd,
    bmc_addr, bmc_cert_sha256, bmc_cred_id,
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
    if (columns.contains('pve_addr')) _moveOut(db);

    final hasPve = db.select('SELECT 1 FROM server_pve LIMIT 1;').isNotEmpty;
    if (hasPve) _addTab();
  }

  void _moveOut(Database db) {
    // Outside the transaction, and restored whatever happens: both pragmas
    // are no-ops inside one, and `foreign_keys` left off disarms every cascade
    // for the rest of this connection's life.
    db.execute('PRAGMA foreign_keys = OFF;');
    db.execute('PRAGMA legacy_alter_table = ON;');
    try {
      db.execute('BEGIN;');
      try {
        db.execute(_pveTable);
        // An empty address was never a PVE configuration — the editor wrote
        // null for one — and `addr` is `NOT NULL` for that reason.
        db.execute(
          'INSERT OR IGNORE INTO server_pve (server_id, addr, auth, pwd) '
          "SELECT id, pve_addr, 'password', "
          "CASE WHEN ssh_key_id IS NOT NULL THEN NULLIF(pve_pwd, '') END "
          'FROM server '
          "WHERE pve_addr IS NOT NULL AND trim(pve_addr) != '';",
        );
        db.execute('DROP TABLE IF EXISTS server_m030;');
        db.execute('CREATE TABLE server_m030 ($_columns) WITHOUT ROWID;');
        db.execute(
          'INSERT INTO server_m030 ($_copied) SELECT $_copied FROM server;',
        );
        db.execute('DROP TABLE server;');
        db.execute('ALTER TABLE server_m030 RENAME TO server;');
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
          'm030 left ${broken.length} foreign key violations',
        );
      }
    } finally {
      db.execute('PRAGMA legacy_alter_table = OFF;');
      db.execute('PRAGMA foreign_keys = ON;');
    }
  }

  void _addTab() {
    final setting = SettingStore.instance;
    final raw = setting.get<Object>(homeTabsKey);
    if (raw is! List || raw.contains(virtTab) || raw.length >= barRoom) {
      return;
    }
    final ok = setting.set(homeTabsKey, [
      ...raw,
      virtTab,
    ], updateLastUpdateTsOnSet: false);
    if (!ok) throw StateError('m030: writing "$homeTabsKey" failed');
  }
}
