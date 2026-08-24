import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/model/server/monitor_metrics.dart';
import 'package:server_box/data/model/server/monitor_metrics_mapper.dart';
import 'package:server_box/data/res/status.dart';

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

  group('the os-release identifiers', () {
    /// The smallest body the agent can send, so a case here says what it adds
    /// and nothing else.
    Map<String, Object?> body(Map<String, Object?> extra) => {
      'timestamp': '2026-08-22T00:00:00Z',
      'extended_updated_at': '2026-08-22T00:00:00Z',
      'server_name': 'test-server',
      'cpu_usage': 0.0,
      'cpu_cores': const [],
      'memory': const {'total': 1, 'used': 0, 'free': 1, 'usage_percent': 0.0},
      'swap': const {'total': 0, 'used': 0, 'usage_percent': 0.0},
      'disk': const {'total': 1, 'used': 0, 'free': 1, 'usage_percent': 0.0},
      'network': const {'rx_bytes': 0, 'tx_bytes': 0},
      ...extra,
    };

    test('arrive under the names the agent serialises them as', () {
      final metrics = MonitorMetrics.fromJson(
        body({
          'sys': 'Linux Mint 21.3',
          'os_id': 'linuxmint',
          'os_id_like': const ['ubuntu', 'debian'],
        }),
      );

      expect(metrics.osId, 'linuxmint');
      expect(metrics.osIdLike, ['ubuntu', 'debian']);
    });

    test('and an agent predating them still parses', () {
      // Every agent released so far. The prose is all it sends, and the mark
      // falls back to matching that.
      final metrics = MonitorMetrics.fromJson(body({'sys': 'Linux Mint 21.3'}));

      expect(metrics.osId, isNull);
      expect(metrics.osIdLike, isEmpty);
      expect(metrics.sys, 'Linux Mint 21.3');
    });

    test('and reach the status the marks are drawn from', () {
      // The monitor half of what `server_status_update_req_test.dart` asserts
      // for SSH: two paths fill the same three fields, and either one can be
      // forgotten on its own.
      final status = applyMonitorMetrics(
        InitStatus.status,
        MonitorMetrics.fromJson(
          body({
            'sys': 'Ubuntu 22.04.3 LTS',
            'os_id': 'linuxmint',
            'os_id_like': const ['ubuntu', 'debian'],
          }),
        ),
      );

      expect(status.osId, 'linuxmint');
      expect(status.osIdLike, ['ubuntu', 'debian']);
      expect(status.dist, Dist.mint, reason: 'the id decides, not the prose');
    });

    test('and an agent that sends only the prose still marks the row', () {
      final status = applyMonitorMetrics(
        InitStatus.status,
        MonitorMetrics.fromJson(body({'sys': 'Alpine Linux v3.20'})),
      );

      expect(status.osId, isNull);
      expect(status.dist, Dist.alpine);
    });
  });
}
