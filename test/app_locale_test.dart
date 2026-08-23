import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/app.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingStore setting;

  setUp(() async {
    SqliteDb.openInMemory();
    setting = SettingStore.forTest();
    getIt.registerSingleton<SettingStore>(setting);
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
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
