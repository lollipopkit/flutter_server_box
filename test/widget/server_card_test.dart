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
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/card/card.dart';
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

  ServerStatus sampled() {
    final ss = ServerStatus(
      cpu: Cpus(),
      // 1 GiB, half of it gone.
      mem: const Memory(total: 1048576, free: 524288, avail: 524288),
      disk: const [],
      tcp: const Conn(maxConn: 0, fail: 0),
      netSpeed: NetSpeed(),
      swap: const Swap(total: 0, free: 0, cached: 0),
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
  }) async {
    tester.view.physicalSize = const Size(600, 900);
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
                status: sampled(),
                conn: ServerConn.finished,
              ),
              promoted: promoted,
              onPromote: onPromote,
              onTap: () {},
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
}
