import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/private_key_info.dart';

class PrivateKeyStore extends SqliteStore {
  PrivateKeyStore._() : super('key');

  static final instance = PrivateKeyStore._();

  void put(PrivateKeyInfo info) {
    set(info.id, info, toObj: (val) => val?.toJson());
  }

  List<PrivateKeyInfo> fetch() {
    final ps = <PrivateKeyInfo>[];
    for (final key in keys().toList()) {
      final s = get<PrivateKeyInfo>(key, fromObj: _parsePrivateKeyInfo);
      if (s != null) {
        if (s.id != key) {
          remove(key);
          put(s);
        }
        ps.add(s);
      }
    }
    return ps;
  }

  PrivateKeyInfo? fetchOne(String? id) {
    if (id == null) return null;
    return get<PrivateKeyInfo>(id, fromObj: _parsePrivateKeyInfo);
  }

  void delete(PrivateKeyInfo s) {
    remove(s.id);
  }

  static PrivateKeyInfo? _parsePrivateKeyInfo(Object? val) {
    if (val is PrivateKeyInfo) return val;
    if (val is Map<dynamic, dynamic>) {
      final map = val.toStrDynMap;
      if (map == null) return null;
      try {
        return PrivateKeyInfo.fromJson(map as Map<String, dynamic>);
      } catch (e) {
        dprint('Parsing PrivateKeyInfo from JSON', e);
      }
    }
    return null;
  }
}
