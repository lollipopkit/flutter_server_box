import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/connection_stat.dart';
import 'package:server_box/data/store/connection_stats.dart';

import 'helpers/test_db.dart';

/// The bounds this table keeps itself inside, which used to be four hand-written
/// passes over a K-V store and are now two `DELETE`s.
void main() {
  late ConnectionStatsStore store;

  /// Anchored to now, not to a literal date: rows older than 30 days are
  /// dropped on the next write, so a fixed date silently empties the table as
  /// soon as it is more than a month in the past.
  /// Truncated to milliseconds, which is what the column holds. A connection
  /// attempt does not need microseconds, but a test comparing `DateTime`s does
  /// need to compare the same precision.
  final base = DateTime.fromMillisecondsSinceEpoch(
    DateTime.now()
        .subtract(const Duration(days: 1))
        .millisecondsSinceEpoch,
  );

  setUp(() async {
    await openTestDb();
    // `server_id` is a foreign key now, so the servers these rows belong to
    // have to exist — an attempt against a server that is gone has nothing to
    // be a statistic of.
    SqliteDb.instance.execute(
      'INSERT INTO server (id, name, ssh_ip) VALUES '
      "('a', 'a', '10.0.0.1'), ('b', 'b', '10.0.0.2'), "
      "('s0', 's0', '10.0.1.0'), ('s1', 's1', '10.0.1.1'), "
      "('s2', 's2', '10.0.1.2'), ('s3', 's3', '10.0.1.3');",
    );
    store = ConnectionStatsStore.instance;
    await store.init();
  });

  tearDown(SqliteDb.close);

  ConnectionStat stat(
    String serverId, {
    required DateTime at,
    ConnectionResult result = ConnectionResult.success,
    String name = 'srv',
  }) => ConnectionStat(
    serverId: serverId,
    serverName: name,
    timestamp: at,
    result: result,
    durationMs: 1,
  );

  test('history comes back newest first', () async {
    for (var i = 0; i < 3; i++) {
      await store.recordConnection(
        stat('a', at: base.add(Duration(minutes: i))),
      );
    }

    final history = store.getConnectionHistory('a');
    expect(history.length, 3);
    expect(history.first.timestamp, base.add(const Duration(minutes: 2)));
    expect(history.last.timestamp, base);
  });

  test('one server does not see another', () async {
    await store.recordConnection(stat('a', at: base));
    await store.recordConnection(stat('b', at: base));

    expect(store.getConnectionHistory('a').single.serverId, 'a');
    expect(store.getConnectionHistory('b').single.serverId, 'b');
  });

  test('a server keeps its newest 100 and no more', () async {
    for (var i = 0; i < 130; i++) {
      await store.recordConnection(
        stat('a', at: base.add(Duration(minutes: i))),
      );
    }

    final history = store.getConnectionHistory('a');
    expect(history.length, 100);
    // The 30 oldest went, not an arbitrary 30.
    expect(history.last.timestamp, base.add(const Duration(minutes: 30)));
    expect(history.first.timestamp, base.add(const Duration(minutes: 129)));
  });

  test('the cap is per server, not overall', () async {
    for (var i = 0; i < 100; i++) {
      await store.recordConnection(
        stat('a', at: base.add(Duration(minutes: i))),
      );
    }
    await store.recordConnection(stat('b', at: base));

    expect(store.getConnectionHistory('a').length, 100);
    expect(store.getConnectionHistory('b').length, 1);
  });

  test('anything older than 30 days is swept at init', () async {
    // The age bound is not applied per write: recording happens on every
    // connection attempt against every server, and paying for a whole-table
    // sweep each time bought nothing in the common case where nothing has
    // expired. It runs once per launch instead.
    await store.recordConnection(
      stat('a', at: DateTime.now().subtract(const Duration(days: 31))),
    );
    await store.recordConnection(stat('a', at: base));
    expect(store.getConnectionHistory('a'), hasLength(2));

    await store.init();

    final kept = store.getConnectionHistory('a');
    expect(kept, hasLength(1));
    expect(kept.single.timestamp, base);
  });

  test('two attempts in the same millisecond are two rows', () async {
    // They used to be one: the id was `<serverId>_<millis>`, so the second
    // attempt overwrote the first and the counters under-reported. The id is
    // generated now, and this is what that buys.
    final at = base;
    await store.recordConnection(stat('a', at: at));
    await store.recordConnection(stat('a', at: at, name: 'renamed'));

    final history = store.getConnectionHistory('a');
    expect(history.length, 2);
    expect(history.map((e) => e.serverName), containsAll(['srv', 'renamed']));
  });

  test('an attempt against a server that is gone is not recorded', () async {
    // `server_id` is a foreign key. A status refresh can land after the user
    // deleted the server, and the row would only ever be orphaned statistics.
    await store.recordConnection(stat('deleted-server', at: base));
    expect(store.getConnectionHistory('deleted-server'), isEmpty);
  });

  test('the summary counts both outcomes', () async {
    await store.recordConnection(stat('a', at: base));
    await store.recordConnection(
      stat(
        'a',
        at: base.add(const Duration(minutes: 1)),
        result: ConnectionResult.timeout,
      ),
    );
    await store.recordConnection(
      stat('a', at: base.add(const Duration(minutes: 2))),
    );

    final summary = store.getAllServerStats().single;
    expect(summary.serverId, 'a');
    expect(summary.serverName, 'srv');
    expect(summary.totalAttempts, 3);
    expect(summary.successCount, 2);
    expect(summary.failureCount, 1);
    expect(summary.successRate, closeTo(2 / 3, 1e-9));
    expect(summary.lastSuccessTime, base.add(const Duration(minutes: 2)));
    expect(summary.lastFailureTime, base.add(const Duration(minutes: 1)));
  });

  test('a server with no attempts is absent from the list, not an error', () async {
    // Rows for `a` only, so the list is non-empty and the assertion is about
    // `b` being left out of it. With nothing recorded at all `getAllServerStats`
    // returns early on `totals.isEmpty`, and every server is absent from the
    // empty list — which a stub answering `[]` would pass just as well.
    await store.recordConnection(stat('a', at: base));

    final all = store.getAllServerStats();
    expect(all.map((e) => e.serverId), ['a']);
    expect(all.where((e) => e.serverId == 'b'), isEmpty);
  });

  test('the overall list names each server as it was named last', () async {
    await store.recordConnection(stat('a', at: base, name: 'old-name'));
    await store.recordConnection(
      stat('a', at: base.add(const Duration(minutes: 1)), name: 'new-name'),
    );
    await store.recordConnection(stat('b', at: base, name: 'other'));

    final all = store.getAllServerStats();
    expect(all.length, 2);
    expect(
      all.firstWhere((e) => e.serverId == 'a').serverName,
      'new-name',
      reason: 'a rename leaves the old name on the older rows',
    );
  });

  test('clearing one server leaves the others', () async {
    await store.recordConnection(stat('a', at: base));
    await store.recordConnection(stat('b', at: base));

    await store.clearServerStats('a');

    expect(store.getConnectionHistory('a'), isEmpty);
    expect(store.getConnectionHistory('b'), hasLength(1));
  });

  test('clearing everything leaves nothing', () async {
    await store.recordConnection(stat('a', at: base));
    await store.clearAll();
    expect(store.getAllServerStats(), isEmpty);
  });

  group('the overall list, which is two queries regardless of server count', () {
    test('the overall list aggregates each server correctly', () async {
      for (var server = 0; server < 4; server++) {
        for (var i = 0; i < 25; i++) {
          await store.recordConnection(
            stat(
              's$server',
              at: base.add(Duration(minutes: i)),
              result: i.isEven
                  ? ConnectionResult.success
                  : ConnectionResult.timeout,
              name: 'name-$server',
            ),
          );
        }
      }

      final all = {
        for (final e in store.getAllServerStats()) e.serverId: e,
      };
      expect(all.keys, hasLength(4));

      // Even minutes succeeded and odd ones timed out, so the aggregates are
      // known up front rather than agreed between two implementations.
      for (var server = 0; server < 4; server++) {
        final id = 's$server';
        final summary = all[id]!;

        expect(summary.serverName, 'name-$server', reason: id);
        expect(summary.totalAttempts, 25, reason: id);
        expect(summary.successCount, 13, reason: id);
        expect(summary.failureCount, 12, reason: id);
        expect(summary.successRate, closeTo(13 / 25, 1e-12), reason: id);
        expect(
          summary.lastSuccessTime,
          base.add(const Duration(minutes: 24)),
          reason: id,
        );
        expect(
          summary.lastFailureTime,
          base.add(const Duration(minutes: 23)),
          reason: id,
        );
        expect(summary.recentConnections, hasLength(20), reason: id);
      }
    });

    test('each server carries at most 20 recent attempts, newest first', () async {
      for (var i = 0; i < 40; i++) {
        await store.recordConnection(
          stat('a', at: base.add(Duration(minutes: i))),
        );
      }

      final recent = store.getAllServerStats().single.recentConnections;
      expect(recent, hasLength(20));
      expect(recent.first.timestamp, base.add(const Duration(minutes: 39)));
      expect(recent.last.timestamp, base.add(const Duration(minutes: 20)));
    });

    test('a rename shows the newest name, not the oldest row\'s', () async {
      await store.recordConnection(stat('a', at: base, name: 'before'));
      await store.recordConnection(
        stat('a', at: base.add(const Duration(minutes: 1)), name: 'after'),
      );

      expect(store.getAllServerStats().single.serverName, 'after');
    });

    test('a server with only failures reports no last success', () async {
      await store.recordConnection(
        stat('a', at: base, result: ConnectionResult.authFailed),
      );

      final summary = store.getAllServerStats().single;
      expect(summary.successCount, 0);
      expect(summary.successRate, 0.0);
      expect(summary.lastSuccessTime, isNull);
      expect(summary.lastFailureTime, base);
    });
  });
}
