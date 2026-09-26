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
class VirtBackupView extends ConsumerStatefulWidget {
  const VirtBackupView({
    super.key,
    required this.serverId,
    required this.guest,
    required this.caps,
    required this.onOpenGuest,
  });

  final String serverId;
  final VirtGuest guest;
  final VirtCapabilities caps;

  /// A backup was restored as the new guest with this id: open it.
  final ValueChanged<String> onOpenGuest;

  @override
  ConsumerState<VirtBackupView> createState() => _VirtBackupViewState();
}

class _VirtBackupViewState extends ConsumerState<VirtBackupView>
    with _PaneRows<VirtBackupView>, _EditPane<VirtBackupView> {
  @override
  String get _serverId => widget.serverId;
  @override
  VirtGuest get _guest => widget.guest;
  @override
  VirtCapabilities get _caps => widget.caps;

  List<VirtBackup>? _backups;
  List<VirtBackupJob> _jobs = const [];
  List<VirtStoragePool> _storages = const [];
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

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _notes.dispose();
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
    return _buildEditPane(
      (hw, busy) => [
        _planGroup(busy),
        _listGroup(busy),
        if (_backups?.isNotEmpty ?? false) _runGroup(busy),
      ],
    );
  }

  bool get _live => _guest.state != VirtGuestState.stopped;

  // --- Plan ---

  _Group _planGroup(bool busy) {
    final job = _jobs.firstOrNull;
    return _Group(
      key: 'plan',
      title: l10n.virtBackupPlan,
      right: l10n.virtBackupPlanWhere,
      warn: false,
      indexNote: job?.schedule ?? l10n.virtBackupNoPlanShort,
      rows: [
        if (job == null) _text(l10n.virtBackupNoPlan),
        for (final j in _jobs) ...[
          _field(Icons.schedule, l10n.virtBackupSchedule, j.schedule ?? '-'),
          _field(Icons.storage_outlined, libL10n.storage, j.storage ?? '-'),
          if (j.keep case final keep?)
            _field(Icons.inventory_2_outlined, l10n.virtBackupKeep, keep),
          _field(
            Icons.compress,
            libL10n.mode,
            [?j.mode, ?j.compress].join(' · '),
          ),
          _field(
            Icons.group_outlined,
            l10n.virtBackupSelection,
            j.all
                ? j.exclude.isEmpty
                      ? l10n.virtBackupSelectionAll
                      : '${l10n.virtBackupSelectionAll} − ${j.exclude.join(', ')}'
                : j.pool != null
                ? 'pool:${j.pool}'
                : j.vmids.join(', '),
          ),
          if (j.node case final node?)
            _field(Icons.dns_outlined, l10n.virtBackupJobNode, node),
          if (!j.enabled) _text(l10n.virtBackupJobDisabled),
        ],
        if (job != null)
          _actions([
            _Action(
              l10n.virtBackupJobRun,
              key: 'plan:run',
              icon: Icons.play_arrow,
              onTap: busy || _working ? null : () => _runNow(job),
            ),
          ]),
      ],
    );
  }

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
        Input(
          key: const ValueKey('opt:notes'),
          controller: _notes,
          label: l10n.virtBackupNotes,
          icon: Icons.notes,
          enabled: !blocked,
          noWrap: true,
          maxLines: 3,
          minLines: 1,
        ),
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
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Input(
                key: ValueKey('$key:notes:field'),
                controller: notes,
                label: l10n.virtBackupEditNotes,
                icon: Icons.notes,
                noWrap: true,
                maxLines: 3,
                minLines: 1,
                enabled: !blocked,
              ),
            ),
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
        if (restoreTo != null || _storages.length > 1)
          _seg(
            Icons.storage_outlined,
            l10n.virtBackupRestoreStorage,
            [
              l10n.virtBackupRestoreStorageSame,
              for (final s in _storages) s.name,
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

  Future<void> _run(Future<void> Function() op, String done) async {
    setState(() {
      _working = true;
      _confirm = null;
    });
    try {
      await op();
      Toast.success(done);
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    } catch (e) {
      Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) setState(() => _working = false);
      await _load();
    }
  }

  Future<void> _backupNow(String target) => _run(
    () => _notifier.backup(
      _guest.id,
      VirtBackupRequest(
        storage: target,
        // A running guest keeps running; one that is off is copied as it is.
        mode: _live && _mode == 'snapshot' ? 'snapshot' : _mode,
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
      widget.onOpenGuest(id);
    }
  }
}
