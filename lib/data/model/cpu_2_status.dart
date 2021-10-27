import 'package:toolbox/data/model/cpu_status.dart';

class Cpu2Status {
  List<CpuStatus> pre;
  List<CpuStatus> now;
  Cpu2Status(this.pre, this.now);

  double usedPercent({int coreIdx = 0}) {
    final used = (now[coreIdx].idle - pre[coreIdx].idle) /
        (now[coreIdx].total - pre[coreIdx].total);
    return used.isNaN ? 0 : used;
  }

  Cpu2Status update(List<CpuStatus> newStatus) {
    return Cpu2Status(now, newStatus);
  }
}
