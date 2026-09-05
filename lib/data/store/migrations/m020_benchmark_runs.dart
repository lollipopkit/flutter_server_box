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
    // Guarded, so the step is safe to run again after a process stops partway:
    // the version is recorded only once every statement has run.
    final existing = db
        .select("SELECT name FROM sqlite_master WHERE type = 'table';")
        .map((row) => row['name'] as String)
        .toSet();
    if (existing.contains('benchmark_run')) return;
    db.execute('''
CREATE TABLE benchmark_run (
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
