import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/temp.dart';

import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/system.dart';

abstract final class InitStatus {
  static SingleCpuCore get _initOneTimeCpuStatus => SingleCpuCore(
        'cpu',
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      );
  static Cpus get cpus => Cpus(
        [_initOneTimeCpuStatus],
        [_initOneTimeCpuStatus],
      );
  static NetSpeedPart get _initNetSpeedPart => NetSpeedPart(
        '',
        BigInt.zero,
        BigInt.zero,
        0,
      );
  static NetSpeed get netSpeed => NetSpeed(
        [_initNetSpeedPart],
        [_initNetSpeedPart],
      );
  static ServerStatus get status => ServerStatus(
        cpu: cpus,
        mem: const Memory(
          total: 1,
          free: 1,
          avail: 1,
        ),
        disk: [
          Disk(
            fs: '/',
            mount: '/',
            usedPercent: 0,
            used: BigInt.zero,
            size: BigInt.one,
            avail: BigInt.zero,
          )
        ],
        tcp: const Conn(maxConn: 0, active: 0, passive: 0, fail: 0),
        netSpeed: netSpeed,
        swap: const Swap(
          total: 0,
          free: 0,
          cached: 0,
        ),
        system: SystemType.linux,
        temps: Temperatures(),
        diskIO: DiskIO([], []),
      );
}
