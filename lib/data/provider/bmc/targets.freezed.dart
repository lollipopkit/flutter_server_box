// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'targets.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BmcTargetsState {

 Map<String, BmcTarget> get targets; List<String> get order; Set<String> get tags;
/// Create a copy of BmcTargetsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BmcTargetsStateCopyWith<BmcTargetsState> get copyWith => _$BmcTargetsStateCopyWithImpl<BmcTargetsState>(this as BmcTargetsState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BmcTargetsState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BmcTargetsState&&const DeepCollectionEquality().equals(other.targets, _this.targets)&&const DeepCollectionEquality().equals(other.order, _this.order)&&const DeepCollectionEquality().equals(other.tags, _this.tags));
}


@override
int get hashCode {
  final _this = this as BmcTargetsState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.targets),const DeepCollectionEquality().hash(_this.order),const DeepCollectionEquality().hash(_this.tags));
}

@override
String toString() {
  final _this = this as BmcTargetsState;
  return 'BmcTargetsState(targets: ${_this.targets}, order: ${_this.order}, tags: ${_this.tags})';
}


}

/// @nodoc
abstract mixin class $BmcTargetsStateCopyWith<$Res>  {
  factory $BmcTargetsStateCopyWith(BmcTargetsState value, $Res Function(BmcTargetsState) _then) = _$BmcTargetsStateCopyWithImpl;
@useResult
$Res call({
 Map<String, BmcTarget> targets, List<String> order, Set<String> tags
});




}
/// @nodoc
class _$BmcTargetsStateCopyWithImpl<$Res>
    implements $BmcTargetsStateCopyWith<$Res> {
  _$BmcTargetsStateCopyWithImpl(this._self, this._then);

  final BmcTargetsState _self;
  final $Res Function(BmcTargetsState) _then;

/// Create a copy of BmcTargetsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? targets = null,Object? order = null,Object? tags = null,}) {
  return _then(BmcTargetsState(
targets: null == targets ? _self.targets : targets // ignore: cast_nullable_to_non_nullable
as Map<String, BmcTarget>,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as List<String>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [BmcTargetsState].
extension BmcTargetsStatePatterns on BmcTargetsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BmcTargetsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BmcTargetsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BmcTargetsState value)  $default,){
final _that = this;
switch (_that) {
case _BmcTargetsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BmcTargetsState value)?  $default,){
final _that = this;
switch (_that) {
case _BmcTargetsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, BmcTarget> targets,  List<String> order,  Set<String> tags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BmcTargetsState() when $default != null:
return $default(_that.targets,_that.order,_that.tags);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, BmcTarget> targets,  List<String> order,  Set<String> tags)  $default,) {final _that = this;
switch (_that) {
case _BmcTargetsState():
return $default(_that.targets,_that.order,_that.tags);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, BmcTarget> targets,  List<String> order,  Set<String> tags)?  $default,) {final _that = this;
switch (_that) {
case _BmcTargetsState() when $default != null:
return $default(_that.targets,_that.order,_that.tags);case _:
  return null;

}
}

}

/// @nodoc


class _BmcTargetsState extends BmcTargetsState {
  const _BmcTargetsState({ Map<String, BmcTarget> targets = const <String, BmcTarget>{},  List<String> order = const <String>[],  Set<String> tags = const <String>{}}): _targets = targets,_order = order,_tags = tags,super._();
  

 final  Map<String, BmcTarget> _targets;
@override@JsonKey() Map<String, BmcTarget> get targets {
  if (_targets is EqualUnmodifiableMapView) return _targets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_targets);
}

 final  List<String> _order;
@override@JsonKey() List<String> get order {
  if (_order is EqualUnmodifiableListView) return _order;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_order);
}

 final  Set<String> _tags;
@override@JsonKey() Set<String> get tags {
  if (_tags is EqualUnmodifiableSetView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_tags);
}


/// Create a copy of BmcTargetsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BmcTargetsStateCopyWith<_BmcTargetsState> get copyWith => __$BmcTargetsStateCopyWithImpl<_BmcTargetsState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BmcTargetsState&&const DeepCollectionEquality().equals(other.targets, _targets)&&const DeepCollectionEquality().equals(other.order, _order)&&const DeepCollectionEquality().equals(other.tags, _tags));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_targets),const DeepCollectionEquality().hash(_order),const DeepCollectionEquality().hash(_tags));
}

@override
String toString() {
    return 'BmcTargetsState(targets: $targets, order: $order, tags: $tags)';
}


}

/// @nodoc
abstract mixin class _$BmcTargetsStateCopyWith<$Res> implements $BmcTargetsStateCopyWith<$Res> {
  factory _$BmcTargetsStateCopyWith(_BmcTargetsState value, $Res Function(_BmcTargetsState) _then) = __$BmcTargetsStateCopyWithImpl;
@override @useResult
$Res call({
 Map<String, BmcTarget> targets, List<String> order, Set<String> tags
});




}
/// @nodoc
class __$BmcTargetsStateCopyWithImpl<$Res>
    implements _$BmcTargetsStateCopyWith<$Res> {
  __$BmcTargetsStateCopyWithImpl(this._self, this._then);

  final _BmcTargetsState _self;
  final $Res Function(_BmcTargetsState) _then;

/// Create a copy of BmcTargetsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? targets = null,Object? order = null,Object? tags = null,}) {
  return _then(_BmcTargetsState(
targets: null == targets ? _self._targets : targets // ignore: cast_nullable_to_non_nullable
as Map<String, BmcTarget>,order: null == order ? _self._order : order // ignore: cast_nullable_to_non_nullable
as List<String>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}


}

// dart format on
