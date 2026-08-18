// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
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

 String get name;/// How to reach this server over SSH, or null if it isn't configured for
/// SSH at all. A peer of [monitorHttp] — see `ServerConnectCredential`.
///
/// Nested rather than flat (as `ip`/`port`/`user`/... used to be) so that
/// "has SSH" is expressible. While they were flat and non-nullable, a
/// monitor-only server had to invent an address and a user named
/// `monitor` to satisfy them.
 SshCredential? get ssh;/// Reach this server via a `monitor` instance's HTTP API. A peer of
/// [ssh]; a server may carry either, both, or neither.
 MonitorHttpCredential? get monitorHttp; List<String>? get tags; bool get autoConnect; ServerCustom? get custom; WakeOnLanCfg? get wolCfg;/// It only applies to SSH terminal.
 Map<String, String>? get envs;@JsonKey(fromJson: Spi.parseId) String get id;/// Custom system type (unix or windows). If set, skip auto-detection.
@JsonKey(includeIfNull: false) SystemType? get customSystemType;/// Disabled command types for this server
@JsonKey(includeIfNull: false) List<String>? get disabledCmdTypes;
/// Create a copy of Spi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpiCopyWith<Spi> get copyWith => _$SpiCopyWithImpl<Spi>(this as Spi, _$identity);

  /// Serializes this Spi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Spi&&(identical(other.name, name) || other.name == name)&&(identical(other.ssh, ssh) || other.ssh == ssh)&&(identical(other.monitorHttp, monitorHttp) || other.monitorHttp == monitorHttp)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.autoConnect, autoConnect) || other.autoConnect == autoConnect)&&(identical(other.custom, custom) || other.custom == custom)&&(identical(other.wolCfg, wolCfg) || other.wolCfg == wolCfg)&&const DeepCollectionEquality().equals(other.envs, envs)&&(identical(other.id, id) || other.id == id)&&(identical(other.customSystemType, customSystemType) || other.customSystemType == customSystemType)&&const DeepCollectionEquality().equals(other.disabledCmdTypes, disabledCmdTypes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,ssh,monitorHttp,const DeepCollectionEquality().hash(tags),autoConnect,custom,wolCfg,const DeepCollectionEquality().hash(envs),id,customSystemType,const DeepCollectionEquality().hash(disabledCmdTypes));



}

/// @nodoc
abstract mixin class $SpiCopyWith<$Res>  {
  factory $SpiCopyWith(Spi value, $Res Function(Spi) _then) = _$SpiCopyWithImpl;
@useResult
$Res call({
 String name, SshCredential? ssh, MonitorHttpCredential? monitorHttp, List<String>? tags, bool autoConnect, ServerCustom? custom, WakeOnLanCfg? wolCfg, Map<String, String>? envs,@JsonKey(fromJson: Spi.parseId) String id,@JsonKey(includeIfNull: false) SystemType? customSystemType,@JsonKey(includeIfNull: false) List<String>? disabledCmdTypes
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
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? ssh = freezed,Object? monitorHttp = freezed,Object? tags = freezed,Object? autoConnect = null,Object? custom = freezed,Object? wolCfg = freezed,Object? envs = freezed,Object? id = null,Object? customSystemType = freezed,Object? disabledCmdTypes = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,ssh: freezed == ssh ? _self.ssh : ssh // ignore: cast_nullable_to_non_nullable
as SshCredential?,monitorHttp: freezed == monitorHttp ? _self.monitorHttp : monitorHttp // ignore: cast_nullable_to_non_nullable
as MonitorHttpCredential?,tags: freezed == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>?,autoConnect: null == autoConnect ? _self.autoConnect : autoConnect // ignore: cast_nullable_to_non_nullable
as bool,custom: freezed == custom ? _self.custom : custom // ignore: cast_nullable_to_non_nullable
as ServerCustom?,wolCfg: freezed == wolCfg ? _self.wolCfg : wolCfg // ignore: cast_nullable_to_non_nullable
as WakeOnLanCfg?,envs: freezed == envs ? _self.envs : envs // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,customSystemType: freezed == customSystemType ? _self.customSystemType : customSystemType // ignore: cast_nullable_to_non_nullable
as SystemType?,disabledCmdTypes: freezed == disabledCmdTypes ? _self.disabledCmdTypes : disabledCmdTypes // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}

}


/// Adds pattern-matching-related methods to [Spi].
extension SpiPatterns on Spi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Spi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Spi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Spi value)  $default,){
final _that = this;
switch (_that) {
case _Spi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Spi value)?  $default,){
final _that = this;
switch (_that) {
case _Spi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  SshCredential? ssh,  MonitorHttpCredential? monitorHttp,  List<String>? tags,  bool autoConnect,  ServerCustom? custom,  WakeOnLanCfg? wolCfg,  Map<String, String>? envs, @JsonKey(fromJson: Spi.parseId)  String id, @JsonKey(includeIfNull: false)  SystemType? customSystemType, @JsonKey(includeIfNull: false)  List<String>? disabledCmdTypes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Spi() when $default != null:
return $default(_that.name,_that.ssh,_that.monitorHttp,_that.tags,_that.autoConnect,_that.custom,_that.wolCfg,_that.envs,_that.id,_that.customSystemType,_that.disabledCmdTypes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  SshCredential? ssh,  MonitorHttpCredential? monitorHttp,  List<String>? tags,  bool autoConnect,  ServerCustom? custom,  WakeOnLanCfg? wolCfg,  Map<String, String>? envs, @JsonKey(fromJson: Spi.parseId)  String id, @JsonKey(includeIfNull: false)  SystemType? customSystemType, @JsonKey(includeIfNull: false)  List<String>? disabledCmdTypes)  $default,) {final _that = this;
switch (_that) {
case _Spi():
return $default(_that.name,_that.ssh,_that.monitorHttp,_that.tags,_that.autoConnect,_that.custom,_that.wolCfg,_that.envs,_that.id,_that.customSystemType,_that.disabledCmdTypes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  SshCredential? ssh,  MonitorHttpCredential? monitorHttp,  List<String>? tags,  bool autoConnect,  ServerCustom? custom,  WakeOnLanCfg? wolCfg,  Map<String, String>? envs, @JsonKey(fromJson: Spi.parseId)  String id, @JsonKey(includeIfNull: false)  SystemType? customSystemType, @JsonKey(includeIfNull: false)  List<String>? disabledCmdTypes)?  $default,) {final _that = this;
switch (_that) {
case _Spi() when $default != null:
return $default(_that.name,_that.ssh,_that.monitorHttp,_that.tags,_that.autoConnect,_that.custom,_that.wolCfg,_that.envs,_that.id,_that.customSystemType,_that.disabledCmdTypes);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _Spi extends Spi {
  const _Spi({required this.name, this.ssh, this.monitorHttp, final  List<String>? tags, this.autoConnect = true, this.custom, this.wolCfg, final  Map<String, String>? envs, @JsonKey(fromJson: Spi.parseId) this.id = '', @JsonKey(includeIfNull: false) this.customSystemType, @JsonKey(includeIfNull: false) final  List<String>? disabledCmdTypes}): _tags = tags,_envs = envs,_disabledCmdTypes = disabledCmdTypes,super._();
  factory _Spi.fromJson(Map<String, dynamic> json) => _$SpiFromJson(json);

@override final  String name;
/// How to reach this server over SSH, or null if it isn't configured for
/// SSH at all. A peer of [monitorHttp] — see `ServerConnectCredential`.
///
/// Nested rather than flat (as `ip`/`port`/`user`/... used to be) so that
/// "has SSH" is expressible. While they were flat and non-nullable, a
/// monitor-only server had to invent an address and a user named
/// `monitor` to satisfy them.
@override final  SshCredential? ssh;
/// Reach this server via a `monitor` instance's HTTP API. A peer of
/// [ssh]; a server may carry either, both, or neither.
@override final  MonitorHttpCredential? monitorHttp;
 final  List<String>? _tags;
@override List<String>? get tags {
  final value = _tags;
  if (value == null) return null;
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey() final  bool autoConnect;
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
/// Custom system type (unix or windows). If set, skip auto-detection.
@override@JsonKey(includeIfNull: false) final  SystemType? customSystemType;
/// Disabled command types for this server
 final  List<String>? _disabledCmdTypes;
/// Disabled command types for this server
@override@JsonKey(includeIfNull: false) List<String>? get disabledCmdTypes {
  final value = _disabledCmdTypes;
  if (value == null) return null;
  if (_disabledCmdTypes is EqualUnmodifiableListView) return _disabledCmdTypes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Spi&&(identical(other.name, name) || other.name == name)&&(identical(other.ssh, ssh) || other.ssh == ssh)&&(identical(other.monitorHttp, monitorHttp) || other.monitorHttp == monitorHttp)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.autoConnect, autoConnect) || other.autoConnect == autoConnect)&&(identical(other.custom, custom) || other.custom == custom)&&(identical(other.wolCfg, wolCfg) || other.wolCfg == wolCfg)&&const DeepCollectionEquality().equals(other._envs, _envs)&&(identical(other.id, id) || other.id == id)&&(identical(other.customSystemType, customSystemType) || other.customSystemType == customSystemType)&&const DeepCollectionEquality().equals(other._disabledCmdTypes, _disabledCmdTypes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,ssh,monitorHttp,const DeepCollectionEquality().hash(_tags),autoConnect,custom,wolCfg,const DeepCollectionEquality().hash(_envs),id,customSystemType,const DeepCollectionEquality().hash(_disabledCmdTypes));



}

/// @nodoc
abstract mixin class _$SpiCopyWith<$Res> implements $SpiCopyWith<$Res> {
  factory _$SpiCopyWith(_Spi value, $Res Function(_Spi) _then) = __$SpiCopyWithImpl;
@override @useResult
$Res call({
 String name, SshCredential? ssh, MonitorHttpCredential? monitorHttp, List<String>? tags, bool autoConnect, ServerCustom? custom, WakeOnLanCfg? wolCfg, Map<String, String>? envs,@JsonKey(fromJson: Spi.parseId) String id,@JsonKey(includeIfNull: false) SystemType? customSystemType,@JsonKey(includeIfNull: false) List<String>? disabledCmdTypes
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
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? ssh = freezed,Object? monitorHttp = freezed,Object? tags = freezed,Object? autoConnect = null,Object? custom = freezed,Object? wolCfg = freezed,Object? envs = freezed,Object? id = null,Object? customSystemType = freezed,Object? disabledCmdTypes = freezed,}) {
  return _then(_Spi(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,ssh: freezed == ssh ? _self.ssh : ssh // ignore: cast_nullable_to_non_nullable
as SshCredential?,monitorHttp: freezed == monitorHttp ? _self.monitorHttp : monitorHttp // ignore: cast_nullable_to_non_nullable
as MonitorHttpCredential?,tags: freezed == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>?,autoConnect: null == autoConnect ? _self.autoConnect : autoConnect // ignore: cast_nullable_to_non_nullable
as bool,custom: freezed == custom ? _self.custom : custom // ignore: cast_nullable_to_non_nullable
as ServerCustom?,wolCfg: freezed == wolCfg ? _self.wolCfg : wolCfg // ignore: cast_nullable_to_non_nullable
as WakeOnLanCfg?,envs: freezed == envs ? _self._envs : envs // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,customSystemType: freezed == customSystemType ? _self.customSystemType : customSystemType // ignore: cast_nullable_to_non_nullable
as SystemType?,disabledCmdTypes: freezed == disabledCmdTypes ? _self._disabledCmdTypes : disabledCmdTypes // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}


}

// dart format on
