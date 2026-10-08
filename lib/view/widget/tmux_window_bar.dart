import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/ssh/terminal_status.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_client.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_models.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:server_box/view/widget/terminal_status_dot.dart';

/// A native app bar for the windows in the attached tmux session.
///
/// tmux remains the source of truth: the bar is rebuilt from control-mode
/// notifications, and tapping a window sends `select-window` over the same
/// CC client that carries pane output.
final class TmuxWindowBar extends StatelessWidget {
  final TmuxControlClient? client;
  final ValueChanged<TmuxControlWindow>? onSelectWindow;
  final ValueChanged<TmuxControlPane>? onSelectPane;
  final VoidCallback? onNewWindow;
  final ValueChanged<TmuxControlWindow>? onCloseWindow;
  final ValueChanged<TmuxControlPane>? onClosePane;

  /// What each pane's programs report, marked on its window and in the pane
  /// menu: a pane out of sight is where a program waiting is easy to miss.
  final TerminalStatus? status;

  const TmuxWindowBar({
    super.key,
    required this.client,
    this.status,
    this.onSelectWindow,
    this.onSelectPane,
    this.onNewWindow,
    this.onCloseWindow,
    this.onClosePane,
  });

  @override
  Widget build(BuildContext context) {
    final controlClient = client;
    if (controlClient == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        bottom: false,
        child: StreamBuilder<TmuxControlSnapshot>(
          stream: controlClient.snapshots,
          initialData: controlClient.snapshot,
          builder: (context, snapshot) {
            final state = snapshot.data;
            if (state == null) return const SizedBox.shrink();
            Widget view() => _TmuxWindowBarView(
              state: state,
              status: status,
              onSelectWindow: onSelectWindow,
              onSelectPane: onSelectPane,
              onNewWindow: onNewWindow,
              onCloseWindow: onCloseWindow,
              onClosePane: onClosePane,
            );
            final status_ = status;
            if (status_ == null) return view();
            return ListenableBuilder(
              listenable: status_,
              builder: (_, _) => view(),
            );
          },
        ),
      ),
    );
  }
}

final class _TmuxWindowBarView extends StatelessWidget {
  final TmuxControlSnapshot state;
  final TerminalStatus? status;
  final ValueChanged<TmuxControlWindow>? onSelectWindow;
  final ValueChanged<TmuxControlPane>? onSelectPane;
  final VoidCallback? onNewWindow;
  final ValueChanged<TmuxControlWindow>? onCloseWindow;
  final ValueChanged<TmuxControlPane>? onClosePane;

  const _TmuxWindowBarView({
    required this.state,
    this.status,
    this.onSelectWindow,
    this.onSelectPane,
    this.onNewWindow,
    this.onCloseWindow,
    this.onClosePane,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final active = state.activeWindow;
    final panes = active?.panes ?? const <TmuxControlPane>[];
    final activePane = panes
        .where((pane) => pane.id == state.activePaneId)
        .firstOrNull;
    TerminalStatusHeadline? windowStatus(TmuxWindowId window) =>
        status?.headlineOf([
          for (final MapEntry(:key, :value) in state.paneWindows.entries)
            if (value == window) key,
        ]);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 46,
          child: Row(
            children: [
              const SizedBox(width: 10),
              Icon(Icons.terminal_outlined, size: 17, color: scheme.primary),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 116),
                child: Tooltip(
                  message: state.session.name,
                  child: Text(
                    state.session.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              VerticalDivider(
                width: 1,
                thickness: 1,
                indent: 10,
                endIndent: 10,
                color: scheme.outlineVariant,
              ),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  children: [
                    if (state.windows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.tmuxNoWindowsFound,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      for (final window in state.windows)
                        _TmuxBarChip(
                          label: '${window.index}:${window.name}',
                          selected: window.id == state.activeWindowId,
                          status: windowStatus(window.id),
                          onTap: onSelectWindow == null
                              ? null
                              : () => onSelectWindow!(window),
                        ),
                  ],
                ),
              ),
              if (panes.length > 1 && activePane != null) ...[
                _PaneSummaryButton(
                  panes: panes,
                  activePaneId: activePane.id,
                  status: status,
                  onSelectPane: onSelectPane,
                  onClosePane: onClosePane,
                ),
                const SizedBox(width: 2),
              ],
              IconButton(
                tooltip: l10n.tmuxNewWindow,
                onPressed: onNewWindow,
                icon: const Icon(Icons.add_outlined, size: 18),
                visualDensity: VisualDensity.compact,
              ),
              if (active != null && onCloseWindow != null)
                IconButton(
                  tooltip: libL10n.delete,
                  onPressed: () => onCloseWindow!(active),
                  icon: const Icon(Icons.close_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ],
    );
  }
}

final class _PaneSummaryButton extends StatefulWidget {
  final List<TmuxControlPane> panes;
  final TmuxPaneId activePaneId;
  final TerminalStatus? status;
  final ValueChanged<TmuxControlPane>? onSelectPane;
  final ValueChanged<TmuxControlPane>? onClosePane;

  const _PaneSummaryButton({
    required this.panes,
    required this.activePaneId,
    this.status,
    this.onSelectPane,
    this.onClosePane,
  });

  @override
  State<_PaneSummaryButton> createState() => _PaneSummaryButtonState();
}

final class _PaneSummaryButtonState extends State<_PaneSummaryButton> {
  void _showPaneMenu(BuildContext buttonContext) {
    final button = buttonContext.findRenderObject();
    if (button is! RenderBox || !button.hasSize) return;
    final onClose = widget.onClosePane;
    // The menu belongs to the control that opened it. A bottom sheet would put
    // a pane switch at the opposite end of the screen from the window switch,
    // even though both are selections in the same tmux hierarchy.
    showContextMenu(
      buttonContext,
      [
        for (final pane in widget.panes)
          ContextMenuAction(
            text: '${pane.index}:${pane.displayName}',
            note: widget.status?.headlineOf([pane.id])?.describe(),
            checked: pane.id == widget.activePaneId,
            // Run once the menu has closed, by when the bar may be gone with
            // the session it was for.
            onTap: () {
              if (mounted) widget.onSelectPane?.call(pane);
            },
            trailing: onClose == null
                ? null
                : ContextMenuTrailing(
                    key: ValueKey('close_tmux_pane_${pane.id}'),
                    icon: Icons.close_outlined,
                    tooltip: libL10n.delete,
                    onTap: () {
                      if (mounted) onClose(pane);
                    },
                  ),
          ),
      ],
      at: button.localToGlobal(button.size.bottomLeft(const Offset(0, 4))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = scheme.onSurfaceVariant;
    final activeIndex = widget.panes.indexWhere(
      (pane) => pane.id == widget.activePaneId,
    );
    // The panes out of sight: the one on screen speaks for itself.
    final hidden = widget.status
        ?.headlineOf([
          for (final pane in widget.panes)
            if (pane.id != widget.activePaneId) pane.id,
        ])
        ?.colorIn(scheme);

    final active = activeIndex < 0 ? null : widget.panes[activeIndex];
    final label = [
      if (active != null) '${active.index}:${active.displayName}',
      '${activeIndex < 0 ? 1 : activeIndex + 1}/${widget.panes.length}',
    ].join(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      // What it opens is the pane list, so it says which pane is on screen and
      // of how many, to a screen reader and on hover alike.
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: label,
          onTap: () => _showPaneMenu(context),
          excludeSemantics: true,
          child: Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => _showPaneMenu(context),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.grid_view_outlined,
                      size: 13,
                      color: hidden ?? foreground,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${activeIndex < 0 ? 1 : activeIndex + 1}'
                      '/${widget.panes.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _TmuxBarChip extends StatelessWidget {
  final String label;
  final bool selected;
  final TerminalStatusHeadline? status;
  final VoidCallback? onTap;

  const _TmuxBarChip({
    required this.label,
    required this.selected,
    this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = selected
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    final mark = status?.colorIn(scheme);

    final chip = Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected
                      ? Icons.check_circle
                      : mark != null
                      ? Icons.circle
                      : Icons.circle_outlined,
                  size: 11,
                  color: mark ?? foreground,
                ),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 128),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final status_ = status;
    if (status_ == null || mark == null) return chip;
    return Tooltip(message: status_.describe(), child: chip);
  }
}
