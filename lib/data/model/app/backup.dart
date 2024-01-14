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
  final Map<String, dynamic> dockerHosts;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> history;
  final int? lastModTime;

  const Backup({
    required this.version,
    required this.date,
    required this.spis,
    required this.snippets,
    required this.keys,
    required this.dockerHosts,
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
        dockerHosts = json['dockerHosts'] ?? {},
        settings = json['settings'] ?? {},
        lastModTime = json['lastModTime'],
        history = json['history'] ?? {};

  Map<String, dynamic> toJson() => {
        'version': version,
        'date': date,
        'spis': spis,
        'snippets': snippets,
        'keys': keys,
        'dockerHosts': dockerHosts,
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
        dockerHosts = Stores.docker.box.toJson(),
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
  Future<bool?> restore({bool force = false}) async {
    final curTime = Stores.lastModTime ?? 0;
    final bakTime = lastModTime ?? 0;
    if (curTime == bakTime && !force) {
      return null;
    }
    if (curTime > bakTime && !force) {
      return false;
    }
    for (final s in settings.keys) {
      Stores.setting.box.put(s, settings[s]);
    }
    for (final s in snippets) {
      Stores.snippet.put(s);
    }
    for (final s in spis) {
      Stores.server.put(s);
    }
    for (final s in keys) {
      Stores.key.put(s);
    }
    for (final s in history.keys) {
      Stores.history.box.put(s, history[s]);
    }
    for (final k in dockerHosts.keys) {
      final val = dockerHosts[k];
      if (val != null && val is String && val.isNotEmpty) {
        Stores.docker.put(k, val);
      }
    }

    // update last modified time, avoid restore again
    Stores.setting.box.updateLastModified(lastModTime);

    Pros.reload();
    RebuildNodes.app.rebuild();

    return true;
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
