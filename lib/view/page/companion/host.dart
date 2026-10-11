import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/companion.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/app/session_requests.dart';

/// Builds one panel for the server a tab is showing.
///
/// What the panel *is* comes from the tab — the file panel beside a terminal
/// follows that terminal, the one beside a server's page does not — so the
/// host only lays them out.
typedef CompanionBuilder =
    Widget Function(BuildContext context, CompanionPanel panel, Spi spi);

/// A tab's subject with its [CompanionPanel]s beside it.
///
/// One panel at a time, under a strip that switches between them. Wide, they
/// are a column on the right, resized by the seam between it and the subject
/// and closed by the grip on it. Narrow, the column has no room, and they are
/// a sheet over the subject instead.
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

  /// The server the subject is about, or null when it is not about one — the
  /// picker, a shell on this device.
  final Spi? spi;

  final CompanionBuilder builder;

  /// The subject.
  final Widget child;

  /// Whether the subject is in [tab] — and so on screen only while that tab
  /// is — rather than a page pushed over whichever tab it was opened from.
  final bool inTab;

  /// The window width from which the panels are a column rather than a sheet.
  ///
  /// The window's, not this widget's: the button that opens them is in a bar
  /// this widget does not contain, and it has to agree with it about which of
  /// the two it is opening. Room for the navigation rail, a subject of the
  /// width a split pane gets, and the column.
  static const columnWidth = 1000.0;

  static bool isColumn(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= columnWidth;

  static const _minWidth = 300.0;

  /// What the subject keeps, however far the column is dragged.
  static const _minSubject = 420.0;

  /// The bar's button for [tab]'s panels, lit while they are open.
  ///
  /// Empty without a server, so a bar about a shell on this device does not
  /// offer panels nobody can have.
  static List<BarAction> actions(AppTab tab, {required bool enabled}) {
    if (!enabled || CompanionPanel.of(tab).isEmpty) return const [];
    return [
      BarAction.listen(
        listenable: CompanionPanels.listenable,
        build: (context) {
          final open = CompanionPanels.isOpen(tab);
          final column = isColumn(context);
          return BarAction(
            key: const ValueKey('companion'),
            // Where they come in from: the side, or the bottom.
            icon: switch ((column, open)) {
              (true, true) => Icons.view_sidebar,
              (true, false) => Icons.view_sidebar_outlined,
              (false, true) => Icons.call_to_action,
              (false, false) => Icons.call_to_action_outlined,
            },
            label: context.l10n.companionPanels,
            color: open ? Theme.of(context).colorScheme.primary : null,
            onTap: () => CompanionPanels.toggle(tab),
          );
        },
      ),
    ];
  }

  @override
  ConsumerState<CompanionHost> createState() => _CompanionHostState();
}

class _CompanionHostState extends ConsumerState<CompanionHost> {
  /// The subject moves when the panels open — into a row, under a sheet — and
  /// under this key it is moved rather than built again: a terminal strip
  /// rebuilt would lose which terminal it was showing.
  final _subject = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    final spi = widget.spi;
    final child = KeyedSubtree(key: _subject, child: widget.child);
    if (spi == null || CompanionPanel.of(tab).isEmpty) return child;
    // Whether this is on screen: its tab current, and on the top page — a
    // server's page pushed over this tab hides it as surely as another tab
    // does. A panel holding what only one view may have — a terminal — lets
    // go of it otherwise.
    final visible =
        (!widget.inTab || ref.watch(currentHomeTabProvider) == tab) &&
        (ModalRoute.isCurrentOf(context) ?? true);
    return ListenBuilder(
      listenable: CompanionPanels.listenable,
      builder: () {
        // Laid out closed as well: closing is the panels leaving, and the
        // column or sheet they leave from is what moves them.
        final open = CompanionPanels.isOpen(tab);
        final column = CompanionHost.isColumn(context);
        final panels = _Panels(
          // One per server: a panel never carries one machine's state over to
          // the next one the tab shows.
          key: ValueKey(spi.id),
          tab: tab,
          spi: spi,
          open: open,
          visible: visible && open,
          inSheet: !column,
          builder: widget.builder,
        );
        return column
            ? _Column(tab: tab, open: open, panels: panels, child: child)
            : _Sheet(open: open, panels: panels, child: child);
      },
    );
  }
}

extension CompanionPanelX on CompanionPanel {
  IconData get icon => switch (this) {
    CompanionPanel.status => Icons.monitor_heart_outlined,
    CompanionPanel.terminal => Icons.terminal,
    CompanionPanel.files => Icons.folder_open_outlined,
    CompanionPanel.agent => Icons.auto_awesome,
  };

  String get label => switch (this) {
    CompanionPanel.status => l10n.status,
    CompanionPanel.terminal => libL10n.terminal,
    CompanionPanel.files => libL10n.file,
    CompanionPanel.agent => 'Agent',
  };
}

/// What a panel needs to know about where the host put it.
class CompanionSlot extends InheritedWidget {
  const CompanionSlot({
    super.key,
    required this.panel,
    required this.visible,
    required super.child,
  });

  final CompanionPanel panel;

  /// On screen: the panels open, this one the one shown, and its tab current.
  final bool visible;

  static CompanionSlot of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CompanionSlot>()!;

  @override
  bool updateShouldNotify(CompanionSlot old) =>
      panel != old.panel || visible != old.visible;
}

/// A panel's own row of buttons, under the strip that switches panels, and
/// its body.
class CompanionFrame extends StatelessWidget {
  const CompanionFrame({
    super.key,
    required this.body,
    this.leading,
    this.actions = const [],
  });

  final Widget body;

  /// What the panel says about itself at the start of its row — a server's
  /// uptime, the Agent's chat.
  final Widget? leading;

  /// The panel's own buttons, at the end of its row.
  final List<BarAction> actions;

  static const rowHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    if (leading == null && actions.isEmpty) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: rowHeight,
          child: Row(
            children: [
              const SizedBox(width: 13),
              Expanded(
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: leading ?? const SizedBox.shrink(),
                ),
              ),
              for (final action in actions) action.button(),
              const SizedBox(width: 5),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

/// The strip that switches panels, and the panel it is on.
///
/// Every panel visited stays built behind the one shown, so switching back to
/// files finds the listing where it was, and an Agent reply still coming in;
/// a panel never visited is not built at all.
class _Panels extends StatefulWidget {
  const _Panels({
    super.key,
    required this.tab,
    required this.spi,
    required this.open,
    required this.visible,
    required this.inSheet,
    required this.builder,
  });

  final AppTab tab;
  final Spi spi;

  /// Whether the panels are open, which is what builds the one shown.
  final bool open;

  /// Whether they are on screen as well — open, and their tab current.
  final bool visible;

  /// In the sheet, which closes from the strip; the column closes from its
  /// seam.
  final bool inSheet;

  final CompanionBuilder builder;

  @override
  State<_Panels> createState() => _PanelsState();
}

class _PanelsState extends State<_Panels> {
  final _visited = <CompanionPanel>{};

  @override
  Widget build(BuildContext context) {
    final panels = CompanionPanel.of(widget.tab);
    final selected = CompanionPanels.selectedOf(widget.tab);
    if (widget.open) _visited.add(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Strip(
          panels: panels,
          selected: selected,
          onSelect: (panel) => CompanionPanels.open(widget.tab, panel),
          onClose: widget.inSheet
              ? () => CompanionPanels.close(widget.tab)
              : null,
        ),
        Expanded(
          child: IndexedStack(
            index: panels.indexOf(selected),
            sizing: StackFit.expand,
            children: [
              for (final panel in panels)
                if (_visited.contains(panel))
                  CompanionSlot(
                    panel: panel,
                    visible: widget.visible && panel == selected,
                    child: Builder(
                      builder: (context) =>
                          widget.builder(context, panel, widget.spi),
                    ),
                  )
                else
                  const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}

/// The panels' names, the one shown underlined — and in a sheet, the way to
/// close it.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.panels,
    required this.selected,
    required this.onSelect,
    required this.onClose,
  });

  final List<CompanionPanel> panels;
  final CompanionPanel selected;
  final ValueChanged<CompanionPanel> onSelect;
  final VoidCallback? onClose;

  static const height = 48.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onClose = this.onClose;
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Hairline.color(context),
            width: Hairline.thickness,
          ),
        ),
      ),
      child: Row(
        children: [
          for (final panel in panels)
            Expanded(
              child: InkWell(
                onTap: panel == selected ? null : () => onSelect(panel),
                child: Column(
                  children: [
                    const Spacer(),
                    Text(
                      panel.label,
                      style: TextStyle(
                        fontSize: 14,
                        color: panel == selected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        fontWeight: panel == selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    AnimatedContainer(
                      duration: Durations.short4,
                      curve: Curves.easeOut,
                      height: 3,
                      width: panel == selected ? 36 : 0,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (onClose != null)
            BarAction(
              icon: Icons.close,
              label: libL10n.close,
              onTap: onClose,
            ).button(),
        ],
      ),
    );
  }
}

class _Column extends StatefulWidget {
  const _Column({
    required this.tab,
    required this.open,
    required this.panels,
    required this.child,
  });

  final AppTab tab;
  final bool open;
  final Widget panels;
  final Widget child;

  @override
  State<_Column> createState() => _ColumnState();
}

class _ColumnState extends State<_Column> {
  /// The width while a drag is under way, written to the store when it ends:
  /// every tab listens to that one, and a write per pointer event rebuilds all
  /// of them.
  double? _dragging;

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
        final open = widget.open;

        void drag(double dx) {
          if (!open) return;
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

        // The panels are laid out at the column's full width whatever it is
        // animating through, and cut to it: laid out narrower on every frame,
        // a terminal in one would be resized sixty times a second.
        final panels = OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: width,
          maxWidth: width,
          child: widget.panels,
        );

        return TweenAnimationBuilder<double>(
          tween: Tween(end: open ? width : 0),
          duration: _dragging != null ? Duration.zero : Durations.medium2,
          curve: Curves.easeInOutCubic,
          // Built once outside the animation, so a frame of it moves the
          // column rather than building what is in it again.
          child: panels,
          builder: (context, w, panels) {
            // A `Stack` around the row, as `AdaptivePanes` has: the grip is
            // wider than the seam it sits on, and inside the seam it was cut
            // to the seam's width.
            return Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: widget.child),
                    // Always in the row, at no width when the column is
                    // gone: the panels after it are kept, and a sibling
                    // coming and going before them would rebuild them.
                    SizedBox(
                      width: w > 0 ? PaneDivider.hitWidth : 0,
                      child: PaneDivider(onDrag: drag, onDragEnd: end),
                    ),
                    SizedBox(width: w, child: ClipRect(child: panels)),
                  ],
                ),
                Positioned(
                  // Centred on the seam, and against the edge once the
                  // column is gone, where it is the way back.
                  right:
                      (w +
                              PaneDivider.hitWidth / 2 -
                              PaneCollapseHandle.width / 2)
                          .clamp(0.0, double.infinity),
                  top: 0,
                  bottom: 0,
                  child: Center(
                    // Mirrored: the grip's chevron is drawn for a column on
                    // the left, and this one goes to the right.
                    child: Transform.flip(
                      flipX: true,
                      child: PaneCollapseHandle(
                        collapsed: !open,
                        tooltip: open ? libL10n.fold : libL10n.open,
                        onTap: () => CompanionPanels.toggle(widget.tab),
                        // The same handlers the line has, mirrored with the
                        // grip: it sits on the line, and a drag aimed at the
                        // middle of the seam would otherwise stop at it.
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
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.open,
    required this.panels,
    required this.child,
  });

  final bool open;
  final Widget panels;
  final Widget child;

  /// How much of the subject the sheet covers. Enough left above it to see
  /// what the subject is — the last lines of a terminal — and to reach its bar.
  static const _heightFactor = 0.8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: constraints.maxHeight * _heightFactor,
            // Up from the bottom and back down. Moved rather than built in
            // and out, so what the panels hold survives being closed.
            child: IgnorePointer(
              ignoring: !open,
              child: AnimatedSlide(
                offset: open ? Offset.zero : const Offset(0, 1),
                duration: Durations.medium2,
                curve: open ? Curves.easeOutCubic : Curves.easeInCubic,
                child: Material(
                  color: scheme.surfaceContainerLow,
                  elevation: open ? 8 : 0,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(17),
                  ),
                  child: panels,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
