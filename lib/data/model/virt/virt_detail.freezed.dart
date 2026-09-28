// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'virt_detail.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VirtDisk {

/// `disk`, `cdrom`, `floppy`, `lun`; PVE containers: `rootfs`, `mp`.
 String get device;/// libvirt's source kind (`file`, `block`, `network`, `volume`).
 String? get sourceType;/// Path, `pool/volume`, PVE `storage:volume`; null for an empty drive.
 String? get source;/// libvirt target (`vda`) or PVE key (`scsi0`, `rootfs`, `mp0`).
 String? get target; String? get bus;/// Image format, e.g. `qcow2`.
 String? get format; bool get readonly;/// Size in bytes, where the configuration says (PVE `size=`).
 int? get size;
/// Create a copy of VirtDisk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtDiskCopyWith<VirtDisk> get copyWith => _$VirtDiskCopyWithImpl<VirtDisk>(this as VirtDisk, _$identity);

  /// Serializes this VirtDisk to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtDisk&&(identical(other.device, device) || other.device == device)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.source, source) || other.source == source)&&(identical(other.target, target) || other.target == target)&&(identical(other.bus, bus) || other.bus == bus)&&(identical(other.format, format) || other.format == format)&&(identical(other.readonly, readonly) || other.readonly == readonly)&&(identical(other.size, size) || other.size == size));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,device,sourceType,source,target,bus,format,readonly,size);

@override
String toString() {
  return 'VirtDisk(device: $device, sourceType: $sourceType, source: $source, target: $target, bus: $bus, format: $format, readonly: $readonly, size: $size)';
}


}

/// @nodoc
abstract mixin class $VirtDiskCopyWith<$Res>  {
  factory $VirtDiskCopyWith(VirtDisk value, $Res Function(VirtDisk) _then) = _$VirtDiskCopyWithImpl;
@useResult
$Res call({
 String device, String? sourceType, String? source, String? target, String? bus, String? format, bool readonly, int? size
});




}
/// @nodoc
class _$VirtDiskCopyWithImpl<$Res>
    implements $VirtDiskCopyWith<$Res> {
  _$VirtDiskCopyWithImpl(this._self, this._then);

  final VirtDisk _self;
  final $Res Function(VirtDisk) _then;

/// Create a copy of VirtDisk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? device = null,Object? sourceType = freezed,Object? source = freezed,Object? target = freezed,Object? bus = freezed,Object? format = freezed,Object? readonly = null,Object? size = freezed,}) {
  return _then(_self.copyWith(
device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,sourceType: freezed == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String?,bus: freezed == bus ? _self.bus : bus // ignore: cast_nullable_to_non_nullable
as String?,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,readonly: null == readonly ? _self.readonly : readonly // ignore: cast_nullable_to_non_nullable
as bool,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtDisk].
extension VirtDiskPatterns on VirtDisk {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtDisk value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtDisk() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtDisk value)  $default,){
final _that = this;
switch (_that) {
case _VirtDisk():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtDisk value)?  $default,){
final _that = this;
switch (_that) {
case _VirtDisk() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String device,  String? sourceType,  String? source,  String? target,  String? bus,  String? format,  bool readonly,  int? size)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtDisk() when $default != null:
return $default(_that.device,_that.sourceType,_that.source,_that.target,_that.bus,_that.format,_that.readonly,_that.size);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String device,  String? sourceType,  String? source,  String? target,  String? bus,  String? format,  bool readonly,  int? size)  $default,) {final _that = this;
switch (_that) {
case _VirtDisk():
return $default(_that.device,_that.sourceType,_that.source,_that.target,_that.bus,_that.format,_that.readonly,_that.size);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String device,  String? sourceType,  String? source,  String? target,  String? bus,  String? format,  bool readonly,  int? size)?  $default,) {final _that = this;
switch (_that) {
case _VirtDisk() when $default != null:
return $default(_that.device,_that.sourceType,_that.source,_that.target,_that.bus,_that.format,_that.readonly,_that.size);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _VirtDisk implements VirtDisk {
  const _VirtDisk({this.device = 'disk', this.sourceType, this.source, this.target, this.bus, this.format, this.readonly = false, this.size});
  factory _VirtDisk.fromJson(Map<String, dynamic> json) => _$VirtDiskFromJson(json);

/// `disk`, `cdrom`, `floppy`, `lun`; PVE containers: `rootfs`, `mp`.
@override@JsonKey() final  String device;
/// libvirt's source kind (`file`, `block`, `network`, `volume`).
@override final  String? sourceType;
/// Path, `pool/volume`, PVE `storage:volume`; null for an empty drive.
@override final  String? source;
/// libvirt target (`vda`) or PVE key (`scsi0`, `rootfs`, `mp0`).
@override final  String? target;
@override final  String? bus;
/// Image format, e.g. `qcow2`.
@override final  String? format;
@override@JsonKey() final  bool readonly;
/// Size in bytes, where the configuration says (PVE `size=`).
@override final  int? size;

/// Create a copy of VirtDisk
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtDiskCopyWith<_VirtDisk> get copyWith => __$VirtDiskCopyWithImpl<_VirtDisk>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VirtDiskToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtDisk&&(identical(other.device, device) || other.device == device)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.source, source) || other.source == source)&&(identical(other.target, target) || other.target == target)&&(identical(other.bus, bus) || other.bus == bus)&&(identical(other.format, format) || other.format == format)&&(identical(other.readonly, readonly) || other.readonly == readonly)&&(identical(other.size, size) || other.size == size));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,device,sourceType,source,target,bus,format,readonly,size);

@override
String toString() {
  return 'VirtDisk(device: $device, sourceType: $sourceType, source: $source, target: $target, bus: $bus, format: $format, readonly: $readonly, size: $size)';
}


}

/// @nodoc
abstract mixin class _$VirtDiskCopyWith<$Res> implements $VirtDiskCopyWith<$Res> {
  factory _$VirtDiskCopyWith(_VirtDisk value, $Res Function(_VirtDisk) _then) = __$VirtDiskCopyWithImpl;
@override @useResult
$Res call({
 String device, String? sourceType, String? source, String? target, String? bus, String? format, bool readonly, int? size
});




}
/// @nodoc
class __$VirtDiskCopyWithImpl<$Res>
    implements _$VirtDiskCopyWith<$Res> {
  __$VirtDiskCopyWithImpl(this._self, this._then);

  final _VirtDisk _self;
  final $Res Function(_VirtDisk) _then;

/// Create a copy of VirtDisk
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? device = null,Object? sourceType = freezed,Object? source = freezed,Object? target = freezed,Object? bus = freezed,Object? format = freezed,Object? readonly = null,Object? size = freezed,}) {
  return _then(_VirtDisk(
device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,sourceType: freezed == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String?,bus: freezed == bus ? _self.bus : bus // ignore: cast_nullable_to_non_nullable
as String?,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,readonly: null == readonly ? _self.readonly : readonly // ignore: cast_nullable_to_non_nullable
as bool,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$VirtNic {

/// libvirt `network`/`bridge`/`direct`/...; PVE `net0`, `net1`, ...
 String get kind; String? get mac;/// Network, bridge or host device.
 String? get source;/// NIC model (`virtio`, `e1000e`), or `veth` for a container.
 String? get model;/// Host-side device while running (libvirt `vnetN`), or a container's
/// interface name (`eth0`).
 String? get target;
/// Create a copy of VirtNic
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtNicCopyWith<VirtNic> get copyWith => _$VirtNicCopyWithImpl<VirtNic>(this as VirtNic, _$identity);

  /// Serializes this VirtNic to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtNic&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.source, source) || other.source == source)&&(identical(other.model, model) || other.model == model)&&(identical(other.target, target) || other.target == target));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,mac,source,model,target);

@override
String toString() {
  return 'VirtNic(kind: $kind, mac: $mac, source: $source, model: $model, target: $target)';
}


}

/// @nodoc
abstract mixin class $VirtNicCopyWith<$Res>  {
  factory $VirtNicCopyWith(VirtNic value, $Res Function(VirtNic) _then) = _$VirtNicCopyWithImpl;
@useResult
$Res call({
 String kind, String? mac, String? source, String? model, String? target
});




}
/// @nodoc
class _$VirtNicCopyWithImpl<$Res>
    implements $VirtNicCopyWith<$Res> {
  _$VirtNicCopyWithImpl(this._self, this._then);

  final VirtNic _self;
  final $Res Function(VirtNic) _then;

/// Create a copy of VirtNic
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? mac = freezed,Object? source = freezed,Object? model = freezed,Object? target = freezed,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,mac: freezed == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtNic].
extension VirtNicPatterns on VirtNic {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtNic value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtNic() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtNic value)  $default,){
final _that = this;
switch (_that) {
case _VirtNic():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtNic value)?  $default,){
final _that = this;
switch (_that) {
case _VirtNic() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  String? mac,  String? source,  String? model,  String? target)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtNic() when $default != null:
return $default(_that.kind,_that.mac,_that.source,_that.model,_that.target);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  String? mac,  String? source,  String? model,  String? target)  $default,) {final _that = this;
switch (_that) {
case _VirtNic():
return $default(_that.kind,_that.mac,_that.source,_that.model,_that.target);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  String? mac,  String? source,  String? model,  String? target)?  $default,) {final _that = this;
switch (_that) {
case _VirtNic() when $default != null:
return $default(_that.kind,_that.mac,_that.source,_that.model,_that.target);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _VirtNic implements VirtNic {
  const _VirtNic({this.kind = '', this.mac, this.source, this.model, this.target});
  factory _VirtNic.fromJson(Map<String, dynamic> json) => _$VirtNicFromJson(json);

/// libvirt `network`/`bridge`/`direct`/...; PVE `net0`, `net1`, ...
@override@JsonKey() final  String kind;
@override final  String? mac;
/// Network, bridge or host device.
@override final  String? source;
/// NIC model (`virtio`, `e1000e`), or `veth` for a container.
@override final  String? model;
/// Host-side device while running (libvirt `vnetN`), or a container's
/// interface name (`eth0`).
@override final  String? target;

/// Create a copy of VirtNic
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtNicCopyWith<_VirtNic> get copyWith => __$VirtNicCopyWithImpl<_VirtNic>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VirtNicToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtNic&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.source, source) || other.source == source)&&(identical(other.model, model) || other.model == model)&&(identical(other.target, target) || other.target == target));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,mac,source,model,target);

@override
String toString() {
  return 'VirtNic(kind: $kind, mac: $mac, source: $source, model: $model, target: $target)';
}


}

/// @nodoc
abstract mixin class _$VirtNicCopyWith<$Res> implements $VirtNicCopyWith<$Res> {
  factory _$VirtNicCopyWith(_VirtNic value, $Res Function(_VirtNic) _then) = __$VirtNicCopyWithImpl;
@override @useResult
$Res call({
 String kind, String? mac, String? source, String? model, String? target
});




}
/// @nodoc
class __$VirtNicCopyWithImpl<$Res>
    implements _$VirtNicCopyWith<$Res> {
  __$VirtNicCopyWithImpl(this._self, this._then);

  final _VirtNic _self;
  final $Res Function(_VirtNic) _then;

/// Create a copy of VirtNic
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? mac = freezed,Object? source = freezed,Object? model = freezed,Object? target = freezed,}) {
  return _then(_VirtNic(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,mac: freezed == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$VirtGraphics {

/// `vnc`, `spice`, ...; PVE's `vga` type (`std`, `qxl`, `serial0`).
 String get kind; int? get port; int? get tlsPort; bool get autoport; String? get listen; String? get socket;
/// Create a copy of VirtGraphics
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtGraphicsCopyWith<VirtGraphics> get copyWith => _$VirtGraphicsCopyWithImpl<VirtGraphics>(this as VirtGraphics, _$identity);

  /// Serializes this VirtGraphics to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtGraphics&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.port, port) || other.port == port)&&(identical(other.tlsPort, tlsPort) || other.tlsPort == tlsPort)&&(identical(other.autoport, autoport) || other.autoport == autoport)&&(identical(other.listen, listen) || other.listen == listen)&&(identical(other.socket, socket) || other.socket == socket));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,port,tlsPort,autoport,listen,socket);

@override
String toString() {
  return 'VirtGraphics(kind: $kind, port: $port, tlsPort: $tlsPort, autoport: $autoport, listen: $listen, socket: $socket)';
}


}

/// @nodoc
abstract mixin class $VirtGraphicsCopyWith<$Res>  {
  factory $VirtGraphicsCopyWith(VirtGraphics value, $Res Function(VirtGraphics) _then) = _$VirtGraphicsCopyWithImpl;
@useResult
$Res call({
 String kind, int? port, int? tlsPort, bool autoport, String? listen, String? socket
});




}
/// @nodoc
class _$VirtGraphicsCopyWithImpl<$Res>
    implements $VirtGraphicsCopyWith<$Res> {
  _$VirtGraphicsCopyWithImpl(this._self, this._then);

  final VirtGraphics _self;
  final $Res Function(VirtGraphics) _then;

/// Create a copy of VirtGraphics
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? port = freezed,Object? tlsPort = freezed,Object? autoport = null,Object? listen = freezed,Object? socket = freezed,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int?,tlsPort: freezed == tlsPort ? _self.tlsPort : tlsPort // ignore: cast_nullable_to_non_nullable
as int?,autoport: null == autoport ? _self.autoport : autoport // ignore: cast_nullable_to_non_nullable
as bool,listen: freezed == listen ? _self.listen : listen // ignore: cast_nullable_to_non_nullable
as String?,socket: freezed == socket ? _self.socket : socket // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtGraphics].
extension VirtGraphicsPatterns on VirtGraphics {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtGraphics value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtGraphics() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtGraphics value)  $default,){
final _that = this;
switch (_that) {
case _VirtGraphics():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtGraphics value)?  $default,){
final _that = this;
switch (_that) {
case _VirtGraphics() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  int? port,  int? tlsPort,  bool autoport,  String? listen,  String? socket)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtGraphics() when $default != null:
return $default(_that.kind,_that.port,_that.tlsPort,_that.autoport,_that.listen,_that.socket);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  int? port,  int? tlsPort,  bool autoport,  String? listen,  String? socket)  $default,) {final _that = this;
switch (_that) {
case _VirtGraphics():
return $default(_that.kind,_that.port,_that.tlsPort,_that.autoport,_that.listen,_that.socket);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  int? port,  int? tlsPort,  bool autoport,  String? listen,  String? socket)?  $default,) {final _that = this;
switch (_that) {
case _VirtGraphics() when $default != null:
return $default(_that.kind,_that.port,_that.tlsPort,_that.autoport,_that.listen,_that.socket);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _VirtGraphics implements VirtGraphics {
  const _VirtGraphics({this.kind = '', this.port, this.tlsPort, this.autoport = false, this.listen, this.socket});
  factory _VirtGraphics.fromJson(Map<String, dynamic> json) => _$VirtGraphicsFromJson(json);

/// `vnc`, `spice`, ...; PVE's `vga` type (`std`, `qxl`, `serial0`).
@override@JsonKey() final  String kind;
@override final  int? port;
@override final  int? tlsPort;
@override@JsonKey() final  bool autoport;
@override final  String? listen;
@override final  String? socket;

/// Create a copy of VirtGraphics
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtGraphicsCopyWith<_VirtGraphics> get copyWith => __$VirtGraphicsCopyWithImpl<_VirtGraphics>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VirtGraphicsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtGraphics&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.port, port) || other.port == port)&&(identical(other.tlsPort, tlsPort) || other.tlsPort == tlsPort)&&(identical(other.autoport, autoport) || other.autoport == autoport)&&(identical(other.listen, listen) || other.listen == listen)&&(identical(other.socket, socket) || other.socket == socket));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,port,tlsPort,autoport,listen,socket);

@override
String toString() {
  return 'VirtGraphics(kind: $kind, port: $port, tlsPort: $tlsPort, autoport: $autoport, listen: $listen, socket: $socket)';
}


}

/// @nodoc
abstract mixin class _$VirtGraphicsCopyWith<$Res> implements $VirtGraphicsCopyWith<$Res> {
  factory _$VirtGraphicsCopyWith(_VirtGraphics value, $Res Function(_VirtGraphics) _then) = __$VirtGraphicsCopyWithImpl;
@override @useResult
$Res call({
 String kind, int? port, int? tlsPort, bool autoport, String? listen, String? socket
});




}
/// @nodoc
class __$VirtGraphicsCopyWithImpl<$Res>
    implements _$VirtGraphicsCopyWith<$Res> {
  __$VirtGraphicsCopyWithImpl(this._self, this._then);

  final _VirtGraphics _self;
  final $Res Function(_VirtGraphics) _then;

/// Create a copy of VirtGraphics
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? port = freezed,Object? tlsPort = freezed,Object? autoport = null,Object? listen = freezed,Object? socket = freezed,}) {
  return _then(_VirtGraphics(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int?,tlsPort: freezed == tlsPort ? _self.tlsPort : tlsPort // ignore: cast_nullable_to_non_nullable
as int?,autoport: null == autoport ? _self.autoport : autoport // ignore: cast_nullable_to_non_nullable
as bool,listen: freezed == listen ? _self.listen : listen // ignore: cast_nullable_to_non_nullable
as String?,socket: freezed == socket ? _self.socket : socket // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$VirtDisplay {

 String get uri; String get protocol;/// On the hypervisor's side; `localhost` means the hypervisor itself.
 String? get host; int? get port; int? get tlsPort; String? get socket;
/// Create a copy of VirtDisplay
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtDisplayCopyWith<VirtDisplay> get copyWith => _$VirtDisplayCopyWithImpl<VirtDisplay>(this as VirtDisplay, _$identity);

  /// Serializes this VirtDisplay to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtDisplay&&(identical(other.uri, uri) || other.uri == uri)&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.tlsPort, tlsPort) || other.tlsPort == tlsPort)&&(identical(other.socket, socket) || other.socket == socket));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uri,protocol,host,port,tlsPort,socket);

@override
String toString() {
  return 'VirtDisplay(uri: $uri, protocol: $protocol, host: $host, port: $port, tlsPort: $tlsPort, socket: $socket)';
}


}

/// @nodoc
abstract mixin class $VirtDisplayCopyWith<$Res>  {
  factory $VirtDisplayCopyWith(VirtDisplay value, $Res Function(VirtDisplay) _then) = _$VirtDisplayCopyWithImpl;
@useResult
$Res call({
 String uri, String protocol, String? host, int? port, int? tlsPort, String? socket
});




}
/// @nodoc
class _$VirtDisplayCopyWithImpl<$Res>
    implements $VirtDisplayCopyWith<$Res> {
  _$VirtDisplayCopyWithImpl(this._self, this._then);

  final VirtDisplay _self;
  final $Res Function(VirtDisplay) _then;

/// Create a copy of VirtDisplay
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uri = null,Object? protocol = null,Object? host = freezed,Object? port = freezed,Object? tlsPort = freezed,Object? socket = freezed,}) {
  return _then(_self.copyWith(
uri: null == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as String,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as String,host: freezed == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String?,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int?,tlsPort: freezed == tlsPort ? _self.tlsPort : tlsPort // ignore: cast_nullable_to_non_nullable
as int?,socket: freezed == socket ? _self.socket : socket // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtDisplay].
extension VirtDisplayPatterns on VirtDisplay {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtDisplay value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtDisplay() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtDisplay value)  $default,){
final _that = this;
switch (_that) {
case _VirtDisplay():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtDisplay value)?  $default,){
final _that = this;
switch (_that) {
case _VirtDisplay() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uri,  String protocol,  String? host,  int? port,  int? tlsPort,  String? socket)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtDisplay() when $default != null:
return $default(_that.uri,_that.protocol,_that.host,_that.port,_that.tlsPort,_that.socket);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uri,  String protocol,  String? host,  int? port,  int? tlsPort,  String? socket)  $default,) {final _that = this;
switch (_that) {
case _VirtDisplay():
return $default(_that.uri,_that.protocol,_that.host,_that.port,_that.tlsPort,_that.socket);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uri,  String protocol,  String? host,  int? port,  int? tlsPort,  String? socket)?  $default,) {final _that = this;
switch (_that) {
case _VirtDisplay() when $default != null:
return $default(_that.uri,_that.protocol,_that.host,_that.port,_that.tlsPort,_that.socket);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _VirtDisplay implements VirtDisplay {
  const _VirtDisplay({required this.uri, required this.protocol, this.host, this.port, this.tlsPort, this.socket});
  factory _VirtDisplay.fromJson(Map<String, dynamic> json) => _$VirtDisplayFromJson(json);

@override final  String uri;
@override final  String protocol;
/// On the hypervisor's side; `localhost` means the hypervisor itself.
@override final  String? host;
@override final  int? port;
@override final  int? tlsPort;
@override final  String? socket;

/// Create a copy of VirtDisplay
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtDisplayCopyWith<_VirtDisplay> get copyWith => __$VirtDisplayCopyWithImpl<_VirtDisplay>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VirtDisplayToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtDisplay&&(identical(other.uri, uri) || other.uri == uri)&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.tlsPort, tlsPort) || other.tlsPort == tlsPort)&&(identical(other.socket, socket) || other.socket == socket));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uri,protocol,host,port,tlsPort,socket);

@override
String toString() {
  return 'VirtDisplay(uri: $uri, protocol: $protocol, host: $host, port: $port, tlsPort: $tlsPort, socket: $socket)';
}


}

/// @nodoc
abstract mixin class _$VirtDisplayCopyWith<$Res> implements $VirtDisplayCopyWith<$Res> {
  factory _$VirtDisplayCopyWith(_VirtDisplay value, $Res Function(_VirtDisplay) _then) = __$VirtDisplayCopyWithImpl;
@override @useResult
$Res call({
 String uri, String protocol, String? host, int? port, int? tlsPort, String? socket
});




}
/// @nodoc
class __$VirtDisplayCopyWithImpl<$Res>
    implements _$VirtDisplayCopyWith<$Res> {
  __$VirtDisplayCopyWithImpl(this._self, this._then);

  final _VirtDisplay _self;
  final $Res Function(_VirtDisplay) _then;

/// Create a copy of VirtDisplay
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uri = null,Object? protocol = null,Object? host = freezed,Object? port = freezed,Object? tlsPort = freezed,Object? socket = freezed,}) {
  return _then(_VirtDisplay(
uri: null == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as String,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as String,host: freezed == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String?,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int?,tlsPort: freezed == tlsPort ? _self.tlsPort : tlsPort // ignore: cast_nullable_to_non_nullable
as int?,socket: freezed == socket ? _self.socket : socket // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$VirtGuestDetail {

 List<VirtDisk> get disks; List<VirtNic> get nics; List<VirtGraphics> get graphics;/// libvirt, while running with graphics.
 VirtDisplay? get display; Set<VirtConsoleKind> get consoles; String? get description; String? get arch;/// libvirt machine type, or PVE `ostype`.
 String? get machine;
/// Create a copy of VirtGuestDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtGuestDetailCopyWith<VirtGuestDetail> get copyWith => _$VirtGuestDetailCopyWithImpl<VirtGuestDetail>(this as VirtGuestDetail, _$identity);

  /// Serializes this VirtGuestDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtGuestDetail&&const DeepCollectionEquality().equals(other.disks, disks)&&const DeepCollectionEquality().equals(other.nics, nics)&&const DeepCollectionEquality().equals(other.graphics, graphics)&&(identical(other.display, display) || other.display == display)&&const DeepCollectionEquality().equals(other.consoles, consoles)&&(identical(other.description, description) || other.description == description)&&(identical(other.arch, arch) || other.arch == arch)&&(identical(other.machine, machine) || other.machine == machine));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(disks),const DeepCollectionEquality().hash(nics),const DeepCollectionEquality().hash(graphics),display,const DeepCollectionEquality().hash(consoles),description,arch,machine);

@override
String toString() {
  return 'VirtGuestDetail(disks: $disks, nics: $nics, graphics: $graphics, display: $display, consoles: $consoles, description: $description, arch: $arch, machine: $machine)';
}


}

/// @nodoc
abstract mixin class $VirtGuestDetailCopyWith<$Res>  {
  factory $VirtGuestDetailCopyWith(VirtGuestDetail value, $Res Function(VirtGuestDetail) _then) = _$VirtGuestDetailCopyWithImpl;
@useResult
$Res call({
 List<VirtDisk> disks, List<VirtNic> nics, List<VirtGraphics> graphics, VirtDisplay? display, Set<VirtConsoleKind> consoles, String? description, String? arch, String? machine
});


$VirtDisplayCopyWith<$Res>? get display;

}
/// @nodoc
class _$VirtGuestDetailCopyWithImpl<$Res>
    implements $VirtGuestDetailCopyWith<$Res> {
  _$VirtGuestDetailCopyWithImpl(this._self, this._then);

  final VirtGuestDetail _self;
  final $Res Function(VirtGuestDetail) _then;

/// Create a copy of VirtGuestDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? disks = null,Object? nics = null,Object? graphics = null,Object? display = freezed,Object? consoles = null,Object? description = freezed,Object? arch = freezed,Object? machine = freezed,}) {
  return _then(_self.copyWith(
disks: null == disks ? _self.disks : disks // ignore: cast_nullable_to_non_nullable
as List<VirtDisk>,nics: null == nics ? _self.nics : nics // ignore: cast_nullable_to_non_nullable
as List<VirtNic>,graphics: null == graphics ? _self.graphics : graphics // ignore: cast_nullable_to_non_nullable
as List<VirtGraphics>,display: freezed == display ? _self.display : display // ignore: cast_nullable_to_non_nullable
as VirtDisplay?,consoles: null == consoles ? _self.consoles : consoles // ignore: cast_nullable_to_non_nullable
as Set<VirtConsoleKind>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,arch: freezed == arch ? _self.arch : arch // ignore: cast_nullable_to_non_nullable
as String?,machine: freezed == machine ? _self.machine : machine // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of VirtGuestDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtDisplayCopyWith<$Res>? get display {
    if (_self.display == null) {
    return null;
  }

  return $VirtDisplayCopyWith<$Res>(_self.display!, (value) {
    return _then(_self.copyWith(display: value));
  });
}
}


/// Adds pattern-matching-related methods to [VirtGuestDetail].
extension VirtGuestDetailPatterns on VirtGuestDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtGuestDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtGuestDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtGuestDetail value)  $default,){
final _that = this;
switch (_that) {
case _VirtGuestDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtGuestDetail value)?  $default,){
final _that = this;
switch (_that) {
case _VirtGuestDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<VirtDisk> disks,  List<VirtNic> nics,  List<VirtGraphics> graphics,  VirtDisplay? display,  Set<VirtConsoleKind> consoles,  String? description,  String? arch,  String? machine)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtGuestDetail() when $default != null:
return $default(_that.disks,_that.nics,_that.graphics,_that.display,_that.consoles,_that.description,_that.arch,_that.machine);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<VirtDisk> disks,  List<VirtNic> nics,  List<VirtGraphics> graphics,  VirtDisplay? display,  Set<VirtConsoleKind> consoles,  String? description,  String? arch,  String? machine)  $default,) {final _that = this;
switch (_that) {
case _VirtGuestDetail():
return $default(_that.disks,_that.nics,_that.graphics,_that.display,_that.consoles,_that.description,_that.arch,_that.machine);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<VirtDisk> disks,  List<VirtNic> nics,  List<VirtGraphics> graphics,  VirtDisplay? display,  Set<VirtConsoleKind> consoles,  String? description,  String? arch,  String? machine)?  $default,) {final _that = this;
switch (_that) {
case _VirtGuestDetail() when $default != null:
return $default(_that.disks,_that.nics,_that.graphics,_that.display,_that.consoles,_that.description,_that.arch,_that.machine);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VirtGuestDetail implements VirtGuestDetail {
  const _VirtGuestDetail({final  List<VirtDisk> disks = const <VirtDisk>[], final  List<VirtNic> nics = const <VirtNic>[], final  List<VirtGraphics> graphics = const <VirtGraphics>[], this.display, final  Set<VirtConsoleKind> consoles = const <VirtConsoleKind>{}, this.description, this.arch, this.machine}): _disks = disks,_nics = nics,_graphics = graphics,_consoles = consoles;
  factory _VirtGuestDetail.fromJson(Map<String, dynamic> json) => _$VirtGuestDetailFromJson(json);

 final  List<VirtDisk> _disks;
@override@JsonKey() List<VirtDisk> get disks {
  if (_disks is EqualUnmodifiableListView) return _disks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_disks);
}

 final  List<VirtNic> _nics;
@override@JsonKey() List<VirtNic> get nics {
  if (_nics is EqualUnmodifiableListView) return _nics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nics);
}

 final  List<VirtGraphics> _graphics;
@override@JsonKey() List<VirtGraphics> get graphics {
  if (_graphics is EqualUnmodifiableListView) return _graphics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_graphics);
}

/// libvirt, while running with graphics.
@override final  VirtDisplay? display;
 final  Set<VirtConsoleKind> _consoles;
@override@JsonKey() Set<VirtConsoleKind> get consoles {
  if (_consoles is EqualUnmodifiableSetView) return _consoles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_consoles);
}

@override final  String? description;
@override final  String? arch;
/// libvirt machine type, or PVE `ostype`.
@override final  String? machine;

/// Create a copy of VirtGuestDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtGuestDetailCopyWith<_VirtGuestDetail> get copyWith => __$VirtGuestDetailCopyWithImpl<_VirtGuestDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VirtGuestDetailToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtGuestDetail&&const DeepCollectionEquality().equals(other._disks, _disks)&&const DeepCollectionEquality().equals(other._nics, _nics)&&const DeepCollectionEquality().equals(other._graphics, _graphics)&&(identical(other.display, display) || other.display == display)&&const DeepCollectionEquality().equals(other._consoles, _consoles)&&(identical(other.description, description) || other.description == description)&&(identical(other.arch, arch) || other.arch == arch)&&(identical(other.machine, machine) || other.machine == machine));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_disks),const DeepCollectionEquality().hash(_nics),const DeepCollectionEquality().hash(_graphics),display,const DeepCollectionEquality().hash(_consoles),description,arch,machine);

@override
String toString() {
  return 'VirtGuestDetail(disks: $disks, nics: $nics, graphics: $graphics, display: $display, consoles: $consoles, description: $description, arch: $arch, machine: $machine)';
}


}

/// @nodoc
abstract mixin class _$VirtGuestDetailCopyWith<$Res> implements $VirtGuestDetailCopyWith<$Res> {
  factory _$VirtGuestDetailCopyWith(_VirtGuestDetail value, $Res Function(_VirtGuestDetail) _then) = __$VirtGuestDetailCopyWithImpl;
@override @useResult
$Res call({
 List<VirtDisk> disks, List<VirtNic> nics, List<VirtGraphics> graphics, VirtDisplay? display, Set<VirtConsoleKind> consoles, String? description, String? arch, String? machine
});


@override $VirtDisplayCopyWith<$Res>? get display;

}
/// @nodoc
class __$VirtGuestDetailCopyWithImpl<$Res>
    implements _$VirtGuestDetailCopyWith<$Res> {
  __$VirtGuestDetailCopyWithImpl(this._self, this._then);

  final _VirtGuestDetail _self;
  final $Res Function(_VirtGuestDetail) _then;

/// Create a copy of VirtGuestDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? disks = null,Object? nics = null,Object? graphics = null,Object? display = freezed,Object? consoles = null,Object? description = freezed,Object? arch = freezed,Object? machine = freezed,}) {
  return _then(_VirtGuestDetail(
disks: null == disks ? _self._disks : disks // ignore: cast_nullable_to_non_nullable
as List<VirtDisk>,nics: null == nics ? _self._nics : nics // ignore: cast_nullable_to_non_nullable
as List<VirtNic>,graphics: null == graphics ? _self._graphics : graphics // ignore: cast_nullable_to_non_nullable
as List<VirtGraphics>,display: freezed == display ? _self.display : display // ignore: cast_nullable_to_non_nullable
as VirtDisplay?,consoles: null == consoles ? _self._consoles : consoles // ignore: cast_nullable_to_non_nullable
as Set<VirtConsoleKind>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,arch: freezed == arch ? _self.arch : arch // ignore: cast_nullable_to_non_nullable
as String?,machine: freezed == machine ? _self.machine : machine // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of VirtGuestDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtDisplayCopyWith<$Res>? get display {
    if (_self.display == null) {
    return null;
  }

  return $VirtDisplayCopyWith<$Res>(_self.display!, (value) {
    return _then(_self.copyWith(display: value));
  });
}
}

// dart format on
