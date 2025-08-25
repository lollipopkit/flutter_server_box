// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sftp.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SftpState {

 List<SftpReqStatus> get requests;
/// Create a copy of SftpState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SftpStateCopyWith<SftpState> get copyWith => _$SftpStateCopyWithImpl<SftpState>(this as SftpState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SftpState&&const DeepCollectionEquality().equals(other.requests, requests));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(requests));

@override
String toString() {
  return 'SftpState(requests: $requests)';
}


}

/// @nodoc
abstract mixin class $SftpStateCopyWith<$Res>  {
  factory $SftpStateCopyWith(SftpState value, $Res Function(SftpState) _then) = _$SftpStateCopyWithImpl;
@useResult
$Res call({
 List<SftpReqStatus> requests
});




}
/// @nodoc
class _$SftpStateCopyWithImpl<$Res>
    implements $SftpStateCopyWith<$Res> {
  _$SftpStateCopyWithImpl(this._self, this._then);

  final SftpState _self;
  final $Res Function(SftpState) _then;

/// Create a copy of SftpState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requests = null,}) {
  return _then(_self.copyWith(
requests: null == requests ? _self.requests : requests // ignore: cast_nullable_to_non_nullable
as List<SftpReqStatus>,
  ));
}

}


/// Adds pattern-matching-related methods to [SftpState].
extension SftpStatePatterns on SftpState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SftpState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SftpState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SftpState value)  $default,){
final _that = this;
switch (_that) {
case _SftpState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SftpState value)?  $default,){
final _that = this;
switch (_that) {
case _SftpState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<SftpReqStatus> requests)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SftpState() when $default != null:
return $default(_that.requests);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<SftpReqStatus> requests)  $default,) {final _that = this;
switch (_that) {
case _SftpState():
return $default(_that.requests);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<SftpReqStatus> requests)?  $default,) {final _that = this;
switch (_that) {
case _SftpState() when $default != null:
return $default(_that.requests);case _:
  return null;

}
}

}

/// @nodoc


class _SftpState implements SftpState {
  const _SftpState({final  List<SftpReqStatus> requests = const <SftpReqStatus>[]}): _requests = requests;
  

 final  List<SftpReqStatus> _requests;
@override@JsonKey() List<SftpReqStatus> get requests {
  if (_requests is EqualUnmodifiableListView) return _requests;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_requests);
}


/// Create a copy of SftpState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SftpStateCopyWith<_SftpState> get copyWith => __$SftpStateCopyWithImpl<_SftpState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SftpState&&const DeepCollectionEquality().equals(other._requests, _requests));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_requests));

@override
String toString() {
  return 'SftpState(requests: $requests)';
}


}

/// @nodoc
abstract mixin class _$SftpStateCopyWith<$Res> implements $SftpStateCopyWith<$Res> {
  factory _$SftpStateCopyWith(_SftpState value, $Res Function(_SftpState) _then) = __$SftpStateCopyWithImpl;
@override @useResult
$Res call({
 List<SftpReqStatus> requests
});




}
/// @nodoc
class __$SftpStateCopyWithImpl<$Res>
    implements _$SftpStateCopyWith<$Res> {
  __$SftpStateCopyWithImpl(this._self, this._then);

  final _SftpState _self;
  final $Res Function(_SftpState) _then;

/// Create a copy of SftpState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requests = null,}) {
  return _then(_SftpState(
requests: null == requests ? _self._requests : requests // ignore: cast_nullable_to_non_nullable
as List<SftpReqStatus>,
  ));
}


}

// dart format on
