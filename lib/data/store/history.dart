import 'dart:async';

import 'package:fl_lib/fl_lib.dart';

/// index from 0 -> n : latest -> oldest
class _ListHistory {
  final List<String> _history;
  final String _name;
  final HistoryStore _store;

  _ListHistory({required HistoryStore store, required String name})
    : _store = store,
      _name = name,
      _history = List<String>.from(
        store.get<List<dynamic>>(name) ?? const <String>[],
      );

  void add(String path) {
    _history.remove(path);
    _history.insert(0, path);
    unawaited(
      _store
          .set(_name, _history)
          .then((ok) {
            if (!ok) {
              Loggers.app.warning('Save history `$_name` failed');
            }
          })
          .catchError((e, s) {
            Loggers.app.warning('Save history `$_name` failed', e, s);
          }),
    );
  }

  List<String> get all => _history;
}

class _MapHistory {
  final Map<String, String> _history;
  final String _name;
  final HistoryStore _store;

  _MapHistory({required HistoryStore store, required String name})
    : _store = store,
      _name = name,
      _history = Map<String, String>.from(
        store.get<Map<dynamic, dynamic>>(name) ?? const <String, String>{},
      );

  void put(String id, String val) {
    _history[id] = val;
    unawaited(
      _store
          .set(_name, _history)
          .then((ok) {
            if (!ok) {
              Loggers.app.warning('Save history `$_name` failed');
            }
          })
          .catchError((e, s) {
            Loggers.app.warning('Save history `$_name` failed', e, s);
          }),
    );
  }

  String? fetch(String id) => _history[id];
}

class HistoryStore {
  HistoryStore._();

  static final instance = HistoryStore._();
  final PrefStore _store = PrefStore(name: 'history', prefix: 'history');

  Future<void> init() => _store.init();

  PrefStore get rawStore => _store;

  String get lastUpdateTsKey => _store.lastUpdateTsKey;

  Map<String, int>? get lastUpdateTs => _store.lastUpdateTs;

  FutureOr<bool> updateLastUpdateTs({int? ts, required String? key}) {
    return _store.updateLastUpdateTs(ts: ts, key: key);
  }

  bool isInternalKey(String key) => _store.isInternalKey(key);

  T? get<T extends Object>(String key, {StoreFromObj<T>? fromObj}) {
    return _store.get<T>(key, fromObj: fromObj);
  }

  Future<bool> set<T extends Object>(
    String key,
    T val, {
    StoreToObj<T>? toObj,
    bool? updateLastUpdateTsOnSet,
  }) {
    return _store.set(
      key,
      val,
      toObj: toObj,
      updateLastUpdateTsOnSet: updateLastUpdateTsOnSet,
    );
  }

  Set<String> keys({
    bool includeInternalKeys = StoreDefaults.defaultIncludeInternalKeys,
  }) {
    return _store.keys(includeInternalKeys: includeInternalKeys);
  }

  Future<bool> remove(String key, {bool? updateLastUpdateTsOnRemove}) {
    return _store.remove(
      key,
      updateLastUpdateTsOnRemove: updateLastUpdateTsOnRemove,
    );
  }

  Future<bool> clear({bool? updateLastUpdateTsOnClear}) {
    return _store.clear(updateLastUpdateTsOnClear: updateLastUpdateTsOnClear);
  }

  Map<String, Object?> getAllMap({
    bool includeInternalKeys = StoreDefaults.defaultIncludeInternalKeys,
  }) {
    final keys = this.keys(includeInternalKeys: includeInternalKeys);
    return Map.fromIterables(keys, keys.map((key) => get(key)));
  }

  PrefProp<T> property<T extends Object>(
    String key, {
    bool updateLastModified = true,
    StoreFromObj<T>? fromObj,
    StoreToObj<T>? toObj,
  }) {
    return _store.property(
      key,
      updateLastModified: updateLastModified,
      fromObj: fromObj,
      toObj: toObj,
    );
  }

  PrefPropDefault<T> propertyDefault<T extends Object>(
    String key,
    T defaultValue, {
    bool updateLastModified = StoreDefaults.defaultUpdateLastUpdateTs,
    StoreFromObj<T>? fromObj,
    StoreToObj<T>? toObj,
  }) {
    return _store.propertyDefault(
      key,
      defaultValue,
      updateLastModified: updateLastModified,
      fromObj: fromObj,
      toObj: toObj,
    );
  }

  /// Paths that user has visited by 'Locate' button
  late final sftpGoPath = _ListHistory(store: this, name: 'sftpPath');

  late final sftpLastPath = _MapHistory(store: this, name: 'sftpLastPath');

  late final sshCmds = _ListHistory(store: this, name: 'sshCmds');

  /// Notify users that this app will write script to server to works properly
  late final writeScriptTipShown = propertyDefault(
    'writeScriptTipShown',
    false,
  );
}
