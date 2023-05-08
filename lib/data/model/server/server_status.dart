import 'cpu_status.dart';
import 'disk_info.dart';
import 'memory.dart';
import 'net_speed.dart';
import 'conn_status.dart';

class ServerStatus {
  CpuStatus cpu;
  Memory mem;
  Swap swap;
  String sysVer;
  String uptime;
  List<DiskInfo> disk;
  ConnStatus tcp;
  NetSpeed netSpeed;
  String? failedInfo;

  ServerStatus({
    required this.cpu,
    required this.mem,
    required this.sysVer,
    required this.uptime,
    required this.disk,
    required this.tcp,
    required this.netSpeed,
    required this.swap,
    this.failedInfo,
  });
}
