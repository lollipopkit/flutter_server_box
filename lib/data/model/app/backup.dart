import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:logging/logging.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/provider.dart';
import 'package:server_box/data/res/rebuild.dart';
import 'package:server_box/data/res/store.dart';

const backupFormatVersion = 1;

final _logger = Logger('Backup');

class Backup {
  // backup format version
  final int version;
  final String date;
  final List<ServerPrivateInfo> spis;
  final List<Snippet> snippets;
  final List<PrivateKeyInfo> keys;
  final Map<String, dynamic> container;
  final Map<String, dynamic> history;
  final int? lastModTime;

  const Backup({
    required this.version,
    required this.date,
    required this.spis,
    required this.snippets,
    required this.keys,
    required this.container,
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
        lastModTime = json['lastModTime'],
        history = json['history'] ?? {};

  Map<String, dynamic> toJson() => {
        'version': version,
        'date': date,
        'spis': spis,
        'snippets': snippets,
        'keys': keys,
        'container': container,
        'lastModTime': lastModTime,
        'history': history,
      };

  Backup.loadFromStore()
      : version = backupFormatVersion,
        date = DateTime.now().toString().split('.').firstOrNull ?? '',
        spis = Stores.server.fetch(),
        snippets = Stores.snippet.fetch(),
        keys = Stores.key.fetch(),
        container = Stores.container.box.toJson(),
        lastModTime = Stores.lastModTime,
        history = Stores.history.box.toJson();

  static Future<String> backup([String? name]) async {
    final result = _diyEncrypt(json.encode(Backup.loadFromStore().toJson()));
    final path = '${Paths.doc}/${name ?? Miscs.bakFileName}';
    await File(path).writeAsString(result);
    return path;
  }

  Future<void> restore({bool force = false}) async {
    final curTime = Stores.lastModTime ?? 0;
    final bakTime = lastModTime ?? 0;
    final shouldRestore = force || curTime < bakTime;
    if (!shouldRestore) {
      _logger.info('No need to restore, local is newer');
      return;
    }

    // Snippets
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

    // ServerPrivateInfo
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

    // PrivateKeyInfo
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

    // History
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

    // Container
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

    Pros.reload();
    RNodes.app.build();

    _logger.info('Restore success');
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
