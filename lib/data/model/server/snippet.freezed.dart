// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'snippet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Snippet _$SnippetFromJson(Map<String, dynamic> json) {
  return _Snippet.fromJson(json);
}

/// @nodoc
mixin _$Snippet {
  String get name => throw _privateConstructorUsedError;
  String get script => throw _privateConstructorUsedError;
  List<String>? get tags => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;

  /// List of server id that this snippet should be auto run on
  List<String>? get autoRunOn => throw _privateConstructorUsedError;

  /// Serializes this Snippet to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Snippet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SnippetCopyWith<Snippet> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SnippetCopyWith<$Res> {
  factory $SnippetCopyWith(Snippet value, $Res Function(Snippet) then) =
      _$SnippetCopyWithImpl<$Res, Snippet>;
  @useResult
  $Res call({
    String name,
    String script,
    List<String>? tags,
    String? note,
    List<String>? autoRunOn,
  });
}

/// @nodoc
class _$SnippetCopyWithImpl<$Res, $Val extends Snippet>
    implements $SnippetCopyWith<$Res> {
  _$SnippetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Snippet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? script = null,
    Object? tags = freezed,
    Object? note = freezed,
    Object? autoRunOn = freezed,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            script: null == script
                ? _value.script
                : script // ignore: cast_nullable_to_non_nullable
                      as String,
            tags: freezed == tags
                ? _value.tags
                : tags // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
            autoRunOn: freezed == autoRunOn
                ? _value.autoRunOn
                : autoRunOn // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SnippetImplCopyWith<$Res> implements $SnippetCopyWith<$Res> {
  factory _$$SnippetImplCopyWith(
    _$SnippetImpl value,
    $Res Function(_$SnippetImpl) then,
  ) = __$$SnippetImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    String script,
    List<String>? tags,
    String? note,
    List<String>? autoRunOn,
  });
}

/// @nodoc
class __$$SnippetImplCopyWithImpl<$Res>
    extends _$SnippetCopyWithImpl<$Res, _$SnippetImpl>
    implements _$$SnippetImplCopyWith<$Res> {
  __$$SnippetImplCopyWithImpl(
    _$SnippetImpl _value,
    $Res Function(_$SnippetImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Snippet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? script = null,
    Object? tags = freezed,
    Object? note = freezed,
    Object? autoRunOn = freezed,
  }) {
    return _then(
      _$SnippetImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        script: null == script
            ? _value.script
            : script // ignore: cast_nullable_to_non_nullable
                  as String,
        tags: freezed == tags
            ? _value._tags
            : tags // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
        autoRunOn: freezed == autoRunOn
            ? _value._autoRunOn
            : autoRunOn // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SnippetImpl implements _Snippet {
  const _$SnippetImpl({
    required this.name,
    required this.script,
    final List<String>? tags,
    this.note,
    final List<String>? autoRunOn,
  }) : _tags = tags,
       _autoRunOn = autoRunOn;

  factory _$SnippetImpl.fromJson(Map<String, dynamic> json) =>
      _$$SnippetImplFromJson(json);

  @override
  final String name;
  @override
  final String script;
  final List<String>? _tags;
  @override
  List<String>? get tags {
    final value = _tags;
    if (value == null) return null;
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? note;

  /// List of server id that this snippet should be auto run on
  final List<String>? _autoRunOn;

  /// List of server id that this snippet should be auto run on
  @override
  List<String>? get autoRunOn {
    final value = _autoRunOn;
    if (value == null) return null;
    if (_autoRunOn is EqualUnmodifiableListView) return _autoRunOn;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'Snippet(name: $name, script: $script, tags: $tags, note: $note, autoRunOn: $autoRunOn)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SnippetImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.script, script) || other.script == script) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.note, note) || other.note == note) &&
            const DeepCollectionEquality().equals(
              other._autoRunOn,
              _autoRunOn,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    name,
    script,
    const DeepCollectionEquality().hash(_tags),
    note,
    const DeepCollectionEquality().hash(_autoRunOn),
  );

  /// Create a copy of Snippet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SnippetImplCopyWith<_$SnippetImpl> get copyWith =>
      __$$SnippetImplCopyWithImpl<_$SnippetImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SnippetImplToJson(this);
  }
}

abstract class _Snippet implements Snippet {
  const factory _Snippet({
    required final String name,
    required final String script,
    final List<String>? tags,
    final String? note,
    final List<String>? autoRunOn,
  }) = _$SnippetImpl;

  factory _Snippet.fromJson(Map<String, dynamic> json) = _$SnippetImpl.fromJson;

  @override
  String get name;
  @override
  String get script;
  @override
  List<String>? get tags;
  @override
  String? get note;

  /// List of server id that this snippet should be auto run on
  @override
  List<String>? get autoRunOn;

  /// Create a copy of Snippet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SnippetImplCopyWith<_$SnippetImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
