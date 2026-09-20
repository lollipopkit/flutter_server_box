import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/connection_stat.dart';
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
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/card/overview.dart';
import 'package:server_box/view/page/server/card/pressure.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

/// The strip over the list: what the whole of it adds up to, in one line.
///
/// What gives as that line narrows is detail and never a section. It used to
/// be sections — memory and then the disk — so a phone was told about the
/// processors and nothing else.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  const id = 'srv-0';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-overview-');
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<ConnectionStatsStore>(ConnectionStatsStore.instance);
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    Stores.setting.serverStatusUpdateInterval.put(0);
    // Before anything is recorded against it: `conn_stat.server_id` is a
    // foreign key, and a record for a server that is not there is dropped
    // without a word.
    Stores.server.put(
      spiFixture(id: id, name: 'web', ip: 'h', user: 'u', autoConnect: false),
    );
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  /// Half the memory gone and [diskPercent] of the disk.
  ServerStatus sampled({double diskPercent = 40}) {
    final status = ServerStatus(
      cpu: Cpus(),
      mem: const Memory(total: 1048576, free: 524288, avail: 524288),
      disk: [
        Disk(
          path: '/dev/sda1',
          mount: '/',
          usedPercent: diskPercent.round(),
          used: BigInt.from(diskPercent * 100000),
          size: BigInt.from(10000000),
          avail: BigInt.from((100 - diskPercent) * 100000),
        ),
      ],
      tcp: const Conn(maxConn: 0, fail: 0),
      netSpeed: NetSpeed(),
      swap: const Swap(total: 0, free: 0, cached: 0),
      temps: Temperatures(),
      system: SystemType.linux,
      diskIO: DiskIO(),
    );
    status.more[StatusCmdType.uptime] = 'up 3 days';
    return status;
  }

  Future<void> record({required bool ok}) =>
      Stores.connectionStats.recordConnection(
        ConnectionStat(
          serverId: id,
          serverName: 'web',
          timestamp: DateTime.now(),
          result: ok ? ConnectionResult.success : ConnectionResult.timeout,
          errorMessage: ok ? '' : 'Connection timed out',
          durationMs: 120,
        ),
      );

  Future<void> pump(
    WidgetTester tester, {
    required double width,
    ServerStatus? status,
  }) async {
    tester.view.physicalSize = Size(width, 600);
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
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: ServerOverview(ids: [id]),
            ),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServerOverview)),
    );
    final notifier = container.read(serverProvider(id).notifier);
    notifier.updateStatus(status ?? sampled());
    notifier.updateConnection(ServerConn.finished);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The colour of the dot inside the control at the right of the line.
  Color? controlDot(WidgetTester tester) {
    final dots = find.descendant(
      of: find.ancestor(
        of: find.byIcon(Icons.expand_more),
        matching: find.byType(InkWell),
      ),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    if (dots.evaluate().isEmpty) return null;
    return (tester.widget<Container>(dots.first).decoration! as BoxDecoration)
        .color;
  }

  testWidgets('a bar each where there is room for three', (tester) async {
    await pump(tester, width: 800);

    expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    expect(find.byType(PressureBar), findsNothing);
  });

  testWidgets('and one bar of all three where there is not', (tester) async {
    await pump(tester, width: 390);

    expect(find.byType(LinearProgressIndicator), findsNothing);
    final bar = tester.widget<PressureBar>(find.byType(PressureBar));
    // Memory and the disk, each at the half a tile in the list gives them:
    // the bar over the list is read against the bars in it.
    expect(bar.segments.map((s) => s.kind), [
      ServerMetricKind.mem,
      ServerMetricKind.disk,
    ]);
    expect(
      bar.segments.first.share,
      moreOrLessEquals(0.5 * kPressureShare, epsilon: 0.001),
    );
    expect(
      bar.segments.last.share,
      moreOrLessEquals(0.4 * kPressureShare, epsilon: 0.001),
    );
    // The bar is what stays. The names that fit are in the colours of their
    // stretches, which is what makes three colours three readings.
    final cpu = tester.widget<Text>(find.text('CPU'));
    expect(cpu.style?.color, ChartPalette.cpu);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the numbers go from the right, and the bar stays', (
    tester,
  ) async {
    await pump(tester, width: 700);
    expect(find.byType(PressureBar), findsOneWidget);
    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('MEM'), findsOneWidget);
    expect(find.text('DISK'), findsOneWidget);

    await pump(tester, width: 320);
    expect(find.byType(PressureBar), findsOneWidget);
    expect(find.text('DISK'), findsNothing);
    expect(
      tester.getSize(find.byType(PressureBar)).width,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('what happened last is a colour and a way in, not a count', (
    tester,
  ) async {
    await tester.runAsync(() => record(ok: true));
    await pump(tester, width: 390);

    expect(find.textContaining('+'), findsNothing);
    expect(controlDot(tester), StatePalette.running);

    // And it opens onto what the colour was of.
    expect(find.textContaining('120 ms'), findsNothing);
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('120 ms'), findsOneWidget);
  });

  testWidgets('and the colour is the last one that failed', (tester) async {
    await tester.runAsync(() => record(ok: false));
    await pump(tester, width: 390);

    expect(controlDot(tester), StatePalette.failed);
  });

  testWidgets('a reading over its line outranks it, and the list says which', (
    tester,
  ) async {
    // The line has no room for the words, so the colour is all of it — and a
    // dot that opened onto connections that went fine would not have said
    // why it was amber.
    await tester.runAsync(() => record(ok: true));
    await pump(tester, width: 390, status: sampled(diskPercent: 95));

    expect(controlDot(tester), StatePalette.warn);
    final bar = tester.widget<PressureBar>(find.byType(PressureBar));
    expect(bar.segments.last.over, isTrue);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining(libL10n.disk), findsWidgets);
    expect(find.textContaining('120 ms'), findsOneWidget);
  });

  testWidgets('with room for the words, the dot is at the head of them', (
    tester,
  ) async {
    await tester.runAsync(() => record(ok: true));
    await pump(tester, width: 1000);

    expect(find.textContaining('120 ms'), findsOneWidget);
    // One dot for one thing said: the control keeps only the way in.
    expect(controlDot(tester), isNull);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
  });
}
