import 'package:toolbox/core/persistant_store.dart';

typedef Order<T> = List<T>;
typedef _OnMove<T> = void Function(Order<T>);

extension OrderX<T> on Order<T> {
  void move(
    int oldIndex,
    int newIndex, {
    StoreProperty<List<T>>? property,
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

  void moveById(
    T oid,
    T nid, {
    StoreProperty<List<T>>? property,
    _OnMove<T>? onMove,
  }) {
    final index = indexOf(oid);
    if (index == -1) return;
    final newIndex = indexOf(nid);
    if (newIndex == -1) return;
    move(index, newIndex, property: property, onMove: onMove);
  }
}
