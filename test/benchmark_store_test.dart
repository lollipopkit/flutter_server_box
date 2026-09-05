/// The record of every yabs run.
///
/// Two things it has to get right, both from `m010`'s playbook. m020 has to
/// produce the same table Drift creates for a fresh install — `createTables` is
/// `IF NOT EXISTS` throughout, so an upgrading install only ever gets the
/// migration's version and `tables_schema_test.dart` only ever sees Drift's.
/// And the store has to survive reading a row a later build wrote.
library;

import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';
import 'package:server_box/data/model/server/benchmark/yabs_options.dart';
import 'package:server_box/data/store/benchmark.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m020_benchmark_runs.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/tables.dart';

import 'helpers/test_db.dart';

/// See `server_dist_store_test.dart`: the constraints are the half that matters
/// and the half a column list cannot see.
({
  List<(String, String, bool, int)> columns,
  List<(String, String, String, String)> foreignKeys,
})
_schemaOf(String table) => (
  columns: [
    for (final row in SqliteDb.instance.select('PRAGMA table_info($table);'))
      (
        row['name'] as String,
        row['type'] as String,
        (row['notnull'] as int) == 1,
        row['pk'] as int,
      ),
  ],
  foreignKeys: [
    for (final row in SqliteDb.instance.select(
      'PRAGMA foreign_key_list($table);',
    ))
      (
        row['table'] as String,
        row['from'] as String,
        row['to'] as String,
        row['on_delete'] as String,
      ),
  ],
);

BenchmarkRun _run(
  String id, {
  String serverId = 'srv',
  BenchmarkStatus status = BenchmarkStatus.completed,
  DateTime? startedAt,
  String? resultJson,
  YabsOptions options = const YabsOptions(),
}) {
  return BenchmarkRun(
    id: id,
    serverId: serverId,
    startedAt: startedAt ?? DateTime.fromMillisecondsSinceEpoch(1000),
    status: status,
    options: options,
    runDir: '/tmp/$id',
    resultJson: resultJson,
    exitCode: status == BenchmarkStatus.completed ? 0 : null,
  );
}

void main() {
  group('the schema step', () {
    setUp(() => SqliteDb.openInMemory());
    tearDown(() async {
      await closeTables();
      await SqliteDb.close();
    });

    // The three edits a schema step is, asserted separately, because two of
    // them are invisible in the step's own test: missing the version bump
    // leaves every install on the old version with a green suite, and missing
    // the registration throws `Missing schema migration from vN` at launch on
    // a user's device.
    test('is registered, and the version was bumped past it', () {
      expect(const BenchmarkRunsMigration().from, 20);
      expect(SchemaVersion.current, 21);
      expect(
        kSchemaMigrations.map((m) => m.from),
        contains(20),
        reason: 'an unregistered step throws at launch, not here',
      );
      expect(
        kSchemaMigrations.last.from,
        SchemaVersion.current - 1,
        reason: 'the chain has to reach the current version',
      );
    });

    test('creates a table Drift would have created identically', () async {
      await createTables(SqliteDb.instance);
      final fromDrift = _schemaOf('benchmark_run');
      expect(fromDrift.columns, isNotEmpty, reason: 'Drift has to make it');
      expect(
        fromDrift.foreignKeys,
        contains(('server', 'server_id', 'id', 'CASCADE')),
        reason: 'a run of a deleted server is a row nothing can ever read',
      );

      await closeTables();
      await SqliteDb.close();
      SqliteDb.openInMemory();
      await createTables(SqliteDb.instance);
      SqliteDb.instance.execute('DROP TABLE benchmark_run;');
      await const BenchmarkRunsMigration().apply();

      final fromMigration = _schemaOf('benchmark_run');
      const why = 'an upgrading install only ever gets this version';
      expect(fromMigration.columns, fromDrift.columns, reason: why);
      expect(fromMigration.foreignKeys, fromDrift.foreignKeys, reason: why);
    });

    test('and running it again on the table it made changes nothing', () async {
      await createTables(SqliteDb.instance);
      final before = _schemaOf('benchmark_run');
      await const BenchmarkRunsMigration().apply();
      expect(_schemaOf('benchmark_run').columns, before.columns);
    });

    test('the table is known but is not synced', () {
      expect(Tables.names, contains('benchmark_run'));
      // A measurement is not an edit anyone made — `conn_stat`'s reason.
      expect(Tables.syncRoots, isNot(contains('benchmark_run')));
    });
  });

  group('the store', () {
    late BenchmarkStore store;

    setUp(() async {
      SqliteDb.openInMemory();
      await createTables(SqliteDb.instance);
      SqliteDb.instance.execute('PRAGMA foreign_keys = ON;');
      SqliteDb.instance.execute(
        "INSERT INTO server (id, name, ssh_ip) VALUES ('srv', 'prod', '10.0.0.1');",
      );
      SqliteDb.instance.execute(
        "INSERT INTO server (id, name, ssh_ip) VALUES ('srv2', 'web', '10.0.0.2');",
      );
      store = BenchmarkStore.forTest();
    });

    tearDown(closeTestDb);

    test('keeps a run and reads it back whole', () {
      const options = YabsOptions(cpu: true, workDir: '/mnt/data');
      store.put(_run('a', options: options, resultJson: '{"version":"v1"}'));

      final read = store.get('a');
      expect(read, isNotNull);
      expect(read!.options, options);
      expect(read.runDir, '/tmp/a');
      expect(read.result?.version, 'v1');
    });

    test('a second write updates rather than replacing the row', () {
      store.put(_run('a', status: BenchmarkStatus.running));
      store.put(
        store.get('a')!.copyWith(
          status: BenchmarkStatus.completed,
          resultJson: '{"version":"v2"}',
          exitCode: 0,
        ),
      );

      expect(store.forServer('srv').length, 1);
      expect(store.get('a')!.status, BenchmarkStatus.completed);
      expect(store.get('a')!.result?.version, 'v2');
    });

    test('history is per server, newest first', () {
      store.put(
        _run('old', startedAt: DateTime.fromMillisecondsSinceEpoch(1000)),
      );
      store.put(
        _run('new', startedAt: DateTime.fromMillisecondsSinceEpoch(9000)),
      );
      store.put(_run('other', serverId: 'srv2'));

      expect(store.forServer('srv').map((e) => e.id), ['new', 'old']);
      expect(store.forServer('srv2').map((e) => e.id), ['other']);
    });

    test('the run in flight is what a reopened page picks up', () {
      store.put(_run('done'));
      expect(store.activeFor('srv'), isNull);

      store.put(_run('going', status: BenchmarkStatus.running));
      expect(store.activeFor('srv')?.id, 'going');
    });

    test('deleting the server takes its runs', () {
      store.put(_run('a'));
      SqliteDb.instance.execute("DELETE FROM server WHERE id = 'srv';");
      expect(store.forServer('srv'), isEmpty);
    });

    test('history is capped, and a running row is never the one dropped', () {
      // The oldest row is also the one still going, so age alone would take it
      // — and with it the only record of where the run lives on the far side.
      store.put(
        _run(
          'going',
          status: BenchmarkStatus.running,
          startedAt: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      );
      for (var i = 0; i < BenchmarkStore.historyLimit + 5; i++) {
        store.put(
          _run('r$i', startedAt: DateTime.fromMillisecondsSinceEpoch(100 + i)),
        );
      }

      final kept = store.forServer('srv');
      expect(kept.where((e) => e.id == 'going'), hasLength(1));
      expect(
        kept.where((e) => e.status != BenchmarkStatus.running),
        hasLength(BenchmarkStore.historyLimit),
      );
    });

    test('a status a later build wrote is skipped, not guessed at', () {
      // Statuses are stored by name so they outlive the build that wrote them.
      // A name this build does not know might mean "running", so the row is
      // left out rather than shown as something it may not be.
      SqliteDb.instance.execute(
        'INSERT INTO benchmark_run '
        '(id, server_id, started_at, status, options, run_dir) '
        "VALUES ('x', 'srv', 1, 'paused', '{}', '/tmp/x');",
      );
      expect(store.forServer('srv'), isEmpty);
    });

    test('unreadable options do not cost the result', () {
      SqliteDb.instance.execute(
        'INSERT INTO benchmark_run '
        '(id, server_id, started_at, status, options, run_dir, result_json) '
        "VALUES ('x', 'srv', 1, 'completed', 'not json', '/tmp/x', "
        '\'{"version":"v9"}\');',
      );
      final read = store.get('x');
      expect(read, isNotNull);
      expect(read!.options, const YabsOptions());
      expect(read.result?.version, 'v9');
    });

    test('a result that is not JSON leaves the raw text reachable', () {
      // yabs assembles its output with `+=` on a shell string, so a value
      // containing a quote produces a document no parser accepts. Losing a
      // fifteen-minute run over that would be the wrong trade.
      store.put(_run('a', resultJson: '{"distro":"Ubuntu "22.04" LTS"}'));
      final read = store.get('a')!;
      expect(read.result, isNull);
      expect(read.hasResult, isTrue);
      expect(read.resultJson, contains('22.04'));
    });

    test('options survive a round trip through JSON', () {
      const options = YabsOptions(
        disk: false,
        cpu: true,
        geekbenchVersion: GeekbenchVersion.v7,
        ipInfo: true,
        reducedNetwork: false,
        customIperfServers: 'h:1-2:n:l:IPv4',
        workDir: '/mnt/nvme',
      );
      expect(
        YabsOptions.fromJson(
          json.decode(json.encode(options.toJson())) as Map<String, dynamic>,
        ),
        options,
      );
    });

    test('forgetting one server leaves the other alone', () {
      store.put(_run('a'));
      store.put(_run('b', serverId: 'srv2'));

      store.removeForServer('srv');

      expect(store.forServer('srv'), isEmpty);
      expect(store.forServer('srv2'), hasLength(1));
    });
  });
}
