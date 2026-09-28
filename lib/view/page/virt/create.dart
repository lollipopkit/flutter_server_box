part of 'hardware.dart';

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

/// A new guest on one host: a VM, or on PVE a container — the design's
/// create form in the sectioned pane: general, system (install media or a
/// cloud image, the firmware) or the template, cloud-init for a cloud image,
/// resources, storage, network, and the confirmation. Each group's dot in
/// the index says whether it is complete.
///
/// Everything offered comes from the host's own lists and what it says a
/// new VM can have ([VirtCreateOptions]), so nothing is typed that the host
/// could have offered. What is wrong is said where it is, and the button
/// waits for it: [virtCreateIssue] checks what the host would refuse before
/// it is asked.
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
  1, 2, 3, 4, 8, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384, 512, 768, 1024, //
  2048, 4096,
];

/// Where a VM's system comes from.
enum _Source { iso, image }

/// A volume as the form offers it: with the storage it was listed in, which
/// is what tells it apart. libvirt names a volume by itself in its pool, so
/// two pools can each hold a `debian.iso`; PVE's storages are per node.
typedef _PoolVolume = ({String key, VirtVolume volume, String pool});

class _VirtCreateViewState extends ConsumerState<VirtCreateView>
    with _PaneRows<VirtCreateView> {
  var _kind = VirtGuestKind.qemu;
  var _source = _Source.iso;
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _keys = TextEditingController();
  int? _vmid;
  String? _node;
  var _cores = _defaultCores;
  var _memory = _memorySteps.indexOf(2048);
  var _disk = _diskSteps.indexOf(32);
  VirtStoragePool? _storage;

  /// The install media (or template) and the cloud image chosen, by
  /// [_PoolVolume.key].
  String? _media;
  String? _image;
  VirtNetwork? _network;

  /// The user chose no NIC, rather than none being chosen yet.
  var _noNetwork = false;
  var _unprivileged = true;
  var _start = true;
  var _busy = false;

  /// Null until chosen: the host's default then.
  bool? _uefi;
  var _secureBoot = false;
  var _tpm = false;
  String? _bus;
  String? _nicModel;

  // cloud-init
  final _ciUser = TextEditingController();
  final _ciPassword = TextEditingController();
  final _ciKeys = TextEditingController();
  final _ciHostname = TextEditingController();
  final _ciAddress = TextEditingController();
  final _ciGateway = TextEditingController();
  final _ciDns = TextEditingController();
  final _ciSearch = TextEditingController();
  var _ciStatic = false;

  /// The hostname was typed rather than following the name.
  var _hostnameTyped = false;

  Future<List<VirtStoragePool>>? _pools;
  Future<List<VirtNetwork>>? _networks;
  Future<VirtCreateOptions>? _options;

  /// Volumes per storage id, fetched once each.
  final _content = <String, Future<List<VirtVolume>>>{};

  /// The volumes of the storages the form offers now, by storage id, and
  /// which storages that read is of: the same future while they stay the
  /// same, so a rebuild does not start it again.
  Future<Map<String, List<VirtVolume>>>? _volumes;
  String? _volumesOf;

  VirtHostNotifier get _notifier =>
      ref.read(virtHostProvider(widget.serverId).notifier);

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(_loadVmid());
  }

  void _load() {
    _content.clear();
    _volumes = null;
    _volumesOf = null;
    _pools = _notifier.storagePools();
    _networks = _notifier.networks();
    _options = _notifier.createOptions();
  }

  @override
  void dispose() {
    for (final c in [
      _name, _password, _keys, _ciUser, _ciPassword, _ciKeys, _ciHostname, //
      _ciAddress, _ciGateway, _ciDns, _ciSearch,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadVmid() async {
    try {
      final id = await _notifier.nextVmid();
      if (!mounted || id == null || _vmid != null) return;
      setState(() => _vmid = id);
    } on VirtErr catch (e) {
      // Stepped to by hand then, from the first VMID there is.
      Loggers.app.info('PVE nextid: ${e.message}');
      if (mounted && _vmid == null) setState(() => _vmid = virtVmidMin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(virtHostProvider(widget.serverId));
    final host = st.data?.host.kind ?? st.kind ?? VirtHostKind.libvirt;
    final lxc = _kind == VirtGuestKind.lxc;
    return Scaffold(
      appBar: virtResourceBar(
        name: host == VirtHostKind.pve && lxc
            ? l10n.virtCreateLxc
            : l10n.virtCreateVm,
        icon: Icons.add_circle_outline,
        leading: widget.leading,
        actions: [
          if (widget.onCancel case final cancel?)
            Btn.icon(
              text: libL10n.cancel,
              icon: const Icon(Icons.close, size: 18),
              onTap: cancel,
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: 3, child: _busy ? const ProgressLine() : null),
          Expanded(
            child: FutureBuilder<List<Object>>(
              future: Future.wait<Object>([?_pools, ?_networks, ?_options]),
              builder: (context, snap) {
                if (snap.error case final e?) {
                  return _buildError(e, onRetry: () => setState(_load));
                }
                final loaded = snap.data;
                if (loaded == null) {
                  return const Center(child: SizedLoading.medium);
                }
                return _buildForm(
                  st,
                  host,
                  loaded[0] as List<VirtStoragePool>,
                  loaded[1] as List<VirtNetwork>,
                  loaded[2] as VirtCreateOptions,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(
    VirtHostState st,
    VirtHostKind host,
    List<VirtStoragePool> pools,
    List<VirtNetwork> networks,
    VirtCreateOptions options,
  ) {
    final data = st.data;
    final pve = host == VirtHostKind.pve;
    final lxc = _kind == VirtGuestKind.lxc;
    final nodes = [
      for (final n in data?.host.nodes ?? const <VirtNode>[])
        if (n.online) n,
    ];
    final node = pve
        ? (nodes.any((n) => n.name == _node) ? _node : nodes.firstOrNull?.name)
        : null;
    final disks = virtDiskStorages(pools, host: host, kind: _kind, node: node);
    final nets = virtCreateNetworks(networks, host: host, node: node);
    final mediaPools = virtMediaStorages(
      pools,
      host: host,
      kind: _kind,
      node: node,
    );
    final imagePools = !lxc && options.cloudImages
        ? virtImageStorages(pools, host: host, node: node)
        : const <VirtStoragePool>[];
    final fromImage = !lxc && options.cloudImages && _source == _Source.image;
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
    final bus = options.buses.contains(_bus) ? _bus : options.buses.firstOrNull;
    final nicModel = options.nicModels.contains(_nicModel)
        ? _nicModel
        : options.nicModels.firstOrNull;
    final uefi = options.uefi && (_uefi ?? true);
    // Secure Boot is UEFI's, and only where the host's firmware can back it.
    final secureBoot = uefi && options.secureBoot && _secureBoot;
    final tpm = options.tpm && _tpm;

    final volumePools = {...mediaPools, ...imagePools}.toList();
    return FutureBuilder<Map<String, List<VirtVolume>>>(
      future: _volumesFor(volumePools),
      builder: (context, snap) {
        final byPool = snap.data;
        // While another node's read is still what the builder holds, nothing
        // of it is on offer: a storage named alike on this node is not it.
        final loaded =
            byPool != null && volumePools.every((p) => byPool.containsKey(p.id));
        List<_PoolVolume> of(
          List<VirtStoragePool> pools,
          bool Function(VirtVolume v) keep,
        ) => [
          if (loaded)
            for (final p in pools)
              for (final v in byPool[p.id]!)
                if (keep(v)) (key: '${p.id}/${v.id}', volume: v, pool: p.name),
        ]..sort((a, b) => a.volume.name.compareTo(b.volume.name));
        final media = of(mediaPools, (v) => virtIsMedia(v, _kind));
        final images = of(imagePools, (v) => virtIsCloudImage(v, host));
        final chosenMedia = media.firstWhereOrNull((v) => v.key == _media);
        final image = images.firstWhereOrNull((v) => v.key == _image);
        final ci = fromImage && options.cloudInit
            ? _cloudInit(pve: pve, withNic: network != null)
            : null;
        final spec = storage == null
            ? null
            : VirtCreateSpec(
                kind: _kind,
                name: _name.text.trim(),
                node: node,
                vmid: pve ? _vmid : null,
                cores: _cores,
                memoryMiB: _memorySteps[_memory],
                storage: storage,
                diskGiB: _diskSteps[_disk],
                media: lxc
                    ? (chosenMedia ?? media.firstOrNull)?.volume
                    : (fromImage ? null : chosenMedia?.volume),
                image: fromImage ? image?.volume : null,
                network: network,
                password: lxc ? _password.text : null,
                sshKeys: lxc ? _keys.text : null,
                unprivileged: _unprivileged,
                bus: lxc ? null : bus,
                nicModel: lxc ? null : nicModel,
                uefi: !lxc && uefi,
                secureBoot: !lxc && secureBoot,
                tpm: !lxc && tpm,
                cloudInit: ci,
                start: _start,
              );
        final issue = spec == null
            ? VirtCreateIssue.storage
            // Without cloud-init (a host with no ISO tool) nothing else says
            // the image is missing: the host would make an empty disk.
            : fromImage && image == null
            ? VirtCreateIssue.image
            : virtCreateIssue(
                spec,
                host: host,
                guests: data?.guests ?? const [],
                maxCores: maxCores,
              );
        // Where the pane's index turns a group orange: what is missing
        // there.
        final generalOk = !const {
          VirtCreateIssue.nameEmpty,
          VirtCreateIssue.nameInvalid,
          VirtCreateIssue.nameTaken,
          VirtCreateIssue.vmidInvalid,
          VirtCreateIssue.vmidTaken,
        }.contains(issue);
        final systemOk =
            !{
              VirtCreateIssue.template,
              VirtCreateIssue.image,
              VirtCreateIssue.imageSize,
            }.contains(issue);
        final ciOk = !_ciIssues.contains(issue) &&
            issue != VirtCreateIssue.sshKeys;
        return _buildGroups(
          [
            _generalGroup(host, issue, node, nodes, generalOk),
            _systemGroup(
              host: host,
              options: options,
              snap: snap,
              loaded: loaded,
              pools: mediaPools.length + imagePools.length,
              media: media,
              images: images,
              chosenMedia: chosenMedia,
              image: image,
              fromImage: fromImage,
              uefi: uefi,
              secureBoot: secureBoot,
              secureBootSupported: options.secureBoot,
              tpm: tpm,
              issue: issue,
              ok: systemOk,
            ),
            if (fromImage) _cloudInitGroup(pve, options, network, issue, ciOk),
            if (lxc) _loginGroup(issue),
            _resourcesGroup(issue),
            _storageGroup(
              disks,
              storage,
              bus,
              options,
              issue,
              minBytes: fromImage ? image?.volume.capacity : null,
            ),
            _networkGroup(nets, network, nicModel, options),
            _confirmGroup(host, spec, issue),
          ],
          onRefresh: () async => setState(_load),
        );
      },
    );
  }

  static const _ciIssues = {
    VirtCreateIssue.ciUser,
    VirtCreateIssue.ciCredentials,
    VirtCreateIssue.ciHostname,
    VirtCreateIssue.ciAddress,
    VirtCreateIssue.ciGateway,
    VirtCreateIssue.ciDns,
    VirtCreateIssue.ciSearch,
  };

  /// The volumes of [pools] by storage id, each storage fetched once; the
  /// same future for the same storages.
  Future<Map<String, List<VirtVolume>>> _volumesFor(
    List<VirtStoragePool> pools,
  ) {
    final ids = (pools.map((p) => p.id).toList()..sort()).join('\n');
    if (_volumes case final f? when _volumesOf == ids) return f;
    _volumesOf = ids;
    return _volumes = () async {
      final lists = await Future.wait([
        for (final p in pools)
          _content.putIfAbsent(p.id, () => _notifier.volumes(p)),
      ]);
      return {for (final (i, p) in pools.indexed) p.id: lists[i]};
    }();
  }

  VirtCloudInit _cloudInit({required bool pve, required bool withNic}) {
    List<String> words(String s) => [
      for (final w in s.split(RegExp(r'[\s,]+')))
        if (w.isNotEmpty) w,
    ];
    final static = withNic && _ciStatic;
    final gateway = _ciGateway.text.trim();
    return VirtCloudInit(
      user: _ciUser.text.trim(),
      password: _ciPassword.text.isEmpty ? null : _ciPassword.text,
      sshKeys: _ciKeys.text,
      hostname: pve ? null : _hostname(),
      address: static ? _ciAddress.text.trim() : null,
      gateway: static && gateway.isNotEmpty ? gateway : null,
      dns: withNic ? words(_ciDns.text) : const [],
      searchDomains: withNic ? words(_ciSearch.text) : const [],
    );
  }

  /// The hostname: as typed, or the name as a DNS label would have it.
  String _hostname() => _hostnameTyped
      ? _ciHostname.text.trim()
      : _name.text.trim().replaceAll(RegExp('[_.]'), '-');

  Color _dot(bool ok) => ok ? StatePalette.running : StatePalette.warn;

  // --- General ---

  _Group _generalGroup(
    VirtHostKind host,
    VirtCreateIssue? issue,
    String? node,
    List<VirtNode> nodes,
    bool ok,
  ) {
    final pve = host == VirtHostKind.pve;
    final lxc = _kind == VirtGuestKind.lxc;
    final caps = ref.read(virtHostProvider(widget.serverId)).data?.capabilities;
    final nameError = _name.text.isEmpty
        ? null
        : switch (issue) {
            VirtCreateIssue.nameInvalid =>
              pve ? l10n.virtCreateNameInvalidPve : l10n.virtCreateNameInvalidLibvirt,
            VirtCreateIssue.nameTaken => l10n.virtCreateNameTaken,
            _ => null,
          };
    final vmid = _vmid;
    return _Group(
      key: 'general',
      title: libL10n.general,
      right: node ?? ref.read(serversProvider).servers[widget.serverId]?.name ?? '',
      warn: false,
      indexNote: _name.text.trim().ifEmpty(l10n.virtCreateUnnamed),
      dot: _dot(ok),
      rows: [
        if (pve && (caps?.lxc ?? false))
          _choice([
            for (final k in VirtGuestKind.values)
              _Choice(
                key: 'create:kind:${k.name}',
                icon: k.icon,
                label: k == VirtGuestKind.qemu ? l10n.virtKindVm : l10n.virtKindLxc,
                sub: k == VirtGuestKind.qemu
                    ? l10n.virtCreateKindVmSub
                    : l10n.virtCreateKindLxcSub,
                selected: _kind == k,
                onTap: () => setState(() {
                  _kind = k;
                  _media = null;
                }),
              ),
          ]),
        _inputRow([Input(
          key: const ValueKey('create:name'),
          controller: _name,
          label: lxc ? l10n.virtHostname : libL10n.name,
          icon: Icons.label_outline,
          noWrap: true,
          suggestion: false,
          errorText: nameError,
          onChanged: (_) => setState(() {
            // The hostname follows the name until it is typed.
            if (!_hostnameTyped) _ciHostname.text = _hostname();
          }),
        )]),
        if (pve)
          _step(
            Icons.tag,
            'VMID',
            vmid == null ? '…' : '$vmid',
            key: 'create-vmid',
            onDec: vmid == null || vmid <= virtVmidMin
                ? null
                : () => setState(() => _vmid = vmid - 1),
            onInc: vmid == null || vmid >= virtVmidMax
                ? null
                : () => setState(() => _vmid = vmid + 1),
          ),
        if (issue == VirtCreateIssue.vmidTaken)
          _text(l10n.virtCreateVmidTaken, error: true),
        if (pve && nodes.length > 1)
          _seg(
            Icons.dns_outlined,
            libL10n.node,
            [for (final n in nodes) n.name],
            node,
            key: 'create:node',
            onSelected: (n) => setState(() {
              _node = n;
              _media = null;
              _image = null;
            }),
          ),
      ],
    );
  }

  // --- System (VM) or template (container) ---

  _Group _systemGroup({
    required VirtHostKind host,
    required VirtCreateOptions options,
    required AsyncSnapshot<Object> snap,
    required bool loaded,
    required int pools,
    required List<_PoolVolume> media,
    required List<_PoolVolume> images,
    required _PoolVolume? chosenMedia,
    required _PoolVolume? image,
    required bool fromImage,
    required bool uefi,
    required bool secureBoot,
    required bool secureBootSupported,
    required bool tpm,
    required VirtCreateIssue? issue,
    required bool ok,
  }) {
    final lxc = _kind == VirtGuestKind.lxc;
    final pve = host == VirtHostKind.pve;
    Widget? waiting() {
      if (snap.error case final e?) {
        return _text(
          e is VirtErr ? [e.title, ?e.detail].join('\n') : '$e',
          error: true,
        );
      }
      if (!loaded) {
        return const Padding(
          padding: EdgeInsets.all(7),
          child: Center(child: SizedLoading.small),
        );
      }
      return null;
    }

    // Where it is, on either host: two pools can hold files of one name, and
    // the rows would otherwise read the same.
    String sub(VirtVolume v, String pool) => [
      if (v.capacity case final size?) size.bytes2Str,
      pool,
    ].join(' · ');

    final List<Widget> rows;
    if (lxc) {
      final template = chosenMedia ?? media.firstOrNull;
      rows = [
        ?waiting(),
        if (loaded)
          media.isEmpty
              ? _text(l10n.virtNoTemplates)
              : _choice([
                  for (final (:key, volume: v, pool: _) in media)
                    _Choice(
                      key: 'create:media:$key',
                      icon: Icons.inventory_2_outlined,
                      label: v.name.split('_').first,
                      sub: v.name.contains('_') ? v.name : null,
                      selected: template?.key == key,
                      onTap: () => setState(() => _media = key),
                    ),
                ]),
        _toggle(
          Icons.shield_outlined,
          l10n.virtUnprivileged,
          _unprivileged,
          key: 'create:unprivileged',
          note: l10n.virtUnprivilegedTip,
          onChanged: (v) => setState(() => _unprivileged = v),
        ),
      ];
    } else {
      final windows =
          !fromImage &&
          (chosenMedia?.volume.name.toLowerCase().contains('win') ?? false);
      rows = [
        if (options.cloudImages)
          _seg(
            Icons.install_desktop_outlined,
            libL10n.source,
            [l10n.virtInstallMedia, l10n.virtCloudImage],
            fromImage ? l10n.virtCloudImage : l10n.virtInstallMedia,
            key: 'create:source',
            onSelected: (s) => setState(
              () => _source = s == l10n.virtCloudImage ? _Source.image : _Source.iso,
            ),
          ),
        ?waiting(),
        if (loaded && !fromImage) ...[
          _choice([
            // Nothing to install from: a network boot, or a disk that
            // gets its system later.
            _Choice(
              key: 'create:media:none',
              icon: Icons.block,
              label: libL10n.none,
              selected: chosenMedia == null,
              onTap: () => setState(() => _media = null),
            ),
            for (final (:key, volume: v, :pool) in media)
              _Choice(
                key: 'create:media:$key',
                icon: Icons.album_outlined,
                label: v.name,
                sub: sub(v, pool),
                selected: chosenMedia?.key == key,
                onTap: () => setState(() => _media = key),
              ),
          ]),
          if (media.isEmpty) _text(l10n.virtNoIsos),
        ],
        if (loaded && fromImage) ...[
          _text(l10n.virtCloudImageTip),
          if (images.isEmpty)
            _text(pve ? l10n.virtNoCloudImagesPve : l10n.virtNoCloudImagesLibvirt)
          else
            _choice([
              for (final (:key, volume: v, :pool) in images)
                _Choice(
                  key: 'create:image:$key',
                  icon: Icons.cloud_outlined,
                  label: v.name,
                  sub: [sub(v, pool), ?v.format].where((s) => s.isNotEmpty).join(' · '),
                  selected: image?.key == key,
                  onTap: () => setState(() {
                    _image = key;
                    // At least the image's own size, which it is grown from.
                    final need = v.capacity;
                    if (need != null && _diskSteps[_disk] * (1 << 30) < need) {
                      final i = _diskSteps.indexWhere((g) => g * (1 << 30) >= need);
                      if (i >= 0) _disk = i;
                    }
                  }),
                ),
            ]),
        ],
        if (options.uefi)
          _seg(
            Icons.memory_outlined,
            l10n.virtHwFirmware,
            const ['UEFI', 'BIOS'],
            uefi ? 'UEFI' : 'BIOS',
            key: 'create:firmware',
            onSelected: (f) => setState(() => _uefi = f == 'UEFI'),
          ),
        if (options.uefi && options.secureBoot)
          _toggle(
            Icons.verified_user_outlined,
            l10n.virtCreateSecureBoot,
            secureBoot,
            key: 'create:secure-boot',
            note: l10n.virtCreateSecureBootNote,
            onChanged: (v) => setState(() => _secureBoot = v),
          ),
        if (options.uefi && !options.secureBoot)
          _text(l10n.virtSbUnsupported),
        if (options.tpm)
          _toggle(
            Icons.shield_outlined,
            'TPM 2.0',
            tpm,
            key: 'create:tpm',
            note: l10n.virtHwTpmNote,
            onChanged: (v) => setState(() => _tpm = v),
          ),
        if (windows && !(uefi && tpm))
          _callout(
            l10n.virtCreateWindowsTitle,
            options.tpm ? l10n.virtCreateWindowsBody : l10n.virtCreateWindowsNoTpm,
            warn: false,
          ),
      ];
    }
    final chosen = lxc
        ? (chosenMedia ?? media.firstOrNull)?.volume.name
        : fromImage
        ? image?.volume.name
        : chosenMedia?.volume.name;
    return _Group(
      key: 'system',
      title: lxc ? l10n.virtTemplate : libL10n.system,
      right: lxc
          ? 'vztmpl'
          : fromImage
          ? l10n.virtCloudImage
          : l10n.virtInstallMedia,
      warn: false,
      indexNote: chosen ?? l10n.virtCreateNotChosen,
      dot: _dot(ok),
      rows: [
        ...rows,
        if (issue == VirtCreateIssue.imageSize && image?.volume.capacity != null)
          _text(
            l10n.virtCreateImageSize(image!.volume.capacity!.bytes2Str),
            error: true,
          ),
      ],
    );
  }

  // --- cloud-init (a cloud image) ---

  _Group _cloudInitGroup(
    bool pve,
    VirtCreateOptions options,
    VirtNetwork? network,
    VirtCreateIssue? issue,
    bool ok,
  ) {
    String? on(VirtCreateIssue which, String text, TextEditingController c) =>
        issue == which && c.text.isNotEmpty ? text : null;
    final rows = <Widget>[];
    if (!options.cloudInit) {
      rows.add(
        _callout(
          l10n.virtCiNoToolTitle,
          l10n.virtCiNoToolBody(options.cloudInitMissing ?? ''),
          key: const ValueKey('create:ci:no-tool'),
        ),
      );
    } else {
      rows.addAll([
        _text(l10n.virtCiTip),
        _inputRow([Input(
          key: const ValueKey('create:ci:user'),
          controller: _ciUser,
          label: libL10n.user,
          icon: Icons.person_outline,
          hint: 'debian',
          noWrap: true,
          suggestion: false,
          errorText: on(VirtCreateIssue.ciUser, l10n.virtCiUserInvalid, _ciUser),
          onChanged: (_) => setState(() {}),
        )]),
        _inputRow([Input(
          key: const ValueKey('create:ci:password'),
          controller: _ciPassword,
          label: libL10n.pwd,
          icon: Icons.password,
          obscureText: true,
          noWrap: true,
          suggestion: false,
          onChanged: (_) => setState(() {}),
        )]),
        _inputRow([Input(
          key: const ValueKey('create:ci:keys'),
          controller: _ciKeys,
          label: l10n.virtSshKeys,
          icon: Icons.vpn_key_outlined,
          hint: 'ssh-ed25519 AAAA…',
          minLines: 1,
          maxLines: 4,
          noWrap: true,
          suggestion: false,
          errorText: issue == VirtCreateIssue.sshKeys
              ? l10n.virtCreateSshKeysInvalid
              : null,
          onChanged: (_) => setState(() {}),
        )]),
        if (issue == VirtCreateIssue.ciCredentials &&
            _ciUser.text.trim().isNotEmpty)
          _text(l10n.virtCiCredentialsMissing, error: true),
        if (!pve)
          _inputRow([Input(
            key: const ValueKey('create:ci:hostname'),
            controller: _ciHostname,
            label: l10n.virtHostname,
            icon: Icons.dns_outlined,
            noWrap: true,
            suggestion: false,
            errorText: issue == VirtCreateIssue.ciHostname && _hostname().isNotEmpty
                ? l10n.virtCreateNameInvalidPve
                : null,
            onChanged: (_) => setState(() => _hostnameTyped = true),
          )])
        else
          _text(l10n.virtCiHostnamePve),
        if (network != null) ...[
          _seg(
            Icons.lan_outlined,
            libL10n.addr,
            ['DHCP', l10n.virtCiStatic],
            _ciStatic ? l10n.virtCiStatic : 'DHCP',
            key: 'create:ci:ip',
            onSelected: (v) => setState(() => _ciStatic = v != 'DHCP'),
          ),
          if (_ciStatic) ...[
            _inputRow([Input(
              key: const ValueKey('create:ci:address'),
              controller: _ciAddress,
              label: 'IPv4 / CIDR',
              icon: Icons.language,
              hint: '10.0.0.5/24',
              noWrap: true,
              suggestion: false,
              errorText: on(VirtCreateIssue.ciAddress, l10n.virtCiAddressInvalid, _ciAddress),
              onChanged: (_) => setState(() {}),
            )]),
            _inputRow([Input(
              key: const ValueKey('create:ci:gateway'),
              controller: _ciGateway,
              label: libL10n.gateway,
              icon: Icons.router_outlined,
              hint: '10.0.0.1',
              noWrap: true,
              suggestion: false,
              errorText: on(VirtCreateIssue.ciGateway, l10n.virtCiGatewayInvalid, _ciGateway),
              onChanged: (_) => setState(() {}),
            )]),
          ],
          _inputRow([Input(
            key: const ValueKey('create:ci:dns'),
            controller: _ciDns,
            label: 'DNS',
            icon: Icons.dns_outlined,
            hint: _ciStatic ? '1.1.1.1 9.9.9.9' : l10n.virtCiDnsFromDhcp,
            noWrap: true,
            suggestion: false,
            errorText: on(VirtCreateIssue.ciDns, l10n.virtCiDnsInvalid, _ciDns),
            onChanged: (_) => setState(() {}),
          )]),
          _inputRow([Input(
            key: const ValueKey('create:ci:search'),
            controller: _ciSearch,
            label: l10n.virtCiSearch,
            icon: Icons.travel_explore,
            hint: 'lab.example',
            noWrap: true,
            suggestion: false,
            errorText: on(VirtCreateIssue.ciSearch, l10n.virtCreateNameInvalidPve, _ciSearch),
            onChanged: (_) => setState(() {}),
          )]),
        ],
        if (!pve) _text(l10n.virtCiSeedNote),
      ]);
    }
    return _Group(
      key: 'cloud-init',
      title: 'cloud-init',
      right: pve ? 'cloudinit' : 'NoCloud',
      warn: false,
      indexNote: options.cloudInit
          ? _ciUser.text.trim().ifEmpty(l10n.virtCreateNotChosen)
          : l10n.virtCiNoToolTitle,
      dot: _dot(ok && options.cloudInit),
      rows: rows,
    );
  }

  /// A container's root login: a password, keys, or both.
  _Group _loginGroup(VirtCreateIssue? issue) {
    final ok = !const {
      VirtCreateIssue.credentials,
      VirtCreateIssue.password,
      VirtCreateIssue.sshKeys,
    }.contains(issue);
    return _Group(
      key: 'login',
      title: 'root',
      right: '',
      warn: false,
      indexNote: l10n.virtCredentialsTip,
      dot: _dot(ok),
      rows: [
        _text(l10n.virtCredentialsTip),
        _inputRow([Input(
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
        )]),
        _inputRow([Input(
          key: const ValueKey('create:keys'),
          controller: _keys,
          label: l10n.virtSshKeys,
          icon: Icons.vpn_key_outlined,
          hint: 'ssh-ed25519 AAAA…',
          minLines: 1,
          maxLines: 4,
          noWrap: true,
          suggestion: false,
          errorText: issue == VirtCreateIssue.sshKeys
              ? l10n.virtCreateSshKeysInvalid
              : null,
          onChanged: (_) => setState(() {}),
        )]),
      ],
    );
  }

  // --- Resources ---

  _Group _resourcesGroup(VirtCreateIssue? issue) {
    final lxc = _kind == VirtGuestKind.lxc;
    final mem = (_memorySteps[_memory] << 20).bytes2Str;
    return _Group(
      key: 'resources',
      title: l10n.virtHwResources,
      right: '',
      warn: false,
      indexNote: '$_cores ${lxc ? l10n.cores : 'vCPU'} · $mem',
      dot: _dot(issue != VirtCreateIssue.cores && issue != VirtCreateIssue.memory),
      rows: [
        _step(
          Icons.developer_board,
          lxc ? l10n.cores : 'vCPU',
          '$_cores',
          key: 'create-cores',
          onDec: _cores > 1 ? () => setState(() => _cores--) : null,
          onInc: () => setState(() => _cores++),
        ),
        _step(
          Icons.memory,
          libL10n.memory,
          mem,
          key: 'create-memory',
          onDec: _memory > 0 ? () => setState(() => _memory--) : null,
          onInc: _memory < _memorySteps.length - 1
              ? () => setState(() => _memory++)
              : null,
        ),
        if (issue == VirtCreateIssue.cores)
          _text(l10n.virtCreateCoresInvalid, error: true)
        else if (issue == VirtCreateIssue.memory)
          _text(l10n.virtCreateMemoryInvalid, error: true),
      ],
    );
  }

  // --- Storage ---

  _Group _storageGroup(
    List<VirtStoragePool> disks,
    VirtStoragePool? storage,
    String? bus,
    VirtCreateOptions options,
    VirtCreateIssue? issue, {
    int? minBytes,
  }) {
    final lxc = _kind == VirtGuestKind.lxc;
    final pve = ref.read(virtHostProvider(widget.serverId)).kind == VirtHostKind.pve;
    // A cloud image's copy holds at least the image: no step below it.
    final canDec =
        _disk > 0 &&
        (minBytes == null || _diskSteps[_disk - 1] * (1 << 30) >= minBytes);
    return _Group(
      key: 'storage',
      title: libL10n.storage,
      right: storage == null || pve ? '' : virtLibvirtDiskFormat(storage.type),
      warn: false,
      indexNote:
          '${storage?.name ?? l10n.virtCreateNotChosen} · ${_diskSteps[_disk]} GiB',
      dot: _dot(storage != null && issue != VirtCreateIssue.diskSize),
      rows: [
        if (disks.isEmpty)
          _text(l10n.virtNoDiskStorage)
        else
          _choice([
            for (final p in disks)
              _Choice(
                key: 'create:storage:${p.id}',
                icon: Icons.storage_outlined,
                label: p.name,
                sub: [
                  p.type,
                  if (p.available case final free?) l10n.virtHwFree(free.bytes2Str),
                ].join(' · '),
                selected: p.id == storage?.id,
                onTap: () => setState(() => _storage = p),
              ),
          ]),
        _step(
          Icons.straighten,
          libL10n.size,
          '${_diskSteps[_disk]} GiB',
          key: 'create-disk',
          onDec: canDec ? () => setState(() => _disk--) : null,
          onInc: _disk < _diskSteps.length - 1
              ? () => setState(() => _disk++)
              : null,
        ),
        if (!lxc && options.buses.length > 1)
          _seg(
            Icons.cable,
            l10n.virtHwBus,
            options.buses,
            bus,
            key: 'create:bus',
            onSelected: (b) => setState(() => _bus = b),
          ),
        if (issue == VirtCreateIssue.diskSize)
          _text(l10n.virtCreateDiskInvalid, error: true),
      ],
    );
  }

  // --- Network ---

  _Group _networkGroup(
    List<VirtNetwork> nets,
    VirtNetwork? network,
    String? model,
    VirtCreateOptions options,
  ) {
    final lxc = _kind == VirtGuestKind.lxc;
    return _Group(
      key: 'network',
      title: libL10n.network,
      right: '',
      warn: false,
      indexNote: network?.name ?? libL10n.none,
      dot: _dot(true),
      rows: [
        _choice([
          _Choice(
            key: 'create:network:none',
            icon: Icons.block,
            label: libL10n.none,
            selected: network == null,
            onTap: () => setState(() => _noNetwork = true),
          ),
          for (final n in nets)
            _Choice(
              key: 'create:network:${n.id}',
              icon: Icons.lan_outlined,
              label: n.name,
              sub: [
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
        ]),
        if (network != null && !lxc && options.nicModels.length > 1)
          _seg(
            Icons.settings_ethernet,
            l10n.virtHwModel,
            options.nicModels,
            model,
            key: 'create:model',
            onSelected: (m) => setState(() => _nicModel = m),
          ),
        if (network?.mode == 'isolated') _text(l10n.virtNetIsolatedTip),
      ],
    );
  }

  // --- Confirm ---

  _Group _confirmGroup(
    VirtHostKind host,
    VirtCreateSpec? spec,
    VirtCreateIssue? issue,
  ) {
    final lxc = _kind == VirtGuestKind.lxc;
    final ready = spec != null && issue == null;
    // Said here; the ones a field shows are said there.
    final note = switch (issue) {
      null => null,
      VirtCreateIssue.storage => l10n.virtCreateStorageMissing,
      VirtCreateIssue.template => l10n.virtCreateTemplateMissing,
      VirtCreateIssue.credentials => l10n.virtCreateCredentialsMissing,
      VirtCreateIssue.image => l10n.virtCreateImageMissing,
      _ => l10n.virtCreateIncomplete,
    };
    final name = ref.read(serversProvider).servers[widget.serverId]?.name;
    return _Group(
      key: 'confirm',
      title: libL10n.confirm,
      right: name == null ? '' : l10n.virtCreateOn(name),
      warn: false,
      indexNote: ready ? libL10n.ready : l10n.virtCreateIncomplete,
      dot: _dot(ready),
      rows: [
        _toggle(
          Icons.play_arrow_outlined,
          l10n.virtStartAfterCreate,
          _start,
          key: 'create:start',
          onChanged: (v) => setState(() => _start = v),
        ),
        ?note == null ? null : _text(note, error: true),
        _actions([
          if (widget.onCancel case final cancel?)
            _Action(libL10n.cancel, icon: Icons.close, onTap: cancel),
          _Action(
            host == VirtHostKind.pve && lxc
                ? l10n.virtCreateLxc
                : l10n.virtCreateVm,
            key: 'create:submit',
            primary: true,
            onTap: !ready || _busy ? null : () => unawaited(_create(spec)),
          ),
        ]),
      ],
    );
  }

  Future<void> _create(VirtCreateSpec spec) async {
    setState(() => _busy = true);
    try {
      final created = await _notifier.create(spec);
      final kept = switch (created.diskKeptBytes) {
        final b? => l10n.virtCreateDiskKept(b.bytes2Str),
        null => null,
      };
      if (created.startError case final err?) {
        Toast.warn(
          l10n.virtCreatedNotStarted(spec.name),
          body: [err, ?kept].join('\n'),
        );
      } else if (kept != null) {
        Toast.info(l10n.virtCreated(spec.name), body: kept);
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
}
