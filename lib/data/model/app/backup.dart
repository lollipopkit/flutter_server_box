import 'dart:convert';
import 'dart:io';

import 'package:toolbox/data/model/server/private_key_info.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/path.dart';
import 'package:toolbox/data/store/docker.dart';
import 'package:toolbox/data/store/private_key.dart';
import 'package:toolbox/data/store/server.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/data/store/snippet.dart';
import 'package:toolbox/locator.dart';

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
        spis = _server.fetch(),
        snippets = _snippet.fetch(),
        keys = _privateKey.fetch(),
        dockerHosts = _dockerHosts.fetchAll(),
        settings = _setting.toJson();

  static Future<void> backup() async {
    final result = _diyEncrtpt(json.encode(Backup.loadFromStore()));
    await File(await backupPath).writeAsString(result);
  }

  Future<void> restore() async {
    for (final s in snippets) {
      _snippet.put(s);
    }
    for (final s in spis) {
      _server.put(s);
    }
    for (final s in keys) {
      _privateKey.put(s);
    }
    for (final k in dockerHosts.keys) {
      final val = dockerHosts[k];
      if (val != null && val is String && val.isNotEmpty) {
        _dockerHosts.put(k, val);
      }
    }
  }

  Backup.fromJsonString(String raw)
      : this.fromJson(json.decode(_diyDecrypt(raw)));
}

final _server = locator<ServerStore>();
final _snippet = locator<SnippetStore>();
final _privateKey = locator<PrivateKeyStore>();
final _dockerHosts = locator<DockerStore>();
final _setting = locator<SettingStore>();

String _diyEncrtpt(String raw) => json.encode(
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
