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
mixin _$Snippet {

 String get name; String get script; List<String>? get tags; String? get note;/// List of server id that this snippet should be auto run on
 List<String>? get autoRunOn;
/// Create a copy of Snippet
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SnippetCopyWith<Snippet> get copyWith => _$SnippetCopyWithImpl<Snippet>(this as Snippet, _$identity);

  /// Serializes this Snippet to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Snippet&&(identical(other.name, name) || other.name == name)&&(identical(other.script, script) || other.script == script)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.note, note) || other.note == note)&&const DeepCollectionEquality().equals(other.autoRunOn, autoRunOn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,script,const DeepCollectionEquality().hash(tags),note,const DeepCollectionEquality().hash(autoRunOn));

@override
String toString() {
  return 'Snippet(name: $name, script: $script, tags: $tags, note: $note, autoRunOn: $autoRunOn)';
}


}

/// @nodoc
abstract mixin class $SnippetCopyWith<$Res>  {
  factory $SnippetCopyWith(Snippet value, $Res Function(Snippet) _then) = _$SnippetCopyWithImpl;
@useResult
$Res call({
 String name, String script, List<String>? tags, String? note, List<String>? autoRunOn
});




}
/// @nodoc
class _$SnippetCopyWithImpl<$Res>
    implements $SnippetCopyWith<$Res> {
  _$SnippetCopyWithImpl(this._self, this._then);

  final Snippet _self;
  final $Res Function(Snippet) _then;

/// Create a copy of Snippet
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? script = null,Object? tags = freezed,Object? note = freezed,Object? autoRunOn = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,script: null == script ? _self.script : script // ignore: cast_nullable_to_non_nullable
as String,tags: freezed == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,autoRunOn: freezed == autoRunOn ? _self.autoRunOn : autoRunOn // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}

}


/// Adds pattern-matching-related methods to [Snippet].
extension SnippetPatterns on Snippet {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Snippet value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Snippet() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Snippet value)  $default,){
final _that = this;
switch (_that) {
case _Snippet():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Snippet value)?  $default,){
final _that = this;
switch (_that) {
case _Snippet() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String script,  List<String>? tags,  String? note,  List<String>? autoRunOn)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Snippet() when $default != null:
return $default(_that.name,_that.script,_that.tags,_that.note,_that.autoRunOn);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String script,  List<String>? tags,  String? note,  List<String>? autoRunOn)  $default,) {final _that = this;
switch (_that) {
case _Snippet():
return $default(_that.name,_that.script,_that.tags,_that.note,_that.autoRunOn);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String script,  List<String>? tags,  String? note,  List<String>? autoRunOn)?  $default,) {final _that = this;
switch (_that) {
case _Snippet() when $default != null:
return $default(_that.name,_that.script,_that.tags,_that.note,_that.autoRunOn);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Snippet implements Snippet {
  const _Snippet({required this.name, required this.script, final  List<String>? tags, this.note, final  List<String>? autoRunOn}): _tags = tags,_autoRunOn = autoRunOn;
  factory _Snippet.fromJson(Map<String, dynamic> json) => _$SnippetFromJson(json);

@override final  String name;
@override final  String script;
 final  List<String>? _tags;
@override List<String>? get tags {
  final value = _tags;
  if (value == null) return null;
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? note;
/// List of server id that this snippet should be auto run on
 final  List<String>? _autoRunOn;
/// List of server id that this snippet should be auto run on
@override List<String>? get autoRunOn {
  final value = _autoRunOn;
  if (value == null) return null;
  if (_autoRunOn is EqualUnmodifiableListView) return _autoRunOn;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of Snippet
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SnippetCopyWith<_Snippet> get copyWith => __$SnippetCopyWithImpl<_Snippet>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SnippetToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Snippet&&(identical(other.name, name) || other.name == name)&&(identical(other.script, script) || other.script == script)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.note, note) || other.note == note)&&const DeepCollectionEquality().equals(other._autoRunOn, _autoRunOn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,script,const DeepCollectionEquality().hash(_tags),note,const DeepCollectionEquality().hash(_autoRunOn));

@override
String toString() {
  return 'Snippet(name: $name, script: $script, tags: $tags, note: $note, autoRunOn: $autoRunOn)';
}


}

/// @nodoc
abstract mixin class _$SnippetCopyWith<$Res> implements $SnippetCopyWith<$Res> {
  factory _$SnippetCopyWith(_Snippet value, $Res Function(_Snippet) _then) = __$SnippetCopyWithImpl;
@override @useResult
$Res call({
 String name, String script, List<String>? tags, String? note, List<String>? autoRunOn
});




}
/// @nodoc
class __$SnippetCopyWithImpl<$Res>
    implements _$SnippetCopyWith<$Res> {
  __$SnippetCopyWithImpl(this._self, this._then);

  final _Snippet _self;
  final $Res Function(_Snippet) _then;

/// Create a copy of Snippet
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? script = null,Object? tags = freezed,Object? note = freezed,Object? autoRunOn = freezed,}) {
  return _then(_Snippet(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,script: null == script ? _self.script : script // ignore: cast_nullable_to_non_nullable
as String,tags: freezed == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,autoRunOn: freezed == autoRunOn ? _self._autoRunOn : autoRunOn // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}


}

// dart format on
