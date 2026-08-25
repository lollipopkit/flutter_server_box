import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds `server_dist`, the cache of what each server was last seen running.
///
/// A table rather than a column on `server`: the distribution is observed, not
/// configured, and `server` is a sync root — a reading from one device would
/// otherwise travel to every other and overwrite theirs. This one syncs
/// nowhere, like `conn_stat`.
///
/// Written by hand rather than left to Drift, which owns the DDL but only for
/// a database being *created*: an install already at v10 has a schema Drift
/// will not revisit, and `createTables` is `IF NOT EXISTS` throughout. The two
/// have to agree — the `the migration` group in `server_dist_store_test.dart`
/// is what checks it, since `tables_schema_test.dart` only ever sees a freshly
/// created schema and never runs this step.
///
/// Nothing is backfilled. There is nothing to backfill from: the reading comes
/// from a status poll, so every server fills its own row the first time it
/// connects after this ships, and draws the neutral mark until then.
class ServerDistMigration implements SchemaMigration {
  const ServerDistMigration();

  @override
  int get from => 10;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    // Guarded, so the step is safe to run again after a process stops partway:
    // the version is recorded only once every statement has run.
    final existing = db
        .select("SELECT name FROM sqlite_master WHERE type = 'table';")
        .map((row) => row['name'] as String)
        .toSet();
    if (existing.contains('server_dist')) return;
    db.execute('''
CREATE TABLE server_dist (
  server_id TEXT NOT NULL PRIMARY KEY REFERENCES server (id) ON DELETE CASCADE,
  dist TEXT NOT NULL,
  updated_at INTEGER NOT NULL
) WITHOUT ROWID;
''');
  }
}
