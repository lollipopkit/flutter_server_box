import '../../core/persistant_store.dart';
import '../model/server/server_private_info.dart';

class ServerStore extends PersistentStore {
  ServerStore() : super('server');

  void put(ServerPrivateInfo info) {
    box.put(info.id, info);
  }

  List<ServerPrivateInfo> fetch() {
    final ids = box.keys;
    final List<ServerPrivateInfo> ss = [];
    for (final id in ids) {
      final s = box.get(id);
      if (s != null && s is ServerPrivateInfo) {
        ss.add(s);
      }
    }
    return ss;
  }

  void delete(String id) {
    box.delete(id);
  }

  void deleteAll() {
    box.clear();
  }

  void update(ServerPrivateInfo old, ServerPrivateInfo newInfo) {
    if (!have(old)) {
      throw Exception('Old spi: $old not found');
    }
    delete(old.id);
    put(newInfo);
  }

  bool have(ServerPrivateInfo s) => box.get(s.id) != null;
}
