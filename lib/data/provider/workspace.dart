import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/workspace/tree.dart';
import 'package:server_box/data/model/workspace/workspace.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_session.dart';

part 'workspace.g.dart';

/// What was closed last, for undo: the whole workspace as it was.
///
/// A snapshot rather than the closed tab, because a tab's place is a position
/// in a tree that the close itself rearranged — putting one back means putting
/// the tree back.
typedef WsClosed = ({String workspaceId, Workspace before});

final class WorkspacesState {
  const WorkspacesState({required this.all, required this.index, this.closed});

  /// Never empty: closing the last one is refused, and a fresh install starts
  /// with one, empty.
  final List<Workspace> all;
  final int index;
  final WsClosed? closed;

  Workspace get current => all[index];

  WorkspacesState copyWith({
    List<Workspace>? all,
    int? index,
    WsClosed? Function()? closed,
  }) => WorkspacesState(
    all: all ?? this.all,
    index: index ?? this.index,
    closed: closed != null ? closed() : this.closed,
  );
}

/// Every workspace, and which one is on screen.
///
/// Kept alive and app-wide rather than in the tab's state: the terminal tab
/// moves a session into one, and quick open lists them, without the workspace
/// tab having been built.
@Riverpod(keepAlive: true)
class Workspaces extends _$Workspaces {
  /// Shells handed over by another page, waiting for the tab that shows them
  /// to be built. Keyed by that tab's id; taken once.
  final _handoff = <String, TerminalSession>{};

  @override
  WorkspacesState build() {
    // Every way a tab leaves — closed, its pane or workspace closed, its
    // server deleted, an undo replacing the workspace — goes through the
    // state, so this is the one place a shell still waiting for its tab is
    // let go of. Its tab was never built, so nothing else holds it.
    listenSelf((_, next) => _dropOrphans(next));
    final all = _restore();
    final at = Stores.history.workspaceIndex.fetch();
    return WorkspacesState(
      all: all,
      index: at >= 0 && at < all.length ? at : 0,
    );
  }

  /// Closes the handed-over shells whose tab is in no workspace any more.
  void _dropOrphans(WorkspacesState next) {
    if (_handoff.isEmpty) return;
    final alive = {
      for (final ws in next.all)
        for (final t in ws.tabs) t.id,
    };
    final gone = [
      for (final id in _handoff.keys)
        if (!alive.contains(id)) id,
    ];
    for (final id in gone) {
      _handoff.remove(id)?.close();
    }
  }

  /// What was saved, minus tabs on servers that are gone. Read entry by entry
  /// like the terminal tab's set: one unreadable workspace costs itself.
  static List<Workspace> _restore() {
    final out = <Workspace>[];
    final raw = Stores.history.workspaces.fetch();
    if (raw.isNotEmpty) {
      try {
        final spis = Stores.server.fetch();
        final servers = {for (final s in spis) s.id};
        // A tab's id keys its page across every workspace, so one written
        // twice — by hand, by a merge — keeps its first place only.
        final tabIds = <String>{};
        final list = jsonDecode(raw);
        if (list is List) {
          for (final e in list) {
            final ws = Workspace.fromJson(
              e,
              keep: (t) => servers.contains(t.serverId) && tabIds.add(t.id),
            );
            if (ws == null) continue;
            // Asleep only where the server is: one set to connect at launch is
            // being connected by the server tab right now, and a tab of it
            // asking to be told to connect is a question already answered.
            var woken = ws;
            for (final spi in spis) {
              if (spi.autoConnect) woken = woken.wake(spi.id);
            }
            out.add(woken);
          }
        }
      } catch (e, s) {
        Loggers.app.warning('Unreadable workspaces', e, s);
      }
    }
    if (out.isEmpty) out.add(Workspace(id: newWsId(), name: _defaultName(1)));
    return out;
  }

  static String _defaultName(int n) => '${l10n.workspace} $n';

  void _save() {
    Stores.history.workspaces.put(
      jsonEncode([for (final ws in state.all) ws.toJson()]),
    );
    Stores.history.workspaceIndex.put(state.index);
  }

  /// The current workspace replaced by what [f] makes of it.
  ///
  /// [persist] off for a change made many times a second — a seam being
  /// dragged — whose last value is saved once the drag ends.
  void edit(Workspace Function(Workspace ws) f, {bool persist = true}) {
    final next = f(state.current);
    if (identical(next, state.current)) return;
    final all = [...state.all];
    all[state.index] = next;
    state = state.copyWith(all: all);
    if (persist) _save();
  }

  void save() => _save();

  void select(int index) {
    if (index < 0 || index >= state.all.length || index == state.index) return;
    state = state.copyWith(index: index);
    _save();
  }

  void selectId(String id) =>
      select(state.all.indexWhere((ws) => ws.id == id));

  /// A new, empty workspace, selected.
  Workspace create({String? name}) {
    final ws = Workspace(
      id: newWsId(),
      name: name ?? _defaultName(state.all.length + 1),
    );
    _append(ws);
    return ws;
  }

  void _append(Workspace ws) {
    state = state.copyWith(all: [...state.all, ws], index: state.all.length);
    _save();
  }

  void rename(int index, String name) {
    final ws = state.all.elementAtOrNull(index);
    if (ws == null || name.isEmpty || ws.name == name) return;
    final all = [...state.all];
    all[index] = ws.copyWith(name: name);
    state = state.copyWith(all: all);
    _save();
  }

  /// Closes the workspace at [index], and every tab in it. The last one
  /// stays: there would be nothing for the tab to show.
  void close(int index) {
    if (state.all.length < 2 || index < 0 || index >= state.all.length) return;
    final all = [...state.all]..removeAt(index);
    var at = state.index;
    if (index < at) at -= 1;
    if (at >= all.length) at = all.length - 1;
    state = state.copyWith(all: all, index: at);
    _save();
  }

  /// [f] applied, with what came before it kept for undo.
  void _closing(Workspace Function(Workspace ws) f) {
    final before = state.current;
    edit(f);
    state = state.copyWith(
      closed: () => (workspaceId: before.id, before: before),
    );
  }

  void closeTab(String paneId, String tabId) =>
      _closing((ws) => ws.closeTab(paneId, tabId));

  void closePane(String paneId) => _closing((ws) => ws.removePane(paneId));

  /// Puts back what was closed last. False when there is nothing to put back,
  /// or its workspace has since been closed itself.
  bool reopen() {
    final closed = state.closed;
    if (closed == null) return false;
    final at = state.all.indexWhere((ws) => ws.id == closed.workspaceId);
    if (at < 0) {
      state = state.copyWith(closed: () => null);
      return false;
    }
    final all = [...state.all];
    all[at] = closed.before;
    state = state.copyWith(all: all, index: at, closed: () => null);
    _save();
    return true;
  }

  /// A new tab of [view] on [serverId], in [paneId] or the focused pane.
  WsTab addTab(
    String? paneId,
    WorkspaceView view,
    String serverId, {
    TerminalSession? session,
  }) {
    final tab = WsTab(id: newWsId(), view: view, serverId: serverId);
    if (session != null) _handoff[tab.id] = session;
    edit((ws) => ws.addTab(paneId, tab, newPaneId: newWsId()));
    return tab;
  }

  /// [paneId] split along [axis], the new half showing what [paneId] shows.
  void split(String paneId, WsAxis axis) => edit((ws) {
    final pane = ws.panes[paneId];
    if (pane == null) return ws;
    final from = pane.active;
    final tab = WsTab(id: newWsId(), view: from.view, serverId: from.serverId);
    return ws.split(paneId, axis, tab, newPaneId: newWsId());
  });

  void dropTab(String fromPane, String tabId, String toPane, WsDropZone zone) =>
      edit(
        (ws) =>
            ws.dropTab(fromPane, tabId, toPane, zone, newPaneId: newWsId()),
      );

  void moveTab(
    String fromPane,
    String tabId,
    String toPane, {
    String? beforeTabId,
  }) => edit(
    (ws) => ws.moveTab(fromPane, tabId, toPane, beforeTabId: beforeTabId),
  );

  void focus(String paneId) => edit((ws) => ws.focus(paneId));

  void selectTab(String paneId, String tabId) =>
      edit((ws) => ws.selectTab(paneId, tabId));

  /// The focused pane's next or previous tab, wrapping.
  void stepTab(int delta) => edit((ws) {
    final pane = ws.focused;
    if (pane == null || pane.tabs.length < 2) return ws;
    final n = pane.tabs.length;
    final next = pane.tabs[(pane.activeIndex + delta + n) % n];
    return ws.selectTab(pane.id, next.id);
  });

  void toggleMax(String paneId) => edit(
    (ws) => ws
        .copyWith(maxId: () => ws.maxId == paneId ? null : paneId)
        .focus(paneId),
  );

  void restore() => edit((ws) => ws.copyWith(maxId: () => null));

  /// Returns whether sync is now on.
  bool toggleSync() {
    final on = !state.current.sync;
    edit((ws) => ws.copyWith(sync: on));
    return on;
  }

  void setRatio(WsPath path, double ratio, {bool persist = true}) => edit(
    (ws) => ws.copyWith(root: () => ws.root?.withRatio(path, ratio)),
    persist: persist,
  );

  void setNarrowRatio(double ratio, {bool persist = true}) => edit(
    (ws) => ws.copyWith(narrowRatio: WsSplit.clampRatio(ratio)),
    persist: persist,
  );

  /// Every tab of [serverId] connects, in every workspace: the server is one
  /// connection, wherever its tabs are.
  void wake(String serverId) => _editAll((ws) => ws.wake(serverId));

  /// A new workspace laid out as [template], on [serverId].
  Workspace applyTemplate(WsTemplate template, String serverId) {
    final ws = template.build(
      workspaceId: newWsId(),
      name: template.name,
      serverId: serverId,
      newId: newWsId,
    );
    _append(ws);
    return ws;
  }

  /// [session] carried into a new terminal tab of [workspaceId]'s focused
  /// pane — a new workspace when null — still connected.
  void adoptSession(String? workspaceId, String serverId, TerminalSession session) {
    if (workspaceId == null) {
      create();
    } else {
      selectId(workspaceId);
    }
    addTab(null, WorkspaceView.term, serverId, session: session);
  }

  /// The shell handed over for [tabId], once.
  TerminalSession? takeSession(String tabId) => _handoff.remove(tabId);

  /// A server's tabs follow it to its new id.
  void renameServer(String oldId, String newId) =>
      _editAll((ws) => ws.renameServer(oldId, newId));

  /// A deleted server's tabs close, and so does any pane left empty. What was
  /// closed before can no longer be put back: it may hold the server too.
  void removeServer(String serverId) {
    if (_editAll((ws) => ws.removeServer(serverId))) {
      state = state.copyWith(closed: () => null);
    }
  }

  /// Every workspace through [f]; whether any changed.
  bool _editAll(Workspace Function(Workspace ws) f) {
    final all = [for (final ws in state.all) f(ws)];
    var changed = false;
    for (var i = 0; i < all.length; i++) {
      if (!identical(all[i], state.all[i])) changed = true;
    }
    if (!changed) return false;
    state = state.copyWith(all: all);
    _save();
    return true;
  }
}

/// The saved layouts.
@Riverpod(keepAlive: true)
class WorkspaceTemplates extends _$WorkspaceTemplates {
  @override
  List<WsTemplate> build() {
    final raw = Stores.setting.workspaceTemplates.fetch();
    if (raw.isEmpty) return _defaults();
    try {
      final list = jsonDecode(raw);
      if (list is! List) return _defaults();
      return [for (final t in list.map(WsTemplate.fromJson)) ?t];
    } catch (e, s) {
      Loggers.app.warning('Unreadable workspace templates', e, s);
      return _defaults();
    }
  }

  /// What a fresh install offers, so the section is not empty the first time
  /// it is seen. Not written until something is changed: until then the
  /// defaults can improve with the app.
  static List<WsTemplate> _defaults() => [
    WsTemplate(
      id: 'term+status',
      name: '${libL10n.terminal} + ${l10n.status}',
      root: const WsSplit(
        WsAxis.row,
        0.62,
        WsLeaf([WorkspaceView.term]),
        WsLeaf([WorkspaceView.status]),
      ),
    ),
    WsTemplate(
      id: 'term+files',
      name: '${libL10n.terminal} + ${libL10n.file}',
      root: const WsSplit(
        WsAxis.col,
        0.6,
        WsLeaf([WorkspaceView.term]),
        WsLeaf([WorkspaceView.files]),
      ),
    ),
    WsTemplate(
      id: 'troubleshoot',
      name: l10n.workspaceTroubleshoot,
      root: const WsSplit(
        WsAxis.row,
        0.52,
        WsLeaf([WorkspaceView.term]),
        WsSplit(
          WsAxis.col,
          0.5,
          WsLeaf([WorkspaceView.status]),
          WsLeaf([WorkspaceView.agent]),
        ),
      ),
    ),
  ];

  void _save() {
    Stores.setting.workspaceTemplates.put(
      jsonEncode([for (final t in state) t.toJson()]),
    );
  }

  /// [ws]'s layout saved as a template named [name]; null for an empty one.
  WsTemplate? saveFrom(Workspace ws, String name) {
    final t = WsTemplate.of(ws, id: newWsId(), name: name);
    if (t == null) return null;
    state = [...state, t];
    _save();
    return t;
  }

  void remove(String id) {
    state = [for (final t in state) if (t.id != id) t];
    _save();
  }
}
