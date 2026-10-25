import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/core/llm/screen.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/workspace/workspace.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/workspace.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/spi_fixture.dart';
import '../../helpers/test_db.dart';

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

  testWidgets('names the server on screen, by the id its tools take', (
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
    String? at([ChatMeta? meta]) => AgentScreen.describe(meta);
    void go(AppTab tab) => c.read(currentHomeTabProvider.notifier).update(tab);

    expect(at(), isNull, reason: 'before the home page has said where it is');

    // The server tab, with its own navigator, as the home page builds it.
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: AgentScreenTab(
          tab: AppTab.server,
          child: Navigator(
            key: nav,
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const Text('list')),
          ),
        ),
      ),
    );
    go(AppTab.server);
    expect(at(), 'On screen: Server tab, the list of servers.');

    nav.currentState!.push(
      MaterialPageRoute(
        builder: (_) => AgentSubject(
          page: 'the status page',
          spi: web,
          child: const Text('web'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      at(),
      'On screen: Server tab, the status page of server "web" (server_id: s1).',
    );

    // Something pushed over it is what is on screen now.
    nav.currentState!.push(
      MaterialPageRoute(builder: (_) => const Text('edit')),
    );
    await tester.pumpAndSettle();
    expect(at(), 'On screen: Server tab, the list of servers.');
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(at(), contains('"web"'));

    // A page about no server, pushed over one that is.
    nav.currentState!.push(
      MaterialPageRoute(
        builder: (_) =>
            const AgentSubject(page: 'the transfer list', child: Text('t')),
      ),
    );
    await tester.pumpAndSettle();
    expect(at(), 'On screen: Server tab, the transfer list.');
    nav.currentState!.pop();
    await tester.pumpAndSettle();

    // A terminal's chat is about its own server and is told nothing.
    expect(
      at(ChatMeta(id: 'x', updatedAt: DateTime(2026), scope: AgentScope.terminal('s1'))),
      isNull,
    );

    go(AppTab.ssh);
    expect(at(), 'On screen: Terminal tab, picking a server to open.');
    final hideDb = AgentScreen.terminal(() => (spi: db));
    expect(
      at(),
      'On screen: Terminal tab, a terminal on server "db" (server_id: s2).',
    );
    // A tab built again before the old one is gone: the old one's removal
    // leaves the new one's in place.
    final hideLocal = AgentScreen.terminal(() => (spi: null));
    hideDb();
    expect(at(), 'On screen: Terminal tab, a terminal on this device.');
    hideLocal();

    go(AppTab.file);
    var transfers = false;
    final hideFiles = AgentScreen.files(
      () => (spi: web, path: '/var/log', transfers: transfers),
    );
    addTearDown(hideFiles);
    expect(
      at(),
      'On screen: File tab, the files of server "web" (server_id: s1) at /var/log.',
    );
    transfers = true;
    expect(
      at(),
      'On screen: File tab, the transfer list, over the files of server "web" (server_id: s1) at /var/log.',
    );

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
