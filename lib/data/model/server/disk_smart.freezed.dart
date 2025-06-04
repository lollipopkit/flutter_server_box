// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'disk_smart.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DiskSmart _$DiskSmartFromJson(Map<String, dynamic> json) {
  return _DiskSmart.fromJson(json);
}

/// @nodoc
mixin _$DiskSmart {
  String get device => throw _privateConstructorUsedError;
  bool? get healthy => throw _privateConstructorUsedError;
  double? get temperature => throw _privateConstructorUsedError;
  String? get model => throw _privateConstructorUsedError;
  String? get serial => throw _privateConstructorUsedError;
  int? get powerOnHours => throw _privateConstructorUsedError;
  int? get powerCycleCount => throw _privateConstructorUsedError;
  Map<String, dynamic> get rawData => throw _privateConstructorUsedError;
  Map<String, SmartAttribute> get smartAttributes =>
      throw _privateConstructorUsedError;

  /// Serializes this DiskSmart to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DiskSmart
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DiskSmartCopyWith<DiskSmart> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DiskSmartCopyWith<$Res> {
  factory $DiskSmartCopyWith(DiskSmart value, $Res Function(DiskSmart) then) =
      _$DiskSmartCopyWithImpl<$Res, DiskSmart>;
  @useResult
  $Res call({
    String device,
    bool? healthy,
    double? temperature,
    String? model,
    String? serial,
    int? powerOnHours,
    int? powerCycleCount,
    Map<String, dynamic> rawData,
    Map<String, SmartAttribute> smartAttributes,
  });
}

/// @nodoc
class _$DiskSmartCopyWithImpl<$Res, $Val extends DiskSmart>
    implements $DiskSmartCopyWith<$Res> {
  _$DiskSmartCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DiskSmart
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? device = null,
    Object? healthy = freezed,
    Object? temperature = freezed,
    Object? model = freezed,
    Object? serial = freezed,
    Object? powerOnHours = freezed,
    Object? powerCycleCount = freezed,
    Object? rawData = null,
    Object? smartAttributes = null,
  }) {
    return _then(
      _value.copyWith(
            device: null == device
                ? _value.device
                : device // ignore: cast_nullable_to_non_nullable
                      as String,
            healthy: freezed == healthy
                ? _value.healthy
                : healthy // ignore: cast_nullable_to_non_nullable
                      as bool?,
            temperature: freezed == temperature
                ? _value.temperature
                : temperature // ignore: cast_nullable_to_non_nullable
                      as double?,
            model: freezed == model
                ? _value.model
                : model // ignore: cast_nullable_to_non_nullable
                      as String?,
            serial: freezed == serial
                ? _value.serial
                : serial // ignore: cast_nullable_to_non_nullable
                      as String?,
            powerOnHours: freezed == powerOnHours
                ? _value.powerOnHours
                : powerOnHours // ignore: cast_nullable_to_non_nullable
                      as int?,
            powerCycleCount: freezed == powerCycleCount
                ? _value.powerCycleCount
                : powerCycleCount // ignore: cast_nullable_to_non_nullable
                      as int?,
            rawData: null == rawData
                ? _value.rawData
                : rawData // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            smartAttributes: null == smartAttributes
                ? _value.smartAttributes
                : smartAttributes // ignore: cast_nullable_to_non_nullable
                      as Map<String, SmartAttribute>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DiskSmartImplCopyWith<$Res>
    implements $DiskSmartCopyWith<$Res> {
  factory _$$DiskSmartImplCopyWith(
    _$DiskSmartImpl value,
    $Res Function(_$DiskSmartImpl) then,
  ) = __$$DiskSmartImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String device,
    bool? healthy,
    double? temperature,
    String? model,
    String? serial,
    int? powerOnHours,
    int? powerCycleCount,
    Map<String, dynamic> rawData,
    Map<String, SmartAttribute> smartAttributes,
  });
}

/// @nodoc
class __$$DiskSmartImplCopyWithImpl<$Res>
    extends _$DiskSmartCopyWithImpl<$Res, _$DiskSmartImpl>
    implements _$$DiskSmartImplCopyWith<$Res> {
  __$$DiskSmartImplCopyWithImpl(
    _$DiskSmartImpl _value,
    $Res Function(_$DiskSmartImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DiskSmart
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? device = null,
    Object? healthy = freezed,
    Object? temperature = freezed,
    Object? model = freezed,
    Object? serial = freezed,
    Object? powerOnHours = freezed,
    Object? powerCycleCount = freezed,
    Object? rawData = null,
    Object? smartAttributes = null,
  }) {
    return _then(
      _$DiskSmartImpl(
        device: null == device
            ? _value.device
            : device // ignore: cast_nullable_to_non_nullable
                  as String,
        healthy: freezed == healthy
            ? _value.healthy
            : healthy // ignore: cast_nullable_to_non_nullable
                  as bool?,
        temperature: freezed == temperature
            ? _value.temperature
            : temperature // ignore: cast_nullable_to_non_nullable
                  as double?,
        model: freezed == model
            ? _value.model
            : model // ignore: cast_nullable_to_non_nullable
                  as String?,
        serial: freezed == serial
            ? _value.serial
            : serial // ignore: cast_nullable_to_non_nullable
                  as String?,
        powerOnHours: freezed == powerOnHours
            ? _value.powerOnHours
            : powerOnHours // ignore: cast_nullable_to_non_nullable
                  as int?,
        powerCycleCount: freezed == powerCycleCount
            ? _value.powerCycleCount
            : powerCycleCount // ignore: cast_nullable_to_non_nullable
                  as int?,
        rawData: null == rawData
            ? _value._rawData
            : rawData // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        smartAttributes: null == smartAttributes
            ? _value._smartAttributes
            : smartAttributes // ignore: cast_nullable_to_non_nullable
                  as Map<String, SmartAttribute>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DiskSmartImpl extends _DiskSmart {
  const _$DiskSmartImpl({
    required this.device,
    this.healthy,
    this.temperature,
    this.model,
    this.serial,
    this.powerOnHours,
    this.powerCycleCount,
    required final Map<String, dynamic> rawData,
    required final Map<String, SmartAttribute> smartAttributes,
  }) : _rawData = rawData,
       _smartAttributes = smartAttributes,
       super._();

  factory _$DiskSmartImpl.fromJson(Map<String, dynamic> json) =>
      _$$DiskSmartImplFromJson(json);

  @override
  final String device;
  @override
  final bool? healthy;
  @override
  final double? temperature;
  @override
  final String? model;
  @override
  final String? serial;
  @override
  final int? powerOnHours;
  @override
  final int? powerCycleCount;
  final Map<String, dynamic> _rawData;
  @override
  Map<String, dynamic> get rawData {
    if (_rawData is EqualUnmodifiableMapView) return _rawData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_rawData);
  }

  final Map<String, SmartAttribute> _smartAttributes;
  @override
  Map<String, SmartAttribute> get smartAttributes {
    if (_smartAttributes is EqualUnmodifiableMapView) return _smartAttributes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_smartAttributes);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DiskSmartImpl &&
            (identical(other.device, device) || other.device == device) &&
            (identical(other.healthy, healthy) || other.healthy == healthy) &&
            (identical(other.temperature, temperature) ||
                other.temperature == temperature) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.serial, serial) || other.serial == serial) &&
            (identical(other.powerOnHours, powerOnHours) ||
                other.powerOnHours == powerOnHours) &&
            (identical(other.powerCycleCount, powerCycleCount) ||
                other.powerCycleCount == powerCycleCount) &&
            const DeepCollectionEquality().equals(other._rawData, _rawData) &&
            const DeepCollectionEquality().equals(
              other._smartAttributes,
              _smartAttributes,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    device,
    healthy,
    temperature,
    model,
    serial,
    powerOnHours,
    powerCycleCount,
    const DeepCollectionEquality().hash(_rawData),
    const DeepCollectionEquality().hash(_smartAttributes),
  );

  /// Create a copy of DiskSmart
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DiskSmartImplCopyWith<_$DiskSmartImpl> get copyWith =>
      __$$DiskSmartImplCopyWithImpl<_$DiskSmartImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DiskSmartImplToJson(this);
  }
}

abstract class _DiskSmart extends DiskSmart {
  const factory _DiskSmart({
    required final String device,
    final bool? healthy,
    final double? temperature,
    final String? model,
    final String? serial,
    final int? powerOnHours,
    final int? powerCycleCount,
    required final Map<String, dynamic> rawData,
    required final Map<String, SmartAttribute> smartAttributes,
  }) = _$DiskSmartImpl;
  const _DiskSmart._() : super._();

  factory _DiskSmart.fromJson(Map<String, dynamic> json) =
      _$DiskSmartImpl.fromJson;

  @override
  String get device;
  @override
  bool? get healthy;
  @override
  double? get temperature;
  @override
  String? get model;
  @override
  String? get serial;
  @override
  int? get powerOnHours;
  @override
  int? get powerCycleCount;
  @override
  Map<String, dynamic> get rawData;
  @override
  Map<String, SmartAttribute> get smartAttributes;

  /// Create a copy of DiskSmart
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DiskSmartImplCopyWith<_$DiskSmartImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SmartAttribute _$SmartAttributeFromJson(Map<String, dynamic> json) {
  return _SmartAttribute.fromJson(json);
}

/// @nodoc
mixin _$SmartAttribute {
  int? get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int? get value => throw _privateConstructorUsedError;
  int? get worst => throw _privateConstructorUsedError;
  int? get thresh => throw _privateConstructorUsedError;
  String? get whenFailed => throw _privateConstructorUsedError;
  dynamic get rawValue => throw _privateConstructorUsedError;
  String? get rawString => throw _privateConstructorUsedError;
  SmartAttributeFlags get flags => throw _privateConstructorUsedError;

  /// Serializes this SmartAttribute to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SmartAttribute
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SmartAttributeCopyWith<SmartAttribute> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SmartAttributeCopyWith<$Res> {
  factory $SmartAttributeCopyWith(
    SmartAttribute value,
    $Res Function(SmartAttribute) then,
  ) = _$SmartAttributeCopyWithImpl<$Res, SmartAttribute>;
  @useResult
  $Res call({
    int? id,
    String name,
    int? value,
    int? worst,
    int? thresh,
    String? whenFailed,
    dynamic rawValue,
    String? rawString,
    SmartAttributeFlags flags,
  });

  $SmartAttributeFlagsCopyWith<$Res> get flags;
}

/// @nodoc
class _$SmartAttributeCopyWithImpl<$Res, $Val extends SmartAttribute>
    implements $SmartAttributeCopyWith<$Res> {
  _$SmartAttributeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SmartAttribute
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = null,
    Object? value = freezed,
    Object? worst = freezed,
    Object? thresh = freezed,
    Object? whenFailed = freezed,
    Object? rawValue = freezed,
    Object? rawString = freezed,
    Object? flags = null,
  }) {
    return _then(
      _value.copyWith(
            id: freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int?,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            value: freezed == value
                ? _value.value
                : value // ignore: cast_nullable_to_non_nullable
                      as int?,
            worst: freezed == worst
                ? _value.worst
                : worst // ignore: cast_nullable_to_non_nullable
                      as int?,
            thresh: freezed == thresh
                ? _value.thresh
                : thresh // ignore: cast_nullable_to_non_nullable
                      as int?,
            whenFailed: freezed == whenFailed
                ? _value.whenFailed
                : whenFailed // ignore: cast_nullable_to_non_nullable
                      as String?,
            rawValue: freezed == rawValue
                ? _value.rawValue
                : rawValue // ignore: cast_nullable_to_non_nullable
                      as dynamic,
            rawString: freezed == rawString
                ? _value.rawString
                : rawString // ignore: cast_nullable_to_non_nullable
                      as String?,
            flags: null == flags
                ? _value.flags
                : flags // ignore: cast_nullable_to_non_nullable
                      as SmartAttributeFlags,
          )
          as $Val,
    );
  }

  /// Create a copy of SmartAttribute
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SmartAttributeFlagsCopyWith<$Res> get flags {
    return $SmartAttributeFlagsCopyWith<$Res>(_value.flags, (value) {
      return _then(_value.copyWith(flags: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SmartAttributeImplCopyWith<$Res>
    implements $SmartAttributeCopyWith<$Res> {
  factory _$$SmartAttributeImplCopyWith(
    _$SmartAttributeImpl value,
    $Res Function(_$SmartAttributeImpl) then,
  ) = __$$SmartAttributeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? id,
    String name,
    int? value,
    int? worst,
    int? thresh,
    String? whenFailed,
    dynamic rawValue,
    String? rawString,
    SmartAttributeFlags flags,
  });

  @override
  $SmartAttributeFlagsCopyWith<$Res> get flags;
}

/// @nodoc
class __$$SmartAttributeImplCopyWithImpl<$Res>
    extends _$SmartAttributeCopyWithImpl<$Res, _$SmartAttributeImpl>
    implements _$$SmartAttributeImplCopyWith<$Res> {
  __$$SmartAttributeImplCopyWithImpl(
    _$SmartAttributeImpl _value,
    $Res Function(_$SmartAttributeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SmartAttribute
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = null,
    Object? value = freezed,
    Object? worst = freezed,
    Object? thresh = freezed,
    Object? whenFailed = freezed,
    Object? rawValue = freezed,
    Object? rawString = freezed,
    Object? flags = null,
  }) {
    return _then(
      _$SmartAttributeImpl(
        id: freezed == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int?,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        value: freezed == value
            ? _value.value
            : value // ignore: cast_nullable_to_non_nullable
                  as int?,
        worst: freezed == worst
            ? _value.worst
            : worst // ignore: cast_nullable_to_non_nullable
                  as int?,
        thresh: freezed == thresh
            ? _value.thresh
            : thresh // ignore: cast_nullable_to_non_nullable
                  as int?,
        whenFailed: freezed == whenFailed
            ? _value.whenFailed
            : whenFailed // ignore: cast_nullable_to_non_nullable
                  as String?,
        rawValue: freezed == rawValue
            ? _value.rawValue
            : rawValue // ignore: cast_nullable_to_non_nullable
                  as dynamic,
        rawString: freezed == rawString
            ? _value.rawString
            : rawString // ignore: cast_nullable_to_non_nullable
                  as String?,
        flags: null == flags
            ? _value.flags
            : flags // ignore: cast_nullable_to_non_nullable
                  as SmartAttributeFlags,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SmartAttributeImpl extends _SmartAttribute {
  const _$SmartAttributeImpl({
    this.id,
    required this.name,
    this.value,
    this.worst,
    this.thresh,
    this.whenFailed,
    this.rawValue,
    this.rawString,
    required this.flags,
  }) : super._();

  factory _$SmartAttributeImpl.fromJson(Map<String, dynamic> json) =>
      _$$SmartAttributeImplFromJson(json);

  @override
  final int? id;
  @override
  final String name;
  @override
  final int? value;
  @override
  final int? worst;
  @override
  final int? thresh;
  @override
  final String? whenFailed;
  @override
  final dynamic rawValue;
  @override
  final String? rawString;
  @override
  final SmartAttributeFlags flags;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SmartAttributeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.worst, worst) || other.worst == worst) &&
            (identical(other.thresh, thresh) || other.thresh == thresh) &&
            (identical(other.whenFailed, whenFailed) ||
                other.whenFailed == whenFailed) &&
            const DeepCollectionEquality().equals(other.rawValue, rawValue) &&
            (identical(other.rawString, rawString) ||
                other.rawString == rawString) &&
            (identical(other.flags, flags) || other.flags == flags));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    value,
    worst,
    thresh,
    whenFailed,
    const DeepCollectionEquality().hash(rawValue),
    rawString,
    flags,
  );

  /// Create a copy of SmartAttribute
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SmartAttributeImplCopyWith<_$SmartAttributeImpl> get copyWith =>
      __$$SmartAttributeImplCopyWithImpl<_$SmartAttributeImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SmartAttributeImplToJson(this);
  }
}

abstract class _SmartAttribute extends SmartAttribute {
  const factory _SmartAttribute({
    final int? id,
    required final String name,
    final int? value,
    final int? worst,
    final int? thresh,
    final String? whenFailed,
    final dynamic rawValue,
    final String? rawString,
    required final SmartAttributeFlags flags,
  }) = _$SmartAttributeImpl;
  const _SmartAttribute._() : super._();

  factory _SmartAttribute.fromJson(Map<String, dynamic> json) =
      _$SmartAttributeImpl.fromJson;

  @override
  int? get id;
  @override
  String get name;
  @override
  int? get value;
  @override
  int? get worst;
  @override
  int? get thresh;
  @override
  String? get whenFailed;
  @override
  dynamic get rawValue;
  @override
  String? get rawString;
  @override
  SmartAttributeFlags get flags;

  /// Create a copy of SmartAttribute
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SmartAttributeImplCopyWith<_$SmartAttributeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SmartAttributeFlags _$SmartAttributeFlagsFromJson(Map<String, dynamic> json) {
  return _SmartAttributeFlags.fromJson(json);
}

/// @nodoc
mixin _$SmartAttributeFlags {
  int? get value => throw _privateConstructorUsedError;
  String? get string => throw _privateConstructorUsedError;
  bool get prefailure => throw _privateConstructorUsedError;
  bool get updatedOnline => throw _privateConstructorUsedError;
  bool get performance => throw _privateConstructorUsedError;
  bool get errorRate => throw _privateConstructorUsedError;
  bool get eventCount => throw _privateConstructorUsedError;
  bool get autoKeep => throw _privateConstructorUsedError;

  /// Serializes this SmartAttributeFlags to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SmartAttributeFlags
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SmartAttributeFlagsCopyWith<SmartAttributeFlags> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SmartAttributeFlagsCopyWith<$Res> {
  factory $SmartAttributeFlagsCopyWith(
    SmartAttributeFlags value,
    $Res Function(SmartAttributeFlags) then,
  ) = _$SmartAttributeFlagsCopyWithImpl<$Res, SmartAttributeFlags>;
  @useResult
  $Res call({
    int? value,
    String? string,
    bool prefailure,
    bool updatedOnline,
    bool performance,
    bool errorRate,
    bool eventCount,
    bool autoKeep,
  });
}

/// @nodoc
class _$SmartAttributeFlagsCopyWithImpl<$Res, $Val extends SmartAttributeFlags>
    implements $SmartAttributeFlagsCopyWith<$Res> {
  _$SmartAttributeFlagsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SmartAttributeFlags
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? value = freezed,
    Object? string = freezed,
    Object? prefailure = null,
    Object? updatedOnline = null,
    Object? performance = null,
    Object? errorRate = null,
    Object? eventCount = null,
    Object? autoKeep = null,
  }) {
    return _then(
      _value.copyWith(
            value: freezed == value
                ? _value.value
                : value // ignore: cast_nullable_to_non_nullable
                      as int?,
            string: freezed == string
                ? _value.string
                : string // ignore: cast_nullable_to_non_nullable
                      as String?,
            prefailure: null == prefailure
                ? _value.prefailure
                : prefailure // ignore: cast_nullable_to_non_nullable
                      as bool,
            updatedOnline: null == updatedOnline
                ? _value.updatedOnline
                : updatedOnline // ignore: cast_nullable_to_non_nullable
                      as bool,
            performance: null == performance
                ? _value.performance
                : performance // ignore: cast_nullable_to_non_nullable
                      as bool,
            errorRate: null == errorRate
                ? _value.errorRate
                : errorRate // ignore: cast_nullable_to_non_nullable
                      as bool,
            eventCount: null == eventCount
                ? _value.eventCount
                : eventCount // ignore: cast_nullable_to_non_nullable
                      as bool,
            autoKeep: null == autoKeep
                ? _value.autoKeep
                : autoKeep // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SmartAttributeFlagsImplCopyWith<$Res>
    implements $SmartAttributeFlagsCopyWith<$Res> {
  factory _$$SmartAttributeFlagsImplCopyWith(
    _$SmartAttributeFlagsImpl value,
    $Res Function(_$SmartAttributeFlagsImpl) then,
  ) = __$$SmartAttributeFlagsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? value,
    String? string,
    bool prefailure,
    bool updatedOnline,
    bool performance,
    bool errorRate,
    bool eventCount,
    bool autoKeep,
  });
}

/// @nodoc
class __$$SmartAttributeFlagsImplCopyWithImpl<$Res>
    extends _$SmartAttributeFlagsCopyWithImpl<$Res, _$SmartAttributeFlagsImpl>
    implements _$$SmartAttributeFlagsImplCopyWith<$Res> {
  __$$SmartAttributeFlagsImplCopyWithImpl(
    _$SmartAttributeFlagsImpl _value,
    $Res Function(_$SmartAttributeFlagsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SmartAttributeFlags
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? value = freezed,
    Object? string = freezed,
    Object? prefailure = null,
    Object? updatedOnline = null,
    Object? performance = null,
    Object? errorRate = null,
    Object? eventCount = null,
    Object? autoKeep = null,
  }) {
    return _then(
      _$SmartAttributeFlagsImpl(
        value: freezed == value
            ? _value.value
            : value // ignore: cast_nullable_to_non_nullable
                  as int?,
        string: freezed == string
            ? _value.string
            : string // ignore: cast_nullable_to_non_nullable
                  as String?,
        prefailure: null == prefailure
            ? _value.prefailure
            : prefailure // ignore: cast_nullable_to_non_nullable
                  as bool,
        updatedOnline: null == updatedOnline
            ? _value.updatedOnline
            : updatedOnline // ignore: cast_nullable_to_non_nullable
                  as bool,
        performance: null == performance
            ? _value.performance
            : performance // ignore: cast_nullable_to_non_nullable
                  as bool,
        errorRate: null == errorRate
            ? _value.errorRate
            : errorRate // ignore: cast_nullable_to_non_nullable
                  as bool,
        eventCount: null == eventCount
            ? _value.eventCount
            : eventCount // ignore: cast_nullable_to_non_nullable
                  as bool,
        autoKeep: null == autoKeep
            ? _value.autoKeep
            : autoKeep // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SmartAttributeFlagsImpl extends _SmartAttributeFlags {
  const _$SmartAttributeFlagsImpl({
    this.value,
    this.string,
    this.prefailure = false,
    this.updatedOnline = false,
    this.performance = false,
    this.errorRate = false,
    this.eventCount = false,
    this.autoKeep = false,
  }) : super._();

  factory _$SmartAttributeFlagsImpl.fromJson(Map<String, dynamic> json) =>
      _$$SmartAttributeFlagsImplFromJson(json);

  @override
  final int? value;
  @override
  final String? string;
  @override
  @JsonKey()
  final bool prefailure;
  @override
  @JsonKey()
  final bool updatedOnline;
  @override
  @JsonKey()
  final bool performance;
  @override
  @JsonKey()
  final bool errorRate;
  @override
  @JsonKey()
  final bool eventCount;
  @override
  @JsonKey()
  final bool autoKeep;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SmartAttributeFlagsImpl &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.string, string) || other.string == string) &&
            (identical(other.prefailure, prefailure) ||
                other.prefailure == prefailure) &&
            (identical(other.updatedOnline, updatedOnline) ||
                other.updatedOnline == updatedOnline) &&
            (identical(other.performance, performance) ||
                other.performance == performance) &&
            (identical(other.errorRate, errorRate) ||
                other.errorRate == errorRate) &&
            (identical(other.eventCount, eventCount) ||
                other.eventCount == eventCount) &&
            (identical(other.autoKeep, autoKeep) ||
                other.autoKeep == autoKeep));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    value,
    string,
    prefailure,
    updatedOnline,
    performance,
    errorRate,
    eventCount,
    autoKeep,
  );

  /// Create a copy of SmartAttributeFlags
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SmartAttributeFlagsImplCopyWith<_$SmartAttributeFlagsImpl> get copyWith =>
      __$$SmartAttributeFlagsImplCopyWithImpl<_$SmartAttributeFlagsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SmartAttributeFlagsImplToJson(this);
  }
}

abstract class _SmartAttributeFlags extends SmartAttributeFlags {
  const factory _SmartAttributeFlags({
    final int? value,
    final String? string,
    final bool prefailure,
    final bool updatedOnline,
    final bool performance,
    final bool errorRate,
    final bool eventCount,
    final bool autoKeep,
  }) = _$SmartAttributeFlagsImpl;
  const _SmartAttributeFlags._() : super._();

  factory _SmartAttributeFlags.fromJson(Map<String, dynamic> json) =
      _$SmartAttributeFlagsImpl.fromJson;

  @override
  int? get value;
  @override
  String? get string;
  @override
  bool get prefailure;
  @override
  bool get updatedOnline;
  @override
  bool get performance;
  @override
  bool get errorRate;
  @override
  bool get eventCount;
  @override
  bool get autoKeep;

  /// Create a copy of SmartAttributeFlags
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SmartAttributeFlagsImplCopyWith<_$SmartAttributeFlagsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
