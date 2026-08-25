import 'package:flutter_test/flutter_test.dart';
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

  test('aggregate compatibility fields replace stale detail state', () {
    final status = InitStatus.status;
    status.temps.setAll({'old': 99});

    applyMonitorMetrics(status, _metrics(timestamp: '2026-08-22T00:00:00Z'));
    applyMonitorMetrics(
      status,
      _metrics(
        timestamp: '2026-08-22T00:00:01Z',
        cpuUsage: 42,
        rxBytes: 110,
        txBytes: 220,
      ),
    );

    expect(status.cpu.usedPercent(), closeTo(42, 0.01));
    expect(status.disk, isEmpty);
    expect(status.diskUsage!.used, BigInt.from(1024));
    expect(status.diskUsage!.size, BigInt.from(2048));
    expect(status.netSpeed.devices, ['eth-monitor-total']);
    expect(status.netSpeed.sizeInBytes(0), BigInt.from(110));
    expect(status.temps.isEmpty, isTrue);
  });

  test('maps monitor GPUs into the existing vendor lists', () {
    final status = InitStatus.status;
    final metrics = _metrics(
      timestamp: '2026-08-22T00:00:00Z',
      gpus: const [
        MonitorGpuMetrics(
          name: 'NVIDIA RTX',
          usagePercent: 75,
          temperature: 60,
          power: '120 W',
          memoryUsed: 4,
          memoryTotal: 8,
          memoryUnit: 'GiB',
        ),
        MonitorGpuMetrics(
          name: 'AMD Radeon',
          usagePercent: 50,
          temperature: 55,
          power: '90 W',
          memoryUsed: 2,
          memoryTotal: 16,
          memoryUnit: 'GiB',
        ),
      ],
    );

    applyMonitorMetrics(status, metrics);

    expect(status.nvidia!.single.name, 'NVIDIA RTX');
    expect(status.amd!.single.name, 'AMD Radeon');
  });
}

MonitorMetrics _metrics({
  required String timestamp,
  double cpuUsage = 10,
  int rxBytes = 10,
  int txBytes = 20,
  List<MonitorGpuMetrics> gpus = const [],
}) => MonitorMetrics(
  timestamp: timestamp,
  extendedUpdatedAt: timestamp,
  serverName: 'test',
  cpuUsage: cpuUsage,
  cpuCores: const [],
  memory: const MonitorMemoryMetrics(
    total: 4096,
    used: 2048,
    free: 2048,
    usagePercent: 50,
  ),
  swap: const MonitorSwapMetrics(total: 0, used: 0, usagePercent: 0),
  disk: const MonitorDiskMetrics(
    total: 2097152,
    used: 1048576,
    free: 1048576,
    usagePercent: 50,
  ),
  network: MonitorNetworkMetrics(rxBytes: rxBytes, txBytes: txBytes),
  gpus: gpus,
);
