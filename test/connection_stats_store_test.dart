import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/connection_stat.dart';
import 'package:server_box/data/store/connection_stats.dart';

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
    SqliteDb.openInMemory();
    store = ConnectionStatsStore.instance;
    await store.init();
    await store.clearAll();
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

  test('anything older than 30 days is dropped as it is written', () async {
    // The age bound runs on every write, so an already-expired record does not
    // survive its own insert. The K-V version could only apply this during a
    // full rebuild at launch, so a long-running app kept expired rows until it
    // was restarted.
    await store.recordConnection(
      stat('a', at: DateTime.now().subtract(const Duration(days: 31))),
    );
    expect(store.getConnectionHistory('a'), isEmpty);

    await store.recordConnection(stat('a', at: base));
    expect(store.getConnectionHistory('a'), hasLength(1));
  });

  test('recording the same attempt twice does not double it', () async {
    final at = base;
    await store.recordConnection(stat('a', at: at));
    await store.recordConnection(stat('a', at: at, name: 'renamed'));

    final history = store.getConnectionHistory('a');
    expect(history.length, 1);
    expect(history.single.serverName, 'renamed');
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

    final summary = store.getServerStats('a', 'srv');
    expect(summary.totalAttempts, 3);
    expect(summary.successCount, 2);
    expect(summary.failureCount, 1);
    expect(summary.successRate, closeTo(2 / 3, 1e-9));
    expect(summary.lastSuccessTime, base.add(const Duration(minutes: 2)));
    expect(summary.lastFailureTime, base.add(const Duration(minutes: 1)));
  });

  test('a server with no attempts summarises as empty, not as an error', () {
    final summary = store.getServerStats('nobody', 'srv');
    expect(summary.totalAttempts, 0);
    expect(summary.successRate, 0.0);
    expect(summary.recentConnections, isEmpty);
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
}
