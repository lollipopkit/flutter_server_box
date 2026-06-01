import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/store/cached_store.dart';

class PrivateKeyStore extends CachedHiveStore<PrivateKeyInfo> {
  PrivateKeyStore._() : super('key');

  static final instance = PrivateKeyStore._();

  @override
  String getKey(PrivateKeyInfo item) => item.id;

  @override
  PrivateKeyInfo? fromJson(Map<String, dynamic> json) =>
      PrivateKeyInfo.fromJson(json);

  PrivateKeyInfo? fetchOne(String? id) {
    if (id == null) return null;
    if (cachedItems != null) {
      for (final pki in cachedItems!) {
        if (pki.id == id) return pki;
      }
    }
    return _decode(box.get(id));
  }

  PrivateKeyInfo? _decode(dynamic val) {
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
