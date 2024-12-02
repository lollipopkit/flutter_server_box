import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/rebuild.dart';
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
    final lastModTime = Stores.lastModTime?.millisecondsSinceEpoch;
    return Backup(
      version: backupFormatVersion,
      date: DateTime.now().toString().split('.').firstOrNull ?? '',
      spis: Stores.server.fetch(),
      snippets: Stores.snippet.fetch(),
      keys: Stores.key.fetch(),
      container: await Stores.container.getAllMap(),
      lastModTime: lastModTime,
      history: await Stores.history.getAllMap(),
      settings: await Stores.setting.getAllMap(),
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
    final curTime = Stores.lastModTime?.millisecondsSinceEpoch ?? 0;
    final bakTime = lastModTime ?? 0;
    final shouldRestore = force || curTime < bakTime;
    if (!shouldRestore) {
      _logger.info('No need to restore, local is newer');
      return;
    }

    // Snippets
    if (force) {
      for (final s in snippets) {
        Stores.snippet.box.put(s.name, s);
      }
    } else {
      final nowSnippets = Stores.snippet.box.keys.toSet();
      final bakSnippets = snippets.map((e) => e.name).toSet();
      final newSnippets = bakSnippets.difference(nowSnippets);
      final delSnippets = nowSnippets.difference(bakSnippets);
      final updateSnippets = nowSnippets.intersection(bakSnippets);
      for (final s in newSnippets) {
        Stores.snippet.box.put(s, snippets.firstWhere((e) => e.name == s));
      }
      for (final s in delSnippets) {
        Stores.snippet.box.delete(s);
      }
      for (final s in updateSnippets) {
        Stores.snippet.box.put(s, snippets.firstWhere((e) => e.name == s));
      }
    }

    // ServerPrivateInfo
    if (force) {
      for (final s in spis) {
        Stores.server.box.put(s.id, s);
      }
    } else {
      final nowSpis = Stores.server.box.keys.toSet();
      final bakSpis = spis.map((e) => e.id).toSet();
      final newSpis = bakSpis.difference(nowSpis);
      final delSpis = nowSpis.difference(bakSpis);
      final updateSpis = nowSpis.intersection(bakSpis);
      for (final s in newSpis) {
        Stores.server.box.put(s, spis.firstWhere((e) => e.id == s));
      }
      for (final s in delSpis) {
        Stores.server.box.delete(s);
      }
      for (final s in updateSpis) {
        Stores.server.box.put(s, spis.firstWhere((e) => e.id == s));
      }
    }

    // PrivateKeyInfo
    if (force) {
      for (final s in keys) {
        Stores.key.box.put(s.id, s);
      }
    } else {
      final nowKeys = Stores.key.box.keys.toSet();
      final bakKeys = keys.map((e) => e.id).toSet();
      final newKeys = bakKeys.difference(nowKeys);
      final delKeys = nowKeys.difference(bakKeys);
      final updateKeys = nowKeys.intersection(bakKeys);
      for (final s in newKeys) {
        Stores.key.box.put(s, keys.firstWhere((e) => e.id == s));
      }
      for (final s in delKeys) {
        Stores.key.box.delete(s);
      }
      for (final s in updateKeys) {
        Stores.key.box.put(s, keys.firstWhere((e) => e.id == s));
      }
    }

    // History
    if (force) {
      Stores.history.box.putAll(history);
    } else {
      final nowHistory = Stores.history.box.keys.toSet();
      final bakHistory = history.keys.toSet();
      final newHistory = bakHistory.difference(nowHistory);
      final delHistory = nowHistory.difference(bakHistory);
      final updateHistory = nowHistory.intersection(bakHistory);
      for (final s in newHistory) {
        Stores.history.box.put(s, history[s]);
      }
      for (final s in delHistory) {
        Stores.history.box.delete(s);
      }
      for (final s in updateHistory) {
        Stores.history.box.put(s, history[s]);
      }
    }

    // Container
    if (force) {
      Stores.container.box.putAll(container);
    } else {
      final nowContainer = Stores.container.box.keys.toSet();
      final bakContainer = container.keys.toSet();
      final newContainer = bakContainer.difference(nowContainer);
      final delContainer = nowContainer.difference(bakContainer);
      final updateContainer = nowContainer.intersection(bakContainer);
      for (final s in newContainer) {
        Stores.container.box.put(s, container[s]);
      }
      for (final s in delContainer) {
        Stores.container.box.delete(s);
      }
      for (final s in updateContainer) {
        Stores.container.box.put(s, container[s]);
      }
    }

    // Settings
    final settings_ = settings;
    if (settings_ != null) {
      if (force) {
        Stores.setting.box.putAll(settings_);
      } else {
        final nowSettings = Stores.setting.box.keys.toSet();
        final bakSettings = settings_.keys.toSet();
        final newSettings = bakSettings.difference(nowSettings);
        final delSettings = nowSettings.difference(bakSettings);
        final updateSettings = nowSettings.intersection(bakSettings);
        for (final s in newSettings) {
          Stores.setting.box.put(s, settings_[s]);
        }
        for (final s in delSettings) {
          Stores.setting.box.delete(s);
        }
        for (final s in updateSettings) {
          Stores.setting.box.put(s, settings_[s]);
        }
      }
    }

    Provider.reload();
    RNodes.app.notify();

    _logger.info('Restore success');
  }

  factory Backup.fromJsonString(String raw) =>
      Backup.fromJson(json.decode(_diyDecrypt(raw)));
}

String _diyEncrypt(String raw) => json.encode(
      raw.codeUnits.map((e) => e * 2 + 1).toList(growable: false),
    );

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
