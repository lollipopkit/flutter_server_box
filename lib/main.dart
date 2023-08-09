import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toolbox/data/model/app/net_view.dart';
import 'package:toolbox/data/model/ssh/virtual_key.dart';

import 'app.dart';
import 'core/analysis.dart';
import 'core/utils/ui.dart';
import 'data/model/server/private_key_info.dart';
import 'data/model/server/server_private_info.dart';
import 'data/model/server/snippet.dart';
import 'data/provider/app.dart';
import 'data/provider/debug.dart';
import 'data/provider/docker.dart';
import 'data/provider/pkg.dart';
import 'data/provider/private_key.dart';
import 'data/provider/server.dart';
import 'data/provider/sftp.dart';
import 'data/provider/snippet.dart';
import 'data/provider/virtual_keyboard.dart';
import 'data/store/setting.dart';
import 'locator.dart';
import 'view/widget/rebuild.dart';

late final DebugProvider _debug;

Future<void> initApp() async {
  await initHive();
  await setupLocator();

  _debug = locator<DebugProvider>();
  locator<SnippetProvider>().loadData();
  locator<PrivateKeyProvider>().loadData();

  final settings = locator<SettingStore>();
  await loadFontFile(settings.fontPath.fetch());

  SharedPreferences.setPrefix('');

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    var str = '[${record.loggerName}][${record.level.name}]: ${record.message}';
    if (record.error != null) {
      str += '\n${record.error}';
      _debug.addMultiline(record.error.toString(), Colors.red);
    }
    if (record.stackTrace != null) {
      str += '\n${record.stackTrace}';
      _debug.addMultiline(record.stackTrace.toString(), Colors.white);
    }
    // ignore: avoid_print
    print(str);
  });
}

Future<void> initHive() async {
  await Hive.initFlutter();
  // 以 typeId 为顺序
  Hive.registerAdapter(PrivateKeyInfoAdapter());
  Hive.registerAdapter(SnippetAdapter());
  Hive.registerAdapter(ServerPrivateInfoAdapter());
  Hive.registerAdapter(VirtKeyAdapter());
  Hive.registerAdapter(NetViewTypeAdapter());
}

void runInZone(void Function() body) {
  final zoneSpec = ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
      parent.print(zone, line);
      // This is a hack to avoid
      // `setState() or markNeedsBuild() called during build`
      // error.
      Future.delayed(const Duration(milliseconds: 1), () {
        _debug.addText(line);
      });
    },
  );

  runZonedGuarded(
    body,
    (obj, trace) => Analysis.recordException(trace),
    zoneSpecification: zoneSpec,
  );
}

Future<void> main() async {
  runInZone(() async {
    await initApp();
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => locator<AppProvider>()),
          ChangeNotifierProvider(create: (_) => locator<PkgProvider>()),
          ChangeNotifierProvider(create: (_) => locator<DebugProvider>()),
          ChangeNotifierProvider(create: (_) => locator<DockerProvider>()),
          ChangeNotifierProvider(create: (_) => locator<ServerProvider>()),
          ChangeNotifierProvider(create: (_) => locator<SnippetProvider>()),
          ChangeNotifierProvider(create: (_) => locator<VirtualKeyboard>()),
          ChangeNotifierProvider(create: (_) => locator<PrivateKeyProvider>()),
          ChangeNotifierProvider(create: (_) => locator<SftpProvider>()),
        ],
        child: RebuildWidget(
          child: MyApp(),
        ),
      ),
    );
  });
}
