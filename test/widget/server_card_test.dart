import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/temp.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/card/card.dart';
import 'package:server_box/view/page/server/card/density.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/chart.dart';
import 'package:server_box/view/page/server/metric_row.dart';
import 'package:server_box/view/page/server/tab/tab.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

/// What a card draws once its server has answered.
///
/// The gesture tests next door only ever reach a server that never connected,
/// which is the one shape of this card with no readings on it at all — so the
/// chart, the rows and the promotion that swaps between them were covered by
/// nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-card2-');
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    // The list draws what has happened to these machines lately, which is
    // the one thing in the app that records a time.
    getIt.registerSingleton<ConnectionStatsStore>(ConnectionStatsStore.instance);
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    Stores.setting.serverStatusUpdateInterval.put(0);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  /// [everything] adds a disk and a swap to the memory: the disk is the third
  /// reading a line's bar holds, and the swap is one it does not.
  ///
  /// [sensor] adds a temperature, which takes the one slot that varies — so
  /// with [everything] the swap has no slot on the card at all.
  ///
  /// [samples] is how many polls it has answered. Two is the least a window
  /// can be drawn from, and what most of these are about is a card with one.
  ///
  /// [differenced] leaves the CPU out of the first of them, which is how a
  /// machine actually reports it: the share of the counters between two
  /// reads has no value at the first read. [lastAgo] is how long ago the last
  /// of them was taken.
  ServerStatus sampled({
    bool everything = false,
    bool sensor = false,
    int samples = 2,
    bool differenced = false,
    Duration lastAgo = const Duration(seconds: 3),
    String uptime = 'up 3 days',
  }) {
    final ss = ServerStatus(
      cpu: Cpus(),
      // 1 GiB, half of it gone.
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
      temps: Temperatures()..setAll({if (sensor) 'coretemp': 41.0}),
      system: SystemType.linux,
      diskIO: DiskIO(),
    );
    // What says a status came back at all — see `serverNeverSampled`.
    ss.more[StatusCmdType.uptime] = uptime;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < samples; i++) {
      ss.history.add(
        timeMs: now - lastAgo.inMilliseconds - (samples - 1 - i) * 3000,
        cpu: differenced && i == 0 ? null : 10.0 + i,
        mem: 50,
      );
    }
    return ss;
  }

  Future<void> pump(
    WidgetTester tester, {
    required ServerMetricKind? promoted,
    required void Function(ServerMetricKind) onPromote,
    ServerListDensity density = ServerListDensity.cards,
    double width = 600,
    bool everything = false,
    bool sensor = false,
    int samples = 2,
    bool differenced = false,
    Duration lastAgo = const Duration(seconds: 3),
    String uptime = 'up 3 days',
    ServerConn conn = ServerConn.finished,
    // Unfolded unless a test is about the fold: what most of these are about
    // is the rows, and a card rests without any.
    bool expanded = true,
    VoidCallback? onToggleExpanded,
  }) async {
    tester.view.physicalSize = Size(width, 900);
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
          home: Scaffold(
            body: ServerCard(
              srv: ServerState(
                spi: spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u'),
                status: sampled(
                  everything: everything,
                  sensor: sensor,
                  samples: samples,
                  differenced: differenced,
                  lastAgo: lastAgo,
                  uptime: uptime,
                ),
                conn: conn,
              ),
              promoted: promoted,
              onPromote: onPromote,
              expanded: expanded,
              onToggleExpanded: onToggleExpanded ?? () {},
              onTap: () {},
              density: density,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the reading drawn in full is not repeated as a row', (
    tester,
  ) async {
    await pump(tester, promoted: null, onPromote: (_) {});

    // CPU leads, so it is the headline — and the row list under it is the rest.
    expect(find.text('CPU'), findsOneWidget);
    expect(find.text(libL10n.memory), findsOneWidget);
  });

  group('a card at rest', () {
    // The way to the rest of the readings, and the way back: the count and
    // the arrow are one control, and which of the two it is, is what it says
    // it does. Found by that rather than by its arrow or its count, because
    // the line it shares folded keeps room for it with a copy of its face
    // that is not drawn — see `ServerCardFocus._under`.
    Finder control(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
    );
    final unfold = control(libL10n.more);
    final fold = control(libL10n.fold);
    Finder said(Finder control, String text) =>
        find.descendant(of: control, matching: find.text(text));

    // What the machine in [pump] reports, to count against.
    ServerCardReadings readingsOf({bool everything = false}) =>
        serverCardReadings(
          ServerState(
            spi: spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u'),
            // A sensor whenever there is a swap, so that one of the two is
            // left without a slot.
            status: sampled(everything: everything, sensor: everything),
            conn: ServerConn.finished,
          ),
        );

    testWidgets('is one reading, and says how many it is not showing', (
      tester,
    ) async {
      var pressed = 0;
      await pump(
        tester,
        promoted: null,
        onPromote: (_) {},
        expanded: false,
        onToggleExpanded: () => pressed++,
      );

      expect(find.text('CPU'), findsOneWidget);
      expect(find.byType(MetricRow), findsNothing);
      // Every reading but the one drawn in full.
      final unseen = readingsOf().all.length - 1;
      expect(said(unfold, '+$unseen ${libL10n.more}'), findsOneWidget);

      expect(fold, findsNothing);
      await tester.tap(unfold);
      expect(pressed, 1);
    });

    testWidgets('has that control on its last line, after what the reading '
        'is of', (tester) async {
      // A line of its own under a rule was a third of a folded card's height
      // spent on saying there is more. The note starts at the left because it
      // is sharing the line; unfolded the line is its own and it is a caption
      // under the middle of the chart again — and it travels there, with the
      // control closing beside it, rather than being there on the next frame.
      Future<void> show({required bool expanded}) => pump(
        tester,
        // Memory, because its note is never empty: a machine in a test has
        // no CPU model to put under the CPU's chart.
        promoted: ServerMetricKind.mem,
        onPromote: (_) {},
        expanded: expanded,
      );
      final note = find.textContaining(' / ');
      Rect chart() => tester.getRect(find.byType(MetricChart));

      await show(expanded: false);
      expect(note, findsOneWidget);
      expect(find.byType(Divider), findsNothing);
      final folded = tester.getRect(note);
      final pressed = tester.getRect(
        find.descendant(of: unfold, matching: find.byType(InkWell)),
      );
      expect(folded.left, moreOrLessEquals(chart().left, epsilon: 0.5));
      expect(pressed.right, moreOrLessEquals(chart().right, epsilon: 0.5));
      expect(pressed.left, greaterThanOrEqualTo(folded.right));
      expect(
        pressed.center.dy,
        moreOrLessEquals(folded.center.dy, epsilon: 0.5),
      );

      await show(expanded: true);
      await tester.pump(const Duration(milliseconds: 60));
      final moving = tester.getRect(note);
      expect(moving.left, greaterThan(folded.left));
      // The same line it was on: the height is stated, so the control
      // arriving or leaving does not move the text up or down.
      expect(moving.top, moreOrLessEquals(folded.top, epsilon: 0.5));

      await tester.pump(const Duration(milliseconds: 500));
      final unfolded = tester.getRect(note);
      expect(
        unfolded.center.dx,
        moreOrLessEquals(chart().center.dx, epsilon: 0.5),
      );
      expect(unfolded.left, greaterThan(moving.left));
      expect(unfolded.top, moreOrLessEquals(folded.top, epsilon: 0.5));
      expect(unfold, findsNothing);
      expect(fold, findsOneWidget);
    });

    testWidgets('and that control travels to the line under the rows, as '
        'one control', (tester) async {
      // It closed where it was while another opened under the rows — which
      // the card, growing by uncovering what was already laid out at its full
      // height, did not show until it had finished. So the thing that had
      // just been pressed went away under the finger, with the ink of the
      // press cut off in it.
      Future<void> show({required bool expanded}) => pump(
        tester,
        promoted: ServerMetricKind.mem,
        onPromote: (_) {},
        everything: true,
        expanded: expanded,
      );
      final pressed = find.descendant(
        of: find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label == libL10n.more ||
                  w.properties.label == libL10n.fold),
        ),
        matching: find.byType(InkWell),
      );
      Rect control() => tester.getRect(pressed);
      double under() =>
          tester.getRect(find.byType(ServerCard)).bottom - control().bottom;

      await show(expanded: false);
      final ink = tester.element(pressed);
      final folded = control();
      final kept = under();

      // [pressedIn] is the control as it was when it was pressed, and
      // [frames] how many of these it is still on its way for.
      Future<List<double>> travel(Rect pressedIn, {required int frames}) async {
        final tops = <double>[];
        // The box the press landed in. Ink is placed from its top left and
        // heads for its middle, so one that is made wider or narrower by the
        // press — as wide as the line, or by what it counts changing — takes
        // the ripple out from under the finger and across the card. It was:
        // from the right of the line to the left of it, then to the middle on
        // the way down.
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          tops.add(control().top);
          if (i < frames) {
            expect(control().size, pressedIn.size, reason: '$i');
            expect(control().right, pressedIn.right, reason: '$i');
          }
          // Held to the bottom of the card the whole way. That is what
          // travelling with it is, and what not being behind its clip is.
          // To within a point: the card is a frame behind the first change
          // in what it holds, which is that frame's share of the movement.
          expect(under(), moreOrLessEquals(kept, epsilon: 1), reason: '$i');
        }
        return tops;
      }

      await show(expanded: true);
      final down = await travel(folded, frames: 22);
      expect(tester.element(pressed), same(ink));
      expect(down.last, greaterThan(folded.top + 50));
      expect(
        down.where((top) => top > folded.top + 5 && top < down.last - 5),
        isNotEmpty,
        reason: 'it was in neither place on the way',
      );
      for (var i = 1; i < down.length; i++) {
        expect(down[i], greaterThanOrEqualTo(down[i - 1] - 0.01));
      }
      expect(
        control().right,
        moreOrLessEquals(folded.right, epsilon: 0.5),
      );

      // And back, with the rows it is over still there to be folded away
      // rather than gone on the frame it set off.
      final unfolded = control();
      await show(expanded: false);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MetricRow), findsWidgets);
      final up = await travel(unfolded, frames: 15);
      expect(tester.element(pressed), same(ink));
      expect(find.byType(MetricRow), findsNothing);
      expect(up.last, moreOrLessEquals(folded.top, epsilon: 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('unfolded, counts only what still has no row', (tester) async {
      await pump(
        tester,
        promoted: null,
        onPromote: (_) {},
        everything: true,
        sensor: true,
      );

      final readings = readingsOf(everything: true);
      expect(
        find.byType(MetricRow),
        findsNWidgets(readings.shown.length - 1),
      );
      expect(fold, findsOneWidget);
      expect(said(fold, '+1 ${libL10n.more}'), findsOneWidget);
    });

    testWidgets('a reading promoted from outside the slots is not counted', (
      tester,
    ) async {
      // What the card says is unseen is counted from what is not drawn, not
      // from how many of the five slots are left. A reading from outside them
      // that is drawn in full is not in a slot and is on screen, so counting
      // slots called it unseen — which the control beside the name makes an
      // ordinary thing to do.
      final readings = readingsOf(everything: true);
      final outside = readings.all.firstWhereOrNull(
        (m) => !readings.shown.contains(m),
      );
      expect(outside, isNotNull, reason: 'a machine with a sixth reading');

      await pump(
        tester,
        promoted: outside!.kind,
        onPromote: (_) {},
        everything: true,
        sensor: true,
      );
      // All five are on screen: the one drawn in full, and a row for each of
      // the four slots. So there is nothing to count, and nothing is said.
      expect(find.byType(MetricRow), findsNWidgets(readings.shown.length));
      expect(find.textContaining(libL10n.more), findsNothing);
      expect(fold, findsOneWidget);
    });

    testWidgets('chooses what is drawn in full beside its name', (
      tester,
    ) async {
      final asked = <ServerMetricKind>[];
      await pump(
        tester,
        promoted: null,
        onPromote: asked.add,
        expanded: false,
      );
      // Folded, so the one place a name other than the CPU's can be is the
      // menu.
      expect(find.text(libL10n.memory), findsNothing);

      await tester.tap(find.byIcon(Icons.unfold_more));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Every reading but the one already there, each with what it reads now.
      final others = readingsOf().all.where(
        (m) => m.kind != ServerMetricKind.cpu,
      );
      for (final m in others) {
        expect(find.text(m.label), findsOneWidget);
      }
      expect(find.text('CPU'), findsOneWidget);

      await tester.tap(find.text(libL10n.memory));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(asked, [ServerMetricKind.mem]);
    });

    testWidgets('and the control is no taller than the line it is on', (
      tester,
    ) async {
      // That line takes the height of what is in it at rest and a stated one
      // from the first frame of opening, so anything taller than the number
      // beside it is a chart that jumps on that frame.
      await pump(tester, promoted: null, onPromote: (_) {});
      final button = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.unfold_more),
          matching: find.byType(InkWell),
        ).first,
      );
      expect(button.height, lessThanOrEqualTo(ServerCardSizes.big));
    });
  });

  group('the window of a reading', () {
    testWidgets('is drawn from the first sample, as a point', (tester) async {
      // Connected and nothing polled into the history yet: a number, and
      // nothing to draw. The card kept the chart's 44 points and the gap over
      // them for a box with nothing in it, which read as a chart that had
      // failed to load rather than as one that had not started.
      await pump(tester, promoted: null, onPromote: (_) {}, samples: 0);
      expect(find.text('CPU'), findsOneWidget);
      expect(find.byType(MetricChart), findsNothing);
      final without = tester.getSize(find.byType(ServerCard)).height;

      LineChartBarData bar() => tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .lineBarsData
          .single;

      // One poll is enough, and the card grows for it. A line cannot be drawn
      // through one sample, so it is a point — holding out for the line was a
      // whole poll's wait on every connection.
      await pump(tester, promoted: null, onPromote: (_) {}, samples: 1);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(MetricChart), findsOneWidget);
      expect(bar().spots, hasLength(1));
      expect(bar().dotData.show, isTrue);
      // In the middle. An axis that is one instant wide puts everything on it
      // at its left edge, which is half of the point outside the plot.
      final lone = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(lone.maxX, greaterThan(lone.minX));
      expect((lone.minX + lone.maxX) / 2, bar().spots.single.x);
      expect(
        tester.getSize(find.byType(ServerCard)).height - without,
        moreOrLessEquals(
          ServerCardSizes.chart + ServerCardSizes.gap,
          epsilon: 0.5,
        ),
      );

      // From two on it is the line, with no dots on it.
      await pump(tester, promoted: null, onPromote: (_) {}, samples: 2);
      await tester.pump(const Duration(milliseconds: 600));
      expect(bar().spots, hasLength(2));
      expect(bar().dotData.show, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reaches both ends of what it is drawn in', (tester) async {
      // It reached neither. The axis ran from the first sample, which has no
      // CPU in it, to the clock, which is later than the last sample by
      // however long ago that was — two stretches with no line in them, and
      // a fifth of the chart each on a machine that has only just answered.
      await pump(
        tester,
        promoted: null,
        onPromote: (_) {},
        samples: 5,
        differenced: true,
      );
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      final spots = data.lineBarsData.single.spots;
      expect(spots, hasLength(4));
      expect(data.minX, spots.first.x);
      expect(data.maxX, spots.last.x);
    });

    testWidgets('and runs on to now once the readings have stopped', (
      tester,
    ) async {
      // The one time the distance to the clock says something, and it is the
      // same gap the page draws its band in.
      final before = DateTime.now().millisecondsSinceEpoch;
      await pump(
        tester,
        promoted: null,
        onPromote: (_) {},
        samples: 5,
        lastAgo: const Duration(minutes: 5),
      );
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      final spots = data.lineBarsData.single.spots;
      expect(data.minX, spots.first.x);
      expect(data.maxX, greaterThanOrEqualTo(before));
    });

    testWidgets('nor for a reading that has no samples of its own', (
      tester,
    ) async {
      // The machine has answered twice and this reading has not been in
      // either: a disk with no history is a share and nothing to plot.
      await pump(
        tester,
        promoted: ServerMetricKind.disk,
        onPromote: (_) {},
        everything: true,
      );
      expect(find.text(libL10n.disk), findsWidgets);
      expect(find.byType(MetricChart), findsNothing);
    });
  });

  group('the readings coming in', () {
    // How opaque the card draws its memory row: every [Opacity] between the
    // two, multiplied.
    double row(WidgetTester tester) {
      var opacity = 1.0;
      tester.element(find.text(libL10n.memory)).visitAncestorElements((e) {
        if (e.widget is ServerCard) return false;
        if (e.widget case Opacity(opacity: final o)) opacity *= o;
        return true;
      });
      return opacity;
    }

    testWidgets('is the machine answering, and nothing else', (tester) async {
      // Block after block, once. What starts it is a card that was on screen
      // without readings getting them — not the blocks being mounted, which
      // happens whenever the grid is: on the way back from an open machine,
      // when a tag is picked, when the globe is left. Each of those played it
      // again, on a card that had had its readings all along.
      await pump(
        tester,
        promoted: null,
        onPromote: (_) {},
        conn: ServerConn.connecting,
      );
      expect(find.text(libL10n.memory), findsNothing);

      await pump(tester, promoted: null, onPromote: (_) {});
      // Past the three blocks above it, each 20ms after the last.
      await tester.pump(const Duration(milliseconds: 120));
      expect(row(tester), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 400));
      expect(row(tester), 1.0);

      // A poll: the same card, built again with what the machine said next.
      await pump(tester, promoted: null, onPromote: (_) {});
      await tester.pump(const Duration(milliseconds: 16));
      expect(row(tester), 1.0);

      // And a card that is mounted with readings already has them.
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(tester, promoted: null, onPromote: (_) {});
      expect(row(tester), 1.0);
    });
  });

  testWidgets('a poll leaves the name row as it was, until it says something '
      'else', (tester) async {
    // A machine's name, what it runs and how it is reached are a fifth of its
    // card and none of it is what a poll is about. Every poll is a new status
    // and so a new widget for each of them, and an element visited to be told
    // what it had.
    await pump(tester, promoted: null, onPromote: (_) {});
    final nameWas = tester.widget(find.text('web'));

    await pump(tester, promoted: null, onPromote: (_) {}, samples: 3);
    expect(tester.widget(find.text('web')), same(nameWas));

    // Kept is not stuck: the line on the right is the uptime, and says the
    // new one.
    await pump(tester, promoted: null, onPromote: (_) {}, uptime: 'up 4 days');
    expect(find.textContaining('4 days'), findsOneWidget);
    expect(find.textContaining('3 days'), findsNothing);

    // Nor is the control on the right: it is the one thing a card that is
    // not answering has, and it changes with how the machine stands.
    await pump(
      tester,
      promoted: null,
      onPromote: (_) {},
      conn: ServerConn.disconnected,
    );
    expect(find.byIcon(MingCute.link_3_line), findsOneWidget);
  });

  testWidgets('tapping a row asks for it to be drawn in full', (tester) async {
    final asked = <ServerMetricKind>[];
    await pump(tester, promoted: null, onPromote: asked.add);

    await tester.tap(find.text(libL10n.memory));
    await tester.pump();

    expect(asked, [ServerMetricKind.mem]);
  });

  testWidgets('a long name elides rather than running past the card', (
    tester,
  ) async {
    // The name already asked for an ellipsis; in a row a text is handed its
    // own intrinsic width, so it never got to use it and pushed the row past
    // the card instead. Overflow is an exception in a test rather than a
    // stripe on the screen, so the pump is most of the assertion.
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Stores.server.put(
      spiFixture(
        id: 'srv-long',
        name: 'a server whose name is far longer than any card is wide',
        ip: 'h',
        user: 'u',
        autoConnect: false,
      ),
    );

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

    expect(find.byType(ServerPage), findsOneWidget);
  });

  testWidgets('what is promoted is what the headline shows', (tester) async {
    await pump(
      tester,
      promoted: ServerMetricKind.mem,
      onPromote: (_) {},
    );

    // Memory has moved up to the headline, so CPU is now the row — the two
    // have swapped places rather than both being drawn twice.
    expect(find.text('CPU'), findsOneWidget);
    expect(find.text(libL10n.memory), findsOneWidget);
    // The headline's value is the one with the big type; finding it at all is
    // what says the promotion took, since a card with no promotion draws the
    // CPU's `--`.
    expect(find.text('50.0%'), findsOneWidget);
  });

  group('the three densities', () {
    ServerListDensity auto(int count, Size viewport, {bool folded = true}) =>
        ServerListDensity.autoFor(count, viewport: viewport, folded: folded);

    test('what auto means is what the window shows at once', () {
      // The richest shape that holds all of them without scrolling. It was
      // six and twenty-four whatever the window, which is what one desktop
      // window holds — so a wide one went to lines with room for a dozen more
      // cards, and a phone kept cards it could show two of.
      const desk = Size(1200, 800);
      // Three columns of four.
      expect(auto(1, desk), ServerListDensity.cards);
      expect(auto(12, desk), ServerListDensity.cards);
      expect(auto(13, desk), ServerListDensity.rows);
      // Eighteen lines.
      expect(auto(18, desk), ServerListDensity.rows);
      expect(auto(19, desk), ServerListDensity.grid);

      // The same list in a bigger window is still cards: five columns of six.
      expect(auto(30, const Size(2000, 1100)), ServerListDensity.cards);
      // And in a narrower one it is not: two columns of four.
      expect(auto(9, const Size(700, 800)), ServerListDensity.rows);
      // Nor in a shorter one, at the same width: three columns of two.
      expect(auto(6, const Size(1200, 500)), ServerListDensity.cards);
      expect(auto(10, const Size(1200, 500)), ServerListDensity.rows);
      // Which has eleven lines, so a list that was cards a moment ago can be
      // tiles after the window is made half as tall.
      expect(auto(12, const Size(1200, 500)), ServerListDensity.grid);
    });

    test('and how tall a card is, which is whether it rests folded', () {
      // Unfolded, that desktop window holds the six it always did.
      const desk = Size(1200, 800);
      expect(auto(6, desk, folded: false), ServerListDensity.cards);
      expect(auto(7, desk, folded: false), ServerListDensity.rows);
    });

    test('one column is given a second screen of cards', () {
      // A phone, where that is a flick. Held to one screen it has room for
      // four, or one unfolded, and would hardly ever be given cards at all.
      const phone = Size(390, 700);
      expect(auto(8, phone), ServerListDensity.cards);
      expect(auto(9, phone), ServerListDensity.rows);
      expect(auto(3, phone, folded: false), ServerListDensity.cards);
      expect(auto(4, phone, folded: false), ServerListDensity.rows);
    });

    test('and one machine is a card whatever the window', () {
      expect(auto(1, const Size(300, 100)), ServerListDensity.cards);
      expect(auto(1, Size.zero), ServerListDensity.cards);
    });

    testWidgets('a card is as tall as auto takes it to be', (tester) async {
      // Those two numbers are about this widget and live in another file, so
      // this is what says when the card has changed under them.
      Future<double> measure({required bool expanded}) async {
        await pump(
          tester,
          // Memory, for a note under the chart: a machine in a test has no
          // CPU model, and most real ones have.
          promoted: ServerMetricKind.mem,
          onPromote: (_) {},
          everything: true,
          sensor: true,
          expanded: expanded,
          width: 338,
        );
        // Frame by frame, as the rows unfold: the card follows a height that
        // changes on every frame, and one that went from folded to unfolded
        // between two frames is a change it would animate on its own after.
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        return tester.getSize(find.byType(ServerCard)).height;
      }

      expect(
        await measure(expanded: false),
        moreOrLessEquals(ServerListDensity.cardFolded, epsilon: 8),
      );
      // Three rows here, and most machines have four: a machine in a test
      // has no network to report. So one more of them, measured.
      final unfolded = await measure(expanded: true);
      expect(find.byType(MetricRow), findsNWidgets(3));
      final row = tester.getSize(find.byType(MetricRow).first).height;
      expect(
        unfolded + row + ServerCardSizes.rowGap,
        moreOrLessEquals(ServerListDensity.cardUnfolded, epsilon: 15),
      );
    });

    test('a larger text scale rules the tightest one out', () {
      // A name in a 44pt tile is the first thing to stop fitting.
      const desk = Size(1200, 800);
      ServerListDensity resolved(ServerListDensity it, double textScale) =>
          it.resolve(
            count: 40,
            textScale: textScale,
            viewport: desk,
            folded: true,
          );
      expect(resolved(ServerListDensity.grid, 1), ServerListDensity.grid);
      expect(resolved(ServerListDensity.grid, 1.5), ServerListDensity.rows);
      expect(resolved(ServerListDensity.auto, 1.5), ServerListDensity.rows);
    });

    test('a choice is kept per tag', () {
      ServerDensityPref.put('', ServerListDensity.grid);
      ServerDensityPref.put('prod', ServerListDensity.cards);

      expect(ServerDensityPref.of(''), ServerListDensity.grid);
      expect(ServerDensityPref.of('prod'), ServerListDensity.cards);
      // Never chosen, so it follows the count rather than another tag's
      // answer.
      expect(ServerDensityPref.of('staging'), ServerListDensity.auto);
    });
  });

  // A line draws what a machine is carrying as one bar, the same one a tile
  // draws, where it used to draw a bar per reading. It has the width a tile
  // has not, so it also names the readings and gives their numbers.
  group('a line in the list', () {
    // The bar is the only rounded clip inside a line.
    final bar = find.descendant(
      of: find.byType(ServerCard),
      matching: find.byType(ClipRRect),
    );

    testWidgets('draws one bar, and names what it is made of', (tester) async {
      await pump(
        tester,
        promoted: null,
        onPromote: (_) {},
        density: ServerListDensity.rows,
        width: 900,
        everything: true,
      );

      expect(bar, findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      // Each name in the colour of its stretch of the bar, which is what ties
      // a number to a length.
      Color? nameColor(String name) =>
          tester.widget<Text>(find.text(name)).style?.color;
      expect(nameColor('CPU'), ChartPalette.cpu);
      expect(nameColor('MEM'), ChartPalette.mem);
      expect(nameColor('DISK'), ChartPalette.diskRead);
      // In the bar's own order.
      expect(
        tester.getCenter(find.text('CPU')).dx,
        lessThan(tester.getCenter(find.text('MEM')).dx),
      );
      expect(
        tester.getCenter(find.text('MEM')).dx,
        lessThan(tester.getCenter(find.text('DISK')).dx),
      );
      // A swap is not part of the bar, and nobody is watching it.
      expect(find.text('SWAP'), findsNothing);
    });

    testWidgets('keeps the bar and the watched number when narrow', (
      tester,
    ) async {
      await pump(
        tester,
        promoted: ServerMetricKind.mem,
        onPromote: (_) {},
        density: ServerListDensity.rows,
        width: 330,
        everything: true,
      );

      expect(tester.takeException(), isNull);
      expect(bar, findsOneWidget);
      expect(tester.getSize(bar).width, greaterThanOrEqualTo(48));
      expect(find.text('MEM'), findsOneWidget);
      expect(find.text('CPU'), findsNothing);
      expect(find.text('DISK'), findsNothing);
    });

    testWidgets('a watched reading the bar does not hold comes first', (
      tester,
    ) async {
      await pump(
        tester,
        promoted: ServerMetricKind.swap,
        onPromote: (_) {},
        density: ServerListDensity.rows,
        width: 900,
        everything: true,
      );

      expect(find.text('SWAP'), findsOneWidget);
      expect(
        tester.getCenter(find.text('SWAP')).dx,
        lessThan(tester.getCenter(find.text('CPU')).dx),
      );
      // Not a stretch of the bar, so not in a colour of it.
      expect(
        tester.widget<Text>(find.text('SWAP')).style?.color,
        Colors.grey,
      );
    });
  });
}
