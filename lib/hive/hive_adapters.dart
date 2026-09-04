import 'package:hive_ce/hive.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/net_view.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';

/// `PrivateKeyInfo`, `Snippet`, `SshCredential` and `ServerCustom` are
/// deliberately absent: all four gained a field the released boxes do not
/// carry, so generating an adapter from them means generating one for a shape
/// no box is in. They are frozen types in `legacy_adapters.dart` instead — see
/// the note there before adding a model back to this list.
@GenerateAdapters([
  AdapterSpec<VirtKey>(),
  AdapterSpec<NetViewType>(),
  AdapterSpec<ServerFuncBtn>(),
  AdapterSpec<WakeOnLanCfg>(),
  AdapterSpec<SystemType>(),
  AdapterSpec<PortForwardType>(),
  AdapterSpec<PortForwardConfig>(),
])
part 'hive_adapters.g.dart';
