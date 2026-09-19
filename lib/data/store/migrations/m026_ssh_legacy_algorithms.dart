import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds `server.ssh_allow_legacy_algorithms`: whether this host may negotiate
/// the algorithms SSH has retired.
///
/// False for every existing row, which is what those builds proposed and what
/// the modern algorithm set still proposes. The column exists only so a host
/// that cannot be reached without `ssh-rsa` or a SHA-1 key exchange can be
/// opted in by hand; nothing changes about how any server was already being
/// talked to.
///
/// Written by hand rather than left to Drift, which owns the DDL but only for a
/// database being *created*: an install already past this step has a `server`
/// table Drift will not revisit, and `createTables` is `IF NOT EXISTS`
/// throughout. `m026_ssh_legacy_algorithms_test.dart` is what checks the two
/// agree.
class SshLegacyAlgorithmsMigration implements SchemaMigration {
  const SshLegacyAlgorithmsMigration();

  @override
  int get from => 26;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    final columns = db
        .select('PRAGMA table_info(server);')
        .map((row) => row['name'] as String)
        .toSet();
    // Guarded, so the step is safe to run again after a process stops partway:
    // the version is recorded only once every statement has run.
    if (columns.contains('ssh_allow_legacy_algorithms')) return;
    db.execute(
      'ALTER TABLE server ADD COLUMN ssh_allow_legacy_algorithms '
      'INTEGER NOT NULL DEFAULT 0;',
    );
  }
}
