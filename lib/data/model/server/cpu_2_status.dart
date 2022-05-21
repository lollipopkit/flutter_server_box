import 'package:toolbox/data/model/server/cpu_status.dart';

class Cpu2Status {
  List<CpuStatus> pre;
  List<CpuStatus> now;
  String temp;
  Cpu2Status(this.pre, this.now, this.temp);

  double usedPercent({int coreIdx = 0}) {
    if (now.length != pre.length) return 0;
    final idleDelta = now[coreIdx].idle - pre[coreIdx].idle;
    final totalDelta = now[coreIdx].total - pre[coreIdx].total;
    final used = idleDelta / totalDelta;
    return used.isNaN ? 0 : 100 - used * 100;
  }

  void update(List<CpuStatus> newStatus, String newTemp) {
    pre = now;
    now = newStatus;
    temp = newTemp;
  }

  int get coresCount => now.length;

  int get totalDelta => now[0].total - pre[0].total;

  double get user {
    if (now.length != pre.length) return 0;
    final delta = now[0].user - pre[0].user;
    final used = delta / totalDelta;
    return used.isNaN ? 0 : used * 100;
  }

  double get sys {
    if (now.length != pre.length) return 0;
    final delta = now[0].sys - pre[0].sys;
    final used = delta / totalDelta;
    return used.isNaN ? 0 : used * 100;
  }

  double get nice {
    if (now.length != pre.length) return 0;
    final delta = now[0].nice - pre[0].nice;
    final used = delta / totalDelta;
    return used.isNaN ? 0 : used * 100;
  }

  double get iowait {
    if (now.length != pre.length) return 0;
    final delta = now[0].iowait - pre[0].iowait;
    final used = delta / totalDelta;
    return used.isNaN ? 0 : used * 100;
  }

  double get idle => 100 - usedPercent();
}
