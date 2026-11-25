import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/db.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds the ordered `server_key` child table so a server can carry multiple
/// stored private keys tried in sequence.
///
/// Existing single-key rows in `server.ssh_key_id` are copied into `server_key`
/// at `ord = 0` while `server.ssh_key_id` stays populated with the first key
/// for legacy index compatibility.
class ServerKeysMigration extends SchemaMigration {
  const ServerKeysMigration();

  @override
  int get from => 44;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    db.execute(
      'CREATE TABLE IF NOT EXISTS server_key ('
      '"server_id" TEXT NOT NULL REFERENCES server (id) ON DELETE CASCADE, '
      '"ord" INTEGER NOT NULL, '
      '"key_id" TEXT NOT NULL REFERENCES private_key (id) ON DELETE CASCADE, '
      'PRIMARY KEY ("server_id", "ord")'
      ') WITHOUT ROWID;',
    );
    db.execute('''
      INSERT OR IGNORE INTO server_key (server_id, ord, key_id)
      SELECT s.id, 0, s.ssh_key_id
      FROM server s
      WHERE s.ssh_key_id IS NOT NULL
        AND EXISTS (SELECT 1 FROM private_key k WHERE k.id = s.ssh_key_id);
    ''');
    AppDb.restoreIndexes();
  }
}
