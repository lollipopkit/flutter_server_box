import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds `server.disk_counts_network`: whether NFS, SMB and the like count in
/// the disk total when status comes over SSH (#1669).
///
/// False for every existing row. The filesystems it covers are listed either
/// way; this decides only whether another machine's storage adds to this
/// one's total.
///
/// Written by hand rather than left to Drift, which owns the DDL only for a
/// database being created; `m032_disk_counts_network_test.dart` checks the two
/// agree.
class DiskCountsNetworkMigration implements SchemaMigration {
  const DiskCountsNetworkMigration();

  @override
  int get from => 32;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    final columns = db
        .select('PRAGMA table_info(server);')
        .map((row) => row['name'] as String)
        .toSet();
    // Guarded, so the step is safe to run again after a process stops partway:
    // the version is recorded only once every statement has run.
    if (columns.contains('disk_counts_network')) return;
    db.execute(
      'ALTER TABLE server ADD COLUMN disk_counts_network '
      'INTEGER NOT NULL DEFAULT 0;',
    );
  }
}
