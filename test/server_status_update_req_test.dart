import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/sensors.dart';
import 'package:server_box/data/model/server/server_status_update_req.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/res/status.dart';

void main() {
  group('Server status snapshot parsing', () {
    test('invalid linux payload does not reuse previous disk and metadata state', () async {
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

      expect(result.disk, isEmpty);
      expect(result.diskUsage, isNull);
      expect(result.more.containsKey(StatusCmdType.host), isFalse);
      expect(result.sensors, isEmpty);

      expect(previous.disk, hasLength(1));
      expect(previous.disk.single.path, '/dev/old');
      expect(previous.diskUsage, isNotNull);
      expect(previous.more[StatusCmdType.host], 'old-host');
      expect(previous.sensors, hasLength(1));
    });
  });
}
