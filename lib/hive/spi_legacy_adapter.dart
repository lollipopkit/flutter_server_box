import 'package:hive_ce/hive.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';

/// A `Spi` record as written before schema v3, when the SSH fields sat flat on
/// the record instead of nested under `ssh`.
///
/// A type of its own rather than another adapter for [Spi]. Hive resolves
/// *writes* by walking its adapters for the first one matching the value's
/// runtime type, so two adapters claiming [Spi] would make every write depend
/// on registration order — and it warns as much:
///
///     WARNING: You are trying to register SpiLegacyAdapter (typeId 3) for
///     type Spi but there is already a TypeAdapter for this type
///
/// Giving the old layout its own type makes the two unambiguous: typeId 3
/// decodes to [LegacySpiV2] and nothing ever writes it, typeId 15 decodes and
/// encodes [Spi].
///
/// TODO: delete with `SpiNestSshMigration` once no install can still be on
/// schema v2.
class LegacySpiV2 {
  final String name;
  final SshCredential? ssh;
  final MonitorHttpCredential? monitorHttp;
  final List<String>? tags;
  final bool autoConnect;
  final ServerCustom? custom;
  final WakeOnLanCfg? wolCfg;
  final Map<String, String>? envs;
  final String id;
  final SystemType? customSystemType;
  final List<String>? disabledCmdTypes;

  const LegacySpiV2({
    required this.name,
    required this.ssh,
    required this.monitorHttp,
    required this.tags,
    required this.autoConnect,
    required this.custom,
    required this.wolCfg,
    required this.envs,
    required this.id,
    required this.customSystemType,
    required this.disabledCmdTypes,
  });

  Spi toSpi() => Spi(
    name: name,
    ssh: ssh,
    monitorHttp: monitorHttp,
    tags: tags,
    autoConnect: autoConnect,
    custom: custom,
    wolCfg: wolCfg,
    envs: envs,
    id: id,
    customSystemType: customSystemType,
    disabledCmdTypes: disabledCmdTypes,
  );
}

/// Read-only decoder for the typeId `Spi` used through schema v2.
///
/// `write` throws: records are re-encoded under the current typeId by
/// `SpiNestSshMigration`, and producing the old layout again would keep v2
/// records alive indefinitely.
class SpiLegacyAdapter extends TypeAdapter<LegacySpiV2> {
  @override
  final typeId = 3;

  @override
  LegacySpiV2 read(BinaryReader reader) {
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

    return LegacySpiV2(
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
  void write(BinaryWriter writer, LegacySpiV2 obj) {
    throw UnsupportedError(
      'SpiLegacyAdapter is read-only: records are rewritten under the current '
      'Spi typeId by SpiNestSshMigration',
    );
  }
}
