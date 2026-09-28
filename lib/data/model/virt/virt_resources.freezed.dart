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
 bool get withMemory;/// Kept outside the disk image (`snapshot='external'`): the guest was
/// left on a qcow2 overlay of the file the snapshot records.
 bool get external;/// Which file each disk was left on, for an external one. Empty for an
/// internal snapshot, which is one image.
 List<VirtSnapshotLayer> get layers;
/// Create a copy of VirtGuestSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtGuestSnapshotCopyWith<VirtGuestSnapshot> get copyWith => _$VirtGuestSnapshotCopyWithImpl<VirtGuestSnapshot>(this as VirtGuestSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtGuestSnapshot&&(identical(other.name, name) || other.name == name)&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.description, description) || other.description == description)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.current, current) || other.current == current)&&(identical(other.withMemory, withMemory) || other.withMemory == withMemory)&&(identical(other.external, external) || other.external == external)&&const DeepCollectionEquality().equals(other.layers, layers));
}


@override
int get hashCode => Object.hash(runtimeType,name,parent,description,createdAt,current,withMemory,external,const DeepCollectionEquality().hash(layers));

@override
String toString() {
  return 'VirtGuestSnapshot(name: $name, parent: $parent, description: $description, createdAt: $createdAt, current: $current, withMemory: $withMemory, external: $external, layers: $layers)';
}


}

/// @nodoc
abstract mixin class $VirtGuestSnapshotCopyWith<$Res>  {
  factory $VirtGuestSnapshotCopyWith(VirtGuestSnapshot value, $Res Function(VirtGuestSnapshot) _then) = _$VirtGuestSnapshotCopyWithImpl;
@useResult
$Res call({
 String name, String? parent, String? description, DateTime? createdAt, bool current, bool withMemory, bool external, List<VirtSnapshotLayer> layers
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
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? parent = freezed,Object? description = freezed,Object? createdAt = freezed,Object? current = null,Object? withMemory = null,Object? external = null,Object? layers = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,parent: freezed == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,withMemory: null == withMemory ? _self.withMemory : withMemory // ignore: cast_nullable_to_non_nullable
as bool,external: null == external ? _self.external : external // ignore: cast_nullable_to_non_nullable
as bool,layers: null == layers ? _self.layers : layers // ignore: cast_nullable_to_non_nullable
as List<VirtSnapshotLayer>,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? parent,  String? description,  DateTime? createdAt,  bool current,  bool withMemory,  bool external,  List<VirtSnapshotLayer> layers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtGuestSnapshot() when $default != null:
return $default(_that.name,_that.parent,_that.description,_that.createdAt,_that.current,_that.withMemory,_that.external,_that.layers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? parent,  String? description,  DateTime? createdAt,  bool current,  bool withMemory,  bool external,  List<VirtSnapshotLayer> layers)  $default,) {final _that = this;
switch (_that) {
case _VirtGuestSnapshot():
return $default(_that.name,_that.parent,_that.description,_that.createdAt,_that.current,_that.withMemory,_that.external,_that.layers);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? parent,  String? description,  DateTime? createdAt,  bool current,  bool withMemory,  bool external,  List<VirtSnapshotLayer> layers)?  $default,) {final _that = this;
switch (_that) {
case _VirtGuestSnapshot() when $default != null:
return $default(_that.name,_that.parent,_that.description,_that.createdAt,_that.current,_that.withMemory,_that.external,_that.layers);case _:
  return null;

}
}

}

/// @nodoc


class _VirtGuestSnapshot extends VirtGuestSnapshot {
  const _VirtGuestSnapshot({required this.name, this.parent, this.description, this.createdAt, this.current = false, this.withMemory = false, this.external = false, final  List<VirtSnapshotLayer> layers = const <VirtSnapshotLayer>[]}): _layers = layers,super._();
  

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
/// Kept outside the disk image (`snapshot='external'`): the guest was
/// left on a qcow2 overlay of the file the snapshot records.
@override@JsonKey() final  bool external;
/// Which file each disk was left on, for an external one. Empty for an
/// internal snapshot, which is one image.
 final  List<VirtSnapshotLayer> _layers;
/// Which file each disk was left on, for an external one. Empty for an
/// internal snapshot, which is one image.
@override@JsonKey() List<VirtSnapshotLayer> get layers {
  if (_layers is EqualUnmodifiableListView) return _layers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_layers);
}


/// Create a copy of VirtGuestSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtGuestSnapshotCopyWith<_VirtGuestSnapshot> get copyWith => __$VirtGuestSnapshotCopyWithImpl<_VirtGuestSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtGuestSnapshot&&(identical(other.name, name) || other.name == name)&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.description, description) || other.description == description)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.current, current) || other.current == current)&&(identical(other.withMemory, withMemory) || other.withMemory == withMemory)&&(identical(other.external, external) || other.external == external)&&const DeepCollectionEquality().equals(other._layers, _layers));
}


@override
int get hashCode => Object.hash(runtimeType,name,parent,description,createdAt,current,withMemory,external,const DeepCollectionEquality().hash(_layers));

@override
String toString() {
  return 'VirtGuestSnapshot(name: $name, parent: $parent, description: $description, createdAt: $createdAt, current: $current, withMemory: $withMemory, external: $external, layers: $layers)';
}


}

/// @nodoc
abstract mixin class _$VirtGuestSnapshotCopyWith<$Res> implements $VirtGuestSnapshotCopyWith<$Res> {
  factory _$VirtGuestSnapshotCopyWith(_VirtGuestSnapshot value, $Res Function(_VirtGuestSnapshot) _then) = __$VirtGuestSnapshotCopyWithImpl;
@override @useResult
$Res call({
 String name, String? parent, String? description, DateTime? createdAt, bool current, bool withMemory, bool external, List<VirtSnapshotLayer> layers
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
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? parent = freezed,Object? description = freezed,Object? createdAt = freezed,Object? current = null,Object? withMemory = null,Object? external = null,Object? layers = null,}) {
  return _then(_VirtGuestSnapshot(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,parent: freezed == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,withMemory: null == withMemory ? _self.withMemory : withMemory // ignore: cast_nullable_to_non_nullable
as bool,external: null == external ? _self.external : external // ignore: cast_nullable_to_non_nullable
as bool,layers: null == layers ? _self._layers : layers // ignore: cast_nullable_to_non_nullable
as List<VirtSnapshotLayer>,
  ));
}


}

/// @nodoc
mixin _$VirtSnapshotLayer {

 String get target;/// The file the snapshot left this disk on. An external layer's file is
/// the one the *guest* is on until the next snapshot moves it on.
 String? get file;/// `snapshot='external'`: the layer is a file of its own rather than
/// something inside the image.
 bool get external;
/// Create a copy of VirtSnapshotLayer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtSnapshotLayerCopyWith<VirtSnapshotLayer> get copyWith => _$VirtSnapshotLayerCopyWithImpl<VirtSnapshotLayer>(this as VirtSnapshotLayer, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtSnapshotLayer&&(identical(other.target, target) || other.target == target)&&(identical(other.file, file) || other.file == file)&&(identical(other.external, external) || other.external == external));
}


@override
int get hashCode => Object.hash(runtimeType,target,file,external);

@override
String toString() {
  return 'VirtSnapshotLayer(target: $target, file: $file, external: $external)';
}


}

/// @nodoc
abstract mixin class $VirtSnapshotLayerCopyWith<$Res>  {
  factory $VirtSnapshotLayerCopyWith(VirtSnapshotLayer value, $Res Function(VirtSnapshotLayer) _then) = _$VirtSnapshotLayerCopyWithImpl;
@useResult
$Res call({
 String target, String? file, bool external
});




}
/// @nodoc
class _$VirtSnapshotLayerCopyWithImpl<$Res>
    implements $VirtSnapshotLayerCopyWith<$Res> {
  _$VirtSnapshotLayerCopyWithImpl(this._self, this._then);

  final VirtSnapshotLayer _self;
  final $Res Function(VirtSnapshotLayer) _then;

/// Create a copy of VirtSnapshotLayer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? file = freezed,Object? external = null,}) {
  return _then(_self.copyWith(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String?,external: null == external ? _self.external : external // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtSnapshotLayer].
extension VirtSnapshotLayerPatterns on VirtSnapshotLayer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtSnapshotLayer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtSnapshotLayer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtSnapshotLayer value)  $default,){
final _that = this;
switch (_that) {
case _VirtSnapshotLayer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtSnapshotLayer value)?  $default,){
final _that = this;
switch (_that) {
case _VirtSnapshotLayer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String target,  String? file,  bool external)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtSnapshotLayer() when $default != null:
return $default(_that.target,_that.file,_that.external);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String target,  String? file,  bool external)  $default,) {final _that = this;
switch (_that) {
case _VirtSnapshotLayer():
return $default(_that.target,_that.file,_that.external);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String target,  String? file,  bool external)?  $default,) {final _that = this;
switch (_that) {
case _VirtSnapshotLayer() when $default != null:
return $default(_that.target,_that.file,_that.external);case _:
  return null;

}
}

}

/// @nodoc


class _VirtSnapshotLayer implements VirtSnapshotLayer {
  const _VirtSnapshotLayer({required this.target, this.file, this.external = false});
  

@override final  String target;
/// The file the snapshot left this disk on. An external layer's file is
/// the one the *guest* is on until the next snapshot moves it on.
@override final  String? file;
/// `snapshot='external'`: the layer is a file of its own rather than
/// something inside the image.
@override@JsonKey() final  bool external;

/// Create a copy of VirtSnapshotLayer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtSnapshotLayerCopyWith<_VirtSnapshotLayer> get copyWith => __$VirtSnapshotLayerCopyWithImpl<_VirtSnapshotLayer>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtSnapshotLayer&&(identical(other.target, target) || other.target == target)&&(identical(other.file, file) || other.file == file)&&(identical(other.external, external) || other.external == external));
}


@override
int get hashCode => Object.hash(runtimeType,target,file,external);

@override
String toString() {
  return 'VirtSnapshotLayer(target: $target, file: $file, external: $external)';
}


}

/// @nodoc
abstract mixin class _$VirtSnapshotLayerCopyWith<$Res> implements $VirtSnapshotLayerCopyWith<$Res> {
  factory _$VirtSnapshotLayerCopyWith(_VirtSnapshotLayer value, $Res Function(_VirtSnapshotLayer) _then) = __$VirtSnapshotLayerCopyWithImpl;
@override @useResult
$Res call({
 String target, String? file, bool external
});




}
/// @nodoc
class __$VirtSnapshotLayerCopyWithImpl<$Res>
    implements _$VirtSnapshotLayerCopyWith<$Res> {
  __$VirtSnapshotLayerCopyWithImpl(this._self, this._then);

  final _VirtSnapshotLayer _self;
  final $Res Function(_VirtSnapshotLayer) _then;

/// Create a copy of VirtSnapshotLayer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? file = freezed,Object? external = null,}) {
  return _then(_VirtSnapshotLayer(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String?,external: null == external ? _self.external : external // ignore: cast_nullable_to_non_nullable
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
 String? get backing; DateTime? get createdAt; List<VirtGuestRef> get users;/// The volumes made on this one — whose [backing] it is — in any active
/// pool, by path (libvirt). A base image a guest's disk is a thin clone
/// of is attached to nothing, and deleting it breaks every one of them.
 List<String> get backs;
/// Create a copy of VirtVolume
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtVolumeCopyWith<VirtVolume> get copyWith => _$VirtVolumeCopyWithImpl<VirtVolume>(this as VirtVolume, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtVolume&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&(identical(other.format, format) || other.format == format)&&(identical(other.content, content) || other.content == content)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.allocation, allocation) || other.allocation == allocation)&&(identical(other.backing, backing) || other.backing == backing)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other.users, users)&&const DeepCollectionEquality().equals(other.backs, backs));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,path,format,content,capacity,allocation,backing,createdAt,const DeepCollectionEquality().hash(users),const DeepCollectionEquality().hash(backs));

@override
String toString() {
  return 'VirtVolume(id: $id, name: $name, path: $path, format: $format, content: $content, capacity: $capacity, allocation: $allocation, backing: $backing, createdAt: $createdAt, users: $users, backs: $backs)';
}


}

/// @nodoc
abstract mixin class $VirtVolumeCopyWith<$Res>  {
  factory $VirtVolumeCopyWith(VirtVolume value, $Res Function(VirtVolume) _then) = _$VirtVolumeCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? path, String? format, String? content, int? capacity, int? allocation, String? backing, DateTime? createdAt, List<VirtGuestRef> users, List<String> backs
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? path = freezed,Object? format = freezed,Object? content = freezed,Object? capacity = freezed,Object? allocation = freezed,Object? backing = freezed,Object? createdAt = freezed,Object? users = null,Object? backs = null,}) {
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
as List<VirtGuestRef>,backs: null == backs ? _self.backs : backs // ignore: cast_nullable_to_non_nullable
as List<String>,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? path,  String? format,  String? content,  int? capacity,  int? allocation,  String? backing,  DateTime? createdAt,  List<VirtGuestRef> users,  List<String> backs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtVolume() when $default != null:
return $default(_that.id,_that.name,_that.path,_that.format,_that.content,_that.capacity,_that.allocation,_that.backing,_that.createdAt,_that.users,_that.backs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? path,  String? format,  String? content,  int? capacity,  int? allocation,  String? backing,  DateTime? createdAt,  List<VirtGuestRef> users,  List<String> backs)  $default,) {final _that = this;
switch (_that) {
case _VirtVolume():
return $default(_that.id,_that.name,_that.path,_that.format,_that.content,_that.capacity,_that.allocation,_that.backing,_that.createdAt,_that.users,_that.backs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? path,  String? format,  String? content,  int? capacity,  int? allocation,  String? backing,  DateTime? createdAt,  List<VirtGuestRef> users,  List<String> backs)?  $default,) {final _that = this;
switch (_that) {
case _VirtVolume() when $default != null:
return $default(_that.id,_that.name,_that.path,_that.format,_that.content,_that.capacity,_that.allocation,_that.backing,_that.createdAt,_that.users,_that.backs);case _:
  return null;

}
}

}

/// @nodoc


class _VirtVolume extends VirtVolume {
  const _VirtVolume({required this.id, required this.name, this.path, this.format, this.content, this.capacity, this.allocation, this.backing, this.createdAt, final  List<VirtGuestRef> users = const <VirtGuestRef>[], final  List<String> backs = const <String>[]}): _users = users,_backs = backs,super._();
  

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

/// The volumes made on this one — whose [backing] it is — in any active
/// pool, by path (libvirt). A base image a guest's disk is a thin clone
/// of is attached to nothing, and deleting it breaks every one of them.
 final  List<String> _backs;
/// The volumes made on this one — whose [backing] it is — in any active
/// pool, by path (libvirt). A base image a guest's disk is a thin clone
/// of is attached to nothing, and deleting it breaks every one of them.
@override@JsonKey() List<String> get backs {
  if (_backs is EqualUnmodifiableListView) return _backs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_backs);
}


/// Create a copy of VirtVolume
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtVolumeCopyWith<_VirtVolume> get copyWith => __$VirtVolumeCopyWithImpl<_VirtVolume>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtVolume&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&(identical(other.format, format) || other.format == format)&&(identical(other.content, content) || other.content == content)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.allocation, allocation) || other.allocation == allocation)&&(identical(other.backing, backing) || other.backing == backing)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other._users, _users)&&const DeepCollectionEquality().equals(other._backs, _backs));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,path,format,content,capacity,allocation,backing,createdAt,const DeepCollectionEquality().hash(_users),const DeepCollectionEquality().hash(_backs));

@override
String toString() {
  return 'VirtVolume(id: $id, name: $name, path: $path, format: $format, content: $content, capacity: $capacity, allocation: $allocation, backing: $backing, createdAt: $createdAt, users: $users, backs: $backs)';
}


}

/// @nodoc
abstract mixin class _$VirtVolumeCopyWith<$Res> implements $VirtVolumeCopyWith<$Res> {
  factory _$VirtVolumeCopyWith(_VirtVolume value, $Res Function(_VirtVolume) _then) = __$VirtVolumeCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? path, String? format, String? content, int? capacity, int? allocation, String? backing, DateTime? createdAt, List<VirtGuestRef> users, List<String> backs
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? path = freezed,Object? format = freezed,Object? content = freezed,Object? capacity = freezed,Object? allocation = freezed,Object? backing = freezed,Object? createdAt = freezed,Object? users = null,Object? backs = null,}) {
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
as List<VirtGuestRef>,backs: null == backs ? _self._backs : backs // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$VirtNetHost {

 String get mac; String get ip;/// The name dnsmasq is told, where one is given.
 String? get name;
/// Create a copy of VirtNetHost
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtNetHostCopyWith<VirtNetHost> get copyWith => _$VirtNetHostCopyWithImpl<VirtNetHost>(this as VirtNetHost, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtNetHost&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,mac,ip,name);

@override
String toString() {
  return 'VirtNetHost(mac: $mac, ip: $ip, name: $name)';
}


}

/// @nodoc
abstract mixin class $VirtNetHostCopyWith<$Res>  {
  factory $VirtNetHostCopyWith(VirtNetHost value, $Res Function(VirtNetHost) _then) = _$VirtNetHostCopyWithImpl;
@useResult
$Res call({
 String mac, String ip, String? name
});




}
/// @nodoc
class _$VirtNetHostCopyWithImpl<$Res>
    implements $VirtNetHostCopyWith<$Res> {
  _$VirtNetHostCopyWithImpl(this._self, this._then);

  final VirtNetHost _self;
  final $Res Function(VirtNetHost) _then;

/// Create a copy of VirtNetHost
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mac = null,Object? ip = null,Object? name = freezed,}) {
  return _then(_self.copyWith(
mac: null == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtNetHost].
extension VirtNetHostPatterns on VirtNetHost {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtNetHost value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtNetHost() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtNetHost value)  $default,){
final _that = this;
switch (_that) {
case _VirtNetHost():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtNetHost value)?  $default,){
final _that = this;
switch (_that) {
case _VirtNetHost() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String mac,  String ip,  String? name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtNetHost() when $default != null:
return $default(_that.mac,_that.ip,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String mac,  String ip,  String? name)  $default,) {final _that = this;
switch (_that) {
case _VirtNetHost():
return $default(_that.mac,_that.ip,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String mac,  String ip,  String? name)?  $default,) {final _that = this;
switch (_that) {
case _VirtNetHost() when $default != null:
return $default(_that.mac,_that.ip,_that.name);case _:
  return null;

}
}

}

/// @nodoc


class _VirtNetHost implements VirtNetHost {
  const _VirtNetHost({required this.mac, required this.ip, this.name});
  

@override final  String mac;
@override final  String ip;
/// The name dnsmasq is told, where one is given.
@override final  String? name;

/// Create a copy of VirtNetHost
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtNetHostCopyWith<_VirtNetHost> get copyWith => __$VirtNetHostCopyWithImpl<_VirtNetHost>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtNetHost&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,mac,ip,name);

@override
String toString() {
  return 'VirtNetHost(mac: $mac, ip: $ip, name: $name)';
}


}

/// @nodoc
abstract mixin class _$VirtNetHostCopyWith<$Res> implements $VirtNetHostCopyWith<$Res> {
  factory _$VirtNetHostCopyWith(_VirtNetHost value, $Res Function(_VirtNetHost) _then) = __$VirtNetHostCopyWithImpl;
@override @useResult
$Res call({
 String mac, String ip, String? name
});




}
/// @nodoc
class __$VirtNetHostCopyWithImpl<$Res>
    implements _$VirtNetHostCopyWith<$Res> {
  __$VirtNetHostCopyWithImpl(this._self, this._then);

  final _VirtNetHost _self;
  final $Res Function(_VirtNetHost) _then;

/// Create a copy of VirtNetHost
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mac = null,Object? ip = null,Object? name = freezed,}) {
  return _then(_VirtNetHost(
mac: null == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,
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
 String? get bondMode; bool get active; bool? get autostart; String? get comment;/// The static DHCP entries it hands out (libvirt). Empty where there
/// are none, and on PVE, which keeps no such list here.
 List<VirtNetHost> get hosts;/// libvirt: the definition **as saved** (`net-dumpxml --inactive`),
/// which is what an edit is made from and what a restart puts the
/// running network on. Refused once the host's has changed since.
/// Empty where the host did not say (PVE).
 String get xml;/// Whether the running network is on something other than its
/// definition: libvirt applies `net-define` at the next start, so a
/// change made while it runs waits, and the view offers the restart
/// that applies it.
 bool get pendingRestart;/// Whether this app may change it at all. PVE: a bridge, and not the
/// interface carrying the node's management address — applying that
/// would cut the host off. libvirt: every network. The backend decides
/// (`virtPveManagedIface`), so the view never re-derives it.
 bool get managementEditable;/// Guests with a NIC on it.
 List<VirtGuestRef> get users;
/// Create a copy of VirtNetwork
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtNetworkCopyWith<VirtNetwork> get copyWith => _$VirtNetworkCopyWithImpl<VirtNetwork>(this as VirtNetwork, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtNetwork&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.node, node) || other.node == node)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.bridge, bridge) || other.bridge == bridge)&&const DeepCollectionEquality().equals(other.cidrs, cidrs)&&(identical(other.gateway, gateway) || other.gateway == gateway)&&const DeepCollectionEquality().equals(other.dhcpRanges, dhcpRanges)&&const DeepCollectionEquality().equals(other.ports, ports)&&(identical(other.vlanAware, vlanAware) || other.vlanAware == vlanAware)&&(identical(other.vlanId, vlanId) || other.vlanId == vlanId)&&(identical(other.vlanDevice, vlanDevice) || other.vlanDevice == vlanDevice)&&(identical(other.bondMode, bondMode) || other.bondMode == bondMode)&&(identical(other.active, active) || other.active == active)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&(identical(other.comment, comment) || other.comment == comment)&&const DeepCollectionEquality().equals(other.hosts, hosts)&&(identical(other.xml, xml) || other.xml == xml)&&(identical(other.pendingRestart, pendingRestart) || other.pendingRestart == pendingRestart)&&(identical(other.managementEditable, managementEditable) || other.managementEditable == managementEditable)&&const DeepCollectionEquality().equals(other.users, users));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,name,node,mode,bridge,const DeepCollectionEquality().hash(cidrs),gateway,const DeepCollectionEquality().hash(dhcpRanges),const DeepCollectionEquality().hash(ports),vlanAware,vlanId,vlanDevice,bondMode,active,autostart,comment,const DeepCollectionEquality().hash(hosts),xml,pendingRestart,managementEditable,const DeepCollectionEquality().hash(users)]);

@override
String toString() {
  return 'VirtNetwork(id: $id, name: $name, node: $node, mode: $mode, bridge: $bridge, cidrs: $cidrs, gateway: $gateway, dhcpRanges: $dhcpRanges, ports: $ports, vlanAware: $vlanAware, vlanId: $vlanId, vlanDevice: $vlanDevice, bondMode: $bondMode, active: $active, autostart: $autostart, comment: $comment, hosts: $hosts, xml: $xml, pendingRestart: $pendingRestart, managementEditable: $managementEditable, users: $users)';
}


}

/// @nodoc
abstract mixin class $VirtNetworkCopyWith<$Res>  {
  factory $VirtNetworkCopyWith(VirtNetwork value, $Res Function(VirtNetwork) _then) = _$VirtNetworkCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? node, String mode, String? bridge, List<String> cidrs, String? gateway, List<String> dhcpRanges, List<String> ports, bool? vlanAware, int? vlanId, String? vlanDevice, String? bondMode, bool active, bool? autostart, String? comment, List<VirtNetHost> hosts, String xml, bool pendingRestart, bool managementEditable, List<VirtGuestRef> users
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? node = freezed,Object? mode = null,Object? bridge = freezed,Object? cidrs = null,Object? gateway = freezed,Object? dhcpRanges = null,Object? ports = null,Object? vlanAware = freezed,Object? vlanId = freezed,Object? vlanDevice = freezed,Object? bondMode = freezed,Object? active = null,Object? autostart = freezed,Object? comment = freezed,Object? hosts = null,Object? xml = null,Object? pendingRestart = null,Object? managementEditable = null,Object? users = null,}) {
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
as String?,hosts: null == hosts ? _self.hosts : hosts // ignore: cast_nullable_to_non_nullable
as List<VirtNetHost>,xml: null == xml ? _self.xml : xml // ignore: cast_nullable_to_non_nullable
as String,pendingRestart: null == pendingRestart ? _self.pendingRestart : pendingRestart // ignore: cast_nullable_to_non_nullable
as bool,managementEditable: null == managementEditable ? _self.managementEditable : managementEditable // ignore: cast_nullable_to_non_nullable
as bool,users: null == users ? _self.users : users // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? node,  String mode,  String? bridge,  List<String> cidrs,  String? gateway,  List<String> dhcpRanges,  List<String> ports,  bool? vlanAware,  int? vlanId,  String? vlanDevice,  String? bondMode,  bool active,  bool? autostart,  String? comment,  List<VirtNetHost> hosts,  String xml,  bool pendingRestart,  bool managementEditable,  List<VirtGuestRef> users)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtNetwork() when $default != null:
return $default(_that.id,_that.name,_that.node,_that.mode,_that.bridge,_that.cidrs,_that.gateway,_that.dhcpRanges,_that.ports,_that.vlanAware,_that.vlanId,_that.vlanDevice,_that.bondMode,_that.active,_that.autostart,_that.comment,_that.hosts,_that.xml,_that.pendingRestart,_that.managementEditable,_that.users);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? node,  String mode,  String? bridge,  List<String> cidrs,  String? gateway,  List<String> dhcpRanges,  List<String> ports,  bool? vlanAware,  int? vlanId,  String? vlanDevice,  String? bondMode,  bool active,  bool? autostart,  String? comment,  List<VirtNetHost> hosts,  String xml,  bool pendingRestart,  bool managementEditable,  List<VirtGuestRef> users)  $default,) {final _that = this;
switch (_that) {
case _VirtNetwork():
return $default(_that.id,_that.name,_that.node,_that.mode,_that.bridge,_that.cidrs,_that.gateway,_that.dhcpRanges,_that.ports,_that.vlanAware,_that.vlanId,_that.vlanDevice,_that.bondMode,_that.active,_that.autostart,_that.comment,_that.hosts,_that.xml,_that.pendingRestart,_that.managementEditable,_that.users);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? node,  String mode,  String? bridge,  List<String> cidrs,  String? gateway,  List<String> dhcpRanges,  List<String> ports,  bool? vlanAware,  int? vlanId,  String? vlanDevice,  String? bondMode,  bool active,  bool? autostart,  String? comment,  List<VirtNetHost> hosts,  String xml,  bool pendingRestart,  bool managementEditable,  List<VirtGuestRef> users)?  $default,) {final _that = this;
switch (_that) {
case _VirtNetwork() when $default != null:
return $default(_that.id,_that.name,_that.node,_that.mode,_that.bridge,_that.cidrs,_that.gateway,_that.dhcpRanges,_that.ports,_that.vlanAware,_that.vlanId,_that.vlanDevice,_that.bondMode,_that.active,_that.autostart,_that.comment,_that.hosts,_that.xml,_that.pendingRestart,_that.managementEditable,_that.users);case _:
  return null;

}
}

}

/// @nodoc


class _VirtNetwork extends VirtNetwork {
  const _VirtNetwork({required this.id, required this.name, this.node, required this.mode, this.bridge, final  List<String> cidrs = const <String>[], this.gateway, final  List<String> dhcpRanges = const <String>[], final  List<String> ports = const <String>[], this.vlanAware, this.vlanId, this.vlanDevice, this.bondMode, this.active = true, this.autostart, this.comment, final  List<VirtNetHost> hosts = const <VirtNetHost>[], this.xml = '', this.pendingRestart = false, this.managementEditable = true, final  List<VirtGuestRef> users = const <VirtGuestRef>[]}): _cidrs = cidrs,_dhcpRanges = dhcpRanges,_ports = ports,_hosts = hosts,_users = users,super._();
  

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
/// The static DHCP entries it hands out (libvirt). Empty where there
/// are none, and on PVE, which keeps no such list here.
 final  List<VirtNetHost> _hosts;
/// The static DHCP entries it hands out (libvirt). Empty where there
/// are none, and on PVE, which keeps no such list here.
@override@JsonKey() List<VirtNetHost> get hosts {
  if (_hosts is EqualUnmodifiableListView) return _hosts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hosts);
}

/// libvirt: the definition **as saved** (`net-dumpxml --inactive`),
/// which is what an edit is made from and what a restart puts the
/// running network on. Refused once the host's has changed since.
/// Empty where the host did not say (PVE).
@override@JsonKey() final  String xml;
/// Whether the running network is on something other than its
/// definition: libvirt applies `net-define` at the next start, so a
/// change made while it runs waits, and the view offers the restart
/// that applies it.
@override@JsonKey() final  bool pendingRestart;
/// Whether this app may change it at all. PVE: a bridge, and not the
/// interface carrying the node's management address — applying that
/// would cut the host off. libvirt: every network. The backend decides
/// (`virtPveManagedIface`), so the view never re-derives it.
@override@JsonKey() final  bool managementEditable;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtNetwork&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.node, node) || other.node == node)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.bridge, bridge) || other.bridge == bridge)&&const DeepCollectionEquality().equals(other._cidrs, _cidrs)&&(identical(other.gateway, gateway) || other.gateway == gateway)&&const DeepCollectionEquality().equals(other._dhcpRanges, _dhcpRanges)&&const DeepCollectionEquality().equals(other._ports, _ports)&&(identical(other.vlanAware, vlanAware) || other.vlanAware == vlanAware)&&(identical(other.vlanId, vlanId) || other.vlanId == vlanId)&&(identical(other.vlanDevice, vlanDevice) || other.vlanDevice == vlanDevice)&&(identical(other.bondMode, bondMode) || other.bondMode == bondMode)&&(identical(other.active, active) || other.active == active)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&(identical(other.comment, comment) || other.comment == comment)&&const DeepCollectionEquality().equals(other._hosts, _hosts)&&(identical(other.xml, xml) || other.xml == xml)&&(identical(other.pendingRestart, pendingRestart) || other.pendingRestart == pendingRestart)&&(identical(other.managementEditable, managementEditable) || other.managementEditable == managementEditable)&&const DeepCollectionEquality().equals(other._users, _users));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,name,node,mode,bridge,const DeepCollectionEquality().hash(_cidrs),gateway,const DeepCollectionEquality().hash(_dhcpRanges),const DeepCollectionEquality().hash(_ports),vlanAware,vlanId,vlanDevice,bondMode,active,autostart,comment,const DeepCollectionEquality().hash(_hosts),xml,pendingRestart,managementEditable,const DeepCollectionEquality().hash(_users)]);

@override
String toString() {
  return 'VirtNetwork(id: $id, name: $name, node: $node, mode: $mode, bridge: $bridge, cidrs: $cidrs, gateway: $gateway, dhcpRanges: $dhcpRanges, ports: $ports, vlanAware: $vlanAware, vlanId: $vlanId, vlanDevice: $vlanDevice, bondMode: $bondMode, active: $active, autostart: $autostart, comment: $comment, hosts: $hosts, xml: $xml, pendingRestart: $pendingRestart, managementEditable: $managementEditable, users: $users)';
}


}

/// @nodoc
abstract mixin class _$VirtNetworkCopyWith<$Res> implements $VirtNetworkCopyWith<$Res> {
  factory _$VirtNetworkCopyWith(_VirtNetwork value, $Res Function(_VirtNetwork) _then) = __$VirtNetworkCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? node, String mode, String? bridge, List<String> cidrs, String? gateway, List<String> dhcpRanges, List<String> ports, bool? vlanAware, int? vlanId, String? vlanDevice, String? bondMode, bool active, bool? autostart, String? comment, List<VirtNetHost> hosts, String xml, bool pendingRestart, bool managementEditable, List<VirtGuestRef> users
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? node = freezed,Object? mode = null,Object? bridge = freezed,Object? cidrs = null,Object? gateway = freezed,Object? dhcpRanges = null,Object? ports = null,Object? vlanAware = freezed,Object? vlanId = freezed,Object? vlanDevice = freezed,Object? bondMode = freezed,Object? active = null,Object? autostart = freezed,Object? comment = freezed,Object? hosts = null,Object? xml = null,Object? pendingRestart = null,Object? managementEditable = null,Object? users = null,}) {
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
as String?,hosts: null == hosts ? _self._hosts : hosts // ignore: cast_nullable_to_non_nullable
as List<VirtNetHost>,xml: null == xml ? _self.xml : xml // ignore: cast_nullable_to_non_nullable
as String,pendingRestart: null == pendingRestart ? _self.pendingRestart : pendingRestart // ignore: cast_nullable_to_non_nullable
as bool,managementEditable: null == managementEditable ? _self.managementEditable : managementEditable // ignore: cast_nullable_to_non_nullable
as bool,users: null == users ? _self._users : users // ignore: cast_nullable_to_non_nullable
as List<VirtGuestRef>,
  ));
}


}

/// @nodoc
mixin _$VirtSnapChainFile {

 String get path;/// `qcow2`, `raw`, ...
 String? get format;/// Bytes it takes on the host.
 int? get allocation;/// The layer below it; null for the base image.
 String? get backing;/// The snapshot this layer belongs to, where one does.
 String? get snap;/// The file the guest is on now.
 bool get active;
/// Create a copy of VirtSnapChainFile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtSnapChainFileCopyWith<VirtSnapChainFile> get copyWith => _$VirtSnapChainFileCopyWithImpl<VirtSnapChainFile>(this as VirtSnapChainFile, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtSnapChainFile&&(identical(other.path, path) || other.path == path)&&(identical(other.format, format) || other.format == format)&&(identical(other.allocation, allocation) || other.allocation == allocation)&&(identical(other.backing, backing) || other.backing == backing)&&(identical(other.snap, snap) || other.snap == snap)&&(identical(other.active, active) || other.active == active));
}


@override
int get hashCode => Object.hash(runtimeType,path,format,allocation,backing,snap,active);

@override
String toString() {
  return 'VirtSnapChainFile(path: $path, format: $format, allocation: $allocation, backing: $backing, snap: $snap, active: $active)';
}


}

/// @nodoc
abstract mixin class $VirtSnapChainFileCopyWith<$Res>  {
  factory $VirtSnapChainFileCopyWith(VirtSnapChainFile value, $Res Function(VirtSnapChainFile) _then) = _$VirtSnapChainFileCopyWithImpl;
@useResult
$Res call({
 String path, String? format, int? allocation, String? backing, String? snap, bool active
});




}
/// @nodoc
class _$VirtSnapChainFileCopyWithImpl<$Res>
    implements $VirtSnapChainFileCopyWith<$Res> {
  _$VirtSnapChainFileCopyWithImpl(this._self, this._then);

  final VirtSnapChainFile _self;
  final $Res Function(VirtSnapChainFile) _then;

/// Create a copy of VirtSnapChainFile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? format = freezed,Object? allocation = freezed,Object? backing = freezed,Object? snap = freezed,Object? active = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,allocation: freezed == allocation ? _self.allocation : allocation // ignore: cast_nullable_to_non_nullable
as int?,backing: freezed == backing ? _self.backing : backing // ignore: cast_nullable_to_non_nullable
as String?,snap: freezed == snap ? _self.snap : snap // ignore: cast_nullable_to_non_nullable
as String?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtSnapChainFile].
extension VirtSnapChainFilePatterns on VirtSnapChainFile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtSnapChainFile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtSnapChainFile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtSnapChainFile value)  $default,){
final _that = this;
switch (_that) {
case _VirtSnapChainFile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtSnapChainFile value)?  $default,){
final _that = this;
switch (_that) {
case _VirtSnapChainFile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  String? format,  int? allocation,  String? backing,  String? snap,  bool active)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtSnapChainFile() when $default != null:
return $default(_that.path,_that.format,_that.allocation,_that.backing,_that.snap,_that.active);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  String? format,  int? allocation,  String? backing,  String? snap,  bool active)  $default,) {final _that = this;
switch (_that) {
case _VirtSnapChainFile():
return $default(_that.path,_that.format,_that.allocation,_that.backing,_that.snap,_that.active);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  String? format,  int? allocation,  String? backing,  String? snap,  bool active)?  $default,) {final _that = this;
switch (_that) {
case _VirtSnapChainFile() when $default != null:
return $default(_that.path,_that.format,_that.allocation,_that.backing,_that.snap,_that.active);case _:
  return null;

}
}

}

/// @nodoc


class _VirtSnapChainFile extends VirtSnapChainFile {
  const _VirtSnapChainFile({required this.path, this.format, this.allocation, this.backing, this.snap, this.active = false}): super._();
  

@override final  String path;
/// `qcow2`, `raw`, ...
@override final  String? format;
/// Bytes it takes on the host.
@override final  int? allocation;
/// The layer below it; null for the base image.
@override final  String? backing;
/// The snapshot this layer belongs to, where one does.
@override final  String? snap;
/// The file the guest is on now.
@override@JsonKey() final  bool active;

/// Create a copy of VirtSnapChainFile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtSnapChainFileCopyWith<_VirtSnapChainFile> get copyWith => __$VirtSnapChainFileCopyWithImpl<_VirtSnapChainFile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtSnapChainFile&&(identical(other.path, path) || other.path == path)&&(identical(other.format, format) || other.format == format)&&(identical(other.allocation, allocation) || other.allocation == allocation)&&(identical(other.backing, backing) || other.backing == backing)&&(identical(other.snap, snap) || other.snap == snap)&&(identical(other.active, active) || other.active == active));
}


@override
int get hashCode => Object.hash(runtimeType,path,format,allocation,backing,snap,active);

@override
String toString() {
  return 'VirtSnapChainFile(path: $path, format: $format, allocation: $allocation, backing: $backing, snap: $snap, active: $active)';
}


}

/// @nodoc
abstract mixin class _$VirtSnapChainFileCopyWith<$Res> implements $VirtSnapChainFileCopyWith<$Res> {
  factory _$VirtSnapChainFileCopyWith(_VirtSnapChainFile value, $Res Function(_VirtSnapChainFile) _then) = __$VirtSnapChainFileCopyWithImpl;
@override @useResult
$Res call({
 String path, String? format, int? allocation, String? backing, String? snap, bool active
});




}
/// @nodoc
class __$VirtSnapChainFileCopyWithImpl<$Res>
    implements _$VirtSnapChainFileCopyWith<$Res> {
  __$VirtSnapChainFileCopyWithImpl(this._self, this._then);

  final _VirtSnapChainFile _self;
  final $Res Function(_VirtSnapChainFile) _then;

/// Create a copy of VirtSnapChainFile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? format = freezed,Object? allocation = freezed,Object? backing = freezed,Object? snap = freezed,Object? active = null,}) {
  return _then(_VirtSnapChainFile(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,allocation: freezed == allocation ? _self.allocation : allocation // ignore: cast_nullable_to_non_nullable
as int?,backing: freezed == backing ? _self.backing : backing // ignore: cast_nullable_to_non_nullable
as String?,snap: freezed == snap ? _self.snap : snap // ignore: cast_nullable_to_non_nullable
as String?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$VirtSnapChainDisk {

 String get target;/// Topmost first: `files.first` is what the guest writes to now.
 List<VirtSnapChainFile> get files;/// The pool whose directory holds the topmost file, where one does.
 String? get pool;/// Why the host could not read the disk's chain, in its words.
 String? get error;
/// Create a copy of VirtSnapChainDisk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtSnapChainDiskCopyWith<VirtSnapChainDisk> get copyWith => _$VirtSnapChainDiskCopyWithImpl<VirtSnapChainDisk>(this as VirtSnapChainDisk, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtSnapChainDisk&&(identical(other.target, target) || other.target == target)&&const DeepCollectionEquality().equals(other.files, files)&&(identical(other.pool, pool) || other.pool == pool)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,target,const DeepCollectionEquality().hash(files),pool,error);

@override
String toString() {
  return 'VirtSnapChainDisk(target: $target, files: $files, pool: $pool, error: $error)';
}


}

/// @nodoc
abstract mixin class $VirtSnapChainDiskCopyWith<$Res>  {
  factory $VirtSnapChainDiskCopyWith(VirtSnapChainDisk value, $Res Function(VirtSnapChainDisk) _then) = _$VirtSnapChainDiskCopyWithImpl;
@useResult
$Res call({
 String target, List<VirtSnapChainFile> files, String? pool, String? error
});




}
/// @nodoc
class _$VirtSnapChainDiskCopyWithImpl<$Res>
    implements $VirtSnapChainDiskCopyWith<$Res> {
  _$VirtSnapChainDiskCopyWithImpl(this._self, this._then);

  final VirtSnapChainDisk _self;
  final $Res Function(VirtSnapChainDisk) _then;

/// Create a copy of VirtSnapChainDisk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? files = null,Object? pool = freezed,Object? error = freezed,}) {
  return _then(_self.copyWith(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,files: null == files ? _self.files : files // ignore: cast_nullable_to_non_nullable
as List<VirtSnapChainFile>,pool: freezed == pool ? _self.pool : pool // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtSnapChainDisk].
extension VirtSnapChainDiskPatterns on VirtSnapChainDisk {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtSnapChainDisk value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtSnapChainDisk() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtSnapChainDisk value)  $default,){
final _that = this;
switch (_that) {
case _VirtSnapChainDisk():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtSnapChainDisk value)?  $default,){
final _that = this;
switch (_that) {
case _VirtSnapChainDisk() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String target,  List<VirtSnapChainFile> files,  String? pool,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtSnapChainDisk() when $default != null:
return $default(_that.target,_that.files,_that.pool,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String target,  List<VirtSnapChainFile> files,  String? pool,  String? error)  $default,) {final _that = this;
switch (_that) {
case _VirtSnapChainDisk():
return $default(_that.target,_that.files,_that.pool,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String target,  List<VirtSnapChainFile> files,  String? pool,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _VirtSnapChainDisk() when $default != null:
return $default(_that.target,_that.files,_that.pool,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _VirtSnapChainDisk extends VirtSnapChainDisk {
  const _VirtSnapChainDisk({required this.target, final  List<VirtSnapChainFile> files = const <VirtSnapChainFile>[], this.pool, this.error}): _files = files,super._();
  

@override final  String target;
/// Topmost first: `files.first` is what the guest writes to now.
 final  List<VirtSnapChainFile> _files;
/// Topmost first: `files.first` is what the guest writes to now.
@override@JsonKey() List<VirtSnapChainFile> get files {
  if (_files is EqualUnmodifiableListView) return _files;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_files);
}

/// The pool whose directory holds the topmost file, where one does.
@override final  String? pool;
/// Why the host could not read the disk's chain, in its words.
@override final  String? error;

/// Create a copy of VirtSnapChainDisk
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtSnapChainDiskCopyWith<_VirtSnapChainDisk> get copyWith => __$VirtSnapChainDiskCopyWithImpl<_VirtSnapChainDisk>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtSnapChainDisk&&(identical(other.target, target) || other.target == target)&&const DeepCollectionEquality().equals(other._files, _files)&&(identical(other.pool, pool) || other.pool == pool)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,target,const DeepCollectionEquality().hash(_files),pool,error);

@override
String toString() {
  return 'VirtSnapChainDisk(target: $target, files: $files, pool: $pool, error: $error)';
}


}

/// @nodoc
abstract mixin class _$VirtSnapChainDiskCopyWith<$Res> implements $VirtSnapChainDiskCopyWith<$Res> {
  factory _$VirtSnapChainDiskCopyWith(_VirtSnapChainDisk value, $Res Function(_VirtSnapChainDisk) _then) = __$VirtSnapChainDiskCopyWithImpl;
@override @useResult
$Res call({
 String target, List<VirtSnapChainFile> files, String? pool, String? error
});




}
/// @nodoc
class __$VirtSnapChainDiskCopyWithImpl<$Res>
    implements _$VirtSnapChainDiskCopyWith<$Res> {
  __$VirtSnapChainDiskCopyWithImpl(this._self, this._then);

  final _VirtSnapChainDisk _self;
  final $Res Function(_VirtSnapChainDisk) _then;

/// Create a copy of VirtSnapChainDisk
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? files = null,Object? pool = freezed,Object? error = freezed,}) {
  return _then(_VirtSnapChainDisk(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,files: null == files ? _self._files : files // ignore: cast_nullable_to_non_nullable
as List<VirtSnapChainFile>,pool: freezed == pool ? _self.pool : pool // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$VirtSnapChain {

 List<VirtSnapChainDisk> get disks;/// Why no snapshot at all can be taken: a disk known not to be qcow2.
 String? get refusal;/// Why an external snapshot cannot be taken, asked of the host's own
/// read: everything [refusal] says, and a disk whose chain could not be
/// read or cannot be trusted.
 String? get externalRefusal;/// The pools an overlay can be placed in, by name: active pools that
/// hold files in a directory (`virtPoolHoldsFiles`).
 List<String> get pools;
/// Create a copy of VirtSnapChain
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtSnapChainCopyWith<VirtSnapChain> get copyWith => _$VirtSnapChainCopyWithImpl<VirtSnapChain>(this as VirtSnapChain, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtSnapChain&&const DeepCollectionEquality().equals(other.disks, disks)&&(identical(other.refusal, refusal) || other.refusal == refusal)&&(identical(other.externalRefusal, externalRefusal) || other.externalRefusal == externalRefusal)&&const DeepCollectionEquality().equals(other.pools, pools));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(disks),refusal,externalRefusal,const DeepCollectionEquality().hash(pools));

@override
String toString() {
  return 'VirtSnapChain(disks: $disks, refusal: $refusal, externalRefusal: $externalRefusal, pools: $pools)';
}


}

/// @nodoc
abstract mixin class $VirtSnapChainCopyWith<$Res>  {
  factory $VirtSnapChainCopyWith(VirtSnapChain value, $Res Function(VirtSnapChain) _then) = _$VirtSnapChainCopyWithImpl;
@useResult
$Res call({
 List<VirtSnapChainDisk> disks, String? refusal, String? externalRefusal, List<String> pools
});




}
/// @nodoc
class _$VirtSnapChainCopyWithImpl<$Res>
    implements $VirtSnapChainCopyWith<$Res> {
  _$VirtSnapChainCopyWithImpl(this._self, this._then);

  final VirtSnapChain _self;
  final $Res Function(VirtSnapChain) _then;

/// Create a copy of VirtSnapChain
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? disks = null,Object? refusal = freezed,Object? externalRefusal = freezed,Object? pools = null,}) {
  return _then(_self.copyWith(
disks: null == disks ? _self.disks : disks // ignore: cast_nullable_to_non_nullable
as List<VirtSnapChainDisk>,refusal: freezed == refusal ? _self.refusal : refusal // ignore: cast_nullable_to_non_nullable
as String?,externalRefusal: freezed == externalRefusal ? _self.externalRefusal : externalRefusal // ignore: cast_nullable_to_non_nullable
as String?,pools: null == pools ? _self.pools : pools // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtSnapChain].
extension VirtSnapChainPatterns on VirtSnapChain {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtSnapChain value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtSnapChain() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtSnapChain value)  $default,){
final _that = this;
switch (_that) {
case _VirtSnapChain():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtSnapChain value)?  $default,){
final _that = this;
switch (_that) {
case _VirtSnapChain() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<VirtSnapChainDisk> disks,  String? refusal,  String? externalRefusal,  List<String> pools)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtSnapChain() when $default != null:
return $default(_that.disks,_that.refusal,_that.externalRefusal,_that.pools);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<VirtSnapChainDisk> disks,  String? refusal,  String? externalRefusal,  List<String> pools)  $default,) {final _that = this;
switch (_that) {
case _VirtSnapChain():
return $default(_that.disks,_that.refusal,_that.externalRefusal,_that.pools);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<VirtSnapChainDisk> disks,  String? refusal,  String? externalRefusal,  List<String> pools)?  $default,) {final _that = this;
switch (_that) {
case _VirtSnapChain() when $default != null:
return $default(_that.disks,_that.refusal,_that.externalRefusal,_that.pools);case _:
  return null;

}
}

}

/// @nodoc


class _VirtSnapChain extends VirtSnapChain {
  const _VirtSnapChain({final  List<VirtSnapChainDisk> disks = const <VirtSnapChainDisk>[], this.refusal, this.externalRefusal, final  List<String> pools = const <String>[]}): _disks = disks,_pools = pools,super._();
  

 final  List<VirtSnapChainDisk> _disks;
@override@JsonKey() List<VirtSnapChainDisk> get disks {
  if (_disks is EqualUnmodifiableListView) return _disks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_disks);
}

/// Why no snapshot at all can be taken: a disk known not to be qcow2.
@override final  String? refusal;
/// Why an external snapshot cannot be taken, asked of the host's own
/// read: everything [refusal] says, and a disk whose chain could not be
/// read or cannot be trusted.
@override final  String? externalRefusal;
/// The pools an overlay can be placed in, by name: active pools that
/// hold files in a directory (`virtPoolHoldsFiles`).
 final  List<String> _pools;
/// The pools an overlay can be placed in, by name: active pools that
/// hold files in a directory (`virtPoolHoldsFiles`).
@override@JsonKey() List<String> get pools {
  if (_pools is EqualUnmodifiableListView) return _pools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pools);
}


/// Create a copy of VirtSnapChain
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtSnapChainCopyWith<_VirtSnapChain> get copyWith => __$VirtSnapChainCopyWithImpl<_VirtSnapChain>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtSnapChain&&const DeepCollectionEquality().equals(other._disks, _disks)&&(identical(other.refusal, refusal) || other.refusal == refusal)&&(identical(other.externalRefusal, externalRefusal) || other.externalRefusal == externalRefusal)&&const DeepCollectionEquality().equals(other._pools, _pools));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_disks),refusal,externalRefusal,const DeepCollectionEquality().hash(_pools));

@override
String toString() {
  return 'VirtSnapChain(disks: $disks, refusal: $refusal, externalRefusal: $externalRefusal, pools: $pools)';
}


}

/// @nodoc
abstract mixin class _$VirtSnapChainCopyWith<$Res> implements $VirtSnapChainCopyWith<$Res> {
  factory _$VirtSnapChainCopyWith(_VirtSnapChain value, $Res Function(_VirtSnapChain) _then) = __$VirtSnapChainCopyWithImpl;
@override @useResult
$Res call({
 List<VirtSnapChainDisk> disks, String? refusal, String? externalRefusal, List<String> pools
});




}
/// @nodoc
class __$VirtSnapChainCopyWithImpl<$Res>
    implements _$VirtSnapChainCopyWith<$Res> {
  __$VirtSnapChainCopyWithImpl(this._self, this._then);

  final _VirtSnapChain _self;
  final $Res Function(_VirtSnapChain) _then;

/// Create a copy of VirtSnapChain
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? disks = null,Object? refusal = freezed,Object? externalRefusal = freezed,Object? pools = null,}) {
  return _then(_VirtSnapChain(
disks: null == disks ? _self._disks : disks // ignore: cast_nullable_to_non_nullable
as List<VirtSnapChainDisk>,refusal: freezed == refusal ? _self.refusal : refusal // ignore: cast_nullable_to_non_nullable
as String?,externalRefusal: freezed == externalRefusal ? _self.externalRefusal : externalRefusal // ignore: cast_nullable_to_non_nullable
as String?,pools: null == pools ? _self._pools : pools // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$VirtSnapDiff {

 VirtSnapDiffGroup get group;/// The configuration key, e.g. `vcpu`, `scsi0`, `net0`.
 String get key;/// What the snapshot has.
 String? get before;/// What the guest has now.
 String? get after;
/// Create a copy of VirtSnapDiff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtSnapDiffCopyWith<VirtSnapDiff> get copyWith => _$VirtSnapDiffCopyWithImpl<VirtSnapDiff>(this as VirtSnapDiff, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtSnapDiff&&(identical(other.group, group) || other.group == group)&&(identical(other.key, key) || other.key == key)&&(identical(other.before, before) || other.before == before)&&(identical(other.after, after) || other.after == after));
}


@override
int get hashCode => Object.hash(runtimeType,group,key,before,after);

@override
String toString() {
  return 'VirtSnapDiff(group: $group, key: $key, before: $before, after: $after)';
}


}

/// @nodoc
abstract mixin class $VirtSnapDiffCopyWith<$Res>  {
  factory $VirtSnapDiffCopyWith(VirtSnapDiff value, $Res Function(VirtSnapDiff) _then) = _$VirtSnapDiffCopyWithImpl;
@useResult
$Res call({
 VirtSnapDiffGroup group, String key, String? before, String? after
});




}
/// @nodoc
class _$VirtSnapDiffCopyWithImpl<$Res>
    implements $VirtSnapDiffCopyWith<$Res> {
  _$VirtSnapDiffCopyWithImpl(this._self, this._then);

  final VirtSnapDiff _self;
  final $Res Function(VirtSnapDiff) _then;

/// Create a copy of VirtSnapDiff
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? group = null,Object? key = null,Object? before = freezed,Object? after = freezed,}) {
  return _then(_self.copyWith(
group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as VirtSnapDiffGroup,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,before: freezed == before ? _self.before : before // ignore: cast_nullable_to_non_nullable
as String?,after: freezed == after ? _self.after : after // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtSnapDiff].
extension VirtSnapDiffPatterns on VirtSnapDiff {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtSnapDiff value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtSnapDiff() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtSnapDiff value)  $default,){
final _that = this;
switch (_that) {
case _VirtSnapDiff():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtSnapDiff value)?  $default,){
final _that = this;
switch (_that) {
case _VirtSnapDiff() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( VirtSnapDiffGroup group,  String key,  String? before,  String? after)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtSnapDiff() when $default != null:
return $default(_that.group,_that.key,_that.before,_that.after);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( VirtSnapDiffGroup group,  String key,  String? before,  String? after)  $default,) {final _that = this;
switch (_that) {
case _VirtSnapDiff():
return $default(_that.group,_that.key,_that.before,_that.after);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( VirtSnapDiffGroup group,  String key,  String? before,  String? after)?  $default,) {final _that = this;
switch (_that) {
case _VirtSnapDiff() when $default != null:
return $default(_that.group,_that.key,_that.before,_that.after);case _:
  return null;

}
}

}

/// @nodoc


class _VirtSnapDiff extends VirtSnapDiff {
  const _VirtSnapDiff({required this.group, required this.key, this.before, this.after}): super._();
  

@override final  VirtSnapDiffGroup group;
/// The configuration key, e.g. `vcpu`, `scsi0`, `net0`.
@override final  String key;
/// What the snapshot has.
@override final  String? before;
/// What the guest has now.
@override final  String? after;

/// Create a copy of VirtSnapDiff
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtSnapDiffCopyWith<_VirtSnapDiff> get copyWith => __$VirtSnapDiffCopyWithImpl<_VirtSnapDiff>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtSnapDiff&&(identical(other.group, group) || other.group == group)&&(identical(other.key, key) || other.key == key)&&(identical(other.before, before) || other.before == before)&&(identical(other.after, after) || other.after == after));
}


@override
int get hashCode => Object.hash(runtimeType,group,key,before,after);

@override
String toString() {
  return 'VirtSnapDiff(group: $group, key: $key, before: $before, after: $after)';
}


}

/// @nodoc
abstract mixin class _$VirtSnapDiffCopyWith<$Res> implements $VirtSnapDiffCopyWith<$Res> {
  factory _$VirtSnapDiffCopyWith(_VirtSnapDiff value, $Res Function(_VirtSnapDiff) _then) = __$VirtSnapDiffCopyWithImpl;
@override @useResult
$Res call({
 VirtSnapDiffGroup group, String key, String? before, String? after
});




}
/// @nodoc
class __$VirtSnapDiffCopyWithImpl<$Res>
    implements _$VirtSnapDiffCopyWith<$Res> {
  __$VirtSnapDiffCopyWithImpl(this._self, this._then);

  final _VirtSnapDiff _self;
  final $Res Function(_VirtSnapDiff) _then;

/// Create a copy of VirtSnapDiff
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? group = null,Object? key = null,Object? before = freezed,Object? after = freezed,}) {
  return _then(_VirtSnapDiff(
group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as VirtSnapDiffGroup,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,before: freezed == before ? _self.before : before // ignore: cast_nullable_to_non_nullable
as String?,after: freezed == after ? _self.after : after // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
