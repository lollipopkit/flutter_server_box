import 'package:hive_flutter/hive_flutter.dart';

import '../app/error.dart';

part 'server_private_info.g.dart';

@HiveType(typeId: 3)
class ServerPrivateInfo {
  @HiveField(0)
  late String name;
  @HiveField(1)
  late String ip;
  @HiveField(2)
  late int port;
  @HiveField(3)
  late String user;
  @HiveField(4)
  late String pwd;
  @HiveField(5)
  String? pubKeyId;
  @HiveField(6)
  List<String>? tags;
  @HiveField(7)
  String? alterUrl;

  late String id;

  ServerPrivateInfo({
    required this.name,
    required this.ip,
    required this.port,
    required this.user,
    required this.pwd,
    this.pubKeyId,
    this.tags,
    this.alterUrl,
  }) : id = '$user@$ip:$port';

  ServerPrivateInfo.fromJson(Map<String, dynamic> json) {
    name = json["name"].toString();
    ip = json["ip"].toString();
    port = json["port"] ?? 22;
    user = json["user"].toString();
    pwd = json["authorization"].toString();
    pubKeyId = json["pubKeyId"]?.toString();
    id = '$user@$ip:$port';
    tags = json["tags"]?.cast<String>();
    alterUrl = json["alterUrl"]?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["name"] = name;
    data["ip"] = ip;
    data["port"] = port;
    data["user"] = user;
    data["authorization"] = pwd;
    data["pubKeyId"] = pubKeyId;
    data["tags"] = tags;
    data["alterUrl"] = alterUrl;
    return data;
  }

  bool shouldReconnect(ServerPrivateInfo old) {
    return id != old.id ||
        pwd != old.pwd ||
        pubKeyId != old.pubKeyId ||
        alterUrl != old.alterUrl;
  }

  void fromStringUrl() {
    if (alterUrl == null) {
      throw SSHErr(type: SSHErrType.connect, message: 'alterUrl is null');
    }
    final splited = alterUrl!.split('@');
    if (splited.length != 2) {
      throw SSHErr(type: SSHErrType.connect, message: 'alterUrl no @');
    }
    user = splited[0];
    final splited2 = splited[1].split(':');
    if (splited2.length != 2) {
      throw SSHErr(type: SSHErrType.connect, message: 'alterUrl no :');
    }
    ip = splited2[0];
    port = int.tryParse(splited2[1]) ?? 22;
    if (port <= 0 || port > 65535) {
      throw SSHErr(type: SSHErrType.connect, message: 'alterUrl port error');
    }

    // Do not update [id]
    // Because [id] is the identity which is used to find the [SSHClient]
    // id = '$user@$ip:$port';
  }

  @override
  String toString() {
    return id;
  }
}
