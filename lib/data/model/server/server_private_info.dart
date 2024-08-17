import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/provider/server.dart';

import 'package:server_box/data/model/app/error.dart';

part 'server_private_info.g.dart';

/// In the first version, it's called `ServerPrivateInfo` which was designed to
/// store the private information of a server.
///
/// Some params named as `spi` in the codebase which is the abbreviation of `ServerPrivateInfo`.
///
/// Nowaday, more fields are added to this class, and it's renamed to `Spi`.
@JsonSerializable()
@HiveType(typeId: 3)
class Spi {
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
  @JsonKey(name: 'pubKeyId')
  @HiveField(5)
  final String? keyId;
  @HiveField(6)
  final List<String>? tags;
  @HiveField(7)
  final String? alterUrl;
  @HiveField(8, defaultValue: true)
  final bool autoConnect;

  /// [id] of the jump server
  @HiveField(9)
  final String? jumpId;

  @HiveField(10)
  final ServerCustom? custom;

  @HiveField(11)
  final WakeOnLanCfg? wolCfg;

  /// It only applies to SSH terminal.
  @HiveField(12)
  final Map<String, String>? envs;

  final String id;

  const Spi({
    required this.name,
    required this.ip,
    required this.port,
    required this.user,
    required this.pwd,
    this.keyId,
    this.tags,
    this.alterUrl,
    this.autoConnect = true,
    this.jumpId,
    this.custom,
    this.wolCfg,
    this.envs,
  }) : id = '$user@$ip:$port';

  factory Spi.fromJson(Map<String, dynamic> json) => _$SpiFromJson(json);

  Map<String, dynamic> toJson() => _$SpiToJson(this);

  @override
  String toString() => id;
}

extension Spix on Spi {
  String toJsonString() => json.encode(toJson());

  VNode<Server>? get server => ServerProvider.pick(spi: this);
  VNode<Server>? get jumpServer => ServerProvider.pick(id: jumpId);

  bool shouldReconnect(Spi old) {
    return id != old.id ||
        pwd != old.pwd ||
        keyId != old.keyId ||
        alterUrl != old.alterUrl ||
        jumpId != old.jumpId ||
        custom?.cmds != old.custom?.cmds;
  }

  (String, int) fromStringUrl() {
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
    return (ip_, port_);
  }

  static const example = Spi(
    name: 'name',
    ip: 'ip',
    port: 22,
    user: 'root',
    pwd: 'pwd',
    keyId: 'private_key_id',
    tags: ['tag1', 'tag2'],
    alterUrl: 'user@ip:port',
    autoConnect: true,
    jumpId: 'jump_server_id',
    custom: ServerCustom(
      pveAddr: 'http://localhost:8006',
      pveIgnoreCert: false,
      cmds: {
        'echo': 'echo hello',
      },
      preferTempDev: 'nvme-pci-0400',
      logoUrl: 'https://example.com/logo.png',
    ),
  );

  bool get isRoot => user == 'root';
}
