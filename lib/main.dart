import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/app.dart';
import 'package:toolbox/core/analysis.dart';
import 'package:toolbox/data/provider/app.dart';
import 'package:toolbox/data/provider/debug.dart';
import 'package:toolbox/data/provider/private_key.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/locator.dart';

Future<void> initApp() async {
  await Hive.initFlutter();
  await setupLocator();
  locator<PrivateKeyProvider>().loadData();

  ///设置Logger
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('[${record.loggerName}][${record.level.name}]: ${record.message}');
  });
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
          ChangeNotifierProvider(create: (_) => locator<DebugProvider>()),
          ChangeNotifierProvider(create: (_) => locator<ServerProvider>()),
          ChangeNotifierProvider(create: (_) => locator<PrivateKeyProvider>()),
        ],
        child: const MyApp(),
      ),
    );
  });
}
