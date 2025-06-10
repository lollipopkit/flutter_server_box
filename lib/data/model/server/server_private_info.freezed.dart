// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'server_private_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Spi {

 String get name; String get ip; int get port; String get user; String? get pwd;/// [id] of private key
@JsonKey(name: 'pubKeyId') String? get keyId; List<String>? get tags; String? get alterUrl; bool get autoConnect;/// [id] of the jump server
 String? get jumpId; ServerCustom? get custom; WakeOnLanCfg? get wolCfg;/// It only applies to SSH terminal.
 Map<String, String>? get envs;@JsonKey(fromJson: Spi.parseId) String get id;
/// Create a copy of Spi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpiCopyWith<Spi> get copyWith => _$SpiCopyWithImpl<Spi>(this as Spi, _$identity);

  /// Serializes this Spi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Spi&&(identical(other.name, name) || other.name == name)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.port, port) || other.port == port)&&(identical(other.user, user) || other.user == user)&&(identical(other.pwd, pwd) || other.pwd == pwd)&&(identical(other.keyId, keyId) || other.keyId == keyId)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.alterUrl, alterUrl) || other.alterUrl == alterUrl)&&(identical(other.autoConnect, autoConnect) || other.autoConnect == autoConnect)&&(identical(other.jumpId, jumpId) || other.jumpId == jumpId)&&(identical(other.custom, custom) || other.custom == custom)&&(identical(other.wolCfg, wolCfg) || other.wolCfg == wolCfg)&&const DeepCollectionEquality().equals(other.envs, envs)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,ip,port,user,pwd,keyId,const DeepCollectionEquality().hash(tags),alterUrl,autoConnect,jumpId,custom,wolCfg,const DeepCollectionEquality().hash(envs),id);



}

/// @nodoc
abstract mixin class $SpiCopyWith<$Res>  {
  factory $SpiCopyWith(Spi value, $Res Function(Spi) _then) = _$SpiCopyWithImpl;
@useResult
$Res call({
 String name, String ip, int port, String user, String? pwd,@JsonKey(name: 'pubKeyId') String? keyId, List<String>? tags, String? alterUrl, bool autoConnect, String? jumpId, ServerCustom? custom, WakeOnLanCfg? wolCfg, Map<String, String>? envs,@JsonKey(fromJson: Spi.parseId) String id
});




}
/// @nodoc
class _$SpiCopyWithImpl<$Res>
    implements $SpiCopyWith<$Res> {
  _$SpiCopyWithImpl(this._self, this._then);

  final Spi _self;
  final $Res Function(Spi) _then;

/// Create a copy of Spi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? ip = null,Object? port = null,Object? user = null,Object? pwd = freezed,Object? keyId = freezed,Object? tags = freezed,Object? alterUrl = freezed,Object? autoConnect = null,Object? jumpId = freezed,Object? custom = freezed,Object? wolCfg = freezed,Object? envs = freezed,Object? id = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as String,pwd: freezed == pwd ? _self.pwd : pwd // ignore: cast_nullable_to_non_nullable
as String?,keyId: freezed == keyId ? _self.keyId : keyId // ignore: cast_nullable_to_non_nullable
as String?,tags: freezed == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>?,alterUrl: freezed == alterUrl ? _self.alterUrl : alterUrl // ignore: cast_nullable_to_non_nullable
as String?,autoConnect: null == autoConnect ? _self.autoConnect : autoConnect // ignore: cast_nullable_to_non_nullable
as bool,jumpId: freezed == jumpId ? _self.jumpId : jumpId // ignore: cast_nullable_to_non_nullable
as String?,custom: freezed == custom ? _self.custom : custom // ignore: cast_nullable_to_non_nullable
as ServerCustom?,wolCfg: freezed == wolCfg ? _self.wolCfg : wolCfg // ignore: cast_nullable_to_non_nullable
as WakeOnLanCfg?,envs: freezed == envs ? _self.envs : envs // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// @nodoc

@JsonSerializable(includeIfNull: false)
class _Spi extends Spi {
  const _Spi({required this.name, required this.ip, required this.port, required this.user, this.pwd, @JsonKey(name: 'pubKeyId') this.keyId, final  List<String>? tags, this.alterUrl, this.autoConnect = true, this.jumpId, this.custom, this.wolCfg, final  Map<String, String>? envs, @JsonKey(fromJson: Spi.parseId) this.id = ''}): _tags = tags,_envs = envs,super._();
  factory _Spi.fromJson(Map<String, dynamic> json) => _$SpiFromJson(json);

@override final  String name;
@override final  String ip;
@override final  int port;
@override final  String user;
@override final  String? pwd;
/// [id] of private key
@override@JsonKey(name: 'pubKeyId') final  String? keyId;
 final  List<String>? _tags;
@override List<String>? get tags {
  final value = _tags;
  if (value == null) return null;
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? alterUrl;
@override@JsonKey() final  bool autoConnect;
/// [id] of the jump server
@override final  String? jumpId;
@override final  ServerCustom? custom;
@override final  WakeOnLanCfg? wolCfg;
/// It only applies to SSH terminal.
 final  Map<String, String>? _envs;
/// It only applies to SSH terminal.
@override Map<String, String>? get envs {
  final value = _envs;
  if (value == null) return null;
  if (_envs is EqualUnmodifiableMapView) return _envs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(fromJson: Spi.parseId) final  String id;

/// Create a copy of Spi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpiCopyWith<_Spi> get copyWith => __$SpiCopyWithImpl<_Spi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SpiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Spi&&(identical(other.name, name) || other.name == name)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.port, port) || other.port == port)&&(identical(other.user, user) || other.user == user)&&(identical(other.pwd, pwd) || other.pwd == pwd)&&(identical(other.keyId, keyId) || other.keyId == keyId)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.alterUrl, alterUrl) || other.alterUrl == alterUrl)&&(identical(other.autoConnect, autoConnect) || other.autoConnect == autoConnect)&&(identical(other.jumpId, jumpId) || other.jumpId == jumpId)&&(identical(other.custom, custom) || other.custom == custom)&&(identical(other.wolCfg, wolCfg) || other.wolCfg == wolCfg)&&const DeepCollectionEquality().equals(other._envs, _envs)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,ip,port,user,pwd,keyId,const DeepCollectionEquality().hash(_tags),alterUrl,autoConnect,jumpId,custom,wolCfg,const DeepCollectionEquality().hash(_envs),id);



}

/// @nodoc
abstract mixin class _$SpiCopyWith<$Res> implements $SpiCopyWith<$Res> {
  factory _$SpiCopyWith(_Spi value, $Res Function(_Spi) _then) = __$SpiCopyWithImpl;
@override @useResult
$Res call({
 String name, String ip, int port, String user, String? pwd,@JsonKey(name: 'pubKeyId') String? keyId, List<String>? tags, String? alterUrl, bool autoConnect, String? jumpId, ServerCustom? custom, WakeOnLanCfg? wolCfg, Map<String, String>? envs,@JsonKey(fromJson: Spi.parseId) String id
});




}
/// @nodoc
class __$SpiCopyWithImpl<$Res>
    implements _$SpiCopyWith<$Res> {
  __$SpiCopyWithImpl(this._self, this._then);

  final _Spi _self;
  final $Res Function(_Spi) _then;

/// Create a copy of Spi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? ip = null,Object? port = null,Object? user = null,Object? pwd = freezed,Object? keyId = freezed,Object? tags = freezed,Object? alterUrl = freezed,Object? autoConnect = null,Object? jumpId = freezed,Object? custom = freezed,Object? wolCfg = freezed,Object? envs = freezed,Object? id = null,}) {
  return _then(_Spi(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as String,pwd: freezed == pwd ? _self.pwd : pwd // ignore: cast_nullable_to_non_nullable
as String?,keyId: freezed == keyId ? _self.keyId : keyId // ignore: cast_nullable_to_non_nullable
as String?,tags: freezed == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>?,alterUrl: freezed == alterUrl ? _self.alterUrl : alterUrl // ignore: cast_nullable_to_non_nullable
as String?,autoConnect: null == autoConnect ? _self.autoConnect : autoConnect // ignore: cast_nullable_to_non_nullable
as bool,jumpId: freezed == jumpId ? _self.jumpId : jumpId // ignore: cast_nullable_to_non_nullable
as String?,custom: freezed == custom ? _self.custom : custom // ignore: cast_nullable_to_non_nullable
as ServerCustom?,wolCfg: freezed == wolCfg ? _self.wolCfg : wolCfg // ignore: cast_nullable_to_non_nullable
as WakeOnLanCfg?,envs: freezed == envs ? _self._envs : envs // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
