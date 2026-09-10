/// A lock nothing on this device can open (#1406).
///
/// `useBioAuth` is stored, synced and restored, so it arrives on machines that
/// were never asked whether they could satisfy it — the reported case is a
/// phone's backup restored onto a Linux desktop. The lock screen then has no
/// way to open, and `PopScope(canPop: false)` there turns the back gesture into
/// "quit the app", so the app is unusable until the setting goes away.
///
/// `LocalAuth` is stubbed to the reported device: nothing available, so every
/// prompt answers `notAvail`. Stubbed rather than left to the plugin, because a
/// plugin call's future does not complete inside a `testWidgets` fake-async
/// zone — the settings tile then renders its loading state for ever, and the
/// test reads as "the switch is missing" whatever the code does.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/setting/platform/platform_pub.dart';

import 'helpers/test_db.dart';

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

  test('turning the lock off is not a user edit', () async {
    // What `home.dart` does when the lock screen reports it cannot open. It is
    // a fact about *this* machine: stamped, the next sync would carry it to the
    // phone the backup came from and silently unlock that too.
    final prop = Stores.setting.useBioAuth;
    prop.store.set(prop.key, true, updateLastUpdateTsOnSet: false);
    final before = Stores.setting.lastUpdateTs;

    final saved = prop.store.set(
      prop.key,
      false,
      updateLastUpdateTsOnSet: false,
    );

    expect(saved, isTrue);
    expect(prop.fetch(), isFalse);
    expect(Stores.setting.lastUpdateTs, before);
  });

  Future<void> pumpSetting(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          LibLocalizations.delegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(children: [PlatformPublicSettings.buildBioAuth]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a device without authentication hides the setting', (
    tester,
  ) async {
    await pumpSetting(tester);
    expect(find.text(libL10n.bioAuth), findsNothing);
    expect(find.text(libL10n.notExistFmt(libL10n.bioAuth)), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('on a device that can authenticate, turning it off asks first', (
    tester,
  ) async {
    // The check that was silently doing nothing. `StoreSwitch` writes the new
    // value after its `callback` regardless of what the callback did, so the
    // old "authenticate, and put the old value back on failure" was overwritten
    // a line later: anyone holding an unlocked device could remove the lock,
    // which is the one thing this asks about.
    LocalAuth.isAvailForTest = () async => true;
    LocalAuth.goWithResultForTest = ({bool onlyBio = false}) async =>
        AuthResult.fail;
    Stores.setting.useBioAuth.put(true);

    await pumpSetting(tester);
    await tester.tap(find.text(libL10n.bioAuth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      Stores.setting.useBioAuth.fetch(),
      isTrue,
      reason: 'the lock came off without anyone proving anything',
    );

    // And it does come off once the prompt is satisfied.
    LocalAuth.goWithResultForTest = ({bool onlyBio = false}) async =>
        AuthResult.success;
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(Stores.setting.useBioAuth.fetch(), isFalse);
  });
}
