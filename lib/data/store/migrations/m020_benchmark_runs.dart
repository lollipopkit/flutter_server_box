import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Adds `benchmark_run`, the record of every yabs run and its result.
///
/// Written by hand rather than left to Drift for the reason `m010` states:
/// Drift owns the DDL only for a database being *created*, and an install
/// already at v20 has a schema it will never revisit. The two definitions have
/// to agree, and `benchmark_store_test.dart`'s migration group is what checks
/// they still do — `tables_schema_test.dart` only ever sees a fresh schema and
/// never runs this step.
///
/// Nothing is backfilled. There is nothing to backfill from: no earlier build
/// could run a benchmark, so every install starts with an empty history.
class BenchmarkRunsMigration implements SchemaMigration {
  const BenchmarkRunsMigration();

  @override
  int get from => 20;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    // Every statement guards itself rather than the step guarding all of them
    // behind one existence check. The step is not one statement: a process
    // that stopped between the table and its index would, under that check,
    // return early on the next launch and leave the index permanently
    // missing — and the version is recorded only once `apply()` returns, so
    // that next launch is guaranteed to happen.
    db.execute('''
CREATE TABLE IF NOT EXISTS benchmark_run (
  id TEXT NOT NULL PRIMARY KEY,
  server_id TEXT NOT NULL REFERENCES server (id) ON DELETE CASCADE,
  started_at INTEGER NOT NULL,
  finished_at INTEGER,
  status TEXT NOT NULL,
  options TEXT NOT NULL,
  run_dir TEXT NOT NULL,
  result_json TEXT,
  log TEXT NOT NULL DEFAULT '',
  exit_code INTEGER,
  error TEXT NOT NULL DEFAULT ''
) WITHOUT ROWID;
''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_benchmark_run_server_started '
      'ON benchmark_run(server_id, started_at DESC);',
    );
  }
}
