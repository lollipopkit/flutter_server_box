import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/time_seq.dart';

/// Capacity of the FIFO queue
const _kCap = 30;

class Cpus extends TimeSeq<SingleCpuCore> {
  Cpus(super.init1, super.init2);

  final Map<String, int> brand = {};

  @override
  void onUpdate() {
    _coresCount = now.length;
    if (pre.isEmpty || now.isEmpty || pre.length != now.length) {
      _totalDelta = 0;
      _user = 0;
      _sys = 0;
      _iowait = 0;
      _idle = 0;
      return;
    }
    _totalDelta = now[0].total - pre[0].total;
    _user = _getUser();
    _sys = _getSys();
    _iowait = _getIowait();
    _idle = _getIdle();
    _updateSpots();
  }

  double usedPercent({int coreIdx = 0}) {
    if (now.length != pre.length) return 0;
    if (now.isEmpty) return 0;
    if (coreIdx >= now.length) return 0;
    try {
      final idleDelta = now[coreIdx].idle - pre[coreIdx].idle;
      final totalDelta = now[coreIdx].total - pre[coreIdx].total;
      if (totalDelta == 0) return 0;
      final used = idleDelta / totalDelta;
      return used.isNaN ? 0 : 100 - used * 100;
    } catch (e, s) {
      Loggers.app.warning('Cpus.usedPercent()', e, s);
      return 0;
    }
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

  void _coresLoop(void Function(int i) callback) {
    /// Only use cpu0
    callback(0);
  }

  /// [core1, core2]
  /// core1: [FlSpot(0, 10), FlSpot(1, 20), FlSpot(2, 30)]
  final _spots = <Fifo<FlSpot>>[];
  List<Fifo<FlSpot>> get spots => _spots;
  void _updateSpots() {
    _coresLoop((i) {
      if (i >= _spots.length) {
        _spots.add(Fifo(capacity: _kCap));
      } else {
        final item = _spots[i];
        final spot = FlSpot(item.count.toDouble(), usedPercent(coreIdx: i));
        item.add(spot);
      }
    });
  }
}

class SingleCpuCore extends TimeSeqIface<SingleCpuCore> {
  final String id;
  final int user;
  final int sys;
  final int nice;
  final int idle;
  final int iowait;
  final int irq;
  final int softirq;

  SingleCpuCore(
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
  bool same(SingleCpuCore other) => id == other.id;

}

// 解析实现已迁移至共享 Rust 库 sbm_parser(见 doc/adr/0001)
