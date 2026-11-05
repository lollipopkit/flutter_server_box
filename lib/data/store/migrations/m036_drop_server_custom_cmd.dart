import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Drops `server_custom_cmd`, what `ServerCustom.cmds` was stored in.
///
/// Custom commands are files on the server since v1.0.1538, and the app moved
/// the local copy there on each server's first connection. The rows left are
/// those of servers that never connected since; they go with the table.
///
/// Idempotent by construction: `IF EXISTS`.
class DropServerCustomCmdMigration implements SchemaMigration {
  const DropServerCustomCmdMigration();

  @override
  int get from => 36;

  @override
  Future<void> apply() async {
    SqliteDb.instance.execute('DROP TABLE IF EXISTS server_custom_cmd;');
  }
}
