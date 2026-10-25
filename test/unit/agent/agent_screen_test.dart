import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/core/llm/screen.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/workspace/workspace.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/selection.dart';
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

  test('names the server on screen, by the id its tools take', () {
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

    go(AppTab.server);
    expect(at(), 'On screen: Server tab, the list of servers.');
    c.read(serverSelectionProvider.notifier).select('s1');
    expect(at(), 'On screen: Server tab, the status page of server "web" (server_id: s1).');

    go(AppTab.ssh);
    expect(at(), 'On screen: Terminal tab, picking a server to open.');
    AgentScreen.terminal = () => (spi: db);
    addTearDown(() => AgentScreen.terminal = () => null);
    expect(at(), 'On screen: Terminal tab, a terminal on server "db" (server_id: s2).');
    AgentScreen.terminal = () => (spi: null);
    expect(at(), 'On screen: Terminal tab, a terminal on this device.');

    go(AppTab.file);
    AgentScreen.files = () => (spi: web, path: '/var/log');
    addTearDown(() => AgentScreen.files = () => null);
    expect(at(), 'On screen: File tab, the files of server "web" (server_id: s1) at /var/log.');

    go(AppTab.workspace);
    final ws = c.read(workspacesProvider).current.name;
    expect(at(), 'On screen: Workspace "$ws", empty.');
    c.read(workspacesProvider.notifier).addTab(null, WorkspaceView.docker, 's2');
    expect(at(), 'On screen: Workspace "$ws", the containers of server "db" (server_id: s2).');

    // The chat's own tab says nothing, so what was said last still stands.
    go(AppTab.agent);
    expect(at(), isNull);
  });
}
