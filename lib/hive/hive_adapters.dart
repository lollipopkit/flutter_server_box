import 'package:hive_ce/hive.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/net_view.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';

@GenerateAdapters([
  AdapterSpec<PrivateKeyInfo>(),
  AdapterSpec<Snippet>(),
  AdapterSpec<Spi>(),
  AdapterSpec<VirtKey>(),
  AdapterSpec<NetViewType>(),
  AdapterSpec<ServerFuncBtn>(),
  AdapterSpec<ServerCustom>(),
  AdapterSpec<WakeOnLanCfg>(),
])
part 'hive_adapters.g.dart';
