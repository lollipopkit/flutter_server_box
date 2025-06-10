// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'backup2.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BackupV2 {

 int get version; int get date; Map<String, Object?> get spis; Map<String, Object?> get snippets; Map<String, Object?> get keys; Map<String, Object?> get container; Map<String, Object?> get history; Map<String, Object?> get settings;
/// Create a copy of BackupV2
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackupV2CopyWith<BackupV2> get copyWith => _$BackupV2CopyWithImpl<BackupV2>(this as BackupV2, _$identity);

  /// Serializes this BackupV2 to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BackupV2&&(identical(other.version, version) || other.version == version)&&(identical(other.date, date) || other.date == date)&&const DeepCollectionEquality().equals(other.spis, spis)&&const DeepCollectionEquality().equals(other.snippets, snippets)&&const DeepCollectionEquality().equals(other.keys, keys)&&const DeepCollectionEquality().equals(other.container, container)&&const DeepCollectionEquality().equals(other.history, history)&&const DeepCollectionEquality().equals(other.settings, settings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,date,const DeepCollectionEquality().hash(spis),const DeepCollectionEquality().hash(snippets),const DeepCollectionEquality().hash(keys),const DeepCollectionEquality().hash(container),const DeepCollectionEquality().hash(history),const DeepCollectionEquality().hash(settings));

@override
String toString() {
  return 'BackupV2(version: $version, date: $date, spis: $spis, snippets: $snippets, keys: $keys, container: $container, history: $history, settings: $settings)';
}


}

/// @nodoc
abstract mixin class $BackupV2CopyWith<$Res>  {
  factory $BackupV2CopyWith(BackupV2 value, $Res Function(BackupV2) _then) = _$BackupV2CopyWithImpl;
@useResult
$Res call({
 int version, int date, Map<String, Object?> spis, Map<String, Object?> snippets, Map<String, Object?> keys, Map<String, Object?> container, Map<String, Object?> history, Map<String, Object?> settings
});




}
/// @nodoc
class _$BackupV2CopyWithImpl<$Res>
    implements $BackupV2CopyWith<$Res> {
  _$BackupV2CopyWithImpl(this._self, this._then);

  final BackupV2 _self;
  final $Res Function(BackupV2) _then;

/// Create a copy of BackupV2
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? date = null,Object? spis = null,Object? snippets = null,Object? keys = null,Object? container = null,Object? history = null,Object? settings = null,}) {
  return _then(_self.copyWith(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as int,spis: null == spis ? _self.spis : spis // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,snippets: null == snippets ? _self.snippets : snippets // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,keys: null == keys ? _self.keys : keys // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,container: null == container ? _self.container : container // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _BackupV2 extends BackupV2 {
  const _BackupV2({required this.version, required this.date, required final  Map<String, Object?> spis, required final  Map<String, Object?> snippets, required final  Map<String, Object?> keys, required final  Map<String, Object?> container, required final  Map<String, Object?> history, required final  Map<String, Object?> settings}): _spis = spis,_snippets = snippets,_keys = keys,_container = container,_history = history,_settings = settings,super._();
  factory _BackupV2.fromJson(Map<String, dynamic> json) => _$BackupV2FromJson(json);

@override final  int version;
@override final  int date;
 final  Map<String, Object?> _spis;
@override Map<String, Object?> get spis {
  if (_spis is EqualUnmodifiableMapView) return _spis;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_spis);
}

 final  Map<String, Object?> _snippets;
@override Map<String, Object?> get snippets {
  if (_snippets is EqualUnmodifiableMapView) return _snippets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_snippets);
}

 final  Map<String, Object?> _keys;
@override Map<String, Object?> get keys {
  if (_keys is EqualUnmodifiableMapView) return _keys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_keys);
}

 final  Map<String, Object?> _container;
@override Map<String, Object?> get container {
  if (_container is EqualUnmodifiableMapView) return _container;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_container);
}

 final  Map<String, Object?> _history;
@override Map<String, Object?> get history {
  if (_history is EqualUnmodifiableMapView) return _history;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_history);
}

 final  Map<String, Object?> _settings;
@override Map<String, Object?> get settings {
  if (_settings is EqualUnmodifiableMapView) return _settings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_settings);
}


/// Create a copy of BackupV2
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BackupV2CopyWith<_BackupV2> get copyWith => __$BackupV2CopyWithImpl<_BackupV2>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BackupV2ToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BackupV2&&(identical(other.version, version) || other.version == version)&&(identical(other.date, date) || other.date == date)&&const DeepCollectionEquality().equals(other._spis, _spis)&&const DeepCollectionEquality().equals(other._snippets, _snippets)&&const DeepCollectionEquality().equals(other._keys, _keys)&&const DeepCollectionEquality().equals(other._container, _container)&&const DeepCollectionEquality().equals(other._history, _history)&&const DeepCollectionEquality().equals(other._settings, _settings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,date,const DeepCollectionEquality().hash(_spis),const DeepCollectionEquality().hash(_snippets),const DeepCollectionEquality().hash(_keys),const DeepCollectionEquality().hash(_container),const DeepCollectionEquality().hash(_history),const DeepCollectionEquality().hash(_settings));

@override
String toString() {
  return 'BackupV2(version: $version, date: $date, spis: $spis, snippets: $snippets, keys: $keys, container: $container, history: $history, settings: $settings)';
}


}

/// @nodoc
abstract mixin class _$BackupV2CopyWith<$Res> implements $BackupV2CopyWith<$Res> {
  factory _$BackupV2CopyWith(_BackupV2 value, $Res Function(_BackupV2) _then) = __$BackupV2CopyWithImpl;
@override @useResult
$Res call({
 int version, int date, Map<String, Object?> spis, Map<String, Object?> snippets, Map<String, Object?> keys, Map<String, Object?> container, Map<String, Object?> history, Map<String, Object?> settings
});




}
/// @nodoc
class __$BackupV2CopyWithImpl<$Res>
    implements _$BackupV2CopyWith<$Res> {
  __$BackupV2CopyWithImpl(this._self, this._then);

  final _BackupV2 _self;
  final $Res Function(_BackupV2) _then;

/// Create a copy of BackupV2
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? date = null,Object? spis = null,Object? snippets = null,Object? keys = null,Object? container = null,Object? history = null,Object? settings = null,}) {
  return _then(_BackupV2(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as int,spis: null == spis ? _self._spis : spis // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,snippets: null == snippets ? _self._snippets : snippets // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,keys: null == keys ? _self._keys : keys // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,container: null == container ? _self._container : container // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,history: null == history ? _self._history : history // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,settings: null == settings ? _self._settings : settings // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

// dart format on
