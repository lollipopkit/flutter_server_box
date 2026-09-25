// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'libvirt.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LibvirtVersion {

 String? get libvirt; String? get hypervisor; String? get hypervisorVersion;
/// Create a copy of LibvirtVersion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtVersionCopyWith<LibvirtVersion> get copyWith => _$LibvirtVersionCopyWithImpl<LibvirtVersion>(this as LibvirtVersion, _$identity);

  /// Serializes this LibvirtVersion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtVersion&&(identical(other.libvirt, libvirt) || other.libvirt == libvirt)&&(identical(other.hypervisor, hypervisor) || other.hypervisor == hypervisor)&&(identical(other.hypervisorVersion, hypervisorVersion) || other.hypervisorVersion == hypervisorVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,libvirt,hypervisor,hypervisorVersion);

@override
String toString() {
  return 'LibvirtVersion(libvirt: $libvirt, hypervisor: $hypervisor, hypervisorVersion: $hypervisorVersion)';
}


}

/// @nodoc
abstract mixin class $LibvirtVersionCopyWith<$Res>  {
  factory $LibvirtVersionCopyWith(LibvirtVersion value, $Res Function(LibvirtVersion) _then) = _$LibvirtVersionCopyWithImpl;
@useResult
$Res call({
 String? libvirt, String? hypervisor, String? hypervisorVersion
});




}
/// @nodoc
class _$LibvirtVersionCopyWithImpl<$Res>
    implements $LibvirtVersionCopyWith<$Res> {
  _$LibvirtVersionCopyWithImpl(this._self, this._then);

  final LibvirtVersion _self;
  final $Res Function(LibvirtVersion) _then;

/// Create a copy of LibvirtVersion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? libvirt = freezed,Object? hypervisor = freezed,Object? hypervisorVersion = freezed,}) {
  return _then(_self.copyWith(
libvirt: freezed == libvirt ? _self.libvirt : libvirt // ignore: cast_nullable_to_non_nullable
as String?,hypervisor: freezed == hypervisor ? _self.hypervisor : hypervisor // ignore: cast_nullable_to_non_nullable
as String?,hypervisorVersion: freezed == hypervisorVersion ? _self.hypervisorVersion : hypervisorVersion // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtVersion].
extension LibvirtVersionPatterns on LibvirtVersion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtVersion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtVersion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtVersion value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtVersion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtVersion value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtVersion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? libvirt,  String? hypervisor,  String? hypervisorVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtVersion() when $default != null:
return $default(_that.libvirt,_that.hypervisor,_that.hypervisorVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? libvirt,  String? hypervisor,  String? hypervisorVersion)  $default,) {final _that = this;
switch (_that) {
case _LibvirtVersion():
return $default(_that.libvirt,_that.hypervisor,_that.hypervisorVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? libvirt,  String? hypervisor,  String? hypervisorVersion)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtVersion() when $default != null:
return $default(_that.libvirt,_that.hypervisor,_that.hypervisorVersion);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtVersion implements LibvirtVersion {
  const _LibvirtVersion({this.libvirt, this.hypervisor, this.hypervisorVersion});
  factory _LibvirtVersion.fromJson(Map<String, dynamic> json) => _$LibvirtVersionFromJson(json);

@override final  String? libvirt;
@override final  String? hypervisor;
@override final  String? hypervisorVersion;

/// Create a copy of LibvirtVersion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtVersionCopyWith<_LibvirtVersion> get copyWith => __$LibvirtVersionCopyWithImpl<_LibvirtVersion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtVersionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtVersion&&(identical(other.libvirt, libvirt) || other.libvirt == libvirt)&&(identical(other.hypervisor, hypervisor) || other.hypervisor == hypervisor)&&(identical(other.hypervisorVersion, hypervisorVersion) || other.hypervisorVersion == hypervisorVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,libvirt,hypervisor,hypervisorVersion);

@override
String toString() {
  return 'LibvirtVersion(libvirt: $libvirt, hypervisor: $hypervisor, hypervisorVersion: $hypervisorVersion)';
}


}

/// @nodoc
abstract mixin class _$LibvirtVersionCopyWith<$Res> implements $LibvirtVersionCopyWith<$Res> {
  factory _$LibvirtVersionCopyWith(_LibvirtVersion value, $Res Function(_LibvirtVersion) _then) = __$LibvirtVersionCopyWithImpl;
@override @useResult
$Res call({
 String? libvirt, String? hypervisor, String? hypervisorVersion
});




}
/// @nodoc
class __$LibvirtVersionCopyWithImpl<$Res>
    implements _$LibvirtVersionCopyWith<$Res> {
  __$LibvirtVersionCopyWithImpl(this._self, this._then);

  final _LibvirtVersion _self;
  final $Res Function(_LibvirtVersion) _then;

/// Create a copy of LibvirtVersion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? libvirt = freezed,Object? hypervisor = freezed,Object? hypervisorVersion = freezed,}) {
  return _then(_LibvirtVersion(
libvirt: freezed == libvirt ? _self.libvirt : libvirt // ignore: cast_nullable_to_non_nullable
as String?,hypervisor: freezed == hypervisor ? _self.hypervisor : hypervisor // ignore: cast_nullable_to_non_nullable
as String?,hypervisorVersion: freezed == hypervisorVersion ? _self.hypervisorVersion : hypervisorVersion // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$VirtHostProbeResult {

/// `pveversion`'s line on a Proxmox VE host; nothing else was asked.
 String? get pve;/// The container the server runs in (`lxc`, `docker`, …).
 String? get container;/// `virsh version`, when `virsh` is installed and answered.
 LibvirtVersion? get libvirt;
/// Create a copy of VirtHostProbeResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHostProbeResultCopyWith<VirtHostProbeResult> get copyWith => _$VirtHostProbeResultCopyWithImpl<VirtHostProbeResult>(this as VirtHostProbeResult, _$identity);

  /// Serializes this VirtHostProbeResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHostProbeResult&&(identical(other.pve, pve) || other.pve == pve)&&(identical(other.container, container) || other.container == container)&&(identical(other.libvirt, libvirt) || other.libvirt == libvirt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pve,container,libvirt);

@override
String toString() {
  return 'VirtHostProbeResult(pve: $pve, container: $container, libvirt: $libvirt)';
}


}

/// @nodoc
abstract mixin class $VirtHostProbeResultCopyWith<$Res>  {
  factory $VirtHostProbeResultCopyWith(VirtHostProbeResult value, $Res Function(VirtHostProbeResult) _then) = _$VirtHostProbeResultCopyWithImpl;
@useResult
$Res call({
 String? pve, String? container, LibvirtVersion? libvirt
});


$LibvirtVersionCopyWith<$Res>? get libvirt;

}
/// @nodoc
class _$VirtHostProbeResultCopyWithImpl<$Res>
    implements $VirtHostProbeResultCopyWith<$Res> {
  _$VirtHostProbeResultCopyWithImpl(this._self, this._then);

  final VirtHostProbeResult _self;
  final $Res Function(VirtHostProbeResult) _then;

/// Create a copy of VirtHostProbeResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pve = freezed,Object? container = freezed,Object? libvirt = freezed,}) {
  return _then(_self.copyWith(
pve: freezed == pve ? _self.pve : pve // ignore: cast_nullable_to_non_nullable
as String?,container: freezed == container ? _self.container : container // ignore: cast_nullable_to_non_nullable
as String?,libvirt: freezed == libvirt ? _self.libvirt : libvirt // ignore: cast_nullable_to_non_nullable
as LibvirtVersion?,
  ));
}
/// Create a copy of VirtHostProbeResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtVersionCopyWith<$Res>? get libvirt {
    if (_self.libvirt == null) {
    return null;
  }

  return $LibvirtVersionCopyWith<$Res>(_self.libvirt!, (value) {
    return _then(_self.copyWith(libvirt: value));
  });
}
}


/// Adds pattern-matching-related methods to [VirtHostProbeResult].
extension VirtHostProbeResultPatterns on VirtHostProbeResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtHostProbeResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtHostProbeResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtHostProbeResult value)  $default,){
final _that = this;
switch (_that) {
case _VirtHostProbeResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtHostProbeResult value)?  $default,){
final _that = this;
switch (_that) {
case _VirtHostProbeResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? pve,  String? container,  LibvirtVersion? libvirt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHostProbeResult() when $default != null:
return $default(_that.pve,_that.container,_that.libvirt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? pve,  String? container,  LibvirtVersion? libvirt)  $default,) {final _that = this;
switch (_that) {
case _VirtHostProbeResult():
return $default(_that.pve,_that.container,_that.libvirt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? pve,  String? container,  LibvirtVersion? libvirt)?  $default,) {final _that = this;
switch (_that) {
case _VirtHostProbeResult() when $default != null:
return $default(_that.pve,_that.container,_that.libvirt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _VirtHostProbeResult implements VirtHostProbeResult {
  const _VirtHostProbeResult({this.pve, this.container, this.libvirt});
  factory _VirtHostProbeResult.fromJson(Map<String, dynamic> json) => _$VirtHostProbeResultFromJson(json);

/// `pveversion`'s line on a Proxmox VE host; nothing else was asked.
@override final  String? pve;
/// The container the server runs in (`lxc`, `docker`, …).
@override final  String? container;
/// `virsh version`, when `virsh` is installed and answered.
@override final  LibvirtVersion? libvirt;

/// Create a copy of VirtHostProbeResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHostProbeResultCopyWith<_VirtHostProbeResult> get copyWith => __$VirtHostProbeResultCopyWithImpl<_VirtHostProbeResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VirtHostProbeResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHostProbeResult&&(identical(other.pve, pve) || other.pve == pve)&&(identical(other.container, container) || other.container == container)&&(identical(other.libvirt, libvirt) || other.libvirt == libvirt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pve,container,libvirt);

@override
String toString() {
  return 'VirtHostProbeResult(pve: $pve, container: $container, libvirt: $libvirt)';
}


}

/// @nodoc
abstract mixin class _$VirtHostProbeResultCopyWith<$Res> implements $VirtHostProbeResultCopyWith<$Res> {
  factory _$VirtHostProbeResultCopyWith(_VirtHostProbeResult value, $Res Function(_VirtHostProbeResult) _then) = __$VirtHostProbeResultCopyWithImpl;
@override @useResult
$Res call({
 String? pve, String? container, LibvirtVersion? libvirt
});


@override $LibvirtVersionCopyWith<$Res>? get libvirt;

}
/// @nodoc
class __$VirtHostProbeResultCopyWithImpl<$Res>
    implements _$VirtHostProbeResultCopyWith<$Res> {
  __$VirtHostProbeResultCopyWithImpl(this._self, this._then);

  final _VirtHostProbeResult _self;
  final $Res Function(_VirtHostProbeResult) _then;

/// Create a copy of VirtHostProbeResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pve = freezed,Object? container = freezed,Object? libvirt = freezed,}) {
  return _then(_VirtHostProbeResult(
pve: freezed == pve ? _self.pve : pve // ignore: cast_nullable_to_non_nullable
as String?,container: freezed == container ? _self.container : container // ignore: cast_nullable_to_non_nullable
as String?,libvirt: freezed == libvirt ? _self.libvirt : libvirt // ignore: cast_nullable_to_non_nullable
as LibvirtVersion?,
  ));
}

/// Create a copy of VirtHostProbeResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtVersionCopyWith<$Res>? get libvirt {
    if (_self.libvirt == null) {
    return null;
  }

  return $LibvirtVersionCopyWith<$Res>(_self.libvirt!, (value) {
    return _then(_self.copyWith(libvirt: value));
  });
}
}


/// @nodoc
mixin _$LibvirtBlockStats {

 String get name; String? get path; int? get rdBytes; int? get wrBytes; int? get capacity; int? get allocation;
/// Create a copy of LibvirtBlockStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtBlockStatsCopyWith<LibvirtBlockStats> get copyWith => _$LibvirtBlockStatsCopyWithImpl<LibvirtBlockStats>(this as LibvirtBlockStats, _$identity);

  /// Serializes this LibvirtBlockStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtBlockStats&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&(identical(other.rdBytes, rdBytes) || other.rdBytes == rdBytes)&&(identical(other.wrBytes, wrBytes) || other.wrBytes == wrBytes)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.allocation, allocation) || other.allocation == allocation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,path,rdBytes,wrBytes,capacity,allocation);

@override
String toString() {
  return 'LibvirtBlockStats(name: $name, path: $path, rdBytes: $rdBytes, wrBytes: $wrBytes, capacity: $capacity, allocation: $allocation)';
}


}

/// @nodoc
abstract mixin class $LibvirtBlockStatsCopyWith<$Res>  {
  factory $LibvirtBlockStatsCopyWith(LibvirtBlockStats value, $Res Function(LibvirtBlockStats) _then) = _$LibvirtBlockStatsCopyWithImpl;
@useResult
$Res call({
 String name, String? path, int? rdBytes, int? wrBytes, int? capacity, int? allocation
});




}
/// @nodoc
class _$LibvirtBlockStatsCopyWithImpl<$Res>
    implements $LibvirtBlockStatsCopyWith<$Res> {
  _$LibvirtBlockStatsCopyWithImpl(this._self, this._then);

  final LibvirtBlockStats _self;
  final $Res Function(LibvirtBlockStats) _then;

/// Create a copy of LibvirtBlockStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? path = freezed,Object? rdBytes = freezed,Object? wrBytes = freezed,Object? capacity = freezed,Object? allocation = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,rdBytes: freezed == rdBytes ? _self.rdBytes : rdBytes // ignore: cast_nullable_to_non_nullable
as int?,wrBytes: freezed == wrBytes ? _self.wrBytes : wrBytes // ignore: cast_nullable_to_non_nullable
as int?,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,allocation: freezed == allocation ? _self.allocation : allocation // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtBlockStats].
extension LibvirtBlockStatsPatterns on LibvirtBlockStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtBlockStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtBlockStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtBlockStats value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtBlockStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtBlockStats value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtBlockStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? path,  int? rdBytes,  int? wrBytes,  int? capacity,  int? allocation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtBlockStats() when $default != null:
return $default(_that.name,_that.path,_that.rdBytes,_that.wrBytes,_that.capacity,_that.allocation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? path,  int? rdBytes,  int? wrBytes,  int? capacity,  int? allocation)  $default,) {final _that = this;
switch (_that) {
case _LibvirtBlockStats():
return $default(_that.name,_that.path,_that.rdBytes,_that.wrBytes,_that.capacity,_that.allocation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? path,  int? rdBytes,  int? wrBytes,  int? capacity,  int? allocation)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtBlockStats() when $default != null:
return $default(_that.name,_that.path,_that.rdBytes,_that.wrBytes,_that.capacity,_that.allocation);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtBlockStats implements LibvirtBlockStats {
  const _LibvirtBlockStats({this.name = '', this.path, this.rdBytes, this.wrBytes, this.capacity, this.allocation});
  factory _LibvirtBlockStats.fromJson(Map<String, dynamic> json) => _$LibvirtBlockStatsFromJson(json);

@override@JsonKey() final  String name;
@override final  String? path;
@override final  int? rdBytes;
@override final  int? wrBytes;
@override final  int? capacity;
@override final  int? allocation;

/// Create a copy of LibvirtBlockStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtBlockStatsCopyWith<_LibvirtBlockStats> get copyWith => __$LibvirtBlockStatsCopyWithImpl<_LibvirtBlockStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtBlockStatsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtBlockStats&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&(identical(other.rdBytes, rdBytes) || other.rdBytes == rdBytes)&&(identical(other.wrBytes, wrBytes) || other.wrBytes == wrBytes)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.allocation, allocation) || other.allocation == allocation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,path,rdBytes,wrBytes,capacity,allocation);

@override
String toString() {
  return 'LibvirtBlockStats(name: $name, path: $path, rdBytes: $rdBytes, wrBytes: $wrBytes, capacity: $capacity, allocation: $allocation)';
}


}

/// @nodoc
abstract mixin class _$LibvirtBlockStatsCopyWith<$Res> implements $LibvirtBlockStatsCopyWith<$Res> {
  factory _$LibvirtBlockStatsCopyWith(_LibvirtBlockStats value, $Res Function(_LibvirtBlockStats) _then) = __$LibvirtBlockStatsCopyWithImpl;
@override @useResult
$Res call({
 String name, String? path, int? rdBytes, int? wrBytes, int? capacity, int? allocation
});




}
/// @nodoc
class __$LibvirtBlockStatsCopyWithImpl<$Res>
    implements _$LibvirtBlockStatsCopyWith<$Res> {
  __$LibvirtBlockStatsCopyWithImpl(this._self, this._then);

  final _LibvirtBlockStats _self;
  final $Res Function(_LibvirtBlockStats) _then;

/// Create a copy of LibvirtBlockStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? path = freezed,Object? rdBytes = freezed,Object? wrBytes = freezed,Object? capacity = freezed,Object? allocation = freezed,}) {
  return _then(_LibvirtBlockStats(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,rdBytes: freezed == rdBytes ? _self.rdBytes : rdBytes // ignore: cast_nullable_to_non_nullable
as int?,wrBytes: freezed == wrBytes ? _self.wrBytes : wrBytes // ignore: cast_nullable_to_non_nullable
as int?,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,allocation: freezed == allocation ? _self.allocation : allocation // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$LibvirtNetStats {

 String get name; int? get rxBytes; int? get txBytes;
/// Create a copy of LibvirtNetStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtNetStatsCopyWith<LibvirtNetStats> get copyWith => _$LibvirtNetStatsCopyWithImpl<LibvirtNetStats>(this as LibvirtNetStats, _$identity);

  /// Serializes this LibvirtNetStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtNetStats&&(identical(other.name, name) || other.name == name)&&(identical(other.rxBytes, rxBytes) || other.rxBytes == rxBytes)&&(identical(other.txBytes, txBytes) || other.txBytes == txBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,rxBytes,txBytes);

@override
String toString() {
  return 'LibvirtNetStats(name: $name, rxBytes: $rxBytes, txBytes: $txBytes)';
}


}

/// @nodoc
abstract mixin class $LibvirtNetStatsCopyWith<$Res>  {
  factory $LibvirtNetStatsCopyWith(LibvirtNetStats value, $Res Function(LibvirtNetStats) _then) = _$LibvirtNetStatsCopyWithImpl;
@useResult
$Res call({
 String name, int? rxBytes, int? txBytes
});




}
/// @nodoc
class _$LibvirtNetStatsCopyWithImpl<$Res>
    implements $LibvirtNetStatsCopyWith<$Res> {
  _$LibvirtNetStatsCopyWithImpl(this._self, this._then);

  final LibvirtNetStats _self;
  final $Res Function(LibvirtNetStats) _then;

/// Create a copy of LibvirtNetStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? rxBytes = freezed,Object? txBytes = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,rxBytes: freezed == rxBytes ? _self.rxBytes : rxBytes // ignore: cast_nullable_to_non_nullable
as int?,txBytes: freezed == txBytes ? _self.txBytes : txBytes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtNetStats].
extension LibvirtNetStatsPatterns on LibvirtNetStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtNetStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtNetStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtNetStats value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtNetStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtNetStats value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtNetStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int? rxBytes,  int? txBytes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtNetStats() when $default != null:
return $default(_that.name,_that.rxBytes,_that.txBytes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int? rxBytes,  int? txBytes)  $default,) {final _that = this;
switch (_that) {
case _LibvirtNetStats():
return $default(_that.name,_that.rxBytes,_that.txBytes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int? rxBytes,  int? txBytes)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtNetStats() when $default != null:
return $default(_that.name,_that.rxBytes,_that.txBytes);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtNetStats implements LibvirtNetStats {
  const _LibvirtNetStats({this.name = '', this.rxBytes, this.txBytes});
  factory _LibvirtNetStats.fromJson(Map<String, dynamic> json) => _$LibvirtNetStatsFromJson(json);

@override@JsonKey() final  String name;
@override final  int? rxBytes;
@override final  int? txBytes;

/// Create a copy of LibvirtNetStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtNetStatsCopyWith<_LibvirtNetStats> get copyWith => __$LibvirtNetStatsCopyWithImpl<_LibvirtNetStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtNetStatsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtNetStats&&(identical(other.name, name) || other.name == name)&&(identical(other.rxBytes, rxBytes) || other.rxBytes == rxBytes)&&(identical(other.txBytes, txBytes) || other.txBytes == txBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,rxBytes,txBytes);

@override
String toString() {
  return 'LibvirtNetStats(name: $name, rxBytes: $rxBytes, txBytes: $txBytes)';
}


}

/// @nodoc
abstract mixin class _$LibvirtNetStatsCopyWith<$Res> implements $LibvirtNetStatsCopyWith<$Res> {
  factory _$LibvirtNetStatsCopyWith(_LibvirtNetStats value, $Res Function(_LibvirtNetStats) _then) = __$LibvirtNetStatsCopyWithImpl;
@override @useResult
$Res call({
 String name, int? rxBytes, int? txBytes
});




}
/// @nodoc
class __$LibvirtNetStatsCopyWithImpl<$Res>
    implements _$LibvirtNetStatsCopyWith<$Res> {
  __$LibvirtNetStatsCopyWithImpl(this._self, this._then);

  final _LibvirtNetStats _self;
  final $Res Function(_LibvirtNetStats) _then;

/// Create a copy of LibvirtNetStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? rxBytes = freezed,Object? txBytes = freezed,}) {
  return _then(_LibvirtNetStats(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,rxBytes: freezed == rxBytes ? _self.rxBytes : rxBytes // ignore: cast_nullable_to_non_nullable
as int?,txBytes: freezed == txBytes ? _self.txBytes : txBytes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$LibvirtCounters {

/// Nanoseconds.
 int? get cpuTimeNs;/// KiB.
 int? get balloonRssKib; int? get balloonAvailableKib; int? get balloonUnusedKib; List<LibvirtBlockStats> get blocks; List<LibvirtNetStats> get nets;
/// Create a copy of LibvirtCounters
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtCountersCopyWith<LibvirtCounters> get copyWith => _$LibvirtCountersCopyWithImpl<LibvirtCounters>(this as LibvirtCounters, _$identity);

  /// Serializes this LibvirtCounters to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtCounters&&(identical(other.cpuTimeNs, cpuTimeNs) || other.cpuTimeNs == cpuTimeNs)&&(identical(other.balloonRssKib, balloonRssKib) || other.balloonRssKib == balloonRssKib)&&(identical(other.balloonAvailableKib, balloonAvailableKib) || other.balloonAvailableKib == balloonAvailableKib)&&(identical(other.balloonUnusedKib, balloonUnusedKib) || other.balloonUnusedKib == balloonUnusedKib)&&const DeepCollectionEquality().equals(other.blocks, blocks)&&const DeepCollectionEquality().equals(other.nets, nets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cpuTimeNs,balloonRssKib,balloonAvailableKib,balloonUnusedKib,const DeepCollectionEquality().hash(blocks),const DeepCollectionEquality().hash(nets));

@override
String toString() {
  return 'LibvirtCounters(cpuTimeNs: $cpuTimeNs, balloonRssKib: $balloonRssKib, balloonAvailableKib: $balloonAvailableKib, balloonUnusedKib: $balloonUnusedKib, blocks: $blocks, nets: $nets)';
}


}

/// @nodoc
abstract mixin class $LibvirtCountersCopyWith<$Res>  {
  factory $LibvirtCountersCopyWith(LibvirtCounters value, $Res Function(LibvirtCounters) _then) = _$LibvirtCountersCopyWithImpl;
@useResult
$Res call({
 int? cpuTimeNs, int? balloonRssKib, int? balloonAvailableKib, int? balloonUnusedKib, List<LibvirtBlockStats> blocks, List<LibvirtNetStats> nets
});




}
/// @nodoc
class _$LibvirtCountersCopyWithImpl<$Res>
    implements $LibvirtCountersCopyWith<$Res> {
  _$LibvirtCountersCopyWithImpl(this._self, this._then);

  final LibvirtCounters _self;
  final $Res Function(LibvirtCounters) _then;

/// Create a copy of LibvirtCounters
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cpuTimeNs = freezed,Object? balloonRssKib = freezed,Object? balloonAvailableKib = freezed,Object? balloonUnusedKib = freezed,Object? blocks = null,Object? nets = null,}) {
  return _then(_self.copyWith(
cpuTimeNs: freezed == cpuTimeNs ? _self.cpuTimeNs : cpuTimeNs // ignore: cast_nullable_to_non_nullable
as int?,balloonRssKib: freezed == balloonRssKib ? _self.balloonRssKib : balloonRssKib // ignore: cast_nullable_to_non_nullable
as int?,balloonAvailableKib: freezed == balloonAvailableKib ? _self.balloonAvailableKib : balloonAvailableKib // ignore: cast_nullable_to_non_nullable
as int?,balloonUnusedKib: freezed == balloonUnusedKib ? _self.balloonUnusedKib : balloonUnusedKib // ignore: cast_nullable_to_non_nullable
as int?,blocks: null == blocks ? _self.blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<LibvirtBlockStats>,nets: null == nets ? _self.nets : nets // ignore: cast_nullable_to_non_nullable
as List<LibvirtNetStats>,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtCounters].
extension LibvirtCountersPatterns on LibvirtCounters {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtCounters value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtCounters() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtCounters value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtCounters():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtCounters value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtCounters() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? cpuTimeNs,  int? balloonRssKib,  int? balloonAvailableKib,  int? balloonUnusedKib,  List<LibvirtBlockStats> blocks,  List<LibvirtNetStats> nets)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtCounters() when $default != null:
return $default(_that.cpuTimeNs,_that.balloonRssKib,_that.balloonAvailableKib,_that.balloonUnusedKib,_that.blocks,_that.nets);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? cpuTimeNs,  int? balloonRssKib,  int? balloonAvailableKib,  int? balloonUnusedKib,  List<LibvirtBlockStats> blocks,  List<LibvirtNetStats> nets)  $default,) {final _that = this;
switch (_that) {
case _LibvirtCounters():
return $default(_that.cpuTimeNs,_that.balloonRssKib,_that.balloonAvailableKib,_that.balloonUnusedKib,_that.blocks,_that.nets);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? cpuTimeNs,  int? balloonRssKib,  int? balloonAvailableKib,  int? balloonUnusedKib,  List<LibvirtBlockStats> blocks,  List<LibvirtNetStats> nets)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtCounters() when $default != null:
return $default(_that.cpuTimeNs,_that.balloonRssKib,_that.balloonAvailableKib,_that.balloonUnusedKib,_that.blocks,_that.nets);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtCounters implements LibvirtCounters {
  const _LibvirtCounters({this.cpuTimeNs, this.balloonRssKib, this.balloonAvailableKib, this.balloonUnusedKib, final  List<LibvirtBlockStats> blocks = const <LibvirtBlockStats>[], final  List<LibvirtNetStats> nets = const <LibvirtNetStats>[]}): _blocks = blocks,_nets = nets;
  factory _LibvirtCounters.fromJson(Map<String, dynamic> json) => _$LibvirtCountersFromJson(json);

/// Nanoseconds.
@override final  int? cpuTimeNs;
/// KiB.
@override final  int? balloonRssKib;
@override final  int? balloonAvailableKib;
@override final  int? balloonUnusedKib;
 final  List<LibvirtBlockStats> _blocks;
@override@JsonKey() List<LibvirtBlockStats> get blocks {
  if (_blocks is EqualUnmodifiableListView) return _blocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_blocks);
}

 final  List<LibvirtNetStats> _nets;
@override@JsonKey() List<LibvirtNetStats> get nets {
  if (_nets is EqualUnmodifiableListView) return _nets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nets);
}


/// Create a copy of LibvirtCounters
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtCountersCopyWith<_LibvirtCounters> get copyWith => __$LibvirtCountersCopyWithImpl<_LibvirtCounters>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtCountersToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtCounters&&(identical(other.cpuTimeNs, cpuTimeNs) || other.cpuTimeNs == cpuTimeNs)&&(identical(other.balloonRssKib, balloonRssKib) || other.balloonRssKib == balloonRssKib)&&(identical(other.balloonAvailableKib, balloonAvailableKib) || other.balloonAvailableKib == balloonAvailableKib)&&(identical(other.balloonUnusedKib, balloonUnusedKib) || other.balloonUnusedKib == balloonUnusedKib)&&const DeepCollectionEquality().equals(other._blocks, _blocks)&&const DeepCollectionEquality().equals(other._nets, _nets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cpuTimeNs,balloonRssKib,balloonAvailableKib,balloonUnusedKib,const DeepCollectionEquality().hash(_blocks),const DeepCollectionEquality().hash(_nets));

@override
String toString() {
  return 'LibvirtCounters(cpuTimeNs: $cpuTimeNs, balloonRssKib: $balloonRssKib, balloonAvailableKib: $balloonAvailableKib, balloonUnusedKib: $balloonUnusedKib, blocks: $blocks, nets: $nets)';
}


}

/// @nodoc
abstract mixin class _$LibvirtCountersCopyWith<$Res> implements $LibvirtCountersCopyWith<$Res> {
  factory _$LibvirtCountersCopyWith(_LibvirtCounters value, $Res Function(_LibvirtCounters) _then) = __$LibvirtCountersCopyWithImpl;
@override @useResult
$Res call({
 int? cpuTimeNs, int? balloonRssKib, int? balloonAvailableKib, int? balloonUnusedKib, List<LibvirtBlockStats> blocks, List<LibvirtNetStats> nets
});




}
/// @nodoc
class __$LibvirtCountersCopyWithImpl<$Res>
    implements _$LibvirtCountersCopyWith<$Res> {
  __$LibvirtCountersCopyWithImpl(this._self, this._then);

  final _LibvirtCounters _self;
  final $Res Function(_LibvirtCounters) _then;

/// Create a copy of LibvirtCounters
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cpuTimeNs = freezed,Object? balloonRssKib = freezed,Object? balloonAvailableKib = freezed,Object? balloonUnusedKib = freezed,Object? blocks = null,Object? nets = null,}) {
  return _then(_LibvirtCounters(
cpuTimeNs: freezed == cpuTimeNs ? _self.cpuTimeNs : cpuTimeNs // ignore: cast_nullable_to_non_nullable
as int?,balloonRssKib: freezed == balloonRssKib ? _self.balloonRssKib : balloonRssKib // ignore: cast_nullable_to_non_nullable
as int?,balloonAvailableKib: freezed == balloonAvailableKib ? _self.balloonAvailableKib : balloonAvailableKib // ignore: cast_nullable_to_non_nullable
as int?,balloonUnusedKib: freezed == balloonUnusedKib ? _self.balloonUnusedKib : balloonUnusedKib // ignore: cast_nullable_to_non_nullable
as int?,blocks: null == blocks ? _self._blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<LibvirtBlockStats>,nets: null == nets ? _self._nets : nets // ignore: cast_nullable_to_non_nullable
as List<LibvirtNetStats>,
  ));
}


}


/// @nodoc
mixin _$LibvirtDomain {

 String get uuid; String get name;/// `sbm_parser::virt::VirtState`: `running`, `paused`, `stopped`,
/// `starting`, `stopping`, `unknown`.
 String get state;/// Raw `virDomainState`; -1 when `domstats` did not report the domain.
 int get stateCode; int get reasonCode; String get reason; bool get autostart; bool get persistent; int? get vcpuCurrent; int? get vcpuMax; int? get memCurrentKib; int? get memMaxKib; LibvirtCounters get counters;
/// Create a copy of LibvirtDomain
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtDomainCopyWith<LibvirtDomain> get copyWith => _$LibvirtDomainCopyWithImpl<LibvirtDomain>(this as LibvirtDomain, _$identity);

  /// Serializes this LibvirtDomain to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtDomain&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.state, state) || other.state == state)&&(identical(other.stateCode, stateCode) || other.stateCode == stateCode)&&(identical(other.reasonCode, reasonCode) || other.reasonCode == reasonCode)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&(identical(other.persistent, persistent) || other.persistent == persistent)&&(identical(other.vcpuCurrent, vcpuCurrent) || other.vcpuCurrent == vcpuCurrent)&&(identical(other.vcpuMax, vcpuMax) || other.vcpuMax == vcpuMax)&&(identical(other.memCurrentKib, memCurrentKib) || other.memCurrentKib == memCurrentKib)&&(identical(other.memMaxKib, memMaxKib) || other.memMaxKib == memMaxKib)&&(identical(other.counters, counters) || other.counters == counters));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,name,state,stateCode,reasonCode,reason,autostart,persistent,vcpuCurrent,vcpuMax,memCurrentKib,memMaxKib,counters);

@override
String toString() {
  return 'LibvirtDomain(uuid: $uuid, name: $name, state: $state, stateCode: $stateCode, reasonCode: $reasonCode, reason: $reason, autostart: $autostart, persistent: $persistent, vcpuCurrent: $vcpuCurrent, vcpuMax: $vcpuMax, memCurrentKib: $memCurrentKib, memMaxKib: $memMaxKib, counters: $counters)';
}


}

/// @nodoc
abstract mixin class $LibvirtDomainCopyWith<$Res>  {
  factory $LibvirtDomainCopyWith(LibvirtDomain value, $Res Function(LibvirtDomain) _then) = _$LibvirtDomainCopyWithImpl;
@useResult
$Res call({
 String uuid, String name, String state, int stateCode, int reasonCode, String reason, bool autostart, bool persistent, int? vcpuCurrent, int? vcpuMax, int? memCurrentKib, int? memMaxKib, LibvirtCounters counters
});


$LibvirtCountersCopyWith<$Res> get counters;

}
/// @nodoc
class _$LibvirtDomainCopyWithImpl<$Res>
    implements $LibvirtDomainCopyWith<$Res> {
  _$LibvirtDomainCopyWithImpl(this._self, this._then);

  final LibvirtDomain _self;
  final $Res Function(LibvirtDomain) _then;

/// Create a copy of LibvirtDomain
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uuid = null,Object? name = null,Object? state = null,Object? stateCode = null,Object? reasonCode = null,Object? reason = null,Object? autostart = null,Object? persistent = null,Object? vcpuCurrent = freezed,Object? vcpuMax = freezed,Object? memCurrentKib = freezed,Object? memMaxKib = freezed,Object? counters = null,}) {
  return _then(_self.copyWith(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,stateCode: null == stateCode ? _self.stateCode : stateCode // ignore: cast_nullable_to_non_nullable
as int,reasonCode: null == reasonCode ? _self.reasonCode : reasonCode // ignore: cast_nullable_to_non_nullable
as int,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,autostart: null == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool,persistent: null == persistent ? _self.persistent : persistent // ignore: cast_nullable_to_non_nullable
as bool,vcpuCurrent: freezed == vcpuCurrent ? _self.vcpuCurrent : vcpuCurrent // ignore: cast_nullable_to_non_nullable
as int?,vcpuMax: freezed == vcpuMax ? _self.vcpuMax : vcpuMax // ignore: cast_nullable_to_non_nullable
as int?,memCurrentKib: freezed == memCurrentKib ? _self.memCurrentKib : memCurrentKib // ignore: cast_nullable_to_non_nullable
as int?,memMaxKib: freezed == memMaxKib ? _self.memMaxKib : memMaxKib // ignore: cast_nullable_to_non_nullable
as int?,counters: null == counters ? _self.counters : counters // ignore: cast_nullable_to_non_nullable
as LibvirtCounters,
  ));
}
/// Create a copy of LibvirtDomain
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtCountersCopyWith<$Res> get counters {
  
  return $LibvirtCountersCopyWith<$Res>(_self.counters, (value) {
    return _then(_self.copyWith(counters: value));
  });
}
}


/// Adds pattern-matching-related methods to [LibvirtDomain].
extension LibvirtDomainPatterns on LibvirtDomain {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtDomain value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtDomain() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtDomain value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtDomain():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtDomain value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtDomain() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uuid,  String name,  String state,  int stateCode,  int reasonCode,  String reason,  bool autostart,  bool persistent,  int? vcpuCurrent,  int? vcpuMax,  int? memCurrentKib,  int? memMaxKib,  LibvirtCounters counters)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtDomain() when $default != null:
return $default(_that.uuid,_that.name,_that.state,_that.stateCode,_that.reasonCode,_that.reason,_that.autostart,_that.persistent,_that.vcpuCurrent,_that.vcpuMax,_that.memCurrentKib,_that.memMaxKib,_that.counters);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uuid,  String name,  String state,  int stateCode,  int reasonCode,  String reason,  bool autostart,  bool persistent,  int? vcpuCurrent,  int? vcpuMax,  int? memCurrentKib,  int? memMaxKib,  LibvirtCounters counters)  $default,) {final _that = this;
switch (_that) {
case _LibvirtDomain():
return $default(_that.uuid,_that.name,_that.state,_that.stateCode,_that.reasonCode,_that.reason,_that.autostart,_that.persistent,_that.vcpuCurrent,_that.vcpuMax,_that.memCurrentKib,_that.memMaxKib,_that.counters);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uuid,  String name,  String state,  int stateCode,  int reasonCode,  String reason,  bool autostart,  bool persistent,  int? vcpuCurrent,  int? vcpuMax,  int? memCurrentKib,  int? memMaxKib,  LibvirtCounters counters)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtDomain() when $default != null:
return $default(_that.uuid,_that.name,_that.state,_that.stateCode,_that.reasonCode,_that.reason,_that.autostart,_that.persistent,_that.vcpuCurrent,_that.vcpuMax,_that.memCurrentKib,_that.memMaxKib,_that.counters);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtDomain implements LibvirtDomain {
  const _LibvirtDomain({required this.uuid, required this.name, required this.state, this.stateCode = -1, this.reasonCode = 0, this.reason = 'unknown', this.autostart = false, this.persistent = false, this.vcpuCurrent, this.vcpuMax, this.memCurrentKib, this.memMaxKib, this.counters = const LibvirtCounters()});
  factory _LibvirtDomain.fromJson(Map<String, dynamic> json) => _$LibvirtDomainFromJson(json);

@override final  String uuid;
@override final  String name;
/// `sbm_parser::virt::VirtState`: `running`, `paused`, `stopped`,
/// `starting`, `stopping`, `unknown`.
@override final  String state;
/// Raw `virDomainState`; -1 when `domstats` did not report the domain.
@override@JsonKey() final  int stateCode;
@override@JsonKey() final  int reasonCode;
@override@JsonKey() final  String reason;
@override@JsonKey() final  bool autostart;
@override@JsonKey() final  bool persistent;
@override final  int? vcpuCurrent;
@override final  int? vcpuMax;
@override final  int? memCurrentKib;
@override final  int? memMaxKib;
@override@JsonKey() final  LibvirtCounters counters;

/// Create a copy of LibvirtDomain
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtDomainCopyWith<_LibvirtDomain> get copyWith => __$LibvirtDomainCopyWithImpl<_LibvirtDomain>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtDomainToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtDomain&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.state, state) || other.state == state)&&(identical(other.stateCode, stateCode) || other.stateCode == stateCode)&&(identical(other.reasonCode, reasonCode) || other.reasonCode == reasonCode)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&(identical(other.persistent, persistent) || other.persistent == persistent)&&(identical(other.vcpuCurrent, vcpuCurrent) || other.vcpuCurrent == vcpuCurrent)&&(identical(other.vcpuMax, vcpuMax) || other.vcpuMax == vcpuMax)&&(identical(other.memCurrentKib, memCurrentKib) || other.memCurrentKib == memCurrentKib)&&(identical(other.memMaxKib, memMaxKib) || other.memMaxKib == memMaxKib)&&(identical(other.counters, counters) || other.counters == counters));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,name,state,stateCode,reasonCode,reason,autostart,persistent,vcpuCurrent,vcpuMax,memCurrentKib,memMaxKib,counters);

@override
String toString() {
  return 'LibvirtDomain(uuid: $uuid, name: $name, state: $state, stateCode: $stateCode, reasonCode: $reasonCode, reason: $reason, autostart: $autostart, persistent: $persistent, vcpuCurrent: $vcpuCurrent, vcpuMax: $vcpuMax, memCurrentKib: $memCurrentKib, memMaxKib: $memMaxKib, counters: $counters)';
}


}

/// @nodoc
abstract mixin class _$LibvirtDomainCopyWith<$Res> implements $LibvirtDomainCopyWith<$Res> {
  factory _$LibvirtDomainCopyWith(_LibvirtDomain value, $Res Function(_LibvirtDomain) _then) = __$LibvirtDomainCopyWithImpl;
@override @useResult
$Res call({
 String uuid, String name, String state, int stateCode, int reasonCode, String reason, bool autostart, bool persistent, int? vcpuCurrent, int? vcpuMax, int? memCurrentKib, int? memMaxKib, LibvirtCounters counters
});


@override $LibvirtCountersCopyWith<$Res> get counters;

}
/// @nodoc
class __$LibvirtDomainCopyWithImpl<$Res>
    implements _$LibvirtDomainCopyWith<$Res> {
  __$LibvirtDomainCopyWithImpl(this._self, this._then);

  final _LibvirtDomain _self;
  final $Res Function(_LibvirtDomain) _then;

/// Create a copy of LibvirtDomain
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uuid = null,Object? name = null,Object? state = null,Object? stateCode = null,Object? reasonCode = null,Object? reason = null,Object? autostart = null,Object? persistent = null,Object? vcpuCurrent = freezed,Object? vcpuMax = freezed,Object? memCurrentKib = freezed,Object? memMaxKib = freezed,Object? counters = null,}) {
  return _then(_LibvirtDomain(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,stateCode: null == stateCode ? _self.stateCode : stateCode // ignore: cast_nullable_to_non_nullable
as int,reasonCode: null == reasonCode ? _self.reasonCode : reasonCode // ignore: cast_nullable_to_non_nullable
as int,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,autostart: null == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool,persistent: null == persistent ? _self.persistent : persistent // ignore: cast_nullable_to_non_nullable
as bool,vcpuCurrent: freezed == vcpuCurrent ? _self.vcpuCurrent : vcpuCurrent // ignore: cast_nullable_to_non_nullable
as int?,vcpuMax: freezed == vcpuMax ? _self.vcpuMax : vcpuMax // ignore: cast_nullable_to_non_nullable
as int?,memCurrentKib: freezed == memCurrentKib ? _self.memCurrentKib : memCurrentKib // ignore: cast_nullable_to_non_nullable
as int?,memMaxKib: freezed == memMaxKib ? _self.memMaxKib : memMaxKib // ignore: cast_nullable_to_non_nullable
as int?,counters: null == counters ? _self.counters : counters // ignore: cast_nullable_to_non_nullable
as LibvirtCounters,
  ));
}

/// Create a copy of LibvirtDomain
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtCountersCopyWith<$Res> get counters {
  
  return $LibvirtCountersCopyWith<$Res>(_self.counters, (value) {
    return _then(_self.copyWith(counters: value));
  });
}
}


/// @nodoc
mixin _$LibvirtOverview {

 LibvirtVersion? get version; List<LibvirtDomain> get domains;
/// Create a copy of LibvirtOverview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtOverviewCopyWith<LibvirtOverview> get copyWith => _$LibvirtOverviewCopyWithImpl<LibvirtOverview>(this as LibvirtOverview, _$identity);

  /// Serializes this LibvirtOverview to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtOverview&&(identical(other.version, version) || other.version == version)&&const DeepCollectionEquality().equals(other.domains, domains));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,const DeepCollectionEquality().hash(domains));

@override
String toString() {
  return 'LibvirtOverview(version: $version, domains: $domains)';
}


}

/// @nodoc
abstract mixin class $LibvirtOverviewCopyWith<$Res>  {
  factory $LibvirtOverviewCopyWith(LibvirtOverview value, $Res Function(LibvirtOverview) _then) = _$LibvirtOverviewCopyWithImpl;
@useResult
$Res call({
 LibvirtVersion? version, List<LibvirtDomain> domains
});


$LibvirtVersionCopyWith<$Res>? get version;

}
/// @nodoc
class _$LibvirtOverviewCopyWithImpl<$Res>
    implements $LibvirtOverviewCopyWith<$Res> {
  _$LibvirtOverviewCopyWithImpl(this._self, this._then);

  final LibvirtOverview _self;
  final $Res Function(LibvirtOverview) _then;

/// Create a copy of LibvirtOverview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = freezed,Object? domains = null,}) {
  return _then(_self.copyWith(
version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as LibvirtVersion?,domains: null == domains ? _self.domains : domains // ignore: cast_nullable_to_non_nullable
as List<LibvirtDomain>,
  ));
}
/// Create a copy of LibvirtOverview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtVersionCopyWith<$Res>? get version {
    if (_self.version == null) {
    return null;
  }

  return $LibvirtVersionCopyWith<$Res>(_self.version!, (value) {
    return _then(_self.copyWith(version: value));
  });
}
}


/// Adds pattern-matching-related methods to [LibvirtOverview].
extension LibvirtOverviewPatterns on LibvirtOverview {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtOverview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtOverview() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtOverview value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtOverview():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtOverview value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtOverview() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LibvirtVersion? version,  List<LibvirtDomain> domains)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtOverview() when $default != null:
return $default(_that.version,_that.domains);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LibvirtVersion? version,  List<LibvirtDomain> domains)  $default,) {final _that = this;
switch (_that) {
case _LibvirtOverview():
return $default(_that.version,_that.domains);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LibvirtVersion? version,  List<LibvirtDomain> domains)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtOverview() when $default != null:
return $default(_that.version,_that.domains);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LibvirtOverview implements LibvirtOverview {
  const _LibvirtOverview({this.version, final  List<LibvirtDomain> domains = const <LibvirtDomain>[]}): _domains = domains;
  factory _LibvirtOverview.fromJson(Map<String, dynamic> json) => _$LibvirtOverviewFromJson(json);

@override final  LibvirtVersion? version;
 final  List<LibvirtDomain> _domains;
@override@JsonKey() List<LibvirtDomain> get domains {
  if (_domains is EqualUnmodifiableListView) return _domains;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_domains);
}


/// Create a copy of LibvirtOverview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtOverviewCopyWith<_LibvirtOverview> get copyWith => __$LibvirtOverviewCopyWithImpl<_LibvirtOverview>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtOverviewToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtOverview&&(identical(other.version, version) || other.version == version)&&const DeepCollectionEquality().equals(other._domains, _domains));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,const DeepCollectionEquality().hash(_domains));

@override
String toString() {
  return 'LibvirtOverview(version: $version, domains: $domains)';
}


}

/// @nodoc
abstract mixin class _$LibvirtOverviewCopyWith<$Res> implements $LibvirtOverviewCopyWith<$Res> {
  factory _$LibvirtOverviewCopyWith(_LibvirtOverview value, $Res Function(_LibvirtOverview) _then) = __$LibvirtOverviewCopyWithImpl;
@override @useResult
$Res call({
 LibvirtVersion? version, List<LibvirtDomain> domains
});


@override $LibvirtVersionCopyWith<$Res>? get version;

}
/// @nodoc
class __$LibvirtOverviewCopyWithImpl<$Res>
    implements _$LibvirtOverviewCopyWith<$Res> {
  __$LibvirtOverviewCopyWithImpl(this._self, this._then);

  final _LibvirtOverview _self;
  final $Res Function(_LibvirtOverview) _then;

/// Create a copy of LibvirtOverview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = freezed,Object? domains = null,}) {
  return _then(_LibvirtOverview(
version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as LibvirtVersion?,domains: null == domains ? _self._domains : domains // ignore: cast_nullable_to_non_nullable
as List<LibvirtDomain>,
  ));
}

/// Create a copy of LibvirtOverview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtVersionCopyWith<$Res>? get version {
    if (_self.version == null) {
    return null;
  }

  return $LibvirtVersionCopyWith<$Res>(_self.version!, (value) {
    return _then(_self.copyWith(version: value));
  });
}
}


/// @nodoc
mixin _$LibvirtDomainXml {

 String? get name; String? get uuid; String? get description; String? get arch; String? get machine; List<VirtDisk> get disks; List<VirtNic> get nics; List<VirtGraphics> get graphics; bool get hasSerialConsole;
/// Create a copy of LibvirtDomainXml
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtDomainXmlCopyWith<LibvirtDomainXml> get copyWith => _$LibvirtDomainXmlCopyWithImpl<LibvirtDomainXml>(this as LibvirtDomainXml, _$identity);

  /// Serializes this LibvirtDomainXml to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtDomainXml&&(identical(other.name, name) || other.name == name)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.description, description) || other.description == description)&&(identical(other.arch, arch) || other.arch == arch)&&(identical(other.machine, machine) || other.machine == machine)&&const DeepCollectionEquality().equals(other.disks, disks)&&const DeepCollectionEquality().equals(other.nics, nics)&&const DeepCollectionEquality().equals(other.graphics, graphics)&&(identical(other.hasSerialConsole, hasSerialConsole) || other.hasSerialConsole == hasSerialConsole));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,uuid,description,arch,machine,const DeepCollectionEquality().hash(disks),const DeepCollectionEquality().hash(nics),const DeepCollectionEquality().hash(graphics),hasSerialConsole);

@override
String toString() {
  return 'LibvirtDomainXml(name: $name, uuid: $uuid, description: $description, arch: $arch, machine: $machine, disks: $disks, nics: $nics, graphics: $graphics, hasSerialConsole: $hasSerialConsole)';
}


}

/// @nodoc
abstract mixin class $LibvirtDomainXmlCopyWith<$Res>  {
  factory $LibvirtDomainXmlCopyWith(LibvirtDomainXml value, $Res Function(LibvirtDomainXml) _then) = _$LibvirtDomainXmlCopyWithImpl;
@useResult
$Res call({
 String? name, String? uuid, String? description, String? arch, String? machine, List<VirtDisk> disks, List<VirtNic> nics, List<VirtGraphics> graphics, bool hasSerialConsole
});




}
/// @nodoc
class _$LibvirtDomainXmlCopyWithImpl<$Res>
    implements $LibvirtDomainXmlCopyWith<$Res> {
  _$LibvirtDomainXmlCopyWithImpl(this._self, this._then);

  final LibvirtDomainXml _self;
  final $Res Function(LibvirtDomainXml) _then;

/// Create a copy of LibvirtDomainXml
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = freezed,Object? uuid = freezed,Object? description = freezed,Object? arch = freezed,Object? machine = freezed,Object? disks = null,Object? nics = null,Object? graphics = null,Object? hasSerialConsole = null,}) {
  return _then(_self.copyWith(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,arch: freezed == arch ? _self.arch : arch // ignore: cast_nullable_to_non_nullable
as String?,machine: freezed == machine ? _self.machine : machine // ignore: cast_nullable_to_non_nullable
as String?,disks: null == disks ? _self.disks : disks // ignore: cast_nullable_to_non_nullable
as List<VirtDisk>,nics: null == nics ? _self.nics : nics // ignore: cast_nullable_to_non_nullable
as List<VirtNic>,graphics: null == graphics ? _self.graphics : graphics // ignore: cast_nullable_to_non_nullable
as List<VirtGraphics>,hasSerialConsole: null == hasSerialConsole ? _self.hasSerialConsole : hasSerialConsole // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtDomainXml].
extension LibvirtDomainXmlPatterns on LibvirtDomainXml {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtDomainXml value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtDomainXml() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtDomainXml value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtDomainXml():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtDomainXml value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtDomainXml() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? name,  String? uuid,  String? description,  String? arch,  String? machine,  List<VirtDisk> disks,  List<VirtNic> nics,  List<VirtGraphics> graphics,  bool hasSerialConsole)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtDomainXml() when $default != null:
return $default(_that.name,_that.uuid,_that.description,_that.arch,_that.machine,_that.disks,_that.nics,_that.graphics,_that.hasSerialConsole);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? name,  String? uuid,  String? description,  String? arch,  String? machine,  List<VirtDisk> disks,  List<VirtNic> nics,  List<VirtGraphics> graphics,  bool hasSerialConsole)  $default,) {final _that = this;
switch (_that) {
case _LibvirtDomainXml():
return $default(_that.name,_that.uuid,_that.description,_that.arch,_that.machine,_that.disks,_that.nics,_that.graphics,_that.hasSerialConsole);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? name,  String? uuid,  String? description,  String? arch,  String? machine,  List<VirtDisk> disks,  List<VirtNic> nics,  List<VirtGraphics> graphics,  bool hasSerialConsole)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtDomainXml() when $default != null:
return $default(_that.name,_that.uuid,_that.description,_that.arch,_that.machine,_that.disks,_that.nics,_that.graphics,_that.hasSerialConsole);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtDomainXml implements LibvirtDomainXml {
  const _LibvirtDomainXml({this.name, this.uuid, this.description, this.arch, this.machine, final  List<VirtDisk> disks = const <VirtDisk>[], final  List<VirtNic> nics = const <VirtNic>[], final  List<VirtGraphics> graphics = const <VirtGraphics>[], this.hasSerialConsole = false}): _disks = disks,_nics = nics,_graphics = graphics;
  factory _LibvirtDomainXml.fromJson(Map<String, dynamic> json) => _$LibvirtDomainXmlFromJson(json);

@override final  String? name;
@override final  String? uuid;
@override final  String? description;
@override final  String? arch;
@override final  String? machine;
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

@override@JsonKey() final  bool hasSerialConsole;

/// Create a copy of LibvirtDomainXml
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtDomainXmlCopyWith<_LibvirtDomainXml> get copyWith => __$LibvirtDomainXmlCopyWithImpl<_LibvirtDomainXml>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtDomainXmlToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtDomainXml&&(identical(other.name, name) || other.name == name)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.description, description) || other.description == description)&&(identical(other.arch, arch) || other.arch == arch)&&(identical(other.machine, machine) || other.machine == machine)&&const DeepCollectionEquality().equals(other._disks, _disks)&&const DeepCollectionEquality().equals(other._nics, _nics)&&const DeepCollectionEquality().equals(other._graphics, _graphics)&&(identical(other.hasSerialConsole, hasSerialConsole) || other.hasSerialConsole == hasSerialConsole));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,uuid,description,arch,machine,const DeepCollectionEquality().hash(_disks),const DeepCollectionEquality().hash(_nics),const DeepCollectionEquality().hash(_graphics),hasSerialConsole);

@override
String toString() {
  return 'LibvirtDomainXml(name: $name, uuid: $uuid, description: $description, arch: $arch, machine: $machine, disks: $disks, nics: $nics, graphics: $graphics, hasSerialConsole: $hasSerialConsole)';
}


}

/// @nodoc
abstract mixin class _$LibvirtDomainXmlCopyWith<$Res> implements $LibvirtDomainXmlCopyWith<$Res> {
  factory _$LibvirtDomainXmlCopyWith(_LibvirtDomainXml value, $Res Function(_LibvirtDomainXml) _then) = __$LibvirtDomainXmlCopyWithImpl;
@override @useResult
$Res call({
 String? name, String? uuid, String? description, String? arch, String? machine, List<VirtDisk> disks, List<VirtNic> nics, List<VirtGraphics> graphics, bool hasSerialConsole
});




}
/// @nodoc
class __$LibvirtDomainXmlCopyWithImpl<$Res>
    implements _$LibvirtDomainXmlCopyWith<$Res> {
  __$LibvirtDomainXmlCopyWithImpl(this._self, this._then);

  final _LibvirtDomainXml _self;
  final $Res Function(_LibvirtDomainXml) _then;

/// Create a copy of LibvirtDomainXml
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = freezed,Object? uuid = freezed,Object? description = freezed,Object? arch = freezed,Object? machine = freezed,Object? disks = null,Object? nics = null,Object? graphics = null,Object? hasSerialConsole = null,}) {
  return _then(_LibvirtDomainXml(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,arch: freezed == arch ? _self.arch : arch // ignore: cast_nullable_to_non_nullable
as String?,machine: freezed == machine ? _self.machine : machine // ignore: cast_nullable_to_non_nullable
as String?,disks: null == disks ? _self._disks : disks // ignore: cast_nullable_to_non_nullable
as List<VirtDisk>,nics: null == nics ? _self._nics : nics // ignore: cast_nullable_to_non_nullable
as List<VirtNic>,graphics: null == graphics ? _self._graphics : graphics // ignore: cast_nullable_to_non_nullable
as List<VirtGraphics>,hasSerialConsole: null == hasSerialConsole ? _self.hasSerialConsole : hasSerialConsole // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$LibvirtDomainDetail {

 VirtDisplay? get display; LibvirtDomainXml get xml;
/// Create a copy of LibvirtDomainDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtDomainDetailCopyWith<LibvirtDomainDetail> get copyWith => _$LibvirtDomainDetailCopyWithImpl<LibvirtDomainDetail>(this as LibvirtDomainDetail, _$identity);

  /// Serializes this LibvirtDomainDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtDomainDetail&&(identical(other.display, display) || other.display == display)&&(identical(other.xml, xml) || other.xml == xml));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,display,xml);

@override
String toString() {
  return 'LibvirtDomainDetail(display: $display, xml: $xml)';
}


}

/// @nodoc
abstract mixin class $LibvirtDomainDetailCopyWith<$Res>  {
  factory $LibvirtDomainDetailCopyWith(LibvirtDomainDetail value, $Res Function(LibvirtDomainDetail) _then) = _$LibvirtDomainDetailCopyWithImpl;
@useResult
$Res call({
 VirtDisplay? display, LibvirtDomainXml xml
});


$VirtDisplayCopyWith<$Res>? get display;$LibvirtDomainXmlCopyWith<$Res> get xml;

}
/// @nodoc
class _$LibvirtDomainDetailCopyWithImpl<$Res>
    implements $LibvirtDomainDetailCopyWith<$Res> {
  _$LibvirtDomainDetailCopyWithImpl(this._self, this._then);

  final LibvirtDomainDetail _self;
  final $Res Function(LibvirtDomainDetail) _then;

/// Create a copy of LibvirtDomainDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? display = freezed,Object? xml = null,}) {
  return _then(_self.copyWith(
display: freezed == display ? _self.display : display // ignore: cast_nullable_to_non_nullable
as VirtDisplay?,xml: null == xml ? _self.xml : xml // ignore: cast_nullable_to_non_nullable
as LibvirtDomainXml,
  ));
}
/// Create a copy of LibvirtDomainDetail
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
}/// Create a copy of LibvirtDomainDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtDomainXmlCopyWith<$Res> get xml {
  
  return $LibvirtDomainXmlCopyWith<$Res>(_self.xml, (value) {
    return _then(_self.copyWith(xml: value));
  });
}
}


/// Adds pattern-matching-related methods to [LibvirtDomainDetail].
extension LibvirtDomainDetailPatterns on LibvirtDomainDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtDomainDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtDomainDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtDomainDetail value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtDomainDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtDomainDetail value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtDomainDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( VirtDisplay? display,  LibvirtDomainXml xml)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtDomainDetail() when $default != null:
return $default(_that.display,_that.xml);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( VirtDisplay? display,  LibvirtDomainXml xml)  $default,) {final _that = this;
switch (_that) {
case _LibvirtDomainDetail():
return $default(_that.display,_that.xml);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( VirtDisplay? display,  LibvirtDomainXml xml)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtDomainDetail() when $default != null:
return $default(_that.display,_that.xml);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LibvirtDomainDetail implements LibvirtDomainDetail {
  const _LibvirtDomainDetail({this.display, this.xml = const LibvirtDomainXml()});
  factory _LibvirtDomainDetail.fromJson(Map<String, dynamic> json) => _$LibvirtDomainDetailFromJson(json);

@override final  VirtDisplay? display;
@override@JsonKey() final  LibvirtDomainXml xml;

/// Create a copy of LibvirtDomainDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtDomainDetailCopyWith<_LibvirtDomainDetail> get copyWith => __$LibvirtDomainDetailCopyWithImpl<_LibvirtDomainDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtDomainDetailToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtDomainDetail&&(identical(other.display, display) || other.display == display)&&(identical(other.xml, xml) || other.xml == xml));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,display,xml);

@override
String toString() {
  return 'LibvirtDomainDetail(display: $display, xml: $xml)';
}


}

/// @nodoc
abstract mixin class _$LibvirtDomainDetailCopyWith<$Res> implements $LibvirtDomainDetailCopyWith<$Res> {
  factory _$LibvirtDomainDetailCopyWith(_LibvirtDomainDetail value, $Res Function(_LibvirtDomainDetail) _then) = __$LibvirtDomainDetailCopyWithImpl;
@override @useResult
$Res call({
 VirtDisplay? display, LibvirtDomainXml xml
});


@override $VirtDisplayCopyWith<$Res>? get display;@override $LibvirtDomainXmlCopyWith<$Res> get xml;

}
/// @nodoc
class __$LibvirtDomainDetailCopyWithImpl<$Res>
    implements _$LibvirtDomainDetailCopyWith<$Res> {
  __$LibvirtDomainDetailCopyWithImpl(this._self, this._then);

  final _LibvirtDomainDetail _self;
  final $Res Function(_LibvirtDomainDetail) _then;

/// Create a copy of LibvirtDomainDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? display = freezed,Object? xml = null,}) {
  return _then(_LibvirtDomainDetail(
display: freezed == display ? _self.display : display // ignore: cast_nullable_to_non_nullable
as VirtDisplay?,xml: null == xml ? _self.xml : xml // ignore: cast_nullable_to_non_nullable
as LibvirtDomainXml,
  ));
}

/// Create a copy of LibvirtDomainDetail
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
}/// Create a copy of LibvirtDomainDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtDomainXmlCopyWith<$Res> get xml {
  
  return $LibvirtDomainXmlCopyWith<$Res>(_self.xml, (value) {
    return _then(_self.copyWith(xml: value));
  });
}
}


/// @nodoc
mixin _$LibvirtSnapshot {

 String get name; String? get description; String? get parent;/// `running`, `paused`, `shutoff`, `disk-snapshot`.
 String? get state;/// Seconds since the epoch.
 int? get creationTime; bool get memory; bool get external; bool get current;
/// Create a copy of LibvirtSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtSnapshotCopyWith<LibvirtSnapshot> get copyWith => _$LibvirtSnapshotCopyWithImpl<LibvirtSnapshot>(this as LibvirtSnapshot, _$identity);

  /// Serializes this LibvirtSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtSnapshot&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.state, state) || other.state == state)&&(identical(other.creationTime, creationTime) || other.creationTime == creationTime)&&(identical(other.memory, memory) || other.memory == memory)&&(identical(other.external, external) || other.external == external)&&(identical(other.current, current) || other.current == current));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,parent,state,creationTime,memory,external,current);

@override
String toString() {
  return 'LibvirtSnapshot(name: $name, description: $description, parent: $parent, state: $state, creationTime: $creationTime, memory: $memory, external: $external, current: $current)';
}


}

/// @nodoc
abstract mixin class $LibvirtSnapshotCopyWith<$Res>  {
  factory $LibvirtSnapshotCopyWith(LibvirtSnapshot value, $Res Function(LibvirtSnapshot) _then) = _$LibvirtSnapshotCopyWithImpl;
@useResult
$Res call({
 String name, String? description, String? parent, String? state, int? creationTime, bool memory, bool external, bool current
});




}
/// @nodoc
class _$LibvirtSnapshotCopyWithImpl<$Res>
    implements $LibvirtSnapshotCopyWith<$Res> {
  _$LibvirtSnapshotCopyWithImpl(this._self, this._then);

  final LibvirtSnapshot _self;
  final $Res Function(LibvirtSnapshot) _then;

/// Create a copy of LibvirtSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = freezed,Object? parent = freezed,Object? state = freezed,Object? creationTime = freezed,Object? memory = null,Object? external = null,Object? current = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,parent: freezed == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String?,creationTime: freezed == creationTime ? _self.creationTime : creationTime // ignore: cast_nullable_to_non_nullable
as int?,memory: null == memory ? _self.memory : memory // ignore: cast_nullable_to_non_nullable
as bool,external: null == external ? _self.external : external // ignore: cast_nullable_to_non_nullable
as bool,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtSnapshot].
extension LibvirtSnapshotPatterns on LibvirtSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? description,  String? parent,  String? state,  int? creationTime,  bool memory,  bool external,  bool current)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtSnapshot() when $default != null:
return $default(_that.name,_that.description,_that.parent,_that.state,_that.creationTime,_that.memory,_that.external,_that.current);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? description,  String? parent,  String? state,  int? creationTime,  bool memory,  bool external,  bool current)  $default,) {final _that = this;
switch (_that) {
case _LibvirtSnapshot():
return $default(_that.name,_that.description,_that.parent,_that.state,_that.creationTime,_that.memory,_that.external,_that.current);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? description,  String? parent,  String? state,  int? creationTime,  bool memory,  bool external,  bool current)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtSnapshot() when $default != null:
return $default(_that.name,_that.description,_that.parent,_that.state,_that.creationTime,_that.memory,_that.external,_that.current);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtSnapshot implements LibvirtSnapshot {
  const _LibvirtSnapshot({required this.name, this.description, this.parent, this.state, this.creationTime, this.memory = false, this.external = false, this.current = false});
  factory _LibvirtSnapshot.fromJson(Map<String, dynamic> json) => _$LibvirtSnapshotFromJson(json);

@override final  String name;
@override final  String? description;
@override final  String? parent;
/// `running`, `paused`, `shutoff`, `disk-snapshot`.
@override final  String? state;
/// Seconds since the epoch.
@override final  int? creationTime;
@override@JsonKey() final  bool memory;
@override@JsonKey() final  bool external;
@override@JsonKey() final  bool current;

/// Create a copy of LibvirtSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtSnapshotCopyWith<_LibvirtSnapshot> get copyWith => __$LibvirtSnapshotCopyWithImpl<_LibvirtSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtSnapshot&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.state, state) || other.state == state)&&(identical(other.creationTime, creationTime) || other.creationTime == creationTime)&&(identical(other.memory, memory) || other.memory == memory)&&(identical(other.external, external) || other.external == external)&&(identical(other.current, current) || other.current == current));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,parent,state,creationTime,memory,external,current);

@override
String toString() {
  return 'LibvirtSnapshot(name: $name, description: $description, parent: $parent, state: $state, creationTime: $creationTime, memory: $memory, external: $external, current: $current)';
}


}

/// @nodoc
abstract mixin class _$LibvirtSnapshotCopyWith<$Res> implements $LibvirtSnapshotCopyWith<$Res> {
  factory _$LibvirtSnapshotCopyWith(_LibvirtSnapshot value, $Res Function(_LibvirtSnapshot) _then) = __$LibvirtSnapshotCopyWithImpl;
@override @useResult
$Res call({
 String name, String? description, String? parent, String? state, int? creationTime, bool memory, bool external, bool current
});




}
/// @nodoc
class __$LibvirtSnapshotCopyWithImpl<$Res>
    implements _$LibvirtSnapshotCopyWith<$Res> {
  __$LibvirtSnapshotCopyWithImpl(this._self, this._then);

  final _LibvirtSnapshot _self;
  final $Res Function(_LibvirtSnapshot) _then;

/// Create a copy of LibvirtSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = freezed,Object? parent = freezed,Object? state = freezed,Object? creationTime = freezed,Object? memory = null,Object? external = null,Object? current = null,}) {
  return _then(_LibvirtSnapshot(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,parent: freezed == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String?,creationTime: freezed == creationTime ? _self.creationTime : creationTime // ignore: cast_nullable_to_non_nullable
as int?,memory: null == memory ? _self.memory : memory // ignore: cast_nullable_to_non_nullable
as bool,external: null == external ? _self.external : external // ignore: cast_nullable_to_non_nullable
as bool,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$LibvirtVolumeRef {

 String get name; String? get path;
/// Create a copy of LibvirtVolumeRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtVolumeRefCopyWith<LibvirtVolumeRef> get copyWith => _$LibvirtVolumeRefCopyWithImpl<LibvirtVolumeRef>(this as LibvirtVolumeRef, _$identity);

  /// Serializes this LibvirtVolumeRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtVolumeRef&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,path);

@override
String toString() {
  return 'LibvirtVolumeRef(name: $name, path: $path)';
}


}

/// @nodoc
abstract mixin class $LibvirtVolumeRefCopyWith<$Res>  {
  factory $LibvirtVolumeRefCopyWith(LibvirtVolumeRef value, $Res Function(LibvirtVolumeRef) _then) = _$LibvirtVolumeRefCopyWithImpl;
@useResult
$Res call({
 String name, String? path
});




}
/// @nodoc
class _$LibvirtVolumeRefCopyWithImpl<$Res>
    implements $LibvirtVolumeRefCopyWith<$Res> {
  _$LibvirtVolumeRefCopyWithImpl(this._self, this._then);

  final LibvirtVolumeRef _self;
  final $Res Function(LibvirtVolumeRef) _then;

/// Create a copy of LibvirtVolumeRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? path = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtVolumeRef].
extension LibvirtVolumeRefPatterns on LibvirtVolumeRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtVolumeRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtVolumeRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtVolumeRef value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtVolumeRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtVolumeRef value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtVolumeRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? path)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtVolumeRef() when $default != null:
return $default(_that.name,_that.path);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? path)  $default,) {final _that = this;
switch (_that) {
case _LibvirtVolumeRef():
return $default(_that.name,_that.path);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? path)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtVolumeRef() when $default != null:
return $default(_that.name,_that.path);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LibvirtVolumeRef implements LibvirtVolumeRef {
  const _LibvirtVolumeRef({required this.name, this.path});
  factory _LibvirtVolumeRef.fromJson(Map<String, dynamic> json) => _$LibvirtVolumeRefFromJson(json);

@override final  String name;
@override final  String? path;

/// Create a copy of LibvirtVolumeRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtVolumeRefCopyWith<_LibvirtVolumeRef> get copyWith => __$LibvirtVolumeRefCopyWithImpl<_LibvirtVolumeRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtVolumeRefToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtVolumeRef&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,path);

@override
String toString() {
  return 'LibvirtVolumeRef(name: $name, path: $path)';
}


}

/// @nodoc
abstract mixin class _$LibvirtVolumeRefCopyWith<$Res> implements $LibvirtVolumeRefCopyWith<$Res> {
  factory _$LibvirtVolumeRefCopyWith(_LibvirtVolumeRef value, $Res Function(_LibvirtVolumeRef) _then) = __$LibvirtVolumeRefCopyWithImpl;
@override @useResult
$Res call({
 String name, String? path
});




}
/// @nodoc
class __$LibvirtVolumeRefCopyWithImpl<$Res>
    implements _$LibvirtVolumeRefCopyWith<$Res> {
  __$LibvirtVolumeRefCopyWithImpl(this._self, this._then);

  final _LibvirtVolumeRef _self;
  final $Res Function(_LibvirtVolumeRef) _then;

/// Create a copy of LibvirtVolumeRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? path = freezed,}) {
  return _then(_LibvirtVolumeRef(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LibvirtPool {

 String get name; String? get uuid; String? get poolType; bool get active; bool get autostart; int? get capacity; int? get allocation; int? get available; String? get target; String? get source;/// Null when they could not be listed (an inactive pool).
 List<LibvirtVolumeRef>? get volumes;
/// Create a copy of LibvirtPool
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtPoolCopyWith<LibvirtPool> get copyWith => _$LibvirtPoolCopyWithImpl<LibvirtPool>(this as LibvirtPool, _$identity);

  /// Serializes this LibvirtPool to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtPool&&(identical(other.name, name) || other.name == name)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.poolType, poolType) || other.poolType == poolType)&&(identical(other.active, active) || other.active == active)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.allocation, allocation) || other.allocation == allocation)&&(identical(other.available, available) || other.available == available)&&(identical(other.target, target) || other.target == target)&&(identical(other.source, source) || other.source == source)&&const DeepCollectionEquality().equals(other.volumes, volumes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,uuid,poolType,active,autostart,capacity,allocation,available,target,source,const DeepCollectionEquality().hash(volumes));

@override
String toString() {
  return 'LibvirtPool(name: $name, uuid: $uuid, poolType: $poolType, active: $active, autostart: $autostart, capacity: $capacity, allocation: $allocation, available: $available, target: $target, source: $source, volumes: $volumes)';
}


}

/// @nodoc
abstract mixin class $LibvirtPoolCopyWith<$Res>  {
  factory $LibvirtPoolCopyWith(LibvirtPool value, $Res Function(LibvirtPool) _then) = _$LibvirtPoolCopyWithImpl;
@useResult
$Res call({
 String name, String? uuid, String? poolType, bool active, bool autostart, int? capacity, int? allocation, int? available, String? target, String? source, List<LibvirtVolumeRef>? volumes
});




}
/// @nodoc
class _$LibvirtPoolCopyWithImpl<$Res>
    implements $LibvirtPoolCopyWith<$Res> {
  _$LibvirtPoolCopyWithImpl(this._self, this._then);

  final LibvirtPool _self;
  final $Res Function(LibvirtPool) _then;

/// Create a copy of LibvirtPool
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? uuid = freezed,Object? poolType = freezed,Object? active = null,Object? autostart = null,Object? capacity = freezed,Object? allocation = freezed,Object? available = freezed,Object? target = freezed,Object? source = freezed,Object? volumes = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,poolType: freezed == poolType ? _self.poolType : poolType // ignore: cast_nullable_to_non_nullable
as String?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,autostart: null == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,allocation: freezed == allocation ? _self.allocation : allocation // ignore: cast_nullable_to_non_nullable
as int?,available: freezed == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as int?,target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,volumes: freezed == volumes ? _self.volumes : volumes // ignore: cast_nullable_to_non_nullable
as List<LibvirtVolumeRef>?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtPool].
extension LibvirtPoolPatterns on LibvirtPool {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtPool value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtPool() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtPool value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtPool():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtPool value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtPool() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? uuid,  String? poolType,  bool active,  bool autostart,  int? capacity,  int? allocation,  int? available,  String? target,  String? source,  List<LibvirtVolumeRef>? volumes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtPool() when $default != null:
return $default(_that.name,_that.uuid,_that.poolType,_that.active,_that.autostart,_that.capacity,_that.allocation,_that.available,_that.target,_that.source,_that.volumes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? uuid,  String? poolType,  bool active,  bool autostart,  int? capacity,  int? allocation,  int? available,  String? target,  String? source,  List<LibvirtVolumeRef>? volumes)  $default,) {final _that = this;
switch (_that) {
case _LibvirtPool():
return $default(_that.name,_that.uuid,_that.poolType,_that.active,_that.autostart,_that.capacity,_that.allocation,_that.available,_that.target,_that.source,_that.volumes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? uuid,  String? poolType,  bool active,  bool autostart,  int? capacity,  int? allocation,  int? available,  String? target,  String? source,  List<LibvirtVolumeRef>? volumes)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtPool() when $default != null:
return $default(_that.name,_that.uuid,_that.poolType,_that.active,_that.autostart,_that.capacity,_that.allocation,_that.available,_that.target,_that.source,_that.volumes);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtPool implements LibvirtPool {
  const _LibvirtPool({required this.name, this.uuid, this.poolType, this.active = false, this.autostart = false, this.capacity, this.allocation, this.available, this.target, this.source, final  List<LibvirtVolumeRef>? volumes}): _volumes = volumes;
  factory _LibvirtPool.fromJson(Map<String, dynamic> json) => _$LibvirtPoolFromJson(json);

@override final  String name;
@override final  String? uuid;
@override final  String? poolType;
@override@JsonKey() final  bool active;
@override@JsonKey() final  bool autostart;
@override final  int? capacity;
@override final  int? allocation;
@override final  int? available;
@override final  String? target;
@override final  String? source;
/// Null when they could not be listed (an inactive pool).
 final  List<LibvirtVolumeRef>? _volumes;
/// Null when they could not be listed (an inactive pool).
@override List<LibvirtVolumeRef>? get volumes {
  final value = _volumes;
  if (value == null) return null;
  if (_volumes is EqualUnmodifiableListView) return _volumes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of LibvirtPool
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtPoolCopyWith<_LibvirtPool> get copyWith => __$LibvirtPoolCopyWithImpl<_LibvirtPool>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtPoolToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtPool&&(identical(other.name, name) || other.name == name)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.poolType, poolType) || other.poolType == poolType)&&(identical(other.active, active) || other.active == active)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.allocation, allocation) || other.allocation == allocation)&&(identical(other.available, available) || other.available == available)&&(identical(other.target, target) || other.target == target)&&(identical(other.source, source) || other.source == source)&&const DeepCollectionEquality().equals(other._volumes, _volumes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,uuid,poolType,active,autostart,capacity,allocation,available,target,source,const DeepCollectionEquality().hash(_volumes));

@override
String toString() {
  return 'LibvirtPool(name: $name, uuid: $uuid, poolType: $poolType, active: $active, autostart: $autostart, capacity: $capacity, allocation: $allocation, available: $available, target: $target, source: $source, volumes: $volumes)';
}


}

/// @nodoc
abstract mixin class _$LibvirtPoolCopyWith<$Res> implements $LibvirtPoolCopyWith<$Res> {
  factory _$LibvirtPoolCopyWith(_LibvirtPool value, $Res Function(_LibvirtPool) _then) = __$LibvirtPoolCopyWithImpl;
@override @useResult
$Res call({
 String name, String? uuid, String? poolType, bool active, bool autostart, int? capacity, int? allocation, int? available, String? target, String? source, List<LibvirtVolumeRef>? volumes
});




}
/// @nodoc
class __$LibvirtPoolCopyWithImpl<$Res>
    implements _$LibvirtPoolCopyWith<$Res> {
  __$LibvirtPoolCopyWithImpl(this._self, this._then);

  final _LibvirtPool _self;
  final $Res Function(_LibvirtPool) _then;

/// Create a copy of LibvirtPool
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? uuid = freezed,Object? poolType = freezed,Object? active = null,Object? autostart = null,Object? capacity = freezed,Object? allocation = freezed,Object? available = freezed,Object? target = freezed,Object? source = freezed,Object? volumes = freezed,}) {
  return _then(_LibvirtPool(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,poolType: freezed == poolType ? _self.poolType : poolType // ignore: cast_nullable_to_non_nullable
as String?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,autostart: null == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,allocation: freezed == allocation ? _self.allocation : allocation // ignore: cast_nullable_to_non_nullable
as int?,available: freezed == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as int?,target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,volumes: freezed == volumes ? _self._volumes : volumes // ignore: cast_nullable_to_non_nullable
as List<LibvirtVolumeRef>?,
  ));
}


}


/// @nodoc
mixin _$LibvirtDiskUse {

 String get domain; String get kind; String get device; String get target; String? get source;
/// Create a copy of LibvirtDiskUse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtDiskUseCopyWith<LibvirtDiskUse> get copyWith => _$LibvirtDiskUseCopyWithImpl<LibvirtDiskUse>(this as LibvirtDiskUse, _$identity);

  /// Serializes this LibvirtDiskUse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtDiskUse&&(identical(other.domain, domain) || other.domain == domain)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.device, device) || other.device == device)&&(identical(other.target, target) || other.target == target)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,domain,kind,device,target,source);

@override
String toString() {
  return 'LibvirtDiskUse(domain: $domain, kind: $kind, device: $device, target: $target, source: $source)';
}


}

/// @nodoc
abstract mixin class $LibvirtDiskUseCopyWith<$Res>  {
  factory $LibvirtDiskUseCopyWith(LibvirtDiskUse value, $Res Function(LibvirtDiskUse) _then) = _$LibvirtDiskUseCopyWithImpl;
@useResult
$Res call({
 String domain, String kind, String device, String target, String? source
});




}
/// @nodoc
class _$LibvirtDiskUseCopyWithImpl<$Res>
    implements $LibvirtDiskUseCopyWith<$Res> {
  _$LibvirtDiskUseCopyWithImpl(this._self, this._then);

  final LibvirtDiskUse _self;
  final $Res Function(LibvirtDiskUse) _then;

/// Create a copy of LibvirtDiskUse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? domain = null,Object? kind = null,Object? device = null,Object? target = null,Object? source = freezed,}) {
  return _then(_self.copyWith(
domain: null == domain ? _self.domain : domain // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtDiskUse].
extension LibvirtDiskUsePatterns on LibvirtDiskUse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtDiskUse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtDiskUse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtDiskUse value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtDiskUse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtDiskUse value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtDiskUse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String domain,  String kind,  String device,  String target,  String? source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtDiskUse() when $default != null:
return $default(_that.domain,_that.kind,_that.device,_that.target,_that.source);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String domain,  String kind,  String device,  String target,  String? source)  $default,) {final _that = this;
switch (_that) {
case _LibvirtDiskUse():
return $default(_that.domain,_that.kind,_that.device,_that.target,_that.source);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String domain,  String kind,  String device,  String target,  String? source)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtDiskUse() when $default != null:
return $default(_that.domain,_that.kind,_that.device,_that.target,_that.source);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LibvirtDiskUse implements LibvirtDiskUse {
  const _LibvirtDiskUse({required this.domain, this.kind = '', this.device = '', this.target = '', this.source});
  factory _LibvirtDiskUse.fromJson(Map<String, dynamic> json) => _$LibvirtDiskUseFromJson(json);

@override final  String domain;
@override@JsonKey() final  String kind;
@override@JsonKey() final  String device;
@override@JsonKey() final  String target;
@override final  String? source;

/// Create a copy of LibvirtDiskUse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtDiskUseCopyWith<_LibvirtDiskUse> get copyWith => __$LibvirtDiskUseCopyWithImpl<_LibvirtDiskUse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtDiskUseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtDiskUse&&(identical(other.domain, domain) || other.domain == domain)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.device, device) || other.device == device)&&(identical(other.target, target) || other.target == target)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,domain,kind,device,target,source);

@override
String toString() {
  return 'LibvirtDiskUse(domain: $domain, kind: $kind, device: $device, target: $target, source: $source)';
}


}

/// @nodoc
abstract mixin class _$LibvirtDiskUseCopyWith<$Res> implements $LibvirtDiskUseCopyWith<$Res> {
  factory _$LibvirtDiskUseCopyWith(_LibvirtDiskUse value, $Res Function(_LibvirtDiskUse) _then) = __$LibvirtDiskUseCopyWithImpl;
@override @useResult
$Res call({
 String domain, String kind, String device, String target, String? source
});




}
/// @nodoc
class __$LibvirtDiskUseCopyWithImpl<$Res>
    implements _$LibvirtDiskUseCopyWith<$Res> {
  __$LibvirtDiskUseCopyWithImpl(this._self, this._then);

  final _LibvirtDiskUse _self;
  final $Res Function(_LibvirtDiskUse) _then;

/// Create a copy of LibvirtDiskUse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? domain = null,Object? kind = null,Object? device = null,Object? target = null,Object? source = freezed,}) {
  return _then(_LibvirtDiskUse(
domain: null == domain ? _self.domain : domain // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LibvirtStorage {

 List<LibvirtPool> get pools; List<LibvirtDiskUse> get disks;
/// Create a copy of LibvirtStorage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtStorageCopyWith<LibvirtStorage> get copyWith => _$LibvirtStorageCopyWithImpl<LibvirtStorage>(this as LibvirtStorage, _$identity);

  /// Serializes this LibvirtStorage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtStorage&&const DeepCollectionEquality().equals(other.pools, pools)&&const DeepCollectionEquality().equals(other.disks, disks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(pools),const DeepCollectionEquality().hash(disks));

@override
String toString() {
  return 'LibvirtStorage(pools: $pools, disks: $disks)';
}


}

/// @nodoc
abstract mixin class $LibvirtStorageCopyWith<$Res>  {
  factory $LibvirtStorageCopyWith(LibvirtStorage value, $Res Function(LibvirtStorage) _then) = _$LibvirtStorageCopyWithImpl;
@useResult
$Res call({
 List<LibvirtPool> pools, List<LibvirtDiskUse> disks
});




}
/// @nodoc
class _$LibvirtStorageCopyWithImpl<$Res>
    implements $LibvirtStorageCopyWith<$Res> {
  _$LibvirtStorageCopyWithImpl(this._self, this._then);

  final LibvirtStorage _self;
  final $Res Function(LibvirtStorage) _then;

/// Create a copy of LibvirtStorage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pools = null,Object? disks = null,}) {
  return _then(_self.copyWith(
pools: null == pools ? _self.pools : pools // ignore: cast_nullable_to_non_nullable
as List<LibvirtPool>,disks: null == disks ? _self.disks : disks // ignore: cast_nullable_to_non_nullable
as List<LibvirtDiskUse>,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtStorage].
extension LibvirtStoragePatterns on LibvirtStorage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtStorage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtStorage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtStorage value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtStorage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtStorage value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtStorage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<LibvirtPool> pools,  List<LibvirtDiskUse> disks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtStorage() when $default != null:
return $default(_that.pools,_that.disks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<LibvirtPool> pools,  List<LibvirtDiskUse> disks)  $default,) {final _that = this;
switch (_that) {
case _LibvirtStorage():
return $default(_that.pools,_that.disks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<LibvirtPool> pools,  List<LibvirtDiskUse> disks)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtStorage() when $default != null:
return $default(_that.pools,_that.disks);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LibvirtStorage implements LibvirtStorage {
  const _LibvirtStorage({final  List<LibvirtPool> pools = const <LibvirtPool>[], final  List<LibvirtDiskUse> disks = const <LibvirtDiskUse>[]}): _pools = pools,_disks = disks;
  factory _LibvirtStorage.fromJson(Map<String, dynamic> json) => _$LibvirtStorageFromJson(json);

 final  List<LibvirtPool> _pools;
@override@JsonKey() List<LibvirtPool> get pools {
  if (_pools is EqualUnmodifiableListView) return _pools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pools);
}

 final  List<LibvirtDiskUse> _disks;
@override@JsonKey() List<LibvirtDiskUse> get disks {
  if (_disks is EqualUnmodifiableListView) return _disks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_disks);
}


/// Create a copy of LibvirtStorage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtStorageCopyWith<_LibvirtStorage> get copyWith => __$LibvirtStorageCopyWithImpl<_LibvirtStorage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtStorageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtStorage&&const DeepCollectionEquality().equals(other._pools, _pools)&&const DeepCollectionEquality().equals(other._disks, _disks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_pools),const DeepCollectionEquality().hash(_disks));

@override
String toString() {
  return 'LibvirtStorage(pools: $pools, disks: $disks)';
}


}

/// @nodoc
abstract mixin class _$LibvirtStorageCopyWith<$Res> implements $LibvirtStorageCopyWith<$Res> {
  factory _$LibvirtStorageCopyWith(_LibvirtStorage value, $Res Function(_LibvirtStorage) _then) = __$LibvirtStorageCopyWithImpl;
@override @useResult
$Res call({
 List<LibvirtPool> pools, List<LibvirtDiskUse> disks
});




}
/// @nodoc
class __$LibvirtStorageCopyWithImpl<$Res>
    implements _$LibvirtStorageCopyWith<$Res> {
  __$LibvirtStorageCopyWithImpl(this._self, this._then);

  final _LibvirtStorage _self;
  final $Res Function(_LibvirtStorage) _then;

/// Create a copy of LibvirtStorage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pools = null,Object? disks = null,}) {
  return _then(_LibvirtStorage(
pools: null == pools ? _self._pools : pools // ignore: cast_nullable_to_non_nullable
as List<LibvirtPool>,disks: null == disks ? _self._disks : disks // ignore: cast_nullable_to_non_nullable
as List<LibvirtDiskUse>,
  ));
}


}


/// @nodoc
mixin _$LibvirtVolume {

 String get name; String? get volType; String? get path; String? get format; int? get capacity; int? get allocation; String? get backing;
/// Create a copy of LibvirtVolume
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtVolumeCopyWith<LibvirtVolume> get copyWith => _$LibvirtVolumeCopyWithImpl<LibvirtVolume>(this as LibvirtVolume, _$identity);

  /// Serializes this LibvirtVolume to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtVolume&&(identical(other.name, name) || other.name == name)&&(identical(other.volType, volType) || other.volType == volType)&&(identical(other.path, path) || other.path == path)&&(identical(other.format, format) || other.format == format)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.allocation, allocation) || other.allocation == allocation)&&(identical(other.backing, backing) || other.backing == backing));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,volType,path,format,capacity,allocation,backing);

@override
String toString() {
  return 'LibvirtVolume(name: $name, volType: $volType, path: $path, format: $format, capacity: $capacity, allocation: $allocation, backing: $backing)';
}


}

/// @nodoc
abstract mixin class $LibvirtVolumeCopyWith<$Res>  {
  factory $LibvirtVolumeCopyWith(LibvirtVolume value, $Res Function(LibvirtVolume) _then) = _$LibvirtVolumeCopyWithImpl;
@useResult
$Res call({
 String name, String? volType, String? path, String? format, int? capacity, int? allocation, String? backing
});




}
/// @nodoc
class _$LibvirtVolumeCopyWithImpl<$Res>
    implements $LibvirtVolumeCopyWith<$Res> {
  _$LibvirtVolumeCopyWithImpl(this._self, this._then);

  final LibvirtVolume _self;
  final $Res Function(LibvirtVolume) _then;

/// Create a copy of LibvirtVolume
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? volType = freezed,Object? path = freezed,Object? format = freezed,Object? capacity = freezed,Object? allocation = freezed,Object? backing = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,volType: freezed == volType ? _self.volType : volType // ignore: cast_nullable_to_non_nullable
as String?,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,allocation: freezed == allocation ? _self.allocation : allocation // ignore: cast_nullable_to_non_nullable
as int?,backing: freezed == backing ? _self.backing : backing // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtVolume].
extension LibvirtVolumePatterns on LibvirtVolume {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtVolume value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtVolume() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtVolume value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtVolume():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtVolume value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtVolume() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? volType,  String? path,  String? format,  int? capacity,  int? allocation,  String? backing)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtVolume() when $default != null:
return $default(_that.name,_that.volType,_that.path,_that.format,_that.capacity,_that.allocation,_that.backing);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? volType,  String? path,  String? format,  int? capacity,  int? allocation,  String? backing)  $default,) {final _that = this;
switch (_that) {
case _LibvirtVolume():
return $default(_that.name,_that.volType,_that.path,_that.format,_that.capacity,_that.allocation,_that.backing);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? volType,  String? path,  String? format,  int? capacity,  int? allocation,  String? backing)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtVolume() when $default != null:
return $default(_that.name,_that.volType,_that.path,_that.format,_that.capacity,_that.allocation,_that.backing);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtVolume implements LibvirtVolume {
  const _LibvirtVolume({required this.name, this.volType, this.path, this.format, this.capacity, this.allocation, this.backing});
  factory _LibvirtVolume.fromJson(Map<String, dynamic> json) => _$LibvirtVolumeFromJson(json);

@override final  String name;
@override final  String? volType;
@override final  String? path;
@override final  String? format;
@override final  int? capacity;
@override final  int? allocation;
@override final  String? backing;

/// Create a copy of LibvirtVolume
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtVolumeCopyWith<_LibvirtVolume> get copyWith => __$LibvirtVolumeCopyWithImpl<_LibvirtVolume>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtVolumeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtVolume&&(identical(other.name, name) || other.name == name)&&(identical(other.volType, volType) || other.volType == volType)&&(identical(other.path, path) || other.path == path)&&(identical(other.format, format) || other.format == format)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.allocation, allocation) || other.allocation == allocation)&&(identical(other.backing, backing) || other.backing == backing));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,volType,path,format,capacity,allocation,backing);

@override
String toString() {
  return 'LibvirtVolume(name: $name, volType: $volType, path: $path, format: $format, capacity: $capacity, allocation: $allocation, backing: $backing)';
}


}

/// @nodoc
abstract mixin class _$LibvirtVolumeCopyWith<$Res> implements $LibvirtVolumeCopyWith<$Res> {
  factory _$LibvirtVolumeCopyWith(_LibvirtVolume value, $Res Function(_LibvirtVolume) _then) = __$LibvirtVolumeCopyWithImpl;
@override @useResult
$Res call({
 String name, String? volType, String? path, String? format, int? capacity, int? allocation, String? backing
});




}
/// @nodoc
class __$LibvirtVolumeCopyWithImpl<$Res>
    implements _$LibvirtVolumeCopyWith<$Res> {
  __$LibvirtVolumeCopyWithImpl(this._self, this._then);

  final _LibvirtVolume _self;
  final $Res Function(_LibvirtVolume) _then;

/// Create a copy of LibvirtVolume
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? volType = freezed,Object? path = freezed,Object? format = freezed,Object? capacity = freezed,Object? allocation = freezed,Object? backing = freezed,}) {
  return _then(_LibvirtVolume(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,volType: freezed == volType ? _self.volType : volType // ignore: cast_nullable_to_non_nullable
as String?,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,allocation: freezed == allocation ? _self.allocation : allocation // ignore: cast_nullable_to_non_nullable
as int?,backing: freezed == backing ? _self.backing : backing // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LibvirtNetIp {

 String get family; String get cidr; List<String> get dhcpRanges;
/// Create a copy of LibvirtNetIp
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtNetIpCopyWith<LibvirtNetIp> get copyWith => _$LibvirtNetIpCopyWithImpl<LibvirtNetIp>(this as LibvirtNetIp, _$identity);

  /// Serializes this LibvirtNetIp to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtNetIp&&(identical(other.family, family) || other.family == family)&&(identical(other.cidr, cidr) || other.cidr == cidr)&&const DeepCollectionEquality().equals(other.dhcpRanges, dhcpRanges));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,family,cidr,const DeepCollectionEquality().hash(dhcpRanges));

@override
String toString() {
  return 'LibvirtNetIp(family: $family, cidr: $cidr, dhcpRanges: $dhcpRanges)';
}


}

/// @nodoc
abstract mixin class $LibvirtNetIpCopyWith<$Res>  {
  factory $LibvirtNetIpCopyWith(LibvirtNetIp value, $Res Function(LibvirtNetIp) _then) = _$LibvirtNetIpCopyWithImpl;
@useResult
$Res call({
 String family, String cidr, List<String> dhcpRanges
});




}
/// @nodoc
class _$LibvirtNetIpCopyWithImpl<$Res>
    implements $LibvirtNetIpCopyWith<$Res> {
  _$LibvirtNetIpCopyWithImpl(this._self, this._then);

  final LibvirtNetIp _self;
  final $Res Function(LibvirtNetIp) _then;

/// Create a copy of LibvirtNetIp
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? family = null,Object? cidr = null,Object? dhcpRanges = null,}) {
  return _then(_self.copyWith(
family: null == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String,cidr: null == cidr ? _self.cidr : cidr // ignore: cast_nullable_to_non_nullable
as String,dhcpRanges: null == dhcpRanges ? _self.dhcpRanges : dhcpRanges // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtNetIp].
extension LibvirtNetIpPatterns on LibvirtNetIp {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtNetIp value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtNetIp() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtNetIp value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtNetIp():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtNetIp value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtNetIp() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String family,  String cidr,  List<String> dhcpRanges)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtNetIp() when $default != null:
return $default(_that.family,_that.cidr,_that.dhcpRanges);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String family,  String cidr,  List<String> dhcpRanges)  $default,) {final _that = this;
switch (_that) {
case _LibvirtNetIp():
return $default(_that.family,_that.cidr,_that.dhcpRanges);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String family,  String cidr,  List<String> dhcpRanges)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtNetIp() when $default != null:
return $default(_that.family,_that.cidr,_that.dhcpRanges);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtNetIp implements LibvirtNetIp {
  const _LibvirtNetIp({this.family = 'ipv4', required this.cidr, final  List<String> dhcpRanges = const <String>[]}): _dhcpRanges = dhcpRanges;
  factory _LibvirtNetIp.fromJson(Map<String, dynamic> json) => _$LibvirtNetIpFromJson(json);

@override@JsonKey() final  String family;
@override final  String cidr;
 final  List<String> _dhcpRanges;
@override@JsonKey() List<String> get dhcpRanges {
  if (_dhcpRanges is EqualUnmodifiableListView) return _dhcpRanges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_dhcpRanges);
}


/// Create a copy of LibvirtNetIp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtNetIpCopyWith<_LibvirtNetIp> get copyWith => __$LibvirtNetIpCopyWithImpl<_LibvirtNetIp>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtNetIpToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtNetIp&&(identical(other.family, family) || other.family == family)&&(identical(other.cidr, cidr) || other.cidr == cidr)&&const DeepCollectionEquality().equals(other._dhcpRanges, _dhcpRanges));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,family,cidr,const DeepCollectionEquality().hash(_dhcpRanges));

@override
String toString() {
  return 'LibvirtNetIp(family: $family, cidr: $cidr, dhcpRanges: $dhcpRanges)';
}


}

/// @nodoc
abstract mixin class _$LibvirtNetIpCopyWith<$Res> implements $LibvirtNetIpCopyWith<$Res> {
  factory _$LibvirtNetIpCopyWith(_LibvirtNetIp value, $Res Function(_LibvirtNetIp) _then) = __$LibvirtNetIpCopyWithImpl;
@override @useResult
$Res call({
 String family, String cidr, List<String> dhcpRanges
});




}
/// @nodoc
class __$LibvirtNetIpCopyWithImpl<$Res>
    implements _$LibvirtNetIpCopyWith<$Res> {
  __$LibvirtNetIpCopyWithImpl(this._self, this._then);

  final _LibvirtNetIp _self;
  final $Res Function(_LibvirtNetIp) _then;

/// Create a copy of LibvirtNetIp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? family = null,Object? cidr = null,Object? dhcpRanges = null,}) {
  return _then(_LibvirtNetIp(
family: null == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String,cidr: null == cidr ? _self.cidr : cidr // ignore: cast_nullable_to_non_nullable
as String,dhcpRanges: null == dhcpRanges ? _self._dhcpRanges : dhcpRanges // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$LibvirtNetwork {

 String get name; String? get uuid; bool get active; bool get autostart; String get mode; String? get bridge; List<String> get forwardDevs; List<LibvirtNetIp> get ips; int? get connections;
/// Create a copy of LibvirtNetwork
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtNetworkCopyWith<LibvirtNetwork> get copyWith => _$LibvirtNetworkCopyWithImpl<LibvirtNetwork>(this as LibvirtNetwork, _$identity);

  /// Serializes this LibvirtNetwork to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtNetwork&&(identical(other.name, name) || other.name == name)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.active, active) || other.active == active)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.bridge, bridge) || other.bridge == bridge)&&const DeepCollectionEquality().equals(other.forwardDevs, forwardDevs)&&const DeepCollectionEquality().equals(other.ips, ips)&&(identical(other.connections, connections) || other.connections == connections));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,uuid,active,autostart,mode,bridge,const DeepCollectionEquality().hash(forwardDevs),const DeepCollectionEquality().hash(ips),connections);

@override
String toString() {
  return 'LibvirtNetwork(name: $name, uuid: $uuid, active: $active, autostart: $autostart, mode: $mode, bridge: $bridge, forwardDevs: $forwardDevs, ips: $ips, connections: $connections)';
}


}

/// @nodoc
abstract mixin class $LibvirtNetworkCopyWith<$Res>  {
  factory $LibvirtNetworkCopyWith(LibvirtNetwork value, $Res Function(LibvirtNetwork) _then) = _$LibvirtNetworkCopyWithImpl;
@useResult
$Res call({
 String name, String? uuid, bool active, bool autostart, String mode, String? bridge, List<String> forwardDevs, List<LibvirtNetIp> ips, int? connections
});




}
/// @nodoc
class _$LibvirtNetworkCopyWithImpl<$Res>
    implements $LibvirtNetworkCopyWith<$Res> {
  _$LibvirtNetworkCopyWithImpl(this._self, this._then);

  final LibvirtNetwork _self;
  final $Res Function(LibvirtNetwork) _then;

/// Create a copy of LibvirtNetwork
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? uuid = freezed,Object? active = null,Object? autostart = null,Object? mode = null,Object? bridge = freezed,Object? forwardDevs = null,Object? ips = null,Object? connections = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,autostart: null == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,bridge: freezed == bridge ? _self.bridge : bridge // ignore: cast_nullable_to_non_nullable
as String?,forwardDevs: null == forwardDevs ? _self.forwardDevs : forwardDevs // ignore: cast_nullable_to_non_nullable
as List<String>,ips: null == ips ? _self.ips : ips // ignore: cast_nullable_to_non_nullable
as List<LibvirtNetIp>,connections: freezed == connections ? _self.connections : connections // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtNetwork].
extension LibvirtNetworkPatterns on LibvirtNetwork {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtNetwork value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtNetwork() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtNetwork value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtNetwork():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtNetwork value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtNetwork() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? uuid,  bool active,  bool autostart,  String mode,  String? bridge,  List<String> forwardDevs,  List<LibvirtNetIp> ips,  int? connections)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtNetwork() when $default != null:
return $default(_that.name,_that.uuid,_that.active,_that.autostart,_that.mode,_that.bridge,_that.forwardDevs,_that.ips,_that.connections);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? uuid,  bool active,  bool autostart,  String mode,  String? bridge,  List<String> forwardDevs,  List<LibvirtNetIp> ips,  int? connections)  $default,) {final _that = this;
switch (_that) {
case _LibvirtNetwork():
return $default(_that.name,_that.uuid,_that.active,_that.autostart,_that.mode,_that.bridge,_that.forwardDevs,_that.ips,_that.connections);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? uuid,  bool active,  bool autostart,  String mode,  String? bridge,  List<String> forwardDevs,  List<LibvirtNetIp> ips,  int? connections)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtNetwork() when $default != null:
return $default(_that.name,_that.uuid,_that.active,_that.autostart,_that.mode,_that.bridge,_that.forwardDevs,_that.ips,_that.connections);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtNetwork implements LibvirtNetwork {
  const _LibvirtNetwork({required this.name, this.uuid, this.active = false, this.autostart = false, this.mode = 'isolated', this.bridge, final  List<String> forwardDevs = const <String>[], final  List<LibvirtNetIp> ips = const <LibvirtNetIp>[], this.connections}): _forwardDevs = forwardDevs,_ips = ips;
  factory _LibvirtNetwork.fromJson(Map<String, dynamic> json) => _$LibvirtNetworkFromJson(json);

@override final  String name;
@override final  String? uuid;
@override@JsonKey() final  bool active;
@override@JsonKey() final  bool autostart;
@override@JsonKey() final  String mode;
@override final  String? bridge;
 final  List<String> _forwardDevs;
@override@JsonKey() List<String> get forwardDevs {
  if (_forwardDevs is EqualUnmodifiableListView) return _forwardDevs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_forwardDevs);
}

 final  List<LibvirtNetIp> _ips;
@override@JsonKey() List<LibvirtNetIp> get ips {
  if (_ips is EqualUnmodifiableListView) return _ips;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ips);
}

@override final  int? connections;

/// Create a copy of LibvirtNetwork
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtNetworkCopyWith<_LibvirtNetwork> get copyWith => __$LibvirtNetworkCopyWithImpl<_LibvirtNetwork>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtNetworkToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtNetwork&&(identical(other.name, name) || other.name == name)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.active, active) || other.active == active)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.bridge, bridge) || other.bridge == bridge)&&const DeepCollectionEquality().equals(other._forwardDevs, _forwardDevs)&&const DeepCollectionEquality().equals(other._ips, _ips)&&(identical(other.connections, connections) || other.connections == connections));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,uuid,active,autostart,mode,bridge,const DeepCollectionEquality().hash(_forwardDevs),const DeepCollectionEquality().hash(_ips),connections);

@override
String toString() {
  return 'LibvirtNetwork(name: $name, uuid: $uuid, active: $active, autostart: $autostart, mode: $mode, bridge: $bridge, forwardDevs: $forwardDevs, ips: $ips, connections: $connections)';
}


}

/// @nodoc
abstract mixin class _$LibvirtNetworkCopyWith<$Res> implements $LibvirtNetworkCopyWith<$Res> {
  factory _$LibvirtNetworkCopyWith(_LibvirtNetwork value, $Res Function(_LibvirtNetwork) _then) = __$LibvirtNetworkCopyWithImpl;
@override @useResult
$Res call({
 String name, String? uuid, bool active, bool autostart, String mode, String? bridge, List<String> forwardDevs, List<LibvirtNetIp> ips, int? connections
});




}
/// @nodoc
class __$LibvirtNetworkCopyWithImpl<$Res>
    implements _$LibvirtNetworkCopyWith<$Res> {
  __$LibvirtNetworkCopyWithImpl(this._self, this._then);

  final _LibvirtNetwork _self;
  final $Res Function(_LibvirtNetwork) _then;

/// Create a copy of LibvirtNetwork
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? uuid = freezed,Object? active = null,Object? autostart = null,Object? mode = null,Object? bridge = freezed,Object? forwardDevs = null,Object? ips = null,Object? connections = freezed,}) {
  return _then(_LibvirtNetwork(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,autostart: null == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,bridge: freezed == bridge ? _self.bridge : bridge // ignore: cast_nullable_to_non_nullable
as String?,forwardDevs: null == forwardDevs ? _self._forwardDevs : forwardDevs // ignore: cast_nullable_to_non_nullable
as List<String>,ips: null == ips ? _self._ips : ips // ignore: cast_nullable_to_non_nullable
as List<LibvirtNetIp>,connections: freezed == connections ? _self.connections : connections // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$LibvirtIfaceUse {

 String get domain; String? get interface; String get kind; String? get source; String? get model; String? get mac;
/// Create a copy of LibvirtIfaceUse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtIfaceUseCopyWith<LibvirtIfaceUse> get copyWith => _$LibvirtIfaceUseCopyWithImpl<LibvirtIfaceUse>(this as LibvirtIfaceUse, _$identity);

  /// Serializes this LibvirtIfaceUse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtIfaceUse&&(identical(other.domain, domain) || other.domain == domain)&&(identical(other.interface, interface) || other.interface == interface)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.source, source) || other.source == source)&&(identical(other.model, model) || other.model == model)&&(identical(other.mac, mac) || other.mac == mac));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,domain,interface,kind,source,model,mac);

@override
String toString() {
  return 'LibvirtIfaceUse(domain: $domain, interface: $interface, kind: $kind, source: $source, model: $model, mac: $mac)';
}


}

/// @nodoc
abstract mixin class $LibvirtIfaceUseCopyWith<$Res>  {
  factory $LibvirtIfaceUseCopyWith(LibvirtIfaceUse value, $Res Function(LibvirtIfaceUse) _then) = _$LibvirtIfaceUseCopyWithImpl;
@useResult
$Res call({
 String domain, String? interface, String kind, String? source, String? model, String? mac
});




}
/// @nodoc
class _$LibvirtIfaceUseCopyWithImpl<$Res>
    implements $LibvirtIfaceUseCopyWith<$Res> {
  _$LibvirtIfaceUseCopyWithImpl(this._self, this._then);

  final LibvirtIfaceUse _self;
  final $Res Function(LibvirtIfaceUse) _then;

/// Create a copy of LibvirtIfaceUse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? domain = null,Object? interface = freezed,Object? kind = null,Object? source = freezed,Object? model = freezed,Object? mac = freezed,}) {
  return _then(_self.copyWith(
domain: null == domain ? _self.domain : domain // ignore: cast_nullable_to_non_nullable
as String,interface: freezed == interface ? _self.interface : interface // ignore: cast_nullable_to_non_nullable
as String?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,mac: freezed == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtIfaceUse].
extension LibvirtIfaceUsePatterns on LibvirtIfaceUse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtIfaceUse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtIfaceUse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtIfaceUse value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtIfaceUse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtIfaceUse value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtIfaceUse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String domain,  String? interface,  String kind,  String? source,  String? model,  String? mac)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtIfaceUse() when $default != null:
return $default(_that.domain,_that.interface,_that.kind,_that.source,_that.model,_that.mac);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String domain,  String? interface,  String kind,  String? source,  String? model,  String? mac)  $default,) {final _that = this;
switch (_that) {
case _LibvirtIfaceUse():
return $default(_that.domain,_that.interface,_that.kind,_that.source,_that.model,_that.mac);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String domain,  String? interface,  String kind,  String? source,  String? model,  String? mac)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtIfaceUse() when $default != null:
return $default(_that.domain,_that.interface,_that.kind,_that.source,_that.model,_that.mac);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LibvirtIfaceUse implements LibvirtIfaceUse {
  const _LibvirtIfaceUse({required this.domain, this.interface, this.kind = '', this.source, this.model, this.mac});
  factory _LibvirtIfaceUse.fromJson(Map<String, dynamic> json) => _$LibvirtIfaceUseFromJson(json);

@override final  String domain;
@override final  String? interface;
@override@JsonKey() final  String kind;
@override final  String? source;
@override final  String? model;
@override final  String? mac;

/// Create a copy of LibvirtIfaceUse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtIfaceUseCopyWith<_LibvirtIfaceUse> get copyWith => __$LibvirtIfaceUseCopyWithImpl<_LibvirtIfaceUse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtIfaceUseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtIfaceUse&&(identical(other.domain, domain) || other.domain == domain)&&(identical(other.interface, interface) || other.interface == interface)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.source, source) || other.source == source)&&(identical(other.model, model) || other.model == model)&&(identical(other.mac, mac) || other.mac == mac));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,domain,interface,kind,source,model,mac);

@override
String toString() {
  return 'LibvirtIfaceUse(domain: $domain, interface: $interface, kind: $kind, source: $source, model: $model, mac: $mac)';
}


}

/// @nodoc
abstract mixin class _$LibvirtIfaceUseCopyWith<$Res> implements $LibvirtIfaceUseCopyWith<$Res> {
  factory _$LibvirtIfaceUseCopyWith(_LibvirtIfaceUse value, $Res Function(_LibvirtIfaceUse) _then) = __$LibvirtIfaceUseCopyWithImpl;
@override @useResult
$Res call({
 String domain, String? interface, String kind, String? source, String? model, String? mac
});




}
/// @nodoc
class __$LibvirtIfaceUseCopyWithImpl<$Res>
    implements _$LibvirtIfaceUseCopyWith<$Res> {
  __$LibvirtIfaceUseCopyWithImpl(this._self, this._then);

  final _LibvirtIfaceUse _self;
  final $Res Function(_LibvirtIfaceUse) _then;

/// Create a copy of LibvirtIfaceUse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? domain = null,Object? interface = freezed,Object? kind = null,Object? source = freezed,Object? model = freezed,Object? mac = freezed,}) {
  return _then(_LibvirtIfaceUse(
domain: null == domain ? _self.domain : domain // ignore: cast_nullable_to_non_nullable
as String,interface: freezed == interface ? _self.interface : interface // ignore: cast_nullable_to_non_nullable
as String?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,mac: freezed == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LibvirtLease {

 String get network; String get mac; String get ip; String? get hostname;
/// Create a copy of LibvirtLease
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtLeaseCopyWith<LibvirtLease> get copyWith => _$LibvirtLeaseCopyWithImpl<LibvirtLease>(this as LibvirtLease, _$identity);

  /// Serializes this LibvirtLease to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtLease&&(identical(other.network, network) || other.network == network)&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.hostname, hostname) || other.hostname == hostname));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,network,mac,ip,hostname);

@override
String toString() {
  return 'LibvirtLease(network: $network, mac: $mac, ip: $ip, hostname: $hostname)';
}


}

/// @nodoc
abstract mixin class $LibvirtLeaseCopyWith<$Res>  {
  factory $LibvirtLeaseCopyWith(LibvirtLease value, $Res Function(LibvirtLease) _then) = _$LibvirtLeaseCopyWithImpl;
@useResult
$Res call({
 String network, String mac, String ip, String? hostname
});




}
/// @nodoc
class _$LibvirtLeaseCopyWithImpl<$Res>
    implements $LibvirtLeaseCopyWith<$Res> {
  _$LibvirtLeaseCopyWithImpl(this._self, this._then);

  final LibvirtLease _self;
  final $Res Function(LibvirtLease) _then;

/// Create a copy of LibvirtLease
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? network = null,Object? mac = null,Object? ip = null,Object? hostname = freezed,}) {
  return _then(_self.copyWith(
network: null == network ? _self.network : network // ignore: cast_nullable_to_non_nullable
as String,mac: null == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,hostname: freezed == hostname ? _self.hostname : hostname // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtLease].
extension LibvirtLeasePatterns on LibvirtLease {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtLease value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtLease() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtLease value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtLease():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtLease value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtLease() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String network,  String mac,  String ip,  String? hostname)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtLease() when $default != null:
return $default(_that.network,_that.mac,_that.ip,_that.hostname);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String network,  String mac,  String ip,  String? hostname)  $default,) {final _that = this;
switch (_that) {
case _LibvirtLease():
return $default(_that.network,_that.mac,_that.ip,_that.hostname);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String network,  String mac,  String ip,  String? hostname)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtLease() when $default != null:
return $default(_that.network,_that.mac,_that.ip,_that.hostname);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LibvirtLease implements LibvirtLease {
  const _LibvirtLease({required this.network, required this.mac, required this.ip, this.hostname});
  factory _LibvirtLease.fromJson(Map<String, dynamic> json) => _$LibvirtLeaseFromJson(json);

@override final  String network;
@override final  String mac;
@override final  String ip;
@override final  String? hostname;

/// Create a copy of LibvirtLease
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtLeaseCopyWith<_LibvirtLease> get copyWith => __$LibvirtLeaseCopyWithImpl<_LibvirtLease>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtLeaseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtLease&&(identical(other.network, network) || other.network == network)&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.hostname, hostname) || other.hostname == hostname));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,network,mac,ip,hostname);

@override
String toString() {
  return 'LibvirtLease(network: $network, mac: $mac, ip: $ip, hostname: $hostname)';
}


}

/// @nodoc
abstract mixin class _$LibvirtLeaseCopyWith<$Res> implements $LibvirtLeaseCopyWith<$Res> {
  factory _$LibvirtLeaseCopyWith(_LibvirtLease value, $Res Function(_LibvirtLease) _then) = __$LibvirtLeaseCopyWithImpl;
@override @useResult
$Res call({
 String network, String mac, String ip, String? hostname
});




}
/// @nodoc
class __$LibvirtLeaseCopyWithImpl<$Res>
    implements _$LibvirtLeaseCopyWith<$Res> {
  __$LibvirtLeaseCopyWithImpl(this._self, this._then);

  final _LibvirtLease _self;
  final $Res Function(_LibvirtLease) _then;

/// Create a copy of LibvirtLease
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? network = null,Object? mac = null,Object? ip = null,Object? hostname = freezed,}) {
  return _then(_LibvirtLease(
network: null == network ? _self.network : network // ignore: cast_nullable_to_non_nullable
as String,mac: null == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,hostname: freezed == hostname ? _self.hostname : hostname // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LibvirtNetworks {

 List<LibvirtNetwork> get networks; List<LibvirtIfaceUse> get ifaces; List<LibvirtLease> get leases;
/// Create a copy of LibvirtNetworks
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtNetworksCopyWith<LibvirtNetworks> get copyWith => _$LibvirtNetworksCopyWithImpl<LibvirtNetworks>(this as LibvirtNetworks, _$identity);

  /// Serializes this LibvirtNetworks to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtNetworks&&const DeepCollectionEquality().equals(other.networks, networks)&&const DeepCollectionEquality().equals(other.ifaces, ifaces)&&const DeepCollectionEquality().equals(other.leases, leases));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(networks),const DeepCollectionEquality().hash(ifaces),const DeepCollectionEquality().hash(leases));

@override
String toString() {
  return 'LibvirtNetworks(networks: $networks, ifaces: $ifaces, leases: $leases)';
}


}

/// @nodoc
abstract mixin class $LibvirtNetworksCopyWith<$Res>  {
  factory $LibvirtNetworksCopyWith(LibvirtNetworks value, $Res Function(LibvirtNetworks) _then) = _$LibvirtNetworksCopyWithImpl;
@useResult
$Res call({
 List<LibvirtNetwork> networks, List<LibvirtIfaceUse> ifaces, List<LibvirtLease> leases
});




}
/// @nodoc
class _$LibvirtNetworksCopyWithImpl<$Res>
    implements $LibvirtNetworksCopyWith<$Res> {
  _$LibvirtNetworksCopyWithImpl(this._self, this._then);

  final LibvirtNetworks _self;
  final $Res Function(LibvirtNetworks) _then;

/// Create a copy of LibvirtNetworks
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? networks = null,Object? ifaces = null,Object? leases = null,}) {
  return _then(_self.copyWith(
networks: null == networks ? _self.networks : networks // ignore: cast_nullable_to_non_nullable
as List<LibvirtNetwork>,ifaces: null == ifaces ? _self.ifaces : ifaces // ignore: cast_nullable_to_non_nullable
as List<LibvirtIfaceUse>,leases: null == leases ? _self.leases : leases // ignore: cast_nullable_to_non_nullable
as List<LibvirtLease>,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtNetworks].
extension LibvirtNetworksPatterns on LibvirtNetworks {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtNetworks value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtNetworks() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtNetworks value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtNetworks():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtNetworks value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtNetworks() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<LibvirtNetwork> networks,  List<LibvirtIfaceUse> ifaces,  List<LibvirtLease> leases)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtNetworks() when $default != null:
return $default(_that.networks,_that.ifaces,_that.leases);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<LibvirtNetwork> networks,  List<LibvirtIfaceUse> ifaces,  List<LibvirtLease> leases)  $default,) {final _that = this;
switch (_that) {
case _LibvirtNetworks():
return $default(_that.networks,_that.ifaces,_that.leases);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<LibvirtNetwork> networks,  List<LibvirtIfaceUse> ifaces,  List<LibvirtLease> leases)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtNetworks() when $default != null:
return $default(_that.networks,_that.ifaces,_that.leases);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LibvirtNetworks implements LibvirtNetworks {
  const _LibvirtNetworks({final  List<LibvirtNetwork> networks = const <LibvirtNetwork>[], final  List<LibvirtIfaceUse> ifaces = const <LibvirtIfaceUse>[], final  List<LibvirtLease> leases = const <LibvirtLease>[]}): _networks = networks,_ifaces = ifaces,_leases = leases;
  factory _LibvirtNetworks.fromJson(Map<String, dynamic> json) => _$LibvirtNetworksFromJson(json);

 final  List<LibvirtNetwork> _networks;
@override@JsonKey() List<LibvirtNetwork> get networks {
  if (_networks is EqualUnmodifiableListView) return _networks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_networks);
}

 final  List<LibvirtIfaceUse> _ifaces;
@override@JsonKey() List<LibvirtIfaceUse> get ifaces {
  if (_ifaces is EqualUnmodifiableListView) return _ifaces;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ifaces);
}

 final  List<LibvirtLease> _leases;
@override@JsonKey() List<LibvirtLease> get leases {
  if (_leases is EqualUnmodifiableListView) return _leases;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_leases);
}


/// Create a copy of LibvirtNetworks
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtNetworksCopyWith<_LibvirtNetworks> get copyWith => __$LibvirtNetworksCopyWithImpl<_LibvirtNetworks>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtNetworksToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtNetworks&&const DeepCollectionEquality().equals(other._networks, _networks)&&const DeepCollectionEquality().equals(other._ifaces, _ifaces)&&const DeepCollectionEquality().equals(other._leases, _leases));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_networks),const DeepCollectionEquality().hash(_ifaces),const DeepCollectionEquality().hash(_leases));

@override
String toString() {
  return 'LibvirtNetworks(networks: $networks, ifaces: $ifaces, leases: $leases)';
}


}

/// @nodoc
abstract mixin class _$LibvirtNetworksCopyWith<$Res> implements $LibvirtNetworksCopyWith<$Res> {
  factory _$LibvirtNetworksCopyWith(_LibvirtNetworks value, $Res Function(_LibvirtNetworks) _then) = __$LibvirtNetworksCopyWithImpl;
@override @useResult
$Res call({
 List<LibvirtNetwork> networks, List<LibvirtIfaceUse> ifaces, List<LibvirtLease> leases
});




}
/// @nodoc
class __$LibvirtNetworksCopyWithImpl<$Res>
    implements _$LibvirtNetworksCopyWith<$Res> {
  __$LibvirtNetworksCopyWithImpl(this._self, this._then);

  final _LibvirtNetworks _self;
  final $Res Function(_LibvirtNetworks) _then;

/// Create a copy of LibvirtNetworks
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? networks = null,Object? ifaces = null,Object? leases = null,}) {
  return _then(_LibvirtNetworks(
networks: null == networks ? _self._networks : networks // ignore: cast_nullable_to_non_nullable
as List<LibvirtNetwork>,ifaces: null == ifaces ? _self._ifaces : ifaces // ignore: cast_nullable_to_non_nullable
as List<LibvirtIfaceUse>,leases: null == leases ? _self._leases : leases // ignore: cast_nullable_to_non_nullable
as List<LibvirtLease>,
  ));
}


}

// dart format on
