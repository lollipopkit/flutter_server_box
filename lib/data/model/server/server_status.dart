import 'package:toolbox/data/model/server/temp.dart';

import 'cpu.dart';
import 'disk.dart';
import 'memory.dart';
import 'net_speed.dart';
import 'conn.dart';

class ServerStatus {
  Cpus cpu;
  Memory mem;
  Swap swap;
  String sysVer;
  String uptime;
  List<Disk> disk;
  Conn tcp;
  NetSpeed netSpeed;
  Temperatures temps;
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
    required this.temps,
    this.failedInfo,
  });
}
