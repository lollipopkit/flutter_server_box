/// Which intro pages a launch shows, and that each lays out at phone and
/// desktop widths.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n_en.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/app.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';

import '../helpers/test_db.dart';

void main() {
  final en = AppLocalizationsEn();
  late SettingStore setting;

  setUp(() async {
    await openTestDb();
    setting = SettingStore('setting_test');
    getIt.registerSingleton<SettingStore>(setting);
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  test('a finished intro shows nothing more', () async {
    setting.introVer.put(1);
    setting.diagnosticsConsentVer.put(1 << 20);
    expect(await introForTest(), isNull);
  });

  for (final size in const [Size(390, 844), Size(1280, 720)]) {
    testWidgets('first launch pages fit ${size.width.toInt()}w', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final intro = await tester.runAsync(introForTest);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [serversProvider.overrideWith(_NoServers.new)],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: app_locale.appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                app_locale.l10n = AppLocalizations.of(context)!;
                context.setLibL10n();
                return intro!;
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(en.introWelcome), findsOneWidget);
      final lib = LibLocalizationsEn();
      for (var i = 0; find.text(lib.done).evaluate().isEmpty; i++) {
        expect(i, lessThan(3));
        await tester.tap(find.text(lib.next));
        // One frame to start the slide, then its length.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.text(en.discoverIntro), findsOneWidget);

      // The real sources read this device's interfaces with a timeout.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}

final class _NoServers extends ServersNotifier {
  @override
  ServersState build() => const ServersState();
}
