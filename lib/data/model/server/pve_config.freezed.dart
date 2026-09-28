// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pve_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PveConfig {

/// The API's base URL, e.g. `https://127.0.0.1:8006`. The host resolves
/// on the far end of whichever transport carries the connection.
 String get addr;/// Unknown names read as [PveAuth.password], which is what every
/// configuration from before tokens was.
@JsonKey(unknownEnumValue: PveAuth.password) PveAuth get auth;/// The PVE password, for [PveAuth.password] when the SSH login uses a
/// stored key and so has no password to lend — see [loginPassword]. Kept
/// null otherwise: the SSH password is what is sent then.
 String? get pwd;/// `user@realm!tokenid` — see [tokenIdPattern].
 String? get tokenId;/// The token's secret. Never logged: messages name [tokenId] instead.
 String? get tokenSecret;/// SHA-256 of the DER certificate the user confirmed, lowercase hex. Null
/// means none has been confirmed, and the next connection asks.
 String? get certSha256;
/// Create a copy of PveConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PveConfigCopyWith<PveConfig> get copyWith => _$PveConfigCopyWithImpl<PveConfig>(this as PveConfig, _$identity);

  /// Serializes this PveConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PveConfig&&(identical(other.addr, addr) || other.addr == addr)&&(identical(other.auth, auth) || other.auth == auth)&&(identical(other.pwd, pwd) || other.pwd == pwd)&&(identical(other.tokenId, tokenId) || other.tokenId == tokenId)&&(identical(other.tokenSecret, tokenSecret) || other.tokenSecret == tokenSecret)&&(identical(other.certSha256, certSha256) || other.certSha256 == certSha256));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,addr,auth,pwd,tokenId,tokenSecret,certSha256);



}

/// @nodoc
abstract mixin class $PveConfigCopyWith<$Res>  {
  factory $PveConfigCopyWith(PveConfig value, $Res Function(PveConfig) _then) = _$PveConfigCopyWithImpl;
@useResult
$Res call({
 String addr,@JsonKey(unknownEnumValue: PveAuth.password) PveAuth auth, String? pwd, String? tokenId, String? tokenSecret, String? certSha256
});




}
/// @nodoc
class _$PveConfigCopyWithImpl<$Res>
    implements $PveConfigCopyWith<$Res> {
  _$PveConfigCopyWithImpl(this._self, this._then);

  final PveConfig _self;
  final $Res Function(PveConfig) _then;

/// Create a copy of PveConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? addr = null,Object? auth = null,Object? pwd = freezed,Object? tokenId = freezed,Object? tokenSecret = freezed,Object? certSha256 = freezed,}) {
  return _then(_self.copyWith(
addr: null == addr ? _self.addr : addr // ignore: cast_nullable_to_non_nullable
as String,auth: null == auth ? _self.auth : auth // ignore: cast_nullable_to_non_nullable
as PveAuth,pwd: freezed == pwd ? _self.pwd : pwd // ignore: cast_nullable_to_non_nullable
as String?,tokenId: freezed == tokenId ? _self.tokenId : tokenId // ignore: cast_nullable_to_non_nullable
as String?,tokenSecret: freezed == tokenSecret ? _self.tokenSecret : tokenSecret // ignore: cast_nullable_to_non_nullable
as String?,certSha256: freezed == certSha256 ? _self.certSha256 : certSha256 // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PveConfig].
extension PveConfigPatterns on PveConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PveConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PveConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PveConfig value)  $default,){
final _that = this;
switch (_that) {
case _PveConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PveConfig value)?  $default,){
final _that = this;
switch (_that) {
case _PveConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String addr, @JsonKey(unknownEnumValue: PveAuth.password)  PveAuth auth,  String? pwd,  String? tokenId,  String? tokenSecret,  String? certSha256)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PveConfig() when $default != null:
return $default(_that.addr,_that.auth,_that.pwd,_that.tokenId,_that.tokenSecret,_that.certSha256);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String addr, @JsonKey(unknownEnumValue: PveAuth.password)  PveAuth auth,  String? pwd,  String? tokenId,  String? tokenSecret,  String? certSha256)  $default,) {final _that = this;
switch (_that) {
case _PveConfig():
return $default(_that.addr,_that.auth,_that.pwd,_that.tokenId,_that.tokenSecret,_that.certSha256);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String addr, @JsonKey(unknownEnumValue: PveAuth.password)  PveAuth auth,  String? pwd,  String? tokenId,  String? tokenSecret,  String? certSha256)?  $default,) {final _that = this;
switch (_that) {
case _PveConfig() when $default != null:
return $default(_that.addr,_that.auth,_that.pwd,_that.tokenId,_that.tokenSecret,_that.certSha256);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PveConfig extends PveConfig {
  const _PveConfig({required this.addr, @JsonKey(unknownEnumValue: PveAuth.password) this.auth = PveAuth.password, this.pwd, this.tokenId, this.tokenSecret, this.certSha256}): super._();
  factory _PveConfig.fromJson(Map<String, dynamic> json) => _$PveConfigFromJson(json);

/// The API's base URL, e.g. `https://127.0.0.1:8006`. The host resolves
/// on the far end of whichever transport carries the connection.
@override final  String addr;
/// Unknown names read as [PveAuth.password], which is what every
/// configuration from before tokens was.
@override@JsonKey(unknownEnumValue: PveAuth.password) final  PveAuth auth;
/// The PVE password, for [PveAuth.password] when the SSH login uses a
/// stored key and so has no password to lend — see [loginPassword]. Kept
/// null otherwise: the SSH password is what is sent then.
@override final  String? pwd;
/// `user@realm!tokenid` — see [tokenIdPattern].
@override final  String? tokenId;
/// The token's secret. Never logged: messages name [tokenId] instead.
@override final  String? tokenSecret;
/// SHA-256 of the DER certificate the user confirmed, lowercase hex. Null
/// means none has been confirmed, and the next connection asks.
@override final  String? certSha256;

/// Create a copy of PveConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PveConfigCopyWith<_PveConfig> get copyWith => __$PveConfigCopyWithImpl<_PveConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PveConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PveConfig&&(identical(other.addr, addr) || other.addr == addr)&&(identical(other.auth, auth) || other.auth == auth)&&(identical(other.pwd, pwd) || other.pwd == pwd)&&(identical(other.tokenId, tokenId) || other.tokenId == tokenId)&&(identical(other.tokenSecret, tokenSecret) || other.tokenSecret == tokenSecret)&&(identical(other.certSha256, certSha256) || other.certSha256 == certSha256));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,addr,auth,pwd,tokenId,tokenSecret,certSha256);



}

/// @nodoc
abstract mixin class _$PveConfigCopyWith<$Res> implements $PveConfigCopyWith<$Res> {
  factory _$PveConfigCopyWith(_PveConfig value, $Res Function(_PveConfig) _then) = __$PveConfigCopyWithImpl;
@override @useResult
$Res call({
 String addr,@JsonKey(unknownEnumValue: PveAuth.password) PveAuth auth, String? pwd, String? tokenId, String? tokenSecret, String? certSha256
});




}
/// @nodoc
class __$PveConfigCopyWithImpl<$Res>
    implements _$PveConfigCopyWith<$Res> {
  __$PveConfigCopyWithImpl(this._self, this._then);

  final _PveConfig _self;
  final $Res Function(_PveConfig) _then;

/// Create a copy of PveConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? addr = null,Object? auth = null,Object? pwd = freezed,Object? tokenId = freezed,Object? tokenSecret = freezed,Object? certSha256 = freezed,}) {
  return _then(_PveConfig(
addr: null == addr ? _self.addr : addr // ignore: cast_nullable_to_non_nullable
as String,auth: null == auth ? _self.auth : auth // ignore: cast_nullable_to_non_nullable
as PveAuth,pwd: freezed == pwd ? _self.pwd : pwd // ignore: cast_nullable_to_non_nullable
as String?,tokenId: freezed == tokenId ? _self.tokenId : tokenId // ignore: cast_nullable_to_non_nullable
as String?,tokenSecret: freezed == tokenSecret ? _self.tokenSecret : tokenSecret // ignore: cast_nullable_to_non_nullable
as String?,certSha256: freezed == certSha256 ? _self.certSha256 : certSha256 // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
