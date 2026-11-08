import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';
import 'package:server_box/data/model/server/benchmark/yabs_options.dart';
import 'package:server_box/data/store/sync_recorder.dart';
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

  /// The record kind a finished run syncs as, by its id (`SyncRecorder`).
  /// One running is this device's: its directory is on the server, polled
  /// from here.
  static const c = 'benchmark';

  final String _table;

  Database get _db => SqliteDb.instance;

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

  BenchmarkRun? _fromRow(Map<String, Object?> row) {
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

  /// Everything about this table that a list of runs would draw differently,
  /// in one cheap query: how many there are, and which servers have one in
  /// flight.
  ///
  /// The benchmark tab asks this once a second to decide whether to re-read
  /// [all], which decodes every run's log and result document — tens of
  /// kilobytes a row. Two small columns per row instead.
  ///
  /// Both halves are needed. The count alone misses a run ending, and the
  /// running set alone misses a run that starts and fails inside one second —
  /// which is what a poll answering "the run directory is gone" does.
  ({int total, Set<String> running}) listRevision() {
    final rows = _db.select('SELECT server_id, status FROM $_table;');
    final running = <String>{};
    for (final row in rows) {
      if (row['status'] == BenchmarkStatus.running.name) {
        running.add(row['server_id'] as String);
      }
    }
    return (total: rows.length, running: running);
  }

  /// Writes [run], replacing whatever was under its id.
  ///
  /// `ON CONFLICT DO UPDATE` naming the data columns, not `INSERT OR REPLACE`:
  /// that form deletes and reinserts, which for a row with a foreign key means
  /// firing cascades for a row that is not going anywhere.
  void put(BenchmarkRun run) {
    _write(run);
    _prune(run.serverId);
    if (run.status != BenchmarkStatus.running && _table == instance._table) SyncRecorder.record(c, run.id);
  }

  void _write(BenchmarkRun run) {
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
  }

  /// Drops this server's oldest runs past [historyLimit].
  ///
  /// A running row is never pruned, whatever its age: it names a directory on a
  /// server that still has a process in it, and losing the row is losing the
  /// only way to reach either.
  void _prune(String serverId) {
    final gone = [
      for (final row in _db.select(
        'SELECT id FROM $_table WHERE server_id = ? AND status != ? '
        'ORDER BY started_at DESC LIMIT -1 OFFSET ?;',
        [serverId, BenchmarkStatus.running.name, historyLimit],
      ))
        row['id'] as String,
    ];
    for (final id in gone) {
      remove(id);
    }
  }

  void remove(String id) {
    _db.execute('DELETE FROM $_table WHERE id = ?;', [id]);
    if (_table == instance._table) SyncRecorder.record(c, id);
  }

  /// The finished run [id] as an op carries it; null when it is not here.
  Map<String, Object?>? read(String id) {
    final rows = _db.select('SELECT $_columns FROM $_table WHERE id = ? AND status != ?;', [id, BenchmarkStatus.running.name]);
    return rows.isEmpty ? null : {...rows.first};
  }

  /// Writes the runs [ops] carry ([read]), or removes them, each recorded at
  /// its op's stamp. One of a server not here yet (the files' sync reads
  /// each device's changes apart, so the server may come later) is kept
  /// for [retry]; one of a server removed here is left out.
  void install(List<({String c, String id, String h, Object? d})> ops) {
    for (final op in ops) {
      _drop(op.id);
      SyncRecorder.receiving(op.h, () {
        final d = op.d;
        if (d is! Map) return remove(op.id);
        final server = d['server_id'];
        if (_db.select('SELECT 1 FROM server WHERE id = ?;', [server]).isEmpty) {
          final removed = _db.select('SELECT 1 FROM tombstone WHERE tbl = ? AND row_id = ?;', ['server', server]).isNotEmpty;
          if (!removed) _keep(op);
          return;
        }
        final run = _fromRow(d.cast());
        if (run == null || run.id != op.id || run.status == BenchmarkStatus.running) return;
        put(run);
      });
    }
  }

  static const _retryPrefix = 'retry:$c:';

  /// Installs what [install] kept once its server is here, unless a newer
  /// record of the run came since.
  void retry() {
    final rows = _db.select('SELECT k, v FROM sync_state WHERE k LIKE ?;', ['$_retryPrefix%']);
    if (rows.isEmpty) return;
    final due = <({String c, String id, String h, Object? d})>[];
    for (final row in rows) {
      final id = (row['k'] as String).substring(_retryPrefix.length);
      final Object? kept;
      try {
        kept = json.decode(row['v'] as String);
      } catch (_) {
        _drop(id);
        continue;
      }
      if (kept case {'h': final String h, 'd': final Map d}) {
        final current = SyncRecorder.stampsOf([(c, id)])[(c, id)];
        if (current != null && current.compareTo(h) >= 0) {
          _drop(id);
        } else if (_db.select('SELECT 1 FROM server WHERE id = ?;', [d['server_id']]).isNotEmpty ||
            _db.select('SELECT 1 FROM tombstone WHERE tbl = ? AND row_id = ?;', ['server', d['server_id']]).isNotEmpty) {
          due.add((c: c, id: id, h: h, d: d));
        }
      } else {
        _drop(id);
      }
    }
    if (due.isNotEmpty) install(due);
  }

  void _keep(({String c, String id, String h, Object? d}) op) => _db.execute(
    'INSERT INTO sync_state (k, v) VALUES (?, ?) ON CONFLICT (k) DO UPDATE SET v = excluded.v;',
    ['$_retryPrefix${op.id}', json.encode({'h': op.h, 'd': op.d})],
  );

  void _drop(String id) => _db.execute('DELETE FROM sync_state WHERE k = ?;', ['$_retryPrefix$id']);

  /// The finished runs, for a migration seeding their records: id and when
  /// each finished.
  static Iterable<(String, int)> finished() => [
    for (final row in SqliteDb.instance.select(
      'SELECT id, COALESCE(finished_at, started_at) AS at FROM benchmark_run WHERE status != ?;',
      [BenchmarkStatus.running.name],
    ))
      (row['id'] as String, row['at'] as int),
  ];

  /// Every run of every server, newest first.
  ///
  /// What the benchmark tab lists. A run belongs to a server, but the tab does
  /// not: keeping the history whole is what lets two machines be read against
  /// each other, which is most of the reason to store a result at all.
  List<BenchmarkRun> all() {
    final rows = _db.select(
      'SELECT $_columns FROM $_table ORDER BY started_at DESC;',
    );
    return [
      for (final row in rows) ?_fromRow(row),
    ];
  }
}
