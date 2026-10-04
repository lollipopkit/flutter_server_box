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
