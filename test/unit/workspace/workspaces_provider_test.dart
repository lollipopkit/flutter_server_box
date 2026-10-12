import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/workspace/tree.dart';
import 'package:server_box/data/model/workspace/workspace.dart';
import 'package:server_box/data/provider/workspace.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/spi_fixture.dart';
import '../../helpers/test_db.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<HistoryStore>(HistoryStore('history_test'));
    Stores.server.put(spiFixture(id: 's1', name: 'web', ip: 'h', user: 'u'));
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await getIt.reset();
    await closeTestDb();
  });

  Workspaces ops() => container.read(workspacesProvider.notifier);
  WorkspacesState state() => container.read(workspacesProvider);

  group('a shell handed over', () {
    TerminalSession shell() =>
        TerminalSession(source: ServerSource(Stores.server.fetch().single));

    test('is kept for its tab until the tab takes it', () {
      final s = shell();
      ops().adoptSession(null, 's1', s);
      final tab = state().current.tabs.single;
      expect(ops().takeSession(tab.id), same(s));
      expect(ops().takeSession(tab.id), isNull);
    });

    test('is let go of when its tab goes before it was shown', () {
      ops().adoptSession(null, 's1', shell());
      final ws = state().current;
      final tab = ws.tabs.single;
      ops().closeTab(ws.focusId!, tab.id);
      expect(ops().takeSession(tab.id), isNull);
    });

    test('is let go of when its workspace or server goes', () {
      ops().adoptSession(null, 's1', shell());
      final viaWorkspace = state().current.tabs.single.id;
      ops().close(state().index);
      expect(ops().takeSession(viaWorkspace), isNull);

      ops().adoptSession(null, 's1', shell());
      final viaServer = state().current.tabs.single.id;
      ops().removeServer('s1');
      expect(ops().takeSession(viaServer), isNull);
    });
  });

  test('closing a workspace that is not there changes nothing', () {
    ops().create();
    final before = state();
    ops().close(-1);
    ops().close(before.all.length);
    expect(identical(state(), before), isTrue);
  });

  test('a restore keeps the first of a repeated pane, leaf or tab', () {
    final pane = {
      'id': 'p1',
      'tabs': [
        {'id': 't1', 'view': 'term', 'server': 's1'},
        {'id': 't1', 'view': 'status', 'server': 's1'},
      ],
      'active': 't1',
    };
    Stores.history.workspaces.put(
      jsonEncode([
        {
          'id': 'w1',
          'name': 'w',
          'root': const WsSplit<String>(
            WsAxis.row,
            0.5,
            WsLeaf('p1'),
            WsLeaf('p1'),
          ).toJson((l) => l),
          'panes': [pane, pane],
        },
        // Another workspace naming the same tab.
        {
          'id': 'w2',
          'name': 'w2',
          'root': const WsLeaf<String>('p2').toJson((l) => l),
          'panes': [
            {
              'id': 'p2',
              'tabs': [
                {'id': 't1', 'view': 'term', 'server': 's1'},
              ],
              'active': 't1',
            },
          ],
        },
      ]),
    );
    final all = ProviderContainer().read(workspacesProvider).all;
    expect(all.first.order, ['p1']);
    expect(all.first.panes['p1']!.tabs.map((t) => t.view), [
      WorkspaceView.term,
    ]);
    expect(all.first.tabs, hasLength(1));
    // Its only tab was the repeat, so it is empty rather than sharing it.
    expect(all[1].isEmpty, isTrue);
  });
}
