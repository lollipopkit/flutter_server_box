import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds the four tables a plugin's records live in. PLUGINS.md section 7.
///
/// Written by hand rather than left to Drift for the reason `m010` states:
/// Drift owns the DDL only for a database being *created*, and an install
/// already at v22 has a schema it will never revisit. The two definitions have
/// to agree, and `plugin_store_test.dart`'s migration group is what checks
/// they still do — `tables_schema_test.dart` only ever sees a fresh schema and
/// never runs this step.
///
/// Nothing is backfilled. No earlier build could install a plugin, so every
/// install starts with none.
///
/// **`plugin_kv` is split in two**, which the design sketch had as one table
/// with a nullable `server_id`. A `WITHOUT ROWID` table refuses NULL in a
/// primary key, and a rowid table would not have refused a *second* global row
/// with the same key — SQLite treats two NULLs as distinct in a unique index,
/// so the one shape that expresses "global" would also be the one shape with
/// no uniqueness at all. Two tables give both halves an honest primary key and
/// let the per-server half cascade with the server.
class PluginTablesMigration implements SchemaMigration {
  const PluginTablesMigration();

  @override
  int get from => 22;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    // Every statement guards itself rather than the step guarding all of them
    // behind one existence check. The step is not one statement: a process
    // that stopped between two of them would, under that check, return early
    // on the next launch and leave the rest permanently missing — and the
    // version is recorded only once `apply()` returns, so that next launch is
    // guaranteed to happen.
    db.execute('''
CREATE TABLE IF NOT EXISTS plugin_install (
  id TEXT NOT NULL PRIMARY KEY,
  version TEXT NOT NULL,
  repo TEXT,
  enabled INTEGER NOT NULL DEFAULT 1,
  granted TEXT NOT NULL,
  installed_at INTEGER NOT NULL
) WITHOUT ROWID;
''');
    db.execute('''
CREATE TABLE IF NOT EXISTS server_plugin_cfg (
  server_id TEXT NOT NULL REFERENCES server (id) ON DELETE CASCADE,
  plugin_id TEXT NOT NULL,
  cfg TEXT NOT NULL,
  cfg_ver INTEGER NOT NULL,
  PRIMARY KEY (server_id, plugin_id)
) WITHOUT ROWID;
''');
    db.execute('''
CREATE TABLE IF NOT EXISTS plugin_kv (
  plugin_id TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (plugin_id, key)
) WITHOUT ROWID;
''');
    db.execute('''
CREATE TABLE IF NOT EXISTS server_plugin_kv (
  server_id TEXT NOT NULL REFERENCES server (id) ON DELETE CASCADE,
  plugin_id TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (server_id, plugin_id, key)
) WITHOUT ROWID;
''');
    // "Everything this plugin stored", which uninstalling asks for and which
    // neither primary key can serve — both lead with `server_id`.
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_server_plugin_kv_plugin '
      'ON server_plugin_kv(plugin_id);',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_server_plugin_cfg_plugin '
      'ON server_plugin_cfg(plugin_id);',
    );
  }
}
