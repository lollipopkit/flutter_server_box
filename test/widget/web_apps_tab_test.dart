/// The Web apps tab over scripted lists: apps grouped by server, a server
/// without the feature left out, search, the empty state, and a tap asking
/// that server's agent for a way in.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_stack.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/web_apps.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/web_apps/detail.dart';
import 'package:server_box/view/page/web_apps/tab.dart';

import '../helpers/test_db.dart';

final _states = <String, WebAppsState>{};
final _entered = <String>[];

class _FakeApps extends WebAppsNotifier {
  @override
  WebAppsState build(String serverId) => _states[serverId] ?? const WebAppsState();

  @override
  Future<void> refresh() async {}

  @override
  Future<Uri?> enter(String id) async {
    _entered.add('$serverId/$id');
    return null;
  }
}

Spi _agent(String id, String name) => Spi(
  id: id,
  name: name,
  monitorHttp: MonitorHttpCredential(addr: 'https://$id:3770'),
);

MonitorWebApp _app(String id, String title, {String? health = 'healthy', bool proxy = true}) =>
    MonitorWebApp(id: id, title: {'en': title}, state: 'installed', health: health, proxy: proxy, version: '1');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    Stores.setting.serverStatusUpdateInterval.put(0);
    _states.clear();
    _entered.clear();
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  Future<void> pump(WidgetTester tester, {bool wide = false}) async {
    tester.view.physicalSize = wide ? const Size(1400, 900) : const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [webAppsProvider.overrideWith2((_) => _FakeApps())],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [...app_locale.appLocalizationsDelegates],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return const WebAppsTabPage();
            },
          ),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('lists each server\'s apps under its name and opens one', (tester) async {
    Stores.server.put(_agent('a', 'box-a'));
    Stores.server.put(_agent('b', 'box-b'));
    Stores.server.put(_agent('c', 'no-stacks'));
    _states['a'] = WebAppsState(offered: true, apps: [_app('futo.immich', 'Immich')]);
    _states['b'] = WebAppsState(
      offered: true,
      apps: [
        _app('jellyfin.jellyfin', 'Jellyfin', health: 'down'),
        _app('x.busy', 'Busy', health: null, proxy: false),
      ],
    );
    await pump(tester);

    expect(find.text('box-a'), findsOneWidget);
    expect(find.text('box-b'), findsOneWidget);
    expect(find.text('no-stacks'), findsNothing);
    expect(find.text('Immich'), findsOneWidget);
    expect(find.text('Jellyfin'), findsOneWidget);
    expect(find.text(app_locale.l10n.webAppDown), findsOneWidget);

    await tester.tap(find.text('Jellyfin'));
    await tester.pump();
    expect(_entered, ['b/jellyfin.jellyfin']);

    // Not behind the proxy: its page instead, saying why.
    await tester.tap(find.text('Busy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_entered, ['b/jellyfin.jellyfin']);
    expect(find.byType(WebAppPage), findsOneWidget);
    expect(find.text(app_locale.l10n.webAppVersion), findsOneWidget);
  });

  testWidgets('a wide window selects in the rail and opens from the page', (tester) async {
    Stores.server.put(_agent('a', 'box-a'));
    _states['a'] = WebAppsState(
      offered: true,
      apps: [
        MonitorWebApp(
          id: 'futo.immich',
          title: const {'en': 'Immich'},
          description: const {'en': 'Photos and videos'},
          state: 'installed',
          health: 'healthy',
          version: '1.0',
          latest: '1.1',
          proxy: true,
        ),
      ],
    );
    await pump(tester, wide: true);

    await tester.tap(find.text('Immich'));
    await tester.pump(const Duration(milliseconds: 500));
    // Selecting is not opening.
    expect(_entered, isEmpty);
    expect(find.text('Photos and videos'), findsOneWidget);
    expect(find.text(app_locale.l10n.webAppUpdate('1.1')), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, libL10n.open));
    await tester.pump();
    expect(_entered, ['a/futo.immich']);
  });

  testWidgets('says where apps come from when there are none', (tester) async {
    Stores.server.put(_agent('a', 'box-a'));
    _states['a'] = const WebAppsState(offered: true, apps: []);
    await pump(tester);
    expect(find.text(app_locale.l10n.webAppsEmpty), findsOneWidget);
  });
}
