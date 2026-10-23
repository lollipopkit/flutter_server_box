/// The Monitor tab over scripted agents: the overview's versions, alerts and
/// shortcuts, the web apps (updates first, a tap asking for a way in), the
/// notifications in this app's words, the audit log by kind, ending a session,
/// what an agent too old for a section says, and how to update an agent.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_access.dart';
import 'package:server_box/data/model/server/monitor_capabilities.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_overview.dart';
import 'package:server_box/data/model/server/monitor_stack.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/monitor_release.dart';
import 'package:server_box/data/provider/server/monitor_overview.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/server/web_apps.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/src/rust/api/script.dart' as rust;
import 'package:server_box/view/page/monitor/tab.dart';
import 'package:server_box/view/page/web_apps/detail.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

const _allFeatures = {'stacks', 'desk', 'alerts', 'audit', 'live'};

final _versions = <String, String>{};
final _features = <String, Set<String>>{};
final _apps = <String, WebAppsState>{};
final _overviews = <String, MonitorOverviewState>{};
final _audits = <String, List<MonitorAuditEntry>>{};
final _lives = <String, MonitorLive>{};
final _calls = <String>[];

/// Agents whose sign-in failed, with why.
final _failed = <String, Err>{};

class _FakeServer extends ServerNotifier {
  @override
  ServerState build(String id) {
    final spi = Stores.server.fetch().firstWhere((s) => s.id == id);
    if (_failed[id] case final err?) {
      return ServerState(spi: spi, status: InitStatus.status..err = err, conn: ServerConn.failed);
    }
    return _reached(spi);
  }

  ServerState _reached(Spi spi) => ServerState(
    spi: spi,
    status: InitStatus.status,
    conn: ServerConn.finished,
    agentCapabilities: MonitorCapabilities(
      access: MonitorAccess.granted,
      features: _features[spi.id] ?? _allFeatures,
      version: _versions[spi.id] ?? '0.3.0',
    ),
  );
}

class _FakeApps extends WebAppsNotifier {
  @override
  WebAppsState build(String serverId) => _apps[serverId] ?? const WebAppsState();

  @override
  Future<void> refresh() async {}

  @override
  Future<Uri?> enter(String id) async {
    _calls.add('enter $serverId/$id');
    return null;
  }
}

class _FakeOverview extends MonitorOverviewNotifier {
  @override
  MonitorOverviewState build(String serverId) =>
      _overviews[serverId] ??
      MonitorOverviewState(
        features: (_features[serverId] ?? _allFeatures).intersection(MonitorOverviewNotifier.watched),
      );

  @override
  Future<void> refresh() async {}

  @override
  Future<void> markRead({List<int> ids = const [], bool all = false}) async =>
      _calls.add('read $serverId ${all ? 'all' : ids.join(',')}');

  @override
  Future<MonitorAuditPage> audit({int? before, String? kind, String? result}) async {
    _calls.add('audit $serverId ${kind ?? '-'}');
    return MonitorAuditPage(
      entries: [
        for (final e in _audits[serverId] ?? const <MonitorAuditEntry>[])
          if (kind == null || e.kind == kind) e,
      ],
    );
  }

  @override
  Future<MonitorLive> live() async => _lives[serverId] ?? const MonitorLive();

  @override
  Future<void> endSession(String id) async => _calls.add('end session $id');

  @override
  Future<void> forgetDevice(int id) async => _calls.add('forget device $id');
}

Spi _agent(String id, String name) => Spi(
  id: id,
  name: name,
  monitorHttp: MonitorHttpCredential(addr: 'https://$id:3770'),
);

MonitorWebApp _app(String id, String title, {String? health = 'healthy', bool proxy = true, String? latest}) =>
    MonitorWebApp(
      id: id,
      title: {'en': title},
      state: 'installed',
      health: health,
      proxy: proxy,
      version: '1',
      latest: latest ?? '1',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initRustLibForTest);

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    Stores.setting.serverStatusUpdateInterval.put(0);
    for (final map in <Map>[_versions, _features, _apps, _overviews, _audits, _lives, _failed]) {
      map.clear();
    }
    _calls.clear();
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
      overrides: [
        serverProvider.overrideWith2((_) => _FakeServer()),
        webAppsProvider.overrideWith2((_) => _FakeApps()),
        monitorOverviewProvider.overrideWith2((_) => _FakeOverview()),
        monitorLatestReleaseProvider.overrideWith((_) async => '0.3.0'),
      ],
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
              // A tab sits in the home page's `Scaffold`, whose Material
              // the rail's buttons draw their ink on.
              return const Scaffold(body: MonitorTabPage());
            },
          ),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The section switcher on the bar, then the section in its sheet.
  Future<void> section(WidgetTester tester, MonitorSection to) async {
    await tester.tap(find.byType(SessionSwitcherLabel));
    // The sheet slides up from below the screen.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.widgetWithText(SheetChoiceTile, to.label));
    // And slides away again.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('the overview says which agent is behind, what fires, and leads on', (tester) async {
    Stores.server.put(_agent('a', 'box-a'));
    Stores.server.put(_agent('b', 'box-b'));
    _versions['a'] = '0.2.0';
    _overviews['a'] = MonitorOverviewState(
      features: MonitorOverviewNotifier.watched,
      alerts: MonitorAlerts(
        checkedAt: DateTime.now(),
        alerts: [
          MonitorAlert(
            rule: 'High CPU',
            monitorType: 'cpu',
            matcher: '>',
            threshold: '90%',
            value: '95.00%',
            since: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
        ],
      ),
      notices: const MonitorNotices(
        notices: [MonitorNotice(id: 1, level: 'warning', source: 'alert', subject: 'High CPU', body: 'x', read: false)],
        unread: 1,
      ),
    );
    _overviews['b'] = MonitorOverviewState(
      features: MonitorOverviewNotifier.watched,
      alerts: const MonitorAlerts(alerts: []),
      notices: const MonitorNotices(),
    );
    await pump(tester);

    expect(find.text('box-a'), findsOneWidget);
    expect(find.text('High CPU'), findsOneWidget);
    expect(find.textContaining('95.00% > 90%'), findsOneWidget);
    // box-b runs the newest: only box-a is offered one.
    expect(find.textContaining(app_locale.l10n.monitorAgentUpdate('0.3.0')), findsOneWidget);
    expect(find.text(app_locale.l10n.monitorAlertsNone), findsOneWidget);

    await tester.tap(find.text(app_locale.l10n.monitorUnread(1)));
    // The section crosses over (`SwapSwitcher`): started, then done.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // The notifications of that server.
    expect(find.text(app_locale.l10n.monitorNotices), findsWidgets);
    expect(find.text('High CPU'), findsOneWidget);
    await tester.tap(find.text('High CPU'));
    await tester.pump();
    expect(_calls, ['read a 1']);
  });

  testWidgets('web apps: an update first, the filter, and a tap asking for a way in', (tester) async {
    Stores.server.put(_agent('a', 'box-a'));
    Stores.server.put(_agent('c', 'no-stacks'));
    _features['c'] = {'desk'};
    _apps['a'] = WebAppsState(
      offered: true,
      apps: [
        _app('futo.immich', 'Immich'),
        _app('jellyfin.jellyfin', 'Jellyfin', latest: '2'),
        _app('x.busy', 'Busy', health: null, proxy: false),
      ],
    );
    await pump(tester);
    await section(tester, MonitorSection.apps);

    expect(find.text('no-stacks'), findsNothing);
    final top = tester.getTopLeft(find.text('Jellyfin')).dy;
    expect(top, lessThan(tester.getTopLeft(find.text('Immich')).dy));
    expect(find.textContaining('1 → 2'), findsOneWidget);

    await tester.tap(find.text('Jellyfin'));
    await tester.pump();
    expect(_calls, ['enter a/jellyfin.jellyfin']);

    await tester.tap(find.byTooltip(app_locale.l10n.monitorUpdatesOnly));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Immich'), findsNothing);
    expect(find.text('Jellyfin'), findsOneWidget);

    // Not behind the proxy: its page instead, saying why.
    await tester.tap(find.byTooltip(app_locale.l10n.monitorUpdatesOnly));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Busy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(WebAppPage), findsOneWidget);
  });

  testWidgets('a notification the agent words by kind is in this app\'s words', (tester) async {
    Stores.server.put(_agent('a', 'box-a'));
    _overviews['a'] = MonitorOverviewState(
      features: MonitorOverviewNotifier.watched,
      notices: const MonitorNotices(
        notices: [
          MonitorNotice(
            id: 7,
            level: 'error',
            source: 'stack',
            subject: 'Immich is down',
            body: 'english',
            read: true,
            kind: 'stack.down',
            params: {
              'titles': {'en': 'Immich'},
              'services': ['server', 'redis'],
            },
          ),
        ],
      ),
    );
    await pump(tester);
    await section(tester, MonitorSection.notices);
    expect(find.text(app_locale.l10n.noticeStackDown('Immich')), findsOneWidget);
    expect(find.textContaining(app_locale.l10n.noticeStackDownBody('server, redis')), findsOneWidget);
    expect(find.text('english'), findsNothing);
  });

  testWidgets('the audit log reads one server, by kind', (tester) async {
    Stores.server.put(_agent('a', 'box-a'));
    _audits['a'] = const [
      MonitorAuditEntry(id: 2, kind: 'login', action: 'denied', result: 'denied', remoteIp: '203.0.113.7', detail: 'wrong password'),
      MonitorAuditEntry(id: 1, kind: 'exec', action: 'open', result: 'ok', subject: 'uptime'),
    ];
    await pump(tester);
    await section(tester, MonitorSection.audit);
    expect(_calls, ['audit a -']);
    expect(find.textContaining('203.0.113.7'), findsOneWidget);
    expect(find.textContaining('uptime'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, libL10n.login));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_calls.last, 'audit a login');
    expect(find.textContaining('uptime'), findsNothing);
  });

  testWidgets('a session is ended and a device forgotten after asking', (tester) async {
    Stores.server.put(_agent('a', 'box-a'));
    _lives['a'] = const MonitorLive(
      sessions: [MonitorLiveSession(id: 's1', what: 'tmux main', attached: false, remoteIp: '192.0.2.4')],
      devices: [MonitorLoginDevice(id: 3, label: 'ServerBox on ios (phone)')],
    );
    await pump(tester);
    await section(tester, MonitorSection.live);
    expect(find.text('tmux main'), findsOneWidget);
    expect(find.text('ServerBox on ios (phone)'), findsOneWidget);
    expect(find.text(app_locale.l10n.monitorLiveDevicesTip), findsOneWidget);

    await tester.tap(find.byTooltip(app_locale.l10n.monitorLiveEnd));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(app_locale.l10n.monitorLiveEndSessionConfirm('tmux main')), findsOneWidget);
    await tester.tap(find.text(libL10n.ok));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_calls, ['end session s1']);

    await tester.tap(find.byTooltip(app_locale.l10n.monitorLiveForget));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(libL10n.cancel));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_calls, ['end session s1']);
  });

  testWidgets('an agent too old for a section says so', (tester) async {
    Stores.server.put(_agent('a', 'box-a'));
    _features['a'] = {'stacks'};
    await pump(tester);
    expect(find.text(app_locale.l10n.monitorAlertsNotOffered), findsOneWidget);
    await section(tester, MonitorSection.audit);
    expect(find.text(app_locale.l10n.monitorNotOffered), findsOneWidget);
  });

  testWidgets('an agent too old to sign in to, or behind, says how to update it', (tester) async {
    Stores.server.put(_agent('a', 'old'));
    Stores.server.put(_agent('b', 'behind'));
    _failed['a'] = MonitorHttpErr(
      type: MonitorHttpErrType.agentTooOld,
      message: 'too old',
    );
    _versions['b'] = '0.2.0';
    await pump(tester);

    expect(find.text('too old'), findsOneWidget);
    // The tip points at this tab: not repeated on it.
    expect(find.textContaining(app_locale.l10n.monitorAgentTooOldTip), findsNothing);
    await tester.tap(find.text(app_locale.l10n.monitorHowToUpdate));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(app_locale.l10n.monitorAgentTooOldBody), findsOneWidget);
    // No SSH to it: the agent starts the update itself, signed in to with the
    // account name it still asks for; no terminal, which its restart would end.
    expect(find.text(app_locale.l10n.monitorUpdateAgentHint), findsOneWidget);
    expect(find.text(app_locale.l10n.monitorUpdateLegacyHint), findsOneWidget);
    expect(find.widgetWithText(TextField, 'admin'), findsOneWidget);
    expect(find.text(app_locale.l10n.monitorUpdateNow), findsOneWidget);
    expect(find.text(app_locale.l10n.monitorUpdateInTerminal), findsNothing);
    await tester.tap(find.text(libL10n.close));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text(app_locale.l10n.monitorAgentUpdate('0.3.0')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(app_locale.l10n.monitorAgentOutdatedBody('0.3.0', '0.2.0')), findsOneWidget);
    // Too old to start it, and no SSH: the command, to run there.
    expect(find.text(rust.monitorUpgradeCommand()), findsOneWidget);
    expect(find.text(app_locale.l10n.monitorUpdateNoSsh), findsOneWidget);
    expect(find.text(app_locale.l10n.monitorUpdateNow), findsNothing);
  });

  testWidgets("an agent's own answer says how it is updated, and it runs the update", (tester) async {
    Stores.server.put(_agent('c', 'docker'));
    Stores.server.put(_agent('d', 'script'));
    _overviews['c'] = MonitorOverviewState(
      features: MonitorOverviewNotifier.watched,
      update: const MonitorUpdate(version: '0.3.0', latest: '0.5.0', outdated: true, install: MonitorInstall.container),
    );
    _overviews['d'] = MonitorOverviewState(
      features: MonitorOverviewNotifier.watched,
      update: const MonitorUpdate(
        version: '0.3.0',
        latest: '0.4.0',
        outdated: true,
        install: MonitorInstall.script,
        command: 'agent-upgrade-command',
      ),
    );
    await pump(tester);

    // Newer than this app's read (0.3.0): the agent's answer wins.
    await tester.tap(find.text(app_locale.l10n.monitorAgentUpdate('0.5.0')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(app_locale.l10n.monitorUpdateDocker), findsOneWidget);
    expect(find.text(rust.monitorUpgradeCommand()), findsNothing);
    expect(find.text(app_locale.l10n.monitorUpdateNow), findsNothing);
    await tester.tap(find.text(libL10n.close));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text(app_locale.l10n.monitorAgentUpdate('0.4.0')));
    await tester.pump(const Duration(milliseconds: 500));
    // Installed by the script and signed in: the agent runs it.
    expect(find.text(app_locale.l10n.monitorUpdateAgentHint), findsOneWidget);
    expect(find.text(app_locale.l10n.monitorUpdateNow), findsOneWidget);
    expect(find.text(app_locale.l10n.monitorUpdateSudoPassword), findsNothing);
    expect(find.text(app_locale.l10n.monitorUpdateDocker), findsNothing);
  });

  testWidgets('a wide window has the sections and servers in a rail, with counts', (tester) async {
    Stores.server.put(_agent('a', 'box-a'));
    Stores.server.put(_agent('b', 'box-b'));
    _overviews['a'] = MonitorOverviewState(
      features: MonitorOverviewNotifier.watched,
      alerts: const MonitorAlerts(),
      notices: const MonitorNotices(unread: 4),
    );
    _audits['b'] = const [MonitorAuditEntry(id: 1, kind: 'exec', action: 'open', result: 'ok', subject: 'df -h')];
    await pump(tester, wide: true);
    // On the rail's Notifications, and the overview's count.
    expect(find.descendant(of: find.byType(SideBarTile), matching: find.text('4')), findsOneWidget);

    await tester.tap(find.widgetWithText(SideBarTile, 'box-b'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(SideBarTile, MonitorSection.audit.label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_calls, ['audit b -']);
    expect(find.textContaining('df -h'), findsOneWidget);
  });

  testWidgets('says how to get an agent when there is none', (tester) async {
    Stores.server.put(spiFixture(id: 'x', name: 'ssh-only', ip: '10.0.0.9'));
    await pump(tester);
    expect(find.text(app_locale.l10n.monitorNoAgents), findsOneWidget);
  });
}
