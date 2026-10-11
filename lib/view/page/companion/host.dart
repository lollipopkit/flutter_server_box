import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/companion.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/app/session_requests.dart';

/// Builds one open panel for the server a tab is showing.
///
/// What the panel *is* comes from the tab — the file panel beside a terminal
/// follows that terminal, the one beside a server's page does not — so the
/// host only lays them out.
typedef CompanionBuilder =
    Widget Function(BuildContext context, CompanionPanel panel, Spi spi);

/// A tab's subject with its [CompanionPanel]s beside it.
///
/// Wide, they are a column on the right: each one a section with a header,
/// folded to that header on its own, the column resized or folded away by the
/// seam between it and the subject. Narrow, the column has no room, and the
/// most recently opened panel is a sheet over the subject instead — the others
/// stay open underneath, and their button brings one to the top.
///
/// Nothing at all without a server: what the panels show is a server's.
class CompanionHost extends ConsumerStatefulWidget {
  const CompanionHost({
    super.key,
    required this.tab,
    required this.spi,
    required this.builder,
    required this.child,
    this.inTab = true,
  });

  final AppTab tab;

  /// Whether the subject is in [tab] — and so on screen only while that tab
  /// is — rather than a page pushed over whichever tab it was opened from.
  final bool inTab;

  /// The server the subject is about, or null when it is not about one — the
  /// picker, a shell on this device.
  final Spi? spi;

  final CompanionBuilder builder;

  /// The subject.
  final Widget child;

  /// The window width from which panels are a column rather than a sheet.
  ///
  /// The window's, not this widget's: the buttons that open the panels are in
  /// a bar this widget does not contain, and they have to agree with it about
  /// which of the two they are opening. Room for the navigation rail, a
  /// subject of the width a split pane gets, and the column.
  static const columnWidth = 1000.0;

  static bool isColumn(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= columnWidth;

  static const _minWidth = 260.0;

  /// What the subject keeps, however far the column is dragged.
  static const _minSubject = 420.0;

  /// A bar button for each panel [tab] offers, lit while it is showing.
  ///
  /// Empty without a server, so a bar about a shell on this device does not
  /// offer a status nobody can have.
  static List<BarAction> actions(AppTab tab, {required bool enabled}) {
    if (!enabled) return const [];
    return [
      for (final panel in CompanionPanel.of(tab))
        BarAction.listen(
          listenable: CompanionPanels.listenable,
          build: (context) {
            final open = CompanionPanels.openOf(tab);
            // In a sheet only the top one is showing; the others are open but
            // out of sight, and lit they would say otherwise.
            final showing = isColumn(context)
                ? open.contains(panel)
                : open.lastOrNull == panel;
            return BarAction(
              key: ValueKey('companion-${panel.name}'),
              icon: panel.icon,
              label: panel.label,
              color: showing ? Theme.of(context).colorScheme.primary : null,
              onTap: () => showing
                  ? CompanionPanels.close(tab, panel)
                  : CompanionPanels.open(tab, panel),
            );
          },
        ),
    ];
  }

  @override
  ConsumerState<CompanionHost> createState() => _CompanionHostState();
}

class _CompanionHostState extends ConsumerState<CompanionHost> {
  /// The subject moves when a panel opens — into a row, under a sheet — and
  /// under this key it is moved rather than built again: a terminal strip
  /// rebuilt would lose which terminal it was showing.
  final _subject = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    final spi = widget.spi;
    final builder = widget.builder;
    final child = KeyedSubtree(key: _subject, child: widget.child);
    if (spi == null || CompanionPanel.of(tab).isEmpty) return child;
    // Whether this tab is the one on screen. A panel holding something only
    // one view may have — a terminal — lets go of it behind another tab.
    // And on the top page: a server's page pushed over this tab hides it as
    // surely as another tab does.
    final visible =
        (!widget.inTab || ref.watch(currentHomeTabProvider) == tab) &&
        (ModalRoute.isCurrentOf(context) ?? true);
    return ListenBuilder(
      listenable: CompanionPanels.listenable,
      builder: () {
        // Laid out with none open as well: a panel closing is a panel
        // leaving, and the column or sheet it leaves from is what moves it.
        final open = CompanionPanels.openOf(tab);
        return CompanionHost.isColumn(context)
            ? _Column(
                tab: tab,
                spi: spi,
                open: open,
                visible: visible,
                builder: builder,
                child: child,
              )
            : _Sheet(
                tab: tab,
                spi: spi,
                panel: open.lastOrNull,
                visible: visible,
                builder: builder,
                child: child,
              );
      },
    );
  }
}

extension CompanionPanelX on CompanionPanel {
  IconData get icon => switch (this) {
    CompanionPanel.status => Icons.monitor_heart_outlined,
    CompanionPanel.terminal => Icons.terminal,
    CompanionPanel.files => Icons.folder_open_outlined,
  };

  String get label => switch (this) {
    CompanionPanel.status => l10n.status,
    CompanionPanel.terminal => libL10n.terminal,
    CompanionPanel.files => libL10n.file,
  };
}

/// What a panel needs to know about where the host put it.
class CompanionSlot extends InheritedWidget {
  const CompanionSlot({
    super.key,
    required this.panel,
    required this.inSheet,
    required this.visible,
    required this.collapsed,
    required this.onCollapse,
    required this.onClose,
    required super.child,
  });

  final CompanionPanel panel;

  /// In the sheet over the subject, rather than a section of the column.
  final bool inSheet;

  /// Both on screen and on the tab that is — not folded, not behind another
  /// tab.
  final bool visible;

  /// Folded to its header, in the column.
  final bool collapsed;

  final ValueChanged<bool> onCollapse;
  final VoidCallback onClose;

  static CompanionSlot of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CompanionSlot>()!;

  @override
  bool updateShouldNotify(CompanionSlot old) =>
      panel != old.panel ||
      inSheet != old.inSheet ||
      visible != old.visible ||
      collapsed != old.collapsed;
}

/// A panel's header and body, as the host places it: a section of the column,
/// or the sheet.
///
/// The panel brings its own buttons, and this adds the host's — fold in a
/// column, close in a sheet — at the end, where they are on every panel.
class CompanionFrame extends StatelessWidget {
  const CompanionFrame({
    super.key,
    required this.body,
    this.actions = const [],
  });

  final Widget body;

  /// The panel's own buttons, drawn in its header.
  final List<BarAction> actions;

  static const headerHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final slot = CompanionSlot.of(context);
    final theme = Theme.of(context);
    final header = SizedBox(
      height: headerHeight,
      child: Row(
        children: [
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              slot.panel.label,
              style: theme.textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Folded, a section is a label to unfold: its buttons act on a body
          // nobody can see.
          if (!slot.collapsed)
            for (final action in actions) action.button(),
          if (slot.inSheet)
            BarAction(
              icon: Icons.close,
              label: libL10n.close,
              onTap: slot.onClose,
            ).button()
          else
            BarAction(
              icon: slot.collapsed ? Icons.expand_more : Icons.expand_less,
              label: slot.collapsed ? libL10n.open : libL10n.fold,
              onTap: () => slot.onCollapse(!slot.collapsed),
            ).button(),
          const SizedBox(width: 5),
        ],
      ),
    );
    // The body stays when folded, so unfolding finds it as it was: the
    // section is cut down to the header around it.
    return Column(
      children: [
        header,
        Expanded(child: body),
      ],
    );
  }
}

class _Column extends StatefulWidget {
  const _Column({
    required this.tab,
    required this.spi,
    required this.open,
    required this.visible,
    required this.builder,
    required this.child,
  });

  final AppTab tab;
  final Spi spi;
  final List<CompanionPanel> open;
  final bool visible;
  final CompanionBuilder builder;
  final Widget child;

  @override
  State<_Column> createState() => _ColumnState();
}

class _ColumnState extends State<_Column> {
  /// The width while a drag is under way, written to the store when it ends:
  /// every tab listens to that one, and a write per pointer event rebuilds all
  /// of them.
  double? _dragging;

  /// The same for the share of the column's height the upper section has.
  double? _splitting;

  bool get _held => _dragging != null || _splitting != null;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final max = (constraints.maxWidth - CompanionHost._minSubject).clamp(
          CompanionHost._minWidth,
          double.infinity,
        );
        final width = (_dragging ?? CompanionPanels.width).clamp(
          CompanionHost._minWidth,
          max,
        );
        final folded = CompanionPanels.folded;
        final shown = widget.open.isNotEmpty && !folded;

        void drag(double dx) {
          if (!shown) return;
          // The column is on the right, so a drag to the left widens it.
          setState(
            () => _dragging = ((_dragging ?? width) - dx).clamp(
              CompanionHost._minWidth,
              max,
            ),
          );
        }

        void end() {
          final dragged = _dragging;
          if (dragged == null) return;
          CompanionPanels.saveWidth(dragged);
          setState(() => _dragging = null);
        }

        // The sections are built at the column's full width whatever it is
        // animating through, and cut to it: laid out narrower on every frame,
        // a terminal in one would be resized sixty times a second.
        final sections = OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: width,
          maxWidth: width,
          child: _buildSections(visible: widget.visible && shown),
        );

        return TweenAnimationBuilder<double>(
          tween: Tween(end: shown ? width : 0),
          duration: _held ? Duration.zero : Durations.medium2,
          curve: Curves.easeInOutCubic,
          // Built once outside the animation, so a frame of it moves the
          // column rather than building what is in it again.
          child: sections,
          builder: (context, w, sections) {
            // A `Stack` around the row, as `AdaptivePanes` has: the handle is
            // wider than the seam it sits on, and inside the seam it was cut
            // to the seam's width.
            return Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: widget.child),
                    // Always in the row, at no width when the column is
                    // gone: the sections after it are kept, and a sibling
                    // coming and going before them would rebuild them.
                    SizedBox(
                      width: w > 0 ? PaneDivider.hitWidth : 0,
                      child: PaneDivider(onDrag: drag, onDragEnd: end),
                    ),
                    SizedBox(
                      width: w,
                      child: ClipRect(child: sections),
                    ),
                  ],
                ),
                if (widget.open.isNotEmpty)
                  Positioned(
                    // Centred on the seam, and against the edge once the
                    // column is folded away.
                    right:
                        (w +
                                PaneDivider.hitWidth / 2 -
                                PaneCollapseHandle.width / 2)
                            .clamp(0.0, double.infinity),
                    top: 0,
                    bottom: 0,
                    child: Center(
                      // Mirrored: the handle's chevron is drawn for a column
                      // on the left, and this one folds to the right.
                      child: Transform.flip(
                        flipX: true,
                        child: PaneCollapseHandle(
                          collapsed: folded,
                          tooltip: folded ? libL10n.open : libL10n.fold,
                          onTap: () => CompanionPanels.saveFolded(!folded),
                          // The same handlers the line has, mirrored with
                          // the handle: the grip sits on the line, and a
                          // drag aimed at the middle of the seam would
                          // otherwise stop at it.
                          onDrag: (dx) => drag(-dx),
                          onDragEnd: end,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Every panel the tab offers, open or not, each in its own place: what
  /// opens, closes or folds changes heights and nothing else, so the panel
  /// beside it is never built again.
  Widget _buildSections({required bool visible}) {
    final collapsed = CompanionPanels.collapsedOf(widget.tab);
    // In the bar's order rather than the order they were opened in, so a
    // section does not move when another one is opened.
    final panels = CompanionPanel.of(widget.tab);
    final open = [
      for (final panel in panels)
        if (widget.open.contains(panel)) panel,
    ];
    final both = open.length == 2;
    final unfolded = open.where((e) => !collapsed.contains(e)).toList();

    return LayoutBuilder(
      builder: (_, constraints) {
        final total = constraints.maxHeight;
        final seam = both ? _SectionSeam.height : 0.0;
        final room = total - seam;
        const header = CompanionFrame.headerHeight;

        // Two unfolded share by the stored split; one unfolded takes what
        // the other's header leaves; folded ones are their header.
        final heights = <CompanionPanel, double>{};
        if (unfolded.length == 2) {
          // Never less than a header and a little of its body.
          const least = header * 2;
          final upper = room < least * 2
              ? room / 2
              : (room * (_splitting ?? CompanionPanels.split)).clamp(
                  least,
                  room - least,
                );
          heights[open[0]] = upper;
          heights[open[1]] = room - upper;
        } else {
          for (final panel in open) {
            heights[panel] = collapsed.contains(panel)
                ? header
                : room - header * (open.length - 1);
          }
        }

        final children = <Widget>[];
        for (final (index, panel) in panels.indexed) {
          if (index > 0) {
            children.add(
              _Animated(
                height: seam,
                instant: _held,
                child: _SectionSeam(
                  enabled: unfolded.length == 2,
                  onDrag: (dy) {
                    final upper = heights[open[0]] ?? 0;
                    setState(
                      () => _splitting = ((_splitting ?? upper / room) +
                              dy / room)
                          .clamp(0.0, 1.0),
                    );
                  },
                  onDragEnd: () {
                    final split = _splitting;
                    if (split == null) return;
                    CompanionPanels.saveSplit(split);
                    setState(() => _splitting = null);
                  },
                ),
              ),
            );
          }
          final isOpen = open.contains(panel);
          children.add(
            _Animated(
              key: ValueKey(panel),
              height: heights[panel] ?? 0,
              instant: _held,
              child: isOpen
                  ? _section(
                      panel,
                      collapsed: collapsed.contains(panel),
                      visible: visible,
                    )
                  : null,
            ),
          );
        }
        return Column(children: children);
      },
    );
  }

  Widget _section(
    CompanionPanel panel, {
    required bool collapsed,
    required bool visible,
  }) {
    return CompanionSlot(
      panel: panel,
      inSheet: false,
      visible: visible && !collapsed,
      collapsed: collapsed,
      onCollapse: (value) =>
          CompanionPanels.setCollapsed(widget.tab, panel, value),
      onClose: () => CompanionPanels.close(widget.tab, panel),
      child: Builder(
        // Keyed by panel and server, so a panel never carries one machine's
        // state over to the next one the tab shows.
        key: ValueKey((panel, widget.spi.id)),
        builder: (context) => widget.builder(context, panel, widget.spi),
      ),
    );
  }
}

/// A box moving to [height], with what it holds laid out at the larger of
/// where it is going and where it came from, and cut to the box: a panel
/// resized on every frame of a fold is a terminal sent a size sixty times a
/// second.
///
/// A null [child] is a box closing: what it held stays until it has shrunk
/// away, and goes then.
class _Animated extends StatefulWidget {
  const _Animated({
    super.key,
    required this.height,
    required this.child,
    this.instant = false,
  });

  final double height;
  final Widget? child;

  /// Follows a drag, which is a movement already.
  final bool instant;

  @override
  State<_Animated> createState() => _AnimatedState();
}

class _AnimatedState extends State<_Animated> {
  late Widget? _held = widget.child;
  late double _layout = widget.height;

  @override
  void didUpdateWidget(_Animated old) {
    super.didUpdateWidget(old);
    if (widget.child != null) _held = widget.child;
    _layout = widget.instant
        ? widget.height
        : math.max(widget.height, math.max(_layout, old.height));
  }

  void _settled() {
    setState(() {
      _layout = widget.height;
      if (widget.child == null) _held = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final held = _held;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.height),
      duration: widget.instant ? Duration.zero : Durations.medium2,
      curve: Curves.easeInOutCubic,
      onEnd: _settled,
      child: held == null
          ? null
          : OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: _layout,
              maxHeight: _layout,
              child: held,
            ),
      builder: (_, h, child) =>
          SizedBox(height: h, child: ClipRect(child: child)),
    );
  }
}

/// The line between two sections, dragged up or down to share the column's
/// height between them — [PaneDivider] turned on its side.
class _SectionSeam extends StatefulWidget {
  const _SectionSeam({
    required this.enabled,
    required this.onDrag,
    required this.onDragEnd,
  });

  static const height = PaneDivider.hitWidth;

  /// Whether there is anything to share: with one of them folded there is
  /// not, and this is a plain line.
  final bool enabled;

  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;

  @override
  State<_SectionSeam> createState() => _SectionSeamState();
}

class _SectionSeamState extends State<_SectionSeam> {
  var _hovered = false;
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && (_hovered || _pressed);
    final line = SizedBox(
      height: _SectionSeam.height,
      child: Center(
        child: Container(
          height: Hairline.thickness,
          color: active
              ? Hairline.activeColor(context)
              : Hairline.color(context),
        ),
      ),
    );
    if (!widget.enabled) return line;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      // Lit on touch, before the drag is recognised — see [PaneDivider].
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (details) => widget.onDrag(details.delta.dy),
          onVerticalDragEnd: (_) => widget.onDragEnd(),
          child: line,
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.tab,
    required this.spi,
    required this.panel,
    required this.visible,
    required this.builder,
    required this.child,
  });

  final AppTab tab;
  final Spi spi;

  /// The one on top, or null with none open.
  final CompanionPanel? panel;
  final bool visible;
  final CompanionBuilder builder;
  final Widget child;

  /// How much of the subject the sheet covers. Enough left above it to see
  /// what the subject is — the last lines of a terminal — and to reach its bar.
  static const _heightFactor = 0.8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final panel = this.panel;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: constraints.maxHeight * _heightFactor,
            // Up from the bottom, back down, and one panel down while the
            // next comes up: the same movement whichever of the three it is.
            child: AnimatedSwitcher(
              duration: Durations.medium2,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              child: panel == null
                  ? const SizedBox.shrink(key: ValueKey('none'))
                  : Material(
                      key: ValueKey((panel, spi.id)),
                      color: scheme.surfaceContainerLow,
                      elevation: 8,
                      clipBehavior: Clip.antiAlias,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(17),
                      ),
                      child: CompanionSlot(
                        panel: panel,
                        inSheet: true,
                        visible: visible,
                        collapsed: false,
                        onCollapse: (_) {},
                        onClose: () => CompanionPanels.close(tab, panel),
                        child: Builder(
                          builder: (context) => builder(context, panel, spi),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
