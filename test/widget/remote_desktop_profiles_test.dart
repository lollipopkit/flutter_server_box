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
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/remote_desktop.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_zh.dart';
import 'package:server_box/view/page/remote_desktop/profile_edit.dart';
import 'package:server_box/view/page/remote_desktop/profiles.dart';
import 'package:server_box/view/page/remote_desktop/tab.dart';
import 'package:server_box/view/widget/group_title.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

class _FixedRemoteDesktopSessions extends RemoteDesktopSessions {
  _FixedRemoteDesktopSessions(this.initial);

  final RemoteDesktopSessionsState initial;

  @override
  RemoteDesktopSessionsState build() => initial;

  @override
  Future<void> close(String id) async => state = state.remove(id);
}

class _NoConnectRemoteDesktopSessions extends RemoteDesktopSessions {
  @override
  RemoteDesktopSessionsState build() => const RemoteDesktopSessionsState();

  @override
  Future<void> close(String id) async => state = state.remove(id);

  @override
  String open(
    RemoteDesktopProfile profile, {
    String? sessionPassword,
    int width = 1280,
    int height = 720,
    int scaleFactor = 100,
  }) {
    state = state
        .put(RemoteDesktopSessionView(profile: profile))
        .select(profile.id);
    return profile.id;
  }
}

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
  Future<void> pumpPage(
    WidgetTester tester, {
    required double width,
    Widget? home,
    Locale locale = const Locale('en'),
    RemoteDesktopSessionsState? sessions,
  }) async {
    // The view, not `setSurfaceSize` — that changes layout without changing
    // what `MediaQuery` reports.
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (sessions != null)
            remoteDesktopSessionsProvider.overrideWith(
              () => _FixedRemoteDesktopSessions(sessions),
            ),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home:
              home ??
              RemoteDesktopProfilesPage(
                args: SpiRequiredArgs(Stores.server.fetch().single),
              ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('the page title says the feature is in beta', (tester) async {
    await pumpPage(tester, width: 620);

    // Beside the title, not appended to it: the mark is the widget every other
    // beta feature carries, and it is *not* localized — the title reads
    // "Remote Desktop" in a locale whose word for it is elsewhere, and the
    // mark beside it still says Beta.
    expect(find.text('Beta'), findsOneWidget);
    final title = tester.getRect(find.text('Remote desktop'));
    final mark = tester.getRect(find.text('Beta'));
    expect(mark.left, greaterThan(title.right));
    expect(mark.center.dy, title.center.dy);
  });

  testWidgets('empty profiles and the editor use Chinese translations', (
    tester,
  ) async {
    final previous = app_locale.l10n;
    app_locale.l10n = AppLocalizationsZh();
    addTearDown(() => app_locale.l10n = previous);
    for (final profile in Stores.remoteDesktop.fetchForServer(sid)) {
      Stores.remoteDesktop.delete(profile);
    }
    await pumpPage(tester, width: 620, locale: const Locale('zh'));
    expect(find.text('暂无远程桌面配置'), findsOneWidget);
    await tester.tap(find.text('添加配置'));
    await tester.pumpAndSettle();
    expect(find.text('添加远程桌面'), findsOneWidget);
    expect(find.text('保存密码'), findsOneWidget);
    expect(find.text('域（可选）'), findsOneWidget);
    expect(find.text('Save password'), findsNothing);
  });

  testWidgets(
    'the remote desktop rail opens server profiles without a session',
    (tester) async {
      await pumpPage(tester, width: 834, home: const RemoteDesktopTabPage());

      expect(find.byType(SideBarTile), findsOneWidget);
      expect(find.byType(EmptyPane), findsOneWidget);
      expect(find.text(libL10n.running.toUpperCase()), findsNothing);

      await tester.tap(find.byType(SideBarTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(RemoteDesktopProfilesPage), findsOneWidget);
      expect(find.text('Windows'), findsOneWidget);
      expect(find.byType(SideBarTile), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, libL10n.edit));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(RemoteDesktopProfileEditPage), findsOneWidget);
      expect(find.byType(SideBarTile), findsOneWidget);
    },
  );

  testWidgets('the rail puts open sessions in a running group', (tester) async {
    final profile = Stores.remoteDesktop.fetchForServer(sid).single;
    final session = RemoteDesktopSessionView(profile: profile);
    await pumpPage(
      tester,
      width: 834,
      home: const RemoteDesktopTabPage(),
      sessions: RemoteDesktopSessionsState(sessions: {session.id: session}),
    );

    expect(find.text(libL10n.running.toUpperCase()), findsOneWidget);
    expect(find.text('Windows'), findsOneWidget);
    expect(find.byType(CustomAppBar), findsNothing);
    expect(
      tester.getTopLeft(find.text(libL10n.running.toUpperCase())).dy,
      lessThan(tester.getTopLeft(find.text('Windows')).dy),
    );
  });

  testWidgets('closing the active session keeps the server editor open', (
    tester,
  ) async {
    final profile = Stores.remoteDesktop.fetchForServer(sid).single;
    final other = profile.copyWith(id: 'rdp-2', name: 'Other');
    final sessions = RemoteDesktopSessionsState(
      sessions: {
        profile.id: RemoteDesktopSessionView(profile: profile),
        other.id: RemoteDesktopSessionView(profile: other),
      },
      activeId: profile.id,
    );
    await pumpPage(
      tester,
      width: 834,
      home: const RemoteDesktopTabPage(),
      sessions: sessions,
    );
    await tester.tap(find.text('web'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, libL10n.edit));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RemoteDesktopTabPage)),
    );
    await container
        .read(remoteDesktopSessionsProvider.notifier)
        .close(profile.id);
    await tester.pumpAndSettle();

    expect(container.read(remoteDesktopSessionsProvider).activeId, other.id);
    expect(find.byType(RemoteDesktopProfileEditPage), findsOneWidget);
  });

  testWidgets('switching servers slides the right pane', (tester) async {
    Stores.server.put(
      spiFixture(
        id: 'srv-other',
        name: 'other',
        ip: 'other',
        autoConnect: false,
      ),
    );
    await pumpPage(tester, width: 834, home: const RemoteDesktopTabPage());

    await tester.tap(find.text('web'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('other'));
    await tester.pump();
    expect(find.byType(RemoteDesktopProfilesPage), findsNWidgets(2));
    final incoming = find.widgetWithText(CustomAppBar, 'other');
    final startingX = tester.getTopLeft(incoming).dx;

    await tester.pumpAndSettle();
    expect(find.byType(RemoteDesktopProfilesPage), findsOneWidget);
    expect(tester.getTopLeft(incoming).dx, lessThan(startingX));
  });

  testWidgets('adding a profile slides the editor in the right pane', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpPage(tester, width: 834, home: const RemoteDesktopTabPage());
      await tester.tap(find.text('web'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(libL10n.add));
      await tester.pump();
      final editor = find.byType(RemoteDesktopProfileEditPage);
      expect(editor, findsOneWidget);
      final startingX = tester.getTopLeft(editor).dx;

      await tester.pumpAndSettle();
      final restingX = tester.getTopLeft(editor).dx;
      expect(restingX, lessThan(startingX));
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(editor).dx, greaterThan(restingX));
      await tester.pumpAndSettle();
      expect(editor, findsNothing);
      expect(find.text('Windows'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'a narrow remote desktop tab can pick a server without a session',
    (tester) async {
      await pumpPage(tester, width: 500, home: const RemoteDesktopTabPage());

      // The picker's cards, not the rail a wide window puts beside a surface.
      expect(find.byType(SideBarTile), findsNothing);
      expect(find.byType(CardTile), findsOneWidget);
      expect(find.byTooltip(libL10n.sort), findsOneWidget);
      await tester.tap(find.byType(CardTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(RemoteDesktopProfilesPage), findsOneWidget);
      expect(find.text('Windows'), findsOneWidget);
    },
  );

  testWidgets('the rail sorts servers and groups them by tag', (tester) async {
    Stores.server.put(
      spiFixture(
        id: 'srv-lower',
        name: 'aardvark',
        ip: 'lower',
        tags: ['prod'],
        autoConnect: false,
      ),
    );
    Stores.server.put(
      spiFixture(
        id: 'srv-alpha',
        name: 'Alpha',
        ip: 'alpha',
        tags: ['prod'],
        autoConnect: false,
      ),
    );
    Stores.server.put(
      spiFixture(
        id: 'srv-beta',
        name: 'Beta',
        ip: 'beta',
        tags: ['prod'],
        autoConnect: false,
      ),
    );
    await pumpPage(tester, width: 834, home: const RemoteDesktopTabPage());
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('PROD'), findsOneWidget);
    expect(find.text('SERVERS'), findsNothing);

    await tester.tap(find.byTooltip(libL10n.sort));
    await tester.pumpAndSettle();
    expect(find.byType(SheetChoiceTile), findsNWidgets(4));
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.tap(find.text('${libL10n.sortByName} (Z-A)'));
    await tester.pumpAndSettle();

    expect(find.text('PROD'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Beta')).dy,
      lessThan(tester.getTopLeft(find.text('Alpha')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Alpha')).dy,
      lessThan(tester.getTopLeft(find.text('aardvark')).dy),
    );
  });

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
    final incomingX = tester
        .getTopLeft(find.byType(RemoteDesktopProfileEditPage))
        .dx;
    await tester.pumpAndSettle();

    // Beside the list, not over it: the rail is still on screen.
    expect(find.byType(RemoteDesktopProfileEditPage), findsOneWidget);
    expect(find.byType(SideBarTile), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(RemoteDesktopProfileEditPage)).dx,
      lessThan(incomingX),
    );
  });

  testWidgets('a narrow window keeps the list and opens the editor over it', (
    tester,
  ) async {
    await pumpPage(tester, width: 320);

    expect(find.byType(SideBarTile), findsNothing);
    expect(find.byType(CardTile), findsOneWidget);

    expect(find.byTooltip('Connect'), findsOneWidget);
    expect(find.byTooltip(libL10n.edit), findsOneWidget);

    await tester.tap(find.byTooltip(libL10n.edit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(RemoteDesktopProfileEditPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile cards show connect and edit within a capped list', (
    tester,
  ) async {
    await pumpPage(
      tester,
      width: 1200,
      home: RemoteDesktopProfilesPage(
        args: SpiRequiredArgs(spi),
        onBack: () {},
      ),
    );

    expect(find.widgetWithText(TextButton, 'Connect'), findsOneWidget);
    expect(find.widgetWithText(TextButton, libL10n.edit), findsOneWidget);
    expect(tester.getSize(find.byType(CardTile)).width, lessThanOrEqualTo(620));

    await tester.tap(find.widgetWithText(TextButton, 'Connect'));
    await tester.pumpAndSettle();
    expect(find.text('RDP ${libL10n.pwd}'), findsOneWidget);
    expect(find.byType(RemoteDesktopProfileEditPage), findsNothing);
  });

  testWidgets('the form uses server editor sections and Material switches', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpPage(tester, width: 1200);
      await tester.tap(find.byType(SideBarTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(GroupTitle), findsNWidgets(3));
      expect(find.byType(SegmentedTabs<RemoteDesktopProtocol>), findsOneWidget);
      expect(find.byType(SegmentedButton<RemoteDesktopProtocol>), findsNothing);
      expect(find.byType(SwitchX), findsNWidgets(2));
      expect(find.byType(CupertinoSwitch), findsNothing);
      expect(find.byType(PageColumns), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.widgetWithText(FilledButton, libL10n.save), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Test'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the fl_lib protocol selector updates the default port', (
    tester,
  ) async {
    await pumpPage(tester, width: 1200);
    await tester.tap(find.byType(SideBarTile));
    await tester.pumpAndSettle();

    final port = find.byWidgetPredicate(
      (widget) => widget is Input && widget.label == libL10n.port,
    );
    expect(tester.widget<Input>(port).controller?.text, '3389');

    await tester.tap(find.text('VNC'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SegmentedTabs<RemoteDesktopProtocol>>(
            find.byType(SegmentedTabs<RemoteDesktopProtocol>),
          )
          .selected,
      RemoteDesktopProtocol.vnc,
    );
    expect(tester.widget<Input>(port).controller?.text, '5900');
    expect(find.text('Share session'), findsOneWidget);
    expect(find.text('Username'), findsNothing);
  });

  testWidgets('the form is not a dialog', (tester) async {
    await pumpPage(tester, width: 500);
    await tester.tap(find.widgetWithText(TextButton, libL10n.edit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AlertDialog), findsNothing);
    // The editor keeps Save in its own app bar.
    expect(
      find.descendant(
        of: find.byType(RemoteDesktopProfileEditPage),
        matching: find.widgetWithText(FilledButton, libL10n.save),
      ),
      findsOneWidget,
    );
  });

  testWidgets('connecting refuses a password that could not be sent', (
    tester,
  ) async {
    // Test authenticates with what is typed even when the save
    // switch is off, so it has to validate that password too. A VNC password
    // over eight bytes is refused by the server, which would present it as a
    // failed session rather than as the field that has to change.
    Stores.remoteDesktop.put(
      const RemoteDesktopProfile(
        id: 'vnc-1',
        serverId: sid,
        name: 'Screen',
        protocol: RemoteDesktopProtocol.vnc,
        host: '127.0.0.1',
        port: 5900,
      ),
    );
    await pumpPage(tester, width: 1200);
    await tester.tap(find.text('Screen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byType(TextField).last,
      'far-too-long-for-classic-vnc',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Test'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Still on the form, and no session was started for it — which is what the
    // refusal is for: the alternative is a session that opens and then fails at
    // authentication.
    expect(find.byType(RemoteDesktopProfileEditPage), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RemoteDesktopProfilesPage)),
    );
    expect(container.read(remoteDesktopSessionsProvider).sessions, isEmpty);
  });

  testWidgets('Test preserves unsaved edits through the password prompt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteDesktopSessionsProvider.overrideWith(
            _NoConnectRemoteDesktopSessions.new,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home: const RemoteDesktopTabPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('web'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, libL10n.edit));
    await tester.pumpAndSettle();
    final hostInput = find.byWidgetPredicate(
      (widget) => widget is Input && widget.label == libL10n.host,
    );
    await tester.enterText(
      find.descendant(of: hostInput, matching: find.byType(TextField)),
      '192.0.2.10',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Test'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'temporary-password',
    );
    await tester.tap(find.widgetWithText(TextButton, libL10n.ok));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(RemoteDesktopProfileEditPage), findsOneWidget);
    expect(tester.widget<Input>(hostInput).controller?.text, '192.0.2.10');
    expect(Stores.remoteDesktop.fetchOneRaw('rdp-1')?.host, '127.0.0.1');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RemoteDesktopTabPage)),
    );
    expect(
      container.read(remoteDesktopSessionsProvider).active?.profile.host,
      '192.0.2.10',
    );
  });
}
