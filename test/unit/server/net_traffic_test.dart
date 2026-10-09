import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/temp.dart';
import 'package:server_box/data/provider/server/data_source.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/detail/metric_devices.dart';

import '../../helpers/spi_fixture.dart';

NetSpeedPart _part(String dev, int inB, int outB, int time) =>
    NetSpeedPart(dev, BigInt.from(inB), BigInt.from(outB), time);

void main() {
  group('cumulativeBytes', () {
    test('weighs each rate by the gap since the sample before it', () {
      expect(
        cumulativeBytes([0, 1000, 3000, 4000], [10, 10, 5, 20]),
        [0, 10, 20, 40],
      );
    });

    test('a missing rate is a gap, and the one after it adds nothing', () {
      expect(
        cumulativeBytes([0, 1000, 2000, 3000, 4000], [10, 10, null, 10, 10]),
        [0, 10, null, 10, 20],
      );
    });
  });

  group('network devices', () {
    ServerState state(List<List<NetSpeedPart>> samples) {
      final ns = NetSpeed();
      final status = ServerStatus(
        cpu: Cpus(),
        mem: const Memory(total: 0, free: 0, avail: 0),
        disk: const [],
        tcp: const Conn(maxConn: 0, fail: 0),
        netSpeed: ns,
        swap: const Swap(total: 0, free: 0, cached: 0),
        temps: Temperatures(),
        system: SystemType.linux,
        diskIO: DiskIO(),
      );
      for (final (i, s) in samples.indexed) {
        ns.update(s);
        status.recordSample(timeMs: (i + 1) * 1000);
      }
      return ServerState(
        spi: spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u'),
        status: status,
      );
    }

    // One real interface and a bridge carrying more, which the picker used
    // to leave out: with a single real interface it had nothing to list.
    final si = state([
      [_part('lo', 0, 0, 1), _part('eth0', 0, 0, 1), _part('vmbr0', 0, 0, 1)],
      [
        _part('lo', 9000, 9000, 2),
        _part('eth0', 1000, 2000, 2),
        _part('vmbr0', 5000, 6000, 2),
      ],
      [
        _part('lo', 9000, 9000, 3),
        _part('eth0', 2000, 4000, 3),
        _part('vmbr0', 10000, 12000, 3),
      ],
    ]);

    test('every interface but loopback is listed, busiest first', () {
      for (final kind in [ServerMetricKind.netSpeed, ServerMetricKind.netTraffic]) {
        final devices = MetricDevices.of(si, kind)!;
        expect(devices.names, ['vmbr0', 'eth0'], reason: '$kind');
        // The real one is drawn by default, being what the totals add up.
        expect(devices.defaults, ['eth0'], reason: '$kind');
      }
    });

    test('a single device is drawn in both directions', () {
      final speed = MetricDevices.of(si, ServerMetricKind.netSpeed)!.alone!('eth0');
      expect(speed.map((s) => s.label), ['eth0 ↑', 'eth0 ↓']);

      // 2000 B/s out over the second, and the first sample has no rate.
      final traffic = MetricDevices.of(
        si,
        ServerMetricKind.netTraffic,
      )!.alone!('eth0');
      expect(traffic.first.values.nonNulls.last, 2000);
    });

    test('the traffic row reads the counters since boot', () {
      final m = serverCardReadings(
        si,
      ).all.firstWhere((m) => m.kind == ServerMetricKind.netTraffic);
      // eth0 alone: vmbr0 is not a real interface, and lo never is.
      expect(m.value, '3.9 KB');
    });
  });
}
