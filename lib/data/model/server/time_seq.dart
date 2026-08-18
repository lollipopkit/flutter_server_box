import 'dart:collection';

/// Bounded FIFO. Adding past [capacity] drops the oldest element.
class Fifo<T> extends ListBase<T> {
  final int capacity;
  final List<T> _list;

  Fifo({this.capacity = 30, List<T>? list}) : _list = list ?? <T>[];


  @override
  void add(T element) {
    while (_list.length >= capacity) {
      _list.removeAt(0);
    }
    _list.add(element);
  }

  @override
  int get length => _list.length;

  /// Fixed-size by construction — resizing through the [List] interface would
  /// bypass [capacity]. [add] is the only supported way to grow it.
  @override
  set length(int newLength) => throw UnsupportedError('Fifo has a fixed capacity');

  @override
  T operator [](int index) => _list[index];

  @override
  void operator []=(int index, T value) => _list[index] = value;

}

/// A two-sample window over a list of counters that gets re-collected every
/// refresh.
///
/// Rates and percentages only exist *between* two samples, so this models
/// "no baseline yet" as an actual absent value instead of faking one. The
/// previous design seeded two synthetic samples at construction so [pre] and
/// [now] would never throw; every derived value was then a delta against
/// invented data over a zero-width window, which is where the NaN byte rates,
/// the -Infinity CPU percentages and the flat 0 B/s readings came from.
///
/// Subclasses expose their derived values as nullable and should route the
/// arithmetic through [window], which yields nothing unless there are two
/// samples covering a positive amount of time.
abstract class TimeSeq<T extends TimeSeqIface<T>> {
  TimeSeq();

  /// An independent copy that keeps the window, so the snapshot it belongs to
  /// stops changing while the live one carries on. Rates still work from a
  /// copy: both samples come along.
  TimeSeq.copy(TimeSeq<T> source)
    : _pre = source._pre?.toList(growable: false),
      _now = source._now.toList(growable: false);

  List<T>? _pre;
  List<T> _now = const [];

  /// The previous sample, empty when none has been taken yet. Prefer
  /// [hasWindow] over checking this for emptiness: a collection that
  /// genuinely returned no items is not the same as having no baseline.
  List<T> get pre => _pre ?? const [];

  List<T> get now => _now;

  /// Whether two samples exist and they line up item-for-item, i.e. whether
  /// any delta computed from them means anything.
  bool get hasWindow {
    final pre = _pre;
    return pre != null && pre.length == _now.length && _now.isNotEmpty;
  }

  /// Called after each [update], for subclasses to refresh cached values.
  void onUpdate();

  /// Whether [next] is a later sample than the one already held.
  ///
  /// Defaults to accepting everything. Sources that can hand back the same
  /// sample twice must override it: monitor refreshes its metrics once per
  /// collection cycle and the app polls faster, so roughly every other fetch
  /// returns the same counters at the same instant. Pushing that in collapses
  /// the window to zero width, which made every derived rate disappear for
  /// that cycle — speeds visibly flickering on and off.
  bool advances(List<T> next) => true;

  void update(List<T> next) {
    if (!advances(next)) return;
    _pre = _now.isEmpty ? null : _now;
    _now = next;
    _alignPre();
    onUpdate();
  }

  /// Reorders the previous sample to match the current one's item order, so
  /// index `i` refers to the same device in both. Items that appeared this
  /// refresh are paired with themselves, which reads as a zero delta rather
  /// than as a spike against an unrelated device's counters.
  void _alignPre() {
    final pre = _pre;
    if (pre == null) return;

    // Fast path: same devices in the same order, which is the norm
    var sameOrder = pre.length == _now.length;
    if (sameOrder) {
      for (var i = 0; i < pre.length; i++) {
        if (!pre[i].same(_now[i])) {
          sameOrder = false;
          break;
        }
      }
    }
    if (sameOrder) return;

    final remaining = pre.toList();
    final aligned = <T>[];
    for (final current in _now) {
      final idx = remaining.indexWhere((e) => e.same(current));
      aligned.add(idx >= 0 ? remaining.removeAt(idx) : current);
    }
    _pre = aligned;
  }
}

abstract class TimeSeqIface<T> {
  bool same(T other);
}

/// Seconds between two samples, or `null` when that span is unusable — no
/// baseline, or a source that hasn't advanced. Monitor only refreshes its
/// metrics once per collection cycle, so polling faster legitimately returns
/// the same instant twice; dividing by that gap is what produced `NaN B/s`.
double? elapsedSeconds(int? preTime, int nowTime) {
  if (preTime == null) return null;
  final diff = nowTime - preTime;
  return diff > 0 ? diff.toDouble() : null;
}

/// Non-negative delta of a monotonic counter, or `null` if it went backwards
/// (reboot, interface reset, counter wrap) — those windows have no meaningful
/// rate and must not be reported as a spike or silently clamped to 0.
int? counterDelta(int pre, int now) {
  final diff = now - pre;
  return diff >= 0 ? diff : null;
}

/// [counterDelta] for the BigInt counters network interfaces use.
BigInt? counterDeltaBig(BigInt pre, BigInt now) {
  final diff = now - pre;
  return diff >= BigInt.zero ? diff : null;
}
