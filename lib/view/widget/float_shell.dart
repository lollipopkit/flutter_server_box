import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:server_box/data/model/app/float_shell.dart';

/// One size for every icon button in a floating panel's title bar, and in the
/// headers that have to weigh the same as one.
///
/// Material's default is 24, which the buttons took and the marks beside them
/// did not — 21 on the tab, 17 in the phone sheet, 22 on the desktop panel —
/// so a row meant to read as one strip had four weights in it. Stated once
/// here rather than at each call site, which is how it came to have four.
///
/// Thin glyphs are the exception and say so where they are used: a chevron in
/// a box this size draws to about two thirds of a solid icon's height.
const floatHeaderIconSize = 22.0;

/// What a chevron needs to weigh the same as the solid icons beside it.
///
/// Not a multiple of [floatHeaderIconSize]: an `IconButton` is its icon plus 8
/// either side, and the desktop panel's title bar is
/// [FloatShellGeometry.barHeight] — 44 — so anything past 28 overflows a bar
/// that cannot grow. 26 leaves the margin and still reads level with a 22
/// close button.
const floatHeaderChevronSize = 26.0;

/// A panel over whatever else is on screen.
///
/// Mounted by the home page above its `PageView` rather than inside any tab,
/// because the point of it is to not belong to one.
///
/// Two renderings: a panel you drag around a desktop window, and a pill that
/// clings to the edge of a phone and opens upwards. Same content in both.
///
/// What that content is, and what the panel is a window *onto*, is the
/// caller's — the Agent's conversation and a floating terminal are the two,
/// and neither of them is what this file is about. This is the window: where
/// it sits, how big it is, how it arrives and leaves, and the three buttons
/// that act on it rather than on what is inside it.
class FloatShell extends StatefulWidget {
  const FloatShell({
    super.key,
    required this.area,
    required this.visible,
    required this.mode,
    required this.geometry,
    required this.title,
    required this.icon,
    required this.onExpand,
    required this.onCollapse,
    required this.onHide,
    required this.builder,
    this.actions = const [],
    this.pillOverlay,
    this.expandTooltip,
    this.hideTooltip,
  });

  /// The box this is painted in, measured by the caller.
  ///
  /// Not `MediaQuery.sizeOf`: that is the window, and a panel kept inside the
  /// window can still hang out of the area it is drawn in.
  final Size area;

  /// Whether there is anything to show. False plays the panel out and then
  /// stops building it — see [mode], which says nothing about this: a panel
  /// can be collapsed and still be on screen.
  final bool visible;

  final FloatShellMode mode;

  /// Where this panel was left, and where a drag writes it back to.
  final FloatShellGeometry geometry;

  /// Named on the title bar and in the collapsed bar it shrinks to.
  final String title;

  /// Beside the title, and alone inside the phone's pill.
  final IconData icon;

  final VoidCallback onExpand;
  final VoidCallback onCollapse;

  /// What the close button does. "Hide", not "close": the panel is a window
  /// onto something that carries on without it.
  final VoidCallback onHide;

  /// The content, built only while the panel is on screen.
  final WidgetBuilder builder;

  /// Buttons that act on what is inside the panel, before the ones that act on
  /// the panel itself.
  final List<Widget> actions;

  /// Drawn behind [icon] in the collapsed pill — a progress ring, a badge.
  /// The pill is the only sign of the panel while you are on another tab.
  final Widget? pillOverlay;

  /// What the chevron says while collapsed. Defaults to [title], which is what
  /// a collapsed panel has room for.
  final String? expandTooltip;

  final String? hideTooltip;

  @override
  State<FloatShell> createState() => _FloatShellState();
}

class _FloatShellState extends State<FloatShell>
    with SingleTickerProviderStateMixin {
  late final _reveal = AnimationController(
    vsync: this,
    duration: Durations.medium2,
    // Closing something is an acknowledgement, not a presentation.
    reverseDuration: Durations.short4,
  );

  late final _curve = CurvedAnimation(
    parent: _reveal,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeIn,
  );

  @override
  void initState() {
    super.initState();
    // The only thing that has to rebuild on the animation finishing is the
    // decision below to stop building at all; the transitions listen for
    // themselves.
    _reveal.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _curve.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Driven from `build` because the caller's inputs are providers, and this
    // is where their current value is known. Both calls are no-ops once the
    // controller is already going that way.
    if (widget.visible) {
      _reveal.forward();
    } else {
      _reveal.reverse();
    }

    // Gone, and nothing on its way back. Worth unmounting rather than merely
    // hiding: what is inside watches something live, and would rebuild on
    // every streamed token or line of output behind a closed window.
    if (!widget.visible && _reveal.isDismissed) return const SizedBox.shrink();

    return ResponsiveBreakpoints.of(context).isMobile
        ? _PhoneShell(shell: widget, reveal: _curve)
        : _DesktopShell(shell: widget, reveal: _curve);
  }
}

/// The controls that act on the window rather than on what is in it.
class _WindowButtons extends StatelessWidget {
  const _WindowButtons({required this.shell, required this.collapsed});

  final FloatShell shell;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: collapsed
              ? (shell.expandTooltip ?? shell.title)
              : libL10n.fold,
          visualDensity: VisualDensity.compact,
          onPressed: collapsed ? shell.onExpand : shell.onCollapse,
          // A chevron is a thin glyph in a wide box: at the size the solid
          // icons take it draws to about two thirds of their height and reads
          // as the smaller button — see [floatHeaderChevronSize].
          icon: Icon(
            collapsed ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            size: floatHeaderChevronSize,
          ),
        ),
        IconButton(
          tooltip: shell.hideTooltip ?? libL10n.close,
          visualDensity: VisualDensity.compact,
          onPressed: shell.onHide,
          icon: const Icon(Icons.close, size: floatHeaderIconSize),
        ),
      ],
    );
  }
}

/// The title bar's contents, shared by the desktop panel and the phone sheet.
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.shell, required this.collapsed});

  final FloatShell shell;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          shell.icon,
          size: floatHeaderIconSize,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            shell.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...shell.actions,
        _WindowButtons(shell: shell, collapsed: collapsed),
      ],
    );
  }
}

// ----------------------------------------------------------------- desktop

class _DesktopShell extends StatefulWidget {
  const _DesktopShell({required this.shell, required this.reveal});

  final FloatShell shell;

  /// Runs forward as the panel appears and back as it closes.
  final Animation<double> reveal;

  @override
  State<_DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<_DesktopShell> {
  late Offset? _offset = widget.shell.geometry.offset;
  late Size _size = widget.shell.geometry.size;

  /// True between a drag's first move and its end.
  ///
  /// Collapsing should glide; a drag should not. Animating the box while the
  /// pointer is moving it makes the panel lag behind the cursor and overshoot
  /// when it stops.
  bool _dragging = false;

  FloatShell get _shell => widget.shell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collapsed = _shell.mode == FloatShellMode.collapsed;
    final padding = MediaQuery.paddingOf(context);
    Rect rectFor(bool collapsed) => FloatShellGeometry.desktopRect(
      area: _shell.area,
      topInset: padding.top,
      bottomInset: padding.bottom,
      offset: _offset,
      size: _size,
      collapsed: collapsed,
      corner: _shell.geometry.defaultCorner,
    );

    final rect = rectFor(collapsed);
    // The content is laid out at its open height even while the box is
    // shrinking past it, so collapsing clips it rather than re-flowing it into
    // a bar-sized column — which would overflow, and would make expanding
    // again a re-layout instead of a reveal.
    final contentHeight = rectFor(false).height - FloatShellGeometry.barHeight;

    return AnimatedPositioned(
      duration: _dragging ? Duration.zero : Durations.medium2,
      curve: Curves.easeOutCubic,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      // Inside the `Positioned`, not around it: a transition builds a render
      // object, and the stack has to be the one reading the position.
      child: _Reveal(
        animation: widget.reveal,
        alignment: Alignment.bottomRight,
        child: Material(
          elevation: 12,
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Hairline.color(context)),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  _buildTitleBar(context, theme, collapsed, rect.topLeft),
                  Expanded(
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: contentHeight,
                        maxHeight: contentHeight,
                        child: Builder(builder: _shell.builder),
                      ),
                    ),
                  ),
                ],
              ),
              if (!collapsed)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _buildResizeHandle(theme, rect.size),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(
    BuildContext context,
    ThemeData theme,
    bool collapsed,
    Offset origin,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Against the clamped position this frame, not the stored one, so a
        // panel that was pushed back inside the window by a resize carries on
        // from where it actually is.
        onPanUpdate: (details) => setState(() {
          _dragging = true;
          _offset = origin + details.delta;
        }),
        // Saved where the drag ends rather than continuously: this writes to
        // the store, and a pointer move is not an event worth a write each.
        onPanEnd: (_) {
          _shell.geometry.saveOffset(origin);
          setState(() => _dragging = false);
        },
        onPanCancel: () => setState(() => _dragging = false),
        child: Container(
          height: FloatShellGeometry.barHeight,
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            border: Border(bottom: BorderSide(color: Hairline.color(context))),
          ),
          child: _TitleRow(shell: _shell, collapsed: collapsed),
        ),
      ),
    );
  }

  Widget _buildResizeHandle(ThemeData theme, Size current) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeDownRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => setState(() {
          _dragging = true;
          _size = Size(
            current.width + details.delta.dx,
            current.height + details.delta.dy,
          );
        }),
        onPanEnd: (_) {
          _shell.geometry.saveSize(current);
          setState(() => _dragging = false);
        },
        onPanCancel: () => setState(() => _dragging = false),
        child: SizedBox(
          width: 20,
          height: 20,
          child: Icon(
            Icons.signal_cellular_4_bar,
            size: 11,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- phone

class _PhoneShell extends StatefulWidget {
  const _PhoneShell({required this.shell, required this.reveal});

  final FloatShell shell;

  /// Runs forward as the shell appears and back as it closes.
  final Animation<double> reveal;

  @override
  State<_PhoneShell> createState() => _PhoneShellState();
}

class _PhoneShellState extends State<_PhoneShell>
    with SingleTickerProviderStateMixin {
  late bool _onRight = widget.shell.geometry.pillOnRight;
  late double _pillY = widget.shell.geometry.pillY;
  late double _sheetFraction = widget.shell.geometry.sheetFraction;

  static const _pillSize = 52.0;

  FloatShell get _shell => widget.shell;

  /// 0 while the pill is showing, 1 while the sheet is.
  ///
  /// The desktop panel glides between its two heights, which it can because
  /// both are the same box; here they are different shapes in different
  /// corners, so they cross over instead — the sheet slides up from the edge
  /// it will sit on while the pill goes. Without this the two simply replaced
  /// each other between one frame and the next.
  late final _expand = AnimationController(
    vsync: this,
    duration: Durations.medium2,
    // Same asymmetry as the reveal: opening presents, closing acknowledges.
    reverseDuration: Durations.short4,
    value: _shell.mode == FloatShellMode.collapsed ? 0 : 1,
  );

  late final _curve = CurvedAnimation(
    parent: _expand,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeIn,
  );

  @override
  void initState() {
    super.initState();
    // The ends are the only thing this state has to rebuild for: they decide
    // which of the two stops being built at all. In between both are on
    // screen and the transitions drive themselves.
    _expand.addStatusListener((status) {
      if (!mounted) return;
      if (status == AnimationStatus.dismissed ||
          status == AnimationStatus.completed) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _curve.dispose();
    _expand.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = _shell.mode;
    // Left where it is while the shell is on its way out: driven from the
    // mode alone, hiding the sheet would also play it collapsing into a pill
    // that is itself fading away.
    if (mode != FloatShellMode.hidden) {
      if (mode == FloatShellMode.collapsed) {
        _expand.reverse();
      } else {
        _expand.forward();
      }
    }

    // Both are on screen while one replaces the other, and the stack above has
    // one slot for this shell — so it takes the whole area and holds its own
    // stack. It paints nothing of its own, and a stack does not absorb what
    // its children did not catch, so everything under it stays tappable.
    return Positioned.fill(
      child: Stack(
        children: [
          if (!_expand.isCompleted) _buildPill(context),
          if (!_expand.isDismissed) _buildSheet(context),
        ],
      ),
    );
  }

  Widget _buildPill(BuildContext context) {
    final theme = Theme.of(context);
    final area = _shell.area;
    final padding = MediaQuery.paddingOf(context);
    const margin = FloatShellGeometry.margin;

    final travel = FloatShellGeometry.pillTravelFor(
      areaHeight: area.height,
      topInset: padding.top,
      bottomInset: padding.bottom,
      pillSize: _pillSize,
    );
    final top = FloatShellGeometry.pillTopFor(
      areaHeight: area.height,
      topInset: padding.top,
      bottomInset: padding.bottom,
      y: _pillY,
      pillSize: _pillSize,
    );

    return Positioned(
      left: _onRight ? null : margin,
      right: _onRight ? margin : null,
      top: top,
      child: _Reveal(
        animation: widget.reveal,
        alignment: Alignment.center,
        // Out of the way as the sheet arrives, and back as it leaves.
        child: _Reveal(
          animation: ReverseAnimation(_curve),
          alignment: Alignment.center,
          child: GestureDetector(
            onPanUpdate: (details) => setState(() {
              if (travel > 0) {
                _pillY = (_pillY + details.delta.dy / travel).clamp(0.0, 1.0);
              }
              // Which edge is decided by which half the finger is in, so a
              // drag across the screen moves the pill with it rather than
              // snapping back.
              _onRight = details.globalPosition.dx > area.width / 2;
            }),
            onPanEnd: (_) =>
                _shell.geometry.savePill(onRight: _onRight, y: _pillY),
            child: Material(
              elevation: 6,
              shape: const CircleBorder(),
              color: theme.colorScheme.primaryContainer,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _shell.onExpand,
                child: SizedBox(
                  width: _pillSize,
                  height: _pillSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ?_shell.pillOverlay,
                      Icon(
                        _shell.icon,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: floatHeaderIconSize,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheet(BuildContext context) {
    final theme = Theme.of(context);
    final area = _shell.area;
    final padding = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final height = FloatShellGeometry.sheetHeightFor(
      areaHeight: area.height,
      topInset: padding.top,
      keyboardInset: keyboard,
      fraction: _sheetFraction,
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: keyboard,
      height: height,
      child: _Reveal(
        animation: widget.reveal,
        alignment: Alignment.bottomCenter,
        // In from the edge it sits on, which is where it goes when collapsed.
        // The stack it is in clips, so what is still below the screen is not
        // drawn over the tab bar on the way past.
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(_curve),
          child: Material(
            elevation: 12,
            color: theme.colorScheme.surface,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                _buildGrabBar(context, theme, height),
                Expanded(child: Builder(builder: _shell.builder)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrabBar(BuildContext context, ThemeData theme, double height) {
    final area = _shell.area;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Upwards is a taller panel, so the delta is subtracted.
      onPanUpdate: (details) => setState(() {
        _sheetFraction = ((height - details.delta.dy) / area.height).clamp(
          FloatShellGeometry.minSheetFraction,
          FloatShellGeometry.maxSheetFraction,
        );
      }),
      onPanEnd: (_) => _shell.geometry.saveSheetFraction(_sheetFraction),
      child: Container(
        padding: const EdgeInsets.only(left: 14, right: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          border: Border(bottom: BorderSide(color: Hairline.color(context))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _TitleRow(shell: _shell, collapsed: false),
          ],
        ),
      ),
    );
  }
}

/// Fades and eases a floating panel in, and back out again on close.
///
/// A widget rather than a pair of transitions written twice, and inside the
/// `Positioned` in every caller: a transition builds a render object, so the
/// stack has to be the thing reading the position, not this.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.animation,
    required this.alignment,
    required this.child,
  });

  final Animation<double> animation;

  /// What the panel grows out of and shrinks back into — its own corner on a
  /// desktop, the bottom edge for a phone sheet.
  final Alignment alignment;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
        alignment: alignment,
        child: child,
      ),
    );
  }
}
