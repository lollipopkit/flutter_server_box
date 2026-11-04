import 'dart:convert';
import 'dart:typed_data';

import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_backup.dart';
import 'package:server_box/data/model/virt/virt_backup_schedule.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_manage.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/src/rust/api/pve.dart';
import 'package:server_box/src/rust/api/virt_model.dart' as vm;
import 'package:server_box/src/rust/api/virt_view.dart' as vv;

/// `sbm_virt`'s models as the FFI mirrors them, mapped to this app's and
/// back. What a guest offers, its state and its usage are decided in Rust
/// for both backends; this only carries them over.
abstract final class VirtRust {
  static VirtSnapshot snapshot(vv.VirtHostReport view, {required String serverId}) => VirtSnapshot(
    host: VirtHost(
      serverId: serverId,
      kind: switch (view.host.kind) {
        vv.HostKind.pve => VirtHostKind.pve,
        vv.HostKind.libvirt => VirtHostKind.libvirt,
      },
      version: view.host.version,
      hypervisor: view.host.hypervisor,
      nodes: [
        for (final n in view.host.nodes)
          VirtNode(
            name: n.name,
            online: n.online,
            cpu: n.cpu,
            maxCpu: n.maxCpu,
            memUsed: n.memUsed?.toInt(),
            memTotal: n.memTotal?.toInt(),
            uptime: _seconds(n.uptime?.toInt()),
          ),
      ],
    ),
    guests: [for (final g in view.guests) guest(g)],
    stats: {for (final (id, s) in view.stats) id: _stats(s)},
    capabilities: capabilities(view.capabilities),
  );

  static VirtGuest guest(vv.VirtGuestReport g) => VirtGuest(
    id: g.id,
    name: g.name,
    kind: switch (g.kind) {
      vv.GuestKind.lxc => VirtGuestKind.lxc,
      vv.GuestKind.qemu => VirtGuestKind.qemu,
    },
    state: VirtGuestState.values.byName(g.state.name),
    stateReason: g.stateReason,
    vmid: g.vmid,
    node: g.node,
    vcpu: g.vcpu,
    memBytes: g.memBytes?.toInt(),
    uptime: _seconds(g.uptime?.toInt()),
    tags: g.tags,
    template: g.template,
    autostart: g.autostart,
    actions: {for (final a in g.actions) VirtPowerAction.values.byName(a.name)},
  );

  /// [g] as `sbm_virt::model::Guest`.
  static vv.VirtGuestReport guestFfi(VirtGuest g) => vv.VirtGuestReport(
    id: g.id,
    name: g.name,
    kind: vv.GuestKind.values.byName(g.kind.name),
    state: vv.GuestState.values.byName(g.state.name),
    stateReason: g.stateReason,
    vmid: g.vmid,
    node: g.node,
    vcpu: g.vcpu,
    memBytes: _big(g.memBytes),
    uptime: _big(g.uptime?.inSeconds),
    tags: g.tags,
    template: g.template,
    autostart: g.autostart,
    actions: [for (final a in g.actions) vv.PowerAction.values.byName(a.name)],
  );

  /// [n] as `sbm_virt::model::Node`.
  static vv.Node nodeFfi(VirtNode n) => vv.Node(
    name: n.name,
    online: n.online,
    cpu: n.cpu,
    maxCpu: n.maxCpu,
    memUsed: _big(n.memUsed),
    memTotal: _big(n.memTotal),
    uptime: _big(n.uptime?.inSeconds),
  );

  /// [spec] as `sbm_virt::create::CreateSpec`: what it names, by id. Its
  /// passwords go in it as typed; it is sent to the host, never logged.
  static vm.CreateSpec specFfi(VirtCreateSpec spec) => vm.CreateSpec(
    kind: vv.GuestKind.values.byName(spec.kind.name),
    name: spec.name,
    node: spec.node,
    vmid: spec.vmid,
    cores: spec.cores,
    memoryMib: BigInt.from(spec.memoryMiB),
    storage: spec.storage.id,
    diskGib: BigInt.from(spec.diskGiB),
    media: _volumeRef(spec.media),
    image: _volumeRef(spec.image),
    network: spec.network?.id,
    password: spec.password,
    sshKeys: _lines(spec.sshKeys),
    unprivileged: spec.unprivileged,
    bus: spec.bus,
    nicModel: spec.nicModel,
    uefi: spec.uefi,
    secureBoot: spec.secureBoot,
    tpm: spec.tpm,
    cloudInit: switch (spec.cloudInit) {
      final ci? => cloudInitFfi(ci),
      null => null,
    },
    start: spec.start,
  );

  static vm.VolumeRef? _volumeRef(VirtPoolVolume? v) => switch (v) {
    final v? => vm.VolumeRef(pool: v.pool.id, volume: v.volume.id),
    null => null,
  };

  static List<String> _lines(String? text) => [
    for (final l in (text ?? '').split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];

  /// [ci] as `sbm_virt::create::CloudInit`.
  static vm.CloudInit cloudInitFfi(VirtCloudInit ci) => vm.CloudInit(
    user: ci.user,
    password: ci.password,
    sshKeys: ci.keys,
    hostname: ci.hostname,
    address: ci.address,
    gateway: ci.gateway,
    dns: ci.dns,
    searchDomains: ci.searchDomains,
  );

  /// [r] as `sbm_virt::create::CloneRequest`.
  static vm.CloneRequest cloneRequestFfi(VirtCloneRequest r) => vm.CloneRequest(
    name: r.name,
    full: r.full,
    vmid: r.vmid,
    storage: r.storage,
    targetNode: r.targetNode,
    targetPool: r.targetPool,
  );

  /// `sbm_virt::create::CreateOptions`.
  static VirtCreateOptions createOptions(vm.CreateOptions o) => VirtCreateOptions(
    buses: o.buses,
    nicModels: o.nicModels,
    uefi: o.uefi,
    secureBoot: o.secureBoot,
    tpm: o.tpm,
    cloudImages: o.cloudImages,
    cloudInit: o.cloudInit,
    cloudInitMissing: o.cloudInitMissing,
  );

  static vm.CreateOptions createOptionsFfi(VirtCreateOptions o) => vm.CreateOptions(
    buses: o.buses,
    nicModels: o.nicModels,
    uefi: o.uefi,
    secureBoot: o.secureBoot,
    tpm: o.tpm,
    cloudImages: o.cloudImages,
    cloudInit: o.cloudInit,
    cloudInitMissing: o.cloudInitMissing,
  );

  /// `sbm_virt::create::Created`.
  static VirtCreated created(vm.Created c) =>
      VirtCreated(id: c.id, startError: c.startError, diskKeptBytes: c.diskKeptBytes?.toInt());

  // --- Backups (sbm_virt::backup) ---

  static DateTime? _unix(int? t) => t == null ? null : DateTime.fromMillisecondsSinceEpoch(t * 1000);

  static VirtGuestKind? _guestKind(vv.GuestKind? k) => switch (k) {
    vv.GuestKind.qemu => VirtGuestKind.qemu,
    vv.GuestKind.lxc => VirtGuestKind.lxc,
    null => null,
  };

  static List<VirtBackup> backups(List<vm.Backup> list) => [
    for (final b in list)
      VirtBackup(
        id: b.id,
        storage: b.storage,
        node: b.node,
        vmid: b.vmid,
        createdAt: _unix(b.createdAt),
        size: b.size?.toInt(),
        format: b.format,
        notes: b.notes,
        protected: b.protected,
        verification: b.verification,
        kind: _guestKind(b.kind),
      ),
  ];

  static vm.Backup backupFfi(VirtBackup b) => vm.Backup(
    id: b.id,
    storage: b.storage,
    node: b.node,
    vmid: b.vmid,
    createdAt: switch (b.createdAt) {
      final t? => t.millisecondsSinceEpoch ~/ 1000,
      null => null,
    },
    size: _big(b.size),
    format: b.format,
    notes: b.notes,
    protected: b.protected,
    verification: b.verification,
    kind: switch (b.kind) {
      null => null,
      final k => vv.GuestKind.values.byName(k.name),
    },
  );

  static List<VirtBackupJob> backupJobs(List<vm.BackupJob> list) => [
    for (final j in list)
      VirtBackupJob(
        id: j.id,
        schedule: j.schedule,
        storage: j.storage,
        mode: VirtBackupMode.fromName(j.mode),
        compress: j.compress,
        keep: j.prune,
        enabled: j.enabled,
        all: j.all,
        vmids: j.vmids,
        exclude: j.exclude,
        pool: j.pool,
        node: j.node,
        comment: j.comment,
        notesTemplate: j.notesTemplate,
        mailNotification: j.mailNotification,
        prune: j.prune,
      ),
  ];

  static vm.BackupJob backupJobFfi(VirtBackupJob j) => vm.BackupJob(
    id: j.id,
    schedule: j.schedule,
    storage: j.storage,
    mode: j.mode?.name,
    compress: j.compress,
    enabled: j.enabled,
    all: j.all,
    vmids: Uint32List.fromList(j.vmids),
    exclude: Uint32List.fromList(j.exclude),
    pool: j.pool,
    node: j.node,
    comment: j.comment,
    notesTemplate: j.notesTemplate,
    mailNotification: j.mailNotification,
    prune: j.prune ?? j.keep,
  );

  static vm.BackupJobEdit backupJobEditFfi(VirtBackupJobEdit e) => vm.BackupJobEdit(
    id: e.id,
    isNew: e.isNew,
    node: e.node,
    storage: e.storage,
    schedule: e.schedule,
    mode: e.mode.name,
    compress: e.compress,
    enabled: e.enabled,
    all: e.all,
    vmids: Uint32List.fromList(e.vmids),
    exclude: Uint32List.fromList(e.exclude),
    pool: e.pool,
    comment: e.comment,
    notesTemplate: e.notesTemplate,
    mailNotification: e.mailNotification,
    prune: e.prune,
  );

  static vm.BackupRequest backupRequestFfi(VirtBackupRequest r) => vm.BackupRequest(
    storage: r.storage,
    mode: r.mode.name,
    compress: r.compress,
    notes: r.notes,
    protected: r.protected,
    prune: r.prune,
  );

  static vm.BackupEdit backupEditFfi(VirtBackupEdit e) => vm.BackupEdit(notes: e.notes, protected: e.protected);

  /// `sbm_virt::backup::ScheduleCheck`: the next runs in UTC.
  static VirtScheduleCheck scheduleCheck(vm.ScheduleCheck c) => VirtScheduleCheck(
    error: c.error,
    next: [for (final t in c.next) DateTime.fromMillisecondsSinceEpoch(t.toInt() * 1000, isUtc: true)],
  );

  static BigInt? _big(int? v) => v == null ? null : BigInt.from(v);

  // --- Hardware (sbm_virt::hardware) ---

  /// `sbm_virt::hardware::Hardware`.
  static VirtHardware hardware(vm.Hardware h) => VirtHardware(
    kind: _guestKind(h.kind)!,
    running: h.running,
    cpu: VirtHwCpu(
      sockets: h.cpu.sockets,
      cores: h.cpu.cores,
      threads: h.cpu.threads,
      online: h.cpu.online,
      type: h.cpu.cpuType,
    ),
    memory: VirtHwMemory(
      mib: h.memory.mib.toInt(),
      minMib: h.memory.minMib?.toInt(),
      balloon: h.memory.balloon,
      swapMib: h.memory.swapMib?.toInt(),
    ),
    disks: [for (final d in h.disks) hwDisk(d)],
    nics: [
      for (final n in h.nics)
        VirtHwNic(
          key: n.key,
          mac: n.mac,
          type: n.nicType,
          source: n.source,
          model: n.model,
          linkUp: n.linkUp,
          firewall: n.firewall,
          name: n.name,
        ),
    ],
    boot: h.boot,
    autostart: h.autostart,
    name: h.name,
    description: h.description,
    protection: h.protection,
    renameRunning: h.renameRunning,
    pending: [
      for (final p in h.pending)
        VirtPendingField(key: p.key, current: p.current, pending: p.pending, delete: p.delete),
    ],
    revision: h.revision,
    limits: VirtHwLimits(hostCpus: h.limits.hostCpus, hostMemoryBytes: h.limits.hostMemoryBytes?.toInt()),
    cpuTypes: h.cpuTypes,
    configText: h.configText,
    firmware: switch (h.firmware) {
      final f? => VirtHwFirmware(uefi: f.uefi, secureBoot: f.secureBoot, varsStorage: f.varsStorage),
      null => null,
    },
    display: switch (h.display) {
      final d? => VirtHwDisplay(protocol: d.protocol, listen: d.listen, gpu: d.gpu, port: d.port),
      null => null,
    },
    devices: [
      for (final d in h.devices)
        VirtHwDevice(
          key: d.key,
          kind: VirtHwDeviceKind.values.byName(d.kind.name),
          detail: d.detail,
          mapping: d.mapping,
        ),
    ],
    support: VirtHwSupport(
      buses: h.support.buses,
      caches: h.support.caches,
      nicModels: h.support.nicModels,
      mac: h.support.mac,
      protocols: h.support.protocols,
      listen: h.support.listen,
      gpus: h.support.gpus,
      uefi: h.support.uefi,
      secureBoot: h.support.secureBoot,
      tpm: h.support.tpm,
      usb: h.support.usb,
      pci: h.support.pci,
    ),
  );

  static VirtHwDisk hwDisk(vm.HwDisk d) => VirtHwDisk(
    key: d.key,
    kind: VirtHwDiskKind.values.byName(d.kind.name),
    source: d.source,
    size: d.size?.toInt(),
    storage: d.storage,
    mountPoint: d.mountPoint,
    bus: d.bus,
    format: d.format,
    readonly: d.readonly,
    cache: d.cache,
    cloudInit: d.cloudInit,
    resizable: d.resizable,
  );

  static vm.HwDisk hwDiskFfi(VirtHwDisk d) => vm.HwDisk(
    key: d.key,
    kind: vm.DiskKind.values.byName(d.kind.name),
    source: d.source,
    size: _big(d.size),
    storage: d.storage,
    mountPoint: d.mountPoint,
    bus: d.bus,
    format: d.format,
    readonly: d.readonly,
    cache: d.cache,
    cloudInit: d.cloudInit,
    resizable: d.resizable,
  );

  /// [hw] as `sbm_virt::hardware::Hardware`, what the rules are given.
  static vm.Hardware hardwareFfi(VirtHardware hw) => vm.Hardware(
    kind: vv.GuestKind.values.byName(hw.kind.name),
    running: hw.running,
    cpu: vm.Cpu(
      sockets: hw.cpu.sockets,
      cores: hw.cpu.cores,
      threads: hw.cpu.threads,
      online: hw.cpu.online,
      cpuType: hw.cpu.type,
    ),
    memory: vm.HwMemory(
      mib: BigInt.from(hw.memory.mib),
      minMib: _big(hw.memory.minMib),
      balloon: hw.memory.balloon,
      swapMib: _big(hw.memory.swapMib),
    ),
    disks: [for (final d in hw.disks) hwDiskFfi(d)],
    nics: [
      for (final n in hw.nics)
        vm.HwNic(
          key: n.key,
          mac: n.mac,
          nicType: n.type,
          source: n.source,
          model: n.model,
          linkUp: n.linkUp,
          firewall: n.firewall,
          name: n.name,
        ),
    ],
    boot: hw.boot,
    autostart: hw.autostart,
    name: hw.name,
    description: hw.description,
    protection: hw.protection,
    renameRunning: hw.renameRunning,
    pending: [
      for (final p in hw.pending) vm.PendingField(key: p.key, current: p.current, pending: p.pending, delete: p.delete),
    ],
    revision: hw.revision,
    limits: vm.Limits(hostCpus: hw.limits.hostCpus, hostMemoryBytes: _big(hw.limits.hostMemoryBytes)),
    cpuTypes: hw.cpuTypes,
    configText: hw.configText,
    firmware: switch (hw.firmware) {
      final f? => vm.Firmware(uefi: f.uefi, secureBoot: f.secureBoot, varsStorage: f.varsStorage),
      null => null,
    },
    display: switch (hw.display) {
      final d? => vm.HwDisplay(protocol: d.protocol, listen: d.listen, gpu: d.gpu, port: d.port),
      null => null,
    },
    devices: [
      for (final d in hw.devices)
        vm.HwDevice(key: d.key, kind: vm.DeviceKind.values.byName(d.kind.name), detail: d.detail, mapping: d.mapping),
    ],
    support: vm.Support(
      buses: hw.support.buses,
      caches: hw.support.caches,
      nicModels: hw.support.nicModels,
      mac: hw.support.mac,
      protocols: hw.support.protocols,
      listen: hw.support.listen,
      gpus: hw.support.gpus,
      uefi: hw.support.uefi,
      secureBoot: hw.support.secureBoot,
      tpm: hw.support.tpm,
      usb: hw.support.usb,
      pci: hw.support.pci,
    ),
  );

  static VirtHostDevice hostDevice(vm.HostDevice d) => VirtHostDevice(
    id: d.id,
    label: d.label,
    detail: d.detail,
    mapping: d.mapping,
    usbBus: d.usbBus,
    usbPort: d.usbPort,
    usbDevice: d.usbDevice,
    iommuGroup: d.iommuGroup,
    groupSize: d.groupSize,
  );

  static vm.HostDevice hostDeviceFfi(VirtHostDevice d) => vm.HostDevice(
    id: d.id,
    label: d.label,
    detail: d.detail,
    mapping: d.mapping,
    usbBus: d.usbBus,
    usbPort: d.usbPort,
    usbDevice: d.usbDevice,
    iommuGroup: d.iommuGroup,
    groupSize: d.groupSize,
  );

  /// `sbm_virt::hardware::HostDevices`.
  static VirtHostDevices hostDevices(vm.HostDevices d) => VirtHostDevices(
    usb: [for (final u in d.usb) hostDevice(u)],
    pci: [for (final p in d.pci) hostDevice(p)],
    iommu: d.iommu,
    mappingsOnly: d.mappingsOnly,
  );

  /// [change] as `sbm_virt::hardware::Change`: what it names, by id.
  static vm.HwChange hwChangeFfi(VirtHwChange change) => switch (change) {
    VirtHwSetCpu(:final sockets, :final cores, :final online, :final type) =>
      vm.HwChange.setCpu(sockets: sockets, cores: cores, online: online, cpuType: type),
    VirtHwSetMemory(:final mib, :final minMib, :final swapMib) =>
      vm.HwChange.setMemory(mib: BigInt.from(mib), minMib: _big(minMib), swapMib: _big(swapMib)),
    VirtHwGrowDisk(:final key, :final bytes) => vm.HwChange.growDisk(key: key, bytes: BigInt.from(bytes)),
    VirtHwAddDisk(:final storage, :final gib, :final mountPoint) =>
      vm.HwChange.addDisk(pool: storage.id, gib: BigInt.from(gib), mountPoint: mountPoint),
    VirtHwAttachVolume(:final storage, :final volume, :final mountPoint) => vm.HwChange.attachVolume(
      volume: vm.VolumeRef(pool: storage.id, volume: volume.id),
      mountPoint: mountPoint,
    ),
    VirtHwRemoveDisk(:final key, :final deleteVolume) => vm.HwChange.removeDisk(key: key, deleteVolume: deleteVolume),
    VirtHwAddCdrom(:final media) => vm.HwChange.addCdrom(media: _volumeRef(media)),
    VirtHwSetMedia(:final key, :final media) => vm.HwChange.setMedia(key: key, media: _volumeRef(media)),
    VirtHwAddNic(:final network, :final model) => vm.HwChange.addNic(network: network.id, model: model),
    VirtHwRemoveNic(:final key) => vm.HwChange.removeNic(key: key),
    VirtHwUpdateNic(:final key, :final network, :final linkUp, :final firewall) =>
      vm.HwChange.updateNic(key: key, network: network?.id, linkUp: linkUp, firewall: firewall),
    VirtHwSetBoot(:final order) => vm.HwChange.setBoot(order: order),
    VirtHwSetAutostart(:final on) => vm.HwChange.setAutostart(on_: on),
    VirtHwSetName(:final name) => vm.HwChange.setName(name: name),
    VirtHwSetDescription(:final text) => vm.HwChange.setDescription(text: text),
    VirtHwSetProtection(:final on) => vm.HwChange.setProtection(on_: on),
    VirtHwUpdateDisk(:final key, :final bus, :final cache) => vm.HwChange.updateDisk(key: key, bus: bus, cache: cache),
    VirtHwSetNicHardware(:final key, :final model, :final mac) =>
      vm.HwChange.setNicHardware(key: key, model: model, mac: mac),
    VirtHwSetFirmware(:final uefi, :final secureBoot, :final storage) =>
      vm.HwChange.setFirmware(uefi: uefi, secureBoot: secureBoot, storage: storage?.id),
    VirtHwSetDisplay(:final protocol, :final listen, :final gpu) =>
      vm.HwChange.setDisplay(protocol: protocol, listen: listen, gpu: gpu),
    VirtHwAddDevice(:final kind, :final host, :final storage, :final usbNaming) => vm.HwChange.addDevice(
      kind: vm.DeviceKind.values.byName(kind.name),
      host: switch (host) {
        final h? => hostDeviceFfi(h),
        null => null,
      },
      storage: storage?.id,
      usbNaming: vm.UsbNaming.values.byName(usbNaming.name),
    ),
    VirtHwRemoveDevice(:final key) => vm.HwChange.removeDevice(key: key),
    VirtHwRevert(:final keys) => vm.HwChange.revert(keys: keys),
    // Its own call (`VirtBackend.revertPending`), never a change.
    VirtHwRevertPending() => const vm.HwChange.revert(keys: []),
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
  static VirtHwOutcome hwOutcome(vm.Outcome o) => VirtHwOutcome(liveError: o.liveError, volumeKept: o.volumeKept);

  /// `sbm_virt::hardware::CloudInitState`.
  static VirtCloudInitState cloudInitState(vm.CloudInitState c) => VirtCloudInitState(
    user: c.user,
    sshKeys: c.sshKeys,
    hostname: c.hostname,
    address: c.address,
    gateway: c.gateway,
    dns: c.dns,
    searchDomains: c.searchDomains,
    nics: c.nics,
    passwordSet: c.passwordSet,
    passwordExpires: c.passwordExpires,
    network: c.network,
    foreign: c.foreign,
    revision: c.revision,
  );

  /// [edit] made from [base] as `sbm_virt::hardware::CloudInitEdit`.
  static vm.CloudInitEdit cloudInitEditFfi(VirtCloudInitState base, VirtCloudInitEdit edit) => vm.CloudInitEdit(
    values: cloudInitFfi(edit.values),
    removePassword: edit.removePassword,
    passwordExpires: edit.passwordExpires,
    revision: base.revision,
  );

  /// `sbm_virt::model::GuestDetail`.
  static VirtGuestDetail detail(vv.VirtGuestDetailReport d) => VirtGuestDetail(
    disks: [
      for (final k in d.disks)
        VirtDisk(
          device: k.device,
          sourceType: k.sourceType,
          source: k.source,
          target: k.target,
          bus: k.bus,
          format: k.format,
          readonly: k.readonly,
          size: k.size?.toInt(),
        ),
    ],
    nics: [
      for (final n in d.nics) VirtNic(kind: n.kind, mac: n.mac, source: n.source, model: n.model, target: n.target),
    ],
    graphics: [
      for (final g in d.graphics)
        VirtGraphics(
          kind: g.kind,
          port: g.port,
          tlsPort: g.tlsPort,
          autoport: g.autoport,
          listen: g.listen,
          socket: g.socket,
        ),
    ],
    display: switch (d.display) {
      null => null,
      final v => VirtDisplay(
        uri: v.uri,
        protocol: v.protocol,
        host: v.host,
        port: v.port,
        tlsPort: v.tlsPort,
        socket: v.socket,
      ),
    },
    consoles: {
      for (final c in d.consoles)
        switch (c) {
          vv.ConsoleKind.text => VirtConsoleKind.text,
          vv.ConsoleKind.vnc => VirtConsoleKind.vnc,
        },
    },
    description: d.description,
    arch: d.arch,
    machine: d.machine,
  );

  static List<VirtGuestSnapshot> snapshots(List<vv.Snapshot> list) => [
    for (final s in list)
      VirtGuestSnapshot(
        name: s.name,
        parent: s.parent,
        description: s.description,
        createdAt: switch (s.createdAt) {
          final t? => DateTime.fromMillisecondsSinceEpoch(t * 1000),
          null => null,
        },
        current: s.current,
        withMemory: s.withMemory,
        external: s.external_,
        layers: [
          for (final l in s.layers) VirtSnapshotLayer(target: l.target, file: l.file, external: l.external_),
        ],
      ),
  ];

  static List<VirtSnapDiff> diff(List<vv.Diff> list) => [
    for (final d in list)
      VirtSnapDiff(
        group: VirtSnapDiffGroup.values.byName(d.group.name),
        key: d.key,
        before: d.before,
        after: d.after,
      ),
  ];

  static VirtSnapChain chain(vv.Chain c) => VirtSnapChain(
    pools: c.pools,
    refusal: c.refusal,
    externalRefusal: c.externalRefusal,
    disks: [
      for (final d in c.disks)
        VirtSnapChainDisk(
          target: d.target,
          pool: d.pool,
          error: d.error,
          files: [
            for (final f in d.files)
              VirtSnapChainFile(
                path: f.path,
                format: f.format,
                allocation: f.allocation?.toInt(),
                backing: f.backing,
                snap: f.snap,
                active: f.active,
              ),
          ],
        ),
    ],
  );

  /// Oldest first.
  static List<VirtStats> history(List<vv.Stats> list) => [for (final s in list) _stats(s)];

  static VirtStats _stats(vv.Stats s) => VirtStats(
    at: DateTime.fromMillisecondsSinceEpoch(s.at),
    cpu: s.cpu,
    memUsed: s.memUsed?.toInt(),
    memTotal: s.memTotal?.toInt(),
    diskUsed: s.diskUsed?.toInt(),
    diskTotal: s.diskTotal?.toInt(),
    diskRead: s.diskRead,
    diskWrite: s.diskWrite,
    netIn: s.netIn,
    netOut: s.netOut,
  );

  static VirtCapabilities capabilities(vv.Capabilities c) => VirtCapabilities(
    lxc: c.lxc,
    pause: c.pause,
    snapshots: c.snapshots,
    snapshotMemoryRequired: c.snapshotMemoryRequired,
    snapshotExternal: c.snapshotExternal,
    snapshotSupported: c.snapshotSupported,
    storage: c.storage,
    network: c.network,
    backup: c.backup,
    clone: c.clone,
    linkedClone: c.linkedClone,
    template: c.template,
    cloneTarget: c.cloneTarget,
    backupJobs: c.backupJobs,
    cluster: c.cluster,
    serialConsole: c.serialConsole,
    vncConsole: c.vncConsole,
    termConsole: c.termConsole,
    storedHistory: c.storedHistory,
    create: c.create,
    deleteKeepsDisks: c.deleteKeepsDisks,
    hardware: c.hardware,
    hardwareRevert: c.hardwareRevert,
    hardwareRevertPending: c.hardwareRevertPending,
    storageEdit: c.storageEdit,
    poolTypes: c.poolTypes,
    poolAutostart: c.poolAutostart,
    poolDeleteStorage: c.poolDeleteStorage,
    volumeResize: c.volumeResize,
    volumeClone: c.volumeClone,
    upload: c.upload,
    networkEdit: c.networkEdit,
    networkModes: c.networkModes,
    networkStart: c.networkStart,
    networkApply: c.networkApply,
    networkEditExisting: c.networkEditExisting,
    networkRestart: c.networkRestart,
  );

  // -------------------------------------------------------------------------
  // Storage and networks (`sbm_virt::resource`)
  // -------------------------------------------------------------------------

  static VirtGuestRef guestRef(vm.GuestRef r) =>
      VirtGuestRef(guestId: r.guestId, vmid: r.vmid, device: r.device, mac: r.mac, ip: r.ip);

  static vm.GuestRef guestRefFfi(VirtGuestRef r) =>
      vm.GuestRef(guestId: r.guestId, vmid: r.vmid, device: r.device, mac: r.mac, ip: r.ip);

  /// A list of `sbm_virt::resource::Pool`.
  static List<VirtStoragePool> pools(List<vm.ResourcePool> list) => [
    for (final p in list)
      VirtStoragePool(
        id: p.id,
        name: p.name,
        node: p.node,
        type: p.poolType,
        path: p.path,
        source: p.source,
        capacity: p.capacity?.toInt(),
        used: p.used?.toInt(),
        available: p.available?.toInt(),
        active: p.active,
        autostart: p.autostart,
        enabled: p.enabled,
        shared: p.shared,
        content: p.content,
        volumeCount: p.volumeCount?.toInt(),
      ),
  ];

  static vm.ResourcePool poolFfi(VirtStoragePool p) => vm.ResourcePool(
    id: p.id,
    name: p.name,
    node: p.node,
    poolType: p.type,
    path: p.path,
    source: p.source,
    capacity: _big(p.capacity),
    used: _big(p.used),
    available: _big(p.available),
    active: p.active,
    autostart: p.autostart,
    enabled: p.enabled,
    shared: p.shared,
    content: p.content,
    volumeCount: _big(p.volumeCount),
  );

  /// A list of `sbm_virt::resource::Volume`.
  static List<VirtVolume> volumes(List<vm.Volume> list) => [
    for (final v in list)
      VirtVolume(
        id: v.id,
        name: v.name,
        path: v.path,
        format: v.format,
        content: v.content,
        capacity: v.capacity?.toInt(),
        allocation: v.allocation?.toInt(),
        backing: v.backing,
        createdAt: switch (v.createdAt) {
          final t? => DateTime.fromMillisecondsSinceEpoch(t * 1000),
          null => null,
        },
        users: [for (final r in v.users) guestRef(r)],
        backs: v.backs,
      ),
  ];

  static vm.Volume volumeFfi(VirtVolume v) => vm.Volume(
    id: v.id,
    name: v.name,
    path: v.path,
    format: v.format,
    content: v.content,
    capacity: _big(v.capacity),
    allocation: _big(v.allocation),
    backing: v.backing,
    createdAt: switch (v.createdAt) {
      final t? => t.millisecondsSinceEpoch ~/ 1000,
      null => null,
    },
    users: [for (final r in v.users) guestRefFfi(r)],
    backs: v.backs,
  );

  /// A list of `sbm_virt::resource::Network`.
  static List<VirtNetwork> networks(List<vm.Network> list) => [
    for (final n in list)
      VirtNetwork(
        id: n.id,
        name: n.name,
        node: n.node,
        mode: n.mode,
        bridge: n.bridge,
        cidrs: n.cidrs,
        gateway: n.gateway,
        dhcpRanges: n.dhcpRanges,
        ports: n.ports,
        vlanAware: n.vlanAware,
        vlanId: n.vlanId,
        vlanDevice: n.vlanDevice,
        bondMode: n.bondMode,
        active: n.active,
        autostart: n.autostart,
        comment: n.comment,
        hosts: [for (final h in n.hosts) VirtNetHost(mac: h.mac, ip: h.ip, name: h.name)],
        xml: n.xml,
        pendingRestart: n.pendingRestart,
        managementEditable: n.managementEditable,
        users: [for (final r in n.users) guestRef(r)],
      ),
  ];

  static vm.Network networkFfi(VirtNetwork n) => vm.Network(
    id: n.id,
    name: n.name,
    node: n.node,
    mode: n.mode,
    bridge: n.bridge,
    cidrs: n.cidrs,
    gateway: n.gateway,
    dhcpRanges: n.dhcpRanges,
    ports: n.ports,
    vlanAware: n.vlanAware,
    vlanId: n.vlanId,
    vlanDevice: n.vlanDevice,
    bondMode: n.bondMode,
    active: n.active,
    autostart: n.autostart,
    comment: n.comment,
    hosts: [for (final h in n.hosts) _hostFfi(h)],
    xml: n.xml,
    pendingRestart: n.pendingRestart,
    managementEditable: n.managementEditable,
    users: [for (final r in n.users) guestRefFfi(r)],
  );

  static vm.NetHost _hostFfi(VirtNetHost h) => vm.NetHost(mac: h.mac, ip: h.ip, name: h.name);

  /// A list of `sbm_virt::resource::NetworkChanges`.
  static List<VirtNetworkChanges> networkChanges(List<vm.NetworkChanges> list) => [
    for (final c in list) VirtNetworkChanges(node: c.node, diff: c.diff),
  ];

  /// [change] as `sbm_virt::resource::Change`: what it is to, named by id,
  /// resolved against what the host lists when it is made.
  static vm.ResourceChange changeFfi(VirtResourceChange change) => switch (change) {
    VirtPoolCreate(
      :final name,
      :final type,
      :final source,
      :final target,
      :final node,
      :final content,
      :final autostart,
    ) =>
      vm.ResourceChange.poolCreate(
        name: name,
        poolType: type,
        source: source,
        target: target,
        node: node,
        content: content,
        autostart: autostart,
      ),
    VirtPoolSetActive(:final pool, :final active) => vm.ResourceChange.poolSetActive(pool: pool.id, active: active),
    VirtPoolSetAutostart(:final pool, :final on) => vm.ResourceChange.poolSetAutostart(pool: pool.id, on_: on),
    VirtPoolRefresh(:final pool) => vm.ResourceChange.poolRefresh(pool: pool.id),
    VirtPoolDelete(:final pool, :final deleteStorage) =>
      vm.ResourceChange.poolDelete(pool: pool.id, deleteStorage: deleteStorage),
    VirtVolumeCreate(:final pool, :final name, :final gib, :final format) =>
      vm.ResourceChange.volumeCreate(pool: pool.id, name: name, gib: BigInt.from(gib), format: format),
    VirtVolumeDelete(:final pool, :final volume) => vm.ResourceChange.volumeDelete(pool: pool.id, volume: volume.id),
    VirtVolumeResize(:final pool, :final volume, :final bytes) =>
      vm.ResourceChange.volumeResize(pool: pool.id, volume: volume.id, bytes: BigInt.from(bytes)),
    VirtVolumeClone(:final pool, :final volume, :final name) =>
      vm.ResourceChange.volumeClone(pool: pool.id, volume: volume.id, name: name),
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
      vm.ResourceChange.networkCreate(
        name: name,
        mode: mode,
        node: node,
        bridge: bridge,
        cidr: cidr,
        dhcpStart: dhcpStart,
        dhcpEnd: dhcpEnd,
        vlanAware: vlanAware,
        autostart: autostart,
      ),
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
      vm.ResourceChange.networkEdit(
        network: network.id,
        mode: mode,
        bridge: bridge,
        address: address,
        prefix: prefix,
        dhcpStart: dhcpStart,
        dhcpEnd: dhcpEnd,
        hosts: [for (final h in hosts) _hostFfi(h)],
        restart: restart,
        // The definition the edit was made from: one changed since is
        // refused rather than overwritten.
        baseXml: network.xml.isEmpty ? null : network.xml,
      ),
    VirtNetworkEditBridge(
      :final network,
      :final ports,
      :final cidr,
      :final gateway,
      :final vlanAware,
      :final autostart,
    ) =>
      vm.ResourceChange.networkEditBridge(
        network: network.id,
        ports: ports,
        cidr: cidr,
        gateway: gateway,
        vlanAware: vlanAware,
        autostart: autostart,
      ),
    VirtNetworkRestart(:final network) =>
      vm.ResourceChange.networkRestart(network: network.id, baseXml: network.xml.isEmpty ? null : network.xml),
    VirtNetworkSetActive(:final network, :final active) =>
      vm.ResourceChange.networkSetActive(network: network.id, active: active),
    VirtNetworkSetAutostart(:final network, :final on) =>
      vm.ResourceChange.networkSetAutostart(network: network.id, on_: on),
    VirtNetworkDelete(:final network) => vm.ResourceChange.networkDelete(network: network.id),
    VirtNetworkApply(:final node) => vm.ResourceChange.networkApply(node: node),
    VirtNetworkRevert(:final node) => vm.ResourceChange.networkRevert(node: node),
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
      {'code': 'backup_refused', 'issue': final String issue} =>
        virtBackupIssueText(issue),
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

  static Duration? _seconds(Object? v) =>
      v is int && v > 0 ? Duration(seconds: v) : null;
}
