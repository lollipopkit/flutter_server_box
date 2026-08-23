// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bmc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BmcState {

/// Null until the first successful discovery.
 RedfishTopology? get topology; BmcSensors get sensors; RedfishFailure? get failure; String? get failureDetail; bool get isBusy;/// Set when the sensor list was cut to [_maxSensorMembers].
 bool get sensorsTruncated;
/// Create a copy of BmcState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BmcStateCopyWith<BmcState> get copyWith => _$BmcStateCopyWithImpl<BmcState>(this as BmcState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BmcState&&(identical(other.topology, topology) || other.topology == topology)&&(identical(other.sensors, sensors) || other.sensors == sensors)&&(identical(other.failure, failure) || other.failure == failure)&&(identical(other.failureDetail, failureDetail) || other.failureDetail == failureDetail)&&(identical(other.isBusy, isBusy) || other.isBusy == isBusy)&&(identical(other.sensorsTruncated, sensorsTruncated) || other.sensorsTruncated == sensorsTruncated));
}


@override
int get hashCode => Object.hash(runtimeType,topology,sensors,failure,failureDetail,isBusy,sensorsTruncated);

@override
String toString() {
  return 'BmcState(topology: $topology, sensors: $sensors, failure: $failure, failureDetail: $failureDetail, isBusy: $isBusy, sensorsTruncated: $sensorsTruncated)';
}


}

/// @nodoc
abstract mixin class $BmcStateCopyWith<$Res>  {
  factory $BmcStateCopyWith(BmcState value, $Res Function(BmcState) _then) = _$BmcStateCopyWithImpl;
@useResult
$Res call({
 RedfishTopology? topology, BmcSensors sensors, RedfishFailure? failure, String? failureDetail, bool isBusy, bool sensorsTruncated
});




}
/// @nodoc
class _$BmcStateCopyWithImpl<$Res>
    implements $BmcStateCopyWith<$Res> {
  _$BmcStateCopyWithImpl(this._self, this._then);

  final BmcState _self;
  final $Res Function(BmcState) _then;

/// Create a copy of BmcState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? topology = freezed,Object? sensors = null,Object? failure = freezed,Object? failureDetail = freezed,Object? isBusy = null,Object? sensorsTruncated = null,}) {
  return _then(_self.copyWith(
topology: freezed == topology ? _self.topology : topology // ignore: cast_nullable_to_non_nullable
as RedfishTopology?,sensors: null == sensors ? _self.sensors : sensors // ignore: cast_nullable_to_non_nullable
as BmcSensors,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as RedfishFailure?,failureDetail: freezed == failureDetail ? _self.failureDetail : failureDetail // ignore: cast_nullable_to_non_nullable
as String?,isBusy: null == isBusy ? _self.isBusy : isBusy // ignore: cast_nullable_to_non_nullable
as bool,sensorsTruncated: null == sensorsTruncated ? _self.sensorsTruncated : sensorsTruncated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [BmcState].
extension BmcStatePatterns on BmcState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BmcState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BmcState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BmcState value)  $default,){
final _that = this;
switch (_that) {
case _BmcState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BmcState value)?  $default,){
final _that = this;
switch (_that) {
case _BmcState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RedfishTopology? topology,  BmcSensors sensors,  RedfishFailure? failure,  String? failureDetail,  bool isBusy,  bool sensorsTruncated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BmcState() when $default != null:
return $default(_that.topology,_that.sensors,_that.failure,_that.failureDetail,_that.isBusy,_that.sensorsTruncated);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RedfishTopology? topology,  BmcSensors sensors,  RedfishFailure? failure,  String? failureDetail,  bool isBusy,  bool sensorsTruncated)  $default,) {final _that = this;
switch (_that) {
case _BmcState():
return $default(_that.topology,_that.sensors,_that.failure,_that.failureDetail,_that.isBusy,_that.sensorsTruncated);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RedfishTopology? topology,  BmcSensors sensors,  RedfishFailure? failure,  String? failureDetail,  bool isBusy,  bool sensorsTruncated)?  $default,) {final _that = this;
switch (_that) {
case _BmcState() when $default != null:
return $default(_that.topology,_that.sensors,_that.failure,_that.failureDetail,_that.isBusy,_that.sensorsTruncated);case _:
  return null;

}
}

}

/// @nodoc


class _BmcState extends BmcState {
  const _BmcState({this.topology, this.sensors = const BmcSensors(), this.failure, this.failureDetail, this.isBusy = false, this.sensorsTruncated = false}): super._();
  

/// Null until the first successful discovery.
@override final  RedfishTopology? topology;
@override@JsonKey() final  BmcSensors sensors;
@override final  RedfishFailure? failure;
@override final  String? failureDetail;
@override@JsonKey() final  bool isBusy;
/// Set when the sensor list was cut to [_maxSensorMembers].
@override@JsonKey() final  bool sensorsTruncated;

/// Create a copy of BmcState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BmcStateCopyWith<_BmcState> get copyWith => __$BmcStateCopyWithImpl<_BmcState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BmcState&&(identical(other.topology, topology) || other.topology == topology)&&(identical(other.sensors, sensors) || other.sensors == sensors)&&(identical(other.failure, failure) || other.failure == failure)&&(identical(other.failureDetail, failureDetail) || other.failureDetail == failureDetail)&&(identical(other.isBusy, isBusy) || other.isBusy == isBusy)&&(identical(other.sensorsTruncated, sensorsTruncated) || other.sensorsTruncated == sensorsTruncated));
}


@override
int get hashCode => Object.hash(runtimeType,topology,sensors,failure,failureDetail,isBusy,sensorsTruncated);

@override
String toString() {
  return 'BmcState(topology: $topology, sensors: $sensors, failure: $failure, failureDetail: $failureDetail, isBusy: $isBusy, sensorsTruncated: $sensorsTruncated)';
}


}

/// @nodoc
abstract mixin class _$BmcStateCopyWith<$Res> implements $BmcStateCopyWith<$Res> {
  factory _$BmcStateCopyWith(_BmcState value, $Res Function(_BmcState) _then) = __$BmcStateCopyWithImpl;
@override @useResult
$Res call({
 RedfishTopology? topology, BmcSensors sensors, RedfishFailure? failure, String? failureDetail, bool isBusy, bool sensorsTruncated
});




}
/// @nodoc
class __$BmcStateCopyWithImpl<$Res>
    implements _$BmcStateCopyWith<$Res> {
  __$BmcStateCopyWithImpl(this._self, this._then);

  final _BmcState _self;
  final $Res Function(_BmcState) _then;

/// Create a copy of BmcState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? topology = freezed,Object? sensors = null,Object? failure = freezed,Object? failureDetail = freezed,Object? isBusy = null,Object? sensorsTruncated = null,}) {
  return _then(_BmcState(
topology: freezed == topology ? _self.topology : topology // ignore: cast_nullable_to_non_nullable
as RedfishTopology?,sensors: null == sensors ? _self.sensors : sensors // ignore: cast_nullable_to_non_nullable
as BmcSensors,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as RedfishFailure?,failureDetail: freezed == failureDetail ? _self.failureDetail : failureDetail // ignore: cast_nullable_to_non_nullable
as String?,isBusy: null == isBusy ? _self.isBusy : isBusy // ignore: cast_nullable_to_non_nullable
as bool,sensorsTruncated: null == sensorsTruncated ? _self.sensorsTruncated : sensorsTruncated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
