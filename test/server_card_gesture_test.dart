import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/server/tab/tab.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

/// What a long press — and so a right-click — does to a server card.
///
/// The two are one callback (`tab.dart:272` passes `_onLongPressCard` to both),
/// and `fl_lib/test/secondary_tap_test.dart` covers the gesture. What is left
/// is the branch that callback takes, which depends on whether the server is
/// connected: a card with a status to show flips over to show it, and a card
/// with nothing behind it opens the page where that is fixed instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-card-');
    await openTestDb();
      // In memory: this tree writes as it builds, and a test has no
      // business leaving a database behind.
    getIt.registerSingleton<SettingStore>(SettingStore.forTest());
    getIt.registerSingleton<ServerStore>(ServerStore.forTest());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore.forTest());
    // No auto-refresh: 0 is what `normalizeServerStatusRefreshSeconds` reads
    // as off, and its periodic timer would otherwise outlive the tree and
    // fail the run on a pending timer.
    Stores.setting.serverStatusUpdateInterval.put(0);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          // Both sets, as `app.dart` does: this page reads `context.libL10n`,
          // which is `LibLocalizations.of(context)!` and throws without it.
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          // The same builder the app installs at its root: this page asks
          // `ResponsiveBreakpoints.of` for whether it is on a phone.
          builder: ResponsivePoints.builder,
          home: const ServerPage(),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Unmounted before the test ends: this page holds a periodic refresh
    // timer, and a timer still pending when the tree is torn down is an
    // assertion failure rather than a leak nobody notices.
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('a long press on a card with nothing behind it opens the edit page', (
    tester,
  ) async {
    // `_onLongPressCard` flips a card that has a status to show, and opens the
    // page where a broken server is fixed when it has not connected. A flip
    // would show the back of a card with nothing on it.
    //
    // `autoConnect: false`, so the server stays `ServerConn.disconnected` and
    // nothing here reaches for a socket.
    Stores.server.put(
      spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u', autoConnect: false),
    );

    await pump(tester);
    expect(find.text('web'), findsWidgets);

    await tester.longPress(find.text('web').first);
    await tester.pumpAndSettle();

    // The edit page — the navigation the callback performs.
    expect(find.byType(ServerEditPage), findsOneWidget);
  });

  testWidgets('and a right-click does the same, being the same callback', (
    tester,
  ) async {
    // `tab.dart:272` passes `asSecondary(() => _onLongPressCard(srv))` beside
    // the `onLongPress` that gets the same call. The gesture itself is
    // `fl_lib/test/secondary_tap_test.dart`; this is that they agree.
    Stores.server.put(
      spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u', autoConnect: false),
    );

    await pump(tester);

    final at = tester.getCenter(find.text('web').first);
    final gesture = await tester.startGesture(at, buttons: kSecondaryButton);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(ServerEditPage), findsOneWidget);
  });
}
