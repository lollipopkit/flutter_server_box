import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/provider/ai/agent_session.dart';
import 'package:server_box/data/provider/ai/agent_shell.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/view/page/agent/view.dart';

/// The Agent, over whatever else is on screen.
///
/// Mounted by the home page above its `PageView` rather than inside any tab,
/// because the point of it is to not belong to one. What it shows is the same
/// [agentSessionProvider] the Agent tab shows — this is a second window onto
/// one conversation, not a second conversation.
///
/// Two renderings: a panel you drag around a desktop window, and a pill that
/// clings to the edge of a phone and opens upwards. Same content in both.
class AgentFloatingShell extends ConsumerStatefulWidget {
  const AgentFloatingShell({super.key, required this.area});

  /// The box this is painted in, measured by the caller.
  ///
  /// Not `MediaQuery.sizeOf`: that is the window, and a panel kept inside the
  /// window can still hang out of the area it is drawn in.
  final Size area;

  @override
  ConsumerState<AgentFloatingShell> createState() =>
      _AgentFloatingShellState();
}

class _AgentFloatingShellState extends ConsumerState<AgentFloatingShell>
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
    final visible =
        ref.watch(agentShellProvider) != AgentShellMode.hidden &&
        // The tab is the better view of the same thing whenever it is the one
        // being looked at, and two of them at once is only confusing.
        ref.watch(currentHomeTabProvider) != AppTab.agent;

    // Driven from `build` because both inputs are providers, and this is where
    // their current value is known. Both calls are no-ops once the controller
    // is already going that way.
    if (visible) {
      _reveal.forward();
    } else {
      _reveal.reverse();
    }

    // Gone, and nothing on its way back. Worth unmounting rather than merely
    // hiding: the conversation inside watches the session, and would rebuild
    // on every streamed token behind a closed window.
    if (!visible && _reveal.isDismissed) return const SizedBox.shrink();

    return ResponsiveBreakpoints.of(context).isMobile
        ? _PhoneShell(area: widget.area, reveal: _curve)
        : _DesktopShell(area: widget.area, reveal: _curve);
  }
}

/// The controls that act on the window rather than on the conversation.
class _WindowButtons extends ConsumerWidget {
  const _WindowButtons({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = ref.read(agentShellProvider.notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: collapsed ? context.l10n.agentTitle : libL10n.fold,
          visualDensity: VisualDensity.compact,
          onPressed: collapsed ? shell.expand : shell.collapse,
          // Larger than the default, and larger than the close beside it. A
          // chevron is a thin glyph in a wide box: at the same nominal size as
          // the solid icons either side of it, it draws to about two thirds of
          // their height and reads as a smaller button.
          icon: Icon(
            collapsed ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            size: 28,
          ),
        ),
        IconButton(
          tooltip: libL10n.close,
          visualDensity: VisualDensity.compact,
          onPressed: shell.hide,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- desktop

class _DesktopShell extends ConsumerStatefulWidget {
  const _DesktopShell({required this.area, required this.reveal});

  final Size area;

  /// Runs forward as the panel appears and back as it closes.
  final Animation<double> reveal;

  @override
  ConsumerState<_DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<_DesktopShell> {
  Offset? _offset = AgentShellGeometry.offset;
  Size _size = AgentShellGeometry.size;

  /// True between a drag's first move and its end.
  ///
  /// Collapsing should glide; a drag should not. Animating the box while the
  /// pointer is moving it makes the panel lag behind the cursor and overshoot
  /// when it stops.
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collapsed =
        ref.watch(agentShellProvider) == AgentShellMode.collapsed;
    final padding = MediaQuery.paddingOf(context);
    Rect rectFor(bool collapsed) => AgentShellGeometry.desktopRect(
      area: widget.area,
      topInset: padding.top,
      bottomInset: padding.bottom,
      offset: _offset,
      size: _size,
      collapsed: collapsed,
    );

    final rect = rectFor(collapsed);
    // The conversation is laid out at its open height even while the box is
    // shrinking past it, so collapsing clips it rather than re-flowing it into
    // a bar-sized column — which would overflow, and would make expanding
    // again a re-layout instead of a reveal.
    final contentHeight =
        rectFor(false).height - AgentShellGeometry.barHeight;

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
                        child: const AgentConversationView(
                          compact: true,
                          showHeader: false,
                        ),
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
          AgentShellGeometry.saveOffset(origin);
          setState(() => _dragging = false);
        },
        onPanCancel: () => setState(() => _dragging = false),
        child: Container(
          height: AgentShellGeometry.barHeight,
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            border: Border(bottom: BorderSide(color: Hairline.color(context))),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 17,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.agentTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const AgentHeaderActions(showConversations: true),
              _WindowButtons(collapsed: collapsed),
            ],
          ),
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
          AgentShellGeometry.saveSize(current);
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

class _PhoneShell extends ConsumerStatefulWidget {
  const _PhoneShell({required this.area, required this.reveal});

  final Size area;

  /// Runs forward as the shell appears and back as it closes.
  final Animation<double> reveal;

  @override
  ConsumerState<_PhoneShell> createState() => _PhoneShellState();
}

class _PhoneShellState extends ConsumerState<_PhoneShell>
    with SingleTickerProviderStateMixin {
  bool _onRight = AgentShellGeometry.pillOnRight;
  double _pillY = AgentShellGeometry.pillY;
  double _sheetFraction = AgentShellGeometry.sheetFraction;

  static const _pillSize = 52.0;

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
    value: ref.read(agentShellProvider) == AgentShellMode.collapsed ? 0 : 1,
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
    final mode = ref.watch(agentShellProvider);
    // Left where it is while the shell is on its way out: driven from the
    // mode alone, hiding the sheet would also play it collapsing into a pill
    // that is itself fading away.
    if (mode != AgentShellMode.hidden) {
      if (mode == AgentShellMode.collapsed) {
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
    final area = widget.area;
    final padding = MediaQuery.paddingOf(context);
    const margin = AgentShellGeometry.margin;
    final working = ref.watch(
      agentSessionProvider.select((session) => session.isWorking),
    );

    final travel = AgentShellGeometry.pillTravelFor(
      areaHeight: area.height,
      topInset: padding.top,
      bottomInset: padding.bottom,
      pillSize: _pillSize,
    );
    final top = AgentShellGeometry.pillTopFor(
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
                AgentShellGeometry.savePill(onRight: _onRight, y: _pillY),
            child: Material(
              elevation: 6,
              shape: const CircleBorder(),
              color: theme.colorScheme.primaryContainer,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: ref.read(agentShellProvider.notifier).expand,
                child: SizedBox(
                  width: _pillSize,
                  height: _pillSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // A ring rather than a badge: the pill is the only sign
                      // the Agent is doing anything while you are on another
                      // tab.
                      if (working)
                        SizedBox(
                          width: _pillSize - 8,
                          height: _pillSize - 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      Icon(
                        Icons.auto_awesome,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 22,
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
    final area = widget.area;
    final padding = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final height = AgentShellGeometry.sheetHeightFor(
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
                const Expanded(
                  child: AgentConversationView(
                    compact: true,
                    showHeader: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrabBar(BuildContext context, ThemeData theme, double height) {
    final area = widget.area;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Upwards is a taller panel, so the delta is subtracted.
      onPanUpdate: (details) => setState(() {
        _sheetFraction = ((height - details.delta.dy) / area.height).clamp(
          AgentShellGeometry.minSheetFraction,
          AgentShellGeometry.maxSheetFraction,
        );
      }),
      onPanEnd: (_) => AgentShellGeometry.saveSheetFraction(_sheetFraction),
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
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 17,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.agentTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const AgentHeaderActions(showConversations: true),
                const _WindowButtons(collapsed: false),
              ],
            ),
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
