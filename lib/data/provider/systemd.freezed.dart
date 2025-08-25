// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'systemd.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SystemdState {

 bool get isBusy; List<SystemdUnit> get units; SystemdScopeFilter get scopeFilter;
/// Create a copy of SystemdState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SystemdStateCopyWith<SystemdState> get copyWith => _$SystemdStateCopyWithImpl<SystemdState>(this as SystemdState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SystemdState&&(identical(other.isBusy, isBusy) || other.isBusy == isBusy)&&const DeepCollectionEquality().equals(other.units, units)&&(identical(other.scopeFilter, scopeFilter) || other.scopeFilter == scopeFilter));
}


@override
int get hashCode => Object.hash(runtimeType,isBusy,const DeepCollectionEquality().hash(units),scopeFilter);

@override
String toString() {
  return 'SystemdState(isBusy: $isBusy, units: $units, scopeFilter: $scopeFilter)';
}


}

/// @nodoc
abstract mixin class $SystemdStateCopyWith<$Res>  {
  factory $SystemdStateCopyWith(SystemdState value, $Res Function(SystemdState) _then) = _$SystemdStateCopyWithImpl;
@useResult
$Res call({
 bool isBusy, List<SystemdUnit> units, SystemdScopeFilter scopeFilter
});




}
/// @nodoc
class _$SystemdStateCopyWithImpl<$Res>
    implements $SystemdStateCopyWith<$Res> {
  _$SystemdStateCopyWithImpl(this._self, this._then);

  final SystemdState _self;
  final $Res Function(SystemdState) _then;

/// Create a copy of SystemdState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isBusy = null,Object? units = null,Object? scopeFilter = null,}) {
  return _then(_self.copyWith(
isBusy: null == isBusy ? _self.isBusy : isBusy // ignore: cast_nullable_to_non_nullable
as bool,units: null == units ? _self.units : units // ignore: cast_nullable_to_non_nullable
as List<SystemdUnit>,scopeFilter: null == scopeFilter ? _self.scopeFilter : scopeFilter // ignore: cast_nullable_to_non_nullable
as SystemdScopeFilter,
  ));
}

}


/// Adds pattern-matching-related methods to [SystemdState].
extension SystemdStatePatterns on SystemdState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SystemdState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SystemdState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SystemdState value)  $default,){
final _that = this;
switch (_that) {
case _SystemdState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SystemdState value)?  $default,){
final _that = this;
switch (_that) {
case _SystemdState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isBusy,  List<SystemdUnit> units,  SystemdScopeFilter scopeFilter)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SystemdState() when $default != null:
return $default(_that.isBusy,_that.units,_that.scopeFilter);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isBusy,  List<SystemdUnit> units,  SystemdScopeFilter scopeFilter)  $default,) {final _that = this;
switch (_that) {
case _SystemdState():
return $default(_that.isBusy,_that.units,_that.scopeFilter);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isBusy,  List<SystemdUnit> units,  SystemdScopeFilter scopeFilter)?  $default,) {final _that = this;
switch (_that) {
case _SystemdState() when $default != null:
return $default(_that.isBusy,_that.units,_that.scopeFilter);case _:
  return null;

}
}

}

/// @nodoc


class _SystemdState implements SystemdState {
  const _SystemdState({this.isBusy = false, final  List<SystemdUnit> units = const <SystemdUnit>[], this.scopeFilter = SystemdScopeFilter.all}): _units = units;
  

@override@JsonKey() final  bool isBusy;
 final  List<SystemdUnit> _units;
@override@JsonKey() List<SystemdUnit> get units {
  if (_units is EqualUnmodifiableListView) return _units;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_units);
}

@override@JsonKey() final  SystemdScopeFilter scopeFilter;

/// Create a copy of SystemdState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SystemdStateCopyWith<_SystemdState> get copyWith => __$SystemdStateCopyWithImpl<_SystemdState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SystemdState&&(identical(other.isBusy, isBusy) || other.isBusy == isBusy)&&const DeepCollectionEquality().equals(other._units, _units)&&(identical(other.scopeFilter, scopeFilter) || other.scopeFilter == scopeFilter));
}


@override
int get hashCode => Object.hash(runtimeType,isBusy,const DeepCollectionEquality().hash(_units),scopeFilter);

@override
String toString() {
  return 'SystemdState(isBusy: $isBusy, units: $units, scopeFilter: $scopeFilter)';
}


}

/// @nodoc
abstract mixin class _$SystemdStateCopyWith<$Res> implements $SystemdStateCopyWith<$Res> {
  factory _$SystemdStateCopyWith(_SystemdState value, $Res Function(_SystemdState) _then) = __$SystemdStateCopyWithImpl;
@override @useResult
$Res call({
 bool isBusy, List<SystemdUnit> units, SystemdScopeFilter scopeFilter
});




}
/// @nodoc
class __$SystemdStateCopyWithImpl<$Res>
    implements _$SystemdStateCopyWith<$Res> {
  __$SystemdStateCopyWithImpl(this._self, this._then);

  final _SystemdState _self;
  final $Res Function(_SystemdState) _then;

/// Create a copy of SystemdState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isBusy = null,Object? units = null,Object? scopeFilter = null,}) {
  return _then(_SystemdState(
isBusy: null == isBusy ? _self.isBusy : isBusy // ignore: cast_nullable_to_non_nullable
as bool,units: null == units ? _self._units : units // ignore: cast_nullable_to_non_nullable
as List<SystemdUnit>,scopeFilter: null == scopeFilter ? _self.scopeFilter : scopeFilter // ignore: cast_nullable_to_non_nullable
as SystemdScopeFilter,
  ));
}


}

// dart format on
