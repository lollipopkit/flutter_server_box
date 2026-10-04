// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'libvirt.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LibvirtVersion _$LibvirtVersionFromJson(Map<String, dynamic> json) =>
    _LibvirtVersion(
      libvirt: json['libvirt'] as String?,
      hypervisor: json['hypervisor'] as String?,
      hypervisorVersion: json['hypervisor_version'] as String?,
    );

Map<String, dynamic> _$LibvirtVersionToJson(_LibvirtVersion instance) =>
    <String, dynamic>{
      'libvirt': instance.libvirt,
      'hypervisor': instance.hypervisor,
      'hypervisor_version': instance.hypervisorVersion,
    };

_VirtHostProbeResult _$VirtHostProbeResultFromJson(Map<String, dynamic> json) =>
    _VirtHostProbeResult(
      pve: json['pve'] as String?,
      container: json['container'] as String?,
      libvirt: json['libvirt'] == null
          ? null
          : LibvirtVersion.fromJson(json['libvirt'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$VirtHostProbeResultToJson(
  _VirtHostProbeResult instance,
) => <String, dynamic>{
  'pve': instance.pve,
  'container': instance.container,
  'libvirt': instance.libvirt,
};

_LibvirtSnapDiff _$LibvirtSnapDiffFromJson(Map<String, dynamic> json) =>
    _LibvirtSnapDiff(
      group: json['group'] as String? ?? '',
      key: json['key'] as String? ?? '',
      before: json['before'] as String?,
      after: json['after'] as String?,
      removed: json['removed'] as bool? ?? false,
      added: json['added'] as bool? ?? false,
    );

Map<String, dynamic> _$LibvirtSnapDiffToJson(_LibvirtSnapDiff instance) =>
    <String, dynamic>{
      'group': instance.group,
      'key': instance.key,
      'before': instance.before,
      'after': instance.after,
      'removed': instance.removed,
      'added': instance.added,
    };

_LibvirtVolumeRef _$LibvirtVolumeRefFromJson(Map<String, dynamic> json) =>
    _LibvirtVolumeRef(
      name: json['name'] as String,
      path: json['path'] as String?,
    );

Map<String, dynamic> _$LibvirtVolumeRefToJson(_LibvirtVolumeRef instance) =>
    <String, dynamic>{'name': instance.name, 'path': instance.path};

_LibvirtPool _$LibvirtPoolFromJson(Map<String, dynamic> json) => _LibvirtPool(
  name: json['name'] as String,
  uuid: json['uuid'] as String?,
  poolType: json['pool_type'] as String?,
  active: json['active'] as bool? ?? false,
  autostart: json['autostart'] as bool? ?? false,
  capacity: (json['capacity'] as num?)?.toInt(),
  allocation: (json['allocation'] as num?)?.toInt(),
  available: (json['available'] as num?)?.toInt(),
  target: json['target'] as String?,
  source: json['source'] as String?,
  volumes: (json['volumes'] as List<dynamic>?)
      ?.map((e) => LibvirtVolumeRef.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$LibvirtPoolToJson(_LibvirtPool instance) =>
    <String, dynamic>{
      'name': instance.name,
      'uuid': instance.uuid,
      'pool_type': instance.poolType,
      'active': instance.active,
      'autostart': instance.autostart,
      'capacity': instance.capacity,
      'allocation': instance.allocation,
      'available': instance.available,
      'target': instance.target,
      'source': instance.source,
      'volumes': instance.volumes,
    };

_LibvirtDiskUse _$LibvirtDiskUseFromJson(Map<String, dynamic> json) =>
    _LibvirtDiskUse(
      domain: json['domain'] as String,
      kind: json['kind'] as String? ?? '',
      device: json['device'] as String? ?? '',
      target: json['target'] as String? ?? '',
      source: json['source'] as String?,
    );

Map<String, dynamic> _$LibvirtDiskUseToJson(_LibvirtDiskUse instance) =>
    <String, dynamic>{
      'domain': instance.domain,
      'kind': instance.kind,
      'device': instance.device,
      'target': instance.target,
      'source': instance.source,
    };

_LibvirtStorage _$LibvirtStorageFromJson(Map<String, dynamic> json) =>
    _LibvirtStorage(
      pools:
          (json['pools'] as List<dynamic>?)
              ?.map((e) => LibvirtPool.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LibvirtPool>[],
      disks:
          (json['disks'] as List<dynamic>?)
              ?.map((e) => LibvirtDiskUse.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LibvirtDiskUse>[],
    );

Map<String, dynamic> _$LibvirtStorageToJson(_LibvirtStorage instance) =>
    <String, dynamic>{'pools': instance.pools, 'disks': instance.disks};

_LibvirtHwCpu _$LibvirtHwCpuFromJson(Map<String, dynamic> json) =>
    _LibvirtHwCpu(
      sockets: (json['sockets'] as num).toInt(),
      dies: (json['dies'] as num?)?.toInt() ?? 1,
      clusters: (json['clusters'] as num?)?.toInt() ?? 1,
      cores: (json['cores'] as num).toInt(),
      threads: (json['threads'] as num?)?.toInt() ?? 1,
      max: (json['max'] as num).toInt(),
      current: (json['current'] as num).toInt(),
      topology: json['topology'] as bool? ?? false,
    );

Map<String, dynamic> _$LibvirtHwCpuToJson(_LibvirtHwCpu instance) =>
    <String, dynamic>{
      'sockets': instance.sockets,
      'dies': instance.dies,
      'clusters': instance.clusters,
      'cores': instance.cores,
      'threads': instance.threads,
      'max': instance.max,
      'current': instance.current,
      'topology': instance.topology,
    };

_LibvirtHwDisk _$LibvirtHwDiskFromJson(Map<String, dynamic> json) =>
    _LibvirtHwDisk(
      target: json['target'] as String,
      device: json['device'] as String? ?? 'disk',
      bus: json['bus'] as String?,
      sourceType: json['source_type'] as String?,
      source: json['source'] as String?,
      format: json['format'] as String?,
      readonly: json['readonly'] as bool? ?? false,
      capacity: (json['capacity'] as num?)?.toInt(),
      bootOrder: (json['boot_order'] as num?)?.toInt(),
      cache: json['cache'] as String?,
    );

Map<String, dynamic> _$LibvirtHwDiskToJson(_LibvirtHwDisk instance) =>
    <String, dynamic>{
      'target': instance.target,
      'device': instance.device,
      'bus': instance.bus,
      'source_type': instance.sourceType,
      'source': instance.source,
      'format': instance.format,
      'readonly': instance.readonly,
      'capacity': instance.capacity,
      'boot_order': instance.bootOrder,
      'cache': instance.cache,
    };

_LibvirtHwNic _$LibvirtHwNicFromJson(Map<String, dynamic> json) =>
    _LibvirtHwNic(
      mac: json['mac'] as String,
      kind: json['kind'] as String? ?? '',
      source: json['source'] as String?,
      model: json['model'] as String?,
      linkUp: json['link_up'] as bool? ?? true,
      bootOrder: (json['boot_order'] as num?)?.toInt(),
    );

Map<String, dynamic> _$LibvirtHwNicToJson(_LibvirtHwNic instance) =>
    <String, dynamic>{
      'mac': instance.mac,
      'kind': instance.kind,
      'source': instance.source,
      'model': instance.model,
      'link_up': instance.linkUp,
      'boot_order': instance.bootOrder,
    };

_LibvirtHwConfig _$LibvirtHwConfigFromJson(Map<String, dynamic> json) =>
    _LibvirtHwConfig(
      cpu: LibvirtHwCpu.fromJson(json['cpu'] as Map<String, dynamic>),
      memoryKib: (json['memory_kib'] as num).toInt(),
      currentMemoryKib: (json['current_memory_kib'] as num).toInt(),
      disks:
          (json['disks'] as List<dynamic>?)
              ?.map((e) => LibvirtHwDisk.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LibvirtHwDisk>[],
      nics:
          (json['nics'] as List<dynamic>?)
              ?.map((e) => LibvirtHwNic.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LibvirtHwNic>[],
      boot:
          (json['boot'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
      balloon: json['balloon'] as bool? ?? false,
      efi: json['efi'] as bool? ?? false,
      secureBoot: json['secure_boot'] as bool? ?? false,
      machine: json['machine'] as String?,
      graphics: json['graphics'] == null
          ? null
          : LibvirtHwGraphics.fromJson(
              json['graphics'] as Map<String, dynamic>,
            ),
      video: json['video'] as String?,
      tpm: json['tpm'] == null
          ? null
          : LibvirtHwTpm.fromJson(json['tpm'] as Map<String, dynamic>),
      hostdevs:
          (json['hostdevs'] as List<dynamic>?)
              ?.map((e) => LibvirtHwHostdev.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LibvirtHwHostdev>[],
      seed: json['seed'] as String?,
    );

Map<String, dynamic> _$LibvirtHwConfigToJson(_LibvirtHwConfig instance) =>
    <String, dynamic>{
      'cpu': instance.cpu,
      'memory_kib': instance.memoryKib,
      'current_memory_kib': instance.currentMemoryKib,
      'disks': instance.disks,
      'nics': instance.nics,
      'boot': instance.boot,
      'balloon': instance.balloon,
      'efi': instance.efi,
      'secure_boot': instance.secureBoot,
      'machine': instance.machine,
      'graphics': instance.graphics,
      'video': instance.video,
      'tpm': instance.tpm,
      'hostdevs': instance.hostdevs,
      'seed': instance.seed,
    };

_LibvirtHwGraphics _$LibvirtHwGraphicsFromJson(Map<String, dynamic> json) =>
    _LibvirtHwGraphics(
      kind: json['kind'] as String? ?? '',
      listen: json['listen'] as String?,
      port: (json['port'] as num?)?.toInt(),
    );

Map<String, dynamic> _$LibvirtHwGraphicsToJson(_LibvirtHwGraphics instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'listen': instance.listen,
      'port': instance.port,
    };

_LibvirtHwTpm _$LibvirtHwTpmFromJson(Map<String, dynamic> json) =>
    _LibvirtHwTpm(
      model: json['model'] as String? ?? '',
      backend: json['backend'] as String? ?? '',
      version: json['version'] as String?,
    );

Map<String, dynamic> _$LibvirtHwTpmToJson(_LibvirtHwTpm instance) =>
    <String, dynamic>{
      'model': instance.model,
      'backend': instance.backend,
      'version': instance.version,
    };

_LibvirtHwHostdev _$LibvirtHwHostdevFromJson(Map<String, dynamic> json) =>
    _LibvirtHwHostdev(
      key: json['key'] as String,
      kind: json['kind'] as String? ?? '',
      vendor: json['vendor'] as String?,
      product: json['product'] as String?,
      address: json['address'] as String?,
    );

Map<String, dynamic> _$LibvirtHwHostdevToJson(_LibvirtHwHostdev instance) =>
    <String, dynamic>{
      'key': instance.key,
      'kind': instance.kind,
      'vendor': instance.vendor,
      'product': instance.product,
      'address': instance.address,
    };

_LibvirtHwCaps _$LibvirtHwCapsFromJson(Map<String, dynamic> json) =>
    _LibvirtHwCaps(
      efi: json['efi'] as bool? ?? false,
      secureBoot: json['secure_boot'] as bool? ?? false,
      tpmEmulator: json['tpm_emulator'] as bool? ?? false,
      graphics:
          (json['graphics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      video:
          (json['video'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
      diskBuses:
          (json['disk_buses'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      hostdev: json['hostdev'] as bool? ?? false,
    );

Map<String, dynamic> _$LibvirtHwCapsToJson(_LibvirtHwCaps instance) =>
    <String, dynamic>{
      'efi': instance.efi,
      'secure_boot': instance.secureBoot,
      'tpm_emulator': instance.tpmEmulator,
      'graphics': instance.graphics,
      'video': instance.video,
      'disk_buses': instance.diskBuses,
      'hostdev': instance.hostdev,
    };

_LibvirtFirmware _$LibvirtFirmwareFromJson(Map<String, dynamic> json) =>
    _LibvirtFirmware(
      name: json['name'] as String,
      secureBoot: json['secure_boot'] as bool? ?? false,
      enrolledKeys: json['enrolled_keys'] as bool? ?? false,
    );

Map<String, dynamic> _$LibvirtFirmwareToJson(_LibvirtFirmware instance) =>
    <String, dynamic>{
      'name': instance.name,
      'secure_boot': instance.secureBoot,
      'enrolled_keys': instance.enrolledKeys,
    };

_LibvirtHostDevices _$LibvirtHostDevicesFromJson(Map<String, dynamic> json) =>
    _LibvirtHostDevices(
      usb:
          (json['usb'] as List<dynamic>?)
              ?.map((e) => LibvirtHostUsb.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LibvirtHostUsb>[],
      pci:
          (json['pci'] as List<dynamic>?)
              ?.map((e) => LibvirtHostPci.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LibvirtHostPci>[],
      iommu: json['iommu'] as bool? ?? false,
    );

Map<String, dynamic> _$LibvirtHostDevicesToJson(_LibvirtHostDevices instance) =>
    <String, dynamic>{
      'usb': instance.usb,
      'pci': instance.pci,
      'iommu': instance.iommu,
    };

_LibvirtHostUsb _$LibvirtHostUsbFromJson(Map<String, dynamic> json) =>
    _LibvirtHostUsb(
      vendor: json['vendor'] as String,
      product: json['product'] as String,
      vendorName: json['vendor_name'] as String?,
      productName: json['product_name'] as String?,
      bus: (json['bus'] as num?)?.toInt(),
      device: (json['device'] as num?)?.toInt(),
      port: json['port'] as String?,
    );

Map<String, dynamic> _$LibvirtHostUsbToJson(_LibvirtHostUsb instance) =>
    <String, dynamic>{
      'vendor': instance.vendor,
      'product': instance.product,
      'vendor_name': instance.vendorName,
      'product_name': instance.productName,
      'bus': instance.bus,
      'device': instance.device,
      'port': instance.port,
    };

_LibvirtHostPci _$LibvirtHostPciFromJson(Map<String, dynamic> json) =>
    _LibvirtHostPci(
      address: json['address'] as String,
      vendor: json['vendor'] as String?,
      product: json['product'] as String?,
      vendorName: json['vendor_name'] as String?,
      productName: json['product_name'] as String?,
      pciClass: json['class'] as String?,
      iommuGroup: (json['iommu_group'] as num?)?.toInt(),
      groupSize: (json['group_size'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$LibvirtHostPciToJson(_LibvirtHostPci instance) =>
    <String, dynamic>{
      'address': instance.address,
      'vendor': instance.vendor,
      'product': instance.product,
      'vendor_name': instance.vendorName,
      'product_name': instance.productName,
      'class': instance.pciClass,
      'iommu_group': instance.iommuGroup,
      'group_size': instance.groupSize,
    };

_LibvirtHardwareInfo _$LibvirtHardwareInfoFromJson(Map<String, dynamic> json) =>
    _LibvirtHardwareInfo(
      config: LibvirtHwConfig.fromJson(json['config'] as Map<String, dynamic>),
      live: json['live'] == null
          ? null
          : LibvirtHwConfig.fromJson(json['live'] as Map<String, dynamic>),
      configXml: json['config_xml'] as String,
      configText: json['config_text'] as String? ?? '',
      liveXml: json['live_xml'] as String? ?? '',
      autostart: json['autostart'] as bool? ?? false,
      description: json['description'] as String?,
      hostCpus: (json['host_cpus'] as num?)?.toInt(),
      hostMemoryKib: (json['host_memory_kib'] as num?)?.toInt(),
      caps: json['caps'] == null
          ? null
          : LibvirtHwCaps.fromJson(json['caps'] as Map<String, dynamic>),
      firmware:
          (json['firmware'] as List<dynamic>?)
              ?.map((e) => LibvirtFirmware.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LibvirtFirmware>[],
    );

Map<String, dynamic> _$LibvirtHardwareInfoToJson(
  _LibvirtHardwareInfo instance,
) => <String, dynamic>{
  'config': instance.config,
  'live': instance.live,
  'config_xml': instance.configXml,
  'config_text': instance.configText,
  'live_xml': instance.liveXml,
  'autostart': instance.autostart,
  'description': instance.description,
  'host_cpus': instance.hostCpus,
  'host_memory_kib': instance.hostMemoryKib,
  'caps': instance.caps,
  'firmware': instance.firmware,
};
