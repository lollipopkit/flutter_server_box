part of 'hardware.dart';

/// One storage pool — the design's pool view: how full it is, what it is,
/// its volumes with the guests using them, and what can be done to it.
///
/// Managed where the host allows (`VirtCapabilities.storageEdit` and the
/// flags beside it): a new volume, a volume grown, copied, attached to a
/// guest (a disk) or inserted into one (an ISO), deleted; a file uploaded
/// from this device; the pool stopped, started, marked to start with the
/// host, removed. What a guest uses cannot be deleted, and a pool with a
/// volume in use cannot be stopped or removed — refused here before the host
/// is asked.
class VirtPoolView extends ConsumerStatefulWidget {
  const VirtPoolView({
    super.key,
    required this.serverId,
    required this.poolId,
    this.leading,
    this.onSwitch,
    this.onDeleted,
  });

  final String serverId;
  final String poolId;
  final Widget? leading;

  /// Moves to another pool in place; null where the list is beside this.
  final ValueChanged<String>? onSwitch;

  /// The pool was removed: whatever showed it closes it.
  final VoidCallback? onDeleted;

  @override
  ConsumerState<VirtPoolView> createState() => _VirtPoolViewState();
}

class _VirtPoolViewState extends ConsumerState<VirtPoolView>
    with _PaneRows<VirtPoolView> {
  String get _serverId => widget.serverId;

  VirtHostNotifier get _notifier =>
      ref.read(virtHostProvider(_serverId).notifier);

  /// The new volume form is open.
  var _adding = false;
  final _volName = TextEditingController();
  String? _volFormat;
  int _volGib = 20;

  /// Grown sizes not saved yet, by volume.
  final _grow = <String, int>{};

  /// The guest picked for each volume's attach or insert, by volume.
  final _target = <String, String>{};

  /// A volume's own change (attach, insert) is running, by volume.
  final _working = <String>{};

  @override
  void dispose() {
    _volName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pools = ref.watch(virtStoragePoolsProvider(_serverId));
    final all = pools.value ?? const <VirtStoragePool>[];
    final pool = all.firstWhereOrNull((p) => p.id == widget.poolId);
    final host = ref.watch(virtHostProvider(_serverId));
    final caps = host.data?.capabilities ?? const VirtCapabilities();
    final at = pool == null ? -1 : all.indexOf(pool);
    final onSwitch = widget.onSwitch;
    final busy = pool != null && host.resourceOps.contains('pool:${pool.id}');
    final uploading = pool == null ? null : host.uploads[pool.id];
    final bar = virtResourceBar(
      name: pool?.name ?? '',
      icon: Icons.storage_outlined,
      leading: widget.leading,
      position: onSwitch != null && at >= 0 ? at + 1 : null,
      total: onSwitch != null ? all.length : 0,
      onSwitch: onSwitch != null && all.length > 1
          ? () => unawaited(_pick(all, onSwitch))
          : null,
      actions: [
        if (pool != null && pool.active && caps.storageEdit)
          Btn.icon(
            key: const ValueKey('pool:vol:new'),
            text: l10n.virtVolNew,
            icon: const Icon(Icons.add, size: 18),
            onTap: busy ? null : () => _openNew(pool),
          ),
        if (pool != null && caps.upload && virtPoolTakesMedia(pool))
          Btn.icon(
            key: const ValueKey('pool:upload'),
            text: l10n.virtUploadIso,
            icon: const Icon(Icons.upload, size: 18),
            onTap: uploading != null ? null : () => unawaited(_upload(pool)),
          ),
      ],
      // libvirt reads the pool again (files put there by other means
      // appear); PVE reads it on every listing anyway.
      onRefresh: () => pool != null && pool.active && caps.storageEdit
          ? unawaited(_manage(VirtPoolRefresh(pool), quiet: true))
          : ref.invalidate(virtStoragePoolsProvider(_serverId)),
    );
    if (pool == null) {
      return Scaffold(
        appBar: bar,
        body: pools.isLoading
            ? const Center(child: SizedLoading.medium)
            : pools.hasError
            ? ListView(
                padding: const EdgeInsets.all(13),
                children: [VirtErrCard(pools.error!)],
              )
            : EmptyPane(icon: Icons.storage_outlined, label: libL10n.empty),
      );
    }
    final vols = ref.watch(virtVolumesProvider(_serverId, pool.id));
    final list = vols.value ?? const <VirtVolume>[];
    return Scaffold(
      appBar: bar,
      body: Column(
        children: [
          SizedBox(
            height: 3,
            child: pools.isLoading || vols.isLoading || busy
                ? const ProgressLine()
                : null,
          ),
          Expanded(
            child: _buildGroups(
              [
                _usageGroup(pool),
                _infoGroup(pool, caps, busy),
                _volumesGroup(pool, vols, host, caps, busy),
                if (caps.storageEdit) _opsGroup(pool, list, host, caps, busy),
              ],
              onRefresh: () =>
                  ref.refresh(virtStoragePoolsProvider(_serverId).future),
            ),
          ),
        ],
      ),
    );
  }

  bool get _pve => ref.read(virtHostProvider(_serverId)).kind == VirtHostKind.pve;

  /// The guests [v] is really in use by: every libvirt one (a domain by
  /// UUID), and a PVE owner that exists — a volume whose VMID has no guest
  /// is left over, not in use.
  List<VirtGuestRef> _users(VirtHostState host, VirtVolume v) => [
    for (final u in v.users)
      if (u.guestId != null || virtGuestOf(host, u) != null) u,
  ];

  // --- Usage ---

  _Group _usageGroup(VirtStoragePool pool) {
    final frac = pool.usedFraction;
    final cap = pool.capacity;
    return _Group(
      key: 'usage',
      title: libL10n.capacity,
      right: pool.active ? libL10n.active : libL10n.inactive,
      warn: !pool.active,
      indexNote: frac == null
          ? '--'
          : l10n.virtPoolUsedPct((frac * 100).toStringAsFixed(1)),
      dot: !pool.active
          ? StatePalette.idle
          : (frac ?? 0) > 0.85
          ? StatePalette.warn
          : StatePalette.running,
      rows: [
        _meter(
          Icons.storage_outlined,
          libL10n.used,
          cap == null ? '--' : '${(pool.used ?? 0).bytes2Str} / ${cap.bytes2Str}',
          frac,
          note: switch (pool.available) {
            final a? => l10n.virtHwFree(a.bytes2Str),
            null => null,
          },
        ),
      ],
    );
  }

  // --- What it is ---

  _Group _infoGroup(VirtStoragePool pool, VirtCapabilities caps, bool busy) {
    final where = pool.path ?? pool.source;
    return _Group(
      key: 'info',
      title: _pve ? libL10n.storage : l10n.virtPool,
      right: '',
      warn: false,
      indexNote: [pool.type, ?where].join(' · '),
      rows: [
        _field(Icons.category_outlined, libL10n.type, pool.type.isEmpty ? '--' : pool.type),
        if (pool.node case final n?) _field(Icons.dns_outlined, libL10n.node, n),
        if (pool.path case final p?)
          _field(Icons.folder_outlined, _pve ? libL10n.location : libL10n.path, p, mono: true),
        if (pool.source case final s? when s != pool.path)
          _field(Icons.lan_outlined, libL10n.source, s, mono: true),
        if (pool.content.isNotEmpty)
          _field(Icons.inventory_2_outlined, libL10n.content, pool.content.join(', ')),
        if (pool.shared ?? false) _text(l10n.virtShared),
        if (caps.poolAutostart)
          _toggle(
            Icons.power_settings_new,
            l10n.virtHwAutostart,
            pool.autostart ?? false,
            key: 'pool:autostart',
            onChanged: busy
                ? null
                : (on) => unawaited(_manage(VirtPoolSetAutostart(pool, on: on))),
          ),
      ],
    );
  }

  // --- Volumes ---

  _Group _volumesGroup(
    VirtStoragePool pool,
    AsyncValue<List<VirtVolume>> vols,
    VirtHostState host,
    VirtCapabilities caps,
    bool busy,
  ) {
    final list = vols.value;
    final upload = host.uploads[pool.id];
    final media = virtPoolTakesMedia(pool) && caps.upload;
    return _Group(
      key: 'vols',
      title: l10n.virtVolumes,
      right: list == null ? '' : '${list.length}',
      warn: false,
      indexNote: list == null ? '--' : l10n.virtVolCount(list.length),
      rows: [
        if (upload != null) _uploadRow(pool, upload),
        if (_adding && caps.storageEdit)
          ..._newVolumeRows(pool, list ?? const [], busy)
        else if (pool.active && caps.storageEdit)
          _empty(
            media ? l10n.virtVolEmptyUpload : l10n.virtVolEmptyAttach,
            l10n.virtVolNew,
            key: 'pool:vol:new:empty',
            onTap: busy ? null : () => _openNew(pool),
          ),
        if (!pool.active)
          _text(l10n.virtPoolInactive)
        else if (vols.hasError)
          VirtErrCard(
            vols.error!,
            onRetry: () =>
                ref.refresh(virtVolumesProvider(_serverId, pool.id).future),
          )
        else if (list == null)
          const Padding(
            padding: EdgeInsets.all(13),
            child: Center(child: SizedLoading.small),
          )
        else if (list.isEmpty)
          _text(l10n.virtVolNone)
        else
          for (final v in list) ..._volumeRows(pool, v, host, caps, busy),
      ],
    );
  }

  Widget _uploadRow(VirtStoragePool pool, VirtUploadProgress p) {
    return _box(
      key: const ValueKey('pool:upload:progress'),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(13, 7, 5, 9),
      child: Row(
        children: [
          _icon(Icons.upload, color: Theme.of(context).colorScheme.primary),
          UIs.width13,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UIs.text13.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 5),
                ProgressLine(value: p.fraction),
                const SizedBox(height: 3),
                Text(
                  '${p.sent.bytes2Str} / ${p.size.bytes2Str} · '
                  '${(p.fraction * 100).toStringAsFixed(0)}%',
                  style: UIs.text11Grey,
                ),
              ],
            ),
          ),
          Btn.icon(
            key: const ValueKey('pool:upload:cancel'),
            text: libL10n.cancel,
            icon: const Icon(Icons.close, size: 18),
            onTap: () => _notifier.cancelUpload(pool.id),
          ),
        ],
      ),
    );
  }

  List<Widget> _newVolumeRows(
    VirtStoragePool pool,
    List<VirtVolume> vols,
    bool busy,
  ) {
    final formats = virtVolumeFormats(pool);
    final format = formats.contains(_volFormat) ? _volFormat! : formats.first;
    final change = VirtVolumeCreate(
      pool,
      name: _volName.text.trim(),
      gib: _volGib,
      format: format,
    );
    final issue = _volName.text.isEmpty
        ? null
        : _issueText(
            virtResourceIssue(
              change,
              host: _pve ? VirtHostKind.pve : VirtHostKind.libvirt,
              volumes: vols,
            ),
          );
    return [
      _disc(
        '__newvol',
        Icons.add_circle_outline,
        l10n.virtVolNew,
        libL10n.cancel,
        onTap: () => setState(() => _adding = false),
      ),
      Padding(
        padding: const EdgeInsets.only(left: _indent),
        child: Input(
          key: const ValueKey('pool:vol:name'),
          controller: _volName,
          label: libL10n.name,
          icon: Icons.label_outline,
          hint: _pve ? 'vm-100-disk-1' : 'data.qcow2',
          noWrap: true,
          suggestion: false,
          errorText: issue,
          onChanged: (_) => setState(() {}),
        ),
      ),
      _seg(
        Icons.description_outlined,
        libL10n.format,
        formats,
        format,
        key: 'pool:vol:format',
        indent: true,
        onSelected: (f) => setState(() => _volFormat = f),
      ),
      _step(
        Icons.straighten,
        libL10n.capacity,
        '$_volGib GiB',
        key: 'pool:vol:size',
        indent: true,
        onDec: _volGib <= 1
            ? null
            : () => setState(() => _volGib = _volGib <= 10 ? 1 : _volGib - 10),
        onInc: () => setState(() => _volGib = _volGib == 1 ? 10 : _volGib + 10),
      ),
      if (_pve) _text(l10n.virtVolPveName, indent: true),
      _actions(indent: true, [
        _Action(
          libL10n.cancel,
          icon: Icons.close,
          onTap: () => setState(() => _adding = false),
        ),
        _Action(
          libL10n.create,
          key: 'pool:vol:create',
          primary: true,
          onTap: busy || _volName.text.trim().isEmpty || issue != null
              ? null
              : () => unawaited(_createVolume(change)),
        ),
      ]),
    ];
  }

  static IconData _volumeIcon(VirtVolume v) => switch (v.content) {
    'iso' => Icons.album_outlined,
    'vztmpl' => Icons.inventory_2_outlined,
    'backup' => Icons.backup_outlined,
    'snippets' || 'import' => Icons.description_outlined,
    _ when virtIsMedia(v, VirtGuestKind.qemu) => Icons.album_outlined,
    _ => Icons.save_outlined,
  };

  List<Widget> _volumeRows(
    VirtStoragePool pool,
    VirtVolume v,
    VirtHostState host,
    VirtCapabilities caps,
    bool busy,
  ) {
    final key = 'vol:${v.id}';
    final iso = virtIsMedia(v, VirtGuestKind.qemu);
    // A disk image: what a guest takes as a disk. The rest (templates,
    // backups, snippets) is only listed and deleted here.
    final disk = !iso && (v.content == null || v.content == 'images' || v.content == 'rootdir');
    final users = _users(host, v);
    final usersText = [
      for (final u in users)
        [virtGuestLabel(host, u), ?u.device].join(' · '),
    ].join(', ');
    final size = switch ((v.allocation, v.capacity)) {
      (final a?, final c?) when a != c => '${a.bytes2Str} / ${c.bytes2Str}',
      (_, final c?) => c.bytes2Str,
      (final a?, null) => a.bytes2Str,
      _ => null,
    };
    final summary = [
      ?size,
      users.isEmpty ? l10n.unused : usersText,
    ].join(' · ');
    final working = _working.contains(v.id);
    final locked = busy || working;
    return [
      _disc(key, _volumeIcon(v), v.name, summary),
      if (_open.contains(key)) ...[
        if (v.path case final p?)
          _field(Icons.folder_outlined, libL10n.path, p, mono: true, indent: true),
        if (disk)
          _field(
            Icons.view_in_ar_outlined,
            l10n.virtVolUsers,
            users.isEmpty ? l10n.unused : usersText,
            indent: true,
          ),
        if (v.backing case final b?)
          _field(Icons.link, l10n.virtBackingFile, b, mono: true, indent: true),
        if (disk && v.capacity != null)
          _meter(
            Icons.pie_chart_outline,
            l10n.virtVolAllocated,
            '${(v.allocation ?? 0).bytes2Str} / ${v.capacity!.bytes2Str}',
            v.allocation == null || v.capacity == 0
                ? null
                : v.allocation! / v.capacity!,
            note: v.format,
            indent: true,
          ),
        if (disk && caps.volumeResize && v.capacity != null)
          ..._resizeRows(pool, v, users, locked),
        if (caps.storageEdit || iso) ..._useRows(pool, v, host, users, iso: iso, disk: disk, locked: locked),
        _actions(indent: true, [
          if (disk && caps.volumeClone)
            _Action(
              libL10n.clone,
              key: 'pool:vol:${v.name}:clone',
              icon: Icons.content_copy,
              onTap: locked || users.any((u) => _running(host, u))
                  ? null
                  : () => unawaited(_clone(pool, v, host)),
            ),
          if (caps.storageEdit)
            _Action(
              libL10n.delete,
              key: 'pool:vol:${v.name}:delete',
              icon: Icons.delete_outline,
              danger: true,
              onTap: locked || users.isNotEmpty
                  ? null
                  : () => unawaited(_deleteVolume(pool, v)),
            ),
        ]),
        if (users.isNotEmpty && caps.storageEdit)
          _text(l10n.virtVolInUse, indent: true),
      ],
    ];
  }

  bool _running(VirtHostState host, VirtGuestRef u) =>
      virtGuestOf(host, u)?.state.isActive ?? true;

  List<Widget> _resizeRows(
    VirtStoragePool pool,
    VirtVolume v,
    List<VirtGuestRef> users,
    bool locked,
  ) {
    final size = v.capacity!;
    final grown = _grow[v.id];
    const step = 8 << 30;
    if (users.isNotEmpty) return [_text(l10n.virtVolGrowFromGuest, indent: true)];
    return [
      _step(
        Icons.straighten,
        libL10n.capacity,
        (grown ?? size).bytes2Str,
        key: 'vol:${v.name}:size',
        indent: true,
        onDec: grown == null
            ? null
            : () => setState(() {
                if (grown - step <= size) {
                  _grow.remove(v.id);
                } else {
                  _grow[v.id] = grown - step;
                }
              }),
        onInc: () => setState(() => _grow[v.id] = (grown ?? size) + step),
      ),
      if (grown != null)
        _actions(indent: true, [
          _Action(
            libL10n.cancel,
            icon: Icons.close,
            onTap: () => setState(() => _grow.remove(v.id)),
          ),
          _Action(
            l10n.virtHwGrow,
            key: 'pool:vol:${v.name}:grow',
            primary: true,
            onTap: locked
                ? null
                : () async {
                    if (await _manage(VirtVolumeResize(pool, v, bytes: grown)) &&
                        mounted) {
                      setState(() => _grow.remove(v.id));
                    }
                  },
          ),
        ]),
    ];
  }

  /// A volume given to a guest: a disk attached, an ISO inserted into its
  /// CD-ROM drive — both through the guest's hardware, as its Hardware view
  /// makes them.
  List<Widget> _useRows(
    VirtStoragePool pool,
    VirtVolume v,
    VirtHostState host,
    List<VirtGuestRef> users, {
    required bool iso,
    required bool disk,
    required bool locked,
  }) {
    if (!iso && !(disk && users.isEmpty)) return const [];
    final guests = [
      for (final g in host.data?.guests ?? const <VirtGuest>[])
        if (g.kind == VirtGuestKind.qemu &&
            !g.template &&
            (pool.node == null || g.node == pool.node))
          g,
    ];
    if (guests.isEmpty) return const [];
    final owner = _pve ? virtPveVolumeVmid(v.name) : null;
    final picked =
        guests.firstWhereOrNull((g) => g.id == _target[v.id]) ??
        guests.firstWhereOrNull((g) => g.vmid != null && g.vmid == owner) ??
        guests.first;
    return [
      _choice([
        for (final g in guests)
          _Choice(
            key: 'pool:vol:${v.name}:to:${g.id}',
            icon: Icons.view_in_ar_outlined,
            label: [?g.vmid?.toString(), g.name].join(' · '),
            sub: host.displayState(g).label,
            selected: g.id == picked.id,
            onTap: () => setState(() => _target[v.id] = g.id),
          ),
      ], indent: true),
      if (disk) _text(l10n.virtVolAttachNote, indent: true),
      _actions(indent: true, [
        _Action(
          iso ? l10n.virtVolInsert : l10n.virtVolAttach,
          key: 'pool:vol:${v.name}:${iso ? 'insert' : 'attach'}',
          primary: true,
          onTap: locked ? null : () => unawaited(_use(pool, v, picked, iso: iso)),
        ),
      ]),
    ];
  }

  // --- Operations ---

  _Group _opsGroup(
    VirtStoragePool pool,
    List<VirtVolume> vols,
    VirtHostState host,
    VirtCapabilities caps,
    bool busy,
  ) {
    final inUse = vols.any((v) => _users(host, v).isNotEmpty);
    final error = Theme.of(context).colorScheme.error;
    return _Group(
      key: 'ops',
      title: l10n.virtOps,
      right: '',
      warn: false,
      dot: error,
      indexNote: inUse ? l10n.virtInUse : l10n.virtCanDelete,
      rows: [
        if (inUse) _text(l10n.virtPoolInUse),
        _actions([
          if (pool.active)
            _Action(
              _pve ? libL10n.disabled : libL10n.stop,
              key: 'pool:stop',
              icon: Icons.stop_circle_outlined,
              danger: true,
              onTap: busy || inUse
                  ? null
                  : () => unawaited(_stop(pool)),
            )
          else
            _Action(
              _pve ? libL10n.enabled : libL10n.start,
              key: 'pool:start',
              icon: Icons.play_circle_outline,
              onTap: busy
                  ? null
                  : () => unawaited(_manage(VirtPoolSetActive(pool, active: true))),
            ),
          _Action(
            _pve ? l10n.virtStorageRemove : l10n.virtPoolDelete,
            key: 'pool:delete',
            icon: Icons.delete_outline,
            danger: true,
            onTap: busy || inUse
                ? null
                : () => unawaited(_deletePool(pool, vols, caps)),
          ),
        ]),
      ],
    );
  }

  String? _issueText(VirtResIssue? issue) => virtResIssueText(issue, pve: _pve);

  // --- Actions ---

  void _openNew(VirtStoragePool pool) {
    setState(() {
      _adding = true;
      _volFormat = null;
      _volGib = 20;
      _volName.clear();
    });
    _scrollTo('vols');
    if (_pve) {
      // PVE names a volume for its guest: the next free VMID's first disk.
      unawaited(
        _notifier.nextVmid().then((id) {
          if (!mounted || id == null || _volName.text.isNotEmpty) return;
          setState(() => _volName.text = 'vm-$id-disk-0');
        }).catchError((Object _) {}),
      );
    }
  }

  Future<bool> _manage(VirtResourceChange change, {bool quiet = false}) =>
      virtManage(ref, _serverId, change, quiet: quiet);

  Future<void> _createVolume(VirtVolumeCreate change) async {
    if (!await _manage(change) || !mounted) return;
    setState(() => _adding = false);
    // The new volume, open, as the design has it.
    final file = _pve
        ? virtVolumeFileName(change.pool, change.name, change.format)
        : change.name;
    try {
      final vols = await ref.read(
        virtVolumesProvider(_serverId, change.pool.id).future,
      );
      final v = vols.firstWhereOrNull((v) => v.name == file);
      if (v != null && mounted) setState(() => _open.add('vol:${v.id}'));
    } catch (_) {
      // The group shows why it cannot list.
    }
  }

  Future<void> _deleteVolume(VirtStoragePool pool, VirtVolume v) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.virtVolDeleteAsk(v.name, pool.name)),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    await _manage(VirtVolumeDelete(pool, v));
  }

  Future<void> _clone(
    VirtStoragePool pool,
    VirtVolume v,
    VirtHostState host,
  ) async {
    final vols = ref.read(virtVolumesProvider(_serverId, pool.id)).value ?? const [];
    final dot = v.name.lastIndexOf('.');
    final stem = dot > 0 ? v.name.substring(0, dot) : v.name;
    final ext = dot > 0 ? v.name.substring(dot) : '';
    var name = '$stem-clone$ext';
    for (var i = 2; vols.any((x) => x.name == name); i++) {
      name = '$stem-clone-$i$ext';
    }
    await _manage(VirtVolumeClone(pool, v, name: name));
  }

  /// Through the guest's hardware: read, checked as its Hardware view checks
  /// it, sent with the revision it was read at.
  Future<void> _use(
    VirtStoragePool pool,
    VirtVolume v,
    VirtGuest guest, {
    required bool iso,
  }) async {
    setState(() => _working.add(v.id));
    try {
      final hwProvider = virtHardwareProvider(_serverId, guest.id);
      final hw = await ref.refresh(hwProvider.future);
      final VirtHwChange change;
      if (iso) {
        final drive = hw.disks.firstWhereOrNull(
          (d) => d.kind == VirtHwDiskKind.cdrom,
        );
        if (drive == null) {
          Toast.warn(l10n.virtVolNoCdrom(guest.name));
          return;
        }
        change = VirtHwSetMedia(key: drive.key, media: v);
      } else {
        change = VirtHwAttachVolume(storage: pool, volume: v);
      }
      final issue = virtHwIssue(hw, change, host: ref.read(virtHostProvider(_serverId)).kind);
      if (issue == VirtHwIssue.volumeInUse) {
        Toast.warn(l10n.virtVolInUse);
        return;
      }
      final outcome = await _notifier.changeHardware(guest.id, hw, change);
      if (!mounted) return;
      ref.invalidate(hwProvider);
      ref.invalidate(virtStoragePoolsProvider(_serverId));
      if (outcome.liveError case final e?) {
        Toast.info(l10n.virtHwAppliesOnRestart, body: e);
      } else {
        Toast.success(
          iso ? l10n.virtVolInserted(guest.name) : l10n.virtVolAttached(guest.name),
        );
      }
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    } catch (e, s) {
      Loggers.app.warning('Virtualization attach', e, s);
      Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) setState(() => _working.remove(v.id));
    }
  }

  Future<void> _stop(VirtStoragePool pool) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(
        _pve ? l10n.virtStorageDisableAsk(pool.name) : l10n.virtPoolStopAsk(pool.name),
      ),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    await _manage(VirtPoolSetActive(pool, active: false));
  }

  Future<void> _deletePool(
    VirtStoragePool pool,
    List<VirtVolume> vols,
    VirtCapabilities caps,
  ) async {
    var deleteStorage = false;
    // `pool-delete` removes an empty directory and nothing else.
    final canDeleteStorage =
        caps.poolDeleteStorage && vols.isEmpty && pool.type != 'logical';
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: StatefulBuilder(
        builder: (context, setDialog) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _pve
                  ? l10n.virtStorageRemoveAsk(pool.name)
                  : l10n.virtPoolDeleteAsk(pool.name),
            ),
            if (vols.isNotEmpty) ...[
              UIs.height7,
              Text(l10n.virtPoolDeleteKeepsVolumes(vols.length), style: UIs.text12Grey),
            ],
            if (canDeleteStorage && pool.path != null)
              CheckboxListTile(
                key: const ValueKey('pool:delete:storage'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: deleteStorage,
                title: Text(l10n.virtPoolDeleteStorage),
                subtitle: Text(pool.path!, style: UIs.text12Grey),
                onChanged: (v) => setDialog(() => deleteStorage = v ?? false),
              ),
          ],
        ),
      ),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    if (await _manage(VirtPoolDelete(pool, deleteStorage: deleteStorage))) {
      widget.onDeleted?.call();
    }
  }

  /// A file from this device into the pool, under a name asked for first;
  /// the upload runs on in the host's state, shown in the volumes group.
  Future<void> _upload(VirtStoragePool pool) async {
    final path = await Pfs.pickFilePath();
    if (path == null || !mounted) return;
    final file = File(path);
    final int size;
    try {
      size = await file.length();
    } catch (e) {
      Toast.error(libL10n.fail, body: '$e');
      return;
    }
    if (!mounted) return;
    final base = path.split(RegExp(r'[/\\]')).last;
    final vols =
        ref.read(virtVolumesProvider(_serverId, pool.id)).value ?? const <VirtVolume>[];
    final ctrl = TextEditingController(
      text: base.replaceAll(RegExp(r'[^A-Za-z0-9._+-]'), '-').replaceFirst(RegExp(r'^[.+-]+'), ''),
    );
    final name = await context.showRoundDialog<String>(
      title: l10n.virtUploadTo(pool.name),
      child: StatefulBuilder(
        builder: (context, setDialog) {
          final issue = virtResIssueText(
            virtUploadIssue(pool, ctrl.text.trim(), size, volumes: vols),
            pve: _pve,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Input(
                key: const ValueKey('pool:upload:name'),
                controller: ctrl,
                label: libL10n.name,
                icon: Icons.label_outline,
                noWrap: true,
                suggestion: false,
                errorText: issue,
                onChanged: (_) => setDialog(() {}),
              ),
              Text('${size.bytes2Str} · $base', style: UIs.text12Grey),
            ],
          );
        },
      ),
      actions: [
        Btn.cancel(),
        Btn.text(
          text: libL10n.upload,
          onTap: () {
            final n = ctrl.text.trim();
            if (virtUploadIssue(pool, n, size, volumes: vols) != null) return;
            context.popDialog(n);
          },
        ),
      ],
    );
    ctrl.dispose();
    if (name == null || !mounted) return;
    final lower = name.toLowerCase();
    final template = RegExp(r'\.tar\.(gz|xz|zst)$').hasMatch(lower);
    try {
      final done = await _notifier.upload(
        VirtUpload(
          pool: pool,
          name: name,
          size: size,
          open: file.openRead,
          content: template ? 'vztmpl' : 'iso',
        ),
      );
      if (done) {
        Toast.success(l10n.virtUploadDone(name));
      } else {
        Toast.info(libL10n.cancelled);
      }
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    } catch (e, s) {
      Loggers.app.warning('Virtualization upload', e, s);
      Toast.error(libL10n.fail, body: '$e');
    }
  }

  Future<void> _pick(
    List<VirtStoragePool> all,
    ValueChanged<String> onSwitch,
  ) async {
    final picked = await showRowsSheet<String>(
      context,
      rows: (ctx) => [
        for (final p in all)
          ListTile(
            selected: p.id == widget.poolId,
            leading: const Icon(Icons.storage_outlined),
            title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [p.type, ?p.node].join(' · '),
              style: UIs.textGrey,
            ),
            onTap: () => Navigator.of(ctx).pop(p.id),
          ),
      ],
    );
    if (picked == null || picked == widget.poolId || !mounted) return;
    onSwitch(picked);
  }
}

/// What a [VirtResIssue] says, for a field's error line or a toast.
String? virtResIssueText(VirtResIssue? issue, {required bool pve}) =>
    switch (issue) {
      null => null,
      VirtResIssue.nameEmpty => l10n.virtResNameEmpty,
      VirtResIssue.nameInvalid => l10n.virtResNameInvalid,
      VirtResIssue.nameTaken => l10n.virtCreateNameTaken,
      VirtResIssue.sourceInvalid => l10n.virtResSourceInvalid,
      VirtResIssue.targetInvalid => l10n.virtResTargetInvalid,
      VirtResIssue.cidrInvalid => l10n.virtResCidrInvalid,
      VirtResIssue.dhcpInvalid => l10n.virtResDhcpInvalid,
      VirtResIssue.subnetTaken => l10n.virtResSubnetTaken,
      VirtResIssue.bridgeInvalid => l10n.virtResBridgeInvalid,
      VirtResIssue.size => l10n.virtHwIssueDiskSize,
      VirtResIssue.space => l10n.virtHwIssueStorageSpace,
      VirtResIssue.format => l10n.virtResFormat,
      VirtResIssue.inUse => l10n.virtVolInUse,
      VirtResIssue.shrink => l10n.virtHwIssueDiskShrink,
    };

/// A new pool (libvirt) or storage (PVE) — the design's form in the detail
/// pane: a name, what it is, where it comes from.
class VirtPoolCreateView extends ConsumerStatefulWidget {
  const VirtPoolCreateView({
    super.key,
    required this.serverId,
    required this.onCancel,
    required this.onCreated,
    this.leading,
  });

  final String serverId;
  final VoidCallback onCancel;

  /// The new pool's id.
  final ValueChanged<String> onCreated;
  final Widget? leading;

  @override
  ConsumerState<VirtPoolCreateView> createState() => _VirtPoolCreateViewState();
}

class _VirtPoolCreateViewState extends ConsumerState<VirtPoolCreateView>
    with _PaneRows<VirtPoolCreateView> {
  final _name = TextEditingController();
  final _source = TextEditingController();
  final _mount = TextEditingController();
  String? _type;
  String? _node;
  var _creating = false;

  @override
  void dispose() {
    _name.dispose();
    _source.dispose();
    _mount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = ref.watch(virtHostProvider(widget.serverId));
    final caps = host.data?.capabilities ?? const VirtCapabilities();
    final pve = host.kind == VirtHostKind.pve;
    final types = caps.poolTypes;
    final type = types.contains(_type) ? _type! : types.firstOrNull;
    final nodes = [
      for (final n in host.data?.host.nodes ?? const <VirtNode>[])
        if (n.online) n.name,
    ];
    final node = nodes.contains(_node) ? _node : nodes.firstOrNull;
    final pools = ref.watch(virtStoragePoolsProvider(widget.serverId)).value ?? const [];
    final name = _name.text.trim();
    // A netfs pool is mounted somewhere of its own; the form offers one.
    final mount = _mount.text.trim().isEmpty && name.isNotEmpty
        ? '/mnt/$name'
        : _mount.text.trim();
    final change = type == null
        ? null
        : VirtPoolCreate(
            name: name,
            type: type,
            source: _source.text.trim(),
            target: type == 'netfs' ? mount : null,
            node: pve ? node : null,
          );
    final issue = change == null
        ? null
        : virtResourceIssue(
            change,
            host: pve ? VirtHostKind.pve : VirtHostKind.libvirt,
            pools: pools,
          );
    final nameIssue = switch (issue) {
      VirtResIssue.nameEmpty || VirtResIssue.nameInvalid || VirtResIssue.nameTaken =>
        virtResIssueText(issue, pve: pve),
      _ => null,
    };
    final sourceIssue = _source.text.isEmpty ? null : switch (issue) {
      VirtResIssue.sourceInvalid => virtResIssueText(issue, pve: pve),
      _ => null,
    };
    final (sourceLabel, sourceHint) = switch (type) {
      'netfs' || 'nfs' => (l10n.virtPoolSourceNfs, '10.0.0.5:/export/data'),
      'logical' => (l10n.virtPoolSourceVg, 'vg_data'),
      'lvmthin' => (l10n.virtPoolSourceThin, 'pve/data'),
      'zfspool' => (l10n.virtPoolSourceZfs, 'rpool/data'),
      _ => (libL10n.path, pve ? '/mnt/data' : '/var/lib/libvirt/$name'),
    };
    final ready = change != null && issue == null && !_creating;
    return Scaffold(
      appBar: virtResourceBar(
        name: pve ? l10n.virtStorageAdd : l10n.virtPoolNew,
        icon: Icons.add_circle_outline,
        leading: widget.leading,
        actions: [
          Btn.icon(
            text: libL10n.cancel,
            icon: const Icon(Icons.close, size: 18),
            onTap: widget.onCancel,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: 3, child: _creating ? const ProgressLine() : null),
          Expanded(
            child: _buildGroups(
              [
                _Group(
                  key: 'new',
                  title: pve ? libL10n.storage : l10n.virtPool,
                  right: ref.read(serversProvider).servers[widget.serverId]?.name ?? '',
                  warn: false,
                  indexNote: type ?? '',
                  rows: [
                    Input(
                      key: const ValueKey('pool:new:name'),
                      controller: _name,
                      label: libL10n.name,
                      icon: Icons.label_outline,
                      hint: 'backup-2',
                      noWrap: true,
                      suggestion: false,
                      errorText: name.isEmpty ? null : nameIssue,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (pve && nodes.length > 1)
                      _seg(
                        Icons.dns_outlined,
                        libL10n.node,
                        nodes,
                        node,
                        key: 'pool:new:node',
                        onSelected: (n) => setState(() => _node = n),
                      ),
                    _choice([
                      for (final t in types)
                        _Choice(
                          key: 'pool:new:type:$t',
                          icon: _typeIcon(t),
                          label: _typeLabel(t),
                          sub: t,
                          selected: t == type,
                          onTap: () => setState(() => _type = t),
                        ),
                    ]),
                    Input(
                      key: const ValueKey('pool:new:source'),
                      controller: _source,
                      label: sourceLabel,
                      icon: Icons.folder_outlined,
                      hint: sourceHint,
                      noWrap: true,
                      suggestion: false,
                      errorText: sourceIssue,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (type == 'netfs')
                      Input(
                        key: const ValueKey('pool:new:mount'),
                        controller: _mount,
                        label: l10n.virtPoolMountPoint,
                        icon: Icons.folder_open,
                        hint: mount.isEmpty ? '/mnt/data' : mount,
                        noWrap: true,
                        suggestion: false,
                        errorText: issue == VirtResIssue.targetInvalid
                            ? virtResIssueText(issue, pve: pve)
                            : null,
                        onChanged: (_) => setState(() {}),
                      ),
                    if (type == 'logical') _text(l10n.virtPoolLogicalNote),
                    _actions([
                      _Action(
                        libL10n.cancel,
                        icon: Icons.close,
                        onTap: widget.onCancel,
                      ),
                      _Action(
                        libL10n.create,
                        key: 'pool:new:create',
                        primary: true,
                        onTap: ready ? () => unawaited(_create(change, pve)) : null,
                      ),
                    ]),
                  ],
                ),
              ],
              onRefresh: () async {},
            ),
          ),
        ],
      ),
    );
  }

  static IconData _typeIcon(String t) => switch (t) {
    'dir' => Icons.folder_outlined,
    'logical' || 'lvmthin' => Icons.layers_outlined,
    'netfs' || 'nfs' => Icons.lan_outlined,
    'zfspool' => Icons.storage_outlined,
    _ => Icons.storage_outlined,
  };

  static String _typeLabel(String t) => switch (t) {
    'dir' => libL10n.folder,
    'logical' => l10n.virtPoolTypeVg,
    'lvmthin' => 'LVM-thin',
    'netfs' || 'nfs' => 'NFS',
    'zfspool' => 'ZFS',
    _ => t,
  };

  Future<void> _create(VirtPoolCreate change, bool pve) async {
    setState(() => _creating = true);
    try {
      await ref.read(virtHostProvider(widget.serverId).notifier).manage(change);
      if (!mounted) return;
      Toast.success(libL10n.success);
      widget.onCreated(pve ? '${change.node}/${change.name}' : change.name);
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    } catch (e, s) {
      Loggers.app.warning('Virtualization new pool', e, s);
      Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}
