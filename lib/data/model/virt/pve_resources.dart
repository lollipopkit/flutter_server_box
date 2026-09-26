import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_backup.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
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

  /// `GET /nodes/{node}/storage/{storage}/content?content=backup`: the
  /// backups on [storage], newest first. `verification` is an object where a
  /// verify job has looked at one.
  static List<VirtBackup> parseBackups(
    String node,
    String storage,
    List<Object?> raw,
  ) {
    final out = <VirtBackup>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final e = item.cast<String, Object?>();
      final id = _str(e['volid']);
      if (id == null || (_str(e['content']) ?? 'backup') != 'backup') continue;
      final ctime = _int(e['ctime']);
      final verification = e['verification'];
      out.add(
        VirtBackup(
          id: id,
          storage: storage,
          node: node,
          vmid: _int(e['vmid']),
          createdAt: ctime == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(ctime * 1000),
          size: _positive(_int(e['size'])),
          format: _str(e['format']),
          notes: _str(e['notes']),
          protected: _int(e['protected']) == 1,
          verification: verification is Map
              ? _str(verification['state'])
              : null,
          kind: switch (_str(e['subtype'])) {
            'qemu' => VirtGuestKind.qemu,
            'lxc' => VirtGuestKind.lxc,
            _ => null,
          },
        ),
      );
    }
    out.sort(
      (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    return out;
  }

  /// `GET /cluster/backup`: the vzdump jobs that take [vmid] — every guest
  /// (`all`), or it by name in `vmid`. A job by pool or excluding it is
  /// left out: which guests a pool holds is not in this answer.
  static List<VirtBackupJob> parseBackupJobs(List<Object?> raw, {int? vmid}) {
    final out = <VirtBackupJob>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final e = item.cast<String, Object?>();
      final id = _str(e['id']);
      if (id == null || (_str(e['type']) ?? 'vzdump') != 'vzdump') continue;
      final all = _int(e['all']) == 1;
      final exclude = (_str(e['exclude']) ?? '').split(',');
      final ids = (_str(e['vmid']) ?? '').split(',');
      final takes = vmid == null ||
          (all && !exclude.contains('$vmid')) ||
          ids.contains('$vmid');
      if (!takes) continue;
      final prune = e['prune-backups'];
      out.add(
        VirtBackupJob(
          id: id,
          schedule: _str(e['schedule']) ?? _str(e['starttime']),
          storage: _str(e['storage']),
          mode: _str(e['mode']),
          compress: _str(e['compress']),
          keep: switch (prune) {
            final Map m when m.isNotEmpty => [
              for (final MapEntry(:key, :value) in m.entries) '$key=$value',
            ].join(','),
            final String p => p,
            _ => null,
          },
          enabled: _int(e['enabled']) != 0,
        ),
      );
    }
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
  /// Whether the content listing's `size` of a volume is its file's rather
  /// than its virtual size: an `import` image in a format with a size of
  /// its own inside (qcow2, vmdk). PVE's `GET .../content/{volid}` answers
  /// the virtual size (`qemu-img info`'s), verified on PVE 9.2.2 with only
  /// `Datastore.Audit` on the storage.
  static bool imageSizeUnknown(String? content, String? format) =>
      content == 'import' && (format == 'qcow2' || format == 'vmdk');

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
      final content = _str(e['content']);
      final sizeUnknown = imageSizeUnknown(content, _str(e['format']));
      out.add(
        VirtVolume(
          id: volid,
          name: name.isEmpty ? volid : name,
          format: _str(e['format']),
          content: content,
          // An import image's `size` is its file's (PVE 9.2), which for a
          // qcow2 or vmdk is not what the guest sees: unknown until
          // `GET .../content/{volid}` says ([imageSizeUnknown]).
          capacity: sizeUnknown ? null : _int(e['size']),
          allocation: sizeUnknown ? _int(e['size']) : _int(e['used']),
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
  /// PVE's cloud-init drive, a volume of the VM's own: `<storage>:vm-<vmid>-cloudinit`,
  /// or `<storage>:<vmid>/vm-<vmid>-cloudinit.qcow2` on a storage of files.
  static final _cloudInitVolume = RegExp(
    r'^[^:]+:(\d+/)?vm-\d+-cloudinit(\.(qcow2|raw|vmdk))?$',
  );

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
    final devices = <VirtHwDevice>[];
    final keys = config.keys.toList()..sort(_naturalCompare);
    for (final key in keys) {
      final value = config[key];
      if (value is! String) continue;
      final diskMatch = lxc ? _lxcDisk.firstMatch(key) : _qemuDisk.firstMatch(key);
      if (diskMatch != null) {
        if (key.startsWith('tpmstate')) {
          final named = {for (final (k, v) in _options(value)) k: v};
          devices.add(
            VirtHwDevice(
              key: key,
              kind: VirtHwDeviceKind.tpm,
              detail: 'TPM ${named['version'] ?? 'v1.2'}',
            ),
          );
          continue;
        }
        // Detached volumes and EFI vars are not disks to edit.
        if (key.startsWith('unused') || key.startsWith('efidisk')) {
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
            cache: named['cache'],
            cloudInit: d.device == 'cdrom' &&
                source != null &&
                _cloudInitVolume.hasMatch(source),
          ),
        );
        continue;
      }
      if (!lxc) {
        final device = _device(key, value);
        if (device != null) {
          devices.add(device);
          continue;
        }
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

    final efi = _str(config['efidisk0']);
    final vga = _str(config['vga']);
    return VirtHardware(
      kind: kind,
      running: running,
      cpu: cpu,
      memory: memory,
      disks: disks,
      nics: nics,
      devices: devices,
      firmware: lxc
          ? null
          : VirtHwFirmware(
              uefi: _str(config['bios']) == 'ovmf',
              secureBoot:
                  efi != null &&
                  _options(efi).any((o) => o == ('pre-enrolled-keys', '1')),
              varsStorage: efi == null ? null : volumeOf(efi)?.split(':').first,
            ),
      display: lxc
          ? null
          : VirtHwDisplay(gpu: vga == null ? 'std' : _options(vga).first.$2),
      support: lxc ? pveLxcSupport : pveQemuSupport,
      boot: lxc ? null : _bootOrder(_str(config['boot']), config, disks, nics),
      autostart: _int(config['onboot']) == 1,
      name: _str(config[lxc ? 'hostname' : 'name']),
      description: switch (_str(config['description'])?.trimRight()) {
        final d? when d.isNotEmpty => d,
        _ => null,
      },
      protection: _int(config['protection']) == 1,
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

  /// What a PVE VM's hardware can be changed to. SPICE is not a choice of
  /// its own there: it comes with a `qxl` card.
  static const pveQemuSupport = VirtHwSupport(
    buses: ['scsi', 'virtio', 'sata', 'ide'],
    caches: ['default', 'none', 'writeback', 'writethrough', 'directsync', 'unsafe'],
    nicModels: ['virtio', 'e1000', 'e1000e', 'rtl8139', 'vmxnet3'],
    mac: true,
    gpus: ['std', 'virtio', 'qxl', 'vmware', 'cirrus', 'none'],
    uefi: true,
    secureBoot: true,
    tpm: true,
    usb: true,
    pci: true,
  );

  static const pveLxcSupport = VirtHwSupport(mac: true);

  static final _usbKey = RegExp(r'^usb\d+$');
  static final _pciKey = RegExp(r'^hostpci\d+$');

  /// `usbN` (`host=0bda:b023`, `host=1-4`, `mapping=bt`, `spice`) and
  /// `hostpciN` (`0000:01:00.0,pcie=1`, `01:00`, `mapping=gpu`) as devices.
  static VirtHwDevice? _device(String key, String value) {
    final VirtHwDeviceKind kind;
    if (_usbKey.hasMatch(key)) {
      kind = VirtHwDeviceKind.usb;
    } else if (_pciKey.hasMatch(key)) {
      kind = VirtHwDeviceKind.pci;
    } else {
      return null;
    }
    final opts = _options(value);
    final named = {for (final (k, v) in opts) k: v};
    final mapping = named['mapping'];
    final detail =
        mapping ??
        switch (kind) {
          VirtHwDeviceKind.usb => named['host'] ?? opts.first.$2,
          _ => named['host'] ?? (opts.first.$1.isEmpty ? opts.first.$2 : null),
        };
    return VirtHwDevice(
      key: key,
      kind: kind,
      detail: detail,
      mapping: mapping != null,
    );
  }

  /// A NIC's option with its model and MAC changed: a VM's `model=MAC`
  /// pair, a container's `hwaddr`. The rest stays as written.
  static String withNicHardware(
    String raw, {
    required bool lxc,
    String? model,
    String? mac,
  }) {
    if (lxc) return mac == null ? raw : withOptions(raw, {'hwaddr': mac.toUpperCase()});
    const models = {
      'virtio', 'e1000', 'e1000e', 'rtl8139', 'vmxnet3', //
      'i82551', 'i82557b', 'i82559er', 'ne2k_isa', 'ne2k_pci', 'pcnet',
    };
    final out = <String>[];
    var done = false;
    for (final (k, v) in _options(raw)) {
      if (!done && models.contains(k)) {
        done = true;
        out.add('${model ?? k}=${mac?.toUpperCase() ?? v}');
        continue;
      }
      out.add(k.isEmpty ? v : '$k=$v');
    }
    return out.join(',');
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

  /// The `size=` of a disk option (`local-lvm:vm-100-disk-0,size=3G`), in
  /// bytes; null where it has none.
  static int? optionSize(String raw) {
    for (final (k, v) in _options(raw)) {
      if (k == 'size') return _size(v);
    }
    return null;
  }

  /// A VM's cloud-init options as the Settings view edits them: `ciuser`,
  /// whether `cipassword` is set (PVE answers it masked, never the value or
  /// its hash), `sshkeys` (stored URL-encoded, as PVE's web UI sends them),
  /// `ipconfig0`, `nameserver`, `searchdomain`; the `digest` an edit is
  /// sent back with.
  static VirtCloudInitState parseCloudInit(Map<String, Object?> config) {
    final rawKeys = _str(config['sshkeys']) ?? '';
    String keys;
    try {
      keys = Uri.decodeComponent(rawKeys);
    } on ArgumentError {
      keys = rawKeys;
    }
    final ip = {
      for (final (k, v) in _options(_str(config['ipconfig0']) ?? '')) k: v,
    };
    final address = ip['ip'];
    final static = address != null && address != 'dhcp' && address.contains('/');
    return VirtCloudInitState(
      user: _str(config['ciuser']) ?? '',
      sshKeys: [
        for (final l in keys.split('\n'))
          if (l.trim().isNotEmpty) l.trim(),
      ],
      address: static ? address : null,
      gateway: static ? ip['gw'] : null,
      dns: [
        for (final w in (_str(config['nameserver']) ?? '').split(RegExp(r'[\s,]+')))
          if (w.isNotEmpty) w,
      ],
      searchDomain: switch (_str(config['searchdomain'])?.trim()) {
        final s? when s.isNotEmpty => s,
        _ => null,
      },
      passwordSet: _str(config['cipassword'])?.isNotEmpty ?? false,
      network: config['net0'] is String,
      revision: _str(config['digest']) ?? '',
    );
  }

  /// PVE sizes, for [VirtHwGrowDisk]: whole GiB where it is, KiB otherwise.
  static String sizeArg(int bytes) => bytes % (1 << 30) == 0
      ? '${bytes >> 30}G'
      : '${(bytes + 1023) >> 10}K';

  /// [_options], for the backend.
  static List<(String, String)> optionsOf(String value) => _options(value);

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
