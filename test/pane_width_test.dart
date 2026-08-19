import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/provider/server/selection.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/tab/tab.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

/// How narrow the list column may be, held to what it actually lays out at.
///
/// The column opens at what dragging used to bottom out at, and dragging now
/// goes narrower still. Both numbers are only worth anything if what goes in
/// that column survives them — a row per server, and above them a bar with the
/// connection count and the tag filter side by side. A width picked by eye and
/// never rendered is how a layout ends up overflowing on a window nobody
/// opened during review, which is what the bar was doing: its leading was
/// sized to its own text, so the tags beside it had nothing left to shrink
/// into and the row ran past the column.
///
/// Overflow is an exception in a test rather than a stripe on the screen, so
/// most of this needs no assertion: a column that did not fit fails the pump.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-pane-');
    await openTestDb();
      // In memory: this tree writes as it builds, and a test has no
      // business leaving a database behind.
    getIt.registerSingleton<SettingStore>(SettingStore.forTest());
    getIt.registerSingleton<ServerStore>(ServerStore.forTest());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore.forTest());
    // 0 is what `normalizeServerStatusRefreshSeconds` reads as off; its
    // periodic timer would otherwise outlive the tree and fail the run.
    Stores.setting.serverStatusUpdateInterval.put(0);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  /// The server list with something already open beside it, in a column
  /// [width] wide.
  ///
  /// Selected from the first frame rather than by tapping a card. Tapping goes
  /// through the full-width grid, and that grid's subtree gets one last layout
  /// as it is torn down — a widget on its way out overflowing, which happens
  /// at the old default just the same and is not what this is about.
  Future<void> pumpSplitAt(WidgetTester tester, double width) async {
    // Sized on the view, because `MediaQuery` reports the view; a surface set
    // on its own lays a tablet out inside a phone's window.
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Stores.setting.paneListWidth.put(width);
    // A name past the column's width and two tags: the row has to elide the
    // one, and the bar above has to fit the other beside the connection count.
    Stores.server.put(
      spiFixture(
        id: 'srv-1',
        name: 'a server with a fairly long name',
        ip: 'h',
        user: 'u',
        tags: ['production', 'eu-west-1'],
        autoConnect: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [serverSelectionProvider.overrideWith(_Selected.new)],
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

    // Unmounted before the test ends: this page holds a periodic refresh
    // timer, and one still pending at teardown is an assertion failure.
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  /// What a caller gets when it names neither width — the numbers under test,
  /// read off the widget rather than copied here.
  const defaults = AdaptivePanes(primaryBuilder: _unused, detailBuilder: null);

  testWidgets('the width the column opens at fits what goes in it', (
    tester,
  ) async {
    await pumpSplitAt(tester, defaults.primaryWidth);

    expect(find.byType(SideBarTile), findsWidgets);
  });

  testWidgets('and so does the narrowest one dragging allows', (tester) async {
    // The number that matters most: every width above it is one the user
    // chose, and this is the one the app can be left in by dragging as far as
    // it goes.
    await pumpSplitAt(tester, defaults.minPrimaryWidth);

    expect(find.byType(SideBarTile), findsWidgets);
  });

  testWidgets('a long name elides in the grid rather than running past it', (
    tester,
  ) async {
    // Not about the column — this is the other layout, the one the list has
    // when nothing is open beside it — but it is the same mistake and it was
    // found looking for this one. The name already asked for an ellipsis; in
    // a row a text is handed its own intrinsic width, so it never got to use
    // it and pushed the row past the card instead.
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Stores.server.put(
      spiFixture(
        id: 'srv-1',
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

  test('a fresh install opens at a width dragging would allow', () {
    // The stored default and the widget's are two numbers in two packages. A
    // column that opened at one and was clamped to the other would move on its
    // own first frame.
    expect(Stores.setting.paneListWidth.fetch(), defaults.primaryWidth);
    expect(defaults.primaryWidth, greaterThanOrEqualTo(defaults.minPrimaryWidth));
    expect(defaults.primaryWidth, lessThanOrEqualTo(defaults.maxPrimaryWidth));
  });
}

/// The page's own selection, already made.
class _Selected extends ServerSelection {
  @override
  String? build() => 'srv-1';
}

Widget _unused(BuildContext context, bool split) => const SizedBox.shrink();
