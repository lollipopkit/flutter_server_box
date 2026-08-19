import 'package:hive_ce/hive.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/net_view.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';

/// `PrivateKeyInfo` and `Snippet` are deliberately absent: both gained a field
/// the released boxes do not carry, so a generated adapter can no longer read
/// one. They are frozen types in `legacy_adapters.dart` instead — see the note
/// there before adding a model back to this list.
@GenerateAdapters([
  AdapterSpec<Spi>(),
  AdapterSpec<VirtKey>(),
  AdapterSpec<NetViewType>(),
  AdapterSpec<ServerFuncBtn>(),
  AdapterSpec<ServerCustom>(),
  AdapterSpec<WakeOnLanCfg>(),
  AdapterSpec<BmcCfg>(),
  AdapterSpec<MonitorHttpCredential>(),
  AdapterSpec<SshCredential>(),
  AdapterSpec<SystemType>(),
  AdapterSpec<PortForwardType>(),
  AdapterSpec<PortForwardConfig>(),
])
part 'hive_adapters.g.dart';
