/// The remote desktop page is two columns where there is room for two, and the
/// form is a page rather than a dialog in either layout.
///
/// Both were reported from a phone: the add form arrived as a modal with
/// Cupertino switches on iOS, and the list never had a second column at all.
/// Neither is visible in a `flutter test` that only checks the form's fields
/// exist — the first is *where* the form is and the second is *what widget*
/// draws a switch — so both are asserted here through the rendered tree.
library;

import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/remote_desktop.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/remote_desktop/profile_edit.dart';
import 'package:server_box/view/page/remote_desktop/profiles.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sid = 'srv-rdp-1';
  final spi = spiFixture(
    id: sid,
    name: 'web',
    ip: 'h',
    user: 'u',
    autoConnect: false,
  );
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-rdp-');
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<RemoteDesktopStore>(RemoteDesktopStore());
    Stores.server.put(spi);
    Stores.remoteDesktop.put(
      const RemoteDesktopProfile(
        id: 'rdp-1',
        serverId: sid,
        name: 'Windows',
        protocol: RemoteDesktopProtocol.rdp,
        host: '127.0.0.1',
        port: 3389,
        username: 'administrator',
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
    await tempDir.delete(recursive: true);
  });

  /// Pumps the page at [width], so a split layout can be asked for by number
  /// rather than by device.
  Future<void> pumpPage(WidgetTester tester, {required double width}) async {
    // The view, not `setSurfaceSize` — that changes layout without changing
    // what `MediaQuery` reports.
    tester.view.physicalSize = Size(width, 1600);
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
          home: RemoteDesktopProfilesPage(
            args: SpiRequiredArgs(Stores.server.fetch().single),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('a wide window puts the editor beside the list', (tester) async {
    await pumpPage(tester, width: 1200);

    // The rail is a `SideBarTile`, which is the narrow index every other pane
    // in this app uses.
    expect(find.byType(SideBarTile), findsOneWidget);
    expect(find.text('Windows'), findsOneWidget);
    // Nothing selected yet: the pane is empty rather than showing a form.
    expect(find.byType(RemoteDesktopProfileEditPage), findsNothing);

    await tester.tap(find.byType(SideBarTile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Beside the list, not over it: the rail is still on screen.
    expect(find.byType(RemoteDesktopProfileEditPage), findsOneWidget);
    expect(find.byType(SideBarTile), findsOneWidget);
  });

  testWidgets('a narrow window keeps the list and opens the editor over it', (
    tester,
  ) async {
    await pumpPage(tester, width: 500);

    expect(find.byType(SideBarTile), findsNothing);
    expect(find.byType(CardTile), findsOneWidget);

    await tester.tap(find.byType(CardTile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(RemoteDesktopProfileEditPage), findsOneWidget);
  });

  testWidgets('the form draws Material switches, not platform-adaptive ones', (
    tester,
  ) async {
    // On iOS is where the difference shows: a plain `SwitchListTile` draws a
    // Material switch on every platform, while `SwitchListTile.adaptive` draws
    // a `CupertinoSwitch` there — which is what made this form the only
    // Cupertino-looking one in an app that is Material on all of them.
    //
    // Cleared before the body ends rather than in a tear-down: the binding
    // checks that no foundation debug variable was left changed as the last
    // thing it does, which is before any tear-down runs.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpPage(tester, width: 1200);
      await tester.tap(find.byType(SideBarTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SwitchListTile), findsWidgets);
      expect(
        find.byType(CupertinoSwitch),
        findsNothing,
        reason: 'an adaptive switch is a Cupertino one on iOS',
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the form is not a dialog', (tester) async {
    await pumpPage(tester, width: 500);
    await tester.tap(find.byType(CardTile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AlertDialog), findsNothing);
    // A dialog would be on the root navigator, over the page; a page has a
    // bar of its own with the save action on it.
    expect(
      find.descendant(
        of: find.byType(RemoteDesktopProfileEditPage),
        matching: find.byTooltip(libL10n.save),
      ),
      findsOneWidget,
    );
  });
}
