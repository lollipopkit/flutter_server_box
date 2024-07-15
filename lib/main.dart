// ignore_for_file: avoid_print

import 'dart:async';

import 'package:computer/computer.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:server_box/app.dart';
import 'package:server_box/core/utils/sync/icloud.dart';
import 'package:server_box/core/utils/sync/webdav.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/net_view.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/provider.dart';
import 'package:server_box/data/res/store.dart';

Future<void> main() async {
  _runInZone(() async {
    await _initApp();
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => Pros.app),
          ChangeNotifierProvider(create: (_) => Pros.server),
          ChangeNotifierProvider(create: (_) => Pros.snippet),
          ChangeNotifierProvider(create: (_) => Pros.key),
          ChangeNotifierProvider(create: (_) => Pros.sftp),
        ],
        child: const MyApp(),
      ),
    );
  });
}

void _runInZone(void Function() body) {
  final zoneSpec = ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
      parent.print(zone, line);
    },
  );

  runZonedGuarded(
    body,
    (obj, trace) {
      Loggers.root.warning(obj, null, trace);
    },
    zoneSpecification: zoneSpec,
  );
}

Future<void> _initApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Paths.init(BuildData.name, bakName: Miscs.bakFileName);
  await _initData();
  _setupDebug();

  final windowSize = Stores.setting.windowSize;
  final hideTitleBar = Stores.setting.hideTitleBar.fetch();
  await SystemUIs.initDesktopWindow(
    hideTitleBar: hideTitleBar,
    size: windowSize.fetch().toSize(),
    listener: WindowSizeListener(windowSize),
  );

  FontUtils.loadFrom(Stores.setting.fontPath.fetch());

  _doPlatformRelated();
  _doVersionRelated();
}

Future<void> _initData() async {
  // await SecureStore.init();
  await Hive.initFlutter();
  // Ordered by typeId
  Hive.registerAdapter(PrivateKeyInfoAdapter()); // 1
  Hive.registerAdapter(SnippetAdapter()); // 2
  Hive.registerAdapter(ServerPrivateInfoAdapter()); // 3
  Hive.registerAdapter(VirtKeyAdapter()); // 4
  Hive.registerAdapter(NetViewTypeAdapter()); // 5
  Hive.registerAdapter(ServerFuncBtnAdapter()); // 6
  Hive.registerAdapter(ServerCustomAdapter()); // 7
  Hive.registerAdapter(WakeOnLanCfgAdapter()); // 8

  await Stores.setting.init();
  await Stores.server.init();
  await Stores.key.init();
  await Stores.snippet.init();
  await Stores.container.init();
  await Stores.history.init();

  Pros.snippet.load();
  Pros.key.load();
  await Pros.app.init();

  if (Stores.setting.betaTest.fetch()) AppUpdate.chan = AppUpdateChan.beta;
}

void _setupDebug() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    Pros.debug.addLog(record);
    print(record);
    if (record.error != null) print(record.error);
    if (record.stackTrace != null) print(record.stackTrace);
  });
}

void _doPlatformRelated() async {
  if (isAndroid) {
    // SharedPreferences is only used on Android for saving home widgets settings.
    SharedPreferences.setPrefix('');
    // try switch to highest refresh rate
    FlutterDisplayMode.setHighRefreshRate();
  }

  final serversCount = Stores.server.box.keys.length;
  // Plus 1 to avoid 0.
  Computer.shared.turnOn(workersCount: (serversCount / 3).round() + 1);

  if (isIOS || isMacOS) {
    if (Stores.setting.icloudSync.fetch()) ICloud.sync();
  }
  if (Stores.setting.webdavSync.fetch()) Webdav.sync();
}

// It may contains some async heavy funcs.
Future<void> _doVersionRelated() async {
  final curVer = Stores.setting.lastVer.fetch();
  const newVer = BuildData.build;
  // It's only the version upgrade trigger logic.
  // How to upgrade the data is inside each own func.
  if (curVer < newVer) {
    ServerDetailCards.autoAddNewCards(newVer);
    Stores.setting.lastVer.put(newVer);
  }
}
