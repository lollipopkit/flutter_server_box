/// The app lock: only a successful prompt changes or passes it.
///
/// `LocalAuth` is stubbed rather than left to the plugin, because a plugin
/// call's future does not complete inside a `testWidgets` fake-async zone.
library;

import 'package:fl_lib/fl_lib.dart' hide isWindows;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/app_auth.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/setting/platform/platform_pub.dart';

import '../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    LocalAuth.isAvailForTest = () async => false;
    LocalAuth.goWithResultForTest = ({bool onlyBio = false}) async =>
        AuthResult.notAvail;
  });

  tearDown(() async {
    LocalAuth.isAvailForTest = null;
    LocalAuth.goWithResultForTest = null;
    await getIt.reset();
    await SqliteDb.close();
  });

  test('the lock stays on this device', () {
    // Never carried by a backup, a restore or a sync: whether a device can
    // open the lock is only known on that device.
    for (final key in ['useBioAuth', 'delayBioAuthLock']) {
      expect(Stores.setting.isDeviceLocalKey(key), isTrue, reason: key);
    }
  });

  test('a device that cannot authenticate reveals nothing', () async {
    Stores.setting.useBioAuth.put(true);
    expect(await AppAuth.confirm(), isFalse);
  });

  Future<void> pumpSetting(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          ...appLocalizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            children: [
              PlatformPublicSettings.buildBioAuth(),
              PlatformPublicSettings.buildBioAuthDelay(),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  test('a device without authentication has no setting to show', () async {
    // Asked before anything is built, and by the page rather than by the row:
    // these two rows live in a named group now, and a group whose rows arrive
    // a frame later is a heading and a hairline with nothing under them.
    expect(await PlatformPublicSettings.bioAuthAvailable, isFalse);
  });

  Future<void> toggle(WidgetTester tester, AuthResult result) async {
    LocalAuth.goWithResultForTest = ({bool onlyBio = false}) async => result;
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('turning it on asks first', (tester) async {
    // A lock this device cannot open would hold the app for good.
    await pumpSetting(tester);

    await toggle(tester, AuthResult.notAvail);
    expect(Stores.setting.useBioAuth.fetch(), isFalse);

    await toggle(tester, AuthResult.success);
    expect(Stores.setting.useBioAuth.fetch(), isTrue);
  });

  testWidgets('turning it off asks first', (tester) async {
    // `StoreSwitch` writes after its callback whatever the callback did, so
    // this goes through the validator.
    Stores.setting.useBioAuth.put(true);
    await pumpSetting(tester);

    await toggle(tester, AuthResult.fail);
    expect(Stores.setting.useBioAuth.fetch(), isTrue);

    await toggle(tester, AuthResult.success);
    expect(Stores.setting.useBioAuth.fetch(), isFalse);
  });
}
