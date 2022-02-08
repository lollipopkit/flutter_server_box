import 'dart:convert';

import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';

class ServerStore extends PersistentStore {
  void put(ServerPrivateInfo info) {
    final ss = fetch();
    if (!have(info)) ss.add(info);
    box.put('servers', json.encode(ss));
  }

  List<ServerPrivateInfo> fetch() {
    return getServerInfoList(
        json.decode(box.get('servers', defaultValue: '[]')!));
  }

  void delete(ServerPrivateInfo s) {
    final ss = fetch();
    ss.removeAt(index(s));
    box.put('servers', json.encode(ss));
  }

  void update(ServerPrivateInfo old, ServerPrivateInfo newInfo) {
    final ss = fetch();
    final idx = index(old);
    if (idx < 0) {
      throw RangeError.index(idx, ss);
    }
    ss[idx] = newInfo;
    box.put('servers', json.encode(ss));
  }

  int index(ServerPrivateInfo s) => fetch()
      .indexWhere((e) => e.ip == s.ip && e.port == s.port && e.user == e.user);

  bool have(ServerPrivateInfo s) => index(s) != -1;
}
