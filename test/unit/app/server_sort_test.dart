import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/server_sort.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/temp.dart';
import 'package:server_box/data/provider/server/single.dart';

import '../../helpers/spi_fixture.dart';

/// How the list is ordered, for the three fields that ask the machines.
///
/// Name and the stored arrangement are answered by the record alone and were
/// the only two with any coverage. These three read a status, which is where
/// the interesting part is: what a server that has not answered sorts as, and
/// that two with the same reading keep the order they were in.
void main() {
  ServerState state(
    String id, {
    double? cpu,
    double memPercentOver = 0,
    int? sampledAtMs,
    ServerConn conn = ServerConn.finished,
  }) {
    final ss = ServerStatus(
      cpu: Cpus(),
      // `mem.total` of 100 makes "used" a percentage directly, so a reading
      // over the alert line is one number rather than a calculation.
      mem: memPercentOver > 0
          ? Memory(
              total: 100,
              free: (100 - memPercentOver).round(),
              avail: (100 - memPercentOver).round(),
            )
          : const Memory(total: 0, free: 0, avail: 0),
      disk: const [],
      tcp: const Conn(maxConn: 0, fail: 0),
      netSpeed: NetSpeed(),
      swap: const Swap(total: 0, free: 0, cached: 0),
      temps: Temperatures(),
      system: SystemType.linux,
      diskIO: DiskIO(),
    );
    ss.more[StatusCmdType.uptime] = 'up';
    if (sampledAtMs != null) ss.history.add(timeMs: sampledAtMs, cpu: cpu);
    return ServerState(
      spi: spiFixture(id: id, name: id, ip: 'h', user: 'u'),
      status: ss,
      conn: conn,
    );
  }

  List<String> sort(
    ServerSortField field,
    List<String> order,
    Map<String, ServerState> states, {
    bool ascending = true,
  }) {
    return ServerSortOrder(field, ascending: ascending).apply(
      order,
      {for (final e in states.entries) e.key: e.value.spi},
      (id) => states[id]!,
    );
  }

  test('the arrangement is the tie, so equal readings do not shuffle', () {
    // `sort` is not stable: without an explicit tie two servers reading the
    // same thing swap places between rebuilds, which is a list that moves on
    // its own while nothing is happening.
    final states = {
      for (final id in ['a', 'b', 'c']) id: state(id),
    };
    expect(sort(ServerSortField.alert, ['a', 'b', 'c'], states), [
      'a',
      'b',
      'c',
    ]);
  });

  test('alerts first is a partition, not a comparison', () {
    final states = {
      'quiet': state('quiet'),
      'hot': state('hot', memPercentOver: 90),
      'also': state('also', memPercentOver: 99),
    };
    expect(sort(ServerSortField.alert, ['quiet', 'hot', 'also'], states), [
      'hot',
      'also',
      'quiet',
    ]);
    // And reversing it is not offered, because "what is wrong, last" is not a
    // thing anyone wants.
    expect(ServerSortField.alert.directional, isFalse);
  });

  test('a machine that has never answered sorts last by uptime', () {
    // Shortest first answers something — a machine that has just come back is
    // news — and one with no samples at all has no uptime to be short.
    final states = {
      'old': state('old', sampledAtMs: 1000),
      'new': state('new', sampledAtMs: 9000),
      'never': state('never', conn: ServerConn.disconnected),
    };
    expect(sort(ServerSortField.uptime, ['old', 'new', 'never'], states), [
      'new',
      'old',
      'never',
    ]);
  });

  test('only the arrangement may be dragged into another one', () {
    // A drag under a comparison moves a card and has the comparison put it
    // straight back, which reads as the drag having failed.
    expect(ServerSortField.manual.reorderable, isTrue);
    for (final field in ServerSortField.values) {
      if (field == ServerSortField.manual) continue;
      expect(field.reorderable, isFalse, reason: field.name);
    }
  });

  test('two fields need nothing from the machines', () {
    // What decides whether the list watches every server's readings, which is
    // a rebuild of the whole page on every poll.
    expect(ServerSortField.manual.readsStatus, isFalse);
    expect(ServerSortField.name.readsStatus, isFalse);
    expect(ServerSortField.cpu.readsStatus, isTrue);
    expect(ServerSortField.alert.readsStatus, isTrue);
    expect(ServerSortField.uptime.readsStatus, isTrue);
    expect(ServerSortField.status.readsStatus, isTrue);
  });
}
