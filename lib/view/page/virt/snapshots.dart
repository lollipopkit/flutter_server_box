part of 'hardware.dart';

/// A guest's snapshots: the tree, a new one, and reverting to or deleting
/// one — each asked first — with the disk chain the guest is on and what a
/// revert would change.
///
/// **The design's group** is what this draws, with the rows the Hardware,
/// Settings and Backup views draw theirs with: a group under a rule, its
/// count on the right and what reverting costs under it, the form a row
/// that opens in the group, each snapshot a row that opens to its own facts
/// and its actions. Two things the design has no place for are added,
/// because the app writes forms the design does not know about:
///
/// - the **disk chain** (libvirt), a group of its own: which file each disk
///   is on now, what backs it, and how deep the chain is. A guest on a chain
///   is one the app must be able to read back, which is what the rest of
///   this view is built around.
/// - the **configuration diff**, read from the snapshot and shown for a
///   revert (where the design shows the revert's own warning) and from the
///   row.
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

class _VirtSnapshotsViewState extends ConsumerState<VirtSnapshotsView>
    with _PaneRows<VirtSnapshotsView> {
  /// The new-snapshot form is open.
  bool _creating = false;
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _memory = true;

  VirtSnapshotForm _form = VirtSnapshotForm.internal;

  /// The pool an external snapshot's overlays go in; null: beside each disk.
  String? _pool;

  /// The diff read per snapshot, and which row asked for it.
  final _diffs = <String, AsyncValue<List<VirtSnapDiff>>>{};

  VirtHostNotifier get _notifier =>
      ref.read(virtHostProvider(widget.serverId).notifier);

  VirtSnapshotsProvider get _provider =>
      virtSnapshotsProvider(widget.serverId, widget.guest.id);

  VirtSnapChainProvider get _chainProvider =>
      virtSnapChainProvider(widget.serverId, widget.guest.id);

  VirtSnapshotRefusalProvider get _refusalProvider =>
      virtSnapshotRefusalProvider(widget.serverId, widget.guest.id);

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snaps = ref.watch(_provider);
    if (snaps.error case final e?) {
      return _buildError(e, onRetry: () => ref.invalidate(_provider));
    }
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
    return _buildGroups(
      [
        _snapshotGroup(list, chain?.value, busy),
        if (chain != null && list != null) _chainGroup(chain, list),
      ],
      // What the view shows besides the list is read on its own: the chain
      // and whether a snapshot can be taken, both of which the host can
      // change as much as the list.
      onRefresh: () {
        ref.invalidate(_chainProvider);
        ref.invalidate(_refusalProvider);
        return ref.refresh(_provider.future);
      },
    );
  }

  // --- Snapshots ---

  /// The count, what reverting costs, the form or the way to it, and the
  /// tree.
  _Group _snapshotGroup(
    List<VirtGuestSnapshot>? list,
    VirtSnapChain? chain,
    bool busy,
  ) {
    // Where the host says the guest cannot be snapshotted at all, the form is
    // not offered: the reason is said instead. libvirt's answer is the chain
    // this view already reads; PVE asks its own storage.
    final unsupported = widget.caps.snapshotExternal
        ? chain?.refusal
        : ref.watch(_refusalProvider).value;
    final current = list?.firstWhereOrNull((s) => s.current);
    return _Group(
      key: 'snapshots',
      title: l10n.virtSnapshots,
      right: list == null ? '' : l10n.virtSnapshotCount(list.length),
      warn: false,
      indexNote: current?.name ?? l10n.virtSnapshotNone,
      note: unsupported == null ? l10n.virtSnapshotRevertTip : null,
      rows: [
        if (list == null)
          const Padding(
            padding: EdgeInsets.all(27),
            child: Center(child: SizedLoading.medium),
          )
        else ...[
          if (unsupported != null)
            _callout(l10n.virtSnapshotNoSupport, unsupported)
          else if (_creating)
            ..._formRows(list, chain, busy)
          else
            _empty(
              // What a snapshot taken now keeps, as the design's empty row
              // says it, for the kind the form will open on.
              _defaultForm(list, chain) == VirtSnapshotForm.external
                  ? l10n.virtSnapshotExternalNoMemory
                  : switch (_memoryOf(VirtSnapshotForm.internal)) {
                      VirtSnapshotMemory.optional => l10n.virtSnapshotMemoryTip,
                      VirtSnapshotMemory.always => l10n.virtSnapshotMemoryAlways,
                      VirtSnapshotMemory.none =>
                        widget.guest.kind == VirtGuestKind.lxc
                            ? l10n.virtSnapshotDiskOnly
                            : l10n.virtSnapshotMemoryOff,
                    },
              l10n.virtSnapshotCreate,
              key: 'snapshot:new',
              onTap: busy ? null : () => _openForm(list),
            ),
          if (list.isEmpty)
            _text(l10n.virtSnapshotNone)
          else
            for (final (snap, depth) in virtSnapshotTree(list))
              ..._snapshotRows(snap, depth, list, busy),
        ],
      ],
    );
  }

  /// The kind the form opens on.
  ///
  /// A guest that already has an external snapshot keeps to that kind: an
  /// internal one on top of an overlay is a different kind of thing, and the
  /// chain it is on is one the next external snapshot deepens. A disk with a
  /// backing file and no snapshot (a thin clone of a base image) is not that:
  /// its first snapshot is internal, as on any other guest.
  VirtSnapshotForm _defaultForm(
    List<VirtGuestSnapshot> list,
    VirtSnapChain? chain,
  ) =>
      widget.caps.snapshotExternal &&
          chain != null &&
          chain.externalRefusal == null &&
          list.any((s) => s.external)
      ? VirtSnapshotForm.external
      : VirtSnapshotForm.internal;

  /// What the host keeps of the guest's memory for a snapshot of [form].
  ///
  /// An external snapshot is disk-only by definition (that is what keeps the
  /// guest running); an internal one is the user's where the host allows it.
  VirtSnapshotMemory _memoryOf(VirtSnapshotForm form) =>
      form == VirtSnapshotForm.external
      ? VirtSnapshotMemory.none
      : virtSnapshotMemory(widget.caps, widget.guest, widget.state);

  /// The design's "new snapshot" rows: the row that closes them, the name
  /// and description, the kind where the host has two, what the picked kind
  /// keeps, and the actions.
  List<Widget> _formRows(
    List<VirtGuestSnapshot> list,
    VirtSnapChain? chain,
    bool busy,
  ) {
    final external = _form == VirtSnapshotForm.external;
    final memory = _memoryOf(_form);
    final issue = virtSnapshotNameIssue(_name.text.trim(), list);
    final nameError = switch (issue) {
      VirtSnapshotNameIssue.invalid => l10n.virtSnapshotNameInvalid,
      VirtSnapshotNameIssue.taken => l10n.virtSnapshotNameTaken,
      VirtSnapshotNameIssue.empty || null => null,
    };
    // Said only of the internal kind: the external one's own line already
    // says it keeps no memory, and "the guest is not running" would be wrong
    // for a guest that is.
    final memoryNote = external
        ? null
        : switch (memory) {
            VirtSnapshotMemory.optional => l10n.virtSnapshotMemoryTip,
            VirtSnapshotMemory.always => l10n.virtSnapshotMemoryAlways,
            VirtSnapshotMemory.none =>
              widget.guest.kind == VirtGuestKind.lxc
                  ? null
                  : l10n.virtSnapshotMemoryOff,
          };
    final pools = chain?.pools ?? const <String>[];
    final externalRefusal = chain?.externalRefusal;
    void close() => setState(() => _creating = false);
    return [
      _disc(
        'snapshot:form',
        Icons.add_circle_outline,
        l10n.virtSnapshotCreate,
        libL10n.cancel,
        onTap: close,
      ),
      _inputRow([Input(
        key: const ValueKey('snapshot:name'),
        controller: _name,
        label: libL10n.name,
        icon: Icons.label_outline,
        noWrap: true,
        suggestion: false,
        errorText: nameError,
        onChanged: (_) => setState(() {}),
      )], indent: true),
      _inputRow([Input(
        key: const ValueKey('snapshot:desc'),
        controller: _desc,
        label: libL10n.description,
        icon: Icons.notes,
        noWrap: true,
        minLines: 1,
        maxLines: 3,
      )], indent: true),
      if (widget.caps.snapshotExternal) ...[
        // Each kind says what it is; the one refused says why instead.
        _choice([
          _Choice(
            key: 'snapshot:form:${VirtSnapshotForm.internal}',
            icon: Icons.save_outlined,
            label: l10n.virtSnapshotFormInternal,
            selected: !external,
            onTap: () => setState(() => _form = VirtSnapshotForm.internal),
          ),
          _Choice(
            key: 'snapshot:form:${VirtSnapshotForm.external}',
            icon: Icons.layers_outlined,
            label: l10n.virtSnapshotExternal,
            sub: externalRefusal ?? l10n.virtSnapshotExternalNoMemory,
            selected: external,
            onTap: externalRefusal != null
                ? null
                : () => setState(() => _form = VirtSnapshotForm.external),
          ),
        ], indent: true),
        if (external) ...[
          _text(l10n.virtSnapshotExternalTip, indent: true),
          // How deep the chain gets. The layers are counted as the files
          // under each disk, whatever put them there (a snapshot or a thin
          // clone of a base image): the new one goes on top either way.
          if (chain != null && chain.hasOverlays)
            _text(
              l10n.virtSnapshotExternalExists('${chain.depth}'),
              indent: true,
            ),
          if (pools.isNotEmpty) ...[
            _text(l10n.virtSnapshotOverlayPool, indent: true),
            _poolChoice(pools),
          ],
        ],
      ],
      if (memory != VirtSnapshotMemory.none)
        KeyedSubtree(
          key: const ValueKey('snapshot:memory'),
          child: _toggle(
            Icons.memory,
            l10n.virtSnapshotMemory,
            memory == VirtSnapshotMemory.always || _memory,
            key: 'snapshot:memory',
            note: memoryNote,
            indent: true,
            onChanged: memory == VirtSnapshotMemory.optional
                ? (v) => setState(() => _memory = v)
                : null,
          ),
        )
      else if (memoryNote != null)
        _text(memoryNote, indent: true),
      _actions([
        _Action(libL10n.cancel, icon: Icons.close, onTap: close),
        _Action(
          l10n.virtSnapshotCreate,
          key: 'snapshot:create',
          primary: true,
          onTap: issue != null || busy ? null : () => unawaited(_create(memory)),
        ),
      ], indent: true),
    ];
  }

  /// Where an external snapshot's overlays go: beside each disk (no
  /// `--diskspec`, libvirt's own placement), or a pool that holds files.
  Widget _poolChoice(List<String> pools) {
    final picked = pools.contains(_pool) ? _pool : null;
    return KeyedSubtree(
      key: const ValueKey('snapshot:pool'),
      child: _choice([
        _Choice(
          // A pool's name is never empty, so this key is no pool's.
          key: 'snapshot:pool:',
          icon: Icons.folder_copy_outlined,
          label: l10n.virtSnapshotOverlayBeside,
          selected: picked == null,
          onTap: () => setState(() => _pool = null),
        ),
        for (final p in pools)
          _Choice(
            key: 'snapshot:pool:$p',
            icon: Icons.storage_outlined,
            label: p,
            selected: p == picked,
            onTap: () => setState(() => _pool = p),
          ),
      ], indent: true),
    );
  }

  /// One snapshot: what it holds and when; open, where it came from, what a
  /// revert would change, and what can be done with it.
  List<Widget> _snapshotRows(
    VirtGuestSnapshot snap,
    int depth,
    List<VirtGuestSnapshot> all,
    bool busy,
  ) {
    final key = 'snapshot:${snap.name}';
    final when = snap.createdAt;
    final summary = [
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
    final revertRefused = snap.external && snap.hasChildren(all);
    // Depth by indent, capped so a long chain still has room for its name;
    // the rows it opens sit under it at the same depth.
    final inset = EdgeInsets.only(left: 13.0 * depth.clamp(0, 4));
    return [
      Padding(
        key: ValueKey(key),
        padding: inset,
        child: _disc(
          key,
          snap.withMemory ? Icons.memory : Icons.save_outlined,
          snap.name,
          summary,
          marked: snap.current,
          badge: snap.current ? VirtChip(libL10n.current) : null,
        ),
      ),
      Padding(
        padding: inset,
        child: _reveal(key, [
        if (when != null)
          _field(Icons.schedule, libL10n.time, when.simple(), indent: true),
        _field(
          Icons.account_tree_outlined,
          l10n.virtSnapshotParent,
          snap.parent ?? '--',
          indent: true,
        ),
        if (snap.description case final d?)
          _field(Icons.notes, libL10n.description, d, indent: true),
        for (final layer in snap.layers)
          if (layer.file case final file?)
            _field(
              Icons.layers_outlined,
              '${l10n.virtSnapshotChain} · ${layer.target}',
              file,
              mono: true,
              indent: true,
            ),
        if (stops)
          _text(l10n.virtSnapshotRevertStops(widget.guest.name), indent: true),
        if (revertRefused)
          _text(l10n.virtSnapshotRevertHasChildren, indent: true, error: true)
        else if (snap.external)
          _text(l10n.virtSnapshotRevertChain, indent: true),
        if (_diffs[snap.name] case final diff?)
          _box(indent: true, child: _buildDiff(diff)),
        _actions([
          _Action(
            l10n.virtSnapshotDiffShow,
            key: 'snapshot:diff:${snap.name}',
            icon: Icons.difference_outlined,
            onTap: () => unawaited(_readDiff(snap)),
          ),
          _Action(
            libL10n.delete,
            key: 'snapshot:delete:${snap.name}',
            icon: Icons.delete_outline,
            danger: true,
            onTap: busy ? null : () => unawaited(_delete(snap)),
          ),
          _Action(
            l10n.virtSnapshotRevert,
            key: 'snapshot:revert:${snap.name}',
            primary: true,
            onTap: busy || revertRefused
                ? null
                : () => unawaited(_revert(snap)),
          ),
        ], indent: true),
        ]),
      ),
    ];
  }

  /// What differs between the snapshot and the guest now, grouped the way the
  /// design groups a view's rows.
  Widget _buildDiff(AsyncValue<List<VirtSnapDiff>> diff) {
    return switch (diff) {
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
                if (d.group == group) VirtFact(d.key, _diffLine(d)),
            ],
        ],
      ),
      AsyncError(:final error) => Text(
        l10n.virtSnapshotDiffHost('$error'),
        style: UIs.text12Grey,
      ),
      _ => const Center(child: SizedLoading.small),
    };
  }

  String _diffLine(VirtSnapDiff d) {
    if (d.removed) return '${d.before} · ${l10n.virtSnapshotDiffRemoved}';
    if (d.added) return '${d.after} · ${l10n.virtSnapshotDiffAdded}';
    return l10n.virtSnapshotDiffValue(d.before ?? '--', d.after ?? '--');
  }

  // --- Chain ---

  /// The design has no chain group; a guest on one needs it, so it is a group
  /// of its own: each disk, and the files it is on, topmost first.
  _Group _chainGroup(
    AsyncValue<VirtSnapChain> chain,
    List<VirtGuestSnapshot> list,
  ) {
    final value = chain.value;
    final depth = value == null || !value.hasOverlays
        ? ''
        : l10n.virtSnapshotChainDepth('${value.depth}');
    return _Group(
      key: 'chain',
      title: l10n.virtSnapshotChain,
      right: depth,
      warn: false,
      indexNote: depth,
      rows: [
        if (chain.error case final e?) ...[
          _text(e is VirtErr ? (e.detail ?? e.title) : '$e', error: true),
          _actions([
            _Action(
              libL10n.retry,
              icon: Icons.refresh,
              onTap: () => ref.invalidate(_chainProvider),
            ),
          ]),
        ] else if (value == null)
          const Center(child: SizedLoading.small)
        else ...[
          for (final d in value.disks) _chainDisk(d),
          // A refusal of every snapshot is said in the snapshot group; here
          // only what refuses the external kind alone.
          if (value.refusal == null && value.externalRefusal != null)
            _text(value.externalRefusal!, error: true),
          // The revert rule is about external snapshots, not about any file
          // with a backing one: a thin clone of a base image is on two
          // layers without a snapshot to revert to.
          _text(
            list.any((s) => s.external)
                ? l10n.virtSnapshotRevertChain
                : l10n.virtSnapshotExternalTip,
          ),
        ],
      ],
    );
  }

  Widget _chainDisk(VirtSnapChainDisk d) {
    return _box(
      key: ValueKey('chain:disk:${d.target}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _icon(Icons.storage),
              UIs.width13,
              Expanded(
                child: Text(
                  [d.target, ?d.pool].join(' · '),
                  style: UIs.text13.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (d.error case final e?)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 3),
              child: Text(e, style: UIs.text12Grey),
            ),
          for (var i = 0; i < d.files.length; i++)
            _chainFile(d.files[i], last: i == d.files.length - 1),
        ],
      ),
    );
  }

  /// One layer: the top one is what the guest writes to, the last is the
  /// base image, indented under the rest.
  Widget _chainFile(VirtSnapChainFile f, {required bool last}) {
    final scheme = Theme.of(context).colorScheme;
    final label = switch (true) {
      _ when f.active => l10n.virtSnapshotChainActive,
      _ when last => l10n.virtSnapshotChainBase,
      _ => f.snap ?? l10n.virtSnapshotChainFile,
    };
    return Padding(
      key: ValueKey('chain:${f.path}'),
      padding: EdgeInsets.only(left: 32.0 + (last ? 13 : 0), top: 5),
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
}

// --- Actions ---

extension _SnapshotActions on _VirtSnapshotsViewState {
  // ignore: invalid_use_of_protected_member
  void _setState(VoidCallback fn) => setState(fn);

  void _openForm(List<VirtGuestSnapshot> list) {
    var n = list.length + 1;
    while (list.any((s) => s.name == 'snap-$n')) {
      n++;
    }
    _name.text = 'snap-$n';
    _desc.clear();
    final chain = ref.read(_chainProvider).value;
    _setState(() {
      _memory = true;
      _creating = true;
      _form = _defaultForm(list, chain);
    });
  }

  Future<void> _create(VirtSnapshotMemory memory) async {
    final name = _name.text.trim();
    final desc = _desc.text.trim();
    _setState(() => _creating = false);
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
        ref.invalidate(_refusalProvider);
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
