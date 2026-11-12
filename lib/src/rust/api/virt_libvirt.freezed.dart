// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'virt_libvirt.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VirtHwChange {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'VirtHwChange()';
}


}

/// @nodoc
class $VirtHwChangeCopyWith<$Res>  {
$VirtHwChangeCopyWith(VirtHwChange _, $Res Function(VirtHwChange) __);
}


/// Adds pattern-matching-related methods to [VirtHwChange].
extension VirtHwChangePatterns on VirtHwChange {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( VirtHwChange_Cpu value)?  cpu,TResult Function( VirtHwChange_Memory value)?  memory,TResult Function( VirtHwChange_GrowDisk value)?  growDisk,TResult Function( VirtHwChange_AddDisk value)?  addDisk,TResult Function( VirtHwChange_AttachVolume value)?  attachVolume,TResult Function( VirtHwChange_RemoveDisk value)?  removeDisk,TResult Function( VirtHwChange_AddCdrom value)?  addCdrom,TResult Function( VirtHwChange_SetMedia value)?  setMedia,TResult Function( VirtHwChange_AddNic value)?  addNic,TResult Function( VirtHwChange_RemoveNic value)?  removeNic,TResult Function( VirtHwChange_UpdateNic value)?  updateNic,TResult Function( VirtHwChange_Boot value)?  boot,TResult Function( VirtHwChange_Autostart value)?  autostart,TResult Function( VirtHwChange_Description value)?  description,TResult Function( VirtHwChange_Rename value)?  rename,TResult Function( VirtHwChange_UpdateDisk value)?  updateDisk,TResult Function( VirtHwChange_UpdateNicHardware value)?  updateNicHardware,TResult Function( VirtHwChange_Firmware value)?  firmware,TResult Function( VirtHwChange_Display value)?  display,TResult Function( VirtHwChange_AddDevice value)?  addDevice,TResult Function( VirtHwChange_RemoveDevice value)?  removeDevice,TResult Function( VirtHwChange_RevertLive value)?  revertLive,required TResult orElse(),}){
final _that = this;
switch (_that) {
case VirtHwChange_Cpu() when cpu != null:
return cpu(_that);case VirtHwChange_Memory() when memory != null:
return memory(_that);case VirtHwChange_GrowDisk() when growDisk != null:
return growDisk(_that);case VirtHwChange_AddDisk() when addDisk != null:
return addDisk(_that);case VirtHwChange_AttachVolume() when attachVolume != null:
return attachVolume(_that);case VirtHwChange_RemoveDisk() when removeDisk != null:
return removeDisk(_that);case VirtHwChange_AddCdrom() when addCdrom != null:
return addCdrom(_that);case VirtHwChange_SetMedia() when setMedia != null:
return setMedia(_that);case VirtHwChange_AddNic() when addNic != null:
return addNic(_that);case VirtHwChange_RemoveNic() when removeNic != null:
return removeNic(_that);case VirtHwChange_UpdateNic() when updateNic != null:
return updateNic(_that);case VirtHwChange_Boot() when boot != null:
return boot(_that);case VirtHwChange_Autostart() when autostart != null:
return autostart(_that);case VirtHwChange_Description() when description != null:
return description(_that);case VirtHwChange_Rename() when rename != null:
return rename(_that);case VirtHwChange_UpdateDisk() when updateDisk != null:
return updateDisk(_that);case VirtHwChange_UpdateNicHardware() when updateNicHardware != null:
return updateNicHardware(_that);case VirtHwChange_Firmware() when firmware != null:
return firmware(_that);case VirtHwChange_Display() when display != null:
return display(_that);case VirtHwChange_AddDevice() when addDevice != null:
return addDevice(_that);case VirtHwChange_RemoveDevice() when removeDevice != null:
return removeDevice(_that);case VirtHwChange_RevertLive() when revertLive != null:
return revertLive(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( VirtHwChange_Cpu value)  cpu,required TResult Function( VirtHwChange_Memory value)  memory,required TResult Function( VirtHwChange_GrowDisk value)  growDisk,required TResult Function( VirtHwChange_AddDisk value)  addDisk,required TResult Function( VirtHwChange_AttachVolume value)  attachVolume,required TResult Function( VirtHwChange_RemoveDisk value)  removeDisk,required TResult Function( VirtHwChange_AddCdrom value)  addCdrom,required TResult Function( VirtHwChange_SetMedia value)  setMedia,required TResult Function( VirtHwChange_AddNic value)  addNic,required TResult Function( VirtHwChange_RemoveNic value)  removeNic,required TResult Function( VirtHwChange_UpdateNic value)  updateNic,required TResult Function( VirtHwChange_Boot value)  boot,required TResult Function( VirtHwChange_Autostart value)  autostart,required TResult Function( VirtHwChange_Description value)  description,required TResult Function( VirtHwChange_Rename value)  rename,required TResult Function( VirtHwChange_UpdateDisk value)  updateDisk,required TResult Function( VirtHwChange_UpdateNicHardware value)  updateNicHardware,required TResult Function( VirtHwChange_Firmware value)  firmware,required TResult Function( VirtHwChange_Display value)  display,required TResult Function( VirtHwChange_AddDevice value)  addDevice,required TResult Function( VirtHwChange_RemoveDevice value)  removeDevice,required TResult Function( VirtHwChange_RevertLive value)  revertLive,}){
final _that = this;
switch (_that) {
case VirtHwChange_Cpu():
return cpu(_that);case VirtHwChange_Memory():
return memory(_that);case VirtHwChange_GrowDisk():
return growDisk(_that);case VirtHwChange_AddDisk():
return addDisk(_that);case VirtHwChange_AttachVolume():
return attachVolume(_that);case VirtHwChange_RemoveDisk():
return removeDisk(_that);case VirtHwChange_AddCdrom():
return addCdrom(_that);case VirtHwChange_SetMedia():
return setMedia(_that);case VirtHwChange_AddNic():
return addNic(_that);case VirtHwChange_RemoveNic():
return removeNic(_that);case VirtHwChange_UpdateNic():
return updateNic(_that);case VirtHwChange_Boot():
return boot(_that);case VirtHwChange_Autostart():
return autostart(_that);case VirtHwChange_Description():
return description(_that);case VirtHwChange_Rename():
return rename(_that);case VirtHwChange_UpdateDisk():
return updateDisk(_that);case VirtHwChange_UpdateNicHardware():
return updateNicHardware(_that);case VirtHwChange_Firmware():
return firmware(_that);case VirtHwChange_Display():
return display(_that);case VirtHwChange_AddDevice():
return addDevice(_that);case VirtHwChange_RemoveDevice():
return removeDevice(_that);case VirtHwChange_RevertLive():
return revertLive(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( VirtHwChange_Cpu value)?  cpu,TResult? Function( VirtHwChange_Memory value)?  memory,TResult? Function( VirtHwChange_GrowDisk value)?  growDisk,TResult? Function( VirtHwChange_AddDisk value)?  addDisk,TResult? Function( VirtHwChange_AttachVolume value)?  attachVolume,TResult? Function( VirtHwChange_RemoveDisk value)?  removeDisk,TResult? Function( VirtHwChange_AddCdrom value)?  addCdrom,TResult? Function( VirtHwChange_SetMedia value)?  setMedia,TResult? Function( VirtHwChange_AddNic value)?  addNic,TResult? Function( VirtHwChange_RemoveNic value)?  removeNic,TResult? Function( VirtHwChange_UpdateNic value)?  updateNic,TResult? Function( VirtHwChange_Boot value)?  boot,TResult? Function( VirtHwChange_Autostart value)?  autostart,TResult? Function( VirtHwChange_Description value)?  description,TResult? Function( VirtHwChange_Rename value)?  rename,TResult? Function( VirtHwChange_UpdateDisk value)?  updateDisk,TResult? Function( VirtHwChange_UpdateNicHardware value)?  updateNicHardware,TResult? Function( VirtHwChange_Firmware value)?  firmware,TResult? Function( VirtHwChange_Display value)?  display,TResult? Function( VirtHwChange_AddDevice value)?  addDevice,TResult? Function( VirtHwChange_RemoveDevice value)?  removeDevice,TResult? Function( VirtHwChange_RevertLive value)?  revertLive,}){
final _that = this;
switch (_that) {
case VirtHwChange_Cpu() when cpu != null:
return cpu(_that);case VirtHwChange_Memory() when memory != null:
return memory(_that);case VirtHwChange_GrowDisk() when growDisk != null:
return growDisk(_that);case VirtHwChange_AddDisk() when addDisk != null:
return addDisk(_that);case VirtHwChange_AttachVolume() when attachVolume != null:
return attachVolume(_that);case VirtHwChange_RemoveDisk() when removeDisk != null:
return removeDisk(_that);case VirtHwChange_AddCdrom() when addCdrom != null:
return addCdrom(_that);case VirtHwChange_SetMedia() when setMedia != null:
return setMedia(_that);case VirtHwChange_AddNic() when addNic != null:
return addNic(_that);case VirtHwChange_RemoveNic() when removeNic != null:
return removeNic(_that);case VirtHwChange_UpdateNic() when updateNic != null:
return updateNic(_that);case VirtHwChange_Boot() when boot != null:
return boot(_that);case VirtHwChange_Autostart() when autostart != null:
return autostart(_that);case VirtHwChange_Description() when description != null:
return description(_that);case VirtHwChange_Rename() when rename != null:
return rename(_that);case VirtHwChange_UpdateDisk() when updateDisk != null:
return updateDisk(_that);case VirtHwChange_UpdateNicHardware() when updateNicHardware != null:
return updateNicHardware(_that);case VirtHwChange_Firmware() when firmware != null:
return firmware(_that);case VirtHwChange_Display() when display != null:
return display(_that);case VirtHwChange_AddDevice() when addDevice != null:
return addDevice(_that);case VirtHwChange_RemoveDevice() when removeDevice != null:
return removeDevice(_that);case VirtHwChange_RevertLive() when revertLive != null:
return revertLive(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int sockets,  int cores,  int? current)?  cpu,TResult Function( BigInt memoryMib,  BigInt? currentMib)?  memory,TResult Function( String target,  BigInt bytes,  String? path,  bool live)?  growDisk,TResult Function( String pool,  String volume,  BigInt gib,  String format,  String target,  String bus)?  addDisk,TResult Function( String path,  String format,  String target,  String bus)?  attachVolume,TResult Function( String target,  String? deletePath,  bool config,  bool live)?  removeDisk,TResult Function( String target,  String bus,  String? source)?  addCdrom,TResult Function( String target,  String? source,  bool config,  bool live)?  setMedia,TResult Function( String kind,  String source,  String model,  String mac)?  addNic,TResult Function( String mac,  String? kind,  String? liveKind)?  removeNic,TResult Function( String mac,  String kind,  String source,  String? model,  bool linkUp,  int? bootOrder,  int? liveBootOrder,  bool config,  bool live)?  updateNic,TResult Function( List<String> order)?  boot,TResult Function( bool on_)?  autostart,TResult Function( String text)?  description,TResult Function( String name)?  rename,TResult Function( String target,  String? newTarget,  String? bus,  String? cache)?  updateDisk,TResult Function( String mac,  String? newMac,  String? model)?  updateNicHardware,TResult Function( bool efi,  bool secureBoot)?  firmware,TResult Function( String? graphics,  String? listen,  String? video)?  display,TResult Function( VirtHwNewDevice device)?  addDevice,TResult Function( String key)?  removeDevice,TResult Function( String liveXml)?  revertLive,required TResult orElse(),}) {final _that = this;
switch (_that) {
case VirtHwChange_Cpu() when cpu != null:
return cpu(_that.sockets,_that.cores,_that.current);case VirtHwChange_Memory() when memory != null:
return memory(_that.memoryMib,_that.currentMib);case VirtHwChange_GrowDisk() when growDisk != null:
return growDisk(_that.target,_that.bytes,_that.path,_that.live);case VirtHwChange_AddDisk() when addDisk != null:
return addDisk(_that.pool,_that.volume,_that.gib,_that.format,_that.target,_that.bus);case VirtHwChange_AttachVolume() when attachVolume != null:
return attachVolume(_that.path,_that.format,_that.target,_that.bus);case VirtHwChange_RemoveDisk() when removeDisk != null:
return removeDisk(_that.target,_that.deletePath,_that.config,_that.live);case VirtHwChange_AddCdrom() when addCdrom != null:
return addCdrom(_that.target,_that.bus,_that.source);case VirtHwChange_SetMedia() when setMedia != null:
return setMedia(_that.target,_that.source,_that.config,_that.live);case VirtHwChange_AddNic() when addNic != null:
return addNic(_that.kind,_that.source,_that.model,_that.mac);case VirtHwChange_RemoveNic() when removeNic != null:
return removeNic(_that.mac,_that.kind,_that.liveKind);case VirtHwChange_UpdateNic() when updateNic != null:
return updateNic(_that.mac,_that.kind,_that.source,_that.model,_that.linkUp,_that.bootOrder,_that.liveBootOrder,_that.config,_that.live);case VirtHwChange_Boot() when boot != null:
return boot(_that.order);case VirtHwChange_Autostart() when autostart != null:
return autostart(_that.on_);case VirtHwChange_Description() when description != null:
return description(_that.text);case VirtHwChange_Rename() when rename != null:
return rename(_that.name);case VirtHwChange_UpdateDisk() when updateDisk != null:
return updateDisk(_that.target,_that.newTarget,_that.bus,_that.cache);case VirtHwChange_UpdateNicHardware() when updateNicHardware != null:
return updateNicHardware(_that.mac,_that.newMac,_that.model);case VirtHwChange_Firmware() when firmware != null:
return firmware(_that.efi,_that.secureBoot);case VirtHwChange_Display() when display != null:
return display(_that.graphics,_that.listen,_that.video);case VirtHwChange_AddDevice() when addDevice != null:
return addDevice(_that.device);case VirtHwChange_RemoveDevice() when removeDevice != null:
return removeDevice(_that.key);case VirtHwChange_RevertLive() when revertLive != null:
return revertLive(_that.liveXml);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int sockets,  int cores,  int? current)  cpu,required TResult Function( BigInt memoryMib,  BigInt? currentMib)  memory,required TResult Function( String target,  BigInt bytes,  String? path,  bool live)  growDisk,required TResult Function( String pool,  String volume,  BigInt gib,  String format,  String target,  String bus)  addDisk,required TResult Function( String path,  String format,  String target,  String bus)  attachVolume,required TResult Function( String target,  String? deletePath,  bool config,  bool live)  removeDisk,required TResult Function( String target,  String bus,  String? source)  addCdrom,required TResult Function( String target,  String? source,  bool config,  bool live)  setMedia,required TResult Function( String kind,  String source,  String model,  String mac)  addNic,required TResult Function( String mac,  String? kind,  String? liveKind)  removeNic,required TResult Function( String mac,  String kind,  String source,  String? model,  bool linkUp,  int? bootOrder,  int? liveBootOrder,  bool config,  bool live)  updateNic,required TResult Function( List<String> order)  boot,required TResult Function( bool on_)  autostart,required TResult Function( String text)  description,required TResult Function( String name)  rename,required TResult Function( String target,  String? newTarget,  String? bus,  String? cache)  updateDisk,required TResult Function( String mac,  String? newMac,  String? model)  updateNicHardware,required TResult Function( bool efi,  bool secureBoot)  firmware,required TResult Function( String? graphics,  String? listen,  String? video)  display,required TResult Function( VirtHwNewDevice device)  addDevice,required TResult Function( String key)  removeDevice,required TResult Function( String liveXml)  revertLive,}) {final _that = this;
switch (_that) {
case VirtHwChange_Cpu():
return cpu(_that.sockets,_that.cores,_that.current);case VirtHwChange_Memory():
return memory(_that.memoryMib,_that.currentMib);case VirtHwChange_GrowDisk():
return growDisk(_that.target,_that.bytes,_that.path,_that.live);case VirtHwChange_AddDisk():
return addDisk(_that.pool,_that.volume,_that.gib,_that.format,_that.target,_that.bus);case VirtHwChange_AttachVolume():
return attachVolume(_that.path,_that.format,_that.target,_that.bus);case VirtHwChange_RemoveDisk():
return removeDisk(_that.target,_that.deletePath,_that.config,_that.live);case VirtHwChange_AddCdrom():
return addCdrom(_that.target,_that.bus,_that.source);case VirtHwChange_SetMedia():
return setMedia(_that.target,_that.source,_that.config,_that.live);case VirtHwChange_AddNic():
return addNic(_that.kind,_that.source,_that.model,_that.mac);case VirtHwChange_RemoveNic():
return removeNic(_that.mac,_that.kind,_that.liveKind);case VirtHwChange_UpdateNic():
return updateNic(_that.mac,_that.kind,_that.source,_that.model,_that.linkUp,_that.bootOrder,_that.liveBootOrder,_that.config,_that.live);case VirtHwChange_Boot():
return boot(_that.order);case VirtHwChange_Autostart():
return autostart(_that.on_);case VirtHwChange_Description():
return description(_that.text);case VirtHwChange_Rename():
return rename(_that.name);case VirtHwChange_UpdateDisk():
return updateDisk(_that.target,_that.newTarget,_that.bus,_that.cache);case VirtHwChange_UpdateNicHardware():
return updateNicHardware(_that.mac,_that.newMac,_that.model);case VirtHwChange_Firmware():
return firmware(_that.efi,_that.secureBoot);case VirtHwChange_Display():
return display(_that.graphics,_that.listen,_that.video);case VirtHwChange_AddDevice():
return addDevice(_that.device);case VirtHwChange_RemoveDevice():
return removeDevice(_that.key);case VirtHwChange_RevertLive():
return revertLive(_that.liveXml);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int sockets,  int cores,  int? current)?  cpu,TResult? Function( BigInt memoryMib,  BigInt? currentMib)?  memory,TResult? Function( String target,  BigInt bytes,  String? path,  bool live)?  growDisk,TResult? Function( String pool,  String volume,  BigInt gib,  String format,  String target,  String bus)?  addDisk,TResult? Function( String path,  String format,  String target,  String bus)?  attachVolume,TResult? Function( String target,  String? deletePath,  bool config,  bool live)?  removeDisk,TResult? Function( String target,  String bus,  String? source)?  addCdrom,TResult? Function( String target,  String? source,  bool config,  bool live)?  setMedia,TResult? Function( String kind,  String source,  String model,  String mac)?  addNic,TResult? Function( String mac,  String? kind,  String? liveKind)?  removeNic,TResult? Function( String mac,  String kind,  String source,  String? model,  bool linkUp,  int? bootOrder,  int? liveBootOrder,  bool config,  bool live)?  updateNic,TResult? Function( List<String> order)?  boot,TResult? Function( bool on_)?  autostart,TResult? Function( String text)?  description,TResult? Function( String name)?  rename,TResult? Function( String target,  String? newTarget,  String? bus,  String? cache)?  updateDisk,TResult? Function( String mac,  String? newMac,  String? model)?  updateNicHardware,TResult? Function( bool efi,  bool secureBoot)?  firmware,TResult? Function( String? graphics,  String? listen,  String? video)?  display,TResult? Function( VirtHwNewDevice device)?  addDevice,TResult? Function( String key)?  removeDevice,TResult? Function( String liveXml)?  revertLive,}) {final _that = this;
switch (_that) {
case VirtHwChange_Cpu() when cpu != null:
return cpu(_that.sockets,_that.cores,_that.current);case VirtHwChange_Memory() when memory != null:
return memory(_that.memoryMib,_that.currentMib);case VirtHwChange_GrowDisk() when growDisk != null:
return growDisk(_that.target,_that.bytes,_that.path,_that.live);case VirtHwChange_AddDisk() when addDisk != null:
return addDisk(_that.pool,_that.volume,_that.gib,_that.format,_that.target,_that.bus);case VirtHwChange_AttachVolume() when attachVolume != null:
return attachVolume(_that.path,_that.format,_that.target,_that.bus);case VirtHwChange_RemoveDisk() when removeDisk != null:
return removeDisk(_that.target,_that.deletePath,_that.config,_that.live);case VirtHwChange_AddCdrom() when addCdrom != null:
return addCdrom(_that.target,_that.bus,_that.source);case VirtHwChange_SetMedia() when setMedia != null:
return setMedia(_that.target,_that.source,_that.config,_that.live);case VirtHwChange_AddNic() when addNic != null:
return addNic(_that.kind,_that.source,_that.model,_that.mac);case VirtHwChange_RemoveNic() when removeNic != null:
return removeNic(_that.mac,_that.kind,_that.liveKind);case VirtHwChange_UpdateNic() when updateNic != null:
return updateNic(_that.mac,_that.kind,_that.source,_that.model,_that.linkUp,_that.bootOrder,_that.liveBootOrder,_that.config,_that.live);case VirtHwChange_Boot() when boot != null:
return boot(_that.order);case VirtHwChange_Autostart() when autostart != null:
return autostart(_that.on_);case VirtHwChange_Description() when description != null:
return description(_that.text);case VirtHwChange_Rename() when rename != null:
return rename(_that.name);case VirtHwChange_UpdateDisk() when updateDisk != null:
return updateDisk(_that.target,_that.newTarget,_that.bus,_that.cache);case VirtHwChange_UpdateNicHardware() when updateNicHardware != null:
return updateNicHardware(_that.mac,_that.newMac,_that.model);case VirtHwChange_Firmware() when firmware != null:
return firmware(_that.efi,_that.secureBoot);case VirtHwChange_Display() when display != null:
return display(_that.graphics,_that.listen,_that.video);case VirtHwChange_AddDevice() when addDevice != null:
return addDevice(_that.device);case VirtHwChange_RemoveDevice() when removeDevice != null:
return removeDevice(_that.key);case VirtHwChange_RevertLive() when revertLive != null:
return revertLive(_that.liveXml);case _:
  return null;

}
}

}

/// @nodoc


class VirtHwChange_Cpu extends VirtHwChange {
  const VirtHwChange_Cpu({required this.sockets, required this.cores, this.current}): super._();
  

 final  int sockets;
 final  int cores;
 final  int? current;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_CpuCopyWith<VirtHwChange_Cpu> get copyWith => _$VirtHwChange_CpuCopyWithImpl<VirtHwChange_Cpu>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_Cpu&&(identical(other.sockets, sockets) || other.sockets == sockets)&&(identical(other.cores, cores) || other.cores == cores)&&(identical(other.current, current) || other.current == current));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sockets,cores,current);
}

@override
String toString() {
    return 'VirtHwChange.cpu(sockets: $sockets, cores: $cores, current: $current)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_CpuCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_CpuCopyWith(VirtHwChange_Cpu value, $Res Function(VirtHwChange_Cpu) _then) = _$VirtHwChange_CpuCopyWithImpl;
@useResult
$Res call({
 int sockets, int cores, int? current
});




}
/// @nodoc
class _$VirtHwChange_CpuCopyWithImpl<$Res>
    implements $VirtHwChange_CpuCopyWith<$Res> {
  _$VirtHwChange_CpuCopyWithImpl(this._self, this._then);

  final VirtHwChange_Cpu _self;
  final $Res Function(VirtHwChange_Cpu) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sockets = null,Object? cores = null,Object? current = freezed,}) {
  return _then(VirtHwChange_Cpu(
sockets: null == sockets ? _self.sockets : sockets // ignore: cast_nullable_to_non_nullable
as int,cores: null == cores ? _self.cores : cores // ignore: cast_nullable_to_non_nullable
as int,current: freezed == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc


class VirtHwChange_Memory extends VirtHwChange {
  const VirtHwChange_Memory({required this.memoryMib, this.currentMib}): super._();
  

 final  BigInt memoryMib;
 final  BigInt? currentMib;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_MemoryCopyWith<VirtHwChange_Memory> get copyWith => _$VirtHwChange_MemoryCopyWithImpl<VirtHwChange_Memory>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_Memory&&(identical(other.memoryMib, memoryMib) || other.memoryMib == memoryMib)&&(identical(other.currentMib, currentMib) || other.currentMib == currentMib));
}


@override
int get hashCode {
    return Object.hash(runtimeType,memoryMib,currentMib);
}

@override
String toString() {
    return 'VirtHwChange.memory(memoryMib: $memoryMib, currentMib: $currentMib)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_MemoryCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_MemoryCopyWith(VirtHwChange_Memory value, $Res Function(VirtHwChange_Memory) _then) = _$VirtHwChange_MemoryCopyWithImpl;
@useResult
$Res call({
 BigInt memoryMib, BigInt? currentMib
});




}
/// @nodoc
class _$VirtHwChange_MemoryCopyWithImpl<$Res>
    implements $VirtHwChange_MemoryCopyWith<$Res> {
  _$VirtHwChange_MemoryCopyWithImpl(this._self, this._then);

  final VirtHwChange_Memory _self;
  final $Res Function(VirtHwChange_Memory) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? memoryMib = null,Object? currentMib = freezed,}) {
  return _then(VirtHwChange_Memory(
memoryMib: null == memoryMib ? _self.memoryMib : memoryMib // ignore: cast_nullable_to_non_nullable
as BigInt,currentMib: freezed == currentMib ? _self.currentMib : currentMib // ignore: cast_nullable_to_non_nullable
as BigInt?,
  ));
}


}

/// @nodoc


class VirtHwChange_GrowDisk extends VirtHwChange {
  const VirtHwChange_GrowDisk({required this.target, required this.bytes, this.path, required this.live}): super._();
  

 final  String target;
 final  BigInt bytes;
 final  String? path;
 final  bool live;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_GrowDiskCopyWith<VirtHwChange_GrowDisk> get copyWith => _$VirtHwChange_GrowDiskCopyWithImpl<VirtHwChange_GrowDisk>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_GrowDisk&&(identical(other.target, target) || other.target == target)&&(identical(other.bytes, bytes) || other.bytes == bytes)&&(identical(other.path, path) || other.path == path)&&(identical(other.live, live) || other.live == live));
}


@override
int get hashCode {
    return Object.hash(runtimeType,target,bytes,path,live);
}

@override
String toString() {
    return 'VirtHwChange.growDisk(target: $target, bytes: $bytes, path: $path, live: $live)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_GrowDiskCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_GrowDiskCopyWith(VirtHwChange_GrowDisk value, $Res Function(VirtHwChange_GrowDisk) _then) = _$VirtHwChange_GrowDiskCopyWithImpl;
@useResult
$Res call({
 String target, BigInt bytes, String? path, bool live
});




}
/// @nodoc
class _$VirtHwChange_GrowDiskCopyWithImpl<$Res>
    implements $VirtHwChange_GrowDiskCopyWith<$Res> {
  _$VirtHwChange_GrowDiskCopyWithImpl(this._self, this._then);

  final VirtHwChange_GrowDisk _self;
  final $Res Function(VirtHwChange_GrowDisk) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,Object? bytes = null,Object? path = freezed,Object? live = null,}) {
  return _then(VirtHwChange_GrowDisk(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as BigInt,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,live: null == live ? _self.live : live // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class VirtHwChange_AddDisk extends VirtHwChange {
  const VirtHwChange_AddDisk({required this.pool, required this.volume, required this.gib, required this.format, required this.target, required this.bus}): super._();
  

 final  String pool;
 final  String volume;
 final  BigInt gib;
 final  String format;
 final  String target;
 final  String bus;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_AddDiskCopyWith<VirtHwChange_AddDisk> get copyWith => _$VirtHwChange_AddDiskCopyWithImpl<VirtHwChange_AddDisk>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_AddDisk&&(identical(other.pool, pool) || other.pool == pool)&&(identical(other.volume, volume) || other.volume == volume)&&(identical(other.gib, gib) || other.gib == gib)&&(identical(other.format, format) || other.format == format)&&(identical(other.target, target) || other.target == target)&&(identical(other.bus, bus) || other.bus == bus));
}


@override
int get hashCode {
    return Object.hash(runtimeType,pool,volume,gib,format,target,bus);
}

@override
String toString() {
    return 'VirtHwChange.addDisk(pool: $pool, volume: $volume, gib: $gib, format: $format, target: $target, bus: $bus)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_AddDiskCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_AddDiskCopyWith(VirtHwChange_AddDisk value, $Res Function(VirtHwChange_AddDisk) _then) = _$VirtHwChange_AddDiskCopyWithImpl;
@useResult
$Res call({
 String pool, String volume, BigInt gib, String format, String target, String bus
});




}
/// @nodoc
class _$VirtHwChange_AddDiskCopyWithImpl<$Res>
    implements $VirtHwChange_AddDiskCopyWith<$Res> {
  _$VirtHwChange_AddDiskCopyWithImpl(this._self, this._then);

  final VirtHwChange_AddDisk _self;
  final $Res Function(VirtHwChange_AddDisk) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pool = null,Object? volume = null,Object? gib = null,Object? format = null,Object? target = null,Object? bus = null,}) {
  return _then(VirtHwChange_AddDisk(
pool: null == pool ? _self.pool : pool // ignore: cast_nullable_to_non_nullable
as String,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as String,gib: null == gib ? _self.gib : gib // ignore: cast_nullable_to_non_nullable
as BigInt,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,bus: null == bus ? _self.bus : bus // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class VirtHwChange_AttachVolume extends VirtHwChange {
  const VirtHwChange_AttachVolume({required this.path, required this.format, required this.target, required this.bus}): super._();
  

 final  String path;
 final  String format;
 final  String target;
 final  String bus;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_AttachVolumeCopyWith<VirtHwChange_AttachVolume> get copyWith => _$VirtHwChange_AttachVolumeCopyWithImpl<VirtHwChange_AttachVolume>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_AttachVolume&&(identical(other.path, path) || other.path == path)&&(identical(other.format, format) || other.format == format)&&(identical(other.target, target) || other.target == target)&&(identical(other.bus, bus) || other.bus == bus));
}


@override
int get hashCode {
    return Object.hash(runtimeType,path,format,target,bus);
}

@override
String toString() {
    return 'VirtHwChange.attachVolume(path: $path, format: $format, target: $target, bus: $bus)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_AttachVolumeCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_AttachVolumeCopyWith(VirtHwChange_AttachVolume value, $Res Function(VirtHwChange_AttachVolume) _then) = _$VirtHwChange_AttachVolumeCopyWithImpl;
@useResult
$Res call({
 String path, String format, String target, String bus
});




}
/// @nodoc
class _$VirtHwChange_AttachVolumeCopyWithImpl<$Res>
    implements $VirtHwChange_AttachVolumeCopyWith<$Res> {
  _$VirtHwChange_AttachVolumeCopyWithImpl(this._self, this._then);

  final VirtHwChange_AttachVolume _self;
  final $Res Function(VirtHwChange_AttachVolume) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,Object? format = null,Object? target = null,Object? bus = null,}) {
  return _then(VirtHwChange_AttachVolume(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,bus: null == bus ? _self.bus : bus // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class VirtHwChange_RemoveDisk extends VirtHwChange {
  const VirtHwChange_RemoveDisk({required this.target, this.deletePath, required this.config, required this.live}): super._();
  

 final  String target;
 final  String? deletePath;
 final  bool config;
 final  bool live;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_RemoveDiskCopyWith<VirtHwChange_RemoveDisk> get copyWith => _$VirtHwChange_RemoveDiskCopyWithImpl<VirtHwChange_RemoveDisk>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_RemoveDisk&&(identical(other.target, target) || other.target == target)&&(identical(other.deletePath, deletePath) || other.deletePath == deletePath)&&(identical(other.config, config) || other.config == config)&&(identical(other.live, live) || other.live == live));
}


@override
int get hashCode {
    return Object.hash(runtimeType,target,deletePath,config,live);
}

@override
String toString() {
    return 'VirtHwChange.removeDisk(target: $target, deletePath: $deletePath, config: $config, live: $live)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_RemoveDiskCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_RemoveDiskCopyWith(VirtHwChange_RemoveDisk value, $Res Function(VirtHwChange_RemoveDisk) _then) = _$VirtHwChange_RemoveDiskCopyWithImpl;
@useResult
$Res call({
 String target, String? deletePath, bool config, bool live
});




}
/// @nodoc
class _$VirtHwChange_RemoveDiskCopyWithImpl<$Res>
    implements $VirtHwChange_RemoveDiskCopyWith<$Res> {
  _$VirtHwChange_RemoveDiskCopyWithImpl(this._self, this._then);

  final VirtHwChange_RemoveDisk _self;
  final $Res Function(VirtHwChange_RemoveDisk) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,Object? deletePath = freezed,Object? config = null,Object? live = null,}) {
  return _then(VirtHwChange_RemoveDisk(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,deletePath: freezed == deletePath ? _self.deletePath : deletePath // ignore: cast_nullable_to_non_nullable
as String?,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as bool,live: null == live ? _self.live : live // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class VirtHwChange_AddCdrom extends VirtHwChange {
  const VirtHwChange_AddCdrom({required this.target, required this.bus, this.source}): super._();
  

 final  String target;
 final  String bus;
 final  String? source;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_AddCdromCopyWith<VirtHwChange_AddCdrom> get copyWith => _$VirtHwChange_AddCdromCopyWithImpl<VirtHwChange_AddCdrom>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_AddCdrom&&(identical(other.target, target) || other.target == target)&&(identical(other.bus, bus) || other.bus == bus)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode {
    return Object.hash(runtimeType,target,bus,source);
}

@override
String toString() {
    return 'VirtHwChange.addCdrom(target: $target, bus: $bus, source: $source)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_AddCdromCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_AddCdromCopyWith(VirtHwChange_AddCdrom value, $Res Function(VirtHwChange_AddCdrom) _then) = _$VirtHwChange_AddCdromCopyWithImpl;
@useResult
$Res call({
 String target, String bus, String? source
});




}
/// @nodoc
class _$VirtHwChange_AddCdromCopyWithImpl<$Res>
    implements $VirtHwChange_AddCdromCopyWith<$Res> {
  _$VirtHwChange_AddCdromCopyWithImpl(this._self, this._then);

  final VirtHwChange_AddCdrom _self;
  final $Res Function(VirtHwChange_AddCdrom) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,Object? bus = null,Object? source = freezed,}) {
  return _then(VirtHwChange_AddCdrom(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,bus: null == bus ? _self.bus : bus // ignore: cast_nullable_to_non_nullable
as String,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class VirtHwChange_SetMedia extends VirtHwChange {
  const VirtHwChange_SetMedia({required this.target, this.source, required this.config, required this.live}): super._();
  

 final  String target;
 final  String? source;
 final  bool config;
 final  bool live;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_SetMediaCopyWith<VirtHwChange_SetMedia> get copyWith => _$VirtHwChange_SetMediaCopyWithImpl<VirtHwChange_SetMedia>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_SetMedia&&(identical(other.target, target) || other.target == target)&&(identical(other.source, source) || other.source == source)&&(identical(other.config, config) || other.config == config)&&(identical(other.live, live) || other.live == live));
}


@override
int get hashCode {
    return Object.hash(runtimeType,target,source,config,live);
}

@override
String toString() {
    return 'VirtHwChange.setMedia(target: $target, source: $source, config: $config, live: $live)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_SetMediaCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_SetMediaCopyWith(VirtHwChange_SetMedia value, $Res Function(VirtHwChange_SetMedia) _then) = _$VirtHwChange_SetMediaCopyWithImpl;
@useResult
$Res call({
 String target, String? source, bool config, bool live
});




}
/// @nodoc
class _$VirtHwChange_SetMediaCopyWithImpl<$Res>
    implements $VirtHwChange_SetMediaCopyWith<$Res> {
  _$VirtHwChange_SetMediaCopyWithImpl(this._self, this._then);

  final VirtHwChange_SetMedia _self;
  final $Res Function(VirtHwChange_SetMedia) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,Object? source = freezed,Object? config = null,Object? live = null,}) {
  return _then(VirtHwChange_SetMedia(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as bool,live: null == live ? _self.live : live // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class VirtHwChange_AddNic extends VirtHwChange {
  const VirtHwChange_AddNic({required this.kind, required this.source, required this.model, required this.mac}): super._();
  

 final  String kind;
 final  String source;
 final  String model;
 final  String mac;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_AddNicCopyWith<VirtHwChange_AddNic> get copyWith => _$VirtHwChange_AddNicCopyWithImpl<VirtHwChange_AddNic>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_AddNic&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.source, source) || other.source == source)&&(identical(other.model, model) || other.model == model)&&(identical(other.mac, mac) || other.mac == mac));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind,source,model,mac);
}

@override
String toString() {
    return 'VirtHwChange.addNic(kind: $kind, source: $source, model: $model, mac: $mac)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_AddNicCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_AddNicCopyWith(VirtHwChange_AddNic value, $Res Function(VirtHwChange_AddNic) _then) = _$VirtHwChange_AddNicCopyWithImpl;
@useResult
$Res call({
 String kind, String source, String model, String mac
});




}
/// @nodoc
class _$VirtHwChange_AddNicCopyWithImpl<$Res>
    implements $VirtHwChange_AddNicCopyWith<$Res> {
  _$VirtHwChange_AddNicCopyWithImpl(this._self, this._then);

  final VirtHwChange_AddNic _self;
  final $Res Function(VirtHwChange_AddNic) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? source = null,Object? model = null,Object? mac = null,}) {
  return _then(VirtHwChange_AddNic(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,mac: null == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class VirtHwChange_RemoveNic extends VirtHwChange {
  const VirtHwChange_RemoveNic({required this.mac, this.kind, this.liveKind}): super._();
  

 final  String mac;
 final  String? kind;
 final  String? liveKind;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_RemoveNicCopyWith<VirtHwChange_RemoveNic> get copyWith => _$VirtHwChange_RemoveNicCopyWithImpl<VirtHwChange_RemoveNic>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_RemoveNic&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.liveKind, liveKind) || other.liveKind == liveKind));
}


@override
int get hashCode {
    return Object.hash(runtimeType,mac,kind,liveKind);
}

@override
String toString() {
    return 'VirtHwChange.removeNic(mac: $mac, kind: $kind, liveKind: $liveKind)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_RemoveNicCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_RemoveNicCopyWith(VirtHwChange_RemoveNic value, $Res Function(VirtHwChange_RemoveNic) _then) = _$VirtHwChange_RemoveNicCopyWithImpl;
@useResult
$Res call({
 String mac, String? kind, String? liveKind
});




}
/// @nodoc
class _$VirtHwChange_RemoveNicCopyWithImpl<$Res>
    implements $VirtHwChange_RemoveNicCopyWith<$Res> {
  _$VirtHwChange_RemoveNicCopyWithImpl(this._self, this._then);

  final VirtHwChange_RemoveNic _self;
  final $Res Function(VirtHwChange_RemoveNic) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mac = null,Object? kind = freezed,Object? liveKind = freezed,}) {
  return _then(VirtHwChange_RemoveNic(
mac: null == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,liveKind: freezed == liveKind ? _self.liveKind : liveKind // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class VirtHwChange_UpdateNic extends VirtHwChange {
  const VirtHwChange_UpdateNic({required this.mac, required this.kind, required this.source, this.model, required this.linkUp, this.bootOrder, this.liveBootOrder, required this.config, required this.live}): super._();
  

 final  String mac;
 final  String kind;
 final  String source;
 final  String? model;
 final  bool linkUp;
 final  int? bootOrder;
 final  int? liveBootOrder;
 final  bool config;
 final  bool live;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_UpdateNicCopyWith<VirtHwChange_UpdateNic> get copyWith => _$VirtHwChange_UpdateNicCopyWithImpl<VirtHwChange_UpdateNic>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_UpdateNic&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.source, source) || other.source == source)&&(identical(other.model, model) || other.model == model)&&(identical(other.linkUp, linkUp) || other.linkUp == linkUp)&&(identical(other.bootOrder, bootOrder) || other.bootOrder == bootOrder)&&(identical(other.liveBootOrder, liveBootOrder) || other.liveBootOrder == liveBootOrder)&&(identical(other.config, config) || other.config == config)&&(identical(other.live, live) || other.live == live));
}


@override
int get hashCode {
    return Object.hash(runtimeType,mac,kind,source,model,linkUp,bootOrder,liveBootOrder,config,live);
}

@override
String toString() {
    return 'VirtHwChange.updateNic(mac: $mac, kind: $kind, source: $source, model: $model, linkUp: $linkUp, bootOrder: $bootOrder, liveBootOrder: $liveBootOrder, config: $config, live: $live)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_UpdateNicCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_UpdateNicCopyWith(VirtHwChange_UpdateNic value, $Res Function(VirtHwChange_UpdateNic) _then) = _$VirtHwChange_UpdateNicCopyWithImpl;
@useResult
$Res call({
 String mac, String kind, String source, String? model, bool linkUp, int? bootOrder, int? liveBootOrder, bool config, bool live
});




}
/// @nodoc
class _$VirtHwChange_UpdateNicCopyWithImpl<$Res>
    implements $VirtHwChange_UpdateNicCopyWith<$Res> {
  _$VirtHwChange_UpdateNicCopyWithImpl(this._self, this._then);

  final VirtHwChange_UpdateNic _self;
  final $Res Function(VirtHwChange_UpdateNic) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mac = null,Object? kind = null,Object? source = null,Object? model = freezed,Object? linkUp = null,Object? bootOrder = freezed,Object? liveBootOrder = freezed,Object? config = null,Object? live = null,}) {
  return _then(VirtHwChange_UpdateNic(
mac: null == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,linkUp: null == linkUp ? _self.linkUp : linkUp // ignore: cast_nullable_to_non_nullable
as bool,bootOrder: freezed == bootOrder ? _self.bootOrder : bootOrder // ignore: cast_nullable_to_non_nullable
as int?,liveBootOrder: freezed == liveBootOrder ? _self.liveBootOrder : liveBootOrder // ignore: cast_nullable_to_non_nullable
as int?,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as bool,live: null == live ? _self.live : live // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class VirtHwChange_Boot extends VirtHwChange {
  const VirtHwChange_Boot({required  List<String> order}): _order = order,super._();
  

 final  List<String> _order;
 List<String> get order {
  if (_order is EqualUnmodifiableListView) return _order;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_order);
}


/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_BootCopyWith<VirtHwChange_Boot> get copyWith => _$VirtHwChange_BootCopyWithImpl<VirtHwChange_Boot>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_Boot&&const DeepCollectionEquality().equals(other.order, _order));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_order));
}

@override
String toString() {
    return 'VirtHwChange.boot(order: $order)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_BootCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_BootCopyWith(VirtHwChange_Boot value, $Res Function(VirtHwChange_Boot) _then) = _$VirtHwChange_BootCopyWithImpl;
@useResult
$Res call({
 List<String> order
});




}
/// @nodoc
class _$VirtHwChange_BootCopyWithImpl<$Res>
    implements $VirtHwChange_BootCopyWith<$Res> {
  _$VirtHwChange_BootCopyWithImpl(this._self, this._then);

  final VirtHwChange_Boot _self;
  final $Res Function(VirtHwChange_Boot) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? order = null,}) {
  return _then(VirtHwChange_Boot(
order: null == order ? _self._order : order // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc


class VirtHwChange_Autostart extends VirtHwChange {
  const VirtHwChange_Autostart({required this.on_}): super._();
  

 final  bool on_;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_AutostartCopyWith<VirtHwChange_Autostart> get copyWith => _$VirtHwChange_AutostartCopyWithImpl<VirtHwChange_Autostart>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_Autostart&&(identical(other.on_, on_) || other.on_ == on_));
}


@override
int get hashCode {
    return Object.hash(runtimeType,on_);
}

@override
String toString() {
    return 'VirtHwChange.autostart(on_: $on_)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_AutostartCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_AutostartCopyWith(VirtHwChange_Autostart value, $Res Function(VirtHwChange_Autostart) _then) = _$VirtHwChange_AutostartCopyWithImpl;
@useResult
$Res call({
 bool on_
});




}
/// @nodoc
class _$VirtHwChange_AutostartCopyWithImpl<$Res>
    implements $VirtHwChange_AutostartCopyWith<$Res> {
  _$VirtHwChange_AutostartCopyWithImpl(this._self, this._then);

  final VirtHwChange_Autostart _self;
  final $Res Function(VirtHwChange_Autostart) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? on_ = null,}) {
  return _then(VirtHwChange_Autostart(
on_: null == on_ ? _self.on_ : on_ // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class VirtHwChange_Description extends VirtHwChange {
  const VirtHwChange_Description({required this.text}): super._();
  

 final  String text;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_DescriptionCopyWith<VirtHwChange_Description> get copyWith => _$VirtHwChange_DescriptionCopyWithImpl<VirtHwChange_Description>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_Description&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode {
    return Object.hash(runtimeType,text);
}

@override
String toString() {
    return 'VirtHwChange.description(text: $text)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_DescriptionCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_DescriptionCopyWith(VirtHwChange_Description value, $Res Function(VirtHwChange_Description) _then) = _$VirtHwChange_DescriptionCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$VirtHwChange_DescriptionCopyWithImpl<$Res>
    implements $VirtHwChange_DescriptionCopyWith<$Res> {
  _$VirtHwChange_DescriptionCopyWithImpl(this._self, this._then);

  final VirtHwChange_Description _self;
  final $Res Function(VirtHwChange_Description) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(VirtHwChange_Description(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class VirtHwChange_Rename extends VirtHwChange {
  const VirtHwChange_Rename({required this.name}): super._();
  

 final  String name;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_RenameCopyWith<VirtHwChange_Rename> get copyWith => _$VirtHwChange_RenameCopyWithImpl<VirtHwChange_Rename>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_Rename&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name);
}

@override
String toString() {
    return 'VirtHwChange.rename(name: $name)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_RenameCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_RenameCopyWith(VirtHwChange_Rename value, $Res Function(VirtHwChange_Rename) _then) = _$VirtHwChange_RenameCopyWithImpl;
@useResult
$Res call({
 String name
});




}
/// @nodoc
class _$VirtHwChange_RenameCopyWithImpl<$Res>
    implements $VirtHwChange_RenameCopyWith<$Res> {
  _$VirtHwChange_RenameCopyWithImpl(this._self, this._then);

  final VirtHwChange_Rename _self;
  final $Res Function(VirtHwChange_Rename) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(VirtHwChange_Rename(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class VirtHwChange_UpdateDisk extends VirtHwChange {
  const VirtHwChange_UpdateDisk({required this.target, this.newTarget, this.bus, this.cache}): super._();
  

 final  String target;
 final  String? newTarget;
 final  String? bus;
 final  String? cache;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_UpdateDiskCopyWith<VirtHwChange_UpdateDisk> get copyWith => _$VirtHwChange_UpdateDiskCopyWithImpl<VirtHwChange_UpdateDisk>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_UpdateDisk&&(identical(other.target, target) || other.target == target)&&(identical(other.newTarget, newTarget) || other.newTarget == newTarget)&&(identical(other.bus, bus) || other.bus == bus)&&(identical(other.cache, cache) || other.cache == cache));
}


@override
int get hashCode {
    return Object.hash(runtimeType,target,newTarget,bus,cache);
}

@override
String toString() {
    return 'VirtHwChange.updateDisk(target: $target, newTarget: $newTarget, bus: $bus, cache: $cache)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_UpdateDiskCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_UpdateDiskCopyWith(VirtHwChange_UpdateDisk value, $Res Function(VirtHwChange_UpdateDisk) _then) = _$VirtHwChange_UpdateDiskCopyWithImpl;
@useResult
$Res call({
 String target, String? newTarget, String? bus, String? cache
});




}
/// @nodoc
class _$VirtHwChange_UpdateDiskCopyWithImpl<$Res>
    implements $VirtHwChange_UpdateDiskCopyWith<$Res> {
  _$VirtHwChange_UpdateDiskCopyWithImpl(this._self, this._then);

  final VirtHwChange_UpdateDisk _self;
  final $Res Function(VirtHwChange_UpdateDisk) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,Object? newTarget = freezed,Object? bus = freezed,Object? cache = freezed,}) {
  return _then(VirtHwChange_UpdateDisk(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,newTarget: freezed == newTarget ? _self.newTarget : newTarget // ignore: cast_nullable_to_non_nullable
as String?,bus: freezed == bus ? _self.bus : bus // ignore: cast_nullable_to_non_nullable
as String?,cache: freezed == cache ? _self.cache : cache // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class VirtHwChange_UpdateNicHardware extends VirtHwChange {
  const VirtHwChange_UpdateNicHardware({required this.mac, this.newMac, this.model}): super._();
  

 final  String mac;
 final  String? newMac;
 final  String? model;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_UpdateNicHardwareCopyWith<VirtHwChange_UpdateNicHardware> get copyWith => _$VirtHwChange_UpdateNicHardwareCopyWithImpl<VirtHwChange_UpdateNicHardware>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_UpdateNicHardware&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.newMac, newMac) || other.newMac == newMac)&&(identical(other.model, model) || other.model == model));
}


@override
int get hashCode {
    return Object.hash(runtimeType,mac,newMac,model);
}

@override
String toString() {
    return 'VirtHwChange.updateNicHardware(mac: $mac, newMac: $newMac, model: $model)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_UpdateNicHardwareCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_UpdateNicHardwareCopyWith(VirtHwChange_UpdateNicHardware value, $Res Function(VirtHwChange_UpdateNicHardware) _then) = _$VirtHwChange_UpdateNicHardwareCopyWithImpl;
@useResult
$Res call({
 String mac, String? newMac, String? model
});




}
/// @nodoc
class _$VirtHwChange_UpdateNicHardwareCopyWithImpl<$Res>
    implements $VirtHwChange_UpdateNicHardwareCopyWith<$Res> {
  _$VirtHwChange_UpdateNicHardwareCopyWithImpl(this._self, this._then);

  final VirtHwChange_UpdateNicHardware _self;
  final $Res Function(VirtHwChange_UpdateNicHardware) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mac = null,Object? newMac = freezed,Object? model = freezed,}) {
  return _then(VirtHwChange_UpdateNicHardware(
mac: null == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String,newMac: freezed == newMac ? _self.newMac : newMac // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class VirtHwChange_Firmware extends VirtHwChange {
  const VirtHwChange_Firmware({required this.efi, required this.secureBoot}): super._();
  

 final  bool efi;
 final  bool secureBoot;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_FirmwareCopyWith<VirtHwChange_Firmware> get copyWith => _$VirtHwChange_FirmwareCopyWithImpl<VirtHwChange_Firmware>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_Firmware&&(identical(other.efi, efi) || other.efi == efi)&&(identical(other.secureBoot, secureBoot) || other.secureBoot == secureBoot));
}


@override
int get hashCode {
    return Object.hash(runtimeType,efi,secureBoot);
}

@override
String toString() {
    return 'VirtHwChange.firmware(efi: $efi, secureBoot: $secureBoot)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_FirmwareCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_FirmwareCopyWith(VirtHwChange_Firmware value, $Res Function(VirtHwChange_Firmware) _then) = _$VirtHwChange_FirmwareCopyWithImpl;
@useResult
$Res call({
 bool efi, bool secureBoot
});




}
/// @nodoc
class _$VirtHwChange_FirmwareCopyWithImpl<$Res>
    implements $VirtHwChange_FirmwareCopyWith<$Res> {
  _$VirtHwChange_FirmwareCopyWithImpl(this._self, this._then);

  final VirtHwChange_Firmware _self;
  final $Res Function(VirtHwChange_Firmware) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? efi = null,Object? secureBoot = null,}) {
  return _then(VirtHwChange_Firmware(
efi: null == efi ? _self.efi : efi // ignore: cast_nullable_to_non_nullable
as bool,secureBoot: null == secureBoot ? _self.secureBoot : secureBoot // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class VirtHwChange_Display extends VirtHwChange {
  const VirtHwChange_Display({this.graphics, this.listen, this.video}): super._();
  

 final  String? graphics;
 final  String? listen;
 final  String? video;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_DisplayCopyWith<VirtHwChange_Display> get copyWith => _$VirtHwChange_DisplayCopyWithImpl<VirtHwChange_Display>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_Display&&(identical(other.graphics, graphics) || other.graphics == graphics)&&(identical(other.listen, listen) || other.listen == listen)&&(identical(other.video, video) || other.video == video));
}


@override
int get hashCode {
    return Object.hash(runtimeType,graphics,listen,video);
}

@override
String toString() {
    return 'VirtHwChange.display(graphics: $graphics, listen: $listen, video: $video)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_DisplayCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_DisplayCopyWith(VirtHwChange_Display value, $Res Function(VirtHwChange_Display) _then) = _$VirtHwChange_DisplayCopyWithImpl;
@useResult
$Res call({
 String? graphics, String? listen, String? video
});




}
/// @nodoc
class _$VirtHwChange_DisplayCopyWithImpl<$Res>
    implements $VirtHwChange_DisplayCopyWith<$Res> {
  _$VirtHwChange_DisplayCopyWithImpl(this._self, this._then);

  final VirtHwChange_Display _self;
  final $Res Function(VirtHwChange_Display) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? graphics = freezed,Object? listen = freezed,Object? video = freezed,}) {
  return _then(VirtHwChange_Display(
graphics: freezed == graphics ? _self.graphics : graphics // ignore: cast_nullable_to_non_nullable
as String?,listen: freezed == listen ? _self.listen : listen // ignore: cast_nullable_to_non_nullable
as String?,video: freezed == video ? _self.video : video // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class VirtHwChange_AddDevice extends VirtHwChange {
  const VirtHwChange_AddDevice({required this.device}): super._();
  

 final  VirtHwNewDevice device;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_AddDeviceCopyWith<VirtHwChange_AddDevice> get copyWith => _$VirtHwChange_AddDeviceCopyWithImpl<VirtHwChange_AddDevice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_AddDevice&&(identical(other.device, device) || other.device == device));
}


@override
int get hashCode {
    return Object.hash(runtimeType,device);
}

@override
String toString() {
    return 'VirtHwChange.addDevice(device: $device)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_AddDeviceCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_AddDeviceCopyWith(VirtHwChange_AddDevice value, $Res Function(VirtHwChange_AddDevice) _then) = _$VirtHwChange_AddDeviceCopyWithImpl;
@useResult
$Res call({
 VirtHwNewDevice device
});


$VirtHwNewDeviceCopyWith<$Res> get device;

}
/// @nodoc
class _$VirtHwChange_AddDeviceCopyWithImpl<$Res>
    implements $VirtHwChange_AddDeviceCopyWith<$Res> {
  _$VirtHwChange_AddDeviceCopyWithImpl(this._self, this._then);

  final VirtHwChange_AddDevice _self;
  final $Res Function(VirtHwChange_AddDevice) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? device = null,}) {
  return _then(VirtHwChange_AddDevice(
device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as VirtHwNewDevice,
  ));
}

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtHwNewDeviceCopyWith<$Res> get device {
  
  return $VirtHwNewDeviceCopyWith<$Res>(_self.device, (value) {
    return _then(_self.copyWith(device: value));
  });
}
}

/// @nodoc


class VirtHwChange_RemoveDevice extends VirtHwChange {
  const VirtHwChange_RemoveDevice({required this.key}): super._();
  

 final  String key;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_RemoveDeviceCopyWith<VirtHwChange_RemoveDevice> get copyWith => _$VirtHwChange_RemoveDeviceCopyWithImpl<VirtHwChange_RemoveDevice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_RemoveDevice&&(identical(other.key, key) || other.key == key));
}


@override
int get hashCode {
    return Object.hash(runtimeType,key);
}

@override
String toString() {
    return 'VirtHwChange.removeDevice(key: $key)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_RemoveDeviceCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_RemoveDeviceCopyWith(VirtHwChange_RemoveDevice value, $Res Function(VirtHwChange_RemoveDevice) _then) = _$VirtHwChange_RemoveDeviceCopyWithImpl;
@useResult
$Res call({
 String key
});




}
/// @nodoc
class _$VirtHwChange_RemoveDeviceCopyWithImpl<$Res>
    implements $VirtHwChange_RemoveDeviceCopyWith<$Res> {
  _$VirtHwChange_RemoveDeviceCopyWithImpl(this._self, this._then);

  final VirtHwChange_RemoveDevice _self;
  final $Res Function(VirtHwChange_RemoveDevice) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? key = null,}) {
  return _then(VirtHwChange_RemoveDevice(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class VirtHwChange_RevertLive extends VirtHwChange {
  const VirtHwChange_RevertLive({required this.liveXml}): super._();
  

 final  String liveXml;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwChange_RevertLiveCopyWith<VirtHwChange_RevertLive> get copyWith => _$VirtHwChange_RevertLiveCopyWithImpl<VirtHwChange_RevertLive>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwChange_RevertLive&&(identical(other.liveXml, liveXml) || other.liveXml == liveXml));
}


@override
int get hashCode {
    return Object.hash(runtimeType,liveXml);
}

@override
String toString() {
    return 'VirtHwChange.revertLive(liveXml: $liveXml)';
}


}

/// @nodoc
abstract mixin class $VirtHwChange_RevertLiveCopyWith<$Res> implements $VirtHwChangeCopyWith<$Res> {
  factory $VirtHwChange_RevertLiveCopyWith(VirtHwChange_RevertLive value, $Res Function(VirtHwChange_RevertLive) _then) = _$VirtHwChange_RevertLiveCopyWithImpl;
@useResult
$Res call({
 String liveXml
});




}
/// @nodoc
class _$VirtHwChange_RevertLiveCopyWithImpl<$Res>
    implements $VirtHwChange_RevertLiveCopyWith<$Res> {
  _$VirtHwChange_RevertLiveCopyWithImpl(this._self, this._then);

  final VirtHwChange_RevertLive _self;
  final $Res Function(VirtHwChange_RevertLive) _then;

/// Create a copy of VirtHwChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? liveXml = null,}) {
  return _then(VirtHwChange_RevertLive(
liveXml: null == liveXml ? _self.liveXml : liveXml // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$VirtHwNewDevice {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwNewDevice);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'VirtHwNewDevice()';
}


}

/// @nodoc
class $VirtHwNewDeviceCopyWith<$Res>  {
$VirtHwNewDeviceCopyWith(VirtHwNewDevice _, $Res Function(VirtHwNewDevice) __);
}


/// Adds pattern-matching-related methods to [VirtHwNewDevice].
extension VirtHwNewDevicePatterns on VirtHwNewDevice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( VirtHwNewDevice_Tpm value)?  tpm,TResult Function( VirtHwNewDevice_Usb value)?  usb,TResult Function( VirtHwNewDevice_Pci value)?  pci,required TResult orElse(),}){
final _that = this;
switch (_that) {
case VirtHwNewDevice_Tpm() when tpm != null:
return tpm(_that);case VirtHwNewDevice_Usb() when usb != null:
return usb(_that);case VirtHwNewDevice_Pci() when pci != null:
return pci(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( VirtHwNewDevice_Tpm value)  tpm,required TResult Function( VirtHwNewDevice_Usb value)  usb,required TResult Function( VirtHwNewDevice_Pci value)  pci,}){
final _that = this;
switch (_that) {
case VirtHwNewDevice_Tpm():
return tpm(_that);case VirtHwNewDevice_Usb():
return usb(_that);case VirtHwNewDevice_Pci():
return pci(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( VirtHwNewDevice_Tpm value)?  tpm,TResult? Function( VirtHwNewDevice_Usb value)?  usb,TResult? Function( VirtHwNewDevice_Pci value)?  pci,}){
final _that = this;
switch (_that) {
case VirtHwNewDevice_Tpm() when tpm != null:
return tpm(_that);case VirtHwNewDevice_Usb() when usb != null:
return usb(_that);case VirtHwNewDevice_Pci() when pci != null:
return pci(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String model)?  tpm,TResult Function( String? vendor,  String? product,  int? bus,  int? device)?  usb,TResult Function( String address)?  pci,required TResult orElse(),}) {final _that = this;
switch (_that) {
case VirtHwNewDevice_Tpm() when tpm != null:
return tpm(_that.model);case VirtHwNewDevice_Usb() when usb != null:
return usb(_that.vendor,_that.product,_that.bus,_that.device);case VirtHwNewDevice_Pci() when pci != null:
return pci(_that.address);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String model)  tpm,required TResult Function( String? vendor,  String? product,  int? bus,  int? device)  usb,required TResult Function( String address)  pci,}) {final _that = this;
switch (_that) {
case VirtHwNewDevice_Tpm():
return tpm(_that.model);case VirtHwNewDevice_Usb():
return usb(_that.vendor,_that.product,_that.bus,_that.device);case VirtHwNewDevice_Pci():
return pci(_that.address);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String model)?  tpm,TResult? Function( String? vendor,  String? product,  int? bus,  int? device)?  usb,TResult? Function( String address)?  pci,}) {final _that = this;
switch (_that) {
case VirtHwNewDevice_Tpm() when tpm != null:
return tpm(_that.model);case VirtHwNewDevice_Usb() when usb != null:
return usb(_that.vendor,_that.product,_that.bus,_that.device);case VirtHwNewDevice_Pci() when pci != null:
return pci(_that.address);case _:
  return null;

}
}

}

/// @nodoc


class VirtHwNewDevice_Tpm extends VirtHwNewDevice {
  const VirtHwNewDevice_Tpm({required this.model}): super._();
  

 final  String model;

/// Create a copy of VirtHwNewDevice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwNewDevice_TpmCopyWith<VirtHwNewDevice_Tpm> get copyWith => _$VirtHwNewDevice_TpmCopyWithImpl<VirtHwNewDevice_Tpm>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwNewDevice_Tpm&&(identical(other.model, model) || other.model == model));
}


@override
int get hashCode {
    return Object.hash(runtimeType,model);
}

@override
String toString() {
    return 'VirtHwNewDevice.tpm(model: $model)';
}


}

/// @nodoc
abstract mixin class $VirtHwNewDevice_TpmCopyWith<$Res> implements $VirtHwNewDeviceCopyWith<$Res> {
  factory $VirtHwNewDevice_TpmCopyWith(VirtHwNewDevice_Tpm value, $Res Function(VirtHwNewDevice_Tpm) _then) = _$VirtHwNewDevice_TpmCopyWithImpl;
@useResult
$Res call({
 String model
});




}
/// @nodoc
class _$VirtHwNewDevice_TpmCopyWithImpl<$Res>
    implements $VirtHwNewDevice_TpmCopyWith<$Res> {
  _$VirtHwNewDevice_TpmCopyWithImpl(this._self, this._then);

  final VirtHwNewDevice_Tpm _self;
  final $Res Function(VirtHwNewDevice_Tpm) _then;

/// Create a copy of VirtHwNewDevice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? model = null,}) {
  return _then(VirtHwNewDevice_Tpm(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class VirtHwNewDevice_Usb extends VirtHwNewDevice {
  const VirtHwNewDevice_Usb({this.vendor, this.product, this.bus, this.device}): super._();
  

 final  String? vendor;
 final  String? product;
 final  int? bus;
 final  int? device;

/// Create a copy of VirtHwNewDevice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwNewDevice_UsbCopyWith<VirtHwNewDevice_Usb> get copyWith => _$VirtHwNewDevice_UsbCopyWithImpl<VirtHwNewDevice_Usb>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwNewDevice_Usb&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.product, product) || other.product == product)&&(identical(other.bus, bus) || other.bus == bus)&&(identical(other.device, device) || other.device == device));
}


@override
int get hashCode {
    return Object.hash(runtimeType,vendor,product,bus,device);
}

@override
String toString() {
    return 'VirtHwNewDevice.usb(vendor: $vendor, product: $product, bus: $bus, device: $device)';
}


}

/// @nodoc
abstract mixin class $VirtHwNewDevice_UsbCopyWith<$Res> implements $VirtHwNewDeviceCopyWith<$Res> {
  factory $VirtHwNewDevice_UsbCopyWith(VirtHwNewDevice_Usb value, $Res Function(VirtHwNewDevice_Usb) _then) = _$VirtHwNewDevice_UsbCopyWithImpl;
@useResult
$Res call({
 String? vendor, String? product, int? bus, int? device
});




}
/// @nodoc
class _$VirtHwNewDevice_UsbCopyWithImpl<$Res>
    implements $VirtHwNewDevice_UsbCopyWith<$Res> {
  _$VirtHwNewDevice_UsbCopyWithImpl(this._self, this._then);

  final VirtHwNewDevice_Usb _self;
  final $Res Function(VirtHwNewDevice_Usb) _then;

/// Create a copy of VirtHwNewDevice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? vendor = freezed,Object? product = freezed,Object? bus = freezed,Object? device = freezed,}) {
  return _then(VirtHwNewDevice_Usb(
vendor: freezed == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String?,product: freezed == product ? _self.product : product // ignore: cast_nullable_to_non_nullable
as String?,bus: freezed == bus ? _self.bus : bus // ignore: cast_nullable_to_non_nullable
as int?,device: freezed == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc


class VirtHwNewDevice_Pci extends VirtHwNewDevice {
  const VirtHwNewDevice_Pci({required this.address}): super._();
  

 final  String address;

/// Create a copy of VirtHwNewDevice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHwNewDevice_PciCopyWith<VirtHwNewDevice_Pci> get copyWith => _$VirtHwNewDevice_PciCopyWithImpl<VirtHwNewDevice_Pci>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHwNewDevice_Pci&&(identical(other.address, address) || other.address == address));
}


@override
int get hashCode {
    return Object.hash(runtimeType,address);
}

@override
String toString() {
    return 'VirtHwNewDevice.pci(address: $address)';
}


}

/// @nodoc
abstract mixin class $VirtHwNewDevice_PciCopyWith<$Res> implements $VirtHwNewDeviceCopyWith<$Res> {
  factory $VirtHwNewDevice_PciCopyWith(VirtHwNewDevice_Pci value, $Res Function(VirtHwNewDevice_Pci) _then) = _$VirtHwNewDevice_PciCopyWithImpl;
@useResult
$Res call({
 String address
});




}
/// @nodoc
class _$VirtHwNewDevice_PciCopyWithImpl<$Res>
    implements $VirtHwNewDevice_PciCopyWith<$Res> {
  _$VirtHwNewDevice_PciCopyWithImpl(this._self, this._then);

  final VirtHwNewDevice_Pci _self;
  final $Res Function(VirtHwNewDevice_Pci) _then;

/// Create a copy of VirtHwNewDevice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? address = null,}) {
  return _then(VirtHwNewDevice_Pci(
address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$VirtResourceOp {

 String get name;
/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtResourceOpCopyWith<VirtResourceOp> get copyWith => _$VirtResourceOpCopyWithImpl<VirtResourceOp>(this as VirtResourceOp, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VirtResourceOp;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtResourceOp&&(identical(other.name, _this.name) || other.name == _this.name));
}


@override
int get hashCode {
  final _this = this as VirtResourceOp;
  return Object.hash(runtimeType,_this.name);
}

@override
String toString() {
  final _this = this as VirtResourceOp;
  return 'VirtResourceOp(name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $VirtResourceOpCopyWith<$Res>  {
  factory $VirtResourceOpCopyWith(VirtResourceOp value, $Res Function(VirtResourceOp) _then) = _$VirtResourceOpCopyWithImpl;
@useResult
$Res call({
 String name
});




}
/// @nodoc
class _$VirtResourceOpCopyWithImpl<$Res>
    implements $VirtResourceOpCopyWith<$Res> {
  _$VirtResourceOpCopyWithImpl(this._self, this._then);

  final VirtResourceOp _self;
  final $Res Function(VirtResourceOp) _then;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtResourceOp].
extension VirtResourceOpPatterns on VirtResourceOp {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( VirtResourceOp_PoolCreate value)?  poolCreate,TResult Function( VirtResourceOp_PoolStart value)?  poolStart,TResult Function( VirtResourceOp_PoolStop value)?  poolStop,TResult Function( VirtResourceOp_PoolAutostart value)?  poolAutostart,TResult Function( VirtResourceOp_PoolRefresh value)?  poolRefresh,TResult Function( VirtResourceOp_PoolDelete value)?  poolDelete,TResult Function( VirtResourceOp_VolCreate value)?  volCreate,TResult Function( VirtResourceOp_VolDelete value)?  volDelete,TResult Function( VirtResourceOp_VolResize value)?  volResize,TResult Function( VirtResourceOp_VolClone value)?  volClone,TResult Function( VirtResourceOp_NetCreate value)?  netCreate,TResult Function( VirtResourceOp_NetStart value)?  netStart,TResult Function( VirtResourceOp_NetStop value)?  netStop,TResult Function( VirtResourceOp_NetAutostart value)?  netAutostart,TResult Function( VirtResourceOp_NetDelete value)?  netDelete,required TResult orElse(),}){
final _that = this;
switch (_that) {
case VirtResourceOp_PoolCreate() when poolCreate != null:
return poolCreate(_that);case VirtResourceOp_PoolStart() when poolStart != null:
return poolStart(_that);case VirtResourceOp_PoolStop() when poolStop != null:
return poolStop(_that);case VirtResourceOp_PoolAutostart() when poolAutostart != null:
return poolAutostart(_that);case VirtResourceOp_PoolRefresh() when poolRefresh != null:
return poolRefresh(_that);case VirtResourceOp_PoolDelete() when poolDelete != null:
return poolDelete(_that);case VirtResourceOp_VolCreate() when volCreate != null:
return volCreate(_that);case VirtResourceOp_VolDelete() when volDelete != null:
return volDelete(_that);case VirtResourceOp_VolResize() when volResize != null:
return volResize(_that);case VirtResourceOp_VolClone() when volClone != null:
return volClone(_that);case VirtResourceOp_NetCreate() when netCreate != null:
return netCreate(_that);case VirtResourceOp_NetStart() when netStart != null:
return netStart(_that);case VirtResourceOp_NetStop() when netStop != null:
return netStop(_that);case VirtResourceOp_NetAutostart() when netAutostart != null:
return netAutostart(_that);case VirtResourceOp_NetDelete() when netDelete != null:
return netDelete(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( VirtResourceOp_PoolCreate value)  poolCreate,required TResult Function( VirtResourceOp_PoolStart value)  poolStart,required TResult Function( VirtResourceOp_PoolStop value)  poolStop,required TResult Function( VirtResourceOp_PoolAutostart value)  poolAutostart,required TResult Function( VirtResourceOp_PoolRefresh value)  poolRefresh,required TResult Function( VirtResourceOp_PoolDelete value)  poolDelete,required TResult Function( VirtResourceOp_VolCreate value)  volCreate,required TResult Function( VirtResourceOp_VolDelete value)  volDelete,required TResult Function( VirtResourceOp_VolResize value)  volResize,required TResult Function( VirtResourceOp_VolClone value)  volClone,required TResult Function( VirtResourceOp_NetCreate value)  netCreate,required TResult Function( VirtResourceOp_NetStart value)  netStart,required TResult Function( VirtResourceOp_NetStop value)  netStop,required TResult Function( VirtResourceOp_NetAutostart value)  netAutostart,required TResult Function( VirtResourceOp_NetDelete value)  netDelete,}){
final _that = this;
switch (_that) {
case VirtResourceOp_PoolCreate():
return poolCreate(_that);case VirtResourceOp_PoolStart():
return poolStart(_that);case VirtResourceOp_PoolStop():
return poolStop(_that);case VirtResourceOp_PoolAutostart():
return poolAutostart(_that);case VirtResourceOp_PoolRefresh():
return poolRefresh(_that);case VirtResourceOp_PoolDelete():
return poolDelete(_that);case VirtResourceOp_VolCreate():
return volCreate(_that);case VirtResourceOp_VolDelete():
return volDelete(_that);case VirtResourceOp_VolResize():
return volResize(_that);case VirtResourceOp_VolClone():
return volClone(_that);case VirtResourceOp_NetCreate():
return netCreate(_that);case VirtResourceOp_NetStart():
return netStart(_that);case VirtResourceOp_NetStop():
return netStop(_that);case VirtResourceOp_NetAutostart():
return netAutostart(_that);case VirtResourceOp_NetDelete():
return netDelete(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( VirtResourceOp_PoolCreate value)?  poolCreate,TResult? Function( VirtResourceOp_PoolStart value)?  poolStart,TResult? Function( VirtResourceOp_PoolStop value)?  poolStop,TResult? Function( VirtResourceOp_PoolAutostart value)?  poolAutostart,TResult? Function( VirtResourceOp_PoolRefresh value)?  poolRefresh,TResult? Function( VirtResourceOp_PoolDelete value)?  poolDelete,TResult? Function( VirtResourceOp_VolCreate value)?  volCreate,TResult? Function( VirtResourceOp_VolDelete value)?  volDelete,TResult? Function( VirtResourceOp_VolResize value)?  volResize,TResult? Function( VirtResourceOp_VolClone value)?  volClone,TResult? Function( VirtResourceOp_NetCreate value)?  netCreate,TResult? Function( VirtResourceOp_NetStart value)?  netStart,TResult? Function( VirtResourceOp_NetStop value)?  netStop,TResult? Function( VirtResourceOp_NetAutostart value)?  netAutostart,TResult? Function( VirtResourceOp_NetDelete value)?  netDelete,}){
final _that = this;
switch (_that) {
case VirtResourceOp_PoolCreate() when poolCreate != null:
return poolCreate(_that);case VirtResourceOp_PoolStart() when poolStart != null:
return poolStart(_that);case VirtResourceOp_PoolStop() when poolStop != null:
return poolStop(_that);case VirtResourceOp_PoolAutostart() when poolAutostart != null:
return poolAutostart(_that);case VirtResourceOp_PoolRefresh() when poolRefresh != null:
return poolRefresh(_that);case VirtResourceOp_PoolDelete() when poolDelete != null:
return poolDelete(_that);case VirtResourceOp_VolCreate() when volCreate != null:
return volCreate(_that);case VirtResourceOp_VolDelete() when volDelete != null:
return volDelete(_that);case VirtResourceOp_VolResize() when volResize != null:
return volResize(_that);case VirtResourceOp_VolClone() when volClone != null:
return volClone(_that);case VirtResourceOp_NetCreate() when netCreate != null:
return netCreate(_that);case VirtResourceOp_NetStart() when netStart != null:
return netStart(_that);case VirtResourceOp_NetStop() when netStop != null:
return netStop(_that);case VirtResourceOp_NetAutostart() when netAutostart != null:
return netAutostart(_that);case VirtResourceOp_NetDelete() when netDelete != null:
return netDelete(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String name,  String poolType,  String? target,  String? source,  bool autostart)?  poolCreate,TResult Function( String name)?  poolStart,TResult Function( String name)?  poolStop,TResult Function( String name,  bool on_)?  poolAutostart,TResult Function( String name)?  poolRefresh,TResult Function( String name,  bool active,  bool deleteStorage)?  poolDelete,TResult Function( String pool,  String name,  BigInt bytes,  String format)?  volCreate,TResult Function( String pool,  String name)?  volDelete,TResult Function( String pool,  String name,  BigInt bytes)?  volResize,TResult Function( String pool,  String name,  String newName)?  volClone,TResult Function( String name,  String mode,  String? bridge,  VirtNetIpv4? ipv4,  bool autostart)?  netCreate,TResult Function( String name)?  netStart,TResult Function( String name)?  netStop,TResult Function( String name,  bool on_)?  netAutostart,TResult Function( String name)?  netDelete,required TResult orElse(),}) {final _that = this;
switch (_that) {
case VirtResourceOp_PoolCreate() when poolCreate != null:
return poolCreate(_that.name,_that.poolType,_that.target,_that.source,_that.autostart);case VirtResourceOp_PoolStart() when poolStart != null:
return poolStart(_that.name);case VirtResourceOp_PoolStop() when poolStop != null:
return poolStop(_that.name);case VirtResourceOp_PoolAutostart() when poolAutostart != null:
return poolAutostart(_that.name,_that.on_);case VirtResourceOp_PoolRefresh() when poolRefresh != null:
return poolRefresh(_that.name);case VirtResourceOp_PoolDelete() when poolDelete != null:
return poolDelete(_that.name,_that.active,_that.deleteStorage);case VirtResourceOp_VolCreate() when volCreate != null:
return volCreate(_that.pool,_that.name,_that.bytes,_that.format);case VirtResourceOp_VolDelete() when volDelete != null:
return volDelete(_that.pool,_that.name);case VirtResourceOp_VolResize() when volResize != null:
return volResize(_that.pool,_that.name,_that.bytes);case VirtResourceOp_VolClone() when volClone != null:
return volClone(_that.pool,_that.name,_that.newName);case VirtResourceOp_NetCreate() when netCreate != null:
return netCreate(_that.name,_that.mode,_that.bridge,_that.ipv4,_that.autostart);case VirtResourceOp_NetStart() when netStart != null:
return netStart(_that.name);case VirtResourceOp_NetStop() when netStop != null:
return netStop(_that.name);case VirtResourceOp_NetAutostart() when netAutostart != null:
return netAutostart(_that.name,_that.on_);case VirtResourceOp_NetDelete() when netDelete != null:
return netDelete(_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String name,  String poolType,  String? target,  String? source,  bool autostart)  poolCreate,required TResult Function( String name)  poolStart,required TResult Function( String name)  poolStop,required TResult Function( String name,  bool on_)  poolAutostart,required TResult Function( String name)  poolRefresh,required TResult Function( String name,  bool active,  bool deleteStorage)  poolDelete,required TResult Function( String pool,  String name,  BigInt bytes,  String format)  volCreate,required TResult Function( String pool,  String name)  volDelete,required TResult Function( String pool,  String name,  BigInt bytes)  volResize,required TResult Function( String pool,  String name,  String newName)  volClone,required TResult Function( String name,  String mode,  String? bridge,  VirtNetIpv4? ipv4,  bool autostart)  netCreate,required TResult Function( String name)  netStart,required TResult Function( String name)  netStop,required TResult Function( String name,  bool on_)  netAutostart,required TResult Function( String name)  netDelete,}) {final _that = this;
switch (_that) {
case VirtResourceOp_PoolCreate():
return poolCreate(_that.name,_that.poolType,_that.target,_that.source,_that.autostart);case VirtResourceOp_PoolStart():
return poolStart(_that.name);case VirtResourceOp_PoolStop():
return poolStop(_that.name);case VirtResourceOp_PoolAutostart():
return poolAutostart(_that.name,_that.on_);case VirtResourceOp_PoolRefresh():
return poolRefresh(_that.name);case VirtResourceOp_PoolDelete():
return poolDelete(_that.name,_that.active,_that.deleteStorage);case VirtResourceOp_VolCreate():
return volCreate(_that.pool,_that.name,_that.bytes,_that.format);case VirtResourceOp_VolDelete():
return volDelete(_that.pool,_that.name);case VirtResourceOp_VolResize():
return volResize(_that.pool,_that.name,_that.bytes);case VirtResourceOp_VolClone():
return volClone(_that.pool,_that.name,_that.newName);case VirtResourceOp_NetCreate():
return netCreate(_that.name,_that.mode,_that.bridge,_that.ipv4,_that.autostart);case VirtResourceOp_NetStart():
return netStart(_that.name);case VirtResourceOp_NetStop():
return netStop(_that.name);case VirtResourceOp_NetAutostart():
return netAutostart(_that.name,_that.on_);case VirtResourceOp_NetDelete():
return netDelete(_that.name);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String name,  String poolType,  String? target,  String? source,  bool autostart)?  poolCreate,TResult? Function( String name)?  poolStart,TResult? Function( String name)?  poolStop,TResult? Function( String name,  bool on_)?  poolAutostart,TResult? Function( String name)?  poolRefresh,TResult? Function( String name,  bool active,  bool deleteStorage)?  poolDelete,TResult? Function( String pool,  String name,  BigInt bytes,  String format)?  volCreate,TResult? Function( String pool,  String name)?  volDelete,TResult? Function( String pool,  String name,  BigInt bytes)?  volResize,TResult? Function( String pool,  String name,  String newName)?  volClone,TResult? Function( String name,  String mode,  String? bridge,  VirtNetIpv4? ipv4,  bool autostart)?  netCreate,TResult? Function( String name)?  netStart,TResult? Function( String name)?  netStop,TResult? Function( String name,  bool on_)?  netAutostart,TResult? Function( String name)?  netDelete,}) {final _that = this;
switch (_that) {
case VirtResourceOp_PoolCreate() when poolCreate != null:
return poolCreate(_that.name,_that.poolType,_that.target,_that.source,_that.autostart);case VirtResourceOp_PoolStart() when poolStart != null:
return poolStart(_that.name);case VirtResourceOp_PoolStop() when poolStop != null:
return poolStop(_that.name);case VirtResourceOp_PoolAutostart() when poolAutostart != null:
return poolAutostart(_that.name,_that.on_);case VirtResourceOp_PoolRefresh() when poolRefresh != null:
return poolRefresh(_that.name);case VirtResourceOp_PoolDelete() when poolDelete != null:
return poolDelete(_that.name,_that.active,_that.deleteStorage);case VirtResourceOp_VolCreate() when volCreate != null:
return volCreate(_that.pool,_that.name,_that.bytes,_that.format);case VirtResourceOp_VolDelete() when volDelete != null:
return volDelete(_that.pool,_that.name);case VirtResourceOp_VolResize() when volResize != null:
return volResize(_that.pool,_that.name,_that.bytes);case VirtResourceOp_VolClone() when volClone != null:
return volClone(_that.pool,_that.name,_that.newName);case VirtResourceOp_NetCreate() when netCreate != null:
return netCreate(_that.name,_that.mode,_that.bridge,_that.ipv4,_that.autostart);case VirtResourceOp_NetStart() when netStart != null:
return netStart(_that.name);case VirtResourceOp_NetStop() when netStop != null:
return netStop(_that.name);case VirtResourceOp_NetAutostart() when netAutostart != null:
return netAutostart(_that.name,_that.on_);case VirtResourceOp_NetDelete() when netDelete != null:
return netDelete(_that.name);case _:
  return null;

}
}

}

/// @nodoc


class VirtResourceOp_PoolCreate extends VirtResourceOp {
  const VirtResourceOp_PoolCreate({required this.name, required this.poolType, this.target, this.source, required this.autostart}): super._();
  

@override final  String name;
 final  String poolType;
 final  String? target;
 final  String? source;
 final  bool autostart;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtResourceOp_PoolCreateCopyWith<VirtResourceOp_PoolCreate> get copyWith => _$VirtResourceOp_PoolCreateCopyWithImpl<VirtResourceOp_PoolCreate>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtResourceOp_PoolCreate&&(identical(other.name, name) || other.name == name)&&(identical(other.poolType, poolType) || other.poolType == poolType)&&(identical(other.target, target) || other.target == target)&&(identical(other.source, source) || other.source == source)&&(identical(other.autostart, autostart) || other.autostart == autostart));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,poolType,target,source,autostart);
}

@override
String toString() {
    return 'VirtResourceOp.poolCreate(name: $name, poolType: $poolType, target: $target, source: $source, autostart: $autostart)';
}


}

/// @nodoc
abstract mixin class $VirtResourceOp_PoolCreateCopyWith<$Res> implements $VirtResourceOpCopyWith<$Res> {
  factory $VirtResourceOp_PoolCreateCopyWith(VirtResourceOp_PoolCreate value, $Res Function(VirtResourceOp_PoolCreate) _then) = _$VirtResourceOp_PoolCreateCopyWithImpl;
@override @useResult
$Res call({
 String name, String poolType, String? target, String? source, bool autostart
});




}
/// @nodoc
class _$VirtResourceOp_PoolCreateCopyWithImpl<$Res>
    implements $VirtResourceOp_PoolCreateCopyWith<$Res> {
  _$VirtResourceOp_PoolCreateCopyWithImpl(this._self, this._then);

  final VirtResourceOp_PoolCreate _self;
  final $Res Function(VirtResourceOp_PoolCreate) _then;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? poolType = null,Object? target = freezed,Object? source = freezed,Object? autostart = null,}) {
  return _then(VirtResourceOp_PoolCreate(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,poolType: null == poolType ? _self.poolType : poolType // ignore: cast_nullable_to_non_nullable
as String,target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,autostart: null == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class VirtResourceOp_PoolStart extends VirtResourceOp {
  const VirtResourceOp_PoolStart({required this.name}): super._();
  

@override final  String name;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtResourceOp_PoolStartCopyWith<VirtResourceOp_PoolStart> get copyWith => _$VirtResourceOp_PoolStartCopyWithImpl<VirtResourceOp_PoolStart>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtResourceOp_PoolStart&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name);
}

@override
String toString() {
    return 'VirtResourceOp.poolStart(name: $name)';
}


}

/// @nodoc
abstract mixin class $VirtResourceOp_PoolStartCopyWith<$Res> implements $VirtResourceOpCopyWith<$Res> {
  factory $VirtResourceOp_PoolStartCopyWith(VirtResourceOp_PoolStart value, $Res Function(VirtResourceOp_PoolStart) _then) = _$VirtResourceOp_PoolStartCopyWithImpl;
@override @useResult
$Res call({
 String name
});




}
/// @nodoc
class _$VirtResourceOp_PoolStartCopyWithImpl<$Res>
    implements $VirtResourceOp_PoolStartCopyWith<$Res> {
  _$VirtResourceOp_PoolStartCopyWithImpl(this._self, this._then);

  final VirtResourceOp_PoolStart _self;
  final $Res Function(VirtResourceOp_PoolStart) _then;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(VirtResourceOp_PoolStart(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class VirtResourceOp_PoolStop extends VirtResourceOp {
  const VirtResourceOp_PoolStop({required this.name}): super._();
  

@override final  String name;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtResourceOp_PoolStopCopyWith<VirtResourceOp_PoolStop> get copyWith => _$VirtResourceOp_PoolStopCopyWithImpl<VirtResourceOp_PoolStop>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtResourceOp_PoolStop&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name);
}

@override
String toString() {
    return 'VirtResourceOp.poolStop(name: $name)';
}


}

/// @nodoc
abstract mixin class $VirtResourceOp_PoolStopCopyWith<$Res> implements $VirtResourceOpCopyWith<$Res> {
  factory $VirtResourceOp_PoolStopCopyWith(VirtResourceOp_PoolStop value, $Res Function(VirtResourceOp_PoolStop) _then) = _$VirtResourceOp_PoolStopCopyWithImpl;
@override @useResult
$Res call({
 String name
});




}
/// @nodoc
class _$VirtResourceOp_PoolStopCopyWithImpl<$Res>
    implements $VirtResourceOp_PoolStopCopyWith<$Res> {
  _$VirtResourceOp_PoolStopCopyWithImpl(this._self, this._then);

  final VirtResourceOp_PoolStop _self;
  final $Res Function(VirtResourceOp_PoolStop) _then;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(VirtResourceOp_PoolStop(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class VirtResourceOp_PoolAutostart extends VirtResourceOp {
  const VirtResourceOp_PoolAutostart({required this.name, required this.on_}): super._();
  

@override final  String name;
 final  bool on_;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtResourceOp_PoolAutostartCopyWith<VirtResourceOp_PoolAutostart> get copyWith => _$VirtResourceOp_PoolAutostartCopyWithImpl<VirtResourceOp_PoolAutostart>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtResourceOp_PoolAutostart&&(identical(other.name, name) || other.name == name)&&(identical(other.on_, on_) || other.on_ == on_));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,on_);
}

@override
String toString() {
    return 'VirtResourceOp.poolAutostart(name: $name, on_: $on_)';
}


}

/// @nodoc
abstract mixin class $VirtResourceOp_PoolAutostartCopyWith<$Res> implements $VirtResourceOpCopyWith<$Res> {
  factory $VirtResourceOp_PoolAutostartCopyWith(VirtResourceOp_PoolAutostart value, $Res Function(VirtResourceOp_PoolAutostart) _then) = _$VirtResourceOp_PoolAutostartCopyWithImpl;
@override @useResult
$Res call({
 String name, bool on_
});




}
/// @nodoc
class _$VirtResourceOp_PoolAutostartCopyWithImpl<$Res>
    implements $VirtResourceOp_PoolAutostartCopyWith<$Res> {
  _$VirtResourceOp_PoolAutostartCopyWithImpl(this._self, this._then);

  final VirtResourceOp_PoolAutostart _self;
  final $Res Function(VirtResourceOp_PoolAutostart) _then;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? on_ = null,}) {
  return _then(VirtResourceOp_PoolAutostart(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,on_: null == on_ ? _self.on_ : on_ // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class VirtResourceOp_PoolRefresh extends VirtResourceOp {
  const VirtResourceOp_PoolRefresh({required this.name}): super._();
  

@override final  String name;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtResourceOp_PoolRefreshCopyWith<VirtResourceOp_PoolRefresh> get copyWith => _$VirtResourceOp_PoolRefreshCopyWithImpl<VirtResourceOp_PoolRefresh>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtResourceOp_PoolRefresh&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name);
}

@override
String toString() {
    return 'VirtResourceOp.poolRefresh(name: $name)';
}


}

/// @nodoc
abstract mixin class $VirtResourceOp_PoolRefreshCopyWith<$Res> implements $VirtResourceOpCopyWith<$Res> {
  factory $VirtResourceOp_PoolRefreshCopyWith(VirtResourceOp_PoolRefresh value, $Res Function(VirtResourceOp_PoolRefresh) _then) = _$VirtResourceOp_PoolRefreshCopyWithImpl;
@override @useResult
$Res call({
 String name
});




}
/// @nodoc
class _$VirtResourceOp_PoolRefreshCopyWithImpl<$Res>
    implements $VirtResourceOp_PoolRefreshCopyWith<$Res> {
  _$VirtResourceOp_PoolRefreshCopyWithImpl(this._self, this._then);

  final VirtResourceOp_PoolRefresh _self;
  final $Res Function(VirtResourceOp_PoolRefresh) _then;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(VirtResourceOp_PoolRefresh(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class VirtResourceOp_PoolDelete extends VirtResourceOp {
  const VirtResourceOp_PoolDelete({required this.name, required this.active, required this.deleteStorage}): super._();
  

@override final  String name;
 final  bool active;
 final  bool deleteStorage;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtResourceOp_PoolDeleteCopyWith<VirtResourceOp_PoolDelete> get copyWith => _$VirtResourceOp_PoolDeleteCopyWithImpl<VirtResourceOp_PoolDelete>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtResourceOp_PoolDelete&&(identical(other.name, name) || other.name == name)&&(identical(other.active, active) || other.active == active)&&(identical(other.deleteStorage, deleteStorage) || other.deleteStorage == deleteStorage));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,active,deleteStorage);
}

@override
String toString() {
    return 'VirtResourceOp.poolDelete(name: $name, active: $active, deleteStorage: $deleteStorage)';
}


}

/// @nodoc
abstract mixin class $VirtResourceOp_PoolDeleteCopyWith<$Res> implements $VirtResourceOpCopyWith<$Res> {
  factory $VirtResourceOp_PoolDeleteCopyWith(VirtResourceOp_PoolDelete value, $Res Function(VirtResourceOp_PoolDelete) _then) = _$VirtResourceOp_PoolDeleteCopyWithImpl;
@override @useResult
$Res call({
 String name, bool active, bool deleteStorage
});




}
/// @nodoc
class _$VirtResourceOp_PoolDeleteCopyWithImpl<$Res>
    implements $VirtResourceOp_PoolDeleteCopyWith<$Res> {
  _$VirtResourceOp_PoolDeleteCopyWithImpl(this._self, this._then);

  final VirtResourceOp_PoolDelete _self;
  final $Res Function(VirtResourceOp_PoolDelete) _then;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? active = null,Object? deleteStorage = null,}) {
  return _then(VirtResourceOp_PoolDelete(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,deleteStorage: null == deleteStorage ? _self.deleteStorage : deleteStorage // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class VirtResourceOp_VolCreate extends VirtResourceOp {
  const VirtResourceOp_VolCreate({required this.pool, required this.name, required this.bytes, required this.format}): super._();
  

 final  String pool;
@override final  String name;
 final  BigInt bytes;
 final  String format;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtResourceOp_VolCreateCopyWith<VirtResourceOp_VolCreate> get copyWith => _$VirtResourceOp_VolCreateCopyWithImpl<VirtResourceOp_VolCreate>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtResourceOp_VolCreate&&(identical(other.pool, pool) || other.pool == pool)&&(identical(other.name, name) || other.name == name)&&(identical(other.bytes, bytes) || other.bytes == bytes)&&(identical(other.format, format) || other.format == format));
}


@override
int get hashCode {
    return Object.hash(runtimeType,pool,name,bytes,format);
}

@override
String toString() {
    return 'VirtResourceOp.volCreate(pool: $pool, name: $name, bytes: $bytes, format: $format)';
}


}

/// @nodoc
abstract mixin class $VirtResourceOp_VolCreateCopyWith<$Res> implements $VirtResourceOpCopyWith<$Res> {
  factory $VirtResourceOp_VolCreateCopyWith(VirtResourceOp_VolCreate value, $Res Function(VirtResourceOp_VolCreate) _then) = _$VirtResourceOp_VolCreateCopyWithImpl;
@override @useResult
$Res call({
 String pool, String name, BigInt bytes, String format
});




}
/// @nodoc
class _$VirtResourceOp_VolCreateCopyWithImpl<$Res>
    implements $VirtResourceOp_VolCreateCopyWith<$Res> {
  _$VirtResourceOp_VolCreateCopyWithImpl(this._self, this._then);

  final VirtResourceOp_VolCreate _self;
  final $Res Function(VirtResourceOp_VolCreate) _then;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pool = null,Object? name = null,Object? bytes = null,Object? format = null,}) {
  return _then(VirtResourceOp_VolCreate(
pool: null == pool ? _self.pool : pool // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as BigInt,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class VirtResourceOp_VolDelete extends VirtResourceOp {
  const VirtResourceOp_VolDelete({required this.pool, required this.name}): super._();
  

 final  String pool;
@override final  String name;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtResourceOp_VolDeleteCopyWith<VirtResourceOp_VolDelete> get copyWith => _$VirtResourceOp_VolDeleteCopyWithImpl<VirtResourceOp_VolDelete>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtResourceOp_VolDelete&&(identical(other.pool, pool) || other.pool == pool)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode {
    return Object.hash(runtimeType,pool,name);
}

@override
String toString() {
    return 'VirtResourceOp.volDelete(pool: $pool, name: $name)';
}


}

/// @nodoc
abstract mixin class $VirtResourceOp_VolDeleteCopyWith<$Res> implements $VirtResourceOpCopyWith<$Res> {
  factory $VirtResourceOp_VolDeleteCopyWith(VirtResourceOp_VolDelete value, $Res Function(VirtResourceOp_VolDelete) _then) = _$VirtResourceOp_VolDeleteCopyWithImpl;
@override @useResult
$Res call({
 String pool, String name
});




}
/// @nodoc
class _$VirtResourceOp_VolDeleteCopyWithImpl<$Res>
    implements $VirtResourceOp_VolDeleteCopyWith<$Res> {
  _$VirtResourceOp_VolDeleteCopyWithImpl(this._self, this._then);

  final VirtResourceOp_VolDelete _self;
  final $Res Function(VirtResourceOp_VolDelete) _then;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pool = null,Object? name = null,}) {
  return _then(VirtResourceOp_VolDelete(
pool: null == pool ? _self.pool : pool // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class VirtResourceOp_VolResize extends VirtResourceOp {
  const VirtResourceOp_VolResize({required this.pool, required this.name, required this.bytes}): super._();
  

 final  String pool;
@override final  String name;
 final  BigInt bytes;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtResourceOp_VolResizeCopyWith<VirtResourceOp_VolResize> get copyWith => _$VirtResourceOp_VolResizeCopyWithImpl<VirtResourceOp_VolResize>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtResourceOp_VolResize&&(identical(other.pool, pool) || other.pool == pool)&&(identical(other.name, name) || other.name == name)&&(identical(other.bytes, bytes) || other.bytes == bytes));
}


@override
int get hashCode {
    return Object.hash(runtimeType,pool,name,bytes);
}

@override
String toString() {
    return 'VirtResourceOp.volResize(pool: $pool, name: $name, bytes: $bytes)';
}


}

/// @nodoc
abstract mixin class $VirtResourceOp_VolResizeCopyWith<$Res> implements $VirtResourceOpCopyWith<$Res> {
  factory $VirtResourceOp_VolResizeCopyWith(VirtResourceOp_VolResize value, $Res Function(VirtResourceOp_VolResize) _then) = _$VirtResourceOp_VolResizeCopyWithImpl;
@override @useResult
$Res call({
 String pool, String name, BigInt bytes
});




}
/// @nodoc
class _$VirtResourceOp_VolResizeCopyWithImpl<$Res>
    implements $VirtResourceOp_VolResizeCopyWith<$Res> {
  _$VirtResourceOp_VolResizeCopyWithImpl(this._self, this._then);

  final VirtResourceOp_VolResize _self;
  final $Res Function(VirtResourceOp_VolResize) _then;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pool = null,Object? name = null,Object? bytes = null,}) {
  return _then(VirtResourceOp_VolResize(
pool: null == pool ? _self.pool : pool // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class VirtResourceOp_VolClone extends VirtResourceOp {
  const VirtResourceOp_VolClone({required this.pool, required this.name, required this.newName}): super._();
  

 final  String pool;
@override final  String name;
 final  String newName;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtResourceOp_VolCloneCopyWith<VirtResourceOp_VolClone> get copyWith => _$VirtResourceOp_VolCloneCopyWithImpl<VirtResourceOp_VolClone>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtResourceOp_VolClone&&(identical(other.pool, pool) || other.pool == pool)&&(identical(other.name, name) || other.name == name)&&(identical(other.newName, newName) || other.newName == newName));
}


@override
int get hashCode {
    return Object.hash(runtimeType,pool,name,newName);
}

@override
String toString() {
    return 'VirtResourceOp.volClone(pool: $pool, name: $name, newName: $newName)';
}


}

/// @nodoc
abstract mixin class $VirtResourceOp_VolCloneCopyWith<$Res> implements $VirtResourceOpCopyWith<$Res> {
  factory $VirtResourceOp_VolCloneCopyWith(VirtResourceOp_VolClone value, $Res Function(VirtResourceOp_VolClone) _then) = _$VirtResourceOp_VolCloneCopyWithImpl;
@override @useResult
$Res call({
 String pool, String name, String newName
});




}
/// @nodoc
class _$VirtResourceOp_VolCloneCopyWithImpl<$Res>
    implements $VirtResourceOp_VolCloneCopyWith<$Res> {
  _$VirtResourceOp_VolCloneCopyWithImpl(this._self, this._then);

  final VirtResourceOp_VolClone _self;
  final $Res Function(VirtResourceOp_VolClone) _then;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pool = null,Object? name = null,Object? newName = null,}) {
  return _then(VirtResourceOp_VolClone(
pool: null == pool ? _self.pool : pool // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,newName: null == newName ? _self.newName : newName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class VirtResourceOp_NetCreate extends VirtResourceOp {
  const VirtResourceOp_NetCreate({required this.name, required this.mode, this.bridge, this.ipv4, required this.autostart}): super._();
  

@override final  String name;
 final  String mode;
 final  String? bridge;
 final  VirtNetIpv4? ipv4;
 final  bool autostart;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtResourceOp_NetCreateCopyWith<VirtResourceOp_NetCreate> get copyWith => _$VirtResourceOp_NetCreateCopyWithImpl<VirtResourceOp_NetCreate>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtResourceOp_NetCreate&&(identical(other.name, name) || other.name == name)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.bridge, bridge) || other.bridge == bridge)&&(identical(other.ipv4, ipv4) || other.ipv4 == ipv4)&&(identical(other.autostart, autostart) || other.autostart == autostart));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,mode,bridge,ipv4,autostart);
}

@override
String toString() {
    return 'VirtResourceOp.netCreate(name: $name, mode: $mode, bridge: $bridge, ipv4: $ipv4, autostart: $autostart)';
}


}

/// @nodoc
abstract mixin class $VirtResourceOp_NetCreateCopyWith<$Res> implements $VirtResourceOpCopyWith<$Res> {
  factory $VirtResourceOp_NetCreateCopyWith(VirtResourceOp_NetCreate value, $Res Function(VirtResourceOp_NetCreate) _then) = _$VirtResourceOp_NetCreateCopyWithImpl;
@override @useResult
$Res call({
 String name, String mode, String? bridge, VirtNetIpv4? ipv4, bool autostart
});




}
/// @nodoc
class _$VirtResourceOp_NetCreateCopyWithImpl<$Res>
    implements $VirtResourceOp_NetCreateCopyWith<$Res> {
  _$VirtResourceOp_NetCreateCopyWithImpl(this._self, this._then);

  final VirtResourceOp_NetCreate _self;
  final $Res Function(VirtResourceOp_NetCreate) _then;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? mode = null,Object? bridge = freezed,Object? ipv4 = freezed,Object? autostart = null,}) {
  return _then(VirtResourceOp_NetCreate(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,bridge: freezed == bridge ? _self.bridge : bridge // ignore: cast_nullable_to_non_nullable
as String?,ipv4: freezed == ipv4 ? _self.ipv4 : ipv4 // ignore: cast_nullable_to_non_nullable
as VirtNetIpv4?,autostart: null == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class VirtResourceOp_NetStart extends VirtResourceOp {
  const VirtResourceOp_NetStart({required this.name}): super._();
  

@override final  String name;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtResourceOp_NetStartCopyWith<VirtResourceOp_NetStart> get copyWith => _$VirtResourceOp_NetStartCopyWithImpl<VirtResourceOp_NetStart>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtResourceOp_NetStart&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name);
}

@override
String toString() {
    return 'VirtResourceOp.netStart(name: $name)';
}


}

/// @nodoc
abstract mixin class $VirtResourceOp_NetStartCopyWith<$Res> implements $VirtResourceOpCopyWith<$Res> {
  factory $VirtResourceOp_NetStartCopyWith(VirtResourceOp_NetStart value, $Res Function(VirtResourceOp_NetStart) _then) = _$VirtResourceOp_NetStartCopyWithImpl;
@override @useResult
$Res call({
 String name
});




}
/// @nodoc
class _$VirtResourceOp_NetStartCopyWithImpl<$Res>
    implements $VirtResourceOp_NetStartCopyWith<$Res> {
  _$VirtResourceOp_NetStartCopyWithImpl(this._self, this._then);

  final VirtResourceOp_NetStart _self;
  final $Res Function(VirtResourceOp_NetStart) _then;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(VirtResourceOp_NetStart(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class VirtResourceOp_NetStop extends VirtResourceOp {
  const VirtResourceOp_NetStop({required this.name}): super._();
  

@override final  String name;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtResourceOp_NetStopCopyWith<VirtResourceOp_NetStop> get copyWith => _$VirtResourceOp_NetStopCopyWithImpl<VirtResourceOp_NetStop>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtResourceOp_NetStop&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name);
}

@override
String toString() {
    return 'VirtResourceOp.netStop(name: $name)';
}


}

/// @nodoc
abstract mixin class $VirtResourceOp_NetStopCopyWith<$Res> implements $VirtResourceOpCopyWith<$Res> {
  factory $VirtResourceOp_NetStopCopyWith(VirtResourceOp_NetStop value, $Res Function(VirtResourceOp_NetStop) _then) = _$VirtResourceOp_NetStopCopyWithImpl;
@override @useResult
$Res call({
 String name
});




}
/// @nodoc
class _$VirtResourceOp_NetStopCopyWithImpl<$Res>
    implements $VirtResourceOp_NetStopCopyWith<$Res> {
  _$VirtResourceOp_NetStopCopyWithImpl(this._self, this._then);

  final VirtResourceOp_NetStop _self;
  final $Res Function(VirtResourceOp_NetStop) _then;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(VirtResourceOp_NetStop(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class VirtResourceOp_NetAutostart extends VirtResourceOp {
  const VirtResourceOp_NetAutostart({required this.name, required this.on_}): super._();
  

@override final  String name;
 final  bool on_;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtResourceOp_NetAutostartCopyWith<VirtResourceOp_NetAutostart> get copyWith => _$VirtResourceOp_NetAutostartCopyWithImpl<VirtResourceOp_NetAutostart>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtResourceOp_NetAutostart&&(identical(other.name, name) || other.name == name)&&(identical(other.on_, on_) || other.on_ == on_));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,on_);
}

@override
String toString() {
    return 'VirtResourceOp.netAutostart(name: $name, on_: $on_)';
}


}

/// @nodoc
abstract mixin class $VirtResourceOp_NetAutostartCopyWith<$Res> implements $VirtResourceOpCopyWith<$Res> {
  factory $VirtResourceOp_NetAutostartCopyWith(VirtResourceOp_NetAutostart value, $Res Function(VirtResourceOp_NetAutostart) _then) = _$VirtResourceOp_NetAutostartCopyWithImpl;
@override @useResult
$Res call({
 String name, bool on_
});




}
/// @nodoc
class _$VirtResourceOp_NetAutostartCopyWithImpl<$Res>
    implements $VirtResourceOp_NetAutostartCopyWith<$Res> {
  _$VirtResourceOp_NetAutostartCopyWithImpl(this._self, this._then);

  final VirtResourceOp_NetAutostart _self;
  final $Res Function(VirtResourceOp_NetAutostart) _then;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? on_ = null,}) {
  return _then(VirtResourceOp_NetAutostart(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,on_: null == on_ ? _self.on_ : on_ // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class VirtResourceOp_NetDelete extends VirtResourceOp {
  const VirtResourceOp_NetDelete({required this.name}): super._();
  

@override final  String name;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtResourceOp_NetDeleteCopyWith<VirtResourceOp_NetDelete> get copyWith => _$VirtResourceOp_NetDeleteCopyWithImpl<VirtResourceOp_NetDelete>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtResourceOp_NetDelete&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name);
}

@override
String toString() {
    return 'VirtResourceOp.netDelete(name: $name)';
}


}

/// @nodoc
abstract mixin class $VirtResourceOp_NetDeleteCopyWith<$Res> implements $VirtResourceOpCopyWith<$Res> {
  factory $VirtResourceOp_NetDeleteCopyWith(VirtResourceOp_NetDelete value, $Res Function(VirtResourceOp_NetDelete) _then) = _$VirtResourceOp_NetDeleteCopyWithImpl;
@override @useResult
$Res call({
 String name
});




}
/// @nodoc
class _$VirtResourceOp_NetDeleteCopyWithImpl<$Res>
    implements $VirtResourceOp_NetDeleteCopyWith<$Res> {
  _$VirtResourceOp_NetDeleteCopyWithImpl(this._self, this._then);

  final VirtResourceOp_NetDelete _self;
  final $Res Function(VirtResourceOp_NetDelete) _then;

/// Create a copy of VirtResourceOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(VirtResourceOp_NetDelete(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
