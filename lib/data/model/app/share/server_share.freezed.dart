// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'server_share.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ServerShare {

 int get version;/// Already made portable by [ServerShare.of] — see [ServerShareOmission]
/// for what that means.
 Spi get spi;/// The private keys [spi] refers to, by value. Normally zero or one; a
/// list because the field is what makes the payload self-contained and a
/// server growing a second key reference should not need a format change.
 List<PrivateKeyInfo> get keys;/// Unix milliseconds, or null for a payload with no deadline.
///
/// Set for the QR flavour and not for the file one, which is the whole
/// difference between them: a QR is shown on a screen in a room, and the
/// realistic way it leaks is a photograph. A deadline does not make the
/// six-digit code longer, it bounds how long guessing it is worth doing.
/// A file the user deliberately saved has no such moment to expire from.
 int? get expiresAt;
/// Create a copy of ServerShare
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerShareCopyWith<ServerShare> get copyWith => _$ServerShareCopyWithImpl<ServerShare>(this as ServerShare, _$identity);

  /// Serializes this ServerShare to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerShare&&(identical(other.version, version) || other.version == version)&&(identical(other.spi, spi) || other.spi == spi)&&const DeepCollectionEquality().equals(other.keys, keys)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,spi,const DeepCollectionEquality().hash(keys),expiresAt);

@override
String toString() {
  return 'ServerShare(version: $version, spi: $spi, keys: $keys, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class $ServerShareCopyWith<$Res>  {
  factory $ServerShareCopyWith(ServerShare value, $Res Function(ServerShare) _then) = _$ServerShareCopyWithImpl;
@useResult
$Res call({
 int version, Spi spi, List<PrivateKeyInfo> keys, int? expiresAt
});


$SpiCopyWith<$Res> get spi;

}
/// @nodoc
class _$ServerShareCopyWithImpl<$Res>
    implements $ServerShareCopyWith<$Res> {
  _$ServerShareCopyWithImpl(this._self, this._then);

  final ServerShare _self;
  final $Res Function(ServerShare) _then;

/// Create a copy of ServerShare
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? spi = null,Object? keys = null,Object? expiresAt = freezed,}) {
  return _then(_self.copyWith(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,spi: null == spi ? _self.spi : spi // ignore: cast_nullable_to_non_nullable
as Spi,keys: null == keys ? _self.keys : keys // ignore: cast_nullable_to_non_nullable
as List<PrivateKeyInfo>,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of ServerShare
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpiCopyWith<$Res> get spi {
  
  return $SpiCopyWith<$Res>(_self.spi, (value) {
    return _then(_self.copyWith(spi: value));
  });
}
}


/// Adds pattern-matching-related methods to [ServerShare].
extension ServerSharePatterns on ServerShare {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServerShare value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServerShare() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServerShare value)  $default,){
final _that = this;
switch (_that) {
case _ServerShare():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServerShare value)?  $default,){
final _that = this;
switch (_that) {
case _ServerShare() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int version,  Spi spi,  List<PrivateKeyInfo> keys,  int? expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServerShare() when $default != null:
return $default(_that.version,_that.spi,_that.keys,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int version,  Spi spi,  List<PrivateKeyInfo> keys,  int? expiresAt)  $default,) {final _that = this;
switch (_that) {
case _ServerShare():
return $default(_that.version,_that.spi,_that.keys,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int version,  Spi spi,  List<PrivateKeyInfo> keys,  int? expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _ServerShare() when $default != null:
return $default(_that.version,_that.spi,_that.keys,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ServerShare extends ServerShare {
  const _ServerShare({required this.version, required this.spi, final  List<PrivateKeyInfo> keys = const <PrivateKeyInfo>[], this.expiresAt}): _keys = keys,super._();
  factory _ServerShare.fromJson(Map<String, dynamic> json) => _$ServerShareFromJson(json);

@override final  int version;
/// Already made portable by [ServerShare.of] — see [ServerShareOmission]
/// for what that means.
@override final  Spi spi;
/// The private keys [spi] refers to, by value. Normally zero or one; a
/// list because the field is what makes the payload self-contained and a
/// server growing a second key reference should not need a format change.
 final  List<PrivateKeyInfo> _keys;
/// The private keys [spi] refers to, by value. Normally zero or one; a
/// list because the field is what makes the payload self-contained and a
/// server growing a second key reference should not need a format change.
@override@JsonKey() List<PrivateKeyInfo> get keys {
  if (_keys is EqualUnmodifiableListView) return _keys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_keys);
}

/// Unix milliseconds, or null for a payload with no deadline.
///
/// Set for the QR flavour and not for the file one, which is the whole
/// difference between them: a QR is shown on a screen in a room, and the
/// realistic way it leaks is a photograph. A deadline does not make the
/// six-digit code longer, it bounds how long guessing it is worth doing.
/// A file the user deliberately saved has no such moment to expire from.
@override final  int? expiresAt;

/// Create a copy of ServerShare
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServerShareCopyWith<_ServerShare> get copyWith => __$ServerShareCopyWithImpl<_ServerShare>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ServerShareToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServerShare&&(identical(other.version, version) || other.version == version)&&(identical(other.spi, spi) || other.spi == spi)&&const DeepCollectionEquality().equals(other._keys, _keys)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,spi,const DeepCollectionEquality().hash(_keys),expiresAt);

@override
String toString() {
  return 'ServerShare(version: $version, spi: $spi, keys: $keys, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$ServerShareCopyWith<$Res> implements $ServerShareCopyWith<$Res> {
  factory _$ServerShareCopyWith(_ServerShare value, $Res Function(_ServerShare) _then) = __$ServerShareCopyWithImpl;
@override @useResult
$Res call({
 int version, Spi spi, List<PrivateKeyInfo> keys, int? expiresAt
});


@override $SpiCopyWith<$Res> get spi;

}
/// @nodoc
class __$ServerShareCopyWithImpl<$Res>
    implements _$ServerShareCopyWith<$Res> {
  __$ServerShareCopyWithImpl(this._self, this._then);

  final _ServerShare _self;
  final $Res Function(_ServerShare) _then;

/// Create a copy of ServerShare
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? spi = null,Object? keys = null,Object? expiresAt = freezed,}) {
  return _then(_ServerShare(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,spi: null == spi ? _self.spi : spi // ignore: cast_nullable_to_non_nullable
as Spi,keys: null == keys ? _self._keys : keys // ignore: cast_nullable_to_non_nullable
as List<PrivateKeyInfo>,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of ServerShare
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpiCopyWith<$Res> get spi {
  
  return $SpiCopyWith<$Res>(_self.spi, (value) {
    return _then(_self.copyWith(spi: value));
  });
}
}

// dart format on
