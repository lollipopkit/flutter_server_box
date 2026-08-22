import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_metrics.dart';

void main() {
  test('ignores the monitor-only disk I/O rate field', () {
    final metrics = MonitorMetrics.fromJson({
      'timestamp': '2026-08-22T00:00:00Z',
      'extended_updated_at': '2026-08-22T00:00:00Z',
      'server_name': 'test-server',
      'cpu_usage': 12.5,
      'cpu_cores': const [],
      'memory': const {
        'total': 1024,
        'used': 512,
        'free': 512,
        'usage_percent': 50.0,
      },
      'swap': const {'total': 0, 'used': 0, 'usage_percent': 0.0},
      'disk': const {
        'total': 2048,
        'used': 1024,
        'free': 1024,
        'usage_percent': 50.0,
      },
      'network': const {'rx_bytes': 10, 'tx_bytes': 20},
      'diskio': const [
        {'dev': 'sda', 'sectors_read': 100, 'sectors_write': 200},
      ],
      'diskio_rate': const [
        {
          'dev': 'sda',
          'read_bytes_per_sec': 4096.0,
          'write_bytes_per_sec': 8192.0,
        },
      ],
    });

    expect(metrics.serverName, 'test-server');
    expect(metrics.diskio.single.dev, 'sda');
  });
}
