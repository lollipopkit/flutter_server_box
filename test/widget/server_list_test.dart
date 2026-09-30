import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
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
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/card/density.dart';
import 'package:server_box/view/page/server/card/overview.dart';
import 'package:server_box/view/page/server/tab/tab.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

const _count = 12;

/// The server list: what sits above it, and where it stays while its servers
/// refresh.
void main() {
  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PveStore>(PveStore());
    getIt.registerSingleton<ConnectionStatsStore>(ConnectionStatsStore.instance);
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    // Off, so no periodic timer outlives the tree.
    Stores.setting.serverStatusUpdateInterval.put(0);
    // The globe would take the page instead of the grid.
    Stores.setting.globeEnabled.put(false);
    // Cards with readings, which are what a reconnect used to take away.
    ServerDensityPref.put(TagSwitcher.kDefaultTag, ServerListDensity.cards);
    for (var i = 0; i < _count; i++) {
      Stores.server.put(
        spiFixture(
          id: 'srv-$i',
          name: 'host$i',
          ip: 'h$i',
          user: 'u',
          autoConnect: false,
        ),
      );
    }
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  ServerStatus sample() {
    final status = ServerStatus(
      cpu: Cpus(),
      mem: const Memory(total: 1048576, free: 524288, avail: 524288),
      disk: const <Disk>[],
      tcp: const Conn(maxConn: 0, fail: 0),
      netSpeed: NetSpeed(),
      swap: const Swap(total: 0, free: 0, cached: 0),
      temps: Temperatures(),
      system: SystemType.linux,
      diskIO: DiskIO(),
    );
    status.more[StatusCmdType.uptime] = 'up 3 days';
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 8; i++) {
      status.history.add(timeMs: now - (8 - i) * 3000, cpu: 10.0 + i, mem: 50);
    }
    return status;
  }

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [...appLocalizationsDelegates],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home: const ServerPage(),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await settle(tester);
  }

  testWidgets('the overview follows its setting, without a restart', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.byType(ServerOverview), findsOneWidget);

    Stores.setting.serverOverview.put(false);
    await settle(tester);
    expect(find.byType(ServerOverview), findsNothing);

    Stores.setting.serverOverview.put(true);
    await settle(tester);
    expect(find.byType(ServerOverview), findsOneWidget);
  });

  // A client that closed — every one of them, once the app is back from the
  // background — reconnects through connecting, connected and loading. The
  // cards used to drop their readings for all three, the list fell to a
  // fraction of its height, and whoever had scrolled it was left at its top.
  testWidgets('a reconnect keeps the list where it was scrolled to', (
    tester,
  ) async {
    await pumpPage(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServerPage)),
    );
    void setAll(ServerConn conn) {
      for (var i = 0; i < _count; i++) {
        container.read(serverProvider('srv-$i').notifier).updateConnection(conn);
      }
    }

    for (var i = 0; i < _count; i++) {
      container.read(serverProvider('srv-$i').notifier).updateStatus(sample());
    }
    setAll(ServerConn.finished);
    await settle(tester);

    final position = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .map((s) => s.position)
        .firstWhere((p) => p.axis == Axis.vertical && p.maxScrollExtent > 0);
    final middle = position.maxScrollExtent / 2;
    position.jumpTo(middle);
    await settle(tester);

    for (final conn in [
      ServerConn.connecting,
      ServerConn.connected,
      ServerConn.loading,
      ServerConn.finished,
    ]) {
      setAll(conn);
      await settle(tester);
      expect(position.pixels, middle, reason: conn.name);
    }
  });
}
