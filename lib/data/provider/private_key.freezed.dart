// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'private_key.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PrivateKeyState {

 List<PrivateKeyInfo> get keys;
/// Create a copy of PrivateKeyState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PrivateKeyStateCopyWith<PrivateKeyState> get copyWith => _$PrivateKeyStateCopyWithImpl<PrivateKeyState>(this as PrivateKeyState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PrivateKeyState&&const DeepCollectionEquality().equals(other.keys, keys));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(keys));

@override
String toString() {
  return 'PrivateKeyState(keys: $keys)';
}


}

/// @nodoc
abstract mixin class $PrivateKeyStateCopyWith<$Res>  {
  factory $PrivateKeyStateCopyWith(PrivateKeyState value, $Res Function(PrivateKeyState) _then) = _$PrivateKeyStateCopyWithImpl;
@useResult
$Res call({
 List<PrivateKeyInfo> keys
});




}
/// @nodoc
class _$PrivateKeyStateCopyWithImpl<$Res>
    implements $PrivateKeyStateCopyWith<$Res> {
  _$PrivateKeyStateCopyWithImpl(this._self, this._then);

  final PrivateKeyState _self;
  final $Res Function(PrivateKeyState) _then;

/// Create a copy of PrivateKeyState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? keys = null,}) {
  return _then(_self.copyWith(
keys: null == keys ? _self.keys : keys // ignore: cast_nullable_to_non_nullable
as List<PrivateKeyInfo>,
  ));
}

}


/// Adds pattern-matching-related methods to [PrivateKeyState].
extension PrivateKeyStatePatterns on PrivateKeyState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PrivateKeyState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PrivateKeyState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PrivateKeyState value)  $default,){
final _that = this;
switch (_that) {
case _PrivateKeyState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PrivateKeyState value)?  $default,){
final _that = this;
switch (_that) {
case _PrivateKeyState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<PrivateKeyInfo> keys)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PrivateKeyState() when $default != null:
return $default(_that.keys);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<PrivateKeyInfo> keys)  $default,) {final _that = this;
switch (_that) {
case _PrivateKeyState():
return $default(_that.keys);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<PrivateKeyInfo> keys)?  $default,) {final _that = this;
switch (_that) {
case _PrivateKeyState() when $default != null:
return $default(_that.keys);case _:
  return null;

}
}

}

/// @nodoc


class _PrivateKeyState implements PrivateKeyState {
  const _PrivateKeyState({final  List<PrivateKeyInfo> keys = const <PrivateKeyInfo>[]}): _keys = keys;
  

 final  List<PrivateKeyInfo> _keys;
@override@JsonKey() List<PrivateKeyInfo> get keys {
  if (_keys is EqualUnmodifiableListView) return _keys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_keys);
}


/// Create a copy of PrivateKeyState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PrivateKeyStateCopyWith<_PrivateKeyState> get copyWith => __$PrivateKeyStateCopyWithImpl<_PrivateKeyState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PrivateKeyState&&const DeepCollectionEquality().equals(other._keys, _keys));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_keys));

@override
String toString() {
  return 'PrivateKeyState(keys: $keys)';
}


}

/// @nodoc
abstract mixin class _$PrivateKeyStateCopyWith<$Res> implements $PrivateKeyStateCopyWith<$Res> {
  factory _$PrivateKeyStateCopyWith(_PrivateKeyState value, $Res Function(_PrivateKeyState) _then) = __$PrivateKeyStateCopyWithImpl;
@override @useResult
$Res call({
 List<PrivateKeyInfo> keys
});




}
/// @nodoc
class __$PrivateKeyStateCopyWithImpl<$Res>
    implements _$PrivateKeyStateCopyWith<$Res> {
  __$PrivateKeyStateCopyWithImpl(this._self, this._then);

  final _PrivateKeyState _self;
  final $Res Function(_PrivateKeyState) _then;

/// Create a copy of PrivateKeyState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? keys = null,}) {
  return _then(_PrivateKeyState(
keys: null == keys ? _self._keys : keys // ignore: cast_nullable_to_non_nullable
as List<PrivateKeyInfo>,
  ));
}


}

// dart format on
