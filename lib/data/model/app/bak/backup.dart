import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';

part 'backup.g.dart';

const backupFormatVersion = 1;

final _logger = Logger('Backup');

@JsonSerializable()
class Backup implements Mergeable {
  // backup format version
  final int version;
  final String date;
  final List<Spi> spis;
  final List<Snippet> snippets;
  final List<PrivateKeyInfo> keys;
  final Map<String, dynamic> container;
  final Map<String, dynamic> history;
  final int? lastModTime;
  final Map<String, dynamic>? settings;

  const Backup({
    required this.version,
    required this.date,
    required this.spis,
    required this.snippets,
    required this.keys,
    required this.container,
    required this.history,
    required this.settings,
    this.lastModTime,
  });

  factory Backup.fromJson(Map<String, dynamic> json) => _$BackupFromJson(json);

  Map<String, dynamic> toJson() => _$BackupToJson(this);

  static Future<Backup> loadFromStore() async {
    final lastModTime = Stores.lastModTime;
    return Backup(
      version: backupFormatVersion,
      date: DateTime.now().toString().split('.').firstOrNull ?? '',
      spis: Stores.server.fetch(),
      snippets: Stores.snippet.fetch(),
      keys: Stores.key.fetch(),
      container: Stores.container.getAllMap(),
      lastModTime: lastModTime,
      history: Stores.history.getAllMap(),
      settings: Stores.setting.getAllMap(),
    );
  }

  static Future<String> backup([String? name]) async {
    final bak = await Backup.loadFromStore();
    final result = _diyEncrypt(json.encode(bak.toJson()));
    final path = Paths.doc.joinPath(name ?? Miscs.bakFileName);
    await File(path).writeAsString(result);
    return path;
  }

  @override
  Future<void> merge({bool force = false}) async {
    final curTime = Stores.lastModTime;
    final bakTime = lastModTime ?? 0;
    final shouldRestore = force || curTime < bakTime;
    if (!shouldRestore) {
      _logger.info('No need to restore, local is newer');
      return;
    }

    final snippetBackup = _withTs(
      Stores.snippet.lastUpdateTsKey,
      <String, Object?>{for (final item in snippets) item.name: item.toJson()},
      bakTime,
    );
    final serverBackup = _withTs(
      Stores.server.lastUpdateTsKey,
      <String, Object?>{for (final item in spis) item.id: item.toJson()},
      bakTime,
    );
    final keyBackup = _withTs(Stores.key.lastUpdateTsKey, <String, Object?>{
      for (final item in keys) item.id: item.toJson(),
    }, bakTime);
    final historyBackup = _withTs(
      Stores.history.lastUpdateTsKey,
      history.cast<String, Object?>(),
      bakTime,
    );
    final containerBackup = _withTs(
      Stores.container.lastUpdateTsKey,
      container.cast<String, Object?>(),
      bakTime,
    );
    final settingsBackup = _withTs(
      Stores.setting.lastUpdateTsKey,
      settings?.cast<String, Object?>() ?? <String, Object?>{},
      bakTime,
    );

    await Mergeable.mergeStore(
      backupData: snippetBackup,
      store: Stores.snippet,
      force: force,
    );
    await Mergeable.mergeStore(
      backupData: serverBackup,
      store: Stores.server,
      force: force,
    );
    await Mergeable.mergeStore(
      backupData: keyBackup,
      store: Stores.key,
      force: force,
    );
    await Mergeable.mergeStore(
      backupData: historyBackup,
      store: Stores.history,
      force: force,
    );
    await Mergeable.mergeStore(
      backupData: containerBackup,
      store: Stores.container,
      force: force,
    );
    await Mergeable.mergeStore(
      backupData: settingsBackup,
      store: Stores.setting,
      force: force,
    );

    Provider.reload();
    RNodes.app.notify();

    _logger.info('Restore success');
  }

  static Map<String, Object?> _withTs(
    String tsKey,
    Map<String, Object?> data,
    int ts,
  ) {
    final map = <String, Object?>{...data};
    map[tsKey] = ts;
    return map;
  }

  factory Backup.fromJsonString(String raw) =>
      Backup.fromJson(json.decode(_diyDecrypt(raw)));
}

String _diyEncrypt(String raw) =>
    json.encode(raw.codeUnits.map((e) => e * 2 + 1).toList(growable: false));

String _diyDecrypt(String raw) {
  try {
    final list = json.decode(raw);
    final sb = StringBuffer();
    for (final e in list) {
      sb.writeCharCode((e - 1) ~/ 2);
    }
    return sb.toString();
  } catch (e, trace) {
    Loggers.app.warning('Backup decrypt failed', e, trace);
    rethrow;
  }
}
