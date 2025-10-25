// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'proxy_command_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProxyCommandConfig {

/// Command template with placeholders
/// Available placeholders: %h (hostname), %p (port), %r (user)
 String get command;/// Command arguments (optional, can be included in command)
 List<String>? get args;/// Working directory for the command
 String? get workingDirectory;/// Environment variables for the command
 Map<String, String>? get environment;/// Timeout for command execution
 Duration get timeout;/// Whether to retry on connection failure
 bool get retryOnFailure;/// Maximum retry attempts
 int get maxRetries;/// Whether the proxy command requires executable download
 bool get requiresExecutable;/// Executable name for download management
 String? get executableName;/// Executable download URL
 String? get executableDownloadUrl;
/// Create a copy of ProxyCommandConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProxyCommandConfigCopyWith<ProxyCommandConfig> get copyWith => _$ProxyCommandConfigCopyWithImpl<ProxyCommandConfig>(this as ProxyCommandConfig, _$identity);

  /// Serializes this ProxyCommandConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProxyCommandConfig&&(identical(other.command, command) || other.command == command)&&const DeepCollectionEquality().equals(other.args, args)&&(identical(other.workingDirectory, workingDirectory) || other.workingDirectory == workingDirectory)&&const DeepCollectionEquality().equals(other.environment, environment)&&(identical(other.timeout, timeout) || other.timeout == timeout)&&(identical(other.retryOnFailure, retryOnFailure) || other.retryOnFailure == retryOnFailure)&&(identical(other.maxRetries, maxRetries) || other.maxRetries == maxRetries)&&(identical(other.requiresExecutable, requiresExecutable) || other.requiresExecutable == requiresExecutable)&&(identical(other.executableName, executableName) || other.executableName == executableName)&&(identical(other.executableDownloadUrl, executableDownloadUrl) || other.executableDownloadUrl == executableDownloadUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,command,const DeepCollectionEquality().hash(args),workingDirectory,const DeepCollectionEquality().hash(environment),timeout,retryOnFailure,maxRetries,requiresExecutable,executableName,executableDownloadUrl);

@override
String toString() {
  return 'ProxyCommandConfig(command: $command, args: $args, workingDirectory: $workingDirectory, environment: $environment, timeout: $timeout, retryOnFailure: $retryOnFailure, maxRetries: $maxRetries, requiresExecutable: $requiresExecutable, executableName: $executableName, executableDownloadUrl: $executableDownloadUrl)';
}


}

/// @nodoc
abstract mixin class $ProxyCommandConfigCopyWith<$Res>  {
  factory $ProxyCommandConfigCopyWith(ProxyCommandConfig value, $Res Function(ProxyCommandConfig) _then) = _$ProxyCommandConfigCopyWithImpl;
@useResult
$Res call({
 String command, List<String>? args, String? workingDirectory, Map<String, String>? environment, Duration timeout, bool retryOnFailure, int maxRetries, bool requiresExecutable, String? executableName, String? executableDownloadUrl
});




}
/// @nodoc
class _$ProxyCommandConfigCopyWithImpl<$Res>
    implements $ProxyCommandConfigCopyWith<$Res> {
  _$ProxyCommandConfigCopyWithImpl(this._self, this._then);

  final ProxyCommandConfig _self;
  final $Res Function(ProxyCommandConfig) _then;

/// Create a copy of ProxyCommandConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? command = null,Object? args = freezed,Object? workingDirectory = freezed,Object? environment = freezed,Object? timeout = null,Object? retryOnFailure = null,Object? maxRetries = null,Object? requiresExecutable = null,Object? executableName = freezed,Object? executableDownloadUrl = freezed,}) {
  return _then(_self.copyWith(
command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,args: freezed == args ? _self.args : args // ignore: cast_nullable_to_non_nullable
as List<String>?,workingDirectory: freezed == workingDirectory ? _self.workingDirectory : workingDirectory // ignore: cast_nullable_to_non_nullable
as String?,environment: freezed == environment ? _self.environment : environment // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,timeout: null == timeout ? _self.timeout : timeout // ignore: cast_nullable_to_non_nullable
as Duration,retryOnFailure: null == retryOnFailure ? _self.retryOnFailure : retryOnFailure // ignore: cast_nullable_to_non_nullable
as bool,maxRetries: null == maxRetries ? _self.maxRetries : maxRetries // ignore: cast_nullable_to_non_nullable
as int,requiresExecutable: null == requiresExecutable ? _self.requiresExecutable : requiresExecutable // ignore: cast_nullable_to_non_nullable
as bool,executableName: freezed == executableName ? _self.executableName : executableName // ignore: cast_nullable_to_non_nullable
as String?,executableDownloadUrl: freezed == executableDownloadUrl ? _self.executableDownloadUrl : executableDownloadUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProxyCommandConfig].
extension ProxyCommandConfigPatterns on ProxyCommandConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProxyCommandConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProxyCommandConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProxyCommandConfig value)  $default,){
final _that = this;
switch (_that) {
case _ProxyCommandConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProxyCommandConfig value)?  $default,){
final _that = this;
switch (_that) {
case _ProxyCommandConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String command,  List<String>? args,  String? workingDirectory,  Map<String, String>? environment,  Duration timeout,  bool retryOnFailure,  int maxRetries,  bool requiresExecutable,  String? executableName,  String? executableDownloadUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProxyCommandConfig() when $default != null:
return $default(_that.command,_that.args,_that.workingDirectory,_that.environment,_that.timeout,_that.retryOnFailure,_that.maxRetries,_that.requiresExecutable,_that.executableName,_that.executableDownloadUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String command,  List<String>? args,  String? workingDirectory,  Map<String, String>? environment,  Duration timeout,  bool retryOnFailure,  int maxRetries,  bool requiresExecutable,  String? executableName,  String? executableDownloadUrl)  $default,) {final _that = this;
switch (_that) {
case _ProxyCommandConfig():
return $default(_that.command,_that.args,_that.workingDirectory,_that.environment,_that.timeout,_that.retryOnFailure,_that.maxRetries,_that.requiresExecutable,_that.executableName,_that.executableDownloadUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String command,  List<String>? args,  String? workingDirectory,  Map<String, String>? environment,  Duration timeout,  bool retryOnFailure,  int maxRetries,  bool requiresExecutable,  String? executableName,  String? executableDownloadUrl)?  $default,) {final _that = this;
switch (_that) {
case _ProxyCommandConfig() when $default != null:
return $default(_that.command,_that.args,_that.workingDirectory,_that.environment,_that.timeout,_that.retryOnFailure,_that.maxRetries,_that.requiresExecutable,_that.executableName,_that.executableDownloadUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProxyCommandConfig implements ProxyCommandConfig {
  const _ProxyCommandConfig({required this.command, final  List<String>? args, this.workingDirectory, final  Map<String, String>? environment, this.timeout = const Duration(seconds: 30), this.retryOnFailure = false, this.maxRetries = 3, this.requiresExecutable = false, this.executableName, this.executableDownloadUrl}): _args = args,_environment = environment;
  factory _ProxyCommandConfig.fromJson(Map<String, dynamic> json) => _$ProxyCommandConfigFromJson(json);

/// Command template with placeholders
/// Available placeholders: %h (hostname), %p (port), %r (user)
@override final  String command;
/// Command arguments (optional, can be included in command)
 final  List<String>? _args;
/// Command arguments (optional, can be included in command)
@override List<String>? get args {
  final value = _args;
  if (value == null) return null;
  if (_args is EqualUnmodifiableListView) return _args;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// Working directory for the command
@override final  String? workingDirectory;
/// Environment variables for the command
 final  Map<String, String>? _environment;
/// Environment variables for the command
@override Map<String, String>? get environment {
  final value = _environment;
  if (value == null) return null;
  if (_environment is EqualUnmodifiableMapView) return _environment;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

/// Timeout for command execution
@override@JsonKey() final  Duration timeout;
/// Whether to retry on connection failure
@override@JsonKey() final  bool retryOnFailure;
/// Maximum retry attempts
@override@JsonKey() final  int maxRetries;
/// Whether the proxy command requires executable download
@override@JsonKey() final  bool requiresExecutable;
/// Executable name for download management
@override final  String? executableName;
/// Executable download URL
@override final  String? executableDownloadUrl;

/// Create a copy of ProxyCommandConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProxyCommandConfigCopyWith<_ProxyCommandConfig> get copyWith => __$ProxyCommandConfigCopyWithImpl<_ProxyCommandConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProxyCommandConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProxyCommandConfig&&(identical(other.command, command) || other.command == command)&&const DeepCollectionEquality().equals(other._args, _args)&&(identical(other.workingDirectory, workingDirectory) || other.workingDirectory == workingDirectory)&&const DeepCollectionEquality().equals(other._environment, _environment)&&(identical(other.timeout, timeout) || other.timeout == timeout)&&(identical(other.retryOnFailure, retryOnFailure) || other.retryOnFailure == retryOnFailure)&&(identical(other.maxRetries, maxRetries) || other.maxRetries == maxRetries)&&(identical(other.requiresExecutable, requiresExecutable) || other.requiresExecutable == requiresExecutable)&&(identical(other.executableName, executableName) || other.executableName == executableName)&&(identical(other.executableDownloadUrl, executableDownloadUrl) || other.executableDownloadUrl == executableDownloadUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,command,const DeepCollectionEquality().hash(_args),workingDirectory,const DeepCollectionEquality().hash(_environment),timeout,retryOnFailure,maxRetries,requiresExecutable,executableName,executableDownloadUrl);

@override
String toString() {
  return 'ProxyCommandConfig(command: $command, args: $args, workingDirectory: $workingDirectory, environment: $environment, timeout: $timeout, retryOnFailure: $retryOnFailure, maxRetries: $maxRetries, requiresExecutable: $requiresExecutable, executableName: $executableName, executableDownloadUrl: $executableDownloadUrl)';
}


}

/// @nodoc
abstract mixin class _$ProxyCommandConfigCopyWith<$Res> implements $ProxyCommandConfigCopyWith<$Res> {
  factory _$ProxyCommandConfigCopyWith(_ProxyCommandConfig value, $Res Function(_ProxyCommandConfig) _then) = __$ProxyCommandConfigCopyWithImpl;
@override @useResult
$Res call({
 String command, List<String>? args, String? workingDirectory, Map<String, String>? environment, Duration timeout, bool retryOnFailure, int maxRetries, bool requiresExecutable, String? executableName, String? executableDownloadUrl
});




}
/// @nodoc
class __$ProxyCommandConfigCopyWithImpl<$Res>
    implements _$ProxyCommandConfigCopyWith<$Res> {
  __$ProxyCommandConfigCopyWithImpl(this._self, this._then);

  final _ProxyCommandConfig _self;
  final $Res Function(_ProxyCommandConfig) _then;

/// Create a copy of ProxyCommandConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? command = null,Object? args = freezed,Object? workingDirectory = freezed,Object? environment = freezed,Object? timeout = null,Object? retryOnFailure = null,Object? maxRetries = null,Object? requiresExecutable = null,Object? executableName = freezed,Object? executableDownloadUrl = freezed,}) {
  return _then(_ProxyCommandConfig(
command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,args: freezed == args ? _self._args : args // ignore: cast_nullable_to_non_nullable
as List<String>?,workingDirectory: freezed == workingDirectory ? _self.workingDirectory : workingDirectory // ignore: cast_nullable_to_non_nullable
as String?,environment: freezed == environment ? _self._environment : environment // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,timeout: null == timeout ? _self.timeout : timeout // ignore: cast_nullable_to_non_nullable
as Duration,retryOnFailure: null == retryOnFailure ? _self.retryOnFailure : retryOnFailure // ignore: cast_nullable_to_non_nullable
as bool,maxRetries: null == maxRetries ? _self.maxRetries : maxRetries // ignore: cast_nullable_to_non_nullable
as int,requiresExecutable: null == requiresExecutable ? _self.requiresExecutable : requiresExecutable // ignore: cast_nullable_to_non_nullable
as bool,executableName: freezed == executableName ? _self.executableName : executableName // ignore: cast_nullable_to_non_nullable
as String?,executableDownloadUrl: freezed == executableDownloadUrl ? _self.executableDownloadUrl : executableDownloadUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
