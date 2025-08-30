// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pve.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PveState {

 PveErr? get error; PveRes? get data; String? get release; bool get isBusy; bool get isConnected;
/// Create a copy of PveState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PveStateCopyWith<PveState> get copyWith => _$PveStateCopyWithImpl<PveState>(this as PveState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PveState&&(identical(other.error, error) || other.error == error)&&(identical(other.data, data) || other.data == data)&&(identical(other.release, release) || other.release == release)&&(identical(other.isBusy, isBusy) || other.isBusy == isBusy)&&(identical(other.isConnected, isConnected) || other.isConnected == isConnected));
}


@override
int get hashCode => Object.hash(runtimeType,error,data,release,isBusy,isConnected);

@override
String toString() {
  return 'PveState(error: $error, data: $data, release: $release, isBusy: $isBusy, isConnected: $isConnected)';
}


}

/// @nodoc
abstract mixin class $PveStateCopyWith<$Res>  {
  factory $PveStateCopyWith(PveState value, $Res Function(PveState) _then) = _$PveStateCopyWithImpl;
@useResult
$Res call({
 PveErr? error, PveRes? data, String? release, bool isBusy, bool isConnected
});




}
/// @nodoc
class _$PveStateCopyWithImpl<$Res>
    implements $PveStateCopyWith<$Res> {
  _$PveStateCopyWithImpl(this._self, this._then);

  final PveState _self;
  final $Res Function(PveState) _then;

/// Create a copy of PveState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? error = freezed,Object? data = freezed,Object? release = freezed,Object? isBusy = null,Object? isConnected = null,}) {
  return _then(_self.copyWith(
error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as PveErr?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as PveRes?,release: freezed == release ? _self.release : release // ignore: cast_nullable_to_non_nullable
as String?,isBusy: null == isBusy ? _self.isBusy : isBusy // ignore: cast_nullable_to_non_nullable
as bool,isConnected: null == isConnected ? _self.isConnected : isConnected // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PveState].
extension PveStatePatterns on PveState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PveState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PveState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PveState value)  $default,){
final _that = this;
switch (_that) {
case _PveState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PveState value)?  $default,){
final _that = this;
switch (_that) {
case _PveState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PveErr? error,  PveRes? data,  String? release,  bool isBusy,  bool isConnected)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PveState() when $default != null:
return $default(_that.error,_that.data,_that.release,_that.isBusy,_that.isConnected);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PveErr? error,  PveRes? data,  String? release,  bool isBusy,  bool isConnected)  $default,) {final _that = this;
switch (_that) {
case _PveState():
return $default(_that.error,_that.data,_that.release,_that.isBusy,_that.isConnected);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PveErr? error,  PveRes? data,  String? release,  bool isBusy,  bool isConnected)?  $default,) {final _that = this;
switch (_that) {
case _PveState() when $default != null:
return $default(_that.error,_that.data,_that.release,_that.isBusy,_that.isConnected);case _:
  return null;

}
}

}

/// @nodoc


class _PveState implements PveState {
  const _PveState({this.error = null, this.data = null, this.release = null, this.isBusy = false, this.isConnected = false});
  

@override@JsonKey() final  PveErr? error;
@override@JsonKey() final  PveRes? data;
@override@JsonKey() final  String? release;
@override@JsonKey() final  bool isBusy;
@override@JsonKey() final  bool isConnected;

/// Create a copy of PveState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PveStateCopyWith<_PveState> get copyWith => __$PveStateCopyWithImpl<_PveState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PveState&&(identical(other.error, error) || other.error == error)&&(identical(other.data, data) || other.data == data)&&(identical(other.release, release) || other.release == release)&&(identical(other.isBusy, isBusy) || other.isBusy == isBusy)&&(identical(other.isConnected, isConnected) || other.isConnected == isConnected));
}


@override
int get hashCode => Object.hash(runtimeType,error,data,release,isBusy,isConnected);

@override
String toString() {
  return 'PveState(error: $error, data: $data, release: $release, isBusy: $isBusy, isConnected: $isConnected)';
}


}

/// @nodoc
abstract mixin class _$PveStateCopyWith<$Res> implements $PveStateCopyWith<$Res> {
  factory _$PveStateCopyWith(_PveState value, $Res Function(_PveState) _then) = __$PveStateCopyWithImpl;
@override @useResult
$Res call({
 PveErr? error, PveRes? data, String? release, bool isBusy, bool isConnected
});




}
/// @nodoc
class __$PveStateCopyWithImpl<$Res>
    implements _$PveStateCopyWith<$Res> {
  __$PveStateCopyWithImpl(this._self, this._then);

  final _PveState _self;
  final $Res Function(_PveState) _then;

/// Create a copy of PveState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? error = freezed,Object? data = freezed,Object? release = freezed,Object? isBusy = null,Object? isConnected = null,}) {
  return _then(_PveState(
error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as PveErr?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as PveRes?,release: freezed == release ? _self.release : release // ignore: cast_nullable_to_non_nullable
as String?,isBusy: null == isBusy ? _self.isBusy : isBusy // ignore: cast_nullable_to_non_nullable
as bool,isConnected: null == isConnected ? _self.isConnected : isConnected // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
