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
