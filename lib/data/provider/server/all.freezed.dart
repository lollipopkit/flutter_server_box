// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'all.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ServersState {

 Map<String, Spi> get servers; List<String> get serverOrder; Set<String> get tags; Set<String> get manualDisconnectedIds; Timer? get autoRefreshTimer;
/// Create a copy of ServersState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServersStateCopyWith<ServersState> get copyWith => _$ServersStateCopyWithImpl<ServersState>(this as ServersState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServersState&&const DeepCollectionEquality().equals(other.servers, servers)&&const DeepCollectionEquality().equals(other.serverOrder, serverOrder)&&const DeepCollectionEquality().equals(other.tags, tags)&&const DeepCollectionEquality().equals(other.manualDisconnectedIds, manualDisconnectedIds)&&(identical(other.autoRefreshTimer, autoRefreshTimer) || other.autoRefreshTimer == autoRefreshTimer));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(servers),const DeepCollectionEquality().hash(serverOrder),const DeepCollectionEquality().hash(tags),const DeepCollectionEquality().hash(manualDisconnectedIds),autoRefreshTimer);

@override
String toString() {
  return 'ServersState(servers: $servers, serverOrder: $serverOrder, tags: $tags, manualDisconnectedIds: $manualDisconnectedIds, autoRefreshTimer: $autoRefreshTimer)';
}


}

/// @nodoc
abstract mixin class $ServersStateCopyWith<$Res>  {
  factory $ServersStateCopyWith(ServersState value, $Res Function(ServersState) _then) = _$ServersStateCopyWithImpl;
@useResult
$Res call({
 Map<String, Spi> servers, List<String> serverOrder, Set<String> tags, Set<String> manualDisconnectedIds, Timer? autoRefreshTimer
});




}
/// @nodoc
class _$ServersStateCopyWithImpl<$Res>
    implements $ServersStateCopyWith<$Res> {
  _$ServersStateCopyWithImpl(this._self, this._then);

  final ServersState _self;
  final $Res Function(ServersState) _then;

/// Create a copy of ServersState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? servers = null,Object? serverOrder = null,Object? tags = null,Object? manualDisconnectedIds = null,Object? autoRefreshTimer = freezed,}) {
  return _then(_self.copyWith(
servers: null == servers ? _self.servers : servers // ignore: cast_nullable_to_non_nullable
as Map<String, Spi>,serverOrder: null == serverOrder ? _self.serverOrder : serverOrder // ignore: cast_nullable_to_non_nullable
as List<String>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as Set<String>,manualDisconnectedIds: null == manualDisconnectedIds ? _self.manualDisconnectedIds : manualDisconnectedIds // ignore: cast_nullable_to_non_nullable
as Set<String>,autoRefreshTimer: freezed == autoRefreshTimer ? _self.autoRefreshTimer : autoRefreshTimer // ignore: cast_nullable_to_non_nullable
as Timer?,
  ));
}

}


/// Adds pattern-matching-related methods to [ServersState].
extension ServersStatePatterns on ServersState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServersState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServersState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServersState value)  $default,){
final _that = this;
switch (_that) {
case _ServersState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServersState value)?  $default,){
final _that = this;
switch (_that) {
case _ServersState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, Spi> servers,  List<String> serverOrder,  Set<String> tags,  Set<String> manualDisconnectedIds,  Timer? autoRefreshTimer)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServersState() when $default != null:
return $default(_that.servers,_that.serverOrder,_that.tags,_that.manualDisconnectedIds,_that.autoRefreshTimer);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, Spi> servers,  List<String> serverOrder,  Set<String> tags,  Set<String> manualDisconnectedIds,  Timer? autoRefreshTimer)  $default,) {final _that = this;
switch (_that) {
case _ServersState():
return $default(_that.servers,_that.serverOrder,_that.tags,_that.manualDisconnectedIds,_that.autoRefreshTimer);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, Spi> servers,  List<String> serverOrder,  Set<String> tags,  Set<String> manualDisconnectedIds,  Timer? autoRefreshTimer)?  $default,) {final _that = this;
switch (_that) {
case _ServersState() when $default != null:
return $default(_that.servers,_that.serverOrder,_that.tags,_that.manualDisconnectedIds,_that.autoRefreshTimer);case _:
  return null;

}
}

}

/// @nodoc


class _ServersState implements ServersState {
  const _ServersState({final  Map<String, Spi> servers = const {}, final  List<String> serverOrder = const [], final  Set<String> tags = const <String>{}, final  Set<String> manualDisconnectedIds = const <String>{}, this.autoRefreshTimer}): _servers = servers,_serverOrder = serverOrder,_tags = tags,_manualDisconnectedIds = manualDisconnectedIds;
  

 final  Map<String, Spi> _servers;
@override@JsonKey() Map<String, Spi> get servers {
  if (_servers is EqualUnmodifiableMapView) return _servers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_servers);
}

 final  List<String> _serverOrder;
@override@JsonKey() List<String> get serverOrder {
  if (_serverOrder is EqualUnmodifiableListView) return _serverOrder;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_serverOrder);
}

 final  Set<String> _tags;
@override@JsonKey() Set<String> get tags {
  if (_tags is EqualUnmodifiableSetView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_tags);
}

 final  Set<String> _manualDisconnectedIds;
@override@JsonKey() Set<String> get manualDisconnectedIds {
  if (_manualDisconnectedIds is EqualUnmodifiableSetView) return _manualDisconnectedIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_manualDisconnectedIds);
}

@override final  Timer? autoRefreshTimer;

/// Create a copy of ServersState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServersStateCopyWith<_ServersState> get copyWith => __$ServersStateCopyWithImpl<_ServersState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServersState&&const DeepCollectionEquality().equals(other._servers, _servers)&&const DeepCollectionEquality().equals(other._serverOrder, _serverOrder)&&const DeepCollectionEquality().equals(other._tags, _tags)&&const DeepCollectionEquality().equals(other._manualDisconnectedIds, _manualDisconnectedIds)&&(identical(other.autoRefreshTimer, autoRefreshTimer) || other.autoRefreshTimer == autoRefreshTimer));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_servers),const DeepCollectionEquality().hash(_serverOrder),const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_manualDisconnectedIds),autoRefreshTimer);

@override
String toString() {
  return 'ServersState(servers: $servers, serverOrder: $serverOrder, tags: $tags, manualDisconnectedIds: $manualDisconnectedIds, autoRefreshTimer: $autoRefreshTimer)';
}


}

/// @nodoc
abstract mixin class _$ServersStateCopyWith<$Res> implements $ServersStateCopyWith<$Res> {
  factory _$ServersStateCopyWith(_ServersState value, $Res Function(_ServersState) _then) = __$ServersStateCopyWithImpl;
@override @useResult
$Res call({
 Map<String, Spi> servers, List<String> serverOrder, Set<String> tags, Set<String> manualDisconnectedIds, Timer? autoRefreshTimer
});




}
/// @nodoc
class __$ServersStateCopyWithImpl<$Res>
    implements _$ServersStateCopyWith<$Res> {
  __$ServersStateCopyWithImpl(this._self, this._then);

  final _ServersState _self;
  final $Res Function(_ServersState) _then;

/// Create a copy of ServersState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? servers = null,Object? serverOrder = null,Object? tags = null,Object? manualDisconnectedIds = null,Object? autoRefreshTimer = freezed,}) {
  return _then(_ServersState(
servers: null == servers ? _self._servers : servers // ignore: cast_nullable_to_non_nullable
as Map<String, Spi>,serverOrder: null == serverOrder ? _self._serverOrder : serverOrder // ignore: cast_nullable_to_non_nullable
as List<String>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as Set<String>,manualDisconnectedIds: null == manualDisconnectedIds ? _self._manualDisconnectedIds : manualDisconnectedIds // ignore: cast_nullable_to_non_nullable
as Set<String>,autoRefreshTimer: freezed == autoRefreshTimer ? _self.autoRefreshTimer : autoRefreshTimer // ignore: cast_nullable_to_non_nullable
as Timer?,
  ));
}


}

// dart format on
