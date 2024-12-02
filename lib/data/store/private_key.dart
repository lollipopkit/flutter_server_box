import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/private_key_info.dart';

class PrivateKeyStore extends HiveStore {
  PrivateKeyStore._() : super('key');

  static final instance = PrivateKeyStore._();

  void put(PrivateKeyInfo info) {
    set(info.id, info);
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

  PrivateKeyInfo? fetchOne(String? id) {
    if (id == null) return null;
    return box.get(id);
  }

  void delete(PrivateKeyInfo s) {
    remove(s.id);
  }
}
