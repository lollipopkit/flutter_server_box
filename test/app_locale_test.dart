import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:server_box/app.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<dynamic> box;
  late SettingStore setting;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-app-test-');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>('setting_test');
    setting = SettingStore.forBox(box);
    getIt.registerSingleton<SettingStore>(setting);
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('updates the onboarding locale when the setting changes', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Initialize'), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).locale, isNull);

    setting.locale.put('zh');
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('zh'),
    );
    expect(
      Localizations.localeOf(tester.element(find.byType(ListView).first)),
      const Locale('zh'),
    );
    expect(find.text('Initialize'), findsNothing);
    expect(find.text('初始化'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
