import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/server_private_info.dart';

class ServerStore extends PersistentStore {
  ServerStore._() : super('server');

  static final instance = ServerStore._();

  void put(Spi info) {
    box.put(info.id, info);
    box.updateLastModified();
  }

  List<Spi> fetch() {
    final ids = box.keys;
    final List<Spi> ss = [];
    for (final id in ids) {
      final s = box.get(id);
      if (s != null && s is Spi) {
        ss.add(s);
      }
    }
    return ss;
  }

  void delete(String id) {
    box.delete(id);
    box.updateLastModified();
  }

  void deleteAll() {
    box.clear();
    box.updateLastModified();
  }

  void update(Spi old, Spi newInfo) {
    if (!have(old)) {
      throw Exception('Old spi: $old not found');
    }
    delete(old.id);
    put(newInfo);
  }

  bool have(Spi s) => box.get(s.id) != null;
}
