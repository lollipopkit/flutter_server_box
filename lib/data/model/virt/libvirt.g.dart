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

_LibvirtBlockStats _$LibvirtBlockStatsFromJson(Map<String, dynamic> json) =>
    _LibvirtBlockStats(
      name: json['name'] as String? ?? '',
      path: json['path'] as String?,
      rdBytes: (json['rd_bytes'] as num?)?.toInt(),
      wrBytes: (json['wr_bytes'] as num?)?.toInt(),
      capacity: (json['capacity'] as num?)?.toInt(),
      allocation: (json['allocation'] as num?)?.toInt(),
    );

Map<String, dynamic> _$LibvirtBlockStatsToJson(_LibvirtBlockStats instance) =>
    <String, dynamic>{
      'name': instance.name,
      'path': instance.path,
      'rd_bytes': instance.rdBytes,
      'wr_bytes': instance.wrBytes,
      'capacity': instance.capacity,
      'allocation': instance.allocation,
    };

_LibvirtNetStats _$LibvirtNetStatsFromJson(Map<String, dynamic> json) =>
    _LibvirtNetStats(
      name: json['name'] as String? ?? '',
      rxBytes: (json['rx_bytes'] as num?)?.toInt(),
      txBytes: (json['tx_bytes'] as num?)?.toInt(),
    );

Map<String, dynamic> _$LibvirtNetStatsToJson(_LibvirtNetStats instance) =>
    <String, dynamic>{
      'name': instance.name,
      'rx_bytes': instance.rxBytes,
      'tx_bytes': instance.txBytes,
    };

_LibvirtCounters _$LibvirtCountersFromJson(Map<String, dynamic> json) =>
    _LibvirtCounters(
      cpuTimeNs: (json['cpu_time_ns'] as num?)?.toInt(),
      balloonRssKib: (json['balloon_rss_kib'] as num?)?.toInt(),
      balloonAvailableKib: (json['balloon_available_kib'] as num?)?.toInt(),
      balloonUnusedKib: (json['balloon_unused_kib'] as num?)?.toInt(),
      blocks:
          (json['blocks'] as List<dynamic>?)
              ?.map(
                (e) => LibvirtBlockStats.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <LibvirtBlockStats>[],
      nets:
          (json['nets'] as List<dynamic>?)
              ?.map((e) => LibvirtNetStats.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LibvirtNetStats>[],
    );

Map<String, dynamic> _$LibvirtCountersToJson(_LibvirtCounters instance) =>
    <String, dynamic>{
      'cpu_time_ns': instance.cpuTimeNs,
      'balloon_rss_kib': instance.balloonRssKib,
      'balloon_available_kib': instance.balloonAvailableKib,
      'balloon_unused_kib': instance.balloonUnusedKib,
      'blocks': instance.blocks,
      'nets': instance.nets,
    };

_LibvirtDomain _$LibvirtDomainFromJson(Map<String, dynamic> json) =>
    _LibvirtDomain(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      state: json['state'] as String,
      stateCode: (json['state_code'] as num?)?.toInt() ?? -1,
      reasonCode: (json['reason_code'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String? ?? 'unknown',
      autostart: json['autostart'] as bool? ?? false,
      persistent: json['persistent'] as bool? ?? false,
      vcpuCurrent: (json['vcpu_current'] as num?)?.toInt(),
      vcpuMax: (json['vcpu_max'] as num?)?.toInt(),
      memCurrentKib: (json['mem_current_kib'] as num?)?.toInt(),
      memMaxKib: (json['mem_max_kib'] as num?)?.toInt(),
      counters: json['counters'] == null
          ? const LibvirtCounters()
          : LibvirtCounters.fromJson(json['counters'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LibvirtDomainToJson(_LibvirtDomain instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'name': instance.name,
      'state': instance.state,
      'state_code': instance.stateCode,
      'reason_code': instance.reasonCode,
      'reason': instance.reason,
      'autostart': instance.autostart,
      'persistent': instance.persistent,
      'vcpu_current': instance.vcpuCurrent,
      'vcpu_max': instance.vcpuMax,
      'mem_current_kib': instance.memCurrentKib,
      'mem_max_kib': instance.memMaxKib,
      'counters': instance.counters,
    };

_LibvirtOverview _$LibvirtOverviewFromJson(Map<String, dynamic> json) =>
    _LibvirtOverview(
      version: json['version'] == null
          ? null
          : LibvirtVersion.fromJson(json['version'] as Map<String, dynamic>),
      domains:
          (json['domains'] as List<dynamic>?)
              ?.map((e) => LibvirtDomain.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LibvirtDomain>[],
    );

Map<String, dynamic> _$LibvirtOverviewToJson(_LibvirtOverview instance) =>
    <String, dynamic>{'version': instance.version, 'domains': instance.domains};

_LibvirtDomainXml _$LibvirtDomainXmlFromJson(Map<String, dynamic> json) =>
    _LibvirtDomainXml(
      name: json['name'] as String?,
      uuid: json['uuid'] as String?,
      description: json['description'] as String?,
      arch: json['arch'] as String?,
      machine: json['machine'] as String?,
      disks:
          (json['disks'] as List<dynamic>?)
              ?.map((e) => VirtDisk.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <VirtDisk>[],
      nics:
          (json['nics'] as List<dynamic>?)
              ?.map((e) => VirtNic.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <VirtNic>[],
      graphics:
          (json['graphics'] as List<dynamic>?)
              ?.map((e) => VirtGraphics.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <VirtGraphics>[],
      hasSerialConsole: json['has_serial_console'] as bool? ?? false,
    );

Map<String, dynamic> _$LibvirtDomainXmlToJson(_LibvirtDomainXml instance) =>
    <String, dynamic>{
      'name': instance.name,
      'uuid': instance.uuid,
      'description': instance.description,
      'arch': instance.arch,
      'machine': instance.machine,
      'disks': instance.disks,
      'nics': instance.nics,
      'graphics': instance.graphics,
      'has_serial_console': instance.hasSerialConsole,
    };

_LibvirtDomainDetail _$LibvirtDomainDetailFromJson(Map<String, dynamic> json) =>
    _LibvirtDomainDetail(
      display: json['display'] == null
          ? null
          : VirtDisplay.fromJson(json['display'] as Map<String, dynamic>),
      xml: json['xml'] == null
          ? const LibvirtDomainXml()
          : LibvirtDomainXml.fromJson(json['xml'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LibvirtDomainDetailToJson(
  _LibvirtDomainDetail instance,
) => <String, dynamic>{'display': instance.display, 'xml': instance.xml};

_LibvirtSnapshot _$LibvirtSnapshotFromJson(Map<String, dynamic> json) =>
    _LibvirtSnapshot(
      name: json['name'] as String,
      description: json['description'] as String?,
      parent: json['parent'] as String?,
      state: json['state'] as String?,
      creationTime: (json['creation_time'] as num?)?.toInt(),
      memory: json['memory'] as bool? ?? false,
      external: json['external'] as bool? ?? false,
      current: json['current'] as bool? ?? false,
    );

Map<String, dynamic> _$LibvirtSnapshotToJson(_LibvirtSnapshot instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'parent': instance.parent,
      'state': instance.state,
      'creation_time': instance.creationTime,
      'memory': instance.memory,
      'external': instance.external,
      'current': instance.current,
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

_LibvirtVolume _$LibvirtVolumeFromJson(Map<String, dynamic> json) =>
    _LibvirtVolume(
      name: json['name'] as String,
      volType: json['vol_type'] as String?,
      path: json['path'] as String?,
      format: json['format'] as String?,
      capacity: (json['capacity'] as num?)?.toInt(),
      allocation: (json['allocation'] as num?)?.toInt(),
      backing: json['backing'] as String?,
    );

Map<String, dynamic> _$LibvirtVolumeToJson(_LibvirtVolume instance) =>
    <String, dynamic>{
      'name': instance.name,
      'vol_type': instance.volType,
      'path': instance.path,
      'format': instance.format,
      'capacity': instance.capacity,
      'allocation': instance.allocation,
      'backing': instance.backing,
    };

_LibvirtNetIp _$LibvirtNetIpFromJson(Map<String, dynamic> json) =>
    _LibvirtNetIp(
      family: json['family'] as String? ?? 'ipv4',
      cidr: json['cidr'] as String,
      dhcpRanges:
          (json['dhcp_ranges'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$LibvirtNetIpToJson(_LibvirtNetIp instance) =>
    <String, dynamic>{
      'family': instance.family,
      'cidr': instance.cidr,
      'dhcp_ranges': instance.dhcpRanges,
    };

_LibvirtNetwork _$LibvirtNetworkFromJson(Map<String, dynamic> json) =>
    _LibvirtNetwork(
      name: json['name'] as String,
      uuid: json['uuid'] as String?,
      active: json['active'] as bool? ?? false,
      autostart: json['autostart'] as bool? ?? false,
      mode: json['mode'] as String? ?? 'isolated',
      bridge: json['bridge'] as String?,
      forwardDevs:
          (json['forward_devs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      ips:
          (json['ips'] as List<dynamic>?)
              ?.map((e) => LibvirtNetIp.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LibvirtNetIp>[],
      connections: (json['connections'] as num?)?.toInt(),
    );

Map<String, dynamic> _$LibvirtNetworkToJson(_LibvirtNetwork instance) =>
    <String, dynamic>{
      'name': instance.name,
      'uuid': instance.uuid,
      'active': instance.active,
      'autostart': instance.autostart,
      'mode': instance.mode,
      'bridge': instance.bridge,
      'forward_devs': instance.forwardDevs,
      'ips': instance.ips,
      'connections': instance.connections,
    };

_LibvirtIfaceUse _$LibvirtIfaceUseFromJson(Map<String, dynamic> json) =>
    _LibvirtIfaceUse(
      domain: json['domain'] as String,
      interface: json['interface'] as String?,
      kind: json['kind'] as String? ?? '',
      source: json['source'] as String?,
      model: json['model'] as String?,
      mac: json['mac'] as String?,
    );

Map<String, dynamic> _$LibvirtIfaceUseToJson(_LibvirtIfaceUse instance) =>
    <String, dynamic>{
      'domain': instance.domain,
      'interface': instance.interface,
      'kind': instance.kind,
      'source': instance.source,
      'model': instance.model,
      'mac': instance.mac,
    };

_LibvirtLease _$LibvirtLeaseFromJson(Map<String, dynamic> json) =>
    _LibvirtLease(
      network: json['network'] as String,
      mac: json['mac'] as String,
      ip: json['ip'] as String,
      hostname: json['hostname'] as String?,
    );

Map<String, dynamic> _$LibvirtLeaseToJson(_LibvirtLease instance) =>
    <String, dynamic>{
      'network': instance.network,
      'mac': instance.mac,
      'ip': instance.ip,
      'hostname': instance.hostname,
    };

_LibvirtNetworks _$LibvirtNetworksFromJson(Map<String, dynamic> json) =>
    _LibvirtNetworks(
      networks:
          (json['networks'] as List<dynamic>?)
              ?.map((e) => LibvirtNetwork.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LibvirtNetwork>[],
      ifaces:
          (json['ifaces'] as List<dynamic>?)
              ?.map((e) => LibvirtIfaceUse.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LibvirtIfaceUse>[],
      leases:
          (json['leases'] as List<dynamic>?)
              ?.map((e) => LibvirtLease.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LibvirtLease>[],
    );

Map<String, dynamic> _$LibvirtNetworksToJson(_LibvirtNetworks instance) =>
    <String, dynamic>{
      'networks': instance.networks,
      'ifaces': instance.ifaces,
      'leases': instance.leases,
    };

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
    };

_LibvirtHardwareInfo _$LibvirtHardwareInfoFromJson(Map<String, dynamic> json) =>
    _LibvirtHardwareInfo(
      config: LibvirtHwConfig.fromJson(json['config'] as Map<String, dynamic>),
      live: json['live'] == null
          ? null
          : LibvirtHwConfig.fromJson(json['live'] as Map<String, dynamic>),
      configXml: json['config_xml'] as String,
      autostart: json['autostart'] as bool? ?? false,
      description: json['description'] as String?,
      hostCpus: (json['host_cpus'] as num?)?.toInt(),
      hostMemoryKib: (json['host_memory_kib'] as num?)?.toInt(),
    );

Map<String, dynamic> _$LibvirtHardwareInfoToJson(
  _LibvirtHardwareInfo instance,
) => <String, dynamic>{
  'config': instance.config,
  'live': instance.live,
  'config_xml': instance.configXml,
  'autostart': instance.autostart,
  'description': instance.description,
  'host_cpus': instance.hostCpus,
  'host_memory_kib': instance.hostMemoryKib,
};
