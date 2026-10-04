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

// dart format on
