/// The discovery view: one tab per source, each started the way it asks,
/// hosts that are already servers marked, and the checked ones added in one
/// go with the servers they jump through.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/service/ssh_discovery.dart';
import 'package:server_box/core/ssh/host_keys.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';
import 'package:server_box/view/widget/ssh_discovery/view.dart';

final _l10n = AppLocalizationsEn();

Future<HostKeyId?> _noKey(SshCredential _, {String? prefer}) async => null;

DiscoveredSshHost _host(
  String ip, {
  int port = 22,
  String? name,
  String? detail,
  List<Spi> via = const [],
}) => DiscoveredSshHost(
  key: '$ip:$port',
  server: Spi(
    name: name ?? ip,
    id: 'id-$ip',
    ssh: SshCredential(
      ip: ip,
      port: port,
      jumpIds: [for (final v in via) v.id],
    ),
  ),
  detail: detail,
  via: via,
);

void main() {
  const existing = Spi(
    name: 'nas',
    id: 'nas',
    ssh: SshCredential(ip: '192.168.1.10'),
  );
  final hosts = [
    _host('192.168.1.2', detail: 'SSH-2.0-OpenSSH_9.6'),
    _host('192.168.1.10'),
    _host('192.168.1.23', port: 2222, name: 'pi'),
  ];

  late _Servers servers;

  Future<void> pump(WidgetTester tester, Widget child) async {
    servers = _Servers(existing);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [serversProvider.overrideWith(() => servers)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: app_locale.appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return Scaffold(body: child);
            },
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('one source: no tabs, its scope, then its hosts', (tester) async {
    await pump(
      tester,
      SshDiscoveryView.batch(thisDevice: false, probe: _noKey, sources: [_Source('lan', hosts)]),
    );
    expect(find.byType(SegmentedTabs<String>), findsNothing);
    expect(find.text('10.0.0.0/24'), findsOneWidget);

    await tester.tap(find.text(_l10n.discoveryScan));
    await tester.pump();

    expect(find.text('10.0.0.0/24 · ${_l10n.discoveryFound(3)}'), findsOneWidget);
    expect(find.text('192.168.1.2'), findsOneWidget);
    expect(find.text('pi'), findsOneWidget);
    // Already a server: no checkbox to tick.
    expect(find.text(_l10n.discoveryExists), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
  });

  testWidgets('checked hosts are added as servers', (tester) async {
    await pump(
      tester,
      SshDiscoveryView.batch(thisDevice: false, probe: _noKey, sources: [_Source('lan', hosts)]),
    );
    await tester.tap(find.text(_l10n.discoveryScan));
    await tester.pump();

    await tester.tap(find.text(_l10n.discoverySelectAll));
    await tester.pump();
    expect(find.text(_l10n.discoverySelected(2)), findsOneWidget);

    await tester.tap(find.text(_l10n.discoveryAddN(2)));
    await tester.pump();

    final added = servers.state.servers.values.where((e) => e.id != 'nas');
    expect(
      added.map((e) => (e.name, e.ssh?.ip, e.ssh?.port)).toSet(),
      {('192.168.1.2', '192.168.1.2', 22), ('pi', '192.168.1.23', 2222)},
    );
    expect(find.text(_l10n.discoveryAdded), findsNWidgets(2));
  });

  testWidgets('select all takes the rows the filter shows', (tester) async {
    await pump(
      tester,
      SshDiscoveryView.batch(
        thisDevice: false,
        probe: _noKey,
        sources: [
          _Source('lan', [
            for (var i = 1; i <= 8; i++)
              _host('10.0.0.$i', name: i.isEven ? 'web$i' : 'db$i'),
          ]),
        ],
      ),
    );
    await tester.tap(find.text(_l10n.discoveryScan));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'web');
    await tester.pump();
    await tester.tap(find.text(_l10n.discoverySelectAll));
    await tester.pump();
    expect(find.text(_l10n.discoverySelected(4)), findsOneWidget);
  });

  testWidgets('a tab per source; one that runs by itself starts when shown', (
    tester,
  ) async {
    final auto = _Source('auto', [_host('example.com')], auto: true);
    await pump(
      tester,
      SshDiscoveryView.batch(
        thisDevice: false,
        probe: _noKey,
        sources: [_Source('lan', hosts), auto],
      ),
    );
    expect(find.byType(SegmentedTabs<String>), findsOneWidget);
    expect(auto.runs, 0);

    await tester.tap(find.text('auto'));
    await tester.pump();
    await tester.pump();
    expect(auto.runs, 1);
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('auto 1'), findsOneWidget);
  });

  testWidgets('a token source runs with what was typed, and forgets it', (
    tester,
  ) async {
    final source = _Source('cf', [_host('ssh.example.com')], token: true);
    await pump(
      tester,
      SshDiscoveryView.batch(thisDevice: false, probe: _noKey, sources: [source]),
    );
    expect(find.text('needs read'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.text(_l10n.connect));
    await tester.pump();
    expect(source.inputs, ['secret']);
    expect(find.text('ssh.example.com'), findsOneWidget);

    await tester.tap(find.text(_l10n.disconnect));
    await tester.pump();
    expect(find.text('ssh.example.com'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('a failed run says why, and offers a file when it can', (
    tester,
  ) async {
    final source = _Source(
      'cfg',
      const [],
      auto: true,
      error: const SshDiscoveryException('denied', tip: 'pick', needsFile: true),
    );
    await pump(
      tester,
      SshDiscoveryView.batch(thisDevice: false, probe: _noKey, sources: [source]),
    );
    await tester.pump();
    expect(find.text('denied'), findsOneWidget);
    expect(find.text(_l10n.discoveryChooseFile), findsOneWidget);
  });

  testWidgets('pick hands one host back', (tester) async {
    DiscoveredSshHost? picked;
    await pump(
      tester,
      SshDiscoveryView.pick(
        onPick: (h) => picked = h,
        sources: [_Source('lan', hosts)],
      ),
    );
    await tester.tap(find.text(_l10n.discoveryScan));
    await tester.pump();

    expect(find.byType(Checkbox), findsNothing);
    await tester.tap(find.text('pi'));
    expect(picked, hosts[2]);
  });

  testWidgets('one machine at two addresses becomes one server, as picked', (
    tester,
  ) async {
    Future<HostKeyId?> sameKey(SshCredential ssh, {String? prefer}) async =>
        (type: 'ssh-ed25519', fingerprint: 'SHA256:same');
    final ts = DiscoveredSshHost(
      key: 'nas-ts',
      server: const Spi(
        name: 'nas',
        id: 'ts-nas',
        ssh: SshCredential(ip: 'nas.example.ts.net'),
      ),
    );
    await pump(
      tester,
      SshDiscoveryView.batch(
        thisDevice: false,
        probe: sameKey,
        sources: [
          _Source('lan', [_host('192.168.1.5')]),
          _Source('tailscale', [ts]),
        ],
      ),
    );
    await tester.tap(find.text(_l10n.discoveryScan));
    await tester.pump();
    await tester.tap(find.text('192.168.1.5'));
    await tester.tap(find.text('tailscale'));
    await tester.pump();
    await tester.tap(find.text(_l10n.discoveryScan));
    await tester.pump();
    await tester.tap(find.text('nas'));
    await tester.pump();
    await tester.tap(find.text(_l10n.discoveryAddN(2)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_l10n.discoverySameMachine), findsOneWidget);
    // The first source leads by default; pick the tailnet address instead.
    await tester.tap(find.text('nas · nas.example.ts.net:22').first);
    await tester.pump();
    await tester.tap(find.text(libL10n.ok));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final added = servers.state.servers.values.where((e) => e.id != 'nas');
    expect(added.map((e) => (e.ssh?.ip, e.ssh?.alterUrl)), [
      ('nas.example.ts.net', 'root@192.168.1.5:22'),
    ]);
  });

  group('groupByHostKey', () {
    const a = (type: 'ssh-ed25519', fingerprint: 'SHA256:a');
    const b = (type: 'ssh-ed25519', fingerprint: 'SHA256:b');
    const srv = Spi(name: 'srv', id: 'srv', ssh: SshCredential(ip: '10.0.0.9'));
    final known = {'srv::ssh-ed25519': 'SHA256:b'};

    test('a server\'s key is a server already; a shared one groups', () {
      final got = groupByHostKey(
        {
          'lan/1': (ids: [a], user: null),
          'ts/1': (ids: [a], user: null),
          'lan/2': (ids: [b], user: null),
        },
        known,
        {'srv': srv},
      );
      expect(got.known, {'lan/2'});
      expect(got.groups, [
        ['lan/1', 'ts/1'],
      ]);
    });

    test('a key under no server is no server', () {
      final got = groupByHostKey(
        {'lan/2': (ids: [b], user: null)},
        known,
        const {},
      );
      expect(got.known, isEmpty);
    });

    test('another account on a known machine is a new server', () {
      final got = groupByHostKey(
        {'cfg/git': (ids: [b], user: 'git')},
        known,
        {'srv': srv},
      );
      expect(got.known, isEmpty);
    });

    test('two named accounts stay apart; an unnamed one joins the first', () {
      final got = groupByHostKey(
        {
          'cfg/root': (ids: [a], user: 'root'),
          'cfg/git': (ids: [a], user: 'git'),
          'lan/1': (ids: [a], user: null),
        },
        const {},
        const {},
      );
      expect(got.groups, [
        ['cfg/root', 'lan/1'],
      ]);
    });

    test('a key of another type matches the one remembered', () {
      const ecdsa = (type: 'ecdsa-sha2-nistp256', fingerprint: 'SHA256:e');
      final got = groupByHostKey(
        {'lan/3': (ids: [a, ecdsa], user: null)},
        {'srv::ecdsa-sha2-nistp256': 'SHA256:e'},
        {'srv': srv},
      );
      expect(got.known, {'lan/3'});
    });
  });

  group('planDiscoveredServers', () {
    const bastion = Spi(
      name: 'bastion',
      id: 'b',
      ssh: SshCredential(ip: 'bastion.example.com'),
    );

    test('a host brings its hops first, once', () {
      final a = _host('10.0.0.1', via: [bastion]);
      final b = _host('10.0.0.2', via: [bastion]);
      final plan = planDiscoveredServers([a, b], const []);
      expect(plan.add.map((e) => e.id), ['b', 'id-10.0.0.1', 'id-10.0.0.2']);
    });

    test('a hop that is a server already is pointed at, not added', () {
      const kept = Spi(
        name: 'jump',
        id: 'kept',
        ssh: SshCredential(ip: 'bastion.example.com'),
      );
      final plan = planDiscoveredServers([
        _host('10.0.0.1', via: [bastion]),
      ], [kept]);
      expect(plan.add.map((e) => e.id), ['id-10.0.0.1']);
      expect(plan.add.single.ssh!.resolvedJumpIds, ['kept']);
      expect(plan.ids['b'], 'kept');
    });

    test('one machine picked from two sources is added once', () {
      final lan = _host('192.168.1.5');
      final cfg = DiscoveredSshHost(
        key: 'nas',
        server: const Spi(
          name: 'nas',
          id: 'cfg-nas',
          ssh: SshCredential(ip: '192.168.1.5'),
        ),
        userKnown: true,
      );
      final plan = planDiscoveredServers([lan, cfg], const []);
      expect(plan.add.map((e) => e.id), ['id-192.168.1.5']);
      expect(plan.ids['cfg-nas'], 'id-192.168.1.5');
    });

    test('a hop at a merged-away address is the server it went into', () {
      final merged = DiscoveredSshHost(
        key: 'bastion',
        server: const Spi(
          name: 'bastion',
          id: 'ts-b',
          ssh: SshCredential(
            ip: 'bastion.example.ts.net',
            alterUrl: 'root@bastion.example.com:22',
          ),
        ),
      );
      final plan = planDiscoveredServers([
        merged,
        _host('10.0.0.1', via: [bastion]),
      ], const []);
      expect(plan.add.map((e) => e.id), ['ts-b', 'id-10.0.0.1']);
      expect(plan.add.last.ssh!.resolvedJumpIds, ['ts-b']);
    });

    test('each server after its hops, along a chain', () {
      const edge = Spi(
        name: 'edge',
        id: 'e',
        ssh: SshCredential(ip: '10.0.0.1', jumpIds: ['b']),
      );
      final e = DiscoveredSshHost(key: 'edge', server: edge, via: [bastion]);
      final d = DiscoveredSshHost(
        key: 'db',
        server: const Spi(
          name: 'db',
          id: 'd',
          ssh: SshCredential(ip: '10.0.0.2', jumpIds: ['e']),
        ),
        via: [bastion, edge],
      );
      final plan = planDiscoveredServers([e, d], const []);
      expect(plan.add.map((s) => s.id), ['b', 'e', 'd']);
    });

    test('names already taken get a suffix', () {
      const nas = Spi(name: 'pi', id: 'x', ssh: SshCredential(ip: '1.1.1.1'));
      final plan = planDiscoveredServers([
        _host('10.0.0.3', name: 'pi'),
      ], [nas]);
      expect(plan.add.single.name, isNot('pi'));
    });
  });

  testWidgets('a host whose hop fails to add is not added', (tester) async {
    const bastion = Spi(
      name: 'bastion',
      id: 'b',
      ssh: SshCredential(ip: 'bastion.example.com'),
    );
    await pump(
      tester,
      SshDiscoveryView.batch(
        thisDevice: false,
        probe: _noKey,
        sources: [
          _Source('cfg', [_host('10.0.0.1', name: 'web', via: [bastion])]),
        ],
      ),
    );
    servers.refuse.add('b');
    await tester.tap(find.text(_l10n.discoveryScan));
    await tester.pump();
    await tester.tap(find.text('web'));
    await tester.pump();
    await tester.tap(find.text(_l10n.discoveryAddN(1)));
    await tester.pump();
    expect(servers.state.servers.keys, ['nas']);
    // Still checked, to try again.
    expect(find.text(_l10n.discoverySelected(1)), findsOneWidget);
  });
}

final class _Source implements SshDiscovery {
  _Source(
    this.id,
    this.hosts, {
    this.auto = false,
    bool token = false,
    this.error,
  }) : credential = token
           ? const SshDiscoveryCredential(label: 'Token', hint: 'needs read')
           : null;

  @override
  final String id;
  final List<DiscoveredSshHost> hosts;
  final SshDiscoveryException? error;
  int runs = 0;
  final inputs = <String?>[];

  @override
  final bool auto;

  @override
  final SshDiscoveryCredential? credential;

  @override
  String get label => id;

  @override
  IconData get icon => Icons.wifi;

  @override
  Future<String?> scope() async => '10.0.0.0/24';

  @override
  Future<SshDiscoveryRun> discover({String? input}) async {
    runs++;
    inputs.add(input);
    if (error case final e?) throw e;
    return (hosts: hosts, scope: null);
  }
}

final class _Servers extends ServersNotifier {
  _Servers(this.initial);

  final Spi initial;

  @override
  ServersState build() =>
      ServersState(servers: {initial.id: initial}, serverOrder: [initial.id]);

  final refuse = <String>{};

  @override
  Future<void> addServer(Spi spi) async {
    if (refuse.contains(spi.id)) throw StateError('refused');
    state = state.copyWith(
      servers: {...state.servers, spi.id: spi},
      serverOrder: [...state.serverOrder, spi.id],
    );
  }
}
