// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'virt.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VirtNode _$VirtNodeFromJson(Map<String, dynamic> json) => _VirtNode(
  name: json['name'] as String,
  online: json['online'] as bool? ?? true,
  cpu: (json['cpu'] as num?)?.toDouble(),
  maxCpu: (json['maxCpu'] as num?)?.toInt(),
  memUsed: (json['memUsed'] as num?)?.toInt(),
  memTotal: (json['memTotal'] as num?)?.toInt(),
  uptime: json['uptime'] == null
      ? null
      : Duration(microseconds: (json['uptime'] as num).toInt()),
);

Map<String, dynamic> _$VirtNodeToJson(_VirtNode instance) => <String, dynamic>{
  'name': instance.name,
  'online': instance.online,
  'cpu': instance.cpu,
  'maxCpu': instance.maxCpu,
  'memUsed': instance.memUsed,
  'memTotal': instance.memTotal,
  'uptime': instance.uptime?.inMicroseconds,
};

_VirtHost _$VirtHostFromJson(Map<String, dynamic> json) => _VirtHost(
  serverId: json['serverId'] as String,
  kind: $enumDecode(_$VirtHostKindEnumMap, json['kind']),
  version: json['version'] as String?,
  hypervisor: json['hypervisor'] as String?,
  nodes:
      (json['nodes'] as List<dynamic>?)
          ?.map((e) => VirtNode.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <VirtNode>[],
);

Map<String, dynamic> _$VirtHostToJson(_VirtHost instance) => <String, dynamic>{
  'serverId': instance.serverId,
  'kind': _$VirtHostKindEnumMap[instance.kind]!,
  'version': instance.version,
  'hypervisor': instance.hypervisor,
  'nodes': instance.nodes,
};

const _$VirtHostKindEnumMap = {
  VirtHostKind.pve: 'pve',
  VirtHostKind.libvirt: 'libvirt',
};

_VirtGuest _$VirtGuestFromJson(Map<String, dynamic> json) => _VirtGuest(
  id: json['id'] as String,
  name: json['name'] as String,
  kind: $enumDecode(_$VirtGuestKindEnumMap, json['kind']),
  state: $enumDecode(_$VirtGuestStateEnumMap, json['state']),
  stateReason: json['stateReason'] as String?,
  vmid: (json['vmid'] as num?)?.toInt(),
  node: json['node'] as String?,
  vcpu: (json['vcpu'] as num?)?.toInt(),
  memBytes: (json['memBytes'] as num?)?.toInt(),
  uptime: json['uptime'] == null
      ? null
      : Duration(microseconds: (json['uptime'] as num).toInt()),
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  template: json['template'] as bool? ?? false,
  autostart: json['autostart'] as bool?,
  actions:
      (json['actions'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$VirtPowerActionEnumMap, e))
          .toSet() ??
      const <VirtPowerAction>{},
);

Map<String, dynamic> _$VirtGuestToJson(
  _VirtGuest instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'kind': _$VirtGuestKindEnumMap[instance.kind]!,
  'state': _$VirtGuestStateEnumMap[instance.state]!,
  'stateReason': instance.stateReason,
  'vmid': instance.vmid,
  'node': instance.node,
  'vcpu': instance.vcpu,
  'memBytes': instance.memBytes,
  'uptime': instance.uptime?.inMicroseconds,
  'tags': instance.tags,
  'template': instance.template,
  'autostart': instance.autostart,
  'actions': instance.actions.map((e) => _$VirtPowerActionEnumMap[e]!).toList(),
};

const _$VirtGuestKindEnumMap = {
  VirtGuestKind.qemu: 'qemu',
  VirtGuestKind.lxc: 'lxc',
};

const _$VirtGuestStateEnumMap = {
  VirtGuestState.running: 'running',
  VirtGuestState.paused: 'paused',
  VirtGuestState.stopped: 'stopped',
  VirtGuestState.starting: 'starting',
  VirtGuestState.stopping: 'stopping',
  VirtGuestState.rebooting: 'rebooting',
  VirtGuestState.migrating: 'migrating',
  VirtGuestState.backup: 'backup',
  VirtGuestState.unknown: 'unknown',
};

const _$VirtPowerActionEnumMap = {
  VirtPowerAction.start: 'start',
  VirtPowerAction.shutdown: 'shutdown',
  VirtPowerAction.reboot: 'reboot',
  VirtPowerAction.forceStop: 'forceStop',
  VirtPowerAction.suspend: 'suspend',
  VirtPowerAction.resume: 'resume',
};

_VirtStats _$VirtStatsFromJson(Map<String, dynamic> json) => _VirtStats(
  at: DateTime.parse(json['at'] as String),
  cpu: (json['cpu'] as num?)?.toDouble(),
  memUsed: (json['memUsed'] as num?)?.toInt(),
  memTotal: (json['memTotal'] as num?)?.toInt(),
  diskUsed: (json['diskUsed'] as num?)?.toInt(),
  diskTotal: (json['diskTotal'] as num?)?.toInt(),
  diskRead: (json['diskRead'] as num?)?.toDouble(),
  diskWrite: (json['diskWrite'] as num?)?.toDouble(),
  netIn: (json['netIn'] as num?)?.toDouble(),
  netOut: (json['netOut'] as num?)?.toDouble(),
);

Map<String, dynamic> _$VirtStatsToJson(_VirtStats instance) =>
    <String, dynamic>{
      'at': instance.at.toIso8601String(),
      'cpu': instance.cpu,
      'memUsed': instance.memUsed,
      'memTotal': instance.memTotal,
      'diskUsed': instance.diskUsed,
      'diskTotal': instance.diskTotal,
      'diskRead': instance.diskRead,
      'diskWrite': instance.diskWrite,
      'netIn': instance.netIn,
      'netOut': instance.netOut,
    };

_VirtCapabilities _$VirtCapabilitiesFromJson(Map<String, dynamic> json) =>
    _VirtCapabilities(
      lxc: json['lxc'] as bool? ?? false,
      pause: json['pause'] as bool? ?? false,
      snapshots: json['snapshots'] as bool? ?? false,
      snapshotMemoryRequired: json['snapshotMemoryRequired'] as bool? ?? false,
      storage: json['storage'] as bool? ?? false,
      network: json['network'] as bool? ?? false,
      backup: json['backup'] as bool? ?? false,
      clone: json['clone'] as bool? ?? false,
      linkedClone: json['linkedClone'] as bool? ?? false,
      cluster: json['cluster'] as bool? ?? false,
      serialConsole: json['serialConsole'] as bool? ?? false,
      vncConsole: json['vncConsole'] as bool? ?? false,
      termConsole: json['termConsole'] as bool? ?? false,
      storedHistory: json['storedHistory'] as bool? ?? false,
      create: json['create'] as bool? ?? false,
      deleteKeepsDisks: json['deleteKeepsDisks'] as bool? ?? false,
      hardware: json['hardware'] as bool? ?? false,
      hardwareRevert: json['hardwareRevert'] as bool? ?? false,
    );

Map<String, dynamic> _$VirtCapabilitiesToJson(_VirtCapabilities instance) =>
    <String, dynamic>{
      'lxc': instance.lxc,
      'pause': instance.pause,
      'snapshots': instance.snapshots,
      'snapshotMemoryRequired': instance.snapshotMemoryRequired,
      'storage': instance.storage,
      'network': instance.network,
      'backup': instance.backup,
      'clone': instance.clone,
      'linkedClone': instance.linkedClone,
      'cluster': instance.cluster,
      'serialConsole': instance.serialConsole,
      'vncConsole': instance.vncConsole,
      'termConsole': instance.termConsole,
      'storedHistory': instance.storedHistory,
      'create': instance.create,
      'deleteKeepsDisks': instance.deleteKeepsDisks,
      'hardware': instance.hardware,
      'hardwareRevert': instance.hardwareRevert,
    };
