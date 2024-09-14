import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/private_key_info.dart';

class PrivateKeyStore extends PersistentStore {
  PrivateKeyStore._() : super('key');

  static final instance = PrivateKeyStore._();

  void put(PrivateKeyInfo info) {
    box.put(info.id, info);
    box.updateLastModified();
  }

  List<PrivateKeyInfo> fetch() {
    final keys = box.keys;
    final ps = <PrivateKeyInfo>[];
    for (final key in keys) {
      final s = box.get(key);
      if (s != null && s is PrivateKeyInfo) {
        ps.add(s);
      }
    }
    return ps;
  }

  PrivateKeyInfo? get(String? id) {
    if (id == null) return null;
    return box.get(id);
  }

  void delete(PrivateKeyInfo s) {
    box.delete(s.id);
    box.updateLastModified();
  }
}
