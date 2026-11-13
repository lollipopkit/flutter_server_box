import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds `server.ssh_forward_agent` (`SshCredential.forwardAgent`): false for
/// every existing row, as no build before forwarded an agent.
///
/// Written by hand: Drift creates tables only for a new database.
/// `m040_ssh_forward_agent_test.dart` checks the two agree.
class SshForwardAgentMigration implements SchemaMigration {
  const SshForwardAgentMigration();

  @override
  int get from => 40;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    final columns = db
        .select('PRAGMA table_info(server);')
        .map((row) => row['name'] as String)
        .toSet();
    // Guarded: the version is recorded only once every statement has run.
    if (columns.contains('ssh_forward_agent')) return;
    db.execute(
      'ALTER TABLE server ADD COLUMN ssh_forward_agent '
      'INTEGER NOT NULL DEFAULT 0 CHECK ("ssh_forward_agent" IN (0, 1));',
    );
  }
}
