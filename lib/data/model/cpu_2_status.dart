import 'package:toolbox/data/model/cpu_status.dart';

class Cpu2Status {
  List<CpuStatus> pre;
  List<CpuStatus> now;
  Cpu2Status(this.pre, this.now);

  double usedPercent({int coreIdx = 0}) {
    final idleDelta = now[coreIdx].idle - pre[coreIdx].idle;
    final totalDelta = now[coreIdx].total - pre[coreIdx].total;
    final used = idleDelta / totalDelta;
    return used.isNaN ? 0 : 100 - used * 100;
  }

  Cpu2Status update(List<CpuStatus> newStatus) {
    return Cpu2Status(now, newStatus);
  }
}
