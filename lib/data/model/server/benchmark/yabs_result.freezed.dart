// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'yabs_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$YabsResult {

 String get version; String get time; YabsOs get os; YabsNet get net; YabsCpu get cpu; YabsMem get mem;/// The device fio tested. Absent when the disk phase did not run.
 String? get partition; List<YabsFio> get fio; List<YabsIperf> get iperf; List<YabsGeekbench> get geekbench;@JsonKey(name: 'ip_info') YabsIpInfo? get ipInfo; YabsRuntime? get runtime;
/// Create a copy of YabsResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$YabsResultCopyWith<YabsResult> get copyWith => _$YabsResultCopyWithImpl<YabsResult>(this as YabsResult, _$identity);

  /// Serializes this YabsResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is YabsResult&&(identical(other.version, version) || other.version == version)&&(identical(other.time, time) || other.time == time)&&(identical(other.os, os) || other.os == os)&&(identical(other.net, net) || other.net == net)&&(identical(other.cpu, cpu) || other.cpu == cpu)&&(identical(other.mem, mem) || other.mem == mem)&&(identical(other.partition, partition) || other.partition == partition)&&const DeepCollectionEquality().equals(other.fio, fio)&&const DeepCollectionEquality().equals(other.iperf, iperf)&&const DeepCollectionEquality().equals(other.geekbench, geekbench)&&(identical(other.ipInfo, ipInfo) || other.ipInfo == ipInfo)&&(identical(other.runtime, runtime) || other.runtime == runtime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,time,os,net,cpu,mem,partition,const DeepCollectionEquality().hash(fio),const DeepCollectionEquality().hash(iperf),const DeepCollectionEquality().hash(geekbench),ipInfo,runtime);

@override
String toString() {
  return 'YabsResult(version: $version, time: $time, os: $os, net: $net, cpu: $cpu, mem: $mem, partition: $partition, fio: $fio, iperf: $iperf, geekbench: $geekbench, ipInfo: $ipInfo, runtime: $runtime)';
}


}

/// @nodoc
abstract mixin class $YabsResultCopyWith<$Res>  {
  factory $YabsResultCopyWith(YabsResult value, $Res Function(YabsResult) _then) = _$YabsResultCopyWithImpl;
@useResult
$Res call({
 String version, String time, YabsOs os, YabsNet net, YabsCpu cpu, YabsMem mem, String? partition, List<YabsFio> fio, List<YabsIperf> iperf, List<YabsGeekbench> geekbench,@JsonKey(name: 'ip_info') YabsIpInfo? ipInfo, YabsRuntime? runtime
});


$YabsOsCopyWith<$Res> get os;$YabsNetCopyWith<$Res> get net;$YabsCpuCopyWith<$Res> get cpu;$YabsMemCopyWith<$Res> get mem;$YabsIpInfoCopyWith<$Res>? get ipInfo;$YabsRuntimeCopyWith<$Res>? get runtime;

}
/// @nodoc
class _$YabsResultCopyWithImpl<$Res>
    implements $YabsResultCopyWith<$Res> {
  _$YabsResultCopyWithImpl(this._self, this._then);

  final YabsResult _self;
  final $Res Function(YabsResult) _then;

/// Create a copy of YabsResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? time = null,Object? os = null,Object? net = null,Object? cpu = null,Object? mem = null,Object? partition = freezed,Object? fio = null,Object? iperf = null,Object? geekbench = null,Object? ipInfo = freezed,Object? runtime = freezed,}) {
  return _then(_self.copyWith(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String,os: null == os ? _self.os : os // ignore: cast_nullable_to_non_nullable
as YabsOs,net: null == net ? _self.net : net // ignore: cast_nullable_to_non_nullable
as YabsNet,cpu: null == cpu ? _self.cpu : cpu // ignore: cast_nullable_to_non_nullable
as YabsCpu,mem: null == mem ? _self.mem : mem // ignore: cast_nullable_to_non_nullable
as YabsMem,partition: freezed == partition ? _self.partition : partition // ignore: cast_nullable_to_non_nullable
as String?,fio: null == fio ? _self.fio : fio // ignore: cast_nullable_to_non_nullable
as List<YabsFio>,iperf: null == iperf ? _self.iperf : iperf // ignore: cast_nullable_to_non_nullable
as List<YabsIperf>,geekbench: null == geekbench ? _self.geekbench : geekbench // ignore: cast_nullable_to_non_nullable
as List<YabsGeekbench>,ipInfo: freezed == ipInfo ? _self.ipInfo : ipInfo // ignore: cast_nullable_to_non_nullable
as YabsIpInfo?,runtime: freezed == runtime ? _self.runtime : runtime // ignore: cast_nullable_to_non_nullable
as YabsRuntime?,
  ));
}
/// Create a copy of YabsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$YabsOsCopyWith<$Res> get os {
  
  return $YabsOsCopyWith<$Res>(_self.os, (value) {
    return _then(_self.copyWith(os: value));
  });
}/// Create a copy of YabsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$YabsNetCopyWith<$Res> get net {
  
  return $YabsNetCopyWith<$Res>(_self.net, (value) {
    return _then(_self.copyWith(net: value));
  });
}/// Create a copy of YabsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$YabsCpuCopyWith<$Res> get cpu {
  
  return $YabsCpuCopyWith<$Res>(_self.cpu, (value) {
    return _then(_self.copyWith(cpu: value));
  });
}/// Create a copy of YabsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$YabsMemCopyWith<$Res> get mem {
  
  return $YabsMemCopyWith<$Res>(_self.mem, (value) {
    return _then(_self.copyWith(mem: value));
  });
}/// Create a copy of YabsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$YabsIpInfoCopyWith<$Res>? get ipInfo {
    if (_self.ipInfo == null) {
    return null;
  }

  return $YabsIpInfoCopyWith<$Res>(_self.ipInfo!, (value) {
    return _then(_self.copyWith(ipInfo: value));
  });
}/// Create a copy of YabsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$YabsRuntimeCopyWith<$Res>? get runtime {
    if (_self.runtime == null) {
    return null;
  }

  return $YabsRuntimeCopyWith<$Res>(_self.runtime!, (value) {
    return _then(_self.copyWith(runtime: value));
  });
}
}


/// Adds pattern-matching-related methods to [YabsResult].
extension YabsResultPatterns on YabsResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _YabsResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _YabsResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _YabsResult value)  $default,){
final _that = this;
switch (_that) {
case _YabsResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _YabsResult value)?  $default,){
final _that = this;
switch (_that) {
case _YabsResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String version,  String time,  YabsOs os,  YabsNet net,  YabsCpu cpu,  YabsMem mem,  String? partition,  List<YabsFio> fio,  List<YabsIperf> iperf,  List<YabsGeekbench> geekbench, @JsonKey(name: 'ip_info')  YabsIpInfo? ipInfo,  YabsRuntime? runtime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _YabsResult() when $default != null:
return $default(_that.version,_that.time,_that.os,_that.net,_that.cpu,_that.mem,_that.partition,_that.fio,_that.iperf,_that.geekbench,_that.ipInfo,_that.runtime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String version,  String time,  YabsOs os,  YabsNet net,  YabsCpu cpu,  YabsMem mem,  String? partition,  List<YabsFio> fio,  List<YabsIperf> iperf,  List<YabsGeekbench> geekbench, @JsonKey(name: 'ip_info')  YabsIpInfo? ipInfo,  YabsRuntime? runtime)  $default,) {final _that = this;
switch (_that) {
case _YabsResult():
return $default(_that.version,_that.time,_that.os,_that.net,_that.cpu,_that.mem,_that.partition,_that.fio,_that.iperf,_that.geekbench,_that.ipInfo,_that.runtime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String version,  String time,  YabsOs os,  YabsNet net,  YabsCpu cpu,  YabsMem mem,  String? partition,  List<YabsFio> fio,  List<YabsIperf> iperf,  List<YabsGeekbench> geekbench, @JsonKey(name: 'ip_info')  YabsIpInfo? ipInfo,  YabsRuntime? runtime)?  $default,) {final _that = this;
switch (_that) {
case _YabsResult() when $default != null:
return $default(_that.version,_that.time,_that.os,_that.net,_that.cpu,_that.mem,_that.partition,_that.fio,_that.iperf,_that.geekbench,_that.ipInfo,_that.runtime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _YabsResult extends YabsResult {
  const _YabsResult({this.version = '', this.time = '', this.os = const YabsOs(), this.net = const YabsNet(), this.cpu = const YabsCpu(), this.mem = const YabsMem(), this.partition, final  List<YabsFio> fio = const [], final  List<YabsIperf> iperf = const [], final  List<YabsGeekbench> geekbench = const [], @JsonKey(name: 'ip_info') this.ipInfo, this.runtime}): _fio = fio,_iperf = iperf,_geekbench = geekbench,super._();
  factory _YabsResult.fromJson(Map<String, dynamic> json) => _$YabsResultFromJson(json);

@override@JsonKey() final  String version;
@override@JsonKey() final  String time;
@override@JsonKey() final  YabsOs os;
@override@JsonKey() final  YabsNet net;
@override@JsonKey() final  YabsCpu cpu;
@override@JsonKey() final  YabsMem mem;
/// The device fio tested. Absent when the disk phase did not run.
@override final  String? partition;
 final  List<YabsFio> _fio;
@override@JsonKey() List<YabsFio> get fio {
  if (_fio is EqualUnmodifiableListView) return _fio;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_fio);
}

 final  List<YabsIperf> _iperf;
@override@JsonKey() List<YabsIperf> get iperf {
  if (_iperf is EqualUnmodifiableListView) return _iperf;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_iperf);
}

 final  List<YabsGeekbench> _geekbench;
@override@JsonKey() List<YabsGeekbench> get geekbench {
  if (_geekbench is EqualUnmodifiableListView) return _geekbench;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_geekbench);
}

@override@JsonKey(name: 'ip_info') final  YabsIpInfo? ipInfo;
@override final  YabsRuntime? runtime;

/// Create a copy of YabsResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$YabsResultCopyWith<_YabsResult> get copyWith => __$YabsResultCopyWithImpl<_YabsResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$YabsResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _YabsResult&&(identical(other.version, version) || other.version == version)&&(identical(other.time, time) || other.time == time)&&(identical(other.os, os) || other.os == os)&&(identical(other.net, net) || other.net == net)&&(identical(other.cpu, cpu) || other.cpu == cpu)&&(identical(other.mem, mem) || other.mem == mem)&&(identical(other.partition, partition) || other.partition == partition)&&const DeepCollectionEquality().equals(other._fio, _fio)&&const DeepCollectionEquality().equals(other._iperf, _iperf)&&const DeepCollectionEquality().equals(other._geekbench, _geekbench)&&(identical(other.ipInfo, ipInfo) || other.ipInfo == ipInfo)&&(identical(other.runtime, runtime) || other.runtime == runtime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,time,os,net,cpu,mem,partition,const DeepCollectionEquality().hash(_fio),const DeepCollectionEquality().hash(_iperf),const DeepCollectionEquality().hash(_geekbench),ipInfo,runtime);

@override
String toString() {
  return 'YabsResult(version: $version, time: $time, os: $os, net: $net, cpu: $cpu, mem: $mem, partition: $partition, fio: $fio, iperf: $iperf, geekbench: $geekbench, ipInfo: $ipInfo, runtime: $runtime)';
}


}

/// @nodoc
abstract mixin class _$YabsResultCopyWith<$Res> implements $YabsResultCopyWith<$Res> {
  factory _$YabsResultCopyWith(_YabsResult value, $Res Function(_YabsResult) _then) = __$YabsResultCopyWithImpl;
@override @useResult
$Res call({
 String version, String time, YabsOs os, YabsNet net, YabsCpu cpu, YabsMem mem, String? partition, List<YabsFio> fio, List<YabsIperf> iperf, List<YabsGeekbench> geekbench,@JsonKey(name: 'ip_info') YabsIpInfo? ipInfo, YabsRuntime? runtime
});


@override $YabsOsCopyWith<$Res> get os;@override $YabsNetCopyWith<$Res> get net;@override $YabsCpuCopyWith<$Res> get cpu;@override $YabsMemCopyWith<$Res> get mem;@override $YabsIpInfoCopyWith<$Res>? get ipInfo;@override $YabsRuntimeCopyWith<$Res>? get runtime;

}
/// @nodoc
class __$YabsResultCopyWithImpl<$Res>
    implements _$YabsResultCopyWith<$Res> {
  __$YabsResultCopyWithImpl(this._self, this._then);

  final _YabsResult _self;
  final $Res Function(_YabsResult) _then;

/// Create a copy of YabsResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? time = null,Object? os = null,Object? net = null,Object? cpu = null,Object? mem = null,Object? partition = freezed,Object? fio = null,Object? iperf = null,Object? geekbench = null,Object? ipInfo = freezed,Object? runtime = freezed,}) {
  return _then(_YabsResult(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String,os: null == os ? _self.os : os // ignore: cast_nullable_to_non_nullable
as YabsOs,net: null == net ? _self.net : net // ignore: cast_nullable_to_non_nullable
as YabsNet,cpu: null == cpu ? _self.cpu : cpu // ignore: cast_nullable_to_non_nullable
as YabsCpu,mem: null == mem ? _self.mem : mem // ignore: cast_nullable_to_non_nullable
as YabsMem,partition: freezed == partition ? _self.partition : partition // ignore: cast_nullable_to_non_nullable
as String?,fio: null == fio ? _self._fio : fio // ignore: cast_nullable_to_non_nullable
as List<YabsFio>,iperf: null == iperf ? _self._iperf : iperf // ignore: cast_nullable_to_non_nullable
as List<YabsIperf>,geekbench: null == geekbench ? _self._geekbench : geekbench // ignore: cast_nullable_to_non_nullable
as List<YabsGeekbench>,ipInfo: freezed == ipInfo ? _self.ipInfo : ipInfo // ignore: cast_nullable_to_non_nullable
as YabsIpInfo?,runtime: freezed == runtime ? _self.runtime : runtime // ignore: cast_nullable_to_non_nullable
as YabsRuntime?,
  ));
}

/// Create a copy of YabsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$YabsOsCopyWith<$Res> get os {
  
  return $YabsOsCopyWith<$Res>(_self.os, (value) {
    return _then(_self.copyWith(os: value));
  });
}/// Create a copy of YabsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$YabsNetCopyWith<$Res> get net {
  
  return $YabsNetCopyWith<$Res>(_self.net, (value) {
    return _then(_self.copyWith(net: value));
  });
}/// Create a copy of YabsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$YabsCpuCopyWith<$Res> get cpu {
  
  return $YabsCpuCopyWith<$Res>(_self.cpu, (value) {
    return _then(_self.copyWith(cpu: value));
  });
}/// Create a copy of YabsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$YabsMemCopyWith<$Res> get mem {
  
  return $YabsMemCopyWith<$Res>(_self.mem, (value) {
    return _then(_self.copyWith(mem: value));
  });
}/// Create a copy of YabsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$YabsIpInfoCopyWith<$Res>? get ipInfo {
    if (_self.ipInfo == null) {
    return null;
  }

  return $YabsIpInfoCopyWith<$Res>(_self.ipInfo!, (value) {
    return _then(_self.copyWith(ipInfo: value));
  });
}/// Create a copy of YabsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$YabsRuntimeCopyWith<$Res>? get runtime {
    if (_self.runtime == null) {
    return null;
  }

  return $YabsRuntimeCopyWith<$Res>(_self.runtime!, (value) {
    return _then(_self.copyWith(runtime: value));
  });
}
}


/// @nodoc
mixin _$YabsOs {

 String get arch; String get distro; String get kernel;/// Seconds, from `/proc/uptime`, so fractional.
@JsonKey(fromJson: yabsDouble) double? get uptime;/// The virtualisation yabs detected — `KVM`, `LXC`, and so on. Empty on
/// bare metal, which is a result rather than a gap.
 String get vm;
/// Create a copy of YabsOs
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$YabsOsCopyWith<YabsOs> get copyWith => _$YabsOsCopyWithImpl<YabsOs>(this as YabsOs, _$identity);

  /// Serializes this YabsOs to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is YabsOs&&(identical(other.arch, arch) || other.arch == arch)&&(identical(other.distro, distro) || other.distro == distro)&&(identical(other.kernel, kernel) || other.kernel == kernel)&&(identical(other.uptime, uptime) || other.uptime == uptime)&&(identical(other.vm, vm) || other.vm == vm));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,arch,distro,kernel,uptime,vm);

@override
String toString() {
  return 'YabsOs(arch: $arch, distro: $distro, kernel: $kernel, uptime: $uptime, vm: $vm)';
}


}

/// @nodoc
abstract mixin class $YabsOsCopyWith<$Res>  {
  factory $YabsOsCopyWith(YabsOs value, $Res Function(YabsOs) _then) = _$YabsOsCopyWithImpl;
@useResult
$Res call({
 String arch, String distro, String kernel,@JsonKey(fromJson: yabsDouble) double? uptime, String vm
});




}
/// @nodoc
class _$YabsOsCopyWithImpl<$Res>
    implements $YabsOsCopyWith<$Res> {
  _$YabsOsCopyWithImpl(this._self, this._then);

  final YabsOs _self;
  final $Res Function(YabsOs) _then;

/// Create a copy of YabsOs
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? arch = null,Object? distro = null,Object? kernel = null,Object? uptime = freezed,Object? vm = null,}) {
  return _then(_self.copyWith(
arch: null == arch ? _self.arch : arch // ignore: cast_nullable_to_non_nullable
as String,distro: null == distro ? _self.distro : distro // ignore: cast_nullable_to_non_nullable
as String,kernel: null == kernel ? _self.kernel : kernel // ignore: cast_nullable_to_non_nullable
as String,uptime: freezed == uptime ? _self.uptime : uptime // ignore: cast_nullable_to_non_nullable
as double?,vm: null == vm ? _self.vm : vm // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [YabsOs].
extension YabsOsPatterns on YabsOs {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _YabsOs value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _YabsOs() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _YabsOs value)  $default,){
final _that = this;
switch (_that) {
case _YabsOs():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _YabsOs value)?  $default,){
final _that = this;
switch (_that) {
case _YabsOs() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String arch,  String distro,  String kernel, @JsonKey(fromJson: yabsDouble)  double? uptime,  String vm)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _YabsOs() when $default != null:
return $default(_that.arch,_that.distro,_that.kernel,_that.uptime,_that.vm);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String arch,  String distro,  String kernel, @JsonKey(fromJson: yabsDouble)  double? uptime,  String vm)  $default,) {final _that = this;
switch (_that) {
case _YabsOs():
return $default(_that.arch,_that.distro,_that.kernel,_that.uptime,_that.vm);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String arch,  String distro,  String kernel, @JsonKey(fromJson: yabsDouble)  double? uptime,  String vm)?  $default,) {final _that = this;
switch (_that) {
case _YabsOs() when $default != null:
return $default(_that.arch,_that.distro,_that.kernel,_that.uptime,_that.vm);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _YabsOs implements YabsOs {
  const _YabsOs({this.arch = '', this.distro = '', this.kernel = '', @JsonKey(fromJson: yabsDouble) this.uptime, this.vm = ''});
  factory _YabsOs.fromJson(Map<String, dynamic> json) => _$YabsOsFromJson(json);

@override@JsonKey() final  String arch;
@override@JsonKey() final  String distro;
@override@JsonKey() final  String kernel;
/// Seconds, from `/proc/uptime`, so fractional.
@override@JsonKey(fromJson: yabsDouble) final  double? uptime;
/// The virtualisation yabs detected — `KVM`, `LXC`, and so on. Empty on
/// bare metal, which is a result rather than a gap.
@override@JsonKey() final  String vm;

/// Create a copy of YabsOs
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$YabsOsCopyWith<_YabsOs> get copyWith => __$YabsOsCopyWithImpl<_YabsOs>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$YabsOsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _YabsOs&&(identical(other.arch, arch) || other.arch == arch)&&(identical(other.distro, distro) || other.distro == distro)&&(identical(other.kernel, kernel) || other.kernel == kernel)&&(identical(other.uptime, uptime) || other.uptime == uptime)&&(identical(other.vm, vm) || other.vm == vm));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,arch,distro,kernel,uptime,vm);

@override
String toString() {
  return 'YabsOs(arch: $arch, distro: $distro, kernel: $kernel, uptime: $uptime, vm: $vm)';
}


}

/// @nodoc
abstract mixin class _$YabsOsCopyWith<$Res> implements $YabsOsCopyWith<$Res> {
  factory _$YabsOsCopyWith(_YabsOs value, $Res Function(_YabsOs) _then) = __$YabsOsCopyWithImpl;
@override @useResult
$Res call({
 String arch, String distro, String kernel,@JsonKey(fromJson: yabsDouble) double? uptime, String vm
});




}
/// @nodoc
class __$YabsOsCopyWithImpl<$Res>
    implements _$YabsOsCopyWith<$Res> {
  __$YabsOsCopyWithImpl(this._self, this._then);

  final _YabsOs _self;
  final $Res Function(_YabsOs) _then;

/// Create a copy of YabsOs
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? arch = null,Object? distro = null,Object? kernel = null,Object? uptime = freezed,Object? vm = null,}) {
  return _then(_YabsOs(
arch: null == arch ? _self.arch : arch // ignore: cast_nullable_to_non_nullable
as String,distro: null == distro ? _self.distro : distro // ignore: cast_nullable_to_non_nullable
as String,kernel: null == kernel ? _self.kernel : kernel // ignore: cast_nullable_to_non_nullable
as String,uptime: freezed == uptime ? _self.uptime : uptime // ignore: cast_nullable_to_non_nullable
as double?,vm: null == vm ? _self.vm : vm // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$YabsNet {

@JsonKey(fromJson: yabsBool) bool get ipv4;@JsonKey(fromJson: yabsBool) bool get ipv6;
/// Create a copy of YabsNet
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$YabsNetCopyWith<YabsNet> get copyWith => _$YabsNetCopyWithImpl<YabsNet>(this as YabsNet, _$identity);

  /// Serializes this YabsNet to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is YabsNet&&(identical(other.ipv4, ipv4) || other.ipv4 == ipv4)&&(identical(other.ipv6, ipv6) || other.ipv6 == ipv6));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ipv4,ipv6);

@override
String toString() {
  return 'YabsNet(ipv4: $ipv4, ipv6: $ipv6)';
}


}

/// @nodoc
abstract mixin class $YabsNetCopyWith<$Res>  {
  factory $YabsNetCopyWith(YabsNet value, $Res Function(YabsNet) _then) = _$YabsNetCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: yabsBool) bool ipv4,@JsonKey(fromJson: yabsBool) bool ipv6
});




}
/// @nodoc
class _$YabsNetCopyWithImpl<$Res>
    implements $YabsNetCopyWith<$Res> {
  _$YabsNetCopyWithImpl(this._self, this._then);

  final YabsNet _self;
  final $Res Function(YabsNet) _then;

/// Create a copy of YabsNet
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ipv4 = null,Object? ipv6 = null,}) {
  return _then(_self.copyWith(
ipv4: null == ipv4 ? _self.ipv4 : ipv4 // ignore: cast_nullable_to_non_nullable
as bool,ipv6: null == ipv6 ? _self.ipv6 : ipv6 // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [YabsNet].
extension YabsNetPatterns on YabsNet {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _YabsNet value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _YabsNet() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _YabsNet value)  $default,){
final _that = this;
switch (_that) {
case _YabsNet():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _YabsNet value)?  $default,){
final _that = this;
switch (_that) {
case _YabsNet() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: yabsBool)  bool ipv4, @JsonKey(fromJson: yabsBool)  bool ipv6)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _YabsNet() when $default != null:
return $default(_that.ipv4,_that.ipv6);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: yabsBool)  bool ipv4, @JsonKey(fromJson: yabsBool)  bool ipv6)  $default,) {final _that = this;
switch (_that) {
case _YabsNet():
return $default(_that.ipv4,_that.ipv6);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: yabsBool)  bool ipv4, @JsonKey(fromJson: yabsBool)  bool ipv6)?  $default,) {final _that = this;
switch (_that) {
case _YabsNet() when $default != null:
return $default(_that.ipv4,_that.ipv6);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _YabsNet implements YabsNet {
  const _YabsNet({@JsonKey(fromJson: yabsBool) this.ipv4 = false, @JsonKey(fromJson: yabsBool) this.ipv6 = false});
  factory _YabsNet.fromJson(Map<String, dynamic> json) => _$YabsNetFromJson(json);

@override@JsonKey(fromJson: yabsBool) final  bool ipv4;
@override@JsonKey(fromJson: yabsBool) final  bool ipv6;

/// Create a copy of YabsNet
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$YabsNetCopyWith<_YabsNet> get copyWith => __$YabsNetCopyWithImpl<_YabsNet>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$YabsNetToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _YabsNet&&(identical(other.ipv4, ipv4) || other.ipv4 == ipv4)&&(identical(other.ipv6, ipv6) || other.ipv6 == ipv6));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ipv4,ipv6);

@override
String toString() {
  return 'YabsNet(ipv4: $ipv4, ipv6: $ipv6)';
}


}

/// @nodoc
abstract mixin class _$YabsNetCopyWith<$Res> implements $YabsNetCopyWith<$Res> {
  factory _$YabsNetCopyWith(_YabsNet value, $Res Function(_YabsNet) _then) = __$YabsNetCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: yabsBool) bool ipv4,@JsonKey(fromJson: yabsBool) bool ipv6
});




}
/// @nodoc
class __$YabsNetCopyWithImpl<$Res>
    implements _$YabsNetCopyWith<$Res> {
  __$YabsNetCopyWithImpl(this._self, this._then);

  final _YabsNet _self;
  final $Res Function(_YabsNet) _then;

/// Create a copy of YabsNet
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ipv4 = null,Object? ipv6 = null,}) {
  return _then(_YabsNet(
ipv4: null == ipv4 ? _self.ipv4 : ipv4 // ignore: cast_nullable_to_non_nullable
as bool,ipv6: null == ipv6 ? _self.ipv6 : ipv6 // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$YabsCpu {

 String get model;@JsonKey(fromJson: yabsInt) int? get cores;/// A string because yabs writes it as one, units and all.
 String get freq;/// AES-NI, and hardware virtualisation. Both are the difference between a
/// host that can do a job and one that will crawl through it.
@JsonKey(fromJson: yabsBool) bool get aes;@JsonKey(fromJson: yabsBool) bool get virt;
/// Create a copy of YabsCpu
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$YabsCpuCopyWith<YabsCpu> get copyWith => _$YabsCpuCopyWithImpl<YabsCpu>(this as YabsCpu, _$identity);

  /// Serializes this YabsCpu to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is YabsCpu&&(identical(other.model, model) || other.model == model)&&(identical(other.cores, cores) || other.cores == cores)&&(identical(other.freq, freq) || other.freq == freq)&&(identical(other.aes, aes) || other.aes == aes)&&(identical(other.virt, virt) || other.virt == virt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,model,cores,freq,aes,virt);

@override
String toString() {
  return 'YabsCpu(model: $model, cores: $cores, freq: $freq, aes: $aes, virt: $virt)';
}


}

/// @nodoc
abstract mixin class $YabsCpuCopyWith<$Res>  {
  factory $YabsCpuCopyWith(YabsCpu value, $Res Function(YabsCpu) _then) = _$YabsCpuCopyWithImpl;
@useResult
$Res call({
 String model,@JsonKey(fromJson: yabsInt) int? cores, String freq,@JsonKey(fromJson: yabsBool) bool aes,@JsonKey(fromJson: yabsBool) bool virt
});




}
/// @nodoc
class _$YabsCpuCopyWithImpl<$Res>
    implements $YabsCpuCopyWith<$Res> {
  _$YabsCpuCopyWithImpl(this._self, this._then);

  final YabsCpu _self;
  final $Res Function(YabsCpu) _then;

/// Create a copy of YabsCpu
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? model = null,Object? cores = freezed,Object? freq = null,Object? aes = null,Object? virt = null,}) {
  return _then(_self.copyWith(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,cores: freezed == cores ? _self.cores : cores // ignore: cast_nullable_to_non_nullable
as int?,freq: null == freq ? _self.freq : freq // ignore: cast_nullable_to_non_nullable
as String,aes: null == aes ? _self.aes : aes // ignore: cast_nullable_to_non_nullable
as bool,virt: null == virt ? _self.virt : virt // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [YabsCpu].
extension YabsCpuPatterns on YabsCpu {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _YabsCpu value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _YabsCpu() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _YabsCpu value)  $default,){
final _that = this;
switch (_that) {
case _YabsCpu():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _YabsCpu value)?  $default,){
final _that = this;
switch (_that) {
case _YabsCpu() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String model, @JsonKey(fromJson: yabsInt)  int? cores,  String freq, @JsonKey(fromJson: yabsBool)  bool aes, @JsonKey(fromJson: yabsBool)  bool virt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _YabsCpu() when $default != null:
return $default(_that.model,_that.cores,_that.freq,_that.aes,_that.virt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String model, @JsonKey(fromJson: yabsInt)  int? cores,  String freq, @JsonKey(fromJson: yabsBool)  bool aes, @JsonKey(fromJson: yabsBool)  bool virt)  $default,) {final _that = this;
switch (_that) {
case _YabsCpu():
return $default(_that.model,_that.cores,_that.freq,_that.aes,_that.virt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String model, @JsonKey(fromJson: yabsInt)  int? cores,  String freq, @JsonKey(fromJson: yabsBool)  bool aes, @JsonKey(fromJson: yabsBool)  bool virt)?  $default,) {final _that = this;
switch (_that) {
case _YabsCpu() when $default != null:
return $default(_that.model,_that.cores,_that.freq,_that.aes,_that.virt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _YabsCpu implements YabsCpu {
  const _YabsCpu({this.model = '', @JsonKey(fromJson: yabsInt) this.cores, this.freq = '', @JsonKey(fromJson: yabsBool) this.aes = false, @JsonKey(fromJson: yabsBool) this.virt = false});
  factory _YabsCpu.fromJson(Map<String, dynamic> json) => _$YabsCpuFromJson(json);

@override@JsonKey() final  String model;
@override@JsonKey(fromJson: yabsInt) final  int? cores;
/// A string because yabs writes it as one, units and all.
@override@JsonKey() final  String freq;
/// AES-NI, and hardware virtualisation. Both are the difference between a
/// host that can do a job and one that will crawl through it.
@override@JsonKey(fromJson: yabsBool) final  bool aes;
@override@JsonKey(fromJson: yabsBool) final  bool virt;

/// Create a copy of YabsCpu
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$YabsCpuCopyWith<_YabsCpu> get copyWith => __$YabsCpuCopyWithImpl<_YabsCpu>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$YabsCpuToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _YabsCpu&&(identical(other.model, model) || other.model == model)&&(identical(other.cores, cores) || other.cores == cores)&&(identical(other.freq, freq) || other.freq == freq)&&(identical(other.aes, aes) || other.aes == aes)&&(identical(other.virt, virt) || other.virt == virt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,model,cores,freq,aes,virt);

@override
String toString() {
  return 'YabsCpu(model: $model, cores: $cores, freq: $freq, aes: $aes, virt: $virt)';
}


}

/// @nodoc
abstract mixin class _$YabsCpuCopyWith<$Res> implements $YabsCpuCopyWith<$Res> {
  factory _$YabsCpuCopyWith(_YabsCpu value, $Res Function(_YabsCpu) _then) = __$YabsCpuCopyWithImpl;
@override @useResult
$Res call({
 String model,@JsonKey(fromJson: yabsInt) int? cores, String freq,@JsonKey(fromJson: yabsBool) bool aes,@JsonKey(fromJson: yabsBool) bool virt
});




}
/// @nodoc
class __$YabsCpuCopyWithImpl<$Res>
    implements _$YabsCpuCopyWith<$Res> {
  __$YabsCpuCopyWithImpl(this._self, this._then);

  final _YabsCpu _self;
  final $Res Function(_YabsCpu) _then;

/// Create a copy of YabsCpu
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? model = null,Object? cores = freezed,Object? freq = null,Object? aes = null,Object? virt = null,}) {
  return _then(_YabsCpu(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,cores: freezed == cores ? _self.cores : cores // ignore: cast_nullable_to_non_nullable
as int?,freq: null == freq ? _self.freq : freq // ignore: cast_nullable_to_non_nullable
as String,aes: null == aes ? _self.aes : aes // ignore: cast_nullable_to_non_nullable
as bool,virt: null == virt ? _self.virt : virt // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$YabsMem {

@JsonKey(fromJson: yabsInt) int? get ram;@JsonKey(name: 'ram_units') String get ramUnits;@JsonKey(fromJson: yabsInt) int? get swap;@JsonKey(name: 'swap_units') String get swapUnits;@JsonKey(fromJson: yabsInt) int? get disk;@JsonKey(name: 'disk_units') String get diskUnits;
/// Create a copy of YabsMem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$YabsMemCopyWith<YabsMem> get copyWith => _$YabsMemCopyWithImpl<YabsMem>(this as YabsMem, _$identity);

  /// Serializes this YabsMem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is YabsMem&&(identical(other.ram, ram) || other.ram == ram)&&(identical(other.ramUnits, ramUnits) || other.ramUnits == ramUnits)&&(identical(other.swap, swap) || other.swap == swap)&&(identical(other.swapUnits, swapUnits) || other.swapUnits == swapUnits)&&(identical(other.disk, disk) || other.disk == disk)&&(identical(other.diskUnits, diskUnits) || other.diskUnits == diskUnits));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ram,ramUnits,swap,swapUnits,disk,diskUnits);

@override
String toString() {
  return 'YabsMem(ram: $ram, ramUnits: $ramUnits, swap: $swap, swapUnits: $swapUnits, disk: $disk, diskUnits: $diskUnits)';
}


}

/// @nodoc
abstract mixin class $YabsMemCopyWith<$Res>  {
  factory $YabsMemCopyWith(YabsMem value, $Res Function(YabsMem) _then) = _$YabsMemCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: yabsInt) int? ram,@JsonKey(name: 'ram_units') String ramUnits,@JsonKey(fromJson: yabsInt) int? swap,@JsonKey(name: 'swap_units') String swapUnits,@JsonKey(fromJson: yabsInt) int? disk,@JsonKey(name: 'disk_units') String diskUnits
});




}
/// @nodoc
class _$YabsMemCopyWithImpl<$Res>
    implements $YabsMemCopyWith<$Res> {
  _$YabsMemCopyWithImpl(this._self, this._then);

  final YabsMem _self;
  final $Res Function(YabsMem) _then;

/// Create a copy of YabsMem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ram = freezed,Object? ramUnits = null,Object? swap = freezed,Object? swapUnits = null,Object? disk = freezed,Object? diskUnits = null,}) {
  return _then(_self.copyWith(
ram: freezed == ram ? _self.ram : ram // ignore: cast_nullable_to_non_nullable
as int?,ramUnits: null == ramUnits ? _self.ramUnits : ramUnits // ignore: cast_nullable_to_non_nullable
as String,swap: freezed == swap ? _self.swap : swap // ignore: cast_nullable_to_non_nullable
as int?,swapUnits: null == swapUnits ? _self.swapUnits : swapUnits // ignore: cast_nullable_to_non_nullable
as String,disk: freezed == disk ? _self.disk : disk // ignore: cast_nullable_to_non_nullable
as int?,diskUnits: null == diskUnits ? _self.diskUnits : diskUnits // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [YabsMem].
extension YabsMemPatterns on YabsMem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _YabsMem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _YabsMem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _YabsMem value)  $default,){
final _that = this;
switch (_that) {
case _YabsMem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _YabsMem value)?  $default,){
final _that = this;
switch (_that) {
case _YabsMem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: yabsInt)  int? ram, @JsonKey(name: 'ram_units')  String ramUnits, @JsonKey(fromJson: yabsInt)  int? swap, @JsonKey(name: 'swap_units')  String swapUnits, @JsonKey(fromJson: yabsInt)  int? disk, @JsonKey(name: 'disk_units')  String diskUnits)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _YabsMem() when $default != null:
return $default(_that.ram,_that.ramUnits,_that.swap,_that.swapUnits,_that.disk,_that.diskUnits);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: yabsInt)  int? ram, @JsonKey(name: 'ram_units')  String ramUnits, @JsonKey(fromJson: yabsInt)  int? swap, @JsonKey(name: 'swap_units')  String swapUnits, @JsonKey(fromJson: yabsInt)  int? disk, @JsonKey(name: 'disk_units')  String diskUnits)  $default,) {final _that = this;
switch (_that) {
case _YabsMem():
return $default(_that.ram,_that.ramUnits,_that.swap,_that.swapUnits,_that.disk,_that.diskUnits);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: yabsInt)  int? ram, @JsonKey(name: 'ram_units')  String ramUnits, @JsonKey(fromJson: yabsInt)  int? swap, @JsonKey(name: 'swap_units')  String swapUnits, @JsonKey(fromJson: yabsInt)  int? disk, @JsonKey(name: 'disk_units')  String diskUnits)?  $default,) {final _that = this;
switch (_that) {
case _YabsMem() when $default != null:
return $default(_that.ram,_that.ramUnits,_that.swap,_that.swapUnits,_that.disk,_that.diskUnits);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _YabsMem extends YabsMem {
  const _YabsMem({@JsonKey(fromJson: yabsInt) this.ram, @JsonKey(name: 'ram_units') this.ramUnits = 'KiB', @JsonKey(fromJson: yabsInt) this.swap, @JsonKey(name: 'swap_units') this.swapUnits = 'KiB', @JsonKey(fromJson: yabsInt) this.disk, @JsonKey(name: 'disk_units') this.diskUnits = 'KB'}): super._();
  factory _YabsMem.fromJson(Map<String, dynamic> json) => _$YabsMemFromJson(json);

@override@JsonKey(fromJson: yabsInt) final  int? ram;
@override@JsonKey(name: 'ram_units') final  String ramUnits;
@override@JsonKey(fromJson: yabsInt) final  int? swap;
@override@JsonKey(name: 'swap_units') final  String swapUnits;
@override@JsonKey(fromJson: yabsInt) final  int? disk;
@override@JsonKey(name: 'disk_units') final  String diskUnits;

/// Create a copy of YabsMem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$YabsMemCopyWith<_YabsMem> get copyWith => __$YabsMemCopyWithImpl<_YabsMem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$YabsMemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _YabsMem&&(identical(other.ram, ram) || other.ram == ram)&&(identical(other.ramUnits, ramUnits) || other.ramUnits == ramUnits)&&(identical(other.swap, swap) || other.swap == swap)&&(identical(other.swapUnits, swapUnits) || other.swapUnits == swapUnits)&&(identical(other.disk, disk) || other.disk == disk)&&(identical(other.diskUnits, diskUnits) || other.diskUnits == diskUnits));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ram,ramUnits,swap,swapUnits,disk,diskUnits);

@override
String toString() {
  return 'YabsMem(ram: $ram, ramUnits: $ramUnits, swap: $swap, swapUnits: $swapUnits, disk: $disk, diskUnits: $diskUnits)';
}


}

/// @nodoc
abstract mixin class _$YabsMemCopyWith<$Res> implements $YabsMemCopyWith<$Res> {
  factory _$YabsMemCopyWith(_YabsMem value, $Res Function(_YabsMem) _then) = __$YabsMemCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: yabsInt) int? ram,@JsonKey(name: 'ram_units') String ramUnits,@JsonKey(fromJson: yabsInt) int? swap,@JsonKey(name: 'swap_units') String swapUnits,@JsonKey(fromJson: yabsInt) int? disk,@JsonKey(name: 'disk_units') String diskUnits
});




}
/// @nodoc
class __$YabsMemCopyWithImpl<$Res>
    implements _$YabsMemCopyWith<$Res> {
  __$YabsMemCopyWithImpl(this._self, this._then);

  final _YabsMem _self;
  final $Res Function(_YabsMem) _then;

/// Create a copy of YabsMem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ram = freezed,Object? ramUnits = null,Object? swap = freezed,Object? swapUnits = null,Object? disk = freezed,Object? diskUnits = null,}) {
  return _then(_YabsMem(
ram: freezed == ram ? _self.ram : ram // ignore: cast_nullable_to_non_nullable
as int?,ramUnits: null == ramUnits ? _self.ramUnits : ramUnits // ignore: cast_nullable_to_non_nullable
as String,swap: freezed == swap ? _self.swap : swap // ignore: cast_nullable_to_non_nullable
as int?,swapUnits: null == swapUnits ? _self.swapUnits : swapUnits // ignore: cast_nullable_to_non_nullable
as String,disk: freezed == disk ? _self.disk : disk // ignore: cast_nullable_to_non_nullable
as int?,diskUnits: null == diskUnits ? _self.diskUnits : diskUnits // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$YabsFio {

/// The block size, e.g. `4k`.
 String get bs;@JsonKey(name: 'speed_r', fromJson: yabsDouble) double? get speedRead;@JsonKey(name: 'iops_r', fromJson: yabsDouble) double? get iopsRead;@JsonKey(name: 'speed_w', fromJson: yabsDouble) double? get speedWrite;@JsonKey(name: 'iops_w', fromJson: yabsDouble) double? get iopsWrite;@JsonKey(name: 'speed_rw', fromJson: yabsDouble) double? get speedTotal;@JsonKey(name: 'iops_rw', fromJson: yabsDouble) double? get iopsTotal;@JsonKey(name: 'speed_units') String get speedUnits;
/// Create a copy of YabsFio
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$YabsFioCopyWith<YabsFio> get copyWith => _$YabsFioCopyWithImpl<YabsFio>(this as YabsFio, _$identity);

  /// Serializes this YabsFio to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is YabsFio&&(identical(other.bs, bs) || other.bs == bs)&&(identical(other.speedRead, speedRead) || other.speedRead == speedRead)&&(identical(other.iopsRead, iopsRead) || other.iopsRead == iopsRead)&&(identical(other.speedWrite, speedWrite) || other.speedWrite == speedWrite)&&(identical(other.iopsWrite, iopsWrite) || other.iopsWrite == iopsWrite)&&(identical(other.speedTotal, speedTotal) || other.speedTotal == speedTotal)&&(identical(other.iopsTotal, iopsTotal) || other.iopsTotal == iopsTotal)&&(identical(other.speedUnits, speedUnits) || other.speedUnits == speedUnits));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bs,speedRead,iopsRead,speedWrite,iopsWrite,speedTotal,iopsTotal,speedUnits);

@override
String toString() {
  return 'YabsFio(bs: $bs, speedRead: $speedRead, iopsRead: $iopsRead, speedWrite: $speedWrite, iopsWrite: $iopsWrite, speedTotal: $speedTotal, iopsTotal: $iopsTotal, speedUnits: $speedUnits)';
}


}

/// @nodoc
abstract mixin class $YabsFioCopyWith<$Res>  {
  factory $YabsFioCopyWith(YabsFio value, $Res Function(YabsFio) _then) = _$YabsFioCopyWithImpl;
@useResult
$Res call({
 String bs,@JsonKey(name: 'speed_r', fromJson: yabsDouble) double? speedRead,@JsonKey(name: 'iops_r', fromJson: yabsDouble) double? iopsRead,@JsonKey(name: 'speed_w', fromJson: yabsDouble) double? speedWrite,@JsonKey(name: 'iops_w', fromJson: yabsDouble) double? iopsWrite,@JsonKey(name: 'speed_rw', fromJson: yabsDouble) double? speedTotal,@JsonKey(name: 'iops_rw', fromJson: yabsDouble) double? iopsTotal,@JsonKey(name: 'speed_units') String speedUnits
});




}
/// @nodoc
class _$YabsFioCopyWithImpl<$Res>
    implements $YabsFioCopyWith<$Res> {
  _$YabsFioCopyWithImpl(this._self, this._then);

  final YabsFio _self;
  final $Res Function(YabsFio) _then;

/// Create a copy of YabsFio
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bs = null,Object? speedRead = freezed,Object? iopsRead = freezed,Object? speedWrite = freezed,Object? iopsWrite = freezed,Object? speedTotal = freezed,Object? iopsTotal = freezed,Object? speedUnits = null,}) {
  return _then(_self.copyWith(
bs: null == bs ? _self.bs : bs // ignore: cast_nullable_to_non_nullable
as String,speedRead: freezed == speedRead ? _self.speedRead : speedRead // ignore: cast_nullable_to_non_nullable
as double?,iopsRead: freezed == iopsRead ? _self.iopsRead : iopsRead // ignore: cast_nullable_to_non_nullable
as double?,speedWrite: freezed == speedWrite ? _self.speedWrite : speedWrite // ignore: cast_nullable_to_non_nullable
as double?,iopsWrite: freezed == iopsWrite ? _self.iopsWrite : iopsWrite // ignore: cast_nullable_to_non_nullable
as double?,speedTotal: freezed == speedTotal ? _self.speedTotal : speedTotal // ignore: cast_nullable_to_non_nullable
as double?,iopsTotal: freezed == iopsTotal ? _self.iopsTotal : iopsTotal // ignore: cast_nullable_to_non_nullable
as double?,speedUnits: null == speedUnits ? _self.speedUnits : speedUnits // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [YabsFio].
extension YabsFioPatterns on YabsFio {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _YabsFio value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _YabsFio() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _YabsFio value)  $default,){
final _that = this;
switch (_that) {
case _YabsFio():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _YabsFio value)?  $default,){
final _that = this;
switch (_that) {
case _YabsFio() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String bs, @JsonKey(name: 'speed_r', fromJson: yabsDouble)  double? speedRead, @JsonKey(name: 'iops_r', fromJson: yabsDouble)  double? iopsRead, @JsonKey(name: 'speed_w', fromJson: yabsDouble)  double? speedWrite, @JsonKey(name: 'iops_w', fromJson: yabsDouble)  double? iopsWrite, @JsonKey(name: 'speed_rw', fromJson: yabsDouble)  double? speedTotal, @JsonKey(name: 'iops_rw', fromJson: yabsDouble)  double? iopsTotal, @JsonKey(name: 'speed_units')  String speedUnits)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _YabsFio() when $default != null:
return $default(_that.bs,_that.speedRead,_that.iopsRead,_that.speedWrite,_that.iopsWrite,_that.speedTotal,_that.iopsTotal,_that.speedUnits);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String bs, @JsonKey(name: 'speed_r', fromJson: yabsDouble)  double? speedRead, @JsonKey(name: 'iops_r', fromJson: yabsDouble)  double? iopsRead, @JsonKey(name: 'speed_w', fromJson: yabsDouble)  double? speedWrite, @JsonKey(name: 'iops_w', fromJson: yabsDouble)  double? iopsWrite, @JsonKey(name: 'speed_rw', fromJson: yabsDouble)  double? speedTotal, @JsonKey(name: 'iops_rw', fromJson: yabsDouble)  double? iopsTotal, @JsonKey(name: 'speed_units')  String speedUnits)  $default,) {final _that = this;
switch (_that) {
case _YabsFio():
return $default(_that.bs,_that.speedRead,_that.iopsRead,_that.speedWrite,_that.iopsWrite,_that.speedTotal,_that.iopsTotal,_that.speedUnits);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String bs, @JsonKey(name: 'speed_r', fromJson: yabsDouble)  double? speedRead, @JsonKey(name: 'iops_r', fromJson: yabsDouble)  double? iopsRead, @JsonKey(name: 'speed_w', fromJson: yabsDouble)  double? speedWrite, @JsonKey(name: 'iops_w', fromJson: yabsDouble)  double? iopsWrite, @JsonKey(name: 'speed_rw', fromJson: yabsDouble)  double? speedTotal, @JsonKey(name: 'iops_rw', fromJson: yabsDouble)  double? iopsTotal, @JsonKey(name: 'speed_units')  String speedUnits)?  $default,) {final _that = this;
switch (_that) {
case _YabsFio() when $default != null:
return $default(_that.bs,_that.speedRead,_that.iopsRead,_that.speedWrite,_that.iopsWrite,_that.speedTotal,_that.iopsTotal,_that.speedUnits);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _YabsFio extends YabsFio {
  const _YabsFio({this.bs = '', @JsonKey(name: 'speed_r', fromJson: yabsDouble) this.speedRead, @JsonKey(name: 'iops_r', fromJson: yabsDouble) this.iopsRead, @JsonKey(name: 'speed_w', fromJson: yabsDouble) this.speedWrite, @JsonKey(name: 'iops_w', fromJson: yabsDouble) this.iopsWrite, @JsonKey(name: 'speed_rw', fromJson: yabsDouble) this.speedTotal, @JsonKey(name: 'iops_rw', fromJson: yabsDouble) this.iopsTotal, @JsonKey(name: 'speed_units') this.speedUnits = 'KBps'}): super._();
  factory _YabsFio.fromJson(Map<String, dynamic> json) => _$YabsFioFromJson(json);

/// The block size, e.g. `4k`.
@override@JsonKey() final  String bs;
@override@JsonKey(name: 'speed_r', fromJson: yabsDouble) final  double? speedRead;
@override@JsonKey(name: 'iops_r', fromJson: yabsDouble) final  double? iopsRead;
@override@JsonKey(name: 'speed_w', fromJson: yabsDouble) final  double? speedWrite;
@override@JsonKey(name: 'iops_w', fromJson: yabsDouble) final  double? iopsWrite;
@override@JsonKey(name: 'speed_rw', fromJson: yabsDouble) final  double? speedTotal;
@override@JsonKey(name: 'iops_rw', fromJson: yabsDouble) final  double? iopsTotal;
@override@JsonKey(name: 'speed_units') final  String speedUnits;

/// Create a copy of YabsFio
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$YabsFioCopyWith<_YabsFio> get copyWith => __$YabsFioCopyWithImpl<_YabsFio>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$YabsFioToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _YabsFio&&(identical(other.bs, bs) || other.bs == bs)&&(identical(other.speedRead, speedRead) || other.speedRead == speedRead)&&(identical(other.iopsRead, iopsRead) || other.iopsRead == iopsRead)&&(identical(other.speedWrite, speedWrite) || other.speedWrite == speedWrite)&&(identical(other.iopsWrite, iopsWrite) || other.iopsWrite == iopsWrite)&&(identical(other.speedTotal, speedTotal) || other.speedTotal == speedTotal)&&(identical(other.iopsTotal, iopsTotal) || other.iopsTotal == iopsTotal)&&(identical(other.speedUnits, speedUnits) || other.speedUnits == speedUnits));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bs,speedRead,iopsRead,speedWrite,iopsWrite,speedTotal,iopsTotal,speedUnits);

@override
String toString() {
  return 'YabsFio(bs: $bs, speedRead: $speedRead, iopsRead: $iopsRead, speedWrite: $speedWrite, iopsWrite: $iopsWrite, speedTotal: $speedTotal, iopsTotal: $iopsTotal, speedUnits: $speedUnits)';
}


}

/// @nodoc
abstract mixin class _$YabsFioCopyWith<$Res> implements $YabsFioCopyWith<$Res> {
  factory _$YabsFioCopyWith(_YabsFio value, $Res Function(_YabsFio) _then) = __$YabsFioCopyWithImpl;
@override @useResult
$Res call({
 String bs,@JsonKey(name: 'speed_r', fromJson: yabsDouble) double? speedRead,@JsonKey(name: 'iops_r', fromJson: yabsDouble) double? iopsRead,@JsonKey(name: 'speed_w', fromJson: yabsDouble) double? speedWrite,@JsonKey(name: 'iops_w', fromJson: yabsDouble) double? iopsWrite,@JsonKey(name: 'speed_rw', fromJson: yabsDouble) double? speedTotal,@JsonKey(name: 'iops_rw', fromJson: yabsDouble) double? iopsTotal,@JsonKey(name: 'speed_units') String speedUnits
});




}
/// @nodoc
class __$YabsFioCopyWithImpl<$Res>
    implements _$YabsFioCopyWith<$Res> {
  __$YabsFioCopyWithImpl(this._self, this._then);

  final _YabsFio _self;
  final $Res Function(_YabsFio) _then;

/// Create a copy of YabsFio
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bs = null,Object? speedRead = freezed,Object? iopsRead = freezed,Object? speedWrite = freezed,Object? iopsWrite = freezed,Object? speedTotal = freezed,Object? iopsTotal = freezed,Object? speedUnits = null,}) {
  return _then(_YabsFio(
bs: null == bs ? _self.bs : bs // ignore: cast_nullable_to_non_nullable
as String,speedRead: freezed == speedRead ? _self.speedRead : speedRead // ignore: cast_nullable_to_non_nullable
as double?,iopsRead: freezed == iopsRead ? _self.iopsRead : iopsRead // ignore: cast_nullable_to_non_nullable
as double?,speedWrite: freezed == speedWrite ? _self.speedWrite : speedWrite // ignore: cast_nullable_to_non_nullable
as double?,iopsWrite: freezed == iopsWrite ? _self.iopsWrite : iopsWrite // ignore: cast_nullable_to_non_nullable
as double?,speedTotal: freezed == speedTotal ? _self.speedTotal : speedTotal // ignore: cast_nullable_to_non_nullable
as double?,iopsTotal: freezed == iopsTotal ? _self.iopsTotal : iopsTotal // ignore: cast_nullable_to_non_nullable
as double?,speedUnits: null == speedUnits ? _self.speedUnits : speedUnits // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$YabsIperf {

/// `IPv4` or `IPv6`.
 String get mode; String get provider; String get loc; String get send; String get recv; String get latency;
/// Create a copy of YabsIperf
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$YabsIperfCopyWith<YabsIperf> get copyWith => _$YabsIperfCopyWithImpl<YabsIperf>(this as YabsIperf, _$identity);

  /// Serializes this YabsIperf to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is YabsIperf&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.loc, loc) || other.loc == loc)&&(identical(other.send, send) || other.send == send)&&(identical(other.recv, recv) || other.recv == recv)&&(identical(other.latency, latency) || other.latency == latency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mode,provider,loc,send,recv,latency);

@override
String toString() {
  return 'YabsIperf(mode: $mode, provider: $provider, loc: $loc, send: $send, recv: $recv, latency: $latency)';
}


}

/// @nodoc
abstract mixin class $YabsIperfCopyWith<$Res>  {
  factory $YabsIperfCopyWith(YabsIperf value, $Res Function(YabsIperf) _then) = _$YabsIperfCopyWithImpl;
@useResult
$Res call({
 String mode, String provider, String loc, String send, String recv, String latency
});




}
/// @nodoc
class _$YabsIperfCopyWithImpl<$Res>
    implements $YabsIperfCopyWith<$Res> {
  _$YabsIperfCopyWithImpl(this._self, this._then);

  final YabsIperf _self;
  final $Res Function(YabsIperf) _then;

/// Create a copy of YabsIperf
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mode = null,Object? provider = null,Object? loc = null,Object? send = null,Object? recv = null,Object? latency = null,}) {
  return _then(_self.copyWith(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,loc: null == loc ? _self.loc : loc // ignore: cast_nullable_to_non_nullable
as String,send: null == send ? _self.send : send // ignore: cast_nullable_to_non_nullable
as String,recv: null == recv ? _self.recv : recv // ignore: cast_nullable_to_non_nullable
as String,latency: null == latency ? _self.latency : latency // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [YabsIperf].
extension YabsIperfPatterns on YabsIperf {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _YabsIperf value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _YabsIperf() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _YabsIperf value)  $default,){
final _that = this;
switch (_that) {
case _YabsIperf():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _YabsIperf value)?  $default,){
final _that = this;
switch (_that) {
case _YabsIperf() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String mode,  String provider,  String loc,  String send,  String recv,  String latency)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _YabsIperf() when $default != null:
return $default(_that.mode,_that.provider,_that.loc,_that.send,_that.recv,_that.latency);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String mode,  String provider,  String loc,  String send,  String recv,  String latency)  $default,) {final _that = this;
switch (_that) {
case _YabsIperf():
return $default(_that.mode,_that.provider,_that.loc,_that.send,_that.recv,_that.latency);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String mode,  String provider,  String loc,  String send,  String recv,  String latency)?  $default,) {final _that = this;
switch (_that) {
case _YabsIperf() when $default != null:
return $default(_that.mode,_that.provider,_that.loc,_that.send,_that.recv,_that.latency);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _YabsIperf extends YabsIperf {
  const _YabsIperf({this.mode = '', this.provider = '', this.loc = '', this.send = '', this.recv = '', this.latency = ''}): super._();
  factory _YabsIperf.fromJson(Map<String, dynamic> json) => _$YabsIperfFromJson(json);

/// `IPv4` or `IPv6`.
@override@JsonKey() final  String mode;
@override@JsonKey() final  String provider;
@override@JsonKey() final  String loc;
@override@JsonKey() final  String send;
@override@JsonKey() final  String recv;
@override@JsonKey() final  String latency;

/// Create a copy of YabsIperf
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$YabsIperfCopyWith<_YabsIperf> get copyWith => __$YabsIperfCopyWithImpl<_YabsIperf>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$YabsIperfToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _YabsIperf&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.loc, loc) || other.loc == loc)&&(identical(other.send, send) || other.send == send)&&(identical(other.recv, recv) || other.recv == recv)&&(identical(other.latency, latency) || other.latency == latency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mode,provider,loc,send,recv,latency);

@override
String toString() {
  return 'YabsIperf(mode: $mode, provider: $provider, loc: $loc, send: $send, recv: $recv, latency: $latency)';
}


}

/// @nodoc
abstract mixin class _$YabsIperfCopyWith<$Res> implements $YabsIperfCopyWith<$Res> {
  factory _$YabsIperfCopyWith(_YabsIperf value, $Res Function(_YabsIperf) _then) = __$YabsIperfCopyWithImpl;
@override @useResult
$Res call({
 String mode, String provider, String loc, String send, String recv, String latency
});




}
/// @nodoc
class __$YabsIperfCopyWithImpl<$Res>
    implements _$YabsIperfCopyWith<$Res> {
  __$YabsIperfCopyWithImpl(this._self, this._then);

  final _YabsIperf _self;
  final $Res Function(_YabsIperf) _then;

/// Create a copy of YabsIperf
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mode = null,Object? provider = null,Object? loc = null,Object? send = null,Object? recv = null,Object? latency = null,}) {
  return _then(_YabsIperf(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,loc: null == loc ? _self.loc : loc // ignore: cast_nullable_to_non_nullable
as String,send: null == send ? _self.send : send // ignore: cast_nullable_to_non_nullable
as String,recv: null == recv ? _self.recv : recv // ignore: cast_nullable_to_non_nullable
as String,latency: null == latency ? _self.latency : latency // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$YabsGeekbench {

@JsonKey(fromJson: yabsInt) int? get version;@JsonKey(fromJson: yabsInt) int? get single;@JsonKey(fromJson: yabsInt) int? get multi;/// The public `browser.geekbench.com` page this run was published to.
///
/// Kept because it is the only way to reach the detail Geekbench keeps and
/// this does not — and because a user who wants the run taken down needs
/// somewhere to go.
 String get url;
/// Create a copy of YabsGeekbench
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$YabsGeekbenchCopyWith<YabsGeekbench> get copyWith => _$YabsGeekbenchCopyWithImpl<YabsGeekbench>(this as YabsGeekbench, _$identity);

  /// Serializes this YabsGeekbench to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is YabsGeekbench&&(identical(other.version, version) || other.version == version)&&(identical(other.single, single) || other.single == single)&&(identical(other.multi, multi) || other.multi == multi)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,single,multi,url);

@override
String toString() {
  return 'YabsGeekbench(version: $version, single: $single, multi: $multi, url: $url)';
}


}

/// @nodoc
abstract mixin class $YabsGeekbenchCopyWith<$Res>  {
  factory $YabsGeekbenchCopyWith(YabsGeekbench value, $Res Function(YabsGeekbench) _then) = _$YabsGeekbenchCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: yabsInt) int? version,@JsonKey(fromJson: yabsInt) int? single,@JsonKey(fromJson: yabsInt) int? multi, String url
});




}
/// @nodoc
class _$YabsGeekbenchCopyWithImpl<$Res>
    implements $YabsGeekbenchCopyWith<$Res> {
  _$YabsGeekbenchCopyWithImpl(this._self, this._then);

  final YabsGeekbench _self;
  final $Res Function(YabsGeekbench) _then;

/// Create a copy of YabsGeekbench
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = freezed,Object? single = freezed,Object? multi = freezed,Object? url = null,}) {
  return _then(_self.copyWith(
version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int?,single: freezed == single ? _self.single : single // ignore: cast_nullable_to_non_nullable
as int?,multi: freezed == multi ? _self.multi : multi // ignore: cast_nullable_to_non_nullable
as int?,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [YabsGeekbench].
extension YabsGeekbenchPatterns on YabsGeekbench {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _YabsGeekbench value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _YabsGeekbench() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _YabsGeekbench value)  $default,){
final _that = this;
switch (_that) {
case _YabsGeekbench():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _YabsGeekbench value)?  $default,){
final _that = this;
switch (_that) {
case _YabsGeekbench() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: yabsInt)  int? version, @JsonKey(fromJson: yabsInt)  int? single, @JsonKey(fromJson: yabsInt)  int? multi,  String url)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _YabsGeekbench() when $default != null:
return $default(_that.version,_that.single,_that.multi,_that.url);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: yabsInt)  int? version, @JsonKey(fromJson: yabsInt)  int? single, @JsonKey(fromJson: yabsInt)  int? multi,  String url)  $default,) {final _that = this;
switch (_that) {
case _YabsGeekbench():
return $default(_that.version,_that.single,_that.multi,_that.url);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: yabsInt)  int? version, @JsonKey(fromJson: yabsInt)  int? single, @JsonKey(fromJson: yabsInt)  int? multi,  String url)?  $default,) {final _that = this;
switch (_that) {
case _YabsGeekbench() when $default != null:
return $default(_that.version,_that.single,_that.multi,_that.url);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _YabsGeekbench implements YabsGeekbench {
  const _YabsGeekbench({@JsonKey(fromJson: yabsInt) this.version, @JsonKey(fromJson: yabsInt) this.single, @JsonKey(fromJson: yabsInt) this.multi, this.url = ''});
  factory _YabsGeekbench.fromJson(Map<String, dynamic> json) => _$YabsGeekbenchFromJson(json);

@override@JsonKey(fromJson: yabsInt) final  int? version;
@override@JsonKey(fromJson: yabsInt) final  int? single;
@override@JsonKey(fromJson: yabsInt) final  int? multi;
/// The public `browser.geekbench.com` page this run was published to.
///
/// Kept because it is the only way to reach the detail Geekbench keeps and
/// this does not — and because a user who wants the run taken down needs
/// somewhere to go.
@override@JsonKey() final  String url;

/// Create a copy of YabsGeekbench
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$YabsGeekbenchCopyWith<_YabsGeekbench> get copyWith => __$YabsGeekbenchCopyWithImpl<_YabsGeekbench>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$YabsGeekbenchToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _YabsGeekbench&&(identical(other.version, version) || other.version == version)&&(identical(other.single, single) || other.single == single)&&(identical(other.multi, multi) || other.multi == multi)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,single,multi,url);

@override
String toString() {
  return 'YabsGeekbench(version: $version, single: $single, multi: $multi, url: $url)';
}


}

/// @nodoc
abstract mixin class _$YabsGeekbenchCopyWith<$Res> implements $YabsGeekbenchCopyWith<$Res> {
  factory _$YabsGeekbenchCopyWith(_YabsGeekbench value, $Res Function(_YabsGeekbench) _then) = __$YabsGeekbenchCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: yabsInt) int? version,@JsonKey(fromJson: yabsInt) int? single,@JsonKey(fromJson: yabsInt) int? multi, String url
});




}
/// @nodoc
class __$YabsGeekbenchCopyWithImpl<$Res>
    implements _$YabsGeekbenchCopyWith<$Res> {
  __$YabsGeekbenchCopyWithImpl(this._self, this._then);

  final _YabsGeekbench _self;
  final $Res Function(_YabsGeekbench) _then;

/// Create a copy of YabsGeekbench
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = freezed,Object? single = freezed,Object? multi = freezed,Object? url = null,}) {
  return _then(_YabsGeekbench(
version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int?,single: freezed == single ? _self.single : single // ignore: cast_nullable_to_non_nullable
as int?,multi: freezed == multi ? _self.multi : multi // ignore: cast_nullable_to_non_nullable
as int?,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$YabsIpInfo {

 String get protocol; String get isp; String get asn; String get org; String get city; String get region;@JsonKey(name: 'region_code') String get regionCode; String get country;
/// Create a copy of YabsIpInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$YabsIpInfoCopyWith<YabsIpInfo> get copyWith => _$YabsIpInfoCopyWithImpl<YabsIpInfo>(this as YabsIpInfo, _$identity);

  /// Serializes this YabsIpInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is YabsIpInfo&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.isp, isp) || other.isp == isp)&&(identical(other.asn, asn) || other.asn == asn)&&(identical(other.org, org) || other.org == org)&&(identical(other.city, city) || other.city == city)&&(identical(other.region, region) || other.region == region)&&(identical(other.regionCode, regionCode) || other.regionCode == regionCode)&&(identical(other.country, country) || other.country == country));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,protocol,isp,asn,org,city,region,regionCode,country);

@override
String toString() {
  return 'YabsIpInfo(protocol: $protocol, isp: $isp, asn: $asn, org: $org, city: $city, region: $region, regionCode: $regionCode, country: $country)';
}


}

/// @nodoc
abstract mixin class $YabsIpInfoCopyWith<$Res>  {
  factory $YabsIpInfoCopyWith(YabsIpInfo value, $Res Function(YabsIpInfo) _then) = _$YabsIpInfoCopyWithImpl;
@useResult
$Res call({
 String protocol, String isp, String asn, String org, String city, String region,@JsonKey(name: 'region_code') String regionCode, String country
});




}
/// @nodoc
class _$YabsIpInfoCopyWithImpl<$Res>
    implements $YabsIpInfoCopyWith<$Res> {
  _$YabsIpInfoCopyWithImpl(this._self, this._then);

  final YabsIpInfo _self;
  final $Res Function(YabsIpInfo) _then;

/// Create a copy of YabsIpInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? protocol = null,Object? isp = null,Object? asn = null,Object? org = null,Object? city = null,Object? region = null,Object? regionCode = null,Object? country = null,}) {
  return _then(_self.copyWith(
protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as String,isp: null == isp ? _self.isp : isp // ignore: cast_nullable_to_non_nullable
as String,asn: null == asn ? _self.asn : asn // ignore: cast_nullable_to_non_nullable
as String,org: null == org ? _self.org : org // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,region: null == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String,regionCode: null == regionCode ? _self.regionCode : regionCode // ignore: cast_nullable_to_non_nullable
as String,country: null == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [YabsIpInfo].
extension YabsIpInfoPatterns on YabsIpInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _YabsIpInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _YabsIpInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _YabsIpInfo value)  $default,){
final _that = this;
switch (_that) {
case _YabsIpInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _YabsIpInfo value)?  $default,){
final _that = this;
switch (_that) {
case _YabsIpInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String protocol,  String isp,  String asn,  String org,  String city,  String region, @JsonKey(name: 'region_code')  String regionCode,  String country)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _YabsIpInfo() when $default != null:
return $default(_that.protocol,_that.isp,_that.asn,_that.org,_that.city,_that.region,_that.regionCode,_that.country);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String protocol,  String isp,  String asn,  String org,  String city,  String region, @JsonKey(name: 'region_code')  String regionCode,  String country)  $default,) {final _that = this;
switch (_that) {
case _YabsIpInfo():
return $default(_that.protocol,_that.isp,_that.asn,_that.org,_that.city,_that.region,_that.regionCode,_that.country);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String protocol,  String isp,  String asn,  String org,  String city,  String region, @JsonKey(name: 'region_code')  String regionCode,  String country)?  $default,) {final _that = this;
switch (_that) {
case _YabsIpInfo() when $default != null:
return $default(_that.protocol,_that.isp,_that.asn,_that.org,_that.city,_that.region,_that.regionCode,_that.country);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _YabsIpInfo implements YabsIpInfo {
  const _YabsIpInfo({this.protocol = '', this.isp = '', this.asn = '', this.org = '', this.city = '', this.region = '', @JsonKey(name: 'region_code') this.regionCode = '', this.country = ''});
  factory _YabsIpInfo.fromJson(Map<String, dynamic> json) => _$YabsIpInfoFromJson(json);

@override@JsonKey() final  String protocol;
@override@JsonKey() final  String isp;
@override@JsonKey() final  String asn;
@override@JsonKey() final  String org;
@override@JsonKey() final  String city;
@override@JsonKey() final  String region;
@override@JsonKey(name: 'region_code') final  String regionCode;
@override@JsonKey() final  String country;

/// Create a copy of YabsIpInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$YabsIpInfoCopyWith<_YabsIpInfo> get copyWith => __$YabsIpInfoCopyWithImpl<_YabsIpInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$YabsIpInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _YabsIpInfo&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.isp, isp) || other.isp == isp)&&(identical(other.asn, asn) || other.asn == asn)&&(identical(other.org, org) || other.org == org)&&(identical(other.city, city) || other.city == city)&&(identical(other.region, region) || other.region == region)&&(identical(other.regionCode, regionCode) || other.regionCode == regionCode)&&(identical(other.country, country) || other.country == country));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,protocol,isp,asn,org,city,region,regionCode,country);

@override
String toString() {
  return 'YabsIpInfo(protocol: $protocol, isp: $isp, asn: $asn, org: $org, city: $city, region: $region, regionCode: $regionCode, country: $country)';
}


}

/// @nodoc
abstract mixin class _$YabsIpInfoCopyWith<$Res> implements $YabsIpInfoCopyWith<$Res> {
  factory _$YabsIpInfoCopyWith(_YabsIpInfo value, $Res Function(_YabsIpInfo) _then) = __$YabsIpInfoCopyWithImpl;
@override @useResult
$Res call({
 String protocol, String isp, String asn, String org, String city, String region,@JsonKey(name: 'region_code') String regionCode, String country
});




}
/// @nodoc
class __$YabsIpInfoCopyWithImpl<$Res>
    implements _$YabsIpInfoCopyWith<$Res> {
  __$YabsIpInfoCopyWithImpl(this._self, this._then);

  final _YabsIpInfo _self;
  final $Res Function(_YabsIpInfo) _then;

/// Create a copy of YabsIpInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? protocol = null,Object? isp = null,Object? asn = null,Object? org = null,Object? city = null,Object? region = null,Object? regionCode = null,Object? country = null,}) {
  return _then(_YabsIpInfo(
protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as String,isp: null == isp ? _self.isp : isp // ignore: cast_nullable_to_non_nullable
as String,asn: null == asn ? _self.asn : asn // ignore: cast_nullable_to_non_nullable
as String,org: null == org ? _self.org : org // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,region: null == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String,regionCode: null == regionCode ? _self.regionCode : regionCode // ignore: cast_nullable_to_non_nullable
as String,country: null == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$YabsRuntime {

@JsonKey(fromJson: yabsInt) int? get start;@JsonKey(fromJson: yabsInt) int? get end;/// Seconds the whole run took, by yabs' own clock.
@JsonKey(fromJson: yabsInt) int? get elapsed;
/// Create a copy of YabsRuntime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$YabsRuntimeCopyWith<YabsRuntime> get copyWith => _$YabsRuntimeCopyWithImpl<YabsRuntime>(this as YabsRuntime, _$identity);

  /// Serializes this YabsRuntime to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is YabsRuntime&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.elapsed, elapsed) || other.elapsed == elapsed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,start,end,elapsed);

@override
String toString() {
  return 'YabsRuntime(start: $start, end: $end, elapsed: $elapsed)';
}


}

/// @nodoc
abstract mixin class $YabsRuntimeCopyWith<$Res>  {
  factory $YabsRuntimeCopyWith(YabsRuntime value, $Res Function(YabsRuntime) _then) = _$YabsRuntimeCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: yabsInt) int? start,@JsonKey(fromJson: yabsInt) int? end,@JsonKey(fromJson: yabsInt) int? elapsed
});




}
/// @nodoc
class _$YabsRuntimeCopyWithImpl<$Res>
    implements $YabsRuntimeCopyWith<$Res> {
  _$YabsRuntimeCopyWithImpl(this._self, this._then);

  final YabsRuntime _self;
  final $Res Function(YabsRuntime) _then;

/// Create a copy of YabsRuntime
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? start = freezed,Object? end = freezed,Object? elapsed = freezed,}) {
  return _then(_self.copyWith(
start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int?,elapsed: freezed == elapsed ? _self.elapsed : elapsed // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [YabsRuntime].
extension YabsRuntimePatterns on YabsRuntime {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _YabsRuntime value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _YabsRuntime() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _YabsRuntime value)  $default,){
final _that = this;
switch (_that) {
case _YabsRuntime():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _YabsRuntime value)?  $default,){
final _that = this;
switch (_that) {
case _YabsRuntime() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: yabsInt)  int? start, @JsonKey(fromJson: yabsInt)  int? end, @JsonKey(fromJson: yabsInt)  int? elapsed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _YabsRuntime() when $default != null:
return $default(_that.start,_that.end,_that.elapsed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: yabsInt)  int? start, @JsonKey(fromJson: yabsInt)  int? end, @JsonKey(fromJson: yabsInt)  int? elapsed)  $default,) {final _that = this;
switch (_that) {
case _YabsRuntime():
return $default(_that.start,_that.end,_that.elapsed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: yabsInt)  int? start, @JsonKey(fromJson: yabsInt)  int? end, @JsonKey(fromJson: yabsInt)  int? elapsed)?  $default,) {final _that = this;
switch (_that) {
case _YabsRuntime() when $default != null:
return $default(_that.start,_that.end,_that.elapsed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _YabsRuntime implements YabsRuntime {
  const _YabsRuntime({@JsonKey(fromJson: yabsInt) this.start, @JsonKey(fromJson: yabsInt) this.end, @JsonKey(fromJson: yabsInt) this.elapsed});
  factory _YabsRuntime.fromJson(Map<String, dynamic> json) => _$YabsRuntimeFromJson(json);

@override@JsonKey(fromJson: yabsInt) final  int? start;
@override@JsonKey(fromJson: yabsInt) final  int? end;
/// Seconds the whole run took, by yabs' own clock.
@override@JsonKey(fromJson: yabsInt) final  int? elapsed;

/// Create a copy of YabsRuntime
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$YabsRuntimeCopyWith<_YabsRuntime> get copyWith => __$YabsRuntimeCopyWithImpl<_YabsRuntime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$YabsRuntimeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _YabsRuntime&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.elapsed, elapsed) || other.elapsed == elapsed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,start,end,elapsed);

@override
String toString() {
  return 'YabsRuntime(start: $start, end: $end, elapsed: $elapsed)';
}


}

/// @nodoc
abstract mixin class _$YabsRuntimeCopyWith<$Res> implements $YabsRuntimeCopyWith<$Res> {
  factory _$YabsRuntimeCopyWith(_YabsRuntime value, $Res Function(_YabsRuntime) _then) = __$YabsRuntimeCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: yabsInt) int? start,@JsonKey(fromJson: yabsInt) int? end,@JsonKey(fromJson: yabsInt) int? elapsed
});




}
/// @nodoc
class __$YabsRuntimeCopyWithImpl<$Res>
    implements _$YabsRuntimeCopyWith<$Res> {
  __$YabsRuntimeCopyWithImpl(this._self, this._then);

  final _YabsRuntime _self;
  final $Res Function(_YabsRuntime) _then;

/// Create a copy of YabsRuntime
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? start = freezed,Object? end = freezed,Object? elapsed = freezed,}) {
  return _then(_YabsRuntime(
start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int?,elapsed: freezed == elapsed ? _self.elapsed : elapsed // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
