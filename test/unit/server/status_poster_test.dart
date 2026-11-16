import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/status/conn.dart';
import 'package:server_box/data/model/server/status/cpu.dart';
import 'package:server_box/data/model/server/status/disk.dart';
import 'package:server_box/data/model/server/status/memory.dart';
import 'package:server_box/data/model/server/status/net_speed.dart';
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
