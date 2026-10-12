import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/theme.dart';
import 'package:flutter/gestures.dart'
    show kDoubleTapSlop, kDoubleTapTimeout, kMiddleMouseButton;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/server_picker.dart';
import 'package:server_box/data/model/app/keybinding.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/workspace/tree.dart';
import 'package:server_box/data/model/workspace/workspace.dart';
import 'package:server_box/data/provider/app/keybindings.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/workspace.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/view/page/workspace/tab_host.dart';
import 'package:server_box/view/page/workspace/view_meta.dart';

part 'area.dart';
part 'pane.dart';
part 'sheets.dart';
part 'sync.dart';

/// How a window this size lays a workspace out.
enum _WsMode {
  /// Every pane, as the tree arranges them.
  full,

  /// Two panes side by side: a portrait tablet.
  pair,

  /// Two panes one over the other: a phone.
  stack;

  bool get narrow => this != full;
}

/// Panes of several servers' views, side by side.
///
/// Several workspaces, one on screen; each a tree of panes, each pane a strip
/// of tabs, each tab one view of one server — a terminal, its status, its
/// containers. The views are the pages the rest of the app pushes, hosted in
/// place.
class WorkspaceTabPage extends ConsumerStatefulWidget {
  const WorkspaceTabPage({super.key});

  @override
  ConsumerState<WorkspaceTabPage> createState() => _WorkspaceTabState();
}

/// A tab being dragged.
typedef _WsDrag = ({String paneId, String tabId});

class _WorkspaceTabState extends ConsumerState<WorkspaceTabPage>
    with AutomaticKeepAliveClientMixin {
  /// Every tab's runtime, of every workspace, by tab id.
  final _runtimes = <String, WsTabRuntime>{};

  final _drag = ValueNotifier<_WsDrag?>(null);

  /// While a seam is held: panes follow the pointer instead of animating.
  final _resizing = ValueNotifier(false);

  /// Focused when a pane is tapped whose view takes no focus of its own, so
  /// the workspace's keys still reach this page.
  final _keys = FocusNode(debugLabel: 'workspace');

  late final _Mirror _mirror = _Mirror(this);

  @override
  bool get wantKeepAlive => true;

  WorkspacesState get _state => ref.read(workspacesProvider);

  Workspaces get _ws => ref.read(workspacesProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sync(_state);
    });
  }

  @override
  void dispose() {
    for (final rt in _runtimes.values) {
      rt.dispose();
    }
    _mirror.dispose();
    _drag.dispose();
    _resizing.dispose();
    _keys.dispose();
    super.dispose();
  }

  WsTabRuntime _runtimeOf(WsTab tab) => _runtimes[tab.id] ??= WsTabRuntime(
    handoff: _ws.takeSession(tab.id),
  );

  /// Lets go of the runtimes of tabs that are gone, and focuses what the
  /// change put in focus.
  void _sync(WorkspacesState next, [WorkspacesState? prev]) {
    final alive = {
      for (final ws in next.all)
        for (final t in ws.tabs) t.id,
    };
    final gone = _runtimes.keys.where((id) => !alive.contains(id)).toList();
    for (final id in gone) {
      // After the frame: the tab's page is still in the tree this frame and
      // its listeners are on these notifiers.
      final rt = _runtimes.remove(id)!;
      WidgetsBinding.instance.addPostFrameCallback((_) => rt.dispose());
    }
    final panes = {
      for (final ws in next.all) ...ws.panes.keys,
    };
    _paneRects.removeWhere((id, _) => !panes.contains(id));
    _mirror.update(next.current);

    final cur = next.current;
    final before = prev?.all.where((w) => w.id == cur.id).firstOrNull;
    final moved =
        prev == null ||
        prev.index != next.index ||
        before?.focusId != cur.focusId ||
        before?.focused?.activeId != cur.focused?.activeId;
    if (moved) _focusActive();
  }

  /// Keys to the focused pane's tab — a terminal takes them — or to this
  /// page when the tab has no use for them.
  void _focusActive() {
    // Null outside the home page — this tab on its own.
    final home = ref.read(currentHomeTabProvider);
    if (home != null && home != AppTab.workspace) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tab = _state.current.focused?.active;
      final rt = tab == null ? null : _runtimes[tab.id];
      if (rt != null && rt.focus.context != null) {
        rt.focus.requestFocus();
      } else {
        _keys.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(workspacesProvider, (prev, next) => _sync(next, prev));
    ref.listen(currentHomeTabProvider, (_, tab) {
      if (tab == AppTab.workspace) _focusActive();
    });
    final state = ref.watch(workspacesProvider);
    final kb = ref.watch(keybindingsProvider);
    // After the frame: the runtimes of tabs added by this change are made
    // while it builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mirror.update(_state.current);
    });

    return Shortcuts(
      shortcuts: kb.shortcutsFor(const [KbScope.workspace]),
      child: Actions(
        actions: {
          WorkspaceKbIntent: CallbackAction<WorkspaceKbIntent>(
            onInvoke: (intent) => _run(intent.command),
          ),
        },
        child: Focus(
          focusNode: _keys,
          skipTraversal: true,
          child: LayoutBuilder(
            builder: (context, c) {
              final mode = _modeFor(c.biggest);
              return Scaffold(
                appBar: _buildBar(state, kb, mode),
                body: IndexedStack(
                  index: state.index,
                  sizing: StackFit.expand,
                  children: [
                    for (var i = 0; i < state.all.length; i++)
                      _WsArea(
                        key: ValueKey(state.all[i].id),
                        host: this,
                        ws: state.all[i],
                        current: i == state.index,
                        mode: mode,
                        phone: c.maxWidth < _phoneWidth,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static const _phoneWidth = 600.0;

  static _WsMode _modeFor(Size size) {
    if (size.width < _phoneWidth) return _WsMode.stack;
    if (size.width < 1000 && size.height > size.width) return _WsMode.pair;
    return _WsMode.full;
  }

  PreferredSizeWidget _buildBar(
    WorkspacesState state,
    KbState kb,
    _WsMode mode,
  ) {
    final ws = state.current;
    final maxed = !mode.narrow && ws.maxId != null;
    return SwitcherBar(
      switcher: Row(
        children: [
          Expanded(
            child: SessionSwitcherLabel(
              name: ws.name,
              position: state.index + 1,
              total: state.all.length,
              onTap: _showWorkspaces,
            ),
          ),
          if (maxed) _MaxBadge(ws: ws, kb: kb, onRestore: _ws.restore),
        ],
      ),
      actions: [
        if (mode.narrow)
          BarAction(
            icon: Icons.splitscreen,
            label: l10n.workspacePanes,
            onTap: () => _showPanes(mode),
          ),
        BarAction(
          icon: Icons.search,
          label: kb.tip(l10n.workspaceQuickOpen, KbCommand.wsQuickOpen),
          onTap: _showQuickOpen,
        ),
        BarAction(
          icon: Icons.sync,
          label: kb.tip(
            ws.sync ? l10n.workspaceSyncOff : l10n.workspaceSyncOn,
            KbCommand.wsSync,
          ),
          color: ws.sync ? Theme.of(context).colorScheme.primary : null,
          onTap: _toggleSync,
        ),
        BarAction(
          icon: Icons.add,
          label: kb.tip(l10n.workspaceNewTab, KbCommand.wsNewTab),
          onTap: () => _showPicker(ws.focusId),
        ),
        BarAction(
          icon: Icons.bookmark_add_outlined,
          label: l10n.workspaceSaveTemplate,
          onTap: _saveTemplate,
        ),
      ],
    );
  }

  /// What a chord asked for.
  void _run(KbCommand command) {
    final ws = _state.current;
    final focus = ws.focusId;
    switch (command) {
      case KbCommand.wsSwitcher:
        _showWorkspaces();
      case KbCommand.wsNewTab:
        _showPicker(focus);
      case KbCommand.wsQuickOpen:
        _showQuickOpen();
      case KbCommand.wsReopenTab:
        _reopen();
      case KbCommand.wsSync:
        _toggleSync();
      case KbCommand.wsMaximize:
        if (focus != null) _toggleMax(focus);
      case KbCommand.wsTabs:
        if (focus != null) _showTabs(focus);
      case KbCommand.wsSplitRight:
        if (focus != null) _ws.split(focus, WsAxis.row);
      case KbCommand.wsSplitDown:
        if (focus != null) _ws.split(focus, WsAxis.col);
      case KbCommand.wsCloseTab:
        final pane = ws.focused;
        if (pane != null) _closeTab(pane.id, pane.active);
      case KbCommand.wsNextTab:
        _ws.stepTab(1);
      case KbCommand.wsPrevTab:
        _ws.stepTab(-1);
      case KbCommand.wsFocusLeft:
        _moveFocus(WsDirection.left);
      case KbCommand.wsFocusRight:
        _moveFocus(WsDirection.right);
      case KbCommand.wsFocusUp:
        _moveFocus(WsDirection.up);
      case KbCommand.wsFocusDown:
        _moveFocus(WsDirection.down);
      default:
    }
  }

  /// Where each pane of the current workspace was last laid out, for moving
  /// the focus by where things are on screen.
  List<WsPaneRect> _laidOut = const [];

  /// Where each pane, of any workspace, was last shown: where a hidden one
  /// stays laid out.
  final _paneRects = <String, Rect>{};

  void _moveFocus(WsDirection direction) {
    final from = _state.current.focusId;
    if (from == null) return;
    final to = neighbourPane(_laidOut, from, direction);
    if (to != null) _ws.focus(to);
  }

  void _toggleMax(String paneId) {
    final box = context.size;
    // A narrow window shows two panes at most and has no room to hide one.
    if (box != null && _modeFor(box).narrow) return;
    _ws.toggleMax(paneId);
  }

  void _toggleSync() {
    final on = _ws.toggleSync();
    Toast.show(on ? l10n.workspaceSyncOnToast : l10n.workspaceSyncOffToast);
  }

  void _closeTab(String paneId, WsTab tab) {
    final spi = ref.read(serversProvider).servers[tab.serverId];
    _ws.closeTab(paneId, tab.id);
    _offerUndo(l10n.workspaceClosed(wsTabTitle(tab, spi)));
  }

  void _closePane(String paneId) {
    final at = _state.current.order.indexOf(paneId);
    _ws.closePane(paneId);
    _offerUndo(l10n.workspaceClosed(l10n.workspacePane(at + 1)));
  }

  void _offerUndo(String message) {
    Toast.show(
      message,
      tag: 'workspace-closed',
      duration: const Duration(seconds: 5),
      action: ToastAction(label: libL10n.undo, onTap: _reopen),
    );
  }

  void _reopen() {
    if (!_ws.reopen()) Toast.show(l10n.workspaceNothingToReopen);
  }

  Future<void> _saveTemplate() async {
    final ws = _state.current;
    if (ws.isEmpty) {
      Toast.show(l10n.workspaceEmptyTemplate);
      return;
    }
    final name = l10n.workspaceTemplateOf(ws.name);
    final saved = ref
        .read(workspaceTemplatesProvider.notifier)
        .saveFrom(ws, name);
    if (saved != null) Toast.show(l10n.workspaceTemplateSaved(name));
  }
}

/// `Pane 2 maximised, 2 others hidden`, and the way back.
class _MaxBadge extends StatelessWidget {
  const _MaxBadge({required this.ws, required this.kb, required this.onRestore});

  final Workspace ws;
  final KbState kb;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final order = ws.order;
    return Container(
      height: 32,
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.only(left: 13, right: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fullscreen, size: 17, color: scheme.onSecondaryContainer),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              l10n.workspaceMaximized(
                order.indexOf(ws.maxId!) + 1,
                order.length - 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
          Btn.icon(
            text: kb.tip(l10n.workspaceRestore, KbCommand.wsMaximize),
            icon: Icon(
              Icons.close_fullscreen,
              size: 18,
              color: scheme.onSecondaryContainer,
            ),
            onTap: onRestore,
          ),
        ],
      ),
    );
  }
}
