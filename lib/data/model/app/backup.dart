import 'package:toolbox/data/model/server/private_key_info.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/snippet.dart';

class Backup {
  // backup format version
  final int version;
  final String date;
  final List<ServerPrivateInfo> spis;
  final List<Snippet> snippets;
  final List<PrivateKeyInfo> keys;
  final int primaryColor;
  final int serverStatusUpdateInterval;
  final int launchPage;

  Backup(
    this.version,
    this.date,
    this.spis,
    this.snippets,
    this.keys,
    this.primaryColor,
    this.serverStatusUpdateInterval,
    this.launchPage,
  );

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
        primaryColor = json['primaryColor'],
        serverStatusUpdateInterval = json['serverStatusUpdateInterval'],
        launchPage = json['launchPage'];

  Map<String, dynamic> toJson() => {
        'version': version,
        'date': date,
        'spis': spis,
        'snippets': snippets,
        'keys': keys,
        'primaryColor': primaryColor,
        'serverStatusUpdateInterval': serverStatusUpdateInterval,
        'launchPage': launchPage,
      };
}
