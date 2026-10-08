import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/view/widget/conn_count_badge.dart';
import 'package:server_box/view/widget/nav_rail.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

/// The connection count on the server tab, which a setting can hide (#1637).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('conn-badge-');
    Paths.doc = tmp.path;
  });

  tearDownAll(() => tmp.delete(recursive: true));

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    Stores.server.put(
      spiFixture(id: 'srv-1', name: 'srv', ip: '10.0.0.1', autoConnect: false),
    );
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: ConnCountRailBadge())),
      ),
    );
    await tester.pump();
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('shown by default', (tester) async {
    await pump(tester);
    expect(find.byType(NavRailBadge), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
  });

  testWidgets('hidden by the setting, and back when it is on again', (
    tester,
  ) async {
    Stores.setting.serverTabConnBadge.put(false);
    await pump(tester);
    expect(find.byType(NavRailBadge), findsNothing);

    Stores.setting.serverTabConnBadge.put(true);
    await tester.pump();
    expect(find.text('0/1'), findsOneWidget);
  });
}
