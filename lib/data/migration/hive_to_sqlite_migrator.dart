import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/model/server/connection_stat.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/hive/hive_registrar.g.dart';

abstract final class HiveToSqliteMigrator {
  static const _migratedFlagKey = 'sqlite_migrated_v1';
  static const _migratedBuildKey = 'sqlite_migrated_build';
  static const _migratedBoxFlagPrefix = 'sqlite_migrated_box_';
  static const _legacySuffix = '.legacy.bak';
  static const _legacyHiveEncKey = 'hive_key';
  static const _legacyHiveEncKeyCompat = 'flutter.$_legacyHiveEncKey';
  static const _containerConfigKeyPrefix = 'providerConfig';
  static const _boxNames = <String>[
    'setting',
    'server',
    'docker',
    'key',
    'snippet',
    'history',
    'connection_stats',
  ];

  static Future<void> migrateIfNeeded() async {
    final migrated = PrefStore.shared.get<bool>(_migratedFlagKey) ?? false;
    if (migrated) return;

    try {
      final path = await _legacyHivePath();
      final hasLegacy = _hasLegacyFiles(path);
      if (!hasLegacy) {
        await _markAllBoxesMigrated();
        await _setMigratedFlag();
        return;
      }

      await Hive.initFlutter();
      Hive.registerAdapters();

      await _migrateOne(
        boxName: 'setting',
        path: path,
        normalize: _normalizeGeneric,
        write: _writeSetting,
      );
      await _migrateOne(
        boxName: 'server',
        path: path,
        normalize: _normalizeSpi,
        write: _writeServer,
      );
      await _migrateOne(
        boxName: 'docker',
        path: path,
        normalize: _normalizeGeneric,
        write: _writeContainer,
      );
      await _migrateOne(
        boxName: 'key',
        path: path,
        normalize: _normalizePrivateKey,
        write: _writePrivateKey,
      );
      await _migrateOne(
        boxName: 'snippet',
        path: path,
        normalize: _normalizeSnippet,
        write: _writeSnippet,
      );
      await _migrateOne(
        boxName: 'history',
        path: path,
        normalize: _normalizeGeneric,
        write: _writeHistory,
      );
      await _migrateOne(
        boxName: 'connection_stats',
        path: path,
        normalize: _normalizeConnectionStat,
        write: _writeConnectionStats,
      );

      if (!_allBoxesMigrated()) {
        Loggers.app.warning(
          'Hive to SQLite migration was partially completed. '
          'Will retry next launch without archiving legacy hive files.',
        );
        return;
      }

      await _archiveLegacyFiles(path);
      await _setMigratedFlag();
    } catch (e, s) {
      Loggers.app.warning(
        'Hive to SQLite migration aborted due to unexpected error',
        e,
        s,
      );
    }
  }

  static Future<bool> _migrateOne({
    required String boxName,
    required String path,
    required Object? Function(Object?) normalize,
    required Future<void> Function(String key, Object value) write,
  }) async {
    final migratedBoxKey = _migratedBoxFlagKey(boxName);
    final migrated = PrefStore.shared.get<bool>(migratedBoxKey) ?? false;
    if (migrated) return true;

    final hasEnc = File(path.joinPath('${boxName}_enc.hive')).existsSync();
    final hasPlain = File(path.joinPath('$boxName.hive')).existsSync();
    if (!hasEnc && !hasPlain) {
      await PrefStore.shared.set(migratedBoxKey, true);
      return true;
    }

    Box<dynamic>? box;
    try {
      box = await _openLegacyBox(
        boxName: boxName,
        path: path,
        hasEnc: hasEnc,
        hasPlain: hasPlain,
      );
      var hasEntryFailure = false;
      for (final rawKey in box.keys) {
        if (rawKey is! String) continue;
        if (_isInternalKey(rawKey)) continue;
        final normalized = normalize(box.get(rawKey));
        if (normalized == null) continue;
        try {
          await write(rawKey, normalized);
        } catch (e, s) {
          hasEntryFailure = true;
          Loggers.app.warning(
            'Migrate hive box `$boxName` entry `$rawKey` failed',
            e,
            s,
          );
        }
      }
      if (hasEntryFailure) {
        Loggers.app.warning(
          'Migrate hive box `$boxName` is partially failed, '
          'will retry this box next launch',
        );
        return false;
      }
      await PrefStore.shared.set(migratedBoxKey, true);
      return true;
    } catch (e, s) {
      Loggers.app.warning('Migrate hive box `$boxName` failed', e, s);
      return false;
    } finally {
      await box?.close();
    }
  }

  static Future<Box<dynamic>> _openLegacyBox({
    required String boxName,
    required String path,
    required bool hasEnc,
    required bool hasPlain,
  }) async {
    final cipher = await _legacyCipher();
    final openErrors = <String>[];

    if (hasEnc) {
      try {
        return await Hive.openBox(
          '${boxName}_enc',
          path: path,
          encryptionCipher: cipher,
        );
      } catch (e, s) {
        openErrors.add('encrypted: $e');
        Loggers.app.warning('Open encrypted hive box `$boxName` failed', e, s);
      }
    }

    if (hasPlain) {
      try {
        return await Hive.openBox(boxName, path: path);
      } catch (e, s) {
        openErrors.add('plain: $e');
        Loggers.app.warning('Open plain hive box `$boxName` failed', e, s);
      }
    }

    throw StateError(
      'Unable to open legacy hive box `$boxName` at `$path` '
      '(${openErrors.join(', ')})',
    );
  }

  static Future<HiveAesCipher?> _legacyCipher() async {
    final key = await _readLegacyHiveKey();
    if (key == null || key.isEmpty) return null;
    try {
      return HiveAesCipher(base64Url.decode(key));
    } catch (e, s) {
      Loggers.app.warning('Decode hive cipher failed', e, s);
      return null;
    }
  }

  static bool _hasLegacyFiles(String path) {
    for (final box in _boxNames) {
      final enc = File(path.joinPath('${box}_enc.hive'));
      final plain = File(path.joinPath('$box.hive'));
      if (enc.existsSync() || plain.existsSync()) {
        return true;
      }
    }
    return false;
  }

  static Future<void> _archiveLegacyFiles(String path) async {
    for (final name in _boxNames) {
      await _archiveOne(File(path.joinPath('${name}_enc.hive')));
      await _archiveOne(File(path.joinPath('${name}_enc.lock')));
      await _archiveOne(File(path.joinPath('$name.hive')));
      await _archiveOne(File(path.joinPath('$name.lock')));
    }
  }

  static String _migratedBoxFlagKey(String boxName) {
    return '$_migratedBoxFlagPrefix$boxName';
  }

  static bool _allBoxesMigrated() {
    for (final boxName in _boxNames) {
      final migrated = PrefStore.shared.get<bool>(_migratedBoxFlagKey(boxName));
      if (migrated != true) return false;
    }
    return true;
  }

  static Future<void> _markAllBoxesMigrated() async {
    for (final boxName in _boxNames) {
      await PrefStore.shared.set(_migratedBoxFlagKey(boxName), true);
    }
  }

  static Future<void> _setMigratedFlag() async {
    if (!_allBoxesMigrated()) return;
    await PrefStore.shared.set(_migratedFlagKey, true);
    await PrefStore.shared.set(_migratedBuildKey, BuildData.build);
  }

  static Future<void> _archiveOne(File file) async {
    if (!file.existsSync()) return;
    final target = File('${file.path}$_legacySuffix');
    if (target.existsSync()) {
      await target.delete();
    }
    await file.rename(target.path);
  }

  static Future<String> _legacyHivePath() async {
    return switch (Pfs.type) {
      Pfs.linux || Pfs.windows => Paths.doc,
      _ => (await getApplicationDocumentsDirectory()).path,
    };
  }

  static Future<String?> _readLegacyHiveKey() async {
    // ignore: deprecated_member_use
    final secureStoreKey = await SecureStoreProps.hivePwd.read();
    if (secureStoreKey != null && secureStoreKey.isNotEmpty) {
      return secureStoreKey;
    }

    final prefKey =
        PrefStore.shared.get<String>(_legacyHiveEncKey) ??
        PrefStore.shared.get<String>(_legacyHiveEncKeyCompat);
    if (prefKey != null && prefKey.isNotEmpty) {
      // Keep key source aligned with previous Hive behavior.
      // ignore: deprecated_member_use
      await SecureStoreProps.hivePwd.write(prefKey);
      return prefKey;
    }
    return null;
  }

  static Object? _normalizeGeneric(Object? raw) {
    return _normalizeRaw(raw);
  }

  static Object? _normalizeSpi(Object? raw) {
    if (raw is Spi) return raw.toJson();
    return _normalizeRaw(raw);
  }

  static Object? _normalizeSnippet(Object? raw) {
    if (raw is Snippet) return raw.toJson();
    return _normalizeRaw(raw);
  }

  static Object? _normalizePrivateKey(Object? raw) {
    if (raw is PrivateKeyInfo) return raw.toJson();
    return _normalizeRaw(raw);
  }

  static Object? _normalizeConnectionStat(Object? raw) {
    if (raw is ConnectionStat) return raw.toJson();
    return _normalizeRaw(raw);
  }

  static Object? _normalizeRaw(Object? raw) {
    if (raw == null) return null;
    if (raw is bool || raw is int || raw is double || raw is String) return raw;
    if (raw is Enum) return raw.name;
    if (raw is List) {
      return raw.map(_normalizeRaw).toList(growable: false);
    }
    if (raw is Map) {
      return <String, Object?>{
        for (final entry in raw.entries)
          entry.key.toString(): _normalizeRaw(entry.value),
      };
    }
    try {
      final dynamic obj = raw;
      final jsonObj = obj.toJson();
      return _normalizeRaw(jsonObj);
    } catch (e, s) {
      Loggers.app.warning(
        'Normalize migration value failed(type: ${raw.runtimeType})',
        e,
        s,
      );
      return null;
    }
  }

  static bool _isInternalKey(String key) {
    return key.startsWith(StoreDefaults.prefixKey) ||
        key.startsWith(StoreDefaults.prefixKeyOld);
  }

  static Map<String, dynamic>? _toJsonMap(Object? val) {
    if (val == null) return null;
    if (val is Map) {
      return val.map((key, value) => MapEntry(key.toString(), value));
    }
    if (val is String) {
      try {
        final decoded = json.decode(val);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<void> _writeSetting(String key, Object value) async {
    await Stores.setting.set<Object>(key, value);
  }

  static Future<void> _writeHistory(String key, Object value) async {
    await Stores.history.set<Object>(key, value);
  }

  static Future<void> _writeServer(String key, Object value) async {
    final map = _toJsonMap(value);
    if (map == null) return;
    if ((map['id'] as String?)?.isEmpty ?? true) {
      map['id'] = key;
    }
    final spi = Spi.fromJson(map);
    await Stores.server.put(spi);
  }

  static Future<void> _writePrivateKey(String key, Object value) async {
    final map = _toJsonMap(value);
    if (map == null) return;
    if ((map['id'] as String?)?.isEmpty ?? true) {
      map['id'] = key;
    }
    if ((map['private_key'] as String?)?.isEmpty ?? true) return;
    final info = PrivateKeyInfo.fromJson(map);
    await Stores.key.put(info);
  }

  static Future<void> _writeSnippet(String key, Object value) async {
    final map = _toJsonMap(value);
    if (map == null) return;
    if ((map['name'] as String?)?.isEmpty ?? true) {
      map['name'] = key;
    }
    final snippet = Snippet.fromJson(map);
    await Stores.snippet.put(snippet);
  }

  static Future<void> _writeContainer(String key, Object value) async {
    if (key.startsWith(_containerConfigKeyPrefix)) {
      final id = key.substring(_containerConfigKeyPrefix.length);
      final cfg = value.toString();
      ContainerType? type;
      try {
        type = ContainerType.values.byName(cfg);
      } catch (_) {
        type = null;
      }
      type ??= ContainerType.values.firstWhereOrNull((e) => e.toString() == cfg);
      if (type != null) {
        await Stores.container.setType(type, id);
      } else {
        Loggers.app.warning('Migrate container config `$key` unknown type: $cfg');
      }
      return;
    }

    if (value is String) {
      await Stores.container.put(key, value);
      return;
    }

    final host = value.toString();
    if (host.isNotEmpty) {
      await Stores.container.put(key, host);
    }
  }

  static Future<void> _writeConnectionStats(String key, Object value) async {
    final map = _toJsonMap(value);
    if (map == null) return;
    final stat = ConnectionStat.fromJson(map);
    await Stores.connectionStats.recordConnection(stat);
  }
}
