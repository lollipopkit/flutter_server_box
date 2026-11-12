import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/status/memory.dart';
import 'package:server_box/data/model/server/status/swap_area.dart';
import 'package:server_box/data/model/server/status/status_history.dart';
import 'package:server_box/data/provider/server/metric.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/view/page/server/detail/metric_devices.dart';

import '../../helpers/spi_fixture.dart';

void main() {
  test('sensors with only the aggregate behind them still draw one', () {
    // An agent's history has one temperature column; the sensors come with
    // the first status, before any live sample has a line per sensor.
    final status = InitStatus.status;
    status.temps.setAll(const {'coretemp': 62.0, 'nvme': 38.0});
    status.history.seed([
      const StatusHistorySample(timeMs: 1000, temp: 60),
      const StatusHistorySample(timeMs: 2000, temp: 61),
    ]);
    final si = ServerState(
      spi: spiFixture(id: 's', name: 'n', ip: 'h', user: 'u'),
      status: status,
    );

    final devices = MetricDevices.of(si, ServerMetricKind.temp)!;
    expect(devices.defaults, ['coretemp']);
  });

  group('swap areas (#1829)', () {
    ServerState state(List<SwapArea> areas) {
      final status = InitStatus.status
        ..swap = const Swap(total: 6 * 1024 * 1024, free: 5 * 1024 * 1024, cached: 0)
        ..swapAreas = areas;
      return ServerState(
        spi: spiFixture(id: 's', name: 'n', ip: 'h', user: 'u'),
        status: status,
      );
    }

    test('the total first and drawn by default, then by priority', () {
      final devices = MetricDevices.of(
        state(const [
          SwapArea(path: '/swapfile', kind: 'file', size: 2 << 30, used: 2 << 30, priority: -2),
          SwapArea(path: '/dev/zram0', kind: 'partition', size: 4 << 30, used: 1 << 30, priority: 100),
        ]),
        ServerMetricKind.swap,
      )!;
      final total = libL10n.total;
      expect(devices.names, [total, '/dev/zram0', '/swapfile']);
      expect(devices.defaults, [total]);
      expect(devices.byDevice.keys, contains(total));
      expect(devices.subtitle('/dev/zram0'), endsWith('100'));
      expect(devices.subtitle('/dev/zram0'), startsWith('25.0%'));
    });

    test('one area is the total, with nothing to pick', () {
      final devices = MetricDevices.of(
        state(const [SwapArea(path: '/swapfile', size: 1 << 30)]),
        ServerMetricKind.swap,
      );
      expect(devices, isNull);
    });
  });
}
