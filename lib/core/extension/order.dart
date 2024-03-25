import 'package:toolbox/core/extension/listx.dart';
import 'package:toolbox/core/persistant_store.dart';

typedef _OnMove<T> = void Function(List<T>);

extension OrderX<T> on List<T> {
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
    int o,
    int n, {
    /// The list after filtering.
    ///
    /// It's used to find the index of the item.
    List<T>? filtered,
    StorePropertyBase<List<T>>? property,
    _OnMove<T>? onMove,
  }) {
    if (o == n) return;
    if (o < n) {
      n -= 1;
    }
    final index = indexOf((filtered ?? this)[o]);
    if (index == -1) return;
    var newIndex = indexOf((filtered ?? this)[n]);
    if (newIndex == -1) return;
    if (o < n) {
      newIndex += 1;
    }
    move(index, newIndex, property: property, onMove: onMove);
  }

  /// order: ['d', 'b', 'e']
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
      final item = firstWhereOrNull((element) => finder(element, id));
      if (item == null) {
        surplus.add(id);
      } else {
        newOrder.add(item);
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
  bool equals(List<T> other) {
    if (length != other.length) return false;
    for (var i = 0; i < length; i++) {
      if (this[i] != other[i]) return false;
    }
    return true;
  }
}
