import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/view/page/virt/common.dart';
import 'package:server_box/view/page/virt/edit_pane.dart';

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
    with VirtPaneRows<VirtSettingsView>, VirtEditPane<VirtSettingsView> {
  @override
  String get editServerId => widget.serverId;
  @override
  VirtGuest get editGuest => widget.guest;
  @override
  VirtCapabilities get editCaps => widget.caps;

  final _name = TextEditingController();
  final _desc = TextEditingController();
  late final _cloneName = TextEditingController(text: '${editGuest.name}-clone');

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
  Widget build(BuildContext context) => buildEditPane(_groups);

  void _sync(VirtHardware hw) {
    final name = hw.name ?? editGuest.name;
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

  List<VirtPaneGroup> _groups(VirtHardware hw, bool busy) {
    _sync(hw);
    return [
      _generalGroup(hw, busy),
      if (!editIsLxc && hw.disks.any((d) => d.cloudInit)) _cloudInitGroup(busy),
      if (editCaps.template && !editGuest.template) _templateGroup(hw, busy),
      if (editCaps.clone) _cloneGroup(hw, busy),
      if (editCaps.create) _deleteGroup(hw, busy),
    ];
  }

  // --- General ---

  VirtPaneGroup _generalGroup(VirtHardware hw, bool busy) {
    final name = _name.text.trim();
    final nameChanged = name != _nameBase;
    final taken =
        nameChanged &&
        (ref.read(virtHostProvider(editServerId)).data?.guests ??
                const <VirtGuest>[])
            .any((g) => g.id != editGuest.id && g.name == name);
    final nameIssue = !nameChanged
        ? null
        : taken
        ? l10n.virtCreateNameTaken
        : hwIssueText(hw, virtHwIssue(hw, VirtHwSetName(name), host: editHostKind));
    final renameLocked = hw.running && !hw.renameRunning;
    final desc = _desc.text;
    final descChanged = desc != _descBase;
    final descIssue = descChanged
        ? hwIssueText(hw, virtHwIssue(hw, VirtHwSetDescription(desc)))
        : null;
    final waits = _waits(hw);
    return VirtPaneGroup(
      key: 'general',
      title: libL10n.general,
      right: waits ? l10n.virtHwLater : '',
      warn: waits,
      indexNote: hw.autostart ? l10n.virtHwAutostart : l10n.virtSetManualStart,
      rows: [
        paneInputRow([Input(
          key: const ValueKey('set:name'),
          controller: _name,
          label: editIsLxc ? l10n.virtHostname : libL10n.name,
          icon: Icons.label_outline,
          noWrap: true,
          suggestion: false,
          enabled: !renameLocked && !busy,
          errorText: nameIssue,
          onChanged: (_) => setState(() {}),
        )]),
        if (renameLocked) paneText(l10n.virtSetRenameStopped),
        if (nameChanged)
          paneActions([
            VirtPaneAction(
              libL10n.cancel,
              icon: Icons.close,
              onTap: () => setState(() => _name.text = _nameBase ?? ''),
            ),
            VirtPaneAction(
              libL10n.save,
              key: 'set:name:save',
              primary: true,
              onTap: busy || nameIssue != null || renameLocked
                  ? null
                  : () => applyHwChange(hw, VirtHwSetName(name)),
            ),
          ]),
        paneInputRow([Input(
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
          paneActions([
            VirtPaneAction(
              libL10n.cancel,
              icon: Icons.close,
              onTap: () => setState(() => _desc.text = _descBase ?? ''),
            ),
            VirtPaneAction(
              libL10n.save,
              key: 'set:desc:save',
              primary: true,
              onTap: busy || descIssue != null
                  ? null
                  : () => applyHwChange(hw, VirtHwSetDescription(desc)),
            ),
          ]),
        paneToggle(
          Icons.power_settings_new,
          l10n.virtHwAutostart,
          hw.autostart,
          key: 'autostart',
          note: editIsPve ? l10n.virtHwAutostartPve : 'virsh autostart',
          onChanged: busy ? null : (on) => applyHwChange(hw, VirtHwSetAutostart(on)),
        ),
        if (hw.protection case final protected?)
          paneToggle(
            Icons.lock_outline,
            l10n.virtSetProtection,
            protected,
            key: 'protection',
            note: l10n.virtSetProtectionNote,
            onChanged: busy
                ? null
                : (on) => applyHwChange(hw, VirtHwSetProtection(on)),
          ),
        ...buildPendingRows(
          hw,
          busy,
          (p) => placeOfPending(hw, p.key) == VirtPendingPlace.settings,
        ),
      ],
    );
  }

  bool _waits(VirtHardware hw) =>
      hw.running &&
      hw.pending.any((p) => placeOfPending(hw, p.key) == VirtPendingPlace.settings);

  // --- Template ---

  /// PVE's "convert to template", offered once and never undone: the dialog
  /// says so, since PVE has no way back (`POST .../template` writes
  /// `template: 1` and turns each disk into a base image).
  ///
  /// The design has no group for this — its list has no template state
  /// either — and it lives here because it is a setting of the guest rather
  /// than an action on it: PVE's own web UI puts it under "More", beside
  /// Clone, and it is the one change that decides what the guest *is*.
  VirtPaneGroup _templateGroup(VirtHardware hw, bool busy) {
    final running = editGuest.state != VirtGuestState.stopped;
    // PVE refuses a guest with snapshots. Only known where the Snapshots
    // view has read them this session; otherwise the host says so itself
    // when the request is made.
    final snapCount = _readSnapshotCount();
    final snaps = snapCount != null && snapCount != 0;
    final blocked = running || snaps || busy || _toTemplate;
    return VirtPaneGroup(
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
        paneText(l10n.virtToTemplateNote),
        if (running) paneText(l10n.virtToTemplateStopped),
        if (snaps) paneText(l10n.virtToTemplateSnapshots),
        paneActions([
          VirtPaneAction(
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
    final provider = virtSnapshotsProvider(editServerId, editGuest.id);
    if (!ref.read(provider.exists)) return null;
    return ref.watch(provider).value?.length;
  }

  Future<void> _onTemplate(VirtHardware hw) async {
    final ok = await context.showSheet<bool>(
      title: libL10n.attention,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.virtToTemplateConfirm(editGuest.name)),
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
      await editNotifier.makeTemplate(editGuest.id);
      Toast.success(l10n.virtTemplateCreated(editGuest.name));
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
      virtCloudInitProvider(editServerId, editGuest.id);

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
        hostname: editIsPve ? null : _ciHostname.text.trim(),
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

  VirtPaneGroup _cloudInitGroup(bool busy) {
    final async = ref.watch(_ciProvider);
    final read = async.value;
    const title = 'cloud-init';
    final right = editIsPve ? 'cloudinit' : 'NoCloud';
    if (read == null) {
      final e = async.error;
      return VirtPaneGroup(
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
            paneText(e is VirtErr ? [e.title, ?e.detail].join('\n') : '$e', error: true),
            paneActions([
              VirtPaneAction(
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
        ? virtCloudInitEditIssue(ci, edit, host: editHostKind ?? VirtHostKind.libvirt)
        : null;
    String? on(VirtCreateIssue which, String text) => issue == which ? text : null;
    final locked = busy || _ciSaving;
    return VirtPaneGroup(
      key: 'cloud-init',
      title: title,
      right: right,
      warn: false,
      indexNote: ci.user.ifEmpty(l10n.virtCreateNotChosen),
      rows: [
        paneText(l10n.virtCiEditTip),
        if (ci.foreign)
          paneCallout(
            l10n.virtCiForeignTitle,
            l10n.virtCiForeignBody,
            key: const ValueKey('ci:foreign'),
          ),
        paneInputRow([Input(
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
        paneInputRow([Input(
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
          paneToggle(
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
        if (!editIsPve && !_ciRemovePassword)
          paneToggle(
            Icons.update_outlined,
            l10n.virtCiExpire,
            _ciExpire,
            key: 'ci:expire',
            note: l10n.virtCiExpireNote,
            onChanged: locked ? null : (on) => setState(() => _ciExpire = on),
          ),
        paneInputRow([Input(
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
        paneText(l10n.virtCiKeysAdded),
        if (issue == VirtCreateIssue.ciCredentials)
          paneText(l10n.virtCiCredentialsMissing, error: true),
        if (editIsPve)
          paneText(l10n.virtCiHostnamePve)
        else
          paneInputRow([Input(
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
          paneSeg(
            Icons.lan_outlined,
            libL10n.addr,
            ['DHCP', l10n.virtCiStatic],
            _ciStatic ? l10n.virtCiStatic : 'DHCP',
            key: 'ci:ip',
            onSelected: locked ? null : (v) => setState(() => _ciStatic = v != 'DHCP'),
          ),
          if (_ciStatic) ...[
            paneInputRow([Input(
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
            paneInputRow([Input(
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
          paneInputRow([Input(
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
          paneInputRow([Input(
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
          paneText(l10n.virtCiSearchTip),
          if (ci.nics > 1) paneText(l10n.virtCiNicsTip(ci.nics)),
        ],
        // cloud-init runs most of what it does once per instance: what
        // saving here does, and when.
        paneCallout(
          l10n.virtCiEffectTitle,
          [
            editIsPve ? l10n.virtCiEffectPve : l10n.virtCiEffectLibvirt,
            l10n.virtCiNewInstance,
          ].join(' '),
          warn: false,
          key: const ValueKey('ci:effect'),
        ),
        if (changed)
          paneActions([
            VirtPaneAction(
              libL10n.cancel,
              icon: Icons.close,
              key: 'ci:cancel',
              onTap: locked ? null : () => setState(() => _ciFill(read)),
            ),
            VirtPaneAction(
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
      await editNotifier.setCloudInit(editGuest.id, base, edit);
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

  VirtPaneGroup _cloneGroup(VirtHardware hw, bool busy) {
    final name = _cloneName.text.trim();
    final taken = (ref.read(virtHostProvider(editServerId)).data?.guests ??
            const <VirtGuest>[])
        .any((g) => g.name == name);
    // libvirt copies a disk only while nothing writes to it; PVE clones a
    // running guest through a snapshot of its own.
    final stopFirst = !editIsPve && editGuest.state != VirtGuestState.stopped;
    // PVE links a clone only to a template's disks; anything else is full.
    final canLink = editCaps.linkedClone && editGuest.template;
    final full = editIsPve && !canLink ? true : _cloneFull;
    final nameOk = virtCloneNameIssue(name, editHostKind) == null && !taken;
    final nameIssue = name.isEmpty || !nameOk
        ? (taken ? l10n.virtCreateNameTaken : _nameIssueText(name))
        : null;
    // Where the copy's disks can go: the host's own lists. PVE needs the
    // storages of *this* guest's node (a storage is per node), libvirt the
    // pools that take a volume.
    final pools = _clonePools();
    final nodes = _cloneNodes();
    final targetIssue = editIsPve && !full
        // A linked clone shares the template's disks: PVE refuses a storage
        // and a node on it (`parameter 'storage' not allowed for linked
        // clones`). libvirt's empty disks are made in the pool picked.
        ? (_cloneStorage != null || _cloneNode != null
              ? VirtCreateIssue.cloneLinkedTarget
              : null)
        : editIsPve
        ? virtCloneNodeIssue(
                nodes: nodes,
                targetNode: _cloneNode,
                sourceNode: editGuest.node,
              ) ??
              virtCloneStorageIssue(
                storages: pools,
                storage: _cloneStorage,
                full: full,
                kind: editGuest.kind,
                targetNode: _cloneNode,
              )
        : null;
    return VirtPaneGroup(
      key: 'clone',
      title: libL10n.clone,
      right: '',
      warn: false,
      indexNote: full
          ? l10n.virtCloneFullShort
          : editIsPve
          ? l10n.virtCloneLinkedShort
          : l10n.virtCloneEmptyShort,
      rows: [
        paneInputRow([Input(
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
        paneToggle(
          Icons.file_copy_outlined,
          editIsPve ? l10n.virtCloneFull : l10n.virtCloneCopyDisks,
          full,
          key: 'clone:full',
          note: !editIsPve
              ? l10n.virtCloneEmptyNote
              : canLink
              ? l10n.virtCloneLinkedNote
              : l10n.virtCloneFullOnly,
          onChanged: _cloning || (editIsPve && !canLink)
              ? null
              : (on) => setState(() => _cloneFull = on),
        ),
        if (editCaps.cloneTarget && (full || !editIsPve) && pools.isNotEmpty)
          paneChoice([
            VirtPaneChoice(
              key: 'clone:target:same',
              icon: Icons.storage_outlined,
              label: l10n.virtCloneStorageSame,
              sub: _cloneSources(),
              selected: _cloneStorage == null,
              onTap: () => setState(() => _cloneStorage = null),
            ),
            for (final p in pools)
              VirtPaneChoice(
                key: 'clone:target:${p.id}',
                icon: Icons.storage_outlined,
                label: p.name,
                sub: editIsPve
                    ? [?p.node, ?p.path].join(' · ')
                    : [p.type, ?p.path].join(' · '),
                selected: _cloneStorage == p.name,
                onTap: () => setState(() => _cloneStorage = p.name),
              ),
          ]),
        // The node, only where there is another one to pick: a copy to
        // another node needs a cluster and a storage both see.
        if (editIsPve && full && nodes.length > 1)
          paneChoice([
            VirtPaneChoice(
              key: 'clone:node:same',
              icon: Icons.dns_outlined,
              label: l10n.virtCloneNodeSame,
              sub: editGuest.node,
              selected: _cloneNode == null,
              onTap: () => setState(() => _cloneNode = null),
            ),
            for (final n in nodes)
              if (n.name != editGuest.node)
                VirtPaneChoice(
                  key: 'clone:node:${n.name}',
                  icon: Icons.dns_outlined,
                  label: n.name,
                  selected: _cloneNode == n.name,
                  onTap: () => setState(() => _cloneNode = n.name),
                ),
          ]),
        if (targetIssue != null)
          paneText(_cloneTargetText(targetIssue), error: true),
        if (stopFirst) paneText(l10n.virtCloneStopFirst),
        paneActions([
          VirtPaneAction(
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

  String _nameIssueText(String name) => switch (virtCloneNameIssue(name, editHostKind)) {
    null => '',
    _ =>
      editIsPve ? l10n.virtCreateNameInvalidPve : l10n.virtCreateNameInvalidLibvirt,
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
        ref.watch(virtStoragePoolsProvider(editServerId)).value ??
        const <VirtStoragePool>[];
    return virtDiskStorages(
      pools,
      host: editHostKind ?? VirtHostKind.libvirt,
      kind: editGuest.kind,
      node: editGuest.node,
    );
  }

  List<VirtNode> _cloneNodes() =>
      ref.watch(virtHostProvider(editServerId)).data?.host.nodes ??
      const <VirtNode>[];

  /// Where the copy's disks stay when no target is picked: the storages the
  /// guest's own disks are on, named as the host names them.
  String _cloneSources() {
    final hw = ref.watch(editHwProvider).value;
    final names = <String>{};
    for (final d in hw?.disks ?? const <VirtHwDisk>[]) {
      final source = d.source;
      if (source == null) continue;
      // PVE: `local-lvm:vm-100-disk-0`; libvirt: a path in a pool.
      names.add(editIsPve ? source.split(':').first : source);
    }
    return names.join(', ');
  }

  Future<void> _onClone(String name, bool full) async {
    setState(() => _cloning = true);
    try {
      final id = await editNotifier.clone(
        editGuest.id,
        VirtCloneRequest(
          name: name,
          full: full,
          storage: editIsPve ? _cloneStorage : null,
          targetNode: editIsPve ? _cloneNode : null,
          targetPool: editIsPve ? null : _cloneStorage,
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

  VirtPaneGroup _deleteGroup(VirtHardware hw, bool busy) {
    final running = editGuest.state != VirtGuestState.stopped;
    final protected = hw.protection ?? false;
    final blocked = running || protected || busy || _deleting;
    final volumes = [
      for (final d in hw.disks)
        if (d.kind != VirtHwDiskKind.cdrom && d.source != null) d.source!,
    ];
    return VirtPaneGroup(
      key: 'delete',
      title: libL10n.delete,
      right: '',
      warn: false,
      dot: Theme.of(context).colorScheme.error,
      indexNote: l10n.virtSetIrreversible,
      rows: [
        if (editCaps.deleteKeepsDisks)
          paneToggle(
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
          paneText(l10n.virtDeleteDisksPve),
        if (running) paneText(l10n.virtSetDeleteStopFirst),
        if (protected) paneText(l10n.virtSetDeleteProtected),
        if (_confirmDelete && !blocked)
          paneBox(
            key: const ValueKey('delete:callout'),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                paneIcon(
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
        paneActions([
          if (_confirmDelete && !blocked)
            VirtPaneAction(
              libL10n.cancel,
              icon: Icons.close,
              onTap: () => setState(() => _confirmDelete = false),
            ),
          VirtPaneAction(
            _confirmDelete && !blocked
                ? l10n.virtSetDeleteConfirm(editGuest.name)
                : editIsLxc
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
        removeDisks: !editCaps.deleteKeepsDisks || _removeDisks,
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
