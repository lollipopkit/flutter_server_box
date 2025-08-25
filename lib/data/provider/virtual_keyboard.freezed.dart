// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'virtual_keyboard.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VirtKeyState {

 bool get ctrl; bool get alt; bool get shift;
/// Create a copy of VirtKeyState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtKeyStateCopyWith<VirtKeyState> get copyWith => _$VirtKeyStateCopyWithImpl<VirtKeyState>(this as VirtKeyState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtKeyState&&(identical(other.ctrl, ctrl) || other.ctrl == ctrl)&&(identical(other.alt, alt) || other.alt == alt)&&(identical(other.shift, shift) || other.shift == shift));
}


@override
int get hashCode => Object.hash(runtimeType,ctrl,alt,shift);

@override
String toString() {
  return 'VirtKeyState(ctrl: $ctrl, alt: $alt, shift: $shift)';
}


}

/// @nodoc
abstract mixin class $VirtKeyStateCopyWith<$Res>  {
  factory $VirtKeyStateCopyWith(VirtKeyState value, $Res Function(VirtKeyState) _then) = _$VirtKeyStateCopyWithImpl;
@useResult
$Res call({
 bool ctrl, bool alt, bool shift
});




}
/// @nodoc
class _$VirtKeyStateCopyWithImpl<$Res>
    implements $VirtKeyStateCopyWith<$Res> {
  _$VirtKeyStateCopyWithImpl(this._self, this._then);

  final VirtKeyState _self;
  final $Res Function(VirtKeyState) _then;

/// Create a copy of VirtKeyState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ctrl = null,Object? alt = null,Object? shift = null,}) {
  return _then(_self.copyWith(
ctrl: null == ctrl ? _self.ctrl : ctrl // ignore: cast_nullable_to_non_nullable
as bool,alt: null == alt ? _self.alt : alt // ignore: cast_nullable_to_non_nullable
as bool,shift: null == shift ? _self.shift : shift // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtKeyState].
extension VirtKeyStatePatterns on VirtKeyState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtKeyState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtKeyState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtKeyState value)  $default,){
final _that = this;
switch (_that) {
case _VirtKeyState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtKeyState value)?  $default,){
final _that = this;
switch (_that) {
case _VirtKeyState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool ctrl,  bool alt,  bool shift)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtKeyState() when $default != null:
return $default(_that.ctrl,_that.alt,_that.shift);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool ctrl,  bool alt,  bool shift)  $default,) {final _that = this;
switch (_that) {
case _VirtKeyState():
return $default(_that.ctrl,_that.alt,_that.shift);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool ctrl,  bool alt,  bool shift)?  $default,) {final _that = this;
switch (_that) {
case _VirtKeyState() when $default != null:
return $default(_that.ctrl,_that.alt,_that.shift);case _:
  return null;

}
}

}

/// @nodoc


class _VirtKeyState implements VirtKeyState {
  const _VirtKeyState({this.ctrl = false, this.alt = false, this.shift = false});
  

@override@JsonKey() final  bool ctrl;
@override@JsonKey() final  bool alt;
@override@JsonKey() final  bool shift;

/// Create a copy of VirtKeyState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtKeyStateCopyWith<_VirtKeyState> get copyWith => __$VirtKeyStateCopyWithImpl<_VirtKeyState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtKeyState&&(identical(other.ctrl, ctrl) || other.ctrl == ctrl)&&(identical(other.alt, alt) || other.alt == alt)&&(identical(other.shift, shift) || other.shift == shift));
}


@override
int get hashCode => Object.hash(runtimeType,ctrl,alt,shift);

@override
String toString() {
  return 'VirtKeyState(ctrl: $ctrl, alt: $alt, shift: $shift)';
}


}

/// @nodoc
abstract mixin class _$VirtKeyStateCopyWith<$Res> implements $VirtKeyStateCopyWith<$Res> {
  factory _$VirtKeyStateCopyWith(_VirtKeyState value, $Res Function(_VirtKeyState) _then) = __$VirtKeyStateCopyWithImpl;
@override @useResult
$Res call({
 bool ctrl, bool alt, bool shift
});




}
/// @nodoc
class __$VirtKeyStateCopyWithImpl<$Res>
    implements _$VirtKeyStateCopyWith<$Res> {
  __$VirtKeyStateCopyWithImpl(this._self, this._then);

  final _VirtKeyState _self;
  final $Res Function(_VirtKeyState) _then;

/// Create a copy of VirtKeyState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ctrl = null,Object? alt = null,Object? shift = null,}) {
  return _then(_VirtKeyState(
ctrl: null == ctrl ? _self.ctrl : ctrl // ignore: cast_nullable_to_non_nullable
as bool,alt: null == alt ? _self.alt : alt // ignore: cast_nullable_to_non_nullable
as bool,shift: null == shift ? _self.shift : shift // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
