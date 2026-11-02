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

import '../../helpers/rust_lib_helper.dart';
import '../../helpers/spi_fixture.dart';

/// How the list is ordered, for the three fields that ask the machines.
///
/// Name and the stored arrangement are answered by the record alone and were
/// the only two with any coverage. These three read a status, which is where
/// the interesting part is: what a server that has not answered sorts as, and
/// that two with the same reading keep the order they were in.
void main() {
  // Uptime is read back by Rust.
  setUpAll(initRustLibForTest);
  ServerState state(
    String id, {
    double? cpu,
    double memPercentOver = 0,
    int? sampledAtMs,
    /// What `uptime(1)`'s output was formatted to, as the parsers keep it —
    /// read back by Rust (`common::uptime_seconds`). Null leaves the field unset,
    /// which is what a machine that has not answered, or one whose `uptime`
    /// could not be read, looks like from here.
    String? uptime,
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
    if (uptime != null) ss.more[StatusCmdType.uptime] = uptime;
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

  test('names equal once case-folded keep the arrangement', () {
    // Forty, not three: under 32 elements `sort` is an insertion sort and
    // happens to be stable, which is how this passed without a tie.
    final order = [for (var i = 0; i < 40; i++) 's$i'];
    final servers = {
      for (final (i, id) in order.indexed)
        id: spiFixture(id: id, name: i.isEven ? 'Alpha' : 'alpha', ip: 'h'),
    };
    for (final ascending in [true, false]) {
      expect(
        ServerSortOrder(
          ServerSortField.name,
          ascending: ascending,
        ).apply(order, servers, (_) => throw StateError('reads no status')),
        order,
      );
    }
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

  test('uptime orders by how long the machine has been up', () {
    // The value the app holds is `uptime(1)`'s wording, not a duration, so
    // this is also the test that the shapes it prints are read at all. Order
    // is by the machine, not by the string: `5 days` is longer than `2:34`
    // even though it sorts higher as text.
    final states = {
      'old': state('old', uptime: '61 days, 18:16'),
      'mid': state('mid', uptime: '5 days'),
      'new': state('new', uptime: '2:34'),
      'newest': state('newest', uptime: '34 min'),
    };
    expect(
      sort(ServerSortField.uptime, ['old', 'mid', 'new', 'newest'], states),
      ['newest', 'new', 'mid', 'old'],
      reason: 'shortest first',
    );
    expect(
      sort(
        ServerSortField.uptime,
        ['old', 'mid', 'new', 'newest'],
        states,
        ascending: false,
      ),
      ['old', 'mid', 'new', 'newest'],
      reason: 'and the other direction is the exact reverse',
    );
  });

  test('an uptime that cannot be read sorts last, not first', () {
    // Two ways to have no number: never answered, and answered with something
    // the parser does not know. Neither is a machine that just came back, and
    // a list whose question is "what is newly up" must not be led by them.
    final states = {
      'up': state('up', uptime: '2:34'),
      'never': state('never', conn: ServerConn.disconnected),
      'garbled': state('garbled', uptime: 'invalid uptime format'),
    };
    expect(
      sort(ServerSortField.uptime, ['never', 'up', 'garbled'], states),
      ['up', 'never', 'garbled'],
      reason: 'the two unknowns keep their arrangement at the end',
    );
    // A sentinel key would flip to the front here; no key stays at the end.
    expect(
      sort(
        ServerSortField.uptime,
        ['never', 'up', 'garbled'],
        states,
        ascending: false,
      ),
      ['up', 'never', 'garbled'],
      reason: 'longest first is not led by the unknowns either',
    );
  });

  test('days are not the whole answer', () {
    // Two machines up the same number of days differ by what follows, and a
    // day count alone keyed them equal, leaving the arrangement to decide.
    final states = {
      'later': state('later', uptime: '5 days, 1:00'),
      'earlier': state('earlier', uptime: '5 days, 20:00'),
    };
    expect(
      sort(ServerSortField.uptime, ['earlier', 'later'], states),
      ['later', 'earlier'],
    );
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
