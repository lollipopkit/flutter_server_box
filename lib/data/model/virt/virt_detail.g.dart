// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'virt_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VirtDisk _$VirtDiskFromJson(Map<String, dynamic> json) => _VirtDisk(
  device: json['device'] as String? ?? 'disk',
  sourceType: json['source_type'] as String?,
  source: json['source'] as String?,
  target: json['target'] as String?,
  bus: json['bus'] as String?,
  format: json['format'] as String?,
  readonly: json['readonly'] as bool? ?? false,
  size: (json['size'] as num?)?.toInt(),
);

Map<String, dynamic> _$VirtDiskToJson(_VirtDisk instance) => <String, dynamic>{
  'device': instance.device,
  'source_type': instance.sourceType,
  'source': instance.source,
  'target': instance.target,
  'bus': instance.bus,
  'format': instance.format,
  'readonly': instance.readonly,
  'size': instance.size,
};

_VirtNic _$VirtNicFromJson(Map<String, dynamic> json) => _VirtNic(
  kind: json['kind'] as String? ?? '',
  mac: json['mac'] as String?,
  source: json['source'] as String?,
  model: json['model'] as String?,
  target: json['target'] as String?,
);

Map<String, dynamic> _$VirtNicToJson(_VirtNic instance) => <String, dynamic>{
  'kind': instance.kind,
  'mac': instance.mac,
  'source': instance.source,
  'model': instance.model,
  'target': instance.target,
};

_VirtGraphics _$VirtGraphicsFromJson(Map<String, dynamic> json) =>
    _VirtGraphics(
      kind: json['kind'] as String? ?? '',
      port: (json['port'] as num?)?.toInt(),
      tlsPort: (json['tls_port'] as num?)?.toInt(),
      autoport: json['autoport'] as bool? ?? false,
      listen: json['listen'] as String?,
      socket: json['socket'] as String?,
    );

Map<String, dynamic> _$VirtGraphicsToJson(_VirtGraphics instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'port': instance.port,
      'tls_port': instance.tlsPort,
      'autoport': instance.autoport,
      'listen': instance.listen,
      'socket': instance.socket,
    };

_VirtDisplay _$VirtDisplayFromJson(Map<String, dynamic> json) => _VirtDisplay(
  uri: json['uri'] as String,
  protocol: json['protocol'] as String,
  host: json['host'] as String?,
  port: (json['port'] as num?)?.toInt(),
  tlsPort: (json['tls_port'] as num?)?.toInt(),
  socket: json['socket'] as String?,
);

Map<String, dynamic> _$VirtDisplayToJson(_VirtDisplay instance) =>
    <String, dynamic>{
      'uri': instance.uri,
      'protocol': instance.protocol,
      'host': instance.host,
      'port': instance.port,
      'tls_port': instance.tlsPort,
      'socket': instance.socket,
    };

_VirtGuestDetail _$VirtGuestDetailFromJson(Map<String, dynamic> json) =>
    _VirtGuestDetail(
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
      display: json['display'] == null
          ? null
          : VirtDisplay.fromJson(json['display'] as Map<String, dynamic>),
      consoles:
          (json['consoles'] as List<dynamic>?)
              ?.map((e) => $enumDecode(_$VirtConsoleKindEnumMap, e))
              .toSet() ??
          const <VirtConsoleKind>{},
      description: json['description'] as String?,
      arch: json['arch'] as String?,
      machine: json['machine'] as String?,
    );

Map<String, dynamic> _$VirtGuestDetailToJson(_VirtGuestDetail instance) =>
    <String, dynamic>{
      'disks': instance.disks,
      'nics': instance.nics,
      'graphics': instance.graphics,
      'display': instance.display,
      'consoles': instance.consoles
          .map((e) => _$VirtConsoleKindEnumMap[e]!)
          .toList(),
      'description': instance.description,
      'arch': instance.arch,
      'machine': instance.machine,
    };

const _$VirtConsoleKindEnumMap = {
  VirtConsoleKind.text: 'text',
  VirtConsoleKind.vnc: 'vnc',
};
