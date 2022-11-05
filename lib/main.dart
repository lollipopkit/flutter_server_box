import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/app.dart';
import 'package:toolbox/core/analysis.dart';
import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/data/model/server/private_key_info.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/provider/app.dart';
import 'package:toolbox/data/provider/apt.dart';
import 'package:toolbox/data/provider/debug.dart';
import 'package:toolbox/data/provider/docker.dart';
import 'package:toolbox/data/provider/private_key.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/provider/sftp_download.dart';
import 'package:toolbox/data/provider/snippet.dart';
import 'package:toolbox/data/store/private_key.dart';
import 'package:toolbox/data/store/server.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/data/store/snippet.dart';
import 'package:toolbox/locator.dart';

Future<void> initApp() async {
  await initHive();
  await setupLocator();
  await upgradeStore();

  locator<SnippetProvider>().loadData();
  locator<PrivateKeyProvider>().loadData();

  ///设置Logger
  Logger.root.level = Level.ALL; // defaults to Level.INFO
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

Future<void> upgradeStore() async {
  final setting = locator<SettingStore>();
  final version = setting.storeVersion.fetch();
  if (version == 0) {
    final snippet = locator<SnippetStore>();
    final key = locator<PrivateKeyStore>();
    final spi = locator<ServerStore>();
    for (final s in <PersistentStore>[snippet, key, spi]) {
      await s.box.deleteAll(s.box.keys);
    }
    setting.storeVersion.put(1);
  }
}

void runInZone(dynamic Function() body) {
  final zoneSpec = ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
      parent.print(zone, line);
      // This is a hack to avoid
      // `setState() or markNeedsBuild() called during build`
      // error.
      Future.delayed(const Duration(milliseconds: 1), () {
        final debugProvider = locator<DebugProvider>();
        debugProvider.addText(line);
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
  final debugProvider = locator<DebugProvider>();
  debugProvider.addError(obj);
  debugProvider.addError(stack);
}

Future<void> main() async {
  runInZone(() async {
    await initApp();
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => locator<AppProvider>()),
          ChangeNotifierProvider(create: (_) => locator<AptProvider>()),
          ChangeNotifierProvider(create: (_) => locator<DebugProvider>()),
          ChangeNotifierProvider(create: (_) => locator<DockerProvider>()),
          ChangeNotifierProvider(create: (_) => locator<ServerProvider>()),
          ChangeNotifierProvider(create: (_) => locator<SnippetProvider>()),
          ChangeNotifierProvider(create: (_) => locator<PrivateKeyProvider>()),
          ChangeNotifierProvider(
              create: (_) => locator<SftpDownloadProvider>()),
        ],
        child: const MyApp(),
      ),
    );
  });
}
