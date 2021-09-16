import 'dart:convert';

import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/data/model/server_private_info.dart';

class ServerStore extends PersistentStore {
  void put(ServerPrivateInfo info) {
    final ss = fetch();
    if (!have(info)) ss.add(info);
    box.put('servers', json.encode(ss));
  }

  List<ServerPrivateInfo> fetch() {
    return getServerInfoList(
        json.decode(box.get('servers', defaultValue: '[]')!))!;
  }

  void delete(ServerPrivateInfo s) {
    final ss = fetch();
    ss.removeWhere((e) => e.ip == s.ip && e.port == s.port && e.user == e.user);
    box.put('servers', json.encode(ss));
  }

  bool have(ServerPrivateInfo s) => fetch()
      .where((e) => e.ip == s.ip && e.port == s.port && e.user == e.user)
      .isNotEmpty;
}
