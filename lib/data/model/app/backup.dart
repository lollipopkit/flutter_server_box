import 'dart:convert';
import 'dart:io';

import 'package:toolbox/data/model/server/private_key_info.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/path.dart';
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

  const Backup({
    required this.version,
    required this.date,
    required this.spis,
    required this.snippets,
    required this.keys,
    required this.dockerHosts,
    required this.settings,
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
        settings = json['settings'] ?? {};

  Map<String, dynamic> toJson() => {
        'version': version,
        'date': date,
        'spis': spis,
        'snippets': snippets,
        'keys': keys,
        'dockerHosts': dockerHosts,
        'settings': settings,
      };

  Backup.loadFromStore()
      : version = backupFormatVersion,
        date = DateTime.now().toString().split('.').first,
        spis = Stores.server.fetch(),
        snippets = Stores.snippet.fetch(),
        keys = Stores.key.fetch(),
        dockerHosts = Stores.docker.toJson(),
        settings = Stores.setting.toJson();

  static Future<String> backup() async {
    final result = _diyEncrypt(json.encode(Backup.loadFromStore()));
    final path = await Paths.bak;
    await File(path).writeAsString(result);
    return path;
  }

  Future<void> restore() async {
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
    for (final k in dockerHosts.keys) {
      final val = dockerHosts[k];
      if (val != null && val is String && val.isNotEmpty) {
        Stores.docker.put(k, val);
      }
    }
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
