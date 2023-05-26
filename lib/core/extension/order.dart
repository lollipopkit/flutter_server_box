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
}
