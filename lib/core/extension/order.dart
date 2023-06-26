import 'package:toolbox/core/persistant_store.dart';

typedef Order<T> = List<T>;

extension OrderX<T> on Order<T> {
  void move(int oldIndex, int newIndex, StoreProperty<List<T>> property) {
    if (oldIndex == newIndex) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = this[oldIndex];
    removeAt(oldIndex);
    insert(newIndex, item);
    property.put(this);
  }

  void update(T id, T newId) {
    final index = indexOf(id);
    if (index == -1) return;
    this[index] = newId;
  }

  int index(T id) {
    return indexOf(id);
  }

  void moveById(T oid, T nid, StoreProperty<List<T>> property) {
    final index = indexOf(oid);
    if (index == -1) return;
    final newIndex = indexOf(nid);
    if (newIndex == -1) return;
    move(index, newIndex, property);
  }
}
