/// The discovery view: one tab per source, a scan per source, hosts that are
/// already servers marked, and the checked ones added in one go.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/service/ssh_discovery.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';
import 'package:server_box/view/widget/ssh_discovery/view.dart';

final _l10n = AppLocalizationsEn();

void main() {
  const existing = Spi(
    name: 'nas',
    id: 'nas',
    ssh: SshCredential(ip: '192.168.1.10'),
  );
  const hosts = [
    DiscoveredSshHost(host: '192.168.1.2', detail: 'SSH-2.0-OpenSSH_9.6'),
    DiscoveredSshHost(host: '192.168.1.10'),
    DiscoveredSshHost(host: '192.168.1.23', port: 2222, name: 'pi'),
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
      const SshDiscoveryView.batch(
        thisDevice: false,
        sources: [_Source('lan', hosts)],
      ),
    );
    expect(find.byType(SegmentedTabs<String>), findsNothing);
    expect(find.text('10.0.0.0/24'), findsOneWidget);

    await tester.tap(find.text(_l10n.discoveryScan));
    await tester.pump();

    expect(find.text('10.0.0.0/24 · ${_l10n.discoveryFound(3)}'), findsOneWidget);
    expect(find.text('192.168.1.2:22'), findsOneWidget);
    expect(find.text('pi'), findsOneWidget);
    // Already a server: no checkbox to tick.
    expect(find.text(_l10n.discoveryExists), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
  });

  testWidgets('checked hosts are added as servers', (tester) async {
    await pump(
      tester,
      const SshDiscoveryView.batch(
        thisDevice: false,
        sources: [_Source('lan', hosts)],
      ),
    );
    await tester.tap(find.text(_l10n.discoveryScan));
    await tester.pump();

    expect(find.text(_l10n.discoveryAddN(1)), findsNothing);
    await tester.tap(find.text('192.168.1.2:22'));
    await tester.tap(find.text('pi'));
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
    expect(find.text(_l10n.discoveryAddN(2)), findsNothing);
  });

  testWidgets('a tab per source', (tester) async {
    await pump(
      tester,
      const SshDiscoveryView.batch(
        thisDevice: false,
        sources: [
          _Source('lan', hosts),
          _Source('other', [DiscoveredSshHost(host: 'example.com')]),
        ],
      ),
    );
    expect(find.byType(SegmentedTabs<String>), findsOneWidget);

    await tester.tap(find.text('other'));
    await tester.pump();
    await tester.tap(find.text(_l10n.discoveryScan));
    await tester.pump();
    expect(find.text('example.com:22'), findsOneWidget);
    expect(find.text('other 1'), findsOneWidget);
  });

  testWidgets('pick hands one host back', (tester) async {
    DiscoveredSshHost? picked;
    await pump(
      tester,
      SshDiscoveryView.pick(
        onPick: (h) => picked = h,
        sources: const [_Source('lan', hosts)],
      ),
    );
    await tester.tap(find.text(_l10n.discoveryScan));
    await tester.pump();

    expect(find.byType(Checkbox), findsNothing);
    await tester.tap(find.text('pi'));
    expect(picked, hosts[2]);
  });
}

final class _Source implements SshDiscovery {
  const _Source(this.id, this.hosts);

  @override
  final String id;
  final List<DiscoveredSshHost> hosts;

  @override
  String get label => id;

  @override
  IconData get icon => Icons.wifi;

  @override
  Future<String?> scope() async => '10.0.0.0/24';

  @override
  Future<List<DiscoveredSshHost>> discover() async => hosts;
}

final class _Servers extends ServersNotifier {
  _Servers(this.initial);

  final Spi initial;

  @override
  ServersState build() =>
      ServersState(servers: {initial.id: initial}, serverOrder: [initial.id]);

  @override
  Future<void> addServer(Spi spi) async {
    state = state.copyWith(
      servers: {...state.servers, spi.id: spi},
      serverOrder: [...state.serverOrder, spi.id],
    );
  }
}
