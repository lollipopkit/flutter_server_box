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
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Spi {
  String get name => throw _privateConstructorUsedError;
  String get ip => throw _privateConstructorUsedError;
  int get port => throw _privateConstructorUsedError;
  String get user => throw _privateConstructorUsedError;
  String? get pwd => throw _privateConstructorUsedError;

  /// [id] of private key
  @JsonKey(name: 'pubKeyId')
  String? get keyId => throw _privateConstructorUsedError;
  List<String>? get tags => throw _privateConstructorUsedError;
  String? get alterUrl => throw _privateConstructorUsedError;
  @JsonKey(defaultValue: true)
  bool get autoConnect => throw _privateConstructorUsedError;

  /// [id] of the jump server
  String? get jumpId => throw _privateConstructorUsedError;
  ServerCustom? get custom => throw _privateConstructorUsedError;
  WakeOnLanCfg? get wolCfg => throw _privateConstructorUsedError;

  /// It only applies to SSH terminal.
  Map<String, String>? get envs => throw _privateConstructorUsedError;
  @JsonKey(fromJson: Spi.parseId)
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
  $Res call({
    String name,
    String ip,
    int port,
    String user,
    String? pwd,
    @JsonKey(name: 'pubKeyId') String? keyId,
    List<String>? tags,
    String? alterUrl,
    @JsonKey(defaultValue: true) bool autoConnect,
    String? jumpId,
    ServerCustom? custom,
    WakeOnLanCfg? wolCfg,
    Map<String, String>? envs,
    @JsonKey(fromJson: Spi.parseId) @HiveField(13, defaultValue: '') String id,
  });
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
    return _then(
      _value.copyWith(
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
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SpiImplCopyWith<$Res> implements $SpiCopyWith<$Res> {
  factory _$$SpiImplCopyWith(_$SpiImpl value, $Res Function(_$SpiImpl) then) =
      __$$SpiImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    String ip,
    int port,
    String user,
    String? pwd,
    @JsonKey(name: 'pubKeyId') String? keyId,
    List<String>? tags,
    String? alterUrl,
    @JsonKey(defaultValue: true) bool autoConnect,
    String? jumpId,
    ServerCustom? custom,
    WakeOnLanCfg? wolCfg,
    Map<String, String>? envs,
    @JsonKey(fromJson: Spi.parseId) @HiveField(13, defaultValue: '') String id,
  });
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
    return _then(
      _$SpiImpl(
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
      ),
    );
  }
}

/// @nodoc
@JsonSerializable(createFactory: false)
class _$SpiImpl extends _Spi {
  const _$SpiImpl({
    required this.name,
    required this.ip,
    required this.port,
    required this.user,
    this.pwd,
    @JsonKey(name: 'pubKeyId') this.keyId,
    final List<String>? tags,
    this.alterUrl,
    @JsonKey(defaultValue: true) this.autoConnect = true,
    this.jumpId,
    this.custom,
    this.wolCfg,
    final Map<String, String>? envs,
    @JsonKey(fromJson: Spi.parseId)
    @HiveField(13, defaultValue: '')
    required this.id,
  }) : _tags = tags,
       _envs = envs,
       super._();

  @override
  final String name;
  @override
  final String ip;
  @override
  final int port;
  @override
  final String user;
  @override
  final String? pwd;

  /// [id] of private key
  @override
  @JsonKey(name: 'pubKeyId')
  final String? keyId;
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
  final String? alterUrl;
  @override
  @JsonKey(defaultValue: true)
  final bool autoConnect;

  /// [id] of the jump server
  @override
  final String? jumpId;
  @override
  final ServerCustom? custom;
  @override
  final WakeOnLanCfg? wolCfg;

  /// It only applies to SSH terminal.
  final Map<String, String>? _envs;

  /// It only applies to SSH terminal.
  @override
  Map<String, String>? get envs {
    final value = _envs;
    if (value == null) return null;
    if (_envs is EqualUnmodifiableMapView) return _envs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey(fromJson: Spi.parseId)
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
    id,
  );

  /// Create a copy of Spi
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SpiImplCopyWith<_$SpiImpl> get copyWith =>
      __$$SpiImplCopyWithImpl<_$SpiImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SpiImplToJson(this);
  }
}

abstract class _Spi extends Spi {
  const factory _Spi({
    required final String name,
    required final String ip,
    required final int port,
    required final String user,
    final String? pwd,
    @JsonKey(name: 'pubKeyId') final String? keyId,
    final List<String>? tags,
    final String? alterUrl,
    @JsonKey(defaultValue: true) final bool autoConnect,
    final String? jumpId,
    final ServerCustom? custom,
    final WakeOnLanCfg? wolCfg,
    final Map<String, String>? envs,
    @JsonKey(fromJson: Spi.parseId)
    @HiveField(13, defaultValue: '')
    required final String id,
  }) = _$SpiImpl;
  const _Spi._() : super._();

  @override
  String get name;
  @override
  String get ip;
  @override
  int get port;
  @override
  String get user;
  @override
  String? get pwd;

  /// [id] of private key
  @override
  @JsonKey(name: 'pubKeyId')
  String? get keyId;
  @override
  List<String>? get tags;
  @override
  String? get alterUrl;
  @override
  @JsonKey(defaultValue: true)
  bool get autoConnect;

  /// [id] of the jump server
  @override
  String? get jumpId;
  @override
  ServerCustom? get custom;
  @override
  WakeOnLanCfg? get wolCfg;

  /// It only applies to SSH terminal.
  @override
  Map<String, String>? get envs;
  @override
  @JsonKey(fromJson: Spi.parseId)
  @HiveField(13, defaultValue: '')
  String get id;

  /// Create a copy of Spi
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SpiImplCopyWith<_$SpiImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
