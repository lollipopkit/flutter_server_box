import 'dart:collection';

/// A FIFO queue with fixed capacity.
abstract class TimeSeq<T extends List<TimeSeqIface>> extends ListBase<T> {
  final int capacity;
  late final List<T> _list;

  /// Due to the design, at least two elements are required, otherwise [pre] /
  /// [now] will throw.
  TimeSeq(
    T init1,
    T init2, {
    this.capacity = 30,
  }) : _list = [init1, init2];

  @override
  void add(element) {
    if (length == capacity) {
      _list.removeAt(0);
    }
    _list.add(element);
  }

  @override
  int get length => _list.length;

  @override
  set length(int newLength) {
    throw UnimplementedError();
  }

  @override
  T operator [](int index) {
    return _list[index];
  }

  @override
  void operator []=(int index, value) {
    _list[index] = value;
  }

  T get pre {
    return _list[length - 2];
  }

  T get now {
    return _list[length - 1];
  }

  void onUpdate();

  void update(T new_) {
    add(new_);

    if (pre.length != now.length) {
      pre.removeWhere((e) => now.any((el) => e.same(el)));
      pre.addAll(now.where((e) => pre.every((el) => !e.same(el))));
    }

    onUpdate();
  }
}

abstract class TimeSeqIface<T> {
  bool same(T other);
}
