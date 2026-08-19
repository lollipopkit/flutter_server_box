import 'package:meta/meta.dart';

import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/store/cached_store.dart';
import 'package:server_box/data/store/server.dart';

class PrivateKeyStore extends CachedSqliteStore<PrivateKeyInfo> {
  PrivateKeyStore._() : super('key');

  /// See [ServerStore.forTest].
  @visibleForTesting
  PrivateKeyStore.forTest() : super('key_test');

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
    return fetchOneRaw(id);
  }
}
