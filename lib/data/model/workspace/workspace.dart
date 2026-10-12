import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/workspace/tree.dart';

/// What a workspace tab shows of its server.
///
/// Stored by name: an index would point every saved tab at a different view
/// the moment a case was inserted.
enum WorkspaceView {
  term,
  status,
  files,
  agent,
  docker,
  proc,
  systemd,
  snippet;

  static final _byName = values.asNameMap();

  static WorkspaceView? byName(Object? name) => _byName[name];
}

/// One tab of a pane: a view of one server.
final class WsTab {
  const WsTab({
    required this.id,
    required this.view,
    required this.serverId,
    this.live = true,
  });

  final String id;
  final WorkspaceView view;
  final String serverId;

  /// Whether the view is running: connected, polling, holding a shell.
  ///
  /// Never stored. A workspace comes back from a relaunch with every tab
  /// asleep, and each one connects when it is asked to — a set of a dozen
  /// panes opening a dozen connections at launch, to servers some of which
  /// may be down, is not what reopening the app should do.
  final bool live;

  WsTab copyWith({bool? live}) =>
      WsTab(id: id, view: view, serverId: serverId, live: live ?? this.live);

  Map<String, dynamic> toJson() => {
    'id': id,
    'view': view.name,
    'server': serverId,
  };

  static WsTab? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final view = WorkspaceView.byName(json['view']);
    final server = json['server'];
    if (id is! String || view == null || server is! String) return null;
    return WsTab(id: id, view: view, serverId: server, live: false);
  }
}

/// A region of a workspace: a strip of tabs, one of them showing.
final class WsPane {
  const WsPane({required this.id, required this.tabs, required this.activeId});

  final String id;

  /// Never empty: a pane whose last tab closes goes with it.
  final List<WsTab> tabs;
  final String activeId;

  WsTab get active =>
      tabs.firstWhere((t) => t.id == activeId, orElse: () => tabs.first);

  int get activeIndex {
    final i = tabs.indexWhere((t) => t.id == activeId);
    return i < 0 ? 0 : i;
  }

  WsPane copyWith({List<WsTab>? tabs, String? activeId}) => WsPane(
    id: id,
    tabs: tabs ?? this.tabs,
    activeId: activeId ?? this.activeId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tabs': [for (final t in tabs) t.toJson()],
    'active': activeId,
  };

  static WsPane? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final raw = json['tabs'];
    if (id is! String || raw is! List) return null;
    final tabs = [for (final t in raw.map(WsTab.fromJson)) ?t];
    if (tabs.isEmpty) return null;
    final active = json['active'];
    return WsPane(
      id: id,
      tabs: tabs,
      activeId: tabs.any((t) => t.id == active) ? active as String : tabs.first.id,
    );
  }
}

/// A named arrangement of panes.
final class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    this.root,
    this.panes = const {},
    this.focusId,
    this.prevId,
    this.maxId,
    this.sync = false,
    this.narrowRatio = 0.55,
  });

  final String id;
  final String name;

  /// Null for an empty workspace.
  final WsNode<String>? root;

  /// By id; exactly the leaves of [root].
  final Map<String, WsPane> panes;

  /// The pane keys and new tabs go to.
  final String? focusId;

  /// The pane focused before [focusId]: the other one a single column shows,
  /// so going back and forth between two panes keeps both on screen.
  final String? prevId;

  /// The pane filling the workspace, the rest hidden; null when none is.
  final String? maxId;

  /// Whether what is typed in one terminal goes to all of them.
  final bool sync;

  /// The first pane's share when a narrow window shows two of them.
  final double narrowRatio;

  /// The panes in reading order.
  List<String> get order => root?.leaves ?? const [];

  bool get isEmpty => root == null;

  WsPane? get focused => panes[focusId];

  Iterable<WsTab> get tabs => order.expand((id) => panes[id]!.tabs);

  Workspace copyWith({
    String? name,
    WsNode<String>? Function()? root,
    Map<String, WsPane>? panes,
    String? Function()? focusId,
    String? Function()? prevId,
    String? Function()? maxId,
    bool? sync,
    double? narrowRatio,
  }) => Workspace(
    id: id,
    name: name ?? this.name,
    root: root != null ? root() : this.root,
    panes: panes ?? this.panes,
    focusId: focusId != null ? focusId() : this.focusId,
    prevId: prevId != null ? prevId() : this.prevId,
    maxId: maxId != null ? maxId() : this.maxId,
    sync: sync ?? this.sync,
    narrowRatio: narrowRatio ?? this.narrowRatio,
  );

  /// [id] focused, the old focus remembered as the previous one.
  Workspace focus(String id) {
    if (focusId == id || !panes.containsKey(id)) return this;
    return copyWith(focusId: () => id, prevId: () => focusId);
  }

  Workspace _withPane(WsPane pane) => copyWith(panes: {...panes, pane.id: pane});

  /// [tabId] showing in [paneId], which takes the focus.
  Workspace selectTab(String paneId, String tabId) {
    final pane = panes[paneId];
    if (pane == null || !pane.tabs.any((t) => t.id == tabId)) return this;
    return _withPane(pane.copyWith(activeId: tabId)).focus(paneId);
  }

  /// [tab] added to [paneId] — the focused pane when that is gone — and
  /// selected. An empty workspace gets its first pane.
  Workspace addTab(String? paneId, WsTab tab, {required String newPaneId}) {
    final target = panes[paneId] ?? focused;
    if (target == null) {
      return copyWith(
        root: () => WsLeaf(newPaneId),
        panes: {
          newPaneId: WsPane(id: newPaneId, tabs: [tab], activeId: tab.id),
        },
        focusId: () => newPaneId,
        prevId: () => null,
        maxId: () => null,
      );
    }
    return _withPane(
      target.copyWith(tabs: [...target.tabs, tab], activeId: tab.id),
    ).focus(target.id);
  }

  /// [paneId] gone with every tab in it.
  Workspace removePane(String paneId) {
    if (!panes.containsKey(paneId)) return this;
    final root = this.root?.removeLeaf(paneId);
    final rest = {...panes}..remove(paneId);
    final order = root?.leaves ?? const <String>[];
    var focus = focusId;
    var prev = prevId;
    if (!order.contains(focus)) {
      // The one beside it in reading order, rather than the first: closing
      // the third of four panes should not throw the focus to the top left.
      final at = this.order.indexOf(paneId);
      focus = order.isEmpty
          ? null
          : (order.contains(prev) ? prev : order[(at - 1).clamp(0, order.length - 1)]);
    }
    if (!order.contains(prev) || prev == focus) {
      prev = order.where((id) => id != focus).firstOrNull;
    }
    return Workspace(
      id: id,
      name: name,
      root: root,
      panes: rest,
      focusId: focus,
      prevId: prev,
      maxId: maxId == paneId ? null : maxId,
      sync: sync,
      narrowRatio: narrowRatio,
    );
  }

  /// [tabId] closed. A pane left with no tabs goes too.
  Workspace closeTab(String paneId, String tabId) {
    final pane = panes[paneId];
    if (pane == null) return this;
    final at = pane.tabs.indexWhere((t) => t.id == tabId);
    if (at < 0) return this;
    final tabs = [...pane.tabs]..removeAt(at);
    if (tabs.isEmpty) return removePane(paneId);
    return _withPane(
      pane.copyWith(
        tabs: tabs,
        // The one before it, as a browser does: the tab that was next to the
        // closed one is the one the eye was already on.
        activeId: pane.activeId == tabId
            ? tabs[(at - 1).clamp(0, tabs.length - 1)].id
            : null,
      ),
    );
  }

  /// [paneId] split along [axis], the new half holding [tab].
  Workspace split(
    String paneId,
    WsAxis axis,
    WsTab tab, {
    required String newPaneId,
    bool before = false,
  }) {
    final root = this.root;
    if (root == null || !panes.containsKey(paneId)) return this;
    return copyWith(
      root: () => root.splitLeaf(paneId, axis, newPaneId, before: before),
      panes: {
        ...panes,
        newPaneId: WsPane(id: newPaneId, tabs: [tab], activeId: tab.id),
      },
      // Splitting is asking to see both halves.
      maxId: () => null,
    ).focus(newPaneId);
  }

  /// [tabId] moved out of [fromPane] into [toPane], before [beforeTabId] or
  /// at the end.
  Workspace moveTab(
    String fromPane,
    String tabId,
    String toPane, {
    String? beforeTabId,
  }) {
    if (beforeTabId == tabId) return this;
    final src = panes[fromPane];
    final dst = panes[toPane];
    if (src == null || dst == null) return this;
    final tab = src.tabs.where((t) => t.id == tabId).firstOrNull;
    if (tab == null) return this;
    if (fromPane == toPane) {
      final tabs = [...src.tabs]..remove(tab);
      final at = beforeTabId == null
          ? tabs.length
          : tabs.indexWhere((t) => t.id == beforeTabId);
      tabs.insert(at < 0 ? tabs.length : at, tab);
      return _withPane(src.copyWith(tabs: tabs, activeId: tabId)).focus(toPane);
    }
    var next = closeTab(fromPane, tabId);
    final target = next.panes[toPane]!;
    final tabs = [...target.tabs];
    final at = beforeTabId == null
        ? tabs.length
        : tabs.indexWhere((t) => t.id == beforeTabId);
    tabs.insert(at < 0 ? tabs.length : at, tab);
    next = next._withPane(target.copyWith(tabs: tabs, activeId: tabId));
    return next.focus(toPane);
  }

  /// [tabId] dropped on [zone] of [toPane]: merged into it at the centre, a
  /// new pane beside it at an edge.
  Workspace dropTab(
    String fromPane,
    String tabId,
    String toPane,
    WsDropZone zone, {
    required String newPaneId,
  }) {
    final src = panes[fromPane];
    if (src == null || !panes.containsKey(toPane)) return this;
    final tab = src.tabs.where((t) => t.id == tabId).firstOrNull;
    if (tab == null) return this;
    final axis = zone.axis;
    if (axis == null) {
      if (fromPane == toPane) return this;
      return moveTab(fromPane, tabId, toPane);
    }
    // A pane's only tab dropped on its own edge would split it into itself
    // and nothing.
    if (fromPane == toPane && src.tabs.length == 1) return this;
    final removed = closeTab(fromPane, tabId);
    // The target may have been the source, emptied and removed — it was not,
    // by the check above, but its place in the tree is read after the close.
    return removed.split(
      toPane,
      axis,
      tab,
      newPaneId: newPaneId,
      before: zone.before,
    );
  }

  /// Every tab of [serverId] running; this workspace itself when none was
  /// asleep.
  Workspace wake(String serverId) {
    if (!tabs.any((t) => t.serverId == serverId && !t.live)) return this;
    return _wake(serverId);
  }

  Workspace _wake(String serverId) => copyWith(
    panes: {
      for (final e in panes.entries)
        e.key: e.value.copyWith(
          tabs: [
            for (final t in e.value.tabs)
              t.serverId == serverId && !t.live ? t.copyWith(live: true) : t,
          ],
        ),
    },
  );

  /// Only the tabs [keep] accepts, asked in reading order; a pane left with
  /// none goes too.
  Workspace retainTabs(bool Function(WsTab) keep) {
    var ws = this;
    for (final id in order) {
      final pane = panes[id]!;
      final tabs = [
        for (final t in pane.tabs)
          if (keep(t)) t,
      ];
      if (tabs.length == pane.tabs.length) continue;
      ws = tabs.isEmpty
          ? ws.removePane(id)
          : ws._withPane(
              pane.copyWith(
                tabs: tabs,
                activeId: tabs.any((t) => t.id == pane.activeId)
                    ? null
                    : tabs.first.id,
              ),
            );
    }
    return ws;
  }

  /// Every tab of [oldId] pointed at [newId]: a server renamed keeps its id
  /// only until it is renamed.
  Workspace renameServer(String oldId, String newId) {
    if (!tabs.any((t) => t.serverId == oldId)) return this;
    return copyWith(
      panes: {
        for (final e in panes.entries)
          e.key: e.value.copyWith(
            tabs: [
              for (final t in e.value.tabs)
                t.serverId == oldId
                    ? WsTab(id: t.id, view: t.view, serverId: newId, live: t.live)
                    : t,
            ],
          ),
      },
    );
  }

  /// Every tab of [serverId] closed, and every pane that leaves empty.
  Workspace removeServer(String serverId) {
    var ws = this;
    for (final pane in panes.values) {
      for (final t in pane.tabs) {
        if (t.serverId == serverId) ws = ws.closeTab(pane.id, t.id);
      }
    }
    return ws;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (root case final root?) 'root': root.toJson((leaf) => leaf),
    'panes': [for (final id in order) panes[id]!.toJson()],
    'focus': focusId,
    'prev': prevId,
    if (maxId != null) 'max': maxId,
    if (sync) 'sync': true,
    'narrowRatio': narrowRatio,
  };

  /// Null when not even a name survives. Tabs [keep] refuses — a server since
  /// deleted — are dropped, and the layout closes up around a pane left
  /// without any. [keep] is asked only of tabs in panes the layout places.
  static Workspace? fromJson(Object? json, {required bool Function(WsTab) keep}) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) return null;
    final panes = <String, WsPane>{};
    final rawPanes = json['panes'];
    if (rawPanes is List) {
      for (final p in rawPanes.map(WsPane.fromJson)) {
        // The first of two records of one pane: the second cannot be put
        // anywhere the first is not already.
        if (p != null) panes.putIfAbsent(p.id, () => p);
      }
    }
    var root = WsNode.fromJson<String>(
      json['root'],
      (raw) => raw is String ? raw : null,
    )?.withoutRepeats();
    // Leaves without a pane — one whose every tab was dropped — and panes
    // without a leaf are both let go of, so the two always describe the same
    // set.
    for (final leaf in root?.leaves ?? const <String>[]) {
      if (!panes.containsKey(leaf)) root = root?.removeLeaf(leaf);
    }
    final order = root?.leaves ?? const <String>[];
    panes.removeWhere((k, _) => !order.contains(k));
    String? pick(Object? v) => order.contains(v) ? v as String : null;
    final focus = pick(json['focus']) ?? order.firstOrNull;
    final ratio = json['narrowRatio'];
    return Workspace(
      id: id,
      name: name,
      root: root,
      panes: panes,
      focusId: focus,
      prevId: pick(json['prev']) ?? order.where((e) => e != focus).firstOrNull,
      maxId: pick(json['max']),
      sync: json['sync'] == true,
      narrowRatio: ratio is num ? WsSplit.clampRatio(ratio.toDouble()) : 0.55,
    ).retainTabs(keep);
  }

  /// The panes a single column shows: the focused one and the one before it,
  /// in reading order. All of them when there are fewer than two.
  List<String> narrowPair() {
    final order = this.order;
    if (order.length < 2) return order;
    final focus = order.contains(focusId) ? focusId! : order.first;
    final other = order.contains(prevId) && prevId != focus
        ? prevId!
        : order.firstWhere((id) => id != focus);
    return [focus, other]..sort((a, b) => order.indexOf(a) - order.indexOf(b));
  }
}

/// A workspace's layout with the views each pane opened with, and no servers:
/// applied, every tab is on whichever server is in focus at the time.
final class WsTemplate {
  const WsTemplate({required this.id, required this.name, required this.root});

  final String id;
  final String name;
  final WsNode<List<WorkspaceView>> root;

  /// [ws]'s layout, or null for an empty one: there is nothing to save.
  static WsTemplate? of(Workspace ws, {required String id, required String name}) {
    final root = ws.root;
    if (root == null) return null;
    return WsTemplate(
      id: id,
      name: name,
      root: root.map((pane) => [for (final t in ws.panes[pane]!.tabs) t.view]),
    );
  }

  /// A new workspace laid out like this one, every tab on [serverId]. A leaf
  /// without views gets no pane; a template without any, an empty workspace.
  Workspace build({
    required String workspaceId,
    required String name,
    required String serverId,
    required String Function() newId,
  }) {
    final panes = <String, WsPane>{};
    final placed = this.root.map((views) {
      final id = newId();
      final tabs = [
        for (final v in views) WsTab(id: newId(), view: v, serverId: serverId),
      ];
      if (tabs.isNotEmpty) {
        panes[id] = WsPane(id: id, tabs: tabs, activeId: tabs.first.id);
      }
      return id;
    });
    WsNode<String>? root = placed;
    for (final leaf in placed.leaves) {
      if (!panes.containsKey(leaf)) root = root?.removeLeaf(leaf);
    }
    final order = root?.leaves ?? const <String>[];
    return Workspace(
      id: workspaceId,
      name: name,
      root: root,
      panes: panes,
      focusId: order.firstOrNull,
      prevId: order.length > 1 ? order[1] : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'root': root.toJson((views) => [for (final v in views) v.name]),
  };

  static WsTemplate? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) return null;
    final root = WsNode.fromJson<List<WorkspaceView>>(json['root'], (raw) {
      if (raw is! List) return null;
      final views = [
        for (final v in raw.map(WorkspaceView.byName))
          ?v,
      ];
      return views.isEmpty ? null : views;
    });
    if (root == null) return null;
    return WsTemplate(id: id, name: name, root: root);
  }
}

/// Ids for panes, tabs, workspaces and templates: unique within the device,
/// which is as far as any of them travels.
String newWsId() => ShortId.generate();
