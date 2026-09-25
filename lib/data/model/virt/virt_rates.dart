import 'package:server_box/data/model/virt/virt.dart';

/// One guest's cumulative counters at one moment, as a host reports them.
class VirtCounterSample {
  const VirtCounterSample({
    required this.at,
    this.cpuTimeNs,
    this.cpuPercent,
    this.vcpus,
    this.memUsed,
    this.memTotal,
    this.diskUsed,
    this.diskTotal,
    this.diskRead,
    this.diskWrite,
    this.netIn,
    this.netOut,
  });

  final DateTime at;

  /// Cumulative CPU time (libvirt). Turned into a percentage of [vcpus].
  final int? cpuTimeNs;

  /// CPU already as a percentage (PVE), used as is.
  final double? cpuPercent;
  final int? vcpus;
  final int? memUsed;
  final int? memTotal;
  final int? diskUsed;
  final int? diskTotal;

  /// Cumulative bytes.
  final int? diskRead;
  final int? diskWrite;
  final int? netIn;
  final int? netOut;

  bool _sameCounters(VirtCounterSample o) =>
      diskRead == o.diskRead &&
      diskWrite == o.diskWrite &&
      netIn == o.netIn &&
      netOut == o.netOut;
}

/// Turns successive [VirtCounterSample]s into [VirtStats] rates, per guest.
///
/// A rate is Δcounter / Δt against the guest's previous sample; CPU from
/// cumulative time is Δcpu_time / (Δt · vcpus). A counter that went backwards
/// (the guest restarted, or a disk was detached) reads as not measured for
/// that sample rather than as a negative rate.
///
/// [holdUntilChanged] is for a host whose counters advance in steps slower
/// than the poll: PVE's `/cluster/resources` is refreshed by `pvestatd` every
/// ten seconds or so, so diffing every poll would alternate zeros and spikes.
/// With it, the base for a rate is the last sample whose byte counters
/// *changed*, and an unchanged reading repeats the last rate for up to
/// [holdFor]; past that, unchanged counters really are idle and read as zero.
class VirtRateTracker {
  VirtRateTracker({
    this.holdUntilChanged = false,
    this.holdFor = const Duration(seconds: 25),
  });

  final bool holdUntilChanged;
  final Duration holdFor;

  final _last = <String, VirtCounterSample>{};
  final _base = <String, VirtCounterSample>{};
  final _rates = <String, VirtStats>{};

  /// The rates for guest [id] as of [sample], and remembers it.
  VirtStats add(String id, VirtCounterSample sample) {
    final last = _last[id];
    _last[id] = sample;
    final cpu =
        sample.cpuPercent ?? _cpuPercent(last, sample, sample.vcpus ?? 1);

    VirtStats plain() => VirtStats(
      at: sample.at,
      cpu: cpu,
      memUsed: sample.memUsed,
      memTotal: sample.memTotal,
      diskUsed: sample.diskUsed,
      diskTotal: sample.diskTotal,
    );

    if (!holdUntilChanged) {
      if (last == null) return _rates[id] = plain();
      return _rates[id] = _diff(last, sample, plain());
    }

    final base = _base[id];
    if (base == null) {
      _base[id] = sample;
      return _rates[id] = plain();
    }
    if (sample._sameCounters(base)) {
      final previous = _rates[id];
      if (previous != null && sample.at.difference(base.at) < holdFor) {
        return _rates[id] = previous.copyWith(
          at: sample.at,
          cpu: cpu,
          memUsed: sample.memUsed,
          memTotal: sample.memTotal,
          diskUsed: sample.diskUsed,
          diskTotal: sample.diskTotal,
        );
      }
      return _rates[id] = _diff(base, sample, plain());
    }
    _base[id] = sample;
    return _rates[id] = _diff(base, sample, plain());
  }

  /// Forgets guests not in [ids], so a deleted guest's base does not linger.
  void retain(Iterable<String> ids) {
    final keep = ids.toSet();
    _last.removeWhere((k, _) => !keep.contains(k));
    _base.removeWhere((k, _) => !keep.contains(k));
    _rates.removeWhere((k, _) => !keep.contains(k));
  }

  void clear() {
    _last.clear();
    _base.clear();
    _rates.clear();
  }

  static VirtStats _diff(
    VirtCounterSample from,
    VirtCounterSample to,
    VirtStats stats,
  ) {
    final seconds = to.at.difference(from.at).inMicroseconds / 1e6;
    if (seconds <= 0) return stats;
    double? rate(int? a, int? b) {
      if (a == null || b == null || b < a) return null;
      return (b - a) / seconds;
    }

    return stats.copyWith(
      diskRead: rate(from.diskRead, to.diskRead),
      diskWrite: rate(from.diskWrite, to.diskWrite),
      netIn: rate(from.netIn, to.netIn),
      netOut: rate(from.netOut, to.netOut),
    );
  }

  static double? _cpuPercent(
    VirtCounterSample? from,
    VirtCounterSample to,
    int vcpus,
  ) {
    final a = from?.cpuTimeNs;
    final b = to.cpuTimeNs;
    if (from == null || a == null || b == null || b < a) return null;
    final ns = to.at.difference(from.at).inMicroseconds * 1000;
    if (ns <= 0) return null;
    final pct = (b - a) / (ns * (vcpus < 1 ? 1 : vcpus)) * 100;
    // Clock skew between the host's accounting and this device's clock can
    // push a busy guest just past 100.
    return pct.clamp(0, 100).toDouble();
  }
}
