// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'disk_smart.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DiskSmart _$DiskSmartFromJson(Map<String, dynamic> json) => _DiskSmart(
  device: json['device'] as String,
  healthy: json['healthy'] as bool?,
  temperature: (json['temperature'] as num?)?.toDouble(),
  model: json['model'] as String?,
  serial: json['serial'] as String?,
  powerOnHours: (json['powerOnHours'] as num?)?.toInt(),
  powerCycleCount: (json['powerCycleCount'] as num?)?.toInt(),
  rawData: json['rawData'] as Map<String, dynamic>,
  smartAttributes: (json['smartAttributes'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, SmartAttribute.fromJson(e as Map<String, dynamic>)),
  ),
);

Map<String, dynamic> _$DiskSmartToJson(_DiskSmart instance) =>
    <String, dynamic>{
      'device': instance.device,
      'healthy': instance.healthy,
      'temperature': instance.temperature,
      'model': instance.model,
      'serial': instance.serial,
      'powerOnHours': instance.powerOnHours,
      'powerCycleCount': instance.powerCycleCount,
      'rawData': instance.rawData,
      'smartAttributes': instance.smartAttributes,
    };

_SmartAttribute _$SmartAttributeFromJson(Map<String, dynamic> json) =>
    _SmartAttribute(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String,
      value: (json['value'] as num?)?.toInt(),
      worst: (json['worst'] as num?)?.toInt(),
      thresh: (json['thresh'] as num?)?.toInt(),
      whenFailed: json['whenFailed'] as String?,
      rawValue: json['rawValue'],
      rawString: json['rawString'] as String?,
      flags: SmartAttributeFlags.fromJson(
        json['flags'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$SmartAttributeToJson(_SmartAttribute instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'value': instance.value,
      'worst': instance.worst,
      'thresh': instance.thresh,
      'whenFailed': instance.whenFailed,
      'rawValue': instance.rawValue,
      'rawString': instance.rawString,
      'flags': instance.flags,
    };

_SmartAttributeFlags _$SmartAttributeFlagsFromJson(Map<String, dynamic> json) =>
    _SmartAttributeFlags(
      value: (json['value'] as num?)?.toInt(),
      string: json['string'] as String?,
      prefailure: json['prefailure'] as bool? ?? false,
      updatedOnline: json['updatedOnline'] as bool? ?? false,
      performance: json['performance'] as bool? ?? false,
      errorRate: json['errorRate'] as bool? ?? false,
      eventCount: json['eventCount'] as bool? ?? false,
      autoKeep: json['autoKeep'] as bool? ?? false,
    );

Map<String, dynamic> _$SmartAttributeFlagsToJson(
  _SmartAttributeFlags instance,
) => <String, dynamic>{
  'value': instance.value,
  'string': instance.string,
  'prefailure': instance.prefailure,
  'updatedOnline': instance.updatedOnline,
  'performance': instance.performance,
  'errorRate': instance.errorRate,
  'eventCount': instance.eventCount,
  'autoKeep': instance.autoKeep,
};
