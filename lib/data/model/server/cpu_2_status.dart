import 'package:toolbox/data/model/server/cpu_status.dart';

class Cpu2Status {
  List<CpuStatus> _pre;
  List<CpuStatus> _now;
  String temp;
  Cpu2Status(this._pre, this._now, this.temp);

  double usedPercent({int coreIdx = 0}) {
    if (_now.length != _pre.length) return 0;
    final idleDelta = _now[coreIdx].idle - _pre[coreIdx].idle;
    final totalDelta = _now[coreIdx].total - _pre[coreIdx].total;
    final used = idleDelta / totalDelta;
    return used.isNaN ? 0 : 100 - used * 100;
  }

  void update(List<CpuStatus> newStatus, String newTemp) {
    _pre = _now;
    _now = newStatus;
    temp = newTemp;
  }

  int get coresCount => _now.length;

  int get totalDelta => _now[0].total - _pre[0].total;

  double get user {
    if (_now.length != _pre.length) return 0;
    final delta = _now[0].user - _pre[0].user;
    final used = delta / totalDelta;
    return used.isNaN ? 0 : used * 100;
  }

  double get sys {
    if (_now.length != _pre.length) return 0;
    final delta = _now[0].sys - _pre[0].sys;
    final used = delta / totalDelta;
    return used.isNaN ? 0 : used * 100;
  }

  double get nice {
    if (_now.length != _pre.length) return 0;
    final delta = _now[0].nice - _pre[0].nice;
    final used = delta / totalDelta;
    return used.isNaN ? 0 : used * 100;
  }

  double get iowait {
    if (_now.length != _pre.length) return 0;
    final delta = _now[0].iowait - _pre[0].iowait;
    final used = delta / totalDelta;
    return used.isNaN ? 0 : used * 100;
  }

  double get idle => 100 - usedPercent();
}
