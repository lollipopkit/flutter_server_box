import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:server_box/data/model/app/bak/container_restore.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';

part 'backup2.freezed.dart';
part 'backup2.g.dart';

final _loggerV2 = Logger('BackupV2');

@freezed
abstract class BackupV2 with _$BackupV2 implements Mergeable {
  const BackupV2._();

  /// Construct a backup with the latest format (v2).
  ///
  /// All `Map<String, dynamic>` are:
  /// ```json
  /// {
  ///   "key1": Model{},
  ///   "_lastModTime": {
  ///     "key1": 1234567890,
  ///   },
  /// }
  /// ```
  const factory BackupV2({
    required int version,
    required int date,
    required Map<String, Object?> spis,
    required Map<String, Object?> snippets,
    required Map<String, Object?> keys,
    required Map<String, Object?> container,
    required Map<String, Object?> history,
    required Map<String, Object?> settings,
  }) = _BackupV2;

  factory BackupV2.fromJson(Map<String, dynamic> json) =>
      _$BackupV2FromJson(json);

  @override
  Future<void> merge({bool force = false}) async {
    _loggerV2.info('Merging...');

    final curTime = await Stores.lastModTime();
    if (!force && date <= curTime) {
      _loggerV2.info('Skip merge, local data is newer');
      return;
    }

    await _restoreServers(spis);
    await _restoreSnippets(snippets);
    await _restoreKeys(keys);
    await _restoreContainer(container);
    await _restoreHistory(history);
    await _restoreSettings(settings);

    GlobalRef.gRef?.read(serversProvider.notifier).reload();
    GlobalRef.gRef?.read(snippetProvider.notifier).reload();
    GlobalRef.gRef?.read(privateKeyProvider.notifier).reload();

    _loggerV2.info('Merge completed');
  }

  static const formatVer = 2;

  static Future<BackupV2> loadFromStore() async {
    final serverRows = await Stores.server.fetch();
    final snippetRows = await Stores.snippet.fetch();
    final keyRows = await Stores.key.fetch();

    return BackupV2(
      version: formatVer,
      date: DateTimeX.timestamp,
      spis: {for (final spi in serverRows) spi.id: spi.toJson()},
      snippets: {
        for (final snippet in snippetRows) snippet.name: snippet.toJson(),
      },
      keys: {for (final key in keyRows) key.id: key.toJson()},
      container: await Stores.container.getAllMap(includeInternalKeys: true),
      history: Stores.history.getAllMap(includeInternalKeys: true),
      settings: Stores.setting.getAllMap(includeInternalKeys: true),
    );
  }

  static Future<String> backup([String? name, String? password]) async {
    final bak = await BackupV2.loadFromStore();
    var result = json.encode(bak.toJson());

    if (password != null && password.isNotEmpty) {
      result = Cryptor.encrypt(result, password);
    }

    final path = Paths.doc.joinPath(name ?? Miscs.bakFileName);
    await File(path).writeAsString(result);
    return path;
  }

  factory BackupV2.fromJsonString(String jsonString, [String? password]) {
    if (Cryptor.isEncrypted(jsonString)) {
      if (password == null || password.isEmpty) {
        throw Exception('Backup is encrypted but no password provided');
      }
      jsonString = Cryptor.decrypt(jsonString, password);
    }

    final map = json.decode(jsonString) as Map<String, dynamic>;
    return BackupV2.fromJson(map);
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
      } catch (e, s) {
        _loggerV2.warning(
          'Decode backup object map failed '
          '(type=${val.runtimeType}, length=${val.length})',
          e,
          s,
        );
      }
    }
    return null;
  }

  static Future<void> _restoreServers(Map<String, Object?> map) async {
    await Stores.server.clear();
    for (final entry in map.entries) {
      if (_isInternalKey(entry.key)) continue;
      final jsonMap = _toJsonMap(entry.value);
      if (jsonMap == null) continue;
      if ((jsonMap['id'] as String?)?.isEmpty ?? true) {
        jsonMap['id'] = entry.key;
      }
      try {
        final spi = Spi.fromJson(jsonMap);
        await Stores.server.put(spi);
      } catch (e, s) {
        _loggerV2.warning('Restore server `${entry.key}` failed', e, s);
      }
    }
  }

  static Future<void> _restoreSnippets(Map<String, Object?> map) async {
    await Stores.snippet.clear();
    for (final entry in map.entries) {
      if (_isInternalKey(entry.key)) continue;
      final jsonMap = _toJsonMap(entry.value);
      if (jsonMap == null) continue;
      if ((jsonMap['name'] as String?)?.isEmpty ?? true) {
        jsonMap['name'] = entry.key;
      }
      try {
        final snippet = Snippet.fromJson(jsonMap);
        await Stores.snippet.put(snippet);
      } catch (e, s) {
        _loggerV2.warning('Restore snippet `${entry.key}` failed', e, s);
      }
    }
  }

  static Future<void> _restoreKeys(Map<String, Object?> map) async {
    await Stores.key.clear();
    for (final entry in map.entries) {
      if (_isInternalKey(entry.key)) continue;
      final jsonMap = _toJsonMap(entry.value);
      if (jsonMap == null) continue;
      if ((jsonMap['id'] as String?)?.isEmpty ?? true) {
        jsonMap['id'] = entry.key;
      }
      if ((jsonMap['private_key'] as String?)?.isEmpty ?? true) continue;
      try {
        final info = PrivateKeyInfo.fromJson(jsonMap);
        await Stores.key.put(info);
      } catch (e, s) {
        _loggerV2.warning('Restore private key `${entry.key}` failed', e, s);
      }
    }
  }

  static Future<void> _restoreContainer(Map<String, Object?> map) async {
    await restoreContainerFromMap(map, shouldSkipKey: _isInternalKey);
  }

  static Future<void> _restoreHistory(Map<String, Object?> map) async {
    await Stores.history.clear();
    for (final entry in map.entries) {
      if (_isInternalKey(entry.key)) continue;
      final value = entry.value;
      if (value == null) continue;
      await Stores.history.set<Object>(entry.key, value);
    }
  }

  static Future<void> _restoreSettings(Map<String, Object?> map) async {
    await Stores.setting.clear();
    for (final entry in map.entries) {
      if (_isInternalKey(entry.key)) continue;
      final value = entry.value;
      if (value == null) continue;
      await Stores.setting.set<Object>(entry.key, value);
    }
  }
}
