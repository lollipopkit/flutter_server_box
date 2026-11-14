import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds `server.ssh_control_path` (`SshCredential.controlPath`): null for
/// every existing row, as no build before asked an OpenSSH master.
///
/// Written by hand: Drift creates tables only for a new database.
/// `m041_ssh_control_path_test.dart` checks the two agree.
class SshControlPathMigration implements SchemaMigration {
  const SshControlPathMigration();

  @override
  int get from => 41;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    final columns = db
        .select('PRAGMA table_info(server);')
        .map((row) => row['name'] as String)
        .toSet();
    // Guarded: the version is recorded only once every statement has run.
    if (columns.contains('ssh_control_path')) return;
    db.execute('ALTER TABLE server ADD COLUMN ssh_control_path TEXT;');
  }
}
