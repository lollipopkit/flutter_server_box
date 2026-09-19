import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/temp.dart';
import 'package:server_box/data/provider/server/selection.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/card/card.dart';
import 'package:server_box/view/page/server/card/swap.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/server/tab/tab.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

/// Opening a server does not leave the list.
///
/// The two used to be two pages, reached by pushing one over the other or by
/// putting a pane beside it. They are one now: the card takes the width of the
/// page and the rest of the grid makes way, so what is on screen is still the
/// list with one of its cards open — which is what the strip of other machines
/// over it and the list actions still in the bar are for.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-open-');
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    // The list draws what has happened to these machines lately, which is
    // the one thing in the app that records a time.
    getIt.registerSingleton<ConnectionStatsStore>(ConnectionStatsStore.instance);
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    // 0 is what `normalizeServerStatusRefreshSeconds` reads as off; its
    // periodic timer would otherwise outlive the tree and fail the run.
    Stores.setting.serverStatusUpdateInterval.put(0);
    // The globe would take the page instead of the grid.
    Stores.setting.globeEnabled.put(false);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  void addServers() {
    for (final (i, name) in ['web', 'db'].indexed) {
      Stores.server.put(
        spiFixture(
          id: 'srv-$i',
          name: name,
          ip: 'h$i',
          user: 'u',
          autoConnect: false,
        ),
      );
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
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
          home: const ServerPage(),
        ),
      ),
    );
    await settle(tester);
    // Unmounted before the test ends: this page holds a periodic refresh
    // timer, and one still pending at teardown is an assertion failure.
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  String? openId(WidgetTester tester) {
    // Not skipping offstage: a narrow window pushes a page over this one,
    // and a route under the top one is offstage rather than gone.
    final ctx = tester.element(find.byType(ServerPage, skipOffstage: false));
    return ProviderScope.containerOf(ctx).read(serverSelectionProvider);
  }

  testWidgets('a card opens where it is, and the list is still the page', (
    tester,
  ) async {
    addServers();
    await pump(tester, size: const Size(1200, 900));
    expect(find.byType(ServerCard), findsNWidgets(2));

    await tester.tap(find.text('web'));
    await settle(tester);

    expect(openId(tester), 'srv-0');
    // One card left — the one that was opened — and the page under it.
    expect(find.byType(ServerDetailPage), findsOneWidget);
    // Both machines are still reachable from the strip over it, which is what
    // the list has become rather than something new to learn.
    expect(find.text('db'), findsWidgets);
  });

  testWidgets('and the way back puts every card in the grid', (tester) async {
    addServers();
    await pump(tester, size: const Size(1200, 900));

    await tester.tap(find.text('web'));
    await settle(tester);
    expect(openId(tester), isNotNull);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await settle(tester);

    expect(openId(tester), isNull);
    expect(find.byType(ServerDetailPage), findsNothing);
    expect(find.byType(ServerCard), findsNWidgets(2));
  });

  testWidgets('nothing is thrown at any point of the movement', (tester) async {
    // The card is laid out at every width between a column and the page, and
    // its contents are laid out for each of them: a row that fits at 330 and
    // not at 1200, or the other way round, is an overflow in the middle of an
    // animation and nowhere else.
    addServers();
    await pump(tester, size: const Size(1200, 900));

    await tester.tap(find.text('web'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 12));
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 12));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('a narrow window pushes a page instead', (tester) async {
    // One column has nothing to grow into: the card already has the width, so
    // growing it would only make it taller.
    addServers();
    await pump(tester, size: const Size(420, 900));

    await tester.tap(find.text('web'));
    await settle(tester);

    // Never connected, so what a tap can usefully offer is the editor — the
    // branch below the width check, which is what says the check took.
    expect(openId(tester), isNull);
    expect(find.byType(ServerPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('escape is the same way back as the arrow', (tester) async {
    addServers();
    await pump(tester, size: const Size(1200, 900));

    await tester.tap(find.text('web'));
    await settle(tester);
    expect(openId(tester), isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);

    expect(openId(tester), isNull);
  });

  testWidgets('and the bracket keys step to the next machine', (tester) async {
    addServers();
    await pump(tester, size: const Size(1200, 900));

    await tester.tap(find.text('web'));
    await settle(tester);
    expect(openId(tester), 'srv-0');

    // The page's own answer to which modifier this platform uses, so the test
    // presses the key the binding is actually registered under.
    final modifier = Platform.isMacOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
    await tester.sendKeyUpEvent(modifier);
    await settle(tester);

    // Wrapping is the point at the ends of a two-server list, but here it is
    // simply the next one.
    expect(openId(tester), 'srv-1');
  });

  testWidgets('the card is laid out at every width on the way', (tester) async {
    // The movement is the card taking the page's width, not a page replacing
    // it: at the halfway point it has to be wider than the column it left and
    // narrower than the page it is going to. A cut would be neither.
    addServers();
    await pump(tester, size: const Size(1200, 900));

    final column = tester.getRect(find.byType(ServerCard).first).width;

    await tester.tap(find.text('web'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 175));

    final open = find.ancestor(
      of: find.text('web'),
      matching: find.byType(ServerCard),
    );
    final midway = tester.getRect(open).width;
    expect(midway, greaterThan(column));
    expect(midway, lessThan(1200));

    // And by the end of the growth it has the page, less what the grid keeps
    // clear at the edges and what a card's own margin takes. Measured before
    // the readings take over from it, which is what the growth finishing is
    // the cue for.
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.getRect(open).width, greaterThan(1100));
  });

  testWidgets('and nothing moves when the page takes the card over', (
    tester,
  ) async {
    // The point of the whole movement: the chart and the rows are the same
    // widgets from the grid to the page, so at the moment the page takes over
    // they have to be exactly where the card had them. A handover that shifts
    // them reads as the card having been replaced by a picture of itself.
    addServers();
    await pump(tester, size: const Size(1200, 900));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServerPage, skipOffstage: false)),
    );
    final status = ServerStatus(
      cpu: Cpus(),
      mem: const Memory(total: 1048576, free: 524288, avail: 524288),
      disk: const [],
      tcp: const Conn(maxConn: 0, fail: 0),
      netSpeed: NetSpeed(),
      swap: const Swap(total: 0, free: 0, cached: 0),
      temps: Temperatures(),
      system: SystemType.linux,
      diskIO: DiskIO(),
    );
    status.more[StatusCmdType.uptime] = 'up 3 days';
    status.history.add(timeMs: DateTime.now().millisecondsSinceEpoch, mem: 50);
    final notifier = container.read(serverProvider('srv-0').notifier);
    notifier.updateStatus(status);
    // The card draws readings only for a machine that has answered, which is
    // what `finished` means — a status alone is what it last said.
    notifier.updateConnection(ServerConn.finished);
    await settle(tester);
    expect(find.text('CPU'), findsWidgets);

    await tester.tap(find.text('web'));
    await tester.pump();
    // Grown, but the page has not taken over yet: that happens when the
    // growth finishes.
    await tester.pump(const Duration(milliseconds: 340));
    final grownLabel = tester.getRect(find.text('CPU').first);
    final grownRow = tester.getRect(find.text(libL10n.memory).first);

    // Past the handover and its crossing.
    await settle(tester);
    expect(find.byType(ServerDetailPage), findsOneWidget);

    expect(
      tester.getRect(find.text('CPU').first),
      rectMoreOrLessEquals(grownLabel, epsilon: 2),
    );
    expect(
      tester.getRect(find.text(libL10n.memory).first),
      rectMoreOrLessEquals(grownRow, epsilon: 2),
    );
  });

  testWidgets('stepping to the next machine comes in from the right', (
    tester,
  ) async {
    // Which way through the list a step went is the one thing a cross-fade
    // cannot say, and it is the reason a list has an order.
    addServers();
    await pump(tester, size: const Size(1200, 900));

    await tester.tap(find.text('web'));
    await settle(tester);
    expect(find.byType(DirectionalSwap), findsOneWidget);

    final modifier = Platform.isMacOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
    await tester.sendKeyUpEvent(modifier);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    // Both machines on screen: the one being left, and the one arriving from
    // the side the list runs towards.
    final pages = tester.widgetList<ServerDetailPage>(
      find.byType(ServerDetailPage),
    );
    expect(pages.length, 2);
    final rects = find
        .byType(ServerDetailPage)
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)).left)
        .toList();
    // The arriving one is to the right of the one it is replacing.
    expect(rects[1], greaterThan(rects[0]));

    await settle(tester);
    expect(find.byType(ServerDetailPage), findsOneWidget);
    expect(openId(tester), 'srv-1');
  });
}
