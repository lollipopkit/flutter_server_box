import 'dart:async';


import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/core/llm/screen.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/workspace/workspace.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/selection.dart';
import 'package:server_box/data/provider/workspace.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/spi_fixture.dart';
import '../../helpers/test_db.dart';

Widget _page({Key? key, required SpiRequiredArgs args}) =>
    Text(args.spi.name, key: key);

Widget _plain({Key? key}) => Text('plain', key: key);

const _detail = AppRouteArg<void, SpiRequiredArgs>(
  page: _page,
  path: '/servers/detail',
);
const _firewall = AppRouteArg<void, SpiRequiredArgs>(
  page: _page,
  path: '/firewall',
);
const _settings = AppRouteNoArg<void>(page: _plain, path: '/settings');

void main() {
  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<HistoryStore>(HistoryStore('history_test'));
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  testWidgets('names what is on screen, and the server by the id its tools take', (
    tester,
  ) async {
    final web = spiFixture(id: 's1', name: 'web', ip: 'h', user: 'u');
    final db = spiFixture(id: 's2', name: 'db', ip: 'h2', user: 'u');
    Stores.server.put(web);
    Stores.server.put(db);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    // Set once per isolate: the one test in this file.
    AgentScope.container = c;
    c.read(serversProvider);
    String? at() => AgentScreen.describe(null);
    void go(AppTab tab) => c.read(currentHomeTabProvider.notifier).update(tab);

    expect(at(), isNull, reason: 'before the home page has said where it is');

    // The root navigator, and the server tab's own inside it, as the app
    // builds them.
    final root = GlobalKey<NavigatorState>();
    final tab = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: root,
        navigatorObservers: [AgentScreen.rootObserver],
        home: Navigator(
          key: tab,
          observers: [AgentScreen.tabObserver(AppTab.server)],
          onGenerateRoute: (_) =>
              MaterialPageRoute(builder: (_) => const Text('list')),
        ),
      ),
    );
    Future<void> settle() => tester.pumpAndSettle();

    go(AppTab.server);
    expect(at(), 'On screen: Server tab, the list of servers.');
    // In place, in a wide window.
    c.read(serverSelectionProvider.notifier).select('s2');
    expect(
      at(),
      'On screen: Server tab, the status page of server "db" (server_id: s2).',
    );
    c.read(serverSelectionProvider.notifier).select(null);

    // Pushed, on a phone; and any page pushed over it, marked or not.
    unawaited(_detail.go(tab.currentContext!, SpiRequiredArgs(web)));
    await settle();
    expect(
      at(),
      'On screen: Server tab, the status page of server "web" (server_id: s1).',
    );
    unawaited(_firewall.go(tab.currentContext!, SpiRequiredArgs(web)));
    await settle();
    expect(
      at(),
      'On screen: Server tab, the page "/firewall" of server "web" (server_id: s1).',
    );

    // A dialog is over the page, not in place of it.
    unawaited(
      showDialog<void>(
        context: tab.currentContext!,
        builder: (_) => const Text('dialog'),
      ),
    );
    await settle();
    expect(at(), contains('"/firewall"'));
    root.currentState!.pop();
    await settle();

    // The name as it is now, not as it was when the page opened.
    Stores.server.put(web.copyWith(name: 'web-prod'));
    await tester.runAsync(c.read(serversProvider.notifier).reload);
    expect(at(), contains('server "web-prod" (server_id: s1)'));

    // Over every tab.
    unawaited(_settings.go(root.currentContext!));
    await settle();
    expect(at(), 'On screen: the settings.');
    root.currentState!.pop();
    tab.currentState!
      ..pop()
      ..pop();
    await settle();
    expect(at(), 'On screen: Server tab, the list of servers.');

    // In place of the tabs, in a wide window.
    AgentScreen.settingsOpen = true;
    expect(at(), 'On screen: Settings.');
    AgentScreen.settingsOpen = false;

    go(AppTab.ssh);
    expect(at(), 'On screen: Terminal tab, picking a server to open.');
    final hideDb = AgentScreen.terminal(() => ServerSource(db));
    expect(
      at(),
      'On screen: Terminal tab, a terminal on server "db" (server_id: s2).',
    );
    // A tab built again before the old one is gone: the old one's removal
    // leaves the new one's in place.
    final hideLocal = AgentScreen.terminal(() => const LocalSource());
    hideDb();
    expect(at(), 'On screen: Terminal tab, a terminal on this device.');
    hideLocal();

    go(AppTab.file);
    final hideFiles = AgentScreen.files(() => 'the transfer list');
    addTearDown(hideFiles);
    expect(at(), 'On screen: File tab, the transfer list.');

    go(AppTab.workspace);
    final ws = c.read(workspacesProvider).current.name;
    expect(at(), 'On screen: Workspace "$ws", empty.');
    c.read(workspacesProvider.notifier).addTab(null, WorkspaceView.docker, 's2');
    expect(
      at(),
      'On screen: Workspace "$ws", the containers of server "db" (server_id: s2).',
    );

    go(AppTab.remoteDesktop);
    expect(at(), 'On screen: Remote desktop tab.');

    // The chat's own tab says nothing, so what was said last still stands.
    go(AppTab.agent);
    expect(at(), isNull);
  });
}
