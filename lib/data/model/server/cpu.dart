import 'package:server_box/data/model/server/time_seq.dart';

class Cpus extends TimeSeq<SingleCpuCore> {
  Cpus();

  Cpus.copy(Cpus source) : super.copy(source) {
    brand.addAll(source.brand);
    _coresCount = source._coresCount;
    _user = source._user;
    _sys = source._sys;
    _iowait = source._iowait;
    _idle = source._idle;
  }

  final Map<String, int> brand = {};

  @override
  void onUpdate() {
    _coresCount = now.length;
    _user = _share((c) => c.user);
    _sys = _share((c) => c.sys);
    _iowait = _share((c) => c.iowait);
    final used = usedPercent();
    _idle = used == null ? null : 100 - used;
  }

  /// Share of the aggregate ("cpu", index 0) window spent in one field.
  /// `null` whenever the window itself is unusable — see [TimeSeq.hasWindow].
  double? _share(int Function(SingleCpuCore) field) {
    if (!hasWindow) return null;
    final total = counterDelta(pre[0].total, now[0].total);
    final delta = counterDelta(field(pre[0]), field(now[0]));
    if (total == null || delta == null || total == 0) return null;
    return delta / total * 100;
  }

  /// Busy share of [coreIdx] over the last window, 0-100, or `null` when
  /// there is no usable window yet. Callers must render that as "no reading",
  /// not as 0 — a fabricated 0 is indistinguishable from a genuinely idle CPU.
  double? usedPercent({int coreIdx = 0}) {
    if (!hasWindow || coreIdx >= now.length) return null;
    final total = counterDelta(pre[coreIdx].total, now[coreIdx].total);
    final idle = counterDelta(pre[coreIdx].idle, now[coreIdx].idle);
    if (total == null || idle == null || total == 0) return null;
    return (100 - idle / total * 100).clamp(0, 100);
  }

  int _coresCount = 0;
  int get coresCount => _coresCount;

  double? _user;
  double? get user => _user;

  double? _sys;
  double? get sys => _sys;

  double? _iowait;
  double? get iowait => _iowait;

  double? _idle;
  double? get idle => _idle;
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

// Parsing implementation migrated to the shared Rust library sbm_parser
