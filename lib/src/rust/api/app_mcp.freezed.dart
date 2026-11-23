// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_mcp.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppMcpRun {

 String get host;/// At least this many bytes of output are kept.
 BigInt get room;
/// Create a copy of AppMcpRun
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppMcpRunCopyWith<AppMcpRun> get copyWith => _$AppMcpRunCopyWithImpl<AppMcpRun>(this as AppMcpRun, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AppMcpRun;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppMcpRun&&(identical(other.host, _this.host) || other.host == _this.host)&&(identical(other.room, _this.room) || other.room == _this.room));
}


@override
int get hashCode {
  final _this = this as AppMcpRun;
  return Object.hash(runtimeType,_this.host,_this.room);
}

@override
String toString() {
  final _this = this as AppMcpRun;
  return 'AppMcpRun(host: ${_this.host}, room: ${_this.room})';
}


}

/// @nodoc
abstract mixin class $AppMcpRunCopyWith<$Res>  {
  factory $AppMcpRunCopyWith(AppMcpRun value, $Res Function(AppMcpRun) _then) = _$AppMcpRunCopyWithImpl;
@useResult
$Res call({
 String host, BigInt room
});




}
/// @nodoc
class _$AppMcpRunCopyWithImpl<$Res>
    implements $AppMcpRunCopyWith<$Res> {
  _$AppMcpRunCopyWithImpl(this._self, this._then);

  final AppMcpRun _self;
  final $Res Function(AppMcpRun) _then;

/// Create a copy of AppMcpRun
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? host = null,Object? room = null,}) {
  return _then(_self.copyWith(
host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}

}


/// Adds pattern-matching-related methods to [AppMcpRun].
extension AppMcpRunPatterns on AppMcpRun {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AppMcpRun_Command value)?  command,TResult Function( AppMcpRun_Script value)?  script,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AppMcpRun_Command() when command != null:
return command(_that);case AppMcpRun_Script() when script != null:
return script(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AppMcpRun_Command value)  command,required TResult Function( AppMcpRun_Script value)  script,}){
final _that = this;
switch (_that) {
case AppMcpRun_Command():
return command(_that);case AppMcpRun_Script():
return script(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AppMcpRun_Command value)?  command,TResult? Function( AppMcpRun_Script value)?  script,}){
final _that = this;
switch (_that) {
case AppMcpRun_Command() when command != null:
return command(_that);case AppMcpRun_Script() when script != null:
return script(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String host,  String script,  String? entry,  String? stdin,  BigInt room)?  command,TResult Function( String host,  ShellFuncKind func,  BigInt room)?  script,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AppMcpRun_Command() when command != null:
return command(_that.host,_that.script,_that.entry,_that.stdin,_that.room);case AppMcpRun_Script() when script != null:
return script(_that.host,_that.func,_that.room);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String host,  String script,  String? entry,  String? stdin,  BigInt room)  command,required TResult Function( String host,  ShellFuncKind func,  BigInt room)  script,}) {final _that = this;
switch (_that) {
case AppMcpRun_Command():
return command(_that.host,_that.script,_that.entry,_that.stdin,_that.room);case AppMcpRun_Script():
return script(_that.host,_that.func,_that.room);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String host,  String script,  String? entry,  String? stdin,  BigInt room)?  command,TResult? Function( String host,  ShellFuncKind func,  BigInt room)?  script,}) {final _that = this;
switch (_that) {
case AppMcpRun_Command() when command != null:
return command(_that.host,_that.script,_that.entry,_that.stdin,_that.room);case AppMcpRun_Script() when script != null:
return script(_that.host,_that.func,_that.room);case _:
  return null;

}
}

}

/// @nodoc


class AppMcpRun_Command extends AppMcpRun {
  const AppMcpRun_Command({required this.host, required this.script, this.entry, this.stdin, required this.room}): super._();
  

@override final  String host;
 final  String script;
 final  String? entry;
 final  String? stdin;
/// At least this many bytes of output are kept.
@override final  BigInt room;

/// Create a copy of AppMcpRun
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppMcpRun_CommandCopyWith<AppMcpRun_Command> get copyWith => _$AppMcpRun_CommandCopyWithImpl<AppMcpRun_Command>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AppMcpRun_Command&&(identical(other.host, host) || other.host == host)&&(identical(other.script, script) || other.script == script)&&(identical(other.entry, entry) || other.entry == entry)&&(identical(other.stdin, stdin) || other.stdin == stdin)&&(identical(other.room, room) || other.room == room));
}


@override
int get hashCode {
    return Object.hash(runtimeType,host,script,entry,stdin,room);
}

@override
String toString() {
    return 'AppMcpRun.command(host: $host, script: $script, entry: $entry, stdin: $stdin, room: $room)';
}


}

/// @nodoc
abstract mixin class $AppMcpRun_CommandCopyWith<$Res> implements $AppMcpRunCopyWith<$Res> {
  factory $AppMcpRun_CommandCopyWith(AppMcpRun_Command value, $Res Function(AppMcpRun_Command) _then) = _$AppMcpRun_CommandCopyWithImpl;
@override @useResult
$Res call({
 String host, String script, String? entry, String? stdin, BigInt room
});




}
/// @nodoc
class _$AppMcpRun_CommandCopyWithImpl<$Res>
    implements $AppMcpRun_CommandCopyWith<$Res> {
  _$AppMcpRun_CommandCopyWithImpl(this._self, this._then);

  final AppMcpRun_Command _self;
  final $Res Function(AppMcpRun_Command) _then;

/// Create a copy of AppMcpRun
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? host = null,Object? script = null,Object? entry = freezed,Object? stdin = freezed,Object? room = null,}) {
  return _then(AppMcpRun_Command(
host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,script: null == script ? _self.script : script // ignore: cast_nullable_to_non_nullable
as String,entry: freezed == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as String?,stdin: freezed == stdin ? _self.stdin : stdin // ignore: cast_nullable_to_non_nullable
as String?,room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class AppMcpRun_Script extends AppMcpRun {
  const AppMcpRun_Script({required this.host, required this.func, required this.room}): super._();
  

@override final  String host;
 final  ShellFuncKind func;
@override final  BigInt room;

/// Create a copy of AppMcpRun
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppMcpRun_ScriptCopyWith<AppMcpRun_Script> get copyWith => _$AppMcpRun_ScriptCopyWithImpl<AppMcpRun_Script>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AppMcpRun_Script&&(identical(other.host, host) || other.host == host)&&(identical(other.func, func) || other.func == func)&&(identical(other.room, room) || other.room == room));
}


@override
int get hashCode {
    return Object.hash(runtimeType,host,func,room);
}

@override
String toString() {
    return 'AppMcpRun.script(host: $host, func: $func, room: $room)';
}


}

/// @nodoc
abstract mixin class $AppMcpRun_ScriptCopyWith<$Res> implements $AppMcpRunCopyWith<$Res> {
  factory $AppMcpRun_ScriptCopyWith(AppMcpRun_Script value, $Res Function(AppMcpRun_Script) _then) = _$AppMcpRun_ScriptCopyWithImpl;
@override @useResult
$Res call({
 String host, ShellFuncKind func, BigInt room
});




}
/// @nodoc
class _$AppMcpRun_ScriptCopyWithImpl<$Res>
    implements $AppMcpRun_ScriptCopyWith<$Res> {
  _$AppMcpRun_ScriptCopyWithImpl(this._self, this._then);

  final AppMcpRun_Script _self;
  final $Res Function(AppMcpRun_Script) _then;

/// Create a copy of AppMcpRun
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? host = null,Object? func = null,Object? room = null,}) {
  return _then(AppMcpRun_Script(
host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,func: null == func ? _self.func : func // ignore: cast_nullable_to_non_nullable
as ShellFuncKind,room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

// dart format on
