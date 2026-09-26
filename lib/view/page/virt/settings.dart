part of 'hardware.dart';

/// A guest's settings — the design's Settings view: what the guest is called
/// and noted as, whether it starts with the host, PVE's protection, cloning
/// it, and deleting it.
///
/// The same pane and the same hardware read as the Hardware view: a setting
/// the running guest takes only at its next start (a container's hostname)
/// is pending there too, and every change is sent back with the revision it
/// was made from. The design's Migrate group is a later phase.
class VirtSettingsView extends ConsumerStatefulWidget {
  const VirtSettingsView({
    super.key,
    required this.serverId,
    required this.guest,
    required this.caps,
    required this.onDelete,
    required this.onCloned,
  });

  final String serverId;
  final VirtGuest guest;
  final VirtCapabilities caps;

  /// Deletes the guest, and its disks with it or not. The guest view owns
  /// what follows: the toast, closing what showed it.
  final Future<void> Function({required bool removeDisks}) onDelete;

  /// The clone with this id was made: the guest view opens it.
  final ValueChanged<String> onCloned;

  @override
  ConsumerState<VirtSettingsView> createState() => _VirtSettingsViewState();
}

class _VirtSettingsViewState extends ConsumerState<VirtSettingsView>
    with _PaneRows<VirtSettingsView>, _EditPane<VirtSettingsView> {
  @override
  String get _serverId => widget.serverId;
  @override
  VirtGuest get _guest => widget.guest;
  @override
  VirtCapabilities get _caps => widget.caps;

  final _name = TextEditingController();
  final _desc = TextEditingController();
  late final _cloneName = TextEditingController(text: '${_guest.name}-clone');

  /// The design's Full clone (PVE) / Copy disk contents (libvirt).
  var _cloneFull = true;
  var _cloning = false;

  /// What [_name] and [_desc] were last filled from. A read that brings a
  /// different value refills a field the user has not changed, and leaves
  /// one they have.
  String? _nameBase;
  String? _descBase;

  var _removeDisks = true;

  /// The design's two-step delete: the first press asks, the second deletes.
  var _confirmDelete = false;
  var _deleting = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _cloneName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildEditPane(_groups);

  void _sync(VirtHardware hw) {
    final name = hw.name ?? _guest.name;
    if (_nameBase != name) {
      if (_nameBase == null || _name.text == _nameBase) _name.text = name;
      _nameBase = name;
    }
    final desc = hw.description ?? '';
    if (_descBase != desc) {
      if (_descBase == null || _desc.text == _descBase) _desc.text = desc;
      _descBase = desc;
    }
  }

  List<_Group> _groups(VirtHardware hw, bool busy) {
    _sync(hw);
    return [
      _generalGroup(hw, busy),
      if (_caps.clone) _cloneGroup(busy),
      if (_caps.create) _deleteGroup(hw, busy),
    ];
  }

  // --- General ---

  _Group _generalGroup(VirtHardware hw, bool busy) {
    final name = _name.text.trim();
    final nameChanged = name != _nameBase;
    final taken =
        nameChanged &&
        (ref.read(virtHostProvider(_serverId)).data?.guests ??
                const <VirtGuest>[])
            .any((g) => g.id != _guest.id && g.name == name);
    final nameIssue = !nameChanged
        ? null
        : taken
        ? l10n.virtCreateNameTaken
        : _issueText(hw, virtHwIssue(hw, VirtHwSetName(name), host: _host));
    final renameLocked = hw.running && !hw.renameRunning;
    final desc = _desc.text;
    final descChanged = desc != _descBase;
    final descIssue = descChanged
        ? _issueText(hw, virtHwIssue(hw, VirtHwSetDescription(desc)))
        : null;
    final waits = _waits(hw);
    return _Group(
      key: 'general',
      title: libL10n.general,
      right: waits ? l10n.virtHwLater : '',
      warn: waits,
      indexNote: hw.autostart ? l10n.virtHwAutostart : l10n.virtSetManualStart,
      rows: [
        Input(
          key: const ValueKey('set:name'),
          controller: _name,
          label: _lxc ? l10n.virtHostname : libL10n.name,
          icon: Icons.label_outline,
          noWrap: true,
          suggestion: false,
          enabled: !renameLocked && !busy,
          errorText: nameIssue,
          onChanged: (_) => setState(() {}),
        ),
        if (renameLocked) _text(l10n.virtSetRenameStopped),
        if (nameChanged)
          _actions([
            _Action(
              libL10n.cancel,
              icon: Icons.close,
              onTap: () => setState(() => _name.text = _nameBase ?? ''),
            ),
            _Action(
              libL10n.save,
              key: 'set:name:save',
              primary: true,
              onTap: busy || nameIssue != null || renameLocked
                  ? null
                  : () => _apply(hw, VirtHwSetName(name)),
            ),
          ]),
        Input(
          key: const ValueKey('set:desc'),
          controller: _desc,
          label: libL10n.description,
          hint: libL10n.optional,
          icon: Icons.notes,
          maxLines: 5,
          minLines: 1,
          noWrap: true,
          enabled: !busy,
          errorText: descIssue,
          onChanged: (_) => setState(() {}),
        ),
        if (descChanged)
          _actions([
            _Action(
              libL10n.cancel,
              icon: Icons.close,
              onTap: () => setState(() => _desc.text = _descBase ?? ''),
            ),
            _Action(
              libL10n.save,
              key: 'set:desc:save',
              primary: true,
              onTap: busy || descIssue != null
                  ? null
                  : () => _apply(hw, VirtHwSetDescription(desc)),
            ),
          ]),
        _toggle(
          Icons.power_settings_new,
          l10n.virtHwAutostart,
          hw.autostart,
          key: 'autostart',
          note: _pve ? l10n.virtHwAutostartPve : 'virsh autostart',
          onChanged: busy ? null : (on) => _apply(hw, VirtHwSetAutostart(on)),
        ),
        if (hw.protection case final protected?)
          _toggle(
            Icons.lock_outline,
            l10n.virtSetProtection,
            protected,
            key: 'protection',
            note: l10n.virtSetProtectionNote,
            onChanged: busy
                ? null
                : (on) => _apply(hw, VirtHwSetProtection(on)),
          ),
        ..._pendingRows(
          hw,
          busy,
          (p) => _placeOf(hw, p.key) == _PendingPlace.settings,
        ),
      ],
    );
  }

  bool _waits(VirtHardware hw) =>
      hw.running &&
      hw.pending.any((p) => _placeOf(hw, p.key) == _PendingPlace.settings);

  // --- Clone ---

  _Group _cloneGroup(bool busy) {
    final name = _cloneName.text.trim();
    final taken = (ref.read(virtHostProvider(_serverId)).data?.guests ??
            const <VirtGuest>[])
        .any((g) => g.name == name);
    final issue = taken
        ? l10n.virtCreateNameTaken
        : switch (virtCloneNameIssue(name, _host)) {
            null => null,
            // Nothing to say yet: the button waits for a name.
            VirtCreateIssue.nameEmpty => null,
            _ =>
              _pve
                  ? l10n.virtCreateNameInvalidPve
                  : l10n.virtCreateNameInvalidLibvirt,
          };
    // libvirt copies a disk only while nothing writes to it; PVE clones a
    // running guest through a snapshot of its own.
    final stopFirst = !_pve && _guest.state != VirtGuestState.stopped;
    // PVE links a clone only to a template's disks; anything else is full.
    final canLink = _caps.linkedClone && _guest.template;
    final full = _pve && !canLink ? true : _cloneFull;
    return _Group(
      key: 'clone',
      title: libL10n.clone,
      right: '',
      warn: false,
      indexNote: full
          ? l10n.virtCloneFullShort
          : _pve
          ? l10n.virtCloneLinkedShort
          : l10n.virtCloneEmptyShort,
      rows: [
        Input(
          key: const ValueKey('clone:name'),
          controller: _cloneName,
          label: l10n.virtCloneName,
          icon: Icons.content_copy_outlined,
          noWrap: true,
          suggestion: false,
          enabled: !_cloning,
          errorText: issue,
          onChanged: (_) => setState(() {}),
        ),
        _toggle(
          Icons.file_copy_outlined,
          _pve ? l10n.virtCloneFull : l10n.virtCloneCopyDisks,
          full,
          key: 'clone:full',
          note: !_pve
              ? l10n.virtCloneEmptyNote
              : canLink
              ? l10n.virtCloneLinkedNote
              : l10n.virtCloneFullOnly,
          onChanged: _cloning || (_pve && !canLink)
              ? null
              : (on) => setState(() => _cloneFull = on),
        ),
        if (stopFirst) _text(l10n.virtCloneStopFirst),
        _actions([
          _Action(
            _cloning ? l10n.virtCloning : libL10n.clone,
            key: 'clone:go',
            primary: true,
            onTap: name.isEmpty || issue != null || stopFirst || busy || _cloning
                ? null
                : () => _onClone(name, full),
          ),
        ]),
      ],
    );
  }

  Future<void> _onClone(String name, bool full) async {
    setState(() => _cloning = true);
    try {
      final id = await _notifier.clone(
        _guest.id,
        VirtCloneRequest(name: name, full: full),
      );
      Toast.success(l10n.virtCloned(name));
      if (mounted) widget.onCloned(id);
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    } catch (e) {
      Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) setState(() => _cloning = false);
    }
  }

  // --- Delete ---

  _Group _deleteGroup(VirtHardware hw, bool busy) {
    final running = _guest.state != VirtGuestState.stopped;
    final protected = hw.protection ?? false;
    final blocked = running || protected || busy || _deleting;
    final volumes = [
      for (final d in hw.disks)
        if (d.kind != VirtHwDiskKind.cdrom && d.source != null) d.source!,
    ];
    return _Group(
      key: 'delete',
      title: libL10n.delete,
      right: '',
      warn: false,
      dot: Theme.of(context).colorScheme.error,
      indexNote: l10n.virtSetIrreversible,
      rows: [
        if (_caps.deleteKeepsDisks)
          _toggle(
            Icons.delete_sweep_outlined,
            l10n.virtDeleteDisks,
            _removeDisks,
            key: 'delete:disks',
            note: volumes.isEmpty ? null : volumes.join(', '),
            onChanged: _deleting
                ? null
                : (on) => setState(() => _removeDisks = on),
          )
        else
          _text(l10n.virtDeleteDisksPve),
        if (running) _text(l10n.virtSetDeleteStopFirst),
        if (protected) _text(l10n.virtSetDeleteProtected),
        if (_confirmDelete && !blocked)
          _box(
            key: const ValueKey('delete:callout'),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                UIs.width13,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.virtSetDeleteAgain,
                        style: UIs.text13.copyWith(fontWeight: FontWeight.w500),
                      ),
                      Text(l10n.virtSetIrreversible, style: UIs.text12Grey),
                    ],
                  ),
                ),
              ],
            ),
          ),
        _actions([
          if (_confirmDelete && !blocked)
            _Action(
              libL10n.cancel,
              icon: Icons.close,
              onTap: () => setState(() => _confirmDelete = false),
            ),
          _Action(
            _confirmDelete && !blocked
                ? l10n.virtSetDeleteConfirm(_guest.name)
                : _lxc
                ? l10n.virtSetDeleteLxc
                : l10n.virtSetDeleteVm,
            key: 'delete:go',
            icon: Icons.delete_outline,
            danger: true,
            onTap: blocked ? null : () => _onDelete(hw),
          ),
        ]),
      ],
    );
  }

  Future<void> _onDelete(VirtHardware hw) async {
    if (!_confirmDelete) {
      setState(() => _confirmDelete = true);
      return;
    }
    setState(() => _deleting = true);
    try {
      await widget.onDelete(
        removeDisks: !_caps.deleteKeepsDisks || _removeDisks,
      );
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
          _confirmDelete = false;
        });
      }
    }
  }
}
