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
import 'package:toolbox/app.dart';
import 'package:toolbox/core/utils/sync/icloud.dart';
import 'package:toolbox/core/utils/sync/webdav.dart';
import 'package:toolbox/data/model/app/menu/server_func.dart';
import 'package:toolbox/data/model/app/net_view.dart';
import 'package:toolbox/data/model/app/version_related.dart';
import 'package:toolbox/data/model/server/custom.dart';
import 'package:toolbox/data/model/server/private_key_info.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/model/ssh/virtual_key.dart';
import 'package:toolbox/data/res/build_data.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/data/res/url.dart';

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
      Analysis.recordException(trace);
      Loggers.root.warning(obj, null, trace);
    },
    zoneSpecification: zoneSpec,
  );
}

Future<void> _initApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Paths.init(BuildData.name);

  // Base of all data.
  await _initDb();

  _setupDebug();
  SystemUIs.initDesktopWindow(Stores.setting.hideTitleBar.fetch());

  // Load font
  FontUtils.loadFrom(Stores.setting.fontPath.fetch());

  if (isAndroid) {
    // SharedPreferences is only used on Android for saving home widgets settings.
    SharedPreferences.setPrefix('');
    // try switch to highest refresh rate
    await FlutterDisplayMode.setHighRefreshRate();
  }

  final serversCount = Stores.server.box.keys.length;
  // Plus 1 to avoid 0.
  Computer.shared.turnOn(workersCount: (serversCount / 3).round() + 1);

  if (isIOS || isMacOS) {
    if (Stores.setting.icloudSync.fetch()) ICloud.sync();
  }
  if (Stores.setting.webdavSync.fetch()) Webdav.sync();

  _doVersionRelated();
}

Future<void> _initDb() async {
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

  await Stores.setting.init();
  await Stores.server.init();
  await Stores.key.init();
  await Stores.snippet.init();
  await Stores.container.init();
  await Stores.history.init();

  Pros.snippet.load();
  Pros.key.load();
}

void _setupDebug() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    Pros.debug.addLog(record);
    print(record);
    if (record.error != null) print(record.error);
    if (record.stackTrace != null) print(record.stackTrace);
  });

  if (Stores.setting.collectUsage.fetch()) {
    Analysis.init(Urls.analysis, '0772e65c696709f879d87db77ae1a811259e3eb9');
  }
}

Future<void> _doVersionRelated() async {
  final curVer = Stores.setting.lastVer.fetch();
  const newVer = BuildData.build;
  if (curVer < newVer) {
    /// Call [Iterable.toList] to consume the lazy iterable.
    VersionRelated.funcs.map((e) => e(newVer)).toList();
    Stores.setting.lastVer.put(newVer);
  }
}
