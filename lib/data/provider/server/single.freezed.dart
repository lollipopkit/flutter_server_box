// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'single.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ServerState {

 Spi get spi; ServerStatus get status; ServerConn get conn; SSHClient? get client;
/// Create a copy of ServerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerStateCopyWith<ServerState> get copyWith => _$ServerStateCopyWithImpl<ServerState>(this as ServerState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerState&&(identical(other.spi, spi) || other.spi == spi)&&(identical(other.status, status) || other.status == status)&&(identical(other.conn, conn) || other.conn == conn)&&(identical(other.client, client) || other.client == client));
}


@override
int get hashCode => Object.hash(runtimeType,spi,status,conn,client);

@override
String toString() {
  return 'ServerState(spi: $spi, status: $status, conn: $conn, client: $client)';
}


}

/// @nodoc
abstract mixin class $ServerStateCopyWith<$Res>  {
  factory $ServerStateCopyWith(ServerState value, $Res Function(ServerState) _then) = _$ServerStateCopyWithImpl;
@useResult
$Res call({
 Spi spi, ServerStatus status, ServerConn conn, SSHClient? client
});


$SpiCopyWith<$Res> get spi;

}
/// @nodoc
class _$ServerStateCopyWithImpl<$Res>
    implements $ServerStateCopyWith<$Res> {
  _$ServerStateCopyWithImpl(this._self, this._then);

  final ServerState _self;
  final $Res Function(ServerState) _then;

/// Create a copy of ServerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? spi = null,Object? status = null,Object? conn = null,Object? client = freezed,}) {
  return _then(_self.copyWith(
spi: null == spi ? _self.spi : spi // ignore: cast_nullable_to_non_nullable
as Spi,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ServerStatus,conn: null == conn ? _self.conn : conn // ignore: cast_nullable_to_non_nullable
as ServerConn,client: freezed == client ? _self.client : client // ignore: cast_nullable_to_non_nullable
as SSHClient?,
  ));
}
/// Create a copy of ServerState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpiCopyWith<$Res> get spi {
  
  return $SpiCopyWith<$Res>(_self.spi, (value) {
    return _then(_self.copyWith(spi: value));
  });
}
}


/// Adds pattern-matching-related methods to [ServerState].
extension ServerStatePatterns on ServerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServerState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServerState value)  $default,){
final _that = this;
switch (_that) {
case _ServerState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServerState value)?  $default,){
final _that = this;
switch (_that) {
case _ServerState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Spi spi,  ServerStatus status,  ServerConn conn,  SSHClient? client)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServerState() when $default != null:
return $default(_that.spi,_that.status,_that.conn,_that.client);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Spi spi,  ServerStatus status,  ServerConn conn,  SSHClient? client)  $default,) {final _that = this;
switch (_that) {
case _ServerState():
return $default(_that.spi,_that.status,_that.conn,_that.client);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Spi spi,  ServerStatus status,  ServerConn conn,  SSHClient? client)?  $default,) {final _that = this;
switch (_that) {
case _ServerState() when $default != null:
return $default(_that.spi,_that.status,_that.conn,_that.client);case _:
  return null;

}
}

}

/// @nodoc


class _ServerState implements ServerState {
  const _ServerState({required this.spi, required this.status, this.conn = ServerConn.disconnected, this.client});
  

@override final  Spi spi;
@override final  ServerStatus status;
@override@JsonKey() final  ServerConn conn;
@override final  SSHClient? client;

/// Create a copy of ServerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServerStateCopyWith<_ServerState> get copyWith => __$ServerStateCopyWithImpl<_ServerState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServerState&&(identical(other.spi, spi) || other.spi == spi)&&(identical(other.status, status) || other.status == status)&&(identical(other.conn, conn) || other.conn == conn)&&(identical(other.client, client) || other.client == client));
}


@override
int get hashCode => Object.hash(runtimeType,spi,status,conn,client);

@override
String toString() {
  return 'ServerState(spi: $spi, status: $status, conn: $conn, client: $client)';
}


}

/// @nodoc
abstract mixin class _$ServerStateCopyWith<$Res> implements $ServerStateCopyWith<$Res> {
  factory _$ServerStateCopyWith(_ServerState value, $Res Function(_ServerState) _then) = __$ServerStateCopyWithImpl;
@override @useResult
$Res call({
 Spi spi, ServerStatus status, ServerConn conn, SSHClient? client
});


@override $SpiCopyWith<$Res> get spi;

}
/// @nodoc
class __$ServerStateCopyWithImpl<$Res>
    implements _$ServerStateCopyWith<$Res> {
  __$ServerStateCopyWithImpl(this._self, this._then);

  final _ServerState _self;
  final $Res Function(_ServerState) _then;

/// Create a copy of ServerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? spi = null,Object? status = null,Object? conn = null,Object? client = freezed,}) {
  return _then(_ServerState(
spi: null == spi ? _self.spi : spi // ignore: cast_nullable_to_non_nullable
as Spi,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ServerStatus,conn: null == conn ? _self.conn : conn // ignore: cast_nullable_to_non_nullable
as ServerConn,client: freezed == client ? _self.client : client // ignore: cast_nullable_to_non_nullable
as SSHClient?,
  ));
}

/// Create a copy of ServerState
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
