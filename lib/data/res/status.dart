import 'package:toolbox/data/model/server/temp.dart';

import '../model/server/cpu_status.dart';
import '../model/server/disk_info.dart';
import '../model/server/memory.dart';
import '../model/server/net_speed.dart';
import '../model/server/server_status.dart';
import '../model/server/conn_status.dart';

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
CpuStatus get initCpuStatus => CpuStatus(
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
      disk: [DiskInfo('/', '/', 0, '0', '0', '0')],
      tcp: ConnStatus(0, 0, 0, 0),
      netSpeed: initNetSpeed,
      swap: _initSwap,
      temps: Temperatures(),
    );
