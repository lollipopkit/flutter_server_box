// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'port_forward.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PortForwardConfig {

 String get id; String get serverId; String get name; PortForwardType get type; String? get localHost; int get localPort; String? get remoteHost; int? get remotePort;
/// Create a copy of PortForwardConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PortForwardConfigCopyWith<PortForwardConfig> get copyWith => _$PortForwardConfigCopyWithImpl<PortForwardConfig>(this as PortForwardConfig, _$identity);

  /// Serializes this PortForwardConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PortForwardConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.localHost, localHost) || other.localHost == localHost)&&(identical(other.localPort, localPort) || other.localPort == localPort)&&(identical(other.remoteHost, remoteHost) || other.remoteHost == remoteHost)&&(identical(other.remotePort, remotePort) || other.remotePort == remotePort));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,serverId,name,type,localHost,localPort,remoteHost,remotePort);

@override
String toString() {
  return 'PortForwardConfig(id: $id, serverId: $serverId, name: $name, type: $type, localHost: $localHost, localPort: $localPort, remoteHost: $remoteHost, remotePort: $remotePort)';
}


}

/// @nodoc
abstract mixin class $PortForwardConfigCopyWith<$Res>  {
  factory $PortForwardConfigCopyWith(PortForwardConfig value, $Res Function(PortForwardConfig) _then) = _$PortForwardConfigCopyWithImpl;
@useResult
$Res call({
 String id, String serverId, String name, PortForwardType type, String? localHost, int localPort, String? remoteHost, int? remotePort
});




}
/// @nodoc
class _$PortForwardConfigCopyWithImpl<$Res>
    implements $PortForwardConfigCopyWith<$Res> {
  _$PortForwardConfigCopyWithImpl(this._self, this._then);

  final PortForwardConfig _self;
  final $Res Function(PortForwardConfig) _then;

/// Create a copy of PortForwardConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? serverId = null,Object? name = null,Object? type = null,Object? localHost = freezed,Object? localPort = null,Object? remoteHost = freezed,Object? remotePort = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as PortForwardType,localHost: freezed == localHost ? _self.localHost : localHost // ignore: cast_nullable_to_non_nullable
as String?,localPort: null == localPort ? _self.localPort : localPort // ignore: cast_nullable_to_non_nullable
as int,remoteHost: freezed == remoteHost ? _self.remoteHost : remoteHost // ignore: cast_nullable_to_non_nullable
as String?,remotePort: freezed == remotePort ? _self.remotePort : remotePort // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [PortForwardConfig].
extension PortForwardConfigPatterns on PortForwardConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PortForwardConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PortForwardConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PortForwardConfig value)  $default,){
final _that = this;
switch (_that) {
case _PortForwardConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PortForwardConfig value)?  $default,){
final _that = this;
switch (_that) {
case _PortForwardConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String serverId,  String name,  PortForwardType type,  String? localHost,  int localPort,  String? remoteHost,  int? remotePort)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PortForwardConfig() when $default != null:
return $default(_that.id,_that.serverId,_that.name,_that.type,_that.localHost,_that.localPort,_that.remoteHost,_that.remotePort);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String serverId,  String name,  PortForwardType type,  String? localHost,  int localPort,  String? remoteHost,  int? remotePort)  $default,) {final _that = this;
switch (_that) {
case _PortForwardConfig():
return $default(_that.id,_that.serverId,_that.name,_that.type,_that.localHost,_that.localPort,_that.remoteHost,_that.remotePort);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String serverId,  String name,  PortForwardType type,  String? localHost,  int localPort,  String? remoteHost,  int? remotePort)?  $default,) {final _that = this;
switch (_that) {
case _PortForwardConfig() when $default != null:
return $default(_that.id,_that.serverId,_that.name,_that.type,_that.localHost,_that.localPort,_that.remoteHost,_that.remotePort);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PortForwardConfig extends PortForwardConfig {
  const _PortForwardConfig({required this.id, required this.serverId, required this.name, required this.type, this.localHost, this.localPort = 0, this.remoteHost, this.remotePort}): super._();
  factory _PortForwardConfig.fromJson(Map<String, dynamic> json) => _$PortForwardConfigFromJson(json);

@override final  String id;
@override final  String serverId;
@override final  String name;
@override final  PortForwardType type;
@override final  String? localHost;
@override@JsonKey() final  int localPort;
@override final  String? remoteHost;
@override final  int? remotePort;

/// Create a copy of PortForwardConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PortForwardConfigCopyWith<_PortForwardConfig> get copyWith => __$PortForwardConfigCopyWithImpl<_PortForwardConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PortForwardConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PortForwardConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.localHost, localHost) || other.localHost == localHost)&&(identical(other.localPort, localPort) || other.localPort == localPort)&&(identical(other.remoteHost, remoteHost) || other.remoteHost == remoteHost)&&(identical(other.remotePort, remotePort) || other.remotePort == remotePort));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,serverId,name,type,localHost,localPort,remoteHost,remotePort);

@override
String toString() {
  return 'PortForwardConfig(id: $id, serverId: $serverId, name: $name, type: $type, localHost: $localHost, localPort: $localPort, remoteHost: $remoteHost, remotePort: $remotePort)';
}


}

/// @nodoc
abstract mixin class _$PortForwardConfigCopyWith<$Res> implements $PortForwardConfigCopyWith<$Res> {
  factory _$PortForwardConfigCopyWith(_PortForwardConfig value, $Res Function(_PortForwardConfig) _then) = __$PortForwardConfigCopyWithImpl;
@override @useResult
$Res call({
 String id, String serverId, String name, PortForwardType type, String? localHost, int localPort, String? remoteHost, int? remotePort
});




}
/// @nodoc
class __$PortForwardConfigCopyWithImpl<$Res>
    implements _$PortForwardConfigCopyWith<$Res> {
  __$PortForwardConfigCopyWithImpl(this._self, this._then);

  final _PortForwardConfig _self;
  final $Res Function(_PortForwardConfig) _then;

/// Create a copy of PortForwardConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? serverId = null,Object? name = null,Object? type = null,Object? localHost = freezed,Object? localPort = null,Object? remoteHost = freezed,Object? remotePort = freezed,}) {
  return _then(_PortForwardConfig(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as PortForwardType,localHost: freezed == localHost ? _self.localHost : localHost // ignore: cast_nullable_to_non_nullable
as String?,localPort: null == localPort ? _self.localPort : localPort // ignore: cast_nullable_to_non_nullable
as int,remoteHost: freezed == remoteHost ? _self.remoteHost : remoteHost // ignore: cast_nullable_to_non_nullable
as String?,remotePort: freezed == remotePort ? _self.remotePort : remotePort // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$PortForwardState {

 String get serverId; List<PortForwardConfig> get configs; Map<String, PortForwardStatus> get activeForwards;
/// Create a copy of PortForwardState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PortForwardStateCopyWith<PortForwardState> get copyWith => _$PortForwardStateCopyWithImpl<PortForwardState>(this as PortForwardState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PortForwardState&&(identical(other.serverId, serverId) || other.serverId == serverId)&&const DeepCollectionEquality().equals(other.configs, configs)&&const DeepCollectionEquality().equals(other.activeForwards, activeForwards));
}


@override
int get hashCode => Object.hash(runtimeType,serverId,const DeepCollectionEquality().hash(configs),const DeepCollectionEquality().hash(activeForwards));

@override
String toString() {
  return 'PortForwardState(serverId: $serverId, configs: $configs, activeForwards: $activeForwards)';
}


}

/// @nodoc
abstract mixin class $PortForwardStateCopyWith<$Res>  {
  factory $PortForwardStateCopyWith(PortForwardState value, $Res Function(PortForwardState) _then) = _$PortForwardStateCopyWithImpl;
@useResult
$Res call({
 String serverId, List<PortForwardConfig> configs, Map<String, PortForwardStatus> activeForwards
});




}
/// @nodoc
class _$PortForwardStateCopyWithImpl<$Res>
    implements $PortForwardStateCopyWith<$Res> {
  _$PortForwardStateCopyWithImpl(this._self, this._then);

  final PortForwardState _self;
  final $Res Function(PortForwardState) _then;

/// Create a copy of PortForwardState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serverId = null,Object? configs = null,Object? activeForwards = null,}) {
  return _then(_self.copyWith(
serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,configs: null == configs ? _self.configs : configs // ignore: cast_nullable_to_non_nullable
as List<PortForwardConfig>,activeForwards: null == activeForwards ? _self.activeForwards : activeForwards // ignore: cast_nullable_to_non_nullable
as Map<String, PortForwardStatus>,
  ));
}

}


/// Adds pattern-matching-related methods to [PortForwardState].
extension PortForwardStatePatterns on PortForwardState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PortForwardState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PortForwardState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PortForwardState value)  $default,){
final _that = this;
switch (_that) {
case _PortForwardState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PortForwardState value)?  $default,){
final _that = this;
switch (_that) {
case _PortForwardState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String serverId,  List<PortForwardConfig> configs,  Map<String, PortForwardStatus> activeForwards)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PortForwardState() when $default != null:
return $default(_that.serverId,_that.configs,_that.activeForwards);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String serverId,  List<PortForwardConfig> configs,  Map<String, PortForwardStatus> activeForwards)  $default,) {final _that = this;
switch (_that) {
case _PortForwardState():
return $default(_that.serverId,_that.configs,_that.activeForwards);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String serverId,  List<PortForwardConfig> configs,  Map<String, PortForwardStatus> activeForwards)?  $default,) {final _that = this;
switch (_that) {
case _PortForwardState() when $default != null:
return $default(_that.serverId,_that.configs,_that.activeForwards);case _:
  return null;

}
}

}

/// @nodoc


class _PortForwardState implements PortForwardState {
  const _PortForwardState({required this.serverId, final  List<PortForwardConfig> configs = const [], final  Map<String, PortForwardStatus> activeForwards = const {}}): _configs = configs,_activeForwards = activeForwards;
  

@override final  String serverId;
 final  List<PortForwardConfig> _configs;
@override@JsonKey() List<PortForwardConfig> get configs {
  if (_configs is EqualUnmodifiableListView) return _configs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_configs);
}

 final  Map<String, PortForwardStatus> _activeForwards;
@override@JsonKey() Map<String, PortForwardStatus> get activeForwards {
  if (_activeForwards is EqualUnmodifiableMapView) return _activeForwards;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_activeForwards);
}


/// Create a copy of PortForwardState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PortForwardStateCopyWith<_PortForwardState> get copyWith => __$PortForwardStateCopyWithImpl<_PortForwardState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PortForwardState&&(identical(other.serverId, serverId) || other.serverId == serverId)&&const DeepCollectionEquality().equals(other._configs, _configs)&&const DeepCollectionEquality().equals(other._activeForwards, _activeForwards));
}


@override
int get hashCode => Object.hash(runtimeType,serverId,const DeepCollectionEquality().hash(_configs),const DeepCollectionEquality().hash(_activeForwards));

@override
String toString() {
  return 'PortForwardState(serverId: $serverId, configs: $configs, activeForwards: $activeForwards)';
}


}

/// @nodoc
abstract mixin class _$PortForwardStateCopyWith<$Res> implements $PortForwardStateCopyWith<$Res> {
  factory _$PortForwardStateCopyWith(_PortForwardState value, $Res Function(_PortForwardState) _then) = __$PortForwardStateCopyWithImpl;
@override @useResult
$Res call({
 String serverId, List<PortForwardConfig> configs, Map<String, PortForwardStatus> activeForwards
});




}
/// @nodoc
class __$PortForwardStateCopyWithImpl<$Res>
    implements _$PortForwardStateCopyWith<$Res> {
  __$PortForwardStateCopyWithImpl(this._self, this._then);

  final _PortForwardState _self;
  final $Res Function(_PortForwardState) _then;

/// Create a copy of PortForwardState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serverId = null,Object? configs = null,Object? activeForwards = null,}) {
  return _then(_PortForwardState(
serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,configs: null == configs ? _self._configs : configs // ignore: cast_nullable_to_non_nullable
as List<PortForwardConfig>,activeForwards: null == activeForwards ? _self._activeForwards : activeForwards // ignore: cast_nullable_to_non_nullable
as Map<String, PortForwardStatus>,
  ));
}


}

// dart format on
