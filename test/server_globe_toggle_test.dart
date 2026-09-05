import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/selection.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/self_addr.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/tab/tab.dart';
import 'package:server_box/view/widget/globe/view.dart';
import 'package:server_box/view/widget/server_globe.dart';

import 'helpers/geo_fixture.dart';
import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

/// The globe as the server tab reaches it: whether the button is there, what
/// it switches to, and whether the choice survives a relaunch.
///
/// `pumpAndSettle` is not usable — the globe animates its entrance and the
/// page holds a refresh timer, so frames are counted out by hand.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('globe-toggle-');
    Paths.doc = tmp.path;
  });

  tearDownAll(() => tmp.delete(recursive: true));

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<SelfAddrStore>(SelfAddrStore('self_addr_test'));
    // Off, or its periodic timer outlives the tree and fails the run.
    Stores.setting.serverStatusUpdateInterval.put(0);
    // The shared vectors, installed as if downloaded: `8.8.8.8` is placed
    // and everything the tests use as a LAN address is not.
    await installGeoVectors();
  });

  tearDown(() async {
    await removeGeoVectors();
    await getIt.reset();
    await SqliteDb.close();
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(420, 900),
    double bottomInset = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    if (bottomInset > 0) {
      tester.view.padding = FakeViewPadding(bottom: bottomInset);
    }
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
          home: const ServerPage(),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  void addServer({String id = 'srv-1', String ip = '8.8.8.8'}) {
    Stores.server.put(
      spiFixture(id: id, name: 'srv $id', ip: ip, user: 'u', autoConnect: false),
    );
  }

  Finder globeButton() => find.byIcon(Icons.public);

  /// Past the entrance animation and the post-frame callback that publishes
  /// the claim. `pumpAndSettle` is not usable here — see the note above.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// The tab asking for the whole window, as the home page reads it.
  AppTab? immersiveTab(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(ServerPage)),
  ).read(immersiveTabProvider);

  /// Opens the detail pane, which is what a wide window needs before it is
  /// split at all.
  ///
  /// `AdaptivePanes` computes `roomForTwo` as `wideEnough && _hasContent`, and
  /// `detailBuilder` is null until something is selected — so a wide window
  /// with nothing open goes down the *single column* branch. A test that only
  /// sets the size is testing the narrow layout on a big screen.
  ///
  /// Written through the provider rather than by tapping a card: a tap also
  /// launches the card-into-rail flight, which is a second animation in the
  /// middle of the one under test.
  Future<void> openDetail(WidgetTester tester, String id) async {
    final ctx = tester.element(find.byType(ServerPage));
    ProviderScope.containerOf(
      ctx,
    ).read(serverSelectionProvider.notifier).select(id);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('the button is there when the feature is on', (tester) async {
    addServer();
    await pump(tester);
    expect(globeButton(), findsOneWidget);
  });

  testWidgets('and absent when it is off', (tester) async {
    // Absent, not disabled. A button that explains itself by doing nothing is
    // worse than one that is not offered.
    Stores.setting.globeEnabled.put(false);
    addServer();
    await pump(tester);
    expect(globeButton(), findsNothing);
    expect(find.byType(ServerGlobe), findsNothing);
  });

  testWidgets('the feature being off wins over a stored choice', (
    tester,
  ) async {
    // Someone who chose the globe and then turned the feature off must not get
    // a globe with no way to leave it.
    Stores.setting.serverPageGlobe.put(true);
    Stores.setting.globeEnabled.put(false);
    addServer();
    await pump(tester);
    expect(find.byType(ServerGlobe), findsNothing);
  });

  testWidgets('tapping it swaps the grid for the globe, and back', (
    tester,
  ) async {
    addServer();
    await pump(tester);
    expect(find.byType(ServerGlobe), findsNothing);

    await tester.tap(globeButton());
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(ServerGlobe), findsOneWidget);
    expect(find.byType(GlobeView), findsOneWidget);

    // The icon is the grid now, because what the button offers is the way out.
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(ServerGlobe), findsNothing);
  });

  testWidgets('the choice is stored, so a relaunch opens on it', (
    tester,
  ) async {
    addServer();
    await pump(tester);
    await tester.tap(globeButton());
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(Stores.setting.serverPageGlobe.fetch(), isTrue);

    // A second page, as a relaunch would build it.
    await tester.pumpWidget(const SizedBox.shrink());
    await pump(tester);
    expect(find.byType(ServerGlobe), findsOneWidget);
  });

  testWidgets('a server the database cannot place is in the strip', (
    tester,
  ) async {
    // A private address never reaches a lookup at all, so this is also the
    // check that such a server is still on screen somewhere.
    Stores.setting.serverPageGlobe.put(true);
    addServer(id: 'lan', ip: '192.168.1.10');
    await pump(tester);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(ServerGlobe), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'srv lan'), findsOneWidget);
  });

  testWidgets('with no servers at all it is the grid\'s empty state', (
    tester,
  ) async {
    // Not an empty globe: "add a server" is what an install with none needs to
    // be told, and a sphere with nothing on it cannot say it.
    Stores.setting.serverPageGlobe.put(true);
    await pump(tester);
    expect(find.byType(ServerGlobe), findsNothing);
    expect(find.byType(EmptyPane), findsOneWidget);
    // And the bar stays, which is not a detail: the empty states are the ones
    // with something to undo, and the control that undoes it is up there.
    expect(find.byType(SessionSwitcherLabel), findsOneWidget);
    expect(immersiveTab(tester), isNull);
  });

  /// The globe as the whole window.
  ///
  /// A sphere fills the column it is given, and the bar over it and the
  /// navigation under it are two rows of controls around a picture that *is*
  /// the page. So the tab takes the window and carries its own way out — which
  /// is the part that has to hold, because nothing else on screen leaves.
  group('taking the window', () {
    testWidgets('the bar goes and the globe carries the way back', (
      tester,
    ) async {
      addServer();
      await pump(tester);
      expect(find.byType(SessionSwitcherLabel), findsOneWidget);

      await tester.tap(globeButton());
      await settle(tester);

      expect(find.byType(ServerGlobe), findsOneWidget);
      expect(find.byType(SessionSwitcherLabel), findsNothing);
      // What the home page reads to take the navigation away with it.
      expect(immersiveTab(tester), AppTab.server);
      // Over the globe itself, since the bar that held the toggle is gone.
      expect(
        find.descendant(
          of: find.byType(ServerGlobe),
          matching: find.byIcon(Icons.grid_view_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('and both come back when it is left', (tester) async {
      Stores.setting.serverPageGlobe.put(true);
      addServer();
      await pump(tester);
      expect(find.byType(SessionSwitcherLabel), findsNothing);

      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await settle(tester);

      expect(find.byType(ServerGlobe), findsNothing);
      expect(find.byType(SessionSwitcherLabel), findsOneWidget);
      expect(immersiveTab(tester), isNull);
    });

    testWidgets('the feature being turned off gives the window back', (
      tester,
    ) async {
      // The globe closes with nothing having been tapped, so the claim has to
      // be dropped by the same build that drops the globe — otherwise the
      // navigation stays gone with nothing on screen that would bring it back.
      Stores.setting.serverPageGlobe.put(true);
      addServer();
      await pump(tester);
      expect(immersiveTab(tester), AppTab.server);

      Stores.setting.globeEnabled.put(false);
      await settle(tester);

      expect(immersiveTab(tester), isNull);
      expect(find.byType(SessionSwitcherLabel), findsOneWidget);
    });

    testWidgets('and the bottom inset is still somebody\'s to spend', (
      tester,
    ) async {
      // The bar that used to spend it is gone, so this page has to — which is
      // why it keeps its `SafeArea` with no app bar over it.
      //
      // The other half of that is on the home page and cannot be seen from
      // here: `Scaffold` takes the bottom padding off its body whenever the
      // bottom slot is *filled*, on the grounds that the bar will spend it. A
      // bar left in place drawing nothing spends nothing, and the globe ran
      // under the home indicator — so the home page removes the bar rather
      // than emptying it.
      const inset = 34.0;
      Stores.setting.serverPageGlobe.put(true);
      addServer();
      await pump(tester, bottomInset: inset);

      expect(find.byType(ServerGlobe), findsOneWidget);
      final globe = tester.getRect(find.byType(ServerGlobe));
      expect(globe.bottom, 900 - inset);
    });

    testWidgets('not beside a detail pane, where the pane has the way out', (
      tester,
    ) async {
      // Split, the globe is a column rather than the page and the actions row
      // above it is still there — so the window's chrome is not in the way of
      // anything.
      Stores.setting.serverPageGlobe.put(true);
      addServer();
      await pump(tester, size: const Size(1400, 900));
      await openDetail(tester, 'srv-1');

      expect(find.byKey(const ValueKey('globe-pane')), findsOneWidget);
      expect(immersiveTab(tester), isNull);
    });

    testWidgets('and the claim is dropped when the split arrives', (
      tester,
    ) async {
      // A wide window with nothing open goes down the single-column branch, so
      // the globe does fill it — until a server is selected and it becomes one
      // column of two.
      Stores.setting.serverPageGlobe.put(true);
      addServer();
      await pump(tester, size: const Size(1400, 900));
      expect(immersiveTab(tester), AppTab.server);

      await openDetail(tester, 'srv-1');
      expect(immersiveTab(tester), isNull);
    });
  });

  testWidgets('turning the feature off while the globe is up closes it', (
    tester,
  ) async {
    // Otherwise the button that turns it off disappears — `_listActions`
    // checks the setting — while the globe stays, leaving a sphere with every
    // server in the unplaced strip and no control anywhere to leave it.
    Stores.setting.serverPageGlobe.put(true);
    addServer();
    await pump(tester);
    expect(find.byType(ServerGlobe), findsOneWidget);

    Stores.setting.globeEnabled.put(false);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(ServerGlobe), findsNothing);
    expect(globeButton(), findsNothing);
  });

  testWidgets('on a wide window the globe replaces the rail', (tester) async {
    // The rail is what a wide window shows, so without this the globe would be
    // unreachable on a desktop entirely.
    //
    // The detail has to be open or there is no split and this exercises the
    // single-column branch on a large canvas — which is what it did, so it
    // passed whatever `_buildGlobePane` was doing. `globe-pane` is the key
    // that says which branch actually ran.
    Stores.setting.serverPageGlobe.put(true);
    addServer();
    await pump(tester, size: const Size(1400, 900));
    await openDetail(tester, 'srv-1');
    expect(find.byKey(const ValueKey('globe-pane')), findsOneWidget);
    expect(find.byType(ServerGlobe), findsOneWidget);
    // And the actions row is still there, which is the way back out.
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
  });

  /// The list becoming the globe, rather than being replaced by it.
  group('the swap', () {
    /// One frame past the tap, then partway into the transition — both
    /// children are mounted here and neither has finished moving.
    Future<void> midway(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('crosses rather than cuts, on a single column', (tester) async {
      addServer();
      await pump(tester);
      expect(find.byKey(const ValueKey('grid')), findsOneWidget);

      await tester.tap(globeButton());
      await midway(tester);
      expect(
        find.byType(ServerGlobe),
        findsOneWidget,
        reason: 'the globe is already in the tree while the grid leaves',
      );
      expect(find.byKey(const ValueKey('grid')), findsOneWidget);

      await settle(tester);
      expect(find.byKey(const ValueKey('grid')), findsNothing);
      expect(find.byType(ServerGlobe), findsOneWidget);
    });

    testWidgets('and on a wide window, which used to cut', (tester) async {
      // The split branch returned one pane or the other directly, so the globe
      // replaced the rail between one frame and the next.
      addServer();
      await pump(tester, size: const Size(1400, 900));
      await openDetail(tester, 'srv-1');
      expect(find.byKey(const ValueKey('list-pane')), findsOneWidget);

      await tester.tap(globeButton());
      await midway(tester);
      // **The regression this test exists for.** Both panes are mounted here,
      // so the actions row is built twice — and the globe button carried a
      // `GlobalKey` for the guide to measure. Two widgets holding one of those
      // at the same time throws during build, which lands here.
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('list-pane')), findsOneWidget);
      expect(find.byKey(const ValueKey('globe-pane')), findsOneWidget);

      await settle(tester);
      expect(find.byKey(const ValueKey('list-pane')), findsNothing);
      expect(find.byKey(const ValueKey('globe-pane')), findsOneWidget);
      expect(find.byType(ServerGlobe), findsOneWidget);
    });

    testWidgets('the way back is the same movement', (tester) async {
      Stores.setting.serverPageGlobe.put(true);
      addServer();
      await pump(tester, size: const Size(1400, 900));
      await openDetail(tester, 'srv-1');
      expect(find.byKey(const ValueKey('globe-pane')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await midway(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('globe-pane')), findsOneWidget);
      expect(find.byKey(const ValueKey('list-pane')), findsOneWidget);

      await settle(tester);
      expect(find.byKey(const ValueKey('globe-pane')), findsNothing);
    });
  });

  /// The one-off walkthrough over the globe button.
  ///
  /// It waits two seconds so the launch notices are up if there are any, and
  /// `pump` above only counts out one — so every test here pumps past that on
  /// purpose, and every other test in this file is unaffected by design.
  group('the guide', () {
    const body =
        'Tap here to see your servers on a globe, at where their addresses are.';

    /// Past the delay in `_scheduleGlobeGuide`, and then through the card's
    /// own fade.
    Future<void> waitItOut(WidgetTester tester) async {
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    setUp(() {
      // One walkthrough per launch, and the tab strip's comes first. Every
      // case here is a launch where that one is already behind us.
      Stores.setting.navTabMenuGuided.put(true);
    });

    testWidgets('points at the button once', (tester) async {
      addServer();
      await pump(tester);
      expect(find.text(body), findsNothing, reason: 'not before the delay');

      await waitItOut(tester);
      expect(find.text(body), findsOneWidget);
      expect(
        Stores.setting.globeGuided.fetch(),
        isFalse,
        reason: 'written when it has been seen through, not when it was shown',
      );

      await tester.tap(find.text(libL10n.done));
      await waitItOut(tester);
      expect(find.text(body), findsNothing);
      expect(Stores.setting.globeGuided.fetch(), isTrue);
    });

    testWidgets('and never again', (tester) async {
      Stores.setting.globeGuided.put(true);
      addServer();
      await pump(tester);
      await waitItOut(tester);
      expect(find.text(body), findsNothing);
    });

    testWidgets('not when the feature is off', (tester) async {
      // There is no button to point at, and turning the feature on later must
      // not find the guide already spent.
      Stores.setting.globeEnabled.put(false);
      addServer();
      await pump(tester);
      await waitItOut(tester);
      expect(find.text(body), findsNothing);
      expect(Stores.setting.globeGuided.fetch(), isFalse);
    });

    testWidgets('not when the globe is already up', (tester) async {
      // Being shown where the button that is already pressed is reads as the
      // app not knowing what is on screen.
      Stores.setting.serverPageGlobe.put(true);
      addServer();
      await pump(tester);
      await waitItOut(tester);
      expect(find.text(body), findsNothing);
    });

    testWidgets('not with no servers to place', (tester) async {
      await pump(tester);
      await waitItOut(tester);
      expect(find.text(body), findsNothing);
    });

    testWidgets('not before the tab strip has had its own', (tester) async {
      // Two scrims at once, one over the other. The strip's comes first
      // because it is about how to reach anything at all.
      Stores.setting.navTabMenuGuided.put(false);
      addServer();
      await pump(tester);
      await waitItOut(tester);
      expect(find.text(body), findsNothing);
    });

    testWidgets('not while another tab is the one on screen', (tester) async {
      // This tab is kept alive behind the others, so the wait can finish after
      // the user has moved on — and the overlay draws above every route.
      addServer();
      await pump(tester);
      final ctx = tester.element(find.byType(ServerPage));
      ProviderScope.containerOf(ctx)
          .read(currentHomeTabProvider.notifier)
          .update(AppTab.ssh);
      await waitItOut(tester);
      expect(find.text(body), findsNothing);
    });

    testWidgets('leaving the page cancels the wait', (tester) async {
      // A bare `Future.delayed` outlives the page, which is a pending timer
      // after the tree is gone.
      addServer();
      await pump(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await waitItOut(tester);
      expect(find.text(body), findsNothing);
    });
  });
}
