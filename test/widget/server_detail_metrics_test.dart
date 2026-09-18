/// The detail page as one chart and a row each.
///
/// What is worth holding: which metric is drawn in full is a choice made on
/// the page and not a route, the facts sit beside the readings only where both
/// fit, and a machine without swap has no swap row rather than an empty one.
library;

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
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/detail/view.dart';

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
    expect(find.text('idle'), findsOneWidget);

    // The first is the row; the Hardware card's total comes later in the tree.
    await tester.tap(find.text(libL10n.memory).first);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    // Memory's stats replaced CPU's, which is what says the chart changed
    // subject rather than a second card having opened.
    expect(find.text('idle'), findsNothing);
    expect(find.text('avail'), findsOneWidget);
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
    expect(find.text(app_locale.l10n.historySinceConnect), findsOneWidget);

    await tester.tap(find.text('24h'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    // Still on the one window it has.
    expect(find.text(app_locale.l10n.rangeLive), findsOneWidget);
  });
}
