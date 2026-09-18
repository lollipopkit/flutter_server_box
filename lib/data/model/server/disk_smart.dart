
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

  /// The counts a drive is judged on beyond [healthy], worst first, each with
  /// the word a row uses and the name the attribute sheet lists it under.
  ///
  /// SMART's own verdict stays PASSED until a drive is nearly gone: one with
  /// reallocated sectors answers PASSED and is the one to replace. Every one
  /// of these should be zero, and the first non-zero one is what a card says
  /// instead of "PASSED".
  ///
  /// The words are smartctl's, spelled out — they are the terms the attribute
  /// tables and every disk forum use, and translating them would leave the
  /// reading and its name in different vocabularies.
  static const criticalAttributes = <String, ({String short, String label})>{
    'Reallocated_Sector_Ct': (
      short: 'reallocated',
      label: 'Reallocated sectors',
    ),
    'Current_Pending_Sector': (short: 'pending', label: 'Pending sectors'),
    'Offline_Uncorrectable': (
      short: 'uncorrectable',
      label: 'Offline uncorrectable',
    ),
    'UDMA_CRC_Error_Count': (short: 'CRC errors', label: 'CRC errors'),
  };

  /// Which of [criticalAttributes] this drive reports above zero, in that
  /// order. Empty on a healthy drive and on one that reports none of them.
  Map<String, int> get faults {
    final out = <String, int>{};
    for (final entry in criticalAttributes.entries) {
      final count = countOf(smartAttributes[entry.key]?.rawValue);
      if (count != null && count > 0) out[entry.value.short] = count;
    }
    return out;
  }

  /// A raw value as the count it is, or null when it is not one.
  ///
  /// `rawValue` is whatever the vendor put in the field and whatever the
  /// transport made of it: an `int` over SSH, a JSON number that decoded as a
  /// `double` through the agent, a string on a drive that spells its raw
  /// values out. A whole number in any of those shapes is the same count, and
  /// `2.5` is not a count of sectors at all.
  static int? countOf(dynamic raw) => switch (raw) {
    final int v => v,
    final num v when v == v.roundToDouble() => v.toInt(),
    final String s => int.tryParse(s.trim()),
    _ => null,
  };

  /// Whether smartctl had nothing to say about this device — a RAID set or a
  /// mapper target, which has no SMART data rather than bad SMART data.
  bool get notApplicable => healthy == null && smartAttributes.isEmpty;

  int? get ssdLifeLeft => countOf(smartAttributes['SSD_Life_Left']?.rawValue);
  int? get lifetimeWritesGiB =>
      countOf(smartAttributes['Lifetime_Writes_GiB']?.rawValue);
  int? get lifetimeReadsGiB =>
      countOf(smartAttributes['Lifetime_Reads_GiB']?.rawValue);
  int? get unsafeShutdownCount =>
      countOf(smartAttributes['Unsafe_Shutdown_Count']?.rawValue);
  int? get averageEraseCount =>
      countOf(smartAttributes['Average_Erase_Count']?.rawValue);

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
