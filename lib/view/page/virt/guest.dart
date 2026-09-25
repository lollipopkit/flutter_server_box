// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/serial_wake.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/session_keep_alive.dart';
import 'package:server_box/data/provider/virt/text_consoles.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/src/rust/api/remote_desktop.dart' as ffi;
import 'package:server_box/view/page/remote_desktop/viewer.dart';
import 'package:server_box/view/page/server/chart.dart';
import 'package:server_box/view/page/server/reading_text.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/page/virt/common.dart';
import 'package:server_box/view/page/virt/console_connect.dart';
import 'package:server_box/view/page/virt/snapshots.dart';
import 'package:server_box/view/widget/progress_line.dart';

part 'console.dart';
part 'overview.dart';

final class VirtGuestArgs {
  const VirtGuestArgs({required this.serverId, required this.guestId});

  final String serverId;
  final String guestId;
}

/// A guest over the list, for a window with room for one column.
///
/// Pushed once from the list. Moving to another guest from here is the
/// switcher in its bar, which changes the guest in place rather than pushing
/// a page per guest.
class VirtGuestPage extends StatelessWidget {
  const VirtGuestPage({super.key, required this.args});

  final VirtGuestArgs args;

  static const route = AppRouteArg<void, VirtGuestArgs>(
    page: VirtGuestPage.new,
    path: '/virt/guest',
  );

  @override
  Widget build(BuildContext context) {
    return VirtGuestView(
      serverId: args.serverId,
      guestId: args.guestId,
      switcher: true,
      leading: const BackButton(),
      onDeleted: () => context.pop(),
    );
  }
}

/// The views a guest has. Hardware, settings and backup come later, as more
/// of these.
enum VirtGuestViewKind {
  overview,
  console,

  /// Where the host has `VirtCapabilities.snapshots`, and not for a template.
  snapshots;

  /// The views [guest] has on a host with [caps].
  static List<VirtGuestViewKind> of(VirtGuest guest, VirtCapabilities? caps) =>
      [
        overview,
        console,
        if ((caps?.snapshots ?? false) && !guest.template) snapshots,
      ];
}

/// One guest: what it is doing, what it is, and the power actions it offers.
///
/// Its own `ref`, because the tab builds it inside a pane whose builder runs
/// on another element.
class VirtGuestView extends ConsumerStatefulWidget {
  const VirtGuestView({
    super.key,
    required this.serverId,
    required this.guestId,
    this.switcher = false,
    this.leading,
    this.onDeleted,
  });

  final String serverId;
  final String guestId;

  /// The guest was deleted from here: whatever shows this closes it.
  final VoidCallback? onDeleted;

  /// Whether the name in the bar opens the host's other guests — with one
  /// column, where the list is not beside this.
  final bool switcher;

  final Widget? leading;

  @override
  ConsumerState<VirtGuestView> createState() => _VirtGuestViewState();
}

class _VirtGuestViewState extends ConsumerState<VirtGuestView> {
  late String _guestId = widget.guestId;
  var _view = VirtGuestViewKind.overview;

  /// The console chosen in the Console segment's second level; null for the
  /// guest's default ([VirtConsoleView.defaultKind]).
  VirtConsoleKind? _console;
  var _metric = _VirtMetric.cpu;

  /// The chart's window: null for this session's samples, otherwise the
  /// host's stored history over it.
  VirtHistoryWindow? _window;
  Future<List<VirtStats>>? _stored;

  Future<VirtGuestDetail>? _detail;

  /// The state [_detail] was fetched in. A guest that starts gains a display
  /// and interface names, so the detail is fetched again when this changes.
  bool? _detailActive;

  VirtHostNotifier get _notifier =>
      ref.read(virtHostProvider(widget.serverId).notifier);

  @override
  void didUpdateWidget(VirtGuestView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guestId != widget.guestId) _switchTo(widget.guestId);
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(virtHostProvider(widget.serverId));
    final guest = st.guest(_guestId);
    if (guest == null) {
      return Scaffold(
        appBar: _bar(st, null),
        body: st.data == null && st.error == null
            ? const Center(child: SizedLoading.medium)
            : EmptyPane(icon: Icons.view_in_ar_outlined, label: libL10n.empty),
      );
    }
    final state = st.displayState(guest);
    _syncDetail(guest, state);
    final busy = st.isBusy(guest.id) || state.isTransient;
    final views = VirtGuestViewKind.of(guest, st.data?.capabilities);
    // A view the guest does not have (a host that lost a capability, a guest
    // switched to a template): back to the overview.
    final view = views.contains(_view) ? _view : VirtGuestViewKind.overview;

    return Scaffold(
      appBar: _bar(st, guest),
      body: Column(
        children: [
          SizedBox(height: 3, child: busy ? const ProgressLine() : null),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 3, 13, 7),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              // The detail says which consoles there are; with two, the
              // Console segment offers them as its second level.
              child: FutureBuilder<VirtGuestDetail>(
                future: _detail,
                builder: (_, snap) => SegmentedTabs<VirtGuestViewKind>(
                  selected: view,
                  onSelected: (v) => setState(() => _view = v),
                  segments: [
                    for (final v in views)
                      SegmentedTab(
                        value: v,
                        label: v.label,
                        icon: v.iconFor(guest),
                        sub: v == VirtGuestViewKind.console
                            ? _consoleSub(snap.data?.consoles, state)
                            : null,
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: switch (view) {
              VirtGuestViewKind.overview => _buildOverview(st, guest, state),
              VirtGuestViewKind.snapshots => VirtSnapshotsView(
                key: ValueKey('snapshots:${guest.id}'),
                serverId: widget.serverId,
                guest: guest,
                state: state,
                caps: st.data!.capabilities,
              ),
              VirtGuestViewKind.console => VirtConsoleView(
                serverId: widget.serverId,
                guest: guest,
                state: state,
                detail: _detail,
                kind: _console,
                onStart: _startIfOffered(st, guest),
                onRetryDetail: () => setState(() {
                  _detail = _notifier.detail(guest.id);
                }),
              ),
            },
          ),
        ],
      ),
    );
  }

  /// Terminal and Graphical, when the guest has both. Only while it is
  /// running: a stopped guest's console view offers to start it instead.
  SegmentedSub<VirtConsoleKind>? _consoleSub(
    Set<VirtConsoleKind>? consoles,
    VirtGuestState state,
  ) {
    if (!state.isActive || consoles == null || consoles.length < 2) {
      return null;
    }
    return SegmentedSub(
      selected: consoles.contains(_console)
          ? _console!
          : VirtConsoleView.defaultKind(consoles),
      onSelected: (kind) => setState(() => _console = kind),
      segments: [
        for (final kind in VirtConsoleKind.values)
          if (consoles.contains(kind))
            SegmentedTab(value: kind, label: kind.label, icon: kind.icon),
      ],
    );
  }

  /// The name, which of the host's guests it is when that is worth saying,
  /// and what can be done to it.
  PreferredSizeWidget _bar(VirtHostState st, VirtGuest? guest) {
    final guests = st.data?.guests ?? const <VirtGuest>[];
    final at = guest == null ? -1 : guests.indexOf(guest);
    final actions = guest == null
        ? const <VirtPowerAction>{}
        : st.actionsOf(guest);
    return PreferredSize(
      preferredSize: const Size.fromHeight(SessionTabBar.height),
      child: SizedBox(
        height: SessionTabBar.height,
        child: Row(
          children: [
            ?widget.leading,
            Expanded(
              child: SessionSwitcherLabel(
                name: guest?.name ?? '',
                icon: guest?.kind.icon,
                leading: guest == null
                    ? null
                    : VirtStateDot(st.displayState(guest)),
                position: widget.switcher && at >= 0 ? at + 1 : null,
                total: widget.switcher ? guests.length : 0,
                onTap: widget.switcher && guests.length > 1
                    ? () => unawaited(_showGuests(st))
                    : null,
              ),
            ),
            if (guest != null)
              for (final action in VirtPowerActionUi.barOrder)
                if (actions.contains(action))
                  Btn.icon(
                    key: ValueKey(action),
                    text: action.label,
                    icon: Icon(
                      action.icon,
                      size: 18,
                      color: action.destructive
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                    onTap: () => unawaited(_onPower(guest, action)),
                  ),
            // Last, after the power actions: it loses more than any of them.
            if (guest != null &&
                (st.data?.capabilities.create ?? false) &&
                !st.isBusy(guest.id))
              Btn.icon(
                key: const ValueKey('virt:delete'),
                text: libL10n.delete,
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                onTap: () => unawaited(_onDelete(st, guest)),
              ),
            const SizedBox(width: 7),
          ],
        ),
      ),
    );
  }

  VoidCallback? _startIfOffered(VirtHostState st, VirtGuest guest) {
    final actions = st.actionsOf(guest);
    final action = actions.contains(VirtPowerAction.start)
        ? VirtPowerAction.start
        : actions.contains(VirtPowerAction.resume)
        ? VirtPowerAction.resume
        : null;
    if (action == null) return null;
    return () => unawaited(_onPower(guest, action));
  }
}

extension on VirtGuestViewKind {
  String get label => switch (this) {
    VirtGuestViewKind.overview => l10n.virtOverview,
    VirtGuestViewKind.console => l10n.virtConsole,
    VirtGuestViewKind.snapshots => l10n.virtSnapshots,
  };

  IconData iconFor(VirtGuest guest) => switch (this) {
    VirtGuestViewKind.overview => Icons.monitor_heart_outlined,
    VirtGuestViewKind.console => guest.kind == VirtGuestKind.lxc
        ? Icons.terminal
        : Icons.desktop_windows_outlined,
    VirtGuestViewKind.snapshots => Icons.history,
  };
}

// --- Actions ---

extension _GuestActions on _VirtGuestViewState {
  void _switchTo(String guestId) {
    setState(() {
      _guestId = guestId;
      _console = null;
      _window = null;
      _stored = null;
      _detail = null;
      _detailActive = null;
    });
  }

  /// Fetches the detail the first time, and again when the guest has started
  /// or stopped since.
  ///
  /// A guest seen to stop takes its consoles with it: what they showed is
  /// gone, and waiting out the idle time would only keep a notice coming for
  /// a screen that no longer exists.
  void _syncDetail(VirtGuest guest, VirtGuestState state) {
    final active = state.isActive;
    if (_detail != null && _detailActive == active) return;
    if (_detailActive == true && !active) {
      final container = ProviderScope.containerOf(context, listen: false);
      final serverId = widget.serverId;
      final guestId = guest.id;
      // After the frame: this runs while the view is being built.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => VirtConsoleConnect.closeAll(
          container,
          serverId: serverId,
          guestId: guestId,
        ),
      );
    }
    _detailActive = active;
    _detail = _notifier.detail(guest.id);
  }

  /// Deletes [guest], once its name is typed back. A guest that is not
  /// stopped is offered a forced stop first, and asked again once it is off:
  /// deleting never stops anything by itself.
  Future<void> _onDelete(VirtHostState st, VirtGuest guest) async {
    if (st.displayState(guest) != VirtGuestState.stopped) {
      final stop = await context.showRoundDialog<bool>(
        title: libL10n.attention,
        child: Text(l10n.virtDeleteStopFirst(guest.name)),
        actions: Btnx.cancelRedOk,
      );
      if (stop != true || !mounted) return;
      try {
        await _notifier.power(guest.id, VirtPowerAction.forceStop);
        // The state after it, not the one the action started from.
        await _notifier.refresh();
      } on VirtErr catch (e) {
        Toast.error(e.title, body: e.detail);
        return;
      }
      if (!mounted) return;
      final now = ref.read(virtHostProvider(widget.serverId)).guest(guest.id);
      if (now == null || now.state != VirtGuestState.stopped) return;
      guest = now;
    }
    final keeps = st.data?.capabilities.deleteKeepsDisks ?? false;
    final removeDisks = await VirtDeleteDialog.show(
      context,
      name: guest.name,
      canKeepDisks: keeps,
    );
    if (removeDisks == null || !mounted) return;
    try {
      await _notifier.delete(guest.id, removeDisks: removeDisks);
      Toast.success(l10n.virtDeleted(guest.name));
      widget.onDeleted?.call();
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    } catch (e, s) {
      Loggers.app.warning('Deleting a guest', e, s);
      Toast.error(libL10n.fail, body: '$e');
    }
  }

  /// Asks, then acts. The action that loses the guest's unsaved state is
  /// asked in red.
  Future<void> _onPower(VirtGuest guest, VirtPowerAction action) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(libL10n.askContinue('${action.label} ${guest.name}')),
      actions: action.destructive ? Btnx.cancelRedOk : Btnx.cancelOk,
    );
    if (ok != true || !mounted) return;
    try {
      await _notifier.power(guest.id, action);
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    } catch (e, s) {
      Loggers.app.warning('Virtualization power action', e, s);
      Toast.error(libL10n.fail, body: '$e');
    }
  }

  /// The host's other guests, for the layout with no list beside this.
  Future<void> _showGuests(VirtHostState st) async {
    final guests = st.data?.guests ?? const <VirtGuest>[];
    final picked = await showRowsSheet<String>(
      context,
      rows: (ctx) => [
        for (final g in guests)
          ListTile(
            selected: g.id == _guestId,
            leading: VirtStateDot(st.displayState(g), size: 9),
            title: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(st.displayState(g).label, style: UIs.textGrey),
            onTap: () => Navigator.of(ctx).pop(g.id),
          ),
      ],
    );
    if (picked == null || picked == _guestId || !mounted) return;
    _switchTo(picked);
  }

  void _selectWindow(VirtHistoryWindow? window) {
    setState(() {
      _window = window;
      _stored = window == null
          ? null
          : _notifier.history(_guestId, window: window);
    });
  }
}

/// Asks to delete a guest named [name]: in red, with the name typed back
/// before the button does anything, and — where the host can keep them —
/// whether its disks go too. Answers whether to remove the disks, or null.
class VirtDeleteDialog extends StatefulWidget {
  const VirtDeleteDialog({
    super.key,
    required this.name,
    required this.canKeepDisks,
  });

  final String name;
  final bool canKeepDisks;

  static Future<bool?> show(
    BuildContext context, {
    required String name,
    required bool canKeepDisks,
  }) => context.showRoundDialog<bool>(
    title: libL10n.delete,
    child: VirtDeleteDialog(name: name, canKeepDisks: canKeepDisks),
  );

  @override
  State<VirtDeleteDialog> createState() => _VirtDeleteDialogState();
}

class _VirtDeleteDialogState extends State<VirtDeleteDialog> {
  final _typed = TextEditingController();
  var _removeDisks = true;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final matches = _typed.text == widget.name;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.virtDeleteAsk(widget.name),
          style: TextStyle(color: scheme.error),
        ),
        UIs.height13,
        Input(
          key: const ValueKey('delete:name'),
          controller: _typed,
          label: l10n.virtDeleteTypeName(widget.name),
          icon: Icons.keyboard_outlined,
          noWrap: true,
          suggestion: false,
          autoCorrect: false,
          onChanged: (_) => setState(() {}),
        ),
        if (widget.canKeepDisks)
          CheckboxListTile(
            key: const ValueKey('delete:disks'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l10n.virtDeleteDisks, style: UIs.text13),
            subtitle: Text(l10n.virtDeleteDisksTip, style: UIs.text12Grey),
            value: _removeDisks,
            onChanged: (v) => setState(() => _removeDisks = v ?? true),
          )
        else ...[
          UIs.height7,
          Text(l10n.virtDeleteDisksPve, style: UIs.text12Grey),
        ],
        UIs.height13,
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Btn.cancel(),
            UIs.width7,
            FilledButton(
              key: const ValueKey('delete:confirm'),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: matches
                  ? () => context.popDialog(_removeDisks)
                  : null,
              child: Text(libL10n.delete),
            ),
          ],
        ),
      ],
    );
  }
}
