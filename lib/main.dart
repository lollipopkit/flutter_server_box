// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:macos_window_utils/window_manipulator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toolbox/core/channel/bg_run.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/store.dart';

import 'app.dart';
import 'core/analysis.dart';
import 'core/utils/ui.dart';
import 'data/model/app/net_view.dart';
import 'data/model/server/private_key_info.dart';
import 'data/model/server/server_private_info.dart';
import 'data/model/server/snippet.dart';
import 'data/model/ssh/virtual_key.dart';
import 'data/provider/app.dart';
import 'data/provider/debug.dart';
import 'data/provider/docker.dart';
import 'data/provider/private_key.dart';
import 'data/provider/server.dart';
import 'data/provider/sftp.dart';
import 'data/provider/snippet.dart';
import 'data/res/color.dart';
import 'locator.dart';
import 'view/widget/custom_appbar.dart';

Future<void> main() async {
  _runInZone(() async {
    await initApp();
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => locator<AppProvider>()),
          ChangeNotifierProvider(create: (_) => locator<DebugProvider>()),
          ChangeNotifierProvider(create: (_) => locator<DockerProvider>()),
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
      Loggers.root.warning(obj);
    },
    zoneSpecification: zoneSpec,
  );
}

Future<void> initApp() async {
  await _initMacOSWindow();

  // Base of all data.
  await _initDb();
  await setupLocator();
  _setupLogger();
  _setupProviders();

  // Load font
  primaryColor = Color(Stores.setting.primaryColor.fetch());
  loadFontFile(Stores.setting.fontPath.fetch());

  if (isAndroid) {
    // Only start service when [bgRun] is true.
    if (Stores.setting.bgRun.fetch()) {
      BgRunMC.startService();
    }
    // SharedPreferences is only used on Android for saving home widgets settings.
    SharedPreferences.setPrefix('');
  }
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

Future<void> _initMacOSWindow() async {
  if (!isMacOS) return;
  WidgetsFlutterBinding.ensureInitialized();
  await WindowManipulator.initialize();
  WindowManipulator.makeTitlebarTransparent();
  WindowManipulator.enableFullSizeContentView();
  WindowManipulator.hideTitle();
  await CustomAppBar.updateTitlebarHeight();
}
