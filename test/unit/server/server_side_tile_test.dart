/// A row in a side rail of servers and sessions, the same on every tab that
/// has one: a dot on the server's mark, or the bar on the edge where there is
/// no mark.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/view/widget/server_side_tile.dart';

import '../../helpers/spi_fixture.dart';
import '../../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    // Marks off, as a fresh install has them.
    Stores.setting.showDistMark.put(false);
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  Widget rail(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('without a mark, a state is the bar on the edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      rail(ServerSideTile(spi: spiFixture(name: 'box'), state: Colors.green)),
    );
    final tile = tester.widget<SideBarTile>(find.byType(SideBarTile));
    expect(tile.leading, isNull);
    expect(tile.live, isTrue);
    expect(tile.liveColor, Colors.green);
  });

  testWidgets('without a state, nothing at all', (tester) async {
    await tester.pumpWidget(rail(ServerSideTile(spi: spiFixture(name: 'box'))));
    final tile = tester.widget<SideBarTile>(find.byType(SideBarTile));
    expect(tile.leading, isNull);
    expect(tile.live, isFalse);
  });

  test('a session on this device is a bar, whatever the marks', () {
    Stores.setting.showDistMark.put(true);
    final row = railRow(serverId: null, live: true, selected: true);
    expect(row.leading, isNull);
    expect(row.live, isTrue);
    expect(row.liveColor, isNull);
  });

  testWidgets('a badge sits on the corner of its mark', (tester) async {
    final mark = sideMark(
      mark: const Icon(Icons.dns, size: kSideMarkSize),
      badge: const SideMarkDot(color: Colors.orange),
    )!;
    await tester.pumpWidget(
      rail(SizedBox.square(dimension: kSideMarkSize, child: mark)),
    );
    expect(
      tester.getCenter(find.byType(SideMarkDot)).dx,
      greaterThan(tester.getCenter(find.byIcon(Icons.dns)).dx),
    );
  });
}
