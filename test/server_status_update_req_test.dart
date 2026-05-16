import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/sensors.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_status_update_req.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/res/status.dart';

void main() {
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
            customCmds: const {},
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
            customCmds: const {},
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
            customCmds: const {},
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
          customCmds: const {},
        ),
      );

      expect(result.disk, isNotEmpty);
      expect(result.diskUsage, isNotNull);
      expect(result.diskUsage!.size, greaterThan(BigInt.zero));
      expect(result.diskUsage!.used, greaterThan(BigInt.zero));
    });

    test('bsd refresh preserves shared cpu history object', () async {
      final previous = InitStatus.status;
      final sharedCpu = previous.cpu;

      final result = await getStatus(
        ServerStatusUpdateReq(
          system: SystemType.bsd,
          ss: previous,
          parsedOutput: {
            BSDStatusCmdType.cpu.name:
                'CPU usage: 14.70% user, 12.76% sys, 72.52% idle',
          },
          customCmds: const {},
        ),
      );

      expect(identical(result.cpu, sharedCpu), isTrue);
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
      adapter: SensorAdaptor.isa,
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
