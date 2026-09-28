part of 'hardware.dart';

/// A guest's settings — the design's Settings view: what the guest is called
/// and noted as, whether it starts with the host, PVE's protection, its
/// cloud-init (a VM with a cloud-init drive; the design has no place for
/// it), cloning it, and deleting it.
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

  /// The pool a libvirt clone's disks go in, the storage a PVE one's do, and
  /// the node a PVE clone is made on — null for each source's own. The
  /// storage and the node are PVE's `storage` and `target`; both are read
  /// from the host's own lists, so the form offers only what is there.
  String? _cloneStorage;
  String? _cloneNode;

  /// The guest is being turned into a template.
  var _toTemplate = false;

  /// What [_name] and [_desc] were last filled from. A read that brings a
  /// different value refills a field the user has not changed, and leaves
  /// one they have.
  String? _nameBase;
  String? _descBase;

  var _removeDisks = true;

  // cloud-init: a draft of the settings [_ciBase] was filled from.
  final _ciUser = TextEditingController();
  final _ciPassword = TextEditingController();
  final _ciKeys = TextEditingController();
  final _ciHostname = TextEditingController();
  final _ciAddress = TextEditingController();
  final _ciGateway = TextEditingController();
  final _ciDns = TextEditingController();
  final _ciSearch = TextEditingController();
  var _ciExpire = false;
  var _ciStatic = false;
  var _ciRemovePassword = false;
  var _ciSaving = false;
  VirtCloudInitState? _ciBase;

  /// The design's two-step delete: the first press asks, the second deletes.
  var _confirmDelete = false;
  var _deleting = false;

  @override
  void dispose() {
    for (final c in [
      _name, _desc, _cloneName, _ciUser, _ciPassword, _ciKeys, _ciHostname, //
      _ciAddress, _ciGateway, _ciDns, _ciSearch,
    ]) {
      c.dispose();
    }
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
      if (!_lxc && hw.disks.any((d) => d.cloudInit)) _cloudInitGroup(busy),
      if (_caps.template && !_guest.template) _templateGroup(hw, busy),
      if (_caps.clone) _cloneGroup(hw, busy),
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
        _inputRow([Input(
          key: const ValueKey('set:name'),
          controller: _name,
          label: _lxc ? l10n.virtHostname : libL10n.name,
          icon: Icons.label_outline,
          noWrap: true,
          suggestion: false,
          enabled: !renameLocked && !busy,
          errorText: nameIssue,
          onChanged: (_) => setState(() {}),
        )]),
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
        _inputRow([Input(
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
        )]),
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

  // --- Template ---

  /// PVE's "convert to template", offered once and never undone: the dialog
  /// says so, since PVE has no way back (`POST .../template` writes
  /// `template: 1` and turns each disk into a base image).
  ///
  /// The design has no group for this — its list has no template state
  /// either — and it lives here because it is a setting of the guest rather
  /// than an action on it: PVE's own web UI puts it under "More", beside
  /// Clone, and it is the one change that decides what the guest *is*.
  _Group _templateGroup(VirtHardware hw, bool busy) {
    final running = _guest.state != VirtGuestState.stopped;
    // PVE refuses a guest with snapshots. Only known where the Snapshots
    // view has read them this session; otherwise the host says so itself
    // when the request is made.
    final snapCount = _readSnapshotCount();
    final snaps = snapCount != null && snapCount != 0;
    final blocked = running || snaps || busy || _toTemplate;
    return _Group(
      key: 'template',
      title: l10n.virtToTemplate,
      right: '',
      warn: false,
      indexNote: snaps
          ? l10n.virtToTemplateSnapshots
          : running
          ? l10n.virtToTemplateStopped
          : l10n.virtToTemplateIrreversible,
      rows: [
        _text(l10n.virtToTemplateNote),
        if (running) _text(l10n.virtToTemplateStopped),
        if (snaps) _text(l10n.virtToTemplateSnapshots),
        _actions([
          _Action(
            l10n.virtToTemplate,
            key: 'template:go',
            icon: Icons.inventory_2_outlined,
            onTap: blocked ? null : () => _onTemplate(hw),
          ),
        ]),
      ],
    );
  }

  /// How many snapshots the guest has, where the Snapshots view has read
  /// them this session — the same trick the pending banner uses, so opening
  /// Settings is not a round trip of its own.
  int? _readSnapshotCount() {
    final provider = virtSnapshotsProvider(_serverId, _guest.id);
    if (!ref.exists(provider)) return null;
    return ref.watch(provider).value?.length;
  }

  Future<void> _onTemplate(VirtHardware hw) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.virtToTemplateConfirm(_guest.name)),
          UIs.height7,
          Text(l10n.virtToTemplateNote, style: UIs.text12Grey),
          UIs.height7,
          Text(
            l10n.virtToTemplateIrreversible,
            style: UIs.text12.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    setState(() => _toTemplate = true);
    try {
      await _notifier.makeTemplate(_guest.id);
      Toast.success(l10n.virtTemplateCreated(_guest.name));
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    } catch (e, s) {
      Loggers.app.warning('Virtualization template', e, s);
      Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) setState(() => _toTemplate = false);
    }
  }

  // --- cloud-init ---

  VirtCloudInitProvider get _ciProvider =>
      virtCloudInitProvider(_serverId, _guest.id);

  /// The draft from [ci], and [ci] as what it is compared with.
  void _ciFill(VirtCloudInitState ci) {
    _ciUser.text = ci.user;
    _ciPassword.clear();
    _ciKeys.text = ci.sshKeys.join('\n');
    _ciHostname.text = ci.hostname ?? '';
    _ciStatic = ci.address != null;
    _ciAddress.text = ci.address ?? '';
    _ciGateway.text = ci.gateway ?? '';
    _ciDns.text = ci.dns.join(' ');
    _ciSearch.text = ci.searchDomains.join(' ');
    _ciExpire = ci.passwordExpires;
    _ciRemovePassword = false;
    _ciBase = ci;
  }

  /// The draft as an edit of [ci]. What the view does not show (the
  /// address settings of a guest without the NIC) stays as it is.
  VirtCloudInitEdit _ciEditOf(VirtCloudInitState ci) {
    List<String> words(String s) => [
      for (final w in s.split(RegExp(r'[\s,]+')))
        if (w.isNotEmpty) w,
    ];
    final static = ci.network && _ciStatic;
    final gateway = _ciGateway.text.trim();
    return VirtCloudInitEdit(
      VirtCloudInit(
        user: _ciUser.text.trim(),
        password: _ciRemovePassword || _ciPassword.text.isEmpty
            ? null
            : _ciPassword.text,
        sshKeys: _ciKeys.text,
        hostname: _pve ? null : _ciHostname.text.trim(),
        address: ci.network ? (static ? _ciAddress.text.trim() : null) : ci.address,
        gateway: ci.network
            ? (static && gateway.isNotEmpty ? gateway : null)
            : ci.gateway,
        dns: ci.network ? words(_ciDns.text) : ci.dns,
        searchDomains: ci.network ? words(_ciSearch.text) : ci.searchDomains,
      ),
      removePassword: _ciRemovePassword,
      passwordExpires: _ciExpire,
    );
  }

  /// Whether [edit] changes anything of [ci].
  static bool _ciChanges(VirtCloudInitState ci, VirtCloudInitEdit edit) {
    final v = edit.values;
    return edit.removePassword ||
        (v.password?.isNotEmpty ?? false) ||
        v.user != ci.user ||
        !listEquals(v.keys, ci.sshKeys) ||
        (v.hostname != null && v.hostname != (ci.hostname ?? '')) ||
        v.address != ci.address ||
        v.gateway != ci.gateway ||
        !listEquals(v.dns, ci.dns) ||
        !listEquals(v.searchDomains, ci.searchDomains) ||
        edit.passwordExpires != ci.passwordExpires;
  }

  _Group _cloudInitGroup(bool busy) {
    final async = ref.watch(_ciProvider);
    final read = async.value;
    const title = 'cloud-init';
    final right = _pve ? 'cloudinit' : 'NoCloud';
    if (read == null) {
      final e = async.error;
      return _Group(
        key: 'cloud-init',
        title: title,
        right: right,
        warn: false,
        indexNote: e == null ? '…' : libL10n.error,
        dot: e == null ? null : Theme.of(context).colorScheme.error,
        rows: [
          if (e == null)
            const Padding(
              padding: EdgeInsets.all(7),
              child: Center(child: SizedLoading.small),
            )
          else ...[
            _text(e is VirtErr ? [e.title, ?e.detail].join('\n') : '$e', error: true),
            _actions([
              _Action(
                libL10n.retry,
                icon: Icons.refresh,
                key: 'ci:retry',
                onTap: () => ref.invalidate(_ciProvider),
              ),
            ]),
          ],
        ],
      );
    }
    // A new read refills a draft nobody has touched, and leaves one that
    // is being edited.
    final base = _ciBase;
    if (base == null ||
        (base.revision != read.revision && !_ciChanges(base, _ciEditOf(base)))) {
      _ciFill(read);
    }
    // The draft is an edit of the read it was filled from, and is checked
    // and saved as one: its revision goes back, so a change made elsewhere
    // since is the host's conflict rather than overwritten.
    final ci = _ciBase!;
    final edit = _ciEditOf(ci);
    final changed = _ciChanges(ci, edit);
    final issue = changed
        ? virtCloudInitEditIssue(ci, edit, host: _host ?? VirtHostKind.libvirt)
        : null;
    String? on(VirtCreateIssue which, String text) => issue == which ? text : null;
    final locked = busy || _ciSaving;
    return _Group(
      key: 'cloud-init',
      title: title,
      right: right,
      warn: false,
      indexNote: ci.user.ifEmpty(l10n.virtCreateNotChosen),
      rows: [
        _text(l10n.virtCiEditTip),
        if (ci.foreign)
          _callout(
            l10n.virtCiForeignTitle,
            l10n.virtCiForeignBody,
            key: const ValueKey('ci:foreign'),
          ),
        _inputRow([Input(
          key: const ValueKey('ci:user'),
          controller: _ciUser,
          label: libL10n.user,
          icon: Icons.person_outline,
          noWrap: true,
          suggestion: false,
          enabled: !locked,
          errorText: on(VirtCreateIssue.ciUser, l10n.virtCiUserInvalid),
          onChanged: (_) => setState(() {}),
        )]),
        _inputRow([Input(
          key: const ValueKey('ci:password'),
          controller: _ciPassword,
          label: libL10n.pwd,
          icon: Icons.password,
          hint: ci.passwordSet && !_ciRemovePassword ? l10n.virtCiPasswordKept : null,
          obscureText: true,
          noWrap: true,
          suggestion: false,
          enabled: !locked && !_ciRemovePassword,
          onChanged: (_) => setState(() {}),
        )]),
        if (ci.passwordSet)
          _toggle(
            Icons.no_encryption_outlined,
            l10n.virtCiRemovePassword,
            _ciRemovePassword,
            key: 'ci:remove-password',
            note: l10n.virtCiRemovePasswordNote,
            onChanged: locked
                ? null
                : (on) => setState(() {
                    _ciRemovePassword = on;
                    if (on) _ciPassword.clear();
                  }),
          ),
        // The expiry is cloud-init's own `chpasswd: expire:`. PVE writes
        // `expire: false` for every VM and has no option for it, so it is
        // offered on libvirt only.
        if (!_pve && !_ciRemovePassword)
          _toggle(
            Icons.update_outlined,
            l10n.virtCiExpire,
            _ciExpire,
            key: 'ci:expire',
            note: l10n.virtCiExpireNote,
            onChanged: locked ? null : (on) => setState(() => _ciExpire = on),
          ),
        _inputRow([Input(
          key: const ValueKey('ci:keys'),
          controller: _ciKeys,
          label: l10n.virtSshKeys,
          icon: Icons.vpn_key_outlined,
          hint: 'ssh-ed25519 AAAA…',
          minLines: 1,
          maxLines: 4,
          noWrap: true,
          suggestion: false,
          enabled: !locked,
          errorText: on(VirtCreateIssue.sshKeys, l10n.virtCreateSshKeysInvalid),
          onChanged: (_) => setState(() {}),
        )]),
        _text(l10n.virtCiKeysAdded),
        if (issue == VirtCreateIssue.ciCredentials)
          _text(l10n.virtCiCredentialsMissing, error: true),
        if (_pve)
          _text(l10n.virtCiHostnamePve)
        else
          _inputRow([Input(
            key: const ValueKey('ci:hostname'),
            controller: _ciHostname,
            label: l10n.virtHostname,
            icon: Icons.dns_outlined,
            noWrap: true,
            suggestion: false,
            enabled: !locked,
            errorText: on(VirtCreateIssue.ciHostname, l10n.virtCreateNameInvalidPve),
            onChanged: (_) => setState(() {}),
          )]),
        if (ci.network) ...[
          _seg(
            Icons.lan_outlined,
            libL10n.addr,
            ['DHCP', l10n.virtCiStatic],
            _ciStatic ? l10n.virtCiStatic : 'DHCP',
            key: 'ci:ip',
            onSelected: locked ? null : (v) => setState(() => _ciStatic = v != 'DHCP'),
          ),
          if (_ciStatic) ...[
            _inputRow([Input(
              key: const ValueKey('ci:address'),
              controller: _ciAddress,
              label: 'IPv4 / CIDR',
              icon: Icons.language,
              hint: '10.0.0.5/24',
              noWrap: true,
              suggestion: false,
              enabled: !locked,
              errorText: on(VirtCreateIssue.ciAddress, l10n.virtCiAddressInvalid),
              onChanged: (_) => setState(() {}),
            )]),
            _inputRow([Input(
              key: const ValueKey('ci:gateway'),
              controller: _ciGateway,
              label: libL10n.gateway,
              icon: Icons.router_outlined,
              hint: '10.0.0.1',
              noWrap: true,
              suggestion: false,
              enabled: !locked,
              errorText: on(VirtCreateIssue.ciGateway, l10n.virtCiGatewayInvalid),
              onChanged: (_) => setState(() {}),
            )]),
          ],
          _inputRow([Input(
            key: const ValueKey('ci:dns'),
            controller: _ciDns,
            label: 'DNS',
            icon: Icons.dns_outlined,
            hint: _ciStatic ? '1.1.1.1 9.9.9.9' : l10n.virtCiDnsFromDhcp,
            noWrap: true,
            suggestion: false,
            enabled: !locked,
            errorText: on(VirtCreateIssue.ciDns, l10n.virtCiDnsInvalid),
            onChanged: (_) => setState(() {}),
          )]),
          _inputRow([Input(
            key: const ValueKey('ci:search'),
            controller: _ciSearch,
            label: l10n.virtCiSearch,
            icon: Icons.travel_explore,
            hint: l10n.virtCiSearchHint,
            noWrap: true,
            suggestion: false,
            enabled: !locked,
            errorText: on(VirtCreateIssue.ciSearch, l10n.virtCreateNameInvalidPve),
            onChanged: (_) => setState(() {}),
          )]),
          _text(l10n.virtCiSearchTip),
          if (ci.nics > 1) _text(l10n.virtCiNicsTip(ci.nics)),
        ],
        // cloud-init runs most of what it does once per instance: what
        // saving here does, and when.
        _callout(
          l10n.virtCiEffectTitle,
          [
            _pve ? l10n.virtCiEffectPve : l10n.virtCiEffectLibvirt,
            l10n.virtCiNewInstance,
          ].join(' '),
          warn: false,
          key: const ValueKey('ci:effect'),
        ),
        if (changed)
          _actions([
            _Action(
              libL10n.cancel,
              icon: Icons.close,
              key: 'ci:cancel',
              onTap: locked ? null : () => setState(() => _ciFill(read)),
            ),
            _Action(
              libL10n.save,
              key: 'ci:save',
              primary: true,
              onTap: locked || issue != null ? null : () => _onSaveCloudInit(ci, edit),
            ),
          ]),
      ],
    );
  }

  Future<void> _onSaveCloudInit(
    VirtCloudInitState base,
    VirtCloudInitEdit edit,
  ) async {
    setState(() => _ciSaving = true);
    try {
      await _notifier.setCloudInit(_guest.id, base, edit);
      // The draft is what was saved: refilled from the read that follows.
      final after = await ref.read(_ciProvider.future);
      if (mounted) setState(() => _ciFill(after));
      Toast.success(l10n.virtCiSaved);
    } on VirtErr catch (e) {
      if (e.type == VirtErrType.conflict) {
        Toast.warn(e.title, body: l10n.virtErrConflictTip);
        if (mounted) {
          _ciBase = null;
          ref.invalidate(_ciProvider);
        }
      } else {
        Toast.error(e.title, body: e.detail);
      }
    } catch (e, s) {
      Loggers.app.warning('Virtualization cloud-init', e, s);
      Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) setState(() => _ciSaving = false);
    }
  }

  // --- Clone ---

  _Group _cloneGroup(VirtHardware hw, bool busy) {
    final name = _cloneName.text.trim();
    final taken = (ref.read(virtHostProvider(_serverId)).data?.guests ??
            const <VirtGuest>[])
        .any((g) => g.name == name);
    // libvirt copies a disk only while nothing writes to it; PVE clones a
    // running guest through a snapshot of its own.
    final stopFirst = !_pve && _guest.state != VirtGuestState.stopped;
    // PVE links a clone only to a template's disks; anything else is full.
    final canLink = _caps.linkedClone && _guest.template;
    final full = _pve && !canLink ? true : _cloneFull;
    final nameOk = virtCloneNameIssue(name, _host) == null && !taken;
    final nameIssue = name.isEmpty || !nameOk
        ? (taken ? l10n.virtCreateNameTaken : _nameIssueText(name))
        : null;
    // Where the copy's disks can go: the host's own lists. PVE needs the
    // storages of *this* guest's node (a storage is per node), libvirt the
    // pools that take a volume.
    final pools = _clonePools();
    final nodes = _cloneNodes();
    final targetIssue = _pve && !full
        // A linked clone shares the template's disks: PVE refuses a storage
        // and a node on it (`parameter 'storage' not allowed for linked
        // clones`). libvirt's empty disks are made in the pool picked.
        ? (_cloneStorage != null || _cloneNode != null
              ? VirtCreateIssue.cloneLinkedTarget
              : null)
        : _pve
        ? virtCloneNodeIssue(
                nodes: nodes,
                targetNode: _cloneNode,
                sourceNode: _guest.node,
              ) ??
              virtCloneStorageIssue(
                storages: pools,
                storage: _cloneStorage,
                full: full,
                kind: _guest.kind,
                targetNode: _cloneNode,
              )
        : null;
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
        _inputRow([Input(
          key: const ValueKey('clone:name'),
          controller: _cloneName,
          label: l10n.virtCloneName,
          icon: Icons.content_copy_outlined,
          noWrap: true,
          suggestion: false,
          enabled: !_cloning,
          errorText: name.isEmpty ? null : nameIssue,
          onChanged: (_) => setState(() {}),
        )]),
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
        if (_caps.cloneTarget && (full || !_pve) && pools.isNotEmpty)
          _choice([
            _Choice(
              key: 'clone:target:same',
              icon: Icons.storage_outlined,
              label: l10n.virtCloneStorageSame,
              sub: _cloneSources(),
              selected: _cloneStorage == null,
              onTap: () => setState(() => _cloneStorage = null),
            ),
            for (final p in pools)
              _Choice(
                key: 'clone:target:${p.id}',
                icon: Icons.storage_outlined,
                label: p.name,
                sub: _pve
                    ? [?p.node, ?p.path].join(' · ')
                    : [p.type, ?p.path].join(' · '),
                selected: _cloneStorage == p.name,
                onTap: () => setState(() => _cloneStorage = p.name),
              ),
          ]),
        // The node, only where there is another one to pick: a copy to
        // another node needs a cluster and a storage both see.
        if (_pve && full && nodes.length > 1)
          _choice([
            _Choice(
              key: 'clone:node:same',
              icon: Icons.dns_outlined,
              label: l10n.virtCloneNodeSame,
              sub: _guest.node,
              selected: _cloneNode == null,
              onTap: () => setState(() => _cloneNode = null),
            ),
            for (final n in nodes)
              if (n.name != _guest.node)
                _Choice(
                  key: 'clone:node:${n.name}',
                  icon: Icons.dns_outlined,
                  label: n.name,
                  selected: _cloneNode == n.name,
                  onTap: () => setState(() => _cloneNode = n.name),
                ),
          ]),
        if (targetIssue != null)
          _text(_cloneTargetText(targetIssue), error: true),
        if (stopFirst) _text(l10n.virtCloneStopFirst),
        _actions([
          _Action(
            _cloning ? l10n.virtCloning : libL10n.clone,
            key: 'clone:go',
            primary: true,
            onTap: name.isEmpty ||
                    !nameOk ||
                    targetIssue != null ||
                    stopFirst ||
                    busy ||
                    _cloning
                ? null
                : () => _onClone(name, full),
          ),
        ]),
      ],
    );
  }

  String _nameIssueText(String name) => switch (virtCloneNameIssue(name, _host)) {
    null => '',
    _ =>
      _pve ? l10n.virtCreateNameInvalidPve : l10n.virtCreateNameInvalidLibvirt,
  };

  String _cloneTargetText(VirtCreateIssue issue) => switch (issue) {
    VirtCreateIssue.cloneStorage => l10n.virtCloneStorageMissing,
    VirtCreateIssue.cloneStorageContent => l10n.virtCloneStorageContent,
    VirtCreateIssue.cloneStorageShared => l10n.virtCloneStorageShared,
    VirtCreateIssue.cloneLinkedTarget => l10n.virtCloneLinkedTarget,
    VirtCreateIssue.cloneNodeUnknown => l10n.virtCloneNodeUnknown,
    _ => libL10n.fail,
  };

  /// The storages a clone's disks can go to: PVE's, on this guest's node;
  /// libvirt's pools that take a volume.
  List<VirtStoragePool> _clonePools() {
    final pools =
        ref.watch(virtStoragePoolsProvider(_serverId)).value ??
        const <VirtStoragePool>[];
    return virtDiskStorages(
      pools,
      host: _host ?? VirtHostKind.libvirt,
      kind: _guest.kind,
      node: _guest.node,
    );
  }

  List<VirtNode> _cloneNodes() =>
      ref.watch(virtHostProvider(_serverId)).data?.host.nodes ??
      const <VirtNode>[];

  /// Where the copy's disks stay when no target is picked: the storages the
  /// guest's own disks are on, named as the host names them.
  String _cloneSources() {
    final hw = ref.watch(_provider).value;
    final names = <String>{};
    for (final d in hw?.disks ?? const <VirtHwDisk>[]) {
      final source = d.source;
      if (source == null) continue;
      // PVE: `local-lvm:vm-100-disk-0`; libvirt: a path in a pool.
      names.add(_pve ? source.split(':').first : source);
    }
    return names.join(', ');
  }

  Future<void> _onClone(String name, bool full) async {
    setState(() => _cloning = true);
    try {
      final id = await _notifier.clone(
        _guest.id,
        VirtCloneRequest(
          name: name,
          full: full,
          storage: _pve ? _cloneStorage : null,
          targetNode: _pve ? _cloneNode : null,
          targetPool: _pve ? null : _cloneStorage,
        ),
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
