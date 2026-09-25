// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'virt_resources.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VirtGuestSnapshot {

 String get name;/// The snapshot this one was taken on top of; null for a root.
 String? get parent; String? get description; DateTime? get createdAt;/// What the guest's disks were last created from or reverted to: the one
/// a new snapshot would have as its parent.
 bool get current;/// Holds the guest's memory: reverting resumes it where it was. Without,
/// reverting leaves the guest stopped.
 bool get withMemory;
/// Create a copy of VirtGuestSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtGuestSnapshotCopyWith<VirtGuestSnapshot> get copyWith => _$VirtGuestSnapshotCopyWithImpl<VirtGuestSnapshot>(this as VirtGuestSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtGuestSnapshot&&(identical(other.name, name) || other.name == name)&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.description, description) || other.description == description)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.current, current) || other.current == current)&&(identical(other.withMemory, withMemory) || other.withMemory == withMemory));
}


@override
int get hashCode => Object.hash(runtimeType,name,parent,description,createdAt,current,withMemory);

@override
String toString() {
  return 'VirtGuestSnapshot(name: $name, parent: $parent, description: $description, createdAt: $createdAt, current: $current, withMemory: $withMemory)';
}


}

/// @nodoc
abstract mixin class $VirtGuestSnapshotCopyWith<$Res>  {
  factory $VirtGuestSnapshotCopyWith(VirtGuestSnapshot value, $Res Function(VirtGuestSnapshot) _then) = _$VirtGuestSnapshotCopyWithImpl;
@useResult
$Res call({
 String name, String? parent, String? description, DateTime? createdAt, bool current, bool withMemory
});




}
/// @nodoc
class _$VirtGuestSnapshotCopyWithImpl<$Res>
    implements $VirtGuestSnapshotCopyWith<$Res> {
  _$VirtGuestSnapshotCopyWithImpl(this._self, this._then);

  final VirtGuestSnapshot _self;
  final $Res Function(VirtGuestSnapshot) _then;

/// Create a copy of VirtGuestSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? parent = freezed,Object? description = freezed,Object? createdAt = freezed,Object? current = null,Object? withMemory = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,parent: freezed == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,withMemory: null == withMemory ? _self.withMemory : withMemory // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtGuestSnapshot].
extension VirtGuestSnapshotPatterns on VirtGuestSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtGuestSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtGuestSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtGuestSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _VirtGuestSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtGuestSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _VirtGuestSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? parent,  String? description,  DateTime? createdAt,  bool current,  bool withMemory)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtGuestSnapshot() when $default != null:
return $default(_that.name,_that.parent,_that.description,_that.createdAt,_that.current,_that.withMemory);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? parent,  String? description,  DateTime? createdAt,  bool current,  bool withMemory)  $default,) {final _that = this;
switch (_that) {
case _VirtGuestSnapshot():
return $default(_that.name,_that.parent,_that.description,_that.createdAt,_that.current,_that.withMemory);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? parent,  String? description,  DateTime? createdAt,  bool current,  bool withMemory)?  $default,) {final _that = this;
switch (_that) {
case _VirtGuestSnapshot() when $default != null:
return $default(_that.name,_that.parent,_that.description,_that.createdAt,_that.current,_that.withMemory);case _:
  return null;

}
}

}

/// @nodoc


class _VirtGuestSnapshot implements VirtGuestSnapshot {
  const _VirtGuestSnapshot({required this.name, this.parent, this.description, this.createdAt, this.current = false, this.withMemory = false});
  

@override final  String name;
/// The snapshot this one was taken on top of; null for a root.
@override final  String? parent;
@override final  String? description;
@override final  DateTime? createdAt;
/// What the guest's disks were last created from or reverted to: the one
/// a new snapshot would have as its parent.
@override@JsonKey() final  bool current;
/// Holds the guest's memory: reverting resumes it where it was. Without,
/// reverting leaves the guest stopped.
@override@JsonKey() final  bool withMemory;

/// Create a copy of VirtGuestSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtGuestSnapshotCopyWith<_VirtGuestSnapshot> get copyWith => __$VirtGuestSnapshotCopyWithImpl<_VirtGuestSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtGuestSnapshot&&(identical(other.name, name) || other.name == name)&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.description, description) || other.description == description)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.current, current) || other.current == current)&&(identical(other.withMemory, withMemory) || other.withMemory == withMemory));
}


@override
int get hashCode => Object.hash(runtimeType,name,parent,description,createdAt,current,withMemory);

@override
String toString() {
  return 'VirtGuestSnapshot(name: $name, parent: $parent, description: $description, createdAt: $createdAt, current: $current, withMemory: $withMemory)';
}


}

/// @nodoc
abstract mixin class _$VirtGuestSnapshotCopyWith<$Res> implements $VirtGuestSnapshotCopyWith<$Res> {
  factory _$VirtGuestSnapshotCopyWith(_VirtGuestSnapshot value, $Res Function(_VirtGuestSnapshot) _then) = __$VirtGuestSnapshotCopyWithImpl;
@override @useResult
$Res call({
 String name, String? parent, String? description, DateTime? createdAt, bool current, bool withMemory
});




}
/// @nodoc
class __$VirtGuestSnapshotCopyWithImpl<$Res>
    implements _$VirtGuestSnapshotCopyWith<$Res> {
  __$VirtGuestSnapshotCopyWithImpl(this._self, this._then);

  final _VirtGuestSnapshot _self;
  final $Res Function(_VirtGuestSnapshot) _then;

/// Create a copy of VirtGuestSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? parent = freezed,Object? description = freezed,Object? createdAt = freezed,Object? current = null,Object? withMemory = null,}) {
  return _then(_VirtGuestSnapshot(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,parent: freezed == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,withMemory: null == withMemory ? _self.withMemory : withMemory // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$VirtGuestRef {

 String? get guestId; int? get vmid;/// How it uses the thing: the disk's target (`vda`, `scsi0`), the NIC's
/// key or host device.
 String? get device;/// What else is known: its MAC and address on a network.
 String? get mac; String? get ip;
/// Create a copy of VirtGuestRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtGuestRefCopyWith<VirtGuestRef> get copyWith => _$VirtGuestRefCopyWithImpl<VirtGuestRef>(this as VirtGuestRef, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtGuestRef&&(identical(other.guestId, guestId) || other.guestId == guestId)&&(identical(other.vmid, vmid) || other.vmid == vmid)&&(identical(other.device, device) || other.device == device)&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.ip, ip) || other.ip == ip));
}


@override
int get hashCode => Object.hash(runtimeType,guestId,vmid,device,mac,ip);

@override
String toString() {
  return 'VirtGuestRef(guestId: $guestId, vmid: $vmid, device: $device, mac: $mac, ip: $ip)';
}


}

/// @nodoc
abstract mixin class $VirtGuestRefCopyWith<$Res>  {
  factory $VirtGuestRefCopyWith(VirtGuestRef value, $Res Function(VirtGuestRef) _then) = _$VirtGuestRefCopyWithImpl;
@useResult
$Res call({
 String? guestId, int? vmid, String? device, String? mac, String? ip
});




}
/// @nodoc
class _$VirtGuestRefCopyWithImpl<$Res>
    implements $VirtGuestRefCopyWith<$Res> {
  _$VirtGuestRefCopyWithImpl(this._self, this._then);

  final VirtGuestRef _self;
  final $Res Function(VirtGuestRef) _then;

/// Create a copy of VirtGuestRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? guestId = freezed,Object? vmid = freezed,Object? device = freezed,Object? mac = freezed,Object? ip = freezed,}) {
  return _then(_self.copyWith(
guestId: freezed == guestId ? _self.guestId : guestId // ignore: cast_nullable_to_non_nullable
as String?,vmid: freezed == vmid ? _self.vmid : vmid // ignore: cast_nullable_to_non_nullable
as int?,device: freezed == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String?,mac: freezed == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String?,ip: freezed == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtGuestRef].
extension VirtGuestRefPatterns on VirtGuestRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtGuestRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtGuestRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtGuestRef value)  $default,){
final _that = this;
switch (_that) {
case _VirtGuestRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtGuestRef value)?  $default,){
final _that = this;
switch (_that) {
case _VirtGuestRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? guestId,  int? vmid,  String? device,  String? mac,  String? ip)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtGuestRef() when $default != null:
return $default(_that.guestId,_that.vmid,_that.device,_that.mac,_that.ip);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? guestId,  int? vmid,  String? device,  String? mac,  String? ip)  $default,) {final _that = this;
switch (_that) {
case _VirtGuestRef():
return $default(_that.guestId,_that.vmid,_that.device,_that.mac,_that.ip);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? guestId,  int? vmid,  String? device,  String? mac,  String? ip)?  $default,) {final _that = this;
switch (_that) {
case _VirtGuestRef() when $default != null:
return $default(_that.guestId,_that.vmid,_that.device,_that.mac,_that.ip);case _:
  return null;

}
}

}

/// @nodoc


class _VirtGuestRef implements VirtGuestRef {
  const _VirtGuestRef({this.guestId, this.vmid, this.device, this.mac, this.ip});
  

@override final  String? guestId;
@override final  int? vmid;
/// How it uses the thing: the disk's target (`vda`, `scsi0`), the NIC's
/// key or host device.
@override final  String? device;
/// What else is known: its MAC and address on a network.
@override final  String? mac;
@override final  String? ip;

/// Create a copy of VirtGuestRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtGuestRefCopyWith<_VirtGuestRef> get copyWith => __$VirtGuestRefCopyWithImpl<_VirtGuestRef>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtGuestRef&&(identical(other.guestId, guestId) || other.guestId == guestId)&&(identical(other.vmid, vmid) || other.vmid == vmid)&&(identical(other.device, device) || other.device == device)&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.ip, ip) || other.ip == ip));
}


@override
int get hashCode => Object.hash(runtimeType,guestId,vmid,device,mac,ip);

@override
String toString() {
  return 'VirtGuestRef(guestId: $guestId, vmid: $vmid, device: $device, mac: $mac, ip: $ip)';
}


}

/// @nodoc
abstract mixin class _$VirtGuestRefCopyWith<$Res> implements $VirtGuestRefCopyWith<$Res> {
  factory _$VirtGuestRefCopyWith(_VirtGuestRef value, $Res Function(_VirtGuestRef) _then) = __$VirtGuestRefCopyWithImpl;
@override @useResult
$Res call({
 String? guestId, int? vmid, String? device, String? mac, String? ip
});




}
/// @nodoc
class __$VirtGuestRefCopyWithImpl<$Res>
    implements _$VirtGuestRefCopyWith<$Res> {
  __$VirtGuestRefCopyWithImpl(this._self, this._then);

  final _VirtGuestRef _self;
  final $Res Function(_VirtGuestRef) _then;

/// Create a copy of VirtGuestRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? guestId = freezed,Object? vmid = freezed,Object? device = freezed,Object? mac = freezed,Object? ip = freezed,}) {
  return _then(_VirtGuestRef(
guestId: freezed == guestId ? _self.guestId : guestId // ignore: cast_nullable_to_non_nullable
as String?,vmid: freezed == vmid ? _self.vmid : vmid // ignore: cast_nullable_to_non_nullable
as int?,device: freezed == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String?,mac: freezed == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String?,ip: freezed == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$VirtStoragePool {

/// Unique on the host: libvirt's pool name, PVE `<node>/<storage>`.
 String get id; String get name;/// The PVE node it is listed for; storage is per node there.
 String? get node;/// `dir`, `logical`, `netfs`, ... (libvirt); `dir`, `lvmthin`, `zfspool`,
/// `nfs`, ... (PVE).
 String get type;/// Where volumes live: a directory, a volume group, a thin pool.
 String? get path;/// Where the pool comes from: `host:/export`, a device.
 String? get source; int? get capacity; int? get used; int? get available; bool get active;/// Started with the host (libvirt).
 bool? get autostart;/// Configured on (PVE `enabled`).
 bool? get enabled;/// Shared between PVE nodes.
 bool? get shared;/// What PVE allows in it: `images`, `rootdir`, `iso`, `vztmpl`,
/// `backup`, `snippets`, `import`.
 List<String> get content;/// Volumes in it, when listing the pools already says.
 int? get volumeCount;
/// Create a copy of VirtStoragePool
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtStoragePoolCopyWith<VirtStoragePool> get copyWith => _$VirtStoragePoolCopyWithImpl<VirtStoragePool>(this as VirtStoragePool, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtStoragePool&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.node, node) || other.node == node)&&(identical(other.type, type) || other.type == type)&&(identical(other.path, path) || other.path == path)&&(identical(other.source, source) || other.source == source)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.used, used) || other.used == used)&&(identical(other.available, available) || other.available == available)&&(identical(other.active, active) || other.active == active)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.shared, shared) || other.shared == shared)&&const DeepCollectionEquality().equals(other.content, content)&&(identical(other.volumeCount, volumeCount) || other.volumeCount == volumeCount));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,node,type,path,source,capacity,used,available,active,autostart,enabled,shared,const DeepCollectionEquality().hash(content),volumeCount);

@override
String toString() {
  return 'VirtStoragePool(id: $id, name: $name, node: $node, type: $type, path: $path, source: $source, capacity: $capacity, used: $used, available: $available, active: $active, autostart: $autostart, enabled: $enabled, shared: $shared, content: $content, volumeCount: $volumeCount)';
}


}

/// @nodoc
abstract mixin class $VirtStoragePoolCopyWith<$Res>  {
  factory $VirtStoragePoolCopyWith(VirtStoragePool value, $Res Function(VirtStoragePool) _then) = _$VirtStoragePoolCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? node, String type, String? path, String? source, int? capacity, int? used, int? available, bool active, bool? autostart, bool? enabled, bool? shared, List<String> content, int? volumeCount
});




}
/// @nodoc
class _$VirtStoragePoolCopyWithImpl<$Res>
    implements $VirtStoragePoolCopyWith<$Res> {
  _$VirtStoragePoolCopyWithImpl(this._self, this._then);

  final VirtStoragePool _self;
  final $Res Function(VirtStoragePool) _then;

/// Create a copy of VirtStoragePool
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? node = freezed,Object? type = null,Object? path = freezed,Object? source = freezed,Object? capacity = freezed,Object? used = freezed,Object? available = freezed,Object? active = null,Object? autostart = freezed,Object? enabled = freezed,Object? shared = freezed,Object? content = null,Object? volumeCount = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,node: freezed == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,used: freezed == used ? _self.used : used // ignore: cast_nullable_to_non_nullable
as int?,available: freezed == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as int?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,autostart: freezed == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool?,enabled: freezed == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool?,shared: freezed == shared ? _self.shared : shared // ignore: cast_nullable_to_non_nullable
as bool?,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as List<String>,volumeCount: freezed == volumeCount ? _self.volumeCount : volumeCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtStoragePool].
extension VirtStoragePoolPatterns on VirtStoragePool {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtStoragePool value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtStoragePool() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtStoragePool value)  $default,){
final _that = this;
switch (_that) {
case _VirtStoragePool():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtStoragePool value)?  $default,){
final _that = this;
switch (_that) {
case _VirtStoragePool() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? node,  String type,  String? path,  String? source,  int? capacity,  int? used,  int? available,  bool active,  bool? autostart,  bool? enabled,  bool? shared,  List<String> content,  int? volumeCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtStoragePool() when $default != null:
return $default(_that.id,_that.name,_that.node,_that.type,_that.path,_that.source,_that.capacity,_that.used,_that.available,_that.active,_that.autostart,_that.enabled,_that.shared,_that.content,_that.volumeCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? node,  String type,  String? path,  String? source,  int? capacity,  int? used,  int? available,  bool active,  bool? autostart,  bool? enabled,  bool? shared,  List<String> content,  int? volumeCount)  $default,) {final _that = this;
switch (_that) {
case _VirtStoragePool():
return $default(_that.id,_that.name,_that.node,_that.type,_that.path,_that.source,_that.capacity,_that.used,_that.available,_that.active,_that.autostart,_that.enabled,_that.shared,_that.content,_that.volumeCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? node,  String type,  String? path,  String? source,  int? capacity,  int? used,  int? available,  bool active,  bool? autostart,  bool? enabled,  bool? shared,  List<String> content,  int? volumeCount)?  $default,) {final _that = this;
switch (_that) {
case _VirtStoragePool() when $default != null:
return $default(_that.id,_that.name,_that.node,_that.type,_that.path,_that.source,_that.capacity,_that.used,_that.available,_that.active,_that.autostart,_that.enabled,_that.shared,_that.content,_that.volumeCount);case _:
  return null;

}
}

}

/// @nodoc


class _VirtStoragePool extends VirtStoragePool {
  const _VirtStoragePool({required this.id, required this.name, this.node, required this.type, this.path, this.source, this.capacity, this.used, this.available, this.active = true, this.autostart, this.enabled, this.shared, final  List<String> content = const <String>[], this.volumeCount}): _content = content,super._();
  

/// Unique on the host: libvirt's pool name, PVE `<node>/<storage>`.
@override final  String id;
@override final  String name;
/// The PVE node it is listed for; storage is per node there.
@override final  String? node;
/// `dir`, `logical`, `netfs`, ... (libvirt); `dir`, `lvmthin`, `zfspool`,
/// `nfs`, ... (PVE).
@override final  String type;
/// Where volumes live: a directory, a volume group, a thin pool.
@override final  String? path;
/// Where the pool comes from: `host:/export`, a device.
@override final  String? source;
@override final  int? capacity;
@override final  int? used;
@override final  int? available;
@override@JsonKey() final  bool active;
/// Started with the host (libvirt).
@override final  bool? autostart;
/// Configured on (PVE `enabled`).
@override final  bool? enabled;
/// Shared between PVE nodes.
@override final  bool? shared;
/// What PVE allows in it: `images`, `rootdir`, `iso`, `vztmpl`,
/// `backup`, `snippets`, `import`.
 final  List<String> _content;
/// What PVE allows in it: `images`, `rootdir`, `iso`, `vztmpl`,
/// `backup`, `snippets`, `import`.
@override@JsonKey() List<String> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

/// Volumes in it, when listing the pools already says.
@override final  int? volumeCount;

/// Create a copy of VirtStoragePool
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtStoragePoolCopyWith<_VirtStoragePool> get copyWith => __$VirtStoragePoolCopyWithImpl<_VirtStoragePool>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtStoragePool&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.node, node) || other.node == node)&&(identical(other.type, type) || other.type == type)&&(identical(other.path, path) || other.path == path)&&(identical(other.source, source) || other.source == source)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.used, used) || other.used == used)&&(identical(other.available, available) || other.available == available)&&(identical(other.active, active) || other.active == active)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.shared, shared) || other.shared == shared)&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.volumeCount, volumeCount) || other.volumeCount == volumeCount));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,node,type,path,source,capacity,used,available,active,autostart,enabled,shared,const DeepCollectionEquality().hash(_content),volumeCount);

@override
String toString() {
  return 'VirtStoragePool(id: $id, name: $name, node: $node, type: $type, path: $path, source: $source, capacity: $capacity, used: $used, available: $available, active: $active, autostart: $autostart, enabled: $enabled, shared: $shared, content: $content, volumeCount: $volumeCount)';
}


}

/// @nodoc
abstract mixin class _$VirtStoragePoolCopyWith<$Res> implements $VirtStoragePoolCopyWith<$Res> {
  factory _$VirtStoragePoolCopyWith(_VirtStoragePool value, $Res Function(_VirtStoragePool) _then) = __$VirtStoragePoolCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? node, String type, String? path, String? source, int? capacity, int? used, int? available, bool active, bool? autostart, bool? enabled, bool? shared, List<String> content, int? volumeCount
});




}
/// @nodoc
class __$VirtStoragePoolCopyWithImpl<$Res>
    implements _$VirtStoragePoolCopyWith<$Res> {
  __$VirtStoragePoolCopyWithImpl(this._self, this._then);

  final _VirtStoragePool _self;
  final $Res Function(_VirtStoragePool) _then;

/// Create a copy of VirtStoragePool
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? node = freezed,Object? type = null,Object? path = freezed,Object? source = freezed,Object? capacity = freezed,Object? used = freezed,Object? available = freezed,Object? active = null,Object? autostart = freezed,Object? enabled = freezed,Object? shared = freezed,Object? content = null,Object? volumeCount = freezed,}) {
  return _then(_VirtStoragePool(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,node: freezed == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,used: freezed == used ? _self.used : used // ignore: cast_nullable_to_non_nullable
as int?,available: freezed == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as int?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,autostart: freezed == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool?,enabled: freezed == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool?,shared: freezed == shared ? _self.shared : shared // ignore: cast_nullable_to_non_nullable
as bool?,content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<String>,volumeCount: freezed == volumeCount ? _self.volumeCount : volumeCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$VirtVolume {

/// libvirt's volume name; PVE's `volid` (`local-lvm:vm-100-disk-0`).
 String get id; String get name; String? get path;/// `qcow2`, `raw`, `iso`, `tzst`, ...
 String? get format;/// PVE's content kind: `images`, `rootdir`, `iso`, `vztmpl`, `backup`.
 String? get content;/// Bytes the guest sees.
 int? get capacity;/// Bytes it takes on the host, where the host says.
 int? get allocation;/// A qcow2 overlay's backing file (libvirt).
 String? get backing; DateTime? get createdAt; List<VirtGuestRef> get users;
/// Create a copy of VirtVolume
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtVolumeCopyWith<VirtVolume> get copyWith => _$VirtVolumeCopyWithImpl<VirtVolume>(this as VirtVolume, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtVolume&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&(identical(other.format, format) || other.format == format)&&(identical(other.content, content) || other.content == content)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.allocation, allocation) || other.allocation == allocation)&&(identical(other.backing, backing) || other.backing == backing)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other.users, users));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,path,format,content,capacity,allocation,backing,createdAt,const DeepCollectionEquality().hash(users));

@override
String toString() {
  return 'VirtVolume(id: $id, name: $name, path: $path, format: $format, content: $content, capacity: $capacity, allocation: $allocation, backing: $backing, createdAt: $createdAt, users: $users)';
}


}

/// @nodoc
abstract mixin class $VirtVolumeCopyWith<$Res>  {
  factory $VirtVolumeCopyWith(VirtVolume value, $Res Function(VirtVolume) _then) = _$VirtVolumeCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? path, String? format, String? content, int? capacity, int? allocation, String? backing, DateTime? createdAt, List<VirtGuestRef> users
});




}
/// @nodoc
class _$VirtVolumeCopyWithImpl<$Res>
    implements $VirtVolumeCopyWith<$Res> {
  _$VirtVolumeCopyWithImpl(this._self, this._then);

  final VirtVolume _self;
  final $Res Function(VirtVolume) _then;

/// Create a copy of VirtVolume
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? path = freezed,Object? format = freezed,Object? content = freezed,Object? capacity = freezed,Object? allocation = freezed,Object? backing = freezed,Object? createdAt = freezed,Object? users = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,allocation: freezed == allocation ? _self.allocation : allocation // ignore: cast_nullable_to_non_nullable
as int?,backing: freezed == backing ? _self.backing : backing // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,users: null == users ? _self.users : users // ignore: cast_nullable_to_non_nullable
as List<VirtGuestRef>,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtVolume].
extension VirtVolumePatterns on VirtVolume {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtVolume value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtVolume() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtVolume value)  $default,){
final _that = this;
switch (_that) {
case _VirtVolume():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtVolume value)?  $default,){
final _that = this;
switch (_that) {
case _VirtVolume() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? path,  String? format,  String? content,  int? capacity,  int? allocation,  String? backing,  DateTime? createdAt,  List<VirtGuestRef> users)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtVolume() when $default != null:
return $default(_that.id,_that.name,_that.path,_that.format,_that.content,_that.capacity,_that.allocation,_that.backing,_that.createdAt,_that.users);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? path,  String? format,  String? content,  int? capacity,  int? allocation,  String? backing,  DateTime? createdAt,  List<VirtGuestRef> users)  $default,) {final _that = this;
switch (_that) {
case _VirtVolume():
return $default(_that.id,_that.name,_that.path,_that.format,_that.content,_that.capacity,_that.allocation,_that.backing,_that.createdAt,_that.users);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? path,  String? format,  String? content,  int? capacity,  int? allocation,  String? backing,  DateTime? createdAt,  List<VirtGuestRef> users)?  $default,) {final _that = this;
switch (_that) {
case _VirtVolume() when $default != null:
return $default(_that.id,_that.name,_that.path,_that.format,_that.content,_that.capacity,_that.allocation,_that.backing,_that.createdAt,_that.users);case _:
  return null;

}
}

}

/// @nodoc


class _VirtVolume implements VirtVolume {
  const _VirtVolume({required this.id, required this.name, this.path, this.format, this.content, this.capacity, this.allocation, this.backing, this.createdAt, final  List<VirtGuestRef> users = const <VirtGuestRef>[]}): _users = users;
  

/// libvirt's volume name; PVE's `volid` (`local-lvm:vm-100-disk-0`).
@override final  String id;
@override final  String name;
@override final  String? path;
/// `qcow2`, `raw`, `iso`, `tzst`, ...
@override final  String? format;
/// PVE's content kind: `images`, `rootdir`, `iso`, `vztmpl`, `backup`.
@override final  String? content;
/// Bytes the guest sees.
@override final  int? capacity;
/// Bytes it takes on the host, where the host says.
@override final  int? allocation;
/// A qcow2 overlay's backing file (libvirt).
@override final  String? backing;
@override final  DateTime? createdAt;
 final  List<VirtGuestRef> _users;
@override@JsonKey() List<VirtGuestRef> get users {
  if (_users is EqualUnmodifiableListView) return _users;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_users);
}


/// Create a copy of VirtVolume
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtVolumeCopyWith<_VirtVolume> get copyWith => __$VirtVolumeCopyWithImpl<_VirtVolume>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtVolume&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&(identical(other.format, format) || other.format == format)&&(identical(other.content, content) || other.content == content)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.allocation, allocation) || other.allocation == allocation)&&(identical(other.backing, backing) || other.backing == backing)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other._users, _users));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,path,format,content,capacity,allocation,backing,createdAt,const DeepCollectionEquality().hash(_users));

@override
String toString() {
  return 'VirtVolume(id: $id, name: $name, path: $path, format: $format, content: $content, capacity: $capacity, allocation: $allocation, backing: $backing, createdAt: $createdAt, users: $users)';
}


}

/// @nodoc
abstract mixin class _$VirtVolumeCopyWith<$Res> implements $VirtVolumeCopyWith<$Res> {
  factory _$VirtVolumeCopyWith(_VirtVolume value, $Res Function(_VirtVolume) _then) = __$VirtVolumeCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? path, String? format, String? content, int? capacity, int? allocation, String? backing, DateTime? createdAt, List<VirtGuestRef> users
});




}
/// @nodoc
class __$VirtVolumeCopyWithImpl<$Res>
    implements _$VirtVolumeCopyWith<$Res> {
  __$VirtVolumeCopyWithImpl(this._self, this._then);

  final _VirtVolume _self;
  final $Res Function(_VirtVolume) _then;

/// Create a copy of VirtVolume
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? path = freezed,Object? format = freezed,Object? content = freezed,Object? capacity = freezed,Object? allocation = freezed,Object? backing = freezed,Object? createdAt = freezed,Object? users = null,}) {
  return _then(_VirtVolume(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,allocation: freezed == allocation ? _self.allocation : allocation // ignore: cast_nullable_to_non_nullable
as int?,backing: freezed == backing ? _self.backing : backing // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,users: null == users ? _self._users : users // ignore: cast_nullable_to_non_nullable
as List<VirtGuestRef>,
  ));
}


}

/// @nodoc
mixin _$VirtNetwork {

/// Unique on the host: libvirt's network name, PVE `<node>/<iface>`.
 String get id; String get name; String? get node;/// libvirt's forward mode: `nat`, `isolated`, `route`, `open`, `bridge`,
/// `passthrough`, ...; PVE's interface type: `bridge`, `bond`, `vlan`,
/// `eth`, `OVSBridge`, ...
 String get mode;/// libvirt: the bridge device (`virbr0`, or the host bridge a
/// bridge-mode network uses).
 String? get bridge;/// Addresses with their prefix, e.g. `192.168.122.1/24`.
 List<String> get cidrs; String? get gateway;/// `start-end` of each DHCP range (libvirt).
 List<String> get dhcpRanges;/// PVE bridge ports or bond slaves; libvirt forward devices.
 List<String> get ports;/// PVE `bridge_vlan_aware`.
 bool? get vlanAware;/// PVE: the VLAN tag and the device it is on.
 int? get vlanId; String? get vlanDevice;/// PVE bond mode (`active-backup`, `802.3ad`, ...).
 String? get bondMode; bool get active; bool? get autostart; String? get comment;/// Guests with a NIC on it.
 List<VirtGuestRef> get users;
/// Create a copy of VirtNetwork
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtNetworkCopyWith<VirtNetwork> get copyWith => _$VirtNetworkCopyWithImpl<VirtNetwork>(this as VirtNetwork, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtNetwork&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.node, node) || other.node == node)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.bridge, bridge) || other.bridge == bridge)&&const DeepCollectionEquality().equals(other.cidrs, cidrs)&&(identical(other.gateway, gateway) || other.gateway == gateway)&&const DeepCollectionEquality().equals(other.dhcpRanges, dhcpRanges)&&const DeepCollectionEquality().equals(other.ports, ports)&&(identical(other.vlanAware, vlanAware) || other.vlanAware == vlanAware)&&(identical(other.vlanId, vlanId) || other.vlanId == vlanId)&&(identical(other.vlanDevice, vlanDevice) || other.vlanDevice == vlanDevice)&&(identical(other.bondMode, bondMode) || other.bondMode == bondMode)&&(identical(other.active, active) || other.active == active)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&(identical(other.comment, comment) || other.comment == comment)&&const DeepCollectionEquality().equals(other.users, users));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,node,mode,bridge,const DeepCollectionEquality().hash(cidrs),gateway,const DeepCollectionEquality().hash(dhcpRanges),const DeepCollectionEquality().hash(ports),vlanAware,vlanId,vlanDevice,bondMode,active,autostart,comment,const DeepCollectionEquality().hash(users));

@override
String toString() {
  return 'VirtNetwork(id: $id, name: $name, node: $node, mode: $mode, bridge: $bridge, cidrs: $cidrs, gateway: $gateway, dhcpRanges: $dhcpRanges, ports: $ports, vlanAware: $vlanAware, vlanId: $vlanId, vlanDevice: $vlanDevice, bondMode: $bondMode, active: $active, autostart: $autostart, comment: $comment, users: $users)';
}


}

/// @nodoc
abstract mixin class $VirtNetworkCopyWith<$Res>  {
  factory $VirtNetworkCopyWith(VirtNetwork value, $Res Function(VirtNetwork) _then) = _$VirtNetworkCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? node, String mode, String? bridge, List<String> cidrs, String? gateway, List<String> dhcpRanges, List<String> ports, bool? vlanAware, int? vlanId, String? vlanDevice, String? bondMode, bool active, bool? autostart, String? comment, List<VirtGuestRef> users
});




}
/// @nodoc
class _$VirtNetworkCopyWithImpl<$Res>
    implements $VirtNetworkCopyWith<$Res> {
  _$VirtNetworkCopyWithImpl(this._self, this._then);

  final VirtNetwork _self;
  final $Res Function(VirtNetwork) _then;

/// Create a copy of VirtNetwork
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? node = freezed,Object? mode = null,Object? bridge = freezed,Object? cidrs = null,Object? gateway = freezed,Object? dhcpRanges = null,Object? ports = null,Object? vlanAware = freezed,Object? vlanId = freezed,Object? vlanDevice = freezed,Object? bondMode = freezed,Object? active = null,Object? autostart = freezed,Object? comment = freezed,Object? users = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,node: freezed == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as String?,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,bridge: freezed == bridge ? _self.bridge : bridge // ignore: cast_nullable_to_non_nullable
as String?,cidrs: null == cidrs ? _self.cidrs : cidrs // ignore: cast_nullable_to_non_nullable
as List<String>,gateway: freezed == gateway ? _self.gateway : gateway // ignore: cast_nullable_to_non_nullable
as String?,dhcpRanges: null == dhcpRanges ? _self.dhcpRanges : dhcpRanges // ignore: cast_nullable_to_non_nullable
as List<String>,ports: null == ports ? _self.ports : ports // ignore: cast_nullable_to_non_nullable
as List<String>,vlanAware: freezed == vlanAware ? _self.vlanAware : vlanAware // ignore: cast_nullable_to_non_nullable
as bool?,vlanId: freezed == vlanId ? _self.vlanId : vlanId // ignore: cast_nullable_to_non_nullable
as int?,vlanDevice: freezed == vlanDevice ? _self.vlanDevice : vlanDevice // ignore: cast_nullable_to_non_nullable
as String?,bondMode: freezed == bondMode ? _self.bondMode : bondMode // ignore: cast_nullable_to_non_nullable
as String?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,autostart: freezed == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool?,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,users: null == users ? _self.users : users // ignore: cast_nullable_to_non_nullable
as List<VirtGuestRef>,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtNetwork].
extension VirtNetworkPatterns on VirtNetwork {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtNetwork value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtNetwork() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtNetwork value)  $default,){
final _that = this;
switch (_that) {
case _VirtNetwork():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtNetwork value)?  $default,){
final _that = this;
switch (_that) {
case _VirtNetwork() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? node,  String mode,  String? bridge,  List<String> cidrs,  String? gateway,  List<String> dhcpRanges,  List<String> ports,  bool? vlanAware,  int? vlanId,  String? vlanDevice,  String? bondMode,  bool active,  bool? autostart,  String? comment,  List<VirtGuestRef> users)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtNetwork() when $default != null:
return $default(_that.id,_that.name,_that.node,_that.mode,_that.bridge,_that.cidrs,_that.gateway,_that.dhcpRanges,_that.ports,_that.vlanAware,_that.vlanId,_that.vlanDevice,_that.bondMode,_that.active,_that.autostart,_that.comment,_that.users);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? node,  String mode,  String? bridge,  List<String> cidrs,  String? gateway,  List<String> dhcpRanges,  List<String> ports,  bool? vlanAware,  int? vlanId,  String? vlanDevice,  String? bondMode,  bool active,  bool? autostart,  String? comment,  List<VirtGuestRef> users)  $default,) {final _that = this;
switch (_that) {
case _VirtNetwork():
return $default(_that.id,_that.name,_that.node,_that.mode,_that.bridge,_that.cidrs,_that.gateway,_that.dhcpRanges,_that.ports,_that.vlanAware,_that.vlanId,_that.vlanDevice,_that.bondMode,_that.active,_that.autostart,_that.comment,_that.users);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? node,  String mode,  String? bridge,  List<String> cidrs,  String? gateway,  List<String> dhcpRanges,  List<String> ports,  bool? vlanAware,  int? vlanId,  String? vlanDevice,  String? bondMode,  bool active,  bool? autostart,  String? comment,  List<VirtGuestRef> users)?  $default,) {final _that = this;
switch (_that) {
case _VirtNetwork() when $default != null:
return $default(_that.id,_that.name,_that.node,_that.mode,_that.bridge,_that.cidrs,_that.gateway,_that.dhcpRanges,_that.ports,_that.vlanAware,_that.vlanId,_that.vlanDevice,_that.bondMode,_that.active,_that.autostart,_that.comment,_that.users);case _:
  return null;

}
}

}

/// @nodoc


class _VirtNetwork implements VirtNetwork {
  const _VirtNetwork({required this.id, required this.name, this.node, required this.mode, this.bridge, final  List<String> cidrs = const <String>[], this.gateway, final  List<String> dhcpRanges = const <String>[], final  List<String> ports = const <String>[], this.vlanAware, this.vlanId, this.vlanDevice, this.bondMode, this.active = true, this.autostart, this.comment, final  List<VirtGuestRef> users = const <VirtGuestRef>[]}): _cidrs = cidrs,_dhcpRanges = dhcpRanges,_ports = ports,_users = users;
  

/// Unique on the host: libvirt's network name, PVE `<node>/<iface>`.
@override final  String id;
@override final  String name;
@override final  String? node;
/// libvirt's forward mode: `nat`, `isolated`, `route`, `open`, `bridge`,
/// `passthrough`, ...; PVE's interface type: `bridge`, `bond`, `vlan`,
/// `eth`, `OVSBridge`, ...
@override final  String mode;
/// libvirt: the bridge device (`virbr0`, or the host bridge a
/// bridge-mode network uses).
@override final  String? bridge;
/// Addresses with their prefix, e.g. `192.168.122.1/24`.
 final  List<String> _cidrs;
/// Addresses with their prefix, e.g. `192.168.122.1/24`.
@override@JsonKey() List<String> get cidrs {
  if (_cidrs is EqualUnmodifiableListView) return _cidrs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cidrs);
}

@override final  String? gateway;
/// `start-end` of each DHCP range (libvirt).
 final  List<String> _dhcpRanges;
/// `start-end` of each DHCP range (libvirt).
@override@JsonKey() List<String> get dhcpRanges {
  if (_dhcpRanges is EqualUnmodifiableListView) return _dhcpRanges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_dhcpRanges);
}

/// PVE bridge ports or bond slaves; libvirt forward devices.
 final  List<String> _ports;
/// PVE bridge ports or bond slaves; libvirt forward devices.
@override@JsonKey() List<String> get ports {
  if (_ports is EqualUnmodifiableListView) return _ports;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ports);
}

/// PVE `bridge_vlan_aware`.
@override final  bool? vlanAware;
/// PVE: the VLAN tag and the device it is on.
@override final  int? vlanId;
@override final  String? vlanDevice;
/// PVE bond mode (`active-backup`, `802.3ad`, ...).
@override final  String? bondMode;
@override@JsonKey() final  bool active;
@override final  bool? autostart;
@override final  String? comment;
/// Guests with a NIC on it.
 final  List<VirtGuestRef> _users;
/// Guests with a NIC on it.
@override@JsonKey() List<VirtGuestRef> get users {
  if (_users is EqualUnmodifiableListView) return _users;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_users);
}


/// Create a copy of VirtNetwork
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtNetworkCopyWith<_VirtNetwork> get copyWith => __$VirtNetworkCopyWithImpl<_VirtNetwork>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtNetwork&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.node, node) || other.node == node)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.bridge, bridge) || other.bridge == bridge)&&const DeepCollectionEquality().equals(other._cidrs, _cidrs)&&(identical(other.gateway, gateway) || other.gateway == gateway)&&const DeepCollectionEquality().equals(other._dhcpRanges, _dhcpRanges)&&const DeepCollectionEquality().equals(other._ports, _ports)&&(identical(other.vlanAware, vlanAware) || other.vlanAware == vlanAware)&&(identical(other.vlanId, vlanId) || other.vlanId == vlanId)&&(identical(other.vlanDevice, vlanDevice) || other.vlanDevice == vlanDevice)&&(identical(other.bondMode, bondMode) || other.bondMode == bondMode)&&(identical(other.active, active) || other.active == active)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&(identical(other.comment, comment) || other.comment == comment)&&const DeepCollectionEquality().equals(other._users, _users));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,node,mode,bridge,const DeepCollectionEquality().hash(_cidrs),gateway,const DeepCollectionEquality().hash(_dhcpRanges),const DeepCollectionEquality().hash(_ports),vlanAware,vlanId,vlanDevice,bondMode,active,autostart,comment,const DeepCollectionEquality().hash(_users));

@override
String toString() {
  return 'VirtNetwork(id: $id, name: $name, node: $node, mode: $mode, bridge: $bridge, cidrs: $cidrs, gateway: $gateway, dhcpRanges: $dhcpRanges, ports: $ports, vlanAware: $vlanAware, vlanId: $vlanId, vlanDevice: $vlanDevice, bondMode: $bondMode, active: $active, autostart: $autostart, comment: $comment, users: $users)';
}


}

/// @nodoc
abstract mixin class _$VirtNetworkCopyWith<$Res> implements $VirtNetworkCopyWith<$Res> {
  factory _$VirtNetworkCopyWith(_VirtNetwork value, $Res Function(_VirtNetwork) _then) = __$VirtNetworkCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? node, String mode, String? bridge, List<String> cidrs, String? gateway, List<String> dhcpRanges, List<String> ports, bool? vlanAware, int? vlanId, String? vlanDevice, String? bondMode, bool active, bool? autostart, String? comment, List<VirtGuestRef> users
});




}
/// @nodoc
class __$VirtNetworkCopyWithImpl<$Res>
    implements _$VirtNetworkCopyWith<$Res> {
  __$VirtNetworkCopyWithImpl(this._self, this._then);

  final _VirtNetwork _self;
  final $Res Function(_VirtNetwork) _then;

/// Create a copy of VirtNetwork
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? node = freezed,Object? mode = null,Object? bridge = freezed,Object? cidrs = null,Object? gateway = freezed,Object? dhcpRanges = null,Object? ports = null,Object? vlanAware = freezed,Object? vlanId = freezed,Object? vlanDevice = freezed,Object? bondMode = freezed,Object? active = null,Object? autostart = freezed,Object? comment = freezed,Object? users = null,}) {
  return _then(_VirtNetwork(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,node: freezed == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as String?,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,bridge: freezed == bridge ? _self.bridge : bridge // ignore: cast_nullable_to_non_nullable
as String?,cidrs: null == cidrs ? _self._cidrs : cidrs // ignore: cast_nullable_to_non_nullable
as List<String>,gateway: freezed == gateway ? _self.gateway : gateway // ignore: cast_nullable_to_non_nullable
as String?,dhcpRanges: null == dhcpRanges ? _self._dhcpRanges : dhcpRanges // ignore: cast_nullable_to_non_nullable
as List<String>,ports: null == ports ? _self._ports : ports // ignore: cast_nullable_to_non_nullable
as List<String>,vlanAware: freezed == vlanAware ? _self.vlanAware : vlanAware // ignore: cast_nullable_to_non_nullable
as bool?,vlanId: freezed == vlanId ? _self.vlanId : vlanId // ignore: cast_nullable_to_non_nullable
as int?,vlanDevice: freezed == vlanDevice ? _self.vlanDevice : vlanDevice // ignore: cast_nullable_to_non_nullable
as String?,bondMode: freezed == bondMode ? _self.bondMode : bondMode // ignore: cast_nullable_to_non_nullable
as String?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,autostart: freezed == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool?,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,users: null == users ? _self._users : users // ignore: cast_nullable_to_non_nullable
as List<VirtGuestRef>,
  ));
}


}

// dart format on
