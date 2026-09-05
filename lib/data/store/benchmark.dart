import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';
import 'package:server_box/data/model/server/benchmark/yabs_options.dart';
import 'package:sqlite3/sqlite3.dart';

/// Every benchmark this device has run, newest first.
///
/// Read synchronously like the rest of the stores here: the UI reads it while
/// building.
///
/// Not cached whole, unlike `server_dist`. A row carries a log and a result
/// document — tens of kilobytes each — and the only readers are one server's
/// history page and the runner polling one run, so keeping every run of every
/// server in memory would cost far more than the query it saves.
class BenchmarkStore {
  BenchmarkStore([this._table = 'benchmark_run']);

  static final instance = BenchmarkStore();

  /// A separate instance for a test, so the change stream is not shared with
  /// the singleton across tests in one process.
  factory BenchmarkStore.forTest() => BenchmarkStore();

  final String _table;

  Database get _db => SqliteDb.instance;

  final _changes = StreamController<void>.broadcast();

  /// Fires after any write, for the pages showing a run or a history list.
  Stream<void> get changes => _changes.stream;

  void _invalidate() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// How many runs are kept per server.
  ///
  /// A bound rather than none: each row is a log plus a result document, and
  /// nothing ever deletes one on its own. Old benchmarks of a machine that has
  /// not changed are the least valuable rows in the database, so the oldest go
  /// first.
  static const historyLimit = 50;

  static const _columns =
      'id, server_id, started_at, finished_at, status, options, run_dir, '
      'result_json, log, exit_code, error';

  BenchmarkRun? _fromRow(Row row) {
    final status = BenchmarkStatus.byName(row['status'] as String?);
    // A status no build knows is a row this one cannot reason about — it might
    // be running. Skipped rather than guessed at.
    if (status == null) return null;

    YabsOptions options;
    try {
      final decoded = json.decode(row['options'] as String? ?? '{}');
      options = decoded is Map<String, dynamic>
          ? YabsOptions.fromJson(decoded)
          : const YabsOptions();
    } catch (e) {
      // The result is still worth showing, and the defaults are honest about
      // being unknown in a way that dropping the row would not be.
      Loggers.app.warning('Benchmark options unreadable: $e');
      options = const YabsOptions();
    }

    final finished = row['finished_at'] as int?;
    return BenchmarkRun(
      id: row['id'] as String,
      serverId: row['server_id'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
      finishedAt: finished == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(finished),
      status: status,
      options: options,
      runDir: row['run_dir'] as String? ?? '',
      resultJson: row['result_json'] as String?,
      log: row['log'] as String? ?? '',
      exitCode: row['exit_code'] as int?,
      error: row['error'] as String? ?? '',
    );
  }

  /// One server's runs, newest first. Served by
  /// `idx_benchmark_run_server_started`.
  List<BenchmarkRun> forServer(String serverId) {
    final rows = _db.select(
      'SELECT $_columns FROM $_table WHERE server_id = ? '
      'ORDER BY started_at DESC;',
      [serverId],
    );
    return [
      for (final row in rows) ?_fromRow(row),
    ];
  }

  BenchmarkRun? get(String id) {
    final rows = _db.select('SELECT $_columns FROM $_table WHERE id = ?;', [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// The run this server has in flight, if any.
  ///
  /// What the page asks on open, so that a benchmark started before the app was
  /// closed is picked back up rather than shown as absent — the run is detached
  /// and has been going the whole time.
  ///
  /// More than one would be a bug; the newest wins rather than throwing, since
  /// there is no reading of the situation where refusing to show either is the
  /// better one.
  BenchmarkRun? activeFor(String serverId) {
    final rows = _db.select(
      'SELECT $_columns FROM $_table WHERE server_id = ? AND status = ? '
      'ORDER BY started_at DESC LIMIT 1;',
      [serverId, BenchmarkStatus.running.name],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Writes [run], replacing whatever was under its id.
  ///
  /// `ON CONFLICT DO UPDATE` naming the data columns, not `INSERT OR REPLACE`:
  /// that form deletes and reinserts, which for a row with a foreign key means
  /// firing cascades for a row that is not going anywhere.
  void put(BenchmarkRun run) {
    _db.execute(
      'INSERT INTO $_table ($_columns) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT (id) DO UPDATE SET '
      'finished_at = excluded.finished_at, status = excluded.status, '
      'options = excluded.options, run_dir = excluded.run_dir, '
      'result_json = excluded.result_json, log = excluded.log, '
      'exit_code = excluded.exit_code, error = excluded.error;',
      [
        run.id,
        run.serverId,
        run.startedAt.millisecondsSinceEpoch,
        run.finishedAt?.millisecondsSinceEpoch,
        run.status.name,
        json.encode(run.options.toJson()),
        run.runDir,
        run.resultJson,
        run.log,
        run.exitCode,
        run.error,
      ],
    );
    _prune(run.serverId);
    _invalidate();
  }

  /// Drops this server's oldest runs past [historyLimit].
  ///
  /// A running row is never pruned, whatever its age: it names a directory on a
  /// server that still has a process in it, and losing the row is losing the
  /// only way to reach either.
  void _prune(String serverId) {
    _db.execute(
      'DELETE FROM $_table WHERE id IN ('
      '  SELECT id FROM $_table WHERE server_id = ? AND status != ? '
      '  ORDER BY started_at DESC LIMIT -1 OFFSET ?'
      ');',
      [serverId, BenchmarkStatus.running.name, historyLimit],
    );
  }

  void remove(String id) {
    _db.execute('DELETE FROM $_table WHERE id = ?;', [id]);
    _invalidate();
  }

  /// Forgets one server's history.
  ///
  /// The foreign key cascades when the server itself is deleted; this is for
  /// the user clearing it by hand.
  void removeForServer(String serverId) {
    _db.execute('DELETE FROM $_table WHERE server_id = ?;', [serverId]);
    _invalidate();
  }

  /// Every run of every server, newest first — the cross-server comparison.
  ///
  /// Only rows that produced a result: comparing against a run that failed
  /// halfway would put an empty column beside real ones.
  List<BenchmarkRun> allCompleted() {
    final rows = _db.select(
      'SELECT $_columns FROM $_table WHERE status = ? AND result_json IS NOT NULL '
      'ORDER BY started_at DESC;',
      [BenchmarkStatus.completed.name],
    );
    return [
      for (final row in rows) ?_fromRow(row),
    ];
  }
}
