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
    await _boxWatchSub?.cancel();
    _boxWatchSub = box.watch().listen((_) {
      if (!_suppressWatch) {
        _cache = null;
      }
    });
  }

  @override
  bool clear({bool? updateLastUpdateTsOnClear}) {
    _suppressWatch = true;
    try {
      _cache = null;
      return super.clear(updateLastUpdateTsOnClear: updateLastUpdateTsOnClear);
    } finally {
      _suppressWatch = false;
    }
  }

  void invalidateCache() {
    _cache = null;
  }

  void put(PrivateKeyInfo info) {
    _suppressWatch = true;
    try {
      set(info.id, info);
      _cache = null;
    } finally {
      _suppressWatch = false;
    }
  }

  void _putWithoutInvalidatingCache(PrivateKeyInfo info) {
    _suppressWatch = true;
    try {
      box.put(info.id, info);
    } finally {
      _suppressWatch = false;
    }
  }

  List<PrivateKeyInfo> fetch() {
    return List<PrivateKeyInfo>.from(_cache ??= _loadAll());
  }

  List<PrivateKeyInfo> _loadAll() {
    final ps = <PrivateKeyInfo>[];
    final toPersist = <PrivateKeyInfo>[];
    for (final key in keys()) {
      final s = get<PrivateKeyInfo>(
        key,
        fromObj: (val) => _decodePrivateKeyInfo(val, toPersist: toPersist),
      );
      if (s != null) {
        ps.add(s);
      }
    }
    for (final pki in toPersist) {
      _putWithoutInvalidatingCache(pki);
    }
    return ps;
  }

  PrivateKeyInfo? _decodePrivateKeyInfo(
    dynamic val, {
    List<PrivateKeyInfo>? toPersist,
  }) {
    if (val is PrivateKeyInfo) return val;
    if (val is Map<dynamic, dynamic>) {
      final map = val.toStrDynMap;
      if (map == null) return null;
      try {
        final pki = PrivateKeyInfo.fromJson(map as Map<String, dynamic>);
        if (toPersist != null) {
          toPersist.add(pki);
        }
        return pki;
      } catch (e) {
        dprint('Parsing PrivateKeyInfo from JSON', e);
      }
    }
    return null;
  }

  PrivateKeyInfo? fetchOne(String? id) {
    if (id == null) return null;
    if (_cache != null) {
      for (final pki in _cache!) {
        if (pki.id == id) return pki;
      }
    }
    return _decodePrivateKeyInfo(box.get(id));
  }

  void delete(PrivateKeyInfo s) {
    _suppressWatch = true;
    try {
      remove(s.id);
      _cache = null;
    } finally {
      _suppressWatch = false;
    }
  }
}
