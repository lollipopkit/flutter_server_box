import 'dart:convert';

import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/data/model/server/private_key_info.dart';

class PrivateKeyStore extends PersistentStore {
  void put(PrivateKeyInfo info) {
    final ss = fetch();
    if (!have(info)) ss.add(info);
    box.put('key', json.encode(ss));
  }

  List<PrivateKeyInfo> fetch() {
    return getPrivateKeyInfoList(
        json.decode(box.get('key', defaultValue: '[]')!));
  }

  PrivateKeyInfo get(String id) {
    final ss = fetch();
    return ss.firstWhere((e) => e.id == id);
  }

  void delete(PrivateKeyInfo s) {
    final ss = fetch();
    ss.removeAt(index(s));
    box.put('key', json.encode(ss));
  }

  void update(PrivateKeyInfo old, PrivateKeyInfo newInfo) {
    final ss = fetch();
    ss[index(old)] = newInfo;
    box.put('key', json.encode(ss));
  }

  int index(PrivateKeyInfo s) => fetch().indexWhere((e) => e.id == s.id);

  bool have(PrivateKeyInfo s) => index(s) != -1;
}
