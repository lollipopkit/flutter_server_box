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

    test('and a parent is dropped when the next sample declares none', () {
      var status = applyMonitorMetrics(
        InitStatus.status,
        MonitorMetrics.fromJson(
          body({
            'os_id': 'linuxmint',
            'os_id_like': const ['ubuntu'],
          }),
        ),
      );
      expect(status.osIdLike, ['ubuntu']);

      // The same machine, reinstalled as something that declares no parent.
      // Keeping the old one made `resolveDist` fall through to Ubuntu for any
      // id this build does not know.
      status = applyMonitorMetrics(
        status,
        MonitorMetrics.fromJson(body({'os_id': 'gentoo'})),
      );
      expect(status.osId, 'gentoo');
      expect(status.osIdLike, isEmpty);
    });
  });

  group('a payload from an agent older than this build', () {
    /// Everything a released agent sends, and nothing this branch added.
    Map<String, Object?> legacyBody(Map<String, Object?> extra) => {
      'timestamp': '2026-08-22T00:00:00Z',
      'server_name': 'test-server',
      'cpu_usage': 40.0,
      'memory': const {
        'total': 2048,
        'used': 1024,
        'free': 1024,
        'usage_percent': 50.0,
      },
      'swap': const {'total': 0, 'used': 0, 'usage_percent': 0.0},
      'disk': const {
        'total': 4096,
        'used': 1024,
        'free': 3072,
        'usage_percent': 25.0,
      },
      'network': const {'rx_bytes': 0, 'tx_bytes': 0},
      ...extra,
    };

    test('decodes without the fields this build added', () {
      // The two were `required` and force-cast, so one missing key threw
      // before the mapper's per-section tolerance could keep anything.
      final metrics = MonitorMetrics.fromJson(legacyBody(const {}));

      expect(metrics.extendedUpdatedAt, isNull);
      expect(metrics.cpuCores, isEmpty);
      expect(metrics.cpuUsage, 40.0);
    });

    test('and its aggregate CPU still moves the reading', () {
      // Two samples, because a percentage is what happened *between* two —
      // the mapper accumulates `cpu_usage` into a synthetic monotonic counter
      // exactly as the Windows SSH path does.
      var status = applyMonitorMetrics(
        InitStatus.status,
        MonitorMetrics.fromJson(legacyBody(const {})),
      );
      status = applyMonitorMetrics(
        status,
        MonitorMetrics.fromJson(legacyBody(const {})),
      );

      // One synthetic core carrying `cpu_usage`. Returning early on an empty
      // `cpu_cores` left `ss.cpu` on its previous sample, and the history
      // buffer then recorded that as the current figure.
      expect(status.cpu.now.length, 2);
      expect(status.cpu.usedPercent(), closeTo(40.0, 0.1));
    });

    test('and its aggregate disk is shown rather than nothing', () {
      final status = applyMonitorMetrics(
        InitStatus.status,
        MonitorMetrics.fromJson(legacyBody(const {})),
      );

      expect(status.disk.length, 1);
      expect(status.disk.single.mount, '/');
      expect(status.disk.single.usedPercent, 25);
    });

    test('and aggregate network data replaces stale temperature detail', () {
      final status = InitStatus.status;
      status.temps.setAll({'old': 99});

      applyMonitorMetrics(
        status,
        MonitorMetrics.fromJson(
          legacyBody({
            'timestamp': '2026-08-22T00:00:00Z',
            'network': const {'rx_bytes': 10, 'tx_bytes': 20},
          }),
        ),
      );
      applyMonitorMetrics(
        status,
        MonitorMetrics.fromJson(
          legacyBody({
            'timestamp': '2026-08-22T00:00:01Z',
            'network': const {'rx_bytes': 110, 'tx_bytes': 220},
          }),
        ),
      );

      expect(status.netSpeed.devices, ['eth-monitor-total']);
      expect(status.netSpeed.sizeInBytes(0), BigInt.from(110));
      expect(status.temps.isEmpty, isTrue);
    });

    test('and a GPU with no vendor field is still placed by its name', () {
      final status = applyMonitorMetrics(
        InitStatus.status,
        MonitorMetrics.fromJson(
          legacyBody({
            'gpus': const [
              {
                'name': 'NVIDIA GeForce RTX 4090',
                'usage_percent': 30.0,
                'temperature': 50,
                'power': '100 W / 350 W',
                'memory_used': 1024,
                'memory_total': 24576,
                'memory_unit': 'MiB',
              },
              {
                'name': 'AMD Radeon RX 7900 XTX',
                'usage_percent': 10.0,
                'temperature': 40,
                'power': '50 W / 355 W',
                'memory_used': 512,
                'memory_total': 24576,
                'memory_unit': 'MiB',
              },
            ],
          }),
        ),
      );

      expect(status.nvidia?.single.name, 'NVIDIA GeForce RTX 4090');
      expect(status.amd?.single.name, 'AMD Radeon RX 7900 XTX');
    });
  });

  test('the vendor the agent reports wins over the name', () {
    final status = applyMonitorMetrics(
      InitStatus.status,
      MonitorMetrics.fromJson({
        'timestamp': '2026-08-22T00:00:00Z',
        'server_name': 'test-server',
        'cpu_usage': 0.0,
        'memory': const {
          'total': 1,
          'used': 0,
          'free': 1,
          'usage_percent': 0.0,
        },
        'swap': const {'total': 0, 'used': 0, 'usage_percent': 0.0},
        'disk': const {'total': 1, 'used': 0, 'free': 1, 'usage_percent': 0.0},
        'network': const {'rx_bytes': 0, 'tx_bytes': 0},
        'gpus': const [
          {
            // Named after neither vendor, which is why the field exists.
            'name': 'Instinct MI300X',
            'vendor': 'amd',
            'usage_percent': 5.0,
            'temperature': 35,
            'power': '20 W / 750 W',
            'memory_used': 1,
            'memory_total': 2,
            'memory_unit': 'MiB',
          },
        ],
      }),
    );

    expect(status.nvidia, isNull);
    expect(status.amd?.single.name, 'Instinct MI300X');
  });
}
