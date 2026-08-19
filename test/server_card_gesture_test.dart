import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/server/tab/tab.dart';

import 'helpers/spi_fixture.dart';

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
  late Box<dynamic> settingBox;
  late Box<dynamic> serverBox;
  late Box<dynamic> keyBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-card-');
    Hive.init(tempDir.path);
    // In memory: this page persists tags and order, and a real write started
    // in a `testWidgets` body never lets go of the box's lock.
    settingBox = await Hive.openBox<dynamic>('setting_test', bytes: Uint8List(0));
    serverBox = await Hive.openBox<dynamic>('server_test', bytes: Uint8List(0));
    keyBox = await Hive.openBox<dynamic>('key_test', bytes: Uint8List(0));
    getIt.registerSingleton<SettingStore>(SettingStore.forBox(settingBox));
    getIt.registerSingleton<ServerStore>(ServerStore.forBox(serverBox));
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore.forBox(keyBox));
    // No auto-refresh: 0 is what `normalizeServerStatusRefreshSeconds` reads
    // as off, and its periodic timer would otherwise outlive the tree and
    // fail the run on a pending timer.
    await Stores.setting.serverStatusUpdateInterval.put(0);
  });

  tearDown(() async {
    await getIt.reset();
    await settingBox.close();
    await serverBox.close();
    await keyBox.close();
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
    await Stores.server.put(
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
    await Stores.server.put(
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
