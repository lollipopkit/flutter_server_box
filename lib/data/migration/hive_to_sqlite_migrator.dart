import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
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
  static const _legacySuffix = '.legacy.bak';
  static const _legacyHiveEncKey = 'hive_key';
  static const _legacyHiveEncKeyCompat = 'flutter.$_legacyHiveEncKey';

  static Future<void> migrateIfNeeded() async {
    final migrated = PrefStore.shared.get<bool>(_migratedFlagKey) ?? false;
    if (migrated) return;

    try {
      final path = await _legacyHivePath();
      final hasLegacy = _hasLegacyFiles(path);
      if (!hasLegacy) {
        await PrefStore.shared.set(_migratedFlagKey, true);
        await PrefStore.shared.set(_migratedBuildKey, BuildData.build);
        return;
      }

      await Hive.initFlutter();
      Hive.registerAdapters();

      final allSucceeded = [
        await _migrateOne(
          boxName: 'setting',
          target: Stores.setting,
          path: path,
          normalize: _normalizeGeneric,
        ),
        await _migrateOne(
          boxName: 'server',
          target: Stores.server,
          path: path,
          normalize: _normalizeSpi,
        ),
        await _migrateOne(
          boxName: 'docker',
          target: Stores.container,
          path: path,
          normalize: _normalizeGeneric,
        ),
        await _migrateOne(
          boxName: 'key',
          target: Stores.key,
          path: path,
          normalize: _normalizePrivateKey,
        ),
        await _migrateOne(
          boxName: 'snippet',
          target: Stores.snippet,
          path: path,
          normalize: _normalizeSnippet,
        ),
        await _migrateOne(
          boxName: 'history',
          target: Stores.history,
          path: path,
          normalize: _normalizeGeneric,
        ),
        await _migrateOne(
          boxName: 'connection_stats',
          target: Stores.connectionStats,
          path: path,
          normalize: _normalizeConnectionStat,
        ),
      ].every((ok) => ok);

      await Stores.setting.flush();
      await Stores.server.flush();
      await Stores.container.flush();
      await Stores.key.flush();
      await Stores.snippet.flush();
      await Stores.history.flush();
      await Stores.connectionStats.flush();

      if (!allSucceeded) {
        Loggers.app.warning(
          'Hive to SQLite migration was partially completed. '
          'Will retry next launch without archiving legacy hive files.',
        );
        return;
      }

      await PrefStore.shared.set(_migratedFlagKey, true);
      await PrefStore.shared.set(_migratedBuildKey, BuildData.build);
      await _archiveLegacyFiles(path);
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
    required SqliteStore target,
    required String path,
    required Object? Function(Object?) normalize,
  }) async {
    final hasEnc = File(path.joinPath('${boxName}_enc.hive')).existsSync();
    final hasPlain = File(path.joinPath('$boxName.hive')).existsSync();
    if (!hasEnc && !hasPlain) return true;

    Box<dynamic>? box;
    try {
      box = await _openLegacyBox(
        boxName: boxName,
        path: path,
        hasEnc: hasEnc,
        hasPlain: hasPlain,
      );
      for (final rawKey in box.keys) {
        if (rawKey is! String) continue;
        final normalized = normalize(box.get(rawKey));
        if (normalized is! Object) continue;
        target.set(rawKey, normalized);
      }
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
    const boxNames = <String>[
      'setting',
      'server',
      'docker',
      'key',
      'snippet',
      'history',
      'connection_stats',
    ];
    for (final box in boxNames) {
      final enc = File(path.joinPath('${box}_enc.hive'));
      final plain = File(path.joinPath('$box.hive'));
      if (enc.existsSync() || plain.existsSync()) {
        return true;
      }
    }
    return false;
  }

  static Future<void> _archiveLegacyFiles(String path) async {
    const names = <String>[
      'setting',
      'server',
      'docker',
      'key',
      'snippet',
      'history',
      'connection_stats',
    ];
    for (final name in names) {
      await _archiveOne(File(path.joinPath('${name}_enc.hive')));
      await _archiveOne(File(path.joinPath('${name}_enc.lock')));
      await _archiveOne(File(path.joinPath('$name.hive')));
      await _archiveOne(File(path.joinPath('$name.lock')));
    }
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
}
