import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/storage/tab.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

/// What the file tab reopens with.
///
/// It held its sessions in a `RestorableString` until this: registered,
/// readable within a session, and gone on every relaunch — because the route
/// `MaterialApp.home` builds hands its subtree no bucket, which
/// `test/restoration_bucket_test.dart` measures. So "the file tab reopens the
/// same servers, each in the directory it was left in" was a line on a
/// checklist for something that had never once worked, and checking it by hand
/// would have found a broken feature and no reason for it.
///
/// It is in Hive now, where the terminal tab's has been since the same
/// measurement was made there.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-filetab-');
    await openTestDb();
    // In memory: this tree writes as it builds, and a test has no
    // business leaving a database behind.
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<HistoryStore>(HistoryStore('history_test'));
    // A restored server session opens its browser, which now connects rather
    // than reporting that it is not connected — so an unreachable fixture
    // leaves a timer running. One second, pumped past below.
    Stores.setting.timeout.put(1);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> saveTabs(List<Map<String, dynamic>> tabs) async {
    Stores.history.fileTabs.put(jsonEncode(tabs));
  }

  /// The tab set as the page wrote it back — one entry per session.
  ///
  /// Read from the store rather than counted on screen: the strip draws a
  /// label per session and the picker lists every server by the same name, so
  /// a text finder cannot tell two sessions from one drawn twice.
  List<Map<String, dynamic>> saved() {
    final raw = Stores.history.fileTabs.fetch();
    if (raw.isEmpty) return const [];
    return [
      for (final e in jsonDecode(raw) as List)
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
          home: const Scaffold(body: FileTabPage()),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Past the connect timeout a restored server session starts, so nothing
    // is left pending when the tree goes away.
    await tester.pump(const Duration(seconds: 2));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('a fresh start opens on this device', (tester) async {
    // Nothing saved: the picker would cost a tap to choose the one place that
    // is always reachable, so the device opens instead.
    await pump(tester);

    expect(saved().map((t) => t['kind']), ['local']);
  });

  testWidgets('a saved local session comes back in its directory', (
    tester,
  ) async {
    await saveTabs([
      {'kind': 'local', 'path': '/tmp/somewhere'},
    ]);

    await pump(tester);

    expect(saved(), hasLength(1));
    expect(saved().single['path'], '/tmp/somewhere');
  });

  testWidgets('a saved server session comes back, in its directory', (
    tester,
  ) async {
    // The line this existed for.
    Stores.server.put(spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u'));
    await saveTabs([
      {'kind': 'server', 'serverId': 'srv-1', 'path': '/var/log'},
    ]);

    await pump(tester);

    final tabs = saved();
    expect(tabs.map((t) => t['serverId']), ['srv-1']);
    expect(tabs.single['path'], '/var/log');
  });

  testWidgets('a session whose server was deleted is dropped', (tester) async {
    // Not an error tab, and not a crash out of the loop that would take the
    // others with it.
    Stores.server.put(spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u'));
    await saveTabs([
      {'kind': 'server', 'serverId': 'srv-1', 'path': '/etc'},
      {'kind': 'server', 'serverId': 'srv-gone', 'path': '/etc'},
    ]);

    await pump(tester);

    expect(saved().map((t) => t['serverId']), ['srv-1']);
  });

  testWidgets('everything gone falls back to this device', (tester) async {
    // Rather than the empty page this tab no longer opens with.
    await saveTabs([
      {'kind': 'server', 'serverId': 'srv-gone', 'path': '/etc'},
    ]);

    await pump(tester);

    expect(saved().map((t) => t['kind']), ['local']);
  });

  testWidgets('a record written before `kind` existed still reads', (
    tester,
  ) async {
    // The migration residue the restore path carries a TODO for: local was
    // implied by the absence of a server id.
    await saveTabs([
      {'path': '/tmp/old'},
    ]);

    await pump(tester);

    expect(saved().map((t) => t['kind']), ['local']);
    expect(saved().single['path'], '/tmp/old');
  });

  testWidgets('an unreadable set does not throw', (tester) async {
    Stores.history.fileTabs.put('{{{ not json');

    await pump(tester);

    expect(find.byType(FileTabPage), findsOneWidget);
  });
}
