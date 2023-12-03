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
}
