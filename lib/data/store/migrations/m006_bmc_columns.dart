import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds the BMC side channel: an account table, and the three columns on
/// `server` that name one device.
///
/// The account is its own table because a rack shares one — see
/// `BmcCredential`. What stays on `server` is what belongs to a single device:
/// the address, and the certificate fingerprint the user reviewed.
///
/// Written by hand rather than left to Drift, which owns the DDL but only for
/// a database being *created*: an install already at v6 has a `server` table
/// Drift will not revisit, and `createTables` is `IF NOT EXISTS` throughout.
/// The two must agree, which `tables_schema_test.dart` is what checks.
///
/// Each statement is guarded, so the step is safe to run again after a process
/// stops partway — the version is recorded only once every statement has run,
/// so a stop between two of them means all of them run again.
class BmcColumnsMigration implements SchemaMigration {
  const BmcColumnsMigration();

  @override
  int get from => 6;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;

    // `IF NOT EXISTS` rather than a check: this one statement is idempotent on
    // its own, and the columns below are what needs the lookup.
    db.execute('''
CREATE TABLE IF NOT EXISTS bmc_credential (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  user TEXT NOT NULL,
  pwd TEXT,
  updated_at INTEGER NOT NULL DEFAULT 0,
  rev INTEGER NOT NULL DEFAULT 0
) WITHOUT ROWID;''');

    final columns = db
        .select('PRAGMA table_info(server);')
        .map((row) => row['name'] as String)
        .toSet();
    // `bmc_cred_id` carries its REFERENCES clause here rather than being a
    // plain column, or a migrated install would differ from a fresh one in the
    // one way that matters: `ON DELETE SET NULL` would not fire, and deleting
    // an account would leave every server that used it pointing at a row that
    // is gone. SQLite accepts a REFERENCES clause on ADD COLUMN as long as the
    // column defaults to NULL, which is what naming no default gives.
    const additions = {
      'bmc_addr': 'TEXT',
      'bmc_cert_sha256': 'TEXT',
      'bmc_cred_id':
          'TEXT REFERENCES bmc_credential (id) ON DELETE SET NULL',
    };
    for (final MapEntry(key: column, value: type) in additions.entries) {
      if (columns.contains(column)) continue;
      db.execute('ALTER TABLE server ADD COLUMN $column $type;');
    }
  }
}
