// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_desktop.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RemoteDesktopProfile _$RemoteDesktopProfileFromJson(
  Map<String, dynamic> json,
) => _RemoteDesktopProfile(
  id: json['id'] as String,
  serverId: json['serverId'] as String,
  name: json['name'] as String,
  protocol: $enumDecode(_$RemoteDesktopProtocolEnumMap, json['protocol']),
  host: json['host'] as String? ?? '127.0.0.1',
  port: (json['port'] as num).toInt(),
  username: json['username'] as String?,
  password: json['password'] as String?,
  domain: json['domain'] as String?,
  viewOnly: json['viewOnly'] as bool? ?? false,
  shared: json['shared'] as bool? ?? true,
  trustedCertSha256: json['trustedCertSha256'] as String?,
);

Map<String, dynamic> _$RemoteDesktopProfileToJson(
  _RemoteDesktopProfile instance,
) => <String, dynamic>{
  'id': instance.id,
  'serverId': instance.serverId,
  'name': instance.name,
  'protocol': _$RemoteDesktopProtocolEnumMap[instance.protocol]!,
  'host': instance.host,
  'port': instance.port,
  'username': instance.username,
  'password': instance.password,
  'domain': instance.domain,
  'viewOnly': instance.viewOnly,
  'shared': instance.shared,
  'trustedCertSha256': instance.trustedCertSha256,
};

const _$RemoteDesktopProtocolEnumMap = {
  RemoteDesktopProtocol.rdp: 'rdp',
  RemoteDesktopProtocol.vnc: 'vnc',
};
