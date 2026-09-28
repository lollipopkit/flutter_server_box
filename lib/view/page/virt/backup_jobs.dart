part of 'hardware.dart';

/// The datacenter's backup jobs — PVE's `/cluster/backup`, the list the
/// design points at with "数据中心 → 备份" from a guest's Plan group.
///
/// A job is the host's, not a guest's: it names the guests it takes (`all`
/// less `exclude`, a list of VMIDs, or a pool), the node it runs on, when
/// (a systemd calendar event), where its backups go, and what they are
/// (`mode`, `compress`, a notes template, protection, retention). This view
/// lists them, makes one, edits one, runs one now, and deletes one — the
/// five things PVE's own datacenter → Backup panel does.
///
/// **Why a section of its own** rather than a group in a guest's Backup
/// view: a job that takes every guest (or a pool) belongs to no guest, and
/// a guest's Plan group can only say "one of them takes you" — it edits a
/// job only when the job takes that guest alone, and opens any other one
/// here. The list is the same `SegmentedTabs` the Storage and Network
/// sections are, and it is offered where `VirtCapabilities.backupJobs` (PVE).
class VirtBackupJobList extends ConsumerWidget {
  const VirtBackupJobList({
    super.key,
    required this.serverId,
    required this.needle,
    required this.selectedId,
    required this.onOpen,
  });

  final String serverId;
  final String needle;
  final String? selectedId;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(virtBackupJobsProvider(serverId));
    final list = jobs.value;
    final shown = [
      for (final j in list ?? const <VirtBackupJob>[])
        if (needle.isEmpty ||
            j.id.toLowerCase().contains(needle) ||
            (j.storage ?? '').toLowerCase().contains(needle))
          j,
    ];
    return VirtResourceColumn(
      loading: jobs.isLoading,
      error: jobs.hasError ? jobs.error : null,
      onRefresh: () => ref.refresh(virtBackupJobsProvider(serverId).future),
      children: [
        if (list != null && list.isEmpty) CenterGreyTitle(l10n.virtBackupJobsNone),
        if (list != null && list.isNotEmpty && shown.isEmpty)
          CenterGreyTitle(libL10n.empty),
        for (final j in shown)
          VirtResourceRow(
            key: ValueKey('job:${j.id}'),
            icon: Icons.backup_outlined,
            active: j.enabled,
            name: j.id,
            meta: j.schedule ?? '',
            sub: [
              ?j.storage,
              ?j.mode,
              if (!j.enabled) libL10n.disabled,
            ].join(' · '),
            selected: j.id == selectedId,
            onTap: () => onOpen(j.id),
          ),
      ],
    );
  }
}

/// One backup job: what it takes, when, where its backups go, and what they
/// are — with Save, Run now and Delete.
///
/// The design has no editor for this (its Plan group is read-only); the
/// rows other than the node and the guests are a [_JobForm]'s, shared with
/// a guest's Plan group. The fields and their names are PVE's own (`schedule`, `storage`, `mode`,
/// `compress`, `vmid`/`all`, `enabled`, `mailnotification`, `notes-template`,
/// `prune-backups`, `node`), because a job made here is one PVE's own panel
/// then shows and edits.
class VirtBackupJobView extends ConsumerStatefulWidget {
  const VirtBackupJobView({
    super.key,
    required this.serverId,
    required this.jobId,
    this.leading,
    this.onSwitch,
    this.onDeleted,
  });

  final String serverId;

  /// The job's id; null makes a new one.
  final String? jobId;
  final Widget? leading;

  /// Moves to another job in place; null where the list is beside this.
  final ValueChanged<String>? onSwitch;

  /// The job was deleted: whatever showed it closes it.
  final VoidCallback? onDeleted;

  @override
  ConsumerState<VirtBackupJobView> createState() => _VirtBackupJobViewState();
}

class _VirtBackupJobViewState extends ConsumerState<VirtBackupJobView>
    with _PaneRows<VirtBackupJobView>, _JobFormRows<VirtBackupJobView> {
  String get _serverId => widget.serverId;
  bool get _isNew => widget.jobId == null;

  VirtHostNotifier get _notifier =>
      ref.read(virtHostProvider(_serverId).notifier);

  late final _form = _JobForm(() => setState(() {}));

  String? _node;
  var _all = true;

  /// The pool a job takes its guests from, kept as it was: the app does not
  /// list PVE's pools, so it is only ever the job's own. Null when the job
  /// takes all guests or a list, or when the user switched it to one.
  String? _pool;
  final _vmids = <int>{};
  final _exclude = <int>{};
  var _saving = false;
  var _confirmDelete = false;

  /// The form was filled from a job (or is new); it is not filled again.
  var _filled = false;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _fill(VirtBackupJob? job) {
    if (_filled) return;
    _filled = true;
    if (job == null) return;
    _form.fill(job);
    _node = job.node;
    _pool = job.pool;
    _all = job.pool == null && job.all;
    _vmids
      ..clear()
      ..addAll(job.vmids);
    _exclude
      ..clear()
      ..addAll(job.exclude);
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(virtBackupJobsProvider(_serverId));
    final all = jobs.value ?? const <VirtBackupJob>[];
    final job = widget.jobId == null
        ? null
        : all.firstWhereOrNull((j) => j.id == widget.jobId);
    if (!_isNew && job == null) {
      return Scaffold(
        appBar: _bar(all, null),
        body: jobs.isLoading
            ? const Center(child: SizedLoading.medium)
            : jobs.hasError
            ? ListView(
                padding: const EdgeInsets.all(13),
                children: [VirtErrCard(jobs.error!)],
              )
            : EmptyPane(icon: Icons.backup_outlined, label: libL10n.empty),
      );
    }
    _fill(job);
    return Scaffold(
      appBar: _bar(all, job),
      body: _buildPane(job),
    );
  }

  PreferredSizeWidget _bar(List<VirtBackupJob> all, VirtBackupJob? job) {
    final at = job == null ? -1 : all.indexOf(job);
    final onSwitch = widget.onSwitch;
    return virtResourceBar(
      name: job?.id ?? l10n.virtBackupJobNew,
      icon: Icons.backup_outlined,
      leading: widget.leading,
      position: onSwitch != null && at >= 0 ? at + 1 : null,
      total: onSwitch != null ? all.length : 0,
      onSwitch: onSwitch != null && all.length > 1
          ? () => unawaited(_pick(all, onSwitch))
          : null,
      onRefresh: () => ref.invalidate(virtBackupJobsProvider(_serverId)),
    );
  }

  Future<void> _pick(List<VirtBackupJob> all, ValueChanged<String> onPick) async {
    final picked = await showRowsSheet<String>(
      context,
      rows: (ctx) => [
        for (final j in all)
          ListTile(
            selected: j.id == widget.jobId,
            leading: const Icon(Icons.backup_outlined),
            title: Text(j.id, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(j.schedule ?? '', style: UIs.textGrey),
            onTap: () => Navigator.of(ctx).pop(j.id),
          ),
      ],
    );
    if (picked != null && picked != widget.jobId) onPick(picked);
  }

  /// Where the job's backups can go: see [_backupStoragesFor].
  List<VirtStoragePool> get _storages => _backupStoragesFor(
    ref.watch(virtBackupStoragesProvider(_serverId)).value ??
        const <VirtStoragePool>[],
    node: _node,
  );

  Widget _buildPane(VirtBackupJob? job) {
    final guestList = ref.watch(virtHostProvider(_serverId)).data?.guests ??
        const <VirtGuest>[];
    final storages = _storages;
    final nodes =
        ref.watch(virtHostProvider(_serverId)).data?.host.nodes ??
        const <VirtNode>[];
    final busy = _saving;
    final guests = _selectableGuests(guestList);
    final storage = _form.storageIn(storages);

    return _buildGroups(
      [
        _Group(
          key: 'when',
          title: l10n.virtBackupSchedule,
          right: '',
          warn: false,
          indexNote: _form.schedule.text.trim().isEmpty
              ? '-'
              : _form.schedule.text.trim(),
          rows: [
            ..._jobWhenRows(
              _form,
              key: 'job',
              busy: busy,
              onValidate: () => _checkSchedule(_form, _notifier),
            ),
            if (nodes.length > 1)
              _seg(
                Icons.dns_outlined,
                l10n.virtBackupJobNode,
                [
                  l10n.virtBackupJobNodeAny,
                  for (final n in nodes) n.name,
                ],
                _node ?? l10n.virtBackupJobNodeAny,
                key: 'job:node',
                onSelected: busy
                    ? null
                    : (v) => setState(() {
                        _node = v == l10n.virtBackupJobNodeAny ? null : v;
                        // A storage the node picked does not have is not
                        // where its backups can go.
                        if (!_storages.any((s) => s.name == _form.storage)) {
                          _form.storage = null;
                        }
                      }),
              ),
          ],
        ),
        _Group(
          key: 'what',
          title: libL10n.backup,
          right: '',
          warn: false,
          // The storage the row below shows, from the same list: a new job
          // has none picked, and the row shows the first it offers.
          indexNote: storage ?? l10n.virtBackupNoStorage,
          rows: _jobWhatRows(_form, storages, key: 'job', busy: busy),
        ),
        _Group(
          key: 'guests',
          title: l10n.virtBackupSelection,
          right: _selectionLabel,
          warn: false,
          indexNote: switch ((_pool, _all)) {
            (final pool?, _) => 'pool:$pool',
            (null, true) => _exclude.isEmpty
                ? l10n.virtBackupSelectionAll
                : '${l10n.virtBackupSelectionAll} − ${_exclude.length}',
            (null, false) => '${_vmids.length}',
          },
          rows: [
            _seg(
              Icons.group_outlined,
              l10n.virtBackupSelection,
              [
                l10n.virtBackupSelectionAll,
                l10n.virtBackupSelectionList,
                if (job?.pool case final pool?) 'pool:$pool',
              ],
              _selectionOption,
              key: 'job:all',
              onSelected: busy
                  ? null
                  : (v) => setState(() {
                      _pool = v == l10n.virtBackupSelectionAll ||
                              v == l10n.virtBackupSelectionList
                          ? null
                          : job?.pool;
                      _all = _pool == null && v == l10n.virtBackupSelectionAll;
                    }),
            ),
            // A pool's members are PVE's to say: nothing to pick.
            if (_pool == null && _all)
              _text(
                l10n.virtBackupExcludeTip,
              )
            else if (_pool == null && _vmids.isEmpty)
              _text(l10n.virtBackupSelectionNone, error: true),
            if (_pool == null)
              for (final g in guests)
                _toggle(
                g.kind == VirtGuestKind.lxc
                    ? Icons.inventory_2_outlined
                    : Icons.memory,
                g.name,
                _all ? !_exclude.contains(g.vmid) : _vmids.contains(g.vmid),
                key: 'job:guest:${g.id}',
                note: '${g.vmid} · ${g.kind.label}',
                onChanged: busy ? null : (on) => _pickGuest(g, on),
              ),
          ],
        ),
        _Group(
          key: 'actions',
          title: libL10n.save,
          right: '',
          warn: false,
          dot: Theme.of(context).colorScheme.error,
          indexNote: _isNew ? l10n.virtBackupJobNew : job?.id ?? '',
          rows: [
            if (_confirmDelete && !_isNew)
              _callout(
                l10n.virtSetDeleteAgain,
                l10n.virtBackupJobDeleteAsk(job!.id),
                key: const ValueKey('job:delete:confirm'),
              ),
            _actions([
              if (_confirmDelete && !_isNew)
                _Action(
                  libL10n.cancel,
                  icon: Icons.close,
                  onTap: () => setState(() => _confirmDelete = false),
                ),
              if (!_isNew)
                _Action(
                  _confirmDelete
                      ? l10n.virtBackupDeleteConfirm
                      : libL10n.delete,
                  key: 'job:delete',
                  icon: Icons.delete_outline,
                  danger: true,
                  onTap: busy ? null : () => _delete(job!),
                ),
              if (!_isNew)
                _Action(
                  l10n.virtBackupJobRun,
                  key: 'job:run',
                  icon: Icons.play_arrow,
                  onTap: busy || _confirmDelete ? null : () => _run(job!),
                ),
              _Action(
                _saving ? libL10n.loadingEllipsis : libL10n.save,
                key: 'job:save',
                primary: true,
                onTap: busy || !_canSave(storage) ? null : () => _save(),
              ),
            ]),
          ],
        ),
      ],
      onRefresh: () => ref.refresh(virtBackupJobsProvider(_serverId).future),
    );
  }

  String get _selectionLabel => switch ((_pool, _all)) {
    (final pool?, _) => 'pool:$pool',
    (null, true) => l10n.virtBackupSelectionAll,
    (null, false) => l10n.virtBackupSelected(_vmids.length),
  };

  /// Which of the selection segment's options is chosen: the option's own
  /// text, where [_selectionLabel] counts the guests of a list.
  String get _selectionOption => switch ((_pool, _all)) {
    (final pool?, _) => 'pool:$pool',
    (null, true) => l10n.virtBackupSelectionAll,
    (null, false) => l10n.virtBackupSelectionList,
  };

  bool _canSave(String? storage) =>
      _form.scheduleIssue == null &&
      storage != null &&
      (_pool != null || _all || _vmids.isNotEmpty);

  /// The guests a job can take: the host's, less a template (PVE refuses to
  /// back one up: `you can't backup a template`) and less a guest with no
  /// VMID, which a job names its guests by.
  List<VirtGuest> _selectableGuests(List<VirtGuest> guests) => [
    for (final g in guests)
      if (!g.template && g.vmid != null) g,
  ];

  void _pickGuest(VirtGuest g, bool on) {
    final vmid = g.vmid;
    if (vmid == null) return;
    setState(() {
      if (_all) {
        // `all` less what it leaves out.
        on ? _exclude.remove(vmid) : _exclude.add(vmid);
      } else {
        on ? _vmids.add(vmid) : _vmids.remove(vmid);
      }
    });
  }

  Future<void> _save() async {
    final storage = _form.storageIn(
      _backupStoragesFor(
        ref.read(virtBackupStoragesProvider(_serverId)).value ??
            const <VirtStoragePool>[],
        node: _node,
      ),
    );
    if (storage == null) return;
    setState(() => _saving = true);
    try {
      await _notifier.editBackupJob(
        _form.edit(
          id: widget.jobId,
          isNew: _isNew,
          node: _node,
          storage: storage,
          all: _all,
          pool: _pool,
          vmids: _all || _pool != null ? const [] : (_vmids.toList()..sort()),
          exclude: _all ? (_exclude.toList()..sort()) : const [],
        ),
      );
      Toast.success(l10n.virtBackupJobSaved);
      if (_isNew && mounted) widget.onDeleted?.call();
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    } catch (e, s) {
      Loggers.app.warning('Virtualization backup job', e, s);
      Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(VirtBackupJob job) async {
    if (!_confirmDelete) {
      setState(() => _confirmDelete = true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _notifier.editBackupJob(_removal(job), remove: true);
      Toast.success(l10n.virtBackupJobDeleted);
      widget.onDeleted?.call();
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    } catch (e, s) {
      Loggers.app.warning('Virtualizing backup job delete', e, s);
      Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _run(VirtBackupJob job) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.virtBackupJobRunAsk),
      actions: Btnx.cancelOk,
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _notifier.runBackupJob(job);
      Toast.success(l10n.virtBackupJobStarted);
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    } catch (e, s) {
      Loggers.app.warning('Virtualization backup job run', e, s);
      Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// What deletes [job]: `editBackupJob(..., remove: true)` reads only its id.
VirtBackupJobEdit _removal(VirtBackupJob job) => VirtBackupJobEdit(
  id: job.id,
  node: job.node,
  storage: job.storage ?? '',
  schedule: job.schedule ?? '',
);

/// Where a job's backups can go, one entry per storage name: the host lists
/// a storage once per node that has it. A job pinned to [node] is offered
/// that node's storages only; one that runs on any node, every storage some
/// node has.
List<VirtStoragePool> _backupStoragesFor(
  List<VirtStoragePool> all, {
  required String? node,
}) {
  final seen = <String>{};
  return [
    for (final s in all)
      if ((node == null || s.node == null || s.node == node) &&
          seen.add(s.name))
        s,
  ];
}

/// The fields of a backup job that are the job's own rather than whom it
/// takes: when it runs, whether it does, where its backups go and what they
/// are. Two editors fill them in — the datacenter's Backup section and a
/// guest's Plan group — with the same rows ([_JobFormRows]), so the same
/// input makes the same job from either.
final class _JobForm {
  _JobForm(this._onChanged) {
    schedule.addListener(_scheduleChanged);
  }

  /// The form's owner redraws: what the schedule field says about the host's
  /// last answer changed.
  final VoidCallback _onChanged;

  final schedule = TextEditingController();
  final notes = TextEditingController();
  final prune = TextEditingController();
  final comment = TextEditingController();

  /// Picked by the user or the job's own; null: the first storage offered,
  /// which is what the storage row shows ([storageIn]).
  String? storage;
  String mode = 'snapshot';
  String compress = 'zstd';
  String mail = 'failure';
  var enabled = true;

  /// What the host made of the schedule last asked about, and which value it
  /// answered for — a check runs when the field settles, not per keystroke.
  String? _checked;
  VirtScheduleCheck? check;

  void _scheduleChanged() {
    final value = schedule.text.trim();
    if (value == _checked) return;
    // What the host last said is about a value that is no longer typed.
    _checked = value;
    check = null;
    _onChanged();
  }

  void fill(VirtBackupJob job) {
    schedule.text = job.schedule ?? '';
    notes.text = job.notesTemplate ?? '';
    prune.text = job.prune ?? '';
    comment.text = job.comment ?? '';
    storage = job.storage;
    mode = job.mode ?? 'snapshot';
    compress = job.compress ?? 'zstd';
    mail = job.mailNotification ?? 'failure';
    enabled = job.enabled;
  }

  void dispose() {
    schedule.removeListener(_scheduleChanged);
    for (final c in [schedule, notes, prune, comment]) {
      c.dispose();
    }
  }

  VirtBackupScheduleIssue? get scheduleIssue => virtScheduleIssue(schedule.text);

  /// The storage the job writes to, of [offered]: the one picked, else the
  /// first — the storage row, the index and Save all read this, so none of
  /// them says something the others do not.
  String? storageIn(List<VirtStoragePool> offered) =>
      storage ?? offered.firstOrNull?.name;

  String? _opt(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  /// The job these fields and the selection given make.
  VirtBackupJobEdit edit({
    required String? id,
    required bool isNew,
    required String? node,
    required String storage,
    bool all = false,
    String? pool,
    List<int> vmids = const [],
    List<int> exclude = const [],
  }) => VirtBackupJobEdit(
    id: id,
    isNew: isNew,
    node: node,
    storage: storage,
    schedule: schedule.text.trim(),
    mode: mode,
    compress: compress,
    enabled: enabled,
    all: all,
    pool: pool,
    vmids: vmids,
    exclude: exclude,
    comment: _opt(comment),
    notesTemplate: _opt(notes),
    mailNotification: mail,
    prune: _opt(prune),
  );
}

/// The rows of a [_JobForm], keyed under a prefix (`job` in the Backup
/// section, `plan:<id>` in a guest's Plan group), and the schedule check
/// both editors offer.
mixin _JobFormRows<W extends ConsumerStatefulWidget>
    on ConsumerState<W>, _PaneRows<W> {
  /// When: the schedule, what it means, the host's check, and whether the
  /// job runs at all.
  List<Widget> _jobWhenRows(
    _JobForm f, {
    required String key,
    required bool busy,
    required VoidCallback onValidate,
    bool indent = false,
  }) {
    final issue = f.scheduleIssue;
    final scheduleError = switch (issue) {
      VirtBackupScheduleIssue.empty || null => null,
      VirtBackupScheduleIssue.invalid => l10n.virtBackupScheduleInvalid,
    };
    return [
      _inputRow([Input(
        key: ValueKey('$key:schedule'),
        controller: f.schedule,
        label: l10n.virtBackupSchedule,
        icon: Icons.schedule,
        noWrap: true,
        suggestion: false,
        enabled: !busy,
        // The host's own answer, once the field has settled: PVE's parser
        // is the authority on what a calendar event is.
        errorText: scheduleError ?? f.check?.error,
      )], indent: indent),
      _text(l10n.virtBackupScheduleHelp, indent: indent),
      if (f.check?.next case final times? when times.isNotEmpty)
        _text(
          l10n.virtBackupScheduleNext(
            times.take(3).map(_scheduleTime).join(', '),
          ),
          indent: indent,
        ),
      Padding(
        padding: EdgeInsets.only(left: indent ? _indent : 0),
        child: Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            Btn.row(
              key: ValueKey('$key:schedule:validate'),
              text: l10n.virtBackupScheduleValidate,
              icon: const Icon(Icons.rule, size: 17),
              onTap: busy || issue != null ? null : onValidate,
            ),
          ],
        ),
      ),
      _toggle(
        Icons.play_circle_outline,
        l10n.virtBackupEnabled,
        f.enabled,
        key: '$key:enabled',
        indent: indent,
        onChanged: busy ? null : (on) => setState(() => f.enabled = on),
      ),
    ];
  }

  /// What: where the backups go (of [storages]) and what they are.
  List<Widget> _jobWhatRows(
    _JobForm f,
    List<VirtStoragePool> storages, {
    required String key,
    required bool busy,
    bool indent = false,
  }) {
    return [
      if (storages.isEmpty)
        _text(l10n.virtBackupNoStorage, indent: indent)
      else
        _seg(
          Icons.storage_outlined,
          libL10n.storage,
          [for (final s in storages) s.name],
          f.storageIn(storages),
          key: '$key:storage',
          indent: indent,
          onSelected: busy ? null : (v) => setState(() => f.storage = v),
        ),
      _seg(
        Icons.restart_alt,
        libL10n.mode,
        const ['snapshot', 'suspend', 'stop'],
        f.mode,
        key: '$key:mode',
        indent: indent,
        onSelected: busy ? null : (v) => setState(() => f.mode = v),
      ),
      _seg(
        Icons.compress,
        l10n.virtBackupCompress,
        const ['zstd', 'lzo', 'gzip', '0'],
        f.compress,
        key: '$key:compress',
        indent: indent,
        onSelected: busy ? null : (v) => setState(() => f.compress = v),
      ),
      _seg(
        Icons.mail_outline,
        l10n.virtBackupMail,
        const ['failure', 'always'],
        f.mail,
        key: '$key:mail',
        indent: indent,
        onSelected: busy ? null : (v) => setState(() => f.mail = v),
      ),
      _inputRow([Input(
        key: ValueKey('$key:notes'),
        controller: f.notes,
        label: l10n.virtBackupNotesTemplate,
        icon: Icons.notes,
        noWrap: true,
        maxLines: 3,
        minLines: 1,
        enabled: !busy,
      )], indent: indent),
      _text(l10n.virtBackupNotesTemplateTip(virtBackupNotesVars), indent: indent),
      _inputRow([Input(
        key: ValueKey('$key:prune'),
        controller: f.prune,
        label: l10n.virtBackupPrune,
        icon: Icons.inventory_2_outlined,
        noWrap: true,
        suggestion: false,
        enabled: !busy,
      )], indent: indent),
      _text(l10n.virtBackupPruneTip, indent: indent),
      _inputRow([Input(
        key: ValueKey('$key:comment'),
        controller: f.comment,
        label: libL10n.description,
        hint: libL10n.optional,
        icon: Icons.label_outline,
        noWrap: true,
        enabled: !busy,
      )], indent: indent),
    ];
  }

  /// Asks the host what it makes of [f]'s schedule — PVE's own parser,
  /// through the call its job editor's "Simulate" button makes. Its answer
  /// is shown either way: the runs it would make, or its refusal in its
  /// words.
  Future<void> _checkSchedule(_JobForm f, VirtHostNotifier notifier) async {
    final schedule = f.schedule.text.trim();
    setState(() => f.check = null);
    try {
      final check = await notifier.checkSchedule(schedule);
      // An answer about a value that has since been typed over is dropped.
      if (mounted && f.schedule.text.trim() == schedule) {
        setState(() => f.check = check);
      }
    } on VirtErr catch (e) {
      if (mounted) Toast.error(e.title, body: e.detail);
    }
  }
}

/// A run the host computed, as the schedule's "next runs" line lists it.
String _scheduleTime(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.month}-${l.day} ${two(l.hour)}:${two(l.minute)}';
}

/// A page of a backup job, for a window with room for one column.
final class VirtBackupJobArgs {
  const VirtBackupJobArgs({required this.serverId, this.jobId});

  final String serverId;

  /// Null makes a new one.
  final String? jobId;
}

class VirtBackupJobPage extends StatefulWidget {
  const VirtBackupJobPage({super.key, required this.args});

  final VirtBackupJobArgs args;

  static const route = AppRouteArg<void, VirtBackupJobArgs>(
    page: VirtBackupJobPage.new,
    path: '/virt/backup-job',
  );

  @override
  State<VirtBackupJobPage> createState() => _VirtBackupJobPageState();
}

class _VirtBackupJobPageState extends State<VirtBackupJobPage> {
  late String? _jobId = widget.args.jobId;

  @override
  Widget build(BuildContext context) {
    return VirtBackupJobView(
      key: ValueKey('job:$_jobId'),
      serverId: widget.args.serverId,
      jobId: _jobId,
      leading: const BackButton(),
      onSwitch: (id) => setState(() => _jobId = id),
      onDeleted: () => Navigator.of(context).maybePop(),
    );
  }
}

/// The variables PVE replaces inside a job's notes template
/// (`PVE::Utils::notesTemplateVars`).
const virtBackupNotesVars = '{{guestname}}, {{vmid}}, {{node}}, {{cluster}}';
