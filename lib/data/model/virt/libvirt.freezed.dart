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

// dart format on
