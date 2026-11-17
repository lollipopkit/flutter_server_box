import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/status/conn.dart';
import 'package:server_box/data/model/server/status/cpu.dart';
import 'package:server_box/data/model/server/status/disk.dart';
import 'package:server_box/data/model/server/status/disk_smart.dart';
import 'package:server_box/data/model/server/status/memory.dart';
import 'package:server_box/data/model/server/status/net_speed.dart';
import 'package:server_box/data/model/server/status/status_history.dart';
import 'package:server_box/data/model/server/status/temp.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/server/data_source.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/page/server/detail/metric_model.dart';
import 'package:server_box/view/page/server/share_status/data.dart';

import '../../helpers/spi_fixture.dart';

Disk _disk(String mount, int sizeKb, {List<Disk> children = const []}) => Disk(
  path: '/dev/$mount',
  mount: mount,
  usedPercent: 50,
  used: BigInt.from(sizeKb ~/ 2),
  size: BigInt.from(sizeKb),
  avail: BigInt.from(sizeKb ~/ 2),
  children: children,
);

ServerState _state() {
  final ns = NetSpeed();
  final status = ServerStatus(
    cpu: Cpus(),
    mem: const Memory(total: 8 << 20, free: 2 << 20, avail: 4 << 20),
    disk: [
      _disk('/boot', 512 << 10),
      _disk('/', 100 << 20, children: [_disk('/data', 400 << 20)]),
      // The same filesystem mounted twice, as a bind mount is.
      _disk('/', 100 << 20),
      _disk('', 1 << 20),
    ],
    tcp: const Conn(maxConn: 0, fail: 0),
    netSpeed: ns,
    swap: const Swap(total: 0, free: 0, cached: 0),
    temps: Temperatures(),
    system: SystemType.linux,
    diskIO: DiskIO(),
  )..more[StatusCmdType.sys] = 'Debian 13';
  for (final (i, bytes) in [0, 1000, 3000].indexed) {
    ns.update([NetSpeedPart('eth0', BigInt.from(bytes), BigInt.from(bytes), i + 1)]);
    status.recordSample(timeMs: (i + 1) * 1000);
  }
  return ServerState(
    spi: spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u'),
    status: status,
  );
}

void main() {
  final srv = _state();
  final poster = StatusPoster.of(srv, MetricWindow.live(srv.status.history));

  test('carries what the machine reports, and nothing it does not', () {
    expect(
      poster.sections.keys,
      [PosterSection.cpu, PosterSection.mem, PosterSection.disk, PosterSection.net],
    );
  });

  test('lists each mounted filesystem once, largest first', () {
    expect(
      poster.sections[PosterSection.disk]!.rows.map((r) => r.name),
      ['/data', '/', '/boot'],
    );
  });

  test('a summary says only what is shown, and hides what is asked', () {
    final open = poster.summary(
      shown: {PosterSection.mem},
      range: 'Live',
      hideName: false,
      hideSystem: false,
    ).split('\n');
    expect(open.first, 'web · Live');
    expect(open, contains('Debian 13'));
    expect(open.where((l) => l.startsWith(libL10n.memory)), hasLength(1));
    expect(open.where((l) => l.startsWith('CPU')), isEmpty);
    expect(open.last, '— ServerBox');

    final hidden = poster.summary(
      shown: {PosterSection.mem},
      range: 'Live',
      hideName: true,
      hideSystem: true,
    );
    expect(hidden, isNot(contains('web')));
    expect(hidden, isNot(contains('Debian')));
  });

  test('a stored window reads only what it carries', () {
    // A window with the CPU's series and nothing else: memory is left out
    // rather than read from the machine's present.
    final stored = StatusPoster.of(
      srv,
      MetricWindow.of([
        StatusHistorySample(timeMs: 1000, cpu: 10),
        StatusHistorySample(timeMs: 2000, cpu: 30),
      ]),
      live: false,
    );
    expect(stored.sections.keys, isNot(contains(PosterSection.mem)));
    final cpu = stored.sections[PosterSection.cpu]!;
    expect(cpu.value, '20.0%');
    expect(cpu.bars, isEmpty, reason: 'each core now is not of the window');
    expect(cpu.aside, contains('30.0%'));
  });

  test('a stored window without its series has no CPU figure', () {
    final stored = StatusPoster.of(
      srv,
      MetricWindow.of([StatusHistorySample(timeMs: 1000)]),
      live: false,
    );
    expect(stored.sections[PosterSection.cpu]?.value, '--');
    expect(stored.sections[PosterSection.cpu]?.note, isNull);
  });

  test('a stored swap window outlives swap being off now', () {
    // The fixture's swap is disabled; the window still has samples of one.
    final stored = StatusPoster.of(
      srv,
      MetricWindow.of([
        StatusHistorySample(timeMs: 1000, swap: 10),
        StatusHistorySample(timeMs: 2000, swap: 20),
      ]),
      live: false,
    );
    final swap = stored.sections[PosterSection.swap]!;
    expect(swap.value, '15.0%');
    expect(swap.summary, startsWith(l10n.average));
  });

  test('a stored window reads battery from its own series', () {
    final stored = StatusPoster.of(
      srv,
      MetricWindow.of([
        StatusHistorySample(timeMs: 1000, battery: 90),
        StatusHistorySample(timeMs: 2000, battery: 80),
      ]),
      live: false,
    );
    expect(stored.sections[PosterSection.battery]!.value, '85.0%');

    // No stored window carries a GPU series — nothing stores one — and the
    // machine's present is not what the range is of.
    final without = StatusPoster.of(srv, const MetricWindow(), live: false);
    expect(without.sections.containsKey(PosterSection.battery), isFalse);
    expect(without.sections.containsKey(PosterSection.gpu), isFalse);
  });

  test('a stored window without detail keeps no names, and no per-device readings', () {
    final stored = StatusPoster.of(
      srv,
      MetricWindow.of([
        StatusHistorySample(timeMs: 1000, disk: 40, temp: 30, netRx: 10, netTx: 20),
        StatusHistorySample(timeMs: 2000, disk: 60, temp: 50, netRx: 30, netTx: 40),
      ]),
      live: false,
    );
    expect(stored.sections[PosterSection.disk]!.value, '50.0%');
    expect(stored.sections[PosterSection.disk]!.rows, isEmpty);
    expect(stored.sections[PosterSection.temp]!.value, '40°C');
    expect(stored.sections[PosterSection.net]!.title, isNull);
    expect(stored.sections.containsKey(PosterSection.sensor), isFalse);
  });

  test('a stored window with per-device detail shows mounts, GPU, sensors, and iface', () {
    final stored = StatusPoster.of(
      srv,
      MetricWindow.of([
        StatusHistorySample(
          timeMs: 1000,
          cpu: 20,
          mem: 50,
          disk: 50,
          gpu: 60,
          temp: 55,
          netRx: 1000,
          netTx: 2000,
          temps: const {'coretemp': 50.0, 'nvme': 40.0},
          netRxs: const {'eth0': 1000.0},
          netTxs: const {'eth0': 2000.0},
          mounts: const [
            (mount: '/', used: 10 << 30, total: 20 << 30),
            (mount: '/data', used: 100 << 30, total: 400 << 30),
            (mount: '/snap/core/1', used: 50 << 20, total: 50 << 20),
          ],
          gpus: const [
            (
              id: 'nvidia:0',
              name: 'RTX 4090',
              usagePercent: 60.0,
              memoryUsed: 4096,
              memoryTotal: 24576,
            ),
          ],
        ),
        StatusHistorySample(
          timeMs: 2000,
          cpu: 30,
          mem: 50,
          disk: 50,
          gpu: 80,
          temp: 65,
          netRx: 3000,
          netTx: 4000,
          temps: const {'coretemp': 60.0, 'nvme': 42.0},
          netRxs: const {'eth0': 3000.0},
          netTxs: const {'eth0': 4000.0},
          mounts: const [
            (mount: '/', used: 10 << 30, total: 20 << 30),
            (mount: '/data', used: 100 << 30, total: 400 << 30),
            (mount: '/snap/core/1', used: 50 << 20, total: 50 << 20),
          ],
          gpus: const [
            (
              id: 'nvidia:0',
              name: 'RTX 4090',
              usagePercent: 80.0,
              memoryUsed: 8192,
              memoryTotal: 24576,
            ),
          ],
        ),
      ]),
      live: false,
    );

    final disk = stored.sections[PosterSection.disk]!;
    expect(disk.rows.map((r) => r.name), ['/data', '/']);
    expect(disk.rows.first.value, contains('25%'));

    final gpu = stored.sections[PosterSection.gpu]!;
    expect(gpu.title, 'RTX 4090');
    expect(gpu.value, '70.0%');
    expect(gpu.note, contains('6144 / 24576 MiB'));

    final temp = stored.sections[PosterSection.temp]!;
    expect(temp.value, '55°C');
    expect(temp.note, contains('coretemp'));

    final sensors = stored.sections[PosterSection.sensor]!;
    expect(sensors.rows.map((r) => r.name), ['coretemp', 'nvme']);

    expect(stored.sections[PosterSection.net]!.title, 'eth0');

    // Non-CPU sensor hotter than CPU (`w.temp`) keeps its own sensor peak.
    final hotterNvme = StatusPoster.of(
      srv,
      MetricWindow.of([
        const StatusHistorySample(
          timeMs: 1000,
          temp: 40,
          temps: {'coretemp': 40.0, 'nvme': 60.0},
        ),
        const StatusHistorySample(
          timeMs: 2000,
          temp: 42,
          temps: {'coretemp': 42.0, 'nvme': 80.0},
        ),
      ]),
      live: false,
    );
    final nvmeTemp = hotterNvme.sections[PosterSection.temp]!;
    expect(nvmeTemp.value, '70°C');
    expect(nvmeTemp.note, contains('nvme'));
    expect(nvmeTemp.note, contains('80°C'));
  });

  test('SMART on every disk unavailable is not a pass', () {
    final smarts = [
      const DiskSmart(device: 'sda', smartAttributes: {}),
      const DiskSmart(device: 'sdb', smartAttributes: {}),
    ];
    expect(smarts.every((e) => e.notApplicable), isTrue);
    final status = srv.status..diskSmart = smarts;
    final poster = StatusPoster.of(
      ServerState(spi: srv.spi, status: status),
      MetricWindow.live(status.history),
    );
    expect(poster.sections.containsKey(PosterSection.smart), isFalse);
  });

  test('a machine not yet sampled has nothing to show', () {
    final blank = ServerState(
      spi: spiFixture(id: 'srv-2', name: 'new', ip: 'h', user: 'u'),
      status: ServerStatus(
        cpu: Cpus(),
        mem: const Memory(total: 0, free: 0, avail: 0),
        disk: const [],
        tcp: const Conn(maxConn: 0, fail: 0),
        netSpeed: NetSpeed(),
        swap: const Swap(total: 0, free: 0, cached: 0),
        temps: Temperatures(),
        system: SystemType.linux,
        diskIO: DiskIO(),
      ),
    );
    expect(StatusPoster.of(blank, const MetricWindow()).sections, isEmpty);
  });
}
