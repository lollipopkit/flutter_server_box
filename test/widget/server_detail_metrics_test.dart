/// The detail page as one chart and a row each.
///
/// What is worth holding: which metric is drawn in full is a choice made on
/// the page and not a route, the facts sit beside the readings only where both
/// fit, and a machine without swap has no swap row rather than an empty one.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/battery.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/gpu.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/chart.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/server/metric_row.dart';

import 'package:server_box/view/widget/server_func_btns.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sid = 'srv-metrics';
  final spi = spiFixture(
    id: sid,
    name: 'web',
    ip: 'h',
    user: 'u',
    autoConnect: false,
  );

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    // 0 is off: a periodic refresh outliving the tree fails the run.
    Stores.setting.serverStatusUpdateInterval.put(0);
    Stores.server.put(spi);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  /// A machine with memory worth a figure and nothing in swap, which is the
  /// shape [InitStatus] has: one disk, no swap, no interfaces.
  ServerStatus statusOf() {
    final status = InitStatus.status;
    status.more[StatusCmdType.host] = 'test-host';
    status.more[StatusCmdType.sys] = 'Ubuntu 24.04';
    status.more[StatusCmdType.uptime] = 'up 12 days';
    status.mem = const Memory(total: 134217728, free: 8388608, avail: 16777216);
    return status;
  }

  /// A machine that reports everything the page can draw a row for.
  ServerStatus richStatus() {
    final status = statusOf();
    status.gpus = const [
      GpuItem(
        id: '0',
        vendor: 'nvidia',
        name: 'NVIDIA T4',
        utilization: 41,
        temperature: 58,
        memory: GpuSmiMem(16384, 2150, 'MiB', []),
      ),
    ];
    status.temps.setAll(const {'coretemp': 62.1, 'nvme': 38.0});
    status.batteries.add(
      const Battery(
        status: BatteryStatus.discharging,
        percent: 87,
        name: 'BAT0',
        cycle: 41,
      ),
    );
    return status;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<ServerNotifier> pump(
    WidgetTester tester, {
    required Size size,
    ServerStatus Function()? status,
  }) async {
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
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return ServerDetailPage(args: SpiRequiredArgs(spi));
            },
          ),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServerDetailPage)),
    );
    final notifier = container.read(serverProvider(sid).notifier);
    notifier.updateStatus((status ?? statusOf)(), latencyMs: 41);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return notifier;
  }

  testWidgets('desktop: the facts sit beside the readings', (tester) async {
    await pump(tester, size: const Size(1200, 900));

    expect(tester.takeException(), isNull);
    // One row per metric the machine reports, and none for what it has not.
    expect(find.text('CPU'), findsWidgets);
    expect(find.text(libL10n.memory), findsWidgets);
    expect(find.text(libL10n.disk), findsWidgets);
    expect(
      find.text('Swap'),
      findsNothing,
      reason: 'a machine with no swap got a row that can never have a value',
    );
    // The facts, in their own column.
    expect(find.text(libL10n.about), findsOneWidget);
    expect(find.text(app_locale.l10n.hardware), findsOneWidget);
    expect(find.text('test-host'), findsOneWidget);
    // How the app reaches the machine and how long it took, in one row.
    expect(find.textContaining('41ms'), findsOneWidget);
    expect(find.text(libL10n.conn), findsOneWidget);
  });

  testWidgets('phone: the facts go under the rows, and nothing overflows', (
    tester,
  ) async {
    await pump(tester, size: const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text(libL10n.about), findsOneWidget);
    expect(find.text('test-host'), findsOneWidget);
  });

  testWidgets('phone: a page pushed on its own is at the scale the list is', (
    tester,
  ) async {
    // Five of its texts were handed the setting as their scaler, which
    // replaces the system's for those five. With the phone's text turned down
    // they were a fifth larger than the rest of the card they were in, and
    // the rest of the page did not follow the setting at all.
    tester.platformDispatcher.textScaleFactorTestValue = 0.82;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester, size: const Size(390, 844));

    final host = find.text('test-host');
    expect(tester.widget<Text>(host).textScaler, isNull);
    double scaled() =>
        MediaQuery.textScalerOf(tester.element(host)).scale(100);
    expect(scaled(), moreOrLessEquals(82, epsilon: 0.01));

    Stores.setting.textFactor.put(1.5);
    await tester.pump();
    expect(scaled(), moreOrLessEquals(123, epsilon: 0.01));
  });

  testWidgets('phone: what goes with the number is on its line, written '
      'one way', (tester) async {
    // They had a line of their own under it, each a number over its name — a
    // second line and a second way of writing for what reads straight on
    // from "idle". And idle was one of them, so it was on the card twice.
    await pump(tester, size: const Size(390, 844));

    final idle = find.textContaining(' idle');
    final user = find.textContaining(' user');
    expect(idle, findsOneWidget);
    expect(user, findsOneWidget);
    expect(
      tester.getRect(user).left,
      greaterThan(tester.getRect(idle).right),
    );
    expect(tester.getRect(user).top, tester.getRect(idle).top);
    expect(tester.widget<Text>(user).style, tester.widget<Text>(idle).style);
  });

  testWidgets('phone: the chart is as wide as its card lets it be', (
    tester,
  ) async {
    // It was 17 in from that on each side, inside a card that is already 17
    // in from its own edge: with the page's 13 and the scale's gutter, a
    // fifth of a phone's width with no chart in it.
    await pump(
      tester,
      size: const Size(390, 844),
      status: () {
        final status = statusOf();
        final now = DateTime.now().millisecondsSinceEpoch;
        for (var i = 0; i < 4; i++) {
          status.history.add(
            timeMs: now - (4 - i) * 3000,
            cpu: 10.0 + i,
            mem: 50,
          );
        }
        return status;
      },
    );

    final given = tester.getRect(find.byType(MetricChart));
    final plot = tester.getRect(find.byType(LineChart));
    expect(plot.left, given.left);
    expect(plot.right, given.right);
    // And what it is given is the card's own inset and the page's, no more.
    expect(given.left, lessThanOrEqualTo(13 + 17 + 4));
  });

  /// Nine rows and the cards under them, at the width where every line of the
  /// focus card is competing for the same 390 points.
  testWidgets('phone: every row a rich machine reports still fits', (
    tester,
  ) async {
    await pump(tester, size: const Size(390, 844), status: richStatus);

    expect(tester.takeException(), isNull);
    expect(find.text('GPU'), findsWidgets);
    expect(find.text(libL10n.battery), findsWidgets);
  });

  testWidgets('a row promotes its metric to the chart', (tester) async {
    await pump(tester, size: const Size(1200, 900));

    // CPU leads, so its stats are the ones in the card.
    expect(find.text('user'), findsOneWidget);

    // The first is the row; the Hardware card's total comes later in the tree.
    await tester.tap(find.text(libL10n.memory).first);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    // Memory's stats replaced CPU's, which is what says the chart changed
    // subject rather than a second card having opened.
    expect(find.text('user'), findsNothing);
    expect(find.text('avail'), findsOneWidget);
  });

  testWidgets('a poll builds again what says something else, and nothing '
      'that does not', (tester) async {
    // Every widget on the page is a new one on every poll, since the status
    // it is built from is, so every element was visited to be told what it
    // already had: sixteen hundred of them here, most about what the machine
    // is rather than what it is doing. Twelve to eighteen milliseconds a poll
    // in this harness and several times that on a phone in debug, every few
    // seconds, for a page that mostly says what it said.
    final notifier = await pump(tester, size: const Size(1200, 900));

    Finder rowOf(String label) => find.ancestor(
      of: find.text(label).first,
      matching: find.byType(MetricRow),
    );
    final hardware = find
        .ancestor(
          of: find.text(app_locale.l10n.hardware),
          matching: find.byType(CardX),
        )
        .first;
    final bar = find.byType(ServerFuncBar);
    final diskWas = tester.widget(rowOf(libL10n.disk));
    final hardwareWas = tester.widget(hardware);
    final barWas = tester.widget(bar);
    expect(find.text('87.5%'), findsWidgets);

    // The same machine with half its memory back.
    final next = statusOf()
      ..mem = const Memory(total: 134217728, free: 8388608, avail: 67108864);
    notifier.updateStatus(next, latencyMs: 41);
    await settle(tester);

    expect(tester.widget(rowOf(libL10n.disk)), same(diskWas));
    expect(tester.widget(hardware), same(hardwareWas));
    expect(tester.widget(bar), same(barWas));
    // And what did change is said: kept is not the same as stuck.
    expect(find.text('87.5%'), findsNothing);
    expect(find.text('50.0%'), findsWidgets);
  });

  testWidgets('choosing a reading builds the readings again, and nothing '
      'beside them', (tester) async {
    // It was the page's own state, so a press built the whole page: every
    // card of facts and every table, none of which is about which reading is
    // drawn in full. Twelve to twenty milliseconds a press in this harness,
    // which is a run of missed frames when one row is pressed after another.
    //
    // A widget that was not built again is the widget it was: none of these
    // are `const`, so building any of them makes a new one.
    await pump(tester, size: const Size(1200, 900));

    final facts = find
        .ancestor(of: find.text(libL10n.about), matching: find.byType(CardX))
        .first;
    // A row that is neither the one being left nor the one being chosen.
    final other = find.ancestor(
      of: find.text(libL10n.disk).first,
      matching: find.byType(MetricRow),
    );
    final factsWere = tester.widget(facts);
    final otherWas = tester.widget(other);

    await tester.tap(find.text(libL10n.memory).first);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // It did change.
    expect(find.text('avail'), findsOneWidget);
    expect(tester.widget(facts), same(factsWere));
    expect(tester.widget(other), same(otherWas));
  });

  testWidgets('which reading leads is the machine\'s, so it goes with the '
      'machine', (tester) async {
    // The page is a widget, not a route: a pane hands this same state another
    // server. The windows fetched and the devices picked were given up then
    // and the reading drawn in full was not, so the second machine opened on
    // whatever had been chosen for the first.
    final other = spiFixture(
      id: 'srv-other',
      name: 'db',
      ip: 'h2',
      user: 'u',
      autoConnect: false,
    );
    Stores.server.put(other);
    await pump(tester, size: const Size(1200, 900));
    await tester.tap(find.text(libL10n.memory).first);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('avail'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return ServerDetailPage(args: SpiRequiredArgs(other));
            },
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServerDetailPage)),
    );
    container.read(serverProvider('srv-other').notifier).updateStatus(
      statusOf(),
      latencyMs: 41,
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Nothing was chosen for this one, so it is the CPU.
    expect(find.text('avail'), findsNothing);
    expect(find.text('user'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone: the chart card eases to the height of another reading', (
    tester,
  ) async {
    // The CPU has one line over its chart and the sensors have two: which of
    // them the chart is of, and the way to the rest. Choosing between them
    // moved the chart by that line and every row under the card with it,
    // between two frames.
    await pump(
      tester,
      size: const Size(402, 874),
      status: () {
        final status = richStatus();
        final now = DateTime.now().millisecondsSinceEpoch;
        for (var i = 0; i < 4; i++) {
          status.history.add(
            timeMs: now - (4 - i) * 3000,
            cpu: 10.0 + i,
            temp: 60.0 + i,
          );
        }
        return status;
      },
    );

    Rect chart() => tester.getRect(find.byType(MetricChart));
    Rect card() => tester.getRect(
      find.ancestor(of: find.byType(MetricChart), matching: find.byType(CardX)),
    );
    final chartWas = chart();
    final cardWas = card();

    await tester.tap(find.text(libL10n.temperature).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final chartOnTheWay = chart();
    final cardOnTheWay = card();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(chart().top, greaterThan(chartWas.top + 10));
    expect(card().height, greaterThan(cardWas.height + 10));

    // Neither where it was nor where it ends up, a fifth of the way through.
    expect(chartOnTheWay.top, greaterThan(chartWas.top + 1));
    expect(chartOnTheWay.top, lessThan(chart().top - 1));
    expect(cardOnTheWay.height, greaterThan(cardWas.height + 1));
    expect(cardOnTheWay.height, lessThan(card().height - 1));
    // And the chart is the height it was the whole way: what moves is what
    // is round it.
    expect(chartOnTheWay.height, chartWas.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row is drawn in the theme colour, whichever reading it is', (
    tester,
  ) async {
    // Only the reading drawn in full was. The rest had a tint of their own,
    // barely off grey and 100° off the theme's hue: olive icons and olive
    // bars under a pink theme, beside cards whose icons were pink.
    await pump(tester, size: const Size(1200, 900));

    // CPU leads, so memory is one of the rest.
    final row = find.ancestor(
      of: find.text(libL10n.memory).first,
      matching: find.byType(MetricRow),
    );
    expect(tester.widget<MetricRow>(row).selected, isFalse);
    final icon = tester.widget<Icon>(
      find.descendant(of: row, matching: find.byType(Icon)).first,
    );
    expect(icon.color, ChartPalette.accent);
    final bar = tester.widget<LinearProgressIndicator>(
      find.descendant(
        of: row,
        matching: find.byType(LinearProgressIndicator),
      ),
    );
    expect(bar.valueColor?.value, ChartPalette.accent);
  });

  /// What a machine reports beyond the five: a percentage with a line behind
  /// it is a row, and the table it comes with stays a card.
  testWidgets('GPU load, the hottest sensor and the battery are rows', (
    tester,
  ) async {
    await pump(tester, size: const Size(1200, 900), status: richStatus);

    expect(tester.takeException(), isNull);
    expect(find.text('GPU'), findsWidgets);
    // What the machine has is a fact about the machine, so it is in the card
    // that lists what it is built of — beside the CPU and the memory.
    expect(find.text('NVIDIA T4'), findsWidgets);
    expect(find.text(libL10n.temperature), findsWidgets);
    expect(find.text(libL10n.battery), findsWidgets);
    // The hottest of the two, not their mean and not the first one.
    expect(find.textContaining('62.1°C'), findsWidgets);
    // Said once, where it is the answer: two sensors and which of them.
    expect(
      find.text(app_locale.l10n.sensorsHottestFmt(2, 'coretemp')),
      findsOneWidget,
    );
  });

  /// Nine rows and the cards under them are taller than a phone, so the row
  /// that promotes a metric is regularly below the card it promotes it into.
  /// From down there the tap changes a chart nobody can see.
  testWidgets('promoting a metric brings its chart back on screen', (
    tester,
  ) async {
    await pump(tester, size: const Size(390, 700), status: richStatus);

    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView).first,
    );
    final controller = scroll.controller!;
    controller.jumpTo(controller.position.maxScrollExtent);
    await settle(tester);
    final atBottom = controller.offset;
    expect(atBottom, greaterThan(0), reason: 'the page has to be scrollable');

    // A row that is on screen down here, promoting a chart that is not.
    await tester.tap(find.text(libL10n.battery).last);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(
      controller.offset,
      lessThan(atBottom),
      reason: 'the chart the tap changed was left off screen',
    );

    // And a tap with the chart already in view leaves the page where it is.
    final settled = controller.offset;
    await tester.tap(find.text('CPU').last);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(controller.offset, settled);
  });

  /// Every card opens, not only the ones with a process in them: the row is
  /// one line of a card that reports a dozen readings.
  testWidgets('a GPU opens its own readings', (tester) async {
    await pump(tester, size: const Size(1200, 900), status: richStatus);

    await tester.tap(find.textContaining('NVIDIA T4 · 0'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.text('NVIDIA T4 · 0'), findsWidgets);
    // The readings the row had no room for.
    expect(find.text('Vendor'), findsOneWidget);
    expect(find.text('nvidia'), findsOneWidget);
    expect(find.text('2150 / 16384 MiB'), findsWidgets);
  });

  /// A machine with several disks is busy because one of them is, so the chart
  /// draws a line each and the card says how many of them are on it.
  testWidgets('disk I/O is drawn per device once there is more than one', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(1200, 900),
      status: () {
        final status = statusOf();
        const names = ['sda', 'sdb'];
        for (final (i, sectors) in [10, 1000].indexed) {
          status.diskIO.updateForSystem([
            for (final name in names)
              DiskIOPiece(
                dev: name,
                sectorsRead: sectors,
                sectorsWrite: sectors * (names.indexOf(name) + 1),
                time: i + 1,
              ),
          ], SystemType.linux);
        }
        // The buffer the live window is: what the sources append on a poll.
        for (var i = 1; i <= 3; i++) {
          status.history.add(
            timeMs: i,
            diskWrites: {'sda': 1000.0 * i, 'sdb': 2000.0 * i},
          );
        }
        return status;
      },
    );

    await tester.tap(find.text(app_locale.l10n.diskIo).first);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);

    // A rate says how high it got, and not what window that was in: the
    // header's chip already does. It said "Live" over the word "window", two
    // lines under a chip that says "Live".
    expect(find.text(app_locale.l10n.window), findsNothing);
    expect(find.text(app_locale.l10n.rangeLive), findsOneWidget);

    // The first line is the theme colour and the second is not: they were
    // a red and an amber fixed at build time, so the one chart on the page
    // with two lines was the one with none of the theme in it.
    final lines = tester
        .widget<LineChart>(find.byType(LineChart))
        .data
        .lineBarsData;
    expect(lines, hasLength(2));
    expect(lines.first.color, ChartPalette.accent);
    expect(lines.last.color, isNot(ChartPalette.accent));
    expect(lines.last.color, ChartPalette.lines[1]);

    // The legend is the device list, so the names are what says the chart is
    // per device rather than read against write.
    expect(find.textContaining('sda'), findsWidgets);
    expect(find.textContaining('sdb'), findsWidgets);
    expect(find.text(app_locale.l10n.devicesPlottedFmt(2, 2)), findsOneWidget);

    // And the control opens them, ticked where they are drawn.
    await tester.tap(find.text(app_locale.l10n.devicesPlottedFmt(2, 2)));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byIcon(Icons.check), findsNWidgets(2));

    await tester.tap(find.text('sdb').last);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  /// The picker offers what the agent can answer for. An SSH server's agent is
  /// no agent at all, so only the window this app kept itself is offerable —
  /// the rest stay in the list, greyed, with the reason.
  testWidgets('the range picker says why a window is not on offer', (
    tester,
  ) async {
    await pump(tester, size: const Size(1200, 900));

    await tester.tap(find.byIcon(Icons.date_range));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);

    // Every window is listed, including the ones this connection cannot fill.
    expect(find.text('24h'), findsWidgets);
    expect(find.text('7d'), findsWidgets);
    // Tapping one of those says why instead of switching to an empty chart.
    await tester.tap(find.text('7d').last);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(app_locale.l10n.rangeLive), findsWidgets);
  });

  /// Only an agent stores history, so an SSH server is offered the one window
  /// it has rather than three it cannot fill.
  testWidgets('an SSH server is told why the longer ranges are empty', (
    tester,
  ) async {
    await pump(tester, size: const Size(1200, 900));

    expect(find.text(app_locale.l10n.rangeLive), findsOneWidget);

    await tester.tap(find.text('24h'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    // Still on the one window it has.
    expect(find.text(app_locale.l10n.rangeLive), findsOneWidget);
  });
}
