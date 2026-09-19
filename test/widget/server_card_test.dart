import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
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
  ServerStatus sampled({bool everything = false}) {
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
      temps: Temperatures(),
      system: SystemType.linux,
      diskIO: DiskIO(),
    );
    // What says a status came back at all — see `serverNeverSampled`.
    ss.more[StatusCmdType.uptime] = 'up 3 days';
    ss.history.add(timeMs: DateTime.now().millisecondsSinceEpoch, mem: 50);
    return ss;
  }

  Future<void> pump(
    WidgetTester tester, {
    required ServerMetricKind? promoted,
    required void Function(ServerMetricKind) onPromote,
    ServerListDensity density = ServerListDensity.cards,
    double width = 600,
    bool everything = false,
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
                status: sampled(everything: everything),
                conn: ServerConn.finished,
              ),
              promoted: promoted,
              onPromote: onPromote,
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
    test('what auto means is decided by the count and nothing else', () {
      // The window's width says nothing about it: three servers on a desktop
      // are still three servers.
      expect(ServerListDensity.autoFor(1), ServerListDensity.cards);
      expect(ServerListDensity.autoFor(6), ServerListDensity.cards);
      expect(ServerListDensity.autoFor(7), ServerListDensity.rows);
      expect(ServerListDensity.autoFor(24), ServerListDensity.rows);
      expect(ServerListDensity.autoFor(25), ServerListDensity.grid);
    });

    test('a larger text scale rules the tightest one out', () {
      // A name in a 44pt tile is the first thing to stop fitting.
      expect(
        ServerListDensity.grid.resolve(count: 40, textScale: 1),
        ServerListDensity.grid,
      );
      expect(
        ServerListDensity.grid.resolve(count: 40, textScale: 1.5),
        ServerListDensity.rows,
      );
      expect(
        ServerListDensity.auto.resolve(count: 40, textScale: 1.5),
        ServerListDensity.rows,
      );
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
