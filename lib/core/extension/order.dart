import 'package:toolbox/core/persistant_store.dart';

typedef StringOrder = List<String>;

extension StringOrderX on StringOrder {
  void move(int oldIndex, int newIndex, StoreProperty property) {
    if (oldIndex == newIndex) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = this[oldIndex];
    removeAt(oldIndex);
    insert(newIndex, item);
    property.put(this);
  }

  void update(String id, String newId) {
    final index = indexOf(id);
    if (index == -1) return;
    this[index] = newId;
  }

  int index(String id) {
    return indexOf(id);
  }

  void moveById(String oid, String nid, StoreProperty property) {
    final index = indexOf(oid);
    if (index == -1) return;
    final newIndex = indexOf(nid);
    if (newIndex == -1) return;
    move(index, newIndex, property);
  }
}
