import 'dart:async';

import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/private_key_info.dart';

class PrivateKeyStore extends HiveStore {
  PrivateKeyStore._() : super('key');

  static final instance = PrivateKeyStore._();

  List<PrivateKeyInfo>? _cache;
  StreamSubscription<dynamic>? _boxWatchSub;
  bool _suppressWatch = false;

  @override
  Future<void> init() async {
    await super.init();
    _boxWatchSub?.cancel();
    _boxWatchSub = box.watch().listen((_) {
      if (!_suppressWatch) {
        _cache = null;
      }
    });
  }

  void close() {
    _boxWatchSub?.cancel();
    _boxWatchSub = null;
    _cache = null;
  }

  @override
  bool clear({bool? updateLastUpdateTsOnClear}) {
    _suppressWatch = true;
    _cache = null;
    final result = super.clear(updateLastUpdateTsOnClear: updateLastUpdateTsOnClear);
    _suppressWatch = false;
    return result;
  }

  void invalidateCache() {
    _suppressWatch = true;
    _cache = null;
    _suppressWatch = false;
  }

  void put(PrivateKeyInfo info) {
    _suppressWatch = true;
    set(info.id, info);
    _cache = null;
    _suppressWatch = false;
  }

  void _putWithoutInvalidatingCache(PrivateKeyInfo info) {
    box.put(info.id, info);
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
              _putWithoutInvalidatingCache(pki);
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
    _suppressWatch = true;
    remove(s.id);
    _cache = null;
    _suppressWatch = false;
  }
}
