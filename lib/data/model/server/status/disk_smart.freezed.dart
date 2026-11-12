// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'disk_smart.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DiskSmart {

 String get device; bool? get healthy; double? get temperature; String? get model; String? get serial; int? get powerOnHours; int? get powerCycleCount; Map<String, SmartAttribute> get smartAttributes;
/// Create a copy of DiskSmart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiskSmartCopyWith<DiskSmart> get copyWith => _$DiskSmartCopyWithImpl<DiskSmart>(this as DiskSmart, _$identity);

  /// Serializes this DiskSmart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DiskSmart;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiskSmart&&(identical(other.device, _this.device) || other.device == _this.device)&&(identical(other.healthy, _this.healthy) || other.healthy == _this.healthy)&&(identical(other.temperature, _this.temperature) || other.temperature == _this.temperature)&&(identical(other.model, _this.model) || other.model == _this.model)&&(identical(other.serial, _this.serial) || other.serial == _this.serial)&&(identical(other.powerOnHours, _this.powerOnHours) || other.powerOnHours == _this.powerOnHours)&&(identical(other.powerCycleCount, _this.powerCycleCount) || other.powerCycleCount == _this.powerCycleCount)&&const DeepCollectionEquality().equals(other.smartAttributes, _this.smartAttributes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DiskSmart;
  return Object.hash(runtimeType,_this.device,_this.healthy,_this.temperature,_this.model,_this.serial,_this.powerOnHours,_this.powerCycleCount,const DeepCollectionEquality().hash(_this.smartAttributes));
}



}

/// @nodoc
abstract mixin class $DiskSmartCopyWith<$Res>  {
  factory $DiskSmartCopyWith(DiskSmart value, $Res Function(DiskSmart) _then) = _$DiskSmartCopyWithImpl;
@useResult
$Res call({
 String device, bool? healthy, double? temperature, String? model, String? serial, int? powerOnHours, int? powerCycleCount, Map<String, SmartAttribute> smartAttributes
});




}
/// @nodoc
class _$DiskSmartCopyWithImpl<$Res>
    implements $DiskSmartCopyWith<$Res> {
  _$DiskSmartCopyWithImpl(this._self, this._then);

  final DiskSmart _self;
  final $Res Function(DiskSmart) _then;

/// Create a copy of DiskSmart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? device = null,Object? healthy = freezed,Object? temperature = freezed,Object? model = freezed,Object? serial = freezed,Object? powerOnHours = freezed,Object? powerCycleCount = freezed,Object? smartAttributes = null,}) {
  return _then(DiskSmart(
device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,healthy: freezed == healthy ? _self.healthy : healthy // ignore: cast_nullable_to_non_nullable
as bool?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,serial: freezed == serial ? _self.serial : serial // ignore: cast_nullable_to_non_nullable
as String?,powerOnHours: freezed == powerOnHours ? _self.powerOnHours : powerOnHours // ignore: cast_nullable_to_non_nullable
as int?,powerCycleCount: freezed == powerCycleCount ? _self.powerCycleCount : powerCycleCount // ignore: cast_nullable_to_non_nullable
as int?,smartAttributes: null == smartAttributes ? _self.smartAttributes : smartAttributes // ignore: cast_nullable_to_non_nullable
as Map<String, SmartAttribute>,
  ));
}

}


/// Adds pattern-matching-related methods to [DiskSmart].
extension DiskSmartPatterns on DiskSmart {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiskSmart value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiskSmart() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiskSmart value)  $default,){
final _that = this;
switch (_that) {
case _DiskSmart():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiskSmart value)?  $default,){
final _that = this;
switch (_that) {
case _DiskSmart() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String device,  bool? healthy,  double? temperature,  String? model,  String? serial,  int? powerOnHours,  int? powerCycleCount,  Map<String, SmartAttribute> smartAttributes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiskSmart() when $default != null:
return $default(_that.device,_that.healthy,_that.temperature,_that.model,_that.serial,_that.powerOnHours,_that.powerCycleCount,_that.smartAttributes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String device,  bool? healthy,  double? temperature,  String? model,  String? serial,  int? powerOnHours,  int? powerCycleCount,  Map<String, SmartAttribute> smartAttributes)  $default,) {final _that = this;
switch (_that) {
case _DiskSmart():
return $default(_that.device,_that.healthy,_that.temperature,_that.model,_that.serial,_that.powerOnHours,_that.powerCycleCount,_that.smartAttributes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String device,  bool? healthy,  double? temperature,  String? model,  String? serial,  int? powerOnHours,  int? powerCycleCount,  Map<String, SmartAttribute> smartAttributes)?  $default,) {final _that = this;
switch (_that) {
case _DiskSmart() when $default != null:
return $default(_that.device,_that.healthy,_that.temperature,_that.model,_that.serial,_that.powerOnHours,_that.powerCycleCount,_that.smartAttributes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DiskSmart extends DiskSmart {
  const _DiskSmart({required this.device, this.healthy, this.temperature, this.model, this.serial, this.powerOnHours, this.powerCycleCount, required  Map<String, SmartAttribute> smartAttributes}): _smartAttributes = smartAttributes,super._();
  factory _DiskSmart.fromJson(Map<String, dynamic> json) => _$DiskSmartFromJson(json);

@override final  String device;
@override final  bool? healthy;
@override final  double? temperature;
@override final  String? model;
@override final  String? serial;
@override final  int? powerOnHours;
@override final  int? powerCycleCount;
 final  Map<String, SmartAttribute> _smartAttributes;
@override Map<String, SmartAttribute> get smartAttributes {
  if (_smartAttributes is EqualUnmodifiableMapView) return _smartAttributes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_smartAttributes);
}


/// Create a copy of DiskSmart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiskSmartCopyWith<_DiskSmart> get copyWith => __$DiskSmartCopyWithImpl<_DiskSmart>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DiskSmartToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiskSmart&&(identical(other.device, device) || other.device == device)&&(identical(other.healthy, healthy) || other.healthy == healthy)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.model, model) || other.model == model)&&(identical(other.serial, serial) || other.serial == serial)&&(identical(other.powerOnHours, powerOnHours) || other.powerOnHours == powerOnHours)&&(identical(other.powerCycleCount, powerCycleCount) || other.powerCycleCount == powerCycleCount)&&const DeepCollectionEquality().equals(other.smartAttributes, _smartAttributes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,device,healthy,temperature,model,serial,powerOnHours,powerCycleCount,const DeepCollectionEquality().hash(_smartAttributes));
}



}

/// @nodoc
abstract mixin class _$DiskSmartCopyWith<$Res> implements $DiskSmartCopyWith<$Res> {
  factory _$DiskSmartCopyWith(_DiskSmart value, $Res Function(_DiskSmart) _then) = __$DiskSmartCopyWithImpl;
@override @useResult
$Res call({
 String device, bool? healthy, double? temperature, String? model, String? serial, int? powerOnHours, int? powerCycleCount, Map<String, SmartAttribute> smartAttributes
});




}
/// @nodoc
class __$DiskSmartCopyWithImpl<$Res>
    implements _$DiskSmartCopyWith<$Res> {
  __$DiskSmartCopyWithImpl(this._self, this._then);

  final _DiskSmart _self;
  final $Res Function(_DiskSmart) _then;

/// Create a copy of DiskSmart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? device = null,Object? healthy = freezed,Object? temperature = freezed,Object? model = freezed,Object? serial = freezed,Object? powerOnHours = freezed,Object? powerCycleCount = freezed,Object? smartAttributes = null,}) {
  return _then(_DiskSmart(
device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,healthy: freezed == healthy ? _self.healthy : healthy // ignore: cast_nullable_to_non_nullable
as bool?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,serial: freezed == serial ? _self.serial : serial // ignore: cast_nullable_to_non_nullable
as String?,powerOnHours: freezed == powerOnHours ? _self.powerOnHours : powerOnHours // ignore: cast_nullable_to_non_nullable
as int?,powerCycleCount: freezed == powerCycleCount ? _self.powerCycleCount : powerCycleCount // ignore: cast_nullable_to_non_nullable
as int?,smartAttributes: null == smartAttributes ? _self._smartAttributes : smartAttributes // ignore: cast_nullable_to_non_nullable
as Map<String, SmartAttribute>,
  ));
}


}


/// @nodoc
mixin _$SmartAttribute {

 int? get id; String get name; int? get value; int? get worst; int? get thresh; String? get whenFailed; dynamic get rawValue; String? get rawString; SmartAttributeFlags get flags;
/// Create a copy of SmartAttribute
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SmartAttributeCopyWith<SmartAttribute> get copyWith => _$SmartAttributeCopyWithImpl<SmartAttribute>(this as SmartAttribute, _$identity);

  /// Serializes this SmartAttribute to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SmartAttribute;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SmartAttribute&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.value, _this.value) || other.value == _this.value)&&(identical(other.worst, _this.worst) || other.worst == _this.worst)&&(identical(other.thresh, _this.thresh) || other.thresh == _this.thresh)&&(identical(other.whenFailed, _this.whenFailed) || other.whenFailed == _this.whenFailed)&&const DeepCollectionEquality().equals(other.rawValue, _this.rawValue)&&(identical(other.rawString, _this.rawString) || other.rawString == _this.rawString)&&(identical(other.flags, _this.flags) || other.flags == _this.flags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SmartAttribute;
  return Object.hash(runtimeType,_this.id,_this.name,_this.value,_this.worst,_this.thresh,_this.whenFailed,const DeepCollectionEquality().hash(_this.rawValue),_this.rawString,_this.flags);
}



}

/// @nodoc
abstract mixin class $SmartAttributeCopyWith<$Res>  {
  factory $SmartAttributeCopyWith(SmartAttribute value, $Res Function(SmartAttribute) _then) = _$SmartAttributeCopyWithImpl;
@useResult
$Res call({
 int? id, String name, int? value, int? worst, int? thresh, String? whenFailed, dynamic rawValue, String? rawString, SmartAttributeFlags flags
});


$SmartAttributeFlagsCopyWith<$Res> get flags;

}
/// @nodoc
class _$SmartAttributeCopyWithImpl<$Res>
    implements $SmartAttributeCopyWith<$Res> {
  _$SmartAttributeCopyWithImpl(this._self, this._then);

  final SmartAttribute _self;
  final $Res Function(SmartAttribute) _then;

/// Create a copy of SmartAttribute
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? name = null,Object? value = freezed,Object? worst = freezed,Object? thresh = freezed,Object? whenFailed = freezed,Object? rawValue = freezed,Object? rawString = freezed,Object? flags = null,}) {
  return _then(SmartAttribute(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int?,worst: freezed == worst ? _self.worst : worst // ignore: cast_nullable_to_non_nullable
as int?,thresh: freezed == thresh ? _self.thresh : thresh // ignore: cast_nullable_to_non_nullable
as int?,whenFailed: freezed == whenFailed ? _self.whenFailed : whenFailed // ignore: cast_nullable_to_non_nullable
as String?,rawValue: freezed == rawValue ? _self.rawValue : rawValue // ignore: cast_nullable_to_non_nullable
as dynamic,rawString: freezed == rawString ? _self.rawString : rawString // ignore: cast_nullable_to_non_nullable
as String?,flags: null == flags ? _self.flags : flags // ignore: cast_nullable_to_non_nullable
as SmartAttributeFlags,
  ));
}
/// Create a copy of SmartAttribute
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SmartAttributeFlagsCopyWith<$Res> get flags {
  
  return $SmartAttributeFlagsCopyWith<$Res>(_self.flags, (value) {
    return _then(_self.copyWith(flags: value));
  });
}
}


/// Adds pattern-matching-related methods to [SmartAttribute].
extension SmartAttributePatterns on SmartAttribute {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SmartAttribute value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SmartAttribute() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SmartAttribute value)  $default,){
final _that = this;
switch (_that) {
case _SmartAttribute():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SmartAttribute value)?  $default,){
final _that = this;
switch (_that) {
case _SmartAttribute() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  String name,  int? value,  int? worst,  int? thresh,  String? whenFailed,  dynamic rawValue,  String? rawString,  SmartAttributeFlags flags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SmartAttribute() when $default != null:
return $default(_that.id,_that.name,_that.value,_that.worst,_that.thresh,_that.whenFailed,_that.rawValue,_that.rawString,_that.flags);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  String name,  int? value,  int? worst,  int? thresh,  String? whenFailed,  dynamic rawValue,  String? rawString,  SmartAttributeFlags flags)  $default,) {final _that = this;
switch (_that) {
case _SmartAttribute():
return $default(_that.id,_that.name,_that.value,_that.worst,_that.thresh,_that.whenFailed,_that.rawValue,_that.rawString,_that.flags);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  String name,  int? value,  int? worst,  int? thresh,  String? whenFailed,  dynamic rawValue,  String? rawString,  SmartAttributeFlags flags)?  $default,) {final _that = this;
switch (_that) {
case _SmartAttribute() when $default != null:
return $default(_that.id,_that.name,_that.value,_that.worst,_that.thresh,_that.whenFailed,_that.rawValue,_that.rawString,_that.flags);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SmartAttribute extends SmartAttribute {
  const _SmartAttribute({this.id, required this.name, this.value, this.worst, this.thresh, this.whenFailed, this.rawValue, this.rawString, required this.flags}): super._();
  factory _SmartAttribute.fromJson(Map<String, dynamic> json) => _$SmartAttributeFromJson(json);

@override final  int? id;
@override final  String name;
@override final  int? value;
@override final  int? worst;
@override final  int? thresh;
@override final  String? whenFailed;
@override final  dynamic rawValue;
@override final  String? rawString;
@override final  SmartAttributeFlags flags;

/// Create a copy of SmartAttribute
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SmartAttributeCopyWith<_SmartAttribute> get copyWith => __$SmartAttributeCopyWithImpl<_SmartAttribute>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SmartAttributeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SmartAttribute&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.value, value) || other.value == value)&&(identical(other.worst, worst) || other.worst == worst)&&(identical(other.thresh, thresh) || other.thresh == thresh)&&(identical(other.whenFailed, whenFailed) || other.whenFailed == whenFailed)&&const DeepCollectionEquality().equals(other.rawValue, rawValue)&&(identical(other.rawString, rawString) || other.rawString == rawString)&&(identical(other.flags, flags) || other.flags == flags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,value,worst,thresh,whenFailed,const DeepCollectionEquality().hash(rawValue),rawString,flags);
}



}

/// @nodoc
abstract mixin class _$SmartAttributeCopyWith<$Res> implements $SmartAttributeCopyWith<$Res> {
  factory _$SmartAttributeCopyWith(_SmartAttribute value, $Res Function(_SmartAttribute) _then) = __$SmartAttributeCopyWithImpl;
@override @useResult
$Res call({
 int? id, String name, int? value, int? worst, int? thresh, String? whenFailed, dynamic rawValue, String? rawString, SmartAttributeFlags flags
});


@override $SmartAttributeFlagsCopyWith<$Res> get flags;

}
/// @nodoc
class __$SmartAttributeCopyWithImpl<$Res>
    implements _$SmartAttributeCopyWith<$Res> {
  __$SmartAttributeCopyWithImpl(this._self, this._then);

  final _SmartAttribute _self;
  final $Res Function(_SmartAttribute) _then;

/// Create a copy of SmartAttribute
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? name = null,Object? value = freezed,Object? worst = freezed,Object? thresh = freezed,Object? whenFailed = freezed,Object? rawValue = freezed,Object? rawString = freezed,Object? flags = null,}) {
  return _then(_SmartAttribute(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int?,worst: freezed == worst ? _self.worst : worst // ignore: cast_nullable_to_non_nullable
as int?,thresh: freezed == thresh ? _self.thresh : thresh // ignore: cast_nullable_to_non_nullable
as int?,whenFailed: freezed == whenFailed ? _self.whenFailed : whenFailed // ignore: cast_nullable_to_non_nullable
as String?,rawValue: freezed == rawValue ? _self.rawValue : rawValue // ignore: cast_nullable_to_non_nullable
as dynamic,rawString: freezed == rawString ? _self.rawString : rawString // ignore: cast_nullable_to_non_nullable
as String?,flags: null == flags ? _self.flags : flags // ignore: cast_nullable_to_non_nullable
as SmartAttributeFlags,
  ));
}

/// Create a copy of SmartAttribute
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SmartAttributeFlagsCopyWith<$Res> get flags {
  
  return $SmartAttributeFlagsCopyWith<$Res>(_self.flags, (value) {
    return _then(_self.copyWith(flags: value));
  });
}
}


/// @nodoc
mixin _$SmartAttributeFlags {

 int? get value; String? get string; bool get prefailure; bool get updatedOnline; bool get performance; bool get errorRate; bool get eventCount; bool get autoKeep;
/// Create a copy of SmartAttributeFlags
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SmartAttributeFlagsCopyWith<SmartAttributeFlags> get copyWith => _$SmartAttributeFlagsCopyWithImpl<SmartAttributeFlags>(this as SmartAttributeFlags, _$identity);

  /// Serializes this SmartAttributeFlags to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SmartAttributeFlags;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SmartAttributeFlags&&(identical(other.value, _this.value) || other.value == _this.value)&&(identical(other.string, _this.string) || other.string == _this.string)&&(identical(other.prefailure, _this.prefailure) || other.prefailure == _this.prefailure)&&(identical(other.updatedOnline, _this.updatedOnline) || other.updatedOnline == _this.updatedOnline)&&(identical(other.performance, _this.performance) || other.performance == _this.performance)&&(identical(other.errorRate, _this.errorRate) || other.errorRate == _this.errorRate)&&(identical(other.eventCount, _this.eventCount) || other.eventCount == _this.eventCount)&&(identical(other.autoKeep, _this.autoKeep) || other.autoKeep == _this.autoKeep));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SmartAttributeFlags;
  return Object.hash(runtimeType,_this.value,_this.string,_this.prefailure,_this.updatedOnline,_this.performance,_this.errorRate,_this.eventCount,_this.autoKeep);
}



}

/// @nodoc
abstract mixin class $SmartAttributeFlagsCopyWith<$Res>  {
  factory $SmartAttributeFlagsCopyWith(SmartAttributeFlags value, $Res Function(SmartAttributeFlags) _then) = _$SmartAttributeFlagsCopyWithImpl;
@useResult
$Res call({
 int? value, String? string, bool prefailure, bool updatedOnline, bool performance, bool errorRate, bool eventCount, bool autoKeep
});




}
/// @nodoc
class _$SmartAttributeFlagsCopyWithImpl<$Res>
    implements $SmartAttributeFlagsCopyWith<$Res> {
  _$SmartAttributeFlagsCopyWithImpl(this._self, this._then);

  final SmartAttributeFlags _self;
  final $Res Function(SmartAttributeFlags) _then;

/// Create a copy of SmartAttributeFlags
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = freezed,Object? string = freezed,Object? prefailure = null,Object? updatedOnline = null,Object? performance = null,Object? errorRate = null,Object? eventCount = null,Object? autoKeep = null,}) {
  return _then(SmartAttributeFlags(
value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int?,string: freezed == string ? _self.string : string // ignore: cast_nullable_to_non_nullable
as String?,prefailure: null == prefailure ? _self.prefailure : prefailure // ignore: cast_nullable_to_non_nullable
as bool,updatedOnline: null == updatedOnline ? _self.updatedOnline : updatedOnline // ignore: cast_nullable_to_non_nullable
as bool,performance: null == performance ? _self.performance : performance // ignore: cast_nullable_to_non_nullable
as bool,errorRate: null == errorRate ? _self.errorRate : errorRate // ignore: cast_nullable_to_non_nullable
as bool,eventCount: null == eventCount ? _self.eventCount : eventCount // ignore: cast_nullable_to_non_nullable
as bool,autoKeep: null == autoKeep ? _self.autoKeep : autoKeep // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SmartAttributeFlags].
extension SmartAttributeFlagsPatterns on SmartAttributeFlags {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SmartAttributeFlags value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SmartAttributeFlags() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SmartAttributeFlags value)  $default,){
final _that = this;
switch (_that) {
case _SmartAttributeFlags():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SmartAttributeFlags value)?  $default,){
final _that = this;
switch (_that) {
case _SmartAttributeFlags() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? value,  String? string,  bool prefailure,  bool updatedOnline,  bool performance,  bool errorRate,  bool eventCount,  bool autoKeep)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SmartAttributeFlags() when $default != null:
return $default(_that.value,_that.string,_that.prefailure,_that.updatedOnline,_that.performance,_that.errorRate,_that.eventCount,_that.autoKeep);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? value,  String? string,  bool prefailure,  bool updatedOnline,  bool performance,  bool errorRate,  bool eventCount,  bool autoKeep)  $default,) {final _that = this;
switch (_that) {
case _SmartAttributeFlags():
return $default(_that.value,_that.string,_that.prefailure,_that.updatedOnline,_that.performance,_that.errorRate,_that.eventCount,_that.autoKeep);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? value,  String? string,  bool prefailure,  bool updatedOnline,  bool performance,  bool errorRate,  bool eventCount,  bool autoKeep)?  $default,) {final _that = this;
switch (_that) {
case _SmartAttributeFlags() when $default != null:
return $default(_that.value,_that.string,_that.prefailure,_that.updatedOnline,_that.performance,_that.errorRate,_that.eventCount,_that.autoKeep);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SmartAttributeFlags extends SmartAttributeFlags {
  const _SmartAttributeFlags({this.value, this.string, this.prefailure = false, this.updatedOnline = false, this.performance = false, this.errorRate = false, this.eventCount = false, this.autoKeep = false}): super._();
  factory _SmartAttributeFlags.fromJson(Map<String, dynamic> json) => _$SmartAttributeFlagsFromJson(json);

@override final  int? value;
@override final  String? string;
@override@JsonKey() final  bool prefailure;
@override@JsonKey() final  bool updatedOnline;
@override@JsonKey() final  bool performance;
@override@JsonKey() final  bool errorRate;
@override@JsonKey() final  bool eventCount;
@override@JsonKey() final  bool autoKeep;

/// Create a copy of SmartAttributeFlags
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SmartAttributeFlagsCopyWith<_SmartAttributeFlags> get copyWith => __$SmartAttributeFlagsCopyWithImpl<_SmartAttributeFlags>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SmartAttributeFlagsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SmartAttributeFlags&&(identical(other.value, value) || other.value == value)&&(identical(other.string, string) || other.string == string)&&(identical(other.prefailure, prefailure) || other.prefailure == prefailure)&&(identical(other.updatedOnline, updatedOnline) || other.updatedOnline == updatedOnline)&&(identical(other.performance, performance) || other.performance == performance)&&(identical(other.errorRate, errorRate) || other.errorRate == errorRate)&&(identical(other.eventCount, eventCount) || other.eventCount == eventCount)&&(identical(other.autoKeep, autoKeep) || other.autoKeep == autoKeep));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,value,string,prefailure,updatedOnline,performance,errorRate,eventCount,autoKeep);
}



}

/// @nodoc
abstract mixin class _$SmartAttributeFlagsCopyWith<$Res> implements $SmartAttributeFlagsCopyWith<$Res> {
  factory _$SmartAttributeFlagsCopyWith(_SmartAttributeFlags value, $Res Function(_SmartAttributeFlags) _then) = __$SmartAttributeFlagsCopyWithImpl;
@override @useResult
$Res call({
 int? value, String? string, bool prefailure, bool updatedOnline, bool performance, bool errorRate, bool eventCount, bool autoKeep
});




}
/// @nodoc
class __$SmartAttributeFlagsCopyWithImpl<$Res>
    implements _$SmartAttributeFlagsCopyWith<$Res> {
  __$SmartAttributeFlagsCopyWithImpl(this._self, this._then);

  final _SmartAttributeFlags _self;
  final $Res Function(_SmartAttributeFlags) _then;

/// Create a copy of SmartAttributeFlags
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = freezed,Object? string = freezed,Object? prefailure = null,Object? updatedOnline = null,Object? performance = null,Object? errorRate = null,Object? eventCount = null,Object? autoKeep = null,}) {
  return _then(_SmartAttributeFlags(
value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int?,string: freezed == string ? _self.string : string // ignore: cast_nullable_to_non_nullable
as String?,prefailure: null == prefailure ? _self.prefailure : prefailure // ignore: cast_nullable_to_non_nullable
as bool,updatedOnline: null == updatedOnline ? _self.updatedOnline : updatedOnline // ignore: cast_nullable_to_non_nullable
as bool,performance: null == performance ? _self.performance : performance // ignore: cast_nullable_to_non_nullable
as bool,errorRate: null == errorRate ? _self.errorRate : errorRate // ignore: cast_nullable_to_non_nullable
as bool,eventCount: null == eventCount ? _self.eventCount : eventCount // ignore: cast_nullable_to_non_nullable
as bool,autoKeep: null == autoKeep ? _self.autoKeep : autoKeep // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
