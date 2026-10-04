import 'dart:convert';

import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_manage.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/src/rust/api/pve.dart';

/// `sbm_virt::model::HostView` JSON (snake_case, the agent's wire format) read
/// into this app's models. What a guest offers, its state and its usage are
/// decided in Rust for both backends; this only carries them over.
abstract final class VirtRust {
  static VirtSnapshot snapshot(Object? json, {required String serverId}) {
    if (json is! Map) throw _invalid('host view');
    final host = json['host'];
    final guests = json['guests'];
    final stats = json['stats'];
    final caps = json['capabilities'];
    if (host is! Map || guests is! List || stats is! Map || caps is! Map) {
      throw _invalid('host view');
    }
    return VirtSnapshot(
      host: VirtHost(
        serverId: serverId,
        kind: _hostKind(host['kind']),
        version: host['version'] as String?,
        hypervisor: host['hypervisor'] as String?,
        nodes: [
          for (final n in (host['nodes'] as List? ?? const []).whereType<Map>())
            VirtNode(
              name: n['name'] as String,
              online: n['online'] as bool? ?? true,
              cpu: (n['cpu'] as num?)?.toDouble(),
              maxCpu: n['max_cpu'] as int?,
              memUsed: n['mem_used'] as int?,
              memTotal: n['mem_total'] as int?,
              uptime: _seconds(n['uptime']),
            ),
        ],
      ),
      guests: [for (final g in guests.whereType<Map>()) guest(g)],
      stats: {
        for (final MapEntry(:key, :value) in stats.entries)
          if (key is String && value is Map) key: _stats(value),
      },
      capabilities: capabilities(caps),
    );
  }

  static VirtGuest guest(Map g) => VirtGuest(
    id: g['id'] as String,
    name: g['name'] as String,
    kind: g['kind'] == 'lxc' ? VirtGuestKind.lxc : VirtGuestKind.qemu,
    state: _state(g['state']),
    stateReason: g['state_reason'] as String?,
    vmid: g['vmid'] as int?,
    node: g['node'] as String?,
    vcpu: g['vcpu'] as int?,
    memBytes: g['mem_bytes'] as int?,
    uptime: _seconds(g['uptime']),
    tags: [...(g['tags'] as List? ?? const []).whereType<String>()],
    template: g['template'] as bool? ?? false,
    autostart: g['autostart'] as bool?,
    actions: {
      for (final a in (g['actions'] as List? ?? const []).whereType<String>())
        ?_action(a),
    },
  );

  /// [g] as `sbm_virt::model::Guest`.
  static Map<String, Object?> guestJson(VirtGuest g) => {
    'id': g.id,
    'name': g.name,
    'kind': g.kind.name,
    'state': g.state.name,
    'state_reason': g.stateReason,
    'vmid': g.vmid,
    'node': g.node,
    'vcpu': g.vcpu,
    'mem_bytes': g.memBytes,
    'uptime': g.uptime?.inSeconds,
    'tags': g.tags,
    'template': g.template,
    'autostart': g.autostart,
    'actions': [for (final a in g.actions) actionName(a)],
  };

  /// [n] as `sbm_virt::model::Node`.
  static Map<String, Object?> nodeJson(VirtNode n) => {
    'name': n.name,
    'online': n.online,
    'cpu': n.cpu,
    'max_cpu': n.maxCpu,
    'mem_used': n.memUsed,
    'mem_total': n.memTotal,
    'uptime': n.uptime?.inSeconds,
  };

  /// [spec] as `sbm_virt::create::CreateSpec`: what it names, by id. Its
  /// passwords go in it as typed; it is sent to the host, never logged.
  static Map<String, Object?> specJson(VirtCreateSpec spec) => {
    'kind': spec.kind.name,
    'name': spec.name,
    'node': spec.node,
    'vmid': spec.vmid,
    'cores': spec.cores,
    'memory_mib': spec.memoryMiB,
    'storage': spec.storage.id,
    'disk_gib': spec.diskGiB,
    'media': _volumeRef(spec.media),
    'image': _volumeRef(spec.image),
    'network': spec.network?.id,
    'password': spec.password,
    'ssh_keys': _lines(spec.sshKeys),
    'unprivileged': spec.unprivileged,
    'bus': spec.bus,
    'nic_model': spec.nicModel,
    'uefi': spec.uefi,
    'secure_boot': spec.secureBoot,
    'tpm': spec.tpm,
    'cloud_init': switch (spec.cloudInit) {
      final ci? => cloudInitJson(ci),
      null => null,
    },
    'start': spec.start,
  };

  static Map<String, Object?>? _volumeRef(VirtPoolVolume? v) => switch (v) {
    final v? => {'pool': v.pool.id, 'volume': v.volume.id},
    null => null,
  };

  static List<String> _lines(String? text) => [
    for (final l in (text ?? '').split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];

  /// [ci] as `sbm_virt::create::CloudInit`.
  static Map<String, Object?> cloudInitJson(VirtCloudInit ci) => {
    'user': ci.user,
    'password': ci.password,
    'ssh_keys': ci.keys,
    'hostname': ci.hostname,
    'address': ci.address,
    'gateway': ci.gateway,
    'dns': ci.dns,
    'search_domains': ci.searchDomains,
  };

  /// [r] as `sbm_virt::create::CloneRequest`.
  static Map<String, Object?> cloneRequestJson(VirtCloneRequest r) => {
    'name': r.name,
    'full': r.full,
    'vmid': r.vmid,
    'storage': r.storage,
    'target_node': r.targetNode,
    'target_pool': r.targetPool,
  };

  /// `sbm_virt::create::CreateOptions`.
  static VirtCreateOptions createOptions(Object? json) {
    final o = json is Map ? json : throw _invalid('create options');
    return VirtCreateOptions(
      buses: _strings(o['buses']),
      nicModels: _strings(o['nic_models']),
      uefi: o['uefi'] as bool? ?? false,
      secureBoot: o['secure_boot'] as bool? ?? false,
      tpm: o['tpm'] as bool? ?? false,
      cloudImages: o['cloud_images'] as bool? ?? false,
      cloudInit: o['cloud_init'] as bool? ?? false,
      cloudInitMissing: o['cloud_init_missing'] as String?,
    );
  }

  static Map<String, Object?> createOptionsJson(VirtCreateOptions o) => {
    'buses': o.buses,
    'nic_models': o.nicModels,
    'uefi': o.uefi,
    'secure_boot': o.secureBoot,
    'tpm': o.tpm,
    'cloud_images': o.cloudImages,
    'cloud_init': o.cloudInit,
    'cloud_init_missing': o.cloudInitMissing,
  };

  /// `sbm_virt::create::Created`.
  static VirtCreated created(Object? json) {
    final c = json is Map ? json : throw _invalid('created');
    return VirtCreated(
      id: c['id'] as String,
      startError: c['start_error'] as String?,
      diskKeptBytes: c['disk_kept_bytes'] as int?,
    );
  }

  // --- Hardware (sbm_virt::hardware) ---

  static List<Map> _list(Object? v) => [...(v as List? ?? const []).whereType<Map>()];

  static T? _enumOf<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    final camel = name.replaceAllMapped(RegExp('_([a-z])'), (m) => m[1]!.toUpperCase());
    for (final v in values) {
      if (v.name == camel) return v;
    }
    return null;
  }

  static String _snake(Enum e) =>
      e.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

  /// `sbm_virt::hardware::Hardware`.
  static VirtHardware hardware(Object? json) {
    final h = json is Map ? json : throw _invalid('hardware');
    final cpu = h['cpu'] as Map;
    final mem = h['memory'] as Map;
    final fw = h['firmware'] as Map?;
    final display = h['display'] as Map?;
    final support = h['support'] as Map? ?? const {};
    final limits = h['limits'] as Map? ?? const {};
    return VirtHardware(
      kind: h['kind'] == 'lxc' ? VirtGuestKind.lxc : VirtGuestKind.qemu,
      running: h['running'] as bool? ?? false,
      cpu: VirtHwCpu(
        sockets: cpu['sockets'] as int,
        cores: cpu['cores'] as int,
        threads: cpu['threads'] as int? ?? 1,
        online: cpu['online'] as int?,
        type: cpu['type'] as String?,
      ),
      memory: VirtHwMemory(
        mib: mem['mib'] as int,
        minMib: mem['min_mib'] as int?,
        balloon: mem['balloon'] as bool? ?? false,
        swapMib: mem['swap_mib'] as int?,
      ),
      disks: [for (final d in _list(h['disks'])) hwDisk(d)],
      nics: [
        for (final n in _list(h['nics']))
          VirtHwNic(
            key: n['key'] as String,
            mac: n['mac'] as String?,
            type: n['type'] as String?,
            source: n['source'] as String?,
            model: n['model'] as String?,
            linkUp: n['link_up'] as bool? ?? true,
            firewall: n['firewall'] as bool?,
            name: n['name'] as String?,
          ),
      ],
      boot: switch (h['boot']) {
        final List b => [...b.whereType<String>()],
        _ => null,
      },
      autostart: h['autostart'] as bool? ?? false,
      name: h['name'] as String?,
      description: h['description'] as String?,
      protection: h['protection'] as bool?,
      renameRunning: h['rename_running'] as bool? ?? true,
      pending: [
        for (final p in _list(h['pending']))
          VirtPendingField(
            key: p['key'] as String,
            current: p['current'] as String?,
            pending: p['pending'] as String?,
            delete: p['delete'] as bool? ?? false,
          ),
      ],
      revision: h['revision'] as String?,
      limits: VirtHwLimits(
        hostCpus: limits['host_cpus'] as int?,
        hostMemoryBytes: limits['host_memory_bytes'] as int?,
      ),
      cpuTypes: _strings(h['cpu_types']),
      configText: h['config_text'] as String?,
      firmware: fw == null
          ? null
          : VirtHwFirmware(
              uefi: fw['uefi'] as bool? ?? false,
              secureBoot: fw['secure_boot'] as bool? ?? false,
              varsStorage: fw['vars_storage'] as String?,
            ),
      display: display == null
          ? null
          : VirtHwDisplay(
              protocol: display['protocol'] as String?,
              listen: display['listen'] as String?,
              gpu: display['gpu'] as String?,
              port: display['port'] as int?,
            ),
      devices: [
        for (final d in _list(h['devices']))
          VirtHwDevice(
            key: d['key'] as String,
            kind: _enumOf(VirtHwDeviceKind.values, d['kind']) ?? VirtHwDeviceKind.usb,
            detail: d['detail'] as String?,
            mapping: d['mapping'] as bool? ?? false,
          ),
      ],
      support: VirtHwSupport(
        buses: _strings(support['buses']),
        caches: _strings(support['caches']),
        nicModels: _strings(support['nic_models']),
        mac: support['mac'] as bool? ?? false,
        protocols: _strings(support['protocols']),
        listen: support['listen'] as bool? ?? false,
        gpus: _strings(support['gpus']),
        uefi: support['uefi'] as bool? ?? false,
        secureBoot: support['secure_boot'] as bool? ?? false,
        tpm: support['tpm'] as bool? ?? false,
        usb: support['usb'] as bool? ?? false,
        pci: support['pci'] as bool? ?? false,
      ),
    );
  }

  static VirtHwDisk hwDisk(Map d) => VirtHwDisk(
    key: d['key'] as String,
    kind: _enumOf(VirtHwDiskKind.values, d['kind']) ?? VirtHwDiskKind.disk,
    source: d['source'] as String?,
    size: d['size'] as int?,
    storage: d['storage'] as String?,
    mountPoint: d['mount_point'] as String?,
    bus: d['bus'] as String?,
    format: d['format'] as String?,
    readonly: d['readonly'] as bool? ?? false,
    cache: d['cache'] as String?,
    cloudInit: d['cloud_init'] as bool? ?? false,
    resizable: d['resizable'] as bool? ?? true,
  );

  static Map<String, Object?> hwDiskJson(VirtHwDisk d) => {
    'key': d.key,
    'kind': _snake(d.kind),
    'source': d.source,
    'size': d.size,
    'storage': d.storage,
    'mount_point': d.mountPoint,
    'bus': d.bus,
    'format': d.format,
    'readonly': d.readonly,
    'cache': d.cache,
    'cloud_init': d.cloudInit,
    'resizable': d.resizable,
  };

  /// [hw] as `sbm_virt::hardware::Hardware`, what the rules are given.
  static Map<String, Object?> hardwareJson(VirtHardware hw) => {
    'kind': hw.kind.name,
    'running': hw.running,
    'cpu': {
      'sockets': hw.cpu.sockets,
      'cores': hw.cpu.cores,
      'threads': hw.cpu.threads,
      'online': hw.cpu.online,
      'type': hw.cpu.type,
    },
    'memory': {
      'mib': hw.memory.mib,
      'min_mib': hw.memory.minMib,
      'balloon': hw.memory.balloon,
      'swap_mib': hw.memory.swapMib,
    },
    'disks': [for (final d in hw.disks) hwDiskJson(d)],
    'nics': [
      for (final n in hw.nics)
        {
          'key': n.key,
          'mac': n.mac,
          'type': n.type,
          'source': n.source,
          'model': n.model,
          'link_up': n.linkUp,
          'firewall': n.firewall,
          'name': n.name,
        },
    ],
    'boot': hw.boot,
    'autostart': hw.autostart,
    'name': hw.name,
    'description': hw.description,
    'protection': hw.protection,
    'rename_running': hw.renameRunning,
    'pending': [
      for (final p in hw.pending)
        {'key': p.key, 'current': p.current, 'pending': p.pending, 'delete': p.delete},
    ],
    'revision': hw.revision,
    'limits': {'host_cpus': hw.limits.hostCpus, 'host_memory_bytes': hw.limits.hostMemoryBytes},
    'cpu_types': hw.cpuTypes,
    'firmware': switch (hw.firmware) {
      final f? => {'uefi': f.uefi, 'secure_boot': f.secureBoot, 'vars_storage': f.varsStorage},
      null => null,
    },
    'display': switch (hw.display) {
      final d? => {'protocol': d.protocol, 'listen': d.listen, 'gpu': d.gpu, 'port': d.port},
      null => null,
    },
    'devices': [
      for (final d in hw.devices)
        {'key': d.key, 'kind': d.kind.name, 'detail': d.detail, 'mapping': d.mapping},
    ],
    'support': {
      'buses': hw.support.buses,
      'caches': hw.support.caches,
      'nic_models': hw.support.nicModels,
      'mac': hw.support.mac,
      'protocols': hw.support.protocols,
      'listen': hw.support.listen,
      'gpus': hw.support.gpus,
      'uefi': hw.support.uefi,
      'secure_boot': hw.support.secureBoot,
      'tpm': hw.support.tpm,
      'usb': hw.support.usb,
      'pci': hw.support.pci,
    },
  };

  static VirtHostDevice hostDevice(Map d) => VirtHostDevice(
    id: d['id'] as String,
    label: d['label'] as String? ?? '',
    detail: d['detail'] as String?,
    mapping: d['mapping'] as bool? ?? false,
    usbBus: d['usb_bus'] as int?,
    usbPort: d['usb_port'] as String?,
    usbDevice: d['usb_device'] as int?,
    iommuGroup: d['iommu_group'] as int?,
    groupSize: d['group_size'] as int? ?? 0,
  );

  static Map<String, Object?> hostDeviceJson(VirtHostDevice d) => {
    'id': d.id,
    'label': d.label,
    'detail': d.detail,
    'mapping': d.mapping,
    'usb_bus': d.usbBus,
    'usb_port': d.usbPort,
    'usb_device': d.usbDevice,
    'iommu_group': d.iommuGroup,
    'group_size': d.groupSize,
  };

  /// `sbm_virt::hardware::HostDevices`.
  static VirtHostDevices hostDevices(Object? json) {
    final d = json is Map ? json : throw _invalid('host devices');
    return VirtHostDevices(
      usb: [for (final u in _list(d['usb'])) hostDevice(u)],
      pci: [for (final p in _list(d['pci'])) hostDevice(p)],
      iommu: d['iommu'] as bool? ?? true,
      mappingsOnly: d['mappings_only'] as bool? ?? false,
    );
  }

  static Map<String, Object?>? _poolVolume(VirtPoolVolume? v) => switch (v) {
    final v? => {'pool': v.pool.id, 'volume': v.volume.id},
    null => null,
  };

  /// [change] as `sbm_virt::hardware::Change`: what it names, by id.
  static Map<String, Object?> hwChangeJson(VirtHwChange change) => switch (change) {
    VirtHwSetCpu(:final sockets, :final cores, :final online, :final type) => {
      'op': 'set_cpu',
      'sockets': sockets,
      'cores': cores,
      'online': online,
      'type': type,
    },
    VirtHwSetMemory(:final mib, :final minMib, :final swapMib) => {
      'op': 'set_memory',
      'mib': mib,
      'min_mib': minMib,
      'swap_mib': swapMib,
    },
    VirtHwGrowDisk(:final key, :final bytes) => {'op': 'grow_disk', 'key': key, 'bytes': bytes},
    VirtHwAddDisk(:final storage, :final gib, :final mountPoint) => {
      'op': 'add_disk',
      'pool': storage.id,
      'gib': gib,
      'mount_point': mountPoint,
    },
    VirtHwAttachVolume(:final storage, :final volume, :final mountPoint) => {
      'op': 'attach_volume',
      'volume': {'pool': storage.id, 'volume': volume.id},
      'mount_point': mountPoint,
    },
    VirtHwRemoveDisk(:final key, :final deleteVolume) => {
      'op': 'remove_disk',
      'key': key,
      'delete_volume': deleteVolume,
    },
    VirtHwAddCdrom(:final media) => {'op': 'add_cdrom', 'media': _poolVolume(media)},
    VirtHwSetMedia(:final key, :final media) => {'op': 'set_media', 'key': key, 'media': _poolVolume(media)},
    VirtHwAddNic(:final network, :final model) => {'op': 'add_nic', 'network': network.id, 'model': model},
    VirtHwRemoveNic(:final key) => {'op': 'remove_nic', 'key': key},
    VirtHwUpdateNic(:final key, :final network, :final linkUp, :final firewall) => {
      'op': 'update_nic',
      'key': key,
      'network': network?.id,
      'link_up': linkUp,
      'firewall': firewall,
    },
    VirtHwSetBoot(:final order) => {'op': 'set_boot', 'order': order},
    VirtHwSetAutostart(:final on) => {'op': 'set_autostart', 'on': on},
    VirtHwSetName(:final name) => {'op': 'set_name', 'name': name},
    VirtHwSetDescription(:final text) => {'op': 'set_description', 'text': text},
    VirtHwSetProtection(:final on) => {'op': 'set_protection', 'on': on},
    VirtHwUpdateDisk(:final key, :final bus, :final cache) => {
      'op': 'update_disk',
      'key': key,
      'bus': bus,
      'cache': cache,
    },
    VirtHwSetNicHardware(:final key, :final model, :final mac) => {
      'op': 'set_nic_hardware',
      'key': key,
      'model': model,
      'mac': mac,
    },
    VirtHwSetFirmware(:final uefi, :final secureBoot, :final storage) => {
      'op': 'set_firmware',
      'uefi': uefi,
      'secure_boot': secureBoot,
      'storage': storage?.id,
    },
    VirtHwSetDisplay(:final protocol, :final listen, :final gpu) => {
      'op': 'set_display',
      'protocol': protocol,
      'listen': listen,
      'gpu': gpu,
    },
    VirtHwAddDevice(:final kind, :final host, :final storage, :final usbNaming) => {
      'op': 'add_device',
      'kind': kind.name,
      'host': switch (host) {
        final h? => hostDeviceJson(h),
        null => null,
      },
      'storage': storage?.id,
      'usb_naming': _snake(usbNaming),
    },
    VirtHwRemoveDevice(:final key) => {'op': 'remove_device', 'key': key},
    VirtHwRevert(:final keys) => {'op': 'revert', 'keys': keys},
    // Its own call (`VirtBackend.revertPending`), never a change.
    VirtHwRevertPending() => {'op': 'revert', 'keys': const <String>[]},
  };

  /// What [change] names, as it carries them: the pools, networks and
  /// volumes a check of it is made against.
  static (List<VirtStoragePool>, List<VirtNetwork>, List<VirtVolume>) hwListing(VirtHwChange change) =>
      switch (change) {
        VirtHwAddDisk(:final storage) => ([storage], const [], const []),
        VirtHwAttachVolume(:final storage, :final volume) => ([storage], const [], [volume]),
        VirtHwAddCdrom(media: final m?) || VirtHwSetMedia(media: final m?) => ([m.pool], const [], [m.volume]),
        VirtHwAddNic(:final network) => (const [], [network], const []),
        VirtHwUpdateNic(network: final n?) => (const [], [n], const []),
        VirtHwSetFirmware(storage: final s?) || VirtHwAddDevice(storage: final s?) => ([s], const [], const []),
        _ => (const [], const [], const []),
      };

  /// `sbm_virt::hardware::Outcome`.
  static VirtHwOutcome hwOutcome(Object? json) {
    final o = json is Map ? json : const {};
    return VirtHwOutcome(
      liveError: o['live_error'] as String?,
      volumeKept: o['volume_kept'] as bool? ?? false,
    );
  }

  /// `sbm_virt::hardware::CloudInitState`.
  static VirtCloudInitState cloudInitState(Object? json) {
    final c = json is Map ? json : throw _invalid('cloud-init');
    return VirtCloudInitState(
      user: c['user'] as String? ?? '',
      sshKeys: _strings(c['ssh_keys']),
      hostname: c['hostname'] as String?,
      address: c['address'] as String?,
      gateway: c['gateway'] as String?,
      dns: _strings(c['dns']),
      searchDomains: _strings(c['search_domains']),
      nics: c['nics'] as int? ?? 0,
      passwordSet: c['password_set'] as bool? ?? false,
      passwordExpires: c['password_expires'] as bool? ?? false,
      network: c['network'] as bool? ?? false,
      foreign: c['foreign'] as bool? ?? false,
      revision: c['revision'] as String? ?? '',
    );
  }

  /// [edit] made from [base] as `sbm_virt::hardware::CloudInitEdit`.
  static Map<String, Object?> cloudInitEditJson(VirtCloudInitState base, VirtCloudInitEdit edit) => {
    'values': cloudInitJson(edit.values),
    'remove_password': edit.removePassword,
    'password_expires': edit.passwordExpires,
    'revision': base.revision,
  };

  /// `sbm_virt::model::GuestDetail`.
  static VirtGuestDetail detail(Object? json) {
    if (json is! Map) throw _invalid('guest detail');
    List<Map<String, dynamic>> maps(Object? v) => [
      for (final e in (v as List? ?? const []).whereType<Map>())
        Map<String, dynamic>.from(e),
    ];
    final display = json['display'];
    return VirtGuestDetail(
      disks: [for (final d in maps(json['disks'])) VirtDisk.fromJson(d)],
      nics: [for (final n in maps(json['nics'])) VirtNic.fromJson(n)],
      graphics: [for (final g in maps(json['graphics'])) VirtGraphics.fromJson(g)],
      display: display is Map
          ? VirtDisplay.fromJson(Map<String, dynamic>.from(display))
          : null,
      consoles: {
        for (final c in (json['consoles'] as List? ?? const []))
          if (c == 'text') VirtConsoleKind.text else if (c == 'vnc') VirtConsoleKind.vnc,
      },
      description: json['description'] as String?,
      arch: json['arch'] as String?,
      machine: json['machine'] as String?,
    );
  }

  /// A list of `sbm_virt::snapshot::Snapshot`.
  static List<VirtGuestSnapshot> snapshots(Object? json) {
    if (json is! List) throw _invalid('snapshots');
    return [
      for (final s in json.whereType<Map>())
        VirtGuestSnapshot(
          name: s['name'] as String,
          parent: s['parent'] as String?,
          description: s['description'] as String?,
          createdAt: switch (s['created_at']) {
            final int t => DateTime.fromMillisecondsSinceEpoch(t * 1000),
            _ => null,
          },
          current: s['current'] as bool? ?? false,
          withMemory: s['with_memory'] as bool? ?? false,
          external: s['external'] as bool? ?? false,
          layers: [
            for (final l in (s['layers'] as List? ?? const []).whereType<Map>())
              VirtSnapshotLayer(
                target: l['target'] as String,
                file: l['file'] as String?,
                external: l['external'] as bool? ?? false,
              ),
          ],
        ),
    ];
  }

  /// A list of `sbm_virt::snapshot::Diff`.
  static List<VirtSnapDiff> diff(Object? json) {
    if (json is! List) throw _invalid('snapshot diff');
    return [
      for (final d in json.whereType<Map>())
        VirtSnapDiff(
          group: VirtSnapDiffGroup.values.firstWhere(
            (g) => g.name == d['group'],
            orElse: () => VirtSnapDiffGroup.other,
          ),
          key: d['key'] as String,
          before: d['before'] as String?,
          after: d['after'] as String?,
        ),
    ];
  }

  /// `sbm_virt::snapshot::Chain`.
  static VirtSnapChain chain(Object? json) {
    if (json is! Map) throw _invalid('snapshot chain');
    return VirtSnapChain(
      pools: [...(json['pools'] as List? ?? const []).whereType<String>()],
      refusal: json['refusal'] as String?,
      externalRefusal: json['external_refusal'] as String?,
      disks: [
        for (final d in (json['disks'] as List? ?? const []).whereType<Map>())
          VirtSnapChainDisk(
            target: d['target'] as String,
            pool: d['pool'] as String?,
            error: d['error'] as String?,
            files: [
              for (final f in (d['files'] as List? ?? const []).whereType<Map>())
                VirtSnapChainFile(
                  path: f['path'] as String,
                  format: f['format'] as String?,
                  allocation: f['allocation'] as int?,
                  backing: f['backing'] as String?,
                  snap: f['snap'] as String?,
                  active: f['active'] as bool? ?? false,
                ),
            ],
          ),
      ],
    );
  }

  /// A list of `sbm_virt::model::Stats`.
  static List<VirtStats> history(Object? json) {
    if (json is! List) throw _invalid('history');
    return [for (final s in json.whereType<Map>()) _stats(s)];
  }

  static VirtStats _stats(Map s) => VirtStats(
    at: DateTime.fromMillisecondsSinceEpoch(s['at'] as int),
    cpu: (s['cpu'] as num?)?.toDouble(),
    memUsed: s['mem_used'] as int?,
    memTotal: s['mem_total'] as int?,
    diskUsed: s['disk_used'] as int?,
    diskTotal: s['disk_total'] as int?,
    diskRead: (s['disk_read'] as num?)?.toDouble(),
    diskWrite: (s['disk_write'] as num?)?.toDouble(),
    netIn: (s['net_in'] as num?)?.toDouble(),
    netOut: (s['net_out'] as num?)?.toDouble(),
  );

  static VirtCapabilities capabilities(Map c) {
    bool b(String key) => c[key] == true;
    List<String> l(String key) => [...(c[key] as List? ?? const []).whereType<String>()];
    return VirtCapabilities(
      lxc: b('lxc'),
      pause: b('pause'),
      snapshots: b('snapshots'),
      snapshotMemoryRequired: b('snapshot_memory_required'),
      snapshotExternal: b('snapshot_external'),
      snapshotSupported: b('snapshot_supported'),
      storage: b('storage'),
      network: b('network'),
      backup: b('backup'),
      clone: b('clone'),
      linkedClone: b('linked_clone'),
      template: b('template'),
      cloneTarget: b('clone_target'),
      backupJobs: b('backup_jobs'),
      cluster: b('cluster'),
      serialConsole: b('serial_console'),
      vncConsole: b('vnc_console'),
      termConsole: b('term_console'),
      storedHistory: b('stored_history'),
      create: b('create'),
      deleteKeepsDisks: b('delete_keeps_disks'),
      hardware: b('hardware'),
      hardwareRevert: b('hardware_revert'),
      hardwareRevertPending: b('hardware_revert_pending'),
      storageEdit: b('storage_edit'),
      poolTypes: l('pool_types'),
      poolAutostart: b('pool_autostart'),
      poolDeleteStorage: b('pool_delete_storage'),
      volumeResize: b('volume_resize'),
      volumeClone: b('volume_clone'),
      upload: b('upload'),
      networkEdit: b('network_edit'),
      networkModes: l('network_modes'),
      networkStart: b('network_start'),
      networkApply: b('network_apply'),
      networkEditExisting: b('network_edit_existing'),
      networkRestart: b('network_restart'),
    );
  }

  // -------------------------------------------------------------------------
  // Storage and networks (`sbm_virt::resource`)
  // -------------------------------------------------------------------------

  static List<Map> _maps(Object? json, String what) {
    if (json is! List) throw _invalid(what);
    return [...json.whereType<Map>()];
  }

  static List<String> _strings(Object? v) => [
    ...(v as List? ?? const []).whereType<String>(),
  ];

  static VirtGuestRef guestRef(Map r) => VirtGuestRef(
    guestId: r['guest_id'] as String?,
    vmid: r['vmid'] as int?,
    device: r['device'] as String?,
    mac: r['mac'] as String?,
    ip: r['ip'] as String?,
  );

  static Map<String, Object?> guestRefJson(VirtGuestRef r) => {
    'guest_id': r.guestId,
    'vmid': r.vmid,
    'device': r.device,
    'mac': r.mac,
    'ip': r.ip,
  };

  static List<VirtGuestRef> _refs(Object? v) => [
    for (final r in (v as List? ?? const []).whereType<Map>()) guestRef(r),
  ];

  /// A list of `sbm_virt::resource::Pool`.
  static List<VirtStoragePool> pools(Object? json) => [
    for (final p in _maps(json, 'storage'))
      VirtStoragePool(
        id: p['id'] as String,
        name: p['name'] as String,
        node: p['node'] as String?,
        type: p['type'] as String? ?? '',
        path: p['path'] as String?,
        source: p['source'] as String?,
        capacity: p['capacity'] as int?,
        used: p['used'] as int?,
        available: p['available'] as int?,
        active: p['active'] as bool? ?? true,
        autostart: p['autostart'] as bool?,
        enabled: p['enabled'] as bool?,
        shared: p['shared'] as bool?,
        content: _strings(p['content']),
        volumeCount: p['volume_count'] as int?,
      ),
  ];

  static Map<String, Object?> poolJson(VirtStoragePool p) => {
    'id': p.id,
    'name': p.name,
    'node': p.node,
    'type': p.type,
    'path': p.path,
    'source': p.source,
    'capacity': p.capacity,
    'used': p.used,
    'available': p.available,
    'active': p.active,
    'autostart': p.autostart,
    'enabled': p.enabled,
    'shared': p.shared,
    'content': p.content,
    'volume_count': p.volumeCount,
  };

  /// A list of `sbm_virt::resource::Volume`.
  static List<VirtVolume> volumes(Object? json) => [
    for (final v in _maps(json, 'volumes'))
      VirtVolume(
        id: v['id'] as String,
        name: v['name'] as String,
        path: v['path'] as String?,
        format: v['format'] as String?,
        content: v['content'] as String?,
        capacity: v['capacity'] as int?,
        allocation: v['allocation'] as int?,
        backing: v['backing'] as String?,
        createdAt: switch (v['created_at']) {
          final int t => DateTime.fromMillisecondsSinceEpoch(t * 1000),
          _ => null,
        },
        users: _refs(v['users']),
        backs: _strings(v['backs']),
      ),
  ];

  static Map<String, Object?> volumeJson(VirtVolume v) => {
    'id': v.id,
    'name': v.name,
    'path': v.path,
    'format': v.format,
    'content': v.content,
    'capacity': v.capacity,
    'allocation': v.allocation,
    'backing': v.backing,
    'created_at': switch (v.createdAt) {
      final t? => t.millisecondsSinceEpoch ~/ 1000,
      null => null,
    },
    'users': [for (final r in v.users) guestRefJson(r)],
    'backs': v.backs,
  };

  /// A list of `sbm_virt::resource::Network`.
  static List<VirtNetwork> networks(Object? json) => [
    for (final n in _maps(json, 'networks'))
      VirtNetwork(
        id: n['id'] as String,
        name: n['name'] as String,
        node: n['node'] as String?,
        mode: n['mode'] as String? ?? '',
        bridge: n['bridge'] as String?,
        cidrs: _strings(n['cidrs']),
        gateway: n['gateway'] as String?,
        dhcpRanges: _strings(n['dhcp_ranges']),
        ports: _strings(n['ports']),
        vlanAware: n['vlan_aware'] as bool?,
        vlanId: n['vlan_id'] as int?,
        vlanDevice: n['vlan_device'] as String?,
        bondMode: n['bond_mode'] as String?,
        active: n['active'] as bool? ?? true,
        autostart: n['autostart'] as bool?,
        comment: n['comment'] as String?,
        hosts: [
          for (final h in (n['hosts'] as List? ?? const []).whereType<Map>())
            VirtNetHost(
              mac: h['mac'] as String,
              ip: h['ip'] as String,
              name: h['name'] as String?,
            ),
        ],
        xml: n['xml'] as String? ?? '',
        pendingRestart: n['pending_restart'] as bool? ?? false,
        managementEditable: n['management_editable'] as bool? ?? true,
        users: _refs(n['users']),
      ),
  ];

  static Map<String, Object?> networkJson(VirtNetwork n) => {
    'id': n.id,
    'name': n.name,
    'node': n.node,
    'mode': n.mode,
    'bridge': n.bridge,
    'cidrs': n.cidrs,
    'gateway': n.gateway,
    'dhcp_ranges': n.dhcpRanges,
    'ports': n.ports,
    'vlan_aware': n.vlanAware,
    'vlan_id': n.vlanId,
    'vlan_device': n.vlanDevice,
    'bond_mode': n.bondMode,
    'active': n.active,
    'autostart': n.autostart,
    'comment': n.comment,
    'hosts': [for (final h in n.hosts) _hostJson(h)],
    'xml': n.xml,
    'pending_restart': n.pendingRestart,
    'management_editable': n.managementEditable,
    'users': [for (final r in n.users) guestRefJson(r)],
  };

  static Map<String, Object?> _hostJson(VirtNetHost h) => {
    'mac': h.mac,
    'ip': h.ip,
    'name': h.name,
  };

  /// A list of `sbm_virt::resource::NetworkChanges`.
  static List<VirtNetworkChanges> networkChanges(Object? json) => [
    for (final c in _maps(json, 'network changes'))
      VirtNetworkChanges(node: c['node'] as String, diff: c['diff'] as String),
  ];

  /// [change] as `sbm_virt::resource::Change`: what it is to named by id,
  /// resolved against what the host lists when it is made.
  static Map<String, Object?> changeJson(VirtResourceChange change) =>
      switch (change) {
        VirtPoolCreate(
          :final name,
          :final type,
          :final source,
          :final target,
          :final node,
          :final content,
          :final autostart,
        ) =>
          {
            'op': 'pool_create',
            'name': name,
            'type': type,
            'source': source,
            'target': target,
            'node': node,
            'content': content,
            'autostart': autostart,
          },
        VirtPoolSetActive(:final pool, :final active) => {
          'op': 'pool_set_active',
          'pool': pool.id,
          'active': active,
        },
        VirtPoolSetAutostart(:final pool, :final on) => {
          'op': 'pool_set_autostart',
          'pool': pool.id,
          'on': on,
        },
        VirtPoolRefresh(:final pool) => {'op': 'pool_refresh', 'pool': pool.id},
        VirtPoolDelete(:final pool, :final deleteStorage) => {
          'op': 'pool_delete',
          'pool': pool.id,
          'delete_storage': deleteStorage,
        },
        VirtVolumeCreate(:final pool, :final name, :final gib, :final format) => {
          'op': 'volume_create',
          'pool': pool.id,
          'name': name,
          'gib': gib,
          'format': format,
        },
        VirtVolumeDelete(:final pool, :final volume) => {
          'op': 'volume_delete',
          'pool': pool.id,
          'volume': volume.id,
        },
        VirtVolumeResize(:final pool, :final volume, :final bytes) => {
          'op': 'volume_resize',
          'pool': pool.id,
          'volume': volume.id,
          'bytes': bytes,
        },
        VirtVolumeClone(:final pool, :final volume, :final name) => {
          'op': 'volume_clone',
          'pool': pool.id,
          'volume': volume.id,
          'name': name,
        },
        VirtNetworkCreate(
          :final name,
          :final mode,
          :final node,
          :final bridge,
          :final cidr,
          :final dhcpStart,
          :final dhcpEnd,
          :final vlanAware,
          :final autostart,
        ) =>
          {
            'op': 'network_create',
            'name': name,
            'mode': mode,
            'node': node,
            'bridge': bridge,
            'cidr': cidr,
            'dhcp_start': dhcpStart,
            'dhcp_end': dhcpEnd,
            'vlan_aware': vlanAware,
            'autostart': autostart,
          },
        VirtNetworkEdit(
          :final network,
          :final mode,
          :final bridge,
          :final address,
          :final prefix,
          :final dhcpStart,
          :final dhcpEnd,
          :final hosts,
          :final restart,
        ) =>
          {
            'op': 'network_edit',
            'network': network.id,
            'mode': mode,
            'bridge': bridge,
            'address': address,
            'prefix': prefix,
            'dhcp_start': dhcpStart,
            'dhcp_end': dhcpEnd,
            'hosts': [for (final h in hosts) _hostJson(h)],
            'restart': restart,
            // The definition the edit was made from: one changed since is
            // refused rather than overwritten.
            'base_xml': network.xml.isEmpty ? null : network.xml,
          },
        VirtNetworkEditBridge(
          :final network,
          :final ports,
          :final cidr,
          :final gateway,
          :final vlanAware,
          :final autostart,
        ) =>
          {
            'op': 'network_edit_bridge',
            'network': network.id,
            'ports': ports,
            'cidr': cidr,
            'gateway': gateway,
            'vlan_aware': vlanAware,
            'autostart': autostart,
          },
        VirtNetworkRestart(:final network) => {
          'op': 'network_restart',
          'network': network.id,
          'base_xml': network.xml.isEmpty ? null : network.xml,
        },
        VirtNetworkSetActive(:final network, :final active) => {
          'op': 'network_set_active',
          'network': network.id,
          'active': active,
        },
        VirtNetworkSetAutostart(:final network, :final on) => {
          'op': 'network_set_autostart',
          'network': network.id,
          'on': on,
        },
        VirtNetworkDelete(:final network) => {
          'op': 'network_delete',
          'network': network.id,
        },
        VirtNetworkApply(:final node) => {'op': 'network_apply', 'node': node},
        VirtNetworkRevert(:final node) => {'op': 'network_revert', 'node': node},
      };

  /// `sbm_virt::error::Error` as this app phrases it. What `sbm_virt` leaves
  /// to the caller (`detail_json`) is said in the user's language; the
  /// host's own words otherwise.
  static VirtErr error(PveError e) {
    final type = switch (e.kind) {
      VirtFailure.unreachable => VirtErrType.unreachable,
      VirtFailure.notConfigured => VirtErrType.notConfigured,
      VirtFailure.authFailed => VirtErrType.authFailed,
      VirtFailure.needTfa => VirtErrType.needTfa,
      VirtFailure.certUnconfirmed => VirtErrType.certUnconfirmed,
      VirtFailure.certChanged => VirtErrType.certChanged,
      VirtFailure.permissionDenied => VirtErrType.permissionDenied,
      VirtFailure.invalidResponse => VirtErrType.invalidResponse,
      VirtFailure.actionFailed => VirtErrType.actionFailed,
      VirtFailure.unsupported => VirtErrType.unsupported,
      VirtFailure.exists => VirtErrType.exists,
      VirtFailure.conflict => VirtErrType.conflict,
      VirtFailure.notInstalled => VirtErrType.notInstalled,
      VirtFailure.sudoPasswordRequired => VirtErrType.sudoPasswordRequired,
      VirtFailure.sudoPasswordRejected => VirtErrType.sudoPasswordRejected,
      VirtFailure.closed || VirtFailure.unknown => VirtErrType.unknown,
    };
    final detail = e.detailJson == null ? null : jsonDecode(e.detailJson!);
    final message = switch (detail) {
      {'code': 'no_user'} => 'No user to log in to PVE as. Use an API token.',
      {'code': 'password_required'} => l10n.pvePasswordRequired,
      {'code': 'token_incomplete'} => 'The PVE API token is incomplete',
      {'code': 'otp_required'} => l10n.pveOtpRequired,
      {'code': 'otp_empty'} => l10n.pveOtpCodeRequired,
      {'code': 'otp_rejected'} => l10n.pveOtpVerificationFailed,
      {'code': 'invalid_body'} => l10n.pveInvalidResponseBody,
      {'code': 'invalid_data'} => l10n.pveInvalidResponseData,
      {'code': 'missing_ticket'} => l10n.pveMissingAuthTicket,
      {
        'code': 'no_privileges',
        'token': final bool token,
        'account': final String account,
        'command': final String command,
      } =>
        token
            ? l10n.pveTokenNoPrivileges(account, command)
            : l10n.pveUserNoPrivileges(account, command),
      {
        'code': 'task_still_running',
        'node': final String node,
        'upid': final String upid,
        'minutes': final int minutes,
      } =>
        'Still running on $node after $minutes min; '
            'its task log on the host says how it ends: $upid',
      {
        'code': 'needs_privilege',
        'account': final String account,
        'privilege': final String privilege,
        'path': final String path,
        'command': final String command,
      } =>
        l10n.pveNeedsPrivilege(account, privilege, path, command),
      {'code': 'refused', 'issue': final String issue} =>
        virtResIssueText(VirtResIssue.ofRust(issue)),
      {'code': 'create_refused', 'issue': final String issue} =>
        virtCreateIssueText(VirtCreateIssue.ofRust(issue)),
      {'code': 'hardware_refused', 'issue': final String issue} =>
        virtHwIssueText(VirtHwIssue.ofRust(issue)),
      {'code': 'apply_touches_management', 'ifaces': final List ifaces} =>
        'The pending configuration changes ${ifaces.join(', ')}, which '
            "carries the host's management traffic: apply it from the "
            "host's console or PVE's own interface",
      {'code': 'apply_unreadable'} =>
        'Which interfaces the pending configuration changes cannot be told '
            "from its diff: apply it from the host's console or PVE's own "
            'interface',
      {'code': 'cert_not_presented'} =>
        'That certificate was not presented by this server',
      {'code': 'not_offered'} => 'Not offered for this guest',
      _ => e.message,
    };
    final cert = e.cert;
    return VirtErr(
      type: type,
      message:
          (type == VirtErrType.certUnconfirmed ||
                  type == VirtErrType.certChanged) &&
              cert != null
          ? cert.prettyFingerprint
          : message,
      cert: cert,
      previousFingerprint: e.previousFingerprint,
      cause: e,
    );
  }

  /// The wire name of [action] (`force_stop`).
  static String actionName(VirtPowerAction action) => switch (action) {
    VirtPowerAction.forceStop => 'force_stop',
    _ => action.name,
  };

  static VirtPowerAction? _action(String name) => switch (name) {
    'start' => VirtPowerAction.start,
    'shutdown' => VirtPowerAction.shutdown,
    'reboot' => VirtPowerAction.reboot,
    'force_stop' => VirtPowerAction.forceStop,
    'suspend' => VirtPowerAction.suspend,
    'resume' => VirtPowerAction.resume,
    _ => null,
  };

  static VirtGuestState _state(Object? name) =>
      VirtGuestState.values.firstWhere(
        (s) => s.name == name,
        orElse: () => VirtGuestState.unknown,
      );

  static VirtHostKind _hostKind(Object? name) =>
      name == 'pve' ? VirtHostKind.pve : VirtHostKind.libvirt;

  static Duration? _seconds(Object? v) =>
      v is int && v > 0 ? Duration(seconds: v) : null;

  static VirtErr _invalid(String what) =>
      VirtErr(type: VirtErrType.invalidResponse, message: 'Unreadable $what');
}
