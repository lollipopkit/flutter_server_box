// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'yabs_options.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_YabsOptions _$YabsOptionsFromJson(Map<String, dynamic> json) => _YabsOptions(
  disk: json['disk'] as bool? ?? true,
  network: json['network'] as bool? ?? true,
  reducedNetwork: json['reducedNetwork'] as bool? ?? true,
  cpu: json['cpu'] as bool? ?? false,
  geekbenchVersion:
      $enumDecodeNullable(
        _$GeekbenchVersionEnumMap,
        json['geekbenchVersion'],
      ) ??
      GeekbenchVersion.v6,
  ipInfo: json['ipInfo'] as bool? ?? false,
  preferPrecompiledBinaries:
      json['preferPrecompiledBinaries'] as bool? ?? false,
  workDir: json['workDir'] as String? ?? '',
);

Map<String, dynamic> _$YabsOptionsToJson(_YabsOptions instance) =>
    <String, dynamic>{
      'disk': instance.disk,
      'network': instance.network,
      'reducedNetwork': instance.reducedNetwork,
      'cpu': instance.cpu,
      'geekbenchVersion': _$GeekbenchVersionEnumMap[instance.geekbenchVersion]!,
      'ipInfo': instance.ipInfo,
      'preferPrecompiledBinaries': instance.preferPrecompiledBinaries,
      'workDir': instance.workDir,
    };

const _$GeekbenchVersionEnumMap = {
  GeekbenchVersion.v4: 'v4',
  GeekbenchVersion.v5: 'v5',
  GeekbenchVersion.v6: 'v6',
  GeekbenchVersion.v7: 'v7',
};
