part of 'hardware.dart';

/// A guest's backups — the design's Backup view (PVE): the scheduled jobs
/// that take it, read only, and its backups, with backing up now, restoring
/// (over it, or as a new guest) and deleting.
///
/// The same pane as the Hardware view, so the groups and their index read
/// alike; what it lists is its own read, again after every operation.
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
    with _EditPane<VirtBackupView> {
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
  var _working = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
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
      });
    } on ParallelWaitError<(List<VirtBackup>?, List<VirtBackupJob>?, List<VirtStoragePool>?), dynamic> catch (e) {
      if (mounted) setState(() => _error = e.errors.$1 ?? e.errors.$2 ?? e.errors.$3);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error case final e?) return _buildError(e);
    if (_backups == null) return const Center(child: SizedLoading.medium);
    return _buildEditPane((hw, busy) => [_planGroup(), _listGroup(busy)]);
  }

  bool get _live => _guest.state != VirtGuestState.stopped;

  // --- Plan ---

  _Group _planGroup() {
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
          _field(Icons.schedule, libL10n.time, j.schedule ?? '-'),
          _field(Icons.storage_outlined, libL10n.storage, j.storage ?? '-'),
          if (j.keep case final keep?)
            _field(Icons.inventory_2_outlined, l10n.virtBackupKeep, keep),
          _field(
            Icons.compress,
            libL10n.mode,
            [?j.mode, ?j.compress].join(' · '),
          ),
          if (!j.enabled) _text(l10n.virtBackupJobDisabled),
        ],
      ],
    );
  }

  // --- Backups ---

  /// Where "Back up now" writes: the storage the guest's job uses, else the
  /// first that holds backups.
  VirtStoragePool? get _target {
    final wanted = _jobs.map((j) => j.storage).nonNulls.toSet();
    return _storages.firstWhereOrNull((s) => wanted.contains(s.name)) ??
        _storages.firstOrNull;
  }

  _Group _listGroup(bool busy) {
    final backups = _backups ?? const <VirtBackup>[];
    final target = _target;
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
    return [
      _disc(key, Icons.backup_outlined, _when(b), summary),
      if (_open.contains(key)) ...[
        _field(Icons.description_outlined, libL10n.file, b.fileName, mono: true, indent: true),
        if (b.notes case final notes?)
          _field(Icons.notes, l10n.virtBackupNotes, notes, indent: true),
        if (b.protected) _text(l10n.virtBackupProtected, indent: true),
        if (b.verification case final v?)
          _text(l10n.virtBackupVerified(v), indent: true, error: v != 'ok'),
        if (_live)
          _callout(
            l10n.virtBackupRestoreOverwrites,
            l10n.virtBackupStopFirst,
            indent: true,
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
      ],
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

  Future<void> _backupNow(VirtStoragePool target) => _run(
    () => _notifier.backup(
      _guest.id,
      VirtBackupRequest(
        storage: target.name,
        // A running guest keeps running; one that is off is copied as it is.
        mode: _live ? 'snapshot' : 'stop',
      ),
    ),
    l10n.virtBackupDone,
  );

  Future<void> _delete(VirtBackup b) async {
    if (_confirm != 'delete:${b.id}') {
      setState(() => _confirm = 'delete:${b.id}');
      return;
    }
    await _run(
      () => _notifier.deleteBackup(_guest.id, b),
      l10n.virtBackupDeleted,
    );
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

  /// As the next free VMID; the new guest is opened once it is there.
  Future<void> _restoreNew(VirtBackup b) async {
    final kind = b.kind ?? _guest.kind;
    String? id;
    await _run(() async {
      final vmid = await _notifier.nextVmid();
      if (vmid == null) {
        throw const VirtErr(type: VirtErrType.invalidResponse);
      }
      await _notifier.restoreBackup(_guest.id, b, vmid: vmid);
      id = '${kind == VirtGuestKind.lxc ? 'lxc' : 'qemu'}/$vmid';
    }, l10n.virtBackupRestored(_when(b)));
    if (id case final id? when mounted) {
      await _notifier.refresh();
      widget.onOpenGuest(id);
    }
  }
}
