import 'dart:async';
import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/data/model/server/private_key_info.dart';
import 'package:toolbox/core/utils/platform.dart';

class PrivateKeyStore extends PersistentStore {
  late SystemPrivateKeyInfo systemPrivateKeyInfo;
  void put(PrivateKeyInfo info) {
    box.put(info.id, info);
  }

  List<PrivateKeyInfo> fetch() {
    final keys = box.keys;
    final ps = <PrivateKeyInfo>[];
    for (final key in keys) {
      final s = box.get(key);
      if (s != null) {
        ps.add(s);
      }
    }
    if (isLinux || isMacOS) {
      SystemPrivateKeyInfo sysPk = SystemPrivateKeyInfo();
      unawaited(sysPk.getKey());
      systemPrivateKeyInfo = sysPk;
      ps.add(sysPk);
    }
    return ps;
  }

  PrivateKeyInfo? get(String? id) {
    if (id == "System private key") {
      return this.systemPrivateKeyInfo;
    }
    if (id == null) return null;
    return box.get(id);
  }

  void delete(PrivateKeyInfo s) {
    box.delete(s.id);
  }
}
