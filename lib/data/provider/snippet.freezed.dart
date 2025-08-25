// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'snippet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SnippetState {

 List<Snippet> get snippets; Set<String> get tags;
/// Create a copy of SnippetState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SnippetStateCopyWith<SnippetState> get copyWith => _$SnippetStateCopyWithImpl<SnippetState>(this as SnippetState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SnippetState&&const DeepCollectionEquality().equals(other.snippets, snippets)&&const DeepCollectionEquality().equals(other.tags, tags));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(snippets),const DeepCollectionEquality().hash(tags));

@override
String toString() {
  return 'SnippetState(snippets: $snippets, tags: $tags)';
}


}

/// @nodoc
abstract mixin class $SnippetStateCopyWith<$Res>  {
  factory $SnippetStateCopyWith(SnippetState value, $Res Function(SnippetState) _then) = _$SnippetStateCopyWithImpl;
@useResult
$Res call({
 List<Snippet> snippets, Set<String> tags
});




}
/// @nodoc
class _$SnippetStateCopyWithImpl<$Res>
    implements $SnippetStateCopyWith<$Res> {
  _$SnippetStateCopyWithImpl(this._self, this._then);

  final SnippetState _self;
  final $Res Function(SnippetState) _then;

/// Create a copy of SnippetState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? snippets = null,Object? tags = null,}) {
  return _then(_self.copyWith(
snippets: null == snippets ? _self.snippets : snippets // ignore: cast_nullable_to_non_nullable
as List<Snippet>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [SnippetState].
extension SnippetStatePatterns on SnippetState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SnippetState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SnippetState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SnippetState value)  $default,){
final _that = this;
switch (_that) {
case _SnippetState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SnippetState value)?  $default,){
final _that = this;
switch (_that) {
case _SnippetState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Snippet> snippets,  Set<String> tags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SnippetState() when $default != null:
return $default(_that.snippets,_that.tags);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Snippet> snippets,  Set<String> tags)  $default,) {final _that = this;
switch (_that) {
case _SnippetState():
return $default(_that.snippets,_that.tags);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Snippet> snippets,  Set<String> tags)?  $default,) {final _that = this;
switch (_that) {
case _SnippetState() when $default != null:
return $default(_that.snippets,_that.tags);case _:
  return null;

}
}

}

/// @nodoc


class _SnippetState implements SnippetState {
  const _SnippetState({final  List<Snippet> snippets = const <Snippet>[], final  Set<String> tags = const <String>{}}): _snippets = snippets,_tags = tags;
  

 final  List<Snippet> _snippets;
@override@JsonKey() List<Snippet> get snippets {
  if (_snippets is EqualUnmodifiableListView) return _snippets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_snippets);
}

 final  Set<String> _tags;
@override@JsonKey() Set<String> get tags {
  if (_tags is EqualUnmodifiableSetView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_tags);
}


/// Create a copy of SnippetState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SnippetStateCopyWith<_SnippetState> get copyWith => __$SnippetStateCopyWithImpl<_SnippetState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SnippetState&&const DeepCollectionEquality().equals(other._snippets, _snippets)&&const DeepCollectionEquality().equals(other._tags, _tags));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_snippets),const DeepCollectionEquality().hash(_tags));

@override
String toString() {
  return 'SnippetState(snippets: $snippets, tags: $tags)';
}


}

/// @nodoc
abstract mixin class _$SnippetStateCopyWith<$Res> implements $SnippetStateCopyWith<$Res> {
  factory _$SnippetStateCopyWith(_SnippetState value, $Res Function(_SnippetState) _then) = __$SnippetStateCopyWithImpl;
@override @useResult
$Res call({
 List<Snippet> snippets, Set<String> tags
});




}
/// @nodoc
class __$SnippetStateCopyWithImpl<$Res>
    implements _$SnippetStateCopyWith<$Res> {
  __$SnippetStateCopyWithImpl(this._self, this._then);

  final _SnippetState _self;
  final $Res Function(_SnippetState) _then;

/// Create a copy of SnippetState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? snippets = null,Object? tags = null,}) {
  return _then(_SnippetState(
snippets: null == snippets ? _self._snippets : snippets // ignore: cast_nullable_to_non_nullable
as List<Snippet>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}


}

// dart format on
