import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_rates.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';

/// Reading PVE API answers into the Virtualization models. Pure functions,
/// tested against captured payloads.
///
/// Lenient where the parser it replaced (the PVE page's `PveRes`) was strict:
/// a field missing from one entry (a guest being created has no name yet, an offline node no
/// figures) costs that field, not the whole listing.
abstract final class PveResources {
  /// `/cluster/resources`: the nodes, the guests (templates included, marked),
  /// and each guest's counters at [at].
  static ({
    List<VirtNode> nodes,
    List<VirtGuest> guests,
    Map<String, VirtCounterSample> samples,
  })
  parse(List<Object?> raw, {required DateTime at}) {
    final nodes = <VirtNode>[];
    final guests = <VirtGuest>[];
    final samples = <String, VirtCounterSample>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final e = item.cast<String, Object?>();
      switch (e['type']) {
        case 'node':
          final name = _str(e['node']);
          if (name == null) continue;
          nodes.add(
            VirtNode(
              name: name,
              online: e['status'] == 'online',
              cpu: _double(e['cpu']),
              maxCpu: _int(e['maxcpu']),
              memUsed: _int(e['mem']),
              memTotal: _int(e['maxmem']),
              uptime: _duration(e['uptime']),
            ),
          );
        case final String type when type == 'qemu' || type == 'lxc':
          final vmid = _int(e['vmid']);
          final id = _str(e['id']) ?? (vmid == null ? null : '$type/$vmid');
          if (id == null) continue;
          final kind = type == 'lxc' ? VirtGuestKind.lxc : VirtGuestKind.qemu;
          final status = _str(e['status']);
          final lock = _str(e['lock']);
          final template = _int(e['template']) == 1;
          final state = stateOf(status, lock);
          guests.add(
            VirtGuest(
              id: id,
              name: _str(e['name']) ?? '${vmid ?? id}',
              kind: kind,
              state: state,
              stateReason: lock ?? (status == state.name ? null : status),
              vmid: vmid,
              node: _str(e['node']),
              vcpu: _int(e['maxcpu']),
              memBytes: _int(e['maxmem']),
              uptime: _duration(e['uptime']),
              tags: _tags(e['tags']),
              template: template,
              actions: template
                  ? const {}
                  : actionsOf(status, lock, kind, state),
            ),
          );
          // What runs, whatever holds the lock: a VM being backed up is
          // still running, and its counters still count.
          final active = stateOf(status, null).isActive;
          final cpu = _double(e['cpu']);
          samples[id] = VirtCounterSample(
            at: at,
            cpuPercent: active && cpu != null ? cpu * 100 : null,
            vcpus: _int(e['maxcpu']),
            memUsed: active ? _int(e['mem']) : null,
            memTotal: _int(e['maxmem']),
            // QEMU reports 0 used without the guest agent; that is "not
            // known", not an empty disk.
            diskUsed: _positive(_int(e['disk'])),
            diskTotal: _positive(_int(e['maxdisk'])),
            diskRead: active ? _int(e['diskread']) : null,
            diskWrite: active ? _int(e['diskwrite']) : null,
            netIn: active ? _int(e['netin']) : null,
            netOut: active ? _int(e['netout']) : null,
          );
      }
    }
    return (nodes: nodes, guests: guests, samples: samples);
  }

  /// What a guest with PVE's [status] and [lock] offers, [state] being
  /// [stateOf] the two.
  ///
  /// A lock is an operation in progress (snapshot, clone, rollback, ...) that
  /// PVE refuses power actions during, with two exceptions. `suspended` is a
  /// hibernated VM, which `start` resumes. `backup` still lets a VM be paused
  /// and resumed (`vm_suspend` and `vm_resume` skip the lock check for it,
  /// PVE 9.2 `QemuServer/RunState.pm`; verified, test/e2e/virt_real_test.dart),
  /// which is how a paused VM that a backup job picked up is woken.
  static Set<VirtPowerAction> actionsOf(
    String? status,
    String? lock,
    VirtGuestKind kind,
    VirtGuestState state,
  ) {
    final qemu = kind == VirtGuestKind.qemu;
    return switch (lock) {
      null || 'suspended' => VirtPowerAction.offered(state, pause: qemu),
      'backup' when qemu => switch (status) {
        'running' => const {VirtPowerAction.suspend},
        'paused' => const {VirtPowerAction.resume},
        _ => const {},
      },
      _ => const {},
    };
  }

  /// PVE's `status` and `lock`, as one state.
  ///
  /// `status` is the QEMU run state where `pvestatd` has one, so beside
  /// `running` and `stopped` it can be `paused`, `prelaunch`, `suspended`
  /// (S3), `io-error`, `internal-error`, `guest-panicked`, ... A `lock` wins
  /// where it names what the guest is busy with.
  static VirtGuestState stateOf(String? status, String? lock) {
    switch (lock) {
      case 'backup':
        return VirtGuestState.backup;
      case 'migrate':
        return VirtGuestState.migrating;
      case 'suspending':
        return VirtGuestState.stopping;
    }
    return switch (status) {
      'running' => VirtGuestState.running,
      'stopped' => VirtGuestState.stopped,
      'paused' || 'suspended' || 'io-error' => VirtGuestState.paused,
      'prelaunch' || 'inmigrate' => VirtGuestState.starting,
      'shutdown' => VirtGuestState.stopping,
      'postmigrate' || 'finish-migrate' => VirtGuestState.migrating,
      _ => VirtGuestState.unknown,
    };
  }

  /// `/nodes/{node}/{type}/{vmid}/rrddata`: rates already, bytes per second.
  static List<VirtStats> parseRrd(List<Object?> raw) {
    final out = <VirtStats>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final e = item.cast<String, Object?>();
      final time = _int(e['time']);
      if (time == null) continue;
      final cpu = _double(e['cpu']);
      out.add(
        VirtStats(
          at: DateTime.fromMillisecondsSinceEpoch(time * 1000),
          cpu: cpu == null ? null : cpu * 100,
          memUsed: _double(e['mem'])?.round(),
          memTotal: _double(e['maxmem'])?.round(),
          diskUsed: _positive(_double(e['disk'])?.round()),
          diskTotal: _positive(_double(e['maxdisk'])?.round()),
          diskRead: _double(e['diskread']),
          diskWrite: _double(e['diskwrite']),
          netIn: _double(e['netin']),
          netOut: _double(e['netout']),
        ),
      );
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  static final _qemuDisk = RegExp(
    r'^(ide|sata|scsi|virtio|efidisk|tpmstate|unused)(\d+)$',
  );
  static final _lxcDisk = RegExp(r'^(rootfs|mp\d+|unused\d+)$');
  static final _net = RegExp(r'^net(\d+)$');
  static final _serial = RegExp(r'^serial\d+$');

  /// `/nodes/{node}/{type}/{vmid}/config`.
  static VirtGuestDetail parseConfig(
    Map<String, Object?> config,
    VirtGuestKind kind,
  ) {
    final disks = <VirtDisk>[];
    final nics = <VirtNic>[];
    var hasSerial = false;
    final keys = config.keys.toList()..sort(_naturalCompare);
    for (final key in keys) {
      final value = config[key];
      if (value is! String) continue;
      if (kind == VirtGuestKind.qemu && _serial.hasMatch(key)) {
        hasSerial = true;
      }
      final diskMatch = kind == VirtGuestKind.qemu
          ? _qemuDisk.firstMatch(key)
          : _lxcDisk.firstMatch(key);
      if (diskMatch != null) {
        disks.add(_disk(key, value, kind, diskMatch));
        continue;
      }
      if (_net.hasMatch(key)) nics.add(_nic(key, value, kind));
    }

    final vgaRaw = config['vga'];
    final vga = vgaRaw is String ? _options(vgaRaw).first.$2 : 'std';
    // `vga: serial0` puts the display on the serial port, and `none` has no
    // display: neither has a VNC console.
    final hasVnc = vga != 'none' && !vga.startsWith('serial');
    final graphics = <VirtGraphics>[
      if (kind == VirtGuestKind.qemu) VirtGraphics(kind: vga),
    ];
    return VirtGuestDetail(
      disks: disks,
      nics: nics,
      graphics: graphics,
      consoles: switch (kind) {
        VirtGuestKind.lxc => const {VirtConsoleKind.text},
        VirtGuestKind.qemu => {
          if (hasVnc) VirtConsoleKind.vnc,
          if (hasSerial) VirtConsoleKind.text,
        },
      },
      description: _str(config['description']),
      arch: _str(config['arch']),
      machine: _str(config['ostype']) ?? _str(config['machine']),
    );
  }

  static VirtDisk _disk(
    String key,
    String value,
    VirtGuestKind kind,
    RegExpMatch match,
  ) {
    final opts = _options(value);
    final named = {for (final (k, v) in opts) k: v};
    // The first option is the volume, written without a key.
    final volume = opts.first.$1.isEmpty ? opts.first.$2 : named['file'];
    final media = named['media'];
    final source = volume == null || volume == 'none' ? null : volume;
    final String device;
    if (kind == VirtGuestKind.lxc) {
      device = key == 'rootfs' ? 'rootfs' : 'mp';
    } else {
      device = media == 'cdrom' ? 'cdrom' : 'disk';
    }
    return VirtDisk(
      device: device,
      source: source,
      target: key,
      bus: kind == VirtGuestKind.qemu ? match.group(1) : null,
      format: named['format'],
      readonly: named['ro'] == '1' || media == 'cdrom',
      size: _size(named['size']),
    );
  }

  static VirtNic _nic(String key, String value, VirtGuestKind kind) {
    final opts = _options(value);
    final named = {for (final (k, v) in opts) k: v};
    if (kind == VirtGuestKind.lxc) {
      return VirtNic(
        kind: key,
        mac: named['hwaddr'],
        source: named['bridge'],
        model: named['type'] ?? 'veth',
        target: named['name'],
      );
    }
    // `virtio=BC:24:11:AA:BB:CC,bridge=vmbr0`: the model is the key of the
    // pair that carries the MAC.
    const models = {
      'virtio',
      'e1000',
      'e1000e',
      'rtl8139',
      'vmxnet3',
      'i82551',
      'i82557b',
      'i82559er',
      'ne2k_isa',
      'ne2k_pci',
      'pcnet',
    };
    String? model;
    String? mac;
    for (final (k, v) in opts) {
      if (models.contains(k)) {
        model = k;
        mac = v.isEmpty ? null : v;
        break;
      }
    }
    return VirtNic(
      kind: key,
      mac: mac ?? named['macaddr'],
      source: named['bridge'],
      model: model ?? named['model'],
    );
  }

  // ---------------------------------------------------------------------------
  // Snapshots, storage, networks
  // ---------------------------------------------------------------------------

  /// `GET .../{qemu|lxc}/{vmid}/snapshot`. The listing ends in an entry named
  /// `current` ("You are here!"), which is not a snapshot: its `parent` is the
  /// current one.
  static List<VirtGuestSnapshot> parseSnapshots(List<Object?> raw) {
    String? current;
    final out = <VirtGuestSnapshot>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final e = item.cast<String, Object?>();
      final name = _str(e['name']);
      if (name == null) continue;
      if (name == 'current') {
        current = _str(e['parent']);
        continue;
      }
      final time = _int(e['snaptime']);
      final desc = _str(e['description'])?.trimRight();
      out.add(
        VirtGuestSnapshot(
          name: name,
          parent: _str(e['parent']),
          description: desc == null || desc.isEmpty ? null : desc,
          createdAt: time == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(time * 1000),
          withMemory: _int(e['vmstate']) == 1,
        ),
      );
    }
    return [
      for (final s in out) s.name == current ? s.copyWith(current: true) : s,
    ];
  }

  /// `GET /nodes/{node}/storage` for [node], with what `GET /storage` (the
  /// cluster's storage configuration, [config]) says of where each one is.
  static List<VirtStoragePool> parseStorages(
    String node,
    List<Object?> raw, {
    List<Object?>? config,
  }) {
    final configs = <String, Map<String, Object?>>{};
    for (final c in config ?? const <Object?>[]) {
      if (c is! Map) continue;
      final id = _str(c['storage']);
      if (id != null) configs[id] = c.cast<String, Object?>();
    }
    final out = <VirtStoragePool>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final e = item.cast<String, Object?>();
      final name = _str(e['storage']);
      if (name == null) continue;
      final c = configs[name] ?? const <String, Object?>{};
      final type = _str(e['type']) ?? _str(c['type']) ?? '';
      final total = _positive(_int(e['total']));
      out.add(
        VirtStoragePool(
          id: '$node/$name',
          name: name,
          node: node,
          type: type,
          path: _storagePath(type, c),
          source: _storageSource(c),
          capacity: total,
          used: total == null ? null : _int(e['used']),
          available: total == null ? null : _int(e['avail']),
          active: _int(e['active']) == 1,
          enabled: switch (_int(e['enabled'])) {
            null => null,
            final v => v == 1,
          },
          shared: _int(e['shared']) == 1,
          content: [
            for (final c in (_str(e['content']) ?? _str(c['content']) ?? '')
                .split(','))
              if (c.trim().isNotEmpty) c.trim(),
          ]..sort(),
        ),
      );
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  /// Where a storage keeps its volumes, by its type's configuration keys.
  static String? _storagePath(String type, Map<String, Object?> c) {
    if (_str(c['path']) case final path?) return path;
    final vg = _str(c['vgname']);
    final thin = _str(c['thinpool']);
    if (vg != null) return thin == null ? vg : '$vg/$thin';
    return _str(c['pool']) ?? _str(c['datastore']);
  }

  /// Where a network storage comes from.
  static String? _storageSource(Map<String, Object?> c) {
    final server = _str(c['server']) ?? _str(c['portal']);
    final export = _str(c['export']) ?? _str(c['share']) ?? _str(c['target']);
    if (server != null && export != null) return '$server:$export';
    return server ?? _str(c['monhost']);
  }

  /// `GET /nodes/{node}/storage/{storage}/content`. The owner is `vmid`.
  static List<VirtVolume> parseContent(List<Object?> raw) {
    final out = <VirtVolume>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final e = item.cast<String, Object?>();
      final volid = _str(e['volid']);
      if (volid == null) continue;
      // `local:iso/debian.iso` → `debian.iso`; `local-lvm:vm-100-disk-0`.
      final afterStorage = volid.substring(volid.indexOf(':') + 1);
      final name = afterStorage.substring(afterStorage.lastIndexOf('/') + 1);
      final vmid = _int(e['vmid']);
      final ctime = _int(e['ctime']);
      out.add(
        VirtVolume(
          id: volid,
          name: name.isEmpty ? volid : name,
          format: _str(e['format']),
          content: _str(e['content']),
          capacity: _int(e['size']),
          allocation: _int(e['used']),
          createdAt: ctime == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(ctime * 1000),
          users: [if (vmid != null && vmid > 0) VirtGuestRef(vmid: vmid)],
        ),
      );
    }
    return out;
  }

  /// `GET /nodes/{node}/network`, with [users] by bridge name.
  static List<VirtNetwork> parseNetworks(
    String node,
    List<Object?> raw, {
    Map<String, List<VirtGuestRef>> users = const {},
  }) {
    List<String> words(Object? v) => [
      for (final w in (_str(v) ?? '').split(RegExp(r'[\s,]+')))
        if (w.isNotEmpty) w,
    ];
    final out = <VirtNetwork>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final e = item.cast<String, Object?>();
      final iface = _str(e['iface']);
      if (iface == null) continue;
      final type = _str(e['type']) ?? 'unknown';
      out.add(
        VirtNetwork(
          id: '$node/$iface',
          name: iface,
          node: node,
          mode: type,
          cidrs: [?_str(e['cidr']), ?_str(e['cidr6'])],
          gateway: _str(e['gateway']),
          ports: [
            ...words(e['bridge_ports']),
            ...words(e['ovs_ports']),
            ...words(e['slaves']),
          ],
          vlanAware: switch (e['bridge_vlan_aware']) {
            null => null,
            final v => _int(v) == 1,
          },
          vlanId: _int(e['vlan-id']),
          vlanDevice: _str(e['vlan-raw-device']),
          bondMode: _str(e['bond_mode']),
          active: _int(e['active']) == 1,
          autostart: _int(e['autostart']) == 1,
          comment: _str(e['comments'])?.trim(),
          users: users[iface] ?? const [],
        ),
      );
    }
    // Bridges first — what guests attach to — then bonds, VLANs and ports.
    int rank(VirtNetwork n) => switch (n.mode) {
      'bridge' || 'OVSBridge' => 0,
      'bond' || 'OVSBond' => 1,
      'vlan' || 'OVSIntPort' => 2,
      _ => 3,
    };
    out.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : _naturalCompare(a.name, b.name);
    });
    return out;
  }

  /// A guest's NICs from its configuration, as users of the bridge each is
  /// on.
  static Map<String, List<VirtGuestRef>> bridgeUsers(
    VirtGuest guest,
    Map<String, Object?> config,
  ) {
    final out = <String, List<VirtGuestRef>>{};
    for (final nic in parseConfig(config, guest.kind).nics) {
      final bridge = nic.source;
      if (bridge == null) continue;
      out
          .putIfAbsent(bridge, () => [])
          .add(
            VirtGuestRef(
              guestId: guest.id,
              vmid: guest.vmid,
              device: nic.kind,
              mac: nic.mac?.toLowerCase(),
            ),
          );
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Hardware
  // ---------------------------------------------------------------------------

  /// A guest's hardware from `GET .../config` — which has the pending
  /// changes applied, so the form edits what the next start gets — and
  /// `GET .../pending`, which says what the running guest has instead.
  ///
  /// [limits] and [cpuTypes] are the node's: `/nodes/{node}/status` and
  /// `/nodes/{node}/capabilities/qemu/cpu`.
  static VirtHardware parseHardware({
    required Map<String, Object?> config,
    required List<Object?> pending,
    required VirtGuestKind kind,
    required bool running,
    VirtHwLimits limits = const VirtHwLimits(),
    List<String> cpuTypes = const [],
  }) {
    final lxc = kind == VirtGuestKind.lxc;
    final disks = <VirtHwDisk>[];
    final nics = <VirtHwNic>[];
    final keys = config.keys.toList()..sort(_naturalCompare);
    for (final key in keys) {
      final value = config[key];
      if (value is! String) continue;
      final diskMatch = lxc ? _lxcDisk.firstMatch(key) : _qemuDisk.firstMatch(key);
      if (diskMatch != null) {
        // Detached volumes, EFI vars and a TPM state are not disks to edit.
        if (key.startsWith('unused') ||
            key.startsWith('efidisk') ||
            key.startsWith('tpmstate')) {
          continue;
        }
        final d = _disk(key, value, kind, diskMatch);
        final named = {for (final (k, v) in _options(value)) k: v};
        final source = d.source;
        disks.add(
          VirtHwDisk(
            key: key,
            kind: switch (d.device) {
              'cdrom' => VirtHwDiskKind.cdrom,
              'rootfs' => VirtHwDiskKind.rootfs,
              'mp' => VirtHwDiskKind.mount,
              _ => VirtHwDiskKind.disk,
            },
            source: source,
            size: d.size,
            storage: source != null && source.contains(':')
                ? source.substring(0, source.indexOf(':'))
                : null,
            mountPoint: named['mp'],
            bus: d.bus,
            format: d.format,
            readonly: d.readonly,
          ),
        );
        continue;
      }
      if (_net.hasMatch(key)) {
        final n = _nic(key, value, kind);
        final named = {for (final (k, v) in _options(value)) k: v};
        nics.add(
          VirtHwNic(
            key: key,
            mac: n.mac,
            source: n.source,
            model: n.model,
            linkUp: named['link_down'] != '1',
            firewall: named['firewall'] == '1',
            name: n.target,
          ),
        );
      }
    }

    final VirtHwCpu cpu;
    final VirtHwMemory memory;
    if (lxc) {
      // No `cores`: every core of the host.
      cpu = VirtHwCpu(
        sockets: 1,
        cores: _int(config['cores']) ?? limits.hostCpus ?? 1,
      );
      memory = VirtHwMemory(
        mib: _int(config['memory']) ?? 512,
        swapMib: _int(config['swap']) ?? 512,
      );
    } else {
      final total =
          (_int(config['sockets']) ?? 1) * (_int(config['cores']) ?? 1);
      final vcpus = _int(config['vcpus']);
      final cpuRaw = _str(config['cpu']);
      // `memory` is a property string since PVE 8.1 (`current=2048`), and a
      // number before.
      final memRaw = config['memory'];
      final mib = memRaw is String
          ? _int(_options(memRaw).firstWhere(
              (o) => o.$1.isEmpty || o.$1 == 'current',
              orElse: () => ('', ''),
            ).$2)
          : _int(memRaw);
      cpu = VirtHwCpu(
        sockets: _int(config['sockets']) ?? 1,
        cores: _int(config['cores']) ?? 1,
        online: vcpus == null || vcpus >= total ? null : vcpus,
        type: cpuRaw == null ? null : _cpuType(cpuRaw),
      );
      memory = VirtHwMemory(
        mib: mib ?? 512,
        minMib: _int(config['balloon']),
        balloon: true,
      );
    }

    return VirtHardware(
      kind: kind,
      running: running,
      cpu: cpu,
      memory: memory,
      disks: disks,
      nics: nics,
      boot: lxc ? null : _bootOrder(_str(config['boot']), config, disks, nics),
      autostart: _int(config['onboot']) == 1,
      pending: [
        for (final item in pending)
          if (item is Map && item['key'] != 'digest')
            if (item.containsKey('pending') || item.containsKey('delete'))
              VirtPendingField(
                key: '${item['key']}',
                current: item['value']?.toString(),
                pending: item['pending']?.toString(),
                delete: _int(item['delete']) != null && _int(item['delete'])! > 0,
              ),
      ],
      revision: _str(config['digest']),
      limits: limits,
      cpuTypes: cpuTypes,
      configText: [
        for (final k in keys)
          if (k != 'digest' && config[k] != null) '$k: ${config[k]}',
      ].join('\n'),
    );
  }

  /// `cpu: host,flags=+aes` or `cputype=host,…`: the model.
  static String? _cpuType(String raw) {
    for (final (k, v) in _options(raw)) {
      if (k.isEmpty || k == 'cputype') return v.isEmpty ? null : v;
    }
    return null;
  }

  /// `cpu`'s value with the model set to [type], its other options kept.
  static String withCpuType(String? raw, String type) {
    final rest = raw == null
        ? const <(String, String)>[]
        : [
            for (final o in _options(raw))
              if (o.$1.isNotEmpty && o.$1 != 'cputype') o,
          ];
    return [type, for (final (k, v) in rest) '$k=$v'].join(',');
  }

  /// `boot`: `order=scsi0;ide2;net0`, or the legacy letters (`cdn`, with
  /// `bootdisk` naming the disk) read the way PVE reads them.
  static List<String> _bootOrder(
    String? raw,
    Map<String, Object?> config,
    List<VirtHwDisk> disks,
    List<VirtHwNic> nics,
  ) {
    if (raw == null) return const [];
    final named = {for (final (k, v) in _options(raw)) k: v};
    final order = named['order'];
    if (order != null) {
      return order.split(';').where((k) => k.isNotEmpty).toList();
    }
    final legacy = named[''] ?? named['legacy'] ?? '';
    final out = <String>[];
    for (final c in legacy.split('')) {
      final key = switch (c) {
        'c' => _str(config['bootdisk']) ??
            disks.where((d) => d.kind == VirtHwDiskKind.disk).firstOrNull?.key,
        'd' => disks.where((d) => d.kind == VirtHwDiskKind.cdrom).firstOrNull?.key,
        'n' => nics.firstOrNull?.key,
        _ => null,
      };
      if (key != null && !out.contains(key)) out.add(key);
    }
    return out;
  }

  /// [raw] with [set] applied: a key to a value, or to null to drop it. The
  /// options it does not name stay as they were, in their place — a NIC's
  /// MAC among them, which rewriting the option from scratch would lose.
  static String withOptions(String raw, Map<String, String?> set) {
    final out = <String>[];
    final done = <String>{};
    for (final (k, v) in _options(raw)) {
      if (set.containsKey(k) && k.isNotEmpty) {
        done.add(k);
        final value = set[k];
        if (value != null) out.add('$k=$value');
        continue;
      }
      out.add(k.isEmpty ? v : '$k=$v');
    }
    for (final MapEntry(key: k, value: v) in set.entries) {
      if (!done.contains(k) && v != null) out.add('$k=$v');
    }
    return out.join(',');
  }

  /// The volume an option names (`local-lvm:vm-100-disk-1,size=8G`).
  static String? volumeOf(String raw) {
    final first = _options(raw).first;
    return first.$1.isEmpty ? first.$2 : null;
  }

  /// PVE sizes, for [VirtHwGrowDisk]: whole GiB where it is, KiB otherwise.
  static String sizeArg(int bytes) => bytes % (1 << 30) == 0
      ? '${bytes >> 30}G'
      : '${(bytes + 1023) >> 10}K';

  /// `a,b=c,d=e` → `[('', a), (b, c), (d, e)]`.
  static List<(String, String)> _options(String value) {
    final out = <(String, String)>[];
    for (final part in value.split(',')) {
      final at = part.indexOf('=');
      if (at < 0) {
        out.add(('', part));
      } else {
        out.add((part.substring(0, at), part.substring(at + 1)));
      }
    }
    return out.isEmpty ? [('', '')] : out;
  }

  /// PVE sizes: `32G`, `512M`, `1T`, `4096` (bytes).
  static int? _size(String? s) {
    if (s == null || s.isEmpty) return null;
    const units = {'K': 1 << 10, 'M': 1 << 20, 'G': 1 << 30, 'T': 1 << 40};
    final unit = units[s[s.length - 1].toUpperCase()];
    final number = double.tryParse(
      unit == null ? s : s.substring(0, s.length - 1),
    );
    if (number == null) return null;
    return (number * (unit ?? 1)).round();
  }

  /// `scsi2` before `scsi10`.
  static int _naturalCompare(String a, String b) {
    final ma = RegExp(r'^(\D*)(\d*)$').firstMatch(a);
    final mb = RegExp(r'^(\D*)(\d*)$').firstMatch(b);
    if (ma == null || mb == null) return a.compareTo(b);
    final p = ma.group(1)!.compareTo(mb.group(1)!);
    if (p != 0) return p;
    return (int.tryParse(ma.group(2)!) ?? -1).compareTo(
      int.tryParse(mb.group(2)!) ?? -1,
    );
  }

  static List<String> _tags(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    return raw
        .split(RegExp('[;, ]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

  static int? _int(Object? v) => switch (v) {
    final int i => i,
    final num n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };

  static double? _double(Object? v) => switch (v) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };

  static int? _positive(int? v) => v == null || v <= 0 ? null : v;

  static Duration? _duration(Object? v) {
    final s = _int(v);
    return s == null || s <= 0 ? null : Duration(seconds: s);
  }
}
