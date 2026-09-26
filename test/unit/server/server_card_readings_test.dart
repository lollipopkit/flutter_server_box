import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/temp.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/page/server/card/metric.dart';

import '../../helpers/spi_fixture.dart';

/// Which readings a card draws, and in which order.
///
/// The card grows into the detail page, which draws every reading in the
/// order of `ServerCardReadings.all`. The rows a card draws at rest must be a
/// subsequence of that order: a row whose position differs between the two
/// changes place on the first frame of the movement and again on the last.
void main() {
  ServerState state({
    bool swap = false,
    bool net = false,
    bool temp = false,
    bool diskIo = false,
  }) {
    final io = DiskIO();
    if (diskIo) {
      io.update([
        DiskIOPiece(dev: 'sda', sectorsRead: 0, sectorsWrite: 0, time: 10),
      ]);
      io.update([
        DiskIOPiece(dev: 'sda', sectorsRead: 800, sectorsWrite: 800, time: 20),
      ]);
    }
    final status = ServerStatus(
      cpu: Cpus(),
      mem: const Memory(total: 1048576, free: 524288, avail: 524288),
      disk: [
        Disk(
          path: '/dev/sda1',
          mount: '/',
          usedPercent: 40,
          used: BigInt.from(4000000),
          size: BigInt.from(10000000),
          avail: BigInt.from(6000000),
        ),
      ],
      tcp: const Conn(maxConn: 0, fail: 0),
      netSpeed: NetSpeed()
        ..update([
          if (net) NetSpeedPart('eth0', BigInt.zero, BigInt.zero, 10),
        ]),
      swap: swap
          ? const Swap(total: 1048576, free: 786432, cached: 0)
          : const Swap(total: 0, free: 0, cached: 0),
      temps: Temperatures()..setAll({if (temp) 'coretemp': 41.0}),
      system: SystemType.linux,
      diskIO: io,
    );
    return ServerState(
      spi: spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u'),
      status: status,
      conn: ServerConn.finished,
    );
  }

  List<ServerMetricKind> kinds(List<ServerMetric> of) =>
      of.map((m) => m.kind).toList();

  /// [part] in the order its members have in [whole].
  List<ServerMetricKind> inOrderOf(
    List<ServerMetricKind> whole,
    List<ServerMetricKind> part,
  ) => whole.where(part.contains).toList();

  test('the card draws its readings in the order the page does', () {
    // One case per reading that can take the slot that varies. Swap sits
    // before the disk on the page, and a sensor after the network.
    for (final srv in [
      state(net: true, swap: true),
      state(net: true, swap: true, diskIo: true),
      state(net: true, swap: true, temp: true),
      state(net: true, swap: true, diskIo: true, temp: true),
    ]) {
      final r = serverCardReadings(srv);
      final all = kinds(r.all);
      final shown = kinds(r.shown);
      expect(shown, inOrderOf(all, shown), reason: 'of $all');
    }
  });

  test('which reading takes the slot that varies is unchanged', () {
    ServerMetricKind extra(ServerState srv) => kinds(serverCardReadings(srv).shown)
        .firstWhere(
          (k) => !const {
            ServerMetricKind.cpu,
            ServerMetricKind.mem,
            ServerMetricKind.disk,
            ServerMetricKind.net,
          }.contains(k),
        );

    expect(extra(state(net: true, swap: true)), ServerMetricKind.swap);
    expect(
      extra(state(net: true, swap: true, diskIo: true)),
      ServerMetricKind.diskIo,
    );
    expect(
      extra(state(net: true, swap: true, diskIo: true, temp: true)),
      ServerMetricKind.temp,
    );
  });

  test('no reading is drawn twice, and the five slots are what is drawn', () {
    // Nothing but what every card draws: the slot that varies has no
    // candidate, and the network must not be taken for one.
    final r = serverCardReadings(state(net: true));
    expect(kinds(r.shown), [
      ServerMetricKind.cpu,
      ServerMetricKind.mem,
      ServerMetricKind.disk,
      ServerMetricKind.net,
    ]);
    // Everything the machine reports has a place, so nothing is left over.
    expect(r.shown.length, r.all.length);

    final full = serverCardReadings(
      state(net: true, swap: true, diskIo: true, temp: true),
    );
    expect(kinds(full.shown).toSet().length, full.shown.length);
    expect(full.shown.length, 5);
    // A sixth reading exists and is not in the slots. How many are unseen is
    // counted from what is drawn, not from this — see `ServerCardReadings`,
    // which has no count of its own for that reason.
    expect(full.all.length, greaterThan(full.shown.length));
  });
}
