import 'package:hive_flutter/hive_flutter.dart';

import '../app/error.dart';

part 'server_private_info.g.dart';

@HiveType(typeId: 3)
class ServerPrivateInfo {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final String ip;
  @HiveField(2)
  final int port;
  @HiveField(3)
  final String user;
  @HiveField(4)
  final String? pwd;
  @HiveField(5)
  final String? pubKeyId;
  @HiveField(6)
  final List<String>? tags;
  @HiveField(7)
  final String? alterUrl;
  @HiveField(8)
  final bool? autoConnect;

  final String id;

  ServerPrivateInfo({
    required this.name,
    required this.ip,
    required this.port,
    required this.user,
    required this.pwd,
    this.pubKeyId,
    this.tags,
    this.alterUrl,
    this.autoConnect,
  }) : id = '$user@$ip:$port';

  /// TODO: if any field is changed, remember to update [id] [name]
  ServerPrivateInfo.fromJson(Map<String, dynamic> json)
      : ip = json["ip"].toString(),
        port = json["port"] ?? 22,
        user = json["user"]?.toString() ?? 'root',
        id =
            '${json["user"]?.toString() ?? "root"}@${json["ip"].toString()}:${json["port"] ?? 22}',
        name = json["name"]?.toString() ??
            '${json["user"]?.toString() ?? 'root'}@${json["ip"].toString()}:${json["port"] ?? 22}',
        pwd = json["authorization"]?.toString(),
        pubKeyId = json["pubKeyId"]?.toString(),
        tags = json["tags"]?.cast<String>(),
        alterUrl = json["alterUrl"]?.toString(),
        autoConnect = json["autoConnect"];

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
    data["autoConnect"] = autoConnect;
    return data;
  }

  bool shouldReconnect(ServerPrivateInfo old) {
    return id != old.id ||
        pwd != old.pwd ||
        pubKeyId != old.pubKeyId ||
        alterUrl != old.alterUrl;
  }

  _IpPort fromStringUrl() {
    if (alterUrl == null) {
      throw SSHErr(type: SSHErrType.connect, message: 'alterUrl is null');
    }
    final splited = alterUrl!.split('@');
    if (splited.length != 2) {
      throw SSHErr(type: SSHErrType.connect, message: 'alterUrl no @');
    }
    final splited2 = splited[1].split(':');
    if (splited2.length != 2) {
      throw SSHErr(type: SSHErrType.connect, message: 'alterUrl no :');
    }
    final ip_ = splited2[0];
    final port_ = int.tryParse(splited2[1]) ?? 22;
    if (port <= 0 || port > 65535) {
      throw SSHErr(type: SSHErrType.connect, message: 'alterUrl port error');
    }
    return _IpPort(ip_, port_);
  }

  @override
  String toString() {
    return id;
  }
}

class _IpPort {
  final String ip;
  final int port;

  _IpPort(this.ip, this.port);
}
