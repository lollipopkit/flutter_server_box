/// The updates tab's two layouts, and the four things about a two-column tab
/// that are not compile errors.
///
/// `AdaptivePanes.detail` hands a narrow window `listBuilder` and nothing
/// else, so what that column *is* decides what a phone gets. Here it is the
/// server list in both layouts — the tab answers "which machine is behind",
/// and that answer is the column of counts — and the machine's own page is
/// pushed rather than swapped in. None of that is checkable by the analyzer.
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
    /// The rule this tab departs from the benchmark tab on, stated as a test:
    /// there, one column is the run and the history hides behind a button;
    /// here the list *is* what somebody opened the tab to read.
    testWidgets('is the server list, not one machine', (tester) async {
      await pump(tester, wide: false);

      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
      // Nothing is selected, so no machine's page is on screen.
      expect(find.byType(PkgUpdatesPage), findsNothing);
    });

    /// Pushed on the tab's own navigator, so back returns to the list rather
    /// than replacing the column — which a test that only checked "the right
    /// thing is on screen" could not tell apart.
    testWidgets('opens a machine as a page, and back returns', (tester) async {
      await pump(tester, wide: false);

      await tester.tap(find.text('alpha'));
      await settle(tester);

      expect(find.byType(PkgUpdatesPage), findsOneWidget);

      // A route was pushed, and on a navigator *inside* the tab: `canPop` is
      // what says the page went on top of the list rather than replacing the
      // column. Popping and finding the list again is the other half — a swap
      // would have nothing to pop, and popping the tab's own navigator when it
      // is empty would take the whole tab off instead.
      final ctx = tester.element(find.byType(PkgUpdatesPage));
      expect(Navigator.of(ctx).canPop(), isTrue);
      Navigator.of(ctx).pop();
      await settle(tester);

      expect(find.byType(PkgUpdatesPage), findsNothing);
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
    });
  });

  group('two columns', () {
    /// The root shows an empty pane rather than a machine picked for the user:
    /// `detailId` has to be null while nothing is selected, or every return
    /// from a machine is one non-null id replacing another — which
    /// `NestedNavigator` reads as a way *in*, and the pane slides off the
    /// wrong edge.
    testWidgets('starts with nothing selected', (tester) async {
      await pump(tester, wide: true);

      expect(find.text('alpha'), findsOneWidget);
      expect(find.byType(PkgUpdatesPage), findsNothing);
      expect(find.byType(EmptyPane), findsOneWidget);
    });

    /// The subject is a widget, not a route: choosing another machine rebuilds
    /// the column rather than stacking a copy per choice.
    testWidgets('shows the machine beside the list', (tester) async {
      await pump(tester, wide: true);

      await tester.tap(find.text('alpha'));
      await settle(tester);

      expect(find.byType(PkgUpdatesPage), findsOneWidget);
      // Both columns, at once — which is the whole of what "two columns" is.
      expect(find.text('beta'), findsOneWidget);

      await tester.tap(find.text('beta'));
      await settle(tester);

      // One, not two. `NestedNavigator` replaces its root when `rootId`
      // changes and clears anything above it, so a second choice must leave
      // one page behind — the two coexist only while the change animates,
      // which is what `settle` waits out.
      expect(find.byType(PkgUpdatesPage), findsOneWidget);
      expect(
        tester.widget<PkgUpdatesPage>(find.byType(PkgUpdatesPage)).args?.serverId,
        'srv-beta',
      );
    });

    /// `CustomAppBar` supplies a back button at a pane's root, wired to
    /// `onCloseDetail`. Right for something opened *into* the pane; wrong for
    /// the list column, where it has nowhere to go and does nothing when
    /// pressed.
    testWidgets('the list column has no back button', (tester) async {
      await pump(tester, wide: true);

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
