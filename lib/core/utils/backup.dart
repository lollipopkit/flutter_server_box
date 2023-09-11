import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/model/app/backup.dart';
import '../../data/res/path.dart';
import '../../data/store/docker.dart';
import '../../data/store/private_key.dart';
import '../../data/store/server.dart';
import '../../data/store/setting.dart';
import '../../data/store/snippet.dart';
import '../../locator.dart';

final _server = locator<ServerStore>();
final _snippet = locator<SnippetStore>();
final _privateKey = locator<PrivateKeyStore>();
final _dockerHosts = locator<DockerStore>();
final _setting = locator<SettingStore>();

Future<String> get backupPath async => '${await docDir}/srvbox_bak.json';

const backupFormatVersion = 1;

Future<void> backup() async {
  final result = _diyEncrtpt(
    json.encode(
      Backup(
        version: backupFormatVersion,
        date: DateTime.now().toString().split('.').first,
        spis: _server.fetch(),
        snippets: _snippet.fetch(),
        keys: _privateKey.fetch(),
        dockerHosts: _dockerHosts.fetchAll(),
        settings: _setting.toJson(),
      ),
    ),
  );
  await File(await backupPath).writeAsString(result);
}

void restore(Backup backup) {
  for (final s in backup.snippets) {
    _snippet.put(s);
  }
  for (final s in backup.spis) {
    _server.put(s);
  }
  for (final s in backup.keys) {
    _privateKey.put(s);
  }
  for (final k in backup.dockerHosts.keys) {
    final val = backup.dockerHosts[k];
    if (val != null && val is String && val.isNotEmpty) {
      _dockerHosts.put(k, val);
    }
  }
}

Future<Backup> decodeBackup(String raw) async {
  return await compute(_decode, raw);
}

Backup _decode(String raw) {
  final decrypted = _diyDecrypt(raw);
  return Backup.fromJson(json.decode(decrypted));
}

String _diyEncrtpt(String raw) =>
    json.encode(raw.codeUnits.map((e) => e * 2 + 1).toList(growable: false));
String _diyDecrypt(String raw) {
  final list = json.decode(raw);
  final sb = StringBuffer();
  for (final e in list) {
    sb.writeCharCode((e - 1) ~/ 2);
  }
  return sb.toString();
}
