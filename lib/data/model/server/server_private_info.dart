import 'package:hive_flutter/hive_flutter.dart';

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

  late String id;

  ServerPrivateInfo({
    required this.name,
    required this.ip,
    required this.port,
    required this.user,
    required this.pwd,
    this.pubKeyId,
    this.tags,
  }) : id = '$user@$ip:$port';

  ServerPrivateInfo.fromJson(Map<String, dynamic> json) {
    name = json["name"].toString();
    ip = json["ip"].toString();
    port = json["port"].toInt();
    user = json["user"].toString();
    pwd = json["authorization"].toString();
    pubKeyId = json["pubKeyId"]?.toString();
    id = '$user@$ip:$port';
    tags = json["tags"]?.cast<String>();
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
    return data;
  }

  bool shouldReconnect(ServerPrivateInfo old) {
    return id != id || pwd != old.pwd || pubKeyId != old.pubKeyId;
  }
}
