import 'package:toolbox/core/persistant_store.dart';

typedef Order<T> = List<T>;
typedef _OnMove<T> = void Function(Order<T>);

extension OrderX<T> on Order<T> {
  void move(
    int oldIndex,
    int newIndex, {
    StorePropertyBase<List<T>>? property,
    _OnMove<T>? onMove,
  }) {
    if (oldIndex == newIndex) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = this[oldIndex];
    removeAt(oldIndex);
    insert(newIndex, item);
    property?.put(this);
    onMove?.call(this);
  }

  void update(T id, T newId) {
    final index = indexOf(id);
    if (index == -1) return;
    this[index] = newId;
  }

  int index(T id) {
    return indexOf(id);
  }

  void moveByItem(
    List<T> items,
    int o,
    int n, {
    StorePropertyBase<List<T>>? property,
    _OnMove<T>? onMove,
  }) {
    if (o == n) return;
    if (o < n) {
      n -= 1;
    }
    final index = indexOf(items[o]);
    if (index == -1) return;
    var newIndex = indexOf(items[n]);
    if (newIndex == -1) return;
    if (o < n) {
      newIndex += 1;
    }
    move(index, newIndex, property: property, onMove: onMove);
  }

  /// order: ['d', 'b', 'e']\
  /// this: ['a', 'b', 'c', 'd']\
  /// result: ['d', 'b', 'a', 'c']\
  /// return: ['e']
  List<String> reorder({
    required List<String> order,
    required bool Function(T, String) finder,
  }) {
    final newOrder = <T>[];
    final missed = <T>[];
    final surplus = <String>[];
    for (final id in order.toSet()) {
      try {
        final item = firstWhere((e) => finder(e, id));
        newOrder.add(item);
      } catch (e) {
        surplus.add(id);
      }
    }
    for (final item in this) {
      if (!newOrder.contains(item)) {
        missed.add(item);
      }
    }
    clear();
    addAll(newOrder);
    addAll(missed);
    return surplus;
  }

  /// Dart uses memory address to compare objects by default.
  /// This method compares the values of the objects.
  bool equals(Order<T> other) {
    if (length != other.length) return false;
    for (var i = 0; i < length; i++) {
      if (this[i] != other[i]) return false;
    }
    return true;
  }
}
