import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/workspace/tree.dart';
import 'package:server_box/data/model/workspace/workspace.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/workspace/tab.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

/// p1 | (p2 / p3), every tab a terminal on `srv-1`.
Workspace _three() => Workspace(
  id: 'w1',
  name: 'Release',
  root: const WsSplit(
    WsAxis.row,
    0.5,
    WsLeaf('p1'),
    WsSplit(WsAxis.col, 0.5, WsLeaf('p2'), WsLeaf('p3')),
  ),
  panes: {
    for (final id in ['p1', 'p2', 'p3'])
      id: WsPane(
        id: id,
        tabs: [
          WsTab(id: 't$id', view: WorkspaceView.term, serverId: 'srv-1'),
        ],
        activeId: 't$id',
      ),
  },
  focusId: 'p1',
  prevId: 'p2',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<HistoryStore>(HistoryStore('history_test'));
    getIt.registerSingleton<SnippetStore>(SnippetStore());
    getIt.registerSingleton<ConnectionStatsStore>(ConnectionStatsStore.instance);
    // Not connected at launch: its tabs come back asleep, which is what these
    // tests look at, and nothing here opens a real connection.
    Stores.server.put(
      spiFixture(
        id: 'srv-1',
        name: 'web',
        ip: 'h',
        user: 'u',
        autoConnect: false,
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  void save(List<Workspace> all) {
    Stores.history.workspaces.put(
      jsonEncode([for (final ws in all) ws.toJson()]),
    );
  }

  List<Workspace> saved() => [
    for (final e in jsonDecode(Stores.history.workspaces.fetch()) as List)
      Workspace.fromJson(e, keep: (_) => true)!,
  ];

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: WorkspaceTabPage()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('a fresh start is one empty workspace', (tester) async {
    await pump(tester, const Size(1200, 800));
    expect(find.text(l10n.workspaceEmpty), findsOneWidget);
    expect(find.text(l10n.workspaceNewTab), findsOneWidget);
  });

  testWidgets('restored tabs wait to be asked to connect', (tester) async {
    save([_three()]);
    await pump(tester, const Size(1200, 800));
    // One per pane, every one asleep.
    expect(find.text(l10n.connect), findsNWidgets(3));
    expect(find.text('Release'), findsOneWidget);
  });

  testWidgets('a tab is selected on the tap, not a double-tap later', (
    tester,
  ) async {
    final ws = _three().addTab(
      'p1',
      const WsTab(id: 'x', view: WorkspaceView.status, serverId: 'srv-1'),
      newPaneId: 'n',
    );
    save([ws.selectTab('p1', 'tp1')]);
    await pump(tester, const Size(1200, 800));

    await tester.tap(find.text(l10n.status));
    // One frame, well inside the double-tap timeout: the strip waited that
    // out before letting a tab's own tap through.
    await tester.pump();
    expect(saved().single.panes['p1']!.activeId, 'x');
  });

  testWidgets('a phone shows the focused pane and the one before it', (
    tester,
  ) async {
    save([_three().focus('p3')]);
    await pump(tester, const Size(390, 800));
    expect(find.text(l10n.connect), findsNWidgets(2));
    expect(find.byTooltip(l10n.workspacePanes), findsOneWidget);
  });

  testWidgets('the keyboard maximizes, and closes with undo', (tester) async {
    save([_three()]);
    await pump(tester, const Size(1200, 800));

    Future<void> chord(LogicalKeyboardKey key, {bool shift = false}) async {
      // The host's keyboard, which is what the app asks — see
      // `KbPlatform.current`.
      final apple = Platform.isMacOS;
      final mods = [
        LogicalKeyboardKey.controlLeft,
        apple ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.altLeft,
        if (shift) LogicalKeyboardKey.shiftLeft,
      ];
      for (final m in mods) {
        await tester.sendKeyDownEvent(m);
      }
      await tester.sendKeyEvent(key);
      for (final m in mods.reversed) {
        await tester.sendKeyUpEvent(m);
      }
      await tester.pump(const Duration(milliseconds: 600));
    }

    await chord(LogicalKeyboardKey.keyM);
    expect(saved().single.maxId, 'p1');
    expect(find.text(l10n.connect), findsOneWidget);
    await chord(LogicalKeyboardKey.keyM);
    expect(saved().single.maxId, isNull);

    await chord(LogicalKeyboardKey.keyW);
    expect(saved().single.order, ['p2', 'p3']);
    await chord(LogicalKeyboardKey.keyT, shift: true);
    expect(saved().single.order, ['p1', 'p2', 'p3']);
    // The toast's timer.
    await tester.pump(const Duration(seconds: 6));
  });
}
