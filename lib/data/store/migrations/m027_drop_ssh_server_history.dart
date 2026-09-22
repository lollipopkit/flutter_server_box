import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Deletes the data left by the retired recent-server dialog.
///
/// The value was an MRU list of server IDs in the `history` key-value store.
/// Terminal tabs already preserve active work, while the server picker exposes
/// every saved server with search and sorting, so nothing replaces this list.
///
/// Idempotent by construction: a second run deletes nothing.
class DropSshServerHistoryMigration implements SchemaMigration {
  const DropSshServerHistoryMigration();

  @override
  int get from => 27;

  @override
  Future<void> apply() async {
    SqliteDb.instance.execute(
      "DELETE FROM kv WHERE store = 'history' AND key = 'sshServerHistory';",
    );
  }
}
