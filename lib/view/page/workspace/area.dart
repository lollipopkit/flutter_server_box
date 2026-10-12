part of 'tab.dart';

/// One workspace's panes, laid out, and the seams between them.
///
/// Every pane is in the tree whether it is shown or not — a narrow window's
/// hidden ones and a maximised pane's neighbours are offstage — because a
/// pane's tabs are pages with state, and a terminal let go of is a terminal
/// that has to connect again.
/// The room around and between panes drawn as tiles.
const _kPaneGap = 5.0;

class _WsArea extends ConsumerWidget {
  const _WsArea({
    super.key,
    required this.host,
    required this.ws,
    required this.current,
    required this.mode,
    required this.phone,
  });

  final _WorkspaceTabState host;
  final Workspace ws;

  /// Whether this is the workspace on screen.
  final bool current;
  final _WsMode mode;
  final bool phone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final root = ws.root;
    if (root == null) return _buildEmpty();
    return LayoutBuilder(
        builder: (context, c) {
          final full = Offset.zero & c.biggest;
          // Several panes are tiles with a gap around each, so where one ends
          // is plain however alike their pages are; one alone fills the area,
          // as any other tab's page does.
          var laid = _layout(root, full.deflate(_kPaneGap), gap: _kPaneGap);
          final tiled = laid.panes.length > 1;
          if (!tiled) laid = _layout(root, full);
          if (current) host._laidOut = laid.panes;
          final shown = {for (final p in laid.panes) p.id: p.rect};
          final homeOn =
              ref.watch(currentHomeTabProvider) == AppTab.workspace;
          return ValueListenableBuilder(
            valueListenable: host._resizing,
            builder: (context, resizing, _) => Stack(
              children: [
                for (final id in ws.order)
                  _positioned(
                    id,
                    shown[id],
                    resizing: resizing,
                    visible: current && homeOn,
                    reduceMotion: context.reduceMotion,
                    tiled: tiled,
                  ),
                for (final seam in laid.seams)
                  _Seam(host: host, seam: seam, narrow: laid.narrow),
              ],
            ),
          );
        },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmptyPane(
            icon: Icons.space_dashboard_outlined,
            label: l10n.workspaceEmpty,
          ),
          UIs.height13,
          FilledButton.tonalIcon(
            onPressed: () => host._showPicker(null),
            icon: const Icon(Icons.add),
            label: Text(l10n.workspaceNewTab),
          ),
        ],
      ),
    );
  }

  /// The panes that are shown and where, and the seams between them.
  ///
  /// [narrow] says the seams are the narrow pair's, which is no split of the
  /// tree: dragging one sets [Workspace.narrowRatio].
  ({List<WsPaneRect> panes, List<WsSeam> seams, bool narrow}) _layout(
    WsNode<String> root,
    Rect area, {
    double gap = 1,
  }) {
    String id(String leaf) => leaf;
    if (!mode.narrow && ws.maxId != null && ws.panes.containsKey(ws.maxId)) {
      final laid = WsLeaf(ws.maxId!).layout(area, idOf: id, gap: gap);
      return (panes: laid.panes, seams: laid.seams, narrow: false);
    }
    final pair = ws.narrowPair();
    if (!mode.narrow || pair.length < 2) {
      final laid = root.layout(area, idOf: id, gap: gap);
      return (panes: laid.panes, seams: laid.seams, narrow: false);
    }
    // A narrow window shows two at most: the focused pane and the one before
    // it.
    final laid = WsSplit(
      mode == _WsMode.pair ? WsAxis.row : WsAxis.col,
      ws.narrowRatio,
      WsLeaf(pair[0]),
      WsLeaf(pair[1]),
    ).layout(area, idOf: id, gap: gap);
    return (panes: laid.panes, seams: laid.seams, narrow: true);
  }

  Widget _positioned(
    String id,
    Rect? rect, {
    required bool resizing,
    required bool visible,
    required bool reduceMotion,
    required bool tiled,
  }) {
    final pane = ws.panes[id]!;
    final child = _Pane(
      key: ValueKey(id),
      host: host,
      ws: ws,
      pane: pane,
      shown: rect != null,
      visible: visible && rect != null,
      width: rect?.width ?? 0,
      mode: mode,
      phone: phone,
      tiled: tiled,
    );
    if (rect == null) {
      // Not painted, but kept — see the class — and laid out at the size it
      // last had: a terminal given no room would tell its shell it has no
      // columns, and one given another size would be resized for nothing.
      final last = host._paneRects[id] ?? Rect.zero;
      return Positioned.fromRect(
        key: ValueKey(id),
        rect: last,
        child: Offstage(child: child),
      );
    }
    host._paneRects[id] = rect;
    return AnimatedPositioned.fromRect(
      key: ValueKey(id),
      rect: rect,
      duration: resizing || reduceMotion ? Duration.zero : Durations.medium3,
      curve: Curves.fastLinearToSlowEaseIn,
      child: child,
    );
  }
}

/// A seam between two halves of a split: dragged to move it, double-clicked
/// to even the halves again.
class _Seam extends StatefulWidget {
  const _Seam({required this.host, required this.seam, required this.narrow});

  final _WorkspaceTabState host;
  final WsSeam seam;

  /// The narrow pair's seam rather than a split's.
  final bool narrow;

  @override
  State<_Seam> createState() => _SeamState();
}

class _SeamState extends State<_Seam> {
  var _hover = false;
  double _ratio = 0.5;

  void _set(double r, {required bool persist}) {
    final ws = widget.host._ws;
    if (widget.narrow) {
      ws.setNarrowRatio(r, persist: persist);
    } else {
      ws.setRatio(widget.seam.path, r, persist: persist);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seam = widget.seam;
    final row = seam.axis == WsAxis.row;
    return Positioned.fromRect(
      rect: seam.rect,
      child: ValueListenableBuilder(
        valueListenable: widget.host._resizing,
        builder: (context, resizing, _) {
          final active = _hover || resizing;
          final scheme = Theme.of(context).colorScheme;
          return MouseRegion(
            cursor: row
                ? SystemMouseCursors.resizeColumn
                : SystemMouseCursors.resizeRow,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () => _set(0.5, persist: true),
              onPanStart: (_) {
                _ratio = seam.ratio;
                widget.host._resizing.value = true;
              },
              onPanUpdate: (d) {
                _ratio += (row ? d.delta.dx : d.delta.dy) / seam.extent;
                _set(_ratio, persist: false);
              },
              onPanEnd: (_) {
                widget.host._resizing.value = false;
                widget.host._ws.save();
              },
              onPanCancel: () {
                widget.host._resizing.value = false;
                widget.host._ws.save();
              },
              child: Tooltip(
                message: l10n.workspaceSeamTip,
                waitDuration: const Duration(seconds: 1),
                // The gap between two tiles is the seam; what is drawn in it
                // is the handle, and only while it is the thing being used.
                child: Center(
                  child: AnimatedOpacity(
                    opacity: active ? 1 : 0,
                    duration: context.motion(Durations.short3),
                    child: Container(
                      width: row ? 4 : 36,
                      height: row ? 36 : 4,
                      decoration: BoxDecoration(
                        color: resizing ? scheme.primary : scheme.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
