import 'package:hive_flutter/hive_flutter.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/res/provider.dart';

import '../app/error.dart';

part 'server_private_info.g.dart';

/// In former version, it's called `ServerPrivateInfo`.
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

  /// [id] of private key
  @HiveField(5)
  final String? keyId;
  @HiveField(6)
  final List<String>? tags;
  @HiveField(7)
  final String? alterUrl;
  @HiveField(8)
  final bool? autoConnect;

  /// [id] of the jump server
  @HiveField(9)
  final String? jumpId;

  @HiveField(10)
  final ServerCustom? custom;

  @HiveField(11)
  final WakeOnLanCfg? wolCfg;

  final String id;

  const ServerPrivateInfo({
    required this.name,
    required this.ip,
    required this.port,
    required this.user,
    required this.pwd,
    this.keyId,
    this.tags,
    this.alterUrl,
    this.autoConnect,
    this.jumpId,
    this.custom,
    this.wolCfg,
  }) : id = '$user@$ip:$port';

  static ServerPrivateInfo fromJson(Map<String, dynamic> json) {
    final ip = json["ip"] as String? ?? '';
    final port = json["port"] as int? ?? 22;
    final user = json["user"] as String? ?? 'root';
    final name = json["name"] as String? ?? '';
    final pwd = json["pwd"] as String? ?? json["authorization"] as String?;
    final keyId = json["pubKeyId"] as String?;
    final tags = (json["tags"] as List?)?.cast<String>();
    final alterUrl = json["alterUrl"] as String?;
    final autoConnect = json["autoConnect"] as bool?;
    final jumpId = json["jumpId"] as String?;
    final custom = json["customCmd"] == null
        ? null
        : ServerCustom.fromJson(json["custom"].cast<String, dynamic>());
    final wolCfg = json["wolCfg"] == null
        ? null
        : WakeOnLanCfg.fromJson(json["wolCfg"].cast<String, dynamic>());

    return ServerPrivateInfo(
      name: name,
      ip: ip,
      port: port,
      user: user,
      pwd: pwd,
      keyId: keyId,
      tags: tags,
      alterUrl: alterUrl,
      autoConnect: autoConnect,
      jumpId: jumpId,
      custom: custom,
      wolCfg: wolCfg,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["name"] = name;
    data["ip"] = ip;
    data["port"] = port;
    data["user"] = user;
    if (pwd != null) {
      data["pwd"] = pwd;
    }
    if (keyId != null) {
      data["pubKeyId"] = keyId;
    }
    if (tags != null) {
      data["tags"] = tags;
    }
    if (alterUrl != null) {
      data["alterUrl"] = alterUrl;
    }
    if (autoConnect != null) {
      data["autoConnect"] = autoConnect;
    }
    if (jumpId != null) {
      data["jumpId"] = jumpId;
    }
    if (custom != null) {
      data["custom"] = custom?.toJson();
    }
    if (wolCfg != null) {
      data["wolCfg"] = wolCfg?.toJson();
    }
    return data;
  }

  Server? get server => Pros.server.pick(spi: this);
  Server? get jumpServer => Pros.server.pick(id: jumpId);

  bool shouldReconnect(ServerPrivateInfo old) {
    return id != old.id ||
        pwd != old.pwd ||
        keyId != old.keyId ||
        alterUrl != old.alterUrl ||
        jumpId != old.jumpId ||
        custom?.cmds != old.custom?.cmds;
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
