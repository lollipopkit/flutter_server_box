import 'package:hive_ce/hive.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';

/// Reads `Spi` records written before schema v3, when the SSH fields sat flat
/// on the record instead of nested under `ssh`.
///
/// Registered alongside the generated adapter, which owns the current typeId
/// and the current layout. Keeping the old layout out of the live adapter is
/// what makes it deletable: a permanent "read either shape" branch has no
/// point at which anyone can tell it is safe to remove — `Spi.jumpId` has
/// carried a compatibility comment for exactly that reason.
///
/// `write` throws on purpose. Records are rewritten in the new shape by
/// `SpiNestSshMigration`, so nothing should ever produce the old layout again;
/// silently writing it would keep the old records alive indefinitely.
///
/// TODO: delete together with `SpiNestSshMigration` once no install can still
/// be on schema v2.
class SpiLegacyAdapter extends TypeAdapter<Spi> {
  /// The typeId `Spi` used through schema v2
  @override
  final typeId = 3;

  @override
  Spi read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    // A v2 record always carried a host; treat a blank one as "no SSH" rather
    // than fabricating a credential that points nowhere
    final ip = fields[1] as String?;
    final ssh = (ip == null || ip.isEmpty)
        ? null
        : SshCredential(
            ip: ip,
            port: (fields[2] as num?)?.toInt() ?? 22,
            user: fields[3] as String? ?? 'root',
            pwd: fields[4] as String?,
            keyId: fields[5] as String?,
            alterUrl: fields[7] as String?,
            jumpId: fields[9] as String?,
            jumpIds: (fields[17] as List?)?.cast<String>(),
            proxyCommand: fields[16] as String?,
          );

    return Spi(
      name: fields[0] as String,
      ssh: ssh,
      monitorHttp: fields[18] as MonitorHttpCredential?,
      tags: (fields[6] as List?)?.cast<String>(),
      autoConnect: fields[8] == null ? true : fields[8] as bool,
      custom: fields[10] as ServerCustom?,
      wolCfg: fields[11] as WakeOnLanCfg?,
      envs: (fields[12] as Map?)?.cast<String, String>(),
      id: fields[13] == null ? '' : fields[13] as String,
      customSystemType: fields[14] as SystemType?,
      disabledCmdTypes: (fields[15] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Spi obj) {
    throw UnsupportedError(
      'SpiLegacyAdapter is read-only: records are rewritten under the current '
      'Spi typeId by SpiNestSshMigration',
    );
  }
}
