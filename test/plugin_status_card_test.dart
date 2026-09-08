/// A status plugin's readings, from `statusCmd` to a row on screen.
/// PLUGINS.md section 9.
///
/// The last join: everything before this proves a plugin can be asked what to
/// run and told what it printed, and this proves the answer is drawn.
///
/// Build the native library first: cargo build -p sbm_ffi
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/plugin/contributions.dart';
import 'package:server_box/data/model/server/plugin_status_reading.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/plugin/installer.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/view/page/home_tab.dart';
import 'package:server_box/view/widget/plugin/status_card.dart';
import 'package:server_box/view/widget/server_func_btns.dart';

import 'helpers/test_db.dart';
import 'rust_lib_helper.dart';

/// A plugin whose command prints two rows, and which parses them back.
const _source = '''
export function statusCmd({ platform }) {
  return { cmd: "printf 'tank\\t0.33\\tONLINE\\npool2\\t0.99\\tDEGRADED\\n'" };
}
export function parse({ text }) {
  const items = text.split('\\n').filter(Boolean).map((line) => {
    const [name, used, health] = line.split('\\t');
    return {
      label: name,
      value: health,
      percent: Number(used),
      tone: health === 'ONLINE' ? 'success' : 'danger',
    };
  });
  return { title: 'ZFS', items, note: items.length + ' pools' };
}
''';

String _manifest({bool requiresConfig = false}) => jsonEncode({
  'id': 'app.serverbox.zfs',
  'version': '1.0.0',
  'abi': 1,
  'name': 'ZFS',
  'permissions': {'server.exec': true},
  'contributes': {
    'status': {
      'id': 'zfs',
      'label': 'ZFS',
      'default_on': true,
      'requires_config': requiresConfig,
      'platforms': ['linux'],
    },
  },
});

List<int> _sbp({bool requiresConfig = false}) {
  final archive = Archive()
    ..add(
      ArchiveFile.bytes(
        'manifest.json',
        utf8.encode(_manifest(requiresConfig: requiresConfig)),
      ),
    )
    ..add(ArchiveFile.bytes('plugin.js', utf8.encode(_source)));
  return ZipEncoder().encode(archive);
}

void main() {
  setUpAll(initRustLibForTest);

  late Directory root;
  late PluginInstaller installer;
  late ProviderContainer container;

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    root = await Directory.systemTemp.createTemp('sbm_status_card');
    installer = PluginInstaller(root: root, store: PluginInstallStore());
    PluginContributions.clear();
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    PluginContributions.clear();
    await getIt.reset();
    await closeTestDb();
    if (await root.exists()) await root.delete(recursive: true);
  });

  /// Installing is real file IO, and a `testWidgets` body is a fake-async
  /// zone: a future waiting on the filesystem is a continuation that zone
  /// never delivers, so this hangs rather than fails if it runs outside
  /// `runAsync`.
  Future<void> install(WidgetTester tester) => tester.runAsync(
    () => installer.install(_sbp(), consented: {'server.exec'}),
  );

  Future<void> mount(
    WidgetTester tester, {
    SystemType? system,
    PluginStatusReading? agentReading,
  }) async {
    final plugin = PluginContributions.byId('app.serverbox.zfs')!;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: PluginStatusCard(
                plugin: plugin,
                spi: const Spi(
                  id: 'srv-1',
                  name: 'one',
                  ssh: SshCredential(ip: '10.0.0.1'),
                ),
                system: system ?? SystemType.linux,
                agentReading: agentReading,
                // The script the app really generated, run for real. A
                // mocked answer would skip the half with a shell in it,
                // which is the half worth checking. `sh -c` rather than
                // feeding it on stdin, which is what the app does — the
                // script is the same either way, and this test has no
                // channel to write to.
                runScript: (script, {entry}) async {
                  final ran = await Process.run('sh', ['-c', script]);
                  return ran.stdout as String;
                },
              ),
            ),
          ),
        ),
      );
    });
    await tester.pump();
  }

  /// Lets the real work run until [finder] matches, or gives up.
  ///
  /// A fixed delay was wrong twice over: too short and the collection is still
  /// in flight, and — worse — once `runAsync` returns, the fake zone is back
  /// and a future waiting on a process or a port never completes at all. So
  /// the waiting is done in slices, each of which is real time.
  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      if (finder.evaluate().isNotEmpty) return;
    }
  }

  /// A status plugin is drawn with the app's own widgets, which is what lets
  /// it ship before the widget vocabulary is settled.
  testWidgets('what the plugin parsed is what the card shows', (tester) async {
    await install(tester);

    await mount(tester);
    await waitFor(tester, find.text('tank'));

    expect(find.text('ZFS'), findsOneWidget);
    expect(find.text('tank'), findsOneWidget);
    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.text('pool2'), findsOneWidget);
    expect(find.text('DEGRADED'), findsOneWidget);
    expect(find.text('2 pools'), findsOneWidget);
    // 0..1, drawn as a bar beside the value.
    final bars = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .map((b) => b.value)
        .toList();
    expect(bars, [closeTo(0.33, 1e-9), closeTo(0.99, 1e-9)]);
  });

  /// A platform the manifest did not name. Asking anyway gets nothing, or a
  /// command for the wrong system — which is one that fails on the machine it
  /// was sent to.
  testWidgets('a platform it did not name is never asked', (tester) async {
    await install(tester);

    await mount(tester, system: SystemType.windows);
    await waitFor(tester, find.text('never matches'), timeout: const Duration(seconds: 2));

    expect(find.text('tank'), findsNothing);
    // The card is still there and still named, so its place in the
    // arrangement does not silently become a gap.
    expect(find.text('ZFS'), findsOneWidget);
  });

  /// The rule this exists to hold: the agent already ran the command on the
  /// machine it is on, so the app runs nothing.
  ///
  /// Two collections for one answer is the lesser problem. The larger one is
  /// that the agent's reading is what reaches `/metrics/history`, the watch
  /// and the home widgets — so if the app collected its own, the card would be
  /// able to disagree with everything else showing the same plugin.
  testWidgets('an agent that reports it is the one the card draws', (
    tester,
  ) async {
    await install(tester);
    var ran = 0;

    final plugin = PluginContributions.byId('app.serverbox.zfs')!;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: PluginStatusCard(
                plugin: plugin,
                spi: const Spi(
                  id: 'srv-1',
                  name: 'one',
                  ssh: SshCredential(ip: '10.0.0.1'),
                ),
                system: SystemType.linux,
                agentReading: const PluginStatusReading(
                  title: 'ZFS',
                  items: [
                    PluginStatusItemReading(
                      label: 'tank',
                      value: 'ONLINE',
                      percent: 0.33,
                      tone: 'success',
                    ),
                  ],
                  note: 'from the agent',
                ),
                runScript: (script, {entry}) async {
                  ran++;
                  return '';
                },
              ),
            ),
          ),
        ),
      );
    });
    await waitFor(tester, find.text('tank'));

    expect(find.text('tank'), findsOneWidget);
    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.text('from the agent'), findsOneWidget);
    // Nothing was run, and nothing was loaded to run it with.
    expect(ran, 0);
  });

  /// A plugin may contribute both, and they are different things: a status
  /// contribution says what to run and reads the output, a card holds state
  /// and answers events. Two ids, two places in the arrangement.
  test('a card and a status contribution are two entries', () async {
    final both = Archive()
      ..add(
        ArchiveFile.bytes(
          'manifest.json',
          utf8.encode(
            jsonEncode({
              'id': 'app.serverbox.both',
              'version': '1.0.0',
              'abi': 1,
              'name': 'Both',
              'permissions': {'server.exec': true},
              'contributes': {
                'card': {'id': 'panel', 'label': 'Panel', 'default_on': true},
                'status': {
                  'id': 'zfs',
                  'label': 'ZFS',
                  'default_on': true,
                  'platforms': ['linux'],
                },
              },
            }),
          ),
        ),
      )
      ..add(ArchiveFile.bytes('plugin.js', utf8.encode(_source)));

    final plugin = await installer.install(
      ZipEncoder().encode(both),
      consented: {'server.exec'},
    );

    expect(plugin.statusFeature?.id, 'app.serverbox.both:zfs');
    expect(plugin.cardFeature?.id, 'app.serverbox.both:panel');
    expect(plugin.isCard('app.serverbox.both:panel'), isTrue);
    expect(plugin.isCard('app.serverbox.both:zfs'), isFalse);
    expect(
      FeatureSlot.detailCard.enabledIds(),
      containsAll(['app.serverbox.both:zfs', 'app.serverbox.both:panel']),
    );

    // And uninstalling takes both places, not one.
    await installer.uninstall('app.serverbox.both');
    expect(
      FeatureSlot.detailCard.enabledIds(),
      isNot(anyOf(
        contains('app.serverbox.both:zfs'),
        contains('app.serverbox.both:panel'),
      )),
    );
  });

  /// A page contribution is a button in the server function bar, and `needs`
  /// is the app's own `availableWith` switch moved into data.
  ///
  /// The point of the test is the filtering: a plugin naming something the
  /// connection cannot do must not put a button there, because the page behind
  /// it could never load. `stored_history` is the discriminator because an SSH
  /// server is the one transport that answers false to it.
  testWidgets('a page contribution is a button, and needs decides', (
    tester,
  ) async {
    Future<void> installPage(List<String> needs) => tester.runAsync(() async {
      final archive = Archive()
        ..add(
          ArchiveFile.bytes(
            'manifest.json',
            utf8.encode(
              jsonEncode({
                'id': 'app.serverbox.page',
                'version': '1.0.0',
                'abi': 1,
                'name': 'Pager',
                'contributes': {
                  'page': {
                    'id': 'main',
                    'label': 'Pager',
                    'default_on': true,
                    'needs': needs,
                  },
                },
              }),
            ),
          ),
        )
        ..add(ArchiveFile.bytes('plugin.js', utf8.encode(_source)));
      await installer.install(ZipEncoder().encode(archive), consented: {});
    });

    await installPage(const ['files']);
    final plugin = PluginContributions.byId('app.serverbox.page')!;
    expect(plugin.pageFeature?.id, 'app.serverbox.page:main');
    expect(plugin.isPage('app.serverbox.page:main'), isTrue);
    expect(plugin.isCard('app.serverbox.page:main'), isFalse);
    expect(
      Features.byId(FeatureSlot.funcBtn, 'app.serverbox.page:main'),
      isNotNull,
    );
    expect(
      FeatureSlot.funcBtn.enabledIds(),
      contains('app.serverbox.page:main'),
    );

    const spi = Spi(id: 'srv-1', name: 'one', ssh: SshCredential(ip: '10.0.0.1'));
    List<String> row() =>
        const ServerFuncBtns(spi: spi).btnsWith(null).map((f) => f.id).toList();

    // SSH serves files, so the button is there — beside the app's own, which
    // is the other half of the row still working.
    expect(row(), contains('app.serverbox.page:main'));
    expect(row(), contains(ServerFuncBtn.terminal.id));

    // And a name the transport does not meet takes it back out.
    await tester.runAsync(() => installer.uninstall('app.serverbox.page'));
    await installPage(const ['stored_history']);
    expect(row(), isNot(contains('app.serverbox.page:main')));

    // A name no build has is ignored rather than hiding the button: a newer
    // plugin should show up on an older app, not disappear.
    await tester.runAsync(() => installer.uninstall('app.serverbox.page'));
    await installPage(const ['telepathy']);
    expect(row(), contains('app.serverbox.page:main'));

    // Alone in the row: it is a lazy horizontal list, so an entry after the
    // app's own eight is off-screen and never built.
    FeatureSlot.funcBtn.putEnabledIds(['app.serverbox.page:main']);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(height: 60, child: ServerFuncBtns(spi: spi))),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Pager'), findsOneWidget);
  });

  /// A tab is the widest surface a plugin gets and the last slot it could not
  /// reach: `homeTabs` was typed `List<AppTab>` until m023, so a name no case
  /// matched had nowhere to go.
  test('a tab contribution reaches the home bar', () async {
    final archive = Archive()
      ..add(
        ArchiveFile.bytes(
          'manifest.json',
          utf8.encode(
            jsonEncode({
              'id': 'app.serverbox.fleet',
              'version': '1.0.0',
              'abi': 1,
              'name': 'Fleet',
              'permissions': {'server.list': true},
              'contributes': {
                'tab': {'id': 'all', 'label': 'Fleet', 'default_on': true},
              },
            }),
          ),
        ),
      )
      ..add(ArchiveFile.bytes('plugin.js', utf8.encode(_source)));

    final plugin = await installer.install(
      ZipEncoder().encode(archive),
      consented: {'server.list'},
    );

    const id = 'app.serverbox.fleet:all';
    expect(plugin.tabFeature?.id, id);
    expect(plugin.isTab(id), isTrue);
    expect(Features.byId(FeatureSlot.homeTab, id), isNotNull);
    // Reachable behind "more" and in the arranging page from the moment it is
    // installed, and resolvable to something the home page can draw.
    expect(HomeTab.orderedIds(FeatureSlot.homeTab.enabledIds()), contains(id));
    expect(HomeTab.of(id), isA<PluginHomeTab>());
    expect(HomeTab.of(id)?.label, 'Fleet');

    // **Not put in the bar.** It fits four labels on a phone, so taking one of
    // those is the user's decision — the same rule that keeps every built-in
    // tab out of `Features.autoAdd`.
    expect(FeatureSlot.homeTab.enabledIds(), isNot(contains(id)));

    // And uninstalling takes it out of the registry while the arrangement, if
    // the user had moved it into the bar, keeps its place.
    await installer.uninstall('app.serverbox.fleet');
    expect(Features.byId(FeatureSlot.homeTab, id), isNull);
    expect(HomeTab.of(id), isNull);
  });

  /// `requires_config` keeps a card off the machines the plugin has nothing to
  /// say about — most of them, for something like a BMC.
  test('the registry and the arrangement both learn about it', () async {
    final plugin = await installer.install(_sbp(), consented: {'server.exec'});

    expect(plugin.statusFeature?.id, 'app.serverbox.zfs:zfs');
    expect(
      Features.byId(FeatureSlot.detailCard, 'app.serverbox.zfs:zfs'),
      isNotNull,
    );
    expect(
      FeatureSlot.detailCard.enabledIds(),
      contains('app.serverbox.zfs:zfs'),
    );
    expect(
      PluginContributions.ofFeature('app.serverbox.zfs:zfs')?.id,
      'app.serverbox.zfs',
    );

    // And a plugin the user turned off keeps its place while contributing
    // nothing, which is what makes turning it back on put it where it was.
    await installer.setEnabled('app.serverbox.zfs', false);
    expect(
      Features.byId(FeatureSlot.detailCard, 'app.serverbox.zfs:zfs'),
      isNull,
    );
    expect(
      FeatureSlot.detailCard.enabledIds(),
      contains('app.serverbox.zfs:zfs'),
    );
  });
}
