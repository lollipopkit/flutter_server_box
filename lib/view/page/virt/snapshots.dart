import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/virt/common.dart';

/// A guest's snapshots: the tree, a new one, and reverting to or deleting
/// one — each asked first.
///
/// Reverting is asked in red when it loses more than changes: a snapshot
/// without memory stops a guest that is running, and the dialog offers to
/// start it again.
class VirtSnapshotsView extends ConsumerStatefulWidget {
  const VirtSnapshotsView({
    super.key,
    required this.serverId,
    required this.guest,
    required this.state,
    required this.caps,
  });

  final String serverId;
  final VirtGuest guest;

  /// [guest]'s state as it reads now (`VirtHostState.displayState`).
  final VirtGuestState state;
  final VirtCapabilities caps;

  @override
  ConsumerState<VirtSnapshotsView> createState() => _VirtSnapshotsViewState();
}

class _VirtSnapshotsViewState extends ConsumerState<VirtSnapshotsView> {
  /// The new-snapshot form is open.
  bool _creating = false;
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _memory = true;

  /// Open rows, by snapshot name.
  final _open = <String>{};

  VirtHostNotifier get _notifier =>
      ref.read(virtHostProvider(widget.serverId).notifier);

  VirtSnapshotsProvider get _provider =>
      virtSnapshotsProvider(widget.serverId, widget.guest.id);

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snaps = ref.watch(_provider);
    final busy = ref.watch(
      virtHostProvider(
        widget.serverId,
      ).select((s) => s.isBusy(widget.guest.id)),
    );
    final list = snaps.value;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(_provider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(13, 0, 13, 17),
        children: [
          _buildHead(list, busy),
          if (snaps.error case final e?)
            _buildError(e)
          else if (list == null)
            const Padding(
              padding: EdgeInsets.all(27),
              child: Center(child: SizedLoading.medium),
            )
          else if (list.isEmpty)
            CenterGreyTitle(l10n.virtSnapshotNone)
          else
            CardX(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  children: [
                    for (final (snap, depth) in virtSnapshotTree(list))
                      _buildRow(snap, depth, busy),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The count, what reverting costs, and the way to a new one.
  Widget _buildHead(List<VirtGuestSnapshot>? list, bool busy) {
    return VirtCard(
      icon: Icons.history,
      title: list == null
          ? l10n.virtSnapshots
          : '${l10n.virtSnapshots} · ${list.length}',
      trailing: _creating
          ? null
          : Btn.icon(
              key: const ValueKey('snapshot:new'),
              text: l10n.virtSnapshotCreate,
              icon: const Icon(Icons.add, size: 18),
              onTap: busy || list == null ? null : () => _openForm(list),
            ),
      children: [
        Text(l10n.virtSnapshotRevertTip, style: UIs.text12Grey),
        if (_creating && list != null) ..._buildForm(list, busy),
      ],
    );
  }

  List<Widget> _buildForm(List<VirtGuestSnapshot> list, bool busy) {
    final memory = virtSnapshotMemory(widget.caps, widget.guest, widget.state);
    final issue = virtSnapshotNameIssue(_name.text.trim(), list);
    final nameError = switch (issue) {
      VirtSnapshotNameIssue.invalid => l10n.virtSnapshotNameInvalid,
      VirtSnapshotNameIssue.taken => l10n.virtSnapshotNameTaken,
      VirtSnapshotNameIssue.empty || null => null,
    };
    final memoryNote = switch (memory) {
      VirtSnapshotMemory.optional => l10n.virtSnapshotMemoryTip,
      VirtSnapshotMemory.always => l10n.virtSnapshotMemoryAlways,
      VirtSnapshotMemory.none =>
        widget.guest.kind == VirtGuestKind.lxc
            ? null
            : l10n.virtSnapshotMemoryOff,
    };
    return [
      UIs.height13,
      Input(
        key: const ValueKey('snapshot:name'),
        controller: _name,
        label: libL10n.name,
        icon: Icons.label_outline,
        noWrap: true,
        errorText: nameError,
        onChanged: (_) => setState(() {}),
      ),
      UIs.height7,
      Input(
        key: const ValueKey('snapshot:desc'),
        controller: _desc,
        label: libL10n.description,
        icon: Icons.notes,
        noWrap: true,
        minLines: 1,
        maxLines: 3,
      ),
      if (memory != VirtSnapshotMemory.none)
        SwitchListTile(
          key: const ValueKey('snapshot:memory'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.virtSnapshotMemory, style: UIs.text13),
          subtitle: memoryNote == null
              ? null
              : Text(memoryNote, style: UIs.text12Grey),
          value: memory == VirtSnapshotMemory.always || _memory,
          onChanged: memory == VirtSnapshotMemory.optional
              ? (v) => setState(() => _memory = v)
              : null,
        )
      else if (memoryNote != null) ...[
        UIs.height7,
        Text(memoryNote, style: UIs.text12Grey),
      ],
      UIs.height7,
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Btn.text(
            text: libL10n.cancel,
            onTap: () => setState(() => _creating = false),
          ),
          UIs.width7,
          FilledButton(
            key: const ValueKey('snapshot:create'),
            onPressed: issue != null || busy
                ? null
                : () => unawaited(_create(memory)),
            child: Text(l10n.virtSnapshotCreate),
          ),
        ],
      ),
    ];
  }

  /// One snapshot: what it holds and when; open, where it came from and what
  /// can be done with it.
  Widget _buildRow(VirtGuestSnapshot snap, int depth, bool busy) {
    final open = _open.contains(snap.name);
    final scheme = Theme.of(context).colorScheme;
    final when = snap.createdAt;
    final sub = [
      if (when != null) when.simple(),
      snap.withMemory ? l10n.virtSnapshotWithMemory : l10n.virtSnapshotDiskOnly,
    ].join(' · ');
    // Without memory, a revert leaves the guest stopped: worth saying before
    // the button, not only in the dialog.
    final stops = !snap.withMemory && widget.state.isActive;
    return Padding(
      key: ValueKey('snapshot:${snap.name}'),
      // Depth by indent, capped so a long chain still has room for its name.
      padding: EdgeInsets.only(left: 13.0 * depth.clamp(0, 4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            dense: true,
            leading: Icon(
              snap.withMemory ? Icons.memory : Icons.save_outlined,
              size: 20,
              color: snap.current ? scheme.primary : null,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    snap.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (snap.current) ...[
                  UIs.width7,
                  VirtChip(libL10n.current),
                ],
              ],
            ),
            subtitle: Text(sub, style: UIs.text11Grey),
            trailing: Icon(open ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() {
              if (!_open.remove(snap.name)) _open.add(snap.name);
            }),
          ),
          Reveal(
            open: open,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 0, 17, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (when != null) VirtFact(libL10n.time, when.simple()),
                    VirtFact(l10n.virtSnapshotParent, snap.parent ?? '--'),
                    if (snap.description case final d?)
                      VirtFact(libL10n.description, d),
                    if (stops)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          l10n.virtSnapshotRevertStops(widget.guest.name),
                          style: const TextStyle(
                            fontSize: 12,
                            color: StatePalette.warn,
                          ),
                        ),
                      ),
                    UIs.height7,
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        TextButton.icon(
                          key: ValueKey('snapshot:delete:${snap.name}'),
                          onPressed: busy
                              ? null
                              : () => unawaited(_delete(snap)),
                          icon: Icon(Icons.delete_outline, color: scheme.error),
                          label: Text(
                            libL10n.delete,
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          key: ValueKey('snapshot:revert:${snap.name}'),
                          onPressed: busy
                              ? null
                              : () => unawaited(_revert(snap)),
                          icon: const Icon(Icons.restore, size: 18),
                          label: Text(l10n.virtSnapshotRevert),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object e) {
    return VirtCard(
      icon: Icons.error_outline,
      title: e is VirtErr ? e.title : libL10n.error,
      trailing: Btn.icon(
        text: libL10n.retry,
        icon: const Icon(Icons.refresh, size: 18),
        onTap: () => ref.invalidate(_provider),
      ),
      children: [
        if (e is VirtErr)
          if (e.detail case final d?) Text(d, style: UIs.text12Grey)
          else UIs.placeholder
        else
          Text('$e', style: UIs.text12Grey),
      ],
    );
  }
}

// --- Actions ---

extension _Actions on _VirtSnapshotsViewState {
  void _openForm(List<VirtGuestSnapshot> list) {
    var n = list.length + 1;
    while (list.any((s) => s.name == 'snap-$n')) {
      n++;
    }
    _name.text = 'snap-$n';
    _desc.clear();
    // ignore: invalid_use_of_protected_member
    setState(() {
      _memory = true;
      _creating = true;
    });
  }

  Future<void> _create(VirtSnapshotMemory memory) async {
    final name = _name.text.trim();
    final desc = _desc.text.trim();
    // ignore: invalid_use_of_protected_member
    setState(() => _creating = false);
    await _run(
      () => _notifier.createSnapshot(
        widget.guest.id,
        name: name,
        description: desc.isEmpty ? null : desc,
        memory: switch (memory) {
          VirtSnapshotMemory.none => false,
          VirtSnapshotMemory.optional => _memory,
          VirtSnapshotMemory.always => true,
        },
      ),
    );
  }

  /// Asks, in red when the guest will be stopped by it, with the choice to
  /// start it again.
  Future<void> _revert(VirtGuestSnapshot snap) async {
    final guest = widget.guest;
    final stops = !snap.withMemory && widget.state.isActive;
    var start = stops;
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: StatefulBuilder(
        builder: (context, setDialog) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.virtSnapshotRevertAsk(guest.name, snap.name)),
            if (stops) ...[
              UIs.height13,
              Text(
                l10n.virtSnapshotRevertStops(guest.name),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              CheckboxListTile(
                key: const ValueKey('snapshot:startAfter'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: start,
                title: Text(l10n.virtSnapshotStartAfter),
                onChanged: (v) => setDialog(() => start = v ?? false),
              ),
            ],
          ],
        ),
      ),
      actions: stops ? Btnx.cancelRedOk : Btnx.cancelOk,
    );
    if (ok != true || !mounted) return;
    await _run(
      () => _notifier.revertSnapshot(guest.id, snap.name, start: stops && start),
    );
  }

  Future<void> _delete(VirtGuestSnapshot snap) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(libL10n.askContinue('${libL10n.delete} ${snap.name}')),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    await _run(() => _notifier.deleteSnapshot(widget.guest.id, snap.name));
  }

  /// Runs [op], says what went wrong, and lists the snapshots again either
  /// way: a failed operation may have done half its work.
  Future<void> _run(Future<void> Function() op) async {
    try {
      await op();
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    } catch (e, s) {
      Loggers.app.warning('Virtualization snapshot', e, s);
      Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) ref.invalidate(_provider);
    }
  }
}
