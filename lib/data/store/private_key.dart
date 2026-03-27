import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/private_key_info.dart';

class PrivateKeyStore extends HiveStore {
  PrivateKeyStore._() : super('key');

  static final instance = PrivateKeyStore._();

  List<PrivateKeyInfo>? _cache;

  @override
  Future<void> init() async {
    await super.init();
    box.watch().listen((_) {
      _cache = null;
    });
  }

  @override
  bool clear({bool? updateLastUpdateTsOnClear}) {
    _cache = null;
    return super.clear(updateLastUpdateTsOnClear: updateLastUpdateTsOnClear);
  }

  void invalidateCache() {
    _cache = null;
  }

  void put(PrivateKeyInfo info) {
    set(info.id, info);
    _cache = null;
  }

  List<PrivateKeyInfo> fetch() {
    return List<PrivateKeyInfo>.from(_cache ??= _loadAll());
  }

  List<PrivateKeyInfo> _loadAll() {
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
    _cache = null;
  }
}
