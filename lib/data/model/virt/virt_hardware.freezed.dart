// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'virt_hardware.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VirtHardware {

 VirtGuestKind get kind;/// There is a running definition too: a change it cannot take waits for
/// the next start, and shows in [pending] until then.
 bool get running; VirtHwCpu get cpu; VirtHwMemory get memory; List<VirtHwDisk> get disks; List<VirtHwNic> get nics;/// Boot devices in order, by [VirtHwDisk.key] / [VirtHwNic.key]. Null
/// where there is no order to set (a container).
 List<String>? get boot; bool get autostart; List<VirtPendingField> get pending;/// What an edit is made from, sent back with it: PVE's `digest`, the
/// persistent XML libvirt printed. An edit made from an older read is
/// refused (`VirtErrType.conflict`) rather than undoing someone else's.
 String? get revision; VirtHwLimits get limits;/// PVE: the CPU models the node offers, for [VirtHwCpu.type].
 List<String> get cpuTypes;/// The configuration as the host writes it — `qm config`'s lines, the
/// persistent XML — for the view to show as it is.
 String? get configText;
/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHardwareCopyWith<VirtHardware> get copyWith => _$VirtHardwareCopyWithImpl<VirtHardware>(this as VirtHardware, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHardware&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.running, running) || other.running == running)&&(identical(other.cpu, cpu) || other.cpu == cpu)&&(identical(other.memory, memory) || other.memory == memory)&&const DeepCollectionEquality().equals(other.disks, disks)&&const DeepCollectionEquality().equals(other.nics, nics)&&const DeepCollectionEquality().equals(other.boot, boot)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&const DeepCollectionEquality().equals(other.pending, pending)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.limits, limits) || other.limits == limits)&&const DeepCollectionEquality().equals(other.cpuTypes, cpuTypes)&&(identical(other.configText, configText) || other.configText == configText));
}


@override
int get hashCode => Object.hash(runtimeType,kind,running,cpu,memory,const DeepCollectionEquality().hash(disks),const DeepCollectionEquality().hash(nics),const DeepCollectionEquality().hash(boot),autostart,const DeepCollectionEquality().hash(pending),revision,limits,const DeepCollectionEquality().hash(cpuTypes),configText);

@override
String toString() {
  return 'VirtHardware(kind: $kind, running: $running, cpu: $cpu, memory: $memory, disks: $disks, nics: $nics, boot: $boot, autostart: $autostart, pending: $pending, revision: $revision, limits: $limits, cpuTypes: $cpuTypes, configText: $configText)';
}


}

/// @nodoc
abstract mixin class $VirtHardwareCopyWith<$Res>  {
  factory $VirtHardwareCopyWith(VirtHardware value, $Res Function(VirtHardware) _then) = _$VirtHardwareCopyWithImpl;
@useResult
$Res call({
 VirtGuestKind kind, bool running, VirtHwCpu cpu, VirtHwMemory memory, List<VirtHwDisk> disks, List<VirtHwNic> nics, List<String>? boot, bool autostart, List<VirtPendingField> pending, String? revision, VirtHwLimits limits, List<String> cpuTypes, String? configText
});


$VirtHwCpuCopyWith<$Res> get cpu;$VirtHwMemoryCopyWith<$Res> get memory;$VirtHwLimitsCopyWith<$Res> get limits;

}
/// @nodoc
class _$VirtHardwareCopyWithImpl<$Res>
    implements $VirtHardwareCopyWith<$Res> {
  _$VirtHardwareCopyWithImpl(this._self, this._then);

  final VirtHardware _self;
  final $Res Function(VirtHardware) _then;

/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? running = null,Object? cpu = null,Object? memory = null,Object? disks = null,Object? nics = null,Object? boot = freezed,Object? autostart = null,Object? pending = null,Object? revision = freezed,Object? limits = null,Object? cpuTypes = null,Object? configText = freezed,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as VirtGuestKind,running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as bool,cpu: null == cpu ? _self.cpu : cpu // ignore: cast_nullable_to_non_nullable
as VirtHwCpu,memory: null == memory ? _self.memory : memory // ignore: cast_nullable_to_non_nullable
as VirtHwMemory,disks: null == disks ? _self.disks : disks // ignore: cast_nullable_to_non_nullable
as List<VirtHwDisk>,nics: null == nics ? _self.nics : nics // ignore: cast_nullable_to_non_nullable
as List<VirtHwNic>,boot: freezed == boot ? _self.boot : boot // ignore: cast_nullable_to_non_nullable
as List<String>?,autostart: null == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool,pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as List<VirtPendingField>,revision: freezed == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as String?,limits: null == limits ? _self.limits : limits // ignore: cast_nullable_to_non_nullable
as VirtHwLimits,cpuTypes: null == cpuTypes ? _self.cpuTypes : cpuTypes // ignore: cast_nullable_to_non_nullable
as List<String>,configText: freezed == configText ? _self.configText : configText // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtHwCpuCopyWith<$Res> get cpu {
  
  return $VirtHwCpuCopyWith<$Res>(_self.cpu, (value) {
    return _then(_self.copyWith(cpu: value));
  });
}/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtHwMemoryCopyWith<$Res> get memory {
  
  return $VirtHwMemoryCopyWith<$Res>(_self.memory, (value) {
    return _then(_self.copyWith(memory: value));
  });
}/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtHwLimitsCopyWith<$Res> get limits {
  
  return $VirtHwLimitsCopyWith<$Res>(_self.limits, (value) {
    return _then(_self.copyWith(limits: value));
  });
}
}


/// Adds pattern-matching-related methods to [VirtHardware].
extension VirtHardwarePatterns on VirtHardware {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtHardware value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtHardware() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtHardware value)  $default,){
final _that = this;
switch (_that) {
case _VirtHardware():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtHardware value)?  $default,){
final _that = this;
switch (_that) {
case _VirtHardware() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( VirtGuestKind kind,  bool running,  VirtHwCpu cpu,  VirtHwMemory memory,  List<VirtHwDisk> disks,  List<VirtHwNic> nics,  List<String>? boot,  bool autostart,  List<VirtPendingField> pending,  String? revision,  VirtHwLimits limits,  List<String> cpuTypes,  String? configText)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHardware() when $default != null:
return $default(_that.kind,_that.running,_that.cpu,_that.memory,_that.disks,_that.nics,_that.boot,_that.autostart,_that.pending,_that.revision,_that.limits,_that.cpuTypes,_that.configText);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( VirtGuestKind kind,  bool running,  VirtHwCpu cpu,  VirtHwMemory memory,  List<VirtHwDisk> disks,  List<VirtHwNic> nics,  List<String>? boot,  bool autostart,  List<VirtPendingField> pending,  String? revision,  VirtHwLimits limits,  List<String> cpuTypes,  String? configText)  $default,) {final _that = this;
switch (_that) {
case _VirtHardware():
return $default(_that.kind,_that.running,_that.cpu,_that.memory,_that.disks,_that.nics,_that.boot,_that.autostart,_that.pending,_that.revision,_that.limits,_that.cpuTypes,_that.configText);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( VirtGuestKind kind,  bool running,  VirtHwCpu cpu,  VirtHwMemory memory,  List<VirtHwDisk> disks,  List<VirtHwNic> nics,  List<String>? boot,  bool autostart,  List<VirtPendingField> pending,  String? revision,  VirtHwLimits limits,  List<String> cpuTypes,  String? configText)?  $default,) {final _that = this;
switch (_that) {
case _VirtHardware() when $default != null:
return $default(_that.kind,_that.running,_that.cpu,_that.memory,_that.disks,_that.nics,_that.boot,_that.autostart,_that.pending,_that.revision,_that.limits,_that.cpuTypes,_that.configText);case _:
  return null;

}
}

}

/// @nodoc


class _VirtHardware extends VirtHardware {
  const _VirtHardware({required this.kind, required this.running, required this.cpu, required this.memory, final  List<VirtHwDisk> disks = const <VirtHwDisk>[], final  List<VirtHwNic> nics = const <VirtHwNic>[], final  List<String>? boot, this.autostart = false, final  List<VirtPendingField> pending = const <VirtPendingField>[], this.revision, this.limits = const VirtHwLimits(), final  List<String> cpuTypes = const <String>[], this.configText}): _disks = disks,_nics = nics,_boot = boot,_pending = pending,_cpuTypes = cpuTypes,super._();
  

@override final  VirtGuestKind kind;
/// There is a running definition too: a change it cannot take waits for
/// the next start, and shows in [pending] until then.
@override final  bool running;
@override final  VirtHwCpu cpu;
@override final  VirtHwMemory memory;
 final  List<VirtHwDisk> _disks;
@override@JsonKey() List<VirtHwDisk> get disks {
  if (_disks is EqualUnmodifiableListView) return _disks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_disks);
}

 final  List<VirtHwNic> _nics;
@override@JsonKey() List<VirtHwNic> get nics {
  if (_nics is EqualUnmodifiableListView) return _nics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nics);
}

/// Boot devices in order, by [VirtHwDisk.key] / [VirtHwNic.key]. Null
/// where there is no order to set (a container).
 final  List<String>? _boot;
/// Boot devices in order, by [VirtHwDisk.key] / [VirtHwNic.key]. Null
/// where there is no order to set (a container).
@override List<String>? get boot {
  final value = _boot;
  if (value == null) return null;
  if (_boot is EqualUnmodifiableListView) return _boot;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey() final  bool autostart;
 final  List<VirtPendingField> _pending;
@override@JsonKey() List<VirtPendingField> get pending {
  if (_pending is EqualUnmodifiableListView) return _pending;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pending);
}

/// What an edit is made from, sent back with it: PVE's `digest`, the
/// persistent XML libvirt printed. An edit made from an older read is
/// refused (`VirtErrType.conflict`) rather than undoing someone else's.
@override final  String? revision;
@override@JsonKey() final  VirtHwLimits limits;
/// PVE: the CPU models the node offers, for [VirtHwCpu.type].
 final  List<String> _cpuTypes;
/// PVE: the CPU models the node offers, for [VirtHwCpu.type].
@override@JsonKey() List<String> get cpuTypes {
  if (_cpuTypes is EqualUnmodifiableListView) return _cpuTypes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cpuTypes);
}

/// The configuration as the host writes it — `qm config`'s lines, the
/// persistent XML — for the view to show as it is.
@override final  String? configText;

/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHardwareCopyWith<_VirtHardware> get copyWith => __$VirtHardwareCopyWithImpl<_VirtHardware>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHardware&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.running, running) || other.running == running)&&(identical(other.cpu, cpu) || other.cpu == cpu)&&(identical(other.memory, memory) || other.memory == memory)&&const DeepCollectionEquality().equals(other._disks, _disks)&&const DeepCollectionEquality().equals(other._nics, _nics)&&const DeepCollectionEquality().equals(other._boot, _boot)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&const DeepCollectionEquality().equals(other._pending, _pending)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.limits, limits) || other.limits == limits)&&const DeepCollectionEquality().equals(other._cpuTypes, _cpuTypes)&&(identical(other.configText, configText) || other.configText == configText));
}


@override
int get hashCode => Object.hash(runtimeType,kind,running,cpu,memory,const DeepCollectionEquality().hash(_disks),const DeepCollectionEquality().hash(_nics),const DeepCollectionEquality().hash(_boot),autostart,const DeepCollectionEquality().hash(_pending),revision,limits,const DeepCollectionEquality().hash(_cpuTypes),configText);

@override
String toString() {
  return 'VirtHardware(kind: $kind, running: $running, cpu: $cpu, memory: $memory, disks: $disks, nics: $nics, boot: $boot, autostart: $autostart, pending: $pending, revision: $revision, limits: $limits, cpuTypes: $cpuTypes, configText: $configText)';
}


}

/// @nodoc
abstract mixin class _$VirtHardwareCopyWith<$Res> implements $VirtHardwareCopyWith<$Res> {
  factory _$VirtHardwareCopyWith(_VirtHardware value, $Res Function(_VirtHardware) _then) = __$VirtHardwareCopyWithImpl;
@override @useResult
$Res call({
 VirtGuestKind kind, bool running, VirtHwCpu cpu, VirtHwMemory memory, List<VirtHwDisk> disks, List<VirtHwNic> nics, List<String>? boot, bool autostart, List<VirtPendingField> pending, String? revision, VirtHwLimits limits, List<String> cpuTypes, String? configText
});


@override $VirtHwCpuCopyWith<$Res> get cpu;@override $VirtHwMemoryCopyWith<$Res> get memory;@override $VirtHwLimitsCopyWith<$Res> get limits;

}
/// @nodoc
class __$VirtHardwareCopyWithImpl<$Res>
    implements _$VirtHardwareCopyWith<$Res> {
  __$VirtHardwareCopyWithImpl(this._self, this._then);

  final _VirtHardware _self;
  final $Res Function(_VirtHardware) _then;

/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? running = null,Object? cpu = null,Object? memory = null,Object? disks = null,Object? nics = null,Object? boot = freezed,Object? autostart = null,Object? pending = null,Object? revision = freezed,Object? limits = null,Object? cpuTypes = null,Object? configText = freezed,}) {
  return _then(_VirtHardware(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as VirtGuestKind,running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as bool,cpu: null == cpu ? _self.cpu : cpu // ignore: cast_nullable_to_non_nullable
as VirtHwCpu,memory: null == memory ? _self.memory : memory // ignore: cast_nullable_to_non_nullable
as VirtHwMemory,disks: null == disks ? _self._disks : disks // ignore: cast_nullable_to_non_nullable
as List<VirtHwDisk>,nics: null == nics ? _self._nics : nics // ignore: cast_nullable_to_non_nullable
as List<VirtHwNic>,boot: freezed == boot ? _self._boot : boot // ignore: cast_nullable_to_non_nullable
as List<String>?,autostart: null == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool,pending: null == pending ? _self._pending : pending // ignore: cast_nullable_to_non_nullable
as List<VirtPendingField>,revision: freezed == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as String?,limits: null == limits ? _self.limits : limits // ignore: cast_nullable_to_non_nullable
as VirtHwLimits,cpuTypes: null == cpuTypes ? _self._cpuTypes : cpuTypes // ignore: cast_nullable_to_non_nullable
as List<String>,configText: freezed == configText ? _self.configText : configText // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtHwCpuCopyWith<$Res> get cpu {
  
  return $VirtHwCpuCopyWith<$Res>(_self.cpu, (value) {
    return _then(_self.copyWith(cpu: value));
  });
}/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtHwMemoryCopyWith<$Res> get memory {
  
  return $VirtHwMemoryCopyWith<$Res>(_self.memory, (value) {
    return _then(_self.copyWith(memory: value));
  });
}/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtHwLimitsCopyWith<$Res> get limits {
  
  return $VirtHwLimitsCopyWith<$Res>(_self.limits, (value) {
    return _then(_self.copyWith(limits: value));
  });
}
}

/// @nodoc
mixin _$VirtHwCpu {

 int get sockets; int get cores;/// libvirt's threads per core, kept as they are; always 1 on PVE.
 int get threads;/// vCPUs online: PVE's `vcpus`, libvirt's `current`. Null for all of
/// them.
 int? get online;/// PVE's CPU model (`cputype`); null where the host decides.
 String? get type;
/// Create a copy of VirtHwCpu
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwCpuCopyWith<VirtHwCpu> get copyWith => _$VirtHwCpuCopyWithImpl<VirtHwCpu>(this as VirtHwCpu, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwCpu&&(identical(other.sockets, sockets) || other.sockets == sockets)&&(identical(other.cores, cores) || other.cores == cores)&&(identical(other.threads, threads) || other.threads == threads)&&(identical(other.online, online) || other.online == online)&&(identical(other.type, type) || other.type == type));
}


@override
int get hashCode => Object.hash(runtimeType,sockets,cores,threads,online,type);

@override
String toString() {
  return 'VirtHwCpu(sockets: $sockets, cores: $cores, threads: $threads, online: $online, type: $type)';
}


}

/// @nodoc
abstract mixin class $VirtHwCpuCopyWith<$Res>  {
  factory $VirtHwCpuCopyWith(VirtHwCpu value, $Res Function(VirtHwCpu) _then) = _$VirtHwCpuCopyWithImpl;
@useResult
$Res call({
 int sockets, int cores, int threads, int? online, String? type
});




}
/// @nodoc
class _$VirtHwCpuCopyWithImpl<$Res>
    implements $VirtHwCpuCopyWith<$Res> {
  _$VirtHwCpuCopyWithImpl(this._self, this._then);

  final VirtHwCpu _self;
  final $Res Function(VirtHwCpu) _then;

/// Create a copy of VirtHwCpu
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sockets = null,Object? cores = null,Object? threads = null,Object? online = freezed,Object? type = freezed,}) {
  return _then(_self.copyWith(
sockets: null == sockets ? _self.sockets : sockets // ignore: cast_nullable_to_non_nullable
as int,cores: null == cores ? _self.cores : cores // ignore: cast_nullable_to_non_nullable
as int,threads: null == threads ? _self.threads : threads // ignore: cast_nullable_to_non_nullable
as int,online: freezed == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as int?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtHwCpu].
extension VirtHwCpuPatterns on VirtHwCpu {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtHwCpu value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtHwCpu() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtHwCpu value)  $default,){
final _that = this;
switch (_that) {
case _VirtHwCpu():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtHwCpu value)?  $default,){
final _that = this;
switch (_that) {
case _VirtHwCpu() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int sockets,  int cores,  int threads,  int? online,  String? type)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHwCpu() when $default != null:
return $default(_that.sockets,_that.cores,_that.threads,_that.online,_that.type);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int sockets,  int cores,  int threads,  int? online,  String? type)  $default,) {final _that = this;
switch (_that) {
case _VirtHwCpu():
return $default(_that.sockets,_that.cores,_that.threads,_that.online,_that.type);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int sockets,  int cores,  int threads,  int? online,  String? type)?  $default,) {final _that = this;
switch (_that) {
case _VirtHwCpu() when $default != null:
return $default(_that.sockets,_that.cores,_that.threads,_that.online,_that.type);case _:
  return null;

}
}

}

/// @nodoc


class _VirtHwCpu extends VirtHwCpu {
  const _VirtHwCpu({required this.sockets, required this.cores, this.threads = 1, this.online, this.type}): super._();
  

@override final  int sockets;
@override final  int cores;
/// libvirt's threads per core, kept as they are; always 1 on PVE.
@override@JsonKey() final  int threads;
/// vCPUs online: PVE's `vcpus`, libvirt's `current`. Null for all of
/// them.
@override final  int? online;
/// PVE's CPU model (`cputype`); null where the host decides.
@override final  String? type;

/// Create a copy of VirtHwCpu
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHwCpuCopyWith<_VirtHwCpu> get copyWith => __$VirtHwCpuCopyWithImpl<_VirtHwCpu>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHwCpu&&(identical(other.sockets, sockets) || other.sockets == sockets)&&(identical(other.cores, cores) || other.cores == cores)&&(identical(other.threads, threads) || other.threads == threads)&&(identical(other.online, online) || other.online == online)&&(identical(other.type, type) || other.type == type));
}


@override
int get hashCode => Object.hash(runtimeType,sockets,cores,threads,online,type);

@override
String toString() {
  return 'VirtHwCpu(sockets: $sockets, cores: $cores, threads: $threads, online: $online, type: $type)';
}


}

/// @nodoc
abstract mixin class _$VirtHwCpuCopyWith<$Res> implements $VirtHwCpuCopyWith<$Res> {
  factory _$VirtHwCpuCopyWith(_VirtHwCpu value, $Res Function(_VirtHwCpu) _then) = __$VirtHwCpuCopyWithImpl;
@override @useResult
$Res call({
 int sockets, int cores, int threads, int? online, String? type
});




}
/// @nodoc
class __$VirtHwCpuCopyWithImpl<$Res>
    implements _$VirtHwCpuCopyWith<$Res> {
  __$VirtHwCpuCopyWithImpl(this._self, this._then);

  final _VirtHwCpu _self;
  final $Res Function(_VirtHwCpu) _then;

/// Create a copy of VirtHwCpu
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sockets = null,Object? cores = null,Object? threads = null,Object? online = freezed,Object? type = freezed,}) {
  return _then(_VirtHwCpu(
sockets: null == sockets ? _self.sockets : sockets // ignore: cast_nullable_to_non_nullable
as int,cores: null == cores ? _self.cores : cores // ignore: cast_nullable_to_non_nullable
as int,threads: null == threads ? _self.threads : threads // ignore: cast_nullable_to_non_nullable
as int,online: freezed == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as int?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$VirtHwMemory {

 int get mib;/// The balloon's floor (PVE `balloon`, 0 turning it off) or target
/// (libvirt `currentMemory`). Null where there is none to set.
 int? get minMib;/// There is a balloon device, so [minMib] can be set.
 bool get balloon;/// A container's swap.
 int? get swapMib;
/// Create a copy of VirtHwMemory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwMemoryCopyWith<VirtHwMemory> get copyWith => _$VirtHwMemoryCopyWithImpl<VirtHwMemory>(this as VirtHwMemory, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwMemory&&(identical(other.mib, mib) || other.mib == mib)&&(identical(other.minMib, minMib) || other.minMib == minMib)&&(identical(other.balloon, balloon) || other.balloon == balloon)&&(identical(other.swapMib, swapMib) || other.swapMib == swapMib));
}


@override
int get hashCode => Object.hash(runtimeType,mib,minMib,balloon,swapMib);

@override
String toString() {
  return 'VirtHwMemory(mib: $mib, minMib: $minMib, balloon: $balloon, swapMib: $swapMib)';
}


}

/// @nodoc
abstract mixin class $VirtHwMemoryCopyWith<$Res>  {
  factory $VirtHwMemoryCopyWith(VirtHwMemory value, $Res Function(VirtHwMemory) _then) = _$VirtHwMemoryCopyWithImpl;
@useResult
$Res call({
 int mib, int? minMib, bool balloon, int? swapMib
});




}
/// @nodoc
class _$VirtHwMemoryCopyWithImpl<$Res>
    implements $VirtHwMemoryCopyWith<$Res> {
  _$VirtHwMemoryCopyWithImpl(this._self, this._then);

  final VirtHwMemory _self;
  final $Res Function(VirtHwMemory) _then;

/// Create a copy of VirtHwMemory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mib = null,Object? minMib = freezed,Object? balloon = null,Object? swapMib = freezed,}) {
  return _then(_self.copyWith(
mib: null == mib ? _self.mib : mib // ignore: cast_nullable_to_non_nullable
as int,minMib: freezed == minMib ? _self.minMib : minMib // ignore: cast_nullable_to_non_nullable
as int?,balloon: null == balloon ? _self.balloon : balloon // ignore: cast_nullable_to_non_nullable
as bool,swapMib: freezed == swapMib ? _self.swapMib : swapMib // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtHwMemory].
extension VirtHwMemoryPatterns on VirtHwMemory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtHwMemory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtHwMemory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtHwMemory value)  $default,){
final _that = this;
switch (_that) {
case _VirtHwMemory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtHwMemory value)?  $default,){
final _that = this;
switch (_that) {
case _VirtHwMemory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int mib,  int? minMib,  bool balloon,  int? swapMib)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHwMemory() when $default != null:
return $default(_that.mib,_that.minMib,_that.balloon,_that.swapMib);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int mib,  int? minMib,  bool balloon,  int? swapMib)  $default,) {final _that = this;
switch (_that) {
case _VirtHwMemory():
return $default(_that.mib,_that.minMib,_that.balloon,_that.swapMib);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int mib,  int? minMib,  bool balloon,  int? swapMib)?  $default,) {final _that = this;
switch (_that) {
case _VirtHwMemory() when $default != null:
return $default(_that.mib,_that.minMib,_that.balloon,_that.swapMib);case _:
  return null;

}
}

}

/// @nodoc


class _VirtHwMemory implements VirtHwMemory {
  const _VirtHwMemory({required this.mib, this.minMib, this.balloon = false, this.swapMib});
  

@override final  int mib;
/// The balloon's floor (PVE `balloon`, 0 turning it off) or target
/// (libvirt `currentMemory`). Null where there is none to set.
@override final  int? minMib;
/// There is a balloon device, so [minMib] can be set.
@override@JsonKey() final  bool balloon;
/// A container's swap.
@override final  int? swapMib;

/// Create a copy of VirtHwMemory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHwMemoryCopyWith<_VirtHwMemory> get copyWith => __$VirtHwMemoryCopyWithImpl<_VirtHwMemory>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHwMemory&&(identical(other.mib, mib) || other.mib == mib)&&(identical(other.minMib, minMib) || other.minMib == minMib)&&(identical(other.balloon, balloon) || other.balloon == balloon)&&(identical(other.swapMib, swapMib) || other.swapMib == swapMib));
}


@override
int get hashCode => Object.hash(runtimeType,mib,minMib,balloon,swapMib);

@override
String toString() {
  return 'VirtHwMemory(mib: $mib, minMib: $minMib, balloon: $balloon, swapMib: $swapMib)';
}


}

/// @nodoc
abstract mixin class _$VirtHwMemoryCopyWith<$Res> implements $VirtHwMemoryCopyWith<$Res> {
  factory _$VirtHwMemoryCopyWith(_VirtHwMemory value, $Res Function(_VirtHwMemory) _then) = __$VirtHwMemoryCopyWithImpl;
@override @useResult
$Res call({
 int mib, int? minMib, bool balloon, int? swapMib
});




}
/// @nodoc
class __$VirtHwMemoryCopyWithImpl<$Res>
    implements _$VirtHwMemoryCopyWith<$Res> {
  __$VirtHwMemoryCopyWithImpl(this._self, this._then);

  final _VirtHwMemory _self;
  final $Res Function(_VirtHwMemory) _then;

/// Create a copy of VirtHwMemory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mib = null,Object? minMib = freezed,Object? balloon = null,Object? swapMib = freezed,}) {
  return _then(_VirtHwMemory(
mib: null == mib ? _self.mib : mib // ignore: cast_nullable_to_non_nullable
as int,minMib: freezed == minMib ? _self.minMib : minMib // ignore: cast_nullable_to_non_nullable
as int?,balloon: null == balloon ? _self.balloon : balloon // ignore: cast_nullable_to_non_nullable
as bool,swapMib: freezed == swapMib ? _self.swapMib : swapMib // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$VirtHwDisk {

/// PVE option (`scsi0`, `rootfs`, `mp0`), libvirt target (`vda`).
 String get key; VirtHwDiskKind get kind;/// PVE volume id, libvirt path; null for an empty drive.
 String? get source;/// Bytes, where known.
 int? get size;/// PVE storage the volume is on.
 String? get storage;/// A mount point's path in the container.
 String? get mountPoint; String? get bus; String? get format; bool get readonly;
/// Create a copy of VirtHwDisk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwDiskCopyWith<VirtHwDisk> get copyWith => _$VirtHwDiskCopyWithImpl<VirtHwDisk>(this as VirtHwDisk, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwDisk&&(identical(other.key, key) || other.key == key)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.source, source) || other.source == source)&&(identical(other.size, size) || other.size == size)&&(identical(other.storage, storage) || other.storage == storage)&&(identical(other.mountPoint, mountPoint) || other.mountPoint == mountPoint)&&(identical(other.bus, bus) || other.bus == bus)&&(identical(other.format, format) || other.format == format)&&(identical(other.readonly, readonly) || other.readonly == readonly));
}


@override
int get hashCode => Object.hash(runtimeType,key,kind,source,size,storage,mountPoint,bus,format,readonly);

@override
String toString() {
  return 'VirtHwDisk(key: $key, kind: $kind, source: $source, size: $size, storage: $storage, mountPoint: $mountPoint, bus: $bus, format: $format, readonly: $readonly)';
}


}

/// @nodoc
abstract mixin class $VirtHwDiskCopyWith<$Res>  {
  factory $VirtHwDiskCopyWith(VirtHwDisk value, $Res Function(VirtHwDisk) _then) = _$VirtHwDiskCopyWithImpl;
@useResult
$Res call({
 String key, VirtHwDiskKind kind, String? source, int? size, String? storage, String? mountPoint, String? bus, String? format, bool readonly
});




}
/// @nodoc
class _$VirtHwDiskCopyWithImpl<$Res>
    implements $VirtHwDiskCopyWith<$Res> {
  _$VirtHwDiskCopyWithImpl(this._self, this._then);

  final VirtHwDisk _self;
  final $Res Function(VirtHwDisk) _then;

/// Create a copy of VirtHwDisk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? kind = null,Object? source = freezed,Object? size = freezed,Object? storage = freezed,Object? mountPoint = freezed,Object? bus = freezed,Object? format = freezed,Object? readonly = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as VirtHwDiskKind,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,storage: freezed == storage ? _self.storage : storage // ignore: cast_nullable_to_non_nullable
as String?,mountPoint: freezed == mountPoint ? _self.mountPoint : mountPoint // ignore: cast_nullable_to_non_nullable
as String?,bus: freezed == bus ? _self.bus : bus // ignore: cast_nullable_to_non_nullable
as String?,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,readonly: null == readonly ? _self.readonly : readonly // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtHwDisk].
extension VirtHwDiskPatterns on VirtHwDisk {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtHwDisk value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtHwDisk() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtHwDisk value)  $default,){
final _that = this;
switch (_that) {
case _VirtHwDisk():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtHwDisk value)?  $default,){
final _that = this;
switch (_that) {
case _VirtHwDisk() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  VirtHwDiskKind kind,  String? source,  int? size,  String? storage,  String? mountPoint,  String? bus,  String? format,  bool readonly)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHwDisk() when $default != null:
return $default(_that.key,_that.kind,_that.source,_that.size,_that.storage,_that.mountPoint,_that.bus,_that.format,_that.readonly);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  VirtHwDiskKind kind,  String? source,  int? size,  String? storage,  String? mountPoint,  String? bus,  String? format,  bool readonly)  $default,) {final _that = this;
switch (_that) {
case _VirtHwDisk():
return $default(_that.key,_that.kind,_that.source,_that.size,_that.storage,_that.mountPoint,_that.bus,_that.format,_that.readonly);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  VirtHwDiskKind kind,  String? source,  int? size,  String? storage,  String? mountPoint,  String? bus,  String? format,  bool readonly)?  $default,) {final _that = this;
switch (_that) {
case _VirtHwDisk() when $default != null:
return $default(_that.key,_that.kind,_that.source,_that.size,_that.storage,_that.mountPoint,_that.bus,_that.format,_that.readonly);case _:
  return null;

}
}

}

/// @nodoc


class _VirtHwDisk implements VirtHwDisk {
  const _VirtHwDisk({required this.key, required this.kind, this.source, this.size, this.storage, this.mountPoint, this.bus, this.format, this.readonly = false});
  

/// PVE option (`scsi0`, `rootfs`, `mp0`), libvirt target (`vda`).
@override final  String key;
@override final  VirtHwDiskKind kind;
/// PVE volume id, libvirt path; null for an empty drive.
@override final  String? source;
/// Bytes, where known.
@override final  int? size;
/// PVE storage the volume is on.
@override final  String? storage;
/// A mount point's path in the container.
@override final  String? mountPoint;
@override final  String? bus;
@override final  String? format;
@override@JsonKey() final  bool readonly;

/// Create a copy of VirtHwDisk
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHwDiskCopyWith<_VirtHwDisk> get copyWith => __$VirtHwDiskCopyWithImpl<_VirtHwDisk>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHwDisk&&(identical(other.key, key) || other.key == key)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.source, source) || other.source == source)&&(identical(other.size, size) || other.size == size)&&(identical(other.storage, storage) || other.storage == storage)&&(identical(other.mountPoint, mountPoint) || other.mountPoint == mountPoint)&&(identical(other.bus, bus) || other.bus == bus)&&(identical(other.format, format) || other.format == format)&&(identical(other.readonly, readonly) || other.readonly == readonly));
}


@override
int get hashCode => Object.hash(runtimeType,key,kind,source,size,storage,mountPoint,bus,format,readonly);

@override
String toString() {
  return 'VirtHwDisk(key: $key, kind: $kind, source: $source, size: $size, storage: $storage, mountPoint: $mountPoint, bus: $bus, format: $format, readonly: $readonly)';
}


}

/// @nodoc
abstract mixin class _$VirtHwDiskCopyWith<$Res> implements $VirtHwDiskCopyWith<$Res> {
  factory _$VirtHwDiskCopyWith(_VirtHwDisk value, $Res Function(_VirtHwDisk) _then) = __$VirtHwDiskCopyWithImpl;
@override @useResult
$Res call({
 String key, VirtHwDiskKind kind, String? source, int? size, String? storage, String? mountPoint, String? bus, String? format, bool readonly
});




}
/// @nodoc
class __$VirtHwDiskCopyWithImpl<$Res>
    implements _$VirtHwDiskCopyWith<$Res> {
  __$VirtHwDiskCopyWithImpl(this._self, this._then);

  final _VirtHwDisk _self;
  final $Res Function(_VirtHwDisk) _then;

/// Create a copy of VirtHwDisk
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? kind = null,Object? source = freezed,Object? size = freezed,Object? storage = freezed,Object? mountPoint = freezed,Object? bus = freezed,Object? format = freezed,Object? readonly = null,}) {
  return _then(_VirtHwDisk(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as VirtHwDiskKind,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,storage: freezed == storage ? _self.storage : storage // ignore: cast_nullable_to_non_nullable
as String?,mountPoint: freezed == mountPoint ? _self.mountPoint : mountPoint // ignore: cast_nullable_to_non_nullable
as String?,bus: freezed == bus ? _self.bus : bus // ignore: cast_nullable_to_non_nullable
as String?,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,readonly: null == readonly ? _self.readonly : readonly // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$VirtHwNic {

/// PVE option (`net0`), libvirt MAC.
 String get key; String? get mac;/// libvirt's interface type (`network`, `bridge`); null on PVE.
 String? get type;/// Bridge (PVE, libvirt `bridge`) or network (libvirt `network`).
 String? get source; String? get model; bool get linkUp;/// PVE's firewall on this interface; null where there is no such thing.
 bool? get firewall;/// A container's interface name (`eth0`).
 String? get name;
/// Create a copy of VirtHwNic
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwNicCopyWith<VirtHwNic> get copyWith => _$VirtHwNicCopyWithImpl<VirtHwNic>(this as VirtHwNic, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwNic&&(identical(other.key, key) || other.key == key)&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.type, type) || other.type == type)&&(identical(other.source, source) || other.source == source)&&(identical(other.model, model) || other.model == model)&&(identical(other.linkUp, linkUp) || other.linkUp == linkUp)&&(identical(other.firewall, firewall) || other.firewall == firewall)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,key,mac,type,source,model,linkUp,firewall,name);

@override
String toString() {
  return 'VirtHwNic(key: $key, mac: $mac, type: $type, source: $source, model: $model, linkUp: $linkUp, firewall: $firewall, name: $name)';
}


}

/// @nodoc
abstract mixin class $VirtHwNicCopyWith<$Res>  {
  factory $VirtHwNicCopyWith(VirtHwNic value, $Res Function(VirtHwNic) _then) = _$VirtHwNicCopyWithImpl;
@useResult
$Res call({
 String key, String? mac, String? type, String? source, String? model, bool linkUp, bool? firewall, String? name
});




}
/// @nodoc
class _$VirtHwNicCopyWithImpl<$Res>
    implements $VirtHwNicCopyWith<$Res> {
  _$VirtHwNicCopyWithImpl(this._self, this._then);

  final VirtHwNic _self;
  final $Res Function(VirtHwNic) _then;

/// Create a copy of VirtHwNic
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? mac = freezed,Object? type = freezed,Object? source = freezed,Object? model = freezed,Object? linkUp = null,Object? firewall = freezed,Object? name = freezed,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,mac: freezed == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,linkUp: null == linkUp ? _self.linkUp : linkUp // ignore: cast_nullable_to_non_nullable
as bool,firewall: freezed == firewall ? _self.firewall : firewall // ignore: cast_nullable_to_non_nullable
as bool?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtHwNic].
extension VirtHwNicPatterns on VirtHwNic {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtHwNic value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtHwNic() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtHwNic value)  $default,){
final _that = this;
switch (_that) {
case _VirtHwNic():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtHwNic value)?  $default,){
final _that = this;
switch (_that) {
case _VirtHwNic() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String? mac,  String? type,  String? source,  String? model,  bool linkUp,  bool? firewall,  String? name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHwNic() when $default != null:
return $default(_that.key,_that.mac,_that.type,_that.source,_that.model,_that.linkUp,_that.firewall,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String? mac,  String? type,  String? source,  String? model,  bool linkUp,  bool? firewall,  String? name)  $default,) {final _that = this;
switch (_that) {
case _VirtHwNic():
return $default(_that.key,_that.mac,_that.type,_that.source,_that.model,_that.linkUp,_that.firewall,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String? mac,  String? type,  String? source,  String? model,  bool linkUp,  bool? firewall,  String? name)?  $default,) {final _that = this;
switch (_that) {
case _VirtHwNic() when $default != null:
return $default(_that.key,_that.mac,_that.type,_that.source,_that.model,_that.linkUp,_that.firewall,_that.name);case _:
  return null;

}
}

}

/// @nodoc


class _VirtHwNic implements VirtHwNic {
  const _VirtHwNic({required this.key, this.mac, this.type, this.source, this.model, this.linkUp = true, this.firewall, this.name});
  

/// PVE option (`net0`), libvirt MAC.
@override final  String key;
@override final  String? mac;
/// libvirt's interface type (`network`, `bridge`); null on PVE.
@override final  String? type;
/// Bridge (PVE, libvirt `bridge`) or network (libvirt `network`).
@override final  String? source;
@override final  String? model;
@override@JsonKey() final  bool linkUp;
/// PVE's firewall on this interface; null where there is no such thing.
@override final  bool? firewall;
/// A container's interface name (`eth0`).
@override final  String? name;

/// Create a copy of VirtHwNic
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHwNicCopyWith<_VirtHwNic> get copyWith => __$VirtHwNicCopyWithImpl<_VirtHwNic>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHwNic&&(identical(other.key, key) || other.key == key)&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.type, type) || other.type == type)&&(identical(other.source, source) || other.source == source)&&(identical(other.model, model) || other.model == model)&&(identical(other.linkUp, linkUp) || other.linkUp == linkUp)&&(identical(other.firewall, firewall) || other.firewall == firewall)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,key,mac,type,source,model,linkUp,firewall,name);

@override
String toString() {
  return 'VirtHwNic(key: $key, mac: $mac, type: $type, source: $source, model: $model, linkUp: $linkUp, firewall: $firewall, name: $name)';
}


}

/// @nodoc
abstract mixin class _$VirtHwNicCopyWith<$Res> implements $VirtHwNicCopyWith<$Res> {
  factory _$VirtHwNicCopyWith(_VirtHwNic value, $Res Function(_VirtHwNic) _then) = __$VirtHwNicCopyWithImpl;
@override @useResult
$Res call({
 String key, String? mac, String? type, String? source, String? model, bool linkUp, bool? firewall, String? name
});




}
/// @nodoc
class __$VirtHwNicCopyWithImpl<$Res>
    implements _$VirtHwNicCopyWith<$Res> {
  __$VirtHwNicCopyWithImpl(this._self, this._then);

  final _VirtHwNic _self;
  final $Res Function(_VirtHwNic) _then;

/// Create a copy of VirtHwNic
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? mac = freezed,Object? type = freezed,Object? source = freezed,Object? model = freezed,Object? linkUp = null,Object? firewall = freezed,Object? name = freezed,}) {
  return _then(_VirtHwNic(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,mac: freezed == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,linkUp: null == linkUp ? _self.linkUp : linkUp // ignore: cast_nullable_to_non_nullable
as bool,firewall: freezed == firewall ? _self.firewall : firewall // ignore: cast_nullable_to_non_nullable
as bool?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$VirtPendingField {

/// PVE's option name; libvirt: `cpu`, `memory`, `boot`, a disk target
/// or a NIC's MAC.
 String get key; String? get current; String? get pending;/// Goes at the next start.
 bool get delete;
/// Create a copy of VirtPendingField
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtPendingFieldCopyWith<VirtPendingField> get copyWith => _$VirtPendingFieldCopyWithImpl<VirtPendingField>(this as VirtPendingField, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtPendingField&&(identical(other.key, key) || other.key == key)&&(identical(other.current, current) || other.current == current)&&(identical(other.pending, pending) || other.pending == pending)&&(identical(other.delete, delete) || other.delete == delete));
}


@override
int get hashCode => Object.hash(runtimeType,key,current,pending,delete);

@override
String toString() {
  return 'VirtPendingField(key: $key, current: $current, pending: $pending, delete: $delete)';
}


}

/// @nodoc
abstract mixin class $VirtPendingFieldCopyWith<$Res>  {
  factory $VirtPendingFieldCopyWith(VirtPendingField value, $Res Function(VirtPendingField) _then) = _$VirtPendingFieldCopyWithImpl;
@useResult
$Res call({
 String key, String? current, String? pending, bool delete
});




}
/// @nodoc
class _$VirtPendingFieldCopyWithImpl<$Res>
    implements $VirtPendingFieldCopyWith<$Res> {
  _$VirtPendingFieldCopyWithImpl(this._self, this._then);

  final VirtPendingField _self;
  final $Res Function(VirtPendingField) _then;

/// Create a copy of VirtPendingField
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? current = freezed,Object? pending = freezed,Object? delete = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,current: freezed == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as String?,pending: freezed == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as String?,delete: null == delete ? _self.delete : delete // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtPendingField].
extension VirtPendingFieldPatterns on VirtPendingField {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtPendingField value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtPendingField() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtPendingField value)  $default,){
final _that = this;
switch (_that) {
case _VirtPendingField():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtPendingField value)?  $default,){
final _that = this;
switch (_that) {
case _VirtPendingField() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String? current,  String? pending,  bool delete)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtPendingField() when $default != null:
return $default(_that.key,_that.current,_that.pending,_that.delete);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String? current,  String? pending,  bool delete)  $default,) {final _that = this;
switch (_that) {
case _VirtPendingField():
return $default(_that.key,_that.current,_that.pending,_that.delete);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String? current,  String? pending,  bool delete)?  $default,) {final _that = this;
switch (_that) {
case _VirtPendingField() when $default != null:
return $default(_that.key,_that.current,_that.pending,_that.delete);case _:
  return null;

}
}

}

/// @nodoc


class _VirtPendingField implements VirtPendingField {
  const _VirtPendingField({required this.key, this.current, this.pending, this.delete = false});
  

/// PVE's option name; libvirt: `cpu`, `memory`, `boot`, a disk target
/// or a NIC's MAC.
@override final  String key;
@override final  String? current;
@override final  String? pending;
/// Goes at the next start.
@override@JsonKey() final  bool delete;

/// Create a copy of VirtPendingField
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtPendingFieldCopyWith<_VirtPendingField> get copyWith => __$VirtPendingFieldCopyWithImpl<_VirtPendingField>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtPendingField&&(identical(other.key, key) || other.key == key)&&(identical(other.current, current) || other.current == current)&&(identical(other.pending, pending) || other.pending == pending)&&(identical(other.delete, delete) || other.delete == delete));
}


@override
int get hashCode => Object.hash(runtimeType,key,current,pending,delete);

@override
String toString() {
  return 'VirtPendingField(key: $key, current: $current, pending: $pending, delete: $delete)';
}


}

/// @nodoc
abstract mixin class _$VirtPendingFieldCopyWith<$Res> implements $VirtPendingFieldCopyWith<$Res> {
  factory _$VirtPendingFieldCopyWith(_VirtPendingField value, $Res Function(_VirtPendingField) _then) = __$VirtPendingFieldCopyWithImpl;
@override @useResult
$Res call({
 String key, String? current, String? pending, bool delete
});




}
/// @nodoc
class __$VirtPendingFieldCopyWithImpl<$Res>
    implements _$VirtPendingFieldCopyWith<$Res> {
  __$VirtPendingFieldCopyWithImpl(this._self, this._then);

  final _VirtPendingField _self;
  final $Res Function(_VirtPendingField) _then;

/// Create a copy of VirtPendingField
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? current = freezed,Object? pending = freezed,Object? delete = null,}) {
  return _then(_VirtPendingField(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,current: freezed == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as String?,pending: freezed == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as String?,delete: null == delete ? _self.delete : delete // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$VirtHwLimits {

 int? get hostCpus; int? get hostMemoryBytes;
/// Create a copy of VirtHwLimits
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwLimitsCopyWith<VirtHwLimits> get copyWith => _$VirtHwLimitsCopyWithImpl<VirtHwLimits>(this as VirtHwLimits, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwLimits&&(identical(other.hostCpus, hostCpus) || other.hostCpus == hostCpus)&&(identical(other.hostMemoryBytes, hostMemoryBytes) || other.hostMemoryBytes == hostMemoryBytes));
}


@override
int get hashCode => Object.hash(runtimeType,hostCpus,hostMemoryBytes);

@override
String toString() {
  return 'VirtHwLimits(hostCpus: $hostCpus, hostMemoryBytes: $hostMemoryBytes)';
}


}

/// @nodoc
abstract mixin class $VirtHwLimitsCopyWith<$Res>  {
  factory $VirtHwLimitsCopyWith(VirtHwLimits value, $Res Function(VirtHwLimits) _then) = _$VirtHwLimitsCopyWithImpl;
@useResult
$Res call({
 int? hostCpus, int? hostMemoryBytes
});




}
/// @nodoc
class _$VirtHwLimitsCopyWithImpl<$Res>
    implements $VirtHwLimitsCopyWith<$Res> {
  _$VirtHwLimitsCopyWithImpl(this._self, this._then);

  final VirtHwLimits _self;
  final $Res Function(VirtHwLimits) _then;

/// Create a copy of VirtHwLimits
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hostCpus = freezed,Object? hostMemoryBytes = freezed,}) {
  return _then(_self.copyWith(
hostCpus: freezed == hostCpus ? _self.hostCpus : hostCpus // ignore: cast_nullable_to_non_nullable
as int?,hostMemoryBytes: freezed == hostMemoryBytes ? _self.hostMemoryBytes : hostMemoryBytes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtHwLimits].
extension VirtHwLimitsPatterns on VirtHwLimits {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtHwLimits value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtHwLimits() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtHwLimits value)  $default,){
final _that = this;
switch (_that) {
case _VirtHwLimits():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtHwLimits value)?  $default,){
final _that = this;
switch (_that) {
case _VirtHwLimits() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? hostCpus,  int? hostMemoryBytes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHwLimits() when $default != null:
return $default(_that.hostCpus,_that.hostMemoryBytes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? hostCpus,  int? hostMemoryBytes)  $default,) {final _that = this;
switch (_that) {
case _VirtHwLimits():
return $default(_that.hostCpus,_that.hostMemoryBytes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? hostCpus,  int? hostMemoryBytes)?  $default,) {final _that = this;
switch (_that) {
case _VirtHwLimits() when $default != null:
return $default(_that.hostCpus,_that.hostMemoryBytes);case _:
  return null;

}
}

}

/// @nodoc


class _VirtHwLimits implements VirtHwLimits {
  const _VirtHwLimits({this.hostCpus, this.hostMemoryBytes});
  

@override final  int? hostCpus;
@override final  int? hostMemoryBytes;

/// Create a copy of VirtHwLimits
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHwLimitsCopyWith<_VirtHwLimits> get copyWith => __$VirtHwLimitsCopyWithImpl<_VirtHwLimits>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHwLimits&&(identical(other.hostCpus, hostCpus) || other.hostCpus == hostCpus)&&(identical(other.hostMemoryBytes, hostMemoryBytes) || other.hostMemoryBytes == hostMemoryBytes));
}


@override
int get hashCode => Object.hash(runtimeType,hostCpus,hostMemoryBytes);

@override
String toString() {
  return 'VirtHwLimits(hostCpus: $hostCpus, hostMemoryBytes: $hostMemoryBytes)';
}


}

/// @nodoc
abstract mixin class _$VirtHwLimitsCopyWith<$Res> implements $VirtHwLimitsCopyWith<$Res> {
  factory _$VirtHwLimitsCopyWith(_VirtHwLimits value, $Res Function(_VirtHwLimits) _then) = __$VirtHwLimitsCopyWithImpl;
@override @useResult
$Res call({
 int? hostCpus, int? hostMemoryBytes
});




}
/// @nodoc
class __$VirtHwLimitsCopyWithImpl<$Res>
    implements _$VirtHwLimitsCopyWith<$Res> {
  __$VirtHwLimitsCopyWithImpl(this._self, this._then);

  final _VirtHwLimits _self;
  final $Res Function(_VirtHwLimits) _then;

/// Create a copy of VirtHwLimits
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hostCpus = freezed,Object? hostMemoryBytes = freezed,}) {
  return _then(_VirtHwLimits(
hostCpus: freezed == hostCpus ? _self.hostCpus : hostCpus // ignore: cast_nullable_to_non_nullable
as int?,hostMemoryBytes: freezed == hostMemoryBytes ? _self.hostMemoryBytes : hostMemoryBytes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
