import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Lets one server carry SSH *and* a monitor agent, and records which leads.
///
/// Two changes to the `server` table, and only one of them is an
/// `ALTER TABLE`:
///
/// - `preferred_transport`, added the ordinary way. Null on every existing
///   row, which is correct: none of them can have both, so none of them has
///   anything to prefer.
/// - The exclusivity check has to go. It reads
///   `CHECK ((ssh_ip IS NOT NULL) <> (monitor_addr IS NOT NULL))` — an
///   exclusive or — and SQLite has no way to drop or replace a table
///   constraint. The only way is the documented twelve-step rebuild: create
///   the table under a new name with the constraint the app now wants, copy
///   every row across, drop the old one, rename.
///
/// The rebuild is why this is more than a one-line step, and why it is worth
/// reading carefully. `server` is the parent of six child tables with
/// `ON DELETE CASCADE`, so **`foreign_keys` must be off while it happens** —
/// with it on, dropping the old table takes every tag, jump, env and custom
/// command with it. `PRAGMA foreign_keys` is also a no-op inside a
/// transaction, which is why it is set outside one and the copy is wrapped in
/// its own.
///
/// `legacy_alter_table` is the other half. Without it, `ALTER TABLE ... RENAME`
/// rewrites references to the old name inside other objects' definitions —
/// helpful in general, and here it would rewrite the child tables' foreign
/// keys to point at a table that is about to not exist.
class BothTransportsMigration implements SchemaMigration {
  const BothTransportsMigration();

  @override
  int get from => 17;

  /// Every column of the rebuilt table, in order, as the current schema has
  /// them.
  ///
  /// Written out rather than derived from `PRAGMA table_info`, because the
  /// point of the copy is to move the rows into *this* shape — a list read
  /// back from the old table would faithfully reproduce whatever it already
  /// was, including anything a partly-applied earlier run left behind.
  static const _columns = '''
    updated_at INTEGER NOT NULL DEFAULT 0,
    rev INTEGER NOT NULL DEFAULT 0,
    id TEXT NOT NULL,
    name TEXT NOT NULL,
    auto_connect INTEGER NOT NULL DEFAULT 1,
    system_type TEXT,
    ssh_ip TEXT,
    ssh_port INTEGER,
    ssh_user TEXT,
    ssh_pwd TEXT,
    ssh_key_id TEXT REFERENCES private_key(id) ON DELETE SET NULL,
    ssh_key_path TEXT,
    ssh_alter_url TEXT,
    ssh_proxy_command TEXT,
    ssh_file_transport TEXT,
    preferred_transport TEXT,
    monitor_addr TEXT,
    monitor_user TEXT,
    monitor_pwd TEXT,
    monitor_ignore_cert INTEGER,
    monitor_allow_insecure INTEGER,
    wol_mac TEXT,
    wol_ip TEXT,
    wol_pwd TEXT,
    bmc_addr TEXT,
    bmc_cert_sha256 TEXT,
    bmc_cred_id TEXT REFERENCES bmc_credential(id) ON DELETE SET NULL,
    pve_addr TEXT,
    pve_ignore_cert INTEGER NOT NULL DEFAULT 0,
    pve_pwd TEXT,
    prefer_temp_dev TEXT,
    temp_is_celsius INTEGER NOT NULL DEFAULT 1,
    logo_url TEXT,
    net_dev TEXT,
    script_dir TEXT,
    PRIMARY KEY (id),
    CHECK (ssh_ip IS NOT NULL OR monitor_addr IS NOT NULL),
    CHECK (ssh_port IS NULL OR ssh_port BETWEEN 1 AND 65535)
''';

  /// The copied columns, which are the above minus the one being added.
  static const _copied = '''
    updated_at, rev, id, name, auto_connect, system_type,
    ssh_ip, ssh_port, ssh_user, ssh_pwd, ssh_key_id, ssh_key_path,
    ssh_alter_url, ssh_proxy_command, ssh_file_transport,
    monitor_addr, monitor_user, monitor_pwd, monitor_ignore_cert,
    monitor_allow_insecure,
    wol_mac, wol_ip, wol_pwd,
    bmc_addr, bmc_cert_sha256, bmc_cred_id,
    pve_addr, pve_ignore_cert, pve_pwd,
    prefer_temp_dev, temp_is_celsius, logo_url, net_dev, script_dir
''';

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;

    final columns = db
        .select('PRAGMA table_info(server);')
        .map((row) => row['name'] as String)
        .toSet();
    // Guarded, so the step is safe to run again after a process stopped
    // partway: the version is recorded only once every statement has run.
    if (columns.contains('preferred_transport')) return;

    // Outside the transaction below, and restored whatever happens. Both
    // pragmas are ignored inside one, and leaving `foreign_keys` off would
    // silently disarm every cascade for the rest of this connection's life.
    db.execute('PRAGMA foreign_keys = OFF;');
    db.execute('PRAGMA legacy_alter_table = ON;');
    try {
      db.execute('BEGIN;');
      try {
        db.execute('DROP TABLE IF EXISTS server_m017;');
        db.execute('CREATE TABLE server_m017 ($_columns) WITHOUT ROWID;');
        db.execute(
          'INSERT INTO server_m017 ($_copied) SELECT $_copied FROM server;',
        );
        db.execute('DROP TABLE server;');
        db.execute('ALTER TABLE server_m017 RENAME TO server;');
        db.execute('COMMIT;');
      } catch (_) {
        db.execute('ROLLBACK;');
        rethrow;
      }
      // After the rename and after the commit: it reports on the whole
      // database, and a violation introduced here is worth knowing about
      // before anything else writes.
      final broken = db.select('PRAGMA foreign_key_check;');
      if (broken.isNotEmpty) {
        Loggers.app.warning(
          'm017 left ${broken.length} foreign key violations',
        );
      }
    } finally {
      db.execute('PRAGMA legacy_alter_table = OFF;');
      db.execute('PRAGMA foreign_keys = ON;');
    }
  }
}
