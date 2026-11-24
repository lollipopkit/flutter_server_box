// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bmc_target.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BmcTarget {

 String get id; String get name;/// Base URL, e.g. `https://10.0.0.9`.
 String get addr;/// Referenced [BmcCredential.id], or null when unset / deleted.
 String? get credId;/// Pinned leaf certificate SHA-256 (lowercase hex), or null until reviewed.
 String? get certSha256;/// Linked [Spi.id], or null for a standalone BMC target.
 String? get serverId; List<String>? get tags;
/// Create a copy of BmcTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BmcTargetCopyWith<BmcTarget> get copyWith => _$BmcTargetCopyWithImpl<BmcTarget>(this as BmcTarget, _$identity);

  /// Serializes this BmcTarget to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BmcTarget;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BmcTarget&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.addr, _this.addr) || other.addr == _this.addr)&&(identical(other.credId, _this.credId) || other.credId == _this.credId)&&(identical(other.certSha256, _this.certSha256) || other.certSha256 == _this.certSha256)&&(identical(other.serverId, _this.serverId) || other.serverId == _this.serverId)&&const DeepCollectionEquality().equals(other.tags, _this.tags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BmcTarget;
  return Object.hash(runtimeType,_this.id,_this.name,_this.addr,_this.credId,_this.certSha256,_this.serverId,const DeepCollectionEquality().hash(_this.tags));
}

@override
String toString() {
  final _this = this as BmcTarget;
  return 'BmcTarget(id: ${_this.id}, name: ${_this.name}, addr: ${_this.addr}, credId: ${_this.credId}, certSha256: ${_this.certSha256}, serverId: ${_this.serverId}, tags: ${_this.tags})';
}


}

/// @nodoc
abstract mixin class $BmcTargetCopyWith<$Res>  {
  factory $BmcTargetCopyWith(BmcTarget value, $Res Function(BmcTarget) _then) = _$BmcTargetCopyWithImpl;
@useResult
$Res call({
 String id, String name, String addr, String? credId, String? certSha256, String? serverId, List<String>? tags
});




}
/// @nodoc
class _$BmcTargetCopyWithImpl<$Res>
    implements $BmcTargetCopyWith<$Res> {
  _$BmcTargetCopyWithImpl(this._self, this._then);

  final BmcTarget _self;
  final $Res Function(BmcTarget) _then;

/// Create a copy of BmcTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? addr = null,Object? credId = freezed,Object? certSha256 = freezed,Object? serverId = freezed,Object? tags = freezed,}) {
  return _then(BmcTarget(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,addr: null == addr ? _self.addr : addr // ignore: cast_nullable_to_non_nullable
as String,credId: freezed == credId ? _self.credId : credId // ignore: cast_nullable_to_non_nullable
as String?,certSha256: freezed == certSha256 ? _self.certSha256 : certSha256 // ignore: cast_nullable_to_non_nullable
as String?,serverId: freezed == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String?,tags: freezed == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}

}


/// Adds pattern-matching-related methods to [BmcTarget].
extension BmcTargetPatterns on BmcTarget {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BmcTarget value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BmcTarget() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BmcTarget value)  $default,){
final _that = this;
switch (_that) {
case _BmcTarget():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BmcTarget value)?  $default,){
final _that = this;
switch (_that) {
case _BmcTarget() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String addr,  String? credId,  String? certSha256,  String? serverId,  List<String>? tags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BmcTarget() when $default != null:
return $default(_that.id,_that.name,_that.addr,_that.credId,_that.certSha256,_that.serverId,_that.tags);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String addr,  String? credId,  String? certSha256,  String? serverId,  List<String>? tags)  $default,) {final _that = this;
switch (_that) {
case _BmcTarget():
return $default(_that.id,_that.name,_that.addr,_that.credId,_that.certSha256,_that.serverId,_that.tags);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String addr,  String? credId,  String? certSha256,  String? serverId,  List<String>? tags)?  $default,) {final _that = this;
switch (_that) {
case _BmcTarget() when $default != null:
return $default(_that.id,_that.name,_that.addr,_that.credId,_that.certSha256,_that.serverId,_that.tags);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _BmcTarget extends BmcTarget {
  const _BmcTarget({required this.id, required this.name, required this.addr, this.credId, this.certSha256, this.serverId,  List<String>? tags}): _tags = tags,super._();
  factory _BmcTarget.fromJson(Map<String, dynamic> json) => _$BmcTargetFromJson(json);

@override final  String id;
@override final  String name;
/// Base URL, e.g. `https://10.0.0.9`.
@override final  String addr;
/// Referenced [BmcCredential.id], or null when unset / deleted.
@override final  String? credId;
/// Pinned leaf certificate SHA-256 (lowercase hex), or null until reviewed.
@override final  String? certSha256;
/// Linked [Spi.id], or null for a standalone BMC target.
@override final  String? serverId;
 final  List<String>? _tags;
@override List<String>? get tags {
  final value = _tags;
  if (value == null) return null;
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of BmcTarget
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BmcTargetCopyWith<_BmcTarget> get copyWith => __$BmcTargetCopyWithImpl<_BmcTarget>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BmcTargetToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BmcTarget&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.addr, addr) || other.addr == addr)&&(identical(other.credId, credId) || other.credId == credId)&&(identical(other.certSha256, certSha256) || other.certSha256 == certSha256)&&(identical(other.serverId, serverId) || other.serverId == serverId)&&const DeepCollectionEquality().equals(other.tags, _tags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,addr,credId,certSha256,serverId,const DeepCollectionEquality().hash(_tags));
}

@override
String toString() {
    return 'BmcTarget(id: $id, name: $name, addr: $addr, credId: $credId, certSha256: $certSha256, serverId: $serverId, tags: $tags)';
}


}

/// @nodoc
abstract mixin class _$BmcTargetCopyWith<$Res> implements $BmcTargetCopyWith<$Res> {
  factory _$BmcTargetCopyWith(_BmcTarget value, $Res Function(_BmcTarget) _then) = __$BmcTargetCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String addr, String? credId, String? certSha256, String? serverId, List<String>? tags
});




}
/// @nodoc
class __$BmcTargetCopyWithImpl<$Res>
    implements _$BmcTargetCopyWith<$Res> {
  __$BmcTargetCopyWithImpl(this._self, this._then);

  final _BmcTarget _self;
  final $Res Function(_BmcTarget) _then;

/// Create a copy of BmcTarget
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? addr = null,Object? credId = freezed,Object? certSha256 = freezed,Object? serverId = freezed,Object? tags = freezed,}) {
  return _then(_BmcTarget(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,addr: null == addr ? _self.addr : addr // ignore: cast_nullable_to_non_nullable
as String,credId: freezed == credId ? _self.credId : credId // ignore: cast_nullable_to_non_nullable
as String?,certSha256: freezed == certSha256 ? _self.certSha256 : certSha256 // ignore: cast_nullable_to_non_nullable
as String?,serverId: freezed == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String?,tags: freezed == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}


}

// dart format on
