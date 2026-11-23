// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BmcSummaryState implements DiagnosticableTreeMixin {

 RedfishTopology? get topology; double? get watts; RedfishFailure? get failure; String? get failureDetail; bool get isBusy; bool get isPowering;
/// Create a copy of BmcSummaryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BmcSummaryStateCopyWith<BmcSummaryState> get copyWith => _$BmcSummaryStateCopyWithImpl<BmcSummaryState>(this as BmcSummaryState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as BmcSummaryState;
  properties
    ..add(DiagnosticsProperty('type', 'BmcSummaryState'))
    ..add(DiagnosticsProperty('topology', _this.topology))..add(DiagnosticsProperty('watts', _this.watts))..add(DiagnosticsProperty('failure', _this.failure))..add(DiagnosticsProperty('failureDetail', _this.failureDetail))..add(DiagnosticsProperty('isBusy', _this.isBusy))..add(DiagnosticsProperty('isPowering', _this.isPowering));
}

@override
bool operator ==(Object other) {
  final _this = this as BmcSummaryState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BmcSummaryState&&(identical(other.topology, _this.topology) || other.topology == _this.topology)&&(identical(other.watts, _this.watts) || other.watts == _this.watts)&&(identical(other.failure, _this.failure) || other.failure == _this.failure)&&(identical(other.failureDetail, _this.failureDetail) || other.failureDetail == _this.failureDetail)&&(identical(other.isBusy, _this.isBusy) || other.isBusy == _this.isBusy)&&(identical(other.isPowering, _this.isPowering) || other.isPowering == _this.isPowering));
}


@override
int get hashCode {
  final _this = this as BmcSummaryState;
  return Object.hash(runtimeType,_this.topology,_this.watts,_this.failure,_this.failureDetail,_this.isBusy,_this.isPowering);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as BmcSummaryState;
  return 'BmcSummaryState(topology: ${_this.topology}, watts: ${_this.watts}, failure: ${_this.failure}, failureDetail: ${_this.failureDetail}, isBusy: ${_this.isBusy}, isPowering: ${_this.isPowering})';
}


}

/// @nodoc
abstract mixin class $BmcSummaryStateCopyWith<$Res>  {
  factory $BmcSummaryStateCopyWith(BmcSummaryState value, $Res Function(BmcSummaryState) _then) = _$BmcSummaryStateCopyWithImpl;
@useResult
$Res call({
 RedfishTopology? topology, double? watts, RedfishFailure? failure, String? failureDetail, bool isBusy, bool isPowering
});




}
/// @nodoc
class _$BmcSummaryStateCopyWithImpl<$Res>
    implements $BmcSummaryStateCopyWith<$Res> {
  _$BmcSummaryStateCopyWithImpl(this._self, this._then);

  final BmcSummaryState _self;
  final $Res Function(BmcSummaryState) _then;

/// Create a copy of BmcSummaryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? topology = freezed,Object? watts = freezed,Object? failure = freezed,Object? failureDetail = freezed,Object? isBusy = null,Object? isPowering = null,}) {
  return _then(BmcSummaryState(
topology: freezed == topology ? _self.topology : topology // ignore: cast_nullable_to_non_nullable
as RedfishTopology?,watts: freezed == watts ? _self.watts : watts // ignore: cast_nullable_to_non_nullable
as double?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as RedfishFailure?,failureDetail: freezed == failureDetail ? _self.failureDetail : failureDetail // ignore: cast_nullable_to_non_nullable
as String?,isBusy: null == isBusy ? _self.isBusy : isBusy // ignore: cast_nullable_to_non_nullable
as bool,isPowering: null == isPowering ? _self.isPowering : isPowering // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [BmcSummaryState].
extension BmcSummaryStatePatterns on BmcSummaryState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BmcSummaryState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BmcSummaryState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BmcSummaryState value)  $default,){
final _that = this;
switch (_that) {
case _BmcSummaryState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BmcSummaryState value)?  $default,){
final _that = this;
switch (_that) {
case _BmcSummaryState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RedfishTopology? topology,  double? watts,  RedfishFailure? failure,  String? failureDetail,  bool isBusy,  bool isPowering)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BmcSummaryState() when $default != null:
return $default(_that.topology,_that.watts,_that.failure,_that.failureDetail,_that.isBusy,_that.isPowering);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RedfishTopology? topology,  double? watts,  RedfishFailure? failure,  String? failureDetail,  bool isBusy,  bool isPowering)  $default,) {final _that = this;
switch (_that) {
case _BmcSummaryState():
return $default(_that.topology,_that.watts,_that.failure,_that.failureDetail,_that.isBusy,_that.isPowering);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RedfishTopology? topology,  double? watts,  RedfishFailure? failure,  String? failureDetail,  bool isBusy,  bool isPowering)?  $default,) {final _that = this;
switch (_that) {
case _BmcSummaryState() when $default != null:
return $default(_that.topology,_that.watts,_that.failure,_that.failureDetail,_that.isBusy,_that.isPowering);case _:
  return null;

}
}

}

/// @nodoc


class _BmcSummaryState extends BmcSummaryState with DiagnosticableTreeMixin {
  const _BmcSummaryState({this.topology, this.watts, this.failure, this.failureDetail, this.isBusy = false, this.isPowering = false}): super._();
  

@override final  RedfishTopology? topology;
@override final  double? watts;
@override final  RedfishFailure? failure;
@override final  String? failureDetail;
@override@JsonKey() final  bool isBusy;
@override@JsonKey() final  bool isPowering;

/// Create a copy of BmcSummaryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BmcSummaryStateCopyWith<_BmcSummaryState> get copyWith => __$BmcSummaryStateCopyWithImpl<_BmcSummaryState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'BmcSummaryState'))
    ..add(DiagnosticsProperty('topology', topology))..add(DiagnosticsProperty('watts', watts))..add(DiagnosticsProperty('failure', failure))..add(DiagnosticsProperty('failureDetail', failureDetail))..add(DiagnosticsProperty('isBusy', isBusy))..add(DiagnosticsProperty('isPowering', isPowering));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BmcSummaryState&&(identical(other.topology, topology) || other.topology == topology)&&(identical(other.watts, watts) || other.watts == watts)&&(identical(other.failure, failure) || other.failure == failure)&&(identical(other.failureDetail, failureDetail) || other.failureDetail == failureDetail)&&(identical(other.isBusy, isBusy) || other.isBusy == isBusy)&&(identical(other.isPowering, isPowering) || other.isPowering == isPowering));
}


@override
int get hashCode {
    return Object.hash(runtimeType,topology,watts,failure,failureDetail,isBusy,isPowering);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'BmcSummaryState(topology: $topology, watts: $watts, failure: $failure, failureDetail: $failureDetail, isBusy: $isBusy, isPowering: $isPowering)';
}


}

/// @nodoc
abstract mixin class _$BmcSummaryStateCopyWith<$Res> implements $BmcSummaryStateCopyWith<$Res> {
  factory _$BmcSummaryStateCopyWith(_BmcSummaryState value, $Res Function(_BmcSummaryState) _then) = __$BmcSummaryStateCopyWithImpl;
@override @useResult
$Res call({
 RedfishTopology? topology, double? watts, RedfishFailure? failure, String? failureDetail, bool isBusy, bool isPowering
});




}
/// @nodoc
class __$BmcSummaryStateCopyWithImpl<$Res>
    implements _$BmcSummaryStateCopyWith<$Res> {
  __$BmcSummaryStateCopyWithImpl(this._self, this._then);

  final _BmcSummaryState _self;
  final $Res Function(_BmcSummaryState) _then;

/// Create a copy of BmcSummaryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? topology = freezed,Object? watts = freezed,Object? failure = freezed,Object? failureDetail = freezed,Object? isBusy = null,Object? isPowering = null,}) {
  return _then(_BmcSummaryState(
topology: freezed == topology ? _self.topology : topology // ignore: cast_nullable_to_non_nullable
as RedfishTopology?,watts: freezed == watts ? _self.watts : watts // ignore: cast_nullable_to_non_nullable
as double?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as RedfishFailure?,failureDetail: freezed == failureDetail ? _self.failureDetail : failureDetail // ignore: cast_nullable_to_non_nullable
as String?,isBusy: null == isBusy ? _self.isBusy : isBusy // ignore: cast_nullable_to_non_nullable
as bool,isPowering: null == isPowering ? _self.isPowering : isPowering // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
