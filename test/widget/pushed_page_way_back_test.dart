import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/monitor/http.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';
import 'package:server_box/data/model/server/benchmark/yabs_options.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor/monitor_push.dart';
import 'package:server_box/data/model/server/monitor/monitor_settings.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/store/benchmark.dart';
import 'package:server_box/data/store/bmc_credential.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/port_forward.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/self_addr.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/server_dist.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/terminal/terminal_session.dart';
import 'package:server_box/data/terminal/terminal_source.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/src/rust/api/users.dart';
import 'package:server_box/view/page/agent/settings.dart';
import 'package:server_box/view/page/backup.dart';
import 'package:server_box/view/page/benchmark/result.dart';
import 'package:server_box/view/page/bmc_credential/edit.dart';
import 'package:server_box/view/page/container/container.dart';
import 'package:server_box/view/page/firewall/firewall.dart';
import 'package:server_box/view/page/iperf.dart';
import 'package:server_box/view/page/port_forward.dart';
import 'package:server_box/view/page/private_key/edit.dart';
import 'package:server_box/view/page/private_key/generate.dart';
import 'package:server_box/view/page/process/process.dart';
import 'package:server_box/view/page/scheduled_tasks/scheduled_tasks.dart';
import 'package:server_box/view/page/server/connection_stats.dart';
import 'package:server_box/view/page/server/custom_cmds.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/server/monitor_settings/agent_permissions.dart';
import 'package:server_box/view/page/server/monitor_settings/lists.dart';
import 'package:server_box/view/page/server/monitor_settings/page.dart';
import 'package:server_box/view/page/server/monitor_settings/push_edit.dart';
import 'package:server_box/view/page/services/detail.dart';
import 'package:server_box/view/page/services/services.dart';
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
import 'package:server_box/view/page/shares/page.dart';
import 'package:server_box/view/page/snippet/edit.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/page/ssh/snippet_run.dart';
import 'package:server_box/view/page/ssh/text_view.dart';
import 'package:server_box/view/page/storage/local.dart';
import 'package:server_box/view/page/storage/server_file.dart';
import 'package:server_box/view/page/storage/sftp.dart';
import 'package:server_box/view/page/storage/transfer_list.dart';
import 'package:server_box/view/page/storage_admin/page.dart';
import 'package:server_box/view/page/users/group_detail.dart';
import 'package:server_box/view/page/users/user_detail.dart';
import 'package:server_box/view/page/users/users.dart';
import 'package:server_box/view/page/virt/guest.dart';
import 'package:server_box/view/page/virt/hardware.dart';
import 'package:server_box/view/page/virt/resources.dart';
import 'package:server_box/view/page/web_apps/detail.dart';
import 'package:xterm/core.dart';

import '../helpers/fake_shell.dart';
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

  final spi = spiFixture(id: 's', name: 'web', ip: 'h', user: 'u');

  /// [spi], saved: most pages over a server look it up by id.
  Spi stored() {
    Stores.server.put(spi);
    return spi;
  }

  SpiRequiredArgs onServer() => SpiRequiredArgs(stored());

  MonitorHttpClient monitor() {
    final client = MonitorHttpClient(
      MonitorHttpCredential(addr: 'http://127.0.0.1:9', pwd: 'p'),
    );
    addTearDown(client.dispose);
    return client;
  }

  const user = SystemUser(
    name: 'u',
    uid: 1000,
    gid: 1000,
    comment: '',
    home: '/home/u',
    shell: '/bin/sh',
    primaryGroup: 'u',
    supplementaryGroups: [],
  );
  const group = SystemGroup(
    name: 'u',
    gid: 1000,
    members: [],
    primaryMembers: ['u'],
    local: true,
  );
  const catalog = UserCatalog(
    currentUser: 'u',
    uidMin: 1000,
    gidMin: 1000,
    users: [user],
    groups: [group],
  );
  Future<bool> unchanged(Object _) async => false;

  const pushEntry = MonitorPushEntry(
    name: 'phone',
    pushType: 'bark',
    config: {'key': null, 'server': 'https://api.day.app'},
    fromIndex: 0,
  );

  final pages = <String, void Function(BuildContext)>{
    'AgentProvidersPage': (c) => AgentProvidersPage.route.go(c),
    'AgentSkillsPage': (c) => AgentSkillsPage.route.go(c),
    'AgentToolsPage': (c) => AgentToolsPage.route.go(c),
    'BackupPage': (c) => BackupPage.route.go(c),
    'BenchmarkResultPage': (c) => BenchmarkResultPage.route.go(
      c,
      BenchmarkRun(
        id: 'b',
        serverId: stored().id,
        startedAt: DateTime(2026),
        finishedAt: DateTime(2026),
        status: BenchmarkStatus.completed,
        options: const YabsOptions(),
        runDir: '/tmp/b',
        exitCode: 0,
      ),
    ),
    'BmcCredentialEditPage': (c) => BmcCredentialEditPage.route.go(c),
    'ConnectionStatsPage': (c) => ConnectionStatsPage.route.go(c),
    'ContainerPage': (c) => ContainerPage.route.go(c, onServer()),
    'CustomCmdsPage': (c) => CustomCmdsPage.route.go(c, onServer()),
    'DesktopSettingsPage': (c) => DesktopSettingsPage.route.go(c),
    'FirewallPage': (c) => FirewallPage.route.go(c, onServer()),
    'GroupDetailPage': (c) => GroupDetailPage.route.go(
      c,
      GroupDetailPageArgs(
        spi: stored(),
        group: group,
        catalog: catalog,
        onEdit: unchanged,
        onDelete: unchanged,
      ),
    ),
    'HomeTabsConfigPage': (c) => HomeTabsConfigPage.route.go(c),
    'IPerfPage': (c) => IPerfPage.route.go(c, onServer()),
    'IosSettingsPage': (c) => IosSettingsPage.route.go(c),
    'KeybindingsPage': (c) => KeybindingsPage.route.go(c),
    'KnownHostsPage': (c) => KnownHostsPage.route.go(c),
    'LocalFilePage': (c) => LocalFilePage.route.go(c),
    'MonitorAgentPermissionsPage': (c) => MonitorAgentPermissionsPage.route.go(
      c,
      MonitorHttpCredential(addr: 'http://127.0.0.1:9', pwd: 'p'),
    ),
    'MonitorCorsPage': (c) => MonitorCorsPage.route.go(
      c,
      MonitorCorsArgs(origins: const [], onChanged: (_) {}),
    ),
    'MonitorPushEditPage': (c) => MonitorPushEditPage.route.go(
      c,
      MonitorPushEditArgs(
        entry: pushEntry,
        pushTypes: const ['bark'],
        client: monitor(),
      ),
    ),
    'MonitorPushListPage': (c) {
      final rate = TextEditingController();
      addTearDown(rate.dispose);
      MonitorPushListPage.route.go(
        c,
        MonitorPushListArgs(
          pushes: const [pushEntry],
          push: const MonitorPushList(pushTypes: ['bark']),
          rateCtrl: rate,
          client: monitor(),
          onChanged: (_) {},
        ),
      );
    },
    'MonitorRulesPage': (c) => MonitorRulesPage.route.go(
      c,
      MonitorRulesArgs(
        rules: const [],
        settings: const MonitorSettings(intervalSeconds: 7),
        onChanged: (_) {},
      ),
    ),
    'MonitorSettingsPage': (c) => MonitorSettingsPage.route.go(
      c,
      MonitorSettingsArgs(
        monitor: MonitorHttpCredential(addr: 'http://127.0.0.1:9', pwd: 'p'),
        subtitle: 'web',
      ),
    ),
    'PortForwardPage': (c) {
      // The first-run notice is a dialog over the page, not the page.
      Stores.setting.portForwardBetaWarned.put(true);
      PortForwardPage.route.go(c, onServer());
    },
    'PrivateKeyEditPage': (c) => PrivateKeyEditPage.route.go(c),
    'PrivateKeyGeneratePage': (c) => PrivateKeyGeneratePage.route.go(c),
    'ProcessPage': (c) => ProcessPage.route.go(c, onServer()),
    'SSHPage': (c) {
      Stores.setting.sshTermHelpShown.put(true);
      final session = TerminalSession(
        source: ServerSource(stored()),
        backend: FakeShellBackend(),
      )..bindForeground(FakeShellSession());
      addTearDown(session.close);
      SSHPage.route.go(
        c,
        SshPageArgs(source: session.source, session: session),
      );
    },
    'SSHVirtualKeySettingPage': (c) => SSHVirtualKeySettingPage.route.go(c),
    'ScheduledTasksPage': (c) =>
        ScheduledTasksPage.route.go(c, onServer()),
    'ServerDetailOrderPage': (c) => ServerDetailOrderPage.route.go(c),
    'ServerDetailPage': (c) => ServerDetailPage.route.go(c, onServer()),
    'ServerEditPage': (c) => ServerEditPage.route.go(c),
    'ServerFilePage': (c) =>
        ServerFilePage.route.go(c, SftpPageArgs(spi: stored())),
    'ServerFuncBtnsOrderPage': (c) => ServerFuncBtnsOrderPage.route.go(c),
    'ServerOrderPage': (c) => ServerOrderPage.route.go(c),
    'ServerOrdersPage': (c) => ServerOrdersPage.route.go(c),
    'ServiceDetailPage': (c) => ServiceDetailPage.route.go(
      c,
      ServiceDetailPageArgs(spi: stored(), unitKey: 'sshd.service'),
    ),
    'ServicesPage': (c) => ServicesPage.route.go(c, onServer()),
    'SettingsSectionPage': (c) =>
        SettingsSectionPage.route.go(c, SettingsSection.app),
    'SftpPage': (c) => SftpPage.route.go(c, SftpPageArgs(spi: stored())),
    'SharesPage': (c) => SharesPage.route.go(c, onServer()),
    'SnippetEditPage': (c) => SnippetEditPage.route.go(c),
    'SnippetRunPage': (c) => SnippetRunPage.route.go(
      c,
      SnippetRunPageArgs(
        spi: stored(),
        snippet: const Snippet(id: 'n', name: 'n', script: 'true'),
      ),
    ),
    'StoragePage': (c) => StoragePage.route.go(c, onServer()),
    'TerminalTextPage': (c) =>
        TerminalTextPage.route.go(c, Terminal()..write('text')),
    'TransferListPage': (c) => TransferListPage.route.go(c),
    'UserDetailPage': (c) => UserDetailPage.route.go(
      c,
      UserDetailPageArgs(
        spi: stored(),
        user: user,
        catalog: catalog,
        onEdit: unchanged,
        onDelete: unchanged,
      ),
    ),
    'UsersPage': (c) => UsersPage.route.go(c, onServer()),
    'VirtBackupJobPage': (c) => VirtBackupJobPage.route.go(
      c,
      VirtBackupJobArgs(serverId: stored().id),
    ),
    'VirtCreatePage': (c) =>
        VirtCreatePage.route.go(c, VirtCreateArgs(serverId: stored().id)),
    'VirtGuestPage': (c) => VirtGuestPage.route.go(
      c,
      VirtGuestArgs(serverId: stored().id, guestId: 'qemu/100'),
    ),
    'VirtNetworkPage': (c) => VirtNetworkPage.route.go(
      c,
      VirtResourceArgs(serverId: stored().id, id: 'pve/vmbr0'),
    ),
    'VirtPoolPage': (c) => VirtPoolPage.route.go(
      c,
      VirtResourceArgs(serverId: stored().id, id: 'pve/local'),
    ),
    'VirtResourceCreatePage': (c) => VirtResourceCreatePage.route.go(
      c,
      VirtResourceCreateArgs(serverId: stored().id, network: false),
    ),
    'WebAppPage': (c) {
      stored();
      WebAppPage.route.go(
        c,
        args: const WebAppPageArgs(serverId: 's', appId: 'a'),
      );
    },
  };

  /// Pages a widget test cannot push, and why.
  final excused = <String, String>{};

  test('every route is checked here or excused', () {
    final declared = <String>{
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          for (final m in RegExp(
            r'static const route = AppRoute(?:NoArg|Arg)?(?:<[^>]*>)?\(\s*page: (\w+)\.new',
          ).allMatches(file.readAsStringSync()))
            m.group(1)!,
    };
    expect(declared, {...pages.keys, ...excused.keys});
    expect(pages.keys.toSet().intersection(excused.keys.toSet()), isEmpty);
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
    getIt.registerSingleton<PortForwardStore>(PortForwardStore());
    getIt.registerSingleton<PveStore>(PveStore());
    getIt.registerSingleton<BenchmarkStore>(BenchmarkStore());
    // A terminal holds the screen on while it is shown.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (_) async => const StandardMessageCodec().encodeMessage(<Object?>[]),
        );
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
        overrides: [serverProvider(spi.id).overrideWith(_OfflineServer.new)],
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

      // What the pages left running stops with them.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 5));
    });
  }
}

/// A server that never connects: a widget test runs in fake async, where a
/// real socket's connect timeout is left pending.
class _OfflineServer extends ServerNotifier {
  @override
  Future<CommandExec> ensureExec({VoidCallback? onSshDial}) async =>
      throw StateError('offline');

  @override
  Future<CommandExec> ensureScriptExec({VoidCallback? onSshDial}) async =>
      throw StateError('offline');

  @override
  Future<SSHClient> ensureShellClient({VoidCallback? onDial}) async =>
      throw StateError('offline');
}
