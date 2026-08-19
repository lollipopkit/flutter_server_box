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
  Future<bool> clear({bool? updateLastUpdateTsOnClear}) async {
    _suppressWatch = true;
    try {
      _cache = null;
      return await super.clear(
        updateLastUpdateTsOnClear: updateLastUpdateTsOnClear,
      );
    } finally {
      _suppressWatch = false;
    }
  }

  void invalidateCache() {
    _cache = null;
  }

  Future<void> put(T item) async {
    _suppressWatch = true;
    try {
      _cache = null;
      if (!await set(getKey(item), item)) {
        throw StateError('Failed to persist $T ${getKey(item)}');
      }
    } finally {
      _suppressWatch = false;
    }
  }

  Future<void> putRaw(T item) async {
    _suppressWatch = true;
    try {
      _cache = null;
      await box.put(getKey(item), item);
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
          unawaited(putRaw(item));
        }
        return item;
      } catch (e) {
        dprint('Parsing $T from JSON', e);
      }
    }
    return null;
  }

  T? fromJson(Map<String, dynamic> json);

  Future<void> deleteById(String id) async {
    _suppressWatch = true;
    try {
      _cache = null;
      if (!await remove(id)) {
        throw StateError('Failed to delete $T $id');
      }
    } finally {
      _suppressWatch = false;
    }
  }

  Future<void> delete(T item) {
    return deleteById(getKey(item));
  }

  Future<void> update(T old, T newItem) async {
    if (!have(old)) {
      throw Exception('Old $T: $old not found');
    }
    _suppressWatch = true;
    try {
      _cache = null;
      final oldKey = getKey(old);
      final newKey = getKey(newItem);
      if (!await set(newKey, newItem)) {
        throw StateError('Failed to persist updated $T $newKey');
      }
      if (oldKey != newKey && !await remove(oldKey)) {
        throw StateError('Failed to remove previous $T $oldKey');
      }
    } finally {
      _suppressWatch = false;
    }
  }

  bool have(T item) => get(getKey(item)) != null;
}
