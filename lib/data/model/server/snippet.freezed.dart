// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
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
