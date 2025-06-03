// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'backup2.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

BackupV2 _$BackupV2FromJson(Map<String, dynamic> json) {
  return _BackupV2.fromJson(json);
}

/// @nodoc
mixin _$BackupV2 {
  int get version => throw _privateConstructorUsedError;
  int get date => throw _privateConstructorUsedError;
  Map<String, Object?> get spis => throw _privateConstructorUsedError;
  Map<String, Object?> get snippets => throw _privateConstructorUsedError;
  Map<String, Object?> get keys => throw _privateConstructorUsedError;
  Map<String, Object?> get container => throw _privateConstructorUsedError;
  Map<String, Object?> get history => throw _privateConstructorUsedError;
  Map<String, Object?> get settings => throw _privateConstructorUsedError;

  /// Serializes this BackupV2 to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BackupV2
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BackupV2CopyWith<BackupV2> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BackupV2CopyWith<$Res> {
  factory $BackupV2CopyWith(BackupV2 value, $Res Function(BackupV2) then) =
      _$BackupV2CopyWithImpl<$Res, BackupV2>;
  @useResult
  $Res call({
    int version,
    int date,
    Map<String, Object?> spis,
    Map<String, Object?> snippets,
    Map<String, Object?> keys,
    Map<String, Object?> container,
    Map<String, Object?> history,
    Map<String, Object?> settings,
  });
}

/// @nodoc
class _$BackupV2CopyWithImpl<$Res, $Val extends BackupV2>
    implements $BackupV2CopyWith<$Res> {
  _$BackupV2CopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BackupV2
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? date = null,
    Object? spis = null,
    Object? snippets = null,
    Object? keys = null,
    Object? container = null,
    Object? history = null,
    Object? settings = null,
  }) {
    return _then(
      _value.copyWith(
            version: null == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as int,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as int,
            spis: null == spis
                ? _value.spis
                : spis // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            snippets: null == snippets
                ? _value.snippets
                : snippets // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            keys: null == keys
                ? _value.keys
                : keys // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            container: null == container
                ? _value.container
                : container // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            history: null == history
                ? _value.history
                : history // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            settings: null == settings
                ? _value.settings
                : settings // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BackupV2ImplCopyWith<$Res>
    implements $BackupV2CopyWith<$Res> {
  factory _$$BackupV2ImplCopyWith(
    _$BackupV2Impl value,
    $Res Function(_$BackupV2Impl) then,
  ) = __$$BackupV2ImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int version,
    int date,
    Map<String, Object?> spis,
    Map<String, Object?> snippets,
    Map<String, Object?> keys,
    Map<String, Object?> container,
    Map<String, Object?> history,
    Map<String, Object?> settings,
  });
}

/// @nodoc
class __$$BackupV2ImplCopyWithImpl<$Res>
    extends _$BackupV2CopyWithImpl<$Res, _$BackupV2Impl>
    implements _$$BackupV2ImplCopyWith<$Res> {
  __$$BackupV2ImplCopyWithImpl(
    _$BackupV2Impl _value,
    $Res Function(_$BackupV2Impl) _then,
  ) : super(_value, _then);

  /// Create a copy of BackupV2
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? date = null,
    Object? spis = null,
    Object? snippets = null,
    Object? keys = null,
    Object? container = null,
    Object? history = null,
    Object? settings = null,
  }) {
    return _then(
      _$BackupV2Impl(
        version: null == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as int,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as int,
        spis: null == spis
            ? _value._spis
            : spis // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        snippets: null == snippets
            ? _value._snippets
            : snippets // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        keys: null == keys
            ? _value._keys
            : keys // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        container: null == container
            ? _value._container
            : container // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        history: null == history
            ? _value._history
            : history // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        settings: null == settings
            ? _value._settings
            : settings // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BackupV2Impl extends _BackupV2 {
  const _$BackupV2Impl({
    required this.version,
    required this.date,
    required final Map<String, Object?> spis,
    required final Map<String, Object?> snippets,
    required final Map<String, Object?> keys,
    required final Map<String, Object?> container,
    required final Map<String, Object?> history,
    required final Map<String, Object?> settings,
  }) : _spis = spis,
       _snippets = snippets,
       _keys = keys,
       _container = container,
       _history = history,
       _settings = settings,
       super._();

  factory _$BackupV2Impl.fromJson(Map<String, dynamic> json) =>
      _$$BackupV2ImplFromJson(json);

  @override
  final int version;
  @override
  final int date;
  final Map<String, Object?> _spis;
  @override
  Map<String, Object?> get spis {
    if (_spis is EqualUnmodifiableMapView) return _spis;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_spis);
  }

  final Map<String, Object?> _snippets;
  @override
  Map<String, Object?> get snippets {
    if (_snippets is EqualUnmodifiableMapView) return _snippets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_snippets);
  }

  final Map<String, Object?> _keys;
  @override
  Map<String, Object?> get keys {
    if (_keys is EqualUnmodifiableMapView) return _keys;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_keys);
  }

  final Map<String, Object?> _container;
  @override
  Map<String, Object?> get container {
    if (_container is EqualUnmodifiableMapView) return _container;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_container);
  }

  final Map<String, Object?> _history;
  @override
  Map<String, Object?> get history {
    if (_history is EqualUnmodifiableMapView) return _history;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_history);
  }

  final Map<String, Object?> _settings;
  @override
  Map<String, Object?> get settings {
    if (_settings is EqualUnmodifiableMapView) return _settings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_settings);
  }

  @override
  String toString() {
    return 'BackupV2(version: $version, date: $date, spis: $spis, snippets: $snippets, keys: $keys, container: $container, history: $history, settings: $settings)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BackupV2Impl &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.date, date) || other.date == date) &&
            const DeepCollectionEquality().equals(other._spis, _spis) &&
            const DeepCollectionEquality().equals(other._snippets, _snippets) &&
            const DeepCollectionEquality().equals(other._keys, _keys) &&
            const DeepCollectionEquality().equals(
              other._container,
              _container,
            ) &&
            const DeepCollectionEquality().equals(other._history, _history) &&
            const DeepCollectionEquality().equals(other._settings, _settings));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    version,
    date,
    const DeepCollectionEquality().hash(_spis),
    const DeepCollectionEquality().hash(_snippets),
    const DeepCollectionEquality().hash(_keys),
    const DeepCollectionEquality().hash(_container),
    const DeepCollectionEquality().hash(_history),
    const DeepCollectionEquality().hash(_settings),
  );

  /// Create a copy of BackupV2
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BackupV2ImplCopyWith<_$BackupV2Impl> get copyWith =>
      __$$BackupV2ImplCopyWithImpl<_$BackupV2Impl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BackupV2ImplToJson(this);
  }
}

abstract class _BackupV2 extends BackupV2 {
  const factory _BackupV2({
    required final int version,
    required final int date,
    required final Map<String, Object?> spis,
    required final Map<String, Object?> snippets,
    required final Map<String, Object?> keys,
    required final Map<String, Object?> container,
    required final Map<String, Object?> history,
    required final Map<String, Object?> settings,
  }) = _$BackupV2Impl;
  const _BackupV2._() : super._();

  factory _BackupV2.fromJson(Map<String, dynamic> json) =
      _$BackupV2Impl.fromJson;

  @override
  int get version;
  @override
  int get date;
  @override
  Map<String, Object?> get spis;
  @override
  Map<String, Object?> get snippets;
  @override
  Map<String, Object?> get keys;
  @override
  Map<String, Object?> get container;
  @override
  Map<String, Object?> get history;
  @override
  Map<String, Object?> get settings;

  /// Create a copy of BackupV2
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BackupV2ImplCopyWith<_$BackupV2Impl> get copyWith =>
      throw _privateConstructorUsedError;
}
