import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/view/page/ssh/metrics_bar.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

/// The readings under a terminal: the card's numbers, four slots, a dash in
/// one the machine has not reported, and nothing at all while the setting is
/// off.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  ServerState state({bool net = false, bool disk = true}) {
    final speed = NetSpeed();
    if (net) {
      speed.update([NetSpeedPart('eth0', BigInt.zero, BigInt.zero, 10)]);
      speed.update([
        NetSpeedPart('eth0', BigInt.from(1024), BigInt.from(4096), 11),
      ]);
    }
    final status = ServerStatus(
      cpu: Cpus(),
      // 1 GiB, half of it gone.
      mem: const Memory(total: 1048576, free: 524288, avail: 524288),
      disk: const [],
      tcp: const Conn(maxConn: 0, fail: 0),
      netSpeed: speed,
      swap: const Swap(total: 0, free: 0, cached: 0),
      temps: Temperatures(),
      system: SystemType.linux,
      diskIO: DiskIO(),
    );
    if (disk) {
      status.diskUsage = DiskUsage(
        used: BigInt.from(4000000),
        size: BigInt.from(10000000),
      );
    }
    return ServerState(
      spi: spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u'),
      status: status,
      conn: ServerConn.finished,
    );
  }

  Future<void> pump(WidgetTester tester, Widget bar) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: Scaffold(body: bar)),
      ),
    );
    await tester.pump();
  }

  testWidgets('the four readings, written as the card writes them', (
    tester,
  ) async {
    await pump(tester, TerminalMetricsBarView(srv: state(net: true)));

    expect(find.text('50.0%'), findsOneWidget); // memory
    expect(find.text('40.0%'), findsOneWidget); // disk
    // Both directions in one slot.
    expect(find.textContaining('↑'), findsOneWidget);
    expect(find.textContaining('↓'), findsOneWidget);
    // No CPU sample yet: the card's dash, in the CPU's slot.
    expect(find.text('--'), findsOneWidget);
  });

  testWidgets('a reading the machine has not reported keeps its slot', (
    tester,
  ) async {
    await pump(tester, TerminalMetricsBarView(srv: state(disk: false)));

    // CPU, network and disk unreported; memory is there.
    expect(find.text('--'), findsNWidgets(3));
    expect(find.text('50.0%'), findsOneWidget);
    expect(find.byType(Icon), findsNWidgets(4));
  });

  testWidgets('nothing while the setting is off', (tester) async {
    Stores.setting.termMetricsBar.put(false);
    await pump(tester, const TerminalMetricsBar(serverId: 'srv-1'));

    expect(find.byType(TerminalMetricsBarView), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });
}
