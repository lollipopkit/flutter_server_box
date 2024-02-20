// ignore_for_file: avoid_print

import 'dart:async';

import 'package:computer/computer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toolbox/core/channel/bg_run.dart';
import 'package:toolbox/core/utils/sync/icloud.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/core/utils/sync/webdav.dart';
import 'package:toolbox/core/utils/ui.dart';
import 'package:toolbox/data/model/app/menu/server_func.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/analysis.dart';
import 'data/model/app/net_view.dart';
import 'data/model/server/private_key_info.dart';
import 'data/model/server/server_private_info.dart';
import 'data/model/server/snippet.dart';
import 'data/model/ssh/virtual_key.dart';
import 'data/provider/app.dart';
import 'data/provider/private_key.dart';
import 'data/provider/server.dart';
import 'data/provider/sftp.dart';
import 'data/provider/snippet.dart';
import 'locator.dart';
import 'view/widget/appbar.dart';

Future<void> main() async {
  _runInZone(() async {
    await _initApp();
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => locator<AppProvider>()),
          ChangeNotifierProvider(create: (_) => locator<ServerProvider>()),
          ChangeNotifierProvider(create: (_) => locator<SnippetProvider>()),
          ChangeNotifierProvider(create: (_) => locator<PrivateKeyProvider>()),
          ChangeNotifierProvider(create: (_) => locator<SftpProvider>()),
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
  await _initDesktopWindow();

  // Base of all data.
  await _initDb();
  await setupLocator();
  Computer.shared.turnOn(
    // Plus 1 to avoid 0.
    workersCount: (Stores.server.box.keys.length / 3).round() + 1,
  );
  _setupLogger();
  _setupProviders();

  // Load font
  loadFontFile(Stores.setting.fontPath.fetch());

  if (isAndroid) {
    // Only start service when [bgRun] is true.
    if (Stores.setting.bgRun.fetch()) {
      BgRunMC.startService();
    }
    // SharedPreferences is only used on Android for saving home widgets settings.
    SharedPreferences.setPrefix('');
    // try switch to highest refresh rate
    await FlutterDisplayMode.setHighRefreshRate();
  }
  if (isIOS || isMacOS) {
    if (Stores.setting.icloudSync.fetch()) ICloud.sync();
  }
  if (Stores.setting.webdavSync.fetch()) Webdav.sync();
}

void _setupProviders() {
  Pros.snippet.load();
  Pros.key.load();
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
}

void _setupLogger() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    Pros.debug.addLog(record);
    print(record);
    if (record.error != null) print(record.error);
    if (record.stackTrace != null) print(record.stackTrace);
  });
}

Future<void> _initDesktopWindow() async {
  if (!isDesktop) return;

  await windowManager.ensureInitialized();
  await CustomAppBar.updateTitlebarHeight();

  const windowOptions = WindowOptions(
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
