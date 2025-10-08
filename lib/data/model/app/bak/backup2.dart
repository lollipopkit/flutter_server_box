import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
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

  factory BackupV2.fromJson(Map<String, dynamic> json) => _$BackupV2FromJson(json);

  @override
  Future<void> merge({bool force = false}) async {
    _loggerV2.info('Merging...');

    // Merge each store and check if changes were made
    final serverChanged = await Mergeable.mergeStore(backupData: spis, store: Stores.server, force: force);
    final snippetChanged = await Mergeable.mergeStore(backupData: snippets, store: Stores.snippet, force: force);
    final keyChanged = await Mergeable.mergeStore(backupData: keys, store: Stores.key, force: force);
    await Mergeable.mergeStore(backupData: container, store: Stores.container, force: force);
    await Mergeable.mergeStore(backupData: history, store: Stores.history, force: force);
    await Mergeable.mergeStore(backupData: settings, store: Stores.setting, force: force);

    if (serverChanged) GlobalRef.gRef?.read(serversProvider.notifier).reload();
    if (snippetChanged) GlobalRef.gRef?.read(snippetProvider.notifier).reload();
    if (keyChanged) GlobalRef.gRef?.read(privateKeyProvider.notifier).reload();

    _loggerV2.info('Merge completed');
  }

  static const formatVer = 2;

  static Future<BackupV2> loadFromStore() async {
    return BackupV2(
      version: formatVer,
      date: DateTimeX.timestamp,
      spis: Stores.server.getAllMap(includeInternalKeys: true),
      snippets: Stores.snippet.getAllMap(includeInternalKeys: true),
      keys: Stores.key.getAllMap(includeInternalKeys: true),
      container: Stores.container.getAllMap(includeInternalKeys: true),
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
}
