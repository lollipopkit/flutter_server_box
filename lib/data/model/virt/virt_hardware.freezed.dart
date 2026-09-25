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
 List<String>? get boot; bool get autostart;/// The guest's name as saved: a VM's `name` or a container's `hostname`
/// on PVE, the domain's name on libvirt. The Settings view edits it.
 String? get name;/// The note kept with the guest: PVE's `description`, libvirt's
/// `<description>`. Null for none.
 String? get description;/// PVE's `protection`: no deleting the guest or its disks while set.
/// Null where the host has no such setting (libvirt).
 bool? get protection;/// Whether the name can change while the guest runs: PVE's can (a
/// container's waits for a restart, as pending), libvirt's
/// `domrename` takes only a domain that is not running.
 bool get renameRunning; List<VirtPendingField> get pending;/// What an edit is made from, sent back with it: PVE's `digest`, the
/// persistent XML libvirt printed. An edit made from an older read is
/// refused (`VirtErrType.conflict`) rather than undoing someone else's.
 String? get revision; VirtHwLimits get limits;/// PVE: the CPU models the node offers, for [VirtHwCpu.type].
 List<String> get cpuTypes;/// The configuration as the host writes it — `qm config`'s lines, the
/// persistent XML — for the view to show as it is.
 String? get configText;/// UEFI or BIOS; null for a container, which has neither.
 VirtHwFirmware? get firmware;/// The console and video card; null for a container.
 VirtHwDisplay? get display;/// Host USB and PCI devices given to the guest, and its TPM.
 List<VirtHwDevice> get devices;/// What this guest can be changed to, on this host.
 VirtHwSupport get support;
/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHardwareCopyWith<VirtHardware> get copyWith => _$VirtHardwareCopyWithImpl<VirtHardware>(this as VirtHardware, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHardware&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.running, running) || other.running == running)&&(identical(other.cpu, cpu) || other.cpu == cpu)&&(identical(other.memory, memory) || other.memory == memory)&&const DeepCollectionEquality().equals(other.disks, disks)&&const DeepCollectionEquality().equals(other.nics, nics)&&const DeepCollectionEquality().equals(other.boot, boot)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.protection, protection) || other.protection == protection)&&(identical(other.renameRunning, renameRunning) || other.renameRunning == renameRunning)&&const DeepCollectionEquality().equals(other.pending, pending)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.limits, limits) || other.limits == limits)&&const DeepCollectionEquality().equals(other.cpuTypes, cpuTypes)&&(identical(other.configText, configText) || other.configText == configText)&&(identical(other.firmware, firmware) || other.firmware == firmware)&&(identical(other.display, display) || other.display == display)&&const DeepCollectionEquality().equals(other.devices, devices)&&(identical(other.support, support) || other.support == support));
}


@override
int get hashCode => Object.hashAll([runtimeType,kind,running,cpu,memory,const DeepCollectionEquality().hash(disks),const DeepCollectionEquality().hash(nics),const DeepCollectionEquality().hash(boot),autostart,name,description,protection,renameRunning,const DeepCollectionEquality().hash(pending),revision,limits,const DeepCollectionEquality().hash(cpuTypes),configText,firmware,display,const DeepCollectionEquality().hash(devices),support]);

@override
String toString() {
  return 'VirtHardware(kind: $kind, running: $running, cpu: $cpu, memory: $memory, disks: $disks, nics: $nics, boot: $boot, autostart: $autostart, name: $name, description: $description, protection: $protection, renameRunning: $renameRunning, pending: $pending, revision: $revision, limits: $limits, cpuTypes: $cpuTypes, configText: $configText, firmware: $firmware, display: $display, devices: $devices, support: $support)';
}


}

/// @nodoc
abstract mixin class $VirtHardwareCopyWith<$Res>  {
  factory $VirtHardwareCopyWith(VirtHardware value, $Res Function(VirtHardware) _then) = _$VirtHardwareCopyWithImpl;
@useResult
$Res call({
 VirtGuestKind kind, bool running, VirtHwCpu cpu, VirtHwMemory memory, List<VirtHwDisk> disks, List<VirtHwNic> nics, List<String>? boot, bool autostart, String? name, String? description, bool? protection, bool renameRunning, List<VirtPendingField> pending, String? revision, VirtHwLimits limits, List<String> cpuTypes, String? configText, VirtHwFirmware? firmware, VirtHwDisplay? display, List<VirtHwDevice> devices, VirtHwSupport support
});


$VirtHwCpuCopyWith<$Res> get cpu;$VirtHwMemoryCopyWith<$Res> get memory;$VirtHwLimitsCopyWith<$Res> get limits;$VirtHwFirmwareCopyWith<$Res>? get firmware;$VirtHwDisplayCopyWith<$Res>? get display;$VirtHwSupportCopyWith<$Res> get support;

}
/// @nodoc
class _$VirtHardwareCopyWithImpl<$Res>
    implements $VirtHardwareCopyWith<$Res> {
  _$VirtHardwareCopyWithImpl(this._self, this._then);

  final VirtHardware _self;
  final $Res Function(VirtHardware) _then;

/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? running = null,Object? cpu = null,Object? memory = null,Object? disks = null,Object? nics = null,Object? boot = freezed,Object? autostart = null,Object? name = freezed,Object? description = freezed,Object? protection = freezed,Object? renameRunning = null,Object? pending = null,Object? revision = freezed,Object? limits = null,Object? cpuTypes = null,Object? configText = freezed,Object? firmware = freezed,Object? display = freezed,Object? devices = null,Object? support = null,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as VirtGuestKind,running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as bool,cpu: null == cpu ? _self.cpu : cpu // ignore: cast_nullable_to_non_nullable
as VirtHwCpu,memory: null == memory ? _self.memory : memory // ignore: cast_nullable_to_non_nullable
as VirtHwMemory,disks: null == disks ? _self.disks : disks // ignore: cast_nullable_to_non_nullable
as List<VirtHwDisk>,nics: null == nics ? _self.nics : nics // ignore: cast_nullable_to_non_nullable
as List<VirtHwNic>,boot: freezed == boot ? _self.boot : boot // ignore: cast_nullable_to_non_nullable
as List<String>?,autostart: null == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,protection: freezed == protection ? _self.protection : protection // ignore: cast_nullable_to_non_nullable
as bool?,renameRunning: null == renameRunning ? _self.renameRunning : renameRunning // ignore: cast_nullable_to_non_nullable
as bool,pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as List<VirtPendingField>,revision: freezed == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as String?,limits: null == limits ? _self.limits : limits // ignore: cast_nullable_to_non_nullable
as VirtHwLimits,cpuTypes: null == cpuTypes ? _self.cpuTypes : cpuTypes // ignore: cast_nullable_to_non_nullable
as List<String>,configText: freezed == configText ? _self.configText : configText // ignore: cast_nullable_to_non_nullable
as String?,firmware: freezed == firmware ? _self.firmware : firmware // ignore: cast_nullable_to_non_nullable
as VirtHwFirmware?,display: freezed == display ? _self.display : display // ignore: cast_nullable_to_non_nullable
as VirtHwDisplay?,devices: null == devices ? _self.devices : devices // ignore: cast_nullable_to_non_nullable
as List<VirtHwDevice>,support: null == support ? _self.support : support // ignore: cast_nullable_to_non_nullable
as VirtHwSupport,
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
}/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtHwFirmwareCopyWith<$Res>? get firmware {
    if (_self.firmware == null) {
    return null;
  }

  return $VirtHwFirmwareCopyWith<$Res>(_self.firmware!, (value) {
    return _then(_self.copyWith(firmware: value));
  });
}/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtHwDisplayCopyWith<$Res>? get display {
    if (_self.display == null) {
    return null;
  }

  return $VirtHwDisplayCopyWith<$Res>(_self.display!, (value) {
    return _then(_self.copyWith(display: value));
  });
}/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtHwSupportCopyWith<$Res> get support {
  
  return $VirtHwSupportCopyWith<$Res>(_self.support, (value) {
    return _then(_self.copyWith(support: value));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( VirtGuestKind kind,  bool running,  VirtHwCpu cpu,  VirtHwMemory memory,  List<VirtHwDisk> disks,  List<VirtHwNic> nics,  List<String>? boot,  bool autostart,  String? name,  String? description,  bool? protection,  bool renameRunning,  List<VirtPendingField> pending,  String? revision,  VirtHwLimits limits,  List<String> cpuTypes,  String? configText,  VirtHwFirmware? firmware,  VirtHwDisplay? display,  List<VirtHwDevice> devices,  VirtHwSupport support)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHardware() when $default != null:
return $default(_that.kind,_that.running,_that.cpu,_that.memory,_that.disks,_that.nics,_that.boot,_that.autostart,_that.name,_that.description,_that.protection,_that.renameRunning,_that.pending,_that.revision,_that.limits,_that.cpuTypes,_that.configText,_that.firmware,_that.display,_that.devices,_that.support);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( VirtGuestKind kind,  bool running,  VirtHwCpu cpu,  VirtHwMemory memory,  List<VirtHwDisk> disks,  List<VirtHwNic> nics,  List<String>? boot,  bool autostart,  String? name,  String? description,  bool? protection,  bool renameRunning,  List<VirtPendingField> pending,  String? revision,  VirtHwLimits limits,  List<String> cpuTypes,  String? configText,  VirtHwFirmware? firmware,  VirtHwDisplay? display,  List<VirtHwDevice> devices,  VirtHwSupport support)  $default,) {final _that = this;
switch (_that) {
case _VirtHardware():
return $default(_that.kind,_that.running,_that.cpu,_that.memory,_that.disks,_that.nics,_that.boot,_that.autostart,_that.name,_that.description,_that.protection,_that.renameRunning,_that.pending,_that.revision,_that.limits,_that.cpuTypes,_that.configText,_that.firmware,_that.display,_that.devices,_that.support);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( VirtGuestKind kind,  bool running,  VirtHwCpu cpu,  VirtHwMemory memory,  List<VirtHwDisk> disks,  List<VirtHwNic> nics,  List<String>? boot,  bool autostart,  String? name,  String? description,  bool? protection,  bool renameRunning,  List<VirtPendingField> pending,  String? revision,  VirtHwLimits limits,  List<String> cpuTypes,  String? configText,  VirtHwFirmware? firmware,  VirtHwDisplay? display,  List<VirtHwDevice> devices,  VirtHwSupport support)?  $default,) {final _that = this;
switch (_that) {
case _VirtHardware() when $default != null:
return $default(_that.kind,_that.running,_that.cpu,_that.memory,_that.disks,_that.nics,_that.boot,_that.autostart,_that.name,_that.description,_that.protection,_that.renameRunning,_that.pending,_that.revision,_that.limits,_that.cpuTypes,_that.configText,_that.firmware,_that.display,_that.devices,_that.support);case _:
  return null;

}
}

}

/// @nodoc


class _VirtHardware extends VirtHardware {
  const _VirtHardware({required this.kind, required this.running, required this.cpu, required this.memory, final  List<VirtHwDisk> disks = const <VirtHwDisk>[], final  List<VirtHwNic> nics = const <VirtHwNic>[], final  List<String>? boot, this.autostart = false, this.name, this.description, this.protection, this.renameRunning = true, final  List<VirtPendingField> pending = const <VirtPendingField>[], this.revision, this.limits = const VirtHwLimits(), final  List<String> cpuTypes = const <String>[], this.configText, this.firmware, this.display, final  List<VirtHwDevice> devices = const <VirtHwDevice>[], this.support = const VirtHwSupport()}): _disks = disks,_nics = nics,_boot = boot,_pending = pending,_cpuTypes = cpuTypes,_devices = devices,super._();
  

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
/// The guest's name as saved: a VM's `name` or a container's `hostname`
/// on PVE, the domain's name on libvirt. The Settings view edits it.
@override final  String? name;
/// The note kept with the guest: PVE's `description`, libvirt's
/// `<description>`. Null for none.
@override final  String? description;
/// PVE's `protection`: no deleting the guest or its disks while set.
/// Null where the host has no such setting (libvirt).
@override final  bool? protection;
/// Whether the name can change while the guest runs: PVE's can (a
/// container's waits for a restart, as pending), libvirt's
/// `domrename` takes only a domain that is not running.
@override@JsonKey() final  bool renameRunning;
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
/// UEFI or BIOS; null for a container, which has neither.
@override final  VirtHwFirmware? firmware;
/// The console and video card; null for a container.
@override final  VirtHwDisplay? display;
/// Host USB and PCI devices given to the guest, and its TPM.
 final  List<VirtHwDevice> _devices;
/// Host USB and PCI devices given to the guest, and its TPM.
@override@JsonKey() List<VirtHwDevice> get devices {
  if (_devices is EqualUnmodifiableListView) return _devices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_devices);
}

/// What this guest can be changed to, on this host.
@override@JsonKey() final  VirtHwSupport support;

/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHardwareCopyWith<_VirtHardware> get copyWith => __$VirtHardwareCopyWithImpl<_VirtHardware>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHardware&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.running, running) || other.running == running)&&(identical(other.cpu, cpu) || other.cpu == cpu)&&(identical(other.memory, memory) || other.memory == memory)&&const DeepCollectionEquality().equals(other._disks, _disks)&&const DeepCollectionEquality().equals(other._nics, _nics)&&const DeepCollectionEquality().equals(other._boot, _boot)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.protection, protection) || other.protection == protection)&&(identical(other.renameRunning, renameRunning) || other.renameRunning == renameRunning)&&const DeepCollectionEquality().equals(other._pending, _pending)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.limits, limits) || other.limits == limits)&&const DeepCollectionEquality().equals(other._cpuTypes, _cpuTypes)&&(identical(other.configText, configText) || other.configText == configText)&&(identical(other.firmware, firmware) || other.firmware == firmware)&&(identical(other.display, display) || other.display == display)&&const DeepCollectionEquality().equals(other._devices, _devices)&&(identical(other.support, support) || other.support == support));
}


@override
int get hashCode => Object.hashAll([runtimeType,kind,running,cpu,memory,const DeepCollectionEquality().hash(_disks),const DeepCollectionEquality().hash(_nics),const DeepCollectionEquality().hash(_boot),autostart,name,description,protection,renameRunning,const DeepCollectionEquality().hash(_pending),revision,limits,const DeepCollectionEquality().hash(_cpuTypes),configText,firmware,display,const DeepCollectionEquality().hash(_devices),support]);

@override
String toString() {
  return 'VirtHardware(kind: $kind, running: $running, cpu: $cpu, memory: $memory, disks: $disks, nics: $nics, boot: $boot, autostart: $autostart, name: $name, description: $description, protection: $protection, renameRunning: $renameRunning, pending: $pending, revision: $revision, limits: $limits, cpuTypes: $cpuTypes, configText: $configText, firmware: $firmware, display: $display, devices: $devices, support: $support)';
}


}

/// @nodoc
abstract mixin class _$VirtHardwareCopyWith<$Res> implements $VirtHardwareCopyWith<$Res> {
  factory _$VirtHardwareCopyWith(_VirtHardware value, $Res Function(_VirtHardware) _then) = __$VirtHardwareCopyWithImpl;
@override @useResult
$Res call({
 VirtGuestKind kind, bool running, VirtHwCpu cpu, VirtHwMemory memory, List<VirtHwDisk> disks, List<VirtHwNic> nics, List<String>? boot, bool autostart, String? name, String? description, bool? protection, bool renameRunning, List<VirtPendingField> pending, String? revision, VirtHwLimits limits, List<String> cpuTypes, String? configText, VirtHwFirmware? firmware, VirtHwDisplay? display, List<VirtHwDevice> devices, VirtHwSupport support
});


@override $VirtHwCpuCopyWith<$Res> get cpu;@override $VirtHwMemoryCopyWith<$Res> get memory;@override $VirtHwLimitsCopyWith<$Res> get limits;@override $VirtHwFirmwareCopyWith<$Res>? get firmware;@override $VirtHwDisplayCopyWith<$Res>? get display;@override $VirtHwSupportCopyWith<$Res> get support;

}
/// @nodoc
class __$VirtHardwareCopyWithImpl<$Res>
    implements _$VirtHardwareCopyWith<$Res> {
  __$VirtHardwareCopyWithImpl(this._self, this._then);

  final _VirtHardware _self;
  final $Res Function(_VirtHardware) _then;

/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? running = null,Object? cpu = null,Object? memory = null,Object? disks = null,Object? nics = null,Object? boot = freezed,Object? autostart = null,Object? name = freezed,Object? description = freezed,Object? protection = freezed,Object? renameRunning = null,Object? pending = null,Object? revision = freezed,Object? limits = null,Object? cpuTypes = null,Object? configText = freezed,Object? firmware = freezed,Object? display = freezed,Object? devices = null,Object? support = null,}) {
  return _then(_VirtHardware(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as VirtGuestKind,running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as bool,cpu: null == cpu ? _self.cpu : cpu // ignore: cast_nullable_to_non_nullable
as VirtHwCpu,memory: null == memory ? _self.memory : memory // ignore: cast_nullable_to_non_nullable
as VirtHwMemory,disks: null == disks ? _self._disks : disks // ignore: cast_nullable_to_non_nullable
as List<VirtHwDisk>,nics: null == nics ? _self._nics : nics // ignore: cast_nullable_to_non_nullable
as List<VirtHwNic>,boot: freezed == boot ? _self._boot : boot // ignore: cast_nullable_to_non_nullable
as List<String>?,autostart: null == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,protection: freezed == protection ? _self.protection : protection // ignore: cast_nullable_to_non_nullable
as bool?,renameRunning: null == renameRunning ? _self.renameRunning : renameRunning // ignore: cast_nullable_to_non_nullable
as bool,pending: null == pending ? _self._pending : pending // ignore: cast_nullable_to_non_nullable
as List<VirtPendingField>,revision: freezed == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as String?,limits: null == limits ? _self.limits : limits // ignore: cast_nullable_to_non_nullable
as VirtHwLimits,cpuTypes: null == cpuTypes ? _self._cpuTypes : cpuTypes // ignore: cast_nullable_to_non_nullable
as List<String>,configText: freezed == configText ? _self.configText : configText // ignore: cast_nullable_to_non_nullable
as String?,firmware: freezed == firmware ? _self.firmware : firmware // ignore: cast_nullable_to_non_nullable
as VirtHwFirmware?,display: freezed == display ? _self.display : display // ignore: cast_nullable_to_non_nullable
as VirtHwDisplay?,devices: null == devices ? _self._devices : devices // ignore: cast_nullable_to_non_nullable
as List<VirtHwDevice>,support: null == support ? _self.support : support // ignore: cast_nullable_to_non_nullable
as VirtHwSupport,
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
}/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtHwFirmwareCopyWith<$Res>? get firmware {
    if (_self.firmware == null) {
    return null;
  }

  return $VirtHwFirmwareCopyWith<$Res>(_self.firmware!, (value) {
    return _then(_self.copyWith(firmware: value));
  });
}/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtHwDisplayCopyWith<$Res>? get display {
    if (_self.display == null) {
    return null;
  }

  return $VirtHwDisplayCopyWith<$Res>(_self.display!, (value) {
    return _then(_self.copyWith(display: value));
  });
}/// Create a copy of VirtHardware
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtHwSupportCopyWith<$Res> get support {
  
  return $VirtHwSupportCopyWith<$Res>(_self.support, (value) {
    return _then(_self.copyWith(support: value));
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
 String? get mountPoint; String? get bus; String? get format; bool get readonly;/// The cache mode; null for the host's default.
 String? get cache;
/// Create a copy of VirtHwDisk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwDiskCopyWith<VirtHwDisk> get copyWith => _$VirtHwDiskCopyWithImpl<VirtHwDisk>(this as VirtHwDisk, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwDisk&&(identical(other.key, key) || other.key == key)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.source, source) || other.source == source)&&(identical(other.size, size) || other.size == size)&&(identical(other.storage, storage) || other.storage == storage)&&(identical(other.mountPoint, mountPoint) || other.mountPoint == mountPoint)&&(identical(other.bus, bus) || other.bus == bus)&&(identical(other.format, format) || other.format == format)&&(identical(other.readonly, readonly) || other.readonly == readonly)&&(identical(other.cache, cache) || other.cache == cache));
}


@override
int get hashCode => Object.hash(runtimeType,key,kind,source,size,storage,mountPoint,bus,format,readonly,cache);

@override
String toString() {
  return 'VirtHwDisk(key: $key, kind: $kind, source: $source, size: $size, storage: $storage, mountPoint: $mountPoint, bus: $bus, format: $format, readonly: $readonly, cache: $cache)';
}


}

/// @nodoc
abstract mixin class $VirtHwDiskCopyWith<$Res>  {
  factory $VirtHwDiskCopyWith(VirtHwDisk value, $Res Function(VirtHwDisk) _then) = _$VirtHwDiskCopyWithImpl;
@useResult
$Res call({
 String key, VirtHwDiskKind kind, String? source, int? size, String? storage, String? mountPoint, String? bus, String? format, bool readonly, String? cache
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
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? kind = null,Object? source = freezed,Object? size = freezed,Object? storage = freezed,Object? mountPoint = freezed,Object? bus = freezed,Object? format = freezed,Object? readonly = null,Object? cache = freezed,}) {
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
as bool,cache: freezed == cache ? _self.cache : cache // ignore: cast_nullable_to_non_nullable
as String?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  VirtHwDiskKind kind,  String? source,  int? size,  String? storage,  String? mountPoint,  String? bus,  String? format,  bool readonly,  String? cache)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHwDisk() when $default != null:
return $default(_that.key,_that.kind,_that.source,_that.size,_that.storage,_that.mountPoint,_that.bus,_that.format,_that.readonly,_that.cache);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  VirtHwDiskKind kind,  String? source,  int? size,  String? storage,  String? mountPoint,  String? bus,  String? format,  bool readonly,  String? cache)  $default,) {final _that = this;
switch (_that) {
case _VirtHwDisk():
return $default(_that.key,_that.kind,_that.source,_that.size,_that.storage,_that.mountPoint,_that.bus,_that.format,_that.readonly,_that.cache);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  VirtHwDiskKind kind,  String? source,  int? size,  String? storage,  String? mountPoint,  String? bus,  String? format,  bool readonly,  String? cache)?  $default,) {final _that = this;
switch (_that) {
case _VirtHwDisk() when $default != null:
return $default(_that.key,_that.kind,_that.source,_that.size,_that.storage,_that.mountPoint,_that.bus,_that.format,_that.readonly,_that.cache);case _:
  return null;

}
}

}

/// @nodoc


class _VirtHwDisk implements VirtHwDisk {
  const _VirtHwDisk({required this.key, required this.kind, this.source, this.size, this.storage, this.mountPoint, this.bus, this.format, this.readonly = false, this.cache});
  

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
/// The cache mode; null for the host's default.
@override final  String? cache;

/// Create a copy of VirtHwDisk
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHwDiskCopyWith<_VirtHwDisk> get copyWith => __$VirtHwDiskCopyWithImpl<_VirtHwDisk>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHwDisk&&(identical(other.key, key) || other.key == key)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.source, source) || other.source == source)&&(identical(other.size, size) || other.size == size)&&(identical(other.storage, storage) || other.storage == storage)&&(identical(other.mountPoint, mountPoint) || other.mountPoint == mountPoint)&&(identical(other.bus, bus) || other.bus == bus)&&(identical(other.format, format) || other.format == format)&&(identical(other.readonly, readonly) || other.readonly == readonly)&&(identical(other.cache, cache) || other.cache == cache));
}


@override
int get hashCode => Object.hash(runtimeType,key,kind,source,size,storage,mountPoint,bus,format,readonly,cache);

@override
String toString() {
  return 'VirtHwDisk(key: $key, kind: $kind, source: $source, size: $size, storage: $storage, mountPoint: $mountPoint, bus: $bus, format: $format, readonly: $readonly, cache: $cache)';
}


}

/// @nodoc
abstract mixin class _$VirtHwDiskCopyWith<$Res> implements $VirtHwDiskCopyWith<$Res> {
  factory _$VirtHwDiskCopyWith(_VirtHwDisk value, $Res Function(_VirtHwDisk) _then) = __$VirtHwDiskCopyWithImpl;
@override @useResult
$Res call({
 String key, VirtHwDiskKind kind, String? source, int? size, String? storage, String? mountPoint, String? bus, String? format, bool readonly, String? cache
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
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? kind = null,Object? source = freezed,Object? size = freezed,Object? storage = freezed,Object? mountPoint = freezed,Object? bus = freezed,Object? format = freezed,Object? readonly = null,Object? cache = freezed,}) {
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
as bool,cache: freezed == cache ? _self.cache : cache // ignore: cast_nullable_to_non_nullable
as String?,
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
mixin _$VirtHwFirmware {

 bool get uefi; bool get secureBoot;/// PVE: the storage the EFI variables disk is on; null without one.
 String? get varsStorage;
/// Create a copy of VirtHwFirmware
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwFirmwareCopyWith<VirtHwFirmware> get copyWith => _$VirtHwFirmwareCopyWithImpl<VirtHwFirmware>(this as VirtHwFirmware, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwFirmware&&(identical(other.uefi, uefi) || other.uefi == uefi)&&(identical(other.secureBoot, secureBoot) || other.secureBoot == secureBoot)&&(identical(other.varsStorage, varsStorage) || other.varsStorage == varsStorage));
}


@override
int get hashCode => Object.hash(runtimeType,uefi,secureBoot,varsStorage);

@override
String toString() {
  return 'VirtHwFirmware(uefi: $uefi, secureBoot: $secureBoot, varsStorage: $varsStorage)';
}


}

/// @nodoc
abstract mixin class $VirtHwFirmwareCopyWith<$Res>  {
  factory $VirtHwFirmwareCopyWith(VirtHwFirmware value, $Res Function(VirtHwFirmware) _then) = _$VirtHwFirmwareCopyWithImpl;
@useResult
$Res call({
 bool uefi, bool secureBoot, String? varsStorage
});




}
/// @nodoc
class _$VirtHwFirmwareCopyWithImpl<$Res>
    implements $VirtHwFirmwareCopyWith<$Res> {
  _$VirtHwFirmwareCopyWithImpl(this._self, this._then);

  final VirtHwFirmware _self;
  final $Res Function(VirtHwFirmware) _then;

/// Create a copy of VirtHwFirmware
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uefi = null,Object? secureBoot = null,Object? varsStorage = freezed,}) {
  return _then(_self.copyWith(
uefi: null == uefi ? _self.uefi : uefi // ignore: cast_nullable_to_non_nullable
as bool,secureBoot: null == secureBoot ? _self.secureBoot : secureBoot // ignore: cast_nullable_to_non_nullable
as bool,varsStorage: freezed == varsStorage ? _self.varsStorage : varsStorage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtHwFirmware].
extension VirtHwFirmwarePatterns on VirtHwFirmware {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtHwFirmware value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtHwFirmware() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtHwFirmware value)  $default,){
final _that = this;
switch (_that) {
case _VirtHwFirmware():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtHwFirmware value)?  $default,){
final _that = this;
switch (_that) {
case _VirtHwFirmware() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool uefi,  bool secureBoot,  String? varsStorage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHwFirmware() when $default != null:
return $default(_that.uefi,_that.secureBoot,_that.varsStorage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool uefi,  bool secureBoot,  String? varsStorage)  $default,) {final _that = this;
switch (_that) {
case _VirtHwFirmware():
return $default(_that.uefi,_that.secureBoot,_that.varsStorage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool uefi,  bool secureBoot,  String? varsStorage)?  $default,) {final _that = this;
switch (_that) {
case _VirtHwFirmware() when $default != null:
return $default(_that.uefi,_that.secureBoot,_that.varsStorage);case _:
  return null;

}
}

}

/// @nodoc


class _VirtHwFirmware implements VirtHwFirmware {
  const _VirtHwFirmware({required this.uefi, this.secureBoot = false, this.varsStorage});
  

@override final  bool uefi;
@override@JsonKey() final  bool secureBoot;
/// PVE: the storage the EFI variables disk is on; null without one.
@override final  String? varsStorage;

/// Create a copy of VirtHwFirmware
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHwFirmwareCopyWith<_VirtHwFirmware> get copyWith => __$VirtHwFirmwareCopyWithImpl<_VirtHwFirmware>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHwFirmware&&(identical(other.uefi, uefi) || other.uefi == uefi)&&(identical(other.secureBoot, secureBoot) || other.secureBoot == secureBoot)&&(identical(other.varsStorage, varsStorage) || other.varsStorage == varsStorage));
}


@override
int get hashCode => Object.hash(runtimeType,uefi,secureBoot,varsStorage);

@override
String toString() {
  return 'VirtHwFirmware(uefi: $uefi, secureBoot: $secureBoot, varsStorage: $varsStorage)';
}


}

/// @nodoc
abstract mixin class _$VirtHwFirmwareCopyWith<$Res> implements $VirtHwFirmwareCopyWith<$Res> {
  factory _$VirtHwFirmwareCopyWith(_VirtHwFirmware value, $Res Function(_VirtHwFirmware) _then) = __$VirtHwFirmwareCopyWithImpl;
@override @useResult
$Res call({
 bool uefi, bool secureBoot, String? varsStorage
});




}
/// @nodoc
class __$VirtHwFirmwareCopyWithImpl<$Res>
    implements _$VirtHwFirmwareCopyWith<$Res> {
  __$VirtHwFirmwareCopyWithImpl(this._self, this._then);

  final _VirtHwFirmware _self;
  final $Res Function(_VirtHwFirmware) _then;

/// Create a copy of VirtHwFirmware
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uefi = null,Object? secureBoot = null,Object? varsStorage = freezed,}) {
  return _then(_VirtHwFirmware(
uefi: null == uefi ? _self.uefi : uefi // ignore: cast_nullable_to_non_nullable
as bool,secureBoot: null == secureBoot ? _self.secureBoot : secureBoot // ignore: cast_nullable_to_non_nullable
as bool,varsStorage: freezed == varsStorage ? _self.varsStorage : varsStorage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$VirtHwDisplay {

/// `vnc`, `spice`; null where the host decides (PVE: VNC through its
/// own proxy, SPICE with a `qxl` card).
 String? get protocol;/// The address the console listens on (libvirt); null for the default.
 String? get listen;/// The video card: libvirt's model, PVE's `vga` type.
 String? get gpu; int? get port;
/// Create a copy of VirtHwDisplay
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwDisplayCopyWith<VirtHwDisplay> get copyWith => _$VirtHwDisplayCopyWithImpl<VirtHwDisplay>(this as VirtHwDisplay, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwDisplay&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.listen, listen) || other.listen == listen)&&(identical(other.gpu, gpu) || other.gpu == gpu)&&(identical(other.port, port) || other.port == port));
}


@override
int get hashCode => Object.hash(runtimeType,protocol,listen,gpu,port);

@override
String toString() {
  return 'VirtHwDisplay(protocol: $protocol, listen: $listen, gpu: $gpu, port: $port)';
}


}

/// @nodoc
abstract mixin class $VirtHwDisplayCopyWith<$Res>  {
  factory $VirtHwDisplayCopyWith(VirtHwDisplay value, $Res Function(VirtHwDisplay) _then) = _$VirtHwDisplayCopyWithImpl;
@useResult
$Res call({
 String? protocol, String? listen, String? gpu, int? port
});




}
/// @nodoc
class _$VirtHwDisplayCopyWithImpl<$Res>
    implements $VirtHwDisplayCopyWith<$Res> {
  _$VirtHwDisplayCopyWithImpl(this._self, this._then);

  final VirtHwDisplay _self;
  final $Res Function(VirtHwDisplay) _then;

/// Create a copy of VirtHwDisplay
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? protocol = freezed,Object? listen = freezed,Object? gpu = freezed,Object? port = freezed,}) {
  return _then(_self.copyWith(
protocol: freezed == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as String?,listen: freezed == listen ? _self.listen : listen // ignore: cast_nullable_to_non_nullable
as String?,gpu: freezed == gpu ? _self.gpu : gpu // ignore: cast_nullable_to_non_nullable
as String?,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtHwDisplay].
extension VirtHwDisplayPatterns on VirtHwDisplay {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtHwDisplay value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtHwDisplay() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtHwDisplay value)  $default,){
final _that = this;
switch (_that) {
case _VirtHwDisplay():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtHwDisplay value)?  $default,){
final _that = this;
switch (_that) {
case _VirtHwDisplay() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? protocol,  String? listen,  String? gpu,  int? port)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHwDisplay() when $default != null:
return $default(_that.protocol,_that.listen,_that.gpu,_that.port);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? protocol,  String? listen,  String? gpu,  int? port)  $default,) {final _that = this;
switch (_that) {
case _VirtHwDisplay():
return $default(_that.protocol,_that.listen,_that.gpu,_that.port);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? protocol,  String? listen,  String? gpu,  int? port)?  $default,) {final _that = this;
switch (_that) {
case _VirtHwDisplay() when $default != null:
return $default(_that.protocol,_that.listen,_that.gpu,_that.port);case _:
  return null;

}
}

}

/// @nodoc


class _VirtHwDisplay implements VirtHwDisplay {
  const _VirtHwDisplay({this.protocol, this.listen, this.gpu, this.port});
  

/// `vnc`, `spice`; null where the host decides (PVE: VNC through its
/// own proxy, SPICE with a `qxl` card).
@override final  String? protocol;
/// The address the console listens on (libvirt); null for the default.
@override final  String? listen;
/// The video card: libvirt's model, PVE's `vga` type.
@override final  String? gpu;
@override final  int? port;

/// Create a copy of VirtHwDisplay
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHwDisplayCopyWith<_VirtHwDisplay> get copyWith => __$VirtHwDisplayCopyWithImpl<_VirtHwDisplay>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHwDisplay&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.listen, listen) || other.listen == listen)&&(identical(other.gpu, gpu) || other.gpu == gpu)&&(identical(other.port, port) || other.port == port));
}


@override
int get hashCode => Object.hash(runtimeType,protocol,listen,gpu,port);

@override
String toString() {
  return 'VirtHwDisplay(protocol: $protocol, listen: $listen, gpu: $gpu, port: $port)';
}


}

/// @nodoc
abstract mixin class _$VirtHwDisplayCopyWith<$Res> implements $VirtHwDisplayCopyWith<$Res> {
  factory _$VirtHwDisplayCopyWith(_VirtHwDisplay value, $Res Function(_VirtHwDisplay) _then) = __$VirtHwDisplayCopyWithImpl;
@override @useResult
$Res call({
 String? protocol, String? listen, String? gpu, int? port
});




}
/// @nodoc
class __$VirtHwDisplayCopyWithImpl<$Res>
    implements _$VirtHwDisplayCopyWith<$Res> {
  __$VirtHwDisplayCopyWithImpl(this._self, this._then);

  final _VirtHwDisplay _self;
  final $Res Function(_VirtHwDisplay) _then;

/// Create a copy of VirtHwDisplay
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? protocol = freezed,Object? listen = freezed,Object? gpu = freezed,Object? port = freezed,}) {
  return _then(_VirtHwDisplay(
protocol: freezed == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as String?,listen: freezed == listen ? _self.listen : listen // ignore: cast_nullable_to_non_nullable
as String?,gpu: freezed == gpu ? _self.gpu : gpu // ignore: cast_nullable_to_non_nullable
as String?,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$VirtHwDevice {

/// PVE option (`usb0`, `hostpci0`, `tpmstate0`); libvirt
/// `usb:0bda:b023`, `pci:0000:01:00.0`, `tpm`.
 String get key; VirtHwDeviceKind get kind;/// `0bda:b023`, `0000:01:00.0`, a PVE mapping's name, or the TPM's
/// model and version.
 String? get detail;/// Given through a PVE resource mapping rather than by address.
 bool get mapping;
/// Create a copy of VirtHwDevice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwDeviceCopyWith<VirtHwDevice> get copyWith => _$VirtHwDeviceCopyWithImpl<VirtHwDevice>(this as VirtHwDevice, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwDevice&&(identical(other.key, key) || other.key == key)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.mapping, mapping) || other.mapping == mapping));
}


@override
int get hashCode => Object.hash(runtimeType,key,kind,detail,mapping);

@override
String toString() {
  return 'VirtHwDevice(key: $key, kind: $kind, detail: $detail, mapping: $mapping)';
}


}

/// @nodoc
abstract mixin class $VirtHwDeviceCopyWith<$Res>  {
  factory $VirtHwDeviceCopyWith(VirtHwDevice value, $Res Function(VirtHwDevice) _then) = _$VirtHwDeviceCopyWithImpl;
@useResult
$Res call({
 String key, VirtHwDeviceKind kind, String? detail, bool mapping
});




}
/// @nodoc
class _$VirtHwDeviceCopyWithImpl<$Res>
    implements $VirtHwDeviceCopyWith<$Res> {
  _$VirtHwDeviceCopyWithImpl(this._self, this._then);

  final VirtHwDevice _self;
  final $Res Function(VirtHwDevice) _then;

/// Create a copy of VirtHwDevice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? kind = null,Object? detail = freezed,Object? mapping = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as VirtHwDeviceKind,detail: freezed == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String?,mapping: null == mapping ? _self.mapping : mapping // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtHwDevice].
extension VirtHwDevicePatterns on VirtHwDevice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtHwDevice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtHwDevice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtHwDevice value)  $default,){
final _that = this;
switch (_that) {
case _VirtHwDevice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtHwDevice value)?  $default,){
final _that = this;
switch (_that) {
case _VirtHwDevice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  VirtHwDeviceKind kind,  String? detail,  bool mapping)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHwDevice() when $default != null:
return $default(_that.key,_that.kind,_that.detail,_that.mapping);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  VirtHwDeviceKind kind,  String? detail,  bool mapping)  $default,) {final _that = this;
switch (_that) {
case _VirtHwDevice():
return $default(_that.key,_that.kind,_that.detail,_that.mapping);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  VirtHwDeviceKind kind,  String? detail,  bool mapping)?  $default,) {final _that = this;
switch (_that) {
case _VirtHwDevice() when $default != null:
return $default(_that.key,_that.kind,_that.detail,_that.mapping);case _:
  return null;

}
}

}

/// @nodoc


class _VirtHwDevice implements VirtHwDevice {
  const _VirtHwDevice({required this.key, required this.kind, this.detail, this.mapping = false});
  

/// PVE option (`usb0`, `hostpci0`, `tpmstate0`); libvirt
/// `usb:0bda:b023`, `pci:0000:01:00.0`, `tpm`.
@override final  String key;
@override final  VirtHwDeviceKind kind;
/// `0bda:b023`, `0000:01:00.0`, a PVE mapping's name, or the TPM's
/// model and version.
@override final  String? detail;
/// Given through a PVE resource mapping rather than by address.
@override@JsonKey() final  bool mapping;

/// Create a copy of VirtHwDevice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHwDeviceCopyWith<_VirtHwDevice> get copyWith => __$VirtHwDeviceCopyWithImpl<_VirtHwDevice>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHwDevice&&(identical(other.key, key) || other.key == key)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.mapping, mapping) || other.mapping == mapping));
}


@override
int get hashCode => Object.hash(runtimeType,key,kind,detail,mapping);

@override
String toString() {
  return 'VirtHwDevice(key: $key, kind: $kind, detail: $detail, mapping: $mapping)';
}


}

/// @nodoc
abstract mixin class _$VirtHwDeviceCopyWith<$Res> implements $VirtHwDeviceCopyWith<$Res> {
  factory _$VirtHwDeviceCopyWith(_VirtHwDevice value, $Res Function(_VirtHwDevice) _then) = __$VirtHwDeviceCopyWithImpl;
@override @useResult
$Res call({
 String key, VirtHwDeviceKind kind, String? detail, bool mapping
});




}
/// @nodoc
class __$VirtHwDeviceCopyWithImpl<$Res>
    implements _$VirtHwDeviceCopyWith<$Res> {
  __$VirtHwDeviceCopyWithImpl(this._self, this._then);

  final _VirtHwDevice _self;
  final $Res Function(_VirtHwDevice) _then;

/// Create a copy of VirtHwDevice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? kind = null,Object? detail = freezed,Object? mapping = null,}) {
  return _then(_VirtHwDevice(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as VirtHwDeviceKind,detail: freezed == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String?,mapping: null == mapping ? _self.mapping : mapping // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$VirtHwSupport {

/// Disk buses; empty: the bus is not changed here.
 List<String> get buses; List<String> get caches; List<String> get nicModels;/// A NIC's MAC can be set.
 bool get mac;/// Console protocols to choose from; empty where the host has one.
 List<String> get protocols;/// The console's listen address can be set (libvirt).
 bool get listen; List<String> get gpus; bool get uefi; bool get secureBoot; bool get tpm; bool get usb; bool get pci;
/// Create a copy of VirtHwSupport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwSupportCopyWith<VirtHwSupport> get copyWith => _$VirtHwSupportCopyWithImpl<VirtHwSupport>(this as VirtHwSupport, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwSupport&&const DeepCollectionEquality().equals(other.buses, buses)&&const DeepCollectionEquality().equals(other.caches, caches)&&const DeepCollectionEquality().equals(other.nicModels, nicModels)&&(identical(other.mac, mac) || other.mac == mac)&&const DeepCollectionEquality().equals(other.protocols, protocols)&&(identical(other.listen, listen) || other.listen == listen)&&const DeepCollectionEquality().equals(other.gpus, gpus)&&(identical(other.uefi, uefi) || other.uefi == uefi)&&(identical(other.secureBoot, secureBoot) || other.secureBoot == secureBoot)&&(identical(other.tpm, tpm) || other.tpm == tpm)&&(identical(other.usb, usb) || other.usb == usb)&&(identical(other.pci, pci) || other.pci == pci));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(buses),const DeepCollectionEquality().hash(caches),const DeepCollectionEquality().hash(nicModels),mac,const DeepCollectionEquality().hash(protocols),listen,const DeepCollectionEquality().hash(gpus),uefi,secureBoot,tpm,usb,pci);

@override
String toString() {
  return 'VirtHwSupport(buses: $buses, caches: $caches, nicModels: $nicModels, mac: $mac, protocols: $protocols, listen: $listen, gpus: $gpus, uefi: $uefi, secureBoot: $secureBoot, tpm: $tpm, usb: $usb, pci: $pci)';
}


}

/// @nodoc
abstract mixin class $VirtHwSupportCopyWith<$Res>  {
  factory $VirtHwSupportCopyWith(VirtHwSupport value, $Res Function(VirtHwSupport) _then) = _$VirtHwSupportCopyWithImpl;
@useResult
$Res call({
 List<String> buses, List<String> caches, List<String> nicModels, bool mac, List<String> protocols, bool listen, List<String> gpus, bool uefi, bool secureBoot, bool tpm, bool usb, bool pci
});




}
/// @nodoc
class _$VirtHwSupportCopyWithImpl<$Res>
    implements $VirtHwSupportCopyWith<$Res> {
  _$VirtHwSupportCopyWithImpl(this._self, this._then);

  final VirtHwSupport _self;
  final $Res Function(VirtHwSupport) _then;

/// Create a copy of VirtHwSupport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? buses = null,Object? caches = null,Object? nicModels = null,Object? mac = null,Object? protocols = null,Object? listen = null,Object? gpus = null,Object? uefi = null,Object? secureBoot = null,Object? tpm = null,Object? usb = null,Object? pci = null,}) {
  return _then(_self.copyWith(
buses: null == buses ? _self.buses : buses // ignore: cast_nullable_to_non_nullable
as List<String>,caches: null == caches ? _self.caches : caches // ignore: cast_nullable_to_non_nullable
as List<String>,nicModels: null == nicModels ? _self.nicModels : nicModels // ignore: cast_nullable_to_non_nullable
as List<String>,mac: null == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as bool,protocols: null == protocols ? _self.protocols : protocols // ignore: cast_nullable_to_non_nullable
as List<String>,listen: null == listen ? _self.listen : listen // ignore: cast_nullable_to_non_nullable
as bool,gpus: null == gpus ? _self.gpus : gpus // ignore: cast_nullable_to_non_nullable
as List<String>,uefi: null == uefi ? _self.uefi : uefi // ignore: cast_nullable_to_non_nullable
as bool,secureBoot: null == secureBoot ? _self.secureBoot : secureBoot // ignore: cast_nullable_to_non_nullable
as bool,tpm: null == tpm ? _self.tpm : tpm // ignore: cast_nullable_to_non_nullable
as bool,usb: null == usb ? _self.usb : usb // ignore: cast_nullable_to_non_nullable
as bool,pci: null == pci ? _self.pci : pci // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtHwSupport].
extension VirtHwSupportPatterns on VirtHwSupport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtHwSupport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtHwSupport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtHwSupport value)  $default,){
final _that = this;
switch (_that) {
case _VirtHwSupport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtHwSupport value)?  $default,){
final _that = this;
switch (_that) {
case _VirtHwSupport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> buses,  List<String> caches,  List<String> nicModels,  bool mac,  List<String> protocols,  bool listen,  List<String> gpus,  bool uefi,  bool secureBoot,  bool tpm,  bool usb,  bool pci)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHwSupport() when $default != null:
return $default(_that.buses,_that.caches,_that.nicModels,_that.mac,_that.protocols,_that.listen,_that.gpus,_that.uefi,_that.secureBoot,_that.tpm,_that.usb,_that.pci);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> buses,  List<String> caches,  List<String> nicModels,  bool mac,  List<String> protocols,  bool listen,  List<String> gpus,  bool uefi,  bool secureBoot,  bool tpm,  bool usb,  bool pci)  $default,) {final _that = this;
switch (_that) {
case _VirtHwSupport():
return $default(_that.buses,_that.caches,_that.nicModels,_that.mac,_that.protocols,_that.listen,_that.gpus,_that.uefi,_that.secureBoot,_that.tpm,_that.usb,_that.pci);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> buses,  List<String> caches,  List<String> nicModels,  bool mac,  List<String> protocols,  bool listen,  List<String> gpus,  bool uefi,  bool secureBoot,  bool tpm,  bool usb,  bool pci)?  $default,) {final _that = this;
switch (_that) {
case _VirtHwSupport() when $default != null:
return $default(_that.buses,_that.caches,_that.nicModels,_that.mac,_that.protocols,_that.listen,_that.gpus,_that.uefi,_that.secureBoot,_that.tpm,_that.usb,_that.pci);case _:
  return null;

}
}

}

/// @nodoc


class _VirtHwSupport implements VirtHwSupport {
  const _VirtHwSupport({final  List<String> buses = const <String>[], final  List<String> caches = const <String>[], final  List<String> nicModels = const <String>[], this.mac = false, final  List<String> protocols = const <String>[], this.listen = false, final  List<String> gpus = const <String>[], this.uefi = false, this.secureBoot = false, this.tpm = false, this.usb = false, this.pci = false}): _buses = buses,_caches = caches,_nicModels = nicModels,_protocols = protocols,_gpus = gpus;
  

/// Disk buses; empty: the bus is not changed here.
 final  List<String> _buses;
/// Disk buses; empty: the bus is not changed here.
@override@JsonKey() List<String> get buses {
  if (_buses is EqualUnmodifiableListView) return _buses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_buses);
}

 final  List<String> _caches;
@override@JsonKey() List<String> get caches {
  if (_caches is EqualUnmodifiableListView) return _caches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_caches);
}

 final  List<String> _nicModels;
@override@JsonKey() List<String> get nicModels {
  if (_nicModels is EqualUnmodifiableListView) return _nicModels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nicModels);
}

/// A NIC's MAC can be set.
@override@JsonKey() final  bool mac;
/// Console protocols to choose from; empty where the host has one.
 final  List<String> _protocols;
/// Console protocols to choose from; empty where the host has one.
@override@JsonKey() List<String> get protocols {
  if (_protocols is EqualUnmodifiableListView) return _protocols;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_protocols);
}

/// The console's listen address can be set (libvirt).
@override@JsonKey() final  bool listen;
 final  List<String> _gpus;
@override@JsonKey() List<String> get gpus {
  if (_gpus is EqualUnmodifiableListView) return _gpus;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_gpus);
}

@override@JsonKey() final  bool uefi;
@override@JsonKey() final  bool secureBoot;
@override@JsonKey() final  bool tpm;
@override@JsonKey() final  bool usb;
@override@JsonKey() final  bool pci;

/// Create a copy of VirtHwSupport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHwSupportCopyWith<_VirtHwSupport> get copyWith => __$VirtHwSupportCopyWithImpl<_VirtHwSupport>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHwSupport&&const DeepCollectionEquality().equals(other._buses, _buses)&&const DeepCollectionEquality().equals(other._caches, _caches)&&const DeepCollectionEquality().equals(other._nicModels, _nicModels)&&(identical(other.mac, mac) || other.mac == mac)&&const DeepCollectionEquality().equals(other._protocols, _protocols)&&(identical(other.listen, listen) || other.listen == listen)&&const DeepCollectionEquality().equals(other._gpus, _gpus)&&(identical(other.uefi, uefi) || other.uefi == uefi)&&(identical(other.secureBoot, secureBoot) || other.secureBoot == secureBoot)&&(identical(other.tpm, tpm) || other.tpm == tpm)&&(identical(other.usb, usb) || other.usb == usb)&&(identical(other.pci, pci) || other.pci == pci));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_buses),const DeepCollectionEquality().hash(_caches),const DeepCollectionEquality().hash(_nicModels),mac,const DeepCollectionEquality().hash(_protocols),listen,const DeepCollectionEquality().hash(_gpus),uefi,secureBoot,tpm,usb,pci);

@override
String toString() {
  return 'VirtHwSupport(buses: $buses, caches: $caches, nicModels: $nicModels, mac: $mac, protocols: $protocols, listen: $listen, gpus: $gpus, uefi: $uefi, secureBoot: $secureBoot, tpm: $tpm, usb: $usb, pci: $pci)';
}


}

/// @nodoc
abstract mixin class _$VirtHwSupportCopyWith<$Res> implements $VirtHwSupportCopyWith<$Res> {
  factory _$VirtHwSupportCopyWith(_VirtHwSupport value, $Res Function(_VirtHwSupport) _then) = __$VirtHwSupportCopyWithImpl;
@override @useResult
$Res call({
 List<String> buses, List<String> caches, List<String> nicModels, bool mac, List<String> protocols, bool listen, List<String> gpus, bool uefi, bool secureBoot, bool tpm, bool usb, bool pci
});




}
/// @nodoc
class __$VirtHwSupportCopyWithImpl<$Res>
    implements _$VirtHwSupportCopyWith<$Res> {
  __$VirtHwSupportCopyWithImpl(this._self, this._then);

  final _VirtHwSupport _self;
  final $Res Function(_VirtHwSupport) _then;

/// Create a copy of VirtHwSupport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? buses = null,Object? caches = null,Object? nicModels = null,Object? mac = null,Object? protocols = null,Object? listen = null,Object? gpus = null,Object? uefi = null,Object? secureBoot = null,Object? tpm = null,Object? usb = null,Object? pci = null,}) {
  return _then(_VirtHwSupport(
buses: null == buses ? _self._buses : buses // ignore: cast_nullable_to_non_nullable
as List<String>,caches: null == caches ? _self._caches : caches // ignore: cast_nullable_to_non_nullable
as List<String>,nicModels: null == nicModels ? _self._nicModels : nicModels // ignore: cast_nullable_to_non_nullable
as List<String>,mac: null == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as bool,protocols: null == protocols ? _self._protocols : protocols // ignore: cast_nullable_to_non_nullable
as List<String>,listen: null == listen ? _self.listen : listen // ignore: cast_nullable_to_non_nullable
as bool,gpus: null == gpus ? _self._gpus : gpus // ignore: cast_nullable_to_non_nullable
as List<String>,uefi: null == uefi ? _self.uefi : uefi // ignore: cast_nullable_to_non_nullable
as bool,secureBoot: null == secureBoot ? _self.secureBoot : secureBoot // ignore: cast_nullable_to_non_nullable
as bool,tpm: null == tpm ? _self.tpm : tpm // ignore: cast_nullable_to_non_nullable
as bool,usb: null == usb ? _self.usb : usb // ignore: cast_nullable_to_non_nullable
as bool,pci: null == pci ? _self.pci : pci // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$VirtHostDevice {

/// What attaching sends: `0bda:b023`, `0000:01:00.0`, or a PVE
/// mapping's name.
 String get id; String get label; String? get detail;/// A PVE resource mapping rather than a raw device.
 bool get mapping; int? get iommuGroup;/// Devices sharing its IOMMU group, itself included: all of them go to
/// the guest together.
 int get groupSize;
/// Create a copy of VirtHostDevice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHostDeviceCopyWith<VirtHostDevice> get copyWith => _$VirtHostDeviceCopyWithImpl<VirtHostDevice>(this as VirtHostDevice, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHostDevice&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.mapping, mapping) || other.mapping == mapping)&&(identical(other.iommuGroup, iommuGroup) || other.iommuGroup == iommuGroup)&&(identical(other.groupSize, groupSize) || other.groupSize == groupSize));
}


@override
int get hashCode => Object.hash(runtimeType,id,label,detail,mapping,iommuGroup,groupSize);

@override
String toString() {
  return 'VirtHostDevice(id: $id, label: $label, detail: $detail, mapping: $mapping, iommuGroup: $iommuGroup, groupSize: $groupSize)';
}


}

/// @nodoc
abstract mixin class $VirtHostDeviceCopyWith<$Res>  {
  factory $VirtHostDeviceCopyWith(VirtHostDevice value, $Res Function(VirtHostDevice) _then) = _$VirtHostDeviceCopyWithImpl;
@useResult
$Res call({
 String id, String label, String? detail, bool mapping, int? iommuGroup, int groupSize
});




}
/// @nodoc
class _$VirtHostDeviceCopyWithImpl<$Res>
    implements $VirtHostDeviceCopyWith<$Res> {
  _$VirtHostDeviceCopyWithImpl(this._self, this._then);

  final VirtHostDevice _self;
  final $Res Function(VirtHostDevice) _then;

/// Create a copy of VirtHostDevice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? detail = freezed,Object? mapping = null,Object? iommuGroup = freezed,Object? groupSize = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,detail: freezed == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String?,mapping: null == mapping ? _self.mapping : mapping // ignore: cast_nullable_to_non_nullable
as bool,iommuGroup: freezed == iommuGroup ? _self.iommuGroup : iommuGroup // ignore: cast_nullable_to_non_nullable
as int?,groupSize: null == groupSize ? _self.groupSize : groupSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtHostDevice].
extension VirtHostDevicePatterns on VirtHostDevice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtHostDevice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtHostDevice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtHostDevice value)  $default,){
final _that = this;
switch (_that) {
case _VirtHostDevice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtHostDevice value)?  $default,){
final _that = this;
switch (_that) {
case _VirtHostDevice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label,  String? detail,  bool mapping,  int? iommuGroup,  int groupSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHostDevice() when $default != null:
return $default(_that.id,_that.label,_that.detail,_that.mapping,_that.iommuGroup,_that.groupSize);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label,  String? detail,  bool mapping,  int? iommuGroup,  int groupSize)  $default,) {final _that = this;
switch (_that) {
case _VirtHostDevice():
return $default(_that.id,_that.label,_that.detail,_that.mapping,_that.iommuGroup,_that.groupSize);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label,  String? detail,  bool mapping,  int? iommuGroup,  int groupSize)?  $default,) {final _that = this;
switch (_that) {
case _VirtHostDevice() when $default != null:
return $default(_that.id,_that.label,_that.detail,_that.mapping,_that.iommuGroup,_that.groupSize);case _:
  return null;

}
}

}

/// @nodoc


class _VirtHostDevice implements VirtHostDevice {
  const _VirtHostDevice({required this.id, required this.label, this.detail, this.mapping = false, this.iommuGroup, this.groupSize = 0});
  

/// What attaching sends: `0bda:b023`, `0000:01:00.0`, or a PVE
/// mapping's name.
@override final  String id;
@override final  String label;
@override final  String? detail;
/// A PVE resource mapping rather than a raw device.
@override@JsonKey() final  bool mapping;
@override final  int? iommuGroup;
/// Devices sharing its IOMMU group, itself included: all of them go to
/// the guest together.
@override@JsonKey() final  int groupSize;

/// Create a copy of VirtHostDevice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHostDeviceCopyWith<_VirtHostDevice> get copyWith => __$VirtHostDeviceCopyWithImpl<_VirtHostDevice>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHostDevice&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.mapping, mapping) || other.mapping == mapping)&&(identical(other.iommuGroup, iommuGroup) || other.iommuGroup == iommuGroup)&&(identical(other.groupSize, groupSize) || other.groupSize == groupSize));
}


@override
int get hashCode => Object.hash(runtimeType,id,label,detail,mapping,iommuGroup,groupSize);

@override
String toString() {
  return 'VirtHostDevice(id: $id, label: $label, detail: $detail, mapping: $mapping, iommuGroup: $iommuGroup, groupSize: $groupSize)';
}


}

/// @nodoc
abstract mixin class _$VirtHostDeviceCopyWith<$Res> implements $VirtHostDeviceCopyWith<$Res> {
  factory _$VirtHostDeviceCopyWith(_VirtHostDevice value, $Res Function(_VirtHostDevice) _then) = __$VirtHostDeviceCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, String? detail, bool mapping, int? iommuGroup, int groupSize
});




}
/// @nodoc
class __$VirtHostDeviceCopyWithImpl<$Res>
    implements _$VirtHostDeviceCopyWith<$Res> {
  __$VirtHostDeviceCopyWithImpl(this._self, this._then);

  final _VirtHostDevice _self;
  final $Res Function(_VirtHostDevice) _then;

/// Create a copy of VirtHostDevice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? detail = freezed,Object? mapping = null,Object? iommuGroup = freezed,Object? groupSize = null,}) {
  return _then(_VirtHostDevice(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,detail: freezed == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String?,mapping: null == mapping ? _self.mapping : mapping // ignore: cast_nullable_to_non_nullable
as bool,iommuGroup: freezed == iommuGroup ? _self.iommuGroup : iommuGroup // ignore: cast_nullable_to_non_nullable
as int?,groupSize: null == groupSize ? _self.groupSize : groupSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$VirtHostDevices {

 List<VirtHostDevice> get usb; List<VirtHostDevice> get pci;/// The host has an IOMMU on; false: VT-d/AMD-Vi is off or absent, and
/// a PCI device given to a guest keeps it from starting.
 bool get iommu;/// PVE: this login may only use resource mappings (only root@pam gives
/// a guest a raw device).
 bool get mappingsOnly;
/// Create a copy of VirtHostDevices
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHostDevicesCopyWith<VirtHostDevices> get copyWith => _$VirtHostDevicesCopyWithImpl<VirtHostDevices>(this as VirtHostDevices, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHostDevices&&const DeepCollectionEquality().equals(other.usb, usb)&&const DeepCollectionEquality().equals(other.pci, pci)&&(identical(other.iommu, iommu) || other.iommu == iommu)&&(identical(other.mappingsOnly, mappingsOnly) || other.mappingsOnly == mappingsOnly));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(usb),const DeepCollectionEquality().hash(pci),iommu,mappingsOnly);

@override
String toString() {
  return 'VirtHostDevices(usb: $usb, pci: $pci, iommu: $iommu, mappingsOnly: $mappingsOnly)';
}


}

/// @nodoc
abstract mixin class $VirtHostDevicesCopyWith<$Res>  {
  factory $VirtHostDevicesCopyWith(VirtHostDevices value, $Res Function(VirtHostDevices) _then) = _$VirtHostDevicesCopyWithImpl;
@useResult
$Res call({
 List<VirtHostDevice> usb, List<VirtHostDevice> pci, bool iommu, bool mappingsOnly
});




}
/// @nodoc
class _$VirtHostDevicesCopyWithImpl<$Res>
    implements $VirtHostDevicesCopyWith<$Res> {
  _$VirtHostDevicesCopyWithImpl(this._self, this._then);

  final VirtHostDevices _self;
  final $Res Function(VirtHostDevices) _then;

/// Create a copy of VirtHostDevices
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? usb = null,Object? pci = null,Object? iommu = null,Object? mappingsOnly = null,}) {
  return _then(_self.copyWith(
usb: null == usb ? _self.usb : usb // ignore: cast_nullable_to_non_nullable
as List<VirtHostDevice>,pci: null == pci ? _self.pci : pci // ignore: cast_nullable_to_non_nullable
as List<VirtHostDevice>,iommu: null == iommu ? _self.iommu : iommu // ignore: cast_nullable_to_non_nullable
as bool,mappingsOnly: null == mappingsOnly ? _self.mappingsOnly : mappingsOnly // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtHostDevices].
extension VirtHostDevicesPatterns on VirtHostDevices {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtHostDevices value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtHostDevices() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtHostDevices value)  $default,){
final _that = this;
switch (_that) {
case _VirtHostDevices():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtHostDevices value)?  $default,){
final _that = this;
switch (_that) {
case _VirtHostDevices() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<VirtHostDevice> usb,  List<VirtHostDevice> pci,  bool iommu,  bool mappingsOnly)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHostDevices() when $default != null:
return $default(_that.usb,_that.pci,_that.iommu,_that.mappingsOnly);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<VirtHostDevice> usb,  List<VirtHostDevice> pci,  bool iommu,  bool mappingsOnly)  $default,) {final _that = this;
switch (_that) {
case _VirtHostDevices():
return $default(_that.usb,_that.pci,_that.iommu,_that.mappingsOnly);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<VirtHostDevice> usb,  List<VirtHostDevice> pci,  bool iommu,  bool mappingsOnly)?  $default,) {final _that = this;
switch (_that) {
case _VirtHostDevices() when $default != null:
return $default(_that.usb,_that.pci,_that.iommu,_that.mappingsOnly);case _:
  return null;

}
}

}

/// @nodoc


class _VirtHostDevices implements VirtHostDevices {
  const _VirtHostDevices({final  List<VirtHostDevice> usb = const <VirtHostDevice>[], final  List<VirtHostDevice> pci = const <VirtHostDevice>[], this.iommu = true, this.mappingsOnly = false}): _usb = usb,_pci = pci;
  

 final  List<VirtHostDevice> _usb;
@override@JsonKey() List<VirtHostDevice> get usb {
  if (_usb is EqualUnmodifiableListView) return _usb;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_usb);
}

 final  List<VirtHostDevice> _pci;
@override@JsonKey() List<VirtHostDevice> get pci {
  if (_pci is EqualUnmodifiableListView) return _pci;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pci);
}

/// The host has an IOMMU on; false: VT-d/AMD-Vi is off or absent, and
/// a PCI device given to a guest keeps it from starting.
@override@JsonKey() final  bool iommu;
/// PVE: this login may only use resource mappings (only root@pam gives
/// a guest a raw device).
@override@JsonKey() final  bool mappingsOnly;

/// Create a copy of VirtHostDevices
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHostDevicesCopyWith<_VirtHostDevices> get copyWith => __$VirtHostDevicesCopyWithImpl<_VirtHostDevices>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHostDevices&&const DeepCollectionEquality().equals(other._usb, _usb)&&const DeepCollectionEquality().equals(other._pci, _pci)&&(identical(other.iommu, iommu) || other.iommu == iommu)&&(identical(other.mappingsOnly, mappingsOnly) || other.mappingsOnly == mappingsOnly));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_usb),const DeepCollectionEquality().hash(_pci),iommu,mappingsOnly);

@override
String toString() {
  return 'VirtHostDevices(usb: $usb, pci: $pci, iommu: $iommu, mappingsOnly: $mappingsOnly)';
}


}

/// @nodoc
abstract mixin class _$VirtHostDevicesCopyWith<$Res> implements $VirtHostDevicesCopyWith<$Res> {
  factory _$VirtHostDevicesCopyWith(_VirtHostDevices value, $Res Function(_VirtHostDevices) _then) = __$VirtHostDevicesCopyWithImpl;
@override @useResult
$Res call({
 List<VirtHostDevice> usb, List<VirtHostDevice> pci, bool iommu, bool mappingsOnly
});




}
/// @nodoc
class __$VirtHostDevicesCopyWithImpl<$Res>
    implements _$VirtHostDevicesCopyWith<$Res> {
  __$VirtHostDevicesCopyWithImpl(this._self, this._then);

  final _VirtHostDevices _self;
  final $Res Function(_VirtHostDevices) _then;

/// Create a copy of VirtHostDevices
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? usb = null,Object? pci = null,Object? iommu = null,Object? mappingsOnly = null,}) {
  return _then(_VirtHostDevices(
usb: null == usb ? _self._usb : usb // ignore: cast_nullable_to_non_nullable
as List<VirtHostDevice>,pci: null == pci ? _self._pci : pci // ignore: cast_nullable_to_non_nullable
as List<VirtHostDevice>,iommu: null == iommu ? _self.iommu : iommu // ignore: cast_nullable_to_non_nullable
as bool,mappingsOnly: null == mappingsOnly ? _self.mappingsOnly : mappingsOnly // ignore: cast_nullable_to_non_nullable
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
