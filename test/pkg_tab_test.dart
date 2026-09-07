/// The updates tab's two layouts, and the things about them that are not
/// compile errors.
///
/// The terminal tab's shape: `AdaptivePanes.surface` keeps the *surface* on a
/// narrow window and drops the rail, so everything the rail said has to be
/// said again in the bar — which is what `SessionSwitcherLabel` is for. A tab
/// that forgets leaves a phone on one machine with no way to another.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/pkg/page.dart';
import 'package:server_box/view/page/pkg/tab.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    // Nothing in this test wants a connection attempt, and a poll timer would
    // keep the tree from ever going quiet.
    Stores.setting.serverStatusUpdateInterval.put(0);
    for (final name in ['alpha', 'beta']) {
      Stores.server.put(
        spiFixture(
          id: 'srv-$name',
          name: name,
          ip: 'h',
          user: 'u',
          autoConnect: false,
        ),
      );
    }
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  /// [wide] decides which layout `AdaptivePanes` picks.
  ///
  /// The view, not `setSurfaceSize`: the latter changes layout without
  /// changing what `MediaQuery` reports, so a "phone" written that way
  /// exercises the desktop rendering.
  Future<void> pump(WidgetTester tester, {required bool wide}) async {
    tester.view.physicalSize = wide
        ? const Size(1400, 1000)
        : const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home: const PkgTabPage(),
        ),
      ),
    );
    // Never `pumpAndSettle`: the bar holds a text field with a blinking
    // cursor, so nothing ever settles and it would give up after its
    // ten-minute default.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  /// Frames enough for a route transition to finish, counted rather than
  /// settled — see [pump].
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('the single column', () {
    /// Nothing is selected yet, so the surface is the overview — which is what
    /// somebody opening this tab came to read.
    testWidgets('opens on the list of machines', (tester) async {
      await pump(tester, wide: false);

      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
      expect(find.byType(PkgUpdatesPage), findsNothing);
      // No rail: a narrow window keeps the surface, and a column beside it
      // would be the same list twice.
      expect(find.byType(SideBarTile), findsNothing);
    });

    /// The subject is a widget, not a route: choosing a machine swaps the
    /// surface. Pushing would stack one copy per choice, which a test that only
    /// checked "the right thing is on screen" could not tell apart.
    testWidgets('a machine replaces the list rather than stacking on it', (
      tester,
    ) async {
      await pump(tester, wide: false);

      await tester.tap(find.text('alpha'));
      await settle(tester);

      expect(find.byType(PkgUpdatesPage), findsOneWidget);
      expect(
        tester.widget<PkgUpdatesPage>(find.byType(PkgUpdatesPage)).args?.serverId,
        'srv-alpha',
      );
      // The list is gone rather than underneath, so there is no route to pop
      // back to — which is why the bar has to carry the way to another machine.
      final ctx = tester.element(find.byType(PkgUpdatesPage));
      expect(Navigator.of(ctx).canPop(), isFalse);
    });

    /// The requirement this layout turns on: with the rail dropped, the top
    /// left is the only thing saying which of the set is on screen and the only
    /// way to another.
    testWidgets('the bar leads with the switcher, and it switches', (
      tester,
    ) async {
      await pump(tester, wide: false);
      await tester.tap(find.text('alpha'));
      await settle(tester);

      final switcher = find.byType(SessionSwitcherLabel);
      expect(switcher, findsOneWidget);
      expect(
        tester.widget<SessionSwitcherLabel>(switcher).name,
        'alpha',
        reason: 'it has to say which one is showing',
      );

      // And it opens the same list, which is what makes reaching another
      // machine one tap rather than a way back that does not exist.
      //
      // The name rather than the widget: the switcher is left-aligned inside
      // its `Expanded`, so its ink is only as wide as the label and the
      // widget's centre is empty space beside it.
      await tester.tap(find.descendant(of: switcher, matching: find.text('alpha')));
      await settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.text('beta').last);
      await settle(tester);

      expect(
        tester.widget<PkgUpdatesPage>(find.byType(PkgUpdatesPage)).args?.serverId,
        'srv-beta',
      );
      expect(tester.widget<SessionSwitcherLabel>(switcher).name, 'beta');
    });
  });

  group('two columns', () {
    /// The rail is there from the start, empty surface or not: folding it away
    /// until a machine was chosen would be two layouts for one page.
    testWidgets('the rail is compact and always present', (tester) async {
      await pump(tester, wide: true);

      expect(find.byType(SideBarTile), findsNWidgets(2));
      // Cards are the full-width form. A column this narrow is an index, and a
      // card per row spends most of the width on its own edges.
      expect(find.byType(CardX), findsNothing);
      expect(find.byType(EmptyPane), findsOneWidget);
    });

    testWidgets('shows the machine beside the rail', (tester) async {
      await pump(tester, wide: true);

      await tester.tap(find.text('alpha'));
      await settle(tester);

      expect(find.byType(PkgUpdatesPage), findsOneWidget);
      // Both columns at once, which is the whole of what "two columns" is.
      expect(find.text('beta'), findsOneWidget);

      await tester.tap(find.text('beta'));
      await settle(tester);

      expect(find.byType(PkgUpdatesPage), findsOneWidget);
      expect(
        tester.widget<PkgUpdatesPage>(find.byType(PkgUpdatesPage)).args?.serverId,
        'srv-beta',
      );
    });

    /// The rail says which machine is on screen and how to reach another, so a
    /// switcher in the bar beside it would say it a second time.
    testWidgets('the pane carries no switcher and no back button', (
      tester,
    ) async {
      await pump(tester, wide: true);
      await tester.tap(find.text('alpha'));
      await settle(tester);

      expect(find.byType(SessionSwitcherLabel), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
    });
  });

  group('the tab itself', () {
    /// A tab is a place in a bar that fits four labels on a phone. Taking one
    /// of those places is the user's decision, so a new tab arrives behind
    /// "more" and nothing moves without being asked.
    test('is reachable but not put in the bar', () {
      expect(AppTab.values, contains(AppTab.pkg));
      expect(AppTab.defaultOrder, isNot(contains(AppTab.pkg)));
      expect(AppTab.overflowOf(AppTab.defaultOrder), contains(AppTab.pkg));
    });

    /// Appended, never inserted: the declaration order is the `@HiveField`
    /// index an older record's integer resolves against, so moving a case
    /// re-points every stored tab at a different one.
    test('was appended to the enum', () {
      expect(AppTab.values.last, AppTab.pkg);
    });
  });
}
