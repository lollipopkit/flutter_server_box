import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/provider/server.dart';
import 'package:server_box/data/store/server.dart';

part 'server_private_info.freezed.dart';
part 'server_private_info.g.dart';

/// In the first version, it's called `ServerPrivateInfo` which was designed to
/// store the private information of a server.
///
/// Some params named as `spi` in the codebase which is the abbreviation of `ServerPrivateInfo`.
///
/// Nowaday, more fields are added to this class, and it's renamed to `Spi`.
@freezed
abstract class Spi with _$Spi {
  const Spi._();

  @JsonSerializable(includeIfNull: false)
  const factory Spi({
    required String name,
    required String ip,
    required int port,
    required String user,
    String? pwd,

    /// [id] of private key
    @JsonKey(name: 'pubKeyId') String? keyId,
    List<String>? tags,
    String? alterUrl,
    @Default(true) bool autoConnect,

    /// [id] of the jump server
    String? jumpId,
    ServerCustom? custom,
    WakeOnLanCfg? wolCfg,

    /// It only applies to SSH terminal.
    Map<String, String>? envs,
    @Default('') @JsonKey(fromJson: Spi.parseId) String id,

    /// Custom system type (unix or windows). If set, skip auto-detection.
    @JsonKey(includeIfNull: false) SystemType? customSystemType,

    /// Disabled command types for this server
    @JsonKey(includeIfNull: false) List<String>? disabledCmdTypes,
  }) = _Spi;

  factory Spi.fromJson(Map<String, dynamic> json) => _$SpiFromJson(json);

  @override
  String toString() => 'Spi<$oldId>';

  static String parseId(Object? id) {
    if (id == null || id is! String || id.isEmpty) return ShortId.generate();
    return id;
  }
}

extension Spix on Spi {
  /// After upgrading to >= 1155, this field is only recommended to be used
  /// for displaying the server name.
  String get oldId => '$user@$ip:$port';

  /// Save the [Spi] to the local storage.
  void save() => ServerStore.instance.put(this);

  /// Migrate the [oldId] to the new generated [id] by [ShortId.generate].
  ///
  /// Returns:
  /// - `null` if the [id] is not empty.
  /// - The new [id] if the [id] is empty.
  String? migrateId() {
    if (id.isNotEmpty) return null;
    ServerStore.instance.delete(oldId);
    final newSpi = copyWith(id: ShortId.generate());
    newSpi.save();
    return newSpi.id;
  }

  String toJsonString() => json.encode(toJson());

  VNode<Server>? get server => ServerProvider.pick(spi: this);
  VNode<Server>? get jumpServer => ServerProvider.pick(id: jumpId);

  bool shouldReconnect(Spi old) {
    return user != old.user ||
        ip != old.ip ||
        port != old.port ||
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
      cmds: {'echo': 'echo hello'},
      preferTempDev: 'nvme-pci-0400',
      logoUrl: 'https://example.com/logo.png',
    ),
    id: 'id',
  );

  bool get isRoot => user == 'root';
}
