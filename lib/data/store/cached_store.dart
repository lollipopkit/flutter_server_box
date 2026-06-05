import 'dart:async';

import 'package:fl_lib/fl_lib.dart';

abstract class CachedHiveStore<T extends Object> extends HiveStore {
  CachedHiveStore(super.boxName);

  List<T>? _cache;
  StreamSubscription<dynamic>? _boxWatchSub;
  bool _suppressWatch = false;

  List<T>? get cachedItems => _cache;

  String getKey(T item);

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

  void put(T item) {
    _suppressWatch = true;
    try {
      set(getKey(item), item);
      _cache = null;
    } finally {
      _suppressWatch = false;
    }
  }

  void putRaw(T item) {
    _suppressWatch = true;
    try {
      box.put(getKey(item), item);
      _cache = null;
    } finally {
      _suppressWatch = false;
    }
  }

  List<T> fetch() {
    return List<T>.from(_cache ??= _loadAll());
  }

  List<T> _loadAll() {
    final result = <T>[];
    for (final key in keys()) {
      final item = _getAndConvert(key);
      if (item != null) {
        result.add(item);
      }
    }
    return result;
  }

  T? _getAndConvert(String key) {
    final val = get<T>(key);
    if (val != null) return val;

    final raw = box.get(key);
    if (raw == null) return null;

    if (raw is Map) {
      try {
        final item = fromJson(Map<String, dynamic>.from(raw));
        if (item != null) {
          putRaw(item);
        }
        return item;
      } catch (e) {
        dprint('Parsing $T from JSON', e);
      }
    }
    return null;
  }

  T? fromJson(Map<String, dynamic> json);

  void deleteById(String id) {
    _suppressWatch = true;
    try {
      remove(id);
      _cache = null;
    } finally {
      _suppressWatch = false;
    }
  }

  void delete(T item) {
    deleteById(getKey(item));
  }

  void update(T old, T newItem) {
    if (!have(old)) {
      throw Exception('Old $T: $old not found');
    }
    _suppressWatch = true;
    try {
      remove(getKey(old));
      set(getKey(newItem), newItem);
      _cache = null;
    } finally {
      _suppressWatch = false;
    }
  }

  bool have(T item) => get(getKey(item)) != null;
}
