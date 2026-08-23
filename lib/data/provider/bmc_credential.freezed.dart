// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bmc_credential.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BmcCredentialState {

 List<BmcCredential> get creds;
/// Create a copy of BmcCredentialState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BmcCredentialStateCopyWith<BmcCredentialState> get copyWith => _$BmcCredentialStateCopyWithImpl<BmcCredentialState>(this as BmcCredentialState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BmcCredentialState&&const DeepCollectionEquality().equals(other.creds, creds));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(creds));

@override
String toString() {
  return 'BmcCredentialState(creds: $creds)';
}


}

/// @nodoc
abstract mixin class $BmcCredentialStateCopyWith<$Res>  {
  factory $BmcCredentialStateCopyWith(BmcCredentialState value, $Res Function(BmcCredentialState) _then) = _$BmcCredentialStateCopyWithImpl;
@useResult
$Res call({
 List<BmcCredential> creds
});




}
/// @nodoc
class _$BmcCredentialStateCopyWithImpl<$Res>
    implements $BmcCredentialStateCopyWith<$Res> {
  _$BmcCredentialStateCopyWithImpl(this._self, this._then);

  final BmcCredentialState _self;
  final $Res Function(BmcCredentialState) _then;

/// Create a copy of BmcCredentialState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? creds = null,}) {
  return _then(_self.copyWith(
creds: null == creds ? _self.creds : creds // ignore: cast_nullable_to_non_nullable
as List<BmcCredential>,
  ));
}

}


/// Adds pattern-matching-related methods to [BmcCredentialState].
extension BmcCredentialStatePatterns on BmcCredentialState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BmcCredentialState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BmcCredentialState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BmcCredentialState value)  $default,){
final _that = this;
switch (_that) {
case _BmcCredentialState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BmcCredentialState value)?  $default,){
final _that = this;
switch (_that) {
case _BmcCredentialState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<BmcCredential> creds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BmcCredentialState() when $default != null:
return $default(_that.creds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<BmcCredential> creds)  $default,) {final _that = this;
switch (_that) {
case _BmcCredentialState():
return $default(_that.creds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<BmcCredential> creds)?  $default,) {final _that = this;
switch (_that) {
case _BmcCredentialState() when $default != null:
return $default(_that.creds);case _:
  return null;

}
}

}

/// @nodoc


class _BmcCredentialState implements BmcCredentialState {
  const _BmcCredentialState({final  List<BmcCredential> creds = const <BmcCredential>[]}): _creds = creds;
  

 final  List<BmcCredential> _creds;
@override@JsonKey() List<BmcCredential> get creds {
  if (_creds is EqualUnmodifiableListView) return _creds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_creds);
}


/// Create a copy of BmcCredentialState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BmcCredentialStateCopyWith<_BmcCredentialState> get copyWith => __$BmcCredentialStateCopyWithImpl<_BmcCredentialState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BmcCredentialState&&const DeepCollectionEquality().equals(other._creds, _creds));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_creds));

@override
String toString() {
  return 'BmcCredentialState(creds: $creds)';
}


}

/// @nodoc
abstract mixin class _$BmcCredentialStateCopyWith<$Res> implements $BmcCredentialStateCopyWith<$Res> {
  factory _$BmcCredentialStateCopyWith(_BmcCredentialState value, $Res Function(_BmcCredentialState) _then) = __$BmcCredentialStateCopyWithImpl;
@override @useResult
$Res call({
 List<BmcCredential> creds
});




}
/// @nodoc
class __$BmcCredentialStateCopyWithImpl<$Res>
    implements _$BmcCredentialStateCopyWith<$Res> {
  __$BmcCredentialStateCopyWithImpl(this._self, this._then);

  final _BmcCredentialState _self;
  final $Res Function(_BmcCredentialState) _then;

/// Create a copy of BmcCredentialState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? creds = null,}) {
  return _then(_BmcCredentialState(
creds: null == creds ? _self._creds : creds // ignore: cast_nullable_to_non_nullable
as List<BmcCredential>,
  ));
}


}

// dart format on
