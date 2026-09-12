// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'remote_desktop.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RemoteDesktopProfile {

 String get id; String get serverId; String get name; RemoteDesktopProtocol get protocol; String get host; int get port; String? get username; String? get password; String? get domain; bool get viewOnly; bool get shared; String? get trustedCertSha256;
/// Create a copy of RemoteDesktopProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteDesktopProfileCopyWith<RemoteDesktopProfile> get copyWith => _$RemoteDesktopProfileCopyWithImpl<RemoteDesktopProfile>(this as RemoteDesktopProfile, _$identity);

  /// Serializes this RemoteDesktopProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteDesktopProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.name, name) || other.name == name)&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.username, username) || other.username == username)&&(identical(other.password, password) || other.password == password)&&(identical(other.domain, domain) || other.domain == domain)&&(identical(other.viewOnly, viewOnly) || other.viewOnly == viewOnly)&&(identical(other.shared, shared) || other.shared == shared)&&(identical(other.trustedCertSha256, trustedCertSha256) || other.trustedCertSha256 == trustedCertSha256));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,serverId,name,protocol,host,port,username,password,domain,viewOnly,shared,trustedCertSha256);



}

/// @nodoc
abstract mixin class $RemoteDesktopProfileCopyWith<$Res>  {
  factory $RemoteDesktopProfileCopyWith(RemoteDesktopProfile value, $Res Function(RemoteDesktopProfile) _then) = _$RemoteDesktopProfileCopyWithImpl;
@useResult
$Res call({
 String id, String serverId, String name, RemoteDesktopProtocol protocol, String host, int port, String? username, String? password, String? domain, bool viewOnly, bool shared, String? trustedCertSha256
});




}
/// @nodoc
class _$RemoteDesktopProfileCopyWithImpl<$Res>
    implements $RemoteDesktopProfileCopyWith<$Res> {
  _$RemoteDesktopProfileCopyWithImpl(this._self, this._then);

  final RemoteDesktopProfile _self;
  final $Res Function(RemoteDesktopProfile) _then;

/// Create a copy of RemoteDesktopProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? serverId = null,Object? name = null,Object? protocol = null,Object? host = null,Object? port = null,Object? username = freezed,Object? password = freezed,Object? domain = freezed,Object? viewOnly = null,Object? shared = null,Object? trustedCertSha256 = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as RemoteDesktopProtocol,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,password: freezed == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String?,domain: freezed == domain ? _self.domain : domain // ignore: cast_nullable_to_non_nullable
as String?,viewOnly: null == viewOnly ? _self.viewOnly : viewOnly // ignore: cast_nullable_to_non_nullable
as bool,shared: null == shared ? _self.shared : shared // ignore: cast_nullable_to_non_nullable
as bool,trustedCertSha256: freezed == trustedCertSha256 ? _self.trustedCertSha256 : trustedCertSha256 // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RemoteDesktopProfile].
extension RemoteDesktopProfilePatterns on RemoteDesktopProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RemoteDesktopProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RemoteDesktopProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RemoteDesktopProfile value)  $default,){
final _that = this;
switch (_that) {
case _RemoteDesktopProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RemoteDesktopProfile value)?  $default,){
final _that = this;
switch (_that) {
case _RemoteDesktopProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String serverId,  String name,  RemoteDesktopProtocol protocol,  String host,  int port,  String? username,  String? password,  String? domain,  bool viewOnly,  bool shared,  String? trustedCertSha256)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RemoteDesktopProfile() when $default != null:
return $default(_that.id,_that.serverId,_that.name,_that.protocol,_that.host,_that.port,_that.username,_that.password,_that.domain,_that.viewOnly,_that.shared,_that.trustedCertSha256);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String serverId,  String name,  RemoteDesktopProtocol protocol,  String host,  int port,  String? username,  String? password,  String? domain,  bool viewOnly,  bool shared,  String? trustedCertSha256)  $default,) {final _that = this;
switch (_that) {
case _RemoteDesktopProfile():
return $default(_that.id,_that.serverId,_that.name,_that.protocol,_that.host,_that.port,_that.username,_that.password,_that.domain,_that.viewOnly,_that.shared,_that.trustedCertSha256);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String serverId,  String name,  RemoteDesktopProtocol protocol,  String host,  int port,  String? username,  String? password,  String? domain,  bool viewOnly,  bool shared,  String? trustedCertSha256)?  $default,) {final _that = this;
switch (_that) {
case _RemoteDesktopProfile() when $default != null:
return $default(_that.id,_that.serverId,_that.name,_that.protocol,_that.host,_that.port,_that.username,_that.password,_that.domain,_that.viewOnly,_that.shared,_that.trustedCertSha256);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RemoteDesktopProfile extends RemoteDesktopProfile {
  const _RemoteDesktopProfile({required this.id, required this.serverId, required this.name, required this.protocol, this.host = '127.0.0.1', required this.port, this.username, this.password, this.domain, this.viewOnly = false, this.shared = true, this.trustedCertSha256}): super._();
  factory _RemoteDesktopProfile.fromJson(Map<String, dynamic> json) => _$RemoteDesktopProfileFromJson(json);

@override final  String id;
@override final  String serverId;
@override final  String name;
@override final  RemoteDesktopProtocol protocol;
@override@JsonKey() final  String host;
@override final  int port;
@override final  String? username;
@override final  String? password;
@override final  String? domain;
@override@JsonKey() final  bool viewOnly;
@override@JsonKey() final  bool shared;
@override final  String? trustedCertSha256;

/// Create a copy of RemoteDesktopProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RemoteDesktopProfileCopyWith<_RemoteDesktopProfile> get copyWith => __$RemoteDesktopProfileCopyWithImpl<_RemoteDesktopProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RemoteDesktopProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RemoteDesktopProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.name, name) || other.name == name)&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.username, username) || other.username == username)&&(identical(other.password, password) || other.password == password)&&(identical(other.domain, domain) || other.domain == domain)&&(identical(other.viewOnly, viewOnly) || other.viewOnly == viewOnly)&&(identical(other.shared, shared) || other.shared == shared)&&(identical(other.trustedCertSha256, trustedCertSha256) || other.trustedCertSha256 == trustedCertSha256));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,serverId,name,protocol,host,port,username,password,domain,viewOnly,shared,trustedCertSha256);



}

/// @nodoc
abstract mixin class _$RemoteDesktopProfileCopyWith<$Res> implements $RemoteDesktopProfileCopyWith<$Res> {
  factory _$RemoteDesktopProfileCopyWith(_RemoteDesktopProfile value, $Res Function(_RemoteDesktopProfile) _then) = __$RemoteDesktopProfileCopyWithImpl;
@override @useResult
$Res call({
 String id, String serverId, String name, RemoteDesktopProtocol protocol, String host, int port, String? username, String? password, String? domain, bool viewOnly, bool shared, String? trustedCertSha256
});




}
/// @nodoc
class __$RemoteDesktopProfileCopyWithImpl<$Res>
    implements _$RemoteDesktopProfileCopyWith<$Res> {
  __$RemoteDesktopProfileCopyWithImpl(this._self, this._then);

  final _RemoteDesktopProfile _self;
  final $Res Function(_RemoteDesktopProfile) _then;

/// Create a copy of RemoteDesktopProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? serverId = null,Object? name = null,Object? protocol = null,Object? host = null,Object? port = null,Object? username = freezed,Object? password = freezed,Object? domain = freezed,Object? viewOnly = null,Object? shared = null,Object? trustedCertSha256 = freezed,}) {
  return _then(_RemoteDesktopProfile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as RemoteDesktopProtocol,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,password: freezed == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String?,domain: freezed == domain ? _self.domain : domain // ignore: cast_nullable_to_non_nullable
as String?,viewOnly: null == viewOnly ? _self.viewOnly : viewOnly // ignore: cast_nullable_to_non_nullable
as bool,shared: null == shared ? _self.shared : shared // ignore: cast_nullable_to_non_nullable
as bool,trustedCertSha256: freezed == trustedCertSha256 ? _self.trustedCertSha256 : trustedCertSha256 // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
