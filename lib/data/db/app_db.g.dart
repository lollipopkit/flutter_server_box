// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $ServersTable extends Servers with TableInfo<$ServersTable, Server> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ipMeta = const VerificationMeta('ip');
  @override
  late final GeneratedColumn<String> ip = GeneratedColumn<String>(
    'ip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userMeta = const VerificationMeta('user');
  @override
  late final GeneratedColumn<String> user = GeneratedColumn<String>(
    'user',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pwdMeta = const VerificationMeta('pwd');
  @override
  late final GeneratedColumn<String> pwd = GeneratedColumn<String>(
    'pwd',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keyIdMeta = const VerificationMeta('keyId');
  @override
  late final GeneratedColumn<String> keyId = GeneratedColumn<String>(
    'key_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _alterUrlMeta = const VerificationMeta(
    'alterUrl',
  );
  @override
  late final GeneratedColumn<String> alterUrl = GeneratedColumn<String>(
    'alter_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _autoConnectMeta = const VerificationMeta(
    'autoConnect',
  );
  @override
  late final GeneratedColumn<bool> autoConnect = GeneratedColumn<bool>(
    'auto_connect',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_connect" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _jumpIdMeta = const VerificationMeta('jumpId');
  @override
  late final GeneratedColumn<String> jumpId = GeneratedColumn<String>(
    'jump_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customSystemTypeMeta = const VerificationMeta(
    'customSystemType',
  );
  @override
  late final GeneratedColumn<String> customSystemType = GeneratedColumn<String>(
    'custom_system_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    ip,
    port,
    user,
    pwd,
    keyId,
    alterUrl,
    autoConnect,
    jumpId,
    customSystemType,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'servers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Server> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('ip')) {
      context.handle(_ipMeta, ip.isAcceptableOrUnknown(data['ip']!, _ipMeta));
    } else if (isInserting) {
      context.missing(_ipMeta);
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    } else if (isInserting) {
      context.missing(_portMeta);
    }
    if (data.containsKey('user')) {
      context.handle(
        _userMeta,
        user.isAcceptableOrUnknown(data['user']!, _userMeta),
      );
    } else if (isInserting) {
      context.missing(_userMeta);
    }
    if (data.containsKey('pwd')) {
      context.handle(
        _pwdMeta,
        pwd.isAcceptableOrUnknown(data['pwd']!, _pwdMeta),
      );
    }
    if (data.containsKey('key_id')) {
      context.handle(
        _keyIdMeta,
        keyId.isAcceptableOrUnknown(data['key_id']!, _keyIdMeta),
      );
    }
    if (data.containsKey('alter_url')) {
      context.handle(
        _alterUrlMeta,
        alterUrl.isAcceptableOrUnknown(data['alter_url']!, _alterUrlMeta),
      );
    }
    if (data.containsKey('auto_connect')) {
      context.handle(
        _autoConnectMeta,
        autoConnect.isAcceptableOrUnknown(
          data['auto_connect']!,
          _autoConnectMeta,
        ),
      );
    }
    if (data.containsKey('jump_id')) {
      context.handle(
        _jumpIdMeta,
        jumpId.isAcceptableOrUnknown(data['jump_id']!, _jumpIdMeta),
      );
    }
    if (data.containsKey('custom_system_type')) {
      context.handle(
        _customSystemTypeMeta,
        customSystemType.isAcceptableOrUnknown(
          data['custom_system_type']!,
          _customSystemTypeMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Server map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Server(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      ip: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ip'],
      )!,
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      )!,
      user: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user'],
      )!,
      pwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pwd'],
      ),
      keyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_id'],
      ),
      alterUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alter_url'],
      ),
      autoConnect: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_connect'],
      )!,
      jumpId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jump_id'],
      ),
      customSystemType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_system_type'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ServersTable createAlias(String alias) {
    return $ServersTable(attachedDatabase, alias);
  }
}

class Server extends DataClass implements Insertable<Server> {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String user;
  final String? pwd;
  final String? keyId;
  final String? alterUrl;
  final bool autoConnect;
  final String? jumpId;
  final String? customSystemType;
  final int updatedAt;
  const Server({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.user,
    this.pwd,
    this.keyId,
    this.alterUrl,
    required this.autoConnect,
    this.jumpId,
    this.customSystemType,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['ip'] = Variable<String>(ip);
    map['port'] = Variable<int>(port);
    map['user'] = Variable<String>(user);
    if (!nullToAbsent || pwd != null) {
      map['pwd'] = Variable<String>(pwd);
    }
    if (!nullToAbsent || keyId != null) {
      map['key_id'] = Variable<String>(keyId);
    }
    if (!nullToAbsent || alterUrl != null) {
      map['alter_url'] = Variable<String>(alterUrl);
    }
    map['auto_connect'] = Variable<bool>(autoConnect);
    if (!nullToAbsent || jumpId != null) {
      map['jump_id'] = Variable<String>(jumpId);
    }
    if (!nullToAbsent || customSystemType != null) {
      map['custom_system_type'] = Variable<String>(customSystemType);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ServersCompanion toCompanion(bool nullToAbsent) {
    return ServersCompanion(
      id: Value(id),
      name: Value(name),
      ip: Value(ip),
      port: Value(port),
      user: Value(user),
      pwd: pwd == null && nullToAbsent ? const Value.absent() : Value(pwd),
      keyId: keyId == null && nullToAbsent
          ? const Value.absent()
          : Value(keyId),
      alterUrl: alterUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(alterUrl),
      autoConnect: Value(autoConnect),
      jumpId: jumpId == null && nullToAbsent
          ? const Value.absent()
          : Value(jumpId),
      customSystemType: customSystemType == null && nullToAbsent
          ? const Value.absent()
          : Value(customSystemType),
      updatedAt: Value(updatedAt),
    );
  }

  factory Server.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Server(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      ip: serializer.fromJson<String>(json['ip']),
      port: serializer.fromJson<int>(json['port']),
      user: serializer.fromJson<String>(json['user']),
      pwd: serializer.fromJson<String?>(json['pwd']),
      keyId: serializer.fromJson<String?>(json['keyId']),
      alterUrl: serializer.fromJson<String?>(json['alterUrl']),
      autoConnect: serializer.fromJson<bool>(json['autoConnect']),
      jumpId: serializer.fromJson<String?>(json['jumpId']),
      customSystemType: serializer.fromJson<String?>(json['customSystemType']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'ip': serializer.toJson<String>(ip),
      'port': serializer.toJson<int>(port),
      'user': serializer.toJson<String>(user),
      'pwd': serializer.toJson<String?>(pwd),
      'keyId': serializer.toJson<String?>(keyId),
      'alterUrl': serializer.toJson<String?>(alterUrl),
      'autoConnect': serializer.toJson<bool>(autoConnect),
      'jumpId': serializer.toJson<String?>(jumpId),
      'customSystemType': serializer.toJson<String?>(customSystemType),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Server copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    String? user,
    Value<String?> pwd = const Value.absent(),
    Value<String?> keyId = const Value.absent(),
    Value<String?> alterUrl = const Value.absent(),
    bool? autoConnect,
    Value<String?> jumpId = const Value.absent(),
    Value<String?> customSystemType = const Value.absent(),
    int? updatedAt,
  }) => Server(
    id: id ?? this.id,
    name: name ?? this.name,
    ip: ip ?? this.ip,
    port: port ?? this.port,
    user: user ?? this.user,
    pwd: pwd.present ? pwd.value : this.pwd,
    keyId: keyId.present ? keyId.value : this.keyId,
    alterUrl: alterUrl.present ? alterUrl.value : this.alterUrl,
    autoConnect: autoConnect ?? this.autoConnect,
    jumpId: jumpId.present ? jumpId.value : this.jumpId,
    customSystemType: customSystemType.present
        ? customSystemType.value
        : this.customSystemType,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Server copyWithCompanion(ServersCompanion data) {
    return Server(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      ip: data.ip.present ? data.ip.value : this.ip,
      port: data.port.present ? data.port.value : this.port,
      user: data.user.present ? data.user.value : this.user,
      pwd: data.pwd.present ? data.pwd.value : this.pwd,
      keyId: data.keyId.present ? data.keyId.value : this.keyId,
      alterUrl: data.alterUrl.present ? data.alterUrl.value : this.alterUrl,
      autoConnect: data.autoConnect.present
          ? data.autoConnect.value
          : this.autoConnect,
      jumpId: data.jumpId.present ? data.jumpId.value : this.jumpId,
      customSystemType: data.customSystemType.present
          ? data.customSystemType.value
          : this.customSystemType,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Server(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ip: $ip, ')
          ..write('port: $port, ')
          ..write('user: $user, ')
          ..write('pwd: $pwd, ')
          ..write('keyId: $keyId, ')
          ..write('alterUrl: $alterUrl, ')
          ..write('autoConnect: $autoConnect, ')
          ..write('jumpId: $jumpId, ')
          ..write('customSystemType: $customSystemType, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    ip,
    port,
    user,
    pwd,
    keyId,
    alterUrl,
    autoConnect,
    jumpId,
    customSystemType,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Server &&
          other.id == this.id &&
          other.name == this.name &&
          other.ip == this.ip &&
          other.port == this.port &&
          other.user == this.user &&
          other.pwd == this.pwd &&
          other.keyId == this.keyId &&
          other.alterUrl == this.alterUrl &&
          other.autoConnect == this.autoConnect &&
          other.jumpId == this.jumpId &&
          other.customSystemType == this.customSystemType &&
          other.updatedAt == this.updatedAt);
}

class ServersCompanion extends UpdateCompanion<Server> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> ip;
  final Value<int> port;
  final Value<String> user;
  final Value<String?> pwd;
  final Value<String?> keyId;
  final Value<String?> alterUrl;
  final Value<bool> autoConnect;
  final Value<String?> jumpId;
  final Value<String?> customSystemType;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ServersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.ip = const Value.absent(),
    this.port = const Value.absent(),
    this.user = const Value.absent(),
    this.pwd = const Value.absent(),
    this.keyId = const Value.absent(),
    this.alterUrl = const Value.absent(),
    this.autoConnect = const Value.absent(),
    this.jumpId = const Value.absent(),
    this.customSystemType = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServersCompanion.insert({
    required String id,
    required String name,
    required String ip,
    required int port,
    required String user,
    this.pwd = const Value.absent(),
    this.keyId = const Value.absent(),
    this.alterUrl = const Value.absent(),
    this.autoConnect = const Value.absent(),
    this.jumpId = const Value.absent(),
    this.customSystemType = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       ip = Value(ip),
       port = Value(port),
       user = Value(user),
       updatedAt = Value(updatedAt);
  static Insertable<Server> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? ip,
    Expression<int>? port,
    Expression<String>? user,
    Expression<String>? pwd,
    Expression<String>? keyId,
    Expression<String>? alterUrl,
    Expression<bool>? autoConnect,
    Expression<String>? jumpId,
    Expression<String>? customSystemType,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (ip != null) 'ip': ip,
      if (port != null) 'port': port,
      if (user != null) 'user': user,
      if (pwd != null) 'pwd': pwd,
      if (keyId != null) 'key_id': keyId,
      if (alterUrl != null) 'alter_url': alterUrl,
      if (autoConnect != null) 'auto_connect': autoConnect,
      if (jumpId != null) 'jump_id': jumpId,
      if (customSystemType != null) 'custom_system_type': customSystemType,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? ip,
    Value<int>? port,
    Value<String>? user,
    Value<String?>? pwd,
    Value<String?>? keyId,
    Value<String?>? alterUrl,
    Value<bool>? autoConnect,
    Value<String?>? jumpId,
    Value<String?>? customSystemType,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ServersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      user: user ?? this.user,
      pwd: pwd ?? this.pwd,
      keyId: keyId ?? this.keyId,
      alterUrl: alterUrl ?? this.alterUrl,
      autoConnect: autoConnect ?? this.autoConnect,
      jumpId: jumpId ?? this.jumpId,
      customSystemType: customSystemType ?? this.customSystemType,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (ip.present) {
      map['ip'] = Variable<String>(ip.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (user.present) {
      map['user'] = Variable<String>(user.value);
    }
    if (pwd.present) {
      map['pwd'] = Variable<String>(pwd.value);
    }
    if (keyId.present) {
      map['key_id'] = Variable<String>(keyId.value);
    }
    if (alterUrl.present) {
      map['alter_url'] = Variable<String>(alterUrl.value);
    }
    if (autoConnect.present) {
      map['auto_connect'] = Variable<bool>(autoConnect.value);
    }
    if (jumpId.present) {
      map['jump_id'] = Variable<String>(jumpId.value);
    }
    if (customSystemType.present) {
      map['custom_system_type'] = Variable<String>(customSystemType.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ip: $ip, ')
          ..write('port: $port, ')
          ..write('user: $user, ')
          ..write('pwd: $pwd, ')
          ..write('keyId: $keyId, ')
          ..write('alterUrl: $alterUrl, ')
          ..write('autoConnect: $autoConnect, ')
          ..write('jumpId: $jumpId, ')
          ..write('customSystemType: $customSystemType, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServerCustomsTable extends ServerCustoms
    with TableInfo<$ServerCustomsTable, ServerCustom> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServerCustomsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES servers(id) ON DELETE CASCADE',
  );
  static const VerificationMeta _pveAddrMeta = const VerificationMeta(
    'pveAddr',
  );
  @override
  late final GeneratedColumn<String> pveAddr = GeneratedColumn<String>(
    'pve_addr',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pveIgnoreCertMeta = const VerificationMeta(
    'pveIgnoreCert',
  );
  @override
  late final GeneratedColumn<bool> pveIgnoreCert = GeneratedColumn<bool>(
    'pve_ignore_cert',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pve_ignore_cert" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _cmdsJsonMeta = const VerificationMeta(
    'cmdsJson',
  );
  @override
  late final GeneratedColumn<String> cmdsJson = GeneratedColumn<String>(
    'cmds_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preferTempDevMeta = const VerificationMeta(
    'preferTempDev',
  );
  @override
  late final GeneratedColumn<String> preferTempDev = GeneratedColumn<String>(
    'prefer_temp_dev',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logoUrlMeta = const VerificationMeta(
    'logoUrl',
  );
  @override
  late final GeneratedColumn<String> logoUrl = GeneratedColumn<String>(
    'logo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _netDevMeta = const VerificationMeta('netDev');
  @override
  late final GeneratedColumn<String> netDev = GeneratedColumn<String>(
    'net_dev',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scriptDirMeta = const VerificationMeta(
    'scriptDir',
  );
  @override
  late final GeneratedColumn<String> scriptDir = GeneratedColumn<String>(
    'script_dir',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    pveAddr,
    pveIgnoreCert,
    cmdsJson,
    preferTempDev,
    logoUrl,
    netDev,
    scriptDir,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server_customs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerCustom> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('pve_addr')) {
      context.handle(
        _pveAddrMeta,
        pveAddr.isAcceptableOrUnknown(data['pve_addr']!, _pveAddrMeta),
      );
    }
    if (data.containsKey('pve_ignore_cert')) {
      context.handle(
        _pveIgnoreCertMeta,
        pveIgnoreCert.isAcceptableOrUnknown(
          data['pve_ignore_cert']!,
          _pveIgnoreCertMeta,
        ),
      );
    }
    if (data.containsKey('cmds_json')) {
      context.handle(
        _cmdsJsonMeta,
        cmdsJson.isAcceptableOrUnknown(data['cmds_json']!, _cmdsJsonMeta),
      );
    }
    if (data.containsKey('prefer_temp_dev')) {
      context.handle(
        _preferTempDevMeta,
        preferTempDev.isAcceptableOrUnknown(
          data['prefer_temp_dev']!,
          _preferTempDevMeta,
        ),
      );
    }
    if (data.containsKey('logo_url')) {
      context.handle(
        _logoUrlMeta,
        logoUrl.isAcceptableOrUnknown(data['logo_url']!, _logoUrlMeta),
      );
    }
    if (data.containsKey('net_dev')) {
      context.handle(
        _netDevMeta,
        netDev.isAcceptableOrUnknown(data['net_dev']!, _netDevMeta),
      );
    }
    if (data.containsKey('script_dir')) {
      context.handle(
        _scriptDirMeta,
        scriptDir.isAcceptableOrUnknown(data['script_dir']!, _scriptDirMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId};
  @override
  ServerCustom map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerCustom(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      pveAddr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pve_addr'],
      ),
      pveIgnoreCert: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pve_ignore_cert'],
      )!,
      cmdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cmds_json'],
      ),
      preferTempDev: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prefer_temp_dev'],
      ),
      logoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_url'],
      ),
      netDev: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}net_dev'],
      ),
      scriptDir: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}script_dir'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ServerCustomsTable createAlias(String alias) {
    return $ServerCustomsTable(attachedDatabase, alias);
  }
}

class ServerCustom extends DataClass implements Insertable<ServerCustom> {
  final String serverId;
  final String? pveAddr;
  final bool pveIgnoreCert;
  final String? cmdsJson;
  final String? preferTempDev;
  final String? logoUrl;
  final String? netDev;
  final String? scriptDir;
  final int updatedAt;
  const ServerCustom({
    required this.serverId,
    this.pveAddr,
    required this.pveIgnoreCert,
    this.cmdsJson,
    this.preferTempDev,
    this.logoUrl,
    this.netDev,
    this.scriptDir,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    if (!nullToAbsent || pveAddr != null) {
      map['pve_addr'] = Variable<String>(pveAddr);
    }
    map['pve_ignore_cert'] = Variable<bool>(pveIgnoreCert);
    if (!nullToAbsent || cmdsJson != null) {
      map['cmds_json'] = Variable<String>(cmdsJson);
    }
    if (!nullToAbsent || preferTempDev != null) {
      map['prefer_temp_dev'] = Variable<String>(preferTempDev);
    }
    if (!nullToAbsent || logoUrl != null) {
      map['logo_url'] = Variable<String>(logoUrl);
    }
    if (!nullToAbsent || netDev != null) {
      map['net_dev'] = Variable<String>(netDev);
    }
    if (!nullToAbsent || scriptDir != null) {
      map['script_dir'] = Variable<String>(scriptDir);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ServerCustomsCompanion toCompanion(bool nullToAbsent) {
    return ServerCustomsCompanion(
      serverId: Value(serverId),
      pveAddr: pveAddr == null && nullToAbsent
          ? const Value.absent()
          : Value(pveAddr),
      pveIgnoreCert: Value(pveIgnoreCert),
      cmdsJson: cmdsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(cmdsJson),
      preferTempDev: preferTempDev == null && nullToAbsent
          ? const Value.absent()
          : Value(preferTempDev),
      logoUrl: logoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(logoUrl),
      netDev: netDev == null && nullToAbsent
          ? const Value.absent()
          : Value(netDev),
      scriptDir: scriptDir == null && nullToAbsent
          ? const Value.absent()
          : Value(scriptDir),
      updatedAt: Value(updatedAt),
    );
  }

  factory ServerCustom.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerCustom(
      serverId: serializer.fromJson<String>(json['serverId']),
      pveAddr: serializer.fromJson<String?>(json['pveAddr']),
      pveIgnoreCert: serializer.fromJson<bool>(json['pveIgnoreCert']),
      cmdsJson: serializer.fromJson<String?>(json['cmdsJson']),
      preferTempDev: serializer.fromJson<String?>(json['preferTempDev']),
      logoUrl: serializer.fromJson<String?>(json['logoUrl']),
      netDev: serializer.fromJson<String?>(json['netDev']),
      scriptDir: serializer.fromJson<String?>(json['scriptDir']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'pveAddr': serializer.toJson<String?>(pveAddr),
      'pveIgnoreCert': serializer.toJson<bool>(pveIgnoreCert),
      'cmdsJson': serializer.toJson<String?>(cmdsJson),
      'preferTempDev': serializer.toJson<String?>(preferTempDev),
      'logoUrl': serializer.toJson<String?>(logoUrl),
      'netDev': serializer.toJson<String?>(netDev),
      'scriptDir': serializer.toJson<String?>(scriptDir),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ServerCustom copyWith({
    String? serverId,
    Value<String?> pveAddr = const Value.absent(),
    bool? pveIgnoreCert,
    Value<String?> cmdsJson = const Value.absent(),
    Value<String?> preferTempDev = const Value.absent(),
    Value<String?> logoUrl = const Value.absent(),
    Value<String?> netDev = const Value.absent(),
    Value<String?> scriptDir = const Value.absent(),
    int? updatedAt,
  }) => ServerCustom(
    serverId: serverId ?? this.serverId,
    pveAddr: pveAddr.present ? pveAddr.value : this.pveAddr,
    pveIgnoreCert: pveIgnoreCert ?? this.pveIgnoreCert,
    cmdsJson: cmdsJson.present ? cmdsJson.value : this.cmdsJson,
    preferTempDev: preferTempDev.present
        ? preferTempDev.value
        : this.preferTempDev,
    logoUrl: logoUrl.present ? logoUrl.value : this.logoUrl,
    netDev: netDev.present ? netDev.value : this.netDev,
    scriptDir: scriptDir.present ? scriptDir.value : this.scriptDir,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ServerCustom copyWithCompanion(ServerCustomsCompanion data) {
    return ServerCustom(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      pveAddr: data.pveAddr.present ? data.pveAddr.value : this.pveAddr,
      pveIgnoreCert: data.pveIgnoreCert.present
          ? data.pveIgnoreCert.value
          : this.pveIgnoreCert,
      cmdsJson: data.cmdsJson.present ? data.cmdsJson.value : this.cmdsJson,
      preferTempDev: data.preferTempDev.present
          ? data.preferTempDev.value
          : this.preferTempDev,
      logoUrl: data.logoUrl.present ? data.logoUrl.value : this.logoUrl,
      netDev: data.netDev.present ? data.netDev.value : this.netDev,
      scriptDir: data.scriptDir.present ? data.scriptDir.value : this.scriptDir,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerCustom(')
          ..write('serverId: $serverId, ')
          ..write('pveAddr: $pveAddr, ')
          ..write('pveIgnoreCert: $pveIgnoreCert, ')
          ..write('cmdsJson: $cmdsJson, ')
          ..write('preferTempDev: $preferTempDev, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('netDev: $netDev, ')
          ..write('scriptDir: $scriptDir, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    serverId,
    pveAddr,
    pveIgnoreCert,
    cmdsJson,
    preferTempDev,
    logoUrl,
    netDev,
    scriptDir,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerCustom &&
          other.serverId == this.serverId &&
          other.pveAddr == this.pveAddr &&
          other.pveIgnoreCert == this.pveIgnoreCert &&
          other.cmdsJson == this.cmdsJson &&
          other.preferTempDev == this.preferTempDev &&
          other.logoUrl == this.logoUrl &&
          other.netDev == this.netDev &&
          other.scriptDir == this.scriptDir &&
          other.updatedAt == this.updatedAt);
}

class ServerCustomsCompanion extends UpdateCompanion<ServerCustom> {
  final Value<String> serverId;
  final Value<String?> pveAddr;
  final Value<bool> pveIgnoreCert;
  final Value<String?> cmdsJson;
  final Value<String?> preferTempDev;
  final Value<String?> logoUrl;
  final Value<String?> netDev;
  final Value<String?> scriptDir;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ServerCustomsCompanion({
    this.serverId = const Value.absent(),
    this.pveAddr = const Value.absent(),
    this.pveIgnoreCert = const Value.absent(),
    this.cmdsJson = const Value.absent(),
    this.preferTempDev = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.netDev = const Value.absent(),
    this.scriptDir = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServerCustomsCompanion.insert({
    required String serverId,
    this.pveAddr = const Value.absent(),
    this.pveIgnoreCert = const Value.absent(),
    this.cmdsJson = const Value.absent(),
    this.preferTempDev = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.netDev = const Value.absent(),
    this.scriptDir = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       updatedAt = Value(updatedAt);
  static Insertable<ServerCustom> custom({
    Expression<String>? serverId,
    Expression<String>? pveAddr,
    Expression<bool>? pveIgnoreCert,
    Expression<String>? cmdsJson,
    Expression<String>? preferTempDev,
    Expression<String>? logoUrl,
    Expression<String>? netDev,
    Expression<String>? scriptDir,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (pveAddr != null) 'pve_addr': pveAddr,
      if (pveIgnoreCert != null) 'pve_ignore_cert': pveIgnoreCert,
      if (cmdsJson != null) 'cmds_json': cmdsJson,
      if (preferTempDev != null) 'prefer_temp_dev': preferTempDev,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (netDev != null) 'net_dev': netDev,
      if (scriptDir != null) 'script_dir': scriptDir,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServerCustomsCompanion copyWith({
    Value<String>? serverId,
    Value<String?>? pveAddr,
    Value<bool>? pveIgnoreCert,
    Value<String?>? cmdsJson,
    Value<String?>? preferTempDev,
    Value<String?>? logoUrl,
    Value<String?>? netDev,
    Value<String?>? scriptDir,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ServerCustomsCompanion(
      serverId: serverId ?? this.serverId,
      pveAddr: pveAddr ?? this.pveAddr,
      pveIgnoreCert: pveIgnoreCert ?? this.pveIgnoreCert,
      cmdsJson: cmdsJson ?? this.cmdsJson,
      preferTempDev: preferTempDev ?? this.preferTempDev,
      logoUrl: logoUrl ?? this.logoUrl,
      netDev: netDev ?? this.netDev,
      scriptDir: scriptDir ?? this.scriptDir,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (pveAddr.present) {
      map['pve_addr'] = Variable<String>(pveAddr.value);
    }
    if (pveIgnoreCert.present) {
      map['pve_ignore_cert'] = Variable<bool>(pveIgnoreCert.value);
    }
    if (cmdsJson.present) {
      map['cmds_json'] = Variable<String>(cmdsJson.value);
    }
    if (preferTempDev.present) {
      map['prefer_temp_dev'] = Variable<String>(preferTempDev.value);
    }
    if (logoUrl.present) {
      map['logo_url'] = Variable<String>(logoUrl.value);
    }
    if (netDev.present) {
      map['net_dev'] = Variable<String>(netDev.value);
    }
    if (scriptDir.present) {
      map['script_dir'] = Variable<String>(scriptDir.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerCustomsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('pveAddr: $pveAddr, ')
          ..write('pveIgnoreCert: $pveIgnoreCert, ')
          ..write('cmdsJson: $cmdsJson, ')
          ..write('preferTempDev: $preferTempDev, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('netDev: $netDev, ')
          ..write('scriptDir: $scriptDir, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServerWolCfgsTable extends ServerWolCfgs
    with TableInfo<$ServerWolCfgsTable, ServerWolCfg> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServerWolCfgsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES servers(id) ON DELETE CASCADE',
  );
  static const VerificationMeta _macMeta = const VerificationMeta('mac');
  @override
  late final GeneratedColumn<String> mac = GeneratedColumn<String>(
    'mac',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ipMeta = const VerificationMeta('ip');
  @override
  late final GeneratedColumn<String> ip = GeneratedColumn<String>(
    'ip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pwdMeta = const VerificationMeta('pwd');
  @override
  late final GeneratedColumn<String> pwd = GeneratedColumn<String>(
    'pwd',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [serverId, mac, ip, pwd, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server_wol_cfgs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerWolCfg> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('mac')) {
      context.handle(
        _macMeta,
        mac.isAcceptableOrUnknown(data['mac']!, _macMeta),
      );
    } else if (isInserting) {
      context.missing(_macMeta);
    }
    if (data.containsKey('ip')) {
      context.handle(_ipMeta, ip.isAcceptableOrUnknown(data['ip']!, _ipMeta));
    } else if (isInserting) {
      context.missing(_ipMeta);
    }
    if (data.containsKey('pwd')) {
      context.handle(
        _pwdMeta,
        pwd.isAcceptableOrUnknown(data['pwd']!, _pwdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId};
  @override
  ServerWolCfg map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerWolCfg(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      mac: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mac'],
      )!,
      ip: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ip'],
      )!,
      pwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pwd'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ServerWolCfgsTable createAlias(String alias) {
    return $ServerWolCfgsTable(attachedDatabase, alias);
  }
}

class ServerWolCfg extends DataClass implements Insertable<ServerWolCfg> {
  final String serverId;
  final String mac;
  final String ip;
  final String? pwd;
  final int updatedAt;
  const ServerWolCfg({
    required this.serverId,
    required this.mac,
    required this.ip,
    this.pwd,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['mac'] = Variable<String>(mac);
    map['ip'] = Variable<String>(ip);
    if (!nullToAbsent || pwd != null) {
      map['pwd'] = Variable<String>(pwd);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ServerWolCfgsCompanion toCompanion(bool nullToAbsent) {
    return ServerWolCfgsCompanion(
      serverId: Value(serverId),
      mac: Value(mac),
      ip: Value(ip),
      pwd: pwd == null && nullToAbsent ? const Value.absent() : Value(pwd),
      updatedAt: Value(updatedAt),
    );
  }

  factory ServerWolCfg.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerWolCfg(
      serverId: serializer.fromJson<String>(json['serverId']),
      mac: serializer.fromJson<String>(json['mac']),
      ip: serializer.fromJson<String>(json['ip']),
      pwd: serializer.fromJson<String?>(json['pwd']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'mac': serializer.toJson<String>(mac),
      'ip': serializer.toJson<String>(ip),
      'pwd': serializer.toJson<String?>(pwd),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ServerWolCfg copyWith({
    String? serverId,
    String? mac,
    String? ip,
    Value<String?> pwd = const Value.absent(),
    int? updatedAt,
  }) => ServerWolCfg(
    serverId: serverId ?? this.serverId,
    mac: mac ?? this.mac,
    ip: ip ?? this.ip,
    pwd: pwd.present ? pwd.value : this.pwd,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ServerWolCfg copyWithCompanion(ServerWolCfgsCompanion data) {
    return ServerWolCfg(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      mac: data.mac.present ? data.mac.value : this.mac,
      ip: data.ip.present ? data.ip.value : this.ip,
      pwd: data.pwd.present ? data.pwd.value : this.pwd,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerWolCfg(')
          ..write('serverId: $serverId, ')
          ..write('mac: $mac, ')
          ..write('ip: $ip, ')
          ..write('pwd: $pwd, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, mac, ip, pwd, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerWolCfg &&
          other.serverId == this.serverId &&
          other.mac == this.mac &&
          other.ip == this.ip &&
          other.pwd == this.pwd &&
          other.updatedAt == this.updatedAt);
}

class ServerWolCfgsCompanion extends UpdateCompanion<ServerWolCfg> {
  final Value<String> serverId;
  final Value<String> mac;
  final Value<String> ip;
  final Value<String?> pwd;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ServerWolCfgsCompanion({
    this.serverId = const Value.absent(),
    this.mac = const Value.absent(),
    this.ip = const Value.absent(),
    this.pwd = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServerWolCfgsCompanion.insert({
    required String serverId,
    required String mac,
    required String ip,
    this.pwd = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       mac = Value(mac),
       ip = Value(ip),
       updatedAt = Value(updatedAt);
  static Insertable<ServerWolCfg> custom({
    Expression<String>? serverId,
    Expression<String>? mac,
    Expression<String>? ip,
    Expression<String>? pwd,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (mac != null) 'mac': mac,
      if (ip != null) 'ip': ip,
      if (pwd != null) 'pwd': pwd,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServerWolCfgsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? mac,
    Value<String>? ip,
    Value<String?>? pwd,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ServerWolCfgsCompanion(
      serverId: serverId ?? this.serverId,
      mac: mac ?? this.mac,
      ip: ip ?? this.ip,
      pwd: pwd ?? this.pwd,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (mac.present) {
      map['mac'] = Variable<String>(mac.value);
    }
    if (ip.present) {
      map['ip'] = Variable<String>(ip.value);
    }
    if (pwd.present) {
      map['pwd'] = Variable<String>(pwd.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerWolCfgsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('mac: $mac, ')
          ..write('ip: $ip, ')
          ..write('pwd: $pwd, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServerTagsTable extends ServerTags
    with TableInfo<$ServerTagsTable, ServerTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServerTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES servers(id) ON DELETE CASCADE',
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [serverId, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, tag};
  @override
  ServerTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerTag(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
    );
  }

  @override
  $ServerTagsTable createAlias(String alias) {
    return $ServerTagsTable(attachedDatabase, alias);
  }
}

class ServerTag extends DataClass implements Insertable<ServerTag> {
  final String serverId;
  final String tag;
  const ServerTag({required this.serverId, required this.tag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  ServerTagsCompanion toCompanion(bool nullToAbsent) {
    return ServerTagsCompanion(serverId: Value(serverId), tag: Value(tag));
  }

  factory ServerTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerTag(
      serverId: serializer.fromJson<String>(json['serverId']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'tag': serializer.toJson<String>(tag),
    };
  }

  ServerTag copyWith({String? serverId, String? tag}) =>
      ServerTag(serverId: serverId ?? this.serverId, tag: tag ?? this.tag);
  ServerTag copyWithCompanion(ServerTagsCompanion data) {
    return ServerTag(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerTag(')
          ..write('serverId: $serverId, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerTag &&
          other.serverId == this.serverId &&
          other.tag == this.tag);
}

class ServerTagsCompanion extends UpdateCompanion<ServerTag> {
  final Value<String> serverId;
  final Value<String> tag;
  final Value<int> rowid;
  const ServerTagsCompanion({
    this.serverId = const Value.absent(),
    this.tag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServerTagsCompanion.insert({
    required String serverId,
    required String tag,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       tag = Value(tag);
  static Insertable<ServerTag> custom({
    Expression<String>? serverId,
    Expression<String>? tag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (tag != null) 'tag': tag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServerTagsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? tag,
    Value<int>? rowid,
  }) {
    return ServerTagsCompanion(
      serverId: serverId ?? this.serverId,
      tag: tag ?? this.tag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerTagsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('tag: $tag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServerEnvsTable extends ServerEnvs
    with TableInfo<$ServerEnvsTable, ServerEnv> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServerEnvsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES servers(id) ON DELETE CASCADE',
  );
  static const VerificationMeta _envKeyMeta = const VerificationMeta('envKey');
  @override
  late final GeneratedColumn<String> envKey = GeneratedColumn<String>(
    'env_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _envValMeta = const VerificationMeta('envVal');
  @override
  late final GeneratedColumn<String> envVal = GeneratedColumn<String>(
    'env_val',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [serverId, envKey, envVal];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server_envs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerEnv> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('env_key')) {
      context.handle(
        _envKeyMeta,
        envKey.isAcceptableOrUnknown(data['env_key']!, _envKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_envKeyMeta);
    }
    if (data.containsKey('env_val')) {
      context.handle(
        _envValMeta,
        envVal.isAcceptableOrUnknown(data['env_val']!, _envValMeta),
      );
    } else if (isInserting) {
      context.missing(_envValMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, envKey};
  @override
  ServerEnv map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerEnv(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      envKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}env_key'],
      )!,
      envVal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}env_val'],
      )!,
    );
  }

  @override
  $ServerEnvsTable createAlias(String alias) {
    return $ServerEnvsTable(attachedDatabase, alias);
  }
}

class ServerEnv extends DataClass implements Insertable<ServerEnv> {
  final String serverId;
  final String envKey;
  final String envVal;
  const ServerEnv({
    required this.serverId,
    required this.envKey,
    required this.envVal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['env_key'] = Variable<String>(envKey);
    map['env_val'] = Variable<String>(envVal);
    return map;
  }

  ServerEnvsCompanion toCompanion(bool nullToAbsent) {
    return ServerEnvsCompanion(
      serverId: Value(serverId),
      envKey: Value(envKey),
      envVal: Value(envVal),
    );
  }

  factory ServerEnv.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerEnv(
      serverId: serializer.fromJson<String>(json['serverId']),
      envKey: serializer.fromJson<String>(json['envKey']),
      envVal: serializer.fromJson<String>(json['envVal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'envKey': serializer.toJson<String>(envKey),
      'envVal': serializer.toJson<String>(envVal),
    };
  }

  ServerEnv copyWith({String? serverId, String? envKey, String? envVal}) =>
      ServerEnv(
        serverId: serverId ?? this.serverId,
        envKey: envKey ?? this.envKey,
        envVal: envVal ?? this.envVal,
      );
  ServerEnv copyWithCompanion(ServerEnvsCompanion data) {
    return ServerEnv(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      envKey: data.envKey.present ? data.envKey.value : this.envKey,
      envVal: data.envVal.present ? data.envVal.value : this.envVal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerEnv(')
          ..write('serverId: $serverId, ')
          ..write('envKey: $envKey, ')
          ..write('envVal: $envVal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, envKey, envVal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerEnv &&
          other.serverId == this.serverId &&
          other.envKey == this.envKey &&
          other.envVal == this.envVal);
}

class ServerEnvsCompanion extends UpdateCompanion<ServerEnv> {
  final Value<String> serverId;
  final Value<String> envKey;
  final Value<String> envVal;
  final Value<int> rowid;
  const ServerEnvsCompanion({
    this.serverId = const Value.absent(),
    this.envKey = const Value.absent(),
    this.envVal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServerEnvsCompanion.insert({
    required String serverId,
    required String envKey,
    required String envVal,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       envKey = Value(envKey),
       envVal = Value(envVal);
  static Insertable<ServerEnv> custom({
    Expression<String>? serverId,
    Expression<String>? envKey,
    Expression<String>? envVal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (envKey != null) 'env_key': envKey,
      if (envVal != null) 'env_val': envVal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServerEnvsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? envKey,
    Value<String>? envVal,
    Value<int>? rowid,
  }) {
    return ServerEnvsCompanion(
      serverId: serverId ?? this.serverId,
      envKey: envKey ?? this.envKey,
      envVal: envVal ?? this.envVal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (envKey.present) {
      map['env_key'] = Variable<String>(envKey.value);
    }
    if (envVal.present) {
      map['env_val'] = Variable<String>(envVal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerEnvsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('envKey: $envKey, ')
          ..write('envVal: $envVal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServerDisabledCmdTypesTable extends ServerDisabledCmdTypes
    with TableInfo<$ServerDisabledCmdTypesTable, ServerDisabledCmdType> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServerDisabledCmdTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES servers(id) ON DELETE CASCADE',
  );
  static const VerificationMeta _cmdTypeMeta = const VerificationMeta(
    'cmdType',
  );
  @override
  late final GeneratedColumn<String> cmdType = GeneratedColumn<String>(
    'cmd_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [serverId, cmdType];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server_disabled_cmd_types';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerDisabledCmdType> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('cmd_type')) {
      context.handle(
        _cmdTypeMeta,
        cmdType.isAcceptableOrUnknown(data['cmd_type']!, _cmdTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_cmdTypeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, cmdType};
  @override
  ServerDisabledCmdType map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerDisabledCmdType(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      cmdType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cmd_type'],
      )!,
    );
  }

  @override
  $ServerDisabledCmdTypesTable createAlias(String alias) {
    return $ServerDisabledCmdTypesTable(attachedDatabase, alias);
  }
}

class ServerDisabledCmdType extends DataClass
    implements Insertable<ServerDisabledCmdType> {
  final String serverId;
  final String cmdType;
  const ServerDisabledCmdType({required this.serverId, required this.cmdType});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['cmd_type'] = Variable<String>(cmdType);
    return map;
  }

  ServerDisabledCmdTypesCompanion toCompanion(bool nullToAbsent) {
    return ServerDisabledCmdTypesCompanion(
      serverId: Value(serverId),
      cmdType: Value(cmdType),
    );
  }

  factory ServerDisabledCmdType.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerDisabledCmdType(
      serverId: serializer.fromJson<String>(json['serverId']),
      cmdType: serializer.fromJson<String>(json['cmdType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'cmdType': serializer.toJson<String>(cmdType),
    };
  }

  ServerDisabledCmdType copyWith({String? serverId, String? cmdType}) =>
      ServerDisabledCmdType(
        serverId: serverId ?? this.serverId,
        cmdType: cmdType ?? this.cmdType,
      );
  ServerDisabledCmdType copyWithCompanion(
    ServerDisabledCmdTypesCompanion data,
  ) {
    return ServerDisabledCmdType(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      cmdType: data.cmdType.present ? data.cmdType.value : this.cmdType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerDisabledCmdType(')
          ..write('serverId: $serverId, ')
          ..write('cmdType: $cmdType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, cmdType);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerDisabledCmdType &&
          other.serverId == this.serverId &&
          other.cmdType == this.cmdType);
}

class ServerDisabledCmdTypesCompanion
    extends UpdateCompanion<ServerDisabledCmdType> {
  final Value<String> serverId;
  final Value<String> cmdType;
  final Value<int> rowid;
  const ServerDisabledCmdTypesCompanion({
    this.serverId = const Value.absent(),
    this.cmdType = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServerDisabledCmdTypesCompanion.insert({
    required String serverId,
    required String cmdType,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       cmdType = Value(cmdType);
  static Insertable<ServerDisabledCmdType> custom({
    Expression<String>? serverId,
    Expression<String>? cmdType,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (cmdType != null) 'cmd_type': cmdType,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServerDisabledCmdTypesCompanion copyWith({
    Value<String>? serverId,
    Value<String>? cmdType,
    Value<int>? rowid,
  }) {
    return ServerDisabledCmdTypesCompanion(
      serverId: serverId ?? this.serverId,
      cmdType: cmdType ?? this.cmdType,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (cmdType.present) {
      map['cmd_type'] = Variable<String>(cmdType.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerDisabledCmdTypesCompanion(')
          ..write('serverId: $serverId, ')
          ..write('cmdType: $cmdType, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SnippetsTable extends Snippets with TableInfo<$SnippetsTable, Snippet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnippetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scriptMeta = const VerificationMeta('script');
  @override
  late final GeneratedColumn<String> script = GeneratedColumn<String>(
    'script',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [name, script, note, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snippets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Snippet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('script')) {
      context.handle(
        _scriptMeta,
        script.isAcceptableOrUnknown(data['script']!, _scriptMeta),
      );
    } else if (isInserting) {
      context.missing(_scriptMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  Snippet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Snippet(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      script: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}script'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SnippetsTable createAlias(String alias) {
    return $SnippetsTable(attachedDatabase, alias);
  }
}

class Snippet extends DataClass implements Insertable<Snippet> {
  final String name;
  final String script;
  final String? note;
  final int updatedAt;
  const Snippet({
    required this.name,
    required this.script,
    this.note,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['script'] = Variable<String>(script);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SnippetsCompanion toCompanion(bool nullToAbsent) {
    return SnippetsCompanion(
      name: Value(name),
      script: Value(script),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      updatedAt: Value(updatedAt),
    );
  }

  factory Snippet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Snippet(
      name: serializer.fromJson<String>(json['name']),
      script: serializer.fromJson<String>(json['script']),
      note: serializer.fromJson<String?>(json['note']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'script': serializer.toJson<String>(script),
      'note': serializer.toJson<String?>(note),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Snippet copyWith({
    String? name,
    String? script,
    Value<String?> note = const Value.absent(),
    int? updatedAt,
  }) => Snippet(
    name: name ?? this.name,
    script: script ?? this.script,
    note: note.present ? note.value : this.note,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Snippet copyWithCompanion(SnippetsCompanion data) {
    return Snippet(
      name: data.name.present ? data.name.value : this.name,
      script: data.script.present ? data.script.value : this.script,
      note: data.note.present ? data.note.value : this.note,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Snippet(')
          ..write('name: $name, ')
          ..write('script: $script, ')
          ..write('note: $note, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, script, note, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Snippet &&
          other.name == this.name &&
          other.script == this.script &&
          other.note == this.note &&
          other.updatedAt == this.updatedAt);
}

class SnippetsCompanion extends UpdateCompanion<Snippet> {
  final Value<String> name;
  final Value<String> script;
  final Value<String?> note;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SnippetsCompanion({
    this.name = const Value.absent(),
    this.script = const Value.absent(),
    this.note = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SnippetsCompanion.insert({
    required String name,
    required String script,
    this.note = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       script = Value(script),
       updatedAt = Value(updatedAt);
  static Insertable<Snippet> custom({
    Expression<String>? name,
    Expression<String>? script,
    Expression<String>? note,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (script != null) 'script': script,
      if (note != null) 'note': note,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SnippetsCompanion copyWith({
    Value<String>? name,
    Value<String>? script,
    Value<String?>? note,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SnippetsCompanion(
      name: name ?? this.name,
      script: script ?? this.script,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (script.present) {
      map['script'] = Variable<String>(script.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnippetsCompanion(')
          ..write('name: $name, ')
          ..write('script: $script, ')
          ..write('note: $note, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SnippetTagsTable extends SnippetTags
    with TableInfo<$SnippetTagsTable, SnippetTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnippetTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _snippetNameMeta = const VerificationMeta(
    'snippetName',
  );
  @override
  late final GeneratedColumn<String> snippetName = GeneratedColumn<String>(
    'snippet_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES snippets(name) ON DELETE CASCADE',
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [snippetName, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snippet_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnippetTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('snippet_name')) {
      context.handle(
        _snippetNameMeta,
        snippetName.isAcceptableOrUnknown(
          data['snippet_name']!,
          _snippetNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snippetNameMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {snippetName, tag};
  @override
  SnippetTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnippetTag(
      snippetName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snippet_name'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
    );
  }

  @override
  $SnippetTagsTable createAlias(String alias) {
    return $SnippetTagsTable(attachedDatabase, alias);
  }
}

class SnippetTag extends DataClass implements Insertable<SnippetTag> {
  final String snippetName;
  final String tag;
  const SnippetTag({required this.snippetName, required this.tag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['snippet_name'] = Variable<String>(snippetName);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  SnippetTagsCompanion toCompanion(bool nullToAbsent) {
    return SnippetTagsCompanion(
      snippetName: Value(snippetName),
      tag: Value(tag),
    );
  }

  factory SnippetTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnippetTag(
      snippetName: serializer.fromJson<String>(json['snippetName']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'snippetName': serializer.toJson<String>(snippetName),
      'tag': serializer.toJson<String>(tag),
    };
  }

  SnippetTag copyWith({String? snippetName, String? tag}) => SnippetTag(
    snippetName: snippetName ?? this.snippetName,
    tag: tag ?? this.tag,
  );
  SnippetTag copyWithCompanion(SnippetTagsCompanion data) {
    return SnippetTag(
      snippetName: data.snippetName.present
          ? data.snippetName.value
          : this.snippetName,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnippetTag(')
          ..write('snippetName: $snippetName, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(snippetName, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnippetTag &&
          other.snippetName == this.snippetName &&
          other.tag == this.tag);
}

class SnippetTagsCompanion extends UpdateCompanion<SnippetTag> {
  final Value<String> snippetName;
  final Value<String> tag;
  final Value<int> rowid;
  const SnippetTagsCompanion({
    this.snippetName = const Value.absent(),
    this.tag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SnippetTagsCompanion.insert({
    required String snippetName,
    required String tag,
    this.rowid = const Value.absent(),
  }) : snippetName = Value(snippetName),
       tag = Value(tag);
  static Insertable<SnippetTag> custom({
    Expression<String>? snippetName,
    Expression<String>? tag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (snippetName != null) 'snippet_name': snippetName,
      if (tag != null) 'tag': tag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SnippetTagsCompanion copyWith({
    Value<String>? snippetName,
    Value<String>? tag,
    Value<int>? rowid,
  }) {
    return SnippetTagsCompanion(
      snippetName: snippetName ?? this.snippetName,
      tag: tag ?? this.tag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (snippetName.present) {
      map['snippet_name'] = Variable<String>(snippetName.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnippetTagsCompanion(')
          ..write('snippetName: $snippetName, ')
          ..write('tag: $tag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SnippetAutoRunsTable extends SnippetAutoRuns
    with TableInfo<$SnippetAutoRunsTable, SnippetAutoRun> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnippetAutoRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _snippetNameMeta = const VerificationMeta(
    'snippetName',
  );
  @override
  late final GeneratedColumn<String> snippetName = GeneratedColumn<String>(
    'snippet_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES snippets(name) ON DELETE CASCADE',
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [snippetName, serverId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snippet_auto_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnippetAutoRun> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('snippet_name')) {
      context.handle(
        _snippetNameMeta,
        snippetName.isAcceptableOrUnknown(
          data['snippet_name']!,
          _snippetNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snippetNameMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {snippetName, serverId};
  @override
  SnippetAutoRun map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnippetAutoRun(
      snippetName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snippet_name'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
    );
  }

  @override
  $SnippetAutoRunsTable createAlias(String alias) {
    return $SnippetAutoRunsTable(attachedDatabase, alias);
  }
}

class SnippetAutoRun extends DataClass implements Insertable<SnippetAutoRun> {
  final String snippetName;
  final String serverId;
  const SnippetAutoRun({required this.snippetName, required this.serverId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['snippet_name'] = Variable<String>(snippetName);
    map['server_id'] = Variable<String>(serverId);
    return map;
  }

  SnippetAutoRunsCompanion toCompanion(bool nullToAbsent) {
    return SnippetAutoRunsCompanion(
      snippetName: Value(snippetName),
      serverId: Value(serverId),
    );
  }

  factory SnippetAutoRun.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnippetAutoRun(
      snippetName: serializer.fromJson<String>(json['snippetName']),
      serverId: serializer.fromJson<String>(json['serverId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'snippetName': serializer.toJson<String>(snippetName),
      'serverId': serializer.toJson<String>(serverId),
    };
  }

  SnippetAutoRun copyWith({String? snippetName, String? serverId}) =>
      SnippetAutoRun(
        snippetName: snippetName ?? this.snippetName,
        serverId: serverId ?? this.serverId,
      );
  SnippetAutoRun copyWithCompanion(SnippetAutoRunsCompanion data) {
    return SnippetAutoRun(
      snippetName: data.snippetName.present
          ? data.snippetName.value
          : this.snippetName,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnippetAutoRun(')
          ..write('snippetName: $snippetName, ')
          ..write('serverId: $serverId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(snippetName, serverId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnippetAutoRun &&
          other.snippetName == this.snippetName &&
          other.serverId == this.serverId);
}

class SnippetAutoRunsCompanion extends UpdateCompanion<SnippetAutoRun> {
  final Value<String> snippetName;
  final Value<String> serverId;
  final Value<int> rowid;
  const SnippetAutoRunsCompanion({
    this.snippetName = const Value.absent(),
    this.serverId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SnippetAutoRunsCompanion.insert({
    required String snippetName,
    required String serverId,
    this.rowid = const Value.absent(),
  }) : snippetName = Value(snippetName),
       serverId = Value(serverId);
  static Insertable<SnippetAutoRun> custom({
    Expression<String>? snippetName,
    Expression<String>? serverId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (snippetName != null) 'snippet_name': snippetName,
      if (serverId != null) 'server_id': serverId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SnippetAutoRunsCompanion copyWith({
    Value<String>? snippetName,
    Value<String>? serverId,
    Value<int>? rowid,
  }) {
    return SnippetAutoRunsCompanion(
      snippetName: snippetName ?? this.snippetName,
      serverId: serverId ?? this.serverId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (snippetName.present) {
      map['snippet_name'] = Variable<String>(snippetName.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnippetAutoRunsCompanion(')
          ..write('snippetName: $snippetName, ')
          ..write('serverId: $serverId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PrivateKeysTable extends PrivateKeys
    with TableInfo<$PrivateKeysTable, PrivateKey> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrivateKeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _privateKeyMeta = const VerificationMeta(
    'privateKey',
  );
  @override
  late final GeneratedColumn<String> privateKey = GeneratedColumn<String>(
    'private_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, privateKey, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'private_keys';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrivateKey> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('private_key')) {
      context.handle(
        _privateKeyMeta,
        privateKey.isAcceptableOrUnknown(data['private_key']!, _privateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_privateKeyMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrivateKey map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrivateKey(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      privateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}private_key'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PrivateKeysTable createAlias(String alias) {
    return $PrivateKeysTable(attachedDatabase, alias);
  }
}

class PrivateKey extends DataClass implements Insertable<PrivateKey> {
  final String id;
  final String privateKey;
  final int updatedAt;
  const PrivateKey({
    required this.id,
    required this.privateKey,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['private_key'] = Variable<String>(privateKey);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PrivateKeysCompanion toCompanion(bool nullToAbsent) {
    return PrivateKeysCompanion(
      id: Value(id),
      privateKey: Value(privateKey),
      updatedAt: Value(updatedAt),
    );
  }

  factory PrivateKey.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrivateKey(
      id: serializer.fromJson<String>(json['id']),
      privateKey: serializer.fromJson<String>(json['privateKey']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'privateKey': serializer.toJson<String>(privateKey),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  PrivateKey copyWith({String? id, String? privateKey, int? updatedAt}) =>
      PrivateKey(
        id: id ?? this.id,
        privateKey: privateKey ?? this.privateKey,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PrivateKey copyWithCompanion(PrivateKeysCompanion data) {
    return PrivateKey(
      id: data.id.present ? data.id.value : this.id,
      privateKey: data.privateKey.present
          ? data.privateKey.value
          : this.privateKey,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrivateKey(')
          ..write('id: $id, ')
          ..write('privateKey: $privateKey, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, privateKey, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrivateKey &&
          other.id == this.id &&
          other.privateKey == this.privateKey &&
          other.updatedAt == this.updatedAt);
}

class PrivateKeysCompanion extends UpdateCompanion<PrivateKey> {
  final Value<String> id;
  final Value<String> privateKey;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const PrivateKeysCompanion({
    this.id = const Value.absent(),
    this.privateKey = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrivateKeysCompanion.insert({
    required String id,
    required String privateKey,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       privateKey = Value(privateKey),
       updatedAt = Value(updatedAt);
  static Insertable<PrivateKey> custom({
    Expression<String>? id,
    Expression<String>? privateKey,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (privateKey != null) 'private_key': privateKey,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrivateKeysCompanion copyWith({
    Value<String>? id,
    Value<String>? privateKey,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return PrivateKeysCompanion(
      id: id ?? this.id,
      privateKey: privateKey ?? this.privateKey,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (privateKey.present) {
      map['private_key'] = Variable<String>(privateKey.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrivateKeysCompanion(')
          ..write('id: $id, ')
          ..write('privateKey: $privateKey, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContainerHostsTable extends ContainerHosts
    with TableInfo<$ContainerHostsTable, ContainerHost> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContainerHostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [serverId, host, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'container_hosts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContainerHost> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId};
  @override
  ContainerHost map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContainerHost(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ContainerHostsTable createAlias(String alias) {
    return $ContainerHostsTable(attachedDatabase, alias);
  }
}

class ContainerHost extends DataClass implements Insertable<ContainerHost> {
  final String serverId;
  final String host;
  final int updatedAt;
  const ContainerHost({
    required this.serverId,
    required this.host,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['host'] = Variable<String>(host);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ContainerHostsCompanion toCompanion(bool nullToAbsent) {
    return ContainerHostsCompanion(
      serverId: Value(serverId),
      host: Value(host),
      updatedAt: Value(updatedAt),
    );
  }

  factory ContainerHost.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContainerHost(
      serverId: serializer.fromJson<String>(json['serverId']),
      host: serializer.fromJson<String>(json['host']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'host': serializer.toJson<String>(host),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ContainerHost copyWith({String? serverId, String? host, int? updatedAt}) =>
      ContainerHost(
        serverId: serverId ?? this.serverId,
        host: host ?? this.host,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ContainerHost copyWithCompanion(ContainerHostsCompanion data) {
    return ContainerHost(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      host: data.host.present ? data.host.value : this.host,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContainerHost(')
          ..write('serverId: $serverId, ')
          ..write('host: $host, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, host, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContainerHost &&
          other.serverId == this.serverId &&
          other.host == this.host &&
          other.updatedAt == this.updatedAt);
}

class ContainerHostsCompanion extends UpdateCompanion<ContainerHost> {
  final Value<String> serverId;
  final Value<String> host;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ContainerHostsCompanion({
    this.serverId = const Value.absent(),
    this.host = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContainerHostsCompanion.insert({
    required String serverId,
    required String host,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       host = Value(host),
       updatedAt = Value(updatedAt);
  static Insertable<ContainerHost> custom({
    Expression<String>? serverId,
    Expression<String>? host,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (host != null) 'host': host,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContainerHostsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? host,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ContainerHostsCompanion(
      serverId: serverId ?? this.serverId,
      host: host ?? this.host,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContainerHostsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('host: $host, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConnectionStatsRecordsTable extends ConnectionStatsRecords
    with TableInfo<$ConnectionStatsRecordsTable, ConnectionStatsRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConnectionStatsRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverNameMeta = const VerificationMeta(
    'serverName',
  );
  @override
  late final GeneratedColumn<String> serverName = GeneratedColumn<String>(
    'server_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMsMeta = const VerificationMeta(
    'timestampMs',
  );
  @override
  late final GeneratedColumn<int> timestampMs = GeneratedColumn<int>(
    'timestamp_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    serverName,
    timestampMs,
    result,
    errorMessage,
    durationMs,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'connection_stats_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConnectionStatsRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('server_name')) {
      context.handle(
        _serverNameMeta,
        serverName.isAcceptableOrUnknown(data['server_name']!, _serverNameMeta),
      );
    } else if (isInserting) {
      context.missing(_serverNameMeta);
    }
    if (data.containsKey('timestamp_ms')) {
      context.handle(
        _timestampMsMeta,
        timestampMs.isAcceptableOrUnknown(
          data['timestamp_ms']!,
          _timestampMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timestampMsMeta);
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    } else if (isInserting) {
      context.missing(_resultMeta);
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_errorMessageMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConnectionStatsRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConnectionStatsRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      serverName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_name'],
      )!,
      timestampMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp_ms'],
      )!,
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ConnectionStatsRecordsTable createAlias(String alias) {
    return $ConnectionStatsRecordsTable(attachedDatabase, alias);
  }
}

class ConnectionStatsRecord extends DataClass
    implements Insertable<ConnectionStatsRecord> {
  final int id;
  final String serverId;
  final String serverName;
  final int timestampMs;
  final String result;
  final String errorMessage;
  final int durationMs;
  final int updatedAt;
  const ConnectionStatsRecord({
    required this.id,
    required this.serverId,
    required this.serverName,
    required this.timestampMs,
    required this.result,
    required this.errorMessage,
    required this.durationMs,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['server_id'] = Variable<String>(serverId);
    map['server_name'] = Variable<String>(serverName);
    map['timestamp_ms'] = Variable<int>(timestampMs);
    map['result'] = Variable<String>(result);
    map['error_message'] = Variable<String>(errorMessage);
    map['duration_ms'] = Variable<int>(durationMs);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ConnectionStatsRecordsCompanion toCompanion(bool nullToAbsent) {
    return ConnectionStatsRecordsCompanion(
      id: Value(id),
      serverId: Value(serverId),
      serverName: Value(serverName),
      timestampMs: Value(timestampMs),
      result: Value(result),
      errorMessage: Value(errorMessage),
      durationMs: Value(durationMs),
      updatedAt: Value(updatedAt),
    );
  }

  factory ConnectionStatsRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConnectionStatsRecord(
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<String>(json['serverId']),
      serverName: serializer.fromJson<String>(json['serverName']),
      timestampMs: serializer.fromJson<int>(json['timestampMs']),
      result: serializer.fromJson<String>(json['result']),
      errorMessage: serializer.fromJson<String>(json['errorMessage']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<String>(serverId),
      'serverName': serializer.toJson<String>(serverName),
      'timestampMs': serializer.toJson<int>(timestampMs),
      'result': serializer.toJson<String>(result),
      'errorMessage': serializer.toJson<String>(errorMessage),
      'durationMs': serializer.toJson<int>(durationMs),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ConnectionStatsRecord copyWith({
    int? id,
    String? serverId,
    String? serverName,
    int? timestampMs,
    String? result,
    String? errorMessage,
    int? durationMs,
    int? updatedAt,
  }) => ConnectionStatsRecord(
    id: id ?? this.id,
    serverId: serverId ?? this.serverId,
    serverName: serverName ?? this.serverName,
    timestampMs: timestampMs ?? this.timestampMs,
    result: result ?? this.result,
    errorMessage: errorMessage ?? this.errorMessage,
    durationMs: durationMs ?? this.durationMs,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ConnectionStatsRecord copyWithCompanion(
    ConnectionStatsRecordsCompanion data,
  ) {
    return ConnectionStatsRecord(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      serverName: data.serverName.present
          ? data.serverName.value
          : this.serverName,
      timestampMs: data.timestampMs.present
          ? data.timestampMs.value
          : this.timestampMs,
      result: data.result.present ? data.result.value : this.result,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConnectionStatsRecord(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('serverName: $serverName, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('result: $result, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    serverName,
    timestampMs,
    result,
    errorMessage,
    durationMs,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConnectionStatsRecord &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.serverName == this.serverName &&
          other.timestampMs == this.timestampMs &&
          other.result == this.result &&
          other.errorMessage == this.errorMessage &&
          other.durationMs == this.durationMs &&
          other.updatedAt == this.updatedAt);
}

class ConnectionStatsRecordsCompanion
    extends UpdateCompanion<ConnectionStatsRecord> {
  final Value<int> id;
  final Value<String> serverId;
  final Value<String> serverName;
  final Value<int> timestampMs;
  final Value<String> result;
  final Value<String> errorMessage;
  final Value<int> durationMs;
  final Value<int> updatedAt;
  const ConnectionStatsRecordsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.serverName = const Value.absent(),
    this.timestampMs = const Value.absent(),
    this.result = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ConnectionStatsRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String serverId,
    required String serverName,
    required int timestampMs,
    required String result,
    required String errorMessage,
    required int durationMs,
    required int updatedAt,
  }) : serverId = Value(serverId),
       serverName = Value(serverName),
       timestampMs = Value(timestampMs),
       result = Value(result),
       errorMessage = Value(errorMessage),
       durationMs = Value(durationMs),
       updatedAt = Value(updatedAt);
  static Insertable<ConnectionStatsRecord> custom({
    Expression<int>? id,
    Expression<String>? serverId,
    Expression<String>? serverName,
    Expression<int>? timestampMs,
    Expression<String>? result,
    Expression<String>? errorMessage,
    Expression<int>? durationMs,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (serverName != null) 'server_name': serverName,
      if (timestampMs != null) 'timestamp_ms': timestampMs,
      if (result != null) 'result': result,
      if (errorMessage != null) 'error_message': errorMessage,
      if (durationMs != null) 'duration_ms': durationMs,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ConnectionStatsRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? serverId,
    Value<String>? serverName,
    Value<int>? timestampMs,
    Value<String>? result,
    Value<String>? errorMessage,
    Value<int>? durationMs,
    Value<int>? updatedAt,
  }) {
    return ConnectionStatsRecordsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      serverName: serverName ?? this.serverName,
      timestampMs: timestampMs ?? this.timestampMs,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      durationMs: durationMs ?? this.durationMs,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (serverName.present) {
      map['server_name'] = Variable<String>(serverName.value);
    }
    if (timestampMs.present) {
      map['timestamp_ms'] = Variable<int>(timestampMs.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConnectionStatsRecordsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('serverName: $serverName, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('result: $result, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $ServersTable servers = $ServersTable(this);
  late final $ServerCustomsTable serverCustoms = $ServerCustomsTable(this);
  late final $ServerWolCfgsTable serverWolCfgs = $ServerWolCfgsTable(this);
  late final $ServerTagsTable serverTags = $ServerTagsTable(this);
  late final $ServerEnvsTable serverEnvs = $ServerEnvsTable(this);
  late final $ServerDisabledCmdTypesTable serverDisabledCmdTypes =
      $ServerDisabledCmdTypesTable(this);
  late final $SnippetsTable snippets = $SnippetsTable(this);
  late final $SnippetTagsTable snippetTags = $SnippetTagsTable(this);
  late final $SnippetAutoRunsTable snippetAutoRuns = $SnippetAutoRunsTable(
    this,
  );
  late final $PrivateKeysTable privateKeys = $PrivateKeysTable(this);
  late final $ContainerHostsTable containerHosts = $ContainerHostsTable(this);
  late final $ConnectionStatsRecordsTable connectionStatsRecords =
      $ConnectionStatsRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    servers,
    serverCustoms,
    serverWolCfgs,
    serverTags,
    serverEnvs,
    serverDisabledCmdTypes,
    snippets,
    snippetTags,
    snippetAutoRuns,
    privateKeys,
    containerHosts,
    connectionStatsRecords,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'servers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('server_customs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'servers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('server_wol_cfgs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'servers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('server_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'servers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('server_envs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'servers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('server_disabled_cmd_types', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'snippets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('snippet_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'snippets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('snippet_auto_runs', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ServersTableCreateCompanionBuilder =
    ServersCompanion Function({
      required String id,
      required String name,
      required String ip,
      required int port,
      required String user,
      Value<String?> pwd,
      Value<String?> keyId,
      Value<String?> alterUrl,
      Value<bool> autoConnect,
      Value<String?> jumpId,
      Value<String?> customSystemType,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ServersTableUpdateCompanionBuilder =
    ServersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> ip,
      Value<int> port,
      Value<String> user,
      Value<String?> pwd,
      Value<String?> keyId,
      Value<String?> alterUrl,
      Value<bool> autoConnect,
      Value<String?> jumpId,
      Value<String?> customSystemType,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$ServersTableReferences
    extends BaseReferences<_$AppDb, $ServersTable, Server> {
  $$ServersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ServerCustomsTable, List<ServerCustom>>
  _serverCustomsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.serverCustoms,
    aliasName: $_aliasNameGenerator(db.servers.id, db.serverCustoms.serverId),
  );

  $$ServerCustomsTableProcessedTableManager get serverCustomsRefs {
    final manager = $$ServerCustomsTableTableManager(
      $_db,
      $_db.serverCustoms,
    ).filter((f) => f.serverId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_serverCustomsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ServerWolCfgsTable, List<ServerWolCfg>>
  _serverWolCfgsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.serverWolCfgs,
    aliasName: $_aliasNameGenerator(db.servers.id, db.serverWolCfgs.serverId),
  );

  $$ServerWolCfgsTableProcessedTableManager get serverWolCfgsRefs {
    final manager = $$ServerWolCfgsTableTableManager(
      $_db,
      $_db.serverWolCfgs,
    ).filter((f) => f.serverId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_serverWolCfgsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ServerTagsTable, List<ServerTag>>
  _serverTagsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.serverTags,
    aliasName: $_aliasNameGenerator(db.servers.id, db.serverTags.serverId),
  );

  $$ServerTagsTableProcessedTableManager get serverTagsRefs {
    final manager = $$ServerTagsTableTableManager(
      $_db,
      $_db.serverTags,
    ).filter((f) => f.serverId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_serverTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ServerEnvsTable, List<ServerEnv>>
  _serverEnvsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.serverEnvs,
    aliasName: $_aliasNameGenerator(db.servers.id, db.serverEnvs.serverId),
  );

  $$ServerEnvsTableProcessedTableManager get serverEnvsRefs {
    final manager = $$ServerEnvsTableTableManager(
      $_db,
      $_db.serverEnvs,
    ).filter((f) => f.serverId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_serverEnvsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ServerDisabledCmdTypesTable,
    List<ServerDisabledCmdType>
  >
  _serverDisabledCmdTypesRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.serverDisabledCmdTypes,
    aliasName: $_aliasNameGenerator(
      db.servers.id,
      db.serverDisabledCmdTypes.serverId,
    ),
  );

  $$ServerDisabledCmdTypesTableProcessedTableManager
  get serverDisabledCmdTypesRefs {
    final manager = $$ServerDisabledCmdTypesTableTableManager(
      $_db,
      $_db.serverDisabledCmdTypes,
    ).filter((f) => f.serverId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _serverDisabledCmdTypesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ServersTableFilterComposer extends Composer<_$AppDb, $ServersTable> {
  $$ServersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ip => $composableBuilder(
    column: $table.ip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get user => $composableBuilder(
    column: $table.user,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pwd => $composableBuilder(
    column: $table.pwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyId => $composableBuilder(
    column: $table.keyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alterUrl => $composableBuilder(
    column: $table.alterUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoConnect => $composableBuilder(
    column: $table.autoConnect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jumpId => $composableBuilder(
    column: $table.jumpId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customSystemType => $composableBuilder(
    column: $table.customSystemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> serverCustomsRefs(
    Expression<bool> Function($$ServerCustomsTableFilterComposer f) f,
  ) {
    final $$ServerCustomsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serverCustoms,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServerCustomsTableFilterComposer(
            $db: $db,
            $table: $db.serverCustoms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> serverWolCfgsRefs(
    Expression<bool> Function($$ServerWolCfgsTableFilterComposer f) f,
  ) {
    final $$ServerWolCfgsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serverWolCfgs,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServerWolCfgsTableFilterComposer(
            $db: $db,
            $table: $db.serverWolCfgs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> serverTagsRefs(
    Expression<bool> Function($$ServerTagsTableFilterComposer f) f,
  ) {
    final $$ServerTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serverTags,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServerTagsTableFilterComposer(
            $db: $db,
            $table: $db.serverTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> serverEnvsRefs(
    Expression<bool> Function($$ServerEnvsTableFilterComposer f) f,
  ) {
    final $$ServerEnvsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serverEnvs,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServerEnvsTableFilterComposer(
            $db: $db,
            $table: $db.serverEnvs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> serverDisabledCmdTypesRefs(
    Expression<bool> Function($$ServerDisabledCmdTypesTableFilterComposer f) f,
  ) {
    final $$ServerDisabledCmdTypesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.serverDisabledCmdTypes,
          getReferencedColumn: (t) => t.serverId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ServerDisabledCmdTypesTableFilterComposer(
                $db: $db,
                $table: $db.serverDisabledCmdTypes,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ServersTableOrderingComposer extends Composer<_$AppDb, $ServersTable> {
  $$ServersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ip => $composableBuilder(
    column: $table.ip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get user => $composableBuilder(
    column: $table.user,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pwd => $composableBuilder(
    column: $table.pwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyId => $composableBuilder(
    column: $table.keyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alterUrl => $composableBuilder(
    column: $table.alterUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoConnect => $composableBuilder(
    column: $table.autoConnect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jumpId => $composableBuilder(
    column: $table.jumpId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customSystemType => $composableBuilder(
    column: $table.customSystemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServersTableAnnotationComposer
    extends Composer<_$AppDb, $ServersTable> {
  $$ServersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get ip =>
      $composableBuilder(column: $table.ip, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<String> get user =>
      $composableBuilder(column: $table.user, builder: (column) => column);

  GeneratedColumn<String> get pwd =>
      $composableBuilder(column: $table.pwd, builder: (column) => column);

  GeneratedColumn<String> get keyId =>
      $composableBuilder(column: $table.keyId, builder: (column) => column);

  GeneratedColumn<String> get alterUrl =>
      $composableBuilder(column: $table.alterUrl, builder: (column) => column);

  GeneratedColumn<bool> get autoConnect => $composableBuilder(
    column: $table.autoConnect,
    builder: (column) => column,
  );

  GeneratedColumn<String> get jumpId =>
      $composableBuilder(column: $table.jumpId, builder: (column) => column);

  GeneratedColumn<String> get customSystemType => $composableBuilder(
    column: $table.customSystemType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> serverCustomsRefs<T extends Object>(
    Expression<T> Function($$ServerCustomsTableAnnotationComposer a) f,
  ) {
    final $$ServerCustomsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serverCustoms,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServerCustomsTableAnnotationComposer(
            $db: $db,
            $table: $db.serverCustoms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> serverWolCfgsRefs<T extends Object>(
    Expression<T> Function($$ServerWolCfgsTableAnnotationComposer a) f,
  ) {
    final $$ServerWolCfgsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serverWolCfgs,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServerWolCfgsTableAnnotationComposer(
            $db: $db,
            $table: $db.serverWolCfgs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> serverTagsRefs<T extends Object>(
    Expression<T> Function($$ServerTagsTableAnnotationComposer a) f,
  ) {
    final $$ServerTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serverTags,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServerTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.serverTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> serverEnvsRefs<T extends Object>(
    Expression<T> Function($$ServerEnvsTableAnnotationComposer a) f,
  ) {
    final $$ServerEnvsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serverEnvs,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServerEnvsTableAnnotationComposer(
            $db: $db,
            $table: $db.serverEnvs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> serverDisabledCmdTypesRefs<T extends Object>(
    Expression<T> Function($$ServerDisabledCmdTypesTableAnnotationComposer a) f,
  ) {
    final $$ServerDisabledCmdTypesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.serverDisabledCmdTypes,
          getReferencedColumn: (t) => t.serverId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ServerDisabledCmdTypesTableAnnotationComposer(
                $db: $db,
                $table: $db.serverDisabledCmdTypes,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ServersTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ServersTable,
          Server,
          $$ServersTableFilterComposer,
          $$ServersTableOrderingComposer,
          $$ServersTableAnnotationComposer,
          $$ServersTableCreateCompanionBuilder,
          $$ServersTableUpdateCompanionBuilder,
          (Server, $$ServersTableReferences),
          Server,
          PrefetchHooks Function({
            bool serverCustomsRefs,
            bool serverWolCfgsRefs,
            bool serverTagsRefs,
            bool serverEnvsRefs,
            bool serverDisabledCmdTypesRefs,
          })
        > {
  $$ServersTableTableManager(_$AppDb db, $ServersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> ip = const Value.absent(),
                Value<int> port = const Value.absent(),
                Value<String> user = const Value.absent(),
                Value<String?> pwd = const Value.absent(),
                Value<String?> keyId = const Value.absent(),
                Value<String?> alterUrl = const Value.absent(),
                Value<bool> autoConnect = const Value.absent(),
                Value<String?> jumpId = const Value.absent(),
                Value<String?> customSystemType = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServersCompanion(
                id: id,
                name: name,
                ip: ip,
                port: port,
                user: user,
                pwd: pwd,
                keyId: keyId,
                alterUrl: alterUrl,
                autoConnect: autoConnect,
                jumpId: jumpId,
                customSystemType: customSystemType,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String ip,
                required int port,
                required String user,
                Value<String?> pwd = const Value.absent(),
                Value<String?> keyId = const Value.absent(),
                Value<String?> alterUrl = const Value.absent(),
                Value<bool> autoConnect = const Value.absent(),
                Value<String?> jumpId = const Value.absent(),
                Value<String?> customSystemType = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ServersCompanion.insert(
                id: id,
                name: name,
                ip: ip,
                port: port,
                user: user,
                pwd: pwd,
                keyId: keyId,
                alterUrl: alterUrl,
                autoConnect: autoConnect,
                jumpId: jumpId,
                customSystemType: customSystemType,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ServersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                serverCustomsRefs = false,
                serverWolCfgsRefs = false,
                serverTagsRefs = false,
                serverEnvsRefs = false,
                serverDisabledCmdTypesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (serverCustomsRefs) db.serverCustoms,
                    if (serverWolCfgsRefs) db.serverWolCfgs,
                    if (serverTagsRefs) db.serverTags,
                    if (serverEnvsRefs) db.serverEnvs,
                    if (serverDisabledCmdTypesRefs) db.serverDisabledCmdTypes,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (serverCustomsRefs)
                        await $_getPrefetchedData<
                          Server,
                          $ServersTable,
                          ServerCustom
                        >(
                          currentTable: table,
                          referencedTable: $$ServersTableReferences
                              ._serverCustomsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ServersTableReferences(
                                db,
                                table,
                                p0,
                              ).serverCustomsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.serverId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (serverWolCfgsRefs)
                        await $_getPrefetchedData<
                          Server,
                          $ServersTable,
                          ServerWolCfg
                        >(
                          currentTable: table,
                          referencedTable: $$ServersTableReferences
                              ._serverWolCfgsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ServersTableReferences(
                                db,
                                table,
                                p0,
                              ).serverWolCfgsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.serverId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (serverTagsRefs)
                        await $_getPrefetchedData<
                          Server,
                          $ServersTable,
                          ServerTag
                        >(
                          currentTable: table,
                          referencedTable: $$ServersTableReferences
                              ._serverTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ServersTableReferences(
                                db,
                                table,
                                p0,
                              ).serverTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.serverId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (serverEnvsRefs)
                        await $_getPrefetchedData<
                          Server,
                          $ServersTable,
                          ServerEnv
                        >(
                          currentTable: table,
                          referencedTable: $$ServersTableReferences
                              ._serverEnvsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ServersTableReferences(
                                db,
                                table,
                                p0,
                              ).serverEnvsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.serverId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (serverDisabledCmdTypesRefs)
                        await $_getPrefetchedData<
                          Server,
                          $ServersTable,
                          ServerDisabledCmdType
                        >(
                          currentTable: table,
                          referencedTable: $$ServersTableReferences
                              ._serverDisabledCmdTypesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ServersTableReferences(
                                db,
                                table,
                                p0,
                              ).serverDisabledCmdTypesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.serverId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ServersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ServersTable,
      Server,
      $$ServersTableFilterComposer,
      $$ServersTableOrderingComposer,
      $$ServersTableAnnotationComposer,
      $$ServersTableCreateCompanionBuilder,
      $$ServersTableUpdateCompanionBuilder,
      (Server, $$ServersTableReferences),
      Server,
      PrefetchHooks Function({
        bool serverCustomsRefs,
        bool serverWolCfgsRefs,
        bool serverTagsRefs,
        bool serverEnvsRefs,
        bool serverDisabledCmdTypesRefs,
      })
    >;
typedef $$ServerCustomsTableCreateCompanionBuilder =
    ServerCustomsCompanion Function({
      required String serverId,
      Value<String?> pveAddr,
      Value<bool> pveIgnoreCert,
      Value<String?> cmdsJson,
      Value<String?> preferTempDev,
      Value<String?> logoUrl,
      Value<String?> netDev,
      Value<String?> scriptDir,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ServerCustomsTableUpdateCompanionBuilder =
    ServerCustomsCompanion Function({
      Value<String> serverId,
      Value<String?> pveAddr,
      Value<bool> pveIgnoreCert,
      Value<String?> cmdsJson,
      Value<String?> preferTempDev,
      Value<String?> logoUrl,
      Value<String?> netDev,
      Value<String?> scriptDir,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$ServerCustomsTableReferences
    extends BaseReferences<_$AppDb, $ServerCustomsTable, ServerCustom> {
  $$ServerCustomsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ServersTable _serverIdTable(_$AppDb db) => db.servers.createAlias(
    $_aliasNameGenerator(db.serverCustoms.serverId, db.servers.id),
  );

  $$ServersTableProcessedTableManager get serverId {
    final $_column = $_itemColumn<String>('server_id')!;

    final manager = $$ServersTableTableManager(
      $_db,
      $_db.servers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_serverIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ServerCustomsTableFilterComposer
    extends Composer<_$AppDb, $ServerCustomsTable> {
  $$ServerCustomsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pveAddr => $composableBuilder(
    column: $table.pveAddr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pveIgnoreCert => $composableBuilder(
    column: $table.pveIgnoreCert,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cmdsJson => $composableBuilder(
    column: $table.cmdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferTempDev => $composableBuilder(
    column: $table.preferTempDev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoUrl => $composableBuilder(
    column: $table.logoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get netDev => $composableBuilder(
    column: $table.netDev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scriptDir => $composableBuilder(
    column: $table.scriptDir,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ServersTableFilterComposer get serverId {
    final $$ServersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableFilterComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServerCustomsTableOrderingComposer
    extends Composer<_$AppDb, $ServerCustomsTable> {
  $$ServerCustomsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pveAddr => $composableBuilder(
    column: $table.pveAddr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pveIgnoreCert => $composableBuilder(
    column: $table.pveIgnoreCert,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cmdsJson => $composableBuilder(
    column: $table.cmdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferTempDev => $composableBuilder(
    column: $table.preferTempDev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoUrl => $composableBuilder(
    column: $table.logoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get netDev => $composableBuilder(
    column: $table.netDev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scriptDir => $composableBuilder(
    column: $table.scriptDir,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ServersTableOrderingComposer get serverId {
    final $$ServersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableOrderingComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServerCustomsTableAnnotationComposer
    extends Composer<_$AppDb, $ServerCustomsTable> {
  $$ServerCustomsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pveAddr =>
      $composableBuilder(column: $table.pveAddr, builder: (column) => column);

  GeneratedColumn<bool> get pveIgnoreCert => $composableBuilder(
    column: $table.pveIgnoreCert,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cmdsJson =>
      $composableBuilder(column: $table.cmdsJson, builder: (column) => column);

  GeneratedColumn<String> get preferTempDev => $composableBuilder(
    column: $table.preferTempDev,
    builder: (column) => column,
  );

  GeneratedColumn<String> get logoUrl =>
      $composableBuilder(column: $table.logoUrl, builder: (column) => column);

  GeneratedColumn<String> get netDev =>
      $composableBuilder(column: $table.netDev, builder: (column) => column);

  GeneratedColumn<String> get scriptDir =>
      $composableBuilder(column: $table.scriptDir, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ServersTableAnnotationComposer get serverId {
    final $$ServersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableAnnotationComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServerCustomsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ServerCustomsTable,
          ServerCustom,
          $$ServerCustomsTableFilterComposer,
          $$ServerCustomsTableOrderingComposer,
          $$ServerCustomsTableAnnotationComposer,
          $$ServerCustomsTableCreateCompanionBuilder,
          $$ServerCustomsTableUpdateCompanionBuilder,
          (ServerCustom, $$ServerCustomsTableReferences),
          ServerCustom,
          PrefetchHooks Function({bool serverId})
        > {
  $$ServerCustomsTableTableManager(_$AppDb db, $ServerCustomsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServerCustomsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServerCustomsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServerCustomsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String?> pveAddr = const Value.absent(),
                Value<bool> pveIgnoreCert = const Value.absent(),
                Value<String?> cmdsJson = const Value.absent(),
                Value<String?> preferTempDev = const Value.absent(),
                Value<String?> logoUrl = const Value.absent(),
                Value<String?> netDev = const Value.absent(),
                Value<String?> scriptDir = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServerCustomsCompanion(
                serverId: serverId,
                pveAddr: pveAddr,
                pveIgnoreCert: pveIgnoreCert,
                cmdsJson: cmdsJson,
                preferTempDev: preferTempDev,
                logoUrl: logoUrl,
                netDev: netDev,
                scriptDir: scriptDir,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                Value<String?> pveAddr = const Value.absent(),
                Value<bool> pveIgnoreCert = const Value.absent(),
                Value<String?> cmdsJson = const Value.absent(),
                Value<String?> preferTempDev = const Value.absent(),
                Value<String?> logoUrl = const Value.absent(),
                Value<String?> netDev = const Value.absent(),
                Value<String?> scriptDir = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ServerCustomsCompanion.insert(
                serverId: serverId,
                pveAddr: pveAddr,
                pveIgnoreCert: pveIgnoreCert,
                cmdsJson: cmdsJson,
                preferTempDev: preferTempDev,
                logoUrl: logoUrl,
                netDev: netDev,
                scriptDir: scriptDir,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ServerCustomsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({serverId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (serverId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.serverId,
                                referencedTable: $$ServerCustomsTableReferences
                                    ._serverIdTable(db),
                                referencedColumn: $$ServerCustomsTableReferences
                                    ._serverIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ServerCustomsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ServerCustomsTable,
      ServerCustom,
      $$ServerCustomsTableFilterComposer,
      $$ServerCustomsTableOrderingComposer,
      $$ServerCustomsTableAnnotationComposer,
      $$ServerCustomsTableCreateCompanionBuilder,
      $$ServerCustomsTableUpdateCompanionBuilder,
      (ServerCustom, $$ServerCustomsTableReferences),
      ServerCustom,
      PrefetchHooks Function({bool serverId})
    >;
typedef $$ServerWolCfgsTableCreateCompanionBuilder =
    ServerWolCfgsCompanion Function({
      required String serverId,
      required String mac,
      required String ip,
      Value<String?> pwd,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ServerWolCfgsTableUpdateCompanionBuilder =
    ServerWolCfgsCompanion Function({
      Value<String> serverId,
      Value<String> mac,
      Value<String> ip,
      Value<String?> pwd,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$ServerWolCfgsTableReferences
    extends BaseReferences<_$AppDb, $ServerWolCfgsTable, ServerWolCfg> {
  $$ServerWolCfgsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ServersTable _serverIdTable(_$AppDb db) => db.servers.createAlias(
    $_aliasNameGenerator(db.serverWolCfgs.serverId, db.servers.id),
  );

  $$ServersTableProcessedTableManager get serverId {
    final $_column = $_itemColumn<String>('server_id')!;

    final manager = $$ServersTableTableManager(
      $_db,
      $_db.servers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_serverIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ServerWolCfgsTableFilterComposer
    extends Composer<_$AppDb, $ServerWolCfgsTable> {
  $$ServerWolCfgsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mac => $composableBuilder(
    column: $table.mac,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ip => $composableBuilder(
    column: $table.ip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pwd => $composableBuilder(
    column: $table.pwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ServersTableFilterComposer get serverId {
    final $$ServersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableFilterComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServerWolCfgsTableOrderingComposer
    extends Composer<_$AppDb, $ServerWolCfgsTable> {
  $$ServerWolCfgsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mac => $composableBuilder(
    column: $table.mac,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ip => $composableBuilder(
    column: $table.ip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pwd => $composableBuilder(
    column: $table.pwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ServersTableOrderingComposer get serverId {
    final $$ServersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableOrderingComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServerWolCfgsTableAnnotationComposer
    extends Composer<_$AppDb, $ServerWolCfgsTable> {
  $$ServerWolCfgsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mac =>
      $composableBuilder(column: $table.mac, builder: (column) => column);

  GeneratedColumn<String> get ip =>
      $composableBuilder(column: $table.ip, builder: (column) => column);

  GeneratedColumn<String> get pwd =>
      $composableBuilder(column: $table.pwd, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ServersTableAnnotationComposer get serverId {
    final $$ServersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableAnnotationComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServerWolCfgsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ServerWolCfgsTable,
          ServerWolCfg,
          $$ServerWolCfgsTableFilterComposer,
          $$ServerWolCfgsTableOrderingComposer,
          $$ServerWolCfgsTableAnnotationComposer,
          $$ServerWolCfgsTableCreateCompanionBuilder,
          $$ServerWolCfgsTableUpdateCompanionBuilder,
          (ServerWolCfg, $$ServerWolCfgsTableReferences),
          ServerWolCfg,
          PrefetchHooks Function({bool serverId})
        > {
  $$ServerWolCfgsTableTableManager(_$AppDb db, $ServerWolCfgsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServerWolCfgsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServerWolCfgsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServerWolCfgsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> mac = const Value.absent(),
                Value<String> ip = const Value.absent(),
                Value<String?> pwd = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServerWolCfgsCompanion(
                serverId: serverId,
                mac: mac,
                ip: ip,
                pwd: pwd,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String mac,
                required String ip,
                Value<String?> pwd = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ServerWolCfgsCompanion.insert(
                serverId: serverId,
                mac: mac,
                ip: ip,
                pwd: pwd,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ServerWolCfgsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({serverId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (serverId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.serverId,
                                referencedTable: $$ServerWolCfgsTableReferences
                                    ._serverIdTable(db),
                                referencedColumn: $$ServerWolCfgsTableReferences
                                    ._serverIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ServerWolCfgsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ServerWolCfgsTable,
      ServerWolCfg,
      $$ServerWolCfgsTableFilterComposer,
      $$ServerWolCfgsTableOrderingComposer,
      $$ServerWolCfgsTableAnnotationComposer,
      $$ServerWolCfgsTableCreateCompanionBuilder,
      $$ServerWolCfgsTableUpdateCompanionBuilder,
      (ServerWolCfg, $$ServerWolCfgsTableReferences),
      ServerWolCfg,
      PrefetchHooks Function({bool serverId})
    >;
typedef $$ServerTagsTableCreateCompanionBuilder =
    ServerTagsCompanion Function({
      required String serverId,
      required String tag,
      Value<int> rowid,
    });
typedef $$ServerTagsTableUpdateCompanionBuilder =
    ServerTagsCompanion Function({
      Value<String> serverId,
      Value<String> tag,
      Value<int> rowid,
    });

final class $$ServerTagsTableReferences
    extends BaseReferences<_$AppDb, $ServerTagsTable, ServerTag> {
  $$ServerTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ServersTable _serverIdTable(_$AppDb db) => db.servers.createAlias(
    $_aliasNameGenerator(db.serverTags.serverId, db.servers.id),
  );

  $$ServersTableProcessedTableManager get serverId {
    final $_column = $_itemColumn<String>('server_id')!;

    final manager = $$ServersTableTableManager(
      $_db,
      $_db.servers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_serverIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ServerTagsTableFilterComposer
    extends Composer<_$AppDb, $ServerTagsTable> {
  $$ServerTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  $$ServersTableFilterComposer get serverId {
    final $$ServersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableFilterComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServerTagsTableOrderingComposer
    extends Composer<_$AppDb, $ServerTagsTable> {
  $$ServerTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  $$ServersTableOrderingComposer get serverId {
    final $$ServersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableOrderingComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServerTagsTableAnnotationComposer
    extends Composer<_$AppDb, $ServerTagsTable> {
  $$ServerTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  $$ServersTableAnnotationComposer get serverId {
    final $$ServersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableAnnotationComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServerTagsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ServerTagsTable,
          ServerTag,
          $$ServerTagsTableFilterComposer,
          $$ServerTagsTableOrderingComposer,
          $$ServerTagsTableAnnotationComposer,
          $$ServerTagsTableCreateCompanionBuilder,
          $$ServerTagsTableUpdateCompanionBuilder,
          (ServerTag, $$ServerTagsTableReferences),
          ServerTag,
          PrefetchHooks Function({bool serverId})
        > {
  $$ServerTagsTableTableManager(_$AppDb db, $ServerTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServerTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServerTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServerTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServerTagsCompanion(
                serverId: serverId,
                tag: tag,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String tag,
                Value<int> rowid = const Value.absent(),
              }) => ServerTagsCompanion.insert(
                serverId: serverId,
                tag: tag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ServerTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({serverId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (serverId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.serverId,
                                referencedTable: $$ServerTagsTableReferences
                                    ._serverIdTable(db),
                                referencedColumn: $$ServerTagsTableReferences
                                    ._serverIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ServerTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ServerTagsTable,
      ServerTag,
      $$ServerTagsTableFilterComposer,
      $$ServerTagsTableOrderingComposer,
      $$ServerTagsTableAnnotationComposer,
      $$ServerTagsTableCreateCompanionBuilder,
      $$ServerTagsTableUpdateCompanionBuilder,
      (ServerTag, $$ServerTagsTableReferences),
      ServerTag,
      PrefetchHooks Function({bool serverId})
    >;
typedef $$ServerEnvsTableCreateCompanionBuilder =
    ServerEnvsCompanion Function({
      required String serverId,
      required String envKey,
      required String envVal,
      Value<int> rowid,
    });
typedef $$ServerEnvsTableUpdateCompanionBuilder =
    ServerEnvsCompanion Function({
      Value<String> serverId,
      Value<String> envKey,
      Value<String> envVal,
      Value<int> rowid,
    });

final class $$ServerEnvsTableReferences
    extends BaseReferences<_$AppDb, $ServerEnvsTable, ServerEnv> {
  $$ServerEnvsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ServersTable _serverIdTable(_$AppDb db) => db.servers.createAlias(
    $_aliasNameGenerator(db.serverEnvs.serverId, db.servers.id),
  );

  $$ServersTableProcessedTableManager get serverId {
    final $_column = $_itemColumn<String>('server_id')!;

    final manager = $$ServersTableTableManager(
      $_db,
      $_db.servers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_serverIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ServerEnvsTableFilterComposer
    extends Composer<_$AppDb, $ServerEnvsTable> {
  $$ServerEnvsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get envKey => $composableBuilder(
    column: $table.envKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get envVal => $composableBuilder(
    column: $table.envVal,
    builder: (column) => ColumnFilters(column),
  );

  $$ServersTableFilterComposer get serverId {
    final $$ServersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableFilterComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServerEnvsTableOrderingComposer
    extends Composer<_$AppDb, $ServerEnvsTable> {
  $$ServerEnvsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get envKey => $composableBuilder(
    column: $table.envKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get envVal => $composableBuilder(
    column: $table.envVal,
    builder: (column) => ColumnOrderings(column),
  );

  $$ServersTableOrderingComposer get serverId {
    final $$ServersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableOrderingComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServerEnvsTableAnnotationComposer
    extends Composer<_$AppDb, $ServerEnvsTable> {
  $$ServerEnvsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get envKey =>
      $composableBuilder(column: $table.envKey, builder: (column) => column);

  GeneratedColumn<String> get envVal =>
      $composableBuilder(column: $table.envVal, builder: (column) => column);

  $$ServersTableAnnotationComposer get serverId {
    final $$ServersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableAnnotationComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServerEnvsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ServerEnvsTable,
          ServerEnv,
          $$ServerEnvsTableFilterComposer,
          $$ServerEnvsTableOrderingComposer,
          $$ServerEnvsTableAnnotationComposer,
          $$ServerEnvsTableCreateCompanionBuilder,
          $$ServerEnvsTableUpdateCompanionBuilder,
          (ServerEnv, $$ServerEnvsTableReferences),
          ServerEnv,
          PrefetchHooks Function({bool serverId})
        > {
  $$ServerEnvsTableTableManager(_$AppDb db, $ServerEnvsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServerEnvsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServerEnvsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServerEnvsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> envKey = const Value.absent(),
                Value<String> envVal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServerEnvsCompanion(
                serverId: serverId,
                envKey: envKey,
                envVal: envVal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String envKey,
                required String envVal,
                Value<int> rowid = const Value.absent(),
              }) => ServerEnvsCompanion.insert(
                serverId: serverId,
                envKey: envKey,
                envVal: envVal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ServerEnvsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({serverId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (serverId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.serverId,
                                referencedTable: $$ServerEnvsTableReferences
                                    ._serverIdTable(db),
                                referencedColumn: $$ServerEnvsTableReferences
                                    ._serverIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ServerEnvsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ServerEnvsTable,
      ServerEnv,
      $$ServerEnvsTableFilterComposer,
      $$ServerEnvsTableOrderingComposer,
      $$ServerEnvsTableAnnotationComposer,
      $$ServerEnvsTableCreateCompanionBuilder,
      $$ServerEnvsTableUpdateCompanionBuilder,
      (ServerEnv, $$ServerEnvsTableReferences),
      ServerEnv,
      PrefetchHooks Function({bool serverId})
    >;
typedef $$ServerDisabledCmdTypesTableCreateCompanionBuilder =
    ServerDisabledCmdTypesCompanion Function({
      required String serverId,
      required String cmdType,
      Value<int> rowid,
    });
typedef $$ServerDisabledCmdTypesTableUpdateCompanionBuilder =
    ServerDisabledCmdTypesCompanion Function({
      Value<String> serverId,
      Value<String> cmdType,
      Value<int> rowid,
    });

final class $$ServerDisabledCmdTypesTableReferences
    extends
        BaseReferences<
          _$AppDb,
          $ServerDisabledCmdTypesTable,
          ServerDisabledCmdType
        > {
  $$ServerDisabledCmdTypesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ServersTable _serverIdTable(_$AppDb db) => db.servers.createAlias(
    $_aliasNameGenerator(db.serverDisabledCmdTypes.serverId, db.servers.id),
  );

  $$ServersTableProcessedTableManager get serverId {
    final $_column = $_itemColumn<String>('server_id')!;

    final manager = $$ServersTableTableManager(
      $_db,
      $_db.servers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_serverIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ServerDisabledCmdTypesTableFilterComposer
    extends Composer<_$AppDb, $ServerDisabledCmdTypesTable> {
  $$ServerDisabledCmdTypesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cmdType => $composableBuilder(
    column: $table.cmdType,
    builder: (column) => ColumnFilters(column),
  );

  $$ServersTableFilterComposer get serverId {
    final $$ServersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableFilterComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServerDisabledCmdTypesTableOrderingComposer
    extends Composer<_$AppDb, $ServerDisabledCmdTypesTable> {
  $$ServerDisabledCmdTypesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cmdType => $composableBuilder(
    column: $table.cmdType,
    builder: (column) => ColumnOrderings(column),
  );

  $$ServersTableOrderingComposer get serverId {
    final $$ServersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableOrderingComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServerDisabledCmdTypesTableAnnotationComposer
    extends Composer<_$AppDb, $ServerDisabledCmdTypesTable> {
  $$ServerDisabledCmdTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cmdType =>
      $composableBuilder(column: $table.cmdType, builder: (column) => column);

  $$ServersTableAnnotationComposer get serverId {
    final $$ServersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serverId,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServersTableAnnotationComposer(
            $db: $db,
            $table: $db.servers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServerDisabledCmdTypesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ServerDisabledCmdTypesTable,
          ServerDisabledCmdType,
          $$ServerDisabledCmdTypesTableFilterComposer,
          $$ServerDisabledCmdTypesTableOrderingComposer,
          $$ServerDisabledCmdTypesTableAnnotationComposer,
          $$ServerDisabledCmdTypesTableCreateCompanionBuilder,
          $$ServerDisabledCmdTypesTableUpdateCompanionBuilder,
          (ServerDisabledCmdType, $$ServerDisabledCmdTypesTableReferences),
          ServerDisabledCmdType,
          PrefetchHooks Function({bool serverId})
        > {
  $$ServerDisabledCmdTypesTableTableManager(
    _$AppDb db,
    $ServerDisabledCmdTypesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServerDisabledCmdTypesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ServerDisabledCmdTypesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ServerDisabledCmdTypesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> cmdType = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServerDisabledCmdTypesCompanion(
                serverId: serverId,
                cmdType: cmdType,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String cmdType,
                Value<int> rowid = const Value.absent(),
              }) => ServerDisabledCmdTypesCompanion.insert(
                serverId: serverId,
                cmdType: cmdType,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ServerDisabledCmdTypesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({serverId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (serverId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.serverId,
                                referencedTable:
                                    $$ServerDisabledCmdTypesTableReferences
                                        ._serverIdTable(db),
                                referencedColumn:
                                    $$ServerDisabledCmdTypesTableReferences
                                        ._serverIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ServerDisabledCmdTypesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ServerDisabledCmdTypesTable,
      ServerDisabledCmdType,
      $$ServerDisabledCmdTypesTableFilterComposer,
      $$ServerDisabledCmdTypesTableOrderingComposer,
      $$ServerDisabledCmdTypesTableAnnotationComposer,
      $$ServerDisabledCmdTypesTableCreateCompanionBuilder,
      $$ServerDisabledCmdTypesTableUpdateCompanionBuilder,
      (ServerDisabledCmdType, $$ServerDisabledCmdTypesTableReferences),
      ServerDisabledCmdType,
      PrefetchHooks Function({bool serverId})
    >;
typedef $$SnippetsTableCreateCompanionBuilder =
    SnippetsCompanion Function({
      required String name,
      required String script,
      Value<String?> note,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SnippetsTableUpdateCompanionBuilder =
    SnippetsCompanion Function({
      Value<String> name,
      Value<String> script,
      Value<String?> note,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$SnippetsTableReferences
    extends BaseReferences<_$AppDb, $SnippetsTable, Snippet> {
  $$SnippetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SnippetTagsTable, List<SnippetTag>>
  _snippetTagsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.snippetTags,
    aliasName: $_aliasNameGenerator(
      db.snippets.name,
      db.snippetTags.snippetName,
    ),
  );

  $$SnippetTagsTableProcessedTableManager get snippetTagsRefs {
    final manager = $$SnippetTagsTableTableManager($_db, $_db.snippetTags)
        .filter(
          (f) => f.snippetName.name.sqlEquals($_itemColumn<String>('name')!),
        );

    final cache = $_typedResult.readTableOrNull(_snippetTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SnippetAutoRunsTable, List<SnippetAutoRun>>
  _snippetAutoRunsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.snippetAutoRuns,
    aliasName: $_aliasNameGenerator(
      db.snippets.name,
      db.snippetAutoRuns.snippetName,
    ),
  );

  $$SnippetAutoRunsTableProcessedTableManager get snippetAutoRunsRefs {
    final manager =
        $$SnippetAutoRunsTableTableManager($_db, $_db.snippetAutoRuns).filter(
          (f) => f.snippetName.name.sqlEquals($_itemColumn<String>('name')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _snippetAutoRunsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SnippetsTableFilterComposer extends Composer<_$AppDb, $SnippetsTable> {
  $$SnippetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get script => $composableBuilder(
    column: $table.script,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> snippetTagsRefs(
    Expression<bool> Function($$SnippetTagsTableFilterComposer f) f,
  ) {
    final $$SnippetTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.name,
      referencedTable: $db.snippetTags,
      getReferencedColumn: (t) => t.snippetName,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnippetTagsTableFilterComposer(
            $db: $db,
            $table: $db.snippetTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> snippetAutoRunsRefs(
    Expression<bool> Function($$SnippetAutoRunsTableFilterComposer f) f,
  ) {
    final $$SnippetAutoRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.name,
      referencedTable: $db.snippetAutoRuns,
      getReferencedColumn: (t) => t.snippetName,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnippetAutoRunsTableFilterComposer(
            $db: $db,
            $table: $db.snippetAutoRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SnippetsTableOrderingComposer
    extends Composer<_$AppDb, $SnippetsTable> {
  $$SnippetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get script => $composableBuilder(
    column: $table.script,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SnippetsTableAnnotationComposer
    extends Composer<_$AppDb, $SnippetsTable> {
  $$SnippetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get script =>
      $composableBuilder(column: $table.script, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> snippetTagsRefs<T extends Object>(
    Expression<T> Function($$SnippetTagsTableAnnotationComposer a) f,
  ) {
    final $$SnippetTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.name,
      referencedTable: $db.snippetTags,
      getReferencedColumn: (t) => t.snippetName,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnippetTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.snippetTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> snippetAutoRunsRefs<T extends Object>(
    Expression<T> Function($$SnippetAutoRunsTableAnnotationComposer a) f,
  ) {
    final $$SnippetAutoRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.name,
      referencedTable: $db.snippetAutoRuns,
      getReferencedColumn: (t) => t.snippetName,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnippetAutoRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.snippetAutoRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SnippetsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SnippetsTable,
          Snippet,
          $$SnippetsTableFilterComposer,
          $$SnippetsTableOrderingComposer,
          $$SnippetsTableAnnotationComposer,
          $$SnippetsTableCreateCompanionBuilder,
          $$SnippetsTableUpdateCompanionBuilder,
          (Snippet, $$SnippetsTableReferences),
          Snippet,
          PrefetchHooks Function({
            bool snippetTagsRefs,
            bool snippetAutoRunsRefs,
          })
        > {
  $$SnippetsTableTableManager(_$AppDb db, $SnippetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnippetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnippetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SnippetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> name = const Value.absent(),
                Value<String> script = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SnippetsCompanion(
                name: name,
                script: script,
                note: note,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String name,
                required String script,
                Value<String?> note = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SnippetsCompanion.insert(
                name: name,
                script: script,
                note: note,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SnippetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({snippetTagsRefs = false, snippetAutoRunsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (snippetTagsRefs) db.snippetTags,
                    if (snippetAutoRunsRefs) db.snippetAutoRuns,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (snippetTagsRefs)
                        await $_getPrefetchedData<
                          Snippet,
                          $SnippetsTable,
                          SnippetTag
                        >(
                          currentTable: table,
                          referencedTable: $$SnippetsTableReferences
                              ._snippetTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SnippetsTableReferences(
                                db,
                                table,
                                p0,
                              ).snippetTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.snippetName == item.name,
                              ),
                          typedResults: items,
                        ),
                      if (snippetAutoRunsRefs)
                        await $_getPrefetchedData<
                          Snippet,
                          $SnippetsTable,
                          SnippetAutoRun
                        >(
                          currentTable: table,
                          referencedTable: $$SnippetsTableReferences
                              ._snippetAutoRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SnippetsTableReferences(
                                db,
                                table,
                                p0,
                              ).snippetAutoRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.snippetName == item.name,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SnippetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SnippetsTable,
      Snippet,
      $$SnippetsTableFilterComposer,
      $$SnippetsTableOrderingComposer,
      $$SnippetsTableAnnotationComposer,
      $$SnippetsTableCreateCompanionBuilder,
      $$SnippetsTableUpdateCompanionBuilder,
      (Snippet, $$SnippetsTableReferences),
      Snippet,
      PrefetchHooks Function({bool snippetTagsRefs, bool snippetAutoRunsRefs})
    >;
typedef $$SnippetTagsTableCreateCompanionBuilder =
    SnippetTagsCompanion Function({
      required String snippetName,
      required String tag,
      Value<int> rowid,
    });
typedef $$SnippetTagsTableUpdateCompanionBuilder =
    SnippetTagsCompanion Function({
      Value<String> snippetName,
      Value<String> tag,
      Value<int> rowid,
    });

final class $$SnippetTagsTableReferences
    extends BaseReferences<_$AppDb, $SnippetTagsTable, SnippetTag> {
  $$SnippetTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SnippetsTable _snippetNameTable(_$AppDb db) =>
      db.snippets.createAlias(
        $_aliasNameGenerator(db.snippetTags.snippetName, db.snippets.name),
      );

  $$SnippetsTableProcessedTableManager get snippetName {
    final $_column = $_itemColumn<String>('snippet_name')!;

    final manager = $$SnippetsTableTableManager(
      $_db,
      $_db.snippets,
    ).filter((f) => f.name.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_snippetNameTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SnippetTagsTableFilterComposer
    extends Composer<_$AppDb, $SnippetTagsTable> {
  $$SnippetTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  $$SnippetsTableFilterComposer get snippetName {
    final $$SnippetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snippetName,
      referencedTable: $db.snippets,
      getReferencedColumn: (t) => t.name,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnippetsTableFilterComposer(
            $db: $db,
            $table: $db.snippets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnippetTagsTableOrderingComposer
    extends Composer<_$AppDb, $SnippetTagsTable> {
  $$SnippetTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  $$SnippetsTableOrderingComposer get snippetName {
    final $$SnippetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snippetName,
      referencedTable: $db.snippets,
      getReferencedColumn: (t) => t.name,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnippetsTableOrderingComposer(
            $db: $db,
            $table: $db.snippets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnippetTagsTableAnnotationComposer
    extends Composer<_$AppDb, $SnippetTagsTable> {
  $$SnippetTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  $$SnippetsTableAnnotationComposer get snippetName {
    final $$SnippetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snippetName,
      referencedTable: $db.snippets,
      getReferencedColumn: (t) => t.name,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnippetsTableAnnotationComposer(
            $db: $db,
            $table: $db.snippets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnippetTagsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SnippetTagsTable,
          SnippetTag,
          $$SnippetTagsTableFilterComposer,
          $$SnippetTagsTableOrderingComposer,
          $$SnippetTagsTableAnnotationComposer,
          $$SnippetTagsTableCreateCompanionBuilder,
          $$SnippetTagsTableUpdateCompanionBuilder,
          (SnippetTag, $$SnippetTagsTableReferences),
          SnippetTag,
          PrefetchHooks Function({bool snippetName})
        > {
  $$SnippetTagsTableTableManager(_$AppDb db, $SnippetTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnippetTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnippetTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SnippetTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> snippetName = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SnippetTagsCompanion(
                snippetName: snippetName,
                tag: tag,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String snippetName,
                required String tag,
                Value<int> rowid = const Value.absent(),
              }) => SnippetTagsCompanion.insert(
                snippetName: snippetName,
                tag: tag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SnippetTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({snippetName = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (snippetName) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.snippetName,
                                referencedTable: $$SnippetTagsTableReferences
                                    ._snippetNameTable(db),
                                referencedColumn: $$SnippetTagsTableReferences
                                    ._snippetNameTable(db)
                                    .name,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SnippetTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SnippetTagsTable,
      SnippetTag,
      $$SnippetTagsTableFilterComposer,
      $$SnippetTagsTableOrderingComposer,
      $$SnippetTagsTableAnnotationComposer,
      $$SnippetTagsTableCreateCompanionBuilder,
      $$SnippetTagsTableUpdateCompanionBuilder,
      (SnippetTag, $$SnippetTagsTableReferences),
      SnippetTag,
      PrefetchHooks Function({bool snippetName})
    >;
typedef $$SnippetAutoRunsTableCreateCompanionBuilder =
    SnippetAutoRunsCompanion Function({
      required String snippetName,
      required String serverId,
      Value<int> rowid,
    });
typedef $$SnippetAutoRunsTableUpdateCompanionBuilder =
    SnippetAutoRunsCompanion Function({
      Value<String> snippetName,
      Value<String> serverId,
      Value<int> rowid,
    });

final class $$SnippetAutoRunsTableReferences
    extends BaseReferences<_$AppDb, $SnippetAutoRunsTable, SnippetAutoRun> {
  $$SnippetAutoRunsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SnippetsTable _snippetNameTable(_$AppDb db) =>
      db.snippets.createAlias(
        $_aliasNameGenerator(db.snippetAutoRuns.snippetName, db.snippets.name),
      );

  $$SnippetsTableProcessedTableManager get snippetName {
    final $_column = $_itemColumn<String>('snippet_name')!;

    final manager = $$SnippetsTableTableManager(
      $_db,
      $_db.snippets,
    ).filter((f) => f.name.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_snippetNameTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SnippetAutoRunsTableFilterComposer
    extends Composer<_$AppDb, $SnippetAutoRunsTable> {
  $$SnippetAutoRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  $$SnippetsTableFilterComposer get snippetName {
    final $$SnippetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snippetName,
      referencedTable: $db.snippets,
      getReferencedColumn: (t) => t.name,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnippetsTableFilterComposer(
            $db: $db,
            $table: $db.snippets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnippetAutoRunsTableOrderingComposer
    extends Composer<_$AppDb, $SnippetAutoRunsTable> {
  $$SnippetAutoRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  $$SnippetsTableOrderingComposer get snippetName {
    final $$SnippetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snippetName,
      referencedTable: $db.snippets,
      getReferencedColumn: (t) => t.name,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnippetsTableOrderingComposer(
            $db: $db,
            $table: $db.snippets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnippetAutoRunsTableAnnotationComposer
    extends Composer<_$AppDb, $SnippetAutoRunsTable> {
  $$SnippetAutoRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  $$SnippetsTableAnnotationComposer get snippetName {
    final $$SnippetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snippetName,
      referencedTable: $db.snippets,
      getReferencedColumn: (t) => t.name,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnippetsTableAnnotationComposer(
            $db: $db,
            $table: $db.snippets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnippetAutoRunsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SnippetAutoRunsTable,
          SnippetAutoRun,
          $$SnippetAutoRunsTableFilterComposer,
          $$SnippetAutoRunsTableOrderingComposer,
          $$SnippetAutoRunsTableAnnotationComposer,
          $$SnippetAutoRunsTableCreateCompanionBuilder,
          $$SnippetAutoRunsTableUpdateCompanionBuilder,
          (SnippetAutoRun, $$SnippetAutoRunsTableReferences),
          SnippetAutoRun,
          PrefetchHooks Function({bool snippetName})
        > {
  $$SnippetAutoRunsTableTableManager(_$AppDb db, $SnippetAutoRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnippetAutoRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnippetAutoRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SnippetAutoRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> snippetName = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SnippetAutoRunsCompanion(
                snippetName: snippetName,
                serverId: serverId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String snippetName,
                required String serverId,
                Value<int> rowid = const Value.absent(),
              }) => SnippetAutoRunsCompanion.insert(
                snippetName: snippetName,
                serverId: serverId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SnippetAutoRunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({snippetName = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (snippetName) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.snippetName,
                                referencedTable:
                                    $$SnippetAutoRunsTableReferences
                                        ._snippetNameTable(db),
                                referencedColumn:
                                    $$SnippetAutoRunsTableReferences
                                        ._snippetNameTable(db)
                                        .name,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SnippetAutoRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SnippetAutoRunsTable,
      SnippetAutoRun,
      $$SnippetAutoRunsTableFilterComposer,
      $$SnippetAutoRunsTableOrderingComposer,
      $$SnippetAutoRunsTableAnnotationComposer,
      $$SnippetAutoRunsTableCreateCompanionBuilder,
      $$SnippetAutoRunsTableUpdateCompanionBuilder,
      (SnippetAutoRun, $$SnippetAutoRunsTableReferences),
      SnippetAutoRun,
      PrefetchHooks Function({bool snippetName})
    >;
typedef $$PrivateKeysTableCreateCompanionBuilder =
    PrivateKeysCompanion Function({
      required String id,
      required String privateKey,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$PrivateKeysTableUpdateCompanionBuilder =
    PrivateKeysCompanion Function({
      Value<String> id,
      Value<String> privateKey,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$PrivateKeysTableFilterComposer
    extends Composer<_$AppDb, $PrivateKeysTable> {
  $$PrivateKeysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get privateKey => $composableBuilder(
    column: $table.privateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PrivateKeysTableOrderingComposer
    extends Composer<_$AppDb, $PrivateKeysTable> {
  $$PrivateKeysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get privateKey => $composableBuilder(
    column: $table.privateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PrivateKeysTableAnnotationComposer
    extends Composer<_$AppDb, $PrivateKeysTable> {
  $$PrivateKeysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get privateKey => $composableBuilder(
    column: $table.privateKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PrivateKeysTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $PrivateKeysTable,
          PrivateKey,
          $$PrivateKeysTableFilterComposer,
          $$PrivateKeysTableOrderingComposer,
          $$PrivateKeysTableAnnotationComposer,
          $$PrivateKeysTableCreateCompanionBuilder,
          $$PrivateKeysTableUpdateCompanionBuilder,
          (PrivateKey, BaseReferences<_$AppDb, $PrivateKeysTable, PrivateKey>),
          PrivateKey,
          PrefetchHooks Function()
        > {
  $$PrivateKeysTableTableManager(_$AppDb db, $PrivateKeysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrivateKeysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrivateKeysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrivateKeysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> privateKey = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrivateKeysCompanion(
                id: id,
                privateKey: privateKey,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String privateKey,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PrivateKeysCompanion.insert(
                id: id,
                privateKey: privateKey,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrivateKeysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $PrivateKeysTable,
      PrivateKey,
      $$PrivateKeysTableFilterComposer,
      $$PrivateKeysTableOrderingComposer,
      $$PrivateKeysTableAnnotationComposer,
      $$PrivateKeysTableCreateCompanionBuilder,
      $$PrivateKeysTableUpdateCompanionBuilder,
      (PrivateKey, BaseReferences<_$AppDb, $PrivateKeysTable, PrivateKey>),
      PrivateKey,
      PrefetchHooks Function()
    >;
typedef $$ContainerHostsTableCreateCompanionBuilder =
    ContainerHostsCompanion Function({
      required String serverId,
      required String host,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ContainerHostsTableUpdateCompanionBuilder =
    ContainerHostsCompanion Function({
      Value<String> serverId,
      Value<String> host,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$ContainerHostsTableFilterComposer
    extends Composer<_$AppDb, $ContainerHostsTable> {
  $$ContainerHostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContainerHostsTableOrderingComposer
    extends Composer<_$AppDb, $ContainerHostsTable> {
  $$ContainerHostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContainerHostsTableAnnotationComposer
    extends Composer<_$AppDb, $ContainerHostsTable> {
  $$ContainerHostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ContainerHostsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ContainerHostsTable,
          ContainerHost,
          $$ContainerHostsTableFilterComposer,
          $$ContainerHostsTableOrderingComposer,
          $$ContainerHostsTableAnnotationComposer,
          $$ContainerHostsTableCreateCompanionBuilder,
          $$ContainerHostsTableUpdateCompanionBuilder,
          (
            ContainerHost,
            BaseReferences<_$AppDb, $ContainerHostsTable, ContainerHost>,
          ),
          ContainerHost,
          PrefetchHooks Function()
        > {
  $$ContainerHostsTableTableManager(_$AppDb db, $ContainerHostsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContainerHostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContainerHostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContainerHostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContainerHostsCompanion(
                serverId: serverId,
                host: host,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String host,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ContainerHostsCompanion.insert(
                serverId: serverId,
                host: host,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContainerHostsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ContainerHostsTable,
      ContainerHost,
      $$ContainerHostsTableFilterComposer,
      $$ContainerHostsTableOrderingComposer,
      $$ContainerHostsTableAnnotationComposer,
      $$ContainerHostsTableCreateCompanionBuilder,
      $$ContainerHostsTableUpdateCompanionBuilder,
      (
        ContainerHost,
        BaseReferences<_$AppDb, $ContainerHostsTable, ContainerHost>,
      ),
      ContainerHost,
      PrefetchHooks Function()
    >;
typedef $$ConnectionStatsRecordsTableCreateCompanionBuilder =
    ConnectionStatsRecordsCompanion Function({
      Value<int> id,
      required String serverId,
      required String serverName,
      required int timestampMs,
      required String result,
      required String errorMessage,
      required int durationMs,
      required int updatedAt,
    });
typedef $$ConnectionStatsRecordsTableUpdateCompanionBuilder =
    ConnectionStatsRecordsCompanion Function({
      Value<int> id,
      Value<String> serverId,
      Value<String> serverName,
      Value<int> timestampMs,
      Value<String> result,
      Value<String> errorMessage,
      Value<int> durationMs,
      Value<int> updatedAt,
    });

class $$ConnectionStatsRecordsTableFilterComposer
    extends Composer<_$AppDb, $ConnectionStatsRecordsTable> {
  $$ConnectionStatsRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverName => $composableBuilder(
    column: $table.serverName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConnectionStatsRecordsTableOrderingComposer
    extends Composer<_$AppDb, $ConnectionStatsRecordsTable> {
  $$ConnectionStatsRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverName => $composableBuilder(
    column: $table.serverName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConnectionStatsRecordsTableAnnotationComposer
    extends Composer<_$AppDb, $ConnectionStatsRecordsTable> {
  $$ConnectionStatsRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get serverName => $composableBuilder(
    column: $table.serverName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ConnectionStatsRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ConnectionStatsRecordsTable,
          ConnectionStatsRecord,
          $$ConnectionStatsRecordsTableFilterComposer,
          $$ConnectionStatsRecordsTableOrderingComposer,
          $$ConnectionStatsRecordsTableAnnotationComposer,
          $$ConnectionStatsRecordsTableCreateCompanionBuilder,
          $$ConnectionStatsRecordsTableUpdateCompanionBuilder,
          (
            ConnectionStatsRecord,
            BaseReferences<
              _$AppDb,
              $ConnectionStatsRecordsTable,
              ConnectionStatsRecord
            >,
          ),
          ConnectionStatsRecord,
          PrefetchHooks Function()
        > {
  $$ConnectionStatsRecordsTableTableManager(
    _$AppDb db,
    $ConnectionStatsRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConnectionStatsRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ConnectionStatsRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConnectionStatsRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<String> serverName = const Value.absent(),
                Value<int> timestampMs = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<String> errorMessage = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => ConnectionStatsRecordsCompanion(
                id: id,
                serverId: serverId,
                serverName: serverName,
                timestampMs: timestampMs,
                result: result,
                errorMessage: errorMessage,
                durationMs: durationMs,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String serverId,
                required String serverName,
                required int timestampMs,
                required String result,
                required String errorMessage,
                required int durationMs,
                required int updatedAt,
              }) => ConnectionStatsRecordsCompanion.insert(
                id: id,
                serverId: serverId,
                serverName: serverName,
                timestampMs: timestampMs,
                result: result,
                errorMessage: errorMessage,
                durationMs: durationMs,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConnectionStatsRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ConnectionStatsRecordsTable,
      ConnectionStatsRecord,
      $$ConnectionStatsRecordsTableFilterComposer,
      $$ConnectionStatsRecordsTableOrderingComposer,
      $$ConnectionStatsRecordsTableAnnotationComposer,
      $$ConnectionStatsRecordsTableCreateCompanionBuilder,
      $$ConnectionStatsRecordsTableUpdateCompanionBuilder,
      (
        ConnectionStatsRecord,
        BaseReferences<
          _$AppDb,
          $ConnectionStatsRecordsTable,
          ConnectionStatsRecord
        >,
      ),
      ConnectionStatsRecord,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$ServersTableTableManager get servers =>
      $$ServersTableTableManager(_db, _db.servers);
  $$ServerCustomsTableTableManager get serverCustoms =>
      $$ServerCustomsTableTableManager(_db, _db.serverCustoms);
  $$ServerWolCfgsTableTableManager get serverWolCfgs =>
      $$ServerWolCfgsTableTableManager(_db, _db.serverWolCfgs);
  $$ServerTagsTableTableManager get serverTags =>
      $$ServerTagsTableTableManager(_db, _db.serverTags);
  $$ServerEnvsTableTableManager get serverEnvs =>
      $$ServerEnvsTableTableManager(_db, _db.serverEnvs);
  $$ServerDisabledCmdTypesTableTableManager get serverDisabledCmdTypes =>
      $$ServerDisabledCmdTypesTableTableManager(
        _db,
        _db.serverDisabledCmdTypes,
      );
  $$SnippetsTableTableManager get snippets =>
      $$SnippetsTableTableManager(_db, _db.snippets);
  $$SnippetTagsTableTableManager get snippetTags =>
      $$SnippetTagsTableTableManager(_db, _db.snippetTags);
  $$SnippetAutoRunsTableTableManager get snippetAutoRuns =>
      $$SnippetAutoRunsTableTableManager(_db, _db.snippetAutoRuns);
  $$PrivateKeysTableTableManager get privateKeys =>
      $$PrivateKeysTableTableManager(_db, _db.privateKeys);
  $$ContainerHostsTableTableManager get containerHosts =>
      $$ContainerHostsTableTableManager(_db, _db.containerHosts);
  $$ConnectionStatsRecordsTableTableManager get connectionStatsRecords =>
      $$ConnectionStatsRecordsTableTableManager(
        _db,
        _db.connectionStatsRecords,
      );
}
