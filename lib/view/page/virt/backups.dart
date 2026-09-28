part of 'hardware.dart';

/// A guest's backups — the design's Backup view (PVE): the scheduled jobs
/// that take it (the Plan group, "Datacenter → Backup"), and its backups,
/// with backing up now, restoring (over it, or as a new guest, onto a
/// storage of its own), editing a backup's notes and protection, and
/// deleting.
///
/// The same pane as the Hardware view, so the groups and their index read
/// alike; what it lists is its own read, again after every operation.
///
/// **What the design has and the phase-5 view did not**: the options a run
/// takes (storage, mode, compression, notes, protection, retention), the
/// notes and the protection of a backup already made, and where a restore
/// puts the disks. The Plan group also gained what a job *is* — its guests,
/// its node, its notification — and the two ways out of it into the
/// datacenter's own list.
///
/// **A plan of the guest's own is edited here**: a job that takes this guest
/// and no other ([VirtBackupJob.takesOnly]) is made, edited and deleted in
/// the Plan group with the Backup section's own rows ([_JobFormRows]), where
/// the design only lists it. A job that takes other guests too stays read
/// only here and opens in that section ([onOpenJob]): a change to it is a
/// change to their backups as well.
class VirtBackupView extends ConsumerStatefulWidget {
  const VirtBackupView({
    super.key,
    required this.serverId,
    required this.guest,
    required this.caps,
    required this.onOpenGuest,
    required this.onOpenJob,
  });

  final String serverId;
  final VirtGuest guest;
  final VirtCapabilities caps;

  /// A backup was restored as the new guest with this id: open it.
  final ValueChanged<String> onOpenGuest;

  /// Opens the backup job with this id in the tab's Backup section.
  final ValueChanged<String> onOpenJob;

  @override
  ConsumerState<VirtBackupView> createState() => _VirtBackupViewState();
}

class _VirtBackupViewState extends ConsumerState<VirtBackupView>
    with
        _PaneRows<VirtBackupView>,
        _EditPane<VirtBackupView>,
        _JobFormRows<VirtBackupView> {
  @override
  String get _serverId => widget.serverId;
  @override
  VirtGuest get _guest => widget.guest;
  @override
  VirtCapabilities get _caps => widget.caps;

  List<VirtBackup>? _backups;
  List<VirtBackupJob> _jobs = const [];
  List<VirtStoragePool> _storages = const [];

  /// The host's storages, for where a restore puts the disks: those that
  /// hold guest disks (`images`, `rootdir`), which a backup storage need not.
  List<VirtStoragePool> _diskPools = const [];
  Object? _error;

  /// A backup's delete or restore asked once: the second press does it.
  String? _confirm;

  /// The options a run now takes. The storage starts as the job's own (or
  /// the first that holds backups) and the rest as the design has them.
  String? _storage;
  String _mode = 'snapshot';
  String _compress = 'zstd';
  final _notes = TextEditingController();
  var _protect = false;
  var _working = false;

  /// A backup's notes as they are being edited, by backup id, and whether
  /// its protection is being flipped. Null: the row is not open for editing.
  final _notesDraft = <String, TextEditingController>{};

  /// The storage a restore puts the disks on, by backup id; null: as the
  /// archive says.
  final _restoreStorage = <String, String?>{};

  /// A plan of this guest's own being edited in place, and which: the job's
  /// id, or null for a new one. One at a time, as a backup's notes are.
  _JobForm? _plan;
  String? _planId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _notes.dispose();
    _plan?.dispose();
    for (final c in _notesDraft.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final id = _guest.id;
    try {
      final (backups, jobs, storages) = await (
        _notifier.backups(id),
        _notifier.backupJobs(id),
        _notifier.backupStorages(id),
      ).wait;
      if (!mounted) return;
      setState(() {
        _backups = backups;
        _jobs = jobs;
        _storages = storages;
        _error = null;
        _storage ??= _defaultTarget?.name;
      });
      // Only the restore's storage picker needs them, so a refusal (an
      // account without `Datastore.Audit` on some storage) leaves it out
      // rather than taking the view with it.
      try {
        final pools = await _notifier.storagePools();
        if (mounted) setState(() => _diskPools = pools);
      } on VirtErr catch (e) {
        Loggers.app.info('PVE storages for a restore: ${e.message}');
      }
    } on ParallelWaitError<
      (List<VirtBackup>?, List<VirtBackupJob>?, List<VirtStoragePool>?),
      dynamic
    > catch (e) {
      if (mounted) {
        setState(
          () => _error = e.errors.$1 ?? e.errors.$2 ?? e.errors.$3,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error case final e?) {
      return _buildError(e, onRetry: () => unawaited(_load()));
    }
    if (_backups == null) return const Center(child: SizedLoading.medium);
    final busy = ref.watch(
      virtHostProvider(_serverId).select((s) => s.isBusy(_guest.id)),
    );
    // Not the hardware pane's own build: nothing here is read from the
    // hardware, and a pull reads again what these groups show — the
    // backups, the jobs and the storages.
    return _buildGroups(
      [
        _planGroup(busy),
        _listGroup(busy),
        // The first backup takes these options as much as any later one.
        _runGroup(busy),
      ],
      onRefresh: _load,
    );
  }

  bool get _live => _guest.state != VirtGuestState.stopped;

  // --- Plan ---

  _Group _planGroup(bool busy) {
    final job = _jobs.firstOrNull;
    final blocked = busy || _working;
    // Made and changed here only where the host has the datacenter's jobs
    // to make: elsewhere the group reads them, as the design has it.
    final editable = _caps.backupJobs && _guest.vmid != null;
    final creating = _plan != null && _planId == null;
    return _Group(
      key: 'plan',
      title: l10n.virtBackupPlan,
      right: l10n.virtBackupPlanWhere,
      warn: false,
      indexNote: job?.schedule ?? l10n.virtBackupNoPlanShort,
      rows: [
        if (creating)
          ..._planEditor(null, blocked)
        else if (editable)
          _empty(
            _jobs.isEmpty ? l10n.virtBackupNoPlan : l10n.virtBackupPlanNewTip,
            l10n.virtBackupPlanNew,
            key: 'plan:new',
            icon: Icons.add,
            onTap: blocked || _plan != null ? null : () => _editPlan(null),
          )
        else if (job == null)
          _text(l10n.virtBackupNoPlan),
        for (final j in _jobs)
          if (_plan != null && _planId == j.id)
            ..._planEditor(j, blocked)
          else
            ..._planRows(j, blocked, editable: editable),
      ],
    );
  }

  /// A job that takes this guest, read: when, where, how — and, for one
  /// that takes other guests too, the line into the datacenter's list.
  List<Widget> _planRows(
    VirtBackupJob j,
    bool blocked, {
    required bool editable,
  }) {
    final own = editable && j.takesOnly(_guest.vmid);
    final key = 'plan:${j.id}';
    final deleting = _confirm == 'job:${j.id}';
    // One line until opened: when, where, and whether it runs at all. A
    // guest can be in several jobs, and each in full was a screen of rows.
    final row = _disc(
      key,
      Icons.schedule,
      j.schedule ?? '-',
      [
        ?j.storage,
        ?j.mode,
        if (!j.enabled) libL10n.disabled,
      ].join(' · '),
      marked: j.enabled,
    );
    if (!_open.contains(key)) return [row];
    return [
      row,
      _field(Icons.storage_outlined, libL10n.storage, j.storage ?? '-', indent: true),
      if (j.keep case final keep?)
        _field(Icons.inventory_2_outlined, l10n.virtBackupKeep, keep, indent: true),
      _field(
        Icons.compress,
        libL10n.mode,
        [?j.mode, ?j.compress].join(' · '),
        indent: true,
      ),
      if (!j.takesOnly(_guest.vmid))
        _field(
          Icons.group_outlined,
          l10n.virtBackupSelection,
          _othersLabel(j),
          key: ValueKey('$key:open'),
          indent: true,
          onTap: editable ? () => widget.onOpenJob(j.id) : null,
          trailing: editable
              ? Icon(
                  Icons.chevron_right,
                  size: 19,
                  color: Theme.of(context).colorScheme.outline,
                )
              : null,
        ),
      if (j.node case final node?)
        _field(Icons.dns_outlined, l10n.virtBackupJobNode, node, indent: true),
      if (!j.enabled) _text(l10n.virtBackupJobDisabled, indent: true),
      if (deleting)
        _callout(
          l10n.virtSetDeleteAgain,
          l10n.virtBackupJobDeleteAsk(j.id),
          key: ValueKey('$key:confirm'),
          indent: true,
        ),
      _actions(indent: true, [
        if (deleting)
          _Action(
            libL10n.cancel,
            icon: Icons.close,
            onTap: () => setState(() => _confirm = null),
          ),
        if (own) ...[
          _Action(
            deleting ? l10n.virtBackupDeleteConfirm : libL10n.delete,
            key: '$key:delete',
            icon: Icons.delete_outline,
            danger: true,
            onTap: blocked || _plan != null ? null : () => _deletePlan(j),
          ),
          _Action(
            libL10n.edit,
            key: '$key:edit',
            icon: Icons.edit_outlined,
            onTap: blocked || deleting || _plan != null
                ? null
                : () => _editPlan(j),
          ),
        ],
        _Action(
          l10n.virtBackupJobRun,
          key: '$key:run',
          icon: Icons.play_arrow,
          onTap: blocked || deleting ? null : () => _runNow(j),
        ),
      ]),
    ];
  }

  /// Whom else [j] takes, as the Plan group says it of a job that is not the
  /// guest's alone.
  String _othersLabel(VirtBackupJob j) {
    if (j.pool case final pool?) return 'pool:$pool';
    if (j.all) {
      return j.exclude.isEmpty
          ? l10n.virtBackupSelectionAll
          : '${l10n.virtBackupSelectionAll} − ${j.exclude.length}';
    }
    final others = j.vmids.where((v) => v != _guest.vmid).length;
    return l10n.virtBackupPlanOthers(others);
  }

  /// The rows of the plan being edited — the Backup section's own, less the
  /// guests (this one) and the node (the job's as it was, or none: a new
  /// plan runs wherever the guest is).
  List<Widget> _planEditor(VirtBackupJob? j, bool blocked) {
    final f = _plan!;
    final key = 'plan:${j?.id ?? 'new'}';
    final storages = _planStorages;
    final storage = f.storageIn(storages);
    return [
      if (j == null) _text(l10n.virtBackupPlanNewTip),
      ..._jobWhenRows(
        f,
        key: key,
        busy: blocked,
        onValidate: () => _checkSchedule(f, _notifier),
      ),
      ..._jobWhatRows(f, storages, key: key, busy: blocked),
      _actions([
        _Action(
          libL10n.cancel,
          key: '$key:cancel',
          icon: Icons.close,
          onTap: blocked ? null : _closePlan,
        ),
        _Action(
          libL10n.save,
          key: '$key:save',
          primary: true,
          onTap: blocked || f.scheduleIssue != null || storage == null
              ? null
              : () => _savePlan(j, storage),
        ),
      ]),
    ];
  }

  /// Where a plan's backups can go: the storages of the guest's node that
  /// hold backups, each once (see [_backupStoragesFor]).
  List<VirtStoragePool> get _planStorages =>
      _backupStoragesFor(_storages, node: _guest.node);

  // --- Backups ---

  /// Where "Back up now" writes: the storage the guest's job uses, else the
  /// first that holds backups.
  VirtStoragePool? get _defaultTarget {
    final wanted = _jobs.map((j) => j.storage).nonNulls.toSet();
    return _storages.firstWhereOrNull((s) => wanted.contains(s.name)) ??
        _storages.firstOrNull;
  }

  _Group _listGroup(bool busy) {
    final backups = _backups ?? const <VirtBackup>[];
    final target = _storage ?? _defaultTarget?.name;
    final blocked = busy || _working;
    return _Group(
      key: 'list',
      title: libL10n.backup,
      right: l10n.virtBackupCount(backups.length),
      warn: false,
      indexNote: backups.firstOrNull?.createdAt == null
          ? l10n.virtBackupCount(backups.length)
          : _when(backups.first),
      rows: [
        _empty(
          target == null
              ? l10n.virtBackupNoStorage
              : _live
              ? l10n.virtBackupLiveTip
              : l10n.virtBackupStoppedTip,
          l10n.virtBackupNow,
          key: 'backup:now',
          icon: Icons.backup_outlined,
          onTap: target == null || blocked ? null : () => _backupNow(target),
        ),
        for (final b in backups) ..._backupRows(b, blocked),
      ],
    );
  }

  /// The options a run now takes — the design's mode and compression, plus
  /// the storage, the notes and the protection PVE's own dialog asks for.
  _Group _runGroup(bool busy) {
    final blocked = busy || _working;
    final storages = _storages;
    return _Group(
      key: 'options',
      title: l10n.virtBackupOptions,
      right: '',
      warn: false,
      indexNote: '$_mode${_compress == '0' ? '' : ' · $_compress'}',
      rows: [
        if (storages.isEmpty)
          _text(l10n.virtBackupNoStorage)
        else
          _seg(
            Icons.storage_outlined,
            libL10n.storage,
            [for (final s in storages) s.name],
            _storage ?? storages.first.name,
            key: 'opt:storage',
            onSelected: blocked ? null : (v) => setState(() => _storage = v),
          ),
        _seg(
          Icons.restart_alt,
          libL10n.mode,
          const ['snapshot', 'suspend', 'stop'],
          _mode,
          key: 'opt:mode',
          onSelected: blocked ? null : (v) => setState(() => _mode = v),
        ),
        _seg(
          Icons.compress,
          l10n.virtBackupCompress,
          const ['zstd', 'lzo', 'gzip', '0'],
          _compress,
          key: 'opt:compress',
          onSelected: blocked ? null : (v) => setState(() => _compress = v),
        ),
        _inputRow([Input(
          key: const ValueKey('opt:notes'),
          controller: _notes,
          label: l10n.virtBackupNotes,
          icon: Icons.notes,
          enabled: !blocked,
          noWrap: true,
          maxLines: 3,
          minLines: 1,
        )]),
        _toggle(
          Icons.lock_outline,
          l10n.virtBackupProtect,
          _protect,
          key: 'opt:protect',
          note: l10n.virtBackupProtectTip,
          onChanged: blocked ? null : (on) => setState(() => _protect = on),
        ),
        if (_live && _mode != 'snapshot')
          _text(l10n.virtBackupModeStops),
        _actions([
          _Action(
            l10n.virtBackupNow,
            key: 'opt:go',
            primary: true,
            icon: Icons.backup_outlined,
            onTap: blocked || _storage == null
                ? null
                : () => _backupNow(_storage!),
          ),
        ]),
      ],
    );
  }

  String _when(VirtBackup b) {
    final t = b.createdAt;
    if (t == null) return b.fileName;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  List<Widget> _backupRows(VirtBackup b, bool blocked) {
    final key = 'backup:${b.id}';
    final summary = [
      if (b.size case final size?) size.bytes2Str,
      ?b.format,
    ].join(' · ');
    final deleting = _confirm == 'delete:${b.id}';
    final restoring = _confirm == 'restore:${b.id}';
    final notes = _notesDraft[b.id];
    final notesOpen = notes != null;
    final restoreTo = _restoreStorage[b.id];
    final diskStorages = virtDiskStorages(
      _diskPools,
      host: VirtHostKind.pve,
      kind: b.kind ?? _guest.kind,
      node: _guest.node,
    );
    return [
      _disc(key, Icons.backup_outlined, _when(b), summary),
      _reveal(key, [
        _field(
          Icons.description_outlined,
          libL10n.file,
          b.fileName,
          mono: true,
          indent: true,
        ),
        if (notesOpen)
          ...[
            _inputRow([Input(
              key: ValueKey('$key:notes:field'),
              controller: notes,
              label: l10n.virtBackupEditNotes,
              icon: Icons.notes,
              noWrap: true,
              maxLines: 3,
              minLines: 1,
              enabled: !blocked,
            )], indent: true),
            _actions(
              [
                _Action(
                  libL10n.cancel,
                  icon: Icons.close,
                  onTap: () => setState(() {
                    _notesDraft.remove(b.id)?.dispose();
                  }),
                ),
                _Action(
                  l10n.virtBackupSaveNotes,
                  key: '$key:notes:save',
                  primary: true,
                  onTap: blocked ? null : () => _saveNotes(b, notes.text),
                ),
              ],
              indent: true,
            ),
          ]
        else if (b.notes case final n? when n.isNotEmpty)
          _field(Icons.notes, l10n.virtBackupNotes, n, indent: true),
        if (b.protected) _text(l10n.virtBackupProtected, indent: true),
        if (b.verification case final v?)
          _text(l10n.virtBackupVerified(v), indent: true, error: v != 'ok'),
        if (_live)
          _callout(
            l10n.virtBackupRestoreOverwrites,
            l10n.virtBackupStopFirst,
            indent: true,
          ),
        // Where a restore as a new guest puts the disks. Over the guest
        // itself PVE has no storage to give (`force=1` restores in place),
        // so the row is only under the "as a new guest" action.
        if (restoreTo != null || diskStorages.isNotEmpty)
          _seg(
            Icons.storage_outlined,
            l10n.virtBackupRestoreStorage,
            [
              l10n.virtBackupRestoreStorageSame,
              for (final s in diskStorages) s.name,
            ],
            restoreTo ?? l10n.virtBackupRestoreStorageSame,
            key: '$key:restore-storage',
            indent: true,
            onSelected: blocked
                ? null
                : (v) => setState(() {
                    _restoreStorage[b.id] =
                        v == l10n.virtBackupRestoreStorageSame ? null : v;
                  }),
          ),
        if (deleting || restoring)
          _callout(
            l10n.virtSetDeleteAgain,
            restoring ? l10n.virtBackupRestoreAgain : l10n.virtSetIrreversible,
            indent: true,
            key: ValueKey('$key:confirm'),
          ),
        _actions(
          [
            if (deleting || restoring)
              _Action(
                libL10n.cancel,
                icon: Icons.close,
                onTap: () => setState(() => _confirm = null),
              ),
            _Action(
              notesOpen ? l10n.virtBackupEditNotes : libL10n.edit,
              key: '$key:notes',
              icon: Icons.notes,
              onTap: blocked || deleting || restoring
                  ? null
                  : () => setState(() {
                      notesOpen
                          ? _notesDraft.remove(b.id)?.dispose()
                          : _notesDraft[b.id] = TextEditingController(
                              text: b.notes ?? '',
                            );
                    }),
            ),
            _Action(
              b.protected ? l10n.virtBackupUnprotect : l10n.virtBackupProtect,
              key: '$key:protect',
              icon: b.protected ? Icons.lock_open : Icons.lock_outline,
              onTap: blocked || deleting || restoring
                  ? null
                  : () => _setProtected(b, !b.protected),
            ),
            _Action(
              deleting ? l10n.virtBackupDeleteConfirm : libL10n.delete,
              key: '$key:delete',
              icon: Icons.delete_outline,
              danger: true,
              onTap: blocked || b.protected || restoring
                  ? null
                  : () => _delete(b),
            ),
            _Action(
              l10n.virtBackupRestoreNew,
              key: '$key:restore-new',
              icon: Icons.add_to_photos_outlined,
              onTap: blocked || deleting ? null : () => _restoreNew(b),
            ),
            _Action(
              restoring ? l10n.virtBackupRestoreConfirm : libL10n.restore,
              key: '$key:restore',
              primary: true,
              onTap: blocked || _live || deleting ? null : () => _restore(b),
            ),
          ],
          indent: true,
        ),
      ]),
    ];
  }

  // --- Actions ---

  /// Runs [op], says [done] or why not, and reads the view again. True when
  /// [op] went through.
  Future<bool> _run(Future<void> Function() op, String done) async {
    setState(() {
      _working = true;
      _confirm = null;
    });
    try {
      await op();
      Toast.success(done);
      return true;
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
      return false;
    } catch (e) {
      Toast.error(libL10n.fail, body: '$e');
      return false;
    } finally {
      // A view closed while this ran has nothing to show it in, and no
      // `ref` to read the list through.
      if (mounted) {
        setState(() => _working = false);
        await _load();
      }
    }
  }

  Future<void> _backupNow(String target) => _run(
    () => _notifier.backup(
      _guest.id,
      VirtBackupRequest(
        storage: target,
        // The mode picked: for a guest that is off, vzdump copies it as it
        // is whichever mode is sent.
        mode: _mode,
        compress: _compress,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        protected: _protect,
      ),
    ),
    l10n.virtBackupDone,
  );

  /// Runs the scheduled [job] now, as PVE's own "Run now" does: the job's
  /// fields, without its schedule.
  Future<void> _runNow(VirtBackupJob job) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.virtBackupJobRunAsk),
      actions: Btnx.cancelOk,
    );
    if (ok != true || !mounted) return;
    await _run(
      () => _notifier.runBackupJob(job),
      l10n.virtBackupJobStarted,
    );
  }

  void _editPlan(VirtBackupJob? j) {
    final f = _JobForm(() => setState(() {}));
    if (j != null) f.fill(j);
    setState(() {
      _plan?.dispose();
      _plan = f;
      _planId = j?.id;
      _confirm = null;
    });
  }

  void _closePlan() => setState(() {
    _plan?.dispose();
    _plan = null;
    _planId = null;
  });

  /// Saves the plan being edited: [j] with the form's fields, or a new job
  /// that takes this guest alone. Closed once the host has it; kept open,
  /// as typed, when it refused.
  Future<void> _savePlan(VirtBackupJob? j, String storage) async {
    final f = _plan;
    final vmid = _guest.vmid;
    if (f == null || vmid == null) return;
    final saved = await _run(
      () => _notifier.editBackupJob(
        f.edit(
          id: j?.id,
          isNew: j == null,
          node: j?.node,
          storage: storage,
          vmids: [vmid],
        ),
      ),
      l10n.virtBackupJobSaved,
    );
    if (saved && mounted && identical(_plan, f)) _closePlan();
  }

  Future<void> _deletePlan(VirtBackupJob j) async {
    if (_confirm != 'job:${j.id}') {
      setState(() => _confirm = 'job:${j.id}');
      return;
    }
    await _run(
      () => _notifier.editBackupJob(_removal(j), remove: true),
      l10n.virtBackupJobDeleted,
    );
  }

  Future<void> _saveNotes(VirtBackup b, String notes) => _run(
    () => _notifier.editBackup(
      b,
      VirtBackupEdit(notes: notes.trim(), protected: b.protected),
    ),
    l10n.virtBackupEdited,
  );

  Future<void> _setProtected(VirtBackup b, bool on) => _run(
    () => _notifier.editBackup(
      b,
      VirtBackupEdit(notes: b.notes ?? '', protected: on),
    ),
    l10n.virtBackupEdited,
  );

  Future<void> _delete(VirtBackup b) async {
    if (_confirm != 'delete:${b.id}') {
      setState(() => _confirm = 'delete:${b.id}');
      return;
    }
    await _run(() => _notifier.deleteBackup(_guest.id, b), l10n.virtBackupDeleted);
  }

  Future<void> _restore(VirtBackup b) async {
    if (_confirm != 'restore:${b.id}') {
      setState(() => _confirm = 'restore:${b.id}');
      return;
    }
    await _run(
      () => _notifier.restoreBackup(_guest.id, b),
      l10n.virtBackupRestored(_when(b)),
    );
  }

  /// As the next free VMID, onto the storage the row picked; the new guest is
  /// opened once it is there.
  Future<void> _restoreNew(VirtBackup b) async {
    final kind = b.kind ?? _guest.kind;
    final storage = _restoreStorage[b.id];
    String? id;
    await _run(() async {
      final vmid = await _notifier.nextVmid();
      if (vmid == null) {
        throw const VirtErr(type: VirtErrType.invalidResponse);
      }
      await _notifier.restoreBackup(
        _guest.id,
        b,
        vmid: vmid,
        storage: storage,
      );
      id = '${kind == VirtGuestKind.lxc ? 'lxc' : 'qemu'}/$vmid';
    }, l10n.virtBackupRestored(_when(b)));
    if (id case final id? when mounted) {
      await _notifier.refresh();
      if (mounted) widget.onOpenGuest(id);
    }
  }
}
