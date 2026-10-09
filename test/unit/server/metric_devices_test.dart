import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/status_history.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/view/page/server/card/metric.dart';
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
}
