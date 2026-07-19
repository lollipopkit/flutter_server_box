
import 'package:freezed_annotation/freezed_annotation.dart';

part 'disk_smart.freezed.dart';
part 'disk_smart.g.dart';

@freezed
abstract class DiskSmart with _$DiskSmart {
  const DiskSmart._();

  const factory DiskSmart({
    required String device,
    bool? healthy,
    double? temperature,
    String? model,
    String? serial,
    int? powerOnHours,
    int? powerCycleCount,
    required Map<String, dynamic> rawData,
    required Map<String, SmartAttribute> smartAttributes,
  }) = _DiskSmart;

  factory DiskSmart.fromJson(Map<String, dynamic> json) =>
      _$DiskSmartFromJson(json);

  // Parsing implementation migrated to the shared Rust library sbm_parser

  /// Get the specific SMART attribute by name
  SmartAttribute? getAttribute(String name) => smartAttributes[name];

  int? get ssdLifeLeft => smartAttributes['SSD_Life_Left']?.rawValue as int?;
  int? get lifetimeWritesGiB =>
      smartAttributes['Lifetime_Writes_GiB']?.rawValue as int?;
  int? get lifetimeReadsGiB =>
      smartAttributes['Lifetime_Reads_GiB']?.rawValue as int?;
  int? get unsafeShutdownCount =>
      smartAttributes['Unsafe_Shutdown_Count']?.rawValue as int?;
  int? get averageEraseCount =>
      smartAttributes['Average_Erase_Count']?.rawValue as int?;

  @override
  String toString() => 'DiskSmart($device)';
}

@freezed
abstract class SmartAttribute with _$SmartAttribute {
  const SmartAttribute._();

  const factory SmartAttribute({
    int? id,
    required String name,
    int? value,
    int? worst,
    int? thresh,
    String? whenFailed,
    dynamic rawValue,
    String? rawString,
    required SmartAttributeFlags flags,
  }) = _SmartAttribute;

  factory SmartAttribute.fromJson(Map<String, dynamic> json) =>
      _$SmartAttributeFromJson(json);

  @override
  String toString() {
    return 'SmartAttribute(id: $id, name: $name)';
  }
}

@freezed
abstract class SmartAttributeFlags with _$SmartAttributeFlags {
  const SmartAttributeFlags._();

  const factory SmartAttributeFlags({
    int? value,
    String? string,
    @Default(false) bool prefailure,
    @Default(false) bool updatedOnline,
    @Default(false) bool performance,
    @Default(false) bool errorRate,
    @Default(false) bool eventCount,
    @Default(false) bool autoKeep,
  }) = _SmartAttributeFlags;

  factory SmartAttributeFlags.fromJson(Map<String, dynamic> json) =>
      _$SmartAttributeFlagsFromJson(json);

  factory SmartAttributeFlags.fromMap(Map<String, dynamic> map) {
    return SmartAttributeFlags(
      value: map['value'] as int?,
      string: map['string']?.toString(),
      prefailure: map['prefailure'] == true,
      updatedOnline: map['updated_online'] == true,
      performance: map['performance'] == true,
      errorRate: map['error_rate'] == true,
      eventCount: map['event_count'] == true,
      autoKeep: map['auto_keep'] == true,
    );
  }

  @override
  String toString() {
    return 'SmartAttributeFlags(value: $value, string: $string)';
  }
}
