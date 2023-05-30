import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

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

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('[${record.loggerName}][${record.level.name}]: ${record.message}');
  });
}

Future<void> initHive() async {
  await Hive.initFlutter();
  Hive.registerAdapter(SnippetAdapter());
  Hive.registerAdapter(PrivateKeyInfoAdapter());
  Hive.registerAdapter(ServerPrivateInfoAdapter());
}

void runInZone(dynamic Function() body) {
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
    onError,
    zoneSpecification: zoneSpec,
  );
}

void onError(Object obj, StackTrace stack) {
  Analysis.recordException(obj);
  _debug.addMultiline(obj, Colors.red);
  _debug.addMultiline(stack, Colors.white);
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
