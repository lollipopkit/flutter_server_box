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
class AgentFloatingShell extends ConsumerWidget {
  const AgentFloatingShell({super.key, required this.area});

  /// The box this is painted in, measured by the caller.
  ///
  /// Not `MediaQuery.sizeOf`: that is the window, and a panel kept inside the
  /// window can still hang out of the area it is drawn in.
  final Size area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(agentShellProvider) == AgentShellMode.hidden) {
      return const SizedBox.shrink();
    }
    // The tab is the better view of the same thing whenever it is the one
    // being looked at, and two of them at once is only confusing.
    if (ref.watch(currentHomeTabProvider) == AppTab.agent) {
      return const SizedBox.shrink();
    }
    return ResponsiveBreakpoints.of(context).isMobile
        ? _PhoneShell(area: area)
        : _DesktopShell(area: area);
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
          icon: Icon(
            collapsed ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
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
  const _DesktopShell({required this.area});

  final Size area;

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
  const _PhoneShell({required this.area});

  final Size area;

  @override
  ConsumerState<_PhoneShell> createState() => _PhoneShellState();
}

class _PhoneShellState extends ConsumerState<_PhoneShell> {
  bool _onRight = AgentShellGeometry.pillOnRight;
  double _pillY = AgentShellGeometry.pillY;
  double _sheetFraction = AgentShellGeometry.sheetFraction;

  static const _pillSize = 52.0;

  @override
  Widget build(BuildContext context) {
    return ref.watch(agentShellProvider) == AgentShellMode.collapsed
        ? _buildPill(context)
        : _buildSheet(context);
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
      child: GestureDetector(
        onPanUpdate: (details) => setState(() {
          if (travel > 0) {
            _pillY = (_pillY + details.delta.dy / travel).clamp(0.0, 1.0);
          }
          // Which edge is decided by which half the finger is in, so a drag
          // across the screen moves the pill with it rather than snapping back.
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
                  // A ring rather than a badge: the pill is the only sign the
                  // Agent is doing anything while you are on another tab.
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
              child: AgentConversationView(compact: true, showHeader: false),
            ),
          ],
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
