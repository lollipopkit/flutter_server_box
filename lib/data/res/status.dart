import '../model/server/cpu_status.dart';
import '../model/server/disk_info.dart';
import '../model/server/memory.dart';
import '../model/server/net_speed.dart';
import '../model/server/server_status.dart';
import '../model/server/tcp_status.dart';

get _initMemory => Memory(
      total: 1,
      used: 0,
      free: 1,
      cache: 0,
      avail: 1,
    );
get _initOneTimeCpuStatus => OneTimeCpuStatus(
      'cpu',
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    );
get initCpuStatus => CpuStatus(
      [_initOneTimeCpuStatus],
      [_initOneTimeCpuStatus],
      '',
    );
get _initNetSpeedPart => NetSpeedPart(
      '',
      0,
      0,
      0,
    );
get initNetSpeed => NetSpeed(
      [_initNetSpeedPart],
      [_initNetSpeedPart],
    );
get initStatus => ServerStatus(
      initCpuStatus,
      _initMemory,
      'Loading...',
      '',
      [DiskInfo('/', '/', 0, '0', '0', '0')],
      TcpStatus(0, 0, 0, 0),
      initNetSpeed,
    );
