import 'package:toolbox/data/model/server/temp.dart';

import '../model/server/cpu.dart';
import '../model/server/disk.dart';
import '../model/server/memory.dart';
import '../model/server/net_speed.dart';
import '../model/server/server_status.dart';
import '../model/server/conn.dart';

Memory get _initMemory => Memory(
      total: 1,
      free: 1,
      cache: 0,
      avail: 1,
    );
OneTimeCpuStatus get _initOneTimeCpuStatus => OneTimeCpuStatus(
      'cpu',
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    );
Cpus get initCpuStatus => Cpus(
      [_initOneTimeCpuStatus],
      [_initOneTimeCpuStatus],
    );
NetSpeedPart get _initNetSpeedPart => NetSpeedPart(
      '',
      BigInt.zero,
      BigInt.zero,
      BigInt.zero,
    );
NetSpeed get initNetSpeed => NetSpeed(
      [_initNetSpeedPart],
      [_initNetSpeedPart],
    );
Swap get _initSwap => Swap(
      total: 1,
      free: 1,
      cached: 0,
    );
ServerStatus get initStatus => ServerStatus(
      cpu: initCpuStatus,
      mem: _initMemory,
      sysVer: 'Loading...',
      uptime: '',
      disk: [
        Disk(
          path: '/',
          loc: '/',
          usedPercent: 0,
          used: '0',
          size: '0',
          avail: '0',
        )
      ],
      tcp: Conn(maxConn: 0, active: 0, passive: 0, fail: 0),
      netSpeed: initNetSpeed,
      swap: _initSwap,
      temps: Temperatures(),
    );
