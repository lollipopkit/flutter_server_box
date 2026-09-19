import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds the two switches that say whether a server's SSH and its agent are
/// dialled at all.
///
/// Off is not absent. Turning a method off used to mean the editor dropped its
/// fields on save, so the host, the port, the account and the key had to be
/// typed again to turn it back on; these columns are what lets the
/// configuration stay while the app stops using it.
///
/// Both default to true, which is what every existing row was doing.
class TransportSwitchesMigration implements SchemaMigration {
  const TransportSwitchesMigration();

  @override
  int get from => 25;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    final existing = db
        .select('PRAGMA table_info(server);')
        .map((row) => row['name'] as String)
        .toSet();
    // Plain `ADD COLUMN`, not a create-copy-drop-rename: no constraint
    // changes, and `server` is the parent of six cascading tables that a
    // rebuild would have to be careful with.
    //
    // Guarded per column, so the step is safe to run again after a process
    // stops partway: the version is recorded only once every statement has
    // run, and `ADD COLUMN` has no `IF NOT EXISTS`.
    for (final column in const ['ssh_enabled', 'monitor_enabled']) {
      if (existing.contains(column)) continue;
      db.execute(
        'ALTER TABLE server ADD COLUMN $column INTEGER NOT NULL DEFAULT 1;',
      );
    }
  }
}
