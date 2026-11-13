import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds `server.ssh_identity_agent`: the ssh-agent a server's keys may come
/// from (`SshCredential.identityAgent`). Null, no agent, for every existing
/// row, which is how those builds authenticated.
///
/// Written by hand: Drift creates tables only for a new database.
/// `m039_ssh_identity_agent_test.dart` checks the two agree.
class SshIdentityAgentMigration implements SchemaMigration {
  const SshIdentityAgentMigration();

  @override
  int get from => 39;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    final columns = db
        .select('PRAGMA table_info(server);')
        .map((row) => row['name'] as String)
        .toSet();
    // Guarded: the version is recorded only once every statement has run.
    if (columns.contains('ssh_identity_agent')) return;
    db.execute('ALTER TABLE server ADD COLUMN ssh_identity_agent TEXT;');
  }
}
