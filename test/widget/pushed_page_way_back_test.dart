import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/store/bmc_credential.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/self_addr.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/server_dist.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/agent/settings.dart';
import 'package:server_box/view/page/backup.dart';
import 'package:server_box/view/page/bmc_credential/edit.dart';
import 'package:server_box/view/page/private_key/edit.dart';
import 'package:server_box/view/page/private_key/generate.dart';
import 'package:server_box/view/page/server/connection_stats.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/setting/entries/home_tabs.dart';
import 'package:server_box/view/page/setting/entries/keybindings.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:server_box/view/page/setting/platform/desktop.dart';
import 'package:server_box/view/page/setting/platform/ios.dart';
import 'package:server_box/view/page/setting/seq/known_hosts.dart';
import 'package:server_box/view/page/setting/seq/srv_detail_seq.dart';
import 'package:server_box/view/page/setting/seq/srv_func_seq.dart';
import 'package:server_box/view/page/setting/seq/srv_orders.dart';
import 'package:server_box/view/page/setting/seq/srv_seq.dart';
import 'package:server_box/view/page/setting/seq/virtual_key.dart';
import 'package:server_box/view/page/snippet/edit.dart';
import 'package:server_box/view/page/storage/local.dart';
import 'package:server_box/view/page/storage/transfer_list.dart';
import 'package:server_box/view/page/web_apps/detail.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

/// Every page a route pushes has a way back on screen, at any width and after
/// the window changes under it (#1886: settings opened narrow, then rotated
/// wide, had none).
///
/// A page that draws no bar of its own in some layout must decide by the
/// route it is on (`ModalRoute.canPopOf`), not by the width.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pages = <String, void Function(BuildContext)>{
    'AgentProvidersPage': (c) => AgentProvidersPage.route.go(c),
    'AgentSkillsPage': (c) => AgentSkillsPage.route.go(c),
    'AgentToolsPage': (c) => AgentToolsPage.route.go(c),
    'BackupPage': (c) => BackupPage.route.go(c),
    'BmcCredentialEditPage': (c) => BmcCredentialEditPage.route.go(c),
    'ConnectionStatsPage': (c) => ConnectionStatsPage.route.go(c),
    'DesktopSettingsPage': (c) => DesktopSettingsPage.route.go(c),
    'HomeTabsConfigPage': (c) => HomeTabsConfigPage.route.go(c),
    'IosSettingsPage': (c) => IosSettingsPage.route.go(c),
    'KeybindingsPage': (c) => KeybindingsPage.route.go(c),
    'KnownHostsPage': (c) => KnownHostsPage.route.go(c),
    'LocalFilePage': (c) => LocalFilePage.route.go(c),
    'PrivateKeyEditPage': (c) => PrivateKeyEditPage.route.go(c),
    'PrivateKeyGeneratePage': (c) => PrivateKeyGeneratePage.route.go(c),
    'SSHVirtualKeySettingPage': (c) => SSHVirtualKeySettingPage.route.go(c),
    'ServerDetailOrderPage': (c) => ServerDetailOrderPage.route.go(c),
    'ServerEditPage': (c) => ServerEditPage.route.go(c),
    'ServerFuncBtnsOrderPage': (c) => ServerFuncBtnsOrderPage.route.go(c),
    'ServerOrderPage': (c) => ServerOrderPage.route.go(c),
    'ServerOrdersPage': (c) => ServerOrdersPage.route.go(c),
    'SettingsPage': (c) => SettingsPage.route.go(c),
    'SnippetEditPage': (c) => SnippetEditPage.route.go(c),
    'TransferListPage': (c) => TransferListPage.route.go(c),
    'WebAppPage': (c) {
      Stores.server.put(spiFixture(id: 's', name: 'web', ip: 'h', user: 'u'));
      WebAppPage.route.go(
        c,
        args: const WebAppPageArgs(serverId: 's', appId: 'a'),
      );
    },
  };


  test('every route pushed without arguments is checked here', () {
    final declared = <String>{
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          for (final m in RegExp(
            r'static const route = AppRoute(?:NoArg)?(?:<[^>]*>)?\(\s*page: (\w+)\.new',
          ).allMatches(file.readAsStringSync()))
            m.group(1)!,
    };
    expect(declared, pages.keys.toSet());
  });

  setUpAll(() async {
    await initRustLibForTest();
    Paths.doc = Directory.systemTemp.createTempSync('server-box-way-back-').path;
  });

  tearDownAll(() => Directory(Paths.doc).deleteSync(recursive: true));

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<HistoryStore>(HistoryStore('history_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<ServerDistStore>(ServerDistStore());
    getIt.registerSingleton<ContainerStore>(ContainerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<SnippetStore>(SnippetStore());
    getIt.registerSingleton<BmcCredentialStore>(BmcCredentialStore());
    getIt.registerSingleton<ConnectionStatsStore>(ConnectionStatsStore.instance);
    getIt.registerSingleton<SelfAddrStore>(SelfAddrStore('self_addr_test'));
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder wayBack() => find.byTooltip(
    const DefaultMaterialLocalizations().backButtonTooltip,
  ).hitTestable();

  Future<void> push(
    WidgetTester tester,
    void Function(BuildContext) go,
    double width,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);
    // A fresh app, or the last one's navigator keeps its pushed page.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              ResponsivePoints.builder(context, child!),
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => go(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await frames(tester);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  for (final MapEntry(key: name, value: build) in pages.entries) {
    testWidgets('$name has a way back, narrow, wide and widened', (
      tester,
    ) async {
      await push(tester, build, 400);
      expect(wayBack(), findsOneWidget, reason: 'narrow');

      tester.view.physicalSize = const Size(1200, 900);
      await frames(tester);
      expect(wayBack(), findsOneWidget, reason: 'widened');

      await push(tester, build, 1200);
      expect(wayBack(), findsOneWidget, reason: 'wide');
    });
  }
}
