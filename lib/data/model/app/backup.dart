import 'dart:convert';
import 'dart:io';

import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/data/model/server/private_key_info.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/path.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/rebuild.dart';
import 'package:toolbox/data/res/store.dart';

const backupFormatVersion = 1;

class Backup {
  // backup format version
  final int version;
  final String date;
  final List<ServerPrivateInfo> spis;
  final List<Snippet> snippets;
  final List<PrivateKeyInfo> keys;
  final Map<String, dynamic> container;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> history;
  final int? lastModTime;

  const Backup({
    required this.version,
    required this.date,
    required this.spis,
    required this.snippets,
    required this.keys,
    required this.container,
    required this.settings,
    required this.history,
    this.lastModTime,
  });

  Backup.fromJson(Map<String, dynamic> json)
      : version = json['version'] as int,
        date = json['date'],
        spis = (json['spis'] as List)
            .map((e) => ServerPrivateInfo.fromJson(e))
            .toList(),
        snippets =
            (json['snippets'] as List).map((e) => Snippet.fromJson(e)).toList(),
        keys = (json['keys'] as List)
            .map((e) => PrivateKeyInfo.fromJson(e))
            .toList(),
        container = json['container'] ?? {},
        settings = json['settings'] ?? {},
        lastModTime = json['lastModTime'],
        history = json['history'] ?? {};

  Map<String, dynamic> toJson() => {
        'version': version,
        'date': date,
        'spis': spis,
        'snippets': snippets,
        'keys': keys,
        'container': container,
        'settings': settings,
        'lastModTime': lastModTime,
        'history': history,
      };

  Backup.loadFromStore()
      : version = backupFormatVersion,
        date = DateTime.now().toString().split('.').first,
        spis = Stores.server.fetch(),
        snippets = Stores.snippet.fetch(),
        keys = Stores.key.fetch(),
        container = Stores.docker.box.toJson(),
        settings = Stores.setting.box.toJson(),
        lastModTime = Stores.lastModTime,
        history = Stores.history.box.toJson();

  static Future<String> backup([String? name]) async {
    final result = _diyEncrypt(json.encode(Backup.loadFromStore()));
    final path = '${await Paths.doc}/${name ?? Paths.bakName}';
    await File(path).writeAsString(result);
    return path;
  }

  /// - Return null if same time
  /// - Return false if local is newer
  /// - Return true if restore success
  Future<void> restore({bool force = false}) async {
    final curTime = Stores.lastModTime ?? 0;
    final bakTime = lastModTime ?? 0;
    final shouldRestore = force || curTime < bakTime;

    // Settings
    final nowSettingsKeys = Stores.setting.box.keys.toSet();
    final bakSettingsKeys = settings.keys.toSet();
    final newSettingsKeys = bakSettingsKeys.difference(nowSettingsKeys);
    final delSettingsKeys = nowSettingsKeys.difference(bakSettingsKeys);
    final updateSettingsKeys = nowSettingsKeys.intersection(bakSettingsKeys);
    for (final k in newSettingsKeys) {
      Stores.setting.box.put(k, settings[k]);
    }
    if (shouldRestore) {
      for (final k in delSettingsKeys) {
        Stores.setting.box.delete(k);
      }
      for (final k in updateSettingsKeys) {
        Stores.setting.box.put(k, settings[k]);
      }
    }

    // Snippets
    final nowSnippets = Stores.snippet.fetch().toSet();
    final bakSnippets = snippets.toSet();
    final newSnippets = bakSnippets.difference(nowSnippets);
    final delSnippets = nowSnippets.difference(bakSnippets);
    final updateSnippets = nowSnippets.intersection(bakSnippets);
    for (final s in newSnippets) {
      Stores.snippet.put(s);
    }
    if (shouldRestore) {
      for (final s in delSnippets) {
        Stores.snippet.delete(s);
      }
      for (final s in updateSnippets) {
        Stores.snippet.put(s);
      }
    }
    
    // ServerPrivateInfo
    final nowSpis = Stores.server.fetch().toSet();
    final bakSpis = spis.toSet();
    final newSpis = bakSpis.difference(nowSpis);
    final delSpis = nowSpis.difference(bakSpis);
    final updateSpis = nowSpis.intersection(bakSpis);
    for (final s in newSpis) {
      Stores.server.put(s);
    }
    if (shouldRestore) {
      for (final s in delSpis) {
        Stores.server.delete(s.id);
      }
      for (final s in updateSpis) {
        Stores.server.put(s);
      }
    }
    
    // PrivateKeyInfo
    final nowKeys = Stores.key.fetch().toSet();
    final bakKeys = keys.toSet();
    final newKeys = bakKeys.difference(nowKeys);
    final delKeys = nowKeys.difference(bakKeys);
    final updateKeys = nowKeys.intersection(bakKeys);
    for (final s in newKeys) {
      Stores.key.put(s);
    }
    if (shouldRestore) {
      for (final s in delKeys) {
        Stores.key.delete(s);
      }
      for (final s in updateKeys) {
        Stores.key.put(s);
      }
    }
    
    // History
    final nowHistory = Stores.history.box.keys.toSet();
    final bakHistory = history.keys.toSet();
    final newHistory = bakHistory.difference(nowHistory);
    final delHistory = nowHistory.difference(bakHistory);
    final updateHistory = nowHistory.intersection(bakHistory);
    for (final s in newHistory) {
      Stores.history.box.put(s, history[s]);
    }
    if (shouldRestore) {
      for (final s in delHistory) {
        Stores.history.box.delete(s);
      }
      for (final s in updateHistory) {
        Stores.history.box.put(s, history[s]);
      }
    }
    
    // Container
    final nowContainer = Stores.docker.box.keys.toSet();
    final bakContainer = container.keys.toSet();
    final newContainer = bakContainer.difference(nowContainer);
    final delContainer = nowContainer.difference(bakContainer);
    final updateContainer = nowContainer.intersection(bakContainer);
    for (final s in newContainer) {
      Stores.docker.put(s, container[s]);
    }
    if (shouldRestore) {
      for (final s in delContainer) {
        Stores.docker.box.delete(s);
      }
      for (final s in updateContainer) {
        Stores.docker.put(s, container[s]);
      }
    }

    // update last modified time, avoid restore again
    Stores.setting.box.updateLastModified(lastModTime);

    Pros.reload();
    RebuildNodes.app.rebuild();
  }

  Backup.fromJsonString(String raw)
      : this.fromJson(json.decode(_diyDecrypt(raw)));
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
