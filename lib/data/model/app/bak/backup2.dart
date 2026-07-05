import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
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

  factory BackupV2.fromJson(Map<String, dynamic> json) {
    final backup = _$BackupV2FromJson(json);
    backup._validateRestorableTypedStores();
    return backup;
  }

  @override
  Future<void> merge({bool force = false}) async {
    _validateRestorableTypedStores();
    _loggerV2.info('Merging...');

    final results = await Future.wait([
      Mergeable.mergeStore(
        backupData: spis,
        store: Stores.server,
        force: force,
      ),
      Mergeable.mergeStore(
        backupData: snippets,
        store: Stores.snippet,
        force: force,
      ),
      Mergeable.mergeStore(backupData: keys, store: Stores.key, force: force),
      Mergeable.mergeStore(
        backupData: container,
        store: Stores.container,
        force: force,
      ),
      Mergeable.mergeStore(
        backupData: history,
        store: Stores.history,
        force: force,
      ),
      if (settings.isNotEmpty)
        Mergeable.mergeStore(
          backupData: settings,
          store: Stores.setting,
          force: force,
        )
      else
        Future.value(false),
    ]);

    if (results[0]) GlobalRef.gRef?.read(serversProvider.notifier).reload();
    if (results[1]) GlobalRef.gRef?.read(snippetProvider.notifier).reload();
    if (results[2]) GlobalRef.gRef?.read(privateKeyProvider.notifier).reload();

    _loggerV2.info('Merge completed');
  }

  static const formatVer = 2;

  static Future<BackupV2> loadFromStore({bool includeSettings = true}) async {
    return BackupV2(
      version: formatVer,
      date: DateTimeX.timestamp,
      spis: Stores.server.getAllMap(includeInternalKeys: true),
      snippets: Stores.snippet.getAllMap(includeInternalKeys: true),
      keys: Stores.key.getAllMap(includeInternalKeys: true),
      container: Stores.container.getAllMap(includeInternalKeys: true),
      history: Stores.history.getAllMap(includeInternalKeys: true),
      settings: includeSettings
          ? Stores.setting.getAllMap(includeInternalKeys: true)
          : const {},
    );
  }

  static Future<String> backup([
    String? name,
    String? password,
    bool includeSettings = true,
  ]) async {
    final bak = await BackupV2.loadFromStore(includeSettings: includeSettings);
    var result = bak.toJsonString();

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

  String toJsonString() => json.encode(_toJsonValue(toJson()));

  void _validateRestorableTypedStores() {
    _validateRestorableStore('spis', spis);
    _validateRestorableStore('snippets', snippets);
    _validateRestorableStore('keys', keys);
  }
}

Object? _toEncodable(Object? value) {
  if (value is Enum) return value.name;

  return switch (value) {
    final Spi spi => spi.toJson(),
    final Snippet snippet => snippet.toJson(),
    final PrivateKeyInfo key => key.toJson(),
    final ServerCustom custom => custom.toJson(),
    final WakeOnLanCfg wolCfg => wolCfg.toJson(),
    _ => throw UnsupportedError(
      'Cannot JSON-encode ${value.runtimeType}: missing supported toJson()',
    ),
  };
}

Object? _toJsonValue(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is Map) {
    return value.map((key, entryValue) {
      if (key is! String) {
        throw UnsupportedError(
          'Cannot JSON-encode map key ${key.runtimeType}: keys must be String',
        );
      }
      return MapEntry(key, _toJsonValue(entryValue));
    });
  }
  if (value is Iterable) {
    return value.map(_toJsonValue).toList(growable: false);
  }
  return _toJsonValue(_toEncodable(value));
}

void _validateRestorableStore(String storeName, Map<String, Object?> data) {
  for (final entry in data.entries) {
    if (_isInternalStoreKey(entry.key) || entry.value == null) continue;
    if (entry.value is Map) continue;

    throw FormatException(
      'Backup contains corrupted $storeName entry "${entry.key}": '
      'expected JSON object, got ${entry.value.runtimeType}. '
      'Backups created by app versions 1.0.1448-1.0.1450 may be affected '
      'and cannot be fully restored.',
    );
  }
}

bool _isInternalStoreKey(String key) =>
    key.startsWith(StoreDefaults.prefixKey) ||
    key.startsWith(StoreDefaults.prefixKeyOld);
