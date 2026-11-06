import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/server_dist.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/page/ssh/tab.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

/// The terminal tab: what a cold start opens, and what its bar offers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-sshtab-');
    await openTestDb();
    // In memory: this tree writes as it builds, and a test has no
    // business leaving a database behind.
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    // The rail draws each server's distribution mark, which reads this.
    getIt.registerSingleton<ServerDistStore>(ServerDistStore());
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<HistoryStore>(HistoryStore('history_test'));
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1200, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // In a Scaffold, as the home page hosts it: the tab strip's buttons
          // are `InkWell`s and want a Material above them.
          home: const Scaffold(body: SSHTabPage()),
        ),
      ),
    );
    // Counted out: a page holding terminals always has something scheduled.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('a cold start opens no terminal', (tester) async {
    // A terminal left open in the last run is not reopened.
    Stores.server.put(spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u'));

    await pump(tester);

    expect(find.byType(SSHPage), findsNothing);
  });

  testWidgets('terminal settings are editable from the terminal page', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.byKey(const ValueKey('terminal-settings')),
      findsOneWidget,
      reason: 'a split terminal page should not show the action twice',
    );
    await tester.tap(
      find.byKey(const ValueKey('terminal-settings')).hitTestable().first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SettingsSectionPage), findsOneWidget);
    expect(find.text(l10n.wakeLock), findsOneWidget);

    final wakeLock = find.ancestor(
      of: find.text(l10n.wakeLock),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: wakeLock, matching: find.byType(Switch)),
    );
    await tester.pump();

    expect(Stores.setting.sshWakeLock.fetch(), isFalse);
  });

  group('the text view', () {
    /// A phone's terminal leaves timers running; they end with the tree.
    Future<void> closeAll(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    }

    Future<void> openOnPhone(WidgetTester tester) async {
      // A phone opens the terminal's help once; not what this is about.
      Stores.setting.sshTermHelpShown.put(true);
      final spi = spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u');
      Stores.server.put(spi);
      await pump(tester, size: const Size(400, 800));
      ProviderScope.containerOf(
        tester.element(find.byType(SSHTabPage)),
      ).read(terminalRequestsProvider.notifier).add(spi);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(SSHPage), findsOneWidget);
    }

    testWidgets('is behind the menu, taking no button from the bar', (
      tester,
    ) async {
      await openOnPhone(tester);
      expect(find.byTooltip(l10n.termTextView), findsNothing);

      await tester.tap(find.byType(ContextMenuButton));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(l10n.termTextView), findsOneWidget);
      await closeAll(tester);
    });

    testWidgets('is a button of its own for a screen reader', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await openOnPhone(tester);
      expect(find.byTooltip(l10n.termTextView), findsOneWidget);
      await closeAll(tester);
    });
  });
}
