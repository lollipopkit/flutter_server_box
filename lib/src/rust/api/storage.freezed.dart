// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'storage.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StorageAction {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'StorageAction()';
}


}

/// @nodoc
class $StorageActionCopyWith<$Res>  {
$StorageActionCopyWith(StorageAction _, $Res Function(StorageAction) __);
}


/// Adds pattern-matching-related methods to [StorageAction].
extension StorageActionPatterns on StorageAction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( StorageAction_Partition value)?  partition,TResult Function( StorageAction_Format value)?  format,TResult Function( StorageAction_Mount value)?  mount,TResult Function( StorageAction_Unmount value)?  unmount,TResult Function( StorageAction_CreateRaid value)?  createRaid,TResult Function( StorageAction_AddToRaid value)?  addToRaid,TResult Function( StorageAction_RemoveFromRaid value)?  removeFromRaid,TResult Function( StorageAction_DeleteRaid value)?  deleteRaid,TResult Function( StorageAction_CreatePool value)?  createPool,TResult Function( StorageAction_ScrubPool value)?  scrubPool,TResult Function( StorageAction_DestroyPool value)?  destroyPool,TResult Function( StorageAction_SmartTest value)?  smartTest,TResult Function( StorageAction_GrowRaid value)?  growRaid,TResult Function( StorageAction_ExpandFilesystem value)?  expandFilesystem,TResult Function( StorageAction_AddToPool value)?  addToPool,TResult Function( StorageAction_ReplaceInPool value)?  replaceInPool,TResult Function( StorageAction_AttachToPool value)?  attachToPool,TResult Function( StorageAction_AddSpare value)?  addSpare,TResult Function( StorageAction_RemoveFromPool value)?  removeFromPool,TResult Function( StorageAction_OnlineInPool value)?  onlineInPool,TResult Function( StorageAction_GrowPartition value)?  growPartition,TResult Function( StorageAction_Unlock value)?  unlock,TResult Function( StorageAction_Lock value)?  lock,required TResult orElse(),}){
final _that = this;
switch (_that) {
case StorageAction_Partition() when partition != null:
return partition(_that);case StorageAction_Format() when format != null:
return format(_that);case StorageAction_Mount() when mount != null:
return mount(_that);case StorageAction_Unmount() when unmount != null:
return unmount(_that);case StorageAction_CreateRaid() when createRaid != null:
return createRaid(_that);case StorageAction_AddToRaid() when addToRaid != null:
return addToRaid(_that);case StorageAction_RemoveFromRaid() when removeFromRaid != null:
return removeFromRaid(_that);case StorageAction_DeleteRaid() when deleteRaid != null:
return deleteRaid(_that);case StorageAction_CreatePool() when createPool != null:
return createPool(_that);case StorageAction_ScrubPool() when scrubPool != null:
return scrubPool(_that);case StorageAction_DestroyPool() when destroyPool != null:
return destroyPool(_that);case StorageAction_SmartTest() when smartTest != null:
return smartTest(_that);case StorageAction_GrowRaid() when growRaid != null:
return growRaid(_that);case StorageAction_ExpandFilesystem() when expandFilesystem != null:
return expandFilesystem(_that);case StorageAction_AddToPool() when addToPool != null:
return addToPool(_that);case StorageAction_ReplaceInPool() when replaceInPool != null:
return replaceInPool(_that);case StorageAction_AttachToPool() when attachToPool != null:
return attachToPool(_that);case StorageAction_AddSpare() when addSpare != null:
return addSpare(_that);case StorageAction_RemoveFromPool() when removeFromPool != null:
return removeFromPool(_that);case StorageAction_OnlineInPool() when onlineInPool != null:
return onlineInPool(_that);case StorageAction_GrowPartition() when growPartition != null:
return growPartition(_that);case StorageAction_Unlock() when unlock != null:
return unlock(_that);case StorageAction_Lock() when lock != null:
return lock(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( StorageAction_Partition value)  partition,required TResult Function( StorageAction_Format value)  format,required TResult Function( StorageAction_Mount value)  mount,required TResult Function( StorageAction_Unmount value)  unmount,required TResult Function( StorageAction_CreateRaid value)  createRaid,required TResult Function( StorageAction_AddToRaid value)  addToRaid,required TResult Function( StorageAction_RemoveFromRaid value)  removeFromRaid,required TResult Function( StorageAction_DeleteRaid value)  deleteRaid,required TResult Function( StorageAction_CreatePool value)  createPool,required TResult Function( StorageAction_ScrubPool value)  scrubPool,required TResult Function( StorageAction_DestroyPool value)  destroyPool,required TResult Function( StorageAction_SmartTest value)  smartTest,required TResult Function( StorageAction_GrowRaid value)  growRaid,required TResult Function( StorageAction_ExpandFilesystem value)  expandFilesystem,required TResult Function( StorageAction_AddToPool value)  addToPool,required TResult Function( StorageAction_ReplaceInPool value)  replaceInPool,required TResult Function( StorageAction_AttachToPool value)  attachToPool,required TResult Function( StorageAction_AddSpare value)  addSpare,required TResult Function( StorageAction_RemoveFromPool value)  removeFromPool,required TResult Function( StorageAction_OnlineInPool value)  onlineInPool,required TResult Function( StorageAction_GrowPartition value)  growPartition,required TResult Function( StorageAction_Unlock value)  unlock,required TResult Function( StorageAction_Lock value)  lock,}){
final _that = this;
switch (_that) {
case StorageAction_Partition():
return partition(_that);case StorageAction_Format():
return format(_that);case StorageAction_Mount():
return mount(_that);case StorageAction_Unmount():
return unmount(_that);case StorageAction_CreateRaid():
return createRaid(_that);case StorageAction_AddToRaid():
return addToRaid(_that);case StorageAction_RemoveFromRaid():
return removeFromRaid(_that);case StorageAction_DeleteRaid():
return deleteRaid(_that);case StorageAction_CreatePool():
return createPool(_that);case StorageAction_ScrubPool():
return scrubPool(_that);case StorageAction_DestroyPool():
return destroyPool(_that);case StorageAction_SmartTest():
return smartTest(_that);case StorageAction_GrowRaid():
return growRaid(_that);case StorageAction_ExpandFilesystem():
return expandFilesystem(_that);case StorageAction_AddToPool():
return addToPool(_that);case StorageAction_ReplaceInPool():
return replaceInPool(_that);case StorageAction_AttachToPool():
return attachToPool(_that);case StorageAction_AddSpare():
return addSpare(_that);case StorageAction_RemoveFromPool():
return removeFromPool(_that);case StorageAction_OnlineInPool():
return onlineInPool(_that);case StorageAction_GrowPartition():
return growPartition(_that);case StorageAction_Unlock():
return unlock(_that);case StorageAction_Lock():
return lock(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( StorageAction_Partition value)?  partition,TResult? Function( StorageAction_Format value)?  format,TResult? Function( StorageAction_Mount value)?  mount,TResult? Function( StorageAction_Unmount value)?  unmount,TResult? Function( StorageAction_CreateRaid value)?  createRaid,TResult? Function( StorageAction_AddToRaid value)?  addToRaid,TResult? Function( StorageAction_RemoveFromRaid value)?  removeFromRaid,TResult? Function( StorageAction_DeleteRaid value)?  deleteRaid,TResult? Function( StorageAction_CreatePool value)?  createPool,TResult? Function( StorageAction_ScrubPool value)?  scrubPool,TResult? Function( StorageAction_DestroyPool value)?  destroyPool,TResult? Function( StorageAction_SmartTest value)?  smartTest,TResult? Function( StorageAction_GrowRaid value)?  growRaid,TResult? Function( StorageAction_ExpandFilesystem value)?  expandFilesystem,TResult? Function( StorageAction_AddToPool value)?  addToPool,TResult? Function( StorageAction_ReplaceInPool value)?  replaceInPool,TResult? Function( StorageAction_AttachToPool value)?  attachToPool,TResult? Function( StorageAction_AddSpare value)?  addSpare,TResult? Function( StorageAction_RemoveFromPool value)?  removeFromPool,TResult? Function( StorageAction_OnlineInPool value)?  onlineInPool,TResult? Function( StorageAction_GrowPartition value)?  growPartition,TResult? Function( StorageAction_Unlock value)?  unlock,TResult? Function( StorageAction_Lock value)?  lock,}){
final _that = this;
switch (_that) {
case StorageAction_Partition() when partition != null:
return partition(_that);case StorageAction_Format() when format != null:
return format(_that);case StorageAction_Mount() when mount != null:
return mount(_that);case StorageAction_Unmount() when unmount != null:
return unmount(_that);case StorageAction_CreateRaid() when createRaid != null:
return createRaid(_that);case StorageAction_AddToRaid() when addToRaid != null:
return addToRaid(_that);case StorageAction_RemoveFromRaid() when removeFromRaid != null:
return removeFromRaid(_that);case StorageAction_DeleteRaid() when deleteRaid != null:
return deleteRaid(_that);case StorageAction_CreatePool() when createPool != null:
return createPool(_that);case StorageAction_ScrubPool() when scrubPool != null:
return scrubPool(_that);case StorageAction_DestroyPool() when destroyPool != null:
return destroyPool(_that);case StorageAction_SmartTest() when smartTest != null:
return smartTest(_that);case StorageAction_GrowRaid() when growRaid != null:
return growRaid(_that);case StorageAction_ExpandFilesystem() when expandFilesystem != null:
return expandFilesystem(_that);case StorageAction_AddToPool() when addToPool != null:
return addToPool(_that);case StorageAction_ReplaceInPool() when replaceInPool != null:
return replaceInPool(_that);case StorageAction_AttachToPool() when attachToPool != null:
return attachToPool(_that);case StorageAction_AddSpare() when addSpare != null:
return addSpare(_that);case StorageAction_RemoveFromPool() when removeFromPool != null:
return removeFromPool(_that);case StorageAction_OnlineInPool() when onlineInPool != null:
return onlineInPool(_that);case StorageAction_GrowPartition() when growPartition != null:
return growPartition(_that);case StorageAction_Unlock() when unlock != null:
return unlock(_that);case StorageAction_Lock() when lock != null:
return lock(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String device)?  partition,TResult Function( String device,  String fstype,  String? label,  bool encrypt)?  format,TResult Function( String device,  String mountpoint,  bool persist,  bool own)?  mount,TResult Function( String mountpoint)?  unmount,TResult Function( String name,  int level,  List<String> devices)?  createRaid,TResult Function( String array,  String device)?  addToRaid,TResult Function( String array,  String device)?  removeFromRaid,TResult Function( String array)?  deleteRaid,TResult Function( String name,  String layout,  List<String> devices)?  createPool,TResult Function( String name)?  scrubPool,TResult Function( String name)?  destroyPool,TResult Function( String device,  bool long)?  smartTest,TResult Function( String array,  String device)?  growRaid,TResult Function( String device)?  expandFilesystem,TResult Function( String name,  String layout,  List<String> devices)?  addToPool,TResult Function( String name,  String old,  String new_)?  replaceInPool,TResult Function( String name,  String existing,  String new_)?  attachToPool,TResult Function( String name,  List<String> devices)?  addSpare,TResult Function( String name,  String device)?  removeFromPool,TResult Function( String name,  String device)?  onlineInPool,TResult Function( String device)?  growPartition,TResult Function( String device)?  unlock,TResult Function( String device)?  lock,required TResult orElse(),}) {final _that = this;
switch (_that) {
case StorageAction_Partition() when partition != null:
return partition(_that.device);case StorageAction_Format() when format != null:
return format(_that.device,_that.fstype,_that.label,_that.encrypt);case StorageAction_Mount() when mount != null:
return mount(_that.device,_that.mountpoint,_that.persist,_that.own);case StorageAction_Unmount() when unmount != null:
return unmount(_that.mountpoint);case StorageAction_CreateRaid() when createRaid != null:
return createRaid(_that.name,_that.level,_that.devices);case StorageAction_AddToRaid() when addToRaid != null:
return addToRaid(_that.array,_that.device);case StorageAction_RemoveFromRaid() when removeFromRaid != null:
return removeFromRaid(_that.array,_that.device);case StorageAction_DeleteRaid() when deleteRaid != null:
return deleteRaid(_that.array);case StorageAction_CreatePool() when createPool != null:
return createPool(_that.name,_that.layout,_that.devices);case StorageAction_ScrubPool() when scrubPool != null:
return scrubPool(_that.name);case StorageAction_DestroyPool() when destroyPool != null:
return destroyPool(_that.name);case StorageAction_SmartTest() when smartTest != null:
return smartTest(_that.device,_that.long);case StorageAction_GrowRaid() when growRaid != null:
return growRaid(_that.array,_that.device);case StorageAction_ExpandFilesystem() when expandFilesystem != null:
return expandFilesystem(_that.device);case StorageAction_AddToPool() when addToPool != null:
return addToPool(_that.name,_that.layout,_that.devices);case StorageAction_ReplaceInPool() when replaceInPool != null:
return replaceInPool(_that.name,_that.old,_that.new_);case StorageAction_AttachToPool() when attachToPool != null:
return attachToPool(_that.name,_that.existing,_that.new_);case StorageAction_AddSpare() when addSpare != null:
return addSpare(_that.name,_that.devices);case StorageAction_RemoveFromPool() when removeFromPool != null:
return removeFromPool(_that.name,_that.device);case StorageAction_OnlineInPool() when onlineInPool != null:
return onlineInPool(_that.name,_that.device);case StorageAction_GrowPartition() when growPartition != null:
return growPartition(_that.device);case StorageAction_Unlock() when unlock != null:
return unlock(_that.device);case StorageAction_Lock() when lock != null:
return lock(_that.device);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String device)  partition,required TResult Function( String device,  String fstype,  String? label,  bool encrypt)  format,required TResult Function( String device,  String mountpoint,  bool persist,  bool own)  mount,required TResult Function( String mountpoint)  unmount,required TResult Function( String name,  int level,  List<String> devices)  createRaid,required TResult Function( String array,  String device)  addToRaid,required TResult Function( String array,  String device)  removeFromRaid,required TResult Function( String array)  deleteRaid,required TResult Function( String name,  String layout,  List<String> devices)  createPool,required TResult Function( String name)  scrubPool,required TResult Function( String name)  destroyPool,required TResult Function( String device,  bool long)  smartTest,required TResult Function( String array,  String device)  growRaid,required TResult Function( String device)  expandFilesystem,required TResult Function( String name,  String layout,  List<String> devices)  addToPool,required TResult Function( String name,  String old,  String new_)  replaceInPool,required TResult Function( String name,  String existing,  String new_)  attachToPool,required TResult Function( String name,  List<String> devices)  addSpare,required TResult Function( String name,  String device)  removeFromPool,required TResult Function( String name,  String device)  onlineInPool,required TResult Function( String device)  growPartition,required TResult Function( String device)  unlock,required TResult Function( String device)  lock,}) {final _that = this;
switch (_that) {
case StorageAction_Partition():
return partition(_that.device);case StorageAction_Format():
return format(_that.device,_that.fstype,_that.label,_that.encrypt);case StorageAction_Mount():
return mount(_that.device,_that.mountpoint,_that.persist,_that.own);case StorageAction_Unmount():
return unmount(_that.mountpoint);case StorageAction_CreateRaid():
return createRaid(_that.name,_that.level,_that.devices);case StorageAction_AddToRaid():
return addToRaid(_that.array,_that.device);case StorageAction_RemoveFromRaid():
return removeFromRaid(_that.array,_that.device);case StorageAction_DeleteRaid():
return deleteRaid(_that.array);case StorageAction_CreatePool():
return createPool(_that.name,_that.layout,_that.devices);case StorageAction_ScrubPool():
return scrubPool(_that.name);case StorageAction_DestroyPool():
return destroyPool(_that.name);case StorageAction_SmartTest():
return smartTest(_that.device,_that.long);case StorageAction_GrowRaid():
return growRaid(_that.array,_that.device);case StorageAction_ExpandFilesystem():
return expandFilesystem(_that.device);case StorageAction_AddToPool():
return addToPool(_that.name,_that.layout,_that.devices);case StorageAction_ReplaceInPool():
return replaceInPool(_that.name,_that.old,_that.new_);case StorageAction_AttachToPool():
return attachToPool(_that.name,_that.existing,_that.new_);case StorageAction_AddSpare():
return addSpare(_that.name,_that.devices);case StorageAction_RemoveFromPool():
return removeFromPool(_that.name,_that.device);case StorageAction_OnlineInPool():
return onlineInPool(_that.name,_that.device);case StorageAction_GrowPartition():
return growPartition(_that.device);case StorageAction_Unlock():
return unlock(_that.device);case StorageAction_Lock():
return lock(_that.device);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String device)?  partition,TResult? Function( String device,  String fstype,  String? label,  bool encrypt)?  format,TResult? Function( String device,  String mountpoint,  bool persist,  bool own)?  mount,TResult? Function( String mountpoint)?  unmount,TResult? Function( String name,  int level,  List<String> devices)?  createRaid,TResult? Function( String array,  String device)?  addToRaid,TResult? Function( String array,  String device)?  removeFromRaid,TResult? Function( String array)?  deleteRaid,TResult? Function( String name,  String layout,  List<String> devices)?  createPool,TResult? Function( String name)?  scrubPool,TResult? Function( String name)?  destroyPool,TResult? Function( String device,  bool long)?  smartTest,TResult? Function( String array,  String device)?  growRaid,TResult? Function( String device)?  expandFilesystem,TResult? Function( String name,  String layout,  List<String> devices)?  addToPool,TResult? Function( String name,  String old,  String new_)?  replaceInPool,TResult? Function( String name,  String existing,  String new_)?  attachToPool,TResult? Function( String name,  List<String> devices)?  addSpare,TResult? Function( String name,  String device)?  removeFromPool,TResult? Function( String name,  String device)?  onlineInPool,TResult? Function( String device)?  growPartition,TResult? Function( String device)?  unlock,TResult? Function( String device)?  lock,}) {final _that = this;
switch (_that) {
case StorageAction_Partition() when partition != null:
return partition(_that.device);case StorageAction_Format() when format != null:
return format(_that.device,_that.fstype,_that.label,_that.encrypt);case StorageAction_Mount() when mount != null:
return mount(_that.device,_that.mountpoint,_that.persist,_that.own);case StorageAction_Unmount() when unmount != null:
return unmount(_that.mountpoint);case StorageAction_CreateRaid() when createRaid != null:
return createRaid(_that.name,_that.level,_that.devices);case StorageAction_AddToRaid() when addToRaid != null:
return addToRaid(_that.array,_that.device);case StorageAction_RemoveFromRaid() when removeFromRaid != null:
return removeFromRaid(_that.array,_that.device);case StorageAction_DeleteRaid() when deleteRaid != null:
return deleteRaid(_that.array);case StorageAction_CreatePool() when createPool != null:
return createPool(_that.name,_that.layout,_that.devices);case StorageAction_ScrubPool() when scrubPool != null:
return scrubPool(_that.name);case StorageAction_DestroyPool() when destroyPool != null:
return destroyPool(_that.name);case StorageAction_SmartTest() when smartTest != null:
return smartTest(_that.device,_that.long);case StorageAction_GrowRaid() when growRaid != null:
return growRaid(_that.array,_that.device);case StorageAction_ExpandFilesystem() when expandFilesystem != null:
return expandFilesystem(_that.device);case StorageAction_AddToPool() when addToPool != null:
return addToPool(_that.name,_that.layout,_that.devices);case StorageAction_ReplaceInPool() when replaceInPool != null:
return replaceInPool(_that.name,_that.old,_that.new_);case StorageAction_AttachToPool() when attachToPool != null:
return attachToPool(_that.name,_that.existing,_that.new_);case StorageAction_AddSpare() when addSpare != null:
return addSpare(_that.name,_that.devices);case StorageAction_RemoveFromPool() when removeFromPool != null:
return removeFromPool(_that.name,_that.device);case StorageAction_OnlineInPool() when onlineInPool != null:
return onlineInPool(_that.name,_that.device);case StorageAction_GrowPartition() when growPartition != null:
return growPartition(_that.device);case StorageAction_Unlock() when unlock != null:
return unlock(_that.device);case StorageAction_Lock() when lock != null:
return lock(_that.device);case _:
  return null;

}
}

}

/// @nodoc


class StorageAction_Partition extends StorageAction {
  const StorageAction_Partition({required this.device}): super._();
  

 final  String device;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_PartitionCopyWith<StorageAction_Partition> get copyWith => _$StorageAction_PartitionCopyWithImpl<StorageAction_Partition>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_Partition&&(identical(other.device, device) || other.device == device));
}


@override
int get hashCode => Object.hash(runtimeType,device);

@override
String toString() {
  return 'StorageAction.partition(device: $device)';
}


}

/// @nodoc
abstract mixin class $StorageAction_PartitionCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_PartitionCopyWith(StorageAction_Partition value, $Res Function(StorageAction_Partition) _then) = _$StorageAction_PartitionCopyWithImpl;
@useResult
$Res call({
 String device
});




}
/// @nodoc
class _$StorageAction_PartitionCopyWithImpl<$Res>
    implements $StorageAction_PartitionCopyWith<$Res> {
  _$StorageAction_PartitionCopyWithImpl(this._self, this._then);

  final StorageAction_Partition _self;
  final $Res Function(StorageAction_Partition) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? device = null,}) {
  return _then(StorageAction_Partition(
device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class StorageAction_Format extends StorageAction {
  const StorageAction_Format({required this.device, required this.fstype, this.label, required this.encrypt}): super._();
  

 final  String device;
 final  String fstype;
 final  String? label;
 final  bool encrypt;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_FormatCopyWith<StorageAction_Format> get copyWith => _$StorageAction_FormatCopyWithImpl<StorageAction_Format>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_Format&&(identical(other.device, device) || other.device == device)&&(identical(other.fstype, fstype) || other.fstype == fstype)&&(identical(other.label, label) || other.label == label)&&(identical(other.encrypt, encrypt) || other.encrypt == encrypt));
}


@override
int get hashCode => Object.hash(runtimeType,device,fstype,label,encrypt);

@override
String toString() {
  return 'StorageAction.format(device: $device, fstype: $fstype, label: $label, encrypt: $encrypt)';
}


}

/// @nodoc
abstract mixin class $StorageAction_FormatCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_FormatCopyWith(StorageAction_Format value, $Res Function(StorageAction_Format) _then) = _$StorageAction_FormatCopyWithImpl;
@useResult
$Res call({
 String device, String fstype, String? label, bool encrypt
});




}
/// @nodoc
class _$StorageAction_FormatCopyWithImpl<$Res>
    implements $StorageAction_FormatCopyWith<$Res> {
  _$StorageAction_FormatCopyWithImpl(this._self, this._then);

  final StorageAction_Format _self;
  final $Res Function(StorageAction_Format) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? device = null,Object? fstype = null,Object? label = freezed,Object? encrypt = null,}) {
  return _then(StorageAction_Format(
device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,fstype: null == fstype ? _self.fstype : fstype // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,encrypt: null == encrypt ? _self.encrypt : encrypt // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class StorageAction_Mount extends StorageAction {
  const StorageAction_Mount({required this.device, required this.mountpoint, required this.persist, required this.own}): super._();
  

 final  String device;
 final  String mountpoint;
 final  bool persist;
 final  bool own;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_MountCopyWith<StorageAction_Mount> get copyWith => _$StorageAction_MountCopyWithImpl<StorageAction_Mount>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_Mount&&(identical(other.device, device) || other.device == device)&&(identical(other.mountpoint, mountpoint) || other.mountpoint == mountpoint)&&(identical(other.persist, persist) || other.persist == persist)&&(identical(other.own, own) || other.own == own));
}


@override
int get hashCode => Object.hash(runtimeType,device,mountpoint,persist,own);

@override
String toString() {
  return 'StorageAction.mount(device: $device, mountpoint: $mountpoint, persist: $persist, own: $own)';
}


}

/// @nodoc
abstract mixin class $StorageAction_MountCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_MountCopyWith(StorageAction_Mount value, $Res Function(StorageAction_Mount) _then) = _$StorageAction_MountCopyWithImpl;
@useResult
$Res call({
 String device, String mountpoint, bool persist, bool own
});




}
/// @nodoc
class _$StorageAction_MountCopyWithImpl<$Res>
    implements $StorageAction_MountCopyWith<$Res> {
  _$StorageAction_MountCopyWithImpl(this._self, this._then);

  final StorageAction_Mount _self;
  final $Res Function(StorageAction_Mount) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? device = null,Object? mountpoint = null,Object? persist = null,Object? own = null,}) {
  return _then(StorageAction_Mount(
device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,mountpoint: null == mountpoint ? _self.mountpoint : mountpoint // ignore: cast_nullable_to_non_nullable
as String,persist: null == persist ? _self.persist : persist // ignore: cast_nullable_to_non_nullable
as bool,own: null == own ? _self.own : own // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class StorageAction_Unmount extends StorageAction {
  const StorageAction_Unmount({required this.mountpoint}): super._();
  

 final  String mountpoint;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_UnmountCopyWith<StorageAction_Unmount> get copyWith => _$StorageAction_UnmountCopyWithImpl<StorageAction_Unmount>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_Unmount&&(identical(other.mountpoint, mountpoint) || other.mountpoint == mountpoint));
}


@override
int get hashCode => Object.hash(runtimeType,mountpoint);

@override
String toString() {
  return 'StorageAction.unmount(mountpoint: $mountpoint)';
}


}

/// @nodoc
abstract mixin class $StorageAction_UnmountCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_UnmountCopyWith(StorageAction_Unmount value, $Res Function(StorageAction_Unmount) _then) = _$StorageAction_UnmountCopyWithImpl;
@useResult
$Res call({
 String mountpoint
});




}
/// @nodoc
class _$StorageAction_UnmountCopyWithImpl<$Res>
    implements $StorageAction_UnmountCopyWith<$Res> {
  _$StorageAction_UnmountCopyWithImpl(this._self, this._then);

  final StorageAction_Unmount _self;
  final $Res Function(StorageAction_Unmount) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mountpoint = null,}) {
  return _then(StorageAction_Unmount(
mountpoint: null == mountpoint ? _self.mountpoint : mountpoint // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class StorageAction_CreateRaid extends StorageAction {
  const StorageAction_CreateRaid({required this.name, required this.level, required final  List<String> devices}): _devices = devices,super._();
  

 final  String name;
 final  int level;
 final  List<String> _devices;
 List<String> get devices {
  if (_devices is EqualUnmodifiableListView) return _devices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_devices);
}


/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_CreateRaidCopyWith<StorageAction_CreateRaid> get copyWith => _$StorageAction_CreateRaidCopyWithImpl<StorageAction_CreateRaid>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_CreateRaid&&(identical(other.name, name) || other.name == name)&&(identical(other.level, level) || other.level == level)&&const DeepCollectionEquality().equals(other._devices, _devices));
}


@override
int get hashCode => Object.hash(runtimeType,name,level,const DeepCollectionEquality().hash(_devices));

@override
String toString() {
  return 'StorageAction.createRaid(name: $name, level: $level, devices: $devices)';
}


}

/// @nodoc
abstract mixin class $StorageAction_CreateRaidCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_CreateRaidCopyWith(StorageAction_CreateRaid value, $Res Function(StorageAction_CreateRaid) _then) = _$StorageAction_CreateRaidCopyWithImpl;
@useResult
$Res call({
 String name, int level, List<String> devices
});




}
/// @nodoc
class _$StorageAction_CreateRaidCopyWithImpl<$Res>
    implements $StorageAction_CreateRaidCopyWith<$Res> {
  _$StorageAction_CreateRaidCopyWithImpl(this._self, this._then);

  final StorageAction_CreateRaid _self;
  final $Res Function(StorageAction_CreateRaid) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? level = null,Object? devices = null,}) {
  return _then(StorageAction_CreateRaid(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,devices: null == devices ? _self._devices : devices // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc


class StorageAction_AddToRaid extends StorageAction {
  const StorageAction_AddToRaid({required this.array, required this.device}): super._();
  

 final  String array;
 final  String device;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_AddToRaidCopyWith<StorageAction_AddToRaid> get copyWith => _$StorageAction_AddToRaidCopyWithImpl<StorageAction_AddToRaid>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_AddToRaid&&(identical(other.array, array) || other.array == array)&&(identical(other.device, device) || other.device == device));
}


@override
int get hashCode => Object.hash(runtimeType,array,device);

@override
String toString() {
  return 'StorageAction.addToRaid(array: $array, device: $device)';
}


}

/// @nodoc
abstract mixin class $StorageAction_AddToRaidCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_AddToRaidCopyWith(StorageAction_AddToRaid value, $Res Function(StorageAction_AddToRaid) _then) = _$StorageAction_AddToRaidCopyWithImpl;
@useResult
$Res call({
 String array, String device
});




}
/// @nodoc
class _$StorageAction_AddToRaidCopyWithImpl<$Res>
    implements $StorageAction_AddToRaidCopyWith<$Res> {
  _$StorageAction_AddToRaidCopyWithImpl(this._self, this._then);

  final StorageAction_AddToRaid _self;
  final $Res Function(StorageAction_AddToRaid) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? array = null,Object? device = null,}) {
  return _then(StorageAction_AddToRaid(
array: null == array ? _self.array : array // ignore: cast_nullable_to_non_nullable
as String,device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class StorageAction_RemoveFromRaid extends StorageAction {
  const StorageAction_RemoveFromRaid({required this.array, required this.device}): super._();
  

 final  String array;
 final  String device;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_RemoveFromRaidCopyWith<StorageAction_RemoveFromRaid> get copyWith => _$StorageAction_RemoveFromRaidCopyWithImpl<StorageAction_RemoveFromRaid>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_RemoveFromRaid&&(identical(other.array, array) || other.array == array)&&(identical(other.device, device) || other.device == device));
}


@override
int get hashCode => Object.hash(runtimeType,array,device);

@override
String toString() {
  return 'StorageAction.removeFromRaid(array: $array, device: $device)';
}


}

/// @nodoc
abstract mixin class $StorageAction_RemoveFromRaidCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_RemoveFromRaidCopyWith(StorageAction_RemoveFromRaid value, $Res Function(StorageAction_RemoveFromRaid) _then) = _$StorageAction_RemoveFromRaidCopyWithImpl;
@useResult
$Res call({
 String array, String device
});




}
/// @nodoc
class _$StorageAction_RemoveFromRaidCopyWithImpl<$Res>
    implements $StorageAction_RemoveFromRaidCopyWith<$Res> {
  _$StorageAction_RemoveFromRaidCopyWithImpl(this._self, this._then);

  final StorageAction_RemoveFromRaid _self;
  final $Res Function(StorageAction_RemoveFromRaid) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? array = null,Object? device = null,}) {
  return _then(StorageAction_RemoveFromRaid(
array: null == array ? _self.array : array // ignore: cast_nullable_to_non_nullable
as String,device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class StorageAction_DeleteRaid extends StorageAction {
  const StorageAction_DeleteRaid({required this.array}): super._();
  

 final  String array;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_DeleteRaidCopyWith<StorageAction_DeleteRaid> get copyWith => _$StorageAction_DeleteRaidCopyWithImpl<StorageAction_DeleteRaid>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_DeleteRaid&&(identical(other.array, array) || other.array == array));
}


@override
int get hashCode => Object.hash(runtimeType,array);

@override
String toString() {
  return 'StorageAction.deleteRaid(array: $array)';
}


}

/// @nodoc
abstract mixin class $StorageAction_DeleteRaidCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_DeleteRaidCopyWith(StorageAction_DeleteRaid value, $Res Function(StorageAction_DeleteRaid) _then) = _$StorageAction_DeleteRaidCopyWithImpl;
@useResult
$Res call({
 String array
});




}
/// @nodoc
class _$StorageAction_DeleteRaidCopyWithImpl<$Res>
    implements $StorageAction_DeleteRaidCopyWith<$Res> {
  _$StorageAction_DeleteRaidCopyWithImpl(this._self, this._then);

  final StorageAction_DeleteRaid _self;
  final $Res Function(StorageAction_DeleteRaid) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? array = null,}) {
  return _then(StorageAction_DeleteRaid(
array: null == array ? _self.array : array // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class StorageAction_CreatePool extends StorageAction {
  const StorageAction_CreatePool({required this.name, required this.layout, required final  List<String> devices}): _devices = devices,super._();
  

 final  String name;
 final  String layout;
 final  List<String> _devices;
 List<String> get devices {
  if (_devices is EqualUnmodifiableListView) return _devices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_devices);
}


/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_CreatePoolCopyWith<StorageAction_CreatePool> get copyWith => _$StorageAction_CreatePoolCopyWithImpl<StorageAction_CreatePool>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_CreatePool&&(identical(other.name, name) || other.name == name)&&(identical(other.layout, layout) || other.layout == layout)&&const DeepCollectionEquality().equals(other._devices, _devices));
}


@override
int get hashCode => Object.hash(runtimeType,name,layout,const DeepCollectionEquality().hash(_devices));

@override
String toString() {
  return 'StorageAction.createPool(name: $name, layout: $layout, devices: $devices)';
}


}

/// @nodoc
abstract mixin class $StorageAction_CreatePoolCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_CreatePoolCopyWith(StorageAction_CreatePool value, $Res Function(StorageAction_CreatePool) _then) = _$StorageAction_CreatePoolCopyWithImpl;
@useResult
$Res call({
 String name, String layout, List<String> devices
});




}
/// @nodoc
class _$StorageAction_CreatePoolCopyWithImpl<$Res>
    implements $StorageAction_CreatePoolCopyWith<$Res> {
  _$StorageAction_CreatePoolCopyWithImpl(this._self, this._then);

  final StorageAction_CreatePool _self;
  final $Res Function(StorageAction_CreatePool) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? layout = null,Object? devices = null,}) {
  return _then(StorageAction_CreatePool(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as String,devices: null == devices ? _self._devices : devices // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc


class StorageAction_ScrubPool extends StorageAction {
  const StorageAction_ScrubPool({required this.name}): super._();
  

 final  String name;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_ScrubPoolCopyWith<StorageAction_ScrubPool> get copyWith => _$StorageAction_ScrubPoolCopyWithImpl<StorageAction_ScrubPool>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_ScrubPool&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,name);

@override
String toString() {
  return 'StorageAction.scrubPool(name: $name)';
}


}

/// @nodoc
abstract mixin class $StorageAction_ScrubPoolCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_ScrubPoolCopyWith(StorageAction_ScrubPool value, $Res Function(StorageAction_ScrubPool) _then) = _$StorageAction_ScrubPoolCopyWithImpl;
@useResult
$Res call({
 String name
});




}
/// @nodoc
class _$StorageAction_ScrubPoolCopyWithImpl<$Res>
    implements $StorageAction_ScrubPoolCopyWith<$Res> {
  _$StorageAction_ScrubPoolCopyWithImpl(this._self, this._then);

  final StorageAction_ScrubPool _self;
  final $Res Function(StorageAction_ScrubPool) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(StorageAction_ScrubPool(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class StorageAction_DestroyPool extends StorageAction {
  const StorageAction_DestroyPool({required this.name}): super._();
  

 final  String name;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_DestroyPoolCopyWith<StorageAction_DestroyPool> get copyWith => _$StorageAction_DestroyPoolCopyWithImpl<StorageAction_DestroyPool>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_DestroyPool&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,name);

@override
String toString() {
  return 'StorageAction.destroyPool(name: $name)';
}


}

/// @nodoc
abstract mixin class $StorageAction_DestroyPoolCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_DestroyPoolCopyWith(StorageAction_DestroyPool value, $Res Function(StorageAction_DestroyPool) _then) = _$StorageAction_DestroyPoolCopyWithImpl;
@useResult
$Res call({
 String name
});




}
/// @nodoc
class _$StorageAction_DestroyPoolCopyWithImpl<$Res>
    implements $StorageAction_DestroyPoolCopyWith<$Res> {
  _$StorageAction_DestroyPoolCopyWithImpl(this._self, this._then);

  final StorageAction_DestroyPool _self;
  final $Res Function(StorageAction_DestroyPool) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(StorageAction_DestroyPool(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class StorageAction_SmartTest extends StorageAction {
  const StorageAction_SmartTest({required this.device, required this.long}): super._();
  

 final  String device;
 final  bool long;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_SmartTestCopyWith<StorageAction_SmartTest> get copyWith => _$StorageAction_SmartTestCopyWithImpl<StorageAction_SmartTest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_SmartTest&&(identical(other.device, device) || other.device == device)&&(identical(other.long, long) || other.long == long));
}


@override
int get hashCode => Object.hash(runtimeType,device,long);

@override
String toString() {
  return 'StorageAction.smartTest(device: $device, long: $long)';
}


}

/// @nodoc
abstract mixin class $StorageAction_SmartTestCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_SmartTestCopyWith(StorageAction_SmartTest value, $Res Function(StorageAction_SmartTest) _then) = _$StorageAction_SmartTestCopyWithImpl;
@useResult
$Res call({
 String device, bool long
});




}
/// @nodoc
class _$StorageAction_SmartTestCopyWithImpl<$Res>
    implements $StorageAction_SmartTestCopyWith<$Res> {
  _$StorageAction_SmartTestCopyWithImpl(this._self, this._then);

  final StorageAction_SmartTest _self;
  final $Res Function(StorageAction_SmartTest) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? device = null,Object? long = null,}) {
  return _then(StorageAction_SmartTest(
device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,long: null == long ? _self.long : long // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class StorageAction_GrowRaid extends StorageAction {
  const StorageAction_GrowRaid({required this.array, required this.device}): super._();
  

 final  String array;
 final  String device;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_GrowRaidCopyWith<StorageAction_GrowRaid> get copyWith => _$StorageAction_GrowRaidCopyWithImpl<StorageAction_GrowRaid>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_GrowRaid&&(identical(other.array, array) || other.array == array)&&(identical(other.device, device) || other.device == device));
}


@override
int get hashCode => Object.hash(runtimeType,array,device);

@override
String toString() {
  return 'StorageAction.growRaid(array: $array, device: $device)';
}


}

/// @nodoc
abstract mixin class $StorageAction_GrowRaidCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_GrowRaidCopyWith(StorageAction_GrowRaid value, $Res Function(StorageAction_GrowRaid) _then) = _$StorageAction_GrowRaidCopyWithImpl;
@useResult
$Res call({
 String array, String device
});




}
/// @nodoc
class _$StorageAction_GrowRaidCopyWithImpl<$Res>
    implements $StorageAction_GrowRaidCopyWith<$Res> {
  _$StorageAction_GrowRaidCopyWithImpl(this._self, this._then);

  final StorageAction_GrowRaid _self;
  final $Res Function(StorageAction_GrowRaid) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? array = null,Object? device = null,}) {
  return _then(StorageAction_GrowRaid(
array: null == array ? _self.array : array // ignore: cast_nullable_to_non_nullable
as String,device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class StorageAction_ExpandFilesystem extends StorageAction {
  const StorageAction_ExpandFilesystem({required this.device}): super._();
  

 final  String device;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_ExpandFilesystemCopyWith<StorageAction_ExpandFilesystem> get copyWith => _$StorageAction_ExpandFilesystemCopyWithImpl<StorageAction_ExpandFilesystem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_ExpandFilesystem&&(identical(other.device, device) || other.device == device));
}


@override
int get hashCode => Object.hash(runtimeType,device);

@override
String toString() {
  return 'StorageAction.expandFilesystem(device: $device)';
}


}

/// @nodoc
abstract mixin class $StorageAction_ExpandFilesystemCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_ExpandFilesystemCopyWith(StorageAction_ExpandFilesystem value, $Res Function(StorageAction_ExpandFilesystem) _then) = _$StorageAction_ExpandFilesystemCopyWithImpl;
@useResult
$Res call({
 String device
});




}
/// @nodoc
class _$StorageAction_ExpandFilesystemCopyWithImpl<$Res>
    implements $StorageAction_ExpandFilesystemCopyWith<$Res> {
  _$StorageAction_ExpandFilesystemCopyWithImpl(this._self, this._then);

  final StorageAction_ExpandFilesystem _self;
  final $Res Function(StorageAction_ExpandFilesystem) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? device = null,}) {
  return _then(StorageAction_ExpandFilesystem(
device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class StorageAction_AddToPool extends StorageAction {
  const StorageAction_AddToPool({required this.name, required this.layout, required final  List<String> devices}): _devices = devices,super._();
  

 final  String name;
 final  String layout;
 final  List<String> _devices;
 List<String> get devices {
  if (_devices is EqualUnmodifiableListView) return _devices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_devices);
}


/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_AddToPoolCopyWith<StorageAction_AddToPool> get copyWith => _$StorageAction_AddToPoolCopyWithImpl<StorageAction_AddToPool>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_AddToPool&&(identical(other.name, name) || other.name == name)&&(identical(other.layout, layout) || other.layout == layout)&&const DeepCollectionEquality().equals(other._devices, _devices));
}


@override
int get hashCode => Object.hash(runtimeType,name,layout,const DeepCollectionEquality().hash(_devices));

@override
String toString() {
  return 'StorageAction.addToPool(name: $name, layout: $layout, devices: $devices)';
}


}

/// @nodoc
abstract mixin class $StorageAction_AddToPoolCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_AddToPoolCopyWith(StorageAction_AddToPool value, $Res Function(StorageAction_AddToPool) _then) = _$StorageAction_AddToPoolCopyWithImpl;
@useResult
$Res call({
 String name, String layout, List<String> devices
});




}
/// @nodoc
class _$StorageAction_AddToPoolCopyWithImpl<$Res>
    implements $StorageAction_AddToPoolCopyWith<$Res> {
  _$StorageAction_AddToPoolCopyWithImpl(this._self, this._then);

  final StorageAction_AddToPool _self;
  final $Res Function(StorageAction_AddToPool) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? layout = null,Object? devices = null,}) {
  return _then(StorageAction_AddToPool(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as String,devices: null == devices ? _self._devices : devices // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc


class StorageAction_ReplaceInPool extends StorageAction {
  const StorageAction_ReplaceInPool({required this.name, required this.old, required this.new_}): super._();
  

 final  String name;
 final  String old;
 final  String new_;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_ReplaceInPoolCopyWith<StorageAction_ReplaceInPool> get copyWith => _$StorageAction_ReplaceInPoolCopyWithImpl<StorageAction_ReplaceInPool>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_ReplaceInPool&&(identical(other.name, name) || other.name == name)&&(identical(other.old, old) || other.old == old)&&(identical(other.new_, new_) || other.new_ == new_));
}


@override
int get hashCode => Object.hash(runtimeType,name,old,new_);

@override
String toString() {
  return 'StorageAction.replaceInPool(name: $name, old: $old, new_: $new_)';
}


}

/// @nodoc
abstract mixin class $StorageAction_ReplaceInPoolCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_ReplaceInPoolCopyWith(StorageAction_ReplaceInPool value, $Res Function(StorageAction_ReplaceInPool) _then) = _$StorageAction_ReplaceInPoolCopyWithImpl;
@useResult
$Res call({
 String name, String old, String new_
});




}
/// @nodoc
class _$StorageAction_ReplaceInPoolCopyWithImpl<$Res>
    implements $StorageAction_ReplaceInPoolCopyWith<$Res> {
  _$StorageAction_ReplaceInPoolCopyWithImpl(this._self, this._then);

  final StorageAction_ReplaceInPool _self;
  final $Res Function(StorageAction_ReplaceInPool) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? old = null,Object? new_ = null,}) {
  return _then(StorageAction_ReplaceInPool(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,old: null == old ? _self.old : old // ignore: cast_nullable_to_non_nullable
as String,new_: null == new_ ? _self.new_ : new_ // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class StorageAction_AttachToPool extends StorageAction {
  const StorageAction_AttachToPool({required this.name, required this.existing, required this.new_}): super._();
  

 final  String name;
 final  String existing;
 final  String new_;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_AttachToPoolCopyWith<StorageAction_AttachToPool> get copyWith => _$StorageAction_AttachToPoolCopyWithImpl<StorageAction_AttachToPool>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_AttachToPool&&(identical(other.name, name) || other.name == name)&&(identical(other.existing, existing) || other.existing == existing)&&(identical(other.new_, new_) || other.new_ == new_));
}


@override
int get hashCode => Object.hash(runtimeType,name,existing,new_);

@override
String toString() {
  return 'StorageAction.attachToPool(name: $name, existing: $existing, new_: $new_)';
}


}

/// @nodoc
abstract mixin class $StorageAction_AttachToPoolCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_AttachToPoolCopyWith(StorageAction_AttachToPool value, $Res Function(StorageAction_AttachToPool) _then) = _$StorageAction_AttachToPoolCopyWithImpl;
@useResult
$Res call({
 String name, String existing, String new_
});




}
/// @nodoc
class _$StorageAction_AttachToPoolCopyWithImpl<$Res>
    implements $StorageAction_AttachToPoolCopyWith<$Res> {
  _$StorageAction_AttachToPoolCopyWithImpl(this._self, this._then);

  final StorageAction_AttachToPool _self;
  final $Res Function(StorageAction_AttachToPool) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? existing = null,Object? new_ = null,}) {
  return _then(StorageAction_AttachToPool(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,existing: null == existing ? _self.existing : existing // ignore: cast_nullable_to_non_nullable
as String,new_: null == new_ ? _self.new_ : new_ // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class StorageAction_AddSpare extends StorageAction {
  const StorageAction_AddSpare({required this.name, required final  List<String> devices}): _devices = devices,super._();
  

 final  String name;
 final  List<String> _devices;
 List<String> get devices {
  if (_devices is EqualUnmodifiableListView) return _devices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_devices);
}


/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_AddSpareCopyWith<StorageAction_AddSpare> get copyWith => _$StorageAction_AddSpareCopyWithImpl<StorageAction_AddSpare>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_AddSpare&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other._devices, _devices));
}


@override
int get hashCode => Object.hash(runtimeType,name,const DeepCollectionEquality().hash(_devices));

@override
String toString() {
  return 'StorageAction.addSpare(name: $name, devices: $devices)';
}


}

/// @nodoc
abstract mixin class $StorageAction_AddSpareCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_AddSpareCopyWith(StorageAction_AddSpare value, $Res Function(StorageAction_AddSpare) _then) = _$StorageAction_AddSpareCopyWithImpl;
@useResult
$Res call({
 String name, List<String> devices
});




}
/// @nodoc
class _$StorageAction_AddSpareCopyWithImpl<$Res>
    implements $StorageAction_AddSpareCopyWith<$Res> {
  _$StorageAction_AddSpareCopyWithImpl(this._self, this._then);

  final StorageAction_AddSpare _self;
  final $Res Function(StorageAction_AddSpare) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? devices = null,}) {
  return _then(StorageAction_AddSpare(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,devices: null == devices ? _self._devices : devices // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc


class StorageAction_RemoveFromPool extends StorageAction {
  const StorageAction_RemoveFromPool({required this.name, required this.device}): super._();
  

 final  String name;
 final  String device;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_RemoveFromPoolCopyWith<StorageAction_RemoveFromPool> get copyWith => _$StorageAction_RemoveFromPoolCopyWithImpl<StorageAction_RemoveFromPool>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_RemoveFromPool&&(identical(other.name, name) || other.name == name)&&(identical(other.device, device) || other.device == device));
}


@override
int get hashCode => Object.hash(runtimeType,name,device);

@override
String toString() {
  return 'StorageAction.removeFromPool(name: $name, device: $device)';
}


}

/// @nodoc
abstract mixin class $StorageAction_RemoveFromPoolCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_RemoveFromPoolCopyWith(StorageAction_RemoveFromPool value, $Res Function(StorageAction_RemoveFromPool) _then) = _$StorageAction_RemoveFromPoolCopyWithImpl;
@useResult
$Res call({
 String name, String device
});




}
/// @nodoc
class _$StorageAction_RemoveFromPoolCopyWithImpl<$Res>
    implements $StorageAction_RemoveFromPoolCopyWith<$Res> {
  _$StorageAction_RemoveFromPoolCopyWithImpl(this._self, this._then);

  final StorageAction_RemoveFromPool _self;
  final $Res Function(StorageAction_RemoveFromPool) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? device = null,}) {
  return _then(StorageAction_RemoveFromPool(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class StorageAction_OnlineInPool extends StorageAction {
  const StorageAction_OnlineInPool({required this.name, required this.device}): super._();
  

 final  String name;
 final  String device;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_OnlineInPoolCopyWith<StorageAction_OnlineInPool> get copyWith => _$StorageAction_OnlineInPoolCopyWithImpl<StorageAction_OnlineInPool>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_OnlineInPool&&(identical(other.name, name) || other.name == name)&&(identical(other.device, device) || other.device == device));
}


@override
int get hashCode => Object.hash(runtimeType,name,device);

@override
String toString() {
  return 'StorageAction.onlineInPool(name: $name, device: $device)';
}


}

/// @nodoc
abstract mixin class $StorageAction_OnlineInPoolCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_OnlineInPoolCopyWith(StorageAction_OnlineInPool value, $Res Function(StorageAction_OnlineInPool) _then) = _$StorageAction_OnlineInPoolCopyWithImpl;
@useResult
$Res call({
 String name, String device
});




}
/// @nodoc
class _$StorageAction_OnlineInPoolCopyWithImpl<$Res>
    implements $StorageAction_OnlineInPoolCopyWith<$Res> {
  _$StorageAction_OnlineInPoolCopyWithImpl(this._self, this._then);

  final StorageAction_OnlineInPool _self;
  final $Res Function(StorageAction_OnlineInPool) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? device = null,}) {
  return _then(StorageAction_OnlineInPool(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class StorageAction_GrowPartition extends StorageAction {
  const StorageAction_GrowPartition({required this.device}): super._();
  

 final  String device;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_GrowPartitionCopyWith<StorageAction_GrowPartition> get copyWith => _$StorageAction_GrowPartitionCopyWithImpl<StorageAction_GrowPartition>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_GrowPartition&&(identical(other.device, device) || other.device == device));
}


@override
int get hashCode => Object.hash(runtimeType,device);

@override
String toString() {
  return 'StorageAction.growPartition(device: $device)';
}


}

/// @nodoc
abstract mixin class $StorageAction_GrowPartitionCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_GrowPartitionCopyWith(StorageAction_GrowPartition value, $Res Function(StorageAction_GrowPartition) _then) = _$StorageAction_GrowPartitionCopyWithImpl;
@useResult
$Res call({
 String device
});




}
/// @nodoc
class _$StorageAction_GrowPartitionCopyWithImpl<$Res>
    implements $StorageAction_GrowPartitionCopyWith<$Res> {
  _$StorageAction_GrowPartitionCopyWithImpl(this._self, this._then);

  final StorageAction_GrowPartition _self;
  final $Res Function(StorageAction_GrowPartition) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? device = null,}) {
  return _then(StorageAction_GrowPartition(
device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class StorageAction_Unlock extends StorageAction {
  const StorageAction_Unlock({required this.device}): super._();
  

 final  String device;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_UnlockCopyWith<StorageAction_Unlock> get copyWith => _$StorageAction_UnlockCopyWithImpl<StorageAction_Unlock>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_Unlock&&(identical(other.device, device) || other.device == device));
}


@override
int get hashCode => Object.hash(runtimeType,device);

@override
String toString() {
  return 'StorageAction.unlock(device: $device)';
}


}

/// @nodoc
abstract mixin class $StorageAction_UnlockCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_UnlockCopyWith(StorageAction_Unlock value, $Res Function(StorageAction_Unlock) _then) = _$StorageAction_UnlockCopyWithImpl;
@useResult
$Res call({
 String device
});




}
/// @nodoc
class _$StorageAction_UnlockCopyWithImpl<$Res>
    implements $StorageAction_UnlockCopyWith<$Res> {
  _$StorageAction_UnlockCopyWithImpl(this._self, this._then);

  final StorageAction_Unlock _self;
  final $Res Function(StorageAction_Unlock) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? device = null,}) {
  return _then(StorageAction_Unlock(
device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class StorageAction_Lock extends StorageAction {
  const StorageAction_Lock({required this.device}): super._();
  

 final  String device;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageAction_LockCopyWith<StorageAction_Lock> get copyWith => _$StorageAction_LockCopyWithImpl<StorageAction_Lock>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageAction_Lock&&(identical(other.device, device) || other.device == device));
}


@override
int get hashCode => Object.hash(runtimeType,device);

@override
String toString() {
  return 'StorageAction.lock(device: $device)';
}


}

/// @nodoc
abstract mixin class $StorageAction_LockCopyWith<$Res> implements $StorageActionCopyWith<$Res> {
  factory $StorageAction_LockCopyWith(StorageAction_Lock value, $Res Function(StorageAction_Lock) _then) = _$StorageAction_LockCopyWithImpl;
@useResult
$Res call({
 String device
});




}
/// @nodoc
class _$StorageAction_LockCopyWithImpl<$Res>
    implements $StorageAction_LockCopyWith<$Res> {
  _$StorageAction_LockCopyWithImpl(this._self, this._then);

  final StorageAction_Lock _self;
  final $Res Function(StorageAction_Lock) _then;

/// Create a copy of StorageAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? device = null,}) {
  return _then(StorageAction_Lock(
device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
