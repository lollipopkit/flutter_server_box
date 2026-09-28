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
/// a guest's Plan group can only say "one of them takes you". The list is
/// the same `SegmentedTabs` the Storage and Network sections are, and it is
/// offered where `VirtCapabilities.backupJobs` (PVE).
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
/// fields and their names are PVE's own (`schedule`, `storage`, `mode`,
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
    with _PaneRows<VirtBackupJobView> {
  String get _serverId => widget.serverId;
  bool get _isNew => widget.jobId == null;

  VirtHostNotifier get _notifier =>
      ref.read(virtHostProvider(_serverId).notifier);

  final _schedule = TextEditingController();
  final _notes = TextEditingController();
  final _prune = TextEditingController();
  final _comment = TextEditingController();

  String? _storage;
  String _mode = 'snapshot';
  String _compress = 'zstd';
  String? _node;
  String _mail = 'failure';
  var _enabled = true;
  var _all = true;

  /// The pool a job takes its guests from, kept as it was: the app does not
  /// list PVE's pools, so it is only ever the job's own. Null when the job
  /// takes all guests or a list, or when the user switched it to one.
  String? _pool;
  final _vmids = <int>{};
  final _exclude = <int>{};
  var _saving = false;
  var _confirmDelete = false;

  /// What the host made of the schedule last asked about, and which value it
  /// answered for — a check runs when the field settles, not per keystroke.
  String? _checked;
  VirtScheduleCheck? _check;

  /// The form was filled from a job (or is new); it is not filled again.
  var _filled = false;

  @override
  void initState() {
    super.initState();
    _schedule.addListener(_scheduleChanged);
  }

  @override
  void dispose() {
    _schedule.removeListener(_scheduleChanged);
    for (final c in [_schedule, _notes, _prune, _comment]) {
      c.dispose();
    }
    super.dispose();
  }

  void _scheduleChanged() {
    final value = _schedule.text.trim();
    if (value == _checked) return;
    // What the host last said is about a value that is no longer typed.
    _checked = value;
    _check = null;
    setState(() {});
  }

  void _fill(VirtBackupJob? job) {
    if (_filled) return;
    _filled = true;
    if (job == null) return;
    _schedule.text = job.schedule ?? '';
    _notes.text = job.notesTemplate ?? '';
    _prune.text = job.prune ?? '';
    _comment.text = job.comment ?? '';
    _storage = job.storage;
    _mode = job.mode ?? 'snapshot';
    _compress = job.compress ?? 'zstd';
    _node = job.node;
    _mail = job.mailNotification ?? 'failure';
    _enabled = job.enabled;
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

  Widget _buildPane(VirtBackupJob? job) {
    final guestList = ref.watch(virtHostProvider(_serverId)).data?.guests ??
        const <VirtGuest>[];
    final storages = _storagesFor(
      ref.watch(virtBackupStoragesProvider(_serverId)).value ??
          const <VirtStoragePool>[],
    );
    final nodes =
        ref.watch(virtHostProvider(_serverId)).data?.host.nodes ??
        const <VirtNode>[];
    final busy = _saving;

    final scheduleIssue = virtScheduleIssue(_schedule.text);
    final scheduleError = switch (scheduleIssue) {
      VirtBackupScheduleIssue.empty || null => null,
      VirtBackupScheduleIssue.invalid => l10n.virtBackupScheduleInvalid,
    };
    // The host's own answer, once the field has settled: PVE's parser is the
    // authority on what a calendar event is.
    final hostError = _check?.error;
    final guests = _selectableGuests(guestList);

    return _buildGroups(
      [
        _Group(
          key: 'when',
          title: l10n.virtBackupSchedule,
          right: '',
          warn: false,
          indexNote: _schedule.text.trim().isEmpty
              ? '-'
              : _schedule.text.trim(),
          rows: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Input(
                key: const ValueKey('job:schedule'),
                controller: _schedule,
                label: l10n.virtBackupSchedule,
                icon: Icons.schedule,
                noWrap: true,
                suggestion: false,
                enabled: !busy,
                errorText: scheduleError ?? hostError,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 13, bottom: 7),
              child: Text(l10n.virtBackupScheduleHelp, style: UIs.text12Grey),
            ),
            if (_check?.next case final times? when times.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 13, bottom: 7),
                child: Text(
                  l10n.virtBackupScheduleNext(
                    times
                        .take(3)
                        .map(
                          (t) =>
                              '${t.toLocal().month}-${t.toLocal().day} '
                              '${t.toLocal().hour.toString().padLeft(2, '0')}:'
                              '${t.toLocal().minute.toString().padLeft(2, '0')}',
                        )
                        .join(', '),
                  ),
                  style: UIs.text12Grey,
                ),
              ),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                Btn.row(
                  key: const ValueKey('job:schedule:validate'),
                  text: l10n.virtBackupScheduleValidate,
                  icon: const Icon(Icons.rule, size: 17),
                  onTap: busy || scheduleIssue != null
                      ? null
                      : () => unawaited(_validate()),
                ),
              ],
            ),
            _toggle(
              Icons.play_circle_outline,
              l10n.virtBackupEnabled,
              _enabled,
              key: 'job:enabled',
              onChanged: busy ? null : (on) => setState(() => _enabled = on),
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
                        final all =
                            ref.read(virtBackupStoragesProvider(_serverId)).value ??
                            const <VirtStoragePool>[];
                        if (!_storagesFor(all).any((s) => s.name == _storage)) {
                          _storage = null;
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
          indexNote: _storage ?? l10n.virtBackupNoStorage,
          rows: [
            if (storages.isEmpty)
              _text(l10n.virtBackupNoStorage)
            else
              _seg(
                Icons.storage_outlined,
                libL10n.storage,
                [for (final s in storages) s.name],
                _storage ?? storages.first.name,
                key: 'job:storage',
                onSelected: busy ? null : (v) => setState(() => _storage = v),
              ),
            _seg(
              Icons.restart_alt,
              libL10n.mode,
              const ['snapshot', 'suspend', 'stop'],
              _mode,
              key: 'job:mode',
              onSelected: busy ? null : (v) => setState(() => _mode = v),
            ),
            _seg(
              Icons.compress,
              l10n.virtBackupCompress,
              const ['zstd', 'lzo', 'gzip', '0'],
              _compress,
              key: 'job:compress',
              onSelected: busy ? null : (v) => setState(() => _compress = v),
            ),
            _seg(
              Icons.mail_outline,
              l10n.virtBackupMail,
              const ['failure', 'always'],
              _mail,
              key: 'job:mail',
              onSelected: busy ? null : (v) => setState(() => _mail = v),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Input(
                key: const ValueKey('job:notes'),
                controller: _notes,
                label: l10n.virtBackupNotesTemplate,
                icon: Icons.notes,
                noWrap: true,
                maxLines: 3,
                minLines: 1,
                enabled: !busy,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 13, bottom: 7),
              child: Text(
                l10n.virtBackupNotesTemplateTip(virtBackupNotesVars),
                style: UIs.text12Grey,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Input(
                key: const ValueKey('job:prune'),
                controller: _prune,
                label: l10n.virtBackupPrune,
                icon: Icons.inventory_2_outlined,
                noWrap: true,
                suggestion: false,
                enabled: !busy,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 13, bottom: 7),
              child: Text(l10n.virtBackupPruneTip, style: UIs.text12Grey),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Input(
                key: const ValueKey('job:comment'),
                controller: _comment,
                label: libL10n.description,
                hint: libL10n.optional,
                icon: Icons.label_outline,
                noWrap: true,
                enabled: !busy,
              ),
            ),
          ],
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
                onTap: busy || scheduleIssue != null || !_canSave(storages)
                    ? null
                    : () => _save(),
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

  /// Where the job's backups can go, one entry per storage name: the
  /// host lists a storage once per node that has it. A job pinned to a node
  /// is offered that node's storages only; one that runs on any node, every
  /// storage some node has.
  List<VirtStoragePool> _storagesFor(List<VirtStoragePool> all) {
    final node = _node;
    final seen = <String>{};
    return [
      for (final s in all)
        if ((node == null || s.node == null || s.node == node) &&
            seen.add(s.name))
          s,
    ];
  }

  bool _canSave(List<VirtStoragePool> storages) =>
      storages.isNotEmpty && (_pool != null || _all || _vmids.isNotEmpty);

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

  /// Asks the host what it makes of the schedule — PVE's own parser, through
  /// the call its job editor's "Simulate" button makes. Its answer is shown
  /// either way: the runs it would make, or its refusal in its words.
  Future<void> _validate() async {
    final schedule = _schedule.text.trim();
    setState(() => _check = null);
    try {
      final check = await _notifier.checkSchedule(schedule);
      // An answer about a value that has since been typed over is dropped.
      if (mounted && _schedule.text.trim() == schedule) {
        setState(() => _check = check);
      }
    } on VirtErr catch (e) {
      if (mounted) Toast.error(e.title, body: e.detail);
    }
  }

  VirtBackupJobEdit _edit(List<VirtStoragePool> storages) {
    final storage = _storage ?? storages.first.name;
    return VirtBackupJobEdit(
      id: widget.jobId,
      isNew: _isNew,
      node: _node,
      storage: storage,
      schedule: _schedule.text.trim(),
      mode: _mode,
      compress: _compress,
      enabled: _enabled,
      all: _all,
      pool: _pool,
      vmids: _all || _pool != null ? const [] : (_vmids.toList()..sort()),
      exclude: _all ? (_exclude.toList()..sort()) : const [],
      comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
      notesTemplate: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      mailNotification: _mail,
      prune: _prune.text.trim().isEmpty ? null : _prune.text.trim(),
    );
  }

  Future<void> _save() async {
    final storages = _storagesFor(
      ref.read(virtBackupStoragesProvider(_serverId)).value ??
          const <VirtStoragePool>[],
    );
    if (storages.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _notifier.editBackupJob(_edit(storages));
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
      await _notifier.editBackupJob(
        VirtBackupJobEdit(
          id: job.id,
          node: job.node,
          storage: job.storage ?? '',
          schedule: job.schedule ?? '',
        ),
        remove: true,
      );
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
