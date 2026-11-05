// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerCustom _$ServerCustomFromJson(Map<String, dynamic> json) => ServerCustom(
  preferTempDev: json['preferTempDev'] as String?,
  tempIsCelsius: json['tempIsCelsius'] as bool? ?? false,
  logoUrl: json['logoUrl'] as String?,
  netDev: json['netDev'] as String?,
  scriptDir: json['scriptDir'] as String?,
  geo: GeoCoord.tryFromJson(json['geo']),
  diskCountsNetwork: json['diskCountsNetwork'] as bool? ?? false,
);

Map<String, dynamic> _$ServerCustomToJson(ServerCustom instance) =>
    <String, dynamic>{
      'preferTempDev': ?instance.preferTempDev,
      'tempIsCelsius': instance.tempIsCelsius,
      'logoUrl': ?instance.logoUrl,
      'netDev': ?instance.netDev,
      'scriptDir': ?instance.scriptDir,
      'geo': ?GeoCoord.encode(instance.geo),
      'diskCountsNetwork': instance.diskCountsNetwork,
    };
