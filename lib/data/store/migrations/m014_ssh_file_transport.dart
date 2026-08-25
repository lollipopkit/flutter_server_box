import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds `server.ssh_file_transport`: which protocol carries this host's files.
///
/// Null for every existing row, and null means SFTP — that is not a default
/// chosen here but a fact about the builds that wrote those rows, which had no
/// other way to move a file. Nothing is backfilled because there is nothing to
/// backfill from: a host that needs SCP is one the user has to name, since the
/// app cannot tell "this server has no SFTP subsystem" from "this server was
/// unreachable when we asked".
///
/// Written by hand rather than left to Drift, which owns the DDL but only for a
/// database being *created*: an install already at v14 has a `server` table
/// Drift will not revisit, and `createTables` is `IF NOT EXISTS` throughout.
/// The two have to agree — `m014_ssh_file_transport_test.dart` is what checks
/// it, since `tables_schema_test.dart` only ever sees a freshly created schema
/// and never runs this step.
class SshFileTransportMigration implements SchemaMigration {
  const SshFileTransportMigration();

  @override
  int get from => 14;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    final columns = db
        .select('PRAGMA table_info(server);')
        .map((row) => row['name'] as String)
        .toSet();
    // Guarded, so the step is safe to run again after a process stops partway:
    // the version is recorded only once every statement has run.
    if (columns.contains('ssh_file_transport')) return;
    db.execute('ALTER TABLE server ADD COLUMN ssh_file_transport TEXT;');
  }
}
