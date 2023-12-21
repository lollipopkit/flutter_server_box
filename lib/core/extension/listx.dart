extension ListX<T> on List<T> {
  List<T> joinWith(T item, [bool self = true]) {
    final list = self ? this : List<T>.from(this);
    for (var i = length - 1; i > 0; i--) {
      list.insert(i, item);
    }
    return list;
  }

  List<T> combine(List<T> other, [bool self = true]) {
    final list = self ? this : List<T>.from(this);
    for (var i = 0; i < length; i++) {
      list[i] = other[i];
    }
    return list;
  }

  T? get firstOrNull => isEmpty ? null : first;

  T? get lastOrNull => isEmpty ? null : last;

  T? firstWhereOrNull(bool Function(T element) test) {
    try {
      return firstWhere(test);
    } catch (_) {
      return null;
    }
  }

  T? lastWhereOrNull(bool Function(T element) test) {
    try {
      return lastWhere(test);
    } catch (_) {
      return null;
    }
  }
}
