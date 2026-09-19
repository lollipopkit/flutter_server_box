import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/temp.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/card/card.dart';
import 'package:server_box/view/page/server/card/density.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/server/tab/tab.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

/// What a long press — and so a right-click — does to a server card.
///
/// The two are one callback (`tab.dart` passes `_onLongPressCard` to both),
/// and `fl_lib/test/secondary_tap_test.dart` covers the gesture. What is left
/// is the branch that callback takes, which depends on whether the server is
/// connected: a card with a status to show raises what can be done to it, and
/// a card with nothing behind it opens the page where that is fixed instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-card-');
    await openTestDb();
    // In memory: this tree writes as it builds, and a test has no
    // business leaving a database behind.
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    // The list draws what has happened to these machines lately, which is
    // the one thing in the app that records a time.
    getIt.registerSingleton<ConnectionStatsStore>(ConnectionStatsStore.instance);
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    // No auto-refresh: 0 is what `normalizeServerStatusRefreshSeconds` reads
    // as off, and its periodic timer would otherwise outlive the tree and
    // fail the run on a pending timer.
    Stores.setting.serverStatusUpdateInterval.put(0);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  /// [size] is the *view*, not the surface: what decides between a menu at the
  /// card and a sheet at the bottom is `MediaQuery`'s width, and
  /// `setSurfaceSize` changes the layout without changing what it reports.
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
          // Both sets, as `app.dart` does: this page reads `context.libL10n`,
          // which is `LibLocalizations.of(context)!` and throws without it.
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          // The same builder the app installs at its root: this page asks
          // `ResponsiveBreakpoints.of` for whether it is on a phone.
          builder: ResponsivePoints.builder,
          home: const ServerPage(),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Unmounted before the test ends: this page holds a periodic refresh
    // timer, and a timer still pending when the tree is torn down is an
    // assertion failure rather than a leak nobody notices.
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets(
    'a long press on a card with nothing behind it opens the edit page',
    (tester) async {
      // `_onLongPressCard` raises the action sheet for a card that has a
      // status, and opens the page where a broken server is fixed when it has
      // not connected — where a menu of things to do to it would be a menu of
      // things that cannot be done.
      //
      // `autoConnect: false`, so the server stays `ServerConn.disconnected` and
      // nothing here reaches for a socket.
      Stores.server.put(
        spiFixture(
          id: 'srv-1',
          name: 'web',
          ip: 'h',
          user: 'u',
          autoConnect: false,
        ),
      );

      await pump(tester);
      expect(find.text('web'), findsWidgets);

      await tester.longPress(find.text('web').first);
      await tester.pumpAndSettle();

      // The edit page — the navigation the callback performs.
      expect(find.byType(ServerEditPage), findsOneWidget);
    },
  );

  testWidgets('and a right-click does the same, being the same callback', (
    tester,
  ) async {
    // `tab.dart` passes `asSecondary(() => _onLongPressCard(srv))` beside
    // the `onLongPress` that gets the same call. The gesture itself is
    // `fl_lib/test/secondary_tap_test.dart`; this is that they agree.
    Stores.server.put(
      spiFixture(
        id: 'srv-1',
        name: 'web',
        ip: 'h',
        user: 'u',
        autoConnect: false,
      ),
    );

    await pump(tester);

    final at = tester.getCenter(find.text('web').first);
    final gesture = await tester.startGesture(at, buttons: kSecondaryButton);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(ServerEditPage), findsOneWidget);
  });

  /// Gives `srv-1` something to report, which is what decides the branch.
  void connect(WidgetTester tester) {
    final ctx = tester.element(find.byType(ServerPage));
    final container = ProviderScope.containerOf(ctx);
    container.read(serverProvider('srv-1').notifier).updateStatus(
      ServerStatus(
        cpu: Cpus(),
        mem: const Memory(total: 1048576, free: 524288, avail: 524288),
        disk: const [],
        tcp: const Conn(maxConn: 0, fail: 0),
        netSpeed: NetSpeed(),
        swap: const Swap(total: 0, free: 0, cached: 0),
        temps: Temperatures(),
        system: SystemType.linux,
        diskIO: DiskIO(),
      ),
    );
    container
        .read(serverProvider('srv-1').notifier)
        .updateConnection(ServerConn.finished);
  }

  Finder menuEntries() => find.byType(ContextMenuRow);

  testWidgets('a card with a status raises the menu beside it', (tester) async {
    // Hung off the card rather than drawn over it or in the middle of the
    // window: which of a list of machines a menu is about is a question the
    // menu's own position answers.
    Stores.server.put(
      spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u', autoConnect: false),
    );
    await pump(tester);
    connect(tester);
    await tester.pumpAndSettle();

    expect(menuEntries(), findsNothing);
    await tester.longPress(find.text('web').first);
    await tester.pumpAndSettle();

    // A menu, not a page and not a sheet.
    expect(find.byType(ServerEditPage), findsNothing);
    expect(menuEntries(), findsWidgets);
    // The one entry that says what it is of, which is the one the design
    // keeps room for: the address that would be copied.
    expect(find.text('u@h:22'), findsOneWidget);
    // And the card says it is the one the menu is about, without moving.
    expect(
      tester.widget<ServerCard>(find.byType(ServerCard)).highlighted,
      isTrue,
    );

    // Escape closes it — the menu's own route takes the key — and the card
    // goes back to being a card.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(menuEntries(), findsNothing);
    expect(
      tester.widget<ServerCard>(find.byType(ServerCard)).highlighted,
      isFalse,
    );
  });

  testWidgets('a tile is too small to say which machine, so the menu does', (
    tester,
  ) async {
    // A 44pt tile holds a state, a name and one number. The menu over it
    // carries the line the taller shapes already have — see `serverMenuHead`.
    Stores.server.put(
      spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u', autoConnect: false),
    );
    ServerDensityPref.put('', ServerListDensity.grid);
    await pump(tester);
    connect(tester);
    await tester.pumpAndSettle();

    await tester.longPress(find.text('web').first);
    await tester.pumpAndSettle();

    expect(menuEntries(), findsWidgets);
    // Twice: on the tile, and at the head of the menu over it.
    expect(find.text('web'), findsNWidgets(2));
  });

  testWidgets('one column under a finger gets the same menu as a sheet', (
    tester,
  ) async {
    // The sheet is where the menu goes, not a second menu: same entries, same
    // rows, and a head — a sheet is at the bottom of the window rather than
    // beside the card it is about.
    Stores.server.put(
      spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u', autoConnect: false),
    );
    await pump(tester, size: const Size(390, 844));
    connect(tester);
    await tester.pumpAndSettle();

    await tester.longPress(find.text('web').first);
    await tester.pumpAndSettle();

    expect(find.byType(RowsSheet), findsOneWidget);
    // The same row widget the popup draws, not a `ListTile` that happens to
    // list the same things.
    expect(
      find.descendant(of: find.byType(RowsSheet), matching: menuEntries()),
      findsWidgets,
    );
    expect(find.text('u@h:22'), findsOneWidget);
    // On the card, and at the head of the sheet.
    expect(find.text('web'), findsNWidgets(2));
  });
}
