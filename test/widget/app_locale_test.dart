import 'package:fl_lib/generated/l10n/lib_l10n_en.dart';
import 'package:fl_lib/generated/l10n/lib_l10n_zh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/app.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/setting.dart';

import '../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final libEn = LibLocalizationsEn();
  final libZh = LibLocalizationsZh();
  late SettingStore setting;

  setUp(() async {
    // The tables, not only a connection: the intro's Virtualization page
    // reads the PVE table to decide what to say.
    await openTestDb();
    setting = SettingStore('setting_test');
    getIt.registerSingleton<SettingStore>(setting);
    getIt.registerSingleton<PveStore>(PveStore());
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  testWidgets('updates the onboarding locale when the setting changes', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text(libEn.init), findsOneWidget);
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
    expect(find.text(libEn.init), findsNothing);
    expect(find.text(libZh.init), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
