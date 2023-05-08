import 'package:toolbox/data/model/server/cpu_status.dart';
import 'package:toolbox/data/model/server/disk_info.dart';
import 'package:toolbox/data/model/server/memory.dart';
import 'package:toolbox/data/model/server/net_speed.dart';
import 'package:toolbox/data/model/server/conn_status.dart';

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
