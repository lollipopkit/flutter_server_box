import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/local_shell.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/page/ssh/tab.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

/// What comes back when the app is opened again.
///
/// The terminal tab set is the one piece of this that does survive a relaunch,
/// because it was moved to Hive when Flutter's restoration turned out not to
/// work here — see `test/restoration_bucket_test.dart`. So it is also the one
/// piece that can be checked without a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-sshtab-');
    await openTestDb();
    // In memory: this tree writes as it builds, and a test has no
    // business leaving a database behind.
    getIt.registerSingleton<SettingStore>(SettingStore.forTest());
    getIt.registerSingleton<ServerStore>(ServerStore.forTest());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore.forTest());
    getIt.registerSingleton<HistoryStore>(HistoryStore.forTest());
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  /// Writes a saved tab set, as a previous run would have left it.
  Future<void> saveTabs(List<Map<String, dynamic>> tabs) async {
    Stores.history.sshTabs.put(jsonEncode(tabs));
  }

  /// The tab set as the page wrote it back.
  ///
  /// `_restore` ends by saving, so this is exactly what came back — one entry
  /// per tab, with the source it is on. Read from the store rather than
  /// counted on screen: the strip renders a label per tab and the picker on
  /// the first tab lists every server by the same name, so a text finder
  /// cannot tell two tabs from one tab drawn twice.
  List<Map<String, dynamic>> restored() {
    final saved = Stores.history.sshTabs.fetch();
    if (saved.isEmpty) return const [];
    return [
      for (final e in jsonDecode(saved) as List)
        if (e is Map) e.cast<String, dynamic>(),
    ];
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // In a Scaffold, as the home page hosts it: the tab strip's buttons
          // are `InkWell`s and want a Material above them.
          home: const Scaffold(body: SSHTabPage()),
        ),
      ),
    );
    // Counted out: a page holding terminals always has something scheduled.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  test('a server rename rewrites history and saved tab ids', () {
    Stores.history.sshServerHistory
      ..add('other')
      ..add('server-old');
    Stores.history.sshTabs.put(
      jsonEncode([
        {'sourceId': 'server-old', 'tmuxSession': 'work'},
        {'serverId': 'server-old'},
      ]),
    );

    Stores.history.renameSshServer('server-old', 'server-new');

    expect(Stores.history.sshServerHistory.all, ['server-new', 'other']);
    expect(restored().map((entry) => entry['sourceId'] ?? entry['serverId']), [
      'server-new',
      'server-new',
    ]);
    expect(Stores.history.resolveSshServerId('server-old'), 'server-new');
  });

  testWidgets('two shells on one server come back as two tabs', (tester) async {
    // The one this exists for. A restore keyed on the server rather than on
    // the entry would collapse these into one, and the second window's tmux
    // state would go with it.
    final spi = spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u');
    Stores.server.put(spi);
    await saveTabs([
      {'sourceId': 'srv-1', 'tmuxSession': 'work', 'tmuxWindow': 0},
      {'sourceId': 'srv-1', 'tmuxSession': 'work', 'tmuxWindow': 3},
    ]);

    await pump(tester);

    final tabs = restored();
    expect(tabs, hasLength(2));
    expect(tabs.map((t) => t['sourceId']), everyElement('srv-1'));
    // Each keeps its own window, which is what would be lost if the two were
    // folded into one.
    expect(tabs.map((t) => t['tmuxWindow']), [0, 3]);
  });

  testWidgets('a tab whose server was deleted is skipped', (tester) async {
    // Not an error tab, and not a crash out of the loop that would take the
    // others with it.
    final spi = spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u');
    Stores.server.put(spi);
    await saveTabs([
      {'sourceId': 'srv-1'},
      {'sourceId': 'srv-gone'},
    ]);

    await pump(tester);

    expect(restored().map((t) => t['sourceId']), ['srv-1']);
  });

  testWidgets('a malformed entry does not take the others with it', (
    tester,
  ) async {
    // What this path is defensive about: it is the one place that reads data
    // an older build wrote, and one bad record used to abort the loop.
    final spi = spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u');
    Stores.server.put(spi);
    Stores.history.sshTabs.put(
      jsonEncode([
        'not a map',
        42,
        {'sourceId': 'srv-1'},
      ]),
    );

    await pump(tester);

    expect(restored().map((t) => t['sourceId']), ['srv-1']);
  });

  testWidgets('malformed tmux fields do not block later tabs', (tester) async {
    final spi = spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u');
    Stores.server.put(spi);
    await saveTabs([
      {'sourceId': 'srv-1', 'tmuxSession': 42, 'tmuxWindow': 'bad'},
      {'sourceId': 'srv-1', 'tmuxSession': 'work', 'tmuxWindow': 3},
    ]);

    await pump(tester);

    final tabs = restored();
    expect(tabs, hasLength(2));
    expect(tabs.last['tmuxSession'], 'work');
    expect(tabs.last['tmuxWindow'], 3);
  });

  testWidgets('a server id sharing the rootfs prefix remains a server', (
    tester,
  ) async {
    final id = '${LocalSource.rootfsId}x';
    Stores.server.put(spiFixture(id: id, name: 'web', ip: 'h', user: 'u'));
    await saveTabs([
      {'sourceId': id},
    ]);

    await pump(tester);

    expect(restored().map((t) => t['sourceId']), [id]);
  });

  testWidgets('an unreadable set opens the picker rather than throwing', (
    tester,
  ) async {
    Stores.history.sshTabs.put('{{{ not json');

    await pump(tester);

    expect(find.byType(SSHTabPage), findsOneWidget);
  });

  testWidgets('the local shell comes back where the platform has one', (
    tester,
  ) async {
    // A tab set saved on a desktop can be restored on a phone — same backup,
    // same account — so this entry is skipped rather than opened as a terminal
    // that can only fail when its pty is asked for. Which way it goes is the
    // platform's answer, so the test asks the same question the page does.
    await saveTabs([
      {'sourceId': const LocalSource().id},
    ]);

    await pump(tester);

    expect(
      restored().map((t) => t['sourceId']),
      LocalShellBackend.isSupported ? [const LocalSource().id] : isEmpty,
    );
  });

  testWidgets('but comes back closed — nothing starts a shell on its own', (
    tester,
  ) async {
    // Reported from a device: opening the terminal tab started the shell on
    // that device, because restoring ended by selecting the first tab and
    // showing a terminal is what starts it. On iOS that boots the Linux guest.
    // The tab is remembered; starting it is a decision, and arriving on this
    // tab is not one.
    if (!LocalShellBackend.isSupported) return;
    await saveTabs([
      {'sourceId': const LocalSource().id},
    ]);

    await pump(tester);

    expect(restored(), hasLength(1), reason: 'the tab is still remembered');
    expect(
      find.byType(SSHPage),
      findsNothing,
      reason:
          'a terminal built is a terminal started — the page view only '
          'builds the tab it is showing, so this is the whole of it',
    );
  });

  testWidgets('a server still opens on sight, as it always did', (
    tester,
  ) async {
    // The other half: passing over the local shell must not turn restoring
    // into a set of tabs that all sit there closed.
    Stores.server.put(spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u'));
    await saveTabs([
      {'sourceId': const LocalSource().id},
      {'sourceId': 'srv-1'},
    ]);

    await pump(tester);

    expect(find.byType(SSHPage), findsOneWidget);
  });
}
