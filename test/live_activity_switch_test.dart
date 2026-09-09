/// The Live Activity switch, and that nothing reaches the lock screen without
/// it.
///
/// One used to appear whenever a terminal connected, with nothing to stop it.
/// It carries a server's name and the state of a connection to it, on a screen
/// readable without unlocking the phone — so it is opted into, and the default
/// is off.
///
/// The decision is a pure function for the same reason
/// `decideAndroidSessionServiceAction` is: everything around it in
/// `TermSessionManager._syncLatest` is behind `isIOS`, which is false wherever
/// these run, so the branch itself is only reachable on a device.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/ios_live_activity_policy.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/setting/platform/ios.dart';

import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    // The watch tile counts monitor-backed servers.
    getIt.registerSingleton<ServerStore>(ServerStore());
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  test('the switch is off out of the box', () {
    // The whole point. A default of true would opt every existing install into
    // putting server names on its lock screen at the next update.
    expect(Stores.setting.liveActivity.fetch(), isFalse);
  });

  group('what a sync does', () {
    test('a session with the switch off raises nothing', () {
      expect(
        decideIosLiveActivityAction(hasSessions: true, enabled: false),
        IosLiveActivityAction.stop,
      );
    });

    test('and with it on, pushes', () {
      expect(
        decideIosLiveActivityAction(hasSessions: true, enabled: true),
        IosLiveActivityAction.update,
      );
    });

    test('the switch off reads exactly like having no sessions', () {
      // Not "leave it alone". An activity outlives the process that raised it,
      // so turning the switch off has to *end* the one already up rather than
      // stop refreshing it — otherwise it sits on the lock screen going stale
      // until the session ends or the user swipes it away.
      for (final hasSessions in [true, false]) {
        expect(
          decideIosLiveActivityAction(hasSessions: hasSessions, enabled: false),
          IosLiveActivityAction.stop,
          reason: 'hasSessions=$hasSessions',
        );
      }
      expect(
        decideIosLiveActivityAction(hasSessions: false, enabled: true),
        IosLiveActivityAction.stop,
      );
    });
  });

  testWidgets('the iOS settings page offers the switch', (tester) async {
    // Off `IosSettingsPage` rather than a tile built here, so a switch dropped
    // from the page fails this. Everything else on that page reads a store or a
    // channel and answers null in a test; the tile under test does not need
    // either.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const IosSettingsPage(embedded: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final title = find.text(l10n.liveActivity);
    expect(title, findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(of: title, matching: find.byType(ListTile)),
        matching: find.byType(Switch),
      ),
      findsOneWidget,
    );
  });
}
