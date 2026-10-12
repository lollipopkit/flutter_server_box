part of 'tab.dart';

/// The height of a pane's bar, and of the workspace's: every point of it is a
/// row less of terminal.
const _kHeadHeight = SwitcherBar.height;

/// A pane: its bar, and the page of the tab on top.
class _Pane extends ConsumerWidget {
  const _Pane({
    super.key,
    required this.host,
    required this.ws,
    required this.pane,
    required this.shown,
    required this.visible,
    required this.width,
    required this.mode,
    required this.phone,
    required this.tiled,
  });

  final _WorkspaceTabState host;
  final Workspace ws;
  final WsPane pane;

  /// Laid out, rather than kept offstage.
  final bool shown;

  /// On screen: [shown], in the workspace on screen, in the tab on screen.
  final bool visible;
  final double width;
  final _WsMode mode;
  final bool phone;

  /// One of several on screen, drawn as a tile: a rounded edge of its own,
  /// coloured where the keys go.
  final bool tiled;

  bool get _focused => ws.focusId == pane.id;

  /// A strip of tabs where there is room for one; one tab's name and a
  /// switcher where there is not.
  bool get _strip => !phone && width >= 340;

  bool get _showSplit => !phone && width >= 420;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversProvider.select((s) => s.servers));
    final active = pane.active;
    final runtimes = [for (final t in pane.tabs) host._runtimeOf(t)];
    for (var i = 0; i < pane.tabs.length; i++) {
      final on = pane.tabs[i].id == active.id;
      // Built the first time it is shown; kept from then on.
      if (on && shown) runtimes[i].built = true;
    }
    // After the frame: a notifier written while building tells its
    // listeners — the pages under this — to rebuild in the middle of it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var i = 0; i < pane.tabs.length; i++) {
        final rt = runtimes[i];
        // A tab closed since is no longer the host's, and its runtime goes.
        if (!identical(host._runtimes[pane.tabs[i].id], rt)) continue;
        rt.visible.value = visible && pane.tabs[i].id == active.id;
      }
    });

    final activeRt = runtimes[pane.activeIndex];
    final syncBar = ws.sync && active.view == WorkspaceView.term && active.live;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (!_focused) host._ws.focus(pane.id);
        // A view that takes no keys itself leaves them with the workspace.
        if (active.view != WorkspaceView.term) host._keys.requestFocus();
      },
      child: _frame(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder(
              valueListenable: activeRt.actions,
              builder: (context, actions, _) => _strip
                  ? _StripHead(pane: this, servers: servers, actions: actions)
                  : _BarHead(pane: this, servers: servers, actions: actions),
            ),
            if (syncBar) _SyncBar(ws: ws),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IndexedStack(
                      index: pane.activeIndex,
                      sizing: StackFit.expand,
                      children: [
                        for (var i = 0; i < pane.tabs.length; i++)
                          KeyedSubtree(
                            key: runtimes[i].key,
                            child: TickerMode(
                              enabled: visible && i == pane.activeIndex,
                              child: runtimes[i].built
                                  ? runtimes[i].host(pane.tabs[i], pane.id)
                                  : const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned.fill(child: _DropZones(pane: this)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [child] inside the pane's edge: a tile's when [tiled], nothing when it
  /// fills the area alone.
  ///
  /// The edge is drawn over the page rather than around it, so a terminal's
  /// own background does not cover it.
  Widget _frame(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    if (!tiled) return ColoredBox(color: bg, child: child);
    final radius = switch (theme.cardTheme.shape) {
      RoundedRectangleBorder(:final BorderRadius borderRadius) => borderRadius,
      _ => BorderRadius.circular(12),
    };
    return AnimatedContainer(
      duration: context.motion(Durations.short3),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          // Light: the edge says where the keys go, and any stronger it is the
          // loudest thing in the window. The rest are the app's hairline, so a
          // theme's divider colour is theirs too.
          color: _focused
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : Hairline.color(context),
        ),
      ),
      child: child,
    );
  }

  /// The pane's own menu, after whatever of the page's buttons the bar had
  /// no room for.
  void openMenu(BuildContext anchor, List<BarAction> folded) {
    final kb = host.ref.read(keybindingsProvider);
    final maxed = ws.maxId == pane.id;
    final at = ws.order.indexOf(pane.id) + 1;
    showRowsSheet<void>(
      host.context,
      rows: (ctx) {
        void then(VoidCallback f) {
          Navigator.of(ctx).pop();
          f();
        }

        return [
          _SheetHead(l10n.workspacePane(at)),
          for (final a in folded)
            if (a.menuItem(anchor) case final item?)
              SheetChoiceTile(
                icon: item.icon,
                title: item.text,
                selected: false,
                onTap: () => then(item.onTap),
              ),
          SheetChoiceTile(
            icon: Icons.vertical_split_outlined,
            title: l10n.workspaceSplitRight,
            subtitle: kb.labelOf(KbCommand.wsSplitRight),
            selected: false,
            onTap: () => then(() => host._ws.split(pane.id, WsAxis.row)),
          ),
          SheetChoiceTile(
            icon: Icons.horizontal_split_outlined,
            title: l10n.workspaceSplitDown,
            subtitle: kb.labelOf(KbCommand.wsSplitDown),
            selected: false,
            onTap: () => then(() => host._ws.split(pane.id, WsAxis.col)),
          ),
          SheetChoiceTile(
            icon: Icons.add,
            title: l10n.workspaceNewTab,
            subtitle: kb.labelOf(KbCommand.wsNewTab),
            selected: false,
            onTap: () => then(() => host._showPicker(pane.id)),
          ),
          if (!mode.narrow)
            SheetChoiceTile(
              icon: maxed ? Icons.close_fullscreen : Icons.open_in_full,
              title: maxed ? l10n.workspaceRestore : l10n.workspaceMaximize,
              subtitle: l10n.workspaceMaximizeHint(
                kb.labelOf(KbCommand.wsMaximize),
              ),
              selected: false,
              onTap: () => then(() => host._toggleMax(pane.id)),
            ),
          SheetChoiceTile(
            icon: Icons.close,
            title: l10n.workspaceClosePane,
            subtitle: l10n.workspaceClosePaneHint,
            selected: false,
            onTap: () => then(() => host._closePane(pane.id)),
          ),
        ];
      },
    );
  }
}

/// The small grey line over a sheet's rows saying what they are about.
class _SheetHead extends StatelessWidget {
  const _SheetHead(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 9, 17, 3),
      child: SizedBox(
        width: double.infinity,
        child: Text(text, style: UIs.text12Grey),
      ),
    );
  }
}

/// `Sync input: what is typed goes to the 3 terminals of this workspace`.
class _SyncBar extends StatelessWidget {
  const _SyncBar({required this.ws});

  final Workspace ws;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = ws.tabs.where((t) => t.view == WorkspaceView.term).length;
    return ColoredBox(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
        child: Row(
          children: [
            Icon(Icons.sync, size: 15, color: scheme.onSecondaryContainer),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                l10n.workspaceSyncBar(n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What marks a pane's selected tab: the theme's segmented marker, the one
/// every other "which of these is on screen" control in the app is drawn
/// with. Which pane has the keys is the tile's edge to say, not this.
({Color fill, Color text, Color quiet, BorderRadius radius}) _tabStyle(
  BuildContext context,
) {
  final scheme = Theme.of(context).colorScheme;
  final style = ComponentStyles.of(context).segmented;
  return (
    fill: style.selectedColor ?? scheme.secondaryContainer,
    text: style.selectedTextColor ?? scheme.onSecondaryContainer,
    quiet: style.textColor ?? scheme.onSurfaceVariant,
    // [SessionSwitcherLabel]'s ink, so a pane's strip and a narrow pane's
    // label are the same shape.
    radius: BorderRadius.circular(style.radius ?? 11),
  );
}

/// The buttons at the end of every pane's bar.
List<Widget> _paneButtons(
  _Pane p, {
  required bool tabsButton,
  required bool splitDown,
  required List<BarAction> shown,
  required List<BarAction> folded,
}) {
  final kb = p.host.ref.read(keybindingsProvider);
  final maxed = p.ws.maxId == p.pane.id;
  return [
    for (final a in shown) a.button(),
    if (tabsButton)
      Btn.icon(
        text: kb.tip(
          l10n.workspaceAllTabs(p.pane.tabs.length),
          KbCommand.wsTabs,
        ),
        icon: const Icon(Icons.expand_more, size: 18),
        onTap: () => p.host._showTabs(p.pane.id),
      ),
    Btn.icon(
      text: kb.tip(l10n.workspaceNewTab, KbCommand.wsNewTab),
      icon: const Icon(Icons.add, size: 18),
      onTap: () => p.host._showPicker(p.pane.id),
    ),
    if (p._showSplit)
      Btn.icon(
        text: kb.tip(l10n.workspaceSplitRight, KbCommand.wsSplitRight),
        icon: const Icon(Icons.vertical_split_outlined, size: 18),
        onTap: () => p.host._ws.split(p.pane.id, WsAxis.row),
      ),
    if (p._showSplit && splitDown)
      Btn.icon(
        text: kb.tip(l10n.workspaceSplitDown, KbCommand.wsSplitDown),
        icon: const Icon(Icons.horizontal_split_outlined, size: 18),
        onTap: () => p.host._ws.split(p.pane.id, WsAxis.col),
      ),
    if (!splitDown && !p.mode.narrow)
      Btn.icon(
        text: kb.tip(
          maxed ? l10n.workspaceRestore : l10n.workspaceMaximize,
          KbCommand.wsMaximize,
        ),
        icon: Icon(
          maxed ? Icons.close_fullscreen : Icons.open_in_full,
          size: 18,
        ),
        onTap: () => p.host._toggleMax(p.pane.id),
      ),
    Builder(
      builder: (anchor) => Btn.icon(
        text: l10n.workspacePaneActions,
        icon: const ThemedIcon(Icons.more_horiz, size: 18),
        onTap: () => p.openMenu(anchor, folded),
      ),
    ),
  ];
}

/// The page's buttons that fit beside the pane's own, and the rest.
({List<BarAction> shown, List<BarAction> folded}) _foldActions(
  List<BarAction> actions,
  double room,
) {
  final fits = (room / SwitcherBar.slot).floor().clamp(0, actions.length);
  return (shown: actions.sublist(0, fits), folded: actions.sublist(fits));
}

/// Two clicks in quick succession, seen without entering the gesture arena.
///
/// A `GestureDetector(onDoubleTap:)` round the strip made every tab in it
/// wait out the double-tap timeout before its own tap was let through: the
/// arena cannot hand a single tap over while a second one might still come,
/// so switching tabs lagged by a third of a second. Watching the pointer
/// instead leaves the tabs' taps alone.
class _DoubleClick extends StatefulWidget {
  const _DoubleClick({required this.onDoubleClick, required this.child});

  final VoidCallback onDoubleClick;
  final Widget child;

  @override
  State<_DoubleClick> createState() => _DoubleClickState();
}

class _DoubleClickState extends State<_DoubleClick> {
  ({Duration at, Offset where})? _last;

  void _onUp(PointerUpEvent e) {
    final last = _last;
    if (last != null &&
        e.timeStamp - last.at <= kDoubleTapTimeout &&
        (e.position - last.where).distance <= kDoubleTapSlop) {
      _last = null;
      widget.onDoubleClick();
      return;
    }
    _last = (at: e.timeStamp, where: e.position);
  }

  @override
  Widget build(BuildContext context) =>
      Listener(onPointerUp: _onUp, child: widget.child);
}

/// A pane's bar where there is room: every tab in a strip.
class _StripHead extends StatelessWidget {
  const _StripHead({
    required this.pane,
    required this.servers,
    required this.actions,
  });

  final _Pane pane;
  final Map<String, Spi> servers;
  final List<BarAction> actions;

  @override
  Widget build(BuildContext context) {
    final p = pane.pane;
    final many = p.tabs.length * 150 > pane.width - 170;
    // What the strip leaves: the page's buttons get what is past 300 points
    // of tabs and the pane's own five.
    final room = pane.width - 300 - SwitcherBar.slot * 5;
    final fold = _foldActions(actions, room);
    return SizedBox(
        height: _kHeadHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The strip only: two quick taps on the buttons beside it are two
            // new tabs, not a maximize.
            Expanded(
              child: _DoubleClick(
                onDoubleClick: () => pane.host._toggleMax(p.id),
                child: _TabStrip(pane: pane, servers: servers),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 3, right: 5),
              child: Row(
                children: _paneButtons(
                  pane,
                  tabsButton: many,
                  splitDown: false,
                  shown: fold.shown,
                  folded: fold.folded,
                ),
              ),
            ),
          ],
        ),
    );
  }
}

/// A pane's bar on a phone or in a narrow pane: the tab on top, which of how
/// many, and the way to the rest — the terminal tab's bar, in a pane.
class _BarHead extends StatelessWidget {
  const _BarHead({
    required this.pane,
    required this.servers,
    required this.actions,
  });

  final _Pane pane;
  final Map<String, Spi> servers;
  final List<BarAction> actions;

  @override
  Widget build(BuildContext context) {
    final p = pane.pane;
    final active = p.active;
    final fixed = 2 + (pane._showSplit ? 2 : 0);
    final room = pane.width - 160 - SwitcherBar.slot * fixed;
    final fold = _foldActions(actions, room);
    final bar = SizedBox(
      height: _kHeadHeight,
      child: Row(
        children: [
          Expanded(
            child: SessionSwitcherLabel(
              name: wsTabTitle(active, servers[active.serverId]),
              position: p.activeIndex + 1,
              total: p.tabs.length,
              leading: active.live ? null : _offMark(context),
              onTap: () {
                pane.host._ws.focus(p.id);
                pane.host._showTabs(p.id);
              },
            ),
          ),
          ..._paneButtons(
            pane,
            tabsButton: false,
            splitDown: true,
            shown: fold.shown,
            folded: fold.folded,
          ),
          const SizedBox(width: 5),
        ],
      ),
    );
    // Dragged by the whole bar: there is no strip to pick a tab out of.
    return _draggable(
      context,
      data: (paneId: p.id, tabId: active.id),
      label: wsTabTitle(active, servers[active.serverId]),
      icon: active.view.icon,
      host: pane.host,
      child: bar,
    );
  }
}

Widget _offMark(BuildContext context) => Icon(
  Icons.link_off,
  size: 15,
  color: Theme.of(context).colorScheme.onSurfaceVariant,
);

/// A tab that can be picked up: by the mouse at once, by a finger after a
/// long press, so a swipe across a strip still scrolls it.
Widget _draggable(
  BuildContext context, {
  required _WsDrag data,
  required String label,
  required IconData icon,
  required _WorkspaceTabState host,
  required Widget child,
}) {
  final scheme = Theme.of(context).colorScheme;
  final feedback = Material(
    color: scheme.secondaryContainer,
    elevation: 3,
    borderRadius: BorderRadius.circular(9),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ThemedIcon(icon, size: 17, color: scheme.onSecondaryContainer),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: scheme.onSecondaryContainer)),
        ],
      ),
    ),
  );
  void start() => host._drag.value = data;
  void end() => host._drag.value = null;
  final ghost = Opacity(opacity: 0.4, child: child);
  if (isMobile) {
    return LongPressDraggable<_WsDrag>(
      data: data,
      feedback: feedback,
      childWhenDragging: ghost,
      onDragStarted: start,
      onDragEnd: (_) => end(),
      child: child,
    );
  }
  return Draggable<_WsDrag>(
    data: data,
    feedback: feedback,
    childWhenDragging: ghost,
    onDragStarted: start,
    onDragEnd: (_) => end(),
    child: child,
  );
}

/// Every tab of a pane, side by side; scrolls when they do not fit.
class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.pane, required this.servers});

  final _Pane pane;
  final Map<String, Spi> servers;

  @override
  Widget build(BuildContext context) {
    final p = pane.pane;
    return DragTarget<_WsDrag>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) =>
          pane.host._ws.moveTab(d.data.paneId, d.data.tabId, p.id),
      builder: (context, candidates, _) {
        final scheme = Theme.of(context).colorScheme;
        return DecoratedBox(
          // At the end: dropped past the last tab.
          decoration: BoxDecoration(
            border: candidates.isEmpty
                ? null
                : Border(right: BorderSide(color: scheme.primary, width: 2)),
          ),
          // Faded where tabs run off an end, as the settings levels are: a
          // pill cut off square reads as the last one.
          child: EdgeFadeScroll(
            fade: 24,
            builder: (context, controller) => ListView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            children: [
              for (final t in p.tabs)
                _StripTab(
                  key: ValueKey(t.id),
                  pane: pane,
                  tab: t,
                  spi: servers[t.serverId],
                ),
            ],
          ),
          ),
        );
      },
    );
  }
}

class _StripTab extends StatefulWidget {
  const _StripTab({
    super.key,
    required this.pane,
    required this.tab,
    required this.spi,
  });

  final _Pane pane;
  final WsTab tab;
  final Spi? spi;

  @override
  State<_StripTab> createState() => _StripTabState();
}

class _StripTabState extends State<_StripTab> {
  var _hover = false;

  bool get _on => widget.pane.pane.activeId == widget.tab.id;

  @override
  void initState() {
    super.initState();
    if (_on) _reveal();
  }

  @override
  void didUpdateWidget(_StripTab old) {
    super.didUpdateWidget(old);
    if (_on && old.pane.pane.activeId != widget.tab.id) _reveal();
  }

  /// Scrolled into the strip when it becomes the selected one — by a key, a
  /// sheet, a tab opened at the end — rather than left selected out of sight.
  void _reveal() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    // Either end, whichever it is past; neither moves it when it is in view.
    for (final policy in const [
      ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    ]) {
      Scrollable.ensureVisible(context, alignmentPolicy: policy);
    }
  });

  @override
  Widget build(BuildContext context) {
    final pane = widget.pane;
    final tab = widget.tab;
    final on = pane.pane.activeId == tab.id;
    final scheme = Theme.of(context).colorScheme;
    final style = _tabStyle(context);
    final fg = on ? style.text : style.quiet;
    final kb = pane.host.ref.read(keybindingsProvider);
    final sync = pane.ws.sync && tab.view == WorkspaceView.term;
    void select() => pane.host._ws.selectTab(pane.pane.id, tab.id);
    void close() => pane.host._closeTab(pane.pane.id, tab);

    final body = AnimatedContainer(
      duration: context.motion(Durations.short3),
      curve: Curves.easeOut,
      constraints: const BoxConstraints(maxWidth: 230),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.only(left: 11, right: 3),
      decoration: BoxDecoration(
        color: on
            ? style.fill
            : _hover
            ? scheme.onSurface.withValues(alpha: 0.06)
            : style.fill.withValues(alpha: 0),
        borderRadius: style.radius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ThemedIcon(tab.view.icon, size: 17, color: fg),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              tab.view.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                color: fg,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            widget.spi?.name ?? '',
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              color: fg.withValues(alpha: fg.a * 0.7),
            ),
          ),
          if (!tab.live) ...[const SizedBox(width: 5), _offMark(context)],
          if (sync) ...[
            const SizedBox(width: 5),
            Icon(Icons.sync, size: 15, color: scheme.primary),
          ],
          const SizedBox(width: 3),
          Opacity(
            opacity: on || _hover ? 1 : 0,
            child: SizedBox.square(
              dimension: 22,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 15,
                color: fg,
                tooltip: kb.tip(libL10n.close, KbCommand.wsCloseTab),
                onPressed: close,
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ],
      ),
    );

    final tile = Semantics(
      selected: on,
      button: true,
      label: '${tab.view.label} · ${widget.spi?.name ?? ''}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Listener(
          // A middle click closes, as on every tab strip with a mouse.
          onPointerDown: (e) {
            if (e.buttons == kMiddleMouseButton) close();
          },
          child: GestureDetector(onTap: select, child: body),
        ),
      ),
    );

    // Dropped on: goes before this one.
    return DragTarget<_WsDrag>(
      onWillAcceptWithDetails: (d) => d.data.tabId != tab.id,
      onAcceptWithDetails: (d) => pane.host._ws.moveTab(
        d.data.paneId,
        d.data.tabId,
        pane.pane.id,
        beforeTabId: tab.id,
      ),
      builder: (context, candidates, _) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: candidates.isEmpty
              ? null
              : Border(left: BorderSide(color: scheme.primary, width: 2)),
        ),
        child: _draggable(
          context,
          data: (paneId: pane.pane.id, tabId: tab.id),
          label: '${tab.view.label} · ${widget.spi?.name ?? ''}',
          icon: tab.view.icon,
          host: pane.host,
          child: tile,
        ),
      ),
    );
  }
}

/// Where a dragged tab can land on a pane: an edge to split it, the middle
/// to join it.
class _DropZones extends StatefulWidget {
  const _DropZones({required this.pane});

  final _Pane pane;

  @override
  State<_DropZones> createState() => _DropZonesState();
}

class _DropZonesState extends State<_DropZones> {
  WsDropZone? _hover;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.pane.host._drag,
      builder: (context, drag, _) {
        if (drag == null) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;
            Rect zone(WsDropZone z) => switch (z) {
              WsDropZone.left => Rect.fromLTWH(0, 0, w * .25, h),
              WsDropZone.right => Rect.fromLTWH(w * .75, 0, w * .25, h),
              WsDropZone.top => Rect.fromLTWH(w * .25, 0, w * .5, h * .3),
              WsDropZone.bottom => Rect.fromLTWH(w * .25, h * .7, w * .5, h * .3),
              WsDropZone.center => Rect.fromLTWH(w * .25, h * .3, w * .5, h * .4),
            };
            return Stack(
              children: [
                if (_hover case final z?) _highlight(context, z, w, h),
                for (final z in WsDropZone.values)
                  Positioned.fromRect(
                    rect: zone(z),
                    child: DragTarget<_WsDrag>(
                      onWillAcceptWithDetails: (_) {
                        setState(() => _hover = z);
                        return true;
                      },
                      onLeave: (_) {
                        if (_hover == z) setState(() => _hover = null);
                      },
                      onAcceptWithDetails: (d) {
                        setState(() => _hover = null);
                        widget.pane.host._ws.dropTab(
                          d.data.paneId,
                          d.data.tabId,
                          widget.pane.pane.id,
                          z,
                        );
                      },
                      builder: (_, _, _) => const SizedBox.expand(),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _highlight(BuildContext context, WsDropZone z, double w, double h) {
    final scheme = Theme.of(context).colorScheme;
    final rect = switch (z) {
      WsDropZone.left => Rect.fromLTWH(0, 0, w / 2, h),
      WsDropZone.right => Rect.fromLTWH(w / 2, 0, w / 2, h),
      WsDropZone.top => Rect.fromLTWH(0, 0, w, h / 2),
      WsDropZone.bottom => Rect.fromLTWH(0, h / 2, w, h / 2),
      WsDropZone.center => Rect.fromLTWH(0, 0, w, h),
    };
    final (icon, label) = switch (z) {
      WsDropZone.left => (Icons.arrow_back, l10n.workspaceDropLeft),
      WsDropZone.right => (Icons.arrow_forward, l10n.workspaceDropRight),
      WsDropZone.top => (Icons.arrow_upward, l10n.workspaceDropTop),
      WsDropZone.bottom => (Icons.arrow_downward, l10n.workspaceDropBottom),
      WsDropZone.center => (Icons.tab, l10n.workspaceDropMerge),
    };
    return AnimatedPositioned.fromRect(
      rect: rect,
      duration: Durations.short4,
      curve: Curves.easeOutCubic,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            border: Border.all(color: scheme.primary, width: 2),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
