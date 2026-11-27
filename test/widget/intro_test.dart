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
import 'package:server_box/core/sync/secret_key_prefs.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_db.dart';

void main() {
  final en = AppLocalizationsEn();
  late SettingStore setting;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    await openTestDb();
    setting = SettingStore('setting_test');
    getIt.registerSingleton<SettingStore>(setting);
    FlutterSecureStorage.setMockInitialValues({});
    SecureProp.legacyApart = false;
    SyncKeyring.resetForTest();
    SyncKeyring.init(label: 'ServerBox sync key');
  });

  tearDown(() async {
    SecureProp.legacyApart = null;
    SyncKeyring.resetForTest();
    await getIt.reset();
    await closeTestDb();
  });

  Future<void> pumpIntro(
    WidgetTester tester,
    Widget intro, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
              return intro;
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  test('a finished local-only intro shows nothing more', () async {
    setting.introVer.put(1);
    setting.diagnosticsConsentVer.put(1 << 20);
    expect(await introForTest(), isNull);
  });

  test('an existing Apple device with synced secret key skips intro', () async {
    setting.introVer.put(1);
    setting.diagnosticsConsentVer.put(1 << 20);
    await PrefProps.webdavSync.set(true);
    FlutterSecureStorage.setMockInitialValues({
      SecureStoreProps.syncSecretKey.key: 'S1-7K4M9-2P8QX-5R3VN-8W6YB-4C9DF-3H2JK',
    });
    expect(await introForTest(), isNull);
  });

  Finder navButton(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(FilledButton));

  Finder listScrollable() => find
      .descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> scrollAndTap(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(target, 200, scrollable: listScrollable());
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
  }

  for (final size in const [Size(390, 844), Size(1280, 720)]) {
    testWidgets('first launch pages fit ${size.width.toInt()}w', (
      tester,
    ) async {
      final intro = await tester.runAsync(introForTest);
      await pumpIntro(tester, intro!, size: size);

      expect(find.text(en.introWelcome), findsOneWidget);
      final lib = LibLocalizationsEn();
      for (var i = 0; find.text(lib.done).evaluate().isEmpty; i++) {
        expect(i, lessThan(4));
        if (find.text(en.syncSecretKey).evaluate().isNotEmpty) {
          // Next button stays gated while unchecked on the Secret Key step.
          expect(tester.widget<FilledButton>(navButton(lib.next)).onPressed, isNull);
          await scrollAndTap(tester, find.text(en.syncSecretKeySkipNew));
        } else {
          await tester.tap(find.text(lib.next));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.text(en.discoverIntro), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 10));
    });
  }

  testWidgets('existing synced device A sees single-page upgrade gated by ack', (tester) async {
    setting.introVer.put(1);
    setting.diagnosticsConsentVer.put(1 << 20);
    await PrefProps.webdavSync.set(true);
    await SyncSecretKeyPrefs.backupPending.set(true);
    FlutterSecureStorage.setMockInitialValues({
      SecureStoreProps.syncSecretKey.key: 'S1-7K4M9-2P8QX-5R3VN-8W6YB-4C9DF-3H2JK',
    });

    final intro = await tester.runAsync(introForTest);
    expect(intro, isNotNull);
    await pumpIntro(tester, intro!);
    final lib = LibLocalizationsEn();

    expect(find.text(en.syncSecretKeyIntroUpgradeA), findsOneWidget);
    expect(find.text(en.syncSecretKeyZeroKnowledgeWarn), findsOneWidget);
    expect(tester.widget<FilledButton>(navButton(lib.done)).onPressed, isNull);

    await scrollAndTap(tester, find.text(en.syncSecretKeyAck));
    await tester.pump();
    expect(tester.widget<FilledButton>(navButton(lib.done)).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('existing synced device B sees single-page import-only step with defer option', (tester) async {
    setting.introVer.put(1);
    setting.diagnosticsConsentVer.put(1 << 20);
    await PrefProps.webdavSync.set(true);
    SyncKeyring.secretKeyMissing.value = true;

    final intro = await tester.runAsync(introForTest);
    expect(intro, isNotNull);
    await pumpIntro(tester, intro!);
    final lib = LibLocalizationsEn();

    expect(find.text(en.syncSecretKeyIntroUpgradeB), findsOneWidget);
    expect(find.text(en.syncSecretKeyTabGenerate), findsNothing);
    expect(find.text(en.syncSecretKeySkipLater), findsOneWidget);
    expect(tester.widget<FilledButton>(navButton(lib.done)).onPressed, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('fresh install with iCloud Keychain key shows synced state and enables Next', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      SecureStoreProps.syncSecretKey.key: 'S1-7K4M9-2P8QX-5R3VN-8W6YB-4C9DF-3H2JK',
    });
    final intro = await tester.runAsync(introForTest);
    expect(intro, isNotNull);
    await pumpIntro(tester, intro!);
    final lib = LibLocalizationsEn();

    await tester.tap(find.text(lib.next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(en.syncSecretKeyIntroSynced), findsOneWidget);
    expect(tester.widget<FilledButton>(navButton(lib.next)).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('device B import shows invalid error from empty state and commits valid key', (tester) async {
    setting.introVer.put(1);
    setting.diagnosticsConsentVer.put(1 << 20);
    await PrefProps.webdavSync.set(true);
    SyncKeyring.secretKeyMissing.value = true;
    await tester.runAsync(() => FlRust.ensureInitialized());
    final validKey = SyncKeyring.generateSecretKey();
    var doneCalled = false;

    final intro = await tester.runAsync(() => introForTest(onDone: (_) => doneCalled = true));
    await pumpIntro(tester, intro!);
    final lib = LibLocalizationsEn();

    // Entering invalid text from empty state immediately displays error.
    await tester.enterText(find.byType(TextField), 'not-a-key');
    await tester.pump();
    expect(find.text(en.syncSecretKeyInvalid), findsOneWidget);
    expect(tester.widget<FilledButton>(navButton(lib.done)).onPressed, isNull);

    // Entering a valid key clears the error and enables Done.
    await tester.enterText(find.byType(TextField), validKey.toLowerCase());
    await tester.pump();
    expect(find.text(en.syncSecretKeyInvalid), findsNothing);
    expect(find.text(validKey), findsOneWidget);
    expect(tester.widget<FilledButton>(navButton(lib.done)).onPressed, isNotNull);

    await tester.tap(navButton(lib.done));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(doneCalled, isTrue);
    expect(await SecureStoreProps.syncSecretKey.read(limited: false), validKey);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('device A reactively switches to import-only when remote reports 2FA missing', (tester) async {
    setting.introVer.put(1);
    setting.diagnosticsConsentVer.put(1 << 20);
    await PrefProps.webdavSync.set(true);
    var doneCalled = false;

    final intro = await tester.runAsync(() => introForTest(onDone: (_) => doneCalled = true));
    await pumpIntro(tester, intro!);

    // Initially Device A with generate/import switch.
    expect(find.text(en.syncSecretKeyIntroUpgradeA), findsOneWidget);
    expect(find.text(en.syncSecretKeyTabGenerate), findsOneWidget);

    // Background probe discovers remote is already 2FA-sealed.
    SyncKeyring.secretKeyMissing.value = true;
    await tester.pump();

    expect(find.text(en.syncSecretKeyIntroUpgradeB), findsOneWidget);
    expect(find.text(en.syncSecretKeyTabGenerate), findsNothing);

    // Deferring sets introDeferred and finishes single-page intro.
    await tester.tap(find.text(en.syncSecretKeySkipLater));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(doneCalled, isTrue);
    expect(SyncSecretKeyPrefs.introDeferred.get(), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('switching locale on page 0 does not dispose SecretKeyIntroController', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [serversProvider.overrideWith(_NoServers.new)],
        child: const MyApp(),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 500));

    // Trigger locale change (recreates MaterialApp with ValueKey(locale)).
    setting.locale.put('zh');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Advance from page 0 to Secret Key page without hitting disposed ValueNotifier.
    final nextBtn = find.byType(FilledButton);
    expect(nextBtn, findsOneWidget);
    await tester.tap(nextBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('安全密钥'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });
}

final class _NoServers extends ServersNotifier {
  @override
  ServersState build() => const ServersState();
}
