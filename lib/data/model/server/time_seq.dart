abstract class TimeSeq<T extends TimeSeqIface> {
  List<T> pre;
  List<T> now;
  void onUpdate();

  void update(List<T> new_) {
    pre = now;
    now = new_;

    if (pre.length != now.length) {
      pre.removeWhere((e) => now.any((el) => e.same(el)));
      pre.addAll(now.where((e) => pre.every((el) => !e.same(el))));
    }

    onUpdate();
  }

  TimeSeq(this.pre, this.now);
}

abstract class TimeSeqIface<T> {
  bool same(T other);
}
