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

 String get uuid; String get name;/// `sbm_virt::libvirt::VirtState`: `running`, `paused`, `stopped`,
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
/// `sbm_virt::libvirt::VirtState`: `running`, `paused`, `stopped`,
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

 String? get name; String? get uuid; String? get description; String? get arch; String? get machine; List<VirtDisk> get disks; List<VirtNic> get nics; List<VirtGraphics> get graphics; bool get hasSerialConsole;/// The domain's own cloud-init seed volume: deleted with it.
 String? get seed;
/// Create a copy of LibvirtDomainXml
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtDomainXmlCopyWith<LibvirtDomainXml> get copyWith => _$LibvirtDomainXmlCopyWithImpl<LibvirtDomainXml>(this as LibvirtDomainXml, _$identity);

  /// Serializes this LibvirtDomainXml to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtDomainXml&&(identical(other.name, name) || other.name == name)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.description, description) || other.description == description)&&(identical(other.arch, arch) || other.arch == arch)&&(identical(other.machine, machine) || other.machine == machine)&&const DeepCollectionEquality().equals(other.disks, disks)&&const DeepCollectionEquality().equals(other.nics, nics)&&const DeepCollectionEquality().equals(other.graphics, graphics)&&(identical(other.hasSerialConsole, hasSerialConsole) || other.hasSerialConsole == hasSerialConsole)&&(identical(other.seed, seed) || other.seed == seed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,uuid,description,arch,machine,const DeepCollectionEquality().hash(disks),const DeepCollectionEquality().hash(nics),const DeepCollectionEquality().hash(graphics),hasSerialConsole,seed);

@override
String toString() {
  return 'LibvirtDomainXml(name: $name, uuid: $uuid, description: $description, arch: $arch, machine: $machine, disks: $disks, nics: $nics, graphics: $graphics, hasSerialConsole: $hasSerialConsole, seed: $seed)';
}


}

/// @nodoc
abstract mixin class $LibvirtDomainXmlCopyWith<$Res>  {
  factory $LibvirtDomainXmlCopyWith(LibvirtDomainXml value, $Res Function(LibvirtDomainXml) _then) = _$LibvirtDomainXmlCopyWithImpl;
@useResult
$Res call({
 String? name, String? uuid, String? description, String? arch, String? machine, List<VirtDisk> disks, List<VirtNic> nics, List<VirtGraphics> graphics, bool hasSerialConsole, String? seed
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
@pragma('vm:prefer-inline') @override $Res call({Object? name = freezed,Object? uuid = freezed,Object? description = freezed,Object? arch = freezed,Object? machine = freezed,Object? disks = null,Object? nics = null,Object? graphics = null,Object? hasSerialConsole = null,Object? seed = freezed,}) {
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
as bool,seed: freezed == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as String?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? name,  String? uuid,  String? description,  String? arch,  String? machine,  List<VirtDisk> disks,  List<VirtNic> nics,  List<VirtGraphics> graphics,  bool hasSerialConsole,  String? seed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtDomainXml() when $default != null:
return $default(_that.name,_that.uuid,_that.description,_that.arch,_that.machine,_that.disks,_that.nics,_that.graphics,_that.hasSerialConsole,_that.seed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? name,  String? uuid,  String? description,  String? arch,  String? machine,  List<VirtDisk> disks,  List<VirtNic> nics,  List<VirtGraphics> graphics,  bool hasSerialConsole,  String? seed)  $default,) {final _that = this;
switch (_that) {
case _LibvirtDomainXml():
return $default(_that.name,_that.uuid,_that.description,_that.arch,_that.machine,_that.disks,_that.nics,_that.graphics,_that.hasSerialConsole,_that.seed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? name,  String? uuid,  String? description,  String? arch,  String? machine,  List<VirtDisk> disks,  List<VirtNic> nics,  List<VirtGraphics> graphics,  bool hasSerialConsole,  String? seed)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtDomainXml() when $default != null:
return $default(_that.name,_that.uuid,_that.description,_that.arch,_that.machine,_that.disks,_that.nics,_that.graphics,_that.hasSerialConsole,_that.seed);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtDomainXml implements LibvirtDomainXml {
  const _LibvirtDomainXml({this.name, this.uuid, this.description, this.arch, this.machine, final  List<VirtDisk> disks = const <VirtDisk>[], final  List<VirtNic> nics = const <VirtNic>[], final  List<VirtGraphics> graphics = const <VirtGraphics>[], this.hasSerialConsole = false, this.seed}): _disks = disks,_nics = nics,_graphics = graphics;
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
/// The domain's own cloud-init seed volume: deleted with it.
@override final  String? seed;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtDomainXml&&(identical(other.name, name) || other.name == name)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.description, description) || other.description == description)&&(identical(other.arch, arch) || other.arch == arch)&&(identical(other.machine, machine) || other.machine == machine)&&const DeepCollectionEquality().equals(other._disks, _disks)&&const DeepCollectionEquality().equals(other._nics, _nics)&&const DeepCollectionEquality().equals(other._graphics, _graphics)&&(identical(other.hasSerialConsole, hasSerialConsole) || other.hasSerialConsole == hasSerialConsole)&&(identical(other.seed, seed) || other.seed == seed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,uuid,description,arch,machine,const DeepCollectionEquality().hash(_disks),const DeepCollectionEquality().hash(_nics),const DeepCollectionEquality().hash(_graphics),hasSerialConsole,seed);

@override
String toString() {
  return 'LibvirtDomainXml(name: $name, uuid: $uuid, description: $description, arch: $arch, machine: $machine, disks: $disks, nics: $nics, graphics: $graphics, hasSerialConsole: $hasSerialConsole, seed: $seed)';
}


}

/// @nodoc
abstract mixin class _$LibvirtDomainXmlCopyWith<$Res> implements $LibvirtDomainXmlCopyWith<$Res> {
  factory _$LibvirtDomainXmlCopyWith(_LibvirtDomainXml value, $Res Function(_LibvirtDomainXml) _then) = __$LibvirtDomainXmlCopyWithImpl;
@override @useResult
$Res call({
 String? name, String? uuid, String? description, String? arch, String? machine, List<VirtDisk> disks, List<VirtNic> nics, List<VirtGraphics> graphics, bool hasSerialConsole, String? seed
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
@override @pragma('vm:prefer-inline') $Res call({Object? name = freezed,Object? uuid = freezed,Object? description = freezed,Object? arch = freezed,Object? machine = freezed,Object? disks = null,Object? nics = null,Object? graphics = null,Object? hasSerialConsole = null,Object? seed = freezed,}) {
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
as bool,seed: freezed == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as String?,
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
 int? get creationTime; bool get memory; bool get external; bool get current;/// Which file each disk was left on (`<disks>`, or `<revertDisks>` for
/// one already reverted to once).
 List<LibvirtSnapLayer> get layers;
/// Create a copy of LibvirtSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtSnapshotCopyWith<LibvirtSnapshot> get copyWith => _$LibvirtSnapshotCopyWithImpl<LibvirtSnapshot>(this as LibvirtSnapshot, _$identity);

  /// Serializes this LibvirtSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtSnapshot&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.state, state) || other.state == state)&&(identical(other.creationTime, creationTime) || other.creationTime == creationTime)&&(identical(other.memory, memory) || other.memory == memory)&&(identical(other.external, external) || other.external == external)&&(identical(other.current, current) || other.current == current)&&const DeepCollectionEquality().equals(other.layers, layers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,parent,state,creationTime,memory,external,current,const DeepCollectionEquality().hash(layers));

@override
String toString() {
  return 'LibvirtSnapshot(name: $name, description: $description, parent: $parent, state: $state, creationTime: $creationTime, memory: $memory, external: $external, current: $current, layers: $layers)';
}


}

/// @nodoc
abstract mixin class $LibvirtSnapshotCopyWith<$Res>  {
  factory $LibvirtSnapshotCopyWith(LibvirtSnapshot value, $Res Function(LibvirtSnapshot) _then) = _$LibvirtSnapshotCopyWithImpl;
@useResult
$Res call({
 String name, String? description, String? parent, String? state, int? creationTime, bool memory, bool external, bool current, List<LibvirtSnapLayer> layers
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
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = freezed,Object? parent = freezed,Object? state = freezed,Object? creationTime = freezed,Object? memory = null,Object? external = null,Object? current = null,Object? layers = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,parent: freezed == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String?,creationTime: freezed == creationTime ? _self.creationTime : creationTime // ignore: cast_nullable_to_non_nullable
as int?,memory: null == memory ? _self.memory : memory // ignore: cast_nullable_to_non_nullable
as bool,external: null == external ? _self.external : external // ignore: cast_nullable_to_non_nullable
as bool,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,layers: null == layers ? _self.layers : layers // ignore: cast_nullable_to_non_nullable
as List<LibvirtSnapLayer>,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? description,  String? parent,  String? state,  int? creationTime,  bool memory,  bool external,  bool current,  List<LibvirtSnapLayer> layers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtSnapshot() when $default != null:
return $default(_that.name,_that.description,_that.parent,_that.state,_that.creationTime,_that.memory,_that.external,_that.current,_that.layers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? description,  String? parent,  String? state,  int? creationTime,  bool memory,  bool external,  bool current,  List<LibvirtSnapLayer> layers)  $default,) {final _that = this;
switch (_that) {
case _LibvirtSnapshot():
return $default(_that.name,_that.description,_that.parent,_that.state,_that.creationTime,_that.memory,_that.external,_that.current,_that.layers);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? description,  String? parent,  String? state,  int? creationTime,  bool memory,  bool external,  bool current,  List<LibvirtSnapLayer> layers)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtSnapshot() when $default != null:
return $default(_that.name,_that.description,_that.parent,_that.state,_that.creationTime,_that.memory,_that.external,_that.current,_that.layers);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtSnapshot implements LibvirtSnapshot {
  const _LibvirtSnapshot({required this.name, this.description, this.parent, this.state, this.creationTime, this.memory = false, this.external = false, this.current = false, final  List<LibvirtSnapLayer> layers = const <LibvirtSnapLayer>[]}): _layers = layers;
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
/// Which file each disk was left on (`<disks>`, or `<revertDisks>` for
/// one already reverted to once).
 final  List<LibvirtSnapLayer> _layers;
/// Which file each disk was left on (`<disks>`, or `<revertDisks>` for
/// one already reverted to once).
@override@JsonKey() List<LibvirtSnapLayer> get layers {
  if (_layers is EqualUnmodifiableListView) return _layers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_layers);
}


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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtSnapshot&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.parent, parent) || other.parent == parent)&&(identical(other.state, state) || other.state == state)&&(identical(other.creationTime, creationTime) || other.creationTime == creationTime)&&(identical(other.memory, memory) || other.memory == memory)&&(identical(other.external, external) || other.external == external)&&(identical(other.current, current) || other.current == current)&&const DeepCollectionEquality().equals(other._layers, _layers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,parent,state,creationTime,memory,external,current,const DeepCollectionEquality().hash(_layers));

@override
String toString() {
  return 'LibvirtSnapshot(name: $name, description: $description, parent: $parent, state: $state, creationTime: $creationTime, memory: $memory, external: $external, current: $current, layers: $layers)';
}


}

/// @nodoc
abstract mixin class _$LibvirtSnapshotCopyWith<$Res> implements $LibvirtSnapshotCopyWith<$Res> {
  factory _$LibvirtSnapshotCopyWith(_LibvirtSnapshot value, $Res Function(_LibvirtSnapshot) _then) = __$LibvirtSnapshotCopyWithImpl;
@override @useResult
$Res call({
 String name, String? description, String? parent, String? state, int? creationTime, bool memory, bool external, bool current, List<LibvirtSnapLayer> layers
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
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = freezed,Object? parent = freezed,Object? state = freezed,Object? creationTime = freezed,Object? memory = null,Object? external = null,Object? current = null,Object? layers = null,}) {
  return _then(_LibvirtSnapshot(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,parent: freezed == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String?,creationTime: freezed == creationTime ? _self.creationTime : creationTime // ignore: cast_nullable_to_non_nullable
as int?,memory: null == memory ? _self.memory : memory // ignore: cast_nullable_to_non_nullable
as bool,external: null == external ? _self.external : external // ignore: cast_nullable_to_non_nullable
as bool,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,layers: null == layers ? _self._layers : layers // ignore: cast_nullable_to_non_nullable
as List<LibvirtSnapLayer>,
  ));
}


}


/// @nodoc
mixin _$LibvirtSnapLayer {

 String get target; String? get file;/// `external`, `internal`, `no`.
 String? get snapshot;
/// Create a copy of LibvirtSnapLayer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtSnapLayerCopyWith<LibvirtSnapLayer> get copyWith => _$LibvirtSnapLayerCopyWithImpl<LibvirtSnapLayer>(this as LibvirtSnapLayer, _$identity);

  /// Serializes this LibvirtSnapLayer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtSnapLayer&&(identical(other.target, target) || other.target == target)&&(identical(other.file, file) || other.file == file)&&(identical(other.snapshot, snapshot) || other.snapshot == snapshot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,target,file,snapshot);

@override
String toString() {
  return 'LibvirtSnapLayer(target: $target, file: $file, snapshot: $snapshot)';
}


}

/// @nodoc
abstract mixin class $LibvirtSnapLayerCopyWith<$Res>  {
  factory $LibvirtSnapLayerCopyWith(LibvirtSnapLayer value, $Res Function(LibvirtSnapLayer) _then) = _$LibvirtSnapLayerCopyWithImpl;
@useResult
$Res call({
 String target, String? file, String? snapshot
});




}
/// @nodoc
class _$LibvirtSnapLayerCopyWithImpl<$Res>
    implements $LibvirtSnapLayerCopyWith<$Res> {
  _$LibvirtSnapLayerCopyWithImpl(this._self, this._then);

  final LibvirtSnapLayer _self;
  final $Res Function(LibvirtSnapLayer) _then;

/// Create a copy of LibvirtSnapLayer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? file = freezed,Object? snapshot = freezed,}) {
  return _then(_self.copyWith(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String?,snapshot: freezed == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtSnapLayer].
extension LibvirtSnapLayerPatterns on LibvirtSnapLayer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtSnapLayer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtSnapLayer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtSnapLayer value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtSnapLayer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtSnapLayer value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtSnapLayer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String target,  String? file,  String? snapshot)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtSnapLayer() when $default != null:
return $default(_that.target,_that.file,_that.snapshot);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String target,  String? file,  String? snapshot)  $default,) {final _that = this;
switch (_that) {
case _LibvirtSnapLayer():
return $default(_that.target,_that.file,_that.snapshot);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String target,  String? file,  String? snapshot)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtSnapLayer() when $default != null:
return $default(_that.target,_that.file,_that.snapshot);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtSnapLayer implements LibvirtSnapLayer {
  const _LibvirtSnapLayer({this.target = '', this.file, this.snapshot});
  factory _LibvirtSnapLayer.fromJson(Map<String, dynamic> json) => _$LibvirtSnapLayerFromJson(json);

@override@JsonKey() final  String target;
@override final  String? file;
/// `external`, `internal`, `no`.
@override final  String? snapshot;

/// Create a copy of LibvirtSnapLayer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtSnapLayerCopyWith<_LibvirtSnapLayer> get copyWith => __$LibvirtSnapLayerCopyWithImpl<_LibvirtSnapLayer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtSnapLayerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtSnapLayer&&(identical(other.target, target) || other.target == target)&&(identical(other.file, file) || other.file == file)&&(identical(other.snapshot, snapshot) || other.snapshot == snapshot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,target,file,snapshot);

@override
String toString() {
  return 'LibvirtSnapLayer(target: $target, file: $file, snapshot: $snapshot)';
}


}

/// @nodoc
abstract mixin class _$LibvirtSnapLayerCopyWith<$Res> implements $LibvirtSnapLayerCopyWith<$Res> {
  factory _$LibvirtSnapLayerCopyWith(_LibvirtSnapLayer value, $Res Function(_LibvirtSnapLayer) _then) = __$LibvirtSnapLayerCopyWithImpl;
@override @useResult
$Res call({
 String target, String? file, String? snapshot
});




}
/// @nodoc
class __$LibvirtSnapLayerCopyWithImpl<$Res>
    implements _$LibvirtSnapLayerCopyWith<$Res> {
  __$LibvirtSnapLayerCopyWithImpl(this._self, this._then);

  final _LibvirtSnapLayer _self;
  final $Res Function(_LibvirtSnapLayer) _then;

/// Create a copy of LibvirtSnapLayer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? file = freezed,Object? snapshot = freezed,}) {
  return _then(_LibvirtSnapLayer(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String?,snapshot: freezed == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LibvirtSnapDiff {

 String get group; String get key; String? get before; String? get after; bool get removed; bool get added;
/// Create a copy of LibvirtSnapDiff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtSnapDiffCopyWith<LibvirtSnapDiff> get copyWith => _$LibvirtSnapDiffCopyWithImpl<LibvirtSnapDiff>(this as LibvirtSnapDiff, _$identity);

  /// Serializes this LibvirtSnapDiff to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtSnapDiff&&(identical(other.group, group) || other.group == group)&&(identical(other.key, key) || other.key == key)&&(identical(other.before, before) || other.before == before)&&(identical(other.after, after) || other.after == after)&&(identical(other.removed, removed) || other.removed == removed)&&(identical(other.added, added) || other.added == added));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,group,key,before,after,removed,added);

@override
String toString() {
  return 'LibvirtSnapDiff(group: $group, key: $key, before: $before, after: $after, removed: $removed, added: $added)';
}


}

/// @nodoc
abstract mixin class $LibvirtSnapDiffCopyWith<$Res>  {
  factory $LibvirtSnapDiffCopyWith(LibvirtSnapDiff value, $Res Function(LibvirtSnapDiff) _then) = _$LibvirtSnapDiffCopyWithImpl;
@useResult
$Res call({
 String group, String key, String? before, String? after, bool removed, bool added
});




}
/// @nodoc
class _$LibvirtSnapDiffCopyWithImpl<$Res>
    implements $LibvirtSnapDiffCopyWith<$Res> {
  _$LibvirtSnapDiffCopyWithImpl(this._self, this._then);

  final LibvirtSnapDiff _self;
  final $Res Function(LibvirtSnapDiff) _then;

/// Create a copy of LibvirtSnapDiff
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? group = null,Object? key = null,Object? before = freezed,Object? after = freezed,Object? removed = null,Object? added = null,}) {
  return _then(_self.copyWith(
group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,before: freezed == before ? _self.before : before // ignore: cast_nullable_to_non_nullable
as String?,after: freezed == after ? _self.after : after // ignore: cast_nullable_to_non_nullable
as String?,removed: null == removed ? _self.removed : removed // ignore: cast_nullable_to_non_nullable
as bool,added: null == added ? _self.added : added // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtSnapDiff].
extension LibvirtSnapDiffPatterns on LibvirtSnapDiff {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtSnapDiff value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtSnapDiff() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtSnapDiff value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtSnapDiff():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtSnapDiff value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtSnapDiff() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String group,  String key,  String? before,  String? after,  bool removed,  bool added)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtSnapDiff() when $default != null:
return $default(_that.group,_that.key,_that.before,_that.after,_that.removed,_that.added);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String group,  String key,  String? before,  String? after,  bool removed,  bool added)  $default,) {final _that = this;
switch (_that) {
case _LibvirtSnapDiff():
return $default(_that.group,_that.key,_that.before,_that.after,_that.removed,_that.added);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String group,  String key,  String? before,  String? after,  bool removed,  bool added)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtSnapDiff() when $default != null:
return $default(_that.group,_that.key,_that.before,_that.after,_that.removed,_that.added);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtSnapDiff implements LibvirtSnapDiff {
  const _LibvirtSnapDiff({this.group = '', this.key = '', this.before, this.after, this.removed = false, this.added = false});
  factory _LibvirtSnapDiff.fromJson(Map<String, dynamic> json) => _$LibvirtSnapDiffFromJson(json);

@override@JsonKey() final  String group;
@override@JsonKey() final  String key;
@override final  String? before;
@override final  String? after;
@override@JsonKey() final  bool removed;
@override@JsonKey() final  bool added;

/// Create a copy of LibvirtSnapDiff
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtSnapDiffCopyWith<_LibvirtSnapDiff> get copyWith => __$LibvirtSnapDiffCopyWithImpl<_LibvirtSnapDiff>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtSnapDiffToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtSnapDiff&&(identical(other.group, group) || other.group == group)&&(identical(other.key, key) || other.key == key)&&(identical(other.before, before) || other.before == before)&&(identical(other.after, after) || other.after == after)&&(identical(other.removed, removed) || other.removed == removed)&&(identical(other.added, added) || other.added == added));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,group,key,before,after,removed,added);

@override
String toString() {
  return 'LibvirtSnapDiff(group: $group, key: $key, before: $before, after: $after, removed: $removed, added: $added)';
}


}

/// @nodoc
abstract mixin class _$LibvirtSnapDiffCopyWith<$Res> implements $LibvirtSnapDiffCopyWith<$Res> {
  factory _$LibvirtSnapDiffCopyWith(_LibvirtSnapDiff value, $Res Function(_LibvirtSnapDiff) _then) = __$LibvirtSnapDiffCopyWithImpl;
@override @useResult
$Res call({
 String group, String key, String? before, String? after, bool removed, bool added
});




}
/// @nodoc
class __$LibvirtSnapDiffCopyWithImpl<$Res>
    implements _$LibvirtSnapDiffCopyWith<$Res> {
  __$LibvirtSnapDiffCopyWithImpl(this._self, this._then);

  final _LibvirtSnapDiff _self;
  final $Res Function(_LibvirtSnapDiff) _then;

/// Create a copy of LibvirtSnapDiff
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? group = null,Object? key = null,Object? before = freezed,Object? after = freezed,Object? removed = null,Object? added = null,}) {
  return _then(_LibvirtSnapDiff(
group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,before: freezed == before ? _self.before : before // ignore: cast_nullable_to_non_nullable
as String?,after: freezed == after ? _self.after : after // ignore: cast_nullable_to_non_nullable
as String?,removed: null == removed ? _self.removed : removed // ignore: cast_nullable_to_non_nullable
as bool,added: null == added ? _self.added : added // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$LibvirtSnapChain {

 List<LibvirtSnapChainDisk> get disks;
/// Create a copy of LibvirtSnapChain
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtSnapChainCopyWith<LibvirtSnapChain> get copyWith => _$LibvirtSnapChainCopyWithImpl<LibvirtSnapChain>(this as LibvirtSnapChain, _$identity);

  /// Serializes this LibvirtSnapChain to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtSnapChain&&const DeepCollectionEquality().equals(other.disks, disks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(disks));

@override
String toString() {
  return 'LibvirtSnapChain(disks: $disks)';
}


}

/// @nodoc
abstract mixin class $LibvirtSnapChainCopyWith<$Res>  {
  factory $LibvirtSnapChainCopyWith(LibvirtSnapChain value, $Res Function(LibvirtSnapChain) _then) = _$LibvirtSnapChainCopyWithImpl;
@useResult
$Res call({
 List<LibvirtSnapChainDisk> disks
});




}
/// @nodoc
class _$LibvirtSnapChainCopyWithImpl<$Res>
    implements $LibvirtSnapChainCopyWith<$Res> {
  _$LibvirtSnapChainCopyWithImpl(this._self, this._then);

  final LibvirtSnapChain _self;
  final $Res Function(LibvirtSnapChain) _then;

/// Create a copy of LibvirtSnapChain
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? disks = null,}) {
  return _then(_self.copyWith(
disks: null == disks ? _self.disks : disks // ignore: cast_nullable_to_non_nullable
as List<LibvirtSnapChainDisk>,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtSnapChain].
extension LibvirtSnapChainPatterns on LibvirtSnapChain {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtSnapChain value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtSnapChain() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtSnapChain value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtSnapChain():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtSnapChain value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtSnapChain() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<LibvirtSnapChainDisk> disks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtSnapChain() when $default != null:
return $default(_that.disks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<LibvirtSnapChainDisk> disks)  $default,) {final _that = this;
switch (_that) {
case _LibvirtSnapChain():
return $default(_that.disks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<LibvirtSnapChainDisk> disks)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtSnapChain() when $default != null:
return $default(_that.disks);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtSnapChain implements LibvirtSnapChain {
  const _LibvirtSnapChain({final  List<LibvirtSnapChainDisk> disks = const <LibvirtSnapChainDisk>[]}): _disks = disks;
  factory _LibvirtSnapChain.fromJson(Map<String, dynamic> json) => _$LibvirtSnapChainFromJson(json);

 final  List<LibvirtSnapChainDisk> _disks;
@override@JsonKey() List<LibvirtSnapChainDisk> get disks {
  if (_disks is EqualUnmodifiableListView) return _disks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_disks);
}


/// Create a copy of LibvirtSnapChain
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtSnapChainCopyWith<_LibvirtSnapChain> get copyWith => __$LibvirtSnapChainCopyWithImpl<_LibvirtSnapChain>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtSnapChainToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtSnapChain&&const DeepCollectionEquality().equals(other._disks, _disks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_disks));

@override
String toString() {
  return 'LibvirtSnapChain(disks: $disks)';
}


}

/// @nodoc
abstract mixin class _$LibvirtSnapChainCopyWith<$Res> implements $LibvirtSnapChainCopyWith<$Res> {
  factory _$LibvirtSnapChainCopyWith(_LibvirtSnapChain value, $Res Function(_LibvirtSnapChain) _then) = __$LibvirtSnapChainCopyWithImpl;
@override @useResult
$Res call({
 List<LibvirtSnapChainDisk> disks
});




}
/// @nodoc
class __$LibvirtSnapChainCopyWithImpl<$Res>
    implements _$LibvirtSnapChainCopyWith<$Res> {
  __$LibvirtSnapChainCopyWithImpl(this._self, this._then);

  final _LibvirtSnapChain _self;
  final $Res Function(_LibvirtSnapChain) _then;

/// Create a copy of LibvirtSnapChain
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? disks = null,}) {
  return _then(_LibvirtSnapChain(
disks: null == disks ? _self._disks : disks // ignore: cast_nullable_to_non_nullable
as List<LibvirtSnapChainDisk>,
  ));
}


}


/// @nodoc
mixin _$LibvirtSnapChainDisk {

 String get target;/// Topmost first: the file the guest writes to now, then its backing
/// store, down to the base image.
 List<LibvirtSnapChainFile> get files;/// Why `qemu-img` could not read the disk, in its words.
 String? get error;
/// Create a copy of LibvirtSnapChainDisk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtSnapChainDiskCopyWith<LibvirtSnapChainDisk> get copyWith => _$LibvirtSnapChainDiskCopyWithImpl<LibvirtSnapChainDisk>(this as LibvirtSnapChainDisk, _$identity);

  /// Serializes this LibvirtSnapChainDisk to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtSnapChainDisk&&(identical(other.target, target) || other.target == target)&&const DeepCollectionEquality().equals(other.files, files)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,target,const DeepCollectionEquality().hash(files),error);

@override
String toString() {
  return 'LibvirtSnapChainDisk(target: $target, files: $files, error: $error)';
}


}

/// @nodoc
abstract mixin class $LibvirtSnapChainDiskCopyWith<$Res>  {
  factory $LibvirtSnapChainDiskCopyWith(LibvirtSnapChainDisk value, $Res Function(LibvirtSnapChainDisk) _then) = _$LibvirtSnapChainDiskCopyWithImpl;
@useResult
$Res call({
 String target, List<LibvirtSnapChainFile> files, String? error
});




}
/// @nodoc
class _$LibvirtSnapChainDiskCopyWithImpl<$Res>
    implements $LibvirtSnapChainDiskCopyWith<$Res> {
  _$LibvirtSnapChainDiskCopyWithImpl(this._self, this._then);

  final LibvirtSnapChainDisk _self;
  final $Res Function(LibvirtSnapChainDisk) _then;

/// Create a copy of LibvirtSnapChainDisk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? files = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,files: null == files ? _self.files : files // ignore: cast_nullable_to_non_nullable
as List<LibvirtSnapChainFile>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtSnapChainDisk].
extension LibvirtSnapChainDiskPatterns on LibvirtSnapChainDisk {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtSnapChainDisk value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtSnapChainDisk() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtSnapChainDisk value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtSnapChainDisk():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtSnapChainDisk value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtSnapChainDisk() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String target,  List<LibvirtSnapChainFile> files,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtSnapChainDisk() when $default != null:
return $default(_that.target,_that.files,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String target,  List<LibvirtSnapChainFile> files,  String? error)  $default,) {final _that = this;
switch (_that) {
case _LibvirtSnapChainDisk():
return $default(_that.target,_that.files,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String target,  List<LibvirtSnapChainFile> files,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtSnapChainDisk() when $default != null:
return $default(_that.target,_that.files,_that.error);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtSnapChainDisk implements LibvirtSnapChainDisk {
  const _LibvirtSnapChainDisk({this.target = '', final  List<LibvirtSnapChainFile> files = const <LibvirtSnapChainFile>[], this.error}): _files = files;
  factory _LibvirtSnapChainDisk.fromJson(Map<String, dynamic> json) => _$LibvirtSnapChainDiskFromJson(json);

@override@JsonKey() final  String target;
/// Topmost first: the file the guest writes to now, then its backing
/// store, down to the base image.
 final  List<LibvirtSnapChainFile> _files;
/// Topmost first: the file the guest writes to now, then its backing
/// store, down to the base image.
@override@JsonKey() List<LibvirtSnapChainFile> get files {
  if (_files is EqualUnmodifiableListView) return _files;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_files);
}

/// Why `qemu-img` could not read the disk, in its words.
@override final  String? error;

/// Create a copy of LibvirtSnapChainDisk
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtSnapChainDiskCopyWith<_LibvirtSnapChainDisk> get copyWith => __$LibvirtSnapChainDiskCopyWithImpl<_LibvirtSnapChainDisk>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtSnapChainDiskToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtSnapChainDisk&&(identical(other.target, target) || other.target == target)&&const DeepCollectionEquality().equals(other._files, _files)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,target,const DeepCollectionEquality().hash(_files),error);

@override
String toString() {
  return 'LibvirtSnapChainDisk(target: $target, files: $files, error: $error)';
}


}

/// @nodoc
abstract mixin class _$LibvirtSnapChainDiskCopyWith<$Res> implements $LibvirtSnapChainDiskCopyWith<$Res> {
  factory _$LibvirtSnapChainDiskCopyWith(_LibvirtSnapChainDisk value, $Res Function(_LibvirtSnapChainDisk) _then) = __$LibvirtSnapChainDiskCopyWithImpl;
@override @useResult
$Res call({
 String target, List<LibvirtSnapChainFile> files, String? error
});




}
/// @nodoc
class __$LibvirtSnapChainDiskCopyWithImpl<$Res>
    implements _$LibvirtSnapChainDiskCopyWith<$Res> {
  __$LibvirtSnapChainDiskCopyWithImpl(this._self, this._then);

  final _LibvirtSnapChainDisk _self;
  final $Res Function(_LibvirtSnapChainDisk) _then;

/// Create a copy of LibvirtSnapChainDisk
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? files = null,Object? error = freezed,}) {
  return _then(_LibvirtSnapChainDisk(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,files: null == files ? _self._files : files // ignore: cast_nullable_to_non_nullable
as List<LibvirtSnapChainFile>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LibvirtSnapChainFile {

 String get path; String? get format; String? get backing; int? get allocation; int? get capacity;
/// Create a copy of LibvirtSnapChainFile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtSnapChainFileCopyWith<LibvirtSnapChainFile> get copyWith => _$LibvirtSnapChainFileCopyWithImpl<LibvirtSnapChainFile>(this as LibvirtSnapChainFile, _$identity);

  /// Serializes this LibvirtSnapChainFile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtSnapChainFile&&(identical(other.path, path) || other.path == path)&&(identical(other.format, format) || other.format == format)&&(identical(other.backing, backing) || other.backing == backing)&&(identical(other.allocation, allocation) || other.allocation == allocation)&&(identical(other.capacity, capacity) || other.capacity == capacity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,format,backing,allocation,capacity);

@override
String toString() {
  return 'LibvirtSnapChainFile(path: $path, format: $format, backing: $backing, allocation: $allocation, capacity: $capacity)';
}


}

/// @nodoc
abstract mixin class $LibvirtSnapChainFileCopyWith<$Res>  {
  factory $LibvirtSnapChainFileCopyWith(LibvirtSnapChainFile value, $Res Function(LibvirtSnapChainFile) _then) = _$LibvirtSnapChainFileCopyWithImpl;
@useResult
$Res call({
 String path, String? format, String? backing, int? allocation, int? capacity
});




}
/// @nodoc
class _$LibvirtSnapChainFileCopyWithImpl<$Res>
    implements $LibvirtSnapChainFileCopyWith<$Res> {
  _$LibvirtSnapChainFileCopyWithImpl(this._self, this._then);

  final LibvirtSnapChainFile _self;
  final $Res Function(LibvirtSnapChainFile) _then;

/// Create a copy of LibvirtSnapChainFile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? format = freezed,Object? backing = freezed,Object? allocation = freezed,Object? capacity = freezed,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,backing: freezed == backing ? _self.backing : backing // ignore: cast_nullable_to_non_nullable
as String?,allocation: freezed == allocation ? _self.allocation : allocation // ignore: cast_nullable_to_non_nullable
as int?,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtSnapChainFile].
extension LibvirtSnapChainFilePatterns on LibvirtSnapChainFile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtSnapChainFile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtSnapChainFile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtSnapChainFile value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtSnapChainFile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtSnapChainFile value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtSnapChainFile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  String? format,  String? backing,  int? allocation,  int? capacity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtSnapChainFile() when $default != null:
return $default(_that.path,_that.format,_that.backing,_that.allocation,_that.capacity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  String? format,  String? backing,  int? allocation,  int? capacity)  $default,) {final _that = this;
switch (_that) {
case _LibvirtSnapChainFile():
return $default(_that.path,_that.format,_that.backing,_that.allocation,_that.capacity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  String? format,  String? backing,  int? allocation,  int? capacity)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtSnapChainFile() when $default != null:
return $default(_that.path,_that.format,_that.backing,_that.allocation,_that.capacity);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtSnapChainFile implements LibvirtSnapChainFile {
  const _LibvirtSnapChainFile({required this.path, this.format, this.backing, this.allocation, this.capacity});
  factory _LibvirtSnapChainFile.fromJson(Map<String, dynamic> json) => _$LibvirtSnapChainFileFromJson(json);

@override final  String path;
@override final  String? format;
@override final  String? backing;
@override final  int? allocation;
@override final  int? capacity;

/// Create a copy of LibvirtSnapChainFile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtSnapChainFileCopyWith<_LibvirtSnapChainFile> get copyWith => __$LibvirtSnapChainFileCopyWithImpl<_LibvirtSnapChainFile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtSnapChainFileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtSnapChainFile&&(identical(other.path, path) || other.path == path)&&(identical(other.format, format) || other.format == format)&&(identical(other.backing, backing) || other.backing == backing)&&(identical(other.allocation, allocation) || other.allocation == allocation)&&(identical(other.capacity, capacity) || other.capacity == capacity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,format,backing,allocation,capacity);

@override
String toString() {
  return 'LibvirtSnapChainFile(path: $path, format: $format, backing: $backing, allocation: $allocation, capacity: $capacity)';
}


}

/// @nodoc
abstract mixin class _$LibvirtSnapChainFileCopyWith<$Res> implements $LibvirtSnapChainFileCopyWith<$Res> {
  factory _$LibvirtSnapChainFileCopyWith(_LibvirtSnapChainFile value, $Res Function(_LibvirtSnapChainFile) _then) = __$LibvirtSnapChainFileCopyWithImpl;
@override @useResult
$Res call({
 String path, String? format, String? backing, int? allocation, int? capacity
});




}
/// @nodoc
class __$LibvirtSnapChainFileCopyWithImpl<$Res>
    implements _$LibvirtSnapChainFileCopyWith<$Res> {
  __$LibvirtSnapChainFileCopyWithImpl(this._self, this._then);

  final _LibvirtSnapChainFile _self;
  final $Res Function(_LibvirtSnapChainFile) _then;

/// Create a copy of LibvirtSnapChainFile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? format = freezed,Object? backing = freezed,Object? allocation = freezed,Object? capacity = freezed,}) {
  return _then(_LibvirtSnapChainFile(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,backing: freezed == backing ? _self.backing : backing // ignore: cast_nullable_to_non_nullable
as String?,allocation: freezed == allocation ? _self.allocation : allocation // ignore: cast_nullable_to_non_nullable
as int?,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,
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
mixin _$LibvirtHwCpu {

 int get sockets; int get dies; int get clusters; int get cores; int get threads; int get max; int get current; bool get topology;
/// Create a copy of LibvirtHwCpu
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtHwCpuCopyWith<LibvirtHwCpu> get copyWith => _$LibvirtHwCpuCopyWithImpl<LibvirtHwCpu>(this as LibvirtHwCpu, _$identity);

  /// Serializes this LibvirtHwCpu to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtHwCpu&&(identical(other.sockets, sockets) || other.sockets == sockets)&&(identical(other.dies, dies) || other.dies == dies)&&(identical(other.clusters, clusters) || other.clusters == clusters)&&(identical(other.cores, cores) || other.cores == cores)&&(identical(other.threads, threads) || other.threads == threads)&&(identical(other.max, max) || other.max == max)&&(identical(other.current, current) || other.current == current)&&(identical(other.topology, topology) || other.topology == topology));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sockets,dies,clusters,cores,threads,max,current,topology);

@override
String toString() {
  return 'LibvirtHwCpu(sockets: $sockets, dies: $dies, clusters: $clusters, cores: $cores, threads: $threads, max: $max, current: $current, topology: $topology)';
}


}

/// @nodoc
abstract mixin class $LibvirtHwCpuCopyWith<$Res>  {
  factory $LibvirtHwCpuCopyWith(LibvirtHwCpu value, $Res Function(LibvirtHwCpu) _then) = _$LibvirtHwCpuCopyWithImpl;
@useResult
$Res call({
 int sockets, int dies, int clusters, int cores, int threads, int max, int current, bool topology
});




}
/// @nodoc
class _$LibvirtHwCpuCopyWithImpl<$Res>
    implements $LibvirtHwCpuCopyWith<$Res> {
  _$LibvirtHwCpuCopyWithImpl(this._self, this._then);

  final LibvirtHwCpu _self;
  final $Res Function(LibvirtHwCpu) _then;

/// Create a copy of LibvirtHwCpu
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sockets = null,Object? dies = null,Object? clusters = null,Object? cores = null,Object? threads = null,Object? max = null,Object? current = null,Object? topology = null,}) {
  return _then(_self.copyWith(
sockets: null == sockets ? _self.sockets : sockets // ignore: cast_nullable_to_non_nullable
as int,dies: null == dies ? _self.dies : dies // ignore: cast_nullable_to_non_nullable
as int,clusters: null == clusters ? _self.clusters : clusters // ignore: cast_nullable_to_non_nullable
as int,cores: null == cores ? _self.cores : cores // ignore: cast_nullable_to_non_nullable
as int,threads: null == threads ? _self.threads : threads // ignore: cast_nullable_to_non_nullable
as int,max: null == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as int,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as int,topology: null == topology ? _self.topology : topology // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtHwCpu].
extension LibvirtHwCpuPatterns on LibvirtHwCpu {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtHwCpu value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtHwCpu() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtHwCpu value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtHwCpu():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtHwCpu value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtHwCpu() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int sockets,  int dies,  int clusters,  int cores,  int threads,  int max,  int current,  bool topology)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtHwCpu() when $default != null:
return $default(_that.sockets,_that.dies,_that.clusters,_that.cores,_that.threads,_that.max,_that.current,_that.topology);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int sockets,  int dies,  int clusters,  int cores,  int threads,  int max,  int current,  bool topology)  $default,) {final _that = this;
switch (_that) {
case _LibvirtHwCpu():
return $default(_that.sockets,_that.dies,_that.clusters,_that.cores,_that.threads,_that.max,_that.current,_that.topology);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int sockets,  int dies,  int clusters,  int cores,  int threads,  int max,  int current,  bool topology)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtHwCpu() when $default != null:
return $default(_that.sockets,_that.dies,_that.clusters,_that.cores,_that.threads,_that.max,_that.current,_that.topology);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtHwCpu implements LibvirtHwCpu {
  const _LibvirtHwCpu({required this.sockets, this.dies = 1, this.clusters = 1, required this.cores, this.threads = 1, required this.max, required this.current, this.topology = false});
  factory _LibvirtHwCpu.fromJson(Map<String, dynamic> json) => _$LibvirtHwCpuFromJson(json);

@override final  int sockets;
@override@JsonKey() final  int dies;
@override@JsonKey() final  int clusters;
@override final  int cores;
@override@JsonKey() final  int threads;
@override final  int max;
@override final  int current;
@override@JsonKey() final  bool topology;

/// Create a copy of LibvirtHwCpu
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtHwCpuCopyWith<_LibvirtHwCpu> get copyWith => __$LibvirtHwCpuCopyWithImpl<_LibvirtHwCpu>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtHwCpuToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtHwCpu&&(identical(other.sockets, sockets) || other.sockets == sockets)&&(identical(other.dies, dies) || other.dies == dies)&&(identical(other.clusters, clusters) || other.clusters == clusters)&&(identical(other.cores, cores) || other.cores == cores)&&(identical(other.threads, threads) || other.threads == threads)&&(identical(other.max, max) || other.max == max)&&(identical(other.current, current) || other.current == current)&&(identical(other.topology, topology) || other.topology == topology));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sockets,dies,clusters,cores,threads,max,current,topology);

@override
String toString() {
  return 'LibvirtHwCpu(sockets: $sockets, dies: $dies, clusters: $clusters, cores: $cores, threads: $threads, max: $max, current: $current, topology: $topology)';
}


}

/// @nodoc
abstract mixin class _$LibvirtHwCpuCopyWith<$Res> implements $LibvirtHwCpuCopyWith<$Res> {
  factory _$LibvirtHwCpuCopyWith(_LibvirtHwCpu value, $Res Function(_LibvirtHwCpu) _then) = __$LibvirtHwCpuCopyWithImpl;
@override @useResult
$Res call({
 int sockets, int dies, int clusters, int cores, int threads, int max, int current, bool topology
});




}
/// @nodoc
class __$LibvirtHwCpuCopyWithImpl<$Res>
    implements _$LibvirtHwCpuCopyWith<$Res> {
  __$LibvirtHwCpuCopyWithImpl(this._self, this._then);

  final _LibvirtHwCpu _self;
  final $Res Function(_LibvirtHwCpu) _then;

/// Create a copy of LibvirtHwCpu
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sockets = null,Object? dies = null,Object? clusters = null,Object? cores = null,Object? threads = null,Object? max = null,Object? current = null,Object? topology = null,}) {
  return _then(_LibvirtHwCpu(
sockets: null == sockets ? _self.sockets : sockets // ignore: cast_nullable_to_non_nullable
as int,dies: null == dies ? _self.dies : dies // ignore: cast_nullable_to_non_nullable
as int,clusters: null == clusters ? _self.clusters : clusters // ignore: cast_nullable_to_non_nullable
as int,cores: null == cores ? _self.cores : cores // ignore: cast_nullable_to_non_nullable
as int,threads: null == threads ? _self.threads : threads // ignore: cast_nullable_to_non_nullable
as int,max: null == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as int,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as int,topology: null == topology ? _self.topology : topology // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$LibvirtHwDisk {

 String get target; String get device; String? get bus; String? get sourceType; String? get source; String? get format; bool get readonly; int? get capacity; int? get bootOrder; String? get cache;
/// Create a copy of LibvirtHwDisk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtHwDiskCopyWith<LibvirtHwDisk> get copyWith => _$LibvirtHwDiskCopyWithImpl<LibvirtHwDisk>(this as LibvirtHwDisk, _$identity);

  /// Serializes this LibvirtHwDisk to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtHwDisk&&(identical(other.target, target) || other.target == target)&&(identical(other.device, device) || other.device == device)&&(identical(other.bus, bus) || other.bus == bus)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.source, source) || other.source == source)&&(identical(other.format, format) || other.format == format)&&(identical(other.readonly, readonly) || other.readonly == readonly)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.bootOrder, bootOrder) || other.bootOrder == bootOrder)&&(identical(other.cache, cache) || other.cache == cache));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,target,device,bus,sourceType,source,format,readonly,capacity,bootOrder,cache);

@override
String toString() {
  return 'LibvirtHwDisk(target: $target, device: $device, bus: $bus, sourceType: $sourceType, source: $source, format: $format, readonly: $readonly, capacity: $capacity, bootOrder: $bootOrder, cache: $cache)';
}


}

/// @nodoc
abstract mixin class $LibvirtHwDiskCopyWith<$Res>  {
  factory $LibvirtHwDiskCopyWith(LibvirtHwDisk value, $Res Function(LibvirtHwDisk) _then) = _$LibvirtHwDiskCopyWithImpl;
@useResult
$Res call({
 String target, String device, String? bus, String? sourceType, String? source, String? format, bool readonly, int? capacity, int? bootOrder, String? cache
});




}
/// @nodoc
class _$LibvirtHwDiskCopyWithImpl<$Res>
    implements $LibvirtHwDiskCopyWith<$Res> {
  _$LibvirtHwDiskCopyWithImpl(this._self, this._then);

  final LibvirtHwDisk _self;
  final $Res Function(LibvirtHwDisk) _then;

/// Create a copy of LibvirtHwDisk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? device = null,Object? bus = freezed,Object? sourceType = freezed,Object? source = freezed,Object? format = freezed,Object? readonly = null,Object? capacity = freezed,Object? bootOrder = freezed,Object? cache = freezed,}) {
  return _then(_self.copyWith(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,bus: freezed == bus ? _self.bus : bus // ignore: cast_nullable_to_non_nullable
as String?,sourceType: freezed == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,readonly: null == readonly ? _self.readonly : readonly // ignore: cast_nullable_to_non_nullable
as bool,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,bootOrder: freezed == bootOrder ? _self.bootOrder : bootOrder // ignore: cast_nullable_to_non_nullable
as int?,cache: freezed == cache ? _self.cache : cache // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtHwDisk].
extension LibvirtHwDiskPatterns on LibvirtHwDisk {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtHwDisk value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtHwDisk() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtHwDisk value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtHwDisk():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtHwDisk value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtHwDisk() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String target,  String device,  String? bus,  String? sourceType,  String? source,  String? format,  bool readonly,  int? capacity,  int? bootOrder,  String? cache)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtHwDisk() when $default != null:
return $default(_that.target,_that.device,_that.bus,_that.sourceType,_that.source,_that.format,_that.readonly,_that.capacity,_that.bootOrder,_that.cache);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String target,  String device,  String? bus,  String? sourceType,  String? source,  String? format,  bool readonly,  int? capacity,  int? bootOrder,  String? cache)  $default,) {final _that = this;
switch (_that) {
case _LibvirtHwDisk():
return $default(_that.target,_that.device,_that.bus,_that.sourceType,_that.source,_that.format,_that.readonly,_that.capacity,_that.bootOrder,_that.cache);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String target,  String device,  String? bus,  String? sourceType,  String? source,  String? format,  bool readonly,  int? capacity,  int? bootOrder,  String? cache)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtHwDisk() when $default != null:
return $default(_that.target,_that.device,_that.bus,_that.sourceType,_that.source,_that.format,_that.readonly,_that.capacity,_that.bootOrder,_that.cache);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtHwDisk implements LibvirtHwDisk {
  const _LibvirtHwDisk({required this.target, this.device = 'disk', this.bus, this.sourceType, this.source, this.format, this.readonly = false, this.capacity, this.bootOrder, this.cache});
  factory _LibvirtHwDisk.fromJson(Map<String, dynamic> json) => _$LibvirtHwDiskFromJson(json);

@override final  String target;
@override@JsonKey() final  String device;
@override final  String? bus;
@override final  String? sourceType;
@override final  String? source;
@override final  String? format;
@override@JsonKey() final  bool readonly;
@override final  int? capacity;
@override final  int? bootOrder;
@override final  String? cache;

/// Create a copy of LibvirtHwDisk
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtHwDiskCopyWith<_LibvirtHwDisk> get copyWith => __$LibvirtHwDiskCopyWithImpl<_LibvirtHwDisk>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtHwDiskToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtHwDisk&&(identical(other.target, target) || other.target == target)&&(identical(other.device, device) || other.device == device)&&(identical(other.bus, bus) || other.bus == bus)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.source, source) || other.source == source)&&(identical(other.format, format) || other.format == format)&&(identical(other.readonly, readonly) || other.readonly == readonly)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.bootOrder, bootOrder) || other.bootOrder == bootOrder)&&(identical(other.cache, cache) || other.cache == cache));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,target,device,bus,sourceType,source,format,readonly,capacity,bootOrder,cache);

@override
String toString() {
  return 'LibvirtHwDisk(target: $target, device: $device, bus: $bus, sourceType: $sourceType, source: $source, format: $format, readonly: $readonly, capacity: $capacity, bootOrder: $bootOrder, cache: $cache)';
}


}

/// @nodoc
abstract mixin class _$LibvirtHwDiskCopyWith<$Res> implements $LibvirtHwDiskCopyWith<$Res> {
  factory _$LibvirtHwDiskCopyWith(_LibvirtHwDisk value, $Res Function(_LibvirtHwDisk) _then) = __$LibvirtHwDiskCopyWithImpl;
@override @useResult
$Res call({
 String target, String device, String? bus, String? sourceType, String? source, String? format, bool readonly, int? capacity, int? bootOrder, String? cache
});




}
/// @nodoc
class __$LibvirtHwDiskCopyWithImpl<$Res>
    implements _$LibvirtHwDiskCopyWith<$Res> {
  __$LibvirtHwDiskCopyWithImpl(this._self, this._then);

  final _LibvirtHwDisk _self;
  final $Res Function(_LibvirtHwDisk) _then;

/// Create a copy of LibvirtHwDisk
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? device = null,Object? bus = freezed,Object? sourceType = freezed,Object? source = freezed,Object? format = freezed,Object? readonly = null,Object? capacity = freezed,Object? bootOrder = freezed,Object? cache = freezed,}) {
  return _then(_LibvirtHwDisk(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,bus: freezed == bus ? _self.bus : bus // ignore: cast_nullable_to_non_nullable
as String?,sourceType: freezed == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,readonly: null == readonly ? _self.readonly : readonly // ignore: cast_nullable_to_non_nullable
as bool,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,bootOrder: freezed == bootOrder ? _self.bootOrder : bootOrder // ignore: cast_nullable_to_non_nullable
as int?,cache: freezed == cache ? _self.cache : cache // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LibvirtHwNic {

 String get mac; String get kind; String? get source; String? get model; bool get linkUp; int? get bootOrder;
/// Create a copy of LibvirtHwNic
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtHwNicCopyWith<LibvirtHwNic> get copyWith => _$LibvirtHwNicCopyWithImpl<LibvirtHwNic>(this as LibvirtHwNic, _$identity);

  /// Serializes this LibvirtHwNic to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtHwNic&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.source, source) || other.source == source)&&(identical(other.model, model) || other.model == model)&&(identical(other.linkUp, linkUp) || other.linkUp == linkUp)&&(identical(other.bootOrder, bootOrder) || other.bootOrder == bootOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mac,kind,source,model,linkUp,bootOrder);

@override
String toString() {
  return 'LibvirtHwNic(mac: $mac, kind: $kind, source: $source, model: $model, linkUp: $linkUp, bootOrder: $bootOrder)';
}


}

/// @nodoc
abstract mixin class $LibvirtHwNicCopyWith<$Res>  {
  factory $LibvirtHwNicCopyWith(LibvirtHwNic value, $Res Function(LibvirtHwNic) _then) = _$LibvirtHwNicCopyWithImpl;
@useResult
$Res call({
 String mac, String kind, String? source, String? model, bool linkUp, int? bootOrder
});




}
/// @nodoc
class _$LibvirtHwNicCopyWithImpl<$Res>
    implements $LibvirtHwNicCopyWith<$Res> {
  _$LibvirtHwNicCopyWithImpl(this._self, this._then);

  final LibvirtHwNic _self;
  final $Res Function(LibvirtHwNic) _then;

/// Create a copy of LibvirtHwNic
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mac = null,Object? kind = null,Object? source = freezed,Object? model = freezed,Object? linkUp = null,Object? bootOrder = freezed,}) {
  return _then(_self.copyWith(
mac: null == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,linkUp: null == linkUp ? _self.linkUp : linkUp // ignore: cast_nullable_to_non_nullable
as bool,bootOrder: freezed == bootOrder ? _self.bootOrder : bootOrder // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtHwNic].
extension LibvirtHwNicPatterns on LibvirtHwNic {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtHwNic value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtHwNic() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtHwNic value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtHwNic():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtHwNic value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtHwNic() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String mac,  String kind,  String? source,  String? model,  bool linkUp,  int? bootOrder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtHwNic() when $default != null:
return $default(_that.mac,_that.kind,_that.source,_that.model,_that.linkUp,_that.bootOrder);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String mac,  String kind,  String? source,  String? model,  bool linkUp,  int? bootOrder)  $default,) {final _that = this;
switch (_that) {
case _LibvirtHwNic():
return $default(_that.mac,_that.kind,_that.source,_that.model,_that.linkUp,_that.bootOrder);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String mac,  String kind,  String? source,  String? model,  bool linkUp,  int? bootOrder)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtHwNic() when $default != null:
return $default(_that.mac,_that.kind,_that.source,_that.model,_that.linkUp,_that.bootOrder);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtHwNic implements LibvirtHwNic {
  const _LibvirtHwNic({required this.mac, this.kind = '', this.source, this.model, this.linkUp = true, this.bootOrder});
  factory _LibvirtHwNic.fromJson(Map<String, dynamic> json) => _$LibvirtHwNicFromJson(json);

@override final  String mac;
@override@JsonKey() final  String kind;
@override final  String? source;
@override final  String? model;
@override@JsonKey() final  bool linkUp;
@override final  int? bootOrder;

/// Create a copy of LibvirtHwNic
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtHwNicCopyWith<_LibvirtHwNic> get copyWith => __$LibvirtHwNicCopyWithImpl<_LibvirtHwNic>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtHwNicToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtHwNic&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.source, source) || other.source == source)&&(identical(other.model, model) || other.model == model)&&(identical(other.linkUp, linkUp) || other.linkUp == linkUp)&&(identical(other.bootOrder, bootOrder) || other.bootOrder == bootOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mac,kind,source,model,linkUp,bootOrder);

@override
String toString() {
  return 'LibvirtHwNic(mac: $mac, kind: $kind, source: $source, model: $model, linkUp: $linkUp, bootOrder: $bootOrder)';
}


}

/// @nodoc
abstract mixin class _$LibvirtHwNicCopyWith<$Res> implements $LibvirtHwNicCopyWith<$Res> {
  factory _$LibvirtHwNicCopyWith(_LibvirtHwNic value, $Res Function(_LibvirtHwNic) _then) = __$LibvirtHwNicCopyWithImpl;
@override @useResult
$Res call({
 String mac, String kind, String? source, String? model, bool linkUp, int? bootOrder
});




}
/// @nodoc
class __$LibvirtHwNicCopyWithImpl<$Res>
    implements _$LibvirtHwNicCopyWith<$Res> {
  __$LibvirtHwNicCopyWithImpl(this._self, this._then);

  final _LibvirtHwNic _self;
  final $Res Function(_LibvirtHwNic) _then;

/// Create a copy of LibvirtHwNic
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mac = null,Object? kind = null,Object? source = freezed,Object? model = freezed,Object? linkUp = null,Object? bootOrder = freezed,}) {
  return _then(_LibvirtHwNic(
mac: null == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,linkUp: null == linkUp ? _self.linkUp : linkUp // ignore: cast_nullable_to_non_nullable
as bool,bootOrder: freezed == bootOrder ? _self.bootOrder : bootOrder // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$LibvirtHwConfig {

 LibvirtHwCpu get cpu; int get memoryKib; int get currentMemoryKib; List<LibvirtHwDisk> get disks; List<LibvirtHwNic> get nics; List<String> get boot; bool get balloon; bool get efi; bool get secureBoot; String? get machine; LibvirtHwGraphics? get graphics; String? get video; LibvirtHwTpm? get tpm; List<LibvirtHwHostdev> get hostdevs;/// The domain's own cloud-init seed, as the app named it when it made
/// the domain.
 String? get seed;
/// Create a copy of LibvirtHwConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtHwConfigCopyWith<LibvirtHwConfig> get copyWith => _$LibvirtHwConfigCopyWithImpl<LibvirtHwConfig>(this as LibvirtHwConfig, _$identity);

  /// Serializes this LibvirtHwConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtHwConfig&&(identical(other.cpu, cpu) || other.cpu == cpu)&&(identical(other.memoryKib, memoryKib) || other.memoryKib == memoryKib)&&(identical(other.currentMemoryKib, currentMemoryKib) || other.currentMemoryKib == currentMemoryKib)&&const DeepCollectionEquality().equals(other.disks, disks)&&const DeepCollectionEquality().equals(other.nics, nics)&&const DeepCollectionEquality().equals(other.boot, boot)&&(identical(other.balloon, balloon) || other.balloon == balloon)&&(identical(other.efi, efi) || other.efi == efi)&&(identical(other.secureBoot, secureBoot) || other.secureBoot == secureBoot)&&(identical(other.machine, machine) || other.machine == machine)&&(identical(other.graphics, graphics) || other.graphics == graphics)&&(identical(other.video, video) || other.video == video)&&(identical(other.tpm, tpm) || other.tpm == tpm)&&const DeepCollectionEquality().equals(other.hostdevs, hostdevs)&&(identical(other.seed, seed) || other.seed == seed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cpu,memoryKib,currentMemoryKib,const DeepCollectionEquality().hash(disks),const DeepCollectionEquality().hash(nics),const DeepCollectionEquality().hash(boot),balloon,efi,secureBoot,machine,graphics,video,tpm,const DeepCollectionEquality().hash(hostdevs),seed);

@override
String toString() {
  return 'LibvirtHwConfig(cpu: $cpu, memoryKib: $memoryKib, currentMemoryKib: $currentMemoryKib, disks: $disks, nics: $nics, boot: $boot, balloon: $balloon, efi: $efi, secureBoot: $secureBoot, machine: $machine, graphics: $graphics, video: $video, tpm: $tpm, hostdevs: $hostdevs, seed: $seed)';
}


}

/// @nodoc
abstract mixin class $LibvirtHwConfigCopyWith<$Res>  {
  factory $LibvirtHwConfigCopyWith(LibvirtHwConfig value, $Res Function(LibvirtHwConfig) _then) = _$LibvirtHwConfigCopyWithImpl;
@useResult
$Res call({
 LibvirtHwCpu cpu, int memoryKib, int currentMemoryKib, List<LibvirtHwDisk> disks, List<LibvirtHwNic> nics, List<String> boot, bool balloon, bool efi, bool secureBoot, String? machine, LibvirtHwGraphics? graphics, String? video, LibvirtHwTpm? tpm, List<LibvirtHwHostdev> hostdevs, String? seed
});


$LibvirtHwCpuCopyWith<$Res> get cpu;$LibvirtHwGraphicsCopyWith<$Res>? get graphics;$LibvirtHwTpmCopyWith<$Res>? get tpm;

}
/// @nodoc
class _$LibvirtHwConfigCopyWithImpl<$Res>
    implements $LibvirtHwConfigCopyWith<$Res> {
  _$LibvirtHwConfigCopyWithImpl(this._self, this._then);

  final LibvirtHwConfig _self;
  final $Res Function(LibvirtHwConfig) _then;

/// Create a copy of LibvirtHwConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cpu = null,Object? memoryKib = null,Object? currentMemoryKib = null,Object? disks = null,Object? nics = null,Object? boot = null,Object? balloon = null,Object? efi = null,Object? secureBoot = null,Object? machine = freezed,Object? graphics = freezed,Object? video = freezed,Object? tpm = freezed,Object? hostdevs = null,Object? seed = freezed,}) {
  return _then(_self.copyWith(
cpu: null == cpu ? _self.cpu : cpu // ignore: cast_nullable_to_non_nullable
as LibvirtHwCpu,memoryKib: null == memoryKib ? _self.memoryKib : memoryKib // ignore: cast_nullable_to_non_nullable
as int,currentMemoryKib: null == currentMemoryKib ? _self.currentMemoryKib : currentMemoryKib // ignore: cast_nullable_to_non_nullable
as int,disks: null == disks ? _self.disks : disks // ignore: cast_nullable_to_non_nullable
as List<LibvirtHwDisk>,nics: null == nics ? _self.nics : nics // ignore: cast_nullable_to_non_nullable
as List<LibvirtHwNic>,boot: null == boot ? _self.boot : boot // ignore: cast_nullable_to_non_nullable
as List<String>,balloon: null == balloon ? _self.balloon : balloon // ignore: cast_nullable_to_non_nullable
as bool,efi: null == efi ? _self.efi : efi // ignore: cast_nullable_to_non_nullable
as bool,secureBoot: null == secureBoot ? _self.secureBoot : secureBoot // ignore: cast_nullable_to_non_nullable
as bool,machine: freezed == machine ? _self.machine : machine // ignore: cast_nullable_to_non_nullable
as String?,graphics: freezed == graphics ? _self.graphics : graphics // ignore: cast_nullable_to_non_nullable
as LibvirtHwGraphics?,video: freezed == video ? _self.video : video // ignore: cast_nullable_to_non_nullable
as String?,tpm: freezed == tpm ? _self.tpm : tpm // ignore: cast_nullable_to_non_nullable
as LibvirtHwTpm?,hostdevs: null == hostdevs ? _self.hostdevs : hostdevs // ignore: cast_nullable_to_non_nullable
as List<LibvirtHwHostdev>,seed: freezed == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of LibvirtHwConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtHwCpuCopyWith<$Res> get cpu {
  
  return $LibvirtHwCpuCopyWith<$Res>(_self.cpu, (value) {
    return _then(_self.copyWith(cpu: value));
  });
}/// Create a copy of LibvirtHwConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtHwGraphicsCopyWith<$Res>? get graphics {
    if (_self.graphics == null) {
    return null;
  }

  return $LibvirtHwGraphicsCopyWith<$Res>(_self.graphics!, (value) {
    return _then(_self.copyWith(graphics: value));
  });
}/// Create a copy of LibvirtHwConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtHwTpmCopyWith<$Res>? get tpm {
    if (_self.tpm == null) {
    return null;
  }

  return $LibvirtHwTpmCopyWith<$Res>(_self.tpm!, (value) {
    return _then(_self.copyWith(tpm: value));
  });
}
}


/// Adds pattern-matching-related methods to [LibvirtHwConfig].
extension LibvirtHwConfigPatterns on LibvirtHwConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtHwConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtHwConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtHwConfig value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtHwConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtHwConfig value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtHwConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LibvirtHwCpu cpu,  int memoryKib,  int currentMemoryKib,  List<LibvirtHwDisk> disks,  List<LibvirtHwNic> nics,  List<String> boot,  bool balloon,  bool efi,  bool secureBoot,  String? machine,  LibvirtHwGraphics? graphics,  String? video,  LibvirtHwTpm? tpm,  List<LibvirtHwHostdev> hostdevs,  String? seed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtHwConfig() when $default != null:
return $default(_that.cpu,_that.memoryKib,_that.currentMemoryKib,_that.disks,_that.nics,_that.boot,_that.balloon,_that.efi,_that.secureBoot,_that.machine,_that.graphics,_that.video,_that.tpm,_that.hostdevs,_that.seed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LibvirtHwCpu cpu,  int memoryKib,  int currentMemoryKib,  List<LibvirtHwDisk> disks,  List<LibvirtHwNic> nics,  List<String> boot,  bool balloon,  bool efi,  bool secureBoot,  String? machine,  LibvirtHwGraphics? graphics,  String? video,  LibvirtHwTpm? tpm,  List<LibvirtHwHostdev> hostdevs,  String? seed)  $default,) {final _that = this;
switch (_that) {
case _LibvirtHwConfig():
return $default(_that.cpu,_that.memoryKib,_that.currentMemoryKib,_that.disks,_that.nics,_that.boot,_that.balloon,_that.efi,_that.secureBoot,_that.machine,_that.graphics,_that.video,_that.tpm,_that.hostdevs,_that.seed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LibvirtHwCpu cpu,  int memoryKib,  int currentMemoryKib,  List<LibvirtHwDisk> disks,  List<LibvirtHwNic> nics,  List<String> boot,  bool balloon,  bool efi,  bool secureBoot,  String? machine,  LibvirtHwGraphics? graphics,  String? video,  LibvirtHwTpm? tpm,  List<LibvirtHwHostdev> hostdevs,  String? seed)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtHwConfig() when $default != null:
return $default(_that.cpu,_that.memoryKib,_that.currentMemoryKib,_that.disks,_that.nics,_that.boot,_that.balloon,_that.efi,_that.secureBoot,_that.machine,_that.graphics,_that.video,_that.tpm,_that.hostdevs,_that.seed);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtHwConfig implements LibvirtHwConfig {
  const _LibvirtHwConfig({required this.cpu, required this.memoryKib, required this.currentMemoryKib, final  List<LibvirtHwDisk> disks = const <LibvirtHwDisk>[], final  List<LibvirtHwNic> nics = const <LibvirtHwNic>[], final  List<String> boot = const <String>[], this.balloon = false, this.efi = false, this.secureBoot = false, this.machine, this.graphics, this.video, this.tpm, final  List<LibvirtHwHostdev> hostdevs = const <LibvirtHwHostdev>[], this.seed}): _disks = disks,_nics = nics,_boot = boot,_hostdevs = hostdevs;
  factory _LibvirtHwConfig.fromJson(Map<String, dynamic> json) => _$LibvirtHwConfigFromJson(json);

@override final  LibvirtHwCpu cpu;
@override final  int memoryKib;
@override final  int currentMemoryKib;
 final  List<LibvirtHwDisk> _disks;
@override@JsonKey() List<LibvirtHwDisk> get disks {
  if (_disks is EqualUnmodifiableListView) return _disks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_disks);
}

 final  List<LibvirtHwNic> _nics;
@override@JsonKey() List<LibvirtHwNic> get nics {
  if (_nics is EqualUnmodifiableListView) return _nics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nics);
}

 final  List<String> _boot;
@override@JsonKey() List<String> get boot {
  if (_boot is EqualUnmodifiableListView) return _boot;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_boot);
}

@override@JsonKey() final  bool balloon;
@override@JsonKey() final  bool efi;
@override@JsonKey() final  bool secureBoot;
@override final  String? machine;
@override final  LibvirtHwGraphics? graphics;
@override final  String? video;
@override final  LibvirtHwTpm? tpm;
 final  List<LibvirtHwHostdev> _hostdevs;
@override@JsonKey() List<LibvirtHwHostdev> get hostdevs {
  if (_hostdevs is EqualUnmodifiableListView) return _hostdevs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hostdevs);
}

/// The domain's own cloud-init seed, as the app named it when it made
/// the domain.
@override final  String? seed;

/// Create a copy of LibvirtHwConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtHwConfigCopyWith<_LibvirtHwConfig> get copyWith => __$LibvirtHwConfigCopyWithImpl<_LibvirtHwConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtHwConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtHwConfig&&(identical(other.cpu, cpu) || other.cpu == cpu)&&(identical(other.memoryKib, memoryKib) || other.memoryKib == memoryKib)&&(identical(other.currentMemoryKib, currentMemoryKib) || other.currentMemoryKib == currentMemoryKib)&&const DeepCollectionEquality().equals(other._disks, _disks)&&const DeepCollectionEquality().equals(other._nics, _nics)&&const DeepCollectionEquality().equals(other._boot, _boot)&&(identical(other.balloon, balloon) || other.balloon == balloon)&&(identical(other.efi, efi) || other.efi == efi)&&(identical(other.secureBoot, secureBoot) || other.secureBoot == secureBoot)&&(identical(other.machine, machine) || other.machine == machine)&&(identical(other.graphics, graphics) || other.graphics == graphics)&&(identical(other.video, video) || other.video == video)&&(identical(other.tpm, tpm) || other.tpm == tpm)&&const DeepCollectionEquality().equals(other._hostdevs, _hostdevs)&&(identical(other.seed, seed) || other.seed == seed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cpu,memoryKib,currentMemoryKib,const DeepCollectionEquality().hash(_disks),const DeepCollectionEquality().hash(_nics),const DeepCollectionEquality().hash(_boot),balloon,efi,secureBoot,machine,graphics,video,tpm,const DeepCollectionEquality().hash(_hostdevs),seed);

@override
String toString() {
  return 'LibvirtHwConfig(cpu: $cpu, memoryKib: $memoryKib, currentMemoryKib: $currentMemoryKib, disks: $disks, nics: $nics, boot: $boot, balloon: $balloon, efi: $efi, secureBoot: $secureBoot, machine: $machine, graphics: $graphics, video: $video, tpm: $tpm, hostdevs: $hostdevs, seed: $seed)';
}


}

/// @nodoc
abstract mixin class _$LibvirtHwConfigCopyWith<$Res> implements $LibvirtHwConfigCopyWith<$Res> {
  factory _$LibvirtHwConfigCopyWith(_LibvirtHwConfig value, $Res Function(_LibvirtHwConfig) _then) = __$LibvirtHwConfigCopyWithImpl;
@override @useResult
$Res call({
 LibvirtHwCpu cpu, int memoryKib, int currentMemoryKib, List<LibvirtHwDisk> disks, List<LibvirtHwNic> nics, List<String> boot, bool balloon, bool efi, bool secureBoot, String? machine, LibvirtHwGraphics? graphics, String? video, LibvirtHwTpm? tpm, List<LibvirtHwHostdev> hostdevs, String? seed
});


@override $LibvirtHwCpuCopyWith<$Res> get cpu;@override $LibvirtHwGraphicsCopyWith<$Res>? get graphics;@override $LibvirtHwTpmCopyWith<$Res>? get tpm;

}
/// @nodoc
class __$LibvirtHwConfigCopyWithImpl<$Res>
    implements _$LibvirtHwConfigCopyWith<$Res> {
  __$LibvirtHwConfigCopyWithImpl(this._self, this._then);

  final _LibvirtHwConfig _self;
  final $Res Function(_LibvirtHwConfig) _then;

/// Create a copy of LibvirtHwConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cpu = null,Object? memoryKib = null,Object? currentMemoryKib = null,Object? disks = null,Object? nics = null,Object? boot = null,Object? balloon = null,Object? efi = null,Object? secureBoot = null,Object? machine = freezed,Object? graphics = freezed,Object? video = freezed,Object? tpm = freezed,Object? hostdevs = null,Object? seed = freezed,}) {
  return _then(_LibvirtHwConfig(
cpu: null == cpu ? _self.cpu : cpu // ignore: cast_nullable_to_non_nullable
as LibvirtHwCpu,memoryKib: null == memoryKib ? _self.memoryKib : memoryKib // ignore: cast_nullable_to_non_nullable
as int,currentMemoryKib: null == currentMemoryKib ? _self.currentMemoryKib : currentMemoryKib // ignore: cast_nullable_to_non_nullable
as int,disks: null == disks ? _self._disks : disks // ignore: cast_nullable_to_non_nullable
as List<LibvirtHwDisk>,nics: null == nics ? _self._nics : nics // ignore: cast_nullable_to_non_nullable
as List<LibvirtHwNic>,boot: null == boot ? _self._boot : boot // ignore: cast_nullable_to_non_nullable
as List<String>,balloon: null == balloon ? _self.balloon : balloon // ignore: cast_nullable_to_non_nullable
as bool,efi: null == efi ? _self.efi : efi // ignore: cast_nullable_to_non_nullable
as bool,secureBoot: null == secureBoot ? _self.secureBoot : secureBoot // ignore: cast_nullable_to_non_nullable
as bool,machine: freezed == machine ? _self.machine : machine // ignore: cast_nullable_to_non_nullable
as String?,graphics: freezed == graphics ? _self.graphics : graphics // ignore: cast_nullable_to_non_nullable
as LibvirtHwGraphics?,video: freezed == video ? _self.video : video // ignore: cast_nullable_to_non_nullable
as String?,tpm: freezed == tpm ? _self.tpm : tpm // ignore: cast_nullable_to_non_nullable
as LibvirtHwTpm?,hostdevs: null == hostdevs ? _self._hostdevs : hostdevs // ignore: cast_nullable_to_non_nullable
as List<LibvirtHwHostdev>,seed: freezed == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of LibvirtHwConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtHwCpuCopyWith<$Res> get cpu {
  
  return $LibvirtHwCpuCopyWith<$Res>(_self.cpu, (value) {
    return _then(_self.copyWith(cpu: value));
  });
}/// Create a copy of LibvirtHwConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtHwGraphicsCopyWith<$Res>? get graphics {
    if (_self.graphics == null) {
    return null;
  }

  return $LibvirtHwGraphicsCopyWith<$Res>(_self.graphics!, (value) {
    return _then(_self.copyWith(graphics: value));
  });
}/// Create a copy of LibvirtHwConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtHwTpmCopyWith<$Res>? get tpm {
    if (_self.tpm == null) {
    return null;
  }

  return $LibvirtHwTpmCopyWith<$Res>(_self.tpm!, (value) {
    return _then(_self.copyWith(tpm: value));
  });
}
}


/// @nodoc
mixin _$LibvirtHwGraphics {

 String get kind; String? get listen; int? get port;
/// Create a copy of LibvirtHwGraphics
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtHwGraphicsCopyWith<LibvirtHwGraphics> get copyWith => _$LibvirtHwGraphicsCopyWithImpl<LibvirtHwGraphics>(this as LibvirtHwGraphics, _$identity);

  /// Serializes this LibvirtHwGraphics to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtHwGraphics&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.listen, listen) || other.listen == listen)&&(identical(other.port, port) || other.port == port));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,listen,port);

@override
String toString() {
  return 'LibvirtHwGraphics(kind: $kind, listen: $listen, port: $port)';
}


}

/// @nodoc
abstract mixin class $LibvirtHwGraphicsCopyWith<$Res>  {
  factory $LibvirtHwGraphicsCopyWith(LibvirtHwGraphics value, $Res Function(LibvirtHwGraphics) _then) = _$LibvirtHwGraphicsCopyWithImpl;
@useResult
$Res call({
 String kind, String? listen, int? port
});




}
/// @nodoc
class _$LibvirtHwGraphicsCopyWithImpl<$Res>
    implements $LibvirtHwGraphicsCopyWith<$Res> {
  _$LibvirtHwGraphicsCopyWithImpl(this._self, this._then);

  final LibvirtHwGraphics _self;
  final $Res Function(LibvirtHwGraphics) _then;

/// Create a copy of LibvirtHwGraphics
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? listen = freezed,Object? port = freezed,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,listen: freezed == listen ? _self.listen : listen // ignore: cast_nullable_to_non_nullable
as String?,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtHwGraphics].
extension LibvirtHwGraphicsPatterns on LibvirtHwGraphics {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtHwGraphics value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtHwGraphics() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtHwGraphics value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtHwGraphics():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtHwGraphics value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtHwGraphics() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  String? listen,  int? port)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtHwGraphics() when $default != null:
return $default(_that.kind,_that.listen,_that.port);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  String? listen,  int? port)  $default,) {final _that = this;
switch (_that) {
case _LibvirtHwGraphics():
return $default(_that.kind,_that.listen,_that.port);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  String? listen,  int? port)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtHwGraphics() when $default != null:
return $default(_that.kind,_that.listen,_that.port);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtHwGraphics implements LibvirtHwGraphics {
  const _LibvirtHwGraphics({this.kind = '', this.listen, this.port});
  factory _LibvirtHwGraphics.fromJson(Map<String, dynamic> json) => _$LibvirtHwGraphicsFromJson(json);

@override@JsonKey() final  String kind;
@override final  String? listen;
@override final  int? port;

/// Create a copy of LibvirtHwGraphics
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtHwGraphicsCopyWith<_LibvirtHwGraphics> get copyWith => __$LibvirtHwGraphicsCopyWithImpl<_LibvirtHwGraphics>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtHwGraphicsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtHwGraphics&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.listen, listen) || other.listen == listen)&&(identical(other.port, port) || other.port == port));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,listen,port);

@override
String toString() {
  return 'LibvirtHwGraphics(kind: $kind, listen: $listen, port: $port)';
}


}

/// @nodoc
abstract mixin class _$LibvirtHwGraphicsCopyWith<$Res> implements $LibvirtHwGraphicsCopyWith<$Res> {
  factory _$LibvirtHwGraphicsCopyWith(_LibvirtHwGraphics value, $Res Function(_LibvirtHwGraphics) _then) = __$LibvirtHwGraphicsCopyWithImpl;
@override @useResult
$Res call({
 String kind, String? listen, int? port
});




}
/// @nodoc
class __$LibvirtHwGraphicsCopyWithImpl<$Res>
    implements _$LibvirtHwGraphicsCopyWith<$Res> {
  __$LibvirtHwGraphicsCopyWithImpl(this._self, this._then);

  final _LibvirtHwGraphics _self;
  final $Res Function(_LibvirtHwGraphics) _then;

/// Create a copy of LibvirtHwGraphics
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? listen = freezed,Object? port = freezed,}) {
  return _then(_LibvirtHwGraphics(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,listen: freezed == listen ? _self.listen : listen // ignore: cast_nullable_to_non_nullable
as String?,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$LibvirtHwTpm {

 String get model; String get backend; String? get version;
/// Create a copy of LibvirtHwTpm
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtHwTpmCopyWith<LibvirtHwTpm> get copyWith => _$LibvirtHwTpmCopyWithImpl<LibvirtHwTpm>(this as LibvirtHwTpm, _$identity);

  /// Serializes this LibvirtHwTpm to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtHwTpm&&(identical(other.model, model) || other.model == model)&&(identical(other.backend, backend) || other.backend == backend)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,model,backend,version);

@override
String toString() {
  return 'LibvirtHwTpm(model: $model, backend: $backend, version: $version)';
}


}

/// @nodoc
abstract mixin class $LibvirtHwTpmCopyWith<$Res>  {
  factory $LibvirtHwTpmCopyWith(LibvirtHwTpm value, $Res Function(LibvirtHwTpm) _then) = _$LibvirtHwTpmCopyWithImpl;
@useResult
$Res call({
 String model, String backend, String? version
});




}
/// @nodoc
class _$LibvirtHwTpmCopyWithImpl<$Res>
    implements $LibvirtHwTpmCopyWith<$Res> {
  _$LibvirtHwTpmCopyWithImpl(this._self, this._then);

  final LibvirtHwTpm _self;
  final $Res Function(LibvirtHwTpm) _then;

/// Create a copy of LibvirtHwTpm
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? model = null,Object? backend = null,Object? version = freezed,}) {
  return _then(_self.copyWith(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,backend: null == backend ? _self.backend : backend // ignore: cast_nullable_to_non_nullable
as String,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtHwTpm].
extension LibvirtHwTpmPatterns on LibvirtHwTpm {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtHwTpm value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtHwTpm() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtHwTpm value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtHwTpm():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtHwTpm value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtHwTpm() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String model,  String backend,  String? version)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtHwTpm() when $default != null:
return $default(_that.model,_that.backend,_that.version);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String model,  String backend,  String? version)  $default,) {final _that = this;
switch (_that) {
case _LibvirtHwTpm():
return $default(_that.model,_that.backend,_that.version);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String model,  String backend,  String? version)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtHwTpm() when $default != null:
return $default(_that.model,_that.backend,_that.version);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtHwTpm implements LibvirtHwTpm {
  const _LibvirtHwTpm({this.model = '', this.backend = '', this.version});
  factory _LibvirtHwTpm.fromJson(Map<String, dynamic> json) => _$LibvirtHwTpmFromJson(json);

@override@JsonKey() final  String model;
@override@JsonKey() final  String backend;
@override final  String? version;

/// Create a copy of LibvirtHwTpm
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtHwTpmCopyWith<_LibvirtHwTpm> get copyWith => __$LibvirtHwTpmCopyWithImpl<_LibvirtHwTpm>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtHwTpmToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtHwTpm&&(identical(other.model, model) || other.model == model)&&(identical(other.backend, backend) || other.backend == backend)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,model,backend,version);

@override
String toString() {
  return 'LibvirtHwTpm(model: $model, backend: $backend, version: $version)';
}


}

/// @nodoc
abstract mixin class _$LibvirtHwTpmCopyWith<$Res> implements $LibvirtHwTpmCopyWith<$Res> {
  factory _$LibvirtHwTpmCopyWith(_LibvirtHwTpm value, $Res Function(_LibvirtHwTpm) _then) = __$LibvirtHwTpmCopyWithImpl;
@override @useResult
$Res call({
 String model, String backend, String? version
});




}
/// @nodoc
class __$LibvirtHwTpmCopyWithImpl<$Res>
    implements _$LibvirtHwTpmCopyWith<$Res> {
  __$LibvirtHwTpmCopyWithImpl(this._self, this._then);

  final _LibvirtHwTpm _self;
  final $Res Function(_LibvirtHwTpm) _then;

/// Create a copy of LibvirtHwTpm
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? model = null,Object? backend = null,Object? version = freezed,}) {
  return _then(_LibvirtHwTpm(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,backend: null == backend ? _self.backend : backend // ignore: cast_nullable_to_non_nullable
as String,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LibvirtHwHostdev {

 String get key; String get kind; String? get vendor; String? get product; String? get address;
/// Create a copy of LibvirtHwHostdev
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtHwHostdevCopyWith<LibvirtHwHostdev> get copyWith => _$LibvirtHwHostdevCopyWithImpl<LibvirtHwHostdev>(this as LibvirtHwHostdev, _$identity);

  /// Serializes this LibvirtHwHostdev to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtHwHostdev&&(identical(other.key, key) || other.key == key)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.product, product) || other.product == product)&&(identical(other.address, address) || other.address == address));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,kind,vendor,product,address);

@override
String toString() {
  return 'LibvirtHwHostdev(key: $key, kind: $kind, vendor: $vendor, product: $product, address: $address)';
}


}

/// @nodoc
abstract mixin class $LibvirtHwHostdevCopyWith<$Res>  {
  factory $LibvirtHwHostdevCopyWith(LibvirtHwHostdev value, $Res Function(LibvirtHwHostdev) _then) = _$LibvirtHwHostdevCopyWithImpl;
@useResult
$Res call({
 String key, String kind, String? vendor, String? product, String? address
});




}
/// @nodoc
class _$LibvirtHwHostdevCopyWithImpl<$Res>
    implements $LibvirtHwHostdevCopyWith<$Res> {
  _$LibvirtHwHostdevCopyWithImpl(this._self, this._then);

  final LibvirtHwHostdev _self;
  final $Res Function(LibvirtHwHostdev) _then;

/// Create a copy of LibvirtHwHostdev
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? kind = null,Object? vendor = freezed,Object? product = freezed,Object? address = freezed,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,vendor: freezed == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String?,product: freezed == product ? _self.product : product // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtHwHostdev].
extension LibvirtHwHostdevPatterns on LibvirtHwHostdev {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtHwHostdev value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtHwHostdev() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtHwHostdev value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtHwHostdev():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtHwHostdev value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtHwHostdev() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String kind,  String? vendor,  String? product,  String? address)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtHwHostdev() when $default != null:
return $default(_that.key,_that.kind,_that.vendor,_that.product,_that.address);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String kind,  String? vendor,  String? product,  String? address)  $default,) {final _that = this;
switch (_that) {
case _LibvirtHwHostdev():
return $default(_that.key,_that.kind,_that.vendor,_that.product,_that.address);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String kind,  String? vendor,  String? product,  String? address)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtHwHostdev() when $default != null:
return $default(_that.key,_that.kind,_that.vendor,_that.product,_that.address);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtHwHostdev implements LibvirtHwHostdev {
  const _LibvirtHwHostdev({required this.key, this.kind = '', this.vendor, this.product, this.address});
  factory _LibvirtHwHostdev.fromJson(Map<String, dynamic> json) => _$LibvirtHwHostdevFromJson(json);

@override final  String key;
@override@JsonKey() final  String kind;
@override final  String? vendor;
@override final  String? product;
@override final  String? address;

/// Create a copy of LibvirtHwHostdev
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtHwHostdevCopyWith<_LibvirtHwHostdev> get copyWith => __$LibvirtHwHostdevCopyWithImpl<_LibvirtHwHostdev>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtHwHostdevToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtHwHostdev&&(identical(other.key, key) || other.key == key)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.product, product) || other.product == product)&&(identical(other.address, address) || other.address == address));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,kind,vendor,product,address);

@override
String toString() {
  return 'LibvirtHwHostdev(key: $key, kind: $kind, vendor: $vendor, product: $product, address: $address)';
}


}

/// @nodoc
abstract mixin class _$LibvirtHwHostdevCopyWith<$Res> implements $LibvirtHwHostdevCopyWith<$Res> {
  factory _$LibvirtHwHostdevCopyWith(_LibvirtHwHostdev value, $Res Function(_LibvirtHwHostdev) _then) = __$LibvirtHwHostdevCopyWithImpl;
@override @useResult
$Res call({
 String key, String kind, String? vendor, String? product, String? address
});




}
/// @nodoc
class __$LibvirtHwHostdevCopyWithImpl<$Res>
    implements _$LibvirtHwHostdevCopyWith<$Res> {
  __$LibvirtHwHostdevCopyWithImpl(this._self, this._then);

  final _LibvirtHwHostdev _self;
  final $Res Function(_LibvirtHwHostdev) _then;

/// Create a copy of LibvirtHwHostdev
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? kind = null,Object? vendor = freezed,Object? product = freezed,Object? address = freezed,}) {
  return _then(_LibvirtHwHostdev(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,vendor: freezed == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String?,product: freezed == product ? _self.product : product // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LibvirtHwCaps {

 bool get efi; bool get secureBoot; bool get tpmEmulator; List<String> get graphics; List<String> get video; List<String> get diskBuses; bool get hostdev;
/// Create a copy of LibvirtHwCaps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtHwCapsCopyWith<LibvirtHwCaps> get copyWith => _$LibvirtHwCapsCopyWithImpl<LibvirtHwCaps>(this as LibvirtHwCaps, _$identity);

  /// Serializes this LibvirtHwCaps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtHwCaps&&(identical(other.efi, efi) || other.efi == efi)&&(identical(other.secureBoot, secureBoot) || other.secureBoot == secureBoot)&&(identical(other.tpmEmulator, tpmEmulator) || other.tpmEmulator == tpmEmulator)&&const DeepCollectionEquality().equals(other.graphics, graphics)&&const DeepCollectionEquality().equals(other.video, video)&&const DeepCollectionEquality().equals(other.diskBuses, diskBuses)&&(identical(other.hostdev, hostdev) || other.hostdev == hostdev));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,efi,secureBoot,tpmEmulator,const DeepCollectionEquality().hash(graphics),const DeepCollectionEquality().hash(video),const DeepCollectionEquality().hash(diskBuses),hostdev);

@override
String toString() {
  return 'LibvirtHwCaps(efi: $efi, secureBoot: $secureBoot, tpmEmulator: $tpmEmulator, graphics: $graphics, video: $video, diskBuses: $diskBuses, hostdev: $hostdev)';
}


}

/// @nodoc
abstract mixin class $LibvirtHwCapsCopyWith<$Res>  {
  factory $LibvirtHwCapsCopyWith(LibvirtHwCaps value, $Res Function(LibvirtHwCaps) _then) = _$LibvirtHwCapsCopyWithImpl;
@useResult
$Res call({
 bool efi, bool secureBoot, bool tpmEmulator, List<String> graphics, List<String> video, List<String> diskBuses, bool hostdev
});




}
/// @nodoc
class _$LibvirtHwCapsCopyWithImpl<$Res>
    implements $LibvirtHwCapsCopyWith<$Res> {
  _$LibvirtHwCapsCopyWithImpl(this._self, this._then);

  final LibvirtHwCaps _self;
  final $Res Function(LibvirtHwCaps) _then;

/// Create a copy of LibvirtHwCaps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? efi = null,Object? secureBoot = null,Object? tpmEmulator = null,Object? graphics = null,Object? video = null,Object? diskBuses = null,Object? hostdev = null,}) {
  return _then(_self.copyWith(
efi: null == efi ? _self.efi : efi // ignore: cast_nullable_to_non_nullable
as bool,secureBoot: null == secureBoot ? _self.secureBoot : secureBoot // ignore: cast_nullable_to_non_nullable
as bool,tpmEmulator: null == tpmEmulator ? _self.tpmEmulator : tpmEmulator // ignore: cast_nullable_to_non_nullable
as bool,graphics: null == graphics ? _self.graphics : graphics // ignore: cast_nullable_to_non_nullable
as List<String>,video: null == video ? _self.video : video // ignore: cast_nullable_to_non_nullable
as List<String>,diskBuses: null == diskBuses ? _self.diskBuses : diskBuses // ignore: cast_nullable_to_non_nullable
as List<String>,hostdev: null == hostdev ? _self.hostdev : hostdev // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtHwCaps].
extension LibvirtHwCapsPatterns on LibvirtHwCaps {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtHwCaps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtHwCaps() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtHwCaps value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtHwCaps():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtHwCaps value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtHwCaps() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool efi,  bool secureBoot,  bool tpmEmulator,  List<String> graphics,  List<String> video,  List<String> diskBuses,  bool hostdev)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtHwCaps() when $default != null:
return $default(_that.efi,_that.secureBoot,_that.tpmEmulator,_that.graphics,_that.video,_that.diskBuses,_that.hostdev);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool efi,  bool secureBoot,  bool tpmEmulator,  List<String> graphics,  List<String> video,  List<String> diskBuses,  bool hostdev)  $default,) {final _that = this;
switch (_that) {
case _LibvirtHwCaps():
return $default(_that.efi,_that.secureBoot,_that.tpmEmulator,_that.graphics,_that.video,_that.diskBuses,_that.hostdev);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool efi,  bool secureBoot,  bool tpmEmulator,  List<String> graphics,  List<String> video,  List<String> diskBuses,  bool hostdev)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtHwCaps() when $default != null:
return $default(_that.efi,_that.secureBoot,_that.tpmEmulator,_that.graphics,_that.video,_that.diskBuses,_that.hostdev);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtHwCaps implements LibvirtHwCaps {
  const _LibvirtHwCaps({this.efi = false, this.secureBoot = false, this.tpmEmulator = false, final  List<String> graphics = const <String>[], final  List<String> video = const <String>[], final  List<String> diskBuses = const <String>[], this.hostdev = false}): _graphics = graphics,_video = video,_diskBuses = diskBuses;
  factory _LibvirtHwCaps.fromJson(Map<String, dynamic> json) => _$LibvirtHwCapsFromJson(json);

@override@JsonKey() final  bool efi;
@override@JsonKey() final  bool secureBoot;
@override@JsonKey() final  bool tpmEmulator;
 final  List<String> _graphics;
@override@JsonKey() List<String> get graphics {
  if (_graphics is EqualUnmodifiableListView) return _graphics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_graphics);
}

 final  List<String> _video;
@override@JsonKey() List<String> get video {
  if (_video is EqualUnmodifiableListView) return _video;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_video);
}

 final  List<String> _diskBuses;
@override@JsonKey() List<String> get diskBuses {
  if (_diskBuses is EqualUnmodifiableListView) return _diskBuses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_diskBuses);
}

@override@JsonKey() final  bool hostdev;

/// Create a copy of LibvirtHwCaps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtHwCapsCopyWith<_LibvirtHwCaps> get copyWith => __$LibvirtHwCapsCopyWithImpl<_LibvirtHwCaps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtHwCapsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtHwCaps&&(identical(other.efi, efi) || other.efi == efi)&&(identical(other.secureBoot, secureBoot) || other.secureBoot == secureBoot)&&(identical(other.tpmEmulator, tpmEmulator) || other.tpmEmulator == tpmEmulator)&&const DeepCollectionEquality().equals(other._graphics, _graphics)&&const DeepCollectionEquality().equals(other._video, _video)&&const DeepCollectionEquality().equals(other._diskBuses, _diskBuses)&&(identical(other.hostdev, hostdev) || other.hostdev == hostdev));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,efi,secureBoot,tpmEmulator,const DeepCollectionEquality().hash(_graphics),const DeepCollectionEquality().hash(_video),const DeepCollectionEquality().hash(_diskBuses),hostdev);

@override
String toString() {
  return 'LibvirtHwCaps(efi: $efi, secureBoot: $secureBoot, tpmEmulator: $tpmEmulator, graphics: $graphics, video: $video, diskBuses: $diskBuses, hostdev: $hostdev)';
}


}

/// @nodoc
abstract mixin class _$LibvirtHwCapsCopyWith<$Res> implements $LibvirtHwCapsCopyWith<$Res> {
  factory _$LibvirtHwCapsCopyWith(_LibvirtHwCaps value, $Res Function(_LibvirtHwCaps) _then) = __$LibvirtHwCapsCopyWithImpl;
@override @useResult
$Res call({
 bool efi, bool secureBoot, bool tpmEmulator, List<String> graphics, List<String> video, List<String> diskBuses, bool hostdev
});




}
/// @nodoc
class __$LibvirtHwCapsCopyWithImpl<$Res>
    implements _$LibvirtHwCapsCopyWith<$Res> {
  __$LibvirtHwCapsCopyWithImpl(this._self, this._then);

  final _LibvirtHwCaps _self;
  final $Res Function(_LibvirtHwCaps) _then;

/// Create a copy of LibvirtHwCaps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? efi = null,Object? secureBoot = null,Object? tpmEmulator = null,Object? graphics = null,Object? video = null,Object? diskBuses = null,Object? hostdev = null,}) {
  return _then(_LibvirtHwCaps(
efi: null == efi ? _self.efi : efi // ignore: cast_nullable_to_non_nullable
as bool,secureBoot: null == secureBoot ? _self.secureBoot : secureBoot // ignore: cast_nullable_to_non_nullable
as bool,tpmEmulator: null == tpmEmulator ? _self.tpmEmulator : tpmEmulator // ignore: cast_nullable_to_non_nullable
as bool,graphics: null == graphics ? _self._graphics : graphics // ignore: cast_nullable_to_non_nullable
as List<String>,video: null == video ? _self._video : video // ignore: cast_nullable_to_non_nullable
as List<String>,diskBuses: null == diskBuses ? _self._diskBuses : diskBuses // ignore: cast_nullable_to_non_nullable
as List<String>,hostdev: null == hostdev ? _self.hostdev : hostdev // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$LibvirtCreateHost {

 String get domainType; String get machine; String get arch; int? get maxVcpus; LibvirtHwCaps? get caps;/// The ISO tool a cloud-init seed is made with; null: none there.
 String? get seedTool;
/// Create a copy of LibvirtCreateHost
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtCreateHostCopyWith<LibvirtCreateHost> get copyWith => _$LibvirtCreateHostCopyWithImpl<LibvirtCreateHost>(this as LibvirtCreateHost, _$identity);

  /// Serializes this LibvirtCreateHost to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtCreateHost&&(identical(other.domainType, domainType) || other.domainType == domainType)&&(identical(other.machine, machine) || other.machine == machine)&&(identical(other.arch, arch) || other.arch == arch)&&(identical(other.maxVcpus, maxVcpus) || other.maxVcpus == maxVcpus)&&(identical(other.caps, caps) || other.caps == caps)&&(identical(other.seedTool, seedTool) || other.seedTool == seedTool));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,domainType,machine,arch,maxVcpus,caps,seedTool);

@override
String toString() {
  return 'LibvirtCreateHost(domainType: $domainType, machine: $machine, arch: $arch, maxVcpus: $maxVcpus, caps: $caps, seedTool: $seedTool)';
}


}

/// @nodoc
abstract mixin class $LibvirtCreateHostCopyWith<$Res>  {
  factory $LibvirtCreateHostCopyWith(LibvirtCreateHost value, $Res Function(LibvirtCreateHost) _then) = _$LibvirtCreateHostCopyWithImpl;
@useResult
$Res call({
 String domainType, String machine, String arch, int? maxVcpus, LibvirtHwCaps? caps, String? seedTool
});


$LibvirtHwCapsCopyWith<$Res>? get caps;

}
/// @nodoc
class _$LibvirtCreateHostCopyWithImpl<$Res>
    implements $LibvirtCreateHostCopyWith<$Res> {
  _$LibvirtCreateHostCopyWithImpl(this._self, this._then);

  final LibvirtCreateHost _self;
  final $Res Function(LibvirtCreateHost) _then;

/// Create a copy of LibvirtCreateHost
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? domainType = null,Object? machine = null,Object? arch = null,Object? maxVcpus = freezed,Object? caps = freezed,Object? seedTool = freezed,}) {
  return _then(_self.copyWith(
domainType: null == domainType ? _self.domainType : domainType // ignore: cast_nullable_to_non_nullable
as String,machine: null == machine ? _self.machine : machine // ignore: cast_nullable_to_non_nullable
as String,arch: null == arch ? _self.arch : arch // ignore: cast_nullable_to_non_nullable
as String,maxVcpus: freezed == maxVcpus ? _self.maxVcpus : maxVcpus // ignore: cast_nullable_to_non_nullable
as int?,caps: freezed == caps ? _self.caps : caps // ignore: cast_nullable_to_non_nullable
as LibvirtHwCaps?,seedTool: freezed == seedTool ? _self.seedTool : seedTool // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of LibvirtCreateHost
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtHwCapsCopyWith<$Res>? get caps {
    if (_self.caps == null) {
    return null;
  }

  return $LibvirtHwCapsCopyWith<$Res>(_self.caps!, (value) {
    return _then(_self.copyWith(caps: value));
  });
}
}


/// Adds pattern-matching-related methods to [LibvirtCreateHost].
extension LibvirtCreateHostPatterns on LibvirtCreateHost {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtCreateHost value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtCreateHost() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtCreateHost value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtCreateHost():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtCreateHost value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtCreateHost() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String domainType,  String machine,  String arch,  int? maxVcpus,  LibvirtHwCaps? caps,  String? seedTool)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtCreateHost() when $default != null:
return $default(_that.domainType,_that.machine,_that.arch,_that.maxVcpus,_that.caps,_that.seedTool);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String domainType,  String machine,  String arch,  int? maxVcpus,  LibvirtHwCaps? caps,  String? seedTool)  $default,) {final _that = this;
switch (_that) {
case _LibvirtCreateHost():
return $default(_that.domainType,_that.machine,_that.arch,_that.maxVcpus,_that.caps,_that.seedTool);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String domainType,  String machine,  String arch,  int? maxVcpus,  LibvirtHwCaps? caps,  String? seedTool)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtCreateHost() when $default != null:
return $default(_that.domainType,_that.machine,_that.arch,_that.maxVcpus,_that.caps,_that.seedTool);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtCreateHost implements LibvirtCreateHost {
  const _LibvirtCreateHost({this.domainType = '', this.machine = '', this.arch = '', this.maxVcpus, this.caps, this.seedTool});
  factory _LibvirtCreateHost.fromJson(Map<String, dynamic> json) => _$LibvirtCreateHostFromJson(json);

@override@JsonKey() final  String domainType;
@override@JsonKey() final  String machine;
@override@JsonKey() final  String arch;
@override final  int? maxVcpus;
@override final  LibvirtHwCaps? caps;
/// The ISO tool a cloud-init seed is made with; null: none there.
@override final  String? seedTool;

/// Create a copy of LibvirtCreateHost
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtCreateHostCopyWith<_LibvirtCreateHost> get copyWith => __$LibvirtCreateHostCopyWithImpl<_LibvirtCreateHost>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtCreateHostToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtCreateHost&&(identical(other.domainType, domainType) || other.domainType == domainType)&&(identical(other.machine, machine) || other.machine == machine)&&(identical(other.arch, arch) || other.arch == arch)&&(identical(other.maxVcpus, maxVcpus) || other.maxVcpus == maxVcpus)&&(identical(other.caps, caps) || other.caps == caps)&&(identical(other.seedTool, seedTool) || other.seedTool == seedTool));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,domainType,machine,arch,maxVcpus,caps,seedTool);

@override
String toString() {
  return 'LibvirtCreateHost(domainType: $domainType, machine: $machine, arch: $arch, maxVcpus: $maxVcpus, caps: $caps, seedTool: $seedTool)';
}


}

/// @nodoc
abstract mixin class _$LibvirtCreateHostCopyWith<$Res> implements $LibvirtCreateHostCopyWith<$Res> {
  factory _$LibvirtCreateHostCopyWith(_LibvirtCreateHost value, $Res Function(_LibvirtCreateHost) _then) = __$LibvirtCreateHostCopyWithImpl;
@override @useResult
$Res call({
 String domainType, String machine, String arch, int? maxVcpus, LibvirtHwCaps? caps, String? seedTool
});


@override $LibvirtHwCapsCopyWith<$Res>? get caps;

}
/// @nodoc
class __$LibvirtCreateHostCopyWithImpl<$Res>
    implements _$LibvirtCreateHostCopyWith<$Res> {
  __$LibvirtCreateHostCopyWithImpl(this._self, this._then);

  final _LibvirtCreateHost _self;
  final $Res Function(_LibvirtCreateHost) _then;

/// Create a copy of LibvirtCreateHost
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? domainType = null,Object? machine = null,Object? arch = null,Object? maxVcpus = freezed,Object? caps = freezed,Object? seedTool = freezed,}) {
  return _then(_LibvirtCreateHost(
domainType: null == domainType ? _self.domainType : domainType // ignore: cast_nullable_to_non_nullable
as String,machine: null == machine ? _self.machine : machine // ignore: cast_nullable_to_non_nullable
as String,arch: null == arch ? _self.arch : arch // ignore: cast_nullable_to_non_nullable
as String,maxVcpus: freezed == maxVcpus ? _self.maxVcpus : maxVcpus // ignore: cast_nullable_to_non_nullable
as int?,caps: freezed == caps ? _self.caps : caps // ignore: cast_nullable_to_non_nullable
as LibvirtHwCaps?,seedTool: freezed == seedTool ? _self.seedTool : seedTool // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of LibvirtCreateHost
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtHwCapsCopyWith<$Res>? get caps {
    if (_self.caps == null) {
    return null;
  }

  return $LibvirtHwCapsCopyWith<$Res>(_self.caps!, (value) {
    return _then(_self.copyWith(caps: value));
  });
}
}


/// @nodoc
mixin _$LibvirtFirmware {

 String get name; bool get secureBoot;/// Carries the vendor's keys, which a domain with Secure Boot on needs.
 bool get enrolledKeys;
/// Create a copy of LibvirtFirmware
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtFirmwareCopyWith<LibvirtFirmware> get copyWith => _$LibvirtFirmwareCopyWithImpl<LibvirtFirmware>(this as LibvirtFirmware, _$identity);

  /// Serializes this LibvirtFirmware to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtFirmware&&(identical(other.name, name) || other.name == name)&&(identical(other.secureBoot, secureBoot) || other.secureBoot == secureBoot)&&(identical(other.enrolledKeys, enrolledKeys) || other.enrolledKeys == enrolledKeys));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,secureBoot,enrolledKeys);

@override
String toString() {
  return 'LibvirtFirmware(name: $name, secureBoot: $secureBoot, enrolledKeys: $enrolledKeys)';
}


}

/// @nodoc
abstract mixin class $LibvirtFirmwareCopyWith<$Res>  {
  factory $LibvirtFirmwareCopyWith(LibvirtFirmware value, $Res Function(LibvirtFirmware) _then) = _$LibvirtFirmwareCopyWithImpl;
@useResult
$Res call({
 String name, bool secureBoot, bool enrolledKeys
});




}
/// @nodoc
class _$LibvirtFirmwareCopyWithImpl<$Res>
    implements $LibvirtFirmwareCopyWith<$Res> {
  _$LibvirtFirmwareCopyWithImpl(this._self, this._then);

  final LibvirtFirmware _self;
  final $Res Function(LibvirtFirmware) _then;

/// Create a copy of LibvirtFirmware
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? secureBoot = null,Object? enrolledKeys = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,secureBoot: null == secureBoot ? _self.secureBoot : secureBoot // ignore: cast_nullable_to_non_nullable
as bool,enrolledKeys: null == enrolledKeys ? _self.enrolledKeys : enrolledKeys // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtFirmware].
extension LibvirtFirmwarePatterns on LibvirtFirmware {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtFirmware value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtFirmware() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtFirmware value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtFirmware():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtFirmware value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtFirmware() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  bool secureBoot,  bool enrolledKeys)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtFirmware() when $default != null:
return $default(_that.name,_that.secureBoot,_that.enrolledKeys);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  bool secureBoot,  bool enrolledKeys)  $default,) {final _that = this;
switch (_that) {
case _LibvirtFirmware():
return $default(_that.name,_that.secureBoot,_that.enrolledKeys);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  bool secureBoot,  bool enrolledKeys)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtFirmware() when $default != null:
return $default(_that.name,_that.secureBoot,_that.enrolledKeys);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtFirmware implements LibvirtFirmware {
  const _LibvirtFirmware({required this.name, this.secureBoot = false, this.enrolledKeys = false});
  factory _LibvirtFirmware.fromJson(Map<String, dynamic> json) => _$LibvirtFirmwareFromJson(json);

@override final  String name;
@override@JsonKey() final  bool secureBoot;
/// Carries the vendor's keys, which a domain with Secure Boot on needs.
@override@JsonKey() final  bool enrolledKeys;

/// Create a copy of LibvirtFirmware
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtFirmwareCopyWith<_LibvirtFirmware> get copyWith => __$LibvirtFirmwareCopyWithImpl<_LibvirtFirmware>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtFirmwareToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtFirmware&&(identical(other.name, name) || other.name == name)&&(identical(other.secureBoot, secureBoot) || other.secureBoot == secureBoot)&&(identical(other.enrolledKeys, enrolledKeys) || other.enrolledKeys == enrolledKeys));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,secureBoot,enrolledKeys);

@override
String toString() {
  return 'LibvirtFirmware(name: $name, secureBoot: $secureBoot, enrolledKeys: $enrolledKeys)';
}


}

/// @nodoc
abstract mixin class _$LibvirtFirmwareCopyWith<$Res> implements $LibvirtFirmwareCopyWith<$Res> {
  factory _$LibvirtFirmwareCopyWith(_LibvirtFirmware value, $Res Function(_LibvirtFirmware) _then) = __$LibvirtFirmwareCopyWithImpl;
@override @useResult
$Res call({
 String name, bool secureBoot, bool enrolledKeys
});




}
/// @nodoc
class __$LibvirtFirmwareCopyWithImpl<$Res>
    implements _$LibvirtFirmwareCopyWith<$Res> {
  __$LibvirtFirmwareCopyWithImpl(this._self, this._then);

  final _LibvirtFirmware _self;
  final $Res Function(_LibvirtFirmware) _then;

/// Create a copy of LibvirtFirmware
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? secureBoot = null,Object? enrolledKeys = null,}) {
  return _then(_LibvirtFirmware(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,secureBoot: null == secureBoot ? _self.secureBoot : secureBoot // ignore: cast_nullable_to_non_nullable
as bool,enrolledKeys: null == enrolledKeys ? _self.enrolledKeys : enrolledKeys // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$LibvirtHostDevices {

 List<LibvirtHostUsb> get usb; List<LibvirtHostPci> get pci; bool get iommu;
/// Create a copy of LibvirtHostDevices
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtHostDevicesCopyWith<LibvirtHostDevices> get copyWith => _$LibvirtHostDevicesCopyWithImpl<LibvirtHostDevices>(this as LibvirtHostDevices, _$identity);

  /// Serializes this LibvirtHostDevices to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtHostDevices&&const DeepCollectionEquality().equals(other.usb, usb)&&const DeepCollectionEquality().equals(other.pci, pci)&&(identical(other.iommu, iommu) || other.iommu == iommu));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(usb),const DeepCollectionEquality().hash(pci),iommu);

@override
String toString() {
  return 'LibvirtHostDevices(usb: $usb, pci: $pci, iommu: $iommu)';
}


}

/// @nodoc
abstract mixin class $LibvirtHostDevicesCopyWith<$Res>  {
  factory $LibvirtHostDevicesCopyWith(LibvirtHostDevices value, $Res Function(LibvirtHostDevices) _then) = _$LibvirtHostDevicesCopyWithImpl;
@useResult
$Res call({
 List<LibvirtHostUsb> usb, List<LibvirtHostPci> pci, bool iommu
});




}
/// @nodoc
class _$LibvirtHostDevicesCopyWithImpl<$Res>
    implements $LibvirtHostDevicesCopyWith<$Res> {
  _$LibvirtHostDevicesCopyWithImpl(this._self, this._then);

  final LibvirtHostDevices _self;
  final $Res Function(LibvirtHostDevices) _then;

/// Create a copy of LibvirtHostDevices
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? usb = null,Object? pci = null,Object? iommu = null,}) {
  return _then(_self.copyWith(
usb: null == usb ? _self.usb : usb // ignore: cast_nullable_to_non_nullable
as List<LibvirtHostUsb>,pci: null == pci ? _self.pci : pci // ignore: cast_nullable_to_non_nullable
as List<LibvirtHostPci>,iommu: null == iommu ? _self.iommu : iommu // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtHostDevices].
extension LibvirtHostDevicesPatterns on LibvirtHostDevices {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtHostDevices value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtHostDevices() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtHostDevices value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtHostDevices():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtHostDevices value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtHostDevices() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<LibvirtHostUsb> usb,  List<LibvirtHostPci> pci,  bool iommu)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtHostDevices() when $default != null:
return $default(_that.usb,_that.pci,_that.iommu);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<LibvirtHostUsb> usb,  List<LibvirtHostPci> pci,  bool iommu)  $default,) {final _that = this;
switch (_that) {
case _LibvirtHostDevices():
return $default(_that.usb,_that.pci,_that.iommu);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<LibvirtHostUsb> usb,  List<LibvirtHostPci> pci,  bool iommu)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtHostDevices() when $default != null:
return $default(_that.usb,_that.pci,_that.iommu);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtHostDevices implements LibvirtHostDevices {
  const _LibvirtHostDevices({final  List<LibvirtHostUsb> usb = const <LibvirtHostUsb>[], final  List<LibvirtHostPci> pci = const <LibvirtHostPci>[], this.iommu = false}): _usb = usb,_pci = pci;
  factory _LibvirtHostDevices.fromJson(Map<String, dynamic> json) => _$LibvirtHostDevicesFromJson(json);

 final  List<LibvirtHostUsb> _usb;
@override@JsonKey() List<LibvirtHostUsb> get usb {
  if (_usb is EqualUnmodifiableListView) return _usb;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_usb);
}

 final  List<LibvirtHostPci> _pci;
@override@JsonKey() List<LibvirtHostPci> get pci {
  if (_pci is EqualUnmodifiableListView) return _pci;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pci);
}

@override@JsonKey() final  bool iommu;

/// Create a copy of LibvirtHostDevices
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtHostDevicesCopyWith<_LibvirtHostDevices> get copyWith => __$LibvirtHostDevicesCopyWithImpl<_LibvirtHostDevices>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtHostDevicesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtHostDevices&&const DeepCollectionEquality().equals(other._usb, _usb)&&const DeepCollectionEquality().equals(other._pci, _pci)&&(identical(other.iommu, iommu) || other.iommu == iommu));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_usb),const DeepCollectionEquality().hash(_pci),iommu);

@override
String toString() {
  return 'LibvirtHostDevices(usb: $usb, pci: $pci, iommu: $iommu)';
}


}

/// @nodoc
abstract mixin class _$LibvirtHostDevicesCopyWith<$Res> implements $LibvirtHostDevicesCopyWith<$Res> {
  factory _$LibvirtHostDevicesCopyWith(_LibvirtHostDevices value, $Res Function(_LibvirtHostDevices) _then) = __$LibvirtHostDevicesCopyWithImpl;
@override @useResult
$Res call({
 List<LibvirtHostUsb> usb, List<LibvirtHostPci> pci, bool iommu
});




}
/// @nodoc
class __$LibvirtHostDevicesCopyWithImpl<$Res>
    implements _$LibvirtHostDevicesCopyWith<$Res> {
  __$LibvirtHostDevicesCopyWithImpl(this._self, this._then);

  final _LibvirtHostDevices _self;
  final $Res Function(_LibvirtHostDevices) _then;

/// Create a copy of LibvirtHostDevices
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? usb = null,Object? pci = null,Object? iommu = null,}) {
  return _then(_LibvirtHostDevices(
usb: null == usb ? _self._usb : usb // ignore: cast_nullable_to_non_nullable
as List<LibvirtHostUsb>,pci: null == pci ? _self._pci : pci // ignore: cast_nullable_to_non_nullable
as List<LibvirtHostPci>,iommu: null == iommu ? _self.iommu : iommu // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$LibvirtHostUsb {

 String get vendor; String get product; String? get vendorName; String? get productName;/// Where it sits, for an address-based hostdev: the bus and the device
/// number on it.
 int? get bus; int? get device;/// The port chain (`4`, or `1.2` behind a hub), for the label.
 String? get port;
/// Create a copy of LibvirtHostUsb
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtHostUsbCopyWith<LibvirtHostUsb> get copyWith => _$LibvirtHostUsbCopyWithImpl<LibvirtHostUsb>(this as LibvirtHostUsb, _$identity);

  /// Serializes this LibvirtHostUsb to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtHostUsb&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.product, product) || other.product == product)&&(identical(other.vendorName, vendorName) || other.vendorName == vendorName)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.bus, bus) || other.bus == bus)&&(identical(other.device, device) || other.device == device)&&(identical(other.port, port) || other.port == port));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,vendor,product,vendorName,productName,bus,device,port);

@override
String toString() {
  return 'LibvirtHostUsb(vendor: $vendor, product: $product, vendorName: $vendorName, productName: $productName, bus: $bus, device: $device, port: $port)';
}


}

/// @nodoc
abstract mixin class $LibvirtHostUsbCopyWith<$Res>  {
  factory $LibvirtHostUsbCopyWith(LibvirtHostUsb value, $Res Function(LibvirtHostUsb) _then) = _$LibvirtHostUsbCopyWithImpl;
@useResult
$Res call({
 String vendor, String product, String? vendorName, String? productName, int? bus, int? device, String? port
});




}
/// @nodoc
class _$LibvirtHostUsbCopyWithImpl<$Res>
    implements $LibvirtHostUsbCopyWith<$Res> {
  _$LibvirtHostUsbCopyWithImpl(this._self, this._then);

  final LibvirtHostUsb _self;
  final $Res Function(LibvirtHostUsb) _then;

/// Create a copy of LibvirtHostUsb
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? vendor = null,Object? product = null,Object? vendorName = freezed,Object? productName = freezed,Object? bus = freezed,Object? device = freezed,Object? port = freezed,}) {
  return _then(_self.copyWith(
vendor: null == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String,product: null == product ? _self.product : product // ignore: cast_nullable_to_non_nullable
as String,vendorName: freezed == vendorName ? _self.vendorName : vendorName // ignore: cast_nullable_to_non_nullable
as String?,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,bus: freezed == bus ? _self.bus : bus // ignore: cast_nullable_to_non_nullable
as int?,device: freezed == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as int?,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtHostUsb].
extension LibvirtHostUsbPatterns on LibvirtHostUsb {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtHostUsb value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtHostUsb() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtHostUsb value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtHostUsb():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtHostUsb value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtHostUsb() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String vendor,  String product,  String? vendorName,  String? productName,  int? bus,  int? device,  String? port)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtHostUsb() when $default != null:
return $default(_that.vendor,_that.product,_that.vendorName,_that.productName,_that.bus,_that.device,_that.port);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String vendor,  String product,  String? vendorName,  String? productName,  int? bus,  int? device,  String? port)  $default,) {final _that = this;
switch (_that) {
case _LibvirtHostUsb():
return $default(_that.vendor,_that.product,_that.vendorName,_that.productName,_that.bus,_that.device,_that.port);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String vendor,  String product,  String? vendorName,  String? productName,  int? bus,  int? device,  String? port)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtHostUsb() when $default != null:
return $default(_that.vendor,_that.product,_that.vendorName,_that.productName,_that.bus,_that.device,_that.port);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtHostUsb implements LibvirtHostUsb {
  const _LibvirtHostUsb({required this.vendor, required this.product, this.vendorName, this.productName, this.bus, this.device, this.port});
  factory _LibvirtHostUsb.fromJson(Map<String, dynamic> json) => _$LibvirtHostUsbFromJson(json);

@override final  String vendor;
@override final  String product;
@override final  String? vendorName;
@override final  String? productName;
/// Where it sits, for an address-based hostdev: the bus and the device
/// number on it.
@override final  int? bus;
@override final  int? device;
/// The port chain (`4`, or `1.2` behind a hub), for the label.
@override final  String? port;

/// Create a copy of LibvirtHostUsb
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtHostUsbCopyWith<_LibvirtHostUsb> get copyWith => __$LibvirtHostUsbCopyWithImpl<_LibvirtHostUsb>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtHostUsbToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtHostUsb&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.product, product) || other.product == product)&&(identical(other.vendorName, vendorName) || other.vendorName == vendorName)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.bus, bus) || other.bus == bus)&&(identical(other.device, device) || other.device == device)&&(identical(other.port, port) || other.port == port));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,vendor,product,vendorName,productName,bus,device,port);

@override
String toString() {
  return 'LibvirtHostUsb(vendor: $vendor, product: $product, vendorName: $vendorName, productName: $productName, bus: $bus, device: $device, port: $port)';
}


}

/// @nodoc
abstract mixin class _$LibvirtHostUsbCopyWith<$Res> implements $LibvirtHostUsbCopyWith<$Res> {
  factory _$LibvirtHostUsbCopyWith(_LibvirtHostUsb value, $Res Function(_LibvirtHostUsb) _then) = __$LibvirtHostUsbCopyWithImpl;
@override @useResult
$Res call({
 String vendor, String product, String? vendorName, String? productName, int? bus, int? device, String? port
});




}
/// @nodoc
class __$LibvirtHostUsbCopyWithImpl<$Res>
    implements _$LibvirtHostUsbCopyWith<$Res> {
  __$LibvirtHostUsbCopyWithImpl(this._self, this._then);

  final _LibvirtHostUsb _self;
  final $Res Function(_LibvirtHostUsb) _then;

/// Create a copy of LibvirtHostUsb
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? vendor = null,Object? product = null,Object? vendorName = freezed,Object? productName = freezed,Object? bus = freezed,Object? device = freezed,Object? port = freezed,}) {
  return _then(_LibvirtHostUsb(
vendor: null == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String,product: null == product ? _self.product : product // ignore: cast_nullable_to_non_nullable
as String,vendorName: freezed == vendorName ? _self.vendorName : vendorName // ignore: cast_nullable_to_non_nullable
as String?,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,bus: freezed == bus ? _self.bus : bus // ignore: cast_nullable_to_non_nullable
as int?,device: freezed == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as int?,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LibvirtHostPci {

 String get address; String? get vendor; String? get product; String? get vendorName; String? get productName;@JsonKey(name: 'class') String? get pciClass; int? get iommuGroup; int get groupSize;
/// Create a copy of LibvirtHostPci
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtHostPciCopyWith<LibvirtHostPci> get copyWith => _$LibvirtHostPciCopyWithImpl<LibvirtHostPci>(this as LibvirtHostPci, _$identity);

  /// Serializes this LibvirtHostPci to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtHostPci&&(identical(other.address, address) || other.address == address)&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.product, product) || other.product == product)&&(identical(other.vendorName, vendorName) || other.vendorName == vendorName)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.pciClass, pciClass) || other.pciClass == pciClass)&&(identical(other.iommuGroup, iommuGroup) || other.iommuGroup == iommuGroup)&&(identical(other.groupSize, groupSize) || other.groupSize == groupSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,address,vendor,product,vendorName,productName,pciClass,iommuGroup,groupSize);

@override
String toString() {
  return 'LibvirtHostPci(address: $address, vendor: $vendor, product: $product, vendorName: $vendorName, productName: $productName, pciClass: $pciClass, iommuGroup: $iommuGroup, groupSize: $groupSize)';
}


}

/// @nodoc
abstract mixin class $LibvirtHostPciCopyWith<$Res>  {
  factory $LibvirtHostPciCopyWith(LibvirtHostPci value, $Res Function(LibvirtHostPci) _then) = _$LibvirtHostPciCopyWithImpl;
@useResult
$Res call({
 String address, String? vendor, String? product, String? vendorName, String? productName,@JsonKey(name: 'class') String? pciClass, int? iommuGroup, int groupSize
});




}
/// @nodoc
class _$LibvirtHostPciCopyWithImpl<$Res>
    implements $LibvirtHostPciCopyWith<$Res> {
  _$LibvirtHostPciCopyWithImpl(this._self, this._then);

  final LibvirtHostPci _self;
  final $Res Function(LibvirtHostPci) _then;

/// Create a copy of LibvirtHostPci
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? address = null,Object? vendor = freezed,Object? product = freezed,Object? vendorName = freezed,Object? productName = freezed,Object? pciClass = freezed,Object? iommuGroup = freezed,Object? groupSize = null,}) {
  return _then(_self.copyWith(
address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,vendor: freezed == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String?,product: freezed == product ? _self.product : product // ignore: cast_nullable_to_non_nullable
as String?,vendorName: freezed == vendorName ? _self.vendorName : vendorName // ignore: cast_nullable_to_non_nullable
as String?,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,pciClass: freezed == pciClass ? _self.pciClass : pciClass // ignore: cast_nullable_to_non_nullable
as String?,iommuGroup: freezed == iommuGroup ? _self.iommuGroup : iommuGroup // ignore: cast_nullable_to_non_nullable
as int?,groupSize: null == groupSize ? _self.groupSize : groupSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LibvirtHostPci].
extension LibvirtHostPciPatterns on LibvirtHostPci {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtHostPci value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtHostPci() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtHostPci value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtHostPci():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtHostPci value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtHostPci() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String address,  String? vendor,  String? product,  String? vendorName,  String? productName, @JsonKey(name: 'class')  String? pciClass,  int? iommuGroup,  int groupSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtHostPci() when $default != null:
return $default(_that.address,_that.vendor,_that.product,_that.vendorName,_that.productName,_that.pciClass,_that.iommuGroup,_that.groupSize);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String address,  String? vendor,  String? product,  String? vendorName,  String? productName, @JsonKey(name: 'class')  String? pciClass,  int? iommuGroup,  int groupSize)  $default,) {final _that = this;
switch (_that) {
case _LibvirtHostPci():
return $default(_that.address,_that.vendor,_that.product,_that.vendorName,_that.productName,_that.pciClass,_that.iommuGroup,_that.groupSize);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String address,  String? vendor,  String? product,  String? vendorName,  String? productName, @JsonKey(name: 'class')  String? pciClass,  int? iommuGroup,  int groupSize)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtHostPci() when $default != null:
return $default(_that.address,_that.vendor,_that.product,_that.vendorName,_that.productName,_that.pciClass,_that.iommuGroup,_that.groupSize);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtHostPci implements LibvirtHostPci {
  const _LibvirtHostPci({required this.address, this.vendor, this.product, this.vendorName, this.productName, @JsonKey(name: 'class') this.pciClass, this.iommuGroup, this.groupSize = 0});
  factory _LibvirtHostPci.fromJson(Map<String, dynamic> json) => _$LibvirtHostPciFromJson(json);

@override final  String address;
@override final  String? vendor;
@override final  String? product;
@override final  String? vendorName;
@override final  String? productName;
@override@JsonKey(name: 'class') final  String? pciClass;
@override final  int? iommuGroup;
@override@JsonKey() final  int groupSize;

/// Create a copy of LibvirtHostPci
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtHostPciCopyWith<_LibvirtHostPci> get copyWith => __$LibvirtHostPciCopyWithImpl<_LibvirtHostPci>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtHostPciToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtHostPci&&(identical(other.address, address) || other.address == address)&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.product, product) || other.product == product)&&(identical(other.vendorName, vendorName) || other.vendorName == vendorName)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.pciClass, pciClass) || other.pciClass == pciClass)&&(identical(other.iommuGroup, iommuGroup) || other.iommuGroup == iommuGroup)&&(identical(other.groupSize, groupSize) || other.groupSize == groupSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,address,vendor,product,vendorName,productName,pciClass,iommuGroup,groupSize);

@override
String toString() {
  return 'LibvirtHostPci(address: $address, vendor: $vendor, product: $product, vendorName: $vendorName, productName: $productName, pciClass: $pciClass, iommuGroup: $iommuGroup, groupSize: $groupSize)';
}


}

/// @nodoc
abstract mixin class _$LibvirtHostPciCopyWith<$Res> implements $LibvirtHostPciCopyWith<$Res> {
  factory _$LibvirtHostPciCopyWith(_LibvirtHostPci value, $Res Function(_LibvirtHostPci) _then) = __$LibvirtHostPciCopyWithImpl;
@override @useResult
$Res call({
 String address, String? vendor, String? product, String? vendorName, String? productName,@JsonKey(name: 'class') String? pciClass, int? iommuGroup, int groupSize
});




}
/// @nodoc
class __$LibvirtHostPciCopyWithImpl<$Res>
    implements _$LibvirtHostPciCopyWith<$Res> {
  __$LibvirtHostPciCopyWithImpl(this._self, this._then);

  final _LibvirtHostPci _self;
  final $Res Function(_LibvirtHostPci) _then;

/// Create a copy of LibvirtHostPci
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? address = null,Object? vendor = freezed,Object? product = freezed,Object? vendorName = freezed,Object? productName = freezed,Object? pciClass = freezed,Object? iommuGroup = freezed,Object? groupSize = null,}) {
  return _then(_LibvirtHostPci(
address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,vendor: freezed == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String?,product: freezed == product ? _self.product : product // ignore: cast_nullable_to_non_nullable
as String?,vendorName: freezed == vendorName ? _self.vendorName : vendorName // ignore: cast_nullable_to_non_nullable
as String?,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,pciClass: freezed == pciClass ? _self.pciClass : pciClass // ignore: cast_nullable_to_non_nullable
as String?,iommuGroup: freezed == iommuGroup ? _self.iommuGroup : iommuGroup // ignore: cast_nullable_to_non_nullable
as int?,groupSize: null == groupSize ? _self.groupSize : groupSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$LibvirtHardwareInfo {

 LibvirtHwConfig get config; LibvirtHwConfig? get live;/// The persistent definition with its secrets (`--security-info`): what
/// a change is made from and compared against. Never shown.
 String get configXml;/// [configXml] with its secrets redacted: what the view shows.
 String get configText;/// `dumpxml` (the running definition) as read; empty while the domain
/// is not running. What a revert to the running definition is made
/// from.
 String get liveXml; bool get autostart; String? get description; int? get hostCpus; int? get hostMemoryKib; LibvirtHwCaps? get caps;/// QEMU's firmware descriptors: what the host can boot with, and which
/// carry Secure Boot's enrolled keys.
 List<LibvirtFirmware> get firmware;
/// Create a copy of LibvirtHardwareInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibvirtHardwareInfoCopyWith<LibvirtHardwareInfo> get copyWith => _$LibvirtHardwareInfoCopyWithImpl<LibvirtHardwareInfo>(this as LibvirtHardwareInfo, _$identity);

  /// Serializes this LibvirtHardwareInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibvirtHardwareInfo&&(identical(other.config, config) || other.config == config)&&(identical(other.live, live) || other.live == live)&&(identical(other.configXml, configXml) || other.configXml == configXml)&&(identical(other.configText, configText) || other.configText == configText)&&(identical(other.liveXml, liveXml) || other.liveXml == liveXml)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&(identical(other.description, description) || other.description == description)&&(identical(other.hostCpus, hostCpus) || other.hostCpus == hostCpus)&&(identical(other.hostMemoryKib, hostMemoryKib) || other.hostMemoryKib == hostMemoryKib)&&(identical(other.caps, caps) || other.caps == caps)&&const DeepCollectionEquality().equals(other.firmware, firmware));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,config,live,configXml,configText,liveXml,autostart,description,hostCpus,hostMemoryKib,caps,const DeepCollectionEquality().hash(firmware));



}

/// @nodoc
abstract mixin class $LibvirtHardwareInfoCopyWith<$Res>  {
  factory $LibvirtHardwareInfoCopyWith(LibvirtHardwareInfo value, $Res Function(LibvirtHardwareInfo) _then) = _$LibvirtHardwareInfoCopyWithImpl;
@useResult
$Res call({
 LibvirtHwConfig config, LibvirtHwConfig? live, String configXml, String configText, String liveXml, bool autostart, String? description, int? hostCpus, int? hostMemoryKib, LibvirtHwCaps? caps, List<LibvirtFirmware> firmware
});


$LibvirtHwConfigCopyWith<$Res> get config;$LibvirtHwConfigCopyWith<$Res>? get live;$LibvirtHwCapsCopyWith<$Res>? get caps;

}
/// @nodoc
class _$LibvirtHardwareInfoCopyWithImpl<$Res>
    implements $LibvirtHardwareInfoCopyWith<$Res> {
  _$LibvirtHardwareInfoCopyWithImpl(this._self, this._then);

  final LibvirtHardwareInfo _self;
  final $Res Function(LibvirtHardwareInfo) _then;

/// Create a copy of LibvirtHardwareInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? config = null,Object? live = freezed,Object? configXml = null,Object? configText = null,Object? liveXml = null,Object? autostart = null,Object? description = freezed,Object? hostCpus = freezed,Object? hostMemoryKib = freezed,Object? caps = freezed,Object? firmware = null,}) {
  return _then(_self.copyWith(
config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as LibvirtHwConfig,live: freezed == live ? _self.live : live // ignore: cast_nullable_to_non_nullable
as LibvirtHwConfig?,configXml: null == configXml ? _self.configXml : configXml // ignore: cast_nullable_to_non_nullable
as String,configText: null == configText ? _self.configText : configText // ignore: cast_nullable_to_non_nullable
as String,liveXml: null == liveXml ? _self.liveXml : liveXml // ignore: cast_nullable_to_non_nullable
as String,autostart: null == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,hostCpus: freezed == hostCpus ? _self.hostCpus : hostCpus // ignore: cast_nullable_to_non_nullable
as int?,hostMemoryKib: freezed == hostMemoryKib ? _self.hostMemoryKib : hostMemoryKib // ignore: cast_nullable_to_non_nullable
as int?,caps: freezed == caps ? _self.caps : caps // ignore: cast_nullable_to_non_nullable
as LibvirtHwCaps?,firmware: null == firmware ? _self.firmware : firmware // ignore: cast_nullable_to_non_nullable
as List<LibvirtFirmware>,
  ));
}
/// Create a copy of LibvirtHardwareInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtHwConfigCopyWith<$Res> get config {
  
  return $LibvirtHwConfigCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}/// Create a copy of LibvirtHardwareInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtHwConfigCopyWith<$Res>? get live {
    if (_self.live == null) {
    return null;
  }

  return $LibvirtHwConfigCopyWith<$Res>(_self.live!, (value) {
    return _then(_self.copyWith(live: value));
  });
}/// Create a copy of LibvirtHardwareInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtHwCapsCopyWith<$Res>? get caps {
    if (_self.caps == null) {
    return null;
  }

  return $LibvirtHwCapsCopyWith<$Res>(_self.caps!, (value) {
    return _then(_self.copyWith(caps: value));
  });
}
}


/// Adds pattern-matching-related methods to [LibvirtHardwareInfo].
extension LibvirtHardwareInfoPatterns on LibvirtHardwareInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibvirtHardwareInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibvirtHardwareInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibvirtHardwareInfo value)  $default,){
final _that = this;
switch (_that) {
case _LibvirtHardwareInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibvirtHardwareInfo value)?  $default,){
final _that = this;
switch (_that) {
case _LibvirtHardwareInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LibvirtHwConfig config,  LibvirtHwConfig? live,  String configXml,  String configText,  String liveXml,  bool autostart,  String? description,  int? hostCpus,  int? hostMemoryKib,  LibvirtHwCaps? caps,  List<LibvirtFirmware> firmware)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibvirtHardwareInfo() when $default != null:
return $default(_that.config,_that.live,_that.configXml,_that.configText,_that.liveXml,_that.autostart,_that.description,_that.hostCpus,_that.hostMemoryKib,_that.caps,_that.firmware);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LibvirtHwConfig config,  LibvirtHwConfig? live,  String configXml,  String configText,  String liveXml,  bool autostart,  String? description,  int? hostCpus,  int? hostMemoryKib,  LibvirtHwCaps? caps,  List<LibvirtFirmware> firmware)  $default,) {final _that = this;
switch (_that) {
case _LibvirtHardwareInfo():
return $default(_that.config,_that.live,_that.configXml,_that.configText,_that.liveXml,_that.autostart,_that.description,_that.hostCpus,_that.hostMemoryKib,_that.caps,_that.firmware);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LibvirtHwConfig config,  LibvirtHwConfig? live,  String configXml,  String configText,  String liveXml,  bool autostart,  String? description,  int? hostCpus,  int? hostMemoryKib,  LibvirtHwCaps? caps,  List<LibvirtFirmware> firmware)?  $default,) {final _that = this;
switch (_that) {
case _LibvirtHardwareInfo() when $default != null:
return $default(_that.config,_that.live,_that.configXml,_that.configText,_that.liveXml,_that.autostart,_that.description,_that.hostCpus,_that.hostMemoryKib,_that.caps,_that.firmware);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LibvirtHardwareInfo extends LibvirtHardwareInfo {
  const _LibvirtHardwareInfo({required this.config, this.live, required this.configXml, this.configText = '', this.liveXml = '', this.autostart = false, this.description, this.hostCpus, this.hostMemoryKib, this.caps, final  List<LibvirtFirmware> firmware = const <LibvirtFirmware>[]}): _firmware = firmware,super._();
  factory _LibvirtHardwareInfo.fromJson(Map<String, dynamic> json) => _$LibvirtHardwareInfoFromJson(json);

@override final  LibvirtHwConfig config;
@override final  LibvirtHwConfig? live;
/// The persistent definition with its secrets (`--security-info`): what
/// a change is made from and compared against. Never shown.
@override final  String configXml;
/// [configXml] with its secrets redacted: what the view shows.
@override@JsonKey() final  String configText;
/// `dumpxml` (the running definition) as read; empty while the domain
/// is not running. What a revert to the running definition is made
/// from.
@override@JsonKey() final  String liveXml;
@override@JsonKey() final  bool autostart;
@override final  String? description;
@override final  int? hostCpus;
@override final  int? hostMemoryKib;
@override final  LibvirtHwCaps? caps;
/// QEMU's firmware descriptors: what the host can boot with, and which
/// carry Secure Boot's enrolled keys.
 final  List<LibvirtFirmware> _firmware;
/// QEMU's firmware descriptors: what the host can boot with, and which
/// carry Secure Boot's enrolled keys.
@override@JsonKey() List<LibvirtFirmware> get firmware {
  if (_firmware is EqualUnmodifiableListView) return _firmware;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_firmware);
}


/// Create a copy of LibvirtHardwareInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibvirtHardwareInfoCopyWith<_LibvirtHardwareInfo> get copyWith => __$LibvirtHardwareInfoCopyWithImpl<_LibvirtHardwareInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibvirtHardwareInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibvirtHardwareInfo&&(identical(other.config, config) || other.config == config)&&(identical(other.live, live) || other.live == live)&&(identical(other.configXml, configXml) || other.configXml == configXml)&&(identical(other.configText, configText) || other.configText == configText)&&(identical(other.liveXml, liveXml) || other.liveXml == liveXml)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&(identical(other.description, description) || other.description == description)&&(identical(other.hostCpus, hostCpus) || other.hostCpus == hostCpus)&&(identical(other.hostMemoryKib, hostMemoryKib) || other.hostMemoryKib == hostMemoryKib)&&(identical(other.caps, caps) || other.caps == caps)&&const DeepCollectionEquality().equals(other._firmware, _firmware));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,config,live,configXml,configText,liveXml,autostart,description,hostCpus,hostMemoryKib,caps,const DeepCollectionEquality().hash(_firmware));



}

/// @nodoc
abstract mixin class _$LibvirtHardwareInfoCopyWith<$Res> implements $LibvirtHardwareInfoCopyWith<$Res> {
  factory _$LibvirtHardwareInfoCopyWith(_LibvirtHardwareInfo value, $Res Function(_LibvirtHardwareInfo) _then) = __$LibvirtHardwareInfoCopyWithImpl;
@override @useResult
$Res call({
 LibvirtHwConfig config, LibvirtHwConfig? live, String configXml, String configText, String liveXml, bool autostart, String? description, int? hostCpus, int? hostMemoryKib, LibvirtHwCaps? caps, List<LibvirtFirmware> firmware
});


@override $LibvirtHwConfigCopyWith<$Res> get config;@override $LibvirtHwConfigCopyWith<$Res>? get live;@override $LibvirtHwCapsCopyWith<$Res>? get caps;

}
/// @nodoc
class __$LibvirtHardwareInfoCopyWithImpl<$Res>
    implements _$LibvirtHardwareInfoCopyWith<$Res> {
  __$LibvirtHardwareInfoCopyWithImpl(this._self, this._then);

  final _LibvirtHardwareInfo _self;
  final $Res Function(_LibvirtHardwareInfo) _then;

/// Create a copy of LibvirtHardwareInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? config = null,Object? live = freezed,Object? configXml = null,Object? configText = null,Object? liveXml = null,Object? autostart = null,Object? description = freezed,Object? hostCpus = freezed,Object? hostMemoryKib = freezed,Object? caps = freezed,Object? firmware = null,}) {
  return _then(_LibvirtHardwareInfo(
config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as LibvirtHwConfig,live: freezed == live ? _self.live : live // ignore: cast_nullable_to_non_nullable
as LibvirtHwConfig?,configXml: null == configXml ? _self.configXml : configXml // ignore: cast_nullable_to_non_nullable
as String,configText: null == configText ? _self.configText : configText // ignore: cast_nullable_to_non_nullable
as String,liveXml: null == liveXml ? _self.liveXml : liveXml // ignore: cast_nullable_to_non_nullable
as String,autostart: null == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,hostCpus: freezed == hostCpus ? _self.hostCpus : hostCpus // ignore: cast_nullable_to_non_nullable
as int?,hostMemoryKib: freezed == hostMemoryKib ? _self.hostMemoryKib : hostMemoryKib // ignore: cast_nullable_to_non_nullable
as int?,caps: freezed == caps ? _self.caps : caps // ignore: cast_nullable_to_non_nullable
as LibvirtHwCaps?,firmware: null == firmware ? _self._firmware : firmware // ignore: cast_nullable_to_non_nullable
as List<LibvirtFirmware>,
  ));
}

/// Create a copy of LibvirtHardwareInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtHwConfigCopyWith<$Res> get config {
  
  return $LibvirtHwConfigCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}/// Create a copy of LibvirtHardwareInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtHwConfigCopyWith<$Res>? get live {
    if (_self.live == null) {
    return null;
  }

  return $LibvirtHwConfigCopyWith<$Res>(_self.live!, (value) {
    return _then(_self.copyWith(live: value));
  });
}/// Create a copy of LibvirtHardwareInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibvirtHwCapsCopyWith<$Res>? get caps {
    if (_self.caps == null) {
    return null;
  }

  return $LibvirtHwCapsCopyWith<$Res>(_self.caps!, (value) {
    return _then(_self.copyWith(caps: value));
  });
}
}

// dart format on
