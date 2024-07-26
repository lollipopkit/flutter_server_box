import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/time_seq.dart';
import 'package:server_box/data/res/status.dart';

/// Capacity of the FIFO queue
const _kCap = 30;

class Cpus extends TimeSeq<List<SingleCpuCore>> {
  Cpus(super.init1, super.init2);

  final Map<String, int> brand = {};

  @override
  void onUpdate() {
    _coresCount = now.length;
    _totalDelta = now[0].total - pre[0].total;
    _user = _getUser();
    _sys = _getSys();
    _iowait = _getIowait();
    _idle = _getIdle();
    _updateSpots();
    //_updateRange();
  }

  double usedPercent({int coreIdx = 0}) {
    if (now.length != pre.length) return 0;
    if (now.isEmpty) return 0;
    try {
      final idleDelta = now[coreIdx].idle - pre[coreIdx].idle;
      final totalDelta = now[coreIdx].total - pre[coreIdx].total;
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
    /// Only update the entire cpu when [coresCount] > 4, or the chart will be too crowded
    // final onlyCalcSingle = coresCount > 4;
    // final maxIdx = onlyCalcSingle ? 1 : coresCount;
    // for (var i = onlyCalcSingle ? 0 : 1; i < maxIdx; i++) {
    //   callback(i);
    // }

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

  // var _rangeX = Range<double>(0.0, _kCap.toDouble());
  // Range<double> get rangeX => _rangeX;
  // // var _rangeY = Range<double>(0.0, 100.0);
  // // Range<double> get rangeY => _rangeY;
  // void _updateRange() {
  //   double minX = 0;
  //   double maxX = 0;
  //   _coresLoop((i) {
  //     final fifo = _spots[i];
  //     if (fifo.isEmpty) return;
  //     final first = fifo.first.x;
  //     final last = fifo.last.x;
  //     if (first > minX) minX = first;
  //     if (last > maxX) maxX = last;
  //   });
  //   _rangeX = Range(minX, maxX);

  //   // double? minY, maxY;
  //   // for (var i = 1; i < now.length; i++) {
  //   //   final item = _spots[i];
  //   //   if (item.isEmpty) continue;
  //   //   final first = item.first.y;
  //   //   final last = item.last.y;
  //   //   if (minY == null || first < minY) minY = first;
  //   //   if (maxY == null || last > maxY) maxY = last;
  //   // }
  //   // if (minY != null && maxY != null) _rangeY = Range(minY, maxY);
  // }
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

  static List<SingleCpuCore> parse(String raw) {
    final List<SingleCpuCore> cpus = [];

    for (var item in raw.split('\n')) {
      if (item == '') break;
      final id = item.split(' ').firstOrNull;
      if (id == null) continue;
      final matches = item.replaceFirst(id, '').trim().split(' ');
      cpus.add(
        SingleCpuCore(
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

final class CpuBrand {
  static Map<String, int> parse(String raw) {
    final lines = raw.split('\n');
    // {brand: count}
    final brands = <String, int>{};
    for (var line in lines) {
      if (line.contains('model name')) {
        final model = line.split(':').last.trim();
        final count = brands[model] ?? 0;
        brands[model] = count + 1;
      }
    }
    return brands;
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
    SingleCpuCore('cpu', percents[0].toInt(), 0, 0,
        percents[2].toInt() + percents[1].toInt(), 0, 0, 0),
  ]);
  return init;
}
