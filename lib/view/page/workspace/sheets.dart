part of 'tab.dart';

/// The lists the workspace opens: of workspaces, of a pane's tabs, of panes,
/// of views to open, and quick open.
extension _Sheets on _WorkspaceTabState {
  Widget _closeButton(String tip, VoidCallback onTap, {IconData? icon}) =>
      Btn.icon(
        text: tip,
        icon: Icon(icon ?? Icons.close, size: 17),
        onTap: onTap,
      );

  /// `3 panes · web-02, db-01`, or that it is empty.
  String _describe(Workspace ws) {
    if (ws.isEmpty) return libL10n.empty;
    final servers = ref.read(serversProvider).servers;
    final names = <String>{
      for (final t in ws.tabs) servers[t.serverId]?.name ?? t.serverId,
    };
    return '${l10n.workspacePaneCount(ws.order.length)} · ${names.join(', ')}';
  }

  /// `Terminal·Status ｜ Agent`: what a template lays out.
  String _describeTemplate(WsNode<List<WorkspaceView>> n) => switch (n) {
    WsLeaf(:final value) => value.map((v) => v.label).join('·'),
    WsSplit(:final axis, :final a, :final b) =>
      '${_describeTemplate(a)}${axis == WsAxis.row ? ' | ' : ' / '}'
          '${_describeTemplate(b)}',
  };

  Future<void> _showWorkspaces() async {
    await showRowsSheet<void>(
      context,
      rows: (ctx) {
        final state = ref.read(workspacesProvider);
        final templates = ref.read(workspaceTemplatesProvider);
        void then(VoidCallback f) {
          Navigator.of(ctx).pop();
          f();
        }

        return [
          _SheetHead(l10n.workspace),
          for (var i = 0; i < state.all.length; i++)
            SheetChoiceTile(
              icon: Icons.space_dashboard_outlined,
              title: state.all[i].name,
              subtitle: _describe(state.all[i]),
              selected: i == state.index,
              onTap: () => then(() => _ws.select(i)),
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _closeButton(
                    libL10n.rename,
                    () => then(() => _rename(i)),
                    icon: Icons.edit_outlined,
                  ),
                  if (state.all.length > 1)
                    _closeButton(
                      '${libL10n.close} ${state.all[i].name}',
                      () => then(() => _ws.close(i)),
                    ),
                ],
              ),
            ),
          SheetChoiceTile(
            icon: Icons.add,
            title: l10n.workspaceNewEmpty,
            selected: false,
            onTap: () => then(_ws.create),
          ),
          const Divider(height: 13, indent: 17, endIndent: 17),
          _SheetHead(l10n.workspaceTemplatesHead),
          for (final t in templates)
            SheetChoiceTile(
              icon: Icons.dashboard_customize_outlined,
              title: t.name,
              subtitle: _describeTemplate(t.root),
              selected: false,
              onTap: () => then(() => _applyTemplate(t)),
              action: _closeButton(
                '${libL10n.delete} ${t.name}',
                () => ref
                    .read(workspaceTemplatesProvider.notifier)
                    .remove(t.id),
                icon: Icons.delete_outline,
              ),
            ),
          SheetChoiceTile(
            icon: Icons.bookmark_add_outlined,
            title: l10n.workspaceSaveTemplate,
            selected: false,
            onTap: () => then(_saveTemplate),
          ),
        ];
      },
    );
  }

  Future<void> _rename(int index) async {
    final ws = _state.all.elementAtOrNull(index);
    if (ws == null) return;
    final ctrl = TextEditingController(text: ws.name);
    final name = await context.showRoundDialog<String>(
      title: libL10n.rename,
      child: Input(
        controller: ctrl,
        autoFocus: true,
        onSubmitted: (v) => context.popDialog(v.trim()),
      ),
      actions: [
        Btn.cancel(),
        TextButton(
          onPressed: () => context.popDialog(ctrl.text.trim()),
          child: Text(libL10n.ok),
        ),
      ],
    );
    ctrl.dispose();
    if (name != null && name.isNotEmpty) _ws.rename(index, name);
  }

  /// A new workspace laid out as [t], on the server in focus — asked for when
  /// there is none.
  Future<void> _applyTemplate(WsTemplate t) async {
    var serverId = _state.current.focused?.active.serverId;
    if (serverId == null) {
      final spi = await pickServer(context);
      if (spi == null || !mounted) return;
      serverId = spi.id;
    }
    _ws.applyTemplate(t, serverId);
    final name = ref.read(serversProvider).servers[serverId]?.name ?? serverId;
    Toast.show(l10n.workspaceFromTemplate(t.name, name));
  }

  Future<void> _showTabs(String paneId) async {
    final kb = ref.read(keybindingsProvider);
    await showRowsSheet<void>(
      context,
      rows: (ctx) {
        final ws = _state.current;
        final pane = ws.panes[paneId];
        if (pane == null) return const [];
        final servers = ref.read(serversProvider).servers;
        void then(VoidCallback f) {
          Navigator.of(ctx).pop();
          f();
        }

        return [
          _SheetHead(
            l10n.workspacePaneTabs(ws.order.indexOf(paneId) + 1),
          ),
          for (final t in pane.tabs)
            SheetChoiceTile(
              icon: t.view.icon,
              title: t.view.label,
              subtitle: [
                servers[t.serverId]?.name ?? t.serverId,
                if (!t.live) l10n.workspaceAsleep,
              ].join(' · '),
              selected: t.id == pane.activeId,
              onTap: () => then(() => _ws.selectTab(paneId, t.id)),
              action: _closeButton(
                '${libL10n.close} ${t.view.label}',
                () => then(() => _closeTab(paneId, t)),
              ),
            ),
          SheetChoiceTile(
            icon: Icons.add,
            title: l10n.workspaceNewTab,
            subtitle: kb.labelOf(KbCommand.wsNewTab),
            selected: false,
            onTap: () => then(() => _showPicker(paneId)),
          ),
        ];
      },
    );
  }

  /// The panes of a narrow window, which shows two of them.
  Future<void> _showPanes(_WsMode mode) async {
    await showRowsSheet<void>(
      context,
      rows: (ctx) {
        final ws = _state.current;
        final pair = ws.narrowPair();
        final servers = ref.read(serversProvider).servers;
        void then(VoidCallback f) {
          Navigator.of(ctx).pop();
          f();
        }

        String slot(String id) {
          final at = pair.indexOf(id);
          if (at < 0) return l10n.workspaceHidden;
          return switch ((mode, at)) {
            (_WsMode.pair, 0) => l10n.workspaceDropLeft,
            (_WsMode.pair, _) => l10n.workspaceDropRight,
            (_, 0) => l10n.workspaceDropTop,
            _ => l10n.workspaceDropBottom,
          };
        }

        return [
          _SheetHead(l10n.workspacePanesHead(ws.name)),
          for (final (i, id) in ws.order.indexed)
            SheetChoiceTile(
              icon: Icons.splitscreen,
              title: l10n.workspacePane(i + 1),
              subtitle: [
                slot(id),
                ws.panes[id]!.tabs
                    .map(
                      (t) =>
                          '${t.view.label} ${servers[t.serverId]?.name ?? ''}',
                    )
                    .join(', '),
              ].join(' · '),
              selected: ws.focusId == id,
              onTap: () => then(() => _ws.focus(id)),
              action: _closeButton(
                '${libL10n.close} ${l10n.workspacePane(i + 1)}',
                () => then(() => _closePane(id)),
              ),
            ),
          SheetChoiceTile(
            icon: Icons.add,
            title: l10n.workspaceNewPane,
            selected: false,
            onTap: () => then(() {
              final focus = ws.focusId;
              if (focus == null) {
                _showPicker(null);
                return;
              }
              _ws.split(
                focus,
                mode == _WsMode.stack ? WsAxis.col : WsAxis.row,
              );
            }),
          ),
        ];
      },
    );
  }

  /// A new tab: which server — the app's own picker — then which view.
  Future<void> _showPicker(String? paneId) async {
    final spi = await pickServer(context);
    if (spi == null || !mounted) return;
    final granted = ref.read(serverProvider(spi.id)).agentAccess;
    final ws = _state.current;
    final at = ws.order.indexOf(paneId ?? ws.focusId ?? '');
    final view = await showRowsSheet<WorkspaceView>(
      context,
      rows: (ctx) => [
        _SheetHead(
          at < 0
              ? l10n.workspacePickView(spi.name)
              : '${l10n.workspacePickView(spi.name)} · '
                    '${l10n.workspacePane(at + 1)}',
        ),
        for (final v in WorkspaceView.values)
          () {
            final reason = v.unavailableOn(spi, granted);
            return SheetChoiceTile(
              icon: v.icon,
              title: v.label,
              subtitle: reason,
              selected: false,
              onTap: () {
                if (reason != null) {
                  Toast.show(reason);
                  return;
                }
                Navigator.of(ctx).pop(v);
              },
            );
          }(),
      ],
    );
    if (view == null || !mounted) return;
    _ws.addTab(paneId, view, spi.id);
  }

  Future<void> _showQuickOpen() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: _QuickOpen(host: this),
      ),
    );
  }
}

/// One thing quick open can do.
typedef _QuickItem = ({
  IconData icon,
  String title,
  String subtitle,
  VoidCallback run,
});

/// Type a few words, open the first match: a tab of this workspace, another
/// workspace, or a new tab of any view on any server.
class _QuickOpen extends ConsumerStatefulWidget {
  const _QuickOpen({required this.host});

  final _WorkspaceTabState host;

  @override
  ConsumerState<_QuickOpen> createState() => _QuickOpenState();
}

class _QuickOpenState extends ConsumerState<_QuickOpen> {
  final _ctrl = TextEditingController();
  var _query = '';

  /// How many a list of matches shows: past this the words typed are too few.
  static const _limit = 10;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<_QuickItem> _items() {
    final host = widget.host;
    final words = _query.toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    bool match(String s) {
      final l = s.toLowerCase();
      return words.every(l.contains);
    }

    final state = ref.read(workspacesProvider);
    final ws = state.current;
    final servers = ref.read(serversProvider).servers;
    final out = <_QuickItem>[];
    void close() => Navigator.of(context).pop();

    for (final (i, paneId) in ws.order.indexed) {
      for (final t in ws.panes[paneId]!.tabs) {
        final name = servers[t.serverId]?.name ?? t.serverId;
        if (!match('${t.view.label} $name ${t.view.name}')) continue;
        out.add((
          icon: t.view.icon,
          title: '${t.view.label} · $name',
          subtitle: '${l10n.workspaceSwitchTo} · ${l10n.workspacePane(i + 1)}',
          run: () {
            close();
            host._ws.selectTab(paneId, t.id);
          },
        ));
      }
    }
    for (final (i, other) in state.all.indexed) {
      if (i == state.index) continue;
      if (!match('${l10n.workspace} ${other.name}')) continue;
      out.add((
        icon: Icons.space_dashboard_outlined,
        title: other.name,
        subtitle: l10n.workspaceSwitchWorkspace,
        run: () {
          close();
          host._ws.select(i);
        },
      ));
    }
    // New tabs only once something is typed: every view of every server is
    // a list nobody reads.
    if (words.isNotEmpty) {
      for (final spi in servers.values) {
        final granted = ref.read(serverProvider(spi.id)).agentAccess;
        for (final v in WorkspaceView.values) {
          if (v.unavailableOn(spi, granted) != null) continue;
          if (!match('${spi.name} ${v.label} ${v.name}')) continue;
          out.add((
            icon: v.icon,
            title: '${v.label} · ${spi.name}',
            subtitle: l10n.workspaceNewTabFocused,
            run: () {
              close();
              host._ws.addTab(null, v, spi.id);
            },
          ));
        }
      }
    }
    return out.take(_limit).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHead(l10n.workspaceQuickOpenHead),
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 3, 17, 9),
          child: Input(
            controller: _ctrl,
            autoFocus: true,
            icon: Icons.search,
            hint: l10n.workspaceQuickOpenHint,
            suggestion: false,
            noWrap: true,
            onChanged: (v) => setState(() => _query = v.trim()),
            onSubmitted: (_) => items.firstOrNull?.run(),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: EmptyPane(
                    icon: Icons.search_off,
                    label: l10n.workspaceNoMatch,
                  ),
                )
              : ListView(
                  children: [
                    for (final it in items)
                      ListTile(
                        leading: ThemedIcon(it.icon),
                        title: Text(it.title),
                        subtitle: Text(it.subtitle, style: UIs.text12Grey),
                        onTap: it.run,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
