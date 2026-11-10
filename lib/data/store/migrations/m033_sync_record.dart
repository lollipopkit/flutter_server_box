import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/sync_recorder.dart';

/// Adds `sync_record`: every synced record's newest stamp, the operation log's
/// state.
///
/// Seeded from what the device already knows: each sync root's `updated_at`,
/// each tombstone's `deleted_at`, and each kv key's stamp in its store's
/// `lastUpdateTs`, all as stamps of no device (`SyncRecorder.legacy`). They are
/// what the snapshot sync agreed on, not changes made here, so none of them is
/// pending; the first change after this step is.
///
/// The table is written by hand, as `m032`'s column was: Drift writes DDL only
/// for a database being created. `m033_sync_record_test.dart` checks the two
/// agree. Safe to run again: the table is `IF NOT EXISTS` and the seed only
/// fills records that have no stamp yet.
class SyncRecordMigration implements SchemaMigration {
  const SyncRecordMigration();

  @override
  int get from => 33;

  static const _table = '''
CREATE TABLE IF NOT EXISTS sync_record (
  "c" TEXT NOT NULL,
  "id" TEXT NOT NULL,
  "hlc" TEXT NOT NULL,
  PRIMARY KEY ("c", "id")
) WITHOUT ROWID;
''';

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    db.execute(_table);
    db.execute('CREATE INDEX IF NOT EXISTS idx_sync_record_hlc ON sync_record(hlc);');
    SyncedStores.seed();
  }
}
