import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';
import 'package:server_box/data/model/container/type.dart';
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
    final lastModTime = await Stores.lastModTime();
    return Backup(
      version: backupFormatVersion,
      date: DateTime.now().toString().split('.').firstOrNull ?? '',
      spis: await Stores.server.fetch(),
      snippets: await Stores.snippet.fetch(),
      keys: await Stores.key.fetch(),
      container: await Stores.container.getAllMap(),
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
    final curTime = await Stores.lastModTime();
    final bakTime = lastModTime ?? 0;
    final shouldRestore = force || curTime < bakTime;
    if (!shouldRestore) {
      _logger.info('No need to restore, local is newer');
      return;
    }

    await _restoreSnippets(snippets);
    await _restoreServers(spis);
    await _restoreKeys(keys);
    await _restoreHistory(history.cast<String, Object?>());
    await _restoreContainer(container.cast<String, Object?>());
    await _restoreSettings(
      settings?.cast<String, Object?>() ?? <String, Object?>{},
    );

    Provider.reload();
    RNodes.app.notify();

    _logger.info('Restore success');
  }

  factory Backup.fromJsonString(String raw) =>
      Backup.fromJson(json.decode(_diyDecrypt(raw)));

  static Future<void> _restoreServers(List<Spi> servers) async {
    await Stores.server.clear();
    for (final spi in servers) {
      await Stores.server.put(spi);
    }
  }

  static Future<void> _restoreSnippets(List<Snippet> snippets) async {
    await Stores.snippet.clear();
    for (final snippet in snippets) {
      await Stores.snippet.put(snippet);
    }
  }

  static Future<void> _restoreKeys(List<PrivateKeyInfo> keys) async {
    await Stores.key.clear();
    for (final key in keys) {
      await Stores.key.put(key);
    }
  }

  static Future<void> _restoreHistory(Map<String, Object?> history) async {
    await Stores.history.clear();
    for (final entry in history.entries) {
      final value = entry.value;
      if (value == null) continue;
      await Stores.history.set<Object>(entry.key, value);
    }
  }

  static Future<void> _restoreSettings(Map<String, Object?> settings) async {
    await Stores.setting.clear();
    for (final entry in settings.entries) {
      final value = entry.value;
      if (value == null) continue;
      await Stores.setting.set<Object>(entry.key, value);
    }
  }

  static Future<void> _restoreContainer(Map<String, Object?> container) async {
    await Stores.container.clear();
    for (final entry in container.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value == null) continue;

      if (key.startsWith('providerConfig')) {
        final id = key.substring('providerConfig'.length);
        final raw = value.toString();
        ContainerType? type;
        try {
          type = ContainerType.values.byName(raw);
        } catch (_) {
          type = null;
        }
        type ??= ContainerType.values.firstWhereOrNull(
          (e) => e.toString() == raw,
        );
        if (type != null) {
          await Stores.container.setType(type, id);
        }
        continue;
      }

      await Stores.container.put(key, value.toString());
    }
  }
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
