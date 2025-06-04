import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'disk_smart.freezed.dart';
part 'disk_smart.g.dart';

@freezed
class DiskSmart with _$DiskSmart {
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

  factory DiskSmart.fromJson(Map<String, dynamic> json) => _$DiskSmartFromJson(json);

  static List<DiskSmart> parse(String raw) {
    final results = <DiskSmart>[];

    final jsonBlocks = raw.split('\n\n').where((s) => s.trim().isNotEmpty);

    for (final jsonStr in jsonBlocks) {
      try {
        final data = json.decode(jsonStr.trim()) as Map<String, dynamic>;

        // Basic
        final device = data['device']?['name']?.toString() ?? '';
        final healthy = data['smart_status']?['passed'] as bool?;

        // Model and Serial
        final model =
            data['model_name']?.toString() ??
            data['model_family']?.toString() ??
            data['device']?['model_name']?.toString();
        final serial = data['serial_number']?.toString() ?? data['device']?['serial_number']?.toString();

        // SMART Attrs
        final smartAttributes = _parseSmartAttributes(data);
        final temperature = _extractTemperature(data, smartAttributes);
        final powerOnHours =
            data['power_on_time']?['hours'] as int? ?? smartAttributes['Power_On_Hours']?.rawValue as int?;
        final powerCycleCount =
            data['power_cycle_count'] as int? ?? smartAttributes['Power_Cycle_Count']?.rawValue as int?;

        results.add(
          DiskSmart(
            device: device,
            healthy: healthy,
            temperature: temperature,
            model: model,
            serial: serial,
            powerOnHours: powerOnHours,
            powerCycleCount: powerCycleCount,
            rawData: data,
            smartAttributes: smartAttributes,
          ),
        );
      } catch (e, s) {
        Loggers.app.warning('DiskSmart parse', e, s);
      }
    }
    return results;
  }

  static Map<String, SmartAttribute> _parseSmartAttributes(Map<String, dynamic> data) {
    final attributes = <String, SmartAttribute>{};

    final attrTable = data['ata_smart_attributes']?['table'] as List?;
    if (attrTable == null) return attributes;

    for (final attr in attrTable) {
      if (attr is Map<String, dynamic>) {
        final name = attr['name']?.toString();
        if (name != null) {
          attributes[name] = SmartAttribute(
            id: attr['id'] as int?,
            name: name,
            value: attr['value'] as int?,
            worst: attr['worst'] as int?,
            thresh: attr['thresh'] as int?,
            whenFailed: attr['when_failed']?.toString(),
            rawValue: attr['raw']?['value'],
            rawString: attr['raw']?['string']?.toString(),
            flags: SmartAttributeFlags.fromMap(attr['flags'] as Map<String, dynamic>? ?? {}),
          );
        }
      }
    }

    return attributes;
  }

  static final _tempReg = RegExp(r'^(\d+(?:\.\d+)?)');

  /// Extract temperature from the data
  static double? _extractTemperature(Map<String, dynamic> data, Map<String, SmartAttribute> attrs) {
    // Directly
    final directTemp = data['temperature']?['current'];
    if (directTemp is num) return directTemp.toDouble();

    // SMART attribute
    final tempAttr = attrs['Temperature_Celsius'];
    if (tempAttr != null) {
      // "35 (Min/Max 14/61)"
      final rawString = tempAttr.rawString;
      if (rawString != null) {
        final match = _tempReg.firstMatch(rawString);
        if (match != null) {
          return double.tryParse(match.group(1)!);
        }
      }

      // Simple numeric value
      if (tempAttr.rawValue is num && tempAttr.rawValue! < 150) {
        return tempAttr.rawValue!.toDouble();
      }
    }

    return null;
  }

  /// Get the specific SMART attribute by name
  SmartAttribute? getAttribute(String name) => smartAttributes[name];

  int? get ssdLifeLeft => smartAttributes['SSD_Life_Left']?.rawValue as int?;
  int? get lifetimeWritesGiB => smartAttributes['Lifetime_Writes_GiB']?.rawValue as int?;
  int? get lifetimeReadsGiB => smartAttributes['Lifetime_Reads_GiB']?.rawValue as int?;
  int? get unsafeShutdownCount => smartAttributes['Unsafe_Shutdown_Count']?.rawValue as int?;
  int? get averageEraseCount => smartAttributes['Average_Erase_Count']?.rawValue as int?;
  int? get maxEraseCount => smartAttributes['Max_Erase_Count']?.rawValue as int?;

  @override
  String toString() => 'DiskSmart($device)';
}

@freezed
class SmartAttribute with _$SmartAttribute {
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

  factory SmartAttribute.fromJson(Map<String, dynamic> json) => _$SmartAttributeFromJson(json);

  @override
  String toString() {
    return 'SmartAttribute(id: $id, name: $name)';
  }
}

@freezed
class SmartAttributeFlags with _$SmartAttributeFlags {
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

  factory SmartAttributeFlags.fromJson(Map<String, dynamic> json) => _$SmartAttributeFlagsFromJson(json);

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
