// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'yabs_options.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$YabsOptions {

/// fio: 4k/64k/512k/1m, mixed read/write, ~30s each.
///
/// Writes a 2 GB test file (512 MB on ARM) into [workDir] and needs that
/// much free, or yabs skips the phase and says so in the log.
 bool get disk;/// iperf3 against public servers. See [reducedNetwork] for the cost.
 bool get network;/// Three iperf locations instead of seven.
 bool get reducedNetwork;/// Geekbench. Off by default — see the note on this class.
 bool get cpu; GeekbenchVersion get geekbenchVersion;/// Look the server's public address up with ip-api.com. Off by default —
/// see the note on this class.
 bool get ipInfo;/// yabs' `-b`: use the binaries it ships rather than the host's own fio and
/// iperf3.
///
/// Off, so a host that has the packages uses them and needs no network for
/// this at all. Turning it on means fetching from raw.githubusercontent.com,
/// which a good share of hosts cannot reach.
 bool get preferPrecompiledBinaries;/// Where the run happens, and therefore **which filesystem fio measures**.
///
/// Empty means the login account's home directory. Anyone benchmarking a
/// second disk needs this; there is no other way to point fio at one.
 String get workDir;
/// Create a copy of YabsOptions
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$YabsOptionsCopyWith<YabsOptions> get copyWith => _$YabsOptionsCopyWithImpl<YabsOptions>(this as YabsOptions, _$identity);

  /// Serializes this YabsOptions to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is YabsOptions&&(identical(other.disk, disk) || other.disk == disk)&&(identical(other.network, network) || other.network == network)&&(identical(other.reducedNetwork, reducedNetwork) || other.reducedNetwork == reducedNetwork)&&(identical(other.cpu, cpu) || other.cpu == cpu)&&(identical(other.geekbenchVersion, geekbenchVersion) || other.geekbenchVersion == geekbenchVersion)&&(identical(other.ipInfo, ipInfo) || other.ipInfo == ipInfo)&&(identical(other.preferPrecompiledBinaries, preferPrecompiledBinaries) || other.preferPrecompiledBinaries == preferPrecompiledBinaries)&&(identical(other.workDir, workDir) || other.workDir == workDir));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,disk,network,reducedNetwork,cpu,geekbenchVersion,ipInfo,preferPrecompiledBinaries,workDir);

@override
String toString() {
  return 'YabsOptions(disk: $disk, network: $network, reducedNetwork: $reducedNetwork, cpu: $cpu, geekbenchVersion: $geekbenchVersion, ipInfo: $ipInfo, preferPrecompiledBinaries: $preferPrecompiledBinaries, workDir: $workDir)';
}


}

/// @nodoc
abstract mixin class $YabsOptionsCopyWith<$Res>  {
  factory $YabsOptionsCopyWith(YabsOptions value, $Res Function(YabsOptions) _then) = _$YabsOptionsCopyWithImpl;
@useResult
$Res call({
 bool disk, bool network, bool reducedNetwork, bool cpu, GeekbenchVersion geekbenchVersion, bool ipInfo, bool preferPrecompiledBinaries, String workDir
});




}
/// @nodoc
class _$YabsOptionsCopyWithImpl<$Res>
    implements $YabsOptionsCopyWith<$Res> {
  _$YabsOptionsCopyWithImpl(this._self, this._then);

  final YabsOptions _self;
  final $Res Function(YabsOptions) _then;

/// Create a copy of YabsOptions
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? disk = null,Object? network = null,Object? reducedNetwork = null,Object? cpu = null,Object? geekbenchVersion = null,Object? ipInfo = null,Object? preferPrecompiledBinaries = null,Object? workDir = null,}) {
  return _then(_self.copyWith(
disk: null == disk ? _self.disk : disk // ignore: cast_nullable_to_non_nullable
as bool,network: null == network ? _self.network : network // ignore: cast_nullable_to_non_nullable
as bool,reducedNetwork: null == reducedNetwork ? _self.reducedNetwork : reducedNetwork // ignore: cast_nullable_to_non_nullable
as bool,cpu: null == cpu ? _self.cpu : cpu // ignore: cast_nullable_to_non_nullable
as bool,geekbenchVersion: null == geekbenchVersion ? _self.geekbenchVersion : geekbenchVersion // ignore: cast_nullable_to_non_nullable
as GeekbenchVersion,ipInfo: null == ipInfo ? _self.ipInfo : ipInfo // ignore: cast_nullable_to_non_nullable
as bool,preferPrecompiledBinaries: null == preferPrecompiledBinaries ? _self.preferPrecompiledBinaries : preferPrecompiledBinaries // ignore: cast_nullable_to_non_nullable
as bool,workDir: null == workDir ? _self.workDir : workDir // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [YabsOptions].
extension YabsOptionsPatterns on YabsOptions {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _YabsOptions value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _YabsOptions() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _YabsOptions value)  $default,){
final _that = this;
switch (_that) {
case _YabsOptions():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _YabsOptions value)?  $default,){
final _that = this;
switch (_that) {
case _YabsOptions() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool disk,  bool network,  bool reducedNetwork,  bool cpu,  GeekbenchVersion geekbenchVersion,  bool ipInfo,  bool preferPrecompiledBinaries,  String workDir)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _YabsOptions() when $default != null:
return $default(_that.disk,_that.network,_that.reducedNetwork,_that.cpu,_that.geekbenchVersion,_that.ipInfo,_that.preferPrecompiledBinaries,_that.workDir);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool disk,  bool network,  bool reducedNetwork,  bool cpu,  GeekbenchVersion geekbenchVersion,  bool ipInfo,  bool preferPrecompiledBinaries,  String workDir)  $default,) {final _that = this;
switch (_that) {
case _YabsOptions():
return $default(_that.disk,_that.network,_that.reducedNetwork,_that.cpu,_that.geekbenchVersion,_that.ipInfo,_that.preferPrecompiledBinaries,_that.workDir);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool disk,  bool network,  bool reducedNetwork,  bool cpu,  GeekbenchVersion geekbenchVersion,  bool ipInfo,  bool preferPrecompiledBinaries,  String workDir)?  $default,) {final _that = this;
switch (_that) {
case _YabsOptions() when $default != null:
return $default(_that.disk,_that.network,_that.reducedNetwork,_that.cpu,_that.geekbenchVersion,_that.ipInfo,_that.preferPrecompiledBinaries,_that.workDir);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _YabsOptions extends YabsOptions {
  const _YabsOptions({this.disk = true, this.network = true, this.reducedNetwork = true, this.cpu = false, this.geekbenchVersion = GeekbenchVersion.v6, this.ipInfo = false, this.preferPrecompiledBinaries = false, this.workDir = ''}): super._();
  factory _YabsOptions.fromJson(Map<String, dynamic> json) => _$YabsOptionsFromJson(json);

/// fio: 4k/64k/512k/1m, mixed read/write, ~30s each.
///
/// Writes a 2 GB test file (512 MB on ARM) into [workDir] and needs that
/// much free, or yabs skips the phase and says so in the log.
@override@JsonKey() final  bool disk;
/// iperf3 against public servers. See [reducedNetwork] for the cost.
@override@JsonKey() final  bool network;
/// Three iperf locations instead of seven.
@override@JsonKey() final  bool reducedNetwork;
/// Geekbench. Off by default — see the note on this class.
@override@JsonKey() final  bool cpu;
@override@JsonKey() final  GeekbenchVersion geekbenchVersion;
/// Look the server's public address up with ip-api.com. Off by default —
/// see the note on this class.
@override@JsonKey() final  bool ipInfo;
/// yabs' `-b`: use the binaries it ships rather than the host's own fio and
/// iperf3.
///
/// Off, so a host that has the packages uses them and needs no network for
/// this at all. Turning it on means fetching from raw.githubusercontent.com,
/// which a good share of hosts cannot reach.
@override@JsonKey() final  bool preferPrecompiledBinaries;
/// Where the run happens, and therefore **which filesystem fio measures**.
///
/// Empty means the login account's home directory. Anyone benchmarking a
/// second disk needs this; there is no other way to point fio at one.
@override@JsonKey() final  String workDir;

/// Create a copy of YabsOptions
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$YabsOptionsCopyWith<_YabsOptions> get copyWith => __$YabsOptionsCopyWithImpl<_YabsOptions>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$YabsOptionsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _YabsOptions&&(identical(other.disk, disk) || other.disk == disk)&&(identical(other.network, network) || other.network == network)&&(identical(other.reducedNetwork, reducedNetwork) || other.reducedNetwork == reducedNetwork)&&(identical(other.cpu, cpu) || other.cpu == cpu)&&(identical(other.geekbenchVersion, geekbenchVersion) || other.geekbenchVersion == geekbenchVersion)&&(identical(other.ipInfo, ipInfo) || other.ipInfo == ipInfo)&&(identical(other.preferPrecompiledBinaries, preferPrecompiledBinaries) || other.preferPrecompiledBinaries == preferPrecompiledBinaries)&&(identical(other.workDir, workDir) || other.workDir == workDir));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,disk,network,reducedNetwork,cpu,geekbenchVersion,ipInfo,preferPrecompiledBinaries,workDir);

@override
String toString() {
  return 'YabsOptions(disk: $disk, network: $network, reducedNetwork: $reducedNetwork, cpu: $cpu, geekbenchVersion: $geekbenchVersion, ipInfo: $ipInfo, preferPrecompiledBinaries: $preferPrecompiledBinaries, workDir: $workDir)';
}


}

/// @nodoc
abstract mixin class _$YabsOptionsCopyWith<$Res> implements $YabsOptionsCopyWith<$Res> {
  factory _$YabsOptionsCopyWith(_YabsOptions value, $Res Function(_YabsOptions) _then) = __$YabsOptionsCopyWithImpl;
@override @useResult
$Res call({
 bool disk, bool network, bool reducedNetwork, bool cpu, GeekbenchVersion geekbenchVersion, bool ipInfo, bool preferPrecompiledBinaries, String workDir
});




}
/// @nodoc
class __$YabsOptionsCopyWithImpl<$Res>
    implements _$YabsOptionsCopyWith<$Res> {
  __$YabsOptionsCopyWithImpl(this._self, this._then);

  final _YabsOptions _self;
  final $Res Function(_YabsOptions) _then;

/// Create a copy of YabsOptions
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? disk = null,Object? network = null,Object? reducedNetwork = null,Object? cpu = null,Object? geekbenchVersion = null,Object? ipInfo = null,Object? preferPrecompiledBinaries = null,Object? workDir = null,}) {
  return _then(_YabsOptions(
disk: null == disk ? _self.disk : disk // ignore: cast_nullable_to_non_nullable
as bool,network: null == network ? _self.network : network // ignore: cast_nullable_to_non_nullable
as bool,reducedNetwork: null == reducedNetwork ? _self.reducedNetwork : reducedNetwork // ignore: cast_nullable_to_non_nullable
as bool,cpu: null == cpu ? _self.cpu : cpu // ignore: cast_nullable_to_non_nullable
as bool,geekbenchVersion: null == geekbenchVersion ? _self.geekbenchVersion : geekbenchVersion // ignore: cast_nullable_to_non_nullable
as GeekbenchVersion,ipInfo: null == ipInfo ? _self.ipInfo : ipInfo // ignore: cast_nullable_to_non_nullable
as bool,preferPrecompiledBinaries: null == preferPrecompiledBinaries ? _self.preferPrecompiledBinaries : preferPrecompiledBinaries // ignore: cast_nullable_to_non_nullable
as bool,workDir: null == workDir ? _self.workDir : workDir // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
