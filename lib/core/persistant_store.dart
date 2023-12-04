import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:toolbox/core/utils/misc.dart';
import 'package:toolbox/data/res/path.dart';

// abstract final class SecureStore {
//   static const _secureStorage = FlutterSecureStorage();

//   static HiveAesCipher? _cipher;

//   static const _hiveKey = 'hive_key';

//   static Future<void> init() async {
//     final encryptionKeyString = await _secureStorage.read(key: _hiveKey);
//     if (encryptionKeyString == null) {
//       final key = Hive.generateSecureKey();
//       await _secureStorage.write(
//         key: _hiveKey,
//         value: base64UrlEncode(key),
//       );
//     }
//     final key = await _secureStorage.read(key: _hiveKey);
//     if (key == null) {
//       throw Exception('Failed to init SecureStore');
//     }
//     final encryptionKeyUint8List = base64Url.decode(key);
//     _cipher = HiveAesCipher(encryptionKeyUint8List);
//   }
// }

class PersistentStore {
  late final Box box;

  final String boxName;

  PersistentStore(this.boxName);

  Future<void> init() async => box = await Hive.openBox(
        boxName,
        //encryptionCipher: SecureStore._cipher,
      );

  /// Get all db filenames.
  ///
  /// - [suffixs] defaults to ['.hive']
  ///
  /// - If [hideSetting] is true, hide 'setting.hive'
  static Future<List<String>> getFileNames({
    bool hideSetting = false,
    List<String>? suffixs,
  }) async {
    final docPath = await Paths.doc;
    final dir = Directory(docPath);
    final files = await dir.list().toList();
    if (suffixs != null) {
      files.removeWhere((e) => !suffixs.contains(e.path.split('.').last));
    } else {
      // filter out non-hive(db) files
      files.removeWhere((e) => !e.path.endsWith('.hive'));
    }
    if (hideSetting) {
      files.removeWhere((e) => e.path.endsWith('setting.hive'));
    }
    final paths =
        files.map((e) => e.path.replaceFirst('$docPath/', '')).toList();
    return paths;
  }
}

extension BoxX on Box {
  static const _internalPreffix = '_sbi_';

  /// Last modified timestamp
  static const String lastModifiedKey = '${_internalPreffix}lastModified';
  int? get lastModified {
    final val = get(lastModifiedKey);
    if (val == null || val is! int) {
      final time = timeStamp;
      put(lastModifiedKey, time);
      return time;
    }
    return val;
  }

  Future<void> updateLastModified() => put(lastModifiedKey, timeStamp);

  /// Convert db to json
  Map<String, dynamic> toJson({bool includeInternal = true}) {
    final json = <String, dynamic>{};
    for (final key in keys) {
      if (key is String &&
          key.startsWith(_internalPreffix) &&
          !includeInternal) {
        continue;
      }
      json[key] = get(key);
    }
    return json;
  }
}

extension StoreX on PersistentStore {
  _StoreProperty<T> property<T>(String key, T defaultValue) {
    return _StoreProperty<T>(box, key, defaultValue);
  }

  _StoreListProperty<T> listProperty<T>(String key, List<T> defaultValue) {
    return _StoreListProperty<T>(box, key, defaultValue);
  }
}

abstract class StorePropertyBase<T> {
  ValueListenable<T> listenable();
  T fetch();
  Future<void> put(T value);
  Future<void> delete();
}

class _StoreProperty<T> implements StorePropertyBase<T> {
  _StoreProperty(this._box, this._key, this.defaultValue);

  final Box _box;
  final String _key;
  T defaultValue;

  @override
  ValueListenable<T> listenable() {
    return PropertyListenable<T>(_box, _key, defaultValue);
  }

  @override
  T fetch() {
    final stored = _box.get(_key);
    if (stored == null || stored is! T) {
      return defaultValue;
    }
    return stored;
  }

  @override
  Future<void> put(T value) {
    _box.updateLastModified();
    return _box.put(_key, value);
  }

  @override
  Future<void> delete() {
    return _box.delete(_key);
  }
}

class _StoreListProperty<T> implements StorePropertyBase<List<T>> {
  _StoreListProperty(this._box, this._key, this.defaultValue);

  final Box _box;
  final String _key;
  List<T> defaultValue;

  @override
  ValueListenable<List<T>> listenable() {
    return PropertyListenable<List<T>>(_box, _key, defaultValue);
  }

  @override
  List<T> fetch() {
    final val = _box.get(_key, defaultValue: defaultValue)!;

    if (val is! List) {
      throw Exception('StoreListProperty("$_key") is: ${val.runtimeType}');
    }

    return List<T>.from(val);
  }

  @override
  Future<void> put(List<T> value) {
    return _box.put(_key, value);
  }

  @override
  Future<void> delete() {
    return _box.delete(_key);
  }
}

class PropertyListenable<T> extends ValueListenable<T> {
  PropertyListenable(this.box, this.key, this.defaultValue);

  final Box box;
  final String key;
  T? defaultValue;

  final List<VoidCallback> _listeners = [];
  StreamSubscription? _subscription;

  @override
  void addListener(VoidCallback listener) {
    _subscription ??= box.watch().listen((event) {
      if (key == event.key) {
        for (var listener in _listeners) {
          listener();
        }
      }
    });

    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);

    if (_listeners.isEmpty) {
      _subscription?.cancel();
      _subscription = null;
    }
  }

  @override
  T get value => box.get(key, defaultValue: defaultValue);
}
