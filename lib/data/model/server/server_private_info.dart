import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/provider/server.dart';

import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/store/server.dart';

part 'server_private_info.g.dart';
part 'server_private_info.freezed.dart';

/// In the first version, it's called `ServerPrivateInfo` which was designed to
/// store the private information of a server.
///
/// Some params named as `spi` in the codebase which is the abbreviation of `ServerPrivateInfo`.
///
/// Nowaday, more fields are added to this class, and it's renamed to `Spi`.
@freezed
@HiveType(typeId: 3)
class Spi with _$Spi, EquatableMixin {
  const Spi._();

  const factory Spi({
    @HiveField(0) required String name,
    @HiveField(1) required String ip,
    @HiveField(2) required int port,
    @HiveField(3) required String user,
    @HiveField(4) String? pwd,

    /// [id] of private key
    @JsonKey(name: 'pubKeyId') @HiveField(5) String? keyId,
    @HiveField(6) List<String>? tags,
    @HiveField(7) String? alterUrl,
    @HiveField(8, defaultValue: true) @Default(true) bool autoConnect,

    /// [id] of the jump server
    @HiveField(9) String? jumpId,
    @HiveField(10) ServerCustom? custom,
    @HiveField(11) WakeOnLanCfg? wolCfg,

    /// It only applies to SSH terminal.
    @HiveField(12) Map<String, String>? envs,
    @HiveField(13, defaultValue: '') required String id,
  }) = _Spi;

  factory Spi.fromJson(Map<String, dynamic> json) => _$SpiFromJson(json);

  @override
  String toString() => 'Spi<$id>';

  @override
  List<Object?> get props => [id];
}

extension Spix on Spi {
  String get oldId => '$user@$ip:$port';

  void save() => ServerStore.instance.put(this);

  void migrateId() {
    if (id.isNotEmpty) return;
    ServerStore.instance.delete(oldId);
    final newSpi = copyWith(id: ShortId.generate());
    newSpi.save();
  }

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

  (String ip, String usr, int port) fromStringUrl() {
    if (alterUrl == null) {
      throw SSHErr(type: SSHErrType.connect, message: 'alterUrl is null');
    }
    final splited = alterUrl!.split('@');
    if (splited.length != 2) {
      throw SSHErr(type: SSHErrType.connect, message: 'alterUrl no @');
    }
    final usr = splited[0];
    final idx = splited[1].lastIndexOf(':');
    if (idx == -1) {
      throw SSHErr(type: SSHErrType.connect, message: 'alterUrl no :');
    }
    final ip_ = splited[1].substring(0, idx);
    final port_ = int.tryParse(splited[1].substring(idx + 1));
    if (port_ == null || port_ <= 0 || port_ > 65535) {
      throw SSHErr(type: SSHErrType.connect, message: 'alterUrl port error');
    }
    return (ip_, usr, port_);
  }

  /// Just for showing the struct of the class.
  ///
  /// **NOT** the default value.
  static final example = Spi(
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
      id: 'id');

  bool get isRoot => user == 'root';
}
