// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'container.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ContainerState {

 List<ContainerPs>? get items; List<ContainerImg>? get images; String? get version; List<ContainerErr> get errors; String? get runLog; ContainerType get type; bool get isBusy;
/// Create a copy of ContainerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContainerStateCopyWith<ContainerState> get copyWith => _$ContainerStateCopyWithImpl<ContainerState>(this as ContainerState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ContainerState&&const DeepCollectionEquality().equals(other.items, items)&&const DeepCollectionEquality().equals(other.images, images)&&(identical(other.version, version) || other.version == version)&&const DeepCollectionEquality().equals(other.errors, errors)&&(identical(other.runLog, runLog) || other.runLog == runLog)&&(identical(other.type, type) || other.type == type)&&(identical(other.isBusy, isBusy) || other.isBusy == isBusy));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),const DeepCollectionEquality().hash(images),version,const DeepCollectionEquality().hash(errors),runLog,type,isBusy);

@override
String toString() {
  return 'ContainerState(items: $items, images: $images, version: $version, errors: $errors, runLog: $runLog, type: $type, isBusy: $isBusy)';
}


}

/// @nodoc
abstract mixin class $ContainerStateCopyWith<$Res>  {
  factory $ContainerStateCopyWith(ContainerState value, $Res Function(ContainerState) _then) = _$ContainerStateCopyWithImpl;
@useResult
$Res call({
 List<ContainerPs>? items, List<ContainerImg>? images, String? version, List<ContainerErr> errors, String? runLog, ContainerType type, bool isBusy
});




}
/// @nodoc
class _$ContainerStateCopyWithImpl<$Res>
    implements $ContainerStateCopyWith<$Res> {
  _$ContainerStateCopyWithImpl(this._self, this._then);

  final ContainerState _self;
  final $Res Function(ContainerState) _then;

/// Create a copy of ContainerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = freezed,Object? images = freezed,Object? version = freezed,Object? errors = null,Object? runLog = freezed,Object? type = null,Object? isBusy = null,}) {
  return _then(_self.copyWith(
items: freezed == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<ContainerPs>?,images: freezed == images ? _self.images : images // ignore: cast_nullable_to_non_nullable
as List<ContainerImg>?,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,errors: null == errors ? _self.errors : errors // ignore: cast_nullable_to_non_nullable
as List<ContainerErr>,runLog: freezed == runLog ? _self.runLog : runLog // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ContainerType,isBusy: null == isBusy ? _self.isBusy : isBusy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ContainerState].
extension ContainerStatePatterns on ContainerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ContainerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ContainerState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ContainerState value)  $default,){
final _that = this;
switch (_that) {
case _ContainerState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ContainerState value)?  $default,){
final _that = this;
switch (_that) {
case _ContainerState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ContainerPs>? items,  List<ContainerImg>? images,  String? version,  List<ContainerErr> errors,  String? runLog,  ContainerType type,  bool isBusy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ContainerState() when $default != null:
return $default(_that.items,_that.images,_that.version,_that.errors,_that.runLog,_that.type,_that.isBusy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ContainerPs>? items,  List<ContainerImg>? images,  String? version,  List<ContainerErr> errors,  String? runLog,  ContainerType type,  bool isBusy)  $default,) {final _that = this;
switch (_that) {
case _ContainerState():
return $default(_that.items,_that.images,_that.version,_that.errors,_that.runLog,_that.type,_that.isBusy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ContainerPs>? items,  List<ContainerImg>? images,  String? version,  List<ContainerErr> errors,  String? runLog,  ContainerType type,  bool isBusy)?  $default,) {final _that = this;
switch (_that) {
case _ContainerState() when $default != null:
return $default(_that.items,_that.images,_that.version,_that.errors,_that.runLog,_that.type,_that.isBusy);case _:
  return null;

}
}

}

/// @nodoc


class _ContainerState implements ContainerState {
  const _ContainerState({final  List<ContainerPs>? items = null, final  List<ContainerImg>? images = null, this.version = null, final  List<ContainerErr> errors = const <ContainerErr>[], this.runLog = null, this.type = ContainerType.docker, this.isBusy = false}): _items = items,_images = images,_errors = errors;
  

 final  List<ContainerPs>? _items;
@override@JsonKey() List<ContainerPs>? get items {
  final value = _items;
  if (value == null) return null;
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<ContainerImg>? _images;
@override@JsonKey() List<ContainerImg>? get images {
  final value = _images;
  if (value == null) return null;
  if (_images is EqualUnmodifiableListView) return _images;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey() final  String? version;
 final  List<ContainerErr> _errors;
@override@JsonKey() List<ContainerErr> get errors {
  if (_errors is EqualUnmodifiableListView) return _errors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_errors);
}

@override@JsonKey() final  String? runLog;
@override@JsonKey() final  ContainerType type;
@override@JsonKey() final  bool isBusy;

/// Create a copy of ContainerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContainerStateCopyWith<_ContainerState> get copyWith => __$ContainerStateCopyWithImpl<_ContainerState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ContainerState&&const DeepCollectionEquality().equals(other._items, _items)&&const DeepCollectionEquality().equals(other._images, _images)&&(identical(other.version, version) || other.version == version)&&const DeepCollectionEquality().equals(other._errors, _errors)&&(identical(other.runLog, runLog) || other.runLog == runLog)&&(identical(other.type, type) || other.type == type)&&(identical(other.isBusy, isBusy) || other.isBusy == isBusy));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),const DeepCollectionEquality().hash(_images),version,const DeepCollectionEquality().hash(_errors),runLog,type,isBusy);

@override
String toString() {
  return 'ContainerState(items: $items, images: $images, version: $version, errors: $errors, runLog: $runLog, type: $type, isBusy: $isBusy)';
}


}

/// @nodoc
abstract mixin class _$ContainerStateCopyWith<$Res> implements $ContainerStateCopyWith<$Res> {
  factory _$ContainerStateCopyWith(_ContainerState value, $Res Function(_ContainerState) _then) = __$ContainerStateCopyWithImpl;
@override @useResult
$Res call({
 List<ContainerPs>? items, List<ContainerImg>? images, String? version, List<ContainerErr> errors, String? runLog, ContainerType type, bool isBusy
});




}
/// @nodoc
class __$ContainerStateCopyWithImpl<$Res>
    implements _$ContainerStateCopyWith<$Res> {
  __$ContainerStateCopyWithImpl(this._self, this._then);

  final _ContainerState _self;
  final $Res Function(_ContainerState) _then;

/// Create a copy of ContainerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = freezed,Object? images = freezed,Object? version = freezed,Object? errors = null,Object? runLog = freezed,Object? type = null,Object? isBusy = null,}) {
  return _then(_ContainerState(
items: freezed == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<ContainerPs>?,images: freezed == images ? _self._images : images // ignore: cast_nullable_to_non_nullable
as List<ContainerImg>?,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,errors: null == errors ? _self._errors : errors // ignore: cast_nullable_to_non_nullable
as List<ContainerErr>,runLog: freezed == runLog ? _self.runLog : runLog // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ContainerType,isBusy: null == isBusy ? _self.isBusy : isBusy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
