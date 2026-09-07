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
import 'package:server_box/data/model/plugin/contributions.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/plugin/installer.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/view/widget/plugin/status_card.dart';

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

  Future<void> mount(WidgetTester tester, {SystemType? system}) async {
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
