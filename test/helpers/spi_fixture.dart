import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';

/// Builds a [Spi] from flat SSH arguments.
///
/// Tests care about "a server at this host as this user", not about how the
/// credential is nested, and most of them predate the nesting. Keeping the
/// flat shape here leaves each test's intent readable and means a future
/// change to [SshCredential] costs one edit instead of one per fixture.
///
/// Production code must not do this: nesting is what makes "has SSH" and "has
/// no SSH" distinguishable, and a helper that always produces a credential
/// would hide the monitor-only case.
Spi spiFixture({
  required String name,
  String id = '',
  String? ip,
  int port = 22,
  String user = 'root',
  String? pwd,
  String? keyId,
  String? keyPath,
  String? alterUrl,
  String? jumpId,
  List<String>? jumpIds,
  String? proxyCommand,
  List<String>? tags,
  bool autoConnect = true,
  ServerCustom? custom,
  WakeOnLanCfg? wolCfg,
  Map<String, String>? envs,
  SystemType? customSystemType,
  List<String>? disabledCmdTypes,
}) {
  return Spi(
    name: name,
    id: id,
    ssh: ip == null
        ? null
        : SshCredential(
            ip: ip,
            port: port,
            user: user,
            pwd: pwd,
            keyId: keyId,
            keyPath: keyPath,
            alterUrl: alterUrl,
            jumpId: jumpId,
            jumpIds: jumpIds,
            proxyCommand: proxyCommand,
          ),
    tags: tags,
    autoConnect: autoConnect,
    custom: custom,
    wolCfg: wolCfg,
    envs: envs,
    customSystemType: customSystemType,
    disabledCmdTypes: disabledCmdTypes,
  );
}
