import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/virt/common.dart';

final class VirtCreateArgs {
  const VirtCreateArgs({required this.serverId});

  final String serverId;
}

/// [VirtCreateView] over the list, for a window with room for one column.
/// Pops with the new guest's id.
class VirtCreatePage extends StatelessWidget {
  const VirtCreatePage({super.key, required this.args});

  final VirtCreateArgs args;

  static const route = AppRouteArg<String, VirtCreateArgs>(
    page: VirtCreatePage.new,
    path: '/virt/create',
  );

  @override
  Widget build(BuildContext context) {
    return VirtCreateView(
      serverId: args.serverId,
      leading: const BackButton(),
      onCreated: (id) => context.pop(id),
    );
  }
}

/// A new guest on one host: a VM, or on PVE a container.
///
/// One page of groups rather than steps — name, media, resources, disk,
/// network, and for a container its root login — each filled in with what
/// the host listed, so nothing is typed that the host could have offered.
/// What is wrong is said under the button, and the button waits for it:
/// [virtCreateIssue] checks what the host would refuse, before it is asked.
class VirtCreateView extends ConsumerStatefulWidget {
  const VirtCreateView({
    super.key,
    required this.serverId,
    required this.onCreated,
    this.onCancel,
    this.leading,
  });

  final String serverId;

  /// The new guest's id, once it is in the host's list.
  final ValueChanged<String> onCreated;

  /// Beside the title, where closing is not the bar's back button.
  final VoidCallback? onCancel;
  final Widget? leading;

  @override
  ConsumerState<VirtCreateView> createState() => _VirtCreateViewState();
}

/// What a new guest is given until the user says otherwise.
const _defaultCores = 2;

/// Memory choices, MiB: fine steps where they matter, doubling above.
const _memorySteps = [
  128, 256, 512, 1024, 2048, 3072, 4096, 6144, 8192, 12288, 16384, 24576, //
  32768, 49152, 65536, 98304, 131072, 262144,
];

/// Disk choices, GiB.
const _diskSteps = [
  1, 2, 4, 8, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384, 512, 768, 1024, //
  2048, 4096,
];

class _VirtCreateViewState extends ConsumerState<VirtCreateView> {
  var _kind = VirtGuestKind.qemu;
  final _name = TextEditingController();
  final _vmid = TextEditingController();
  final _password = TextEditingController();
  final _keys = TextEditingController();
  String? _node;
  var _cores = _defaultCores;
  var _memory = _memorySteps.indexOf(2048);
  var _disk = _diskSteps.indexOf(32);
  VirtStoragePool? _storage;
  VirtVolume? _media;
  VirtNetwork? _network;

  /// The user chose no NIC, rather than none being chosen yet.
  var _noNetwork = false;
  var _unprivileged = true;
  var _start = true;
  var _busy = false;

  Future<List<VirtStoragePool>>? _pools;
  Future<List<VirtNetwork>>? _networks;

  /// Media and templates per storage id, fetched once each.
  final _content = <String, Future<List<VirtVolume>>>{};

  VirtHostNotifier get _notifier =>
      ref.read(virtHostProvider(widget.serverId).notifier);

  @override
  void initState() {
    super.initState();
    _pools = _notifier.storagePools();
    _networks = _notifier.networks();
    unawaited(_loadVmid());
  }

  @override
  void dispose() {
    _name.dispose();
    _vmid.dispose();
    _password.dispose();
    _keys.dispose();
    super.dispose();
  }

  Future<void> _loadVmid() async {
    try {
      final id = await _notifier.nextVmid();
      if (!mounted || id == null || _vmid.text.isNotEmpty) return;
      setState(() => _vmid.text = '$id');
    } on VirtErr catch (e) {
      // Typed by hand then: the field is there either way.
      Loggers.app.info('PVE nextid: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(virtHostProvider(widget.serverId));
    final data = st.data;
    final host = data?.host.kind ?? st.kind ?? VirtHostKind.libvirt;
    final pve = host == VirtHostKind.pve;
    final nodes = [
      for (final n in data?.host.nodes ?? const <VirtNode>[])
        if (n.online) n,
    ];
    final node = pve
        ? (nodes.any((n) => n.name == _node) ? _node : nodes.firstOrNull?.name)
        : null;
    final lxc = _kind == VirtGuestKind.lxc;
    return Scaffold(
      appBar: CustomAppBar(
        leading: widget.leading,
        title: Text(lxc ? l10n.virtCreateLxc : l10n.virtCreateVm),
        actions: [
          if (widget.onCancel case final cancel?)
            Btn.icon(
              text: libL10n.cancel,
              icon: const Icon(Icons.close, size: 18),
              onTap: cancel,
            ),
          UIs.width7,
        ],
      ),
      body: FutureBuilder<List<Object>>(
        future: Future.wait<Object>([?_pools, ?_networks]),
        builder: (context, snap) {
          if (snap.error case final e?) return _buildLoadError(e);
          final loaded = snap.data;
          if (loaded == null) return const Center(child: SizedLoading.medium);
          final pools = loaded[0] as List<VirtStoragePool>;
          final networks = loaded[1] as List<VirtNetwork>;
          return _buildForm(
            host: host,
            data: data,
            node: node,
            nodes: nodes,
            pools: pools,
            networks: networks,
          );
        },
      ),
    );
  }

  Widget _buildLoadError(Object e) {
    return EmptyPane(
      icon: Icons.error_outline,
      title: e is VirtErr ? e.title : libL10n.fail,
      label: e is VirtErr ? e.detail : '$e',
      action: Btn.text(
        text: libL10n.retry,
        onTap: () => setState(() {
          _content.clear();
          _pools = _notifier.storagePools();
          _networks = _notifier.networks();
        }),
      ),
    );
  }

  Widget _buildForm({
    required VirtHostKind host,
    required VirtSnapshot? data,
    required String? node,
    required List<VirtNode> nodes,
    required List<VirtStoragePool> pools,
    required List<VirtNetwork> networks,
  }) {
    final pve = host == VirtHostKind.pve;
    final lxc = _kind == VirtGuestKind.lxc;
    final disks = virtDiskStorages(pools, host: host, kind: _kind, node: node);
    final nets = virtCreateNetworks(networks, host: host, node: node);
    final mediaPools = virtMediaStorages(
      pools,
      host: host,
      kind: _kind,
      node: node,
    );
    // What was chosen, while it is still on offer: another node or kind
    // offers other things.
    final storage =
        disks.firstWhereOrNull((p) => p.id == _storage?.id) ??
        disks.firstOrNull;
    final network = _noNetwork
        ? null
        : nets.firstWhereOrNull((n) => n.id == _network?.id) ??
              nets.firstWhereOrNull((n) => n.name == 'default') ??
              nets.firstOrNull;
    final maxCores = pve
        ? nodes.firstWhereOrNull((n) => n.name == node)?.maxCpu
        : null;
    final caps = data?.capabilities;

    return FutureBuilder<List<VirtVolume>>(
      future: _mediaOf(mediaPools),
      builder: (context, snap) {
        final media = snap.data;
        final chosen = media?.firstWhereOrNull((v) => v.id == _media?.id);
        final spec = storage == null
            ? null
            : VirtCreateSpec(
                kind: _kind,
                name: _name.text.trim(),
                node: node,
                vmid: pve ? int.tryParse(_vmid.text.trim()) : null,
                cores: _cores,
                memoryMiB: _memorySteps[_memory],
                storage: storage,
                diskGiB: _diskSteps[_disk],
                media: lxc ? (chosen ?? media?.firstOrNull) : chosen,
                network: network,
                password: lxc ? _password.text : null,
                sshKeys: lxc ? _keys.text : null,
                unprivileged: _unprivileged,
                start: _start,
              );
        final issue = spec == null
            ? VirtCreateIssue.storage
            : virtCreateIssue(
                spec,
                host: host,
                guests: data?.guests ?? const [],
                maxCores: maxCores,
              );
        return ListView(
          padding: const EdgeInsets.fromLTRB(13, 3, 13, 27),
          children: [
            if (pve && (caps?.lxc ?? false))
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: SegmentedTabs<VirtGuestKind>(
                  expand: true,
                  selected: _kind,
                  onSelected: (k) => setState(() {
                    _kind = k;
                    _media = null;
                  }),
                  segments: [
                    SegmentedTab(
                      value: VirtGuestKind.qemu,
                      label: l10n.virtKindVm,
                      icon: VirtGuestKind.qemu.icon,
                    ),
                    SegmentedTab(
                      value: VirtGuestKind.lxc,
                      label: l10n.virtKindLxc,
                      icon: VirtGuestKind.lxc.icon,
                    ),
                  ],
                ),
              ),
            _buildGeneral(host, issue, node, nodes),
            _buildMedia(mediaPools, snap, spec?.media),
            _buildResources(issue),
            _buildDisk(disks, storage, issue),
            _buildNetwork(nets, network),
            if (lxc) _buildLogin(issue),
            _buildConfirm(spec, issue),
          ],
        );
      },
    );
  }

  /// The media or templates in [pools], fetched once per storage.
  Future<List<VirtVolume>> _mediaOf(List<VirtStoragePool> pools) async {
    final kind = _kind;
    final lists = await Future.wait([
      for (final p in pools)
        _content.putIfAbsent(p.id, () => _notifier.volumes(p)),
    ]);
    return [
      for (final list in lists)
        for (final v in list)
          if (virtIsMedia(v, kind)) v,
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  Widget _buildGeneral(
    VirtHostKind host,
    VirtCreateIssue? issue,
    String? node,
    List<VirtNode> nodes,
  ) {
    final pve = host == VirtHostKind.pve;
    final nameError = switch (issue) {
      VirtCreateIssue.nameInvalid =>
        pve ? l10n.virtCreateNameInvalidPve : l10n.virtCreateNameInvalidLibvirt,
      VirtCreateIssue.nameTaken => l10n.virtCreateNameTaken,
      _ => null,
    };
    final vmidError = switch (issue) {
      VirtCreateIssue.vmidInvalid when _vmid.text.isNotEmpty =>
        l10n.virtCreateVmidInvalid,
      VirtCreateIssue.vmidTaken => l10n.virtCreateVmidTaken,
      _ => null,
    };
    return VirtCard(
      icon: Icons.label_outline,
      title: libL10n.general,
      children: [
        Input(
          key: const ValueKey('create:name'),
          controller: _name,
          label: _kind == VirtGuestKind.lxc ? l10n.virtHostname : libL10n.name,
          icon: Icons.label_outline,
          noWrap: true,
          suggestion: false,
          errorText: nameError,
          onChanged: (_) => setState(() {}),
        ),
        if (pve) ...[
          UIs.height7,
          Input(
            key: const ValueKey('create:vmid'),
            controller: _vmid,
            label: 'VMID',
            icon: Icons.tag,
            type: TextInputType.number,
            noWrap: true,
            suggestion: false,
            errorText: vmidError,
            onChanged: (_) => setState(() {}),
          ),
          if (nodes.length > 1) ...[
            UIs.height7,
            Text(libL10n.node, style: UIs.text12Grey),
            UIs.height7,
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final n in nodes)
                  ChoiceChip(
                    key: ValueKey('create:node:${n.name}'),
                    label: Text(n.name),
                    selected: n.name == node,
                    onSelected: (_) => setState(() {
                      _node = n.name;
                      _media = null;
                    }),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildMedia(
    List<VirtStoragePool> pools,
    AsyncSnapshot<List<VirtVolume>> snap,
    VirtVolume? chosen,
  ) {
    final lxc = _kind == VirtGuestKind.lxc;
    final media = snap.data;
    return VirtCard(
      icon: lxc ? Icons.inventory_2_outlined : Icons.album_outlined,
      title: lxc ? l10n.virtTemplate : l10n.virtInstallMedia,
      children: [
        if (snap.error case final e?)
          Text(
            e is VirtErr ? [e.title, ?e.detail].join('\n') : '$e',
            style: UIs.text12Grey,
          )
        else if (media == null)
          const Padding(
            padding: EdgeInsets.all(7),
            child: Center(child: SizedLoading.small),
          )
        else ...[
          if (!lxc)
            _choice(
              key: 'media:none',
              title: libL10n.none,
              selected: chosen == null,
              onTap: () => setState(() => _media = null),
            ),
          for (final v in media)
            _choice(
              key: 'media:${v.id}',
              title: v.name,
              subtitle: [
                if (pools.length > 1) v.id.split(':').first,
                if (v.capacity case final size?) size.bytes2Str,
              ].join(' · '),
              selected: chosen?.id == v.id,
              onTap: () => setState(() => _media = v),
            ),
          if (media.isEmpty)
            Text(
              lxc ? l10n.virtNoTemplates : l10n.virtNoIsos,
              style: UIs.text12Grey,
            ),
        ],
      ],
    );
  }

  Widget _buildResources(VirtCreateIssue? issue) {
    final lxc = _kind == VirtGuestKind.lxc;
    return VirtCard(
      icon: Icons.memory,
      title: '${l10n.cores} · ${libL10n.memory}',
      children: [
        _stepper(
          key: 'cores',
          label: lxc ? l10n.cores : 'vCPU',
          value: '$_cores',
          onMinus: _cores > 1 ? () => setState(() => _cores--) : null,
          onPlus: () => setState(() => _cores++),
        ),
        _stepper(
          key: 'memory',
          label: libL10n.memory,
          value: (_memorySteps[_memory] * 1024 * 1024).bytes2Str,
          onMinus: _memory > 0 ? () => setState(() => _memory--) : null,
          onPlus: _memory < _memorySteps.length - 1
              ? () => setState(() => _memory++)
              : null,
        ),
        if (issue == VirtCreateIssue.cores)
          _issueText(l10n.virtCreateCoresInvalid)
        else if (issue == VirtCreateIssue.memory)
          _issueText(l10n.virtCreateMemoryInvalid),
      ],
    );
  }

  Widget _buildDisk(
    List<VirtStoragePool> disks,
    VirtStoragePool? storage,
    VirtCreateIssue? issue,
  ) {
    return VirtCard(
      icon: Icons.storage_outlined,
      title: libL10n.storage,
      children: [
        for (final p in disks)
          _choice(
            key: 'storage:${p.id}',
            title: p.name,
            subtitle: [
              p.type,
              if (p.available case final free?)
                '${free.bytes2Str} ${libL10n.available}',
            ].join(' · '),
            selected: p.id == storage?.id,
            onTap: () => setState(() => _storage = p),
          ),
        if (disks.isEmpty) Text(l10n.virtNoDiskStorage, style: UIs.text12Grey),
        _stepper(
          key: 'disk',
          label: libL10n.size,
          value: '${_diskSteps[_disk]} GiB',
          onMinus: _disk > 0 ? () => setState(() => _disk--) : null,
          onPlus: _disk < _diskSteps.length - 1
              ? () => setState(() => _disk++)
              : null,
        ),
      ],
    );
  }

  Widget _buildNetwork(List<VirtNetwork> nets, VirtNetwork? network) {
    return VirtCard(
      icon: Icons.lan_outlined,
      title: libL10n.network,
      children: [
        _choice(
          key: 'network:none',
          title: libL10n.none,
          selected: network == null,
          onTap: () => setState(() => _noNetwork = true),
        ),
        for (final n in nets)
          _choice(
            key: 'network:${n.id}',
            title: n.name,
            subtitle: [
              n.mode,
              ?n.bridge,
              ...n.cidrs,
            ].where((s) => s.isNotEmpty && s != n.name).join(' · '),
            selected: n.id == network?.id,
            onTap: () => setState(() {
              _noNetwork = false;
              _network = n;
            }),
          ),
      ],
    );
  }

  /// A container's root login: a password, keys, or both.
  Widget _buildLogin(VirtCreateIssue? issue) {
    return VirtCard(
      icon: Icons.key_outlined,
      title: 'root',
      children: [
        Text(l10n.virtCredentialsTip, style: UIs.text12Grey),
        UIs.height7,
        Input(
          key: const ValueKey('create:password'),
          controller: _password,
          label: libL10n.pwd,
          icon: Icons.password,
          obscureText: true,
          noWrap: true,
          suggestion: false,
          errorText: issue == VirtCreateIssue.password
              ? l10n.virtCreatePasswordShort(virtLxcPasswordMin)
              : null,
          onChanged: (_) => setState(() {}),
        ),
        UIs.height7,
        Input(
          key: const ValueKey('create:keys'),
          controller: _keys,
          label: l10n.virtSshKeys,
          icon: Icons.vpn_key_outlined,
          hint: 'ssh-ed25519 AAAA…',
          minLines: 1,
          maxLines: 4,
          suggestion: false,
          errorText: issue == VirtCreateIssue.sshKeys
              ? l10n.virtCreateSshKeysInvalid
              : null,
          onChanged: (_) => setState(() {}),
        ),
        SwitchListTile(
          key: const ValueKey('create:unprivileged'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.virtUnprivileged, style: UIs.text13),
          subtitle: Text(l10n.virtUnprivilegedTip, style: UIs.text12Grey),
          value: _unprivileged,
          onChanged: (v) => setState(() => _unprivileged = v),
        ),
      ],
    );
  }

  Widget _buildConfirm(VirtCreateSpec? spec, VirtCreateIssue? issue) {
    final lxc = _kind == VirtGuestKind.lxc;
    // Said under the button; the ones a field shows are said there.
    final note = switch (issue) {
      VirtCreateIssue.storage => l10n.virtCreateStorageMissing,
      VirtCreateIssue.diskSize => l10n.virtCreateDiskInvalid,
      VirtCreateIssue.template => l10n.virtCreateTemplateMissing,
      VirtCreateIssue.credentials => l10n.virtCreateCredentialsMissing,
      _ => null,
    };
    return VirtCard(
      icon: Icons.check_circle_outline,
      title: libL10n.confirm,
      children: [
        SwitchListTile(
          key: const ValueKey('create:start'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.virtStartAfterCreate, style: UIs.text13),
          value: _start,
          onChanged: (v) => setState(() => _start = v),
        ),
        ?note == null ? null : _issueText(note),
        UIs.height7,
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: _busy
              ? SizedLoading.small
              : FilledButton(
                  key: const ValueKey('create:submit'),
                  onPressed: issue != null || spec == null
                      ? null
                      : () => unawaited(_create(spec)),
                  child: Text(lxc ? l10n.virtCreateLxc : l10n.virtCreateVm),
                ),
        ),
      ],
    );
  }

  Future<void> _create(VirtCreateSpec spec) async {
    setState(() => _busy = true);
    try {
      final created = await _notifier.create(spec);
      if (created.startError case final err?) {
        Toast.warn(l10n.virtCreatedNotStarted(spec.name), body: err);
      } else {
        Toast.success(l10n.virtCreated(spec.name));
      }
      if (mounted) widget.onCreated(created.id);
    } on VirtErr catch (e) {
      Toast.error(e.title, body: e.detail);
    } catch (e, s) {
      Loggers.app.warning('Creating a guest', e, s);
      Toast.error(libL10n.fail, body: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _choice({
    required String key,
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: ValueKey('create:$key'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 20,
        color: selected ? scheme.primary : null,
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: UIs.text13,
      ),
      subtitle: subtitle == null || subtitle.isEmpty
          ? null
          : Text(subtitle, style: UIs.text11Grey),
      onTap: onTap,
    );
  }

  Widget _stepper({
    required String key,
    required String label,
    required String value,
    required VoidCallback? onMinus,
    required VoidCallback? onPlus,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: UIs.text13)),
        IconButton(
          key: ValueKey('create:$key:minus'),
          onPressed: onMinus,
          icon: const Icon(Icons.remove, size: 18),
        ),
        SizedBox(
          width: 72,
          child: Text(
            value,
            key: ValueKey('create:$key:value'),
            textAlign: TextAlign.center,
            style: UIs.text13Bold,
          ),
        ),
        IconButton(
          key: ValueKey('create:$key:plus'),
          onPressed: onPlus,
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    );
  }

  Widget _issueText(String text) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: StatePalette.warn),
    ),
  );
}
