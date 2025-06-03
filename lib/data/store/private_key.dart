import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/private_key_info.dart';

class PrivateKeyStore extends HiveStore {
  PrivateKeyStore._() : super('key');

  static final instance = PrivateKeyStore._();

  void put(PrivateKeyInfo info) {
    set(info.id, info);
  }

  List<PrivateKeyInfo> fetch() {
    final ps = <PrivateKeyInfo>[];
    for (final key in keys()) {
      final s = get<PrivateKeyInfo>(
        key,
        fromObj: (val) {
          if (val is PrivateKeyInfo) return val;
          if (val is Map<dynamic, dynamic>) {
            final map = val.toStrDynMap;
            if (map == null) return null;
            try {
              final pki = PrivateKeyInfo.fromJson(map as Map<String, dynamic>);
              put(pki);
              return pki;
            } catch (e) {
              dprint('Parsing PrivateKeyInfo from JSON', e);
            }
          }
          return null;
        },
      );
      if (s != null) {
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
