// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'server_private_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Spi _$SpiFromJson(Map<String, dynamic> json) {
  return _Spi.fromJson(json);
}

/// @nodoc
mixin _$Spi {
  @HiveField(0)
  String get name => throw _privateConstructorUsedError;
  @HiveField(1)
  String get ip => throw _privateConstructorUsedError;
  @HiveField(2)
  int get port => throw _privateConstructorUsedError;
  @HiveField(3)
  String get user => throw _privateConstructorUsedError;
  @HiveField(4)
  String? get pwd => throw _privateConstructorUsedError;

  /// [id] of private key
  @JsonKey(name: 'pubKeyId')
  @HiveField(5)
  String? get keyId => throw _privateConstructorUsedError;
  @HiveField(6)
  List<String>? get tags => throw _privateConstructorUsedError;
  @HiveField(7)
  String? get alterUrl => throw _privateConstructorUsedError;
  @HiveField(8, defaultValue: true)
  bool get autoConnect => throw _privateConstructorUsedError;

  /// [id] of the jump server
  @HiveField(9)
  String? get jumpId => throw _privateConstructorUsedError;
  @HiveField(10)
  ServerCustom? get custom => throw _privateConstructorUsedError;
  @HiveField(11)
  WakeOnLanCfg? get wolCfg => throw _privateConstructorUsedError;

  /// It only applies to SSH terminal.
  @HiveField(12)
  Map<String, String>? get envs => throw _privateConstructorUsedError;
  @HiveField(13, defaultValue: '')
  String get id => throw _privateConstructorUsedError;

  /// Serializes this Spi to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Spi
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SpiCopyWith<Spi> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SpiCopyWith<$Res> {
  factory $SpiCopyWith(Spi value, $Res Function(Spi) then) =
      _$SpiCopyWithImpl<$Res, Spi>;
  @useResult
  $Res call(
      {@HiveField(0) String name,
      @HiveField(1) String ip,
      @HiveField(2) int port,
      @HiveField(3) String user,
      @HiveField(4) String? pwd,
      @JsonKey(name: 'pubKeyId') @HiveField(5) String? keyId,
      @HiveField(6) List<String>? tags,
      @HiveField(7) String? alterUrl,
      @HiveField(8, defaultValue: true) bool autoConnect,
      @HiveField(9) String? jumpId,
      @HiveField(10) ServerCustom? custom,
      @HiveField(11) WakeOnLanCfg? wolCfg,
      @HiveField(12) Map<String, String>? envs,
      @HiveField(13, defaultValue: '') String id});
}

/// @nodoc
class _$SpiCopyWithImpl<$Res, $Val extends Spi> implements $SpiCopyWith<$Res> {
  _$SpiCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Spi
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? ip = null,
    Object? port = null,
    Object? user = null,
    Object? pwd = freezed,
    Object? keyId = freezed,
    Object? tags = freezed,
    Object? alterUrl = freezed,
    Object? autoConnect = null,
    Object? jumpId = freezed,
    Object? custom = freezed,
    Object? wolCfg = freezed,
    Object? envs = freezed,
    Object? id = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      ip: null == ip
          ? _value.ip
          : ip // ignore: cast_nullable_to_non_nullable
              as String,
      port: null == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      pwd: freezed == pwd
          ? _value.pwd
          : pwd // ignore: cast_nullable_to_non_nullable
              as String?,
      keyId: freezed == keyId
          ? _value.keyId
          : keyId // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: freezed == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      alterUrl: freezed == alterUrl
          ? _value.alterUrl
          : alterUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      autoConnect: null == autoConnect
          ? _value.autoConnect
          : autoConnect // ignore: cast_nullable_to_non_nullable
              as bool,
      jumpId: freezed == jumpId
          ? _value.jumpId
          : jumpId // ignore: cast_nullable_to_non_nullable
              as String?,
      custom: freezed == custom
          ? _value.custom
          : custom // ignore: cast_nullable_to_non_nullable
              as ServerCustom?,
      wolCfg: freezed == wolCfg
          ? _value.wolCfg
          : wolCfg // ignore: cast_nullable_to_non_nullable
              as WakeOnLanCfg?,
      envs: freezed == envs
          ? _value.envs
          : envs // ignore: cast_nullable_to_non_nullable
              as Map<String, String>?,
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SpiImplCopyWith<$Res> implements $SpiCopyWith<$Res> {
  factory _$$SpiImplCopyWith(_$SpiImpl value, $Res Function(_$SpiImpl) then) =
      __$$SpiImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) String name,
      @HiveField(1) String ip,
      @HiveField(2) int port,
      @HiveField(3) String user,
      @HiveField(4) String? pwd,
      @JsonKey(name: 'pubKeyId') @HiveField(5) String? keyId,
      @HiveField(6) List<String>? tags,
      @HiveField(7) String? alterUrl,
      @HiveField(8, defaultValue: true) bool autoConnect,
      @HiveField(9) String? jumpId,
      @HiveField(10) ServerCustom? custom,
      @HiveField(11) WakeOnLanCfg? wolCfg,
      @HiveField(12) Map<String, String>? envs,
      @HiveField(13, defaultValue: '') String id});
}

/// @nodoc
class __$$SpiImplCopyWithImpl<$Res> extends _$SpiCopyWithImpl<$Res, _$SpiImpl>
    implements _$$SpiImplCopyWith<$Res> {
  __$$SpiImplCopyWithImpl(_$SpiImpl _value, $Res Function(_$SpiImpl) _then)
      : super(_value, _then);

  /// Create a copy of Spi
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? ip = null,
    Object? port = null,
    Object? user = null,
    Object? pwd = freezed,
    Object? keyId = freezed,
    Object? tags = freezed,
    Object? alterUrl = freezed,
    Object? autoConnect = null,
    Object? jumpId = freezed,
    Object? custom = freezed,
    Object? wolCfg = freezed,
    Object? envs = freezed,
    Object? id = null,
  }) {
    return _then(_$SpiImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      ip: null == ip
          ? _value.ip
          : ip // ignore: cast_nullable_to_non_nullable
              as String,
      port: null == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      pwd: freezed == pwd
          ? _value.pwd
          : pwd // ignore: cast_nullable_to_non_nullable
              as String?,
      keyId: freezed == keyId
          ? _value.keyId
          : keyId // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: freezed == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      alterUrl: freezed == alterUrl
          ? _value.alterUrl
          : alterUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      autoConnect: null == autoConnect
          ? _value.autoConnect
          : autoConnect // ignore: cast_nullable_to_non_nullable
              as bool,
      jumpId: freezed == jumpId
          ? _value.jumpId
          : jumpId // ignore: cast_nullable_to_non_nullable
              as String?,
      custom: freezed == custom
          ? _value.custom
          : custom // ignore: cast_nullable_to_non_nullable
              as ServerCustom?,
      wolCfg: freezed == wolCfg
          ? _value.wolCfg
          : wolCfg // ignore: cast_nullable_to_non_nullable
              as WakeOnLanCfg?,
      envs: freezed == envs
          ? _value._envs
          : envs // ignore: cast_nullable_to_non_nullable
              as Map<String, String>?,
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SpiImpl extends _Spi {
  const _$SpiImpl(
      {@HiveField(0) required this.name,
      @HiveField(1) required this.ip,
      @HiveField(2) required this.port,
      @HiveField(3) required this.user,
      @HiveField(4) this.pwd,
      @JsonKey(name: 'pubKeyId') @HiveField(5) this.keyId,
      @HiveField(6) final List<String>? tags,
      @HiveField(7) this.alterUrl,
      @HiveField(8, defaultValue: true) this.autoConnect = true,
      @HiveField(9) this.jumpId,
      @HiveField(10) this.custom,
      @HiveField(11) this.wolCfg,
      @HiveField(12) final Map<String, String>? envs,
      @HiveField(13, defaultValue: '') required this.id})
      : _tags = tags,
        _envs = envs,
        super._();

  factory _$SpiImpl.fromJson(Map<String, dynamic> json) =>
      _$$SpiImplFromJson(json);

  @override
  @HiveField(0)
  final String name;
  @override
  @HiveField(1)
  final String ip;
  @override
  @HiveField(2)
  final int port;
  @override
  @HiveField(3)
  final String user;
  @override
  @HiveField(4)
  final String? pwd;

  /// [id] of private key
  @override
  @JsonKey(name: 'pubKeyId')
  @HiveField(5)
  final String? keyId;
  final List<String>? _tags;
  @override
  @HiveField(6)
  List<String>? get tags {
    final value = _tags;
    if (value == null) return null;
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @HiveField(7)
  final String? alterUrl;
  @override
  @JsonKey()
  @HiveField(8, defaultValue: true)
  final bool autoConnect;

  /// [id] of the jump server
  @override
  @HiveField(9)
  final String? jumpId;
  @override
  @HiveField(10)
  final ServerCustom? custom;
  @override
  @HiveField(11)
  final WakeOnLanCfg? wolCfg;

  /// It only applies to SSH terminal.
  final Map<String, String>? _envs;

  /// It only applies to SSH terminal.
  @override
  @HiveField(12)
  Map<String, String>? get envs {
    final value = _envs;
    if (value == null) return null;
    if (_envs is EqualUnmodifiableMapView) return _envs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @HiveField(13, defaultValue: '')
  final String id;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SpiImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.ip, ip) || other.ip == ip) &&
            (identical(other.port, port) || other.port == port) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.pwd, pwd) || other.pwd == pwd) &&
            (identical(other.keyId, keyId) || other.keyId == keyId) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.alterUrl, alterUrl) ||
                other.alterUrl == alterUrl) &&
            (identical(other.autoConnect, autoConnect) ||
                other.autoConnect == autoConnect) &&
            (identical(other.jumpId, jumpId) || other.jumpId == jumpId) &&
            (identical(other.custom, custom) || other.custom == custom) &&
            (identical(other.wolCfg, wolCfg) || other.wolCfg == wolCfg) &&
            const DeepCollectionEquality().equals(other._envs, _envs) &&
            (identical(other.id, id) || other.id == id));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      name,
      ip,
      port,
      user,
      pwd,
      keyId,
      const DeepCollectionEquality().hash(_tags),
      alterUrl,
      autoConnect,
      jumpId,
      custom,
      wolCfg,
      const DeepCollectionEquality().hash(_envs),
      id);

  /// Create a copy of Spi
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SpiImplCopyWith<_$SpiImpl> get copyWith =>
      __$$SpiImplCopyWithImpl<_$SpiImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SpiImplToJson(
      this,
    );
  }
}

abstract class _Spi extends Spi {
  const factory _Spi(
      {@HiveField(0) required final String name,
      @HiveField(1) required final String ip,
      @HiveField(2) required final int port,
      @HiveField(3) required final String user,
      @HiveField(4) final String? pwd,
      @JsonKey(name: 'pubKeyId') @HiveField(5) final String? keyId,
      @HiveField(6) final List<String>? tags,
      @HiveField(7) final String? alterUrl,
      @HiveField(8, defaultValue: true) final bool autoConnect,
      @HiveField(9) final String? jumpId,
      @HiveField(10) final ServerCustom? custom,
      @HiveField(11) final WakeOnLanCfg? wolCfg,
      @HiveField(12) final Map<String, String>? envs,
      @HiveField(13, defaultValue: '') required final String id}) = _$SpiImpl;
  const _Spi._() : super._();

  factory _Spi.fromJson(Map<String, dynamic> json) = _$SpiImpl.fromJson;

  @override
  @HiveField(0)
  String get name;
  @override
  @HiveField(1)
  String get ip;
  @override
  @HiveField(2)
  int get port;
  @override
  @HiveField(3)
  String get user;
  @override
  @HiveField(4)
  String? get pwd;

  /// [id] of private key
  @override
  @JsonKey(name: 'pubKeyId')
  @HiveField(5)
  String? get keyId;
  @override
  @HiveField(6)
  List<String>? get tags;
  @override
  @HiveField(7)
  String? get alterUrl;
  @override
  @HiveField(8, defaultValue: true)
  bool get autoConnect;

  /// [id] of the jump server
  @override
  @HiveField(9)
  String? get jumpId;
  @override
  @HiveField(10)
  ServerCustom? get custom;
  @override
  @HiveField(11)
  WakeOnLanCfg? get wolCfg;

  /// It only applies to SSH terminal.
  @override
  @HiveField(12)
  Map<String, String>? get envs;
  @override
  @HiveField(13, defaultValue: '')
  String get id;

  /// Create a copy of Spi
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SpiImplCopyWith<_$SpiImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
