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

 Spi get spi; ServerStatus get status; ServerConn get conn;/// How long the last successful status read took, in milliseconds.
///
/// The read, not the connect: a handshake happens once and then never
/// again, so showing it would pin a number taken minutes ago — and over a
/// jump chain it measures the whole chain rather than this server.
///
/// What the read *is* differs by transport, and the two figures are not
/// interchangeable. Over SSH it is the status script running on the
/// machine, so it carries that machine's load as well as the network; over
/// a monitor agent it is one HTTP request for a sample the agent had
/// already taken, so it carries little but the network. A server reachable
/// both ways reports whichever transport led that poll. What neither
/// includes is the work of turning the answer into a [ServerStatus], which
/// happens on the isolate drawing frames and is not the machine's doing.
///
/// Null when there has been no successful read since the server was last
/// reachable. Every path that gives up on a connection clears it, and so
/// does publishing a status that carries an error, because a latency left
/// behind reads as a live measurement of a machine that is no longer
/// answering — and survives an edit pointing the server at a different
/// host.
 int? get latencyMs; SSHClient? get client;/// What the agent said it allows, or null before it has been asked.
///
/// Asked rather than configured: whether this app can reach the machine
/// without SSH is the agent's decision, it re-checks that decision when a
/// request arrives, and it already answers the question over an
/// authenticated endpoint. Putting the same question to the user meant
/// asking them to assert something the server knows — and being wrong
/// either way, since a "yes" the agent refuses is a row of dead buttons
/// and a "no" it would have allowed hides features that are there.
 MonitorRemoteAccess? get remoteAccess;/// The agent's version, as it reported it, or null for a server with no
/// agent — and for an agent built before it said so.
 String? get agentVersion;/// What the agent said it can answer for: how long it keeps readings and
/// the oldest one it still has.
///
/// What a window picker may offer is this, rather than a list of fixed
/// windows the app decided on: an agent keeping three days and one keeping
/// ninety are both ordinary, and offering "30 d" to the first draws an
/// empty chart and calls it a machine that was idle.
 MonitorCapabilities? get agentCapabilities;
/// Create a copy of ServerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerStateCopyWith<ServerState> get copyWith => _$ServerStateCopyWithImpl<ServerState>(this as ServerState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerState&&(identical(other.spi, spi) || other.spi == spi)&&(identical(other.status, status) || other.status == status)&&(identical(other.conn, conn) || other.conn == conn)&&(identical(other.latencyMs, latencyMs) || other.latencyMs == latencyMs)&&(identical(other.client, client) || other.client == client)&&(identical(other.remoteAccess, remoteAccess) || other.remoteAccess == remoteAccess)&&(identical(other.agentVersion, agentVersion) || other.agentVersion == agentVersion)&&const DeepCollectionEquality().equals(other.agentCapabilities, agentCapabilities));
}


@override
int get hashCode => Object.hash(runtimeType,spi,status,conn,latencyMs,client,remoteAccess,agentVersion,const DeepCollectionEquality().hash(agentCapabilities));

@override
String toString() {
  return 'ServerState(spi: $spi, status: $status, conn: $conn, latencyMs: $latencyMs, client: $client, remoteAccess: $remoteAccess, agentVersion: $agentVersion, agentCapabilities: $agentCapabilities)';
}


}

/// @nodoc
abstract mixin class $ServerStateCopyWith<$Res>  {
  factory $ServerStateCopyWith(ServerState value, $Res Function(ServerState) _then) = _$ServerStateCopyWithImpl;
@useResult
$Res call({
 Spi spi, ServerStatus status, ServerConn conn, int? latencyMs, SSHClient? client, MonitorRemoteAccess? remoteAccess, String? agentVersion, MonitorCapabilities? agentCapabilities
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
@pragma('vm:prefer-inline') @override $Res call({Object? spi = null,Object? status = null,Object? conn = null,Object? latencyMs = freezed,Object? client = freezed,Object? remoteAccess = freezed,Object? agentVersion = freezed,Object? agentCapabilities = freezed,}) {
  return _then(_self.copyWith(
spi: null == spi ? _self.spi : spi // ignore: cast_nullable_to_non_nullable
as Spi,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ServerStatus,conn: null == conn ? _self.conn : conn // ignore: cast_nullable_to_non_nullable
as ServerConn,latencyMs: freezed == latencyMs ? _self.latencyMs : latencyMs // ignore: cast_nullable_to_non_nullable
as int?,client: freezed == client ? _self.client : client // ignore: cast_nullable_to_non_nullable
as SSHClient?,remoteAccess: freezed == remoteAccess ? _self.remoteAccess : remoteAccess // ignore: cast_nullable_to_non_nullable
as MonitorRemoteAccess?,agentVersion: freezed == agentVersion ? _self.agentVersion : agentVersion // ignore: cast_nullable_to_non_nullable
as String?,agentCapabilities: freezed == agentCapabilities ? _self.agentCapabilities : agentCapabilities // ignore: cast_nullable_to_non_nullable
as MonitorCapabilities?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Spi spi,  ServerStatus status,  ServerConn conn,  int? latencyMs,  SSHClient? client,  MonitorRemoteAccess? remoteAccess,  String? agentVersion,  MonitorCapabilities? agentCapabilities)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServerState() when $default != null:
return $default(_that.spi,_that.status,_that.conn,_that.latencyMs,_that.client,_that.remoteAccess,_that.agentVersion,_that.agentCapabilities);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Spi spi,  ServerStatus status,  ServerConn conn,  int? latencyMs,  SSHClient? client,  MonitorRemoteAccess? remoteAccess,  String? agentVersion,  MonitorCapabilities? agentCapabilities)  $default,) {final _that = this;
switch (_that) {
case _ServerState():
return $default(_that.spi,_that.status,_that.conn,_that.latencyMs,_that.client,_that.remoteAccess,_that.agentVersion,_that.agentCapabilities);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Spi spi,  ServerStatus status,  ServerConn conn,  int? latencyMs,  SSHClient? client,  MonitorRemoteAccess? remoteAccess,  String? agentVersion,  MonitorCapabilities? agentCapabilities)?  $default,) {final _that = this;
switch (_that) {
case _ServerState() when $default != null:
return $default(_that.spi,_that.status,_that.conn,_that.latencyMs,_that.client,_that.remoteAccess,_that.agentVersion,_that.agentCapabilities);case _:
  return null;

}
}

}

/// @nodoc


class _ServerState extends ServerState {
  const _ServerState({required this.spi, required this.status, this.conn = ServerConn.disconnected, this.latencyMs, this.client, this.remoteAccess, this.agentVersion, this.agentCapabilities}): super._();
  

@override final  Spi spi;
@override final  ServerStatus status;
@override@JsonKey() final  ServerConn conn;
/// How long the last successful status read took, in milliseconds.
///
/// The read, not the connect: a handshake happens once and then never
/// again, so showing it would pin a number taken minutes ago — and over a
/// jump chain it measures the whole chain rather than this server.
///
/// What the read *is* differs by transport, and the two figures are not
/// interchangeable. Over SSH it is the status script running on the
/// machine, so it carries that machine's load as well as the network; over
/// a monitor agent it is one HTTP request for a sample the agent had
/// already taken, so it carries little but the network. A server reachable
/// both ways reports whichever transport led that poll. What neither
/// includes is the work of turning the answer into a [ServerStatus], which
/// happens on the isolate drawing frames and is not the machine's doing.
///
/// Null when there has been no successful read since the server was last
/// reachable. Every path that gives up on a connection clears it, and so
/// does publishing a status that carries an error, because a latency left
/// behind reads as a live measurement of a machine that is no longer
/// answering — and survives an edit pointing the server at a different
/// host.
@override final  int? latencyMs;
@override final  SSHClient? client;
/// What the agent said it allows, or null before it has been asked.
///
/// Asked rather than configured: whether this app can reach the machine
/// without SSH is the agent's decision, it re-checks that decision when a
/// request arrives, and it already answers the question over an
/// authenticated endpoint. Putting the same question to the user meant
/// asking them to assert something the server knows — and being wrong
/// either way, since a "yes" the agent refuses is a row of dead buttons
/// and a "no" it would have allowed hides features that are there.
@override final  MonitorRemoteAccess? remoteAccess;
/// The agent's version, as it reported it, or null for a server with no
/// agent — and for an agent built before it said so.
@override final  String? agentVersion;
/// What the agent said it can answer for: how long it keeps readings and
/// the oldest one it still has.
///
/// What a window picker may offer is this, rather than a list of fixed
/// windows the app decided on: an agent keeping three days and one keeping
/// ninety are both ordinary, and offering "30 d" to the first draws an
/// empty chart and calls it a machine that was idle.
@override final  MonitorCapabilities? agentCapabilities;

/// Create a copy of ServerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServerStateCopyWith<_ServerState> get copyWith => __$ServerStateCopyWithImpl<_ServerState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServerState&&(identical(other.spi, spi) || other.spi == spi)&&(identical(other.status, status) || other.status == status)&&(identical(other.conn, conn) || other.conn == conn)&&(identical(other.latencyMs, latencyMs) || other.latencyMs == latencyMs)&&(identical(other.client, client) || other.client == client)&&(identical(other.remoteAccess, remoteAccess) || other.remoteAccess == remoteAccess)&&(identical(other.agentVersion, agentVersion) || other.agentVersion == agentVersion)&&const DeepCollectionEquality().equals(other.agentCapabilities, agentCapabilities));
}


@override
int get hashCode => Object.hash(runtimeType,spi,status,conn,latencyMs,client,remoteAccess,agentVersion,const DeepCollectionEquality().hash(agentCapabilities));

@override
String toString() {
  return 'ServerState(spi: $spi, status: $status, conn: $conn, latencyMs: $latencyMs, client: $client, remoteAccess: $remoteAccess, agentVersion: $agentVersion, agentCapabilities: $agentCapabilities)';
}


}

/// @nodoc
abstract mixin class _$ServerStateCopyWith<$Res> implements $ServerStateCopyWith<$Res> {
  factory _$ServerStateCopyWith(_ServerState value, $Res Function(_ServerState) _then) = __$ServerStateCopyWithImpl;
@override @useResult
$Res call({
 Spi spi, ServerStatus status, ServerConn conn, int? latencyMs, SSHClient? client, MonitorRemoteAccess? remoteAccess, String? agentVersion, MonitorCapabilities? agentCapabilities
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
@override @pragma('vm:prefer-inline') $Res call({Object? spi = null,Object? status = null,Object? conn = null,Object? latencyMs = freezed,Object? client = freezed,Object? remoteAccess = freezed,Object? agentVersion = freezed,Object? agentCapabilities = freezed,}) {
  return _then(_ServerState(
spi: null == spi ? _self.spi : spi // ignore: cast_nullable_to_non_nullable
as Spi,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ServerStatus,conn: null == conn ? _self.conn : conn // ignore: cast_nullable_to_non_nullable
as ServerConn,latencyMs: freezed == latencyMs ? _self.latencyMs : latencyMs // ignore: cast_nullable_to_non_nullable
as int?,client: freezed == client ? _self.client : client // ignore: cast_nullable_to_non_nullable
as SSHClient?,remoteAccess: freezed == remoteAccess ? _self.remoteAccess : remoteAccess // ignore: cast_nullable_to_non_nullable
as MonitorRemoteAccess?,agentVersion: freezed == agentVersion ? _self.agentVersion : agentVersion // ignore: cast_nullable_to_non_nullable
as String?,agentCapabilities: freezed == agentCapabilities ? _self.agentCapabilities : agentCapabilities // ignore: cast_nullable_to_non_nullable
as MonitorCapabilities?,
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
