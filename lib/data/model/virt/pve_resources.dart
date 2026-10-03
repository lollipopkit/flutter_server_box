import 'dart:convert';

import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_backup.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/model/virt/virt_rust.dart';
import 'package:server_box/src/rust/api/pve.dart' show pveGuestDetail;

/// Reading PVE API answers into the Virtualization models. Pure functions,
/// tested against captured payloads.
///
/// Lenient where the parser it replaced (the PVE page's `PveRes`) was strict:
/// a field missing from one entry (a guest being created has no name yet, an offline node no
/// figures) costs that field, not the whole listing.
abstract final class PveResources {
  static final _qemuDisk = RegExp(
    r'^(ide|sata|scsi|virtio|efidisk|tpmstate|unused)(\d+)$',
  );
  static final _lxcDisk = RegExp(r'^(rootfs|mp\d+|unused\d+)$');
  static final _net = RegExp(r'^net(\d+)$');

  /// `/nodes/{node}/{type}/{vmid}/config`: `sbm_virt::pve::resources`'s
  /// reading of it.
  static VirtGuestDetail parseConfig(
    Map<String, Object?> config,
    VirtGuestKind kind,
  ) => VirtRust.detail(
    jsonDecode(
      pveGuestDetail(
        configJson: jsonEncode(config),
        lxc: kind == VirtGuestKind.lxc,
      ),
    ),
  );

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
  // TODO(migration): `sbm_virt::pve::resources::parse_storages`; here for the
  // backup storages only, until backups move (#1623 item 5.7).
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

  /// `GET /cluster/backup`: the vzdump jobs. With [vmid], only those that
  /// take it — every guest of the node (`all`, less `exclude`), it in
  /// `vmid`, or every guest of its pool (whose members are not in this
  /// answer, so one that takes the guest by pool is left out of a guest's
  /// own Plan group); with [node], the guest's, not those restricted to
  /// another node ([VirtBackupJob.takes]).
  static List<VirtBackupJob> parseBackupJobs(
    List<Object?> raw, {
    int? vmid,
    String? node,
  }) {
    final out = <VirtBackupJob>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final e = item.cast<String, Object?>();
      final id = _str(e['id']);
      if (id == null || (_str(e['type']) ?? 'vzdump') != 'vzdump') continue;
      final prune = e['prune-backups'];
      final job = VirtBackupJob(
        id: id,
        schedule: _str(e['schedule']) ?? _str(e['starttime']),
        storage: _str(e['storage']),
        mode: _str(e['mode']),
        compress: _str(e['compress']),
        keep: pruneString(prune),
        enabled: _int(e['enabled']) != 0,
        all: _int(e['all']) == 1,
        vmids: _intList(e['vmid']),
        exclude: _intList(e['exclude']),
        pool: _str(e['pool']),
        node: _str(e['node']),
        comment: _str(e['comment']),
        notesTemplate: _str(e['notes-template']),
        mailNotification: _str(e['mailnotification']),
        prune: pruneString(prune),
      );
      if (vmid != null && !job.takes(vmid, node: node)) continue;
      out.add(job);
    }
    return out;
  }

  /// PVE's `prune-backups` as one property string: an object
  /// (`{keep-last: "7"}`) or the string it is stored as.
  static String? pruneString(Object? raw) => switch (raw) {
    final Map m when m.isNotEmpty => [
      for (final MapEntry(:key, :value) in m.entries) '$key=$value',
    ].join(','),
    final String p when p.isNotEmpty => p,
    _ => null,
  };

  /// The `vzdump` request a job's "Run now" sends, from the job as
  /// `GET /cluster/backup/{id}` has it: what PVE's own web UI sends
  /// (`run_backup_now`, pve-manager 9.2) — every field but the ones that
  /// describe the schedule, `all` as `1`/`0`, and the fields PVE answers as
  /// objects (`performance`, `prune-backups`, `fleecing`) as the property
  /// strings `vzdump` takes.
  static Map<String, Object?> vzdumpOfJob(Map<String, Object?> job) => {
    for (final MapEntry(:key, :value) in job.entries)
      if (!_jobScheduleKeys.contains(key) && value != null)
        key: switch (value) {
          _ when key == 'all' => value == true || value == 1 || value == '1' ? 1 : 0,
          final Map m => [
            for (final MapEntry(:key, :value) in m.entries) '$key=$value',
          ].join(','),
          _ => value,
        },
  };

  static const _jobScheduleKeys = {
    'enabled',
    'starttime',
    'dow',
    'id',
    'schedule',
    'type',
    'node',
    'comment',
    'next-run',
    'repeat-missed',
  };

  /// A comma-separated list of VMIDs, as PVE stores `vmid` and `exclude`.
  /// Null and an empty string are both "none", `all` names no single guest,
  /// and anything that is not a number is skipped rather than costing the
  /// listing.
  static List<int> _intList(Object? raw) {
    if (raw is List) return [for (final v in raw) ?_int(v)];
    final text = _str(raw);
    if (text == null || text.isEmpty || text == 'all') return const [];
    return [
      for (final part in text.split(',')) ?int.tryParse(part.trim()),
    ];
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
    // The disks and NICs as `sbm_virt` reads them; what only the Hardware
    // view needs is read here beside them.
    final base = parseConfig(config, kind);
    final disksByKey = {for (final d in base.disks) d.target: d};
    final nicsByKey = {for (final n in base.nics) n.kind: n};
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
        final d = disksByKey[key] ?? VirtDisk(target: key);
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
        final n = nicsByKey[key] ?? VirtNic(kind: key);
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

  /// The volume an option names: first and without a key
  /// (`local-lvm:vm-100-disk-1,size=8G`), or as `file=`, which PVE takes
  /// too (`file=local-lvm:vm-100-disk-1,size=8G`).
  static String? volumeOf(String raw) {
    final opts = _options(raw);
    if (opts.first.$1.isEmpty) return opts.first.$2;
    for (final (k, v) in opts) {
      if (k == 'file') return v;
    }
    return null;
  }

  /// The disk options only some buses take (qemu-server's `Drive.pm`), and
  /// which: moving a disk to a bus that lacks one is refused, so it is
  /// dropped on the way ([onBus]).
  static const _busOptions = <String, Set<String>>{
    'iothread': {'scsi', 'virtio'},
    'ro': {'scsi', 'virtio'},
    'ssd': {'ide', 'sata', 'scsi'},
    'wwn': {'ide', 'sata', 'scsi'},
    'queues': {'scsi'},
    'product': {'scsi'},
    'vendor': {'scsi'},
    'scsiblock': {'scsi'},
    'model': {'ide'},
  };

  /// Disk option [raw] as [bus] takes it: less the options that bus has not
  /// ([_busOptions]). The rest stays as it was, in its place.
  static String onBus(String raw, String bus) => withOptions(raw, {
    for (final MapEntry(key: k, value: buses) in _busOptions.entries)
      if (!buses.contains(bus)) k: null,
  });

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
      // PVE keeps one property string; several domains are a
      // space-separated list.
      searchDomains: [
        for (final w in (_str(config['searchdomain']) ?? '').split(RegExp(r'[\s,]+')))
          if (w.isNotEmpty) w,
      ],
      nics: [
        for (var i = 0; i < _maxNics; i++)
          if (config['net$i'] is String) i,
      ].length,
      passwordSet: _str(config['cipassword'])?.isNotEmpty ?? false,
      // PVE writes `chpasswd: expire: false` for every VM and has no option
      // for it: a password never expires there.
      passwordExpires: false,
      network: config['net0'] is String,
      revision: _str(config['digest']) ?? '',
    );
  }

  /// How many `net` keys are looked at when counting a VM's NICs.
  static const _maxNics = 32;

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

  static String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

  static int? _int(Object? v) => switch (v) {
    final int i => i,
    final num n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };

  static int? _positive(int? v) => v == null || v <= 0 ? null : v;

}
