import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:server_box/view/page/server/tab/group_heading.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

/// The alert count beside a section's heading follows the machines in it.
///
/// The grid the heading sits in is not rebuilt by a poll — each card watches
/// its own server — so a count the grid took when it laid the list out stayed
/// there: a machine going over the line after that was never counted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<ConnectionStatsStore>(
      ConnectionStatsStore.instance,
    );
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    Stores.setting.serverStatusUpdateInterval.put(0);
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
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  /// [memUsed] is the share of memory in use, 0 to 1.
  ServerStatus statusWith({required double memUsed}) {
    const total = 1048576;
    final avail = (total * (1 - memUsed)).round();
    return ServerStatus(
      cpu: Cpus(),
      mem: Memory(total: total, free: avail, avail: avail),
      disk: const [],
      tcp: const Conn(maxConn: 0, fail: 0),
      netSpeed: NetSpeed(),
      swap: const Swap(total: 0, free: 0, cached: 0),
      temps: Temperatures(),
      system: SystemType.linux,
      diskIO: DiskIO(),
    );
  }

  testWidgets('the alert count follows a poll', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ServerGroupHeading(
              label: 'prod',
              ids: ['srv-0', 'srv-1'],
              first: true,
            ),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServerGroupHeading)),
    );
    final notifier = container.read(serverProvider('srv-0').notifier);

    expect(find.text('2'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsNothing);

    notifier.updateStatus(statusWith(memUsed: 0.95));
    notifier.updateConnection(ServerConn.finished);
    await tester.pump();
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    notifier.updateStatus(statusWith(memUsed: 0.5));
    await tester.pump();
    expect(find.byIcon(Icons.warning_amber), findsNothing);
  });
}
