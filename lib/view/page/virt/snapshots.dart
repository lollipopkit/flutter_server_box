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
/// one — each asked first — with the disk chain the guest is on and what a
/// revert would change.
///
/// **The design's group** is what this draws: a group under a rule, its
/// count and where the snapshots live on the right, each snapshot a row that
/// opens to its own facts and its actions. Two things the design has no
/// place for are added, because the app writes forms the design does not
/// know about:
///
/// - the **disk chain** (libvirt external snapshots): which file the guest
///   writes to now, what backs it, and how deep the chain is. A guest on a
///   chain is one the app must be able to read back, which is what the rest
///   of this view is built around.
/// - the **configuration diff**, read from the snapshot and shown for a
///   revert (where the design shows the revert's own warning) and from the
///   list.
///
/// Reverting is asked in red when it loses more than changes: a snapshot
/// without memory stops a guest that is running, the dialog offers to start
/// it again, and a revert that a chain makes unsafe is refused before it is
/// asked for.
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

  /// The design's "新快照" row: the form is a row of the group, opened by the
  /// empty row or the bar's button.
  VirtSnapshotForm _form = VirtSnapshotForm.internal;

  /// The pool an external snapshot's overlays go in; null: beside each disk.
  String? _pool;

  /// Open rows, by snapshot name.
  final _open = <String>{};

  /// The diff read per snapshot, and which row asked for it.
  final _diffs = <String, AsyncValue<List<VirtSnapDiff>>>{};

  VirtHostNotifier get _notifier =>
      ref.read(virtHostProvider(widget.serverId).notifier);

  VirtSnapshotsProvider get _provider =>
      virtSnapshotsProvider(widget.serverId, widget.guest.id);

  VirtSnapChainProvider get _chainProvider =>
      virtSnapChainProvider(widget.serverId, widget.guest.id);

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
    // The chain is read only where the host writes one, and its own provider
    // is not watched until then: a read that fails must not take the whole
    // view with it.
    final chain = widget.caps.snapshotExternal
        ? ref.watch(_chainProvider)
        : null;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(_provider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(13, 0, 13, 17),
        children: [
          _buildHead(list, busy),
          if (snaps.error case final e?)
            _buildError(e, () => ref.invalidate(_provider))
          else if (list == null)
            const Padding(
              padding: EdgeInsets.all(27),
              child: Center(child: SizedLoading.medium),
            )
          else ...[
            if (chain != null) _buildChain(chain),
            if (list.isEmpty)
              CenterGreyTitle(l10n.virtSnapshotNone)
            else
              CardX(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    children: [
                      for (final (snap, depth) in virtSnapshotTree(list))
                        _buildRow(snap, depth, list, busy),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// The count, what reverting costs, and the way to a new one.
  Widget _buildHead(List<VirtGuestSnapshot>? list, bool busy) {
    // Where the host says the guest cannot be snapshotted at all, the form is
    // not offered: the reason is said instead. libvirt's answer is the chain
    // this view already reads; PVE asks its own storage.
    final unsupported = widget.caps.snapshotExternal
        ? ref.watch(_chainProvider).value?.refusal
        : ref
              .watch(
                virtSnapshotRefusalProvider(widget.serverId, widget.guest.id),
              )
              .value;
    return VirtCard(
      icon: Icons.history,
      title: list == null
          ? l10n.virtSnapshots
          : '${l10n.virtSnapshots} · ${list.length}',
      trailing: _creating || unsupported != null
          ? null
          : Btn.icon(
              key: const ValueKey('snapshot:new'),
              text: l10n.virtSnapshotCreate,
              icon: const Icon(Icons.add, size: 18),
              onTap: busy || list == null ? null : () => _openForm(list),
            ),
      children: [
        if (unsupported != null)
          Text(
            '${l10n.virtSnapshotNoSupport}\n$unsupported',
            style: UIs.text12Grey,
          )
        else
          Text(l10n.virtSnapshotRevertTip, style: UIs.text12Grey),
        if (_creating && list != null && unsupported == null)
          ..._buildForm(list, busy),
      ],
    );
  }

  List<Widget> _buildForm(List<VirtGuestSnapshot> list, bool busy) {
    final external = _form == VirtSnapshotForm.external;
    // Memory is the user's where the host allows it; an external snapshot is
    // disk-only by definition (that is what keeps the guest running).
    final memory = external
        ? VirtSnapshotMemory.none
        : virtSnapshotMemory(widget.caps, widget.guest, widget.state);
    final issue = virtSnapshotNameIssue(_name.text.trim(), list);
    final nameError = switch (issue) {
      VirtSnapshotNameIssue.invalid => l10n.virtSnapshotNameInvalid,
      VirtSnapshotNameIssue.taken => l10n.virtSnapshotNameTaken,
      VirtSnapshotNameIssue.empty || null => null,
    };
    final memoryNote = switch (memory) {
      VirtSnapshotMemory.optional => l10n.virtSnapshotMemoryTip,
      VirtSnapshotMemory.always => l10n.virtSnapshotMemoryAlways,
      VirtSnapshotMemory.none => widget.guest.kind == VirtGuestKind.lxc
          ? null
          : l10n.virtSnapshotMemoryOff,
    };
    final chain = ref.watch(_chainProvider).value;
    final pools = chain?.pools ?? const <String>[];
    final externalRefusal = chain?.externalRefusal;
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
      if (widget.caps.snapshotExternal) ...[
        UIs.height13,
        _segmented(
          l10n.virtSnapshotForm,
          {
            VirtSnapshotForm.internal: l10n.virtSnapshotFormInternal,
            VirtSnapshotForm.external: l10n.virtSnapshotExternal,
          },
          _form,
          (v) => setState(() => _form = v),
          disabled: {
            if (externalRefusal != null) VirtSnapshotForm.external,
          },
        ),
        if (externalRefusal != null) ...[
          UIs.height7,
          Text(
            externalRefusal,
            style: const TextStyle(fontSize: 12, color: StatePalette.warn),
          ),
        ],
        UIs.height7,
        Text(
          external
              ? l10n.virtSnapshotExternalTip
              : l10n.virtSnapshotExternalNoMemory,
          style: UIs.text12Grey,
        ),
        // Which file the guest ends up on, and where the new layer goes.
        if (external && chain != null && chain.hasOverlays) ...[
          UIs.height7,
          Text(
            l10n.virtSnapshotExternalExists('${chain.depth}'),
            style: UIs.text12Grey,
          ),
        ],
        if (external && pools.isNotEmpty) ...[
          UIs.height7,
          _poolPicker(pools),
        ],
      ],
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

  /// The design's segmented choice, as the rest of the tab draws one.
  Widget _segmented<T>(
    String label,
    Map<T, String> options,
    T current,
    ValueChanged<T> onPick, {
    Set<T> disabled = const {},
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: UIs.text12Grey),
        UIs.height7,
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final e in options.entries)
              ChoiceChip(
                key: ValueKey('snapshot:form:${e.key}'),
                label: Text(e.value, style: UIs.text12),
                selected: e.key == current,
                onSelected: disabled.contains(e.key)
                    ? null
                    : (_) => onPick(e.key),
              ),
          ],
        ),
      ],
    );
  }

  /// Where an external snapshot's overlays go: beside each disk (no
  /// `--diskspec`, libvirt's own placement), or a pool that holds files.
  Widget _poolPicker(List<String> pools) {
    return Row(
      children: [
        Text(l10n.virtSnapshotOverlayPool, style: UIs.text12Grey),
        UIs.width7,
        Expanded(
          child: DropdownButton<String?>(
            key: const ValueKey('snapshot:pool'),
            value: pools.contains(_pool) ? _pool : null,
            isExpanded: true,
            style: UIs.text13,
            items: [
              DropdownMenuItem(
                child: Text(l10n.virtSnapshotOverlayBeside, style: UIs.text13),
              ),
              for (final p in pools)
                DropdownMenuItem(value: p, child: Text(p, style: UIs.text13)),
            ],
            onChanged: (v) => setState(() => _pool = v),
          ),
        ),
      ],
    );
  }

  /// The design has no chain group; a guest on one needs it, so it is drawn
  /// the way the design draws a device: a row that opens.
  Widget _buildChain(AsyncValue<VirtSnapChain> chain) {
    final value = chain.value;
    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: VirtCard(
        icon: Icons.account_tree_outlined,
        title: l10n.virtSnapshotChain,
        trailing: value == null || !value.hasOverlays
            ? null
            : VirtChip(l10n.virtSnapshotChainDepth('${value.depth}')),
        children: [
          if (chain.error case final e?)
            Row(
              children: [
                Expanded(
                  child: Text(
                    e is VirtErr ? (e.detail ?? e.title) : '$e',
                    style: UIs.text12Grey,
                  ),
                ),
                Btn.icon(
                  text: libL10n.retry,
                  icon: const Icon(Icons.refresh, size: 18),
                  onTap: () => ref.invalidate(_chainProvider),
                ),
              ],
            )
          else if (value == null)
            const Center(child: SizedLoading.small)
          else ...[
            for (final d in value.disks) _buildChainDisk(d),
            // A refusal of every snapshot is said at the top of the view; here
            // only what refuses the external kind alone.
            if (value.refusal == null && value.externalRefusal != null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  value.externalRefusal!,
                  style: const TextStyle(fontSize: 12, color: StatePalette.warn),
                ),
              ),
            Text(
              value.hasOverlays
                  ? l10n.virtSnapshotRevertChain
                  : l10n.virtSnapshotExternalTip,
              style: UIs.text12Grey,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChainDisk(VirtSnapChainDisk d) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.storage, size: 15, color: scheme.onSurfaceVariant),
              UIs.width7,
              Expanded(
                child: Text(
                  [d.target, ?d.pool].join(' · '),
                  style: UIs.text12Bold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          for (var i = 0; i < d.files.length; i++)
            _buildChainFile(d.files[i], last: i == d.files.length - 1),
        ],
      ),
    );
  }

  /// One layer, indented by depth, the way the snapshot tree is: the top one
  /// is what the guest writes to, the last is the base image.
  Widget _buildChainFile(VirtSnapChainFile f, {required bool last}) {
    final scheme = Theme.of(context).colorScheme;
    final label = switch (true) {
      _ when f.active => l10n.virtSnapshotChainActive,
      _ when last => l10n.virtSnapshotChainBase,
      _ => f.snap ?? l10n.virtSnapshotChainFile,
    };
    return Padding(
      key: ValueKey('chain:${f.path}'),
      padding: EdgeInsets.only(left: 13.0 * (last ? 1 : 0), top: 3),
      child: Row(
        children: [
          Icon(
            last ? Icons.crop_square : Icons.layers_outlined,
            size: 13,
            color: f.active ? scheme.primary : scheme.onSurfaceVariant,
          ),
          UIs.width7,
          Expanded(
            child: Text(
              f.name,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: f.active ? scheme.primary : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          UIs.width7,
          VirtChip(label),
          if (f.allocation case final bytes?) ...[
            UIs.width7,
            Text(bytes.bytes2Str, style: UIs.text11Grey),
          ],
        ],
      ),
    );
  }

  /// One snapshot: what it holds and when; open, where it came from, what a
  /// revert would change, and what can be done with it.
  Widget _buildRow(
    VirtGuestSnapshot snap,
    int depth,
    List<VirtGuestSnapshot> all,
    bool busy,
  ) {
    final open = _open.contains(snap.name);
    final scheme = Theme.of(context).colorScheme;
    final when = snap.createdAt;
    final sub = [
      if (when != null) when.simple(),
      snap.withMemory ? l10n.virtSnapshotWithMemory : l10n.virtSnapshotDiskOnly,
      if (snap.external) l10n.virtSnapshotExternal,
    ].join(' · ');
    // Without memory, a revert leaves the guest stopped: worth saying before
    // the button, not only in the dialog.
    final stops = !snap.withMemory && widget.state.isActive;
    // On a chain, only a leaf can be reverted to: libvirt's revert flattens
    // the chain and leaves every later snapshot pointing at a file that is
    // gone (see `sbm_parser::virt_snapshot`).
    final hasChildren = snap.hasChildren(all);
    final revertRefused = snap.external && hasChildren;
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
                if (snap.current) ...[UIs.width7, VirtChip(libL10n.current)],
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
                    for (final layer in snap.layers)
                      if (layer.file case final file?)
                        VirtFact(
                          '${l10n.virtSnapshotChain} · ${layer.target}',
                          file,
                        ),
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
                    if (revertRefused)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          l10n.virtSnapshotRevertHasChildren,
                          style: const TextStyle(
                            fontSize: 12,
                            color: StatePalette.warn,
                          ),
                        ),
                      )
                    else if (snap.external)
                      Text(
                        l10n.virtSnapshotRevertChain,
                        style: UIs.text11Grey,
                      ),
                    if (_diffs[snap.name] case final diff?) _buildDiff(diff),
                    UIs.height7,
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        TextButton.icon(
                          key: ValueKey('snapshot:diff:${snap.name}'),
                          onPressed: () => unawaited(_readDiff(snap)),
                          icon: const Icon(Icons.difference_outlined, size: 18),
                          label: Text(l10n.virtSnapshotDiffShow),
                        ),
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
                          onPressed: busy || revertRefused
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

  /// What differs between the snapshot and the guest now, grouped the way the
  /// design groups a view's rows.
  Widget _buildDiff(AsyncValue<List<VirtSnapDiff>> diff) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: switch (diff) {
        AsyncData(:final value) when value.isEmpty => Text(
          l10n.virtSnapshotDiffNone,
          style: UIs.text12Grey,
        ),
        AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.virtSnapshotDiff, style: UIs.text12Bold),
            for (final group in VirtSnapDiffGroup.values)
              if (value.any((d) => d.group == group)) ...[
                UIs.height7,
                Text(group.label, style: UIs.text11Grey),
                for (final d in value)
                  if (d.group == group) _buildDiffRow(d),
              ],
          ],
        ),
        AsyncError(:final error) => Text(
          l10n.virtSnapshotDiffHost('$error'),
          style: UIs.text12Grey,
        ),
        _ => const Center(child: SizedLoading.small),
      },
    );
  }

  Widget _buildDiffRow(VirtSnapDiff d) {
    final value = switch (d) {
      _ when d.removed => '${d.before} · ${l10n.virtSnapshotDiffRemoved}',
      _ when d.added => '${d.after} · ${l10n.virtSnapshotDiffAdded}',
      _ => l10n.virtSnapshotDiffValue(d.before ?? '--', d.after ?? '--'),
    };
    return VirtFact(d.key, value);
  }

  Widget _buildError(Object e, VoidCallback onRetry) {
    return VirtCard(
      icon: Icons.error_outline,
      title: e is VirtErr ? e.title : libL10n.error,
      trailing: Btn.icon(
        text: libL10n.retry,
        icon: const Icon(Icons.refresh, size: 18),
        onTap: onRetry,
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
  // ignore: invalid_use_of_protected_member
  void _setState(VoidCallback fn) => setState(fn);

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
      // A guest already on a chain keeps it: a second snapshot deepens it,
      // and an internal one on a chain would be a different kind of thing.
      final chain = ref.read(_chainProvider).value;
      _form =
          widget.caps.snapshotExternal &&
              chain != null &&
              chain.hasOverlays &&
              chain.externalRefusal == null
          ? VirtSnapshotForm.external
          : VirtSnapshotForm.internal;
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
        form: _form,
        // What the picker shows: a pool gone from the list is "beside each
        // disk", not a name the host no longer has.
        overlayPool:
            _form == VirtSnapshotForm.external &&
                (ref.read(_chainProvider).value?.pools.contains(_pool) ?? false)
            ? _pool
            : null,
        memory: switch (memory) {
          VirtSnapshotMemory.none => false,
          VirtSnapshotMemory.optional => _memory,
          VirtSnapshotMemory.always => true,
        },
      ),
    );
  }

  /// Reads what differs between [snap] and the guest now, and holds it for
  /// the row. Read again on every press: the guest changes under it.
  Future<void> _readDiff(VirtGuestSnapshot snap) async {
    void put(AsyncValue<List<VirtSnapDiff>> v) {
      if (mounted) _setState(() => _diffs[snap.name] = v);
    }

    put(const AsyncLoading());
    try {
      final diff = await _notifier.snapshotDiff(widget.guest.id, snap.name);
      put(AsyncData(diff));
    } on VirtErr catch (e, s) {
      put(AsyncError(e, s));
    } catch (e, s) {
      Loggers.app.warning('Virtualization snapshot diff', e, s);
      put(AsyncError(e, s));
    }
  }

  /// Asks, in red when the guest will be stopped by it, with the choice to
  /// start it again, and with what the revert would change read first.
  Future<void> _revert(VirtGuestSnapshot snap) async {
    final guest = widget.guest;
    final stops = !snap.withMemory && widget.state.isActive;
    var start = stops;
    // The design shows the revert with what it changes; a read that fails is
    // shown in the dialog rather than holding the revert up.
    final diff = await _notifier
        .snapshotDiff(guest.id, snap.name)
        .then<Object>((d) => d)
        .catchError((Object e) => e);
    if (!mounted) return;
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: StatefulBuilder(
        builder: (context, setDialog) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.virtSnapshotRevertAsk(guest.name, snap.name)),
              if (diff is List<VirtSnapDiff>) ...[
                UIs.height13,
                if (diff.isEmpty)
                  Text(l10n.virtSnapshotDiffNone, style: UIs.text12Grey)
                else ...[
                  Text(
                    l10n.virtSnapshotDiffAsk(snap.name),
                    style: UIs.text12Bold,
                  ),
                  UIs.height7,
                  for (final d in diff)
                    Text(
                      '${d.key}: ${_diffLine(d)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ] else ...[
                UIs.height13,
                Text(
                  l10n.virtSnapshotDiffHost('$diff'),
                  style: UIs.text12Grey,
                ),
              ],
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
      ),
      actions: stops ? Btnx.cancelRedOk : Btnx.cancelOk,
    );
    if (ok != true || !mounted) return;
    await _run(
      () => _notifier.revertSnapshot(guest.id, snap.name, start: stops && start),
    );
  }

  String _diffLine(VirtSnapDiff d) {
    if (d.removed) return '${d.before} · ${l10n.virtSnapshotDiffRemoved}';
    if (d.added) return '${d.after} · ${l10n.virtSnapshotDiffAdded}';
    return l10n.virtSnapshotDiffValue(d.before ?? '--', d.after ?? '--');
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
  /// way: a failed operation may have done half its work. The chain is read
  /// again too — a snapshot is what puts a guest on one.
  Future<void> _run(Future<void> Function() op) async {
    try {
      await op();
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    } catch (e, s) {
      Loggers.app.warning('Virtualization snapshot', e, s);
      Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) {
        ref.invalidate(_provider);
        ref.invalidate(_chainProvider);
        ref.invalidate(
          virtSnapshotRefusalProvider(widget.serverId, widget.guest.id),
        );
      }
    }
  }
}

extension on VirtSnapDiffGroup {
  String get label => switch (this) {
    VirtSnapDiffGroup.cpu => l10n.virtSnapshotDiffGroupCpu,
    VirtSnapDiffGroup.memory => l10n.virtSnapshotDiffGroupMemory,
    VirtSnapDiffGroup.disks => l10n.virtSnapshotDiffGroupDisks,
    VirtSnapDiffGroup.nics => l10n.virtSnapshotDiffGroupNic,
    VirtSnapDiffGroup.firmware => l10n.virtSnapshotDiffGroupFirmware,
    VirtSnapDiffGroup.boot => l10n.virtSnapshotDiffGroupBoot,
    VirtSnapDiffGroup.other => l10n.virtSnapshotDiffGroupOther,
  };
}
