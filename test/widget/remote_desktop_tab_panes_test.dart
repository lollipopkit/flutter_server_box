import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/remote_desktop.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/server_dist.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/remote_desktop/profiles.dart';
import 'package:server_box/view/page/remote_desktop/tab.dart';

import '../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<ServerDistStore>(ServerDistStore());
    getIt.registerSingleton<RemoteDesktopStore>(RemoteDesktopStore());

    const ssh = SshCredential(ip: '127.0.0.1', port: 22, user: 'test');
    Stores.server.put(const Spi(name: 'Zulu', id: 'zulu', ssh: ssh));
    Stores.server.put(const Spi(name: 'Available', id: 'available', ssh: ssh));
    Stores.server.put(
      const Spi(
        name: 'Monitor only',
        id: 'monitor',
        monitorHttp: MonitorHttpCredential(addr: 'https://example.test:3770'),
      ),
    );
    Stores.server.put(
      const Spi(
        name: 'SSH disabled',
        id: 'disabled',
        ssh: ssh,
        sshEnabled: false,
      ),
    );
    Stores.remoteDesktop.put(
      const RemoteDesktopProfile(
        id: 'office',
        serverId: 'available',
        name: 'Office',
        protocol: RemoteDesktopProtocol.rdp,
        host: '127.0.0.1',
        port: 3389,
        username: 'test',
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  Future<void> pumpTab(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return const RemoteDesktopTabPage();
            },
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('wide tab keeps the server pane before any session opens', (
    tester,
  ) async {
    await pumpTab(tester, 1200);

    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Zulu'), findsOneWidget);
    expect(find.text('Monitor only'), findsOneWidget);
    expect(find.text('SSH disabled'), findsNothing);
    expect(find.text('No remote desktop sessions'), findsOneWidget);

    await tester.tap(find.text('Available'));
    await tester.pump();

    expect(find.byType(RemoteDesktopProfilesPage), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Available'), findsWidgets);
  });

  testWidgets('narrow tab picks a server in one column', (tester) async {
    await pumpTab(tester, 500);

    expect(find.text('Available'), findsOneWidget);
    expect(find.text('SSH disabled'), findsNothing);
    await tester.tap(find.text('Available'));
    await tester.pump();

    expect(find.byType(RemoteDesktopProfilesPage), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);
  });

  testWidgets('narrow tab searches servers', (tester) async {
    await pumpTab(tester, 500);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'avail');
    await tester.pump();

    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Zulu'), findsNothing);
  });

  testWidgets('the pane searches servers and sorts them by name', (
    tester,
  ) async {
    await pumpTab(tester, 1200);

    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('By name (A-Z)'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.getTopLeft(find.text('Available')).dy,
      lessThan(tester.getTopLeft(find.text('Zulu')).dy),
    );

    await tester.tap(find.byTooltip('Search'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'avail');
    await tester.pump();
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Zulu'), findsNothing);
  });
}
