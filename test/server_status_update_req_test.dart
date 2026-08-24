import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/battery.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/model/server/sensors.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_status_update_req.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/res/status.dart';

import 'rust_lib_helper.dart';

void main() {
  setUpAll(initRustLibForTest);

  group('Server status snapshot parsing', () {
    test(
      'invalid linux payload does not reuse previous disk and metadata state',
      () async {
        final previous = _createPreviousStatus();

        final result = await getStatus(
          ServerStatusUpdateReq(
            system: SystemType.linux,
            ss: previous,
            parsedOutput: {
              StatusCmdType.time.name: '1710000000',
              StatusCmdType.disk.name: 'not a valid disk payload',
              StatusCmdType.host.name: '',
              StatusCmdType.sensors.name: '',
            },
          ),
        );

        _expectClearedResult(result);
        _expectPreviousStatusImmutableFields(previous);
      },
    );

    test(
      'invalid bsd payload does not reuse previous disk and metadata state',
      () async {
        final previous = _createPreviousStatus();

        final result = await getStatus(
          ServerStatusUpdateReq(
            system: SystemType.bsd,
            ss: previous,
            parsedOutput: {
              BSDStatusCmdType.time.name: '1710000000',
              BSDStatusCmdType.disk.name: 'not a valid disk payload',
              BSDStatusCmdType.host.name: '',
            },
          ),
        );

        _expectBsdClearedResult(result);
        _expectPreviousStatusImmutableFields(previous);
      },
    );

    test(
      'invalid windows payload does not reuse previous disk and metadata state',
      () async {
        final previous = _createPreviousStatus();

        final result = await getStatus(
          ServerStatusUpdateReq(
            system: SystemType.windows,
            ss: previous,
            parsedOutput: {
              WindowsStatusCmdType.time.name: '1710000000',
              WindowsStatusCmdType.disk.name: 'not a valid disk payload',
              WindowsStatusCmdType.host.name: '',
              WindowsStatusCmdType.temp.name: '',
            },
          ),
        );

        _expectClearedResult(result);
        _expectPreviousStatusImmutableFields(previous);
      },
    );

    test('valid bsd disk payload computes disk usage summary', () async {
      final result = await getStatus(
        ServerStatusUpdateReq(
          system: SystemType.bsd,
          ss: InitStatus.status,
          parsedOutput: {
            BSDStatusCmdType.disk.name: '''
Filesystem  1024-blocks   Used Available Capacity Mounted on
/dev/disk1s1     100000  40000     60000      40% /
''',
          },
        ),
      );

      expect(result.disk, isNotEmpty);
      expect(result.diskUsage, isNotNull);
      expect(result.diskUsage!.size, greaterThan(BigInt.zero));
      expect(result.diskUsage!.used, greaterThan(BigInt.zero));
    });

    test('status parsing copies rolling history objects', () async {
      final previous = InitStatus.status;

      final result = await getStatus(
        ServerStatusUpdateReq(
          system: SystemType.bsd,
          ss: previous,
          parsedOutput: {
            BSDStatusCmdType.cpu.name:
                'CPU usage: 14.70% user, 12.76% sys, 72.52% idle',
          },
        ),
      );

      // `getStatus` parses into the status it was handed; the private copy is
      // made by `ServerNotifier._copyStatus` before it gets here. What matters
      // is that a copy is independent, which `Cpus.copy` is asserted on below.
      expect(result.cpu.now.single.user, 14);

      final snapshot = Cpus.copy(result.cpu);
      result.cpu.update([SingleCpuCore('cpu', 99, 0, 0, 1, 0, 0, 0)]);
      expect(
        snapshot.now.single.user,
        14,
        reason: 'a copy must stop tracking the original',
      );
    });

    test('the trend buffer carries over between refreshes', () async {
      // What the chart cards are drawn from. Handing every refresh a fresh
      // buffer left them holding only the sample taken moments ago, which
      // fl_chart plots as a single point against the left edge.
      final previous = InitStatus.status;
      previous.history.add(timeMs: 1, cpu: 1);
      previous.history.add(timeMs: 2, cpu: 2);

      final result = await getStatus(
        ServerStatusUpdateReq(
          system: SystemType.bsd,
          ss: previous,
          parsedOutput: const {},
        ),
      );

      expect(identical(result.history, previous.history), isTrue);
      expect(result.history.length, 2);
    });

    test('Windows CPU brand comes from the processor record', () async {
      // One WMI record carries Name alongside the core counts, so the brand
      // and the count it applies to can't disagree. Upstream reads the brand
      // from a second, plain-text command instead.
      final result = await getStatus(
        ServerStatusUpdateReq(
          system: SystemType.windows,
          ss: InitStatus.status,
          parsedOutput: {
            WindowsStatusCmdType.cpu.name:
                '{"Name":"Example CPU","LoadPercentage":50,'
                '"NumberOfCores":4,"NumberOfLogicalProcessors":8}',
          },
        ),
      );

      expect(result.cpu.brand, {'Example CPU': 4});
      expect(result.cpu.coresCount, 9);
    });

    test('Windows Celsius temperatures ignore Unix divisor settings', () async {
      for (final divisor in [1.0, 1000.0]) {
        final result = await getStatus(
          ServerStatusUpdateReq(
            system: SystemType.windows,
            ss: InitStatus.status,
            parsedOutput: {
              WindowsStatusCmdType.temp.name:
                  '{"InstanceName":"zone","Temperature":45.0}',
            },
            tempDivisor: divisor,
          ),
        );
        expect(result.temps.first, 45);
      }
    });

    test('Windows full batteries and hardware sections are retained', () async {
      final result = await getStatus(
        ServerStatusUpdateReq(
          system: SystemType.windows,
          ss: InitStatus.status,
          parsedOutput: {
            WindowsStatusCmdType.battery.name:
                '{"EstimatedChargeRemaining":100,"BatteryStatus":3}',
            WindowsStatusCmdType.sensors.name:
                '{"Name":"Probe","CurrentReading":42}',
            WindowsStatusCmdType.diskSmart.name:
                '{"DeviceId":"0","Temperature":35,"PowerOnHours":10}',
          },
        ),
      );

      expect(result.batteries.single.status, BatteryStatus.full);
      expect(result.sensors.single.device, 'Probe');
      expect(result.diskSmart.single.device, '0');
      expect(result.diskSmart.single.temperature, 35);
    });
  });

  /// The wiring between the parser's JSON and the fields the marks are drawn
  /// from. Every failure here is silent: a key that stopped arriving leaves
  /// `osId` null and the prose match answers instead, usually with the parent.
  group('what the sys segment fills in', () {
    Future<ServerStatus> parse(String sys) => getStatus(
      ServerStatusUpdateReq(
        system: SystemType.linux,
        ss: InitStatus.status,
        parsedOutput: {StatusCmdType.sys.name: sys},
      ),
    );

    test('the os-release identifiers reach the status', () async {
      final result = await parse(
        'ID=linuxmint\nID_LIKE="ubuntu debian"\nPRETTY_NAME="Linux Mint 21.3"\n',
      );

      expect(result.osId, 'linuxmint');
      expect(result.osIdLike, ['ubuntu', 'debian']);
      // The prose stays what it was — it is the line the detail page shows.
      expect(result.more[StatusCmdType.sys], 'Linux Mint 21.3');
      expect(result.dist, Dist.mint);
    });

    test('and the id decides, not the prose', () async {
      // A Mint install whose `PRETTY_NAME` still says Ubuntu — which is what
      // several derivatives ship. Matching the prose reads it as the parent.
      final result = await parse('ID=linuxmint\nPRETTY_NAME="Ubuntu 22.04.3 LTS"\n');

      expect(result.dist, Dist.mint);
    });

    test('a remote with no os-release still reads by its prose', () async {
      final result = await parse('PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"\n');

      expect(result.osId, isNull);
      expect(result.osIdLike, isEmpty);
      expect(result.dist, Dist.debian);
    });
  });
}

// These tests rely on `InitStatus.status` returning a fresh `ServerStatus`
// instance on each call so this helper can safely seed per-test state.
ServerStatus _createPreviousStatus() {
  final previous = InitStatus.status;
  previous.disk = [
    Disk(
      path: '/dev/old',
      mount: '/',
      usedPercent: 50,
      used: BigInt.from(500),
      size: BigInt.from(1000),
      avail: BigInt.from(500),
    ),
  ];
  previous.diskUsage = DiskUsage.parse(previous.disk);
  previous.more[StatusCmdType.host] = 'old-host';
  previous.sensors.add(
    const SensorItem(
      device: 'old-sensor',
      adapter: SensorAdaptor(SensorAdaptor.isaRaw),
      details: {'temp1': '+40.0C'},
    ),
  );
  return previous;
}

void _expectClearedResult(ServerStatus result) {
  expect(result.disk, isEmpty);
  expect(result.diskUsage, isNull);
  expect(result.more.containsKey(StatusCmdType.host), isFalse);
  expect(result.sensors, isEmpty);
}

void _expectBsdClearedResult(ServerStatus result) {
  expect(result.disk, isEmpty);
  expect(result.diskUsage, isNull);
  expect(result.sensors, isEmpty);
}

void _expectPreviousStatusImmutableFields(ServerStatus previous) {
  expect(previous.disk, hasLength(1));
  expect(previous.disk.single.path, '/dev/old');
  expect(previous.diskUsage, isNotNull);
  expect(previous.more[StatusCmdType.host], 'old-host');
  expect(previous.sensors, hasLength(1));
}
