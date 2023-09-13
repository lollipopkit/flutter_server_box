import 'package:toolbox/data/res/status.dart';

import 'time_seq.dart';

class Cpus extends TimeSeq<OneTimeCpuStatus> {
  Cpus(super.pre, super.now);

  double usedPercent({int coreIdx = 0}) {
    if (now.length != pre.length) return 0;
    final idleDelta = now[coreIdx].idle - pre[coreIdx].idle;
    final totalDelta = now[coreIdx].total - pre[coreIdx].total;
    final used = idleDelta / totalDelta;
    return used.isNaN ? 0 : 100 - used * 100;
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

class OneTimeCpuStatus extends TimeSeqIface<OneTimeCpuStatus> {
  final String id;
  final int user;
  final int sys;
  final int nice;
  final int idle;
  final int iowait;
  final int irq;
  final int softirq;

  OneTimeCpuStatus(
    this.id,
    this.user,
    this.sys,
    this.nice,
    this.idle,
    this.iowait,
    this.irq,
    this.softirq,
  );

  int get total => user + sys + nice + idle + iowait + irq + softirq;

  @override
  bool same(OneTimeCpuStatus other) => id == other.id;
}

List<OneTimeCpuStatus> parseCPU(String raw) {
  final List<OneTimeCpuStatus> cpus = [];

  for (var item in raw.split('\n')) {
    if (item == '') break;
    final id = item.split(' ').first;
    final matches = item.replaceFirst(id, '').trim().split(' ');
    cpus.add(
      OneTimeCpuStatus(
        id,
        int.parse(matches[0]),
        int.parse(matches[1]),
        int.parse(matches[2]),
        int.parse(matches[3]),
        int.parse(matches[4]),
        int.parse(matches[5]),
        int.parse(matches[6]),
      ),
    );
  }
  return cpus;
}

final _bsdCpuPercentReg = RegExp(r'(\d+\.\d+)%');

/// TODO: Change this implementation to parse cpu status on BSD system
///
/// [raw]:
/// CPU usage: 14.70% user, 12.76% sys, 72.52% idle
Cpus parseBsdCpu(String raw) {
  final percents = _bsdCpuPercentReg
      .allMatches(raw)
      .map((e) => double.parse(e.group(1) ?? '0') * 100)
      .toList();
  if (percents.length != 3) return InitStatus.cpus;
  return InitStatus.cpus
    ..now = [
      OneTimeCpuStatus('cpu', percents[0].toInt(), 0, 0,
          percents[2].toInt() + percents[1].toInt(), 0, 0, 0)
    ];
}
