// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connection_stat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ConnectionStat {

 String get serverId; String get serverName; DateTime get timestamp; ConnectionResult get result; String get errorMessage; int get durationMs;
/// Create a copy of ConnectionStat
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionStatCopyWith<ConnectionStat> get copyWith => _$ConnectionStatCopyWithImpl<ConnectionStat>(this as ConnectionStat, _$identity);

  /// Serializes this ConnectionStat to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionStat&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.serverName, serverName) || other.serverName == serverName)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.result, result) || other.result == result)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serverId,serverName,timestamp,result,errorMessage,durationMs);

@override
String toString() {
  return 'ConnectionStat(serverId: $serverId, serverName: $serverName, timestamp: $timestamp, result: $result, errorMessage: $errorMessage, durationMs: $durationMs)';
}


}

/// @nodoc
abstract mixin class $ConnectionStatCopyWith<$Res>  {
  factory $ConnectionStatCopyWith(ConnectionStat value, $Res Function(ConnectionStat) _then) = _$ConnectionStatCopyWithImpl;
@useResult
$Res call({
 String serverId, String serverName, DateTime timestamp, ConnectionResult result, String errorMessage, int durationMs
});




}
/// @nodoc
class _$ConnectionStatCopyWithImpl<$Res>
    implements $ConnectionStatCopyWith<$Res> {
  _$ConnectionStatCopyWithImpl(this._self, this._then);

  final ConnectionStat _self;
  final $Res Function(ConnectionStat) _then;

/// Create a copy of ConnectionStat
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serverId = null,Object? serverName = null,Object? timestamp = null,Object? result = null,Object? errorMessage = null,Object? durationMs = null,}) {
  return _then(_self.copyWith(
serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,serverName: null == serverName ? _self.serverName : serverName // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,result: null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as ConnectionResult,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ConnectionStat].
extension ConnectionStatPatterns on ConnectionStat {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConnectionStat value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConnectionStat() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConnectionStat value)  $default,){
final _that = this;
switch (_that) {
case _ConnectionStat():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConnectionStat value)?  $default,){
final _that = this;
switch (_that) {
case _ConnectionStat() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String serverId,  String serverName,  DateTime timestamp,  ConnectionResult result,  String errorMessage,  int durationMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConnectionStat() when $default != null:
return $default(_that.serverId,_that.serverName,_that.timestamp,_that.result,_that.errorMessage,_that.durationMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String serverId,  String serverName,  DateTime timestamp,  ConnectionResult result,  String errorMessage,  int durationMs)  $default,) {final _that = this;
switch (_that) {
case _ConnectionStat():
return $default(_that.serverId,_that.serverName,_that.timestamp,_that.result,_that.errorMessage,_that.durationMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String serverId,  String serverName,  DateTime timestamp,  ConnectionResult result,  String errorMessage,  int durationMs)?  $default,) {final _that = this;
switch (_that) {
case _ConnectionStat() when $default != null:
return $default(_that.serverId,_that.serverName,_that.timestamp,_that.result,_that.errorMessage,_that.durationMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ConnectionStat implements ConnectionStat {
  const _ConnectionStat({required this.serverId, required this.serverName, required this.timestamp, required this.result, this.errorMessage = '', required this.durationMs});
  factory _ConnectionStat.fromJson(Map<String, dynamic> json) => _$ConnectionStatFromJson(json);

@override final  String serverId;
@override final  String serverName;
@override final  DateTime timestamp;
@override final  ConnectionResult result;
@override@JsonKey() final  String errorMessage;
@override final  int durationMs;

/// Create a copy of ConnectionStat
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConnectionStatCopyWith<_ConnectionStat> get copyWith => __$ConnectionStatCopyWithImpl<_ConnectionStat>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConnectionStatToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConnectionStat&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.serverName, serverName) || other.serverName == serverName)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.result, result) || other.result == result)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serverId,serverName,timestamp,result,errorMessage,durationMs);

@override
String toString() {
  return 'ConnectionStat(serverId: $serverId, serverName: $serverName, timestamp: $timestamp, result: $result, errorMessage: $errorMessage, durationMs: $durationMs)';
}


}

/// @nodoc
abstract mixin class _$ConnectionStatCopyWith<$Res> implements $ConnectionStatCopyWith<$Res> {
  factory _$ConnectionStatCopyWith(_ConnectionStat value, $Res Function(_ConnectionStat) _then) = __$ConnectionStatCopyWithImpl;
@override @useResult
$Res call({
 String serverId, String serverName, DateTime timestamp, ConnectionResult result, String errorMessage, int durationMs
});




}
/// @nodoc
class __$ConnectionStatCopyWithImpl<$Res>
    implements _$ConnectionStatCopyWith<$Res> {
  __$ConnectionStatCopyWithImpl(this._self, this._then);

  final _ConnectionStat _self;
  final $Res Function(_ConnectionStat) _then;

/// Create a copy of ConnectionStat
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serverId = null,Object? serverName = null,Object? timestamp = null,Object? result = null,Object? errorMessage = null,Object? durationMs = null,}) {
  return _then(_ConnectionStat(
serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,serverName: null == serverName ? _self.serverName : serverName // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,result: null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as ConnectionResult,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ServerConnectionStats {

 String get serverId; String get serverName; int get totalAttempts; int get successCount; int get failureCount; DateTime? get lastSuccessTime; DateTime? get lastFailureTime; List<ConnectionStat> get recentConnections; double get successRate;
/// Create a copy of ServerConnectionStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerConnectionStatsCopyWith<ServerConnectionStats> get copyWith => _$ServerConnectionStatsCopyWithImpl<ServerConnectionStats>(this as ServerConnectionStats, _$identity);

  /// Serializes this ServerConnectionStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerConnectionStats&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.serverName, serverName) || other.serverName == serverName)&&(identical(other.totalAttempts, totalAttempts) || other.totalAttempts == totalAttempts)&&(identical(other.successCount, successCount) || other.successCount == successCount)&&(identical(other.failureCount, failureCount) || other.failureCount == failureCount)&&(identical(other.lastSuccessTime, lastSuccessTime) || other.lastSuccessTime == lastSuccessTime)&&(identical(other.lastFailureTime, lastFailureTime) || other.lastFailureTime == lastFailureTime)&&const DeepCollectionEquality().equals(other.recentConnections, recentConnections)&&(identical(other.successRate, successRate) || other.successRate == successRate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serverId,serverName,totalAttempts,successCount,failureCount,lastSuccessTime,lastFailureTime,const DeepCollectionEquality().hash(recentConnections),successRate);

@override
String toString() {
  return 'ServerConnectionStats(serverId: $serverId, serverName: $serverName, totalAttempts: $totalAttempts, successCount: $successCount, failureCount: $failureCount, lastSuccessTime: $lastSuccessTime, lastFailureTime: $lastFailureTime, recentConnections: $recentConnections, successRate: $successRate)';
}


}

/// @nodoc
abstract mixin class $ServerConnectionStatsCopyWith<$Res>  {
  factory $ServerConnectionStatsCopyWith(ServerConnectionStats value, $Res Function(ServerConnectionStats) _then) = _$ServerConnectionStatsCopyWithImpl;
@useResult
$Res call({
 String serverId, String serverName, int totalAttempts, int successCount, int failureCount, DateTime? lastSuccessTime, DateTime? lastFailureTime, List<ConnectionStat> recentConnections, double successRate
});




}
/// @nodoc
class _$ServerConnectionStatsCopyWithImpl<$Res>
    implements $ServerConnectionStatsCopyWith<$Res> {
  _$ServerConnectionStatsCopyWithImpl(this._self, this._then);

  final ServerConnectionStats _self;
  final $Res Function(ServerConnectionStats) _then;

/// Create a copy of ServerConnectionStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serverId = null,Object? serverName = null,Object? totalAttempts = null,Object? successCount = null,Object? failureCount = null,Object? lastSuccessTime = freezed,Object? lastFailureTime = freezed,Object? recentConnections = null,Object? successRate = null,}) {
  return _then(_self.copyWith(
serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,serverName: null == serverName ? _self.serverName : serverName // ignore: cast_nullable_to_non_nullable
as String,totalAttempts: null == totalAttempts ? _self.totalAttempts : totalAttempts // ignore: cast_nullable_to_non_nullable
as int,successCount: null == successCount ? _self.successCount : successCount // ignore: cast_nullable_to_non_nullable
as int,failureCount: null == failureCount ? _self.failureCount : failureCount // ignore: cast_nullable_to_non_nullable
as int,lastSuccessTime: freezed == lastSuccessTime ? _self.lastSuccessTime : lastSuccessTime // ignore: cast_nullable_to_non_nullable
as DateTime?,lastFailureTime: freezed == lastFailureTime ? _self.lastFailureTime : lastFailureTime // ignore: cast_nullable_to_non_nullable
as DateTime?,recentConnections: null == recentConnections ? _self.recentConnections : recentConnections // ignore: cast_nullable_to_non_nullable
as List<ConnectionStat>,successRate: null == successRate ? _self.successRate : successRate // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [ServerConnectionStats].
extension ServerConnectionStatsPatterns on ServerConnectionStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServerConnectionStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServerConnectionStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServerConnectionStats value)  $default,){
final _that = this;
switch (_that) {
case _ServerConnectionStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServerConnectionStats value)?  $default,){
final _that = this;
switch (_that) {
case _ServerConnectionStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String serverId,  String serverName,  int totalAttempts,  int successCount,  int failureCount,  DateTime? lastSuccessTime,  DateTime? lastFailureTime,  List<ConnectionStat> recentConnections,  double successRate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServerConnectionStats() when $default != null:
return $default(_that.serverId,_that.serverName,_that.totalAttempts,_that.successCount,_that.failureCount,_that.lastSuccessTime,_that.lastFailureTime,_that.recentConnections,_that.successRate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String serverId,  String serverName,  int totalAttempts,  int successCount,  int failureCount,  DateTime? lastSuccessTime,  DateTime? lastFailureTime,  List<ConnectionStat> recentConnections,  double successRate)  $default,) {final _that = this;
switch (_that) {
case _ServerConnectionStats():
return $default(_that.serverId,_that.serverName,_that.totalAttempts,_that.successCount,_that.failureCount,_that.lastSuccessTime,_that.lastFailureTime,_that.recentConnections,_that.successRate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String serverId,  String serverName,  int totalAttempts,  int successCount,  int failureCount,  DateTime? lastSuccessTime,  DateTime? lastFailureTime,  List<ConnectionStat> recentConnections,  double successRate)?  $default,) {final _that = this;
switch (_that) {
case _ServerConnectionStats() when $default != null:
return $default(_that.serverId,_that.serverName,_that.totalAttempts,_that.successCount,_that.failureCount,_that.lastSuccessTime,_that.lastFailureTime,_that.recentConnections,_that.successRate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ServerConnectionStats implements ServerConnectionStats {
  const _ServerConnectionStats({required this.serverId, required this.serverName, required this.totalAttempts, required this.successCount, required this.failureCount, this.lastSuccessTime = null, this.lastFailureTime = null, final  List<ConnectionStat> recentConnections = const [], required this.successRate}): _recentConnections = recentConnections;
  factory _ServerConnectionStats.fromJson(Map<String, dynamic> json) => _$ServerConnectionStatsFromJson(json);

@override final  String serverId;
@override final  String serverName;
@override final  int totalAttempts;
@override final  int successCount;
@override final  int failureCount;
@override@JsonKey() final  DateTime? lastSuccessTime;
@override@JsonKey() final  DateTime? lastFailureTime;
 final  List<ConnectionStat> _recentConnections;
@override@JsonKey() List<ConnectionStat> get recentConnections {
  if (_recentConnections is EqualUnmodifiableListView) return _recentConnections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recentConnections);
}

@override final  double successRate;

/// Create a copy of ServerConnectionStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServerConnectionStatsCopyWith<_ServerConnectionStats> get copyWith => __$ServerConnectionStatsCopyWithImpl<_ServerConnectionStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ServerConnectionStatsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServerConnectionStats&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.serverName, serverName) || other.serverName == serverName)&&(identical(other.totalAttempts, totalAttempts) || other.totalAttempts == totalAttempts)&&(identical(other.successCount, successCount) || other.successCount == successCount)&&(identical(other.failureCount, failureCount) || other.failureCount == failureCount)&&(identical(other.lastSuccessTime, lastSuccessTime) || other.lastSuccessTime == lastSuccessTime)&&(identical(other.lastFailureTime, lastFailureTime) || other.lastFailureTime == lastFailureTime)&&const DeepCollectionEquality().equals(other._recentConnections, _recentConnections)&&(identical(other.successRate, successRate) || other.successRate == successRate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serverId,serverName,totalAttempts,successCount,failureCount,lastSuccessTime,lastFailureTime,const DeepCollectionEquality().hash(_recentConnections),successRate);

@override
String toString() {
  return 'ServerConnectionStats(serverId: $serverId, serverName: $serverName, totalAttempts: $totalAttempts, successCount: $successCount, failureCount: $failureCount, lastSuccessTime: $lastSuccessTime, lastFailureTime: $lastFailureTime, recentConnections: $recentConnections, successRate: $successRate)';
}


}

/// @nodoc
abstract mixin class _$ServerConnectionStatsCopyWith<$Res> implements $ServerConnectionStatsCopyWith<$Res> {
  factory _$ServerConnectionStatsCopyWith(_ServerConnectionStats value, $Res Function(_ServerConnectionStats) _then) = __$ServerConnectionStatsCopyWithImpl;
@override @useResult
$Res call({
 String serverId, String serverName, int totalAttempts, int successCount, int failureCount, DateTime? lastSuccessTime, DateTime? lastFailureTime, List<ConnectionStat> recentConnections, double successRate
});




}
/// @nodoc
class __$ServerConnectionStatsCopyWithImpl<$Res>
    implements _$ServerConnectionStatsCopyWith<$Res> {
  __$ServerConnectionStatsCopyWithImpl(this._self, this._then);

  final _ServerConnectionStats _self;
  final $Res Function(_ServerConnectionStats) _then;

/// Create a copy of ServerConnectionStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serverId = null,Object? serverName = null,Object? totalAttempts = null,Object? successCount = null,Object? failureCount = null,Object? lastSuccessTime = freezed,Object? lastFailureTime = freezed,Object? recentConnections = null,Object? successRate = null,}) {
  return _then(_ServerConnectionStats(
serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,serverName: null == serverName ? _self.serverName : serverName // ignore: cast_nullable_to_non_nullable
as String,totalAttempts: null == totalAttempts ? _self.totalAttempts : totalAttempts // ignore: cast_nullable_to_non_nullable
as int,successCount: null == successCount ? _self.successCount : successCount // ignore: cast_nullable_to_non_nullable
as int,failureCount: null == failureCount ? _self.failureCount : failureCount // ignore: cast_nullable_to_non_nullable
as int,lastSuccessTime: freezed == lastSuccessTime ? _self.lastSuccessTime : lastSuccessTime // ignore: cast_nullable_to_non_nullable
as DateTime?,lastFailureTime: freezed == lastFailureTime ? _self.lastFailureTime : lastFailureTime // ignore: cast_nullable_to_non_nullable
as DateTime?,recentConnections: null == recentConnections ? _self._recentConnections : recentConnections // ignore: cast_nullable_to_non_nullable
as List<ConnectionStat>,successRate: null == successRate ? _self.successRate : successRate // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
