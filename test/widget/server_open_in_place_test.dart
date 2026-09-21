import 'dart:io';
import 'dart:ui' show lerpDouble;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/gestures.dart';
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
import 'package:server_box/view/page/server/card/density.dart';
import 'package:server_box/view/page/server/card/overview.dart';
import 'package:server_box/view/page/server/card/swap.dart';
import 'package:server_box/view/page/server/chart.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/server/metric_row.dart';
import 'package:server_box/view/page/server/tab/tab.dart';
import 'package:server_box/view/widget/server_func_btns.dart';

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

  /// [expanded] unfolds both cards' rows, which is not what a card rests at
  /// but is what most of this file measures: the rows a card shows are the
  /// ones that can be compared between the card and the page.
  ///
  /// Said about the two cards rather than by switching "UI Fold" off, which
  /// would also change what the page they open into unfolds.
  void addServers({bool expanded = true}) {
    if (expanded) {
      Stores.setting.serverCardExpandedOverride.put({
        'srv-0': true,
        'srv-1': true,
      });
    }
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

  /// Has a machine answer — the first, unless [id] names another — so its
  /// card has readings to draw.
  ///
  /// [everything] adds a swap and a disk to the memory, so the swap sits
  /// between two of the card's own rows. With [sensor] the one slot that varies
  /// goes to the sensor and the swap has no row on the card; without it the
  /// swap takes that slot and is a row of the card's.
  Future<void> answer(
    WidgetTester tester, {
    String id = 'srv-0',
    bool everything = false,
    bool sensor = true,
  }) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServerPage, skipOffstage: false)),
    );
    final status = ServerStatus(
      cpu: Cpus(),
      mem: const Memory(total: 1048576, free: 524288, avail: 524288),
      disk: [
        if (everything)
          Disk(
            path: '/dev/sda1',
            mount: '/',
            usedPercent: 40,
            used: BigInt.from(4000000),
            size: BigInt.from(10000000),
            avail: BigInt.from(6000000),
          ),
      ],
      tcp: const Conn(maxConn: 0, fail: 0),
      netSpeed: NetSpeed(),
      swap: everything
          ? const Swap(total: 1048576, free: 786432, cached: 0)
          : const Swap(total: 0, free: 0, cached: 0),
      temps: Temperatures()
        ..setAll({if (everything && sensor) 'coretemp': 41.0}),
      system: SystemType.linux,
      diskIO: DiskIO(),
    );
    status.more[StatusCmdType.uptime] = 'up 3 days';
    // Enough of a window for there to be a line: with nothing stored the page
    // draws a sentence where the chart goes, which is a different thing again.
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 8; i++) {
      status.history.add(timeMs: now - (8 - i) * 3000, cpu: 10.0 + i, mem: 50);
    }
    final notifier = container.read(serverProvider(id).notifier);
    notifier.updateStatus(status);
    // The card draws readings only for a machine that has answered, which is
    // what `finished` means — a status alone is what it last said.
    notifier.updateConnection(ServerConn.finished);
    await settle(tester);
    expect(find.text('CPU'), findsWidgets);
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

  testWidgets('and so does the full-screen pager, however wide it is', (
    tester,
  ) async {
    // The pager draws one card at a time and no grid, so there is nothing for
    // a card to grow out of and nowhere for the detail to be drawn. The tap
    // asked the window's width instead of the layout, so in a wide window it
    // selected the server and started the movement with nothing on screen to
    // show either: the tap did nothing visible, and the selection it left
    // behind opened that server the next time the list was the layout.
    addServers();
    Stores.setting.fullScreen.put(true);
    await pump(tester, size: const Size(1200, 700));
    expect(find.byType(PageView), findsOneWidget);

    await tester.tap(find.text('web'));
    await settle(tester);

    // Never connected, so what the tap offers is the editor, as a page.
    expect(openId(tester), isNull);
    expect(find.byType(ServerEditPage), findsOneWidget);

    // And one that has answered gets its own page, pushed the same way.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    await answer(tester);
    await tester.tap(find.text('web'));
    await settle(tester);

    expect(openId(tester), isNull);
    expect(find.byType(ServerDetailPage), findsOneWidget);
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
    await answer(tester);

    await tester.tap(find.text('web'));
    await tester.pump();
    // Grown, but the page has not taken over yet: that happens when the
    // growth finishes.
    await tester.pump(const Duration(milliseconds: 340));
    // Two trees are on screen here: the card, which is drawing the readings,
    // and the page under it, which is laid out so that its own facts can be
    // placed against them and paints none of it until the handover. So both
    // ends of the handover can be measured on this one frame, and the frames
    // either side of it measured against each other as well.
    Finder inCard(Finder f) =>
        find.descendant(of: find.byType(AnimatedMasonry), matching: f);
    Finder inPage(Finder f) =>
        find.descendant(of: find.byType(ServerDetailPage), matching: f);

    final grownLabel = tester.getRect(inCard(find.text('CPU')).first);
    final grownRow = tester.getRect(inCard(find.text(libL10n.memory)).first);
    // The card is drawing the page's own chart by now, not a picture of one:
    // a bar sparkline cannot become a line chart by moving, so the box
    // travels and what is in it crosses over on the way.
    expect(inCard(find.byType(MetricChart)), findsOneWidget);
    final grownChart = tester.getRect(inCard(find.byType(MetricChart)));
    // And the rows are the page's own rows, not a second set drawn from the
    // same numbers.
    final grownRows = inCard(find.byType(MetricRow)).evaluate().length;
    final firstRow = tester.getRect(inCard(find.byType(MetricRow)).first);

    // The page is already laid out exactly where the card has arrived.
    expect(
      tester.getRect(inPage(find.byType(MetricChart))),
      rectMoreOrLessEquals(grownChart, epsilon: 2),
    );

    // Past the handover, where the grid is dropped and the page starts
    // painting what it had been holding room for.
    await settle(tester);
    expect(find.byType(ServerDetailPage), findsOneWidget);
    expect(find.byType(AnimatedMasonry), findsNothing);

    expect(
      tester.getRect(find.text('CPU').first),
      rectMoreOrLessEquals(grownLabel, epsilon: 2),
    );
    expect(
      tester.getRect(find.text(libL10n.memory).first),
      rectMoreOrLessEquals(grownRow, epsilon: 2),
    );
    expect(find.byType(MetricChart), findsOneWidget);
    expect(
      tester.getRect(find.byType(MetricChart)),
      rectMoreOrLessEquals(grownChart, epsilon: 2),
    );
    expect(find.byType(MetricRow).evaluate().length, grownRows);
    expect(
      tester.getRect(find.byType(MetricRow).first),
      rectMoreOrLessEquals(firstRow, epsilon: 2),
    );
  });

  // The near end of the same movement. Everything about the card is a lerp on
  // how far it has got, so the frame after it starts and the frame before it
  // stops are the card at rest, to within nothing anyone could see. What
  // breaks that is never a lerp — it is something that is one thing at any
  // openness above 0 and another at 0, which is a cut on exactly those two
  // frames. Four of them made the way back end in one: the chart held at the
  // height it had halfway, a full gap for each row that had shrunk to nothing,
  // a bar at half its length beside a note nobody could see, and a row the
  // card draws in a different place from the page.
  Future<void> restsAsItMoves(
    WidgetTester tester, {
    required bool sensor,
    bool expanded = true,
  }) async {
    addServers(expanded: expanded);
    await pump(tester, size: const Size(1200, 900));
    await answer(tester, everything: true, sensor: sensor);

    final card = find.ancestor(
      of: find.text('web'),
      matching: find.byType(ServerCard),
    );
    Finder inCard(Finder f) => find.descendant(of: card, matching: f);
    double openness() => tester.widget<ServerCard>(card).openness;

    // The rows the card draws at rest, which are the ones that can be compared
    // at both ends. With a sensor the swap between them has no slot on the
    // card; without one it has, and used to be drawn after the disk there and
    // before it on the page.
    //
    // Folded there are none, and what is compared is the card and its chart:
    // every row grows in from nothing, and the line under them goes the same
    // way, so neither may be a height the card has at 0 and not just past it.
    final rows = expanded
        ? [libL10n.memory, if (!sensor) 'Swap', libL10n.disk]
        : const <String>[];
    Map<String, Rect> geometry() => {
      'card': tester.getRect(card),
      'chart': tester.getRect(inCard(find.byType(MetricChart))),
      for (final label in rows) ...{
        label: tester.getRect(inCard(find.widgetWithText(MetricRow, label))),
        '$label bar': tester.getRect(
          find.descendant(
            of: inCard(find.widgetWithText(MetricRow, label)),
            matching: find.byType(LinearProgressIndicator),
          ),
        ),
      },
    };
    void expectSame(Map<String, Rect> moving, Map<String, Rect> rest) {
      for (final MapEntry(key: what, value: rect) in rest.entries) {
        expect(
          moving[what],
          rectMoreOrLessEquals(rect, epsilon: 1),
          reason: '$what, against $rect at rest',
        );
      }
    }

    // The chart's box is a lerp like the rest, on every frame and not only at
    // the ends: the chart inside it is held unbuilt for half of the movement,
    // and a height that was part of what is held stops following for that
    // half and jumps when it is let go.
    void expectChartFollows() {
      final hero = tester.widget<ServerCard>(card);
      final open = hero.pageWidth >= ServerCardSizes.columnsWidth
          ? ServerCardSizes.openChart
          : ServerCardSizes.openChartNarrow;
      expect(
        tester.getRect(inCard(find.byType(MetricChart))).height,
        moreOrLessEquals(
          lerpDouble(ServerCardSizes.chart, open, hero.openness)!,
          epsilon: 0.5,
        ),
        reason: 'the chart at ${hero.openness}',
      );
    }

    final atRest = geometry();

    // A millisecond at a time, which no display does: a frame's worth of the
    // movement is a couple of points of width already, and what is being
    // asked here is what the card is *next to* rest, not a frame away from it.
    const tick = Duration(milliseconds: 1);
    const frame = Duration(milliseconds: 16);

    await tester.tap(find.text('web'));
    await tester.pump();
    await tester.pump(tick);
    expect(openness(), inExclusiveRange(0, 0.001));
    expectSame(geometry(), atRest);
    // The rest of the way in, until the page takes the readings over and the
    // grid is dropped.
    for (var i = 0; i < 30 && card.evaluate().isNotEmpty; i++) {
      expectChartFollows();
      await tester.pump(frame);
    }

    await settle(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    // The chrome leaves first, and the card starts back once it has.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    // Through the middle a frame at a time, because where the hold starts is
    // what decides what is held.
    for (var i = 0; i < 21; i++) {
      await tester.pump(frame);
      expectChartFollows();
    }
    Map<String, Rect>? last;
    for (var i = 0; i < 30; i++) {
      await tester.pump(tick);
      if (openness() <= 0) break;
      last = geometry();
    }
    expect(openness(), 0);
    expect(last, isNotNull);

    await settle(tester);
    expectSame(geometry(), atRest);
    expectSame(last!, atRest);
  }

  testWidgets(
    'nor when the card leaves the grid, or comes to rest in it',
    (tester) => restsAsItMoves(tester, sensor: true),
  );

  testWidgets(
    'and a row the card draws is where the page draws it',
    (tester) => restsAsItMoves(tester, sensor: false),
  );

  testWidgets(
    'nor with its rows folded, which is what a card rests at',
    (tester) => restsAsItMoves(tester, sensor: true, expanded: false),
  );

  /// The control that unfolds a card's rows, or folds them: [label] is which.
  ///
  /// By what it says it does rather than by its arrow. It is one arrow that
  /// turns, and folded there are two of it in the tree: the line the control
  /// shares keeps room for it with a copy of its face that is not drawn.
  Finder foldControl(String id, String label) => find.descendant(
    of: find.byWidgetPredicate((w) => w is ServerCard && w.srv.spi.id == id),
    matching: find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
    ),
  );

  testWidgets('a card keeps its rows folded or not through being opened', (
    tester,
  ) async {
    // Not the card's own state: the grid is dropped while a machine is open
    // and mounted again for the way back, so a card that remembered this for
    // itself would come back folded from every visit.
    addServers(expanded: false);
    await pump(tester, size: const Size(1200, 900));
    await answer(tester);

    final card = find.byWidgetPredicate(
      (w) => w is ServerCard && w.srv.spi.id == 'srv-0',
    );
    Finder inCard(Finder f) => find.descendant(of: card, matching: f);

    expect(inCard(find.byType(MetricRow)), findsNothing);
    final folded = tester.getSize(card).height;

    await tester.tap(foldControl('srv-0', libL10n.more));
    await settle(tester);
    expect(inCard(find.byType(MetricRow)), findsWidgets);
    expect(Stores.setting.serverCardExpandedOverride.fetch(), {'srv-0': true});
    final unfolded = tester.getSize(card).height;
    expect(unfolded, greaterThan(folded));

    // The press was the line's, not the card's.
    expect(openId(tester), isNull);

    await tester.tap(find.text('web'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await settle(tester);
    expect(inCard(find.byType(MetricRow)), findsWidgets);
    expect(tester.getSize(card).height, moreOrLessEquals(unfolded, epsilon: 1));

    await tester.tap(foldControl('srv-0', libL10n.fold));
    await settle(tester);
    expect(inCard(find.byType(MetricRow)), findsNothing);
    // Back to what the setting says, which is no opinion about this card.
    expect(Stores.setting.serverCardExpandedOverride.fetch(), isEmpty);
    expect(tester.getSize(card).height, moreOrLessEquals(folded, epsilon: 1));
  });

  testWidgets('how much of each machine is drawn is one word in the bar, and '
      'four under a pointer', (tester) async {
    // Four labelled positions were the widest thing in a bar they are the
    // least used part of. It rests as the one it is set to, drawn as the same
    // control, and opens where it stands.
    addServers();
    await pump(tester, size: const Size(1200, 900));

    final control = find.byType(SegmentedTabs<ServerListDensity>);
    final closed = tester.getRect(control);
    bool shown(ServerListDensity density) {
      final label = tester.getRect(
        find.descendant(of: control, matching: find.text(density.label)),
      );
      final box = tester.getRect(control);
      return label.left >= box.left && label.right <= box.right;
    }

    expect(shown(ServerListDensity.auto), isTrue);
    expect(shown(ServerListDensity.rows), isFalse);
    expect(find.text(ServerListDensity.rows.label).hitTestable(), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(closed.center);
    await settle(tester);

    final open = tester.getRect(control);
    expect(open.width, greaterThan(closed.width * 2));
    // What comes after it in the bar has not moved: it opens into the room
    // the switcher on its other side was given.
    expect(open.right, closed.right);
    for (final density in ServerListDensity.values) {
      expect(shown(density), isTrue, reason: density.name);
    }

    await tester.tap(find.text(ServerListDensity.rows.label));
    await settle(tester);
    expect(
      tester.widget<ServerCard>(find.byType(ServerCard).first).density,
      ServerListDensity.rows,
    );

    await mouse.moveTo(Offset.zero);
    await settle(tester);
    expect(tester.getRect(control).width, lessThan(open.width / 2));
    expect(shown(ServerListDensity.rows), isTrue);
    expect(shown(ServerListDensity.auto), isFalse);
  });

  testWidgets('auto is what the window shows at once, and follows it', (
    tester,
  ) async {
    // It was the count alone — cards up to six, lines up to twenty-four —
    // which is what one desktop window holds. So a wider one went to lines
    // with room for the cards, and nothing happened when a window was made
    // too narrow for the ones it had.
    for (var i = 0; i < 10; i++) {
      Stores.server.put(
        spiFixture(
          id: 'many-$i',
          name: 'm$i',
          ip: 'h$i',
          user: 'u',
          autoConnect: false,
        ),
      );
    }
    await pump(tester, size: const Size(1200, 900));

    Set<ServerListDensity> drawn() => {
      for (final card in tester.widgetList<ServerCard>(find.byType(ServerCard)))
        card.density,
    };

    // Three columns of four: ten of them fit, where ten used to be lines.
    expect(drawn(), {ServerListDensity.cards});

    // One column, and two screens of it is nine.
    tester.view.physicalSize = const Size(500, 900);
    await settle(tester);
    expect(drawn(), {ServerListDensity.rows});
    // The bar is a button this narrow, and wears what auto came to — which
    // only the grid knows, and tells it a frame later.
    expect(find.byIcon(ServerListDensity.rows.icon), findsOneWidget);

    tester.view.physicalSize = const Size(1200, 900);
    await settle(tester);
    expect(drawn(), {ServerListDensity.cards});
    expect(tester.takeException(), isNull);
  });

  testWidgets('the list is drawn at the size the system asks for, times '
      'its own setting', (tester) async {
    // The setting replaced the system's scale rather than multiplying it. On
    // a phone with its text turned down to 0.82 that was every other page at
    // 0.82 and this one at 1: a list a fifth larger than the bars it sits
    // between, for a reader who had asked for smaller. A desktop has no such
    // setting, which is how long it took to be seen.
    tester.platformDispatcher.textScaleFactorTestValue = 0.82;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addServers();
    await pump(tester, size: const Size(402, 874));

    double scaled(double size) => MediaQuery.textScalerOf(
      tester.element(find.byType(ServerCard).first),
    ).scale(size);

    expect(scaled(100), moreOrLessEquals(82, epsilon: 0.01));
    // The same 0.82 the bar over the list is drawn at, which is outside it.
    expect(
      MediaQuery.textScalerOf(tester.element(find.byType(ServerPage))).scale(100),
      moreOrLessEquals(82, epsilon: 0.01),
    );

    // And the setting still does what it says, on top of that.
    Stores.setting.textFactor.put(1.5);
    await tester.pump();
    expect(scaled(100), moreOrLessEquals(123, epsilon: 0.01));
  });

  testWidgets('what a card nobody has touched rests at is "UI Fold"', (
    tester,
  ) async {
    // A default rather than a starting value: nothing is written for a card
    // until somebody says something about it, so switching the setting moves
    // every card that nobody has — and this tab is kept alive behind the
    // settings page, so it has to be told.
    addServers(expanded: false);
    await pump(tester, size: const Size(1200, 900));
    await answer(tester);
    await answer(tester, id: 'srv-1');

    Finder rowsOf(String id) => find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is ServerCard && w.srv.spi.id == id,
      ),
      matching: find.byType(MetricRow),
    );
    // On, which is what an install starts with: folded.
    expect(Stores.setting.collapseUIDefault.fetch(), isTrue);
    expect(rowsOf('srv-0'), findsNothing);
    expect(rowsOf('srv-1'), findsNothing);

    // One of them is unfolded by hand, and the setting is switched after.
    await tester.tap(foldControl('srv-0', libL10n.more));
    await settle(tester);
    Stores.setting.collapseUIDefault.put(false);
    await settle(tester);
    expect(rowsOf('srv-0'), findsWidgets);
    expect(rowsOf('srv-1'), findsWidgets);
    // What was said about the first now agrees with the setting, and stays
    // said; nothing was written for the second.
    expect(Stores.setting.serverCardExpandedOverride.fetch(), {'srv-0': true});

    // Folding one by hand is the opinion now, and the other still follows.
    await tester.tap(foldControl('srv-1', libL10n.fold));
    await settle(tester);
    expect(rowsOf('srv-1'), findsNothing);
    expect(Stores.setting.serverCardExpandedOverride.fetch(), {
      'srv-0': true,
      'srv-1': false,
    });

    // Unfolded again, it is back to what the setting says: no entry, so it
    // is not held unfolded when the setting is switched back.
    await tester.tap(foldControl('srv-1', libL10n.more));
    await settle(tester);
    expect(Stores.setting.serverCardExpandedOverride.fetch(), {'srv-0': true});

    Stores.setting.collapseUIDefault.put(true);
    await settle(tester);
    expect(rowsOf('srv-0'), findsWidgets);
    expect(rowsOf('srv-1'), findsNothing);
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

  testWidgets('the strip over the list turns over rather than crossing', (
    tester,
  ) async {
    // What the list adds up to and the rest of the list as pills are the two
    // faces of one slot: one height, and never both on screen at once.
    addServers();
    await pump(tester, size: const Size(1200, 900));

    final under = tester.getRect(find.byType(AnimatedMasonry)).top;
    expect(find.byType(ServerOverview), findsOneWidget);
    expect(find.byKey(const ValueKey('switcher')), findsNothing);

    await tester.tap(find.text('web'));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        find.byType(ServerOverview).evaluate().length +
            find.byKey(const ValueKey('switcher')).evaluate().length,
        1,
        reason: 'one face at a time, turned rather than faded past',
      );
    }

    await settle(tester);
    expect(find.byType(ServerOverview), findsNothing);
    expect(find.byKey(const ValueKey('switcher')), findsOneWidget);
    // The same slot at the same height, so what is under it has not moved.
    expect(tester.getRect(find.byType(ServerDetailPage)).top, under);
  });

  testWidgets('and a face at rest is the one that was turning', (tester) async {
    // Each face was handed back bare once the turn was over and wrapped in
    // the turn while it lasted: a different parent at rest, so the face was
    // unmounted and built again on the frame the turn started or stopped. The
    // pills keep a scroll position and work out their faded edges a frame
    // after they are mounted, so the way back began with the row of machines
    // jumping to its start and its edges going hard for a frame.
    addServers();
    await pump(tester, size: const Size(1200, 900));

    Element overview() => tester.element(find.byType(ServerOverview));
    Element switcher() =>
        tester.element(find.byKey(const ValueKey('switcher')));

    final resting = overview();
    await tester.tap(find.text('web'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(identical(overview(), resting), isTrue);

    // Past the halfway point, where the other face is the one turning.
    await tester.pump(const Duration(milliseconds: 240));
    final turning = switcher();
    await settle(tester);
    expect(identical(switcher(), turning), isTrue);

    // And into the way back: past the chrome leaving, a little into the turn.
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    expect(identical(switcher(), turning), isTrue);

    await tester.pump(const Duration(milliseconds: 240));
    final landing = overview();
    await settle(tester);
    expect(identical(overview(), landing), isTrue);
  });

  testWidgets('and it is as far from the bar as the cards are from it', (
    tester,
  ) async {
    // Measured between what is drawn, not between boxes: the strip had no gap
    // above it and 9 below, which with the bar's own 4 and the grid's 8 drew
    // as 4 above and 17 below — the summary read as part of the bar, and the
    // cards as a separate block under it.
    addServers();
    await pump(tester, size: const Size(1200, 900));

    Rect cardOf(String name) => tester.getRect(
      find.ancestor(of: find.text(name), matching: find.byType(ServerCard)),
    );
    // A card's box includes its margin, which is not drawn.
    const margin = 4.0;
    final strip = tester.getRect(find.byType(ServerOverview));
    final control = tester.getRect(
      find.byType(SegmentedTabs<ServerListDensity>),
    );

    final above = strip.top - control.bottom;
    final below = cardOf('web').top + margin - strip.bottom;
    final between = cardOf('db').left + margin - (cardOf('web').right - margin);

    // Under it, the same as between two cards: it is one more block of the
    // same grid.
    expect(below, moreOrLessEquals(between, epsilon: 0.5));
    expect(above, moreOrLessEquals(below, epsilon: 1.5));
  });

  testWidgets('only the card that is opening is rebuilt while it opens', (
    tester,
  ) async {
    // The rest of them do not change: they are drawn fainter, which is a
    // property of a layer and not of a card. Rebuilding them per frame meant
    // every chart on screen being built sixty times a second to fade out.
    addServers();
    await pump(tester, size: const Size(1200, 900));

    ServerCard cardOf(String name) => tester.widget<ServerCard>(
      find.ancestor(of: find.text(name), matching: find.byType(ServerCard)),
    );

    await tester.tap(find.text('web'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final other = cardOf('db');
    final hero = cardOf('web');

    await tester.pump(const Duration(milliseconds: 60));
    // The one growing is a different widget each frame — what it looks like
    // part way is a lerp inside it, so it has to be.
    expect(identical(cardOf('web'), hero), isFalse);
    // The one that is not, is not.
    expect(identical(cardOf('db'), other), isTrue);
  });

  testWidgets('a card opened from under the pointer carries no ink with it', (
    tester,
  ) async {
    // A highlight is painted into the card's `Material` across the whole of
    // what responds to a tap, and not through the card's own colour. So a card
    // opened with the pointer over it grew a full-size sheet of `hoverColor`
    // that outlasted its surface — which looks like the card's background
    // expanding into the page, and only ever happened on the way in.
    addServers();
    await pump(tester, size: const Size(1200, 900));

    Finder inkOf(String name) => find.descendant(
      of: find.ancestor(
        of: find.text(name),
        matching: find.byType(ServerCard),
      ),
      matching: find.byType(InkWell),
    );

    // A card in the grid is a thing to point at, and says so.
    expect(tester.widget<InkWell>(inkOf('web').first).hoverColor, isNull);

    await tester.tap(find.text('web'));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      if (inkOf('web').evaluate().isEmpty) break;
      final ink = tester.widget<InkWell>(inkOf('web').first);
      expect(ink.hoverColor, Colors.transparent);
      expect(ink.splashColor, Colors.transparent);
      expect(ink.highlightColor, Colors.transparent);
    }

    await settle(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await settle(tester);
    expect(tester.widget<InkWell>(inkOf('web').first).hoverColor, isNull);
  });

  testWidgets('nor the ripple of the tap that opened it', (tester) async {
    // `InkResponse` confirms a ripple and stops tracking it before it calls
    // `onTap`, so the transparent `splashColor` the card sets once it is
    // moving never reaches it. The ripple went on expanding for its fade-out,
    // clipped to a card that was growing to the width of the page. A card that
    // opens in place starts none; one that pushes a page still does.
    addServers();

    // Every splash the card's `Material` is painting, whichever factory the
    // platform's theme picked. Highlights are tracked and do go transparent.
    Iterable<InkFeature> ripples() {
      final ink = find.descendant(
        of: find.ancestor(
          of: find.text('web'),
          matching: find.byType(ServerCard),
        ),
        matching: find.byType(InkWell),
      );
      final all =
          (Material.of(tester.element(ink.first)) as dynamic).debugInkFeatures
              as List<InkFeature>?;
      return (all ?? const <InkFeature>[]).where(
        (f) => f is! InkHighlight && f is! NoSplash,
      );
    }

    // Held for longer than the press timeout, which is when a splash starts.
    Future<TestGesture> press() async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('web')),
      );
      await tester.pump(const Duration(milliseconds: 150));
      return gesture;
    }

    // Narrow first, where a tap pushes a page: this is what says the probe
    // above can see a ripple at all.
    await pump(tester, size: const Size(420, 900));
    var gesture = await press();
    expect(ripples(), isNotEmpty);
    await gesture.cancel();
    await settle(tester);

    tester.view.physicalSize = const Size(1200, 900);
    await settle(tester);
    gesture = await press();
    expect(ripples(), isEmpty);
    await gesture.up();
    expect(openId(tester), 'srv-0');
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      if (find.byType(AnimatedMasonry).evaluate().isEmpty) break;
      expect(ripples(), isEmpty);
    }
  });

  testWidgets('and the row of things to do stays where it is', (tester) async {
    // The row floats over the page rather than being part of it, so a step
    // through the list is not something that happens to it. Sliding it along
    // with the page said the buttons had changed when they had not.
    addServers();
    await pump(tester, size: const Size(1200, 900));

    await tester.tap(find.text('web'));
    await settle(tester);
    expect(find.byType(ServerFuncBar), findsOneWidget);
    final at = tester.getRect(find.byType(ServerFuncBar));

    final modifier = Platform.isMacOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
    await tester.sendKeyUpEvent(modifier);

    // Through the whole of the step, including the middle of it where both
    // machines are on screen.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(ServerFuncBar), findsOneWidget);
      expect(tester.getRect(find.byType(ServerFuncBar)), at);
    }

    await settle(tester);
    expect(tester.getRect(find.byType(ServerFuncBar)), at);
  });

  testWidgets('and is the same row from the way in to the way back', (
    tester,
  ) async {
    // It rises and sinks with the card, and once the card had stopped it was
    // handed back without the layers that do that — a different parent at
    // openness 1 from the one at anything less. So the row was unmounted and
    // built again on the last frame of the way in and the first of the way
    // back, and a row that has just been mounted spends its first frames off
    // the bottom of the window: it went out just as the card started to
    // shrink, and came back to fade.
    addServers();
    await pump(tester, size: const Size(1200, 900));

    Element bar() => tester.element(find.byType(ServerFuncBar));

    await tester.tap(find.text('web'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final rising = bar();

    await settle(tester);
    expect(identical(bar(), rising), isTrue);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      // Gone with the card landing, which is the end of it.
      if (find.byType(ServerFuncBar).evaluate().isEmpty) break;
      expect(identical(bar(), rising), isTrue, reason: 'frame $i');
      // And where it belongs rather than past the edge it sits on.
      final slide = tester.widget<AnimatedSlide>(
        find.ancestor(
          of: find.byType(ServerFuncBar),
          matching: find.byType(AnimatedSlide),
        ),
      );
      expect(slide.offset, Offset.zero, reason: 'frame $i');
    }
    expect(find.byType(ServerFuncBar), findsNothing);
  });

  testWidgets('and what the page adds is built once, not at each handover', (
    tester,
  ) async {
    // The facts beside the readings and the tables under them come in with
    // the card, and were handed back without the layers that do that once it
    // had stopped — so all of them were unmounted, built and laid out again
    // on the last frame of the way in and the first of the way back, which is
    // the most there is to build on this page and the least time to do it in.
    addServers();
    await pump(tester, size: const Size(1200, 900));
    await answer(tester);

    Element fact() => tester.element(
      find
          .descendant(
            of: find.byType(ServerDetailPage),
            matching: find.text(libL10n.conn),
          )
          .first,
    );

    await tester.tap(find.text('web'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final entering = fact();

    await settle(tester);
    expect(identical(fact(), entering), isTrue);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    expect(identical(fact(), entering), isTrue);
  });

  testWidgets('the way back is a movement too, not a snap', (tester) async {
    // The expansion used to hang off the selection, which is cleared the
    // moment the way back is taken — so the card was already a card again on
    // the first frame of what was supposed to be it shrinking.
    addServers();
    await pump(tester, size: const Size(1200, 900));

    final column = tester.getRect(find.byType(ServerCard).first).width;

    await tester.tap(find.text('web'));
    await settle(tester);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    // Past the chrome leaving, and part way into the card's own movement.
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump(const Duration(milliseconds: 80));

    final shrinking = tester.getRect(
      find.ancestor(
        of: find.text('web'),
        matching: find.byType(ServerCard),
      ),
    );
    expect(shrinking.width, greaterThan(column));

    await settle(tester);
    expect(
      tester
          .getRect(
            find.ancestor(
              of: find.text('web'),
              matching: find.byType(ServerCard),
            ),
          )
          .width,
      moreOrLessEquals(column, epsilon: 1),
    );
  });

  testWidgets('the readings come in once, not at each end of the movement', (
    tester,
  ) async {
    // A card fills block by block when its machine first answers. That ran
    // whenever the blocks were *mounted*, and the movement mounts them again
    // three times over: the grid is dropped while the page has the readings
    // and mounted for the way back, the open card's body changed parents on
    // the first and last frames, and every other card was wrapped to be faded
    // and unwrapped after. So the readings went out and came back in before
    // the card started shrinking, and again once it had landed.
    addServers();
    await pump(tester, size: const Size(1200, 900));
    await answer(tester);
    await answer(tester, id: 'srv-1');

    // How opaque the card itself draws each machine's memory row. A row both
    // cards have at rest, so nothing about the movement is fading it — and
    // only as far up as the card, which leaves out the layer the other cards
    // are faded through.
    Iterable<double> rows() sync* {
      final labels = find.descendant(
        of: find.byType(AnimatedMasonry),
        matching: find.text(libL10n.memory),
      );
      for (final label in labels.evaluate()) {
        var opacity = 1.0;
        label.visitAncestorElements((e) {
          if (e.widget is ServerCard) return false;
          if (e.widget case Opacity(opacity: final o)) opacity *= o;
          return true;
        });
        yield opacity;
      }
    }

    expect(rows(), [1.0, 1.0]);

    await tester.tap(find.text('web'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      // The page has taken the readings over, and the grid is gone.
      if (find.byType(AnimatedMasonry).evaluate().isEmpty) break;
      expect(rows(), everyElement(1.0), reason: 'frame $i of the way in');
    }

    await settle(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    // From the chrome leaving to well past the card landing.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(rows(), [1.0, 1.0], reason: 'frame $i of the way back');
    }
    expect(openId(tester), isNull);
  });

  testWidgets('and no card is built again from nothing at either end', (
    tester,
  ) async {
    // What the above was a symptom of, for the cards that are not the one
    // being opened. The layer they are faded through was put around each when
    // a machine opened and taken off when it closed — a different widget at
    // the same place, so every one of them was unmounted and built from
    // nothing on the first frame of the movement and again on the last, which
    // are the two frames with the least time to spare.
    addServers();
    await pump(tester, size: const Size(1200, 900));
    await answer(tester);

    Element cardOf(String id) => tester.element(
      find.byWidgetPredicate((w) => w is ServerCard && w.srv.spi.id == id),
    );

    final hero = cardOf('srv-0');
    final other = cardOf('srv-1');

    await tester.tap(find.text('web'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(identical(cardOf('srv-0'), hero), isTrue);
    expect(identical(cardOf('srv-1'), other), isTrue);

    // The grid is mounted again for the way back, so these are new elements
    // by design — and the same ones from there until the card has landed.
    await settle(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    final heroBack = cardOf('srv-0');
    final otherBack = cardOf('srv-1');

    await settle(tester);
    expect(identical(cardOf('srv-0'), heroBack), isTrue);
    expect(identical(cardOf('srv-1'), otherBack), isTrue);
  });

  testWidgets('the cards that are not being opened never move', (tester) async {
    // They used to be taken out of the list while one was open, so they left
    // and then arrived again: every one of them growing in and shuffling into
    // place, on a page nobody had asked to rearrange. Opening one machine is
    // not something that happens to the others.
    addServers();
    await pump(tester, size: const Size(1200, 900));

    Rect other() => tester.getRect(
      find.ancestor(
        of: find.text('db'),
        matching: find.byType(ServerCard),
      ),
    );

    final atRest = other();

    // Sideways is the whole of it: the strip of machines takes a line above
    // the grid while one is open, so everything under it is that much lower,
    // and that is the strip arriving rather than the grid rearranging.
    void expectStill() {
      expect(other().left, moreOrLessEquals(atRest.left, epsilon: 0.5));
      expect(other().width, moreOrLessEquals(atRest.width, epsilon: 0.5));
    }

    await tester.tap(find.text('web'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expectStill();

    await settle(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    expectStill();

    await settle(tester);
    expect(other(), rectMoreOrLessEquals(atRest, epsilon: 0.5));
  });

  // A line and a tile are a different shape from the card, not the card at a
  // smaller size, so they cannot be a lerp of it. They were swapped for the
  // card on the first frame of the movement and swapped back on the last: the
  // line was 40 tall on one frame and the height of a card on the next, and
  // the grid reserved the card's height for it and moved every line under it.
  // The two shapes are crossed over the start of the movement instead, and
  // the height between them is part of it.
  for (final density in [ServerListDensity.rows, ServerListDensity.grid]) {
    testWidgets('a ${density.name} entry opens from the size it has', (
      tester,
    ) async {
      addServers();
      ServerDensityPref.put(TagSwitcher.kDefaultTag, density);
      await pump(tester, size: const Size(1200, 900));
      await answer(tester, everything: true);

      // The first of them: while the two shapes cross, the name is in both.
      Finder cardOf(String name) => find
          .ancestor(of: find.text(name), matching: find.byType(ServerCard))
          .first;
      double openness() => tester.widget<ServerCard>(cardOf('web')).openness;
      Rect hero() => tester.getRect(cardOf('web'));
      Rect other() => tester.getRect(cardOf('db'));

      final heroAtRest = hero();
      final otherAtRest = other();
      const tick = Duration(milliseconds: 1);
      const frame = Duration(milliseconds: 16);

      await tester.tap(find.text('web'));
      await tester.pump();
      await tester.pump(tick);
      expect(openness(), inExclusiveRange(0, 0.001));
      expect(hero(), rectMoreOrLessEquals(heroAtRest, epsilon: 1));
      expect(other(), rectMoreOrLessEquals(otherAtRest, epsilon: 0.5));

      // No frame of the way in is a jump: the height is part of the movement,
      // which covers about 500 points in 350 ms and peaks near 50 a frame. The
      // swap was over 200 in one, and a cross that eased in and out was 100.
      // Nor is any of them an overflow: a tile is narrower than anything the
      // card's layout was written for.
      var last = hero().height;
      // Until the page takes the readings over and the grid is dropped.
      for (var i = 0; i < 30; i++) {
        if (find.byType(AnimatedMasonry).evaluate().isEmpty) break;
        final now = hero().height;
        expect((now - last).abs(), lessThan(80), reason: 'at ${openness()}');
        expect(tester.takeException(), isNull, reason: 'at ${openness()}');
        last = now;
        await tester.pump(frame);
      }

      await settle(tester);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      for (var i = 0; i < 21; i++) {
        await tester.pump(frame);
      }
      Rect? lastMoving;
      for (var i = 0; i < 30; i++) {
        await tester.pump(tick);
        if (openness() <= 0) break;
        lastMoving = hero();
      }
      expect(openness(), 0);
      // Already the size it rests at, with nothing left to close afterwards.
      expect(lastMoving, rectMoreOrLessEquals(heroAtRest, epsilon: 1));
      expect(hero(), rectMoreOrLessEquals(heroAtRest, epsilon: 1));
      expect(other(), rectMoreOrLessEquals(otherAtRest, epsilon: 0.5));
    });
  }
}
