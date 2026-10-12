import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/workspace/tree.dart';
import 'package:server_box/data/model/workspace/workspace.dart';

WsTab _tab(String id, {String server = 's1', WorkspaceView? view}) =>
    WsTab(id: id, view: view ?? WorkspaceView.term, serverId: server);

/// p1 | (p2 / p3), each pane one tab named after it.
Workspace _three() {
  const root = WsSplit<String>(
    WsAxis.row,
    0.5,
    WsLeaf('p1'),
    WsSplit(WsAxis.col, 0.5, WsLeaf('p2'), WsLeaf('p3')),
  );
  return Workspace(
    id: 'w',
    name: 'w',
    root: root,
    panes: {
      for (final id in ['p1', 'p2', 'p3'])
        id: WsPane(id: id, tabs: [_tab('t$id')], activeId: 't$id'),
    },
    focusId: 'p1',
    prevId: 'p2',
  );
}

void main() {
  group('tree', () {
    test('leaves are in reading order', () {
      expect(_three().order, ['p1', 'p2', 'p3']);
    });

    test('removing a leaf hands its space to its sibling', () {
      final root = _three().root!.removeLeaf('p2')!;
      expect(root.leaves, ['p1', 'p3']);
      expect((root as WsSplit).b, isA<WsLeaf<String>>());
      expect(const WsLeaf('x').removeLeaf('x'), isNull);
    });

    test('splitting puts the new leaf on the asked side', () {
      final root = const WsLeaf('a').splitLeaf('a', WsAxis.col, 'b');
      expect(root.leaves, ['a', 'b']);
      final before = const WsLeaf(
        'a',
      ).splitLeaf('a', WsAxis.row, 'b', before: true);
      expect(before.leaves, ['b', 'a']);
    });

    test('ratios are clamped and set by path', () {
      final root = _three().root!.withRatio([true], 0.99) as WsSplit<String>;
      final inner = root.b as WsSplit<String>;
      expect(inner.ratio, WsSplit.maxRatio);
      expect(root.ratio, 0.5);
    });

    test('layout gives seams one pixel and panes the rest', () {
      final out = _three().root!.layout(
        const Rect.fromLTWH(0, 0, 201, 101),
        idOf: (id) => id,
      );
      final rects = {for (final p in out.panes) p.id: p.rect};
      expect(rects['p1'], const Rect.fromLTWH(0, 0, 100, 101));
      expect(rects['p2']!.left, 101);
      expect(rects['p2']!.width, 100);
      expect(rects['p2']!.height + rects['p3']!.height + 1, 101);
      expect(out.seams, hasLength(2));
      expect(out.seams.first.path, isEmpty);
    });

    test('focus moves to what is on that side', () {
      final panes = _three().root!.layout(
        const Rect.fromLTWH(0, 0, 200, 100),
        idOf: (id) => id,
      ).panes;
      expect(neighbourPane(panes, 'p1', WsDirection.right), 'p2');
      expect(neighbourPane(panes, 'p3', WsDirection.left), 'p1');
      expect(neighbourPane(panes, 'p2', WsDirection.down), 'p3');
      expect(neighbourPane(panes, 'p1', WsDirection.left), isNull);
    });

    test('json round-trips, and an unreadable split keeps its children', () {
      final root = _three().root!;
      final json = jsonDecode(jsonEncode(root.toJson((l) => l)));
      expect(
        WsNode.fromJson<String>(json, (r) => r as String?)!.leaves,
        root.leaves,
      );
      final broken = {
        'split': 'diagonal',
        'ratio': 0.5,
        'a': {'leaf': 'x'},
        'b': {'leaf': 'y'},
      };
      expect(
        WsNode.fromJson<String>(broken, (r) => r as String?)!.leaves,
        ['x'],
      );
    });
  });

  group('workspace', () {
    test('closing the last tab of a pane closes the pane', () {
      final ws = _three().closeTab('p1', 'tp1');
      expect(ws.order, ['p2', 'p3']);
      expect(ws.panes.keys, unorderedEquals(['p2', 'p3']));
      expect(ws.focusId, 'p2');
    });

    test('closing the active tab selects the one before it', () {
      var ws = _three().addTab('p1', _tab('a'), newPaneId: 'n');
      ws = ws.addTab('p1', _tab('b'), newPaneId: 'n');
      ws = ws.closeTab('p1', 'b');
      expect(ws.panes['p1']!.activeId, 'a');
    });

    test('an empty workspace gets its first pane from a new tab', () {
      final ws = const Workspace(
        id: 'w',
        name: 'w',
      ).addTab(null, _tab('t'), newPaneId: 'p');
      expect(ws.order, ['p']);
      expect(ws.focusId, 'p');
    });

    test('split focuses the new half and ends a maximize', () {
      final ws = _three()
          .copyWith(maxId: () => 'p1')
          .split('p1', WsAxis.row, _tab('n'), newPaneId: 'p4');
      expect(ws.order, ['p1', 'p4', 'p2', 'p3']);
      expect(ws.focusId, 'p4');
      expect(ws.prevId, 'p1');
      expect(ws.maxId, isNull);
    });

    test('dropping on an edge splits, in the centre merges', () {
      final edge = _three().dropTab(
        'p2',
        'tp2',
        'p1',
        WsDropZone.left,
        newPaneId: 'n',
      );
      expect(edge.order, ['n', 'p1', 'p3']);
      final centre = _three().dropTab(
        'p2',
        'tp2',
        'p1',
        WsDropZone.center,
        newPaneId: 'n',
      );
      expect(centre.order, ['p1', 'p3']);
      expect(centre.panes['p1']!.tabs.map((t) => t.id), ['tp1', 'tp2']);
    });

    test('a pane cannot be split by dropping its only tab on itself', () {
      final ws = _three();
      expect(
        identical(
          ws.dropTab('p1', 'tp1', 'p1', WsDropZone.right, newPaneId: 'n'),
          ws,
        ),
        isTrue,
      );
    });

    test('moving within a strip reorders', () {
      var ws = _three().addTab('p1', _tab('a'), newPaneId: 'n');
      ws = ws.moveTab('p1', 'a', 'p1', beforeTabId: 'tp1');
      expect(ws.panes['p1']!.tabs.map((t) => t.id), ['a', 'tp1']);
    });

    test('the narrow pair is focus and previous, in reading order', () {
      final ws = _three().focus('p3');
      expect(ws.narrowPair(), ['p1', 'p3']);
    });

    test('restored tabs are asleep, and waking one wakes its server', () {
      final ws = _three();
      final back = Workspace.fromJson(
        jsonDecode(jsonEncode(ws.toJson())),
        keep: (_) => true,
      )!;
      expect(back.tabs.every((t) => !t.live), isTrue);
      expect(back.order, ws.order);
      expect(back.wake('s1').tabs.every((t) => t.live), isTrue);
    });

    test('a tab on a deleted server is dropped on restore, with its pane', () {
      final ws = _three().addTab(
        'p2',
        _tab('x', server: 's2'),
        newPaneId: 'n',
      );
      final json = jsonDecode(jsonEncode(ws.toJson()));
      final back = Workspace.fromJson(json, keep: (t) => t.serverId == 's2')!;
      expect(back.order, ['p2']);
      expect(back.focusId, 'p2');
    });

    test('renaming and removing a server reach every tab', () {
      final renamed = _three().renameServer('s1', 's9');
      expect(renamed.tabs.every((t) => t.serverId == 's9'), isTrue);
      expect(_three().removeServer('s1').isEmpty, isTrue);
    });
  });

  group('template', () {
    test('keeps views and layout, and builds on one server', () {
      final t = WsTemplate.of(
        _three().addTab(
          'p1',
          _tab('d', view: WorkspaceView.docker),
          newPaneId: 'n',
        ),
        id: 't',
        name: 'x',
      )!;
      final back = WsTemplate.fromJson(jsonDecode(jsonEncode(t.toJson())))!;
      var n = 0;
      final ws = back.build(
        workspaceId: 'w2',
        name: 'x',
        serverId: 'db',
        newId: () => 'id${n++}',
      );
      expect(ws.order, hasLength(3));
      expect(ws.panes[ws.order.first]!.tabs.map((t) => t.view), [
        WorkspaceView.term,
        WorkspaceView.docker,
      ]);
      expect(ws.tabs.every((t) => t.serverId == 'db' && t.live), isTrue);
    });

    test('a leaf without views gets no pane', () {
      var n = 0;
      Workspace build(WsNode<List<WorkspaceView>> root) =>
          WsTemplate(id: 't', name: 'x', root: root).build(
            workspaceId: 'w',
            name: 'x',
            serverId: 'db',
            newId: () => 'id${n++}',
          );
      final ws = build(
        const WsSplit(
          WsAxis.row,
          0.5,
          WsLeaf([WorkspaceView.term]),
          WsLeaf(<WorkspaceView>[]),
        ),
      );
      expect(ws.order, hasLength(1));
      expect(ws.focusId, ws.order.single);
      expect(build(const WsLeaf(<WorkspaceView>[])).isEmpty, isTrue);
    });

    test('an empty workspace has nothing to save', () {
      expect(
        WsTemplate.of(const Workspace(id: 'w', name: 'w'), id: 't', name: 'x'),
        isNull,
      );
    });
  });
}
