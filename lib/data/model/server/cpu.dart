import 'dart:collection';

import 'package:toolbox/data/model/server/time_seq.dart';
import 'package:toolbox/data/res/status.dart';

class Cpus extends TimeSeq<List<OneTimeCpuStatus>> {
  Cpus(super.init1, super.init2);

  @override
  void onUpdate() {
    _coresCount = now.length;
    _totalDelta = now[0].total - pre[0].total;
    _user = _getUser();
    _sys = _getSys();
    _iowait = _getIowait();
    _idle = _getIdle();
  }

  double usedPercent({int coreIdx = 0}) {
    if (now.length != pre.length) return 0;
    final idleDelta = now[coreIdx].idle - pre[coreIdx].idle;
    final totalDelta = now[coreIdx].total - pre[coreIdx].total;
    final used = idleDelta / totalDelta;
    return used.isNaN ? 0 : 100 - used * 100;
  }

  int _coresCount = 0;
  int get coresCount => _coresCount;

  int _totalDelta = 0;
  int get totalDelta => _totalDelta;

  double _user = 0;
  double get user => _user;
  double _getUser() {
    if (now.length != pre.length) return 0;
    final delta = now[0].user - pre[0].user;
    final used = delta / totalDelta;
    return used.isNaN ? 0 : used * 100;
  }

  double _sys = 0;
  double get sys => _sys;
  double _getSys() {
    if (now.length != pre.length) return 0;
    final delta = now[0].sys - pre[0].sys;
    final used = delta / totalDelta;
    return used.isNaN ? 0 : used * 100;
  }

  double _iowait = 0;
  double get iowait => _iowait;
  double _getIowait() {
    if (now.length != pre.length) return 0;
    final delta = now[0].iowait - pre[0].iowait;
    final used = delta / totalDelta;
    return used.isNaN ? 0 : used * 100;
  }

  double _idle = 0;
  double get idle => _idle;
  double _getIdle() => 100 - usedPercent();
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

  static List<OneTimeCpuStatus> parse(String raw) {
    final List<OneTimeCpuStatus> cpus = [];

    for (var item in raw.split('\n')) {
      if (item == '') break;
      final id = item.split(' ').firstOrNull;
      if (id == null) continue;
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

  final init = InitStatus.cpus;
  init.add([
    OneTimeCpuStatus('cpu', percents[0].toInt(), 0, 0,
        percents[2].toInt() + percents[1].toInt(), 0, 0, 0),
  ]);
  return init;
}
