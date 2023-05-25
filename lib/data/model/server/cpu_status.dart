class CpuStatus {
  List<OneTimeCpuStatus> _pre;
  List<OneTimeCpuStatus> _now;
  CpuStatus(this._pre, this._now);

  double usedPercent({int coreIdx = 0}) {
    if (_now.length != _pre.length) return 0;
    final idleDelta = _now[coreIdx].idle - _pre[coreIdx].idle;
    final totalDelta = _now[coreIdx].total - _pre[coreIdx].total;
    final used = idleDelta / totalDelta;
    return used.isNaN ? 0 : 100 - used * 100;
  }

  void update(List<OneTimeCpuStatus> newStatus) {
    _pre = _now;
    _now = newStatus;
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

class OneTimeCpuStatus {
  late String id;
  late int user;
  late int sys;
  late int nice;
  late int idle;
  late int iowait;
  late int irq;
  late int softirq;

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
}

List<OneTimeCpuStatus> parseCPU(String raw) {
  final List<OneTimeCpuStatus> cpus = [];

  for (var item in raw.split('\n')) {
    if (item == '') break;
    final id = item.split(' ').first;
    final matches = item.replaceFirst(id, '').trim().split(' ');
    cpus.add(OneTimeCpuStatus(
        id,
        int.parse(matches[0]),
        int.parse(matches[1]),
        int.parse(matches[2]),
        int.parse(matches[3]),
        int.parse(matches[4]),
        int.parse(matches[5]),
        int.parse(matches[6])));
  }
  return cpus;
}
