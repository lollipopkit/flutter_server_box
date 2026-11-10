import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/benchmark.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/sync_recorder.dart';

/// Syncs what was left on the device: each kind by its own switch
/// (`SyncCategory`).
///
/// - `sync_passed`: what a category turned off here takes from the others,
///   kept for the snapshots this device writes.
/// - The Agent's stores and the finished benchmarks sync: records now
///   (`SyncedStores.seed`, `SyncRecorder.seedRecords`).
/// - The logs are joined again: what was left out of them (the settings,
///   until now off unless turned on) goes out from every device.
class SyncAllMigration implements SchemaMigration {
  const SyncAllMigration();

  @override
  int get from => 38;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    db.execute(
      'CREATE TABLE IF NOT EXISTS sync_passed ('
      'e TEXT NOT NULL, c TEXT NOT NULL, id TEXT NOT NULL, h TEXT NOT NULL, d TEXT NOT NULL, '
      'PRIMARY KEY (e, c, id)) WITHOUT ROWID;',
    );
    SyncedStores.seed();
    SyncRecorder.seedRecords(BenchmarkStore.c, BenchmarkStore.finished());
    // As the engines' forget: read again, everything sent. The account and
    // the store they are bound to stay, and this device's segment numbering:
    // a segment written again under a number the others read past is never
    // read.
    db.execute(
      "DELETE FROM sync_state WHERE (k LIKE 'log.%' AND k != 'log.account') "
      "OR (k LIKE 'seg.%' AND k NOT IN ('seg.store', 'seg.n'));",
    );
  }
}
