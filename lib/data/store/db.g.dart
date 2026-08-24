// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $PrivateKeysTable extends PrivateKeys
    with TableInfo<$PrivateKeysTable, PrivateKeyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrivateKeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _revMeta = const VerificationMeta('rev');
  @override
  late final GeneratedColumn<int> rev = GeneratedColumn<int>(
    'rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    rev,
    id,
    name,
    key,
    comment,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'private_key';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrivateKeyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('rev')) {
      context.handle(
        _revMeta,
        rev.isAcceptableOrUnknown(data['rev']!, _revMeta),
      );
    }
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
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrivateKeyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrivateKeyRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rev'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
    );
  }

  @override
  $PrivateKeysTable createAlias(String alias) {
    return $PrivateKeysTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class PrivateKeyRow extends DataClass implements Insertable<PrivateKeyRow> {
  final int updatedAt;
  final int rev;
  final String id;
  final String name;
  final String key;

  /// The OpenSSH comment to put at the end of the public key line.
  ///
  /// Held here rather than rewritten into the key: the key file carries its own
  /// copy, inside the part that gets encrypted, so changing that one means
  /// opening the key and writing it out again — a passphrase prompt and a
  /// rewrite of key material, to edit a label.
  ///
  /// Null for a key stored before this column, and for one whose comment has
  /// never been edited. The key's own comment is read in that case, which is
  /// what keeps an imported key showing what it arrived with.
  final String? comment;
  const PrivateKeyRow({
    required this.updatedAt,
    required this.rev,
    required this.id,
    required this.name,
    required this.key,
    this.comment,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['rev'] = Variable<int>(rev);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    return map;
  }

  PrivateKeysCompanion toCompanion(bool nullToAbsent) {
    return PrivateKeysCompanion(
      updatedAt: Value(updatedAt),
      rev: Value(rev),
      id: Value(id),
      name: Value(name),
      key: Value(key),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
    );
  }

  factory PrivateKeyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrivateKeyRow(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rev: serializer.fromJson<int>(json['rev']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      key: serializer.fromJson<String>(json['key']),
      comment: serializer.fromJson<String?>(json['comment']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rev': serializer.toJson<int>(rev),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'key': serializer.toJson<String>(key),
      'comment': serializer.toJson<String?>(comment),
    };
  }

  PrivateKeyRow copyWith({
    int? updatedAt,
    int? rev,
    String? id,
    String? name,
    String? key,
    Value<String?> comment = const Value.absent(),
  }) => PrivateKeyRow(
    updatedAt: updatedAt ?? this.updatedAt,
    rev: rev ?? this.rev,
    id: id ?? this.id,
    name: name ?? this.name,
    key: key ?? this.key,
    comment: comment.present ? comment.value : this.comment,
  );
  PrivateKeyRow copyWithCompanion(PrivateKeysCompanion data) {
    return PrivateKeyRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rev: data.rev.present ? data.rev.value : this.rev,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      key: data.key.present ? data.key.value : this.key,
      comment: data.comment.present ? data.comment.value : this.comment,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrivateKeyRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('rev: $rev, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('key: $key, ')
          ..write('comment: $comment')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(updatedAt, rev, id, name, key, comment);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrivateKeyRow &&
          other.updatedAt == this.updatedAt &&
          other.rev == this.rev &&
          other.id == this.id &&
          other.name == this.name &&
          other.key == this.key &&
          other.comment == this.comment);
}

class PrivateKeysCompanion extends UpdateCompanion<PrivateKeyRow> {
  final Value<int> updatedAt;
  final Value<int> rev;
  final Value<String> id;
  final Value<String> name;
  final Value<String> key;
  final Value<String?> comment;
  const PrivateKeysCompanion({
    this.updatedAt = const Value.absent(),
    this.rev = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.key = const Value.absent(),
    this.comment = const Value.absent(),
  });
  PrivateKeysCompanion.insert({
    this.updatedAt = const Value.absent(),
    this.rev = const Value.absent(),
    required String id,
    required String name,
    required String key,
    this.comment = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       key = Value(key);
  static Insertable<PrivateKeyRow> custom({
    Expression<int>? updatedAt,
    Expression<int>? rev,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? key,
    Expression<String>? comment,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rev != null) 'rev': rev,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (key != null) 'key': key,
      if (comment != null) 'comment': comment,
    });
  }

  PrivateKeysCompanion copyWith({
    Value<int>? updatedAt,
    Value<int>? rev,
    Value<String>? id,
    Value<String>? name,
    Value<String>? key,
    Value<String?>? comment,
  }) {
    return PrivateKeysCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      rev: rev ?? this.rev,
      id: id ?? this.id,
      name: name ?? this.name,
      key: key ?? this.key,
      comment: comment ?? this.comment,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rev.present) {
      map['rev'] = Variable<int>(rev.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrivateKeysCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('rev: $rev, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('key: $key, ')
          ..write('comment: $comment')
          ..write(')'))
        .toString();
  }
}

class $BmcCredentialsTable extends BmcCredentials
    with TableInfo<$BmcCredentialsTable, BmcCredentialRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BmcCredentialsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _revMeta = const VerificationMeta('rev');
  @override
  late final GeneratedColumn<int> rev = GeneratedColumn<int>(
    'rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
  @override
  List<GeneratedColumn> get $columns => [updatedAt, rev, id, name, user, pwd];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bmc_credential';
  @override
  VerificationContext validateIntegrity(
    Insertable<BmcCredentialRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('rev')) {
      context.handle(
        _revMeta,
        rev.isAcceptableOrUnknown(data['rev']!, _revMeta),
      );
    }
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BmcCredentialRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BmcCredentialRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rev'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      user: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user'],
      )!,
      pwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pwd'],
      ),
    );
  }

  @override
  $BmcCredentialsTable createAlias(String alias) {
    return $BmcCredentialsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class BmcCredentialRow extends DataClass
    implements Insertable<BmcCredentialRow> {
  final int updatedAt;
  final int rev;
  final String id;
  final String name;
  final String user;
  final String? pwd;
  const BmcCredentialRow({
    required this.updatedAt,
    required this.rev,
    required this.id,
    required this.name,
    required this.user,
    this.pwd,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['rev'] = Variable<int>(rev);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['user'] = Variable<String>(user);
    if (!nullToAbsent || pwd != null) {
      map['pwd'] = Variable<String>(pwd);
    }
    return map;
  }

  BmcCredentialsCompanion toCompanion(bool nullToAbsent) {
    return BmcCredentialsCompanion(
      updatedAt: Value(updatedAt),
      rev: Value(rev),
      id: Value(id),
      name: Value(name),
      user: Value(user),
      pwd: pwd == null && nullToAbsent ? const Value.absent() : Value(pwd),
    );
  }

  factory BmcCredentialRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BmcCredentialRow(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rev: serializer.fromJson<int>(json['rev']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      user: serializer.fromJson<String>(json['user']),
      pwd: serializer.fromJson<String?>(json['pwd']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rev': serializer.toJson<int>(rev),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'user': serializer.toJson<String>(user),
      'pwd': serializer.toJson<String?>(pwd),
    };
  }

  BmcCredentialRow copyWith({
    int? updatedAt,
    int? rev,
    String? id,
    String? name,
    String? user,
    Value<String?> pwd = const Value.absent(),
  }) => BmcCredentialRow(
    updatedAt: updatedAt ?? this.updatedAt,
    rev: rev ?? this.rev,
    id: id ?? this.id,
    name: name ?? this.name,
    user: user ?? this.user,
    pwd: pwd.present ? pwd.value : this.pwd,
  );
  BmcCredentialRow copyWithCompanion(BmcCredentialsCompanion data) {
    return BmcCredentialRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rev: data.rev.present ? data.rev.value : this.rev,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      user: data.user.present ? data.user.value : this.user,
      pwd: data.pwd.present ? data.pwd.value : this.pwd,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BmcCredentialRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('rev: $rev, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('user: $user, ')
          ..write('pwd: $pwd')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(updatedAt, rev, id, name, user, pwd);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BmcCredentialRow &&
          other.updatedAt == this.updatedAt &&
          other.rev == this.rev &&
          other.id == this.id &&
          other.name == this.name &&
          other.user == this.user &&
          other.pwd == this.pwd);
}

class BmcCredentialsCompanion extends UpdateCompanion<BmcCredentialRow> {
  final Value<int> updatedAt;
  final Value<int> rev;
  final Value<String> id;
  final Value<String> name;
  final Value<String> user;
  final Value<String?> pwd;
  const BmcCredentialsCompanion({
    this.updatedAt = const Value.absent(),
    this.rev = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.user = const Value.absent(),
    this.pwd = const Value.absent(),
  });
  BmcCredentialsCompanion.insert({
    this.updatedAt = const Value.absent(),
    this.rev = const Value.absent(),
    required String id,
    required String name,
    required String user,
    this.pwd = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       user = Value(user);
  static Insertable<BmcCredentialRow> custom({
    Expression<int>? updatedAt,
    Expression<int>? rev,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? user,
    Expression<String>? pwd,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rev != null) 'rev': rev,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (user != null) 'user': user,
      if (pwd != null) 'pwd': pwd,
    });
  }

  BmcCredentialsCompanion copyWith({
    Value<int>? updatedAt,
    Value<int>? rev,
    Value<String>? id,
    Value<String>? name,
    Value<String>? user,
    Value<String?>? pwd,
  }) {
    return BmcCredentialsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      rev: rev ?? this.rev,
      id: id ?? this.id,
      name: name ?? this.name,
      user: user ?? this.user,
      pwd: pwd ?? this.pwd,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rev.present) {
      map['rev'] = Variable<int>(rev.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (user.present) {
      map['user'] = Variable<String>(user.value);
    }
    if (pwd.present) {
      map['pwd'] = Variable<String>(pwd.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BmcCredentialsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('rev: $rev, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('user: $user, ')
          ..write('pwd: $pwd')
          ..write(')'))
        .toString();
  }
}

class $ServersTable extends Servers with TableInfo<$ServersTable, ServerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _revMeta = const VerificationMeta('rev');
  @override
  late final GeneratedColumn<int> rev = GeneratedColumn<int>(
    'rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
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
  static const VerificationMeta _systemTypeMeta = const VerificationMeta(
    'systemType',
  );
  @override
  late final GeneratedColumn<String> systemType = GeneratedColumn<String>(
    'system_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sshIpMeta = const VerificationMeta('sshIp');
  @override
  late final GeneratedColumn<String> sshIp = GeneratedColumn<String>(
    'ssh_ip',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sshPortMeta = const VerificationMeta(
    'sshPort',
  );
  @override
  late final GeneratedColumn<int> sshPort = GeneratedColumn<int>(
    'ssh_port',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sshUserMeta = const VerificationMeta(
    'sshUser',
  );
  @override
  late final GeneratedColumn<String> sshUser = GeneratedColumn<String>(
    'ssh_user',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sshPwdMeta = const VerificationMeta('sshPwd');
  @override
  late final GeneratedColumn<String> sshPwd = GeneratedColumn<String>(
    'ssh_pwd',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sshKeyIdMeta = const VerificationMeta(
    'sshKeyId',
  );
  @override
  late final GeneratedColumn<String> sshKeyId = GeneratedColumn<String>(
    'ssh_key_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES private_key (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _sshKeyPathMeta = const VerificationMeta(
    'sshKeyPath',
  );
  @override
  late final GeneratedColumn<String> sshKeyPath = GeneratedColumn<String>(
    'ssh_key_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sshAlterUrlMeta = const VerificationMeta(
    'sshAlterUrl',
  );
  @override
  late final GeneratedColumn<String> sshAlterUrl = GeneratedColumn<String>(
    'ssh_alter_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sshProxyCommandMeta = const VerificationMeta(
    'sshProxyCommand',
  );
  @override
  late final GeneratedColumn<String> sshProxyCommand = GeneratedColumn<String>(
    'ssh_proxy_command',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monitorAddrMeta = const VerificationMeta(
    'monitorAddr',
  );
  @override
  late final GeneratedColumn<String> monitorAddr = GeneratedColumn<String>(
    'monitor_addr',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monitorUserMeta = const VerificationMeta(
    'monitorUser',
  );
  @override
  late final GeneratedColumn<String> monitorUser = GeneratedColumn<String>(
    'monitor_user',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monitorPwdMeta = const VerificationMeta(
    'monitorPwd',
  );
  @override
  late final GeneratedColumn<String> monitorPwd = GeneratedColumn<String>(
    'monitor_pwd',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monitorIgnoreCertMeta = const VerificationMeta(
    'monitorIgnoreCert',
  );
  @override
  late final GeneratedColumn<bool> monitorIgnoreCert = GeneratedColumn<bool>(
    'monitor_ignore_cert',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("monitor_ignore_cert" IN (0, 1))',
    ),
  );
  static const VerificationMeta _monitorAllowInsecureMeta =
      const VerificationMeta('monitorAllowInsecure');
  @override
  late final GeneratedColumn<bool> monitorAllowInsecure = GeneratedColumn<bool>(
    'monitor_allow_insecure',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("monitor_allow_insecure" IN (0, 1))',
    ),
  );
  static const VerificationMeta _wolMacMeta = const VerificationMeta('wolMac');
  @override
  late final GeneratedColumn<String> wolMac = GeneratedColumn<String>(
    'wol_mac',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wolIpMeta = const VerificationMeta('wolIp');
  @override
  late final GeneratedColumn<String> wolIp = GeneratedColumn<String>(
    'wol_ip',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wolPwdMeta = const VerificationMeta('wolPwd');
  @override
  late final GeneratedColumn<String> wolPwd = GeneratedColumn<String>(
    'wol_pwd',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bmcAddrMeta = const VerificationMeta(
    'bmcAddr',
  );
  @override
  late final GeneratedColumn<String> bmcAddr = GeneratedColumn<String>(
    'bmc_addr',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bmcCertSha256Meta = const VerificationMeta(
    'bmcCertSha256',
  );
  @override
  late final GeneratedColumn<String> bmcCertSha256 = GeneratedColumn<String>(
    'bmc_cert_sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bmcCredIdMeta = const VerificationMeta(
    'bmcCredId',
  );
  @override
  late final GeneratedColumn<String> bmcCredId = GeneratedColumn<String>(
    'bmc_cred_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES bmc_credential (id) ON DELETE SET NULL',
    ),
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
  static const VerificationMeta _pvePwdMeta = const VerificationMeta('pvePwd');
  @override
  late final GeneratedColumn<String> pvePwd = GeneratedColumn<String>(
    'pve_pwd',
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
  static const VerificationMeta _tempIsCelsiusMeta = const VerificationMeta(
    'tempIsCelsius',
  );
  @override
  late final GeneratedColumn<bool> tempIsCelsius = GeneratedColumn<bool>(
    'temp_is_celsius',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("temp_is_celsius" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    rev,
    id,
    name,
    autoConnect,
    systemType,
    sshIp,
    sshPort,
    sshUser,
    sshPwd,
    sshKeyId,
    sshKeyPath,
    sshAlterUrl,
    sshProxyCommand,
    monitorAddr,
    monitorUser,
    monitorPwd,
    monitorIgnoreCert,
    monitorAllowInsecure,
    wolMac,
    wolIp,
    wolPwd,
    bmcAddr,
    bmcCertSha256,
    bmcCredId,
    pveAddr,
    pveIgnoreCert,
    pvePwd,
    preferTempDev,
    tempIsCelsius,
    logoUrl,
    netDev,
    scriptDir,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('rev')) {
      context.handle(
        _revMeta,
        rev.isAcceptableOrUnknown(data['rev']!, _revMeta),
      );
    }
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
    if (data.containsKey('auto_connect')) {
      context.handle(
        _autoConnectMeta,
        autoConnect.isAcceptableOrUnknown(
          data['auto_connect']!,
          _autoConnectMeta,
        ),
      );
    }
    if (data.containsKey('system_type')) {
      context.handle(
        _systemTypeMeta,
        systemType.isAcceptableOrUnknown(data['system_type']!, _systemTypeMeta),
      );
    }
    if (data.containsKey('ssh_ip')) {
      context.handle(
        _sshIpMeta,
        sshIp.isAcceptableOrUnknown(data['ssh_ip']!, _sshIpMeta),
      );
    }
    if (data.containsKey('ssh_port')) {
      context.handle(
        _sshPortMeta,
        sshPort.isAcceptableOrUnknown(data['ssh_port']!, _sshPortMeta),
      );
    }
    if (data.containsKey('ssh_user')) {
      context.handle(
        _sshUserMeta,
        sshUser.isAcceptableOrUnknown(data['ssh_user']!, _sshUserMeta),
      );
    }
    if (data.containsKey('ssh_pwd')) {
      context.handle(
        _sshPwdMeta,
        sshPwd.isAcceptableOrUnknown(data['ssh_pwd']!, _sshPwdMeta),
      );
    }
    if (data.containsKey('ssh_key_id')) {
      context.handle(
        _sshKeyIdMeta,
        sshKeyId.isAcceptableOrUnknown(data['ssh_key_id']!, _sshKeyIdMeta),
      );
    }
    if (data.containsKey('ssh_key_path')) {
      context.handle(
        _sshKeyPathMeta,
        sshKeyPath.isAcceptableOrUnknown(
          data['ssh_key_path']!,
          _sshKeyPathMeta,
        ),
      );
    }
    if (data.containsKey('ssh_alter_url')) {
      context.handle(
        _sshAlterUrlMeta,
        sshAlterUrl.isAcceptableOrUnknown(
          data['ssh_alter_url']!,
          _sshAlterUrlMeta,
        ),
      );
    }
    if (data.containsKey('ssh_proxy_command')) {
      context.handle(
        _sshProxyCommandMeta,
        sshProxyCommand.isAcceptableOrUnknown(
          data['ssh_proxy_command']!,
          _sshProxyCommandMeta,
        ),
      );
    }
    if (data.containsKey('monitor_addr')) {
      context.handle(
        _monitorAddrMeta,
        monitorAddr.isAcceptableOrUnknown(
          data['monitor_addr']!,
          _monitorAddrMeta,
        ),
      );
    }
    if (data.containsKey('monitor_user')) {
      context.handle(
        _monitorUserMeta,
        monitorUser.isAcceptableOrUnknown(
          data['monitor_user']!,
          _monitorUserMeta,
        ),
      );
    }
    if (data.containsKey('monitor_pwd')) {
      context.handle(
        _monitorPwdMeta,
        monitorPwd.isAcceptableOrUnknown(data['monitor_pwd']!, _monitorPwdMeta),
      );
    }
    if (data.containsKey('monitor_ignore_cert')) {
      context.handle(
        _monitorIgnoreCertMeta,
        monitorIgnoreCert.isAcceptableOrUnknown(
          data['monitor_ignore_cert']!,
          _monitorIgnoreCertMeta,
        ),
      );
    }
    if (data.containsKey('monitor_allow_insecure')) {
      context.handle(
        _monitorAllowInsecureMeta,
        monitorAllowInsecure.isAcceptableOrUnknown(
          data['monitor_allow_insecure']!,
          _monitorAllowInsecureMeta,
        ),
      );
    }
    if (data.containsKey('wol_mac')) {
      context.handle(
        _wolMacMeta,
        wolMac.isAcceptableOrUnknown(data['wol_mac']!, _wolMacMeta),
      );
    }
    if (data.containsKey('wol_ip')) {
      context.handle(
        _wolIpMeta,
        wolIp.isAcceptableOrUnknown(data['wol_ip']!, _wolIpMeta),
      );
    }
    if (data.containsKey('wol_pwd')) {
      context.handle(
        _wolPwdMeta,
        wolPwd.isAcceptableOrUnknown(data['wol_pwd']!, _wolPwdMeta),
      );
    }
    if (data.containsKey('bmc_addr')) {
      context.handle(
        _bmcAddrMeta,
        bmcAddr.isAcceptableOrUnknown(data['bmc_addr']!, _bmcAddrMeta),
      );
    }
    if (data.containsKey('bmc_cert_sha256')) {
      context.handle(
        _bmcCertSha256Meta,
        bmcCertSha256.isAcceptableOrUnknown(
          data['bmc_cert_sha256']!,
          _bmcCertSha256Meta,
        ),
      );
    }
    if (data.containsKey('bmc_cred_id')) {
      context.handle(
        _bmcCredIdMeta,
        bmcCredId.isAcceptableOrUnknown(data['bmc_cred_id']!, _bmcCredIdMeta),
      );
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
    if (data.containsKey('pve_pwd')) {
      context.handle(
        _pvePwdMeta,
        pvePwd.isAcceptableOrUnknown(data['pve_pwd']!, _pvePwdMeta),
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
    if (data.containsKey('temp_is_celsius')) {
      context.handle(
        _tempIsCelsiusMeta,
        tempIsCelsius.isAcceptableOrUnknown(
          data['temp_is_celsius']!,
          _tempIsCelsiusMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rev'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      autoConnect: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_connect'],
      )!,
      systemType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}system_type'],
      ),
      sshIp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ssh_ip'],
      ),
      sshPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ssh_port'],
      ),
      sshUser: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ssh_user'],
      ),
      sshPwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ssh_pwd'],
      ),
      sshKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ssh_key_id'],
      ),
      sshKeyPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ssh_key_path'],
      ),
      sshAlterUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ssh_alter_url'],
      ),
      sshProxyCommand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ssh_proxy_command'],
      ),
      monitorAddr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}monitor_addr'],
      ),
      monitorUser: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}monitor_user'],
      ),
      monitorPwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}monitor_pwd'],
      ),
      monitorIgnoreCert: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}monitor_ignore_cert'],
      ),
      monitorAllowInsecure: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}monitor_allow_insecure'],
      ),
      wolMac: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wol_mac'],
      ),
      wolIp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wol_ip'],
      ),
      wolPwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wol_pwd'],
      ),
      bmcAddr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bmc_addr'],
      ),
      bmcCertSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bmc_cert_sha256'],
      ),
      bmcCredId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bmc_cred_id'],
      ),
      pveAddr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pve_addr'],
      ),
      pveIgnoreCert: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pve_ignore_cert'],
      )!,
      pvePwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pve_pwd'],
      ),
      preferTempDev: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prefer_temp_dev'],
      ),
      tempIsCelsius: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}temp_is_celsius'],
      )!,
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
    );
  }

  @override
  $ServersTable createAlias(String alias) {
    return $ServersTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class ServerRow extends DataClass implements Insertable<ServerRow> {
  final int updatedAt;
  final int rev;
  final String id;
  final String name;
  final bool autoConnect;
  final String? systemType;
  final String? sshIp;
  final int? sshPort;
  final String? sshUser;
  final String? sshPwd;

  /// Deleting a key must not delete the servers that used it; it must leave
  /// them asking for a new one.
  final String? sshKeyId;
  final String? sshKeyPath;
  final String? sshAlterUrl;
  final String? sshProxyCommand;
  final String? monitorAddr;
  final String? monitorUser;
  final String? monitorPwd;
  final bool? monitorIgnoreCert;
  final bool? monitorAllowInsecure;
  final String? wolMac;
  final String? wolIp;
  final String? wolPwd;

  /// The BMC, a side channel beside the Wake-on-LAN fields above.
  ///
  /// Deliberately outside the SSH/monitor constraint below: a BMC is not a way
  /// of reaching the host, so it neither satisfies that requirement nor
  /// conflicts with either side of it. A server may carry one alongside SSH or
  /// alongside a monitor agent.
  ///
  /// [bmcCertSha256] is what the user reviewed, not what a CA said — see
  /// `BmcCfg.certSha256`. Null means nothing has been reviewed and a
  /// connection is refused rather than trusted.
  final String? bmcAddr;
  final String? bmcCertSha256;

  /// Deleting an account must not delete the servers that used it; it must
  /// leave them with an address and nothing to log in with, which the editor
  /// can then say. Same rule as [sshKeyId].
  final String? bmcCredId;
  final String? pveAddr;
  final bool pveIgnoreCert;
  final String? pvePwd;
  final String? preferTempDev;
  final bool tempIsCelsius;
  final String? logoUrl;
  final String? netDev;
  final String? scriptDir;
  const ServerRow({
    required this.updatedAt,
    required this.rev,
    required this.id,
    required this.name,
    required this.autoConnect,
    this.systemType,
    this.sshIp,
    this.sshPort,
    this.sshUser,
    this.sshPwd,
    this.sshKeyId,
    this.sshKeyPath,
    this.sshAlterUrl,
    this.sshProxyCommand,
    this.monitorAddr,
    this.monitorUser,
    this.monitorPwd,
    this.monitorIgnoreCert,
    this.monitorAllowInsecure,
    this.wolMac,
    this.wolIp,
    this.wolPwd,
    this.bmcAddr,
    this.bmcCertSha256,
    this.bmcCredId,
    this.pveAddr,
    required this.pveIgnoreCert,
    this.pvePwd,
    this.preferTempDev,
    required this.tempIsCelsius,
    this.logoUrl,
    this.netDev,
    this.scriptDir,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['rev'] = Variable<int>(rev);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['auto_connect'] = Variable<bool>(autoConnect);
    if (!nullToAbsent || systemType != null) {
      map['system_type'] = Variable<String>(systemType);
    }
    if (!nullToAbsent || sshIp != null) {
      map['ssh_ip'] = Variable<String>(sshIp);
    }
    if (!nullToAbsent || sshPort != null) {
      map['ssh_port'] = Variable<int>(sshPort);
    }
    if (!nullToAbsent || sshUser != null) {
      map['ssh_user'] = Variable<String>(sshUser);
    }
    if (!nullToAbsent || sshPwd != null) {
      map['ssh_pwd'] = Variable<String>(sshPwd);
    }
    if (!nullToAbsent || sshKeyId != null) {
      map['ssh_key_id'] = Variable<String>(sshKeyId);
    }
    if (!nullToAbsent || sshKeyPath != null) {
      map['ssh_key_path'] = Variable<String>(sshKeyPath);
    }
    if (!nullToAbsent || sshAlterUrl != null) {
      map['ssh_alter_url'] = Variable<String>(sshAlterUrl);
    }
    if (!nullToAbsent || sshProxyCommand != null) {
      map['ssh_proxy_command'] = Variable<String>(sshProxyCommand);
    }
    if (!nullToAbsent || monitorAddr != null) {
      map['monitor_addr'] = Variable<String>(monitorAddr);
    }
    if (!nullToAbsent || monitorUser != null) {
      map['monitor_user'] = Variable<String>(monitorUser);
    }
    if (!nullToAbsent || monitorPwd != null) {
      map['monitor_pwd'] = Variable<String>(monitorPwd);
    }
    if (!nullToAbsent || monitorIgnoreCert != null) {
      map['monitor_ignore_cert'] = Variable<bool>(monitorIgnoreCert);
    }
    if (!nullToAbsent || monitorAllowInsecure != null) {
      map['monitor_allow_insecure'] = Variable<bool>(monitorAllowInsecure);
    }
    if (!nullToAbsent || wolMac != null) {
      map['wol_mac'] = Variable<String>(wolMac);
    }
    if (!nullToAbsent || wolIp != null) {
      map['wol_ip'] = Variable<String>(wolIp);
    }
    if (!nullToAbsent || wolPwd != null) {
      map['wol_pwd'] = Variable<String>(wolPwd);
    }
    if (!nullToAbsent || bmcAddr != null) {
      map['bmc_addr'] = Variable<String>(bmcAddr);
    }
    if (!nullToAbsent || bmcCertSha256 != null) {
      map['bmc_cert_sha256'] = Variable<String>(bmcCertSha256);
    }
    if (!nullToAbsent || bmcCredId != null) {
      map['bmc_cred_id'] = Variable<String>(bmcCredId);
    }
    if (!nullToAbsent || pveAddr != null) {
      map['pve_addr'] = Variable<String>(pveAddr);
    }
    map['pve_ignore_cert'] = Variable<bool>(pveIgnoreCert);
    if (!nullToAbsent || pvePwd != null) {
      map['pve_pwd'] = Variable<String>(pvePwd);
    }
    if (!nullToAbsent || preferTempDev != null) {
      map['prefer_temp_dev'] = Variable<String>(preferTempDev);
    }
    map['temp_is_celsius'] = Variable<bool>(tempIsCelsius);
    if (!nullToAbsent || logoUrl != null) {
      map['logo_url'] = Variable<String>(logoUrl);
    }
    if (!nullToAbsent || netDev != null) {
      map['net_dev'] = Variable<String>(netDev);
    }
    if (!nullToAbsent || scriptDir != null) {
      map['script_dir'] = Variable<String>(scriptDir);
    }
    return map;
  }

  ServersCompanion toCompanion(bool nullToAbsent) {
    return ServersCompanion(
      updatedAt: Value(updatedAt),
      rev: Value(rev),
      id: Value(id),
      name: Value(name),
      autoConnect: Value(autoConnect),
      systemType: systemType == null && nullToAbsent
          ? const Value.absent()
          : Value(systemType),
      sshIp: sshIp == null && nullToAbsent
          ? const Value.absent()
          : Value(sshIp),
      sshPort: sshPort == null && nullToAbsent
          ? const Value.absent()
          : Value(sshPort),
      sshUser: sshUser == null && nullToAbsent
          ? const Value.absent()
          : Value(sshUser),
      sshPwd: sshPwd == null && nullToAbsent
          ? const Value.absent()
          : Value(sshPwd),
      sshKeyId: sshKeyId == null && nullToAbsent
          ? const Value.absent()
          : Value(sshKeyId),
      sshKeyPath: sshKeyPath == null && nullToAbsent
          ? const Value.absent()
          : Value(sshKeyPath),
      sshAlterUrl: sshAlterUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sshAlterUrl),
      sshProxyCommand: sshProxyCommand == null && nullToAbsent
          ? const Value.absent()
          : Value(sshProxyCommand),
      monitorAddr: monitorAddr == null && nullToAbsent
          ? const Value.absent()
          : Value(monitorAddr),
      monitorUser: monitorUser == null && nullToAbsent
          ? const Value.absent()
          : Value(monitorUser),
      monitorPwd: monitorPwd == null && nullToAbsent
          ? const Value.absent()
          : Value(monitorPwd),
      monitorIgnoreCert: monitorIgnoreCert == null && nullToAbsent
          ? const Value.absent()
          : Value(monitorIgnoreCert),
      monitorAllowInsecure: monitorAllowInsecure == null && nullToAbsent
          ? const Value.absent()
          : Value(monitorAllowInsecure),
      wolMac: wolMac == null && nullToAbsent
          ? const Value.absent()
          : Value(wolMac),
      wolIp: wolIp == null && nullToAbsent
          ? const Value.absent()
          : Value(wolIp),
      wolPwd: wolPwd == null && nullToAbsent
          ? const Value.absent()
          : Value(wolPwd),
      bmcAddr: bmcAddr == null && nullToAbsent
          ? const Value.absent()
          : Value(bmcAddr),
      bmcCertSha256: bmcCertSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(bmcCertSha256),
      bmcCredId: bmcCredId == null && nullToAbsent
          ? const Value.absent()
          : Value(bmcCredId),
      pveAddr: pveAddr == null && nullToAbsent
          ? const Value.absent()
          : Value(pveAddr),
      pveIgnoreCert: Value(pveIgnoreCert),
      pvePwd: pvePwd == null && nullToAbsent
          ? const Value.absent()
          : Value(pvePwd),
      preferTempDev: preferTempDev == null && nullToAbsent
          ? const Value.absent()
          : Value(preferTempDev),
      tempIsCelsius: Value(tempIsCelsius),
      logoUrl: logoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(logoUrl),
      netDev: netDev == null && nullToAbsent
          ? const Value.absent()
          : Value(netDev),
      scriptDir: scriptDir == null && nullToAbsent
          ? const Value.absent()
          : Value(scriptDir),
    );
  }

  factory ServerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerRow(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rev: serializer.fromJson<int>(json['rev']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      autoConnect: serializer.fromJson<bool>(json['autoConnect']),
      systemType: serializer.fromJson<String?>(json['systemType']),
      sshIp: serializer.fromJson<String?>(json['sshIp']),
      sshPort: serializer.fromJson<int?>(json['sshPort']),
      sshUser: serializer.fromJson<String?>(json['sshUser']),
      sshPwd: serializer.fromJson<String?>(json['sshPwd']),
      sshKeyId: serializer.fromJson<String?>(json['sshKeyId']),
      sshKeyPath: serializer.fromJson<String?>(json['sshKeyPath']),
      sshAlterUrl: serializer.fromJson<String?>(json['sshAlterUrl']),
      sshProxyCommand: serializer.fromJson<String?>(json['sshProxyCommand']),
      monitorAddr: serializer.fromJson<String?>(json['monitorAddr']),
      monitorUser: serializer.fromJson<String?>(json['monitorUser']),
      monitorPwd: serializer.fromJson<String?>(json['monitorPwd']),
      monitorIgnoreCert: serializer.fromJson<bool?>(json['monitorIgnoreCert']),
      monitorAllowInsecure: serializer.fromJson<bool?>(
        json['monitorAllowInsecure'],
      ),
      wolMac: serializer.fromJson<String?>(json['wolMac']),
      wolIp: serializer.fromJson<String?>(json['wolIp']),
      wolPwd: serializer.fromJson<String?>(json['wolPwd']),
      bmcAddr: serializer.fromJson<String?>(json['bmcAddr']),
      bmcCertSha256: serializer.fromJson<String?>(json['bmcCertSha256']),
      bmcCredId: serializer.fromJson<String?>(json['bmcCredId']),
      pveAddr: serializer.fromJson<String?>(json['pveAddr']),
      pveIgnoreCert: serializer.fromJson<bool>(json['pveIgnoreCert']),
      pvePwd: serializer.fromJson<String?>(json['pvePwd']),
      preferTempDev: serializer.fromJson<String?>(json['preferTempDev']),
      tempIsCelsius: serializer.fromJson<bool>(json['tempIsCelsius']),
      logoUrl: serializer.fromJson<String?>(json['logoUrl']),
      netDev: serializer.fromJson<String?>(json['netDev']),
      scriptDir: serializer.fromJson<String?>(json['scriptDir']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rev': serializer.toJson<int>(rev),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'autoConnect': serializer.toJson<bool>(autoConnect),
      'systemType': serializer.toJson<String?>(systemType),
      'sshIp': serializer.toJson<String?>(sshIp),
      'sshPort': serializer.toJson<int?>(sshPort),
      'sshUser': serializer.toJson<String?>(sshUser),
      'sshPwd': serializer.toJson<String?>(sshPwd),
      'sshKeyId': serializer.toJson<String?>(sshKeyId),
      'sshKeyPath': serializer.toJson<String?>(sshKeyPath),
      'sshAlterUrl': serializer.toJson<String?>(sshAlterUrl),
      'sshProxyCommand': serializer.toJson<String?>(sshProxyCommand),
      'monitorAddr': serializer.toJson<String?>(monitorAddr),
      'monitorUser': serializer.toJson<String?>(monitorUser),
      'monitorPwd': serializer.toJson<String?>(monitorPwd),
      'monitorIgnoreCert': serializer.toJson<bool?>(monitorIgnoreCert),
      'monitorAllowInsecure': serializer.toJson<bool?>(monitorAllowInsecure),
      'wolMac': serializer.toJson<String?>(wolMac),
      'wolIp': serializer.toJson<String?>(wolIp),
      'wolPwd': serializer.toJson<String?>(wolPwd),
      'bmcAddr': serializer.toJson<String?>(bmcAddr),
      'bmcCertSha256': serializer.toJson<String?>(bmcCertSha256),
      'bmcCredId': serializer.toJson<String?>(bmcCredId),
      'pveAddr': serializer.toJson<String?>(pveAddr),
      'pveIgnoreCert': serializer.toJson<bool>(pveIgnoreCert),
      'pvePwd': serializer.toJson<String?>(pvePwd),
      'preferTempDev': serializer.toJson<String?>(preferTempDev),
      'tempIsCelsius': serializer.toJson<bool>(tempIsCelsius),
      'logoUrl': serializer.toJson<String?>(logoUrl),
      'netDev': serializer.toJson<String?>(netDev),
      'scriptDir': serializer.toJson<String?>(scriptDir),
    };
  }

  ServerRow copyWith({
    int? updatedAt,
    int? rev,
    String? id,
    String? name,
    bool? autoConnect,
    Value<String?> systemType = const Value.absent(),
    Value<String?> sshIp = const Value.absent(),
    Value<int?> sshPort = const Value.absent(),
    Value<String?> sshUser = const Value.absent(),
    Value<String?> sshPwd = const Value.absent(),
    Value<String?> sshKeyId = const Value.absent(),
    Value<String?> sshKeyPath = const Value.absent(),
    Value<String?> sshAlterUrl = const Value.absent(),
    Value<String?> sshProxyCommand = const Value.absent(),
    Value<String?> monitorAddr = const Value.absent(),
    Value<String?> monitorUser = const Value.absent(),
    Value<String?> monitorPwd = const Value.absent(),
    Value<bool?> monitorIgnoreCert = const Value.absent(),
    Value<bool?> monitorAllowInsecure = const Value.absent(),
    Value<String?> wolMac = const Value.absent(),
    Value<String?> wolIp = const Value.absent(),
    Value<String?> wolPwd = const Value.absent(),
    Value<String?> bmcAddr = const Value.absent(),
    Value<String?> bmcCertSha256 = const Value.absent(),
    Value<String?> bmcCredId = const Value.absent(),
    Value<String?> pveAddr = const Value.absent(),
    bool? pveIgnoreCert,
    Value<String?> pvePwd = const Value.absent(),
    Value<String?> preferTempDev = const Value.absent(),
    bool? tempIsCelsius,
    Value<String?> logoUrl = const Value.absent(),
    Value<String?> netDev = const Value.absent(),
    Value<String?> scriptDir = const Value.absent(),
  }) => ServerRow(
    updatedAt: updatedAt ?? this.updatedAt,
    rev: rev ?? this.rev,
    id: id ?? this.id,
    name: name ?? this.name,
    autoConnect: autoConnect ?? this.autoConnect,
    systemType: systemType.present ? systemType.value : this.systemType,
    sshIp: sshIp.present ? sshIp.value : this.sshIp,
    sshPort: sshPort.present ? sshPort.value : this.sshPort,
    sshUser: sshUser.present ? sshUser.value : this.sshUser,
    sshPwd: sshPwd.present ? sshPwd.value : this.sshPwd,
    sshKeyId: sshKeyId.present ? sshKeyId.value : this.sshKeyId,
    sshKeyPath: sshKeyPath.present ? sshKeyPath.value : this.sshKeyPath,
    sshAlterUrl: sshAlterUrl.present ? sshAlterUrl.value : this.sshAlterUrl,
    sshProxyCommand: sshProxyCommand.present
        ? sshProxyCommand.value
        : this.sshProxyCommand,
    monitorAddr: monitorAddr.present ? monitorAddr.value : this.monitorAddr,
    monitorUser: monitorUser.present ? monitorUser.value : this.monitorUser,
    monitorPwd: monitorPwd.present ? monitorPwd.value : this.monitorPwd,
    monitorIgnoreCert: monitorIgnoreCert.present
        ? monitorIgnoreCert.value
        : this.monitorIgnoreCert,
    monitorAllowInsecure: monitorAllowInsecure.present
        ? monitorAllowInsecure.value
        : this.monitorAllowInsecure,
    wolMac: wolMac.present ? wolMac.value : this.wolMac,
    wolIp: wolIp.present ? wolIp.value : this.wolIp,
    wolPwd: wolPwd.present ? wolPwd.value : this.wolPwd,
    bmcAddr: bmcAddr.present ? bmcAddr.value : this.bmcAddr,
    bmcCertSha256: bmcCertSha256.present
        ? bmcCertSha256.value
        : this.bmcCertSha256,
    bmcCredId: bmcCredId.present ? bmcCredId.value : this.bmcCredId,
    pveAddr: pveAddr.present ? pveAddr.value : this.pveAddr,
    pveIgnoreCert: pveIgnoreCert ?? this.pveIgnoreCert,
    pvePwd: pvePwd.present ? pvePwd.value : this.pvePwd,
    preferTempDev: preferTempDev.present
        ? preferTempDev.value
        : this.preferTempDev,
    tempIsCelsius: tempIsCelsius ?? this.tempIsCelsius,
    logoUrl: logoUrl.present ? logoUrl.value : this.logoUrl,
    netDev: netDev.present ? netDev.value : this.netDev,
    scriptDir: scriptDir.present ? scriptDir.value : this.scriptDir,
  );
  ServerRow copyWithCompanion(ServersCompanion data) {
    return ServerRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rev: data.rev.present ? data.rev.value : this.rev,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      autoConnect: data.autoConnect.present
          ? data.autoConnect.value
          : this.autoConnect,
      systemType: data.systemType.present
          ? data.systemType.value
          : this.systemType,
      sshIp: data.sshIp.present ? data.sshIp.value : this.sshIp,
      sshPort: data.sshPort.present ? data.sshPort.value : this.sshPort,
      sshUser: data.sshUser.present ? data.sshUser.value : this.sshUser,
      sshPwd: data.sshPwd.present ? data.sshPwd.value : this.sshPwd,
      sshKeyId: data.sshKeyId.present ? data.sshKeyId.value : this.sshKeyId,
      sshKeyPath: data.sshKeyPath.present
          ? data.sshKeyPath.value
          : this.sshKeyPath,
      sshAlterUrl: data.sshAlterUrl.present
          ? data.sshAlterUrl.value
          : this.sshAlterUrl,
      sshProxyCommand: data.sshProxyCommand.present
          ? data.sshProxyCommand.value
          : this.sshProxyCommand,
      monitorAddr: data.monitorAddr.present
          ? data.monitorAddr.value
          : this.monitorAddr,
      monitorUser: data.monitorUser.present
          ? data.monitorUser.value
          : this.monitorUser,
      monitorPwd: data.monitorPwd.present
          ? data.monitorPwd.value
          : this.monitorPwd,
      monitorIgnoreCert: data.monitorIgnoreCert.present
          ? data.monitorIgnoreCert.value
          : this.monitorIgnoreCert,
      monitorAllowInsecure: data.monitorAllowInsecure.present
          ? data.monitorAllowInsecure.value
          : this.monitorAllowInsecure,
      wolMac: data.wolMac.present ? data.wolMac.value : this.wolMac,
      wolIp: data.wolIp.present ? data.wolIp.value : this.wolIp,
      wolPwd: data.wolPwd.present ? data.wolPwd.value : this.wolPwd,
      bmcAddr: data.bmcAddr.present ? data.bmcAddr.value : this.bmcAddr,
      bmcCertSha256: data.bmcCertSha256.present
          ? data.bmcCertSha256.value
          : this.bmcCertSha256,
      bmcCredId: data.bmcCredId.present ? data.bmcCredId.value : this.bmcCredId,
      pveAddr: data.pveAddr.present ? data.pveAddr.value : this.pveAddr,
      pveIgnoreCert: data.pveIgnoreCert.present
          ? data.pveIgnoreCert.value
          : this.pveIgnoreCert,
      pvePwd: data.pvePwd.present ? data.pvePwd.value : this.pvePwd,
      preferTempDev: data.preferTempDev.present
          ? data.preferTempDev.value
          : this.preferTempDev,
      tempIsCelsius: data.tempIsCelsius.present
          ? data.tempIsCelsius.value
          : this.tempIsCelsius,
      logoUrl: data.logoUrl.present ? data.logoUrl.value : this.logoUrl,
      netDev: data.netDev.present ? data.netDev.value : this.netDev,
      scriptDir: data.scriptDir.present ? data.scriptDir.value : this.scriptDir,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('rev: $rev, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('autoConnect: $autoConnect, ')
          ..write('systemType: $systemType, ')
          ..write('sshIp: $sshIp, ')
          ..write('sshPort: $sshPort, ')
          ..write('sshUser: $sshUser, ')
          ..write('sshPwd: $sshPwd, ')
          ..write('sshKeyId: $sshKeyId, ')
          ..write('sshKeyPath: $sshKeyPath, ')
          ..write('sshAlterUrl: $sshAlterUrl, ')
          ..write('sshProxyCommand: $sshProxyCommand, ')
          ..write('monitorAddr: $monitorAddr, ')
          ..write('monitorUser: $monitorUser, ')
          ..write('monitorPwd: $monitorPwd, ')
          ..write('monitorIgnoreCert: $monitorIgnoreCert, ')
          ..write('monitorAllowInsecure: $monitorAllowInsecure, ')
          ..write('wolMac: $wolMac, ')
          ..write('wolIp: $wolIp, ')
          ..write('wolPwd: $wolPwd, ')
          ..write('bmcAddr: $bmcAddr, ')
          ..write('bmcCertSha256: $bmcCertSha256, ')
          ..write('bmcCredId: $bmcCredId, ')
          ..write('pveAddr: $pveAddr, ')
          ..write('pveIgnoreCert: $pveIgnoreCert, ')
          ..write('pvePwd: $pvePwd, ')
          ..write('preferTempDev: $preferTempDev, ')
          ..write('tempIsCelsius: $tempIsCelsius, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('netDev: $netDev, ')
          ..write('scriptDir: $scriptDir')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    updatedAt,
    rev,
    id,
    name,
    autoConnect,
    systemType,
    sshIp,
    sshPort,
    sshUser,
    sshPwd,
    sshKeyId,
    sshKeyPath,
    sshAlterUrl,
    sshProxyCommand,
    monitorAddr,
    monitorUser,
    monitorPwd,
    monitorIgnoreCert,
    monitorAllowInsecure,
    wolMac,
    wolIp,
    wolPwd,
    bmcAddr,
    bmcCertSha256,
    bmcCredId,
    pveAddr,
    pveIgnoreCert,
    pvePwd,
    preferTempDev,
    tempIsCelsius,
    logoUrl,
    netDev,
    scriptDir,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerRow &&
          other.updatedAt == this.updatedAt &&
          other.rev == this.rev &&
          other.id == this.id &&
          other.name == this.name &&
          other.autoConnect == this.autoConnect &&
          other.systemType == this.systemType &&
          other.sshIp == this.sshIp &&
          other.sshPort == this.sshPort &&
          other.sshUser == this.sshUser &&
          other.sshPwd == this.sshPwd &&
          other.sshKeyId == this.sshKeyId &&
          other.sshKeyPath == this.sshKeyPath &&
          other.sshAlterUrl == this.sshAlterUrl &&
          other.sshProxyCommand == this.sshProxyCommand &&
          other.monitorAddr == this.monitorAddr &&
          other.monitorUser == this.monitorUser &&
          other.monitorPwd == this.monitorPwd &&
          other.monitorIgnoreCert == this.monitorIgnoreCert &&
          other.monitorAllowInsecure == this.monitorAllowInsecure &&
          other.wolMac == this.wolMac &&
          other.wolIp == this.wolIp &&
          other.wolPwd == this.wolPwd &&
          other.bmcAddr == this.bmcAddr &&
          other.bmcCertSha256 == this.bmcCertSha256 &&
          other.bmcCredId == this.bmcCredId &&
          other.pveAddr == this.pveAddr &&
          other.pveIgnoreCert == this.pveIgnoreCert &&
          other.pvePwd == this.pvePwd &&
          other.preferTempDev == this.preferTempDev &&
          other.tempIsCelsius == this.tempIsCelsius &&
          other.logoUrl == this.logoUrl &&
          other.netDev == this.netDev &&
          other.scriptDir == this.scriptDir);
}

class ServersCompanion extends UpdateCompanion<ServerRow> {
  final Value<int> updatedAt;
  final Value<int> rev;
  final Value<String> id;
  final Value<String> name;
  final Value<bool> autoConnect;
  final Value<String?> systemType;
  final Value<String?> sshIp;
  final Value<int?> sshPort;
  final Value<String?> sshUser;
  final Value<String?> sshPwd;
  final Value<String?> sshKeyId;
  final Value<String?> sshKeyPath;
  final Value<String?> sshAlterUrl;
  final Value<String?> sshProxyCommand;
  final Value<String?> monitorAddr;
  final Value<String?> monitorUser;
  final Value<String?> monitorPwd;
  final Value<bool?> monitorIgnoreCert;
  final Value<bool?> monitorAllowInsecure;
  final Value<String?> wolMac;
  final Value<String?> wolIp;
  final Value<String?> wolPwd;
  final Value<String?> bmcAddr;
  final Value<String?> bmcCertSha256;
  final Value<String?> bmcCredId;
  final Value<String?> pveAddr;
  final Value<bool> pveIgnoreCert;
  final Value<String?> pvePwd;
  final Value<String?> preferTempDev;
  final Value<bool> tempIsCelsius;
  final Value<String?> logoUrl;
  final Value<String?> netDev;
  final Value<String?> scriptDir;
  const ServersCompanion({
    this.updatedAt = const Value.absent(),
    this.rev = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.autoConnect = const Value.absent(),
    this.systemType = const Value.absent(),
    this.sshIp = const Value.absent(),
    this.sshPort = const Value.absent(),
    this.sshUser = const Value.absent(),
    this.sshPwd = const Value.absent(),
    this.sshKeyId = const Value.absent(),
    this.sshKeyPath = const Value.absent(),
    this.sshAlterUrl = const Value.absent(),
    this.sshProxyCommand = const Value.absent(),
    this.monitorAddr = const Value.absent(),
    this.monitorUser = const Value.absent(),
    this.monitorPwd = const Value.absent(),
    this.monitorIgnoreCert = const Value.absent(),
    this.monitorAllowInsecure = const Value.absent(),
    this.wolMac = const Value.absent(),
    this.wolIp = const Value.absent(),
    this.wolPwd = const Value.absent(),
    this.bmcAddr = const Value.absent(),
    this.bmcCertSha256 = const Value.absent(),
    this.bmcCredId = const Value.absent(),
    this.pveAddr = const Value.absent(),
    this.pveIgnoreCert = const Value.absent(),
    this.pvePwd = const Value.absent(),
    this.preferTempDev = const Value.absent(),
    this.tempIsCelsius = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.netDev = const Value.absent(),
    this.scriptDir = const Value.absent(),
  });
  ServersCompanion.insert({
    this.updatedAt = const Value.absent(),
    this.rev = const Value.absent(),
    required String id,
    required String name,
    this.autoConnect = const Value.absent(),
    this.systemType = const Value.absent(),
    this.sshIp = const Value.absent(),
    this.sshPort = const Value.absent(),
    this.sshUser = const Value.absent(),
    this.sshPwd = const Value.absent(),
    this.sshKeyId = const Value.absent(),
    this.sshKeyPath = const Value.absent(),
    this.sshAlterUrl = const Value.absent(),
    this.sshProxyCommand = const Value.absent(),
    this.monitorAddr = const Value.absent(),
    this.monitorUser = const Value.absent(),
    this.monitorPwd = const Value.absent(),
    this.monitorIgnoreCert = const Value.absent(),
    this.monitorAllowInsecure = const Value.absent(),
    this.wolMac = const Value.absent(),
    this.wolIp = const Value.absent(),
    this.wolPwd = const Value.absent(),
    this.bmcAddr = const Value.absent(),
    this.bmcCertSha256 = const Value.absent(),
    this.bmcCredId = const Value.absent(),
    this.pveAddr = const Value.absent(),
    this.pveIgnoreCert = const Value.absent(),
    this.pvePwd = const Value.absent(),
    this.preferTempDev = const Value.absent(),
    this.tempIsCelsius = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.netDev = const Value.absent(),
    this.scriptDir = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<ServerRow> custom({
    Expression<int>? updatedAt,
    Expression<int>? rev,
    Expression<String>? id,
    Expression<String>? name,
    Expression<bool>? autoConnect,
    Expression<String>? systemType,
    Expression<String>? sshIp,
    Expression<int>? sshPort,
    Expression<String>? sshUser,
    Expression<String>? sshPwd,
    Expression<String>? sshKeyId,
    Expression<String>? sshKeyPath,
    Expression<String>? sshAlterUrl,
    Expression<String>? sshProxyCommand,
    Expression<String>? monitorAddr,
    Expression<String>? monitorUser,
    Expression<String>? monitorPwd,
    Expression<bool>? monitorIgnoreCert,
    Expression<bool>? monitorAllowInsecure,
    Expression<String>? wolMac,
    Expression<String>? wolIp,
    Expression<String>? wolPwd,
    Expression<String>? bmcAddr,
    Expression<String>? bmcCertSha256,
    Expression<String>? bmcCredId,
    Expression<String>? pveAddr,
    Expression<bool>? pveIgnoreCert,
    Expression<String>? pvePwd,
    Expression<String>? preferTempDev,
    Expression<bool>? tempIsCelsius,
    Expression<String>? logoUrl,
    Expression<String>? netDev,
    Expression<String>? scriptDir,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rev != null) 'rev': rev,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (autoConnect != null) 'auto_connect': autoConnect,
      if (systemType != null) 'system_type': systemType,
      if (sshIp != null) 'ssh_ip': sshIp,
      if (sshPort != null) 'ssh_port': sshPort,
      if (sshUser != null) 'ssh_user': sshUser,
      if (sshPwd != null) 'ssh_pwd': sshPwd,
      if (sshKeyId != null) 'ssh_key_id': sshKeyId,
      if (sshKeyPath != null) 'ssh_key_path': sshKeyPath,
      if (sshAlterUrl != null) 'ssh_alter_url': sshAlterUrl,
      if (sshProxyCommand != null) 'ssh_proxy_command': sshProxyCommand,
      if (monitorAddr != null) 'monitor_addr': monitorAddr,
      if (monitorUser != null) 'monitor_user': monitorUser,
      if (monitorPwd != null) 'monitor_pwd': monitorPwd,
      if (monitorIgnoreCert != null) 'monitor_ignore_cert': monitorIgnoreCert,
      if (monitorAllowInsecure != null)
        'monitor_allow_insecure': monitorAllowInsecure,
      if (wolMac != null) 'wol_mac': wolMac,
      if (wolIp != null) 'wol_ip': wolIp,
      if (wolPwd != null) 'wol_pwd': wolPwd,
      if (bmcAddr != null) 'bmc_addr': bmcAddr,
      if (bmcCertSha256 != null) 'bmc_cert_sha256': bmcCertSha256,
      if (bmcCredId != null) 'bmc_cred_id': bmcCredId,
      if (pveAddr != null) 'pve_addr': pveAddr,
      if (pveIgnoreCert != null) 'pve_ignore_cert': pveIgnoreCert,
      if (pvePwd != null) 'pve_pwd': pvePwd,
      if (preferTempDev != null) 'prefer_temp_dev': preferTempDev,
      if (tempIsCelsius != null) 'temp_is_celsius': tempIsCelsius,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (netDev != null) 'net_dev': netDev,
      if (scriptDir != null) 'script_dir': scriptDir,
    });
  }

  ServersCompanion copyWith({
    Value<int>? updatedAt,
    Value<int>? rev,
    Value<String>? id,
    Value<String>? name,
    Value<bool>? autoConnect,
    Value<String?>? systemType,
    Value<String?>? sshIp,
    Value<int?>? sshPort,
    Value<String?>? sshUser,
    Value<String?>? sshPwd,
    Value<String?>? sshKeyId,
    Value<String?>? sshKeyPath,
    Value<String?>? sshAlterUrl,
    Value<String?>? sshProxyCommand,
    Value<String?>? monitorAddr,
    Value<String?>? monitorUser,
    Value<String?>? monitorPwd,
    Value<bool?>? monitorIgnoreCert,
    Value<bool?>? monitorAllowInsecure,
    Value<String?>? wolMac,
    Value<String?>? wolIp,
    Value<String?>? wolPwd,
    Value<String?>? bmcAddr,
    Value<String?>? bmcCertSha256,
    Value<String?>? bmcCredId,
    Value<String?>? pveAddr,
    Value<bool>? pveIgnoreCert,
    Value<String?>? pvePwd,
    Value<String?>? preferTempDev,
    Value<bool>? tempIsCelsius,
    Value<String?>? logoUrl,
    Value<String?>? netDev,
    Value<String?>? scriptDir,
  }) {
    return ServersCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      rev: rev ?? this.rev,
      id: id ?? this.id,
      name: name ?? this.name,
      autoConnect: autoConnect ?? this.autoConnect,
      systemType: systemType ?? this.systemType,
      sshIp: sshIp ?? this.sshIp,
      sshPort: sshPort ?? this.sshPort,
      sshUser: sshUser ?? this.sshUser,
      sshPwd: sshPwd ?? this.sshPwd,
      sshKeyId: sshKeyId ?? this.sshKeyId,
      sshKeyPath: sshKeyPath ?? this.sshKeyPath,
      sshAlterUrl: sshAlterUrl ?? this.sshAlterUrl,
      sshProxyCommand: sshProxyCommand ?? this.sshProxyCommand,
      monitorAddr: monitorAddr ?? this.monitorAddr,
      monitorUser: monitorUser ?? this.monitorUser,
      monitorPwd: monitorPwd ?? this.monitorPwd,
      monitorIgnoreCert: monitorIgnoreCert ?? this.monitorIgnoreCert,
      monitorAllowInsecure: monitorAllowInsecure ?? this.monitorAllowInsecure,
      wolMac: wolMac ?? this.wolMac,
      wolIp: wolIp ?? this.wolIp,
      wolPwd: wolPwd ?? this.wolPwd,
      bmcAddr: bmcAddr ?? this.bmcAddr,
      bmcCertSha256: bmcCertSha256 ?? this.bmcCertSha256,
      bmcCredId: bmcCredId ?? this.bmcCredId,
      pveAddr: pveAddr ?? this.pveAddr,
      pveIgnoreCert: pveIgnoreCert ?? this.pveIgnoreCert,
      pvePwd: pvePwd ?? this.pvePwd,
      preferTempDev: preferTempDev ?? this.preferTempDev,
      tempIsCelsius: tempIsCelsius ?? this.tempIsCelsius,
      logoUrl: logoUrl ?? this.logoUrl,
      netDev: netDev ?? this.netDev,
      scriptDir: scriptDir ?? this.scriptDir,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rev.present) {
      map['rev'] = Variable<int>(rev.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (autoConnect.present) {
      map['auto_connect'] = Variable<bool>(autoConnect.value);
    }
    if (systemType.present) {
      map['system_type'] = Variable<String>(systemType.value);
    }
    if (sshIp.present) {
      map['ssh_ip'] = Variable<String>(sshIp.value);
    }
    if (sshPort.present) {
      map['ssh_port'] = Variable<int>(sshPort.value);
    }
    if (sshUser.present) {
      map['ssh_user'] = Variable<String>(sshUser.value);
    }
    if (sshPwd.present) {
      map['ssh_pwd'] = Variable<String>(sshPwd.value);
    }
    if (sshKeyId.present) {
      map['ssh_key_id'] = Variable<String>(sshKeyId.value);
    }
    if (sshKeyPath.present) {
      map['ssh_key_path'] = Variable<String>(sshKeyPath.value);
    }
    if (sshAlterUrl.present) {
      map['ssh_alter_url'] = Variable<String>(sshAlterUrl.value);
    }
    if (sshProxyCommand.present) {
      map['ssh_proxy_command'] = Variable<String>(sshProxyCommand.value);
    }
    if (monitorAddr.present) {
      map['monitor_addr'] = Variable<String>(monitorAddr.value);
    }
    if (monitorUser.present) {
      map['monitor_user'] = Variable<String>(monitorUser.value);
    }
    if (monitorPwd.present) {
      map['monitor_pwd'] = Variable<String>(monitorPwd.value);
    }
    if (monitorIgnoreCert.present) {
      map['monitor_ignore_cert'] = Variable<bool>(monitorIgnoreCert.value);
    }
    if (monitorAllowInsecure.present) {
      map['monitor_allow_insecure'] = Variable<bool>(
        monitorAllowInsecure.value,
      );
    }
    if (wolMac.present) {
      map['wol_mac'] = Variable<String>(wolMac.value);
    }
    if (wolIp.present) {
      map['wol_ip'] = Variable<String>(wolIp.value);
    }
    if (wolPwd.present) {
      map['wol_pwd'] = Variable<String>(wolPwd.value);
    }
    if (bmcAddr.present) {
      map['bmc_addr'] = Variable<String>(bmcAddr.value);
    }
    if (bmcCertSha256.present) {
      map['bmc_cert_sha256'] = Variable<String>(bmcCertSha256.value);
    }
    if (bmcCredId.present) {
      map['bmc_cred_id'] = Variable<String>(bmcCredId.value);
    }
    if (pveAddr.present) {
      map['pve_addr'] = Variable<String>(pveAddr.value);
    }
    if (pveIgnoreCert.present) {
      map['pve_ignore_cert'] = Variable<bool>(pveIgnoreCert.value);
    }
    if (pvePwd.present) {
      map['pve_pwd'] = Variable<String>(pvePwd.value);
    }
    if (preferTempDev.present) {
      map['prefer_temp_dev'] = Variable<String>(preferTempDev.value);
    }
    if (tempIsCelsius.present) {
      map['temp_is_celsius'] = Variable<bool>(tempIsCelsius.value);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServersCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('rev: $rev, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('autoConnect: $autoConnect, ')
          ..write('systemType: $systemType, ')
          ..write('sshIp: $sshIp, ')
          ..write('sshPort: $sshPort, ')
          ..write('sshUser: $sshUser, ')
          ..write('sshPwd: $sshPwd, ')
          ..write('sshKeyId: $sshKeyId, ')
          ..write('sshKeyPath: $sshKeyPath, ')
          ..write('sshAlterUrl: $sshAlterUrl, ')
          ..write('sshProxyCommand: $sshProxyCommand, ')
          ..write('monitorAddr: $monitorAddr, ')
          ..write('monitorUser: $monitorUser, ')
          ..write('monitorPwd: $monitorPwd, ')
          ..write('monitorIgnoreCert: $monitorIgnoreCert, ')
          ..write('monitorAllowInsecure: $monitorAllowInsecure, ')
          ..write('wolMac: $wolMac, ')
          ..write('wolIp: $wolIp, ')
          ..write('wolPwd: $wolPwd, ')
          ..write('bmcAddr: $bmcAddr, ')
          ..write('bmcCertSha256: $bmcCertSha256, ')
          ..write('bmcCredId: $bmcCredId, ')
          ..write('pveAddr: $pveAddr, ')
          ..write('pveIgnoreCert: $pveIgnoreCert, ')
          ..write('pvePwd: $pvePwd, ')
          ..write('preferTempDev: $preferTempDev, ')
          ..write('tempIsCelsius: $tempIsCelsius, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('netDev: $netDev, ')
          ..write('scriptDir: $scriptDir')
          ..write(')'))
        .toString();
  }
}

class $ServerTagsTable extends ServerTags
    with TableInfo<$ServerTagsTable, ServerTagRow> {
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES server (id) ON DELETE CASCADE',
    ),
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
  static const String $name = 'server_tag';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerTagRow> instance, {
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
  ServerTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerTagRow(
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

  @override
  bool get withoutRowId => true;
}

class ServerTagRow extends DataClass implements Insertable<ServerTagRow> {
  final String serverId;
  final String tag;
  const ServerTagRow({required this.serverId, required this.tag});
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

  factory ServerTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerTagRow(
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

  ServerTagRow copyWith({String? serverId, String? tag}) =>
      ServerTagRow(serverId: serverId ?? this.serverId, tag: tag ?? this.tag);
  ServerTagRow copyWithCompanion(ServerTagsCompanion data) {
    return ServerTagRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerTagRow(')
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
      (other is ServerTagRow &&
          other.serverId == this.serverId &&
          other.tag == this.tag);
}

class ServerTagsCompanion extends UpdateCompanion<ServerTagRow> {
  final Value<String> serverId;
  final Value<String> tag;
  const ServerTagsCompanion({
    this.serverId = const Value.absent(),
    this.tag = const Value.absent(),
  });
  ServerTagsCompanion.insert({required String serverId, required String tag})
    : serverId = Value(serverId),
      tag = Value(tag);
  static Insertable<ServerTagRow> custom({
    Expression<String>? serverId,
    Expression<String>? tag,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (tag != null) 'tag': tag,
    });
  }

  ServerTagsCompanion copyWith({Value<String>? serverId, Value<String>? tag}) {
    return ServerTagsCompanion(
      serverId: serverId ?? this.serverId,
      tag: tag ?? this.tag,
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerTagsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }
}

class $ServerEnvsTable extends ServerEnvs
    with TableInfo<$ServerEnvsTable, ServerEnvRow> {
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES server (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [serverId, key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server_env';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerEnvRow> instance, {
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
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, key};
  @override
  ServerEnvRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerEnvRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $ServerEnvsTable createAlias(String alias) {
    return $ServerEnvsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class ServerEnvRow extends DataClass implements Insertable<ServerEnvRow> {
  final String serverId;
  final String key;
  final String value;
  const ServerEnvRow({
    required this.serverId,
    required this.key,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  ServerEnvsCompanion toCompanion(bool nullToAbsent) {
    return ServerEnvsCompanion(
      serverId: Value(serverId),
      key: Value(key),
      value: Value(value),
    );
  }

  factory ServerEnvRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerEnvRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  ServerEnvRow copyWith({String? serverId, String? key, String? value}) =>
      ServerEnvRow(
        serverId: serverId ?? this.serverId,
        key: key ?? this.key,
        value: value ?? this.value,
      );
  ServerEnvRow copyWithCompanion(ServerEnvsCompanion data) {
    return ServerEnvRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerEnvRow(')
          ..write('serverId: $serverId, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerEnvRow &&
          other.serverId == this.serverId &&
          other.key == this.key &&
          other.value == this.value);
}

class ServerEnvsCompanion extends UpdateCompanion<ServerEnvRow> {
  final Value<String> serverId;
  final Value<String> key;
  final Value<String> value;
  const ServerEnvsCompanion({
    this.serverId = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
  });
  ServerEnvsCompanion.insert({
    required String serverId,
    required String key,
    required String value,
  }) : serverId = Value(serverId),
       key = Value(key),
       value = Value(value);
  static Insertable<ServerEnvRow> custom({
    Expression<String>? serverId,
    Expression<String>? key,
    Expression<String>? value,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
    });
  }

  ServerEnvsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? key,
    Value<String>? value,
  }) {
    return ServerEnvsCompanion(
      serverId: serverId ?? this.serverId,
      key: key ?? this.key,
      value: value ?? this.value,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerEnvsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }
}

class $ServerJumpsTable extends ServerJumps
    with TableInfo<$ServerJumpsTable, ServerJumpRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServerJumpsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES server (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ordMeta = const VerificationMeta('ord');
  @override
  late final GeneratedColumn<int> ord = GeneratedColumn<int>(
    'ord',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jumpIdMeta = const VerificationMeta('jumpId');
  @override
  late final GeneratedColumn<String> jumpId = GeneratedColumn<String>(
    'jump_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES server (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [serverId, ord, jumpId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server_jump';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerJumpRow> instance, {
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
    if (data.containsKey('ord')) {
      context.handle(
        _ordMeta,
        ord.isAcceptableOrUnknown(data['ord']!, _ordMeta),
      );
    } else if (isInserting) {
      context.missing(_ordMeta);
    }
    if (data.containsKey('jump_id')) {
      context.handle(
        _jumpIdMeta,
        jumpId.isAcceptableOrUnknown(data['jump_id']!, _jumpIdMeta),
      );
    } else if (isInserting) {
      context.missing(_jumpIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, ord};
  @override
  ServerJumpRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerJumpRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      ord: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ord'],
      )!,
      jumpId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jump_id'],
      )!,
    );
  }

  @override
  $ServerJumpsTable createAlias(String alias) {
    return $ServerJumpsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class ServerJumpRow extends DataClass implements Insertable<ServerJumpRow> {
  final String serverId;
  final int ord;
  final String jumpId;
  const ServerJumpRow({
    required this.serverId,
    required this.ord,
    required this.jumpId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['ord'] = Variable<int>(ord);
    map['jump_id'] = Variable<String>(jumpId);
    return map;
  }

  ServerJumpsCompanion toCompanion(bool nullToAbsent) {
    return ServerJumpsCompanion(
      serverId: Value(serverId),
      ord: Value(ord),
      jumpId: Value(jumpId),
    );
  }

  factory ServerJumpRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerJumpRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      ord: serializer.fromJson<int>(json['ord']),
      jumpId: serializer.fromJson<String>(json['jumpId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'ord': serializer.toJson<int>(ord),
      'jumpId': serializer.toJson<String>(jumpId),
    };
  }

  ServerJumpRow copyWith({String? serverId, int? ord, String? jumpId}) =>
      ServerJumpRow(
        serverId: serverId ?? this.serverId,
        ord: ord ?? this.ord,
        jumpId: jumpId ?? this.jumpId,
      );
  ServerJumpRow copyWithCompanion(ServerJumpsCompanion data) {
    return ServerJumpRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      ord: data.ord.present ? data.ord.value : this.ord,
      jumpId: data.jumpId.present ? data.jumpId.value : this.jumpId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerJumpRow(')
          ..write('serverId: $serverId, ')
          ..write('ord: $ord, ')
          ..write('jumpId: $jumpId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, ord, jumpId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerJumpRow &&
          other.serverId == this.serverId &&
          other.ord == this.ord &&
          other.jumpId == this.jumpId);
}

class ServerJumpsCompanion extends UpdateCompanion<ServerJumpRow> {
  final Value<String> serverId;
  final Value<int> ord;
  final Value<String> jumpId;
  const ServerJumpsCompanion({
    this.serverId = const Value.absent(),
    this.ord = const Value.absent(),
    this.jumpId = const Value.absent(),
  });
  ServerJumpsCompanion.insert({
    required String serverId,
    required int ord,
    required String jumpId,
  }) : serverId = Value(serverId),
       ord = Value(ord),
       jumpId = Value(jumpId);
  static Insertable<ServerJumpRow> custom({
    Expression<String>? serverId,
    Expression<int>? ord,
    Expression<String>? jumpId,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (ord != null) 'ord': ord,
      if (jumpId != null) 'jump_id': jumpId,
    });
  }

  ServerJumpsCompanion copyWith({
    Value<String>? serverId,
    Value<int>? ord,
    Value<String>? jumpId,
  }) {
    return ServerJumpsCompanion(
      serverId: serverId ?? this.serverId,
      ord: ord ?? this.ord,
      jumpId: jumpId ?? this.jumpId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (ord.present) {
      map['ord'] = Variable<int>(ord.value);
    }
    if (jumpId.present) {
      map['jump_id'] = Variable<String>(jumpId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerJumpsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('ord: $ord, ')
          ..write('jumpId: $jumpId')
          ..write(')'))
        .toString();
  }
}

class $ServerDisabledCmdsTable extends ServerDisabledCmds
    with TableInfo<$ServerDisabledCmdsTable, ServerDisabledCmdRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServerDisabledCmdsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES server (id) ON DELETE CASCADE',
    ),
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
  static const String $name = 'server_disabled_cmd';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerDisabledCmdRow> instance, {
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
  ServerDisabledCmdRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerDisabledCmdRow(
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
  $ServerDisabledCmdsTable createAlias(String alias) {
    return $ServerDisabledCmdsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class ServerDisabledCmdRow extends DataClass
    implements Insertable<ServerDisabledCmdRow> {
  final String serverId;
  final String cmdType;
  const ServerDisabledCmdRow({required this.serverId, required this.cmdType});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['cmd_type'] = Variable<String>(cmdType);
    return map;
  }

  ServerDisabledCmdsCompanion toCompanion(bool nullToAbsent) {
    return ServerDisabledCmdsCompanion(
      serverId: Value(serverId),
      cmdType: Value(cmdType),
    );
  }

  factory ServerDisabledCmdRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerDisabledCmdRow(
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

  ServerDisabledCmdRow copyWith({String? serverId, String? cmdType}) =>
      ServerDisabledCmdRow(
        serverId: serverId ?? this.serverId,
        cmdType: cmdType ?? this.cmdType,
      );
  ServerDisabledCmdRow copyWithCompanion(ServerDisabledCmdsCompanion data) {
    return ServerDisabledCmdRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      cmdType: data.cmdType.present ? data.cmdType.value : this.cmdType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerDisabledCmdRow(')
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
      (other is ServerDisabledCmdRow &&
          other.serverId == this.serverId &&
          other.cmdType == this.cmdType);
}

class ServerDisabledCmdsCompanion
    extends UpdateCompanion<ServerDisabledCmdRow> {
  final Value<String> serverId;
  final Value<String> cmdType;
  const ServerDisabledCmdsCompanion({
    this.serverId = const Value.absent(),
    this.cmdType = const Value.absent(),
  });
  ServerDisabledCmdsCompanion.insert({
    required String serverId,
    required String cmdType,
  }) : serverId = Value(serverId),
       cmdType = Value(cmdType);
  static Insertable<ServerDisabledCmdRow> custom({
    Expression<String>? serverId,
    Expression<String>? cmdType,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (cmdType != null) 'cmd_type': cmdType,
    });
  }

  ServerDisabledCmdsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? cmdType,
  }) {
    return ServerDisabledCmdsCompanion(
      serverId: serverId ?? this.serverId,
      cmdType: cmdType ?? this.cmdType,
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerDisabledCmdsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('cmdType: $cmdType')
          ..write(')'))
        .toString();
  }
}

class $ServerCustomCmdsTable extends ServerCustomCmds
    with TableInfo<$ServerCustomCmdsTable, ServerCustomCmdRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServerCustomCmdsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES server (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _cmdMeta = const VerificationMeta('cmd');
  @override
  late final GeneratedColumn<String> cmd = GeneratedColumn<String>(
    'cmd',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [serverId, name, cmd];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server_custom_cmd';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerCustomCmdRow> instance, {
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('cmd')) {
      context.handle(
        _cmdMeta,
        cmd.isAcceptableOrUnknown(data['cmd']!, _cmdMeta),
      );
    } else if (isInserting) {
      context.missing(_cmdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, name};
  @override
  ServerCustomCmdRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerCustomCmdRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      cmd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cmd'],
      )!,
    );
  }

  @override
  $ServerCustomCmdsTable createAlias(String alias) {
    return $ServerCustomCmdsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class ServerCustomCmdRow extends DataClass
    implements Insertable<ServerCustomCmdRow> {
  final String serverId;
  final String name;
  final String cmd;
  const ServerCustomCmdRow({
    required this.serverId,
    required this.name,
    required this.cmd,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['name'] = Variable<String>(name);
    map['cmd'] = Variable<String>(cmd);
    return map;
  }

  ServerCustomCmdsCompanion toCompanion(bool nullToAbsent) {
    return ServerCustomCmdsCompanion(
      serverId: Value(serverId),
      name: Value(name),
      cmd: Value(cmd),
    );
  }

  factory ServerCustomCmdRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerCustomCmdRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      name: serializer.fromJson<String>(json['name']),
      cmd: serializer.fromJson<String>(json['cmd']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'name': serializer.toJson<String>(name),
      'cmd': serializer.toJson<String>(cmd),
    };
  }

  ServerCustomCmdRow copyWith({String? serverId, String? name, String? cmd}) =>
      ServerCustomCmdRow(
        serverId: serverId ?? this.serverId,
        name: name ?? this.name,
        cmd: cmd ?? this.cmd,
      );
  ServerCustomCmdRow copyWithCompanion(ServerCustomCmdsCompanion data) {
    return ServerCustomCmdRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      name: data.name.present ? data.name.value : this.name,
      cmd: data.cmd.present ? data.cmd.value : this.cmd,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerCustomCmdRow(')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('cmd: $cmd')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, name, cmd);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerCustomCmdRow &&
          other.serverId == this.serverId &&
          other.name == this.name &&
          other.cmd == this.cmd);
}

class ServerCustomCmdsCompanion extends UpdateCompanion<ServerCustomCmdRow> {
  final Value<String> serverId;
  final Value<String> name;
  final Value<String> cmd;
  const ServerCustomCmdsCompanion({
    this.serverId = const Value.absent(),
    this.name = const Value.absent(),
    this.cmd = const Value.absent(),
  });
  ServerCustomCmdsCompanion.insert({
    required String serverId,
    required String name,
    required String cmd,
  }) : serverId = Value(serverId),
       name = Value(name),
       cmd = Value(cmd);
  static Insertable<ServerCustomCmdRow> custom({
    Expression<String>? serverId,
    Expression<String>? name,
    Expression<String>? cmd,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (name != null) 'name': name,
      if (cmd != null) 'cmd': cmd,
    });
  }

  ServerCustomCmdsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? name,
    Value<String>? cmd,
  }) {
    return ServerCustomCmdsCompanion(
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      cmd: cmd ?? this.cmd,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (cmd.present) {
      map['cmd'] = Variable<String>(cmd.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerCustomCmdsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('cmd: $cmd')
          ..write(')'))
        .toString();
  }
}

class $KnownHostsTable extends KnownHosts
    with TableInfo<$KnownHostsTable, KnownHostRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KnownHostsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES server (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _keyTypeMeta = const VerificationMeta(
    'keyType',
  );
  @override
  late final GeneratedColumn<String> keyType = GeneratedColumn<String>(
    'key_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [serverId, keyType, fingerprint];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'known_host';
  @override
  VerificationContext validateIntegrity(
    Insertable<KnownHostRow> instance, {
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
    if (data.containsKey('key_type')) {
      context.handle(
        _keyTypeMeta,
        keyType.isAcceptableOrUnknown(data['key_type']!, _keyTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_keyTypeMeta);
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, keyType};
  @override
  KnownHostRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KnownHostRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      keyType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_type'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      )!,
    );
  }

  @override
  $KnownHostsTable createAlias(String alias) {
    return $KnownHostsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class KnownHostRow extends DataClass implements Insertable<KnownHostRow> {
  final String serverId;
  final String keyType;
  final String fingerprint;
  const KnownHostRow({
    required this.serverId,
    required this.keyType,
    required this.fingerprint,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['key_type'] = Variable<String>(keyType);
    map['fingerprint'] = Variable<String>(fingerprint);
    return map;
  }

  KnownHostsCompanion toCompanion(bool nullToAbsent) {
    return KnownHostsCompanion(
      serverId: Value(serverId),
      keyType: Value(keyType),
      fingerprint: Value(fingerprint),
    );
  }

  factory KnownHostRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KnownHostRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      keyType: serializer.fromJson<String>(json['keyType']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'keyType': serializer.toJson<String>(keyType),
      'fingerprint': serializer.toJson<String>(fingerprint),
    };
  }

  KnownHostRow copyWith({
    String? serverId,
    String? keyType,
    String? fingerprint,
  }) => KnownHostRow(
    serverId: serverId ?? this.serverId,
    keyType: keyType ?? this.keyType,
    fingerprint: fingerprint ?? this.fingerprint,
  );
  KnownHostRow copyWithCompanion(KnownHostsCompanion data) {
    return KnownHostRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      keyType: data.keyType.present ? data.keyType.value : this.keyType,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KnownHostRow(')
          ..write('serverId: $serverId, ')
          ..write('keyType: $keyType, ')
          ..write('fingerprint: $fingerprint')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, keyType, fingerprint);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KnownHostRow &&
          other.serverId == this.serverId &&
          other.keyType == this.keyType &&
          other.fingerprint == this.fingerprint);
}

class KnownHostsCompanion extends UpdateCompanion<KnownHostRow> {
  final Value<String> serverId;
  final Value<String> keyType;
  final Value<String> fingerprint;
  const KnownHostsCompanion({
    this.serverId = const Value.absent(),
    this.keyType = const Value.absent(),
    this.fingerprint = const Value.absent(),
  });
  KnownHostsCompanion.insert({
    required String serverId,
    required String keyType,
    required String fingerprint,
  }) : serverId = Value(serverId),
       keyType = Value(keyType),
       fingerprint = Value(fingerprint);
  static Insertable<KnownHostRow> custom({
    Expression<String>? serverId,
    Expression<String>? keyType,
    Expression<String>? fingerprint,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (keyType != null) 'key_type': keyType,
      if (fingerprint != null) 'fingerprint': fingerprint,
    });
  }

  KnownHostsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? keyType,
    Value<String>? fingerprint,
  }) {
    return KnownHostsCompanion(
      serverId: serverId ?? this.serverId,
      keyType: keyType ?? this.keyType,
      fingerprint: fingerprint ?? this.fingerprint,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (keyType.present) {
      map['key_type'] = Variable<String>(keyType.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KnownHostsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('keyType: $keyType, ')
          ..write('fingerprint: $fingerprint')
          ..write(')'))
        .toString();
  }
}

class $SnippetsTable extends Snippets
    with TableInfo<$SnippetsTable, SnippetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnippetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _revMeta = const VerificationMeta('rev');
  @override
  late final GeneratedColumn<int> rev = GeneratedColumn<int>(
    'rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    rev,
    id,
    name,
    script,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snippet';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnippetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('rev')) {
      context.handle(
        _revMeta,
        rev.isAcceptableOrUnknown(data['rev']!, _revMeta),
      );
    }
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SnippetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnippetRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rev'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
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
    );
  }

  @override
  $SnippetsTable createAlias(String alias) {
    return $SnippetsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class SnippetRow extends DataClass implements Insertable<SnippetRow> {
  final int updatedAt;
  final int rev;
  final String id;
  final String name;
  final String script;
  final String? note;
  const SnippetRow({
    required this.updatedAt,
    required this.rev,
    required this.id,
    required this.name,
    required this.script,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['rev'] = Variable<int>(rev);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['script'] = Variable<String>(script);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  SnippetsCompanion toCompanion(bool nullToAbsent) {
    return SnippetsCompanion(
      updatedAt: Value(updatedAt),
      rev: Value(rev),
      id: Value(id),
      name: Value(name),
      script: Value(script),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory SnippetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnippetRow(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rev: serializer.fromJson<int>(json['rev']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      script: serializer.fromJson<String>(json['script']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rev': serializer.toJson<int>(rev),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'script': serializer.toJson<String>(script),
      'note': serializer.toJson<String?>(note),
    };
  }

  SnippetRow copyWith({
    int? updatedAt,
    int? rev,
    String? id,
    String? name,
    String? script,
    Value<String?> note = const Value.absent(),
  }) => SnippetRow(
    updatedAt: updatedAt ?? this.updatedAt,
    rev: rev ?? this.rev,
    id: id ?? this.id,
    name: name ?? this.name,
    script: script ?? this.script,
    note: note.present ? note.value : this.note,
  );
  SnippetRow copyWithCompanion(SnippetsCompanion data) {
    return SnippetRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rev: data.rev.present ? data.rev.value : this.rev,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      script: data.script.present ? data.script.value : this.script,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnippetRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('rev: $rev, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('script: $script, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(updatedAt, rev, id, name, script, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnippetRow &&
          other.updatedAt == this.updatedAt &&
          other.rev == this.rev &&
          other.id == this.id &&
          other.name == this.name &&
          other.script == this.script &&
          other.note == this.note);
}

class SnippetsCompanion extends UpdateCompanion<SnippetRow> {
  final Value<int> updatedAt;
  final Value<int> rev;
  final Value<String> id;
  final Value<String> name;
  final Value<String> script;
  final Value<String?> note;
  const SnippetsCompanion({
    this.updatedAt = const Value.absent(),
    this.rev = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.script = const Value.absent(),
    this.note = const Value.absent(),
  });
  SnippetsCompanion.insert({
    this.updatedAt = const Value.absent(),
    this.rev = const Value.absent(),
    required String id,
    required String name,
    required String script,
    this.note = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       script = Value(script);
  static Insertable<SnippetRow> custom({
    Expression<int>? updatedAt,
    Expression<int>? rev,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? script,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rev != null) 'rev': rev,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (script != null) 'script': script,
      if (note != null) 'note': note,
    });
  }

  SnippetsCompanion copyWith({
    Value<int>? updatedAt,
    Value<int>? rev,
    Value<String>? id,
    Value<String>? name,
    Value<String>? script,
    Value<String?>? note,
  }) {
    return SnippetsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      rev: rev ?? this.rev,
      id: id ?? this.id,
      name: name ?? this.name,
      script: script ?? this.script,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rev.present) {
      map['rev'] = Variable<int>(rev.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (script.present) {
      map['script'] = Variable<String>(script.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnippetsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('rev: $rev, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('script: $script, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $SnippetTagsTable extends SnippetTags
    with TableInfo<$SnippetTagsTable, SnippetTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnippetTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _snippetIdMeta = const VerificationMeta(
    'snippetId',
  );
  @override
  late final GeneratedColumn<String> snippetId = GeneratedColumn<String>(
    'snippet_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES snippet (id) ON DELETE CASCADE',
    ),
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
  List<GeneratedColumn> get $columns => [snippetId, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snippet_tag';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnippetTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('snippet_id')) {
      context.handle(
        _snippetIdMeta,
        snippetId.isAcceptableOrUnknown(data['snippet_id']!, _snippetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_snippetIdMeta);
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
  Set<GeneratedColumn> get $primaryKey => {snippetId, tag};
  @override
  SnippetTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnippetTagRow(
      snippetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snippet_id'],
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

  @override
  bool get withoutRowId => true;
}

class SnippetTagRow extends DataClass implements Insertable<SnippetTagRow> {
  final String snippetId;
  final String tag;
  const SnippetTagRow({required this.snippetId, required this.tag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['snippet_id'] = Variable<String>(snippetId);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  SnippetTagsCompanion toCompanion(bool nullToAbsent) {
    return SnippetTagsCompanion(snippetId: Value(snippetId), tag: Value(tag));
  }

  factory SnippetTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnippetTagRow(
      snippetId: serializer.fromJson<String>(json['snippetId']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'snippetId': serializer.toJson<String>(snippetId),
      'tag': serializer.toJson<String>(tag),
    };
  }

  SnippetTagRow copyWith({String? snippetId, String? tag}) => SnippetTagRow(
    snippetId: snippetId ?? this.snippetId,
    tag: tag ?? this.tag,
  );
  SnippetTagRow copyWithCompanion(SnippetTagsCompanion data) {
    return SnippetTagRow(
      snippetId: data.snippetId.present ? data.snippetId.value : this.snippetId,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnippetTagRow(')
          ..write('snippetId: $snippetId, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(snippetId, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnippetTagRow &&
          other.snippetId == this.snippetId &&
          other.tag == this.tag);
}

class SnippetTagsCompanion extends UpdateCompanion<SnippetTagRow> {
  final Value<String> snippetId;
  final Value<String> tag;
  const SnippetTagsCompanion({
    this.snippetId = const Value.absent(),
    this.tag = const Value.absent(),
  });
  SnippetTagsCompanion.insert({required String snippetId, required String tag})
    : snippetId = Value(snippetId),
      tag = Value(tag);
  static Insertable<SnippetTagRow> custom({
    Expression<String>? snippetId,
    Expression<String>? tag,
  }) {
    return RawValuesInsertable({
      if (snippetId != null) 'snippet_id': snippetId,
      if (tag != null) 'tag': tag,
    });
  }

  SnippetTagsCompanion copyWith({
    Value<String>? snippetId,
    Value<String>? tag,
  }) {
    return SnippetTagsCompanion(
      snippetId: snippetId ?? this.snippetId,
      tag: tag ?? this.tag,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (snippetId.present) {
      map['snippet_id'] = Variable<String>(snippetId.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnippetTagsCompanion(')
          ..write('snippetId: $snippetId, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }
}

class $SnippetAutoRunOnTable extends SnippetAutoRunOn
    with TableInfo<$SnippetAutoRunOnTable, SnippetAutoRunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnippetAutoRunOnTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _snippetIdMeta = const VerificationMeta(
    'snippetId',
  );
  @override
  late final GeneratedColumn<String> snippetId = GeneratedColumn<String>(
    'snippet_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES snippet (id) ON DELETE CASCADE',
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES server (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [snippetId, serverId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snippet_auto_run_on';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnippetAutoRunRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('snippet_id')) {
      context.handle(
        _snippetIdMeta,
        snippetId.isAcceptableOrUnknown(data['snippet_id']!, _snippetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_snippetIdMeta);
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
  Set<GeneratedColumn> get $primaryKey => {snippetId, serverId};
  @override
  SnippetAutoRunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnippetAutoRunRow(
      snippetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snippet_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
    );
  }

  @override
  $SnippetAutoRunOnTable createAlias(String alias) {
    return $SnippetAutoRunOnTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class SnippetAutoRunRow extends DataClass
    implements Insertable<SnippetAutoRunRow> {
  final String snippetId;
  final String serverId;
  const SnippetAutoRunRow({required this.snippetId, required this.serverId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['snippet_id'] = Variable<String>(snippetId);
    map['server_id'] = Variable<String>(serverId);
    return map;
  }

  SnippetAutoRunOnCompanion toCompanion(bool nullToAbsent) {
    return SnippetAutoRunOnCompanion(
      snippetId: Value(snippetId),
      serverId: Value(serverId),
    );
  }

  factory SnippetAutoRunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnippetAutoRunRow(
      snippetId: serializer.fromJson<String>(json['snippetId']),
      serverId: serializer.fromJson<String>(json['serverId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'snippetId': serializer.toJson<String>(snippetId),
      'serverId': serializer.toJson<String>(serverId),
    };
  }

  SnippetAutoRunRow copyWith({String? snippetId, String? serverId}) =>
      SnippetAutoRunRow(
        snippetId: snippetId ?? this.snippetId,
        serverId: serverId ?? this.serverId,
      );
  SnippetAutoRunRow copyWithCompanion(SnippetAutoRunOnCompanion data) {
    return SnippetAutoRunRow(
      snippetId: data.snippetId.present ? data.snippetId.value : this.snippetId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnippetAutoRunRow(')
          ..write('snippetId: $snippetId, ')
          ..write('serverId: $serverId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(snippetId, serverId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnippetAutoRunRow &&
          other.snippetId == this.snippetId &&
          other.serverId == this.serverId);
}

class SnippetAutoRunOnCompanion extends UpdateCompanion<SnippetAutoRunRow> {
  final Value<String> snippetId;
  final Value<String> serverId;
  const SnippetAutoRunOnCompanion({
    this.snippetId = const Value.absent(),
    this.serverId = const Value.absent(),
  });
  SnippetAutoRunOnCompanion.insert({
    required String snippetId,
    required String serverId,
  }) : snippetId = Value(snippetId),
       serverId = Value(serverId);
  static Insertable<SnippetAutoRunRow> custom({
    Expression<String>? snippetId,
    Expression<String>? serverId,
  }) {
    return RawValuesInsertable({
      if (snippetId != null) 'snippet_id': snippetId,
      if (serverId != null) 'server_id': serverId,
    });
  }

  SnippetAutoRunOnCompanion copyWith({
    Value<String>? snippetId,
    Value<String>? serverId,
  }) {
    return SnippetAutoRunOnCompanion(
      snippetId: snippetId ?? this.snippetId,
      serverId: serverId ?? this.serverId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (snippetId.present) {
      map['snippet_id'] = Variable<String>(snippetId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnippetAutoRunOnCompanion(')
          ..write('snippetId: $snippetId, ')
          ..write('serverId: $serverId')
          ..write(')'))
        .toString();
  }
}

class $PortForwardsTable extends PortForwards
    with TableInfo<$PortForwardsTable, PortForwardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PortForwardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _revMeta = const VerificationMeta('rev');
  @override
  late final GeneratedColumn<int> rev = GeneratedColumn<int>(
    'rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES server (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localHostMeta = const VerificationMeta(
    'localHost',
  );
  @override
  late final GeneratedColumn<String> localHost = GeneratedColumn<String>(
    'local_host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPortMeta = const VerificationMeta(
    'localPort',
  );
  @override
  late final GeneratedColumn<int> localPort = GeneratedColumn<int>(
    'local_port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remoteHostMeta = const VerificationMeta(
    'remoteHost',
  );
  @override
  late final GeneratedColumn<String> remoteHost = GeneratedColumn<String>(
    'remote_host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remotePortMeta = const VerificationMeta(
    'remotePort',
  );
  @override
  late final GeneratedColumn<int> remotePort = GeneratedColumn<int>(
    'remote_port',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    rev,
    id,
    serverId,
    name,
    type,
    localHost,
    localPort,
    remoteHost,
    remotePort,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'port_forward';
  @override
  VerificationContext validateIntegrity(
    Insertable<PortForwardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('rev')) {
      context.handle(
        _revMeta,
        rev.isAcceptableOrUnknown(data['rev']!, _revMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('local_host')) {
      context.handle(
        _localHostMeta,
        localHost.isAcceptableOrUnknown(data['local_host']!, _localHostMeta),
      );
    }
    if (data.containsKey('local_port')) {
      context.handle(
        _localPortMeta,
        localPort.isAcceptableOrUnknown(data['local_port']!, _localPortMeta),
      );
    }
    if (data.containsKey('remote_host')) {
      context.handle(
        _remoteHostMeta,
        remoteHost.isAcceptableOrUnknown(data['remote_host']!, _remoteHostMeta),
      );
    }
    if (data.containsKey('remote_port')) {
      context.handle(
        _remotePortMeta,
        remotePort.isAcceptableOrUnknown(data['remote_port']!, _remotePortMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PortForwardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PortForwardRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rev'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      localHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_host'],
      ),
      localPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_port'],
      )!,
      remoteHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_host'],
      ),
      remotePort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_port'],
      ),
    );
  }

  @override
  $PortForwardsTable createAlias(String alias) {
    return $PortForwardsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class PortForwardRow extends DataClass implements Insertable<PortForwardRow> {
  final int updatedAt;
  final int rev;
  final String id;
  final String serverId;
  final String name;
  final String type;
  final String? localHost;
  final int localPort;
  final String? remoteHost;
  final int? remotePort;
  const PortForwardRow({
    required this.updatedAt,
    required this.rev,
    required this.id,
    required this.serverId,
    required this.name,
    required this.type,
    this.localHost,
    required this.localPort,
    this.remoteHost,
    this.remotePort,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['rev'] = Variable<int>(rev);
    map['id'] = Variable<String>(id);
    map['server_id'] = Variable<String>(serverId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || localHost != null) {
      map['local_host'] = Variable<String>(localHost);
    }
    map['local_port'] = Variable<int>(localPort);
    if (!nullToAbsent || remoteHost != null) {
      map['remote_host'] = Variable<String>(remoteHost);
    }
    if (!nullToAbsent || remotePort != null) {
      map['remote_port'] = Variable<int>(remotePort);
    }
    return map;
  }

  PortForwardsCompanion toCompanion(bool nullToAbsent) {
    return PortForwardsCompanion(
      updatedAt: Value(updatedAt),
      rev: Value(rev),
      id: Value(id),
      serverId: Value(serverId),
      name: Value(name),
      type: Value(type),
      localHost: localHost == null && nullToAbsent
          ? const Value.absent()
          : Value(localHost),
      localPort: Value(localPort),
      remoteHost: remoteHost == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteHost),
      remotePort: remotePort == null && nullToAbsent
          ? const Value.absent()
          : Value(remotePort),
    );
  }

  factory PortForwardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PortForwardRow(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rev: serializer.fromJson<int>(json['rev']),
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<String>(json['serverId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      localHost: serializer.fromJson<String?>(json['localHost']),
      localPort: serializer.fromJson<int>(json['localPort']),
      remoteHost: serializer.fromJson<String?>(json['remoteHost']),
      remotePort: serializer.fromJson<int?>(json['remotePort']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rev': serializer.toJson<int>(rev),
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<String>(serverId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'localHost': serializer.toJson<String?>(localHost),
      'localPort': serializer.toJson<int>(localPort),
      'remoteHost': serializer.toJson<String?>(remoteHost),
      'remotePort': serializer.toJson<int?>(remotePort),
    };
  }

  PortForwardRow copyWith({
    int? updatedAt,
    int? rev,
    String? id,
    String? serverId,
    String? name,
    String? type,
    Value<String?> localHost = const Value.absent(),
    int? localPort,
    Value<String?> remoteHost = const Value.absent(),
    Value<int?> remotePort = const Value.absent(),
  }) => PortForwardRow(
    updatedAt: updatedAt ?? this.updatedAt,
    rev: rev ?? this.rev,
    id: id ?? this.id,
    serverId: serverId ?? this.serverId,
    name: name ?? this.name,
    type: type ?? this.type,
    localHost: localHost.present ? localHost.value : this.localHost,
    localPort: localPort ?? this.localPort,
    remoteHost: remoteHost.present ? remoteHost.value : this.remoteHost,
    remotePort: remotePort.present ? remotePort.value : this.remotePort,
  );
  PortForwardRow copyWithCompanion(PortForwardsCompanion data) {
    return PortForwardRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rev: data.rev.present ? data.rev.value : this.rev,
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      localHost: data.localHost.present ? data.localHost.value : this.localHost,
      localPort: data.localPort.present ? data.localPort.value : this.localPort,
      remoteHost: data.remoteHost.present
          ? data.remoteHost.value
          : this.remoteHost,
      remotePort: data.remotePort.present
          ? data.remotePort.value
          : this.remotePort,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PortForwardRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('rev: $rev, ')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('localHost: $localHost, ')
          ..write('localPort: $localPort, ')
          ..write('remoteHost: $remoteHost, ')
          ..write('remotePort: $remotePort')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    rev,
    id,
    serverId,
    name,
    type,
    localHost,
    localPort,
    remoteHost,
    remotePort,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PortForwardRow &&
          other.updatedAt == this.updatedAt &&
          other.rev == this.rev &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.name == this.name &&
          other.type == this.type &&
          other.localHost == this.localHost &&
          other.localPort == this.localPort &&
          other.remoteHost == this.remoteHost &&
          other.remotePort == this.remotePort);
}

class PortForwardsCompanion extends UpdateCompanion<PortForwardRow> {
  final Value<int> updatedAt;
  final Value<int> rev;
  final Value<String> id;
  final Value<String> serverId;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> localHost;
  final Value<int> localPort;
  final Value<String?> remoteHost;
  final Value<int?> remotePort;
  const PortForwardsCompanion({
    this.updatedAt = const Value.absent(),
    this.rev = const Value.absent(),
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.localHost = const Value.absent(),
    this.localPort = const Value.absent(),
    this.remoteHost = const Value.absent(),
    this.remotePort = const Value.absent(),
  });
  PortForwardsCompanion.insert({
    this.updatedAt = const Value.absent(),
    this.rev = const Value.absent(),
    required String id,
    required String serverId,
    required String name,
    required String type,
    this.localHost = const Value.absent(),
    this.localPort = const Value.absent(),
    this.remoteHost = const Value.absent(),
    this.remotePort = const Value.absent(),
  }) : id = Value(id),
       serverId = Value(serverId),
       name = Value(name),
       type = Value(type);
  static Insertable<PortForwardRow> custom({
    Expression<int>? updatedAt,
    Expression<int>? rev,
    Expression<String>? id,
    Expression<String>? serverId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? localHost,
    Expression<int>? localPort,
    Expression<String>? remoteHost,
    Expression<int>? remotePort,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rev != null) 'rev': rev,
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (localHost != null) 'local_host': localHost,
      if (localPort != null) 'local_port': localPort,
      if (remoteHost != null) 'remote_host': remoteHost,
      if (remotePort != null) 'remote_port': remotePort,
    });
  }

  PortForwardsCompanion copyWith({
    Value<int>? updatedAt,
    Value<int>? rev,
    Value<String>? id,
    Value<String>? serverId,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? localHost,
    Value<int>? localPort,
    Value<String?>? remoteHost,
    Value<int?>? remotePort,
  }) {
    return PortForwardsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      rev: rev ?? this.rev,
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      type: type ?? this.type,
      localHost: localHost ?? this.localHost,
      localPort: localPort ?? this.localPort,
      remoteHost: remoteHost ?? this.remoteHost,
      remotePort: remotePort ?? this.remotePort,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rev.present) {
      map['rev'] = Variable<int>(rev.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (localHost.present) {
      map['local_host'] = Variable<String>(localHost.value);
    }
    if (localPort.present) {
      map['local_port'] = Variable<int>(localPort.value);
    }
    if (remoteHost.present) {
      map['remote_host'] = Variable<String>(remoteHost.value);
    }
    if (remotePort.present) {
      map['remote_port'] = Variable<int>(remotePort.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PortForwardsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('rev: $rev, ')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('localHost: $localHost, ')
          ..write('localPort: $localPort, ')
          ..write('remoteHost: $remoteHost, ')
          ..write('remotePort: $remotePort')
          ..write(')'))
        .toString();
  }
}

class $ContainerHostsTable extends ContainerHosts
    with TableInfo<$ContainerHostsTable, ContainerHostRow> {
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES server (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
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
  @override
  List<GeneratedColumn> get $columns => [serverId, type, host];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'container_host';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContainerHostRow> instance, {
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
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, type};
  @override
  ContainerHostRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContainerHostRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
    );
  }

  @override
  $ContainerHostsTable createAlias(String alias) {
    return $ContainerHostsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class ContainerHostRow extends DataClass
    implements Insertable<ContainerHostRow> {
  final String serverId;
  final String type;
  final String host;
  const ContainerHostRow({
    required this.serverId,
    required this.type,
    required this.host,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['type'] = Variable<String>(type);
    map['host'] = Variable<String>(host);
    return map;
  }

  ContainerHostsCompanion toCompanion(bool nullToAbsent) {
    return ContainerHostsCompanion(
      serverId: Value(serverId),
      type: Value(type),
      host: Value(host),
    );
  }

  factory ContainerHostRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContainerHostRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      type: serializer.fromJson<String>(json['type']),
      host: serializer.fromJson<String>(json['host']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'type': serializer.toJson<String>(type),
      'host': serializer.toJson<String>(host),
    };
  }

  ContainerHostRow copyWith({String? serverId, String? type, String? host}) =>
      ContainerHostRow(
        serverId: serverId ?? this.serverId,
        type: type ?? this.type,
        host: host ?? this.host,
      );
  ContainerHostRow copyWithCompanion(ContainerHostsCompanion data) {
    return ContainerHostRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      type: data.type.present ? data.type.value : this.type,
      host: data.host.present ? data.host.value : this.host,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContainerHostRow(')
          ..write('serverId: $serverId, ')
          ..write('type: $type, ')
          ..write('host: $host')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, type, host);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContainerHostRow &&
          other.serverId == this.serverId &&
          other.type == this.type &&
          other.host == this.host);
}

class ContainerHostsCompanion extends UpdateCompanion<ContainerHostRow> {
  final Value<String> serverId;
  final Value<String> type;
  final Value<String> host;
  const ContainerHostsCompanion({
    this.serverId = const Value.absent(),
    this.type = const Value.absent(),
    this.host = const Value.absent(),
  });
  ContainerHostsCompanion.insert({
    required String serverId,
    required String type,
    required String host,
  }) : serverId = Value(serverId),
       type = Value(type),
       host = Value(host);
  static Insertable<ContainerHostRow> custom({
    Expression<String>? serverId,
    Expression<String>? type,
    Expression<String>? host,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (type != null) 'type': type,
      if (host != null) 'host': host,
    });
  }

  ContainerHostsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? type,
    Value<String>? host,
  }) {
    return ContainerHostsCompanion(
      serverId: serverId ?? this.serverId,
      type: type ?? this.type,
      host: host ?? this.host,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContainerHostsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('type: $type, ')
          ..write('host: $host')
          ..write(')'))
        .toString();
  }
}

class $ContainerRuntimesTable extends ContainerRuntimes
    with TableInfo<$ContainerRuntimesTable, ContainerRuntimeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContainerRuntimesTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES server (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [serverId, type];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'container_runtime';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContainerRuntimeRow> instance, {
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
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId};
  @override
  ContainerRuntimeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContainerRuntimeRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
    );
  }

  @override
  $ContainerRuntimesTable createAlias(String alias) {
    return $ContainerRuntimesTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class ContainerRuntimeRow extends DataClass
    implements Insertable<ContainerRuntimeRow> {
  final String serverId;
  final String type;
  const ContainerRuntimeRow({required this.serverId, required this.type});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['type'] = Variable<String>(type);
    return map;
  }

  ContainerRuntimesCompanion toCompanion(bool nullToAbsent) {
    return ContainerRuntimesCompanion(
      serverId: Value(serverId),
      type: Value(type),
    );
  }

  factory ContainerRuntimeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContainerRuntimeRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      type: serializer.fromJson<String>(json['type']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'type': serializer.toJson<String>(type),
    };
  }

  ContainerRuntimeRow copyWith({String? serverId, String? type}) =>
      ContainerRuntimeRow(
        serverId: serverId ?? this.serverId,
        type: type ?? this.type,
      );
  ContainerRuntimeRow copyWithCompanion(ContainerRuntimesCompanion data) {
    return ContainerRuntimeRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      type: data.type.present ? data.type.value : this.type,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContainerRuntimeRow(')
          ..write('serverId: $serverId, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, type);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContainerRuntimeRow &&
          other.serverId == this.serverId &&
          other.type == this.type);
}

class ContainerRuntimesCompanion extends UpdateCompanion<ContainerRuntimeRow> {
  final Value<String> serverId;
  final Value<String> type;
  const ContainerRuntimesCompanion({
    this.serverId = const Value.absent(),
    this.type = const Value.absent(),
  });
  ContainerRuntimesCompanion.insert({
    required String serverId,
    required String type,
  }) : serverId = Value(serverId),
       type = Value(type);
  static Insertable<ContainerRuntimeRow> custom({
    Expression<String>? serverId,
    Expression<String>? type,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (type != null) 'type': type,
    });
  }

  ContainerRuntimesCompanion copyWith({
    Value<String>? serverId,
    Value<String>? type,
  }) {
    return ContainerRuntimesCompanion(
      serverId: serverId ?? this.serverId,
      type: type ?? this.type,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContainerRuntimesCompanion(')
          ..write('serverId: $serverId, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }
}

class $ConnStatsTable extends ConnStats
    with TableInfo<$ConnStatsTable, ConnStatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConnStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES server (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
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
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    serverName,
    timestamp,
    result,
    errorMessage,
    durationMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conn_stat';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConnStatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
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
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConnStatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConnStatRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
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
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
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
    );
  }

  @override
  $ConnStatsTable createAlias(String alias) {
    return $ConnStatsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class ConnStatRow extends DataClass implements Insertable<ConnStatRow> {
  final String id;
  final String serverId;
  final String serverName;
  final int timestamp;
  final String result;
  final String errorMessage;
  final int durationMs;
  const ConnStatRow({
    required this.id,
    required this.serverId,
    required this.serverName,
    required this.timestamp,
    required this.result,
    required this.errorMessage,
    required this.durationMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['server_id'] = Variable<String>(serverId);
    map['server_name'] = Variable<String>(serverName);
    map['timestamp'] = Variable<int>(timestamp);
    map['result'] = Variable<String>(result);
    map['error_message'] = Variable<String>(errorMessage);
    map['duration_ms'] = Variable<int>(durationMs);
    return map;
  }

  ConnStatsCompanion toCompanion(bool nullToAbsent) {
    return ConnStatsCompanion(
      id: Value(id),
      serverId: Value(serverId),
      serverName: Value(serverName),
      timestamp: Value(timestamp),
      result: Value(result),
      errorMessage: Value(errorMessage),
      durationMs: Value(durationMs),
    );
  }

  factory ConnStatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConnStatRow(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<String>(json['serverId']),
      serverName: serializer.fromJson<String>(json['serverName']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
      result: serializer.fromJson<String>(json['result']),
      errorMessage: serializer.fromJson<String>(json['errorMessage']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<String>(serverId),
      'serverName': serializer.toJson<String>(serverName),
      'timestamp': serializer.toJson<int>(timestamp),
      'result': serializer.toJson<String>(result),
      'errorMessage': serializer.toJson<String>(errorMessage),
      'durationMs': serializer.toJson<int>(durationMs),
    };
  }

  ConnStatRow copyWith({
    String? id,
    String? serverId,
    String? serverName,
    int? timestamp,
    String? result,
    String? errorMessage,
    int? durationMs,
  }) => ConnStatRow(
    id: id ?? this.id,
    serverId: serverId ?? this.serverId,
    serverName: serverName ?? this.serverName,
    timestamp: timestamp ?? this.timestamp,
    result: result ?? this.result,
    errorMessage: errorMessage ?? this.errorMessage,
    durationMs: durationMs ?? this.durationMs,
  );
  ConnStatRow copyWithCompanion(ConnStatsCompanion data) {
    return ConnStatRow(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      serverName: data.serverName.present
          ? data.serverName.value
          : this.serverName,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      result: data.result.present ? data.result.value : this.result,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConnStatRow(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('serverName: $serverName, ')
          ..write('timestamp: $timestamp, ')
          ..write('result: $result, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('durationMs: $durationMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    serverName,
    timestamp,
    result,
    errorMessage,
    durationMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConnStatRow &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.serverName == this.serverName &&
          other.timestamp == this.timestamp &&
          other.result == this.result &&
          other.errorMessage == this.errorMessage &&
          other.durationMs == this.durationMs);
}

class ConnStatsCompanion extends UpdateCompanion<ConnStatRow> {
  final Value<String> id;
  final Value<String> serverId;
  final Value<String> serverName;
  final Value<int> timestamp;
  final Value<String> result;
  final Value<String> errorMessage;
  final Value<int> durationMs;
  const ConnStatsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.serverName = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.result = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.durationMs = const Value.absent(),
  });
  ConnStatsCompanion.insert({
    required String id,
    required String serverId,
    required String serverName,
    required int timestamp,
    required String result,
    this.errorMessage = const Value.absent(),
    required int durationMs,
  }) : id = Value(id),
       serverId = Value(serverId),
       serverName = Value(serverName),
       timestamp = Value(timestamp),
       result = Value(result),
       durationMs = Value(durationMs);
  static Insertable<ConnStatRow> custom({
    Expression<String>? id,
    Expression<String>? serverId,
    Expression<String>? serverName,
    Expression<int>? timestamp,
    Expression<String>? result,
    Expression<String>? errorMessage,
    Expression<int>? durationMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (serverName != null) 'server_name': serverName,
      if (timestamp != null) 'timestamp': timestamp,
      if (result != null) 'result': result,
      if (errorMessage != null) 'error_message': errorMessage,
      if (durationMs != null) 'duration_ms': durationMs,
    });
  }

  ConnStatsCompanion copyWith({
    Value<String>? id,
    Value<String>? serverId,
    Value<String>? serverName,
    Value<int>? timestamp,
    Value<String>? result,
    Value<String>? errorMessage,
    Value<int>? durationMs,
  }) {
    return ConnStatsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      serverName: serverName ?? this.serverName,
      timestamp: timestamp ?? this.timestamp,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (serverName.present) {
      map['server_name'] = Variable<String>(serverName.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConnStatsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('serverName: $serverName, ')
          ..write('timestamp: $timestamp, ')
          ..write('result: $result, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('durationMs: $durationMs')
          ..write(')'))
        .toString();
  }
}

class $AgentConversationsTable extends AgentConversations
    with TableInfo<$AgentConversationsTable, AgentConversationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, serverId, updatedAt, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_conversation';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentConversationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AgentConversationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentConversationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
    );
  }

  @override
  $AgentConversationsTable createAlias(String alias) {
    return $AgentConversationsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class AgentConversationRow extends DataClass
    implements Insertable<AgentConversationRow> {
  final String id;
  final String serverId;
  final int updatedAt;
  final String data;
  const AgentConversationRow({
    required this.id,
    required this.serverId,
    required this.updatedAt,
    required this.data,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['server_id'] = Variable<String>(serverId);
    map['updated_at'] = Variable<int>(updatedAt);
    map['data'] = Variable<String>(data);
    return map;
  }

  AgentConversationsCompanion toCompanion(bool nullToAbsent) {
    return AgentConversationsCompanion(
      id: Value(id),
      serverId: Value(serverId),
      updatedAt: Value(updatedAt),
      data: Value(data),
    );
  }

  factory AgentConversationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentConversationRow(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<String>(json['serverId']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<String>(serverId),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'data': serializer.toJson<String>(data),
    };
  }

  AgentConversationRow copyWith({
    String? id,
    String? serverId,
    int? updatedAt,
    String? data,
  }) => AgentConversationRow(
    id: id ?? this.id,
    serverId: serverId ?? this.serverId,
    updatedAt: updatedAt ?? this.updatedAt,
    data: data ?? this.data,
  );
  AgentConversationRow copyWithCompanion(AgentConversationsCompanion data) {
    return AgentConversationRow(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentConversationRow(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, serverId, updatedAt, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentConversationRow &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.updatedAt == this.updatedAt &&
          other.data == this.data);
}

class AgentConversationsCompanion
    extends UpdateCompanion<AgentConversationRow> {
  final Value<String> id;
  final Value<String> serverId;
  final Value<int> updatedAt;
  final Value<String> data;
  const AgentConversationsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.data = const Value.absent(),
  });
  AgentConversationsCompanion.insert({
    required String id,
    required String serverId,
    required int updatedAt,
    required String data,
  }) : id = Value(id),
       serverId = Value(serverId),
       updatedAt = Value(updatedAt),
       data = Value(data);
  static Insertable<AgentConversationRow> custom({
    Expression<String>? id,
    Expression<String>? serverId,
    Expression<int>? updatedAt,
    Expression<String>? data,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (data != null) 'data': data,
    });
  }

  AgentConversationsCompanion copyWith({
    Value<String>? id,
    Value<String>? serverId,
    Value<int>? updatedAt,
    Value<String>? data,
  }) {
    return AgentConversationsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      updatedAt: updatedAt ?? this.updatedAt,
      data: data ?? this.data,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentConversationsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }
}

class $AgentActiveConversationsTable extends AgentActiveConversations
    with TableInfo<$AgentActiveConversationsTable, AgentActiveConversationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentActiveConversationsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES agent_conversation (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [serverId, conversationId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_active_conversation';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentActiveConversationRow> instance, {
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
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId};
  @override
  AgentActiveConversationRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentActiveConversationRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
    );
  }

  @override
  $AgentActiveConversationsTable createAlias(String alias) {
    return $AgentActiveConversationsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class AgentActiveConversationRow extends DataClass
    implements Insertable<AgentActiveConversationRow> {
  final String serverId;
  final String conversationId;
  const AgentActiveConversationRow({
    required this.serverId,
    required this.conversationId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['conversation_id'] = Variable<String>(conversationId);
    return map;
  }

  AgentActiveConversationsCompanion toCompanion(bool nullToAbsent) {
    return AgentActiveConversationsCompanion(
      serverId: Value(serverId),
      conversationId: Value(conversationId),
    );
  }

  factory AgentActiveConversationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentActiveConversationRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'conversationId': serializer.toJson<String>(conversationId),
    };
  }

  AgentActiveConversationRow copyWith({
    String? serverId,
    String? conversationId,
  }) => AgentActiveConversationRow(
    serverId: serverId ?? this.serverId,
    conversationId: conversationId ?? this.conversationId,
  );
  AgentActiveConversationRow copyWithCompanion(
    AgentActiveConversationsCompanion data,
  ) {
    return AgentActiveConversationRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentActiveConversationRow(')
          ..write('serverId: $serverId, ')
          ..write('conversationId: $conversationId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, conversationId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentActiveConversationRow &&
          other.serverId == this.serverId &&
          other.conversationId == this.conversationId);
}

class AgentActiveConversationsCompanion
    extends UpdateCompanion<AgentActiveConversationRow> {
  final Value<String> serverId;
  final Value<String> conversationId;
  const AgentActiveConversationsCompanion({
    this.serverId = const Value.absent(),
    this.conversationId = const Value.absent(),
  });
  AgentActiveConversationsCompanion.insert({
    required String serverId,
    required String conversationId,
  }) : serverId = Value(serverId),
       conversationId = Value(conversationId);
  static Insertable<AgentActiveConversationRow> custom({
    Expression<String>? serverId,
    Expression<String>? conversationId,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (conversationId != null) 'conversation_id': conversationId,
    });
  }

  AgentActiveConversationsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? conversationId,
  }) {
    return AgentActiveConversationsCompanion(
      serverId: serverId ?? this.serverId,
      conversationId: conversationId ?? this.conversationId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentActiveConversationsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('conversationId: $conversationId')
          ..write(')'))
        .toString();
  }
}

class $TombstonesTable extends Tombstones
    with TableInfo<$TombstonesTable, TombstoneRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TombstonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tblMeta = const VerificationMeta('tbl');
  @override
  late final GeneratedColumn<String> tbl = GeneratedColumn<String>(
    'tbl',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [tbl, rowId, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tombstone';
  @override
  VerificationContext validateIntegrity(
    Insertable<TombstoneRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tbl')) {
      context.handle(
        _tblMeta,
        tbl.isAcceptableOrUnknown(data['tbl']!, _tblMeta),
      );
    } else if (isInserting) {
      context.missing(_tblMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tbl, rowId};
  @override
  TombstoneRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TombstoneRow(
      tbl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tbl'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      )!,
    );
  }

  @override
  $TombstonesTable createAlias(String alias) {
    return $TombstonesTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class TombstoneRow extends DataClass implements Insertable<TombstoneRow> {
  final String tbl;
  final String rowId;
  final int deletedAt;
  const TombstoneRow({
    required this.tbl,
    required this.rowId,
    required this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tbl'] = Variable<String>(tbl);
    map['row_id'] = Variable<String>(rowId);
    map['deleted_at'] = Variable<int>(deletedAt);
    return map;
  }

  TombstonesCompanion toCompanion(bool nullToAbsent) {
    return TombstonesCompanion(
      tbl: Value(tbl),
      rowId: Value(rowId),
      deletedAt: Value(deletedAt),
    );
  }

  factory TombstoneRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TombstoneRow(
      tbl: serializer.fromJson<String>(json['tbl']),
      rowId: serializer.fromJson<String>(json['rowId']),
      deletedAt: serializer.fromJson<int>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tbl': serializer.toJson<String>(tbl),
      'rowId': serializer.toJson<String>(rowId),
      'deletedAt': serializer.toJson<int>(deletedAt),
    };
  }

  TombstoneRow copyWith({String? tbl, String? rowId, int? deletedAt}) =>
      TombstoneRow(
        tbl: tbl ?? this.tbl,
        rowId: rowId ?? this.rowId,
        deletedAt: deletedAt ?? this.deletedAt,
      );
  TombstoneRow copyWithCompanion(TombstonesCompanion data) {
    return TombstoneRow(
      tbl: data.tbl.present ? data.tbl.value : this.tbl,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TombstoneRow(')
          ..write('tbl: $tbl, ')
          ..write('rowId: $rowId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tbl, rowId, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TombstoneRow &&
          other.tbl == this.tbl &&
          other.rowId == this.rowId &&
          other.deletedAt == this.deletedAt);
}

class TombstonesCompanion extends UpdateCompanion<TombstoneRow> {
  final Value<String> tbl;
  final Value<String> rowId;
  final Value<int> deletedAt;
  const TombstonesCompanion({
    this.tbl = const Value.absent(),
    this.rowId = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  TombstonesCompanion.insert({
    required String tbl,
    required String rowId,
    required int deletedAt,
  }) : tbl = Value(tbl),
       rowId = Value(rowId),
       deletedAt = Value(deletedAt);
  static Insertable<TombstoneRow> custom({
    Expression<String>? tbl,
    Expression<String>? rowId,
    Expression<int>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (tbl != null) 'tbl': tbl,
      if (rowId != null) 'row_id': rowId,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  TombstonesCompanion copyWith({
    Value<String>? tbl,
    Value<String>? rowId,
    Value<int>? deletedAt,
  }) {
    return TombstonesCompanion(
      tbl: tbl ?? this.tbl,
      rowId: rowId ?? this.rowId,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tbl.present) {
      map['tbl'] = Variable<String>(tbl.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TombstonesCompanion(')
          ..write('tbl: $tbl, ')
          ..write('rowId: $rowId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kMeta = const VerificationMeta('k');
  @override
  late final GeneratedColumn<String> k = GeneratedColumn<String>(
    'k',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vMeta = const VerificationMeta('v');
  @override
  late final GeneratedColumn<String> v = GeneratedColumn<String>(
    'v',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [k, v];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('k')) {
      context.handle(_kMeta, k.isAcceptableOrUnknown(data['k']!, _kMeta));
    } else if (isInserting) {
      context.missing(_kMeta);
    }
    if (data.containsKey('v')) {
      context.handle(_vMeta, v.isAcceptableOrUnknown(data['v']!, _vMeta));
    } else if (isInserting) {
      context.missing(_vMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {k};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      k: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}k'],
      )!,
      v: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}v'],
      )!,
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final String k;
  final String v;
  const SyncStateRow({required this.k, required this.v});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['k'] = Variable<String>(k);
    map['v'] = Variable<String>(v);
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(k: Value(k), v: Value(v));
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      k: serializer.fromJson<String>(json['k']),
      v: serializer.fromJson<String>(json['v']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'k': serializer.toJson<String>(k),
      'v': serializer.toJson<String>(v),
    };
  }

  SyncStateRow copyWith({String? k, String? v}) =>
      SyncStateRow(k: k ?? this.k, v: v ?? this.v);
  SyncStateRow copyWithCompanion(SyncStatesCompanion data) {
    return SyncStateRow(
      k: data.k.present ? data.k.value : this.k,
      v: data.v.present ? data.v.value : this.v,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('k: $k, ')
          ..write('v: $v')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(k, v);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow && other.k == this.k && other.v == this.v);
}

class SyncStatesCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<String> k;
  final Value<String> v;
  const SyncStatesCompanion({
    this.k = const Value.absent(),
    this.v = const Value.absent(),
  });
  SyncStatesCompanion.insert({required String k, required String v})
    : k = Value(k),
      v = Value(v);
  static Insertable<SyncStateRow> custom({
    Expression<String>? k,
    Expression<String>? v,
  }) {
    return RawValuesInsertable({if (k != null) 'k': k, if (v != null) 'v': v});
  }

  SyncStatesCompanion copyWith({Value<String>? k, Value<String>? v}) {
    return SyncStatesCompanion(k: k ?? this.k, v: v ?? this.v);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (k.present) {
      map['k'] = Variable<String>(k.value);
    }
    if (v.present) {
      map['v'] = Variable<String>(v.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('k: $k, ')
          ..write('v: $v')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $PrivateKeysTable privateKeys = $PrivateKeysTable(this);
  late final $BmcCredentialsTable bmcCredentials = $BmcCredentialsTable(this);
  late final $ServersTable servers = $ServersTable(this);
  late final $ServerTagsTable serverTags = $ServerTagsTable(this);
  late final $ServerEnvsTable serverEnvs = $ServerEnvsTable(this);
  late final $ServerJumpsTable serverJumps = $ServerJumpsTable(this);
  late final $ServerDisabledCmdsTable serverDisabledCmds =
      $ServerDisabledCmdsTable(this);
  late final $ServerCustomCmdsTable serverCustomCmds = $ServerCustomCmdsTable(
    this,
  );
  late final $KnownHostsTable knownHosts = $KnownHostsTable(this);
  late final $SnippetsTable snippets = $SnippetsTable(this);
  late final $SnippetTagsTable snippetTags = $SnippetTagsTable(this);
  late final $SnippetAutoRunOnTable snippetAutoRunOn = $SnippetAutoRunOnTable(
    this,
  );
  late final $PortForwardsTable portForwards = $PortForwardsTable(this);
  late final $ContainerHostsTable containerHosts = $ContainerHostsTable(this);
  late final $ContainerRuntimesTable containerRuntimes =
      $ContainerRuntimesTable(this);
  late final $ConnStatsTable connStats = $ConnStatsTable(this);
  late final $AgentConversationsTable agentConversations =
      $AgentConversationsTable(this);
  late final $AgentActiveConversationsTable agentActiveConversations =
      $AgentActiveConversationsTable(this);
  late final $TombstonesTable tombstones = $TombstonesTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    privateKeys,
    bmcCredentials,
    servers,
    serverTags,
    serverEnvs,
    serverJumps,
    serverDisabledCmds,
    serverCustomCmds,
    knownHosts,
    snippets,
    snippetTags,
    snippetAutoRunOn,
    portForwards,
    containerHosts,
    containerRuntimes,
    connStats,
    agentConversations,
    agentActiveConversations,
    tombstones,
    syncStates,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'private_key',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('server', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'bmc_credential',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('server', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'server',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('server_tag', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'server',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('server_env', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'server',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('server_jump', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'server',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('server_jump', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'server',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('server_disabled_cmd', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'server',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('server_custom_cmd', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'server',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('known_host', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'snippet',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('snippet_tag', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'snippet',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('snippet_auto_run_on', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'server',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('snippet_auto_run_on', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'server',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('port_forward', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'server',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('container_host', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'server',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('container_runtime', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'server',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('conn_stat', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'agent_conversation',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('agent_active_conversation', kind: UpdateKind.delete),
      ],
    ),
  ]);
}

typedef $$PrivateKeysTableCreateCompanionBuilder =
    PrivateKeysCompanion Function({
      Value<int> updatedAt,
      Value<int> rev,
      required String id,
      required String name,
      required String key,
      Value<String?> comment,
    });
typedef $$PrivateKeysTableUpdateCompanionBuilder =
    PrivateKeysCompanion Function({
      Value<int> updatedAt,
      Value<int> rev,
      Value<String> id,
      Value<String> name,
      Value<String> key,
      Value<String?> comment,
    });

final class $$PrivateKeysTableReferences
    extends BaseReferences<_$AppDb, $PrivateKeysTable, PrivateKeyRow> {
  $$PrivateKeysTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ServersTable, List<ServerRow>> _serversRefsTable(
    _$AppDb db,
  ) => MultiTypedResultKey.fromTable(
    db.servers,
    aliasName: 'private_key__id__server__ssh_key_id',
  );

  $$ServersTableProcessedTableManager get serversRefs {
    final manager = $$ServersTableTableManager(
      $_db,
      $_db.servers,
    ).filter((f) => f.sshKeyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_serversRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PrivateKeysTableFilterComposer
    extends Composer<_$AppDb, $PrivateKeysTable> {
  $$PrivateKeysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> serversRefs(
    Expression<bool> Function($$ServersTableFilterComposer f) f,
  ) {
    final $$ServersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.sshKeyId,
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
    return f(composer);
  }
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
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
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
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rev =>
      $composableBuilder(column: $table.rev, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  Expression<T> serversRefs<T extends Object>(
    Expression<T> Function($$ServersTableAnnotationComposer a) f,
  ) {
    final $$ServersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.sshKeyId,
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
    return f(composer);
  }
}

class $$PrivateKeysTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $PrivateKeysTable,
          PrivateKeyRow,
          $$PrivateKeysTableFilterComposer,
          $$PrivateKeysTableOrderingComposer,
          $$PrivateKeysTableAnnotationComposer,
          $$PrivateKeysTableCreateCompanionBuilder,
          $$PrivateKeysTableUpdateCompanionBuilder,
          (PrivateKeyRow, $$PrivateKeysTableReferences),
          PrivateKeyRow,
          PrefetchHooks Function({bool serversRefs})
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
                Value<int> updatedAt = const Value.absent(),
                Value<int> rev = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String?> comment = const Value.absent(),
              }) => PrivateKeysCompanion(
                updatedAt: updatedAt,
                rev: rev,
                id: id,
                name: name,
                key: key,
                comment: comment,
              ),
          createCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int> rev = const Value.absent(),
                required String id,
                required String name,
                required String key,
                Value<String?> comment = const Value.absent(),
              }) => PrivateKeysCompanion.insert(
                updatedAt: updatedAt,
                rev: rev,
                id: id,
                name: name,
                key: key,
                comment: comment,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PrivateKeysTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({serversRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (serversRefs) db.servers],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (serversRefs)
                    await $_getPrefetchedData<
                      PrivateKeyRow,
                      $PrivateKeysTable,
                      ServerRow
                    >(
                      currentTable: table,
                      referencedTable: $$PrivateKeysTableReferences
                          ._serversRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PrivateKeysTableReferences(
                            db,
                            table,
                            p0,
                          ).serversRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sshKeyId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PrivateKeysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $PrivateKeysTable,
      PrivateKeyRow,
      $$PrivateKeysTableFilterComposer,
      $$PrivateKeysTableOrderingComposer,
      $$PrivateKeysTableAnnotationComposer,
      $$PrivateKeysTableCreateCompanionBuilder,
      $$PrivateKeysTableUpdateCompanionBuilder,
      (PrivateKeyRow, $$PrivateKeysTableReferences),
      PrivateKeyRow,
      PrefetchHooks Function({bool serversRefs})
    >;
typedef $$BmcCredentialsTableCreateCompanionBuilder =
    BmcCredentialsCompanion Function({
      Value<int> updatedAt,
      Value<int> rev,
      required String id,
      required String name,
      required String user,
      Value<String?> pwd,
    });
typedef $$BmcCredentialsTableUpdateCompanionBuilder =
    BmcCredentialsCompanion Function({
      Value<int> updatedAt,
      Value<int> rev,
      Value<String> id,
      Value<String> name,
      Value<String> user,
      Value<String?> pwd,
    });

final class $$BmcCredentialsTableReferences
    extends BaseReferences<_$AppDb, $BmcCredentialsTable, BmcCredentialRow> {
  $$BmcCredentialsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ServersTable, List<ServerRow>> _serversRefsTable(
    _$AppDb db,
  ) => MultiTypedResultKey.fromTable(
    db.servers,
    aliasName: 'bmc_credential__id__server__bmc_cred_id',
  );

  $$ServersTableProcessedTableManager get serversRefs {
    final manager = $$ServersTableTableManager(
      $_db,
      $_db.servers,
    ).filter((f) => f.bmcCredId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_serversRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BmcCredentialsTableFilterComposer
    extends Composer<_$AppDb, $BmcCredentialsTable> {
  $$BmcCredentialsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
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

  Expression<bool> serversRefs(
    Expression<bool> Function($$ServersTableFilterComposer f) f,
  ) {
    final $$ServersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.bmcCredId,
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
    return f(composer);
  }
}

class $$BmcCredentialsTableOrderingComposer
    extends Composer<_$AppDb, $BmcCredentialsTable> {
  $$BmcCredentialsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
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
}

class $$BmcCredentialsTableAnnotationComposer
    extends Composer<_$AppDb, $BmcCredentialsTable> {
  $$BmcCredentialsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rev =>
      $composableBuilder(column: $table.rev, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get user =>
      $composableBuilder(column: $table.user, builder: (column) => column);

  GeneratedColumn<String> get pwd =>
      $composableBuilder(column: $table.pwd, builder: (column) => column);

  Expression<T> serversRefs<T extends Object>(
    Expression<T> Function($$ServersTableAnnotationComposer a) f,
  ) {
    final $$ServersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.servers,
      getReferencedColumn: (t) => t.bmcCredId,
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
    return f(composer);
  }
}

class $$BmcCredentialsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $BmcCredentialsTable,
          BmcCredentialRow,
          $$BmcCredentialsTableFilterComposer,
          $$BmcCredentialsTableOrderingComposer,
          $$BmcCredentialsTableAnnotationComposer,
          $$BmcCredentialsTableCreateCompanionBuilder,
          $$BmcCredentialsTableUpdateCompanionBuilder,
          (BmcCredentialRow, $$BmcCredentialsTableReferences),
          BmcCredentialRow,
          PrefetchHooks Function({bool serversRefs})
        > {
  $$BmcCredentialsTableTableManager(_$AppDb db, $BmcCredentialsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BmcCredentialsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BmcCredentialsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BmcCredentialsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int> rev = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> user = const Value.absent(),
                Value<String?> pwd = const Value.absent(),
              }) => BmcCredentialsCompanion(
                updatedAt: updatedAt,
                rev: rev,
                id: id,
                name: name,
                user: user,
                pwd: pwd,
              ),
          createCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int> rev = const Value.absent(),
                required String id,
                required String name,
                required String user,
                Value<String?> pwd = const Value.absent(),
              }) => BmcCredentialsCompanion.insert(
                updatedAt: updatedAt,
                rev: rev,
                id: id,
                name: name,
                user: user,
                pwd: pwd,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BmcCredentialsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({serversRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (serversRefs) db.servers],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (serversRefs)
                    await $_getPrefetchedData<
                      BmcCredentialRow,
                      $BmcCredentialsTable,
                      ServerRow
                    >(
                      currentTable: table,
                      referencedTable: $$BmcCredentialsTableReferences
                          ._serversRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$BmcCredentialsTableReferences(
                            db,
                            table,
                            p0,
                          ).serversRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.bmcCredId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BmcCredentialsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $BmcCredentialsTable,
      BmcCredentialRow,
      $$BmcCredentialsTableFilterComposer,
      $$BmcCredentialsTableOrderingComposer,
      $$BmcCredentialsTableAnnotationComposer,
      $$BmcCredentialsTableCreateCompanionBuilder,
      $$BmcCredentialsTableUpdateCompanionBuilder,
      (BmcCredentialRow, $$BmcCredentialsTableReferences),
      BmcCredentialRow,
      PrefetchHooks Function({bool serversRefs})
    >;
typedef $$ServersTableCreateCompanionBuilder =
    ServersCompanion Function({
      Value<int> updatedAt,
      Value<int> rev,
      required String id,
      required String name,
      Value<bool> autoConnect,
      Value<String?> systemType,
      Value<String?> sshIp,
      Value<int?> sshPort,
      Value<String?> sshUser,
      Value<String?> sshPwd,
      Value<String?> sshKeyId,
      Value<String?> sshKeyPath,
      Value<String?> sshAlterUrl,
      Value<String?> sshProxyCommand,
      Value<String?> monitorAddr,
      Value<String?> monitorUser,
      Value<String?> monitorPwd,
      Value<bool?> monitorIgnoreCert,
      Value<bool?> monitorAllowInsecure,
      Value<String?> wolMac,
      Value<String?> wolIp,
      Value<String?> wolPwd,
      Value<String?> bmcAddr,
      Value<String?> bmcCertSha256,
      Value<String?> bmcCredId,
      Value<String?> pveAddr,
      Value<bool> pveIgnoreCert,
      Value<String?> pvePwd,
      Value<String?> preferTempDev,
      Value<bool> tempIsCelsius,
      Value<String?> logoUrl,
      Value<String?> netDev,
      Value<String?> scriptDir,
    });
typedef $$ServersTableUpdateCompanionBuilder =
    ServersCompanion Function({
      Value<int> updatedAt,
      Value<int> rev,
      Value<String> id,
      Value<String> name,
      Value<bool> autoConnect,
      Value<String?> systemType,
      Value<String?> sshIp,
      Value<int?> sshPort,
      Value<String?> sshUser,
      Value<String?> sshPwd,
      Value<String?> sshKeyId,
      Value<String?> sshKeyPath,
      Value<String?> sshAlterUrl,
      Value<String?> sshProxyCommand,
      Value<String?> monitorAddr,
      Value<String?> monitorUser,
      Value<String?> monitorPwd,
      Value<bool?> monitorIgnoreCert,
      Value<bool?> monitorAllowInsecure,
      Value<String?> wolMac,
      Value<String?> wolIp,
      Value<String?> wolPwd,
      Value<String?> bmcAddr,
      Value<String?> bmcCertSha256,
      Value<String?> bmcCredId,
      Value<String?> pveAddr,
      Value<bool> pveIgnoreCert,
      Value<String?> pvePwd,
      Value<String?> preferTempDev,
      Value<bool> tempIsCelsius,
      Value<String?> logoUrl,
      Value<String?> netDev,
      Value<String?> scriptDir,
    });

final class $$ServersTableReferences
    extends BaseReferences<_$AppDb, $ServersTable, ServerRow> {
  $$ServersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PrivateKeysTable _sshKeyIdTable(_$AppDb db) =>
      db.privateKeys.createAlias('server__ssh_key_id__private_key__id');

  $$PrivateKeysTableProcessedTableManager? get sshKeyId {
    final $_column = $_itemColumn<String>('ssh_key_id');
    if ($_column == null) return null;
    final manager = $$PrivateKeysTableTableManager(
      $_db,
      $_db.privateKeys,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sshKeyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $BmcCredentialsTable _bmcCredIdTable(_$AppDb db) =>
      db.bmcCredentials.createAlias('server__bmc_cred_id__bmc_credential__id');

  $$BmcCredentialsTableProcessedTableManager? get bmcCredId {
    final $_column = $_itemColumn<String>('bmc_cred_id');
    if ($_column == null) return null;
    final manager = $$BmcCredentialsTableTableManager(
      $_db,
      $_db.bmcCredentials,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bmcCredIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ServerTagsTable, List<ServerTagRow>>
  _serverTagsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.serverTags,
    aliasName: 'server__id__server_tag__server_id',
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

  static MultiTypedResultKey<$ServerEnvsTable, List<ServerEnvRow>>
  _serverEnvsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.serverEnvs,
    aliasName: 'server__id__server_env__server_id',
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
    $ServerDisabledCmdsTable,
    List<ServerDisabledCmdRow>
  >
  _serverDisabledCmdsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.serverDisabledCmds,
    aliasName: 'server__id__server_disabled_cmd__server_id',
  );

  $$ServerDisabledCmdsTableProcessedTableManager get serverDisabledCmdsRefs {
    final manager = $$ServerDisabledCmdsTableTableManager(
      $_db,
      $_db.serverDisabledCmds,
    ).filter((f) => f.serverId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _serverDisabledCmdsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ServerCustomCmdsTable, List<ServerCustomCmdRow>>
  _serverCustomCmdsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.serverCustomCmds,
    aliasName: 'server__id__server_custom_cmd__server_id',
  );

  $$ServerCustomCmdsTableProcessedTableManager get serverCustomCmdsRefs {
    final manager = $$ServerCustomCmdsTableTableManager(
      $_db,
      $_db.serverCustomCmds,
    ).filter((f) => f.serverId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _serverCustomCmdsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$KnownHostsTable, List<KnownHostRow>>
  _knownHostsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.knownHosts,
    aliasName: 'server__id__known_host__server_id',
  );

  $$KnownHostsTableProcessedTableManager get knownHostsRefs {
    final manager = $$KnownHostsTableTableManager(
      $_db,
      $_db.knownHosts,
    ).filter((f) => f.serverId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_knownHostsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SnippetAutoRunOnTable, List<SnippetAutoRunRow>>
  _snippetAutoRunOnRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.snippetAutoRunOn,
    aliasName: 'server__id__snippet_auto_run_on__server_id',
  );

  $$SnippetAutoRunOnTableProcessedTableManager get snippetAutoRunOnRefs {
    final manager = $$SnippetAutoRunOnTableTableManager(
      $_db,
      $_db.snippetAutoRunOn,
    ).filter((f) => f.serverId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _snippetAutoRunOnRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PortForwardsTable, List<PortForwardRow>>
  _portForwardsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.portForwards,
    aliasName: 'server__id__port_forward__server_id',
  );

  $$PortForwardsTableProcessedTableManager get portForwardsRefs {
    final manager = $$PortForwardsTableTableManager(
      $_db,
      $_db.portForwards,
    ).filter((f) => f.serverId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_portForwardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ContainerHostsTable, List<ContainerHostRow>>
  _containerHostsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.containerHosts,
    aliasName: 'server__id__container_host__server_id',
  );

  $$ContainerHostsTableProcessedTableManager get containerHostsRefs {
    final manager = $$ContainerHostsTableTableManager(
      $_db,
      $_db.containerHosts,
    ).filter((f) => f.serverId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_containerHostsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ContainerRuntimesTable, List<ContainerRuntimeRow>>
  _containerRuntimesRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.containerRuntimes,
    aliasName: 'server__id__container_runtime__server_id',
  );

  $$ContainerRuntimesTableProcessedTableManager get containerRuntimesRefs {
    final manager = $$ContainerRuntimesTableTableManager(
      $_db,
      $_db.containerRuntimes,
    ).filter((f) => f.serverId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _containerRuntimesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ConnStatsTable, List<ConnStatRow>>
  _connStatsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.connStats,
    aliasName: 'server__id__conn_stat__server_id',
  );

  $$ConnStatsTableProcessedTableManager get connStatsRefs {
    final manager = $$ConnStatsTableTableManager(
      $_db,
      $_db.connStats,
    ).filter((f) => f.serverId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_connStatsRefsTable($_db));
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
  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoConnect => $composableBuilder(
    column: $table.autoConnect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get systemType => $composableBuilder(
    column: $table.systemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sshIp => $composableBuilder(
    column: $table.sshIp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sshPort => $composableBuilder(
    column: $table.sshPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sshUser => $composableBuilder(
    column: $table.sshUser,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sshPwd => $composableBuilder(
    column: $table.sshPwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sshKeyPath => $composableBuilder(
    column: $table.sshKeyPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sshAlterUrl => $composableBuilder(
    column: $table.sshAlterUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sshProxyCommand => $composableBuilder(
    column: $table.sshProxyCommand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get monitorAddr => $composableBuilder(
    column: $table.monitorAddr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get monitorUser => $composableBuilder(
    column: $table.monitorUser,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get monitorPwd => $composableBuilder(
    column: $table.monitorPwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get monitorIgnoreCert => $composableBuilder(
    column: $table.monitorIgnoreCert,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get monitorAllowInsecure => $composableBuilder(
    column: $table.monitorAllowInsecure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wolMac => $composableBuilder(
    column: $table.wolMac,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wolIp => $composableBuilder(
    column: $table.wolIp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wolPwd => $composableBuilder(
    column: $table.wolPwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bmcAddr => $composableBuilder(
    column: $table.bmcAddr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bmcCertSha256 => $composableBuilder(
    column: $table.bmcCertSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pveAddr => $composableBuilder(
    column: $table.pveAddr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pveIgnoreCert => $composableBuilder(
    column: $table.pveIgnoreCert,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pvePwd => $composableBuilder(
    column: $table.pvePwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferTempDev => $composableBuilder(
    column: $table.preferTempDev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get tempIsCelsius => $composableBuilder(
    column: $table.tempIsCelsius,
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

  $$PrivateKeysTableFilterComposer get sshKeyId {
    final $$PrivateKeysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sshKeyId,
      referencedTable: $db.privateKeys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrivateKeysTableFilterComposer(
            $db: $db,
            $table: $db.privateKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BmcCredentialsTableFilterComposer get bmcCredId {
    final $$BmcCredentialsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bmcCredId,
      referencedTable: $db.bmcCredentials,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BmcCredentialsTableFilterComposer(
            $db: $db,
            $table: $db.bmcCredentials,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
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

  Expression<bool> serverDisabledCmdsRefs(
    Expression<bool> Function($$ServerDisabledCmdsTableFilterComposer f) f,
  ) {
    final $$ServerDisabledCmdsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serverDisabledCmds,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServerDisabledCmdsTableFilterComposer(
            $db: $db,
            $table: $db.serverDisabledCmds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> serverCustomCmdsRefs(
    Expression<bool> Function($$ServerCustomCmdsTableFilterComposer f) f,
  ) {
    final $$ServerCustomCmdsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serverCustomCmds,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServerCustomCmdsTableFilterComposer(
            $db: $db,
            $table: $db.serverCustomCmds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> knownHostsRefs(
    Expression<bool> Function($$KnownHostsTableFilterComposer f) f,
  ) {
    final $$KnownHostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.knownHosts,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KnownHostsTableFilterComposer(
            $db: $db,
            $table: $db.knownHosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> snippetAutoRunOnRefs(
    Expression<bool> Function($$SnippetAutoRunOnTableFilterComposer f) f,
  ) {
    final $$SnippetAutoRunOnTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.snippetAutoRunOn,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnippetAutoRunOnTableFilterComposer(
            $db: $db,
            $table: $db.snippetAutoRunOn,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> portForwardsRefs(
    Expression<bool> Function($$PortForwardsTableFilterComposer f) f,
  ) {
    final $$PortForwardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.portForwards,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PortForwardsTableFilterComposer(
            $db: $db,
            $table: $db.portForwards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> containerHostsRefs(
    Expression<bool> Function($$ContainerHostsTableFilterComposer f) f,
  ) {
    final $$ContainerHostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.containerHosts,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContainerHostsTableFilterComposer(
            $db: $db,
            $table: $db.containerHosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> containerRuntimesRefs(
    Expression<bool> Function($$ContainerRuntimesTableFilterComposer f) f,
  ) {
    final $$ContainerRuntimesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.containerRuntimes,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContainerRuntimesTableFilterComposer(
            $db: $db,
            $table: $db.containerRuntimes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> connStatsRefs(
    Expression<bool> Function($$ConnStatsTableFilterComposer f) f,
  ) {
    final $$ConnStatsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.connStats,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConnStatsTableFilterComposer(
            $db: $db,
            $table: $db.connStats,
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
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoConnect => $composableBuilder(
    column: $table.autoConnect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get systemType => $composableBuilder(
    column: $table.systemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sshIp => $composableBuilder(
    column: $table.sshIp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sshPort => $composableBuilder(
    column: $table.sshPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sshUser => $composableBuilder(
    column: $table.sshUser,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sshPwd => $composableBuilder(
    column: $table.sshPwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sshKeyPath => $composableBuilder(
    column: $table.sshKeyPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sshAlterUrl => $composableBuilder(
    column: $table.sshAlterUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sshProxyCommand => $composableBuilder(
    column: $table.sshProxyCommand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get monitorAddr => $composableBuilder(
    column: $table.monitorAddr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get monitorUser => $composableBuilder(
    column: $table.monitorUser,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get monitorPwd => $composableBuilder(
    column: $table.monitorPwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get monitorIgnoreCert => $composableBuilder(
    column: $table.monitorIgnoreCert,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get monitorAllowInsecure => $composableBuilder(
    column: $table.monitorAllowInsecure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wolMac => $composableBuilder(
    column: $table.wolMac,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wolIp => $composableBuilder(
    column: $table.wolIp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wolPwd => $composableBuilder(
    column: $table.wolPwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bmcAddr => $composableBuilder(
    column: $table.bmcAddr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bmcCertSha256 => $composableBuilder(
    column: $table.bmcCertSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pveAddr => $composableBuilder(
    column: $table.pveAddr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pveIgnoreCert => $composableBuilder(
    column: $table.pveIgnoreCert,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pvePwd => $composableBuilder(
    column: $table.pvePwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferTempDev => $composableBuilder(
    column: $table.preferTempDev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get tempIsCelsius => $composableBuilder(
    column: $table.tempIsCelsius,
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

  $$PrivateKeysTableOrderingComposer get sshKeyId {
    final $$PrivateKeysTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sshKeyId,
      referencedTable: $db.privateKeys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrivateKeysTableOrderingComposer(
            $db: $db,
            $table: $db.privateKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BmcCredentialsTableOrderingComposer get bmcCredId {
    final $$BmcCredentialsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bmcCredId,
      referencedTable: $db.bmcCredentials,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BmcCredentialsTableOrderingComposer(
            $db: $db,
            $table: $db.bmcCredentials,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rev =>
      $composableBuilder(column: $table.rev, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get autoConnect => $composableBuilder(
    column: $table.autoConnect,
    builder: (column) => column,
  );

  GeneratedColumn<String> get systemType => $composableBuilder(
    column: $table.systemType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sshIp =>
      $composableBuilder(column: $table.sshIp, builder: (column) => column);

  GeneratedColumn<int> get sshPort =>
      $composableBuilder(column: $table.sshPort, builder: (column) => column);

  GeneratedColumn<String> get sshUser =>
      $composableBuilder(column: $table.sshUser, builder: (column) => column);

  GeneratedColumn<String> get sshPwd =>
      $composableBuilder(column: $table.sshPwd, builder: (column) => column);

  GeneratedColumn<String> get sshKeyPath => $composableBuilder(
    column: $table.sshKeyPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sshAlterUrl => $composableBuilder(
    column: $table.sshAlterUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sshProxyCommand => $composableBuilder(
    column: $table.sshProxyCommand,
    builder: (column) => column,
  );

  GeneratedColumn<String> get monitorAddr => $composableBuilder(
    column: $table.monitorAddr,
    builder: (column) => column,
  );

  GeneratedColumn<String> get monitorUser => $composableBuilder(
    column: $table.monitorUser,
    builder: (column) => column,
  );

  GeneratedColumn<String> get monitorPwd => $composableBuilder(
    column: $table.monitorPwd,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get monitorIgnoreCert => $composableBuilder(
    column: $table.monitorIgnoreCert,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get monitorAllowInsecure => $composableBuilder(
    column: $table.monitorAllowInsecure,
    builder: (column) => column,
  );

  GeneratedColumn<String> get wolMac =>
      $composableBuilder(column: $table.wolMac, builder: (column) => column);

  GeneratedColumn<String> get wolIp =>
      $composableBuilder(column: $table.wolIp, builder: (column) => column);

  GeneratedColumn<String> get wolPwd =>
      $composableBuilder(column: $table.wolPwd, builder: (column) => column);

  GeneratedColumn<String> get bmcAddr =>
      $composableBuilder(column: $table.bmcAddr, builder: (column) => column);

  GeneratedColumn<String> get bmcCertSha256 => $composableBuilder(
    column: $table.bmcCertSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pveAddr =>
      $composableBuilder(column: $table.pveAddr, builder: (column) => column);

  GeneratedColumn<bool> get pveIgnoreCert => $composableBuilder(
    column: $table.pveIgnoreCert,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pvePwd =>
      $composableBuilder(column: $table.pvePwd, builder: (column) => column);

  GeneratedColumn<String> get preferTempDev => $composableBuilder(
    column: $table.preferTempDev,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get tempIsCelsius => $composableBuilder(
    column: $table.tempIsCelsius,
    builder: (column) => column,
  );

  GeneratedColumn<String> get logoUrl =>
      $composableBuilder(column: $table.logoUrl, builder: (column) => column);

  GeneratedColumn<String> get netDev =>
      $composableBuilder(column: $table.netDev, builder: (column) => column);

  GeneratedColumn<String> get scriptDir =>
      $composableBuilder(column: $table.scriptDir, builder: (column) => column);

  $$PrivateKeysTableAnnotationComposer get sshKeyId {
    final $$PrivateKeysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sshKeyId,
      referencedTable: $db.privateKeys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrivateKeysTableAnnotationComposer(
            $db: $db,
            $table: $db.privateKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BmcCredentialsTableAnnotationComposer get bmcCredId {
    final $$BmcCredentialsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bmcCredId,
      referencedTable: $db.bmcCredentials,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BmcCredentialsTableAnnotationComposer(
            $db: $db,
            $table: $db.bmcCredentials,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
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

  Expression<T> serverDisabledCmdsRefs<T extends Object>(
    Expression<T> Function($$ServerDisabledCmdsTableAnnotationComposer a) f,
  ) {
    final $$ServerDisabledCmdsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.serverDisabledCmds,
          getReferencedColumn: (t) => t.serverId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ServerDisabledCmdsTableAnnotationComposer(
                $db: $db,
                $table: $db.serverDisabledCmds,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> serverCustomCmdsRefs<T extends Object>(
    Expression<T> Function($$ServerCustomCmdsTableAnnotationComposer a) f,
  ) {
    final $$ServerCustomCmdsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serverCustomCmds,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServerCustomCmdsTableAnnotationComposer(
            $db: $db,
            $table: $db.serverCustomCmds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> knownHostsRefs<T extends Object>(
    Expression<T> Function($$KnownHostsTableAnnotationComposer a) f,
  ) {
    final $$KnownHostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.knownHosts,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KnownHostsTableAnnotationComposer(
            $db: $db,
            $table: $db.knownHosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> snippetAutoRunOnRefs<T extends Object>(
    Expression<T> Function($$SnippetAutoRunOnTableAnnotationComposer a) f,
  ) {
    final $$SnippetAutoRunOnTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.snippetAutoRunOn,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnippetAutoRunOnTableAnnotationComposer(
            $db: $db,
            $table: $db.snippetAutoRunOn,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> portForwardsRefs<T extends Object>(
    Expression<T> Function($$PortForwardsTableAnnotationComposer a) f,
  ) {
    final $$PortForwardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.portForwards,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PortForwardsTableAnnotationComposer(
            $db: $db,
            $table: $db.portForwards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> containerHostsRefs<T extends Object>(
    Expression<T> Function($$ContainerHostsTableAnnotationComposer a) f,
  ) {
    final $$ContainerHostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.containerHosts,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContainerHostsTableAnnotationComposer(
            $db: $db,
            $table: $db.containerHosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> containerRuntimesRefs<T extends Object>(
    Expression<T> Function($$ContainerRuntimesTableAnnotationComposer a) f,
  ) {
    final $$ContainerRuntimesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.containerRuntimes,
          getReferencedColumn: (t) => t.serverId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ContainerRuntimesTableAnnotationComposer(
                $db: $db,
                $table: $db.containerRuntimes,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> connStatsRefs<T extends Object>(
    Expression<T> Function($$ConnStatsTableAnnotationComposer a) f,
  ) {
    final $$ConnStatsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.connStats,
      getReferencedColumn: (t) => t.serverId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConnStatsTableAnnotationComposer(
            $db: $db,
            $table: $db.connStats,
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
          ServerRow,
          $$ServersTableFilterComposer,
          $$ServersTableOrderingComposer,
          $$ServersTableAnnotationComposer,
          $$ServersTableCreateCompanionBuilder,
          $$ServersTableUpdateCompanionBuilder,
          (ServerRow, $$ServersTableReferences),
          ServerRow,
          PrefetchHooks Function({
            bool sshKeyId,
            bool bmcCredId,
            bool serverTagsRefs,
            bool serverEnvsRefs,
            bool serverDisabledCmdsRefs,
            bool serverCustomCmdsRefs,
            bool knownHostsRefs,
            bool snippetAutoRunOnRefs,
            bool portForwardsRefs,
            bool containerHostsRefs,
            bool containerRuntimesRefs,
            bool connStatsRefs,
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
                Value<int> updatedAt = const Value.absent(),
                Value<int> rev = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> autoConnect = const Value.absent(),
                Value<String?> systemType = const Value.absent(),
                Value<String?> sshIp = const Value.absent(),
                Value<int?> sshPort = const Value.absent(),
                Value<String?> sshUser = const Value.absent(),
                Value<String?> sshPwd = const Value.absent(),
                Value<String?> sshKeyId = const Value.absent(),
                Value<String?> sshKeyPath = const Value.absent(),
                Value<String?> sshAlterUrl = const Value.absent(),
                Value<String?> sshProxyCommand = const Value.absent(),
                Value<String?> monitorAddr = const Value.absent(),
                Value<String?> monitorUser = const Value.absent(),
                Value<String?> monitorPwd = const Value.absent(),
                Value<bool?> monitorIgnoreCert = const Value.absent(),
                Value<bool?> monitorAllowInsecure = const Value.absent(),
                Value<String?> wolMac = const Value.absent(),
                Value<String?> wolIp = const Value.absent(),
                Value<String?> wolPwd = const Value.absent(),
                Value<String?> bmcAddr = const Value.absent(),
                Value<String?> bmcCertSha256 = const Value.absent(),
                Value<String?> bmcCredId = const Value.absent(),
                Value<String?> pveAddr = const Value.absent(),
                Value<bool> pveIgnoreCert = const Value.absent(),
                Value<String?> pvePwd = const Value.absent(),
                Value<String?> preferTempDev = const Value.absent(),
                Value<bool> tempIsCelsius = const Value.absent(),
                Value<String?> logoUrl = const Value.absent(),
                Value<String?> netDev = const Value.absent(),
                Value<String?> scriptDir = const Value.absent(),
              }) => ServersCompanion(
                updatedAt: updatedAt,
                rev: rev,
                id: id,
                name: name,
                autoConnect: autoConnect,
                systemType: systemType,
                sshIp: sshIp,
                sshPort: sshPort,
                sshUser: sshUser,
                sshPwd: sshPwd,
                sshKeyId: sshKeyId,
                sshKeyPath: sshKeyPath,
                sshAlterUrl: sshAlterUrl,
                sshProxyCommand: sshProxyCommand,
                monitorAddr: monitorAddr,
                monitorUser: monitorUser,
                monitorPwd: monitorPwd,
                monitorIgnoreCert: monitorIgnoreCert,
                monitorAllowInsecure: monitorAllowInsecure,
                wolMac: wolMac,
                wolIp: wolIp,
                wolPwd: wolPwd,
                bmcAddr: bmcAddr,
                bmcCertSha256: bmcCertSha256,
                bmcCredId: bmcCredId,
                pveAddr: pveAddr,
                pveIgnoreCert: pveIgnoreCert,
                pvePwd: pvePwd,
                preferTempDev: preferTempDev,
                tempIsCelsius: tempIsCelsius,
                logoUrl: logoUrl,
                netDev: netDev,
                scriptDir: scriptDir,
              ),
          createCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int> rev = const Value.absent(),
                required String id,
                required String name,
                Value<bool> autoConnect = const Value.absent(),
                Value<String?> systemType = const Value.absent(),
                Value<String?> sshIp = const Value.absent(),
                Value<int?> sshPort = const Value.absent(),
                Value<String?> sshUser = const Value.absent(),
                Value<String?> sshPwd = const Value.absent(),
                Value<String?> sshKeyId = const Value.absent(),
                Value<String?> sshKeyPath = const Value.absent(),
                Value<String?> sshAlterUrl = const Value.absent(),
                Value<String?> sshProxyCommand = const Value.absent(),
                Value<String?> monitorAddr = const Value.absent(),
                Value<String?> monitorUser = const Value.absent(),
                Value<String?> monitorPwd = const Value.absent(),
                Value<bool?> monitorIgnoreCert = const Value.absent(),
                Value<bool?> monitorAllowInsecure = const Value.absent(),
                Value<String?> wolMac = const Value.absent(),
                Value<String?> wolIp = const Value.absent(),
                Value<String?> wolPwd = const Value.absent(),
                Value<String?> bmcAddr = const Value.absent(),
                Value<String?> bmcCertSha256 = const Value.absent(),
                Value<String?> bmcCredId = const Value.absent(),
                Value<String?> pveAddr = const Value.absent(),
                Value<bool> pveIgnoreCert = const Value.absent(),
                Value<String?> pvePwd = const Value.absent(),
                Value<String?> preferTempDev = const Value.absent(),
                Value<bool> tempIsCelsius = const Value.absent(),
                Value<String?> logoUrl = const Value.absent(),
                Value<String?> netDev = const Value.absent(),
                Value<String?> scriptDir = const Value.absent(),
              }) => ServersCompanion.insert(
                updatedAt: updatedAt,
                rev: rev,
                id: id,
                name: name,
                autoConnect: autoConnect,
                systemType: systemType,
                sshIp: sshIp,
                sshPort: sshPort,
                sshUser: sshUser,
                sshPwd: sshPwd,
                sshKeyId: sshKeyId,
                sshKeyPath: sshKeyPath,
                sshAlterUrl: sshAlterUrl,
                sshProxyCommand: sshProxyCommand,
                monitorAddr: monitorAddr,
                monitorUser: monitorUser,
                monitorPwd: monitorPwd,
                monitorIgnoreCert: monitorIgnoreCert,
                monitorAllowInsecure: monitorAllowInsecure,
                wolMac: wolMac,
                wolIp: wolIp,
                wolPwd: wolPwd,
                bmcAddr: bmcAddr,
                bmcCertSha256: bmcCertSha256,
                bmcCredId: bmcCredId,
                pveAddr: pveAddr,
                pveIgnoreCert: pveIgnoreCert,
                pvePwd: pvePwd,
                preferTempDev: preferTempDev,
                tempIsCelsius: tempIsCelsius,
                logoUrl: logoUrl,
                netDev: netDev,
                scriptDir: scriptDir,
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
                sshKeyId = false,
                bmcCredId = false,
                serverTagsRefs = false,
                serverEnvsRefs = false,
                serverDisabledCmdsRefs = false,
                serverCustomCmdsRefs = false,
                knownHostsRefs = false,
                snippetAutoRunOnRefs = false,
                portForwardsRefs = false,
                containerHostsRefs = false,
                containerRuntimesRefs = false,
                connStatsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (serverTagsRefs) db.serverTags,
                    if (serverEnvsRefs) db.serverEnvs,
                    if (serverDisabledCmdsRefs) db.serverDisabledCmds,
                    if (serverCustomCmdsRefs) db.serverCustomCmds,
                    if (knownHostsRefs) db.knownHosts,
                    if (snippetAutoRunOnRefs) db.snippetAutoRunOn,
                    if (portForwardsRefs) db.portForwards,
                    if (containerHostsRefs) db.containerHosts,
                    if (containerRuntimesRefs) db.containerRuntimes,
                    if (connStatsRefs) db.connStats,
                  ],
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
                        if (sshKeyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sshKeyId,
                                    referencedTable: $$ServersTableReferences
                                        ._sshKeyIdTable(db),
                                    referencedColumn: $$ServersTableReferences
                                        ._sshKeyIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (bmcCredId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.bmcCredId,
                                    referencedTable: $$ServersTableReferences
                                        ._bmcCredIdTable(db),
                                    referencedColumn: $$ServersTableReferences
                                        ._bmcCredIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (serverTagsRefs)
                        await $_getPrefetchedData<
                          ServerRow,
                          $ServersTable,
                          ServerTagRow
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
                          ServerRow,
                          $ServersTable,
                          ServerEnvRow
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
                      if (serverDisabledCmdsRefs)
                        await $_getPrefetchedData<
                          ServerRow,
                          $ServersTable,
                          ServerDisabledCmdRow
                        >(
                          currentTable: table,
                          referencedTable: $$ServersTableReferences
                              ._serverDisabledCmdsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ServersTableReferences(
                                db,
                                table,
                                p0,
                              ).serverDisabledCmdsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.serverId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (serverCustomCmdsRefs)
                        await $_getPrefetchedData<
                          ServerRow,
                          $ServersTable,
                          ServerCustomCmdRow
                        >(
                          currentTable: table,
                          referencedTable: $$ServersTableReferences
                              ._serverCustomCmdsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ServersTableReferences(
                                db,
                                table,
                                p0,
                              ).serverCustomCmdsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.serverId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (knownHostsRefs)
                        await $_getPrefetchedData<
                          ServerRow,
                          $ServersTable,
                          KnownHostRow
                        >(
                          currentTable: table,
                          referencedTable: $$ServersTableReferences
                              ._knownHostsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ServersTableReferences(
                                db,
                                table,
                                p0,
                              ).knownHostsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.serverId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (snippetAutoRunOnRefs)
                        await $_getPrefetchedData<
                          ServerRow,
                          $ServersTable,
                          SnippetAutoRunRow
                        >(
                          currentTable: table,
                          referencedTable: $$ServersTableReferences
                              ._snippetAutoRunOnRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ServersTableReferences(
                                db,
                                table,
                                p0,
                              ).snippetAutoRunOnRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.serverId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (portForwardsRefs)
                        await $_getPrefetchedData<
                          ServerRow,
                          $ServersTable,
                          PortForwardRow
                        >(
                          currentTable: table,
                          referencedTable: $$ServersTableReferences
                              ._portForwardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ServersTableReferences(
                                db,
                                table,
                                p0,
                              ).portForwardsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.serverId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (containerHostsRefs)
                        await $_getPrefetchedData<
                          ServerRow,
                          $ServersTable,
                          ContainerHostRow
                        >(
                          currentTable: table,
                          referencedTable: $$ServersTableReferences
                              ._containerHostsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ServersTableReferences(
                                db,
                                table,
                                p0,
                              ).containerHostsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.serverId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (containerRuntimesRefs)
                        await $_getPrefetchedData<
                          ServerRow,
                          $ServersTable,
                          ContainerRuntimeRow
                        >(
                          currentTable: table,
                          referencedTable: $$ServersTableReferences
                              ._containerRuntimesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ServersTableReferences(
                                db,
                                table,
                                p0,
                              ).containerRuntimesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.serverId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (connStatsRefs)
                        await $_getPrefetchedData<
                          ServerRow,
                          $ServersTable,
                          ConnStatRow
                        >(
                          currentTable: table,
                          referencedTable: $$ServersTableReferences
                              ._connStatsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ServersTableReferences(
                                db,
                                table,
                                p0,
                              ).connStatsRefs,
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
      ServerRow,
      $$ServersTableFilterComposer,
      $$ServersTableOrderingComposer,
      $$ServersTableAnnotationComposer,
      $$ServersTableCreateCompanionBuilder,
      $$ServersTableUpdateCompanionBuilder,
      (ServerRow, $$ServersTableReferences),
      ServerRow,
      PrefetchHooks Function({
        bool sshKeyId,
        bool bmcCredId,
        bool serverTagsRefs,
        bool serverEnvsRefs,
        bool serverDisabledCmdsRefs,
        bool serverCustomCmdsRefs,
        bool knownHostsRefs,
        bool snippetAutoRunOnRefs,
        bool portForwardsRefs,
        bool containerHostsRefs,
        bool containerRuntimesRefs,
        bool connStatsRefs,
      })
    >;
typedef $$ServerTagsTableCreateCompanionBuilder =
    ServerTagsCompanion Function({
      required String serverId,
      required String tag,
    });
typedef $$ServerTagsTableUpdateCompanionBuilder =
    ServerTagsCompanion Function({Value<String> serverId, Value<String> tag});

final class $$ServerTagsTableReferences
    extends BaseReferences<_$AppDb, $ServerTagsTable, ServerTagRow> {
  $$ServerTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ServersTable _serverIdTable(_$AppDb db) =>
      db.servers.createAlias('server_tag__server_id__server__id');

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
          ServerTagRow,
          $$ServerTagsTableFilterComposer,
          $$ServerTagsTableOrderingComposer,
          $$ServerTagsTableAnnotationComposer,
          $$ServerTagsTableCreateCompanionBuilder,
          $$ServerTagsTableUpdateCompanionBuilder,
          (ServerTagRow, $$ServerTagsTableReferences),
          ServerTagRow,
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
              }) => ServerTagsCompanion(serverId: serverId, tag: tag),
          createCompanionCallback:
              ({required String serverId, required String tag}) =>
                  ServerTagsCompanion.insert(serverId: serverId, tag: tag),
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
      ServerTagRow,
      $$ServerTagsTableFilterComposer,
      $$ServerTagsTableOrderingComposer,
      $$ServerTagsTableAnnotationComposer,
      $$ServerTagsTableCreateCompanionBuilder,
      $$ServerTagsTableUpdateCompanionBuilder,
      (ServerTagRow, $$ServerTagsTableReferences),
      ServerTagRow,
      PrefetchHooks Function({bool serverId})
    >;
typedef $$ServerEnvsTableCreateCompanionBuilder =
    ServerEnvsCompanion Function({
      required String serverId,
      required String key,
      required String value,
    });
typedef $$ServerEnvsTableUpdateCompanionBuilder =
    ServerEnvsCompanion Function({
      Value<String> serverId,
      Value<String> key,
      Value<String> value,
    });

final class $$ServerEnvsTableReferences
    extends BaseReferences<_$AppDb, $ServerEnvsTable, ServerEnvRow> {
  $$ServerEnvsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ServersTable _serverIdTable(_$AppDb db) =>
      db.servers.createAlias('server_env__server_id__server__id');

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
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
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
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
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
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

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
          ServerEnvRow,
          $$ServerEnvsTableFilterComposer,
          $$ServerEnvsTableOrderingComposer,
          $$ServerEnvsTableAnnotationComposer,
          $$ServerEnvsTableCreateCompanionBuilder,
          $$ServerEnvsTableUpdateCompanionBuilder,
          (ServerEnvRow, $$ServerEnvsTableReferences),
          ServerEnvRow,
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
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
              }) => ServerEnvsCompanion(
                serverId: serverId,
                key: key,
                value: value,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String key,
                required String value,
              }) => ServerEnvsCompanion.insert(
                serverId: serverId,
                key: key,
                value: value,
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
      ServerEnvRow,
      $$ServerEnvsTableFilterComposer,
      $$ServerEnvsTableOrderingComposer,
      $$ServerEnvsTableAnnotationComposer,
      $$ServerEnvsTableCreateCompanionBuilder,
      $$ServerEnvsTableUpdateCompanionBuilder,
      (ServerEnvRow, $$ServerEnvsTableReferences),
      ServerEnvRow,
      PrefetchHooks Function({bool serverId})
    >;
typedef $$ServerJumpsTableCreateCompanionBuilder =
    ServerJumpsCompanion Function({
      required String serverId,
      required int ord,
      required String jumpId,
    });
typedef $$ServerJumpsTableUpdateCompanionBuilder =
    ServerJumpsCompanion Function({
      Value<String> serverId,
      Value<int> ord,
      Value<String> jumpId,
    });

final class $$ServerJumpsTableReferences
    extends BaseReferences<_$AppDb, $ServerJumpsTable, ServerJumpRow> {
  $$ServerJumpsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ServersTable _serverIdTable(_$AppDb db) =>
      db.servers.createAlias('server_jump__server_id__server__id');

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

  static $ServersTable _jumpIdTable(_$AppDb db) =>
      db.servers.createAlias('server_jump__jump_id__server__id');

  $$ServersTableProcessedTableManager get jumpId {
    final $_column = $_itemColumn<String>('jump_id')!;

    final manager = $$ServersTableTableManager(
      $_db,
      $_db.servers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_jumpIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ServerJumpsTableFilterComposer
    extends Composer<_$AppDb, $ServerJumpsTable> {
  $$ServerJumpsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get ord => $composableBuilder(
    column: $table.ord,
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

  $$ServersTableFilterComposer get jumpId {
    final $$ServersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.jumpId,
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

class $$ServerJumpsTableOrderingComposer
    extends Composer<_$AppDb, $ServerJumpsTable> {
  $$ServerJumpsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get ord => $composableBuilder(
    column: $table.ord,
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

  $$ServersTableOrderingComposer get jumpId {
    final $$ServersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.jumpId,
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

class $$ServerJumpsTableAnnotationComposer
    extends Composer<_$AppDb, $ServerJumpsTable> {
  $$ServerJumpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get ord =>
      $composableBuilder(column: $table.ord, builder: (column) => column);

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

  $$ServersTableAnnotationComposer get jumpId {
    final $$ServersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.jumpId,
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

class $$ServerJumpsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ServerJumpsTable,
          ServerJumpRow,
          $$ServerJumpsTableFilterComposer,
          $$ServerJumpsTableOrderingComposer,
          $$ServerJumpsTableAnnotationComposer,
          $$ServerJumpsTableCreateCompanionBuilder,
          $$ServerJumpsTableUpdateCompanionBuilder,
          (ServerJumpRow, $$ServerJumpsTableReferences),
          ServerJumpRow,
          PrefetchHooks Function({bool serverId, bool jumpId})
        > {
  $$ServerJumpsTableTableManager(_$AppDb db, $ServerJumpsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServerJumpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServerJumpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServerJumpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<int> ord = const Value.absent(),
                Value<String> jumpId = const Value.absent(),
              }) => ServerJumpsCompanion(
                serverId: serverId,
                ord: ord,
                jumpId: jumpId,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required int ord,
                required String jumpId,
              }) => ServerJumpsCompanion.insert(
                serverId: serverId,
                ord: ord,
                jumpId: jumpId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ServerJumpsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({serverId = false, jumpId = false}) {
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
                                referencedTable: $$ServerJumpsTableReferences
                                    ._serverIdTable(db),
                                referencedColumn: $$ServerJumpsTableReferences
                                    ._serverIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (jumpId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.jumpId,
                                referencedTable: $$ServerJumpsTableReferences
                                    ._jumpIdTable(db),
                                referencedColumn: $$ServerJumpsTableReferences
                                    ._jumpIdTable(db)
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

typedef $$ServerJumpsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ServerJumpsTable,
      ServerJumpRow,
      $$ServerJumpsTableFilterComposer,
      $$ServerJumpsTableOrderingComposer,
      $$ServerJumpsTableAnnotationComposer,
      $$ServerJumpsTableCreateCompanionBuilder,
      $$ServerJumpsTableUpdateCompanionBuilder,
      (ServerJumpRow, $$ServerJumpsTableReferences),
      ServerJumpRow,
      PrefetchHooks Function({bool serverId, bool jumpId})
    >;
typedef $$ServerDisabledCmdsTableCreateCompanionBuilder =
    ServerDisabledCmdsCompanion Function({
      required String serverId,
      required String cmdType,
    });
typedef $$ServerDisabledCmdsTableUpdateCompanionBuilder =
    ServerDisabledCmdsCompanion Function({
      Value<String> serverId,
      Value<String> cmdType,
    });

final class $$ServerDisabledCmdsTableReferences
    extends
        BaseReferences<
          _$AppDb,
          $ServerDisabledCmdsTable,
          ServerDisabledCmdRow
        > {
  $$ServerDisabledCmdsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ServersTable _serverIdTable(_$AppDb db) =>
      db.servers.createAlias('server_disabled_cmd__server_id__server__id');

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

class $$ServerDisabledCmdsTableFilterComposer
    extends Composer<_$AppDb, $ServerDisabledCmdsTable> {
  $$ServerDisabledCmdsTableFilterComposer({
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

class $$ServerDisabledCmdsTableOrderingComposer
    extends Composer<_$AppDb, $ServerDisabledCmdsTable> {
  $$ServerDisabledCmdsTableOrderingComposer({
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

class $$ServerDisabledCmdsTableAnnotationComposer
    extends Composer<_$AppDb, $ServerDisabledCmdsTable> {
  $$ServerDisabledCmdsTableAnnotationComposer({
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

class $$ServerDisabledCmdsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ServerDisabledCmdsTable,
          ServerDisabledCmdRow,
          $$ServerDisabledCmdsTableFilterComposer,
          $$ServerDisabledCmdsTableOrderingComposer,
          $$ServerDisabledCmdsTableAnnotationComposer,
          $$ServerDisabledCmdsTableCreateCompanionBuilder,
          $$ServerDisabledCmdsTableUpdateCompanionBuilder,
          (ServerDisabledCmdRow, $$ServerDisabledCmdsTableReferences),
          ServerDisabledCmdRow,
          PrefetchHooks Function({bool serverId})
        > {
  $$ServerDisabledCmdsTableTableManager(
    _$AppDb db,
    $ServerDisabledCmdsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServerDisabledCmdsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServerDisabledCmdsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServerDisabledCmdsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> cmdType = const Value.absent(),
              }) => ServerDisabledCmdsCompanion(
                serverId: serverId,
                cmdType: cmdType,
              ),
          createCompanionCallback:
              ({required String serverId, required String cmdType}) =>
                  ServerDisabledCmdsCompanion.insert(
                    serverId: serverId,
                    cmdType: cmdType,
                  ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ServerDisabledCmdsTableReferences(db, table, e),
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
                                    $$ServerDisabledCmdsTableReferences
                                        ._serverIdTable(db),
                                referencedColumn:
                                    $$ServerDisabledCmdsTableReferences
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

typedef $$ServerDisabledCmdsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ServerDisabledCmdsTable,
      ServerDisabledCmdRow,
      $$ServerDisabledCmdsTableFilterComposer,
      $$ServerDisabledCmdsTableOrderingComposer,
      $$ServerDisabledCmdsTableAnnotationComposer,
      $$ServerDisabledCmdsTableCreateCompanionBuilder,
      $$ServerDisabledCmdsTableUpdateCompanionBuilder,
      (ServerDisabledCmdRow, $$ServerDisabledCmdsTableReferences),
      ServerDisabledCmdRow,
      PrefetchHooks Function({bool serverId})
    >;
typedef $$ServerCustomCmdsTableCreateCompanionBuilder =
    ServerCustomCmdsCompanion Function({
      required String serverId,
      required String name,
      required String cmd,
    });
typedef $$ServerCustomCmdsTableUpdateCompanionBuilder =
    ServerCustomCmdsCompanion Function({
      Value<String> serverId,
      Value<String> name,
      Value<String> cmd,
    });

final class $$ServerCustomCmdsTableReferences
    extends
        BaseReferences<_$AppDb, $ServerCustomCmdsTable, ServerCustomCmdRow> {
  $$ServerCustomCmdsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ServersTable _serverIdTable(_$AppDb db) =>
      db.servers.createAlias('server_custom_cmd__server_id__server__id');

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

class $$ServerCustomCmdsTableFilterComposer
    extends Composer<_$AppDb, $ServerCustomCmdsTable> {
  $$ServerCustomCmdsTableFilterComposer({
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

  ColumnFilters<String> get cmd => $composableBuilder(
    column: $table.cmd,
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

class $$ServerCustomCmdsTableOrderingComposer
    extends Composer<_$AppDb, $ServerCustomCmdsTable> {
  $$ServerCustomCmdsTableOrderingComposer({
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

  ColumnOrderings<String> get cmd => $composableBuilder(
    column: $table.cmd,
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

class $$ServerCustomCmdsTableAnnotationComposer
    extends Composer<_$AppDb, $ServerCustomCmdsTable> {
  $$ServerCustomCmdsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get cmd =>
      $composableBuilder(column: $table.cmd, builder: (column) => column);

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

class $$ServerCustomCmdsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ServerCustomCmdsTable,
          ServerCustomCmdRow,
          $$ServerCustomCmdsTableFilterComposer,
          $$ServerCustomCmdsTableOrderingComposer,
          $$ServerCustomCmdsTableAnnotationComposer,
          $$ServerCustomCmdsTableCreateCompanionBuilder,
          $$ServerCustomCmdsTableUpdateCompanionBuilder,
          (ServerCustomCmdRow, $$ServerCustomCmdsTableReferences),
          ServerCustomCmdRow,
          PrefetchHooks Function({bool serverId})
        > {
  $$ServerCustomCmdsTableTableManager(_$AppDb db, $ServerCustomCmdsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServerCustomCmdsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServerCustomCmdsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServerCustomCmdsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> cmd = const Value.absent(),
              }) => ServerCustomCmdsCompanion(
                serverId: serverId,
                name: name,
                cmd: cmd,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String name,
                required String cmd,
              }) => ServerCustomCmdsCompanion.insert(
                serverId: serverId,
                name: name,
                cmd: cmd,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ServerCustomCmdsTableReferences(db, table, e),
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
                                    $$ServerCustomCmdsTableReferences
                                        ._serverIdTable(db),
                                referencedColumn:
                                    $$ServerCustomCmdsTableReferences
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

typedef $$ServerCustomCmdsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ServerCustomCmdsTable,
      ServerCustomCmdRow,
      $$ServerCustomCmdsTableFilterComposer,
      $$ServerCustomCmdsTableOrderingComposer,
      $$ServerCustomCmdsTableAnnotationComposer,
      $$ServerCustomCmdsTableCreateCompanionBuilder,
      $$ServerCustomCmdsTableUpdateCompanionBuilder,
      (ServerCustomCmdRow, $$ServerCustomCmdsTableReferences),
      ServerCustomCmdRow,
      PrefetchHooks Function({bool serverId})
    >;
typedef $$KnownHostsTableCreateCompanionBuilder =
    KnownHostsCompanion Function({
      required String serverId,
      required String keyType,
      required String fingerprint,
    });
typedef $$KnownHostsTableUpdateCompanionBuilder =
    KnownHostsCompanion Function({
      Value<String> serverId,
      Value<String> keyType,
      Value<String> fingerprint,
    });

final class $$KnownHostsTableReferences
    extends BaseReferences<_$AppDb, $KnownHostsTable, KnownHostRow> {
  $$KnownHostsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ServersTable _serverIdTable(_$AppDb db) =>
      db.servers.createAlias('known_host__server_id__server__id');

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

class $$KnownHostsTableFilterComposer
    extends Composer<_$AppDb, $KnownHostsTable> {
  $$KnownHostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get keyType => $composableBuilder(
    column: $table.keyType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
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

class $$KnownHostsTableOrderingComposer
    extends Composer<_$AppDb, $KnownHostsTable> {
  $$KnownHostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get keyType => $composableBuilder(
    column: $table.keyType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
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

class $$KnownHostsTableAnnotationComposer
    extends Composer<_$AppDb, $KnownHostsTable> {
  $$KnownHostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get keyType =>
      $composableBuilder(column: $table.keyType, builder: (column) => column);

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

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

class $$KnownHostsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $KnownHostsTable,
          KnownHostRow,
          $$KnownHostsTableFilterComposer,
          $$KnownHostsTableOrderingComposer,
          $$KnownHostsTableAnnotationComposer,
          $$KnownHostsTableCreateCompanionBuilder,
          $$KnownHostsTableUpdateCompanionBuilder,
          (KnownHostRow, $$KnownHostsTableReferences),
          KnownHostRow,
          PrefetchHooks Function({bool serverId})
        > {
  $$KnownHostsTableTableManager(_$AppDb db, $KnownHostsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KnownHostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KnownHostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KnownHostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> keyType = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
              }) => KnownHostsCompanion(
                serverId: serverId,
                keyType: keyType,
                fingerprint: fingerprint,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String keyType,
                required String fingerprint,
              }) => KnownHostsCompanion.insert(
                serverId: serverId,
                keyType: keyType,
                fingerprint: fingerprint,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$KnownHostsTableReferences(db, table, e),
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
                                referencedTable: $$KnownHostsTableReferences
                                    ._serverIdTable(db),
                                referencedColumn: $$KnownHostsTableReferences
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

typedef $$KnownHostsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $KnownHostsTable,
      KnownHostRow,
      $$KnownHostsTableFilterComposer,
      $$KnownHostsTableOrderingComposer,
      $$KnownHostsTableAnnotationComposer,
      $$KnownHostsTableCreateCompanionBuilder,
      $$KnownHostsTableUpdateCompanionBuilder,
      (KnownHostRow, $$KnownHostsTableReferences),
      KnownHostRow,
      PrefetchHooks Function({bool serverId})
    >;
typedef $$SnippetsTableCreateCompanionBuilder =
    SnippetsCompanion Function({
      Value<int> updatedAt,
      Value<int> rev,
      required String id,
      required String name,
      required String script,
      Value<String?> note,
    });
typedef $$SnippetsTableUpdateCompanionBuilder =
    SnippetsCompanion Function({
      Value<int> updatedAt,
      Value<int> rev,
      Value<String> id,
      Value<String> name,
      Value<String> script,
      Value<String?> note,
    });

final class $$SnippetsTableReferences
    extends BaseReferences<_$AppDb, $SnippetsTable, SnippetRow> {
  $$SnippetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SnippetTagsTable, List<SnippetTagRow>>
  _snippetTagsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.snippetTags,
    aliasName: 'snippet__id__snippet_tag__snippet_id',
  );

  $$SnippetTagsTableProcessedTableManager get snippetTagsRefs {
    final manager = $$SnippetTagsTableTableManager(
      $_db,
      $_db.snippetTags,
    ).filter((f) => f.snippetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_snippetTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SnippetAutoRunOnTable, List<SnippetAutoRunRow>>
  _snippetAutoRunOnRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.snippetAutoRunOn,
    aliasName: 'snippet__id__snippet_auto_run_on__snippet_id',
  );

  $$SnippetAutoRunOnTableProcessedTableManager get snippetAutoRunOnRefs {
    final manager = $$SnippetAutoRunOnTableTableManager(
      $_db,
      $_db.snippetAutoRunOn,
    ).filter((f) => f.snippetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _snippetAutoRunOnRefsTable($_db),
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
  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

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

  Expression<bool> snippetTagsRefs(
    Expression<bool> Function($$SnippetTagsTableFilterComposer f) f,
  ) {
    final $$SnippetTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.snippetTags,
      getReferencedColumn: (t) => t.snippetId,
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

  Expression<bool> snippetAutoRunOnRefs(
    Expression<bool> Function($$SnippetAutoRunOnTableFilterComposer f) f,
  ) {
    final $$SnippetAutoRunOnTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.snippetAutoRunOn,
      getReferencedColumn: (t) => t.snippetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnippetAutoRunOnTableFilterComposer(
            $db: $db,
            $table: $db.snippetAutoRunOn,
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
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

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
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rev =>
      $composableBuilder(column: $table.rev, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get script =>
      $composableBuilder(column: $table.script, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  Expression<T> snippetTagsRefs<T extends Object>(
    Expression<T> Function($$SnippetTagsTableAnnotationComposer a) f,
  ) {
    final $$SnippetTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.snippetTags,
      getReferencedColumn: (t) => t.snippetId,
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

  Expression<T> snippetAutoRunOnRefs<T extends Object>(
    Expression<T> Function($$SnippetAutoRunOnTableAnnotationComposer a) f,
  ) {
    final $$SnippetAutoRunOnTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.snippetAutoRunOn,
      getReferencedColumn: (t) => t.snippetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnippetAutoRunOnTableAnnotationComposer(
            $db: $db,
            $table: $db.snippetAutoRunOn,
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
          SnippetRow,
          $$SnippetsTableFilterComposer,
          $$SnippetsTableOrderingComposer,
          $$SnippetsTableAnnotationComposer,
          $$SnippetsTableCreateCompanionBuilder,
          $$SnippetsTableUpdateCompanionBuilder,
          (SnippetRow, $$SnippetsTableReferences),
          SnippetRow,
          PrefetchHooks Function({
            bool snippetTagsRefs,
            bool snippetAutoRunOnRefs,
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
                Value<int> updatedAt = const Value.absent(),
                Value<int> rev = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> script = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => SnippetsCompanion(
                updatedAt: updatedAt,
                rev: rev,
                id: id,
                name: name,
                script: script,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int> rev = const Value.absent(),
                required String id,
                required String name,
                required String script,
                Value<String?> note = const Value.absent(),
              }) => SnippetsCompanion.insert(
                updatedAt: updatedAt,
                rev: rev,
                id: id,
                name: name,
                script: script,
                note: note,
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
              ({snippetTagsRefs = false, snippetAutoRunOnRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (snippetTagsRefs) db.snippetTags,
                    if (snippetAutoRunOnRefs) db.snippetAutoRunOn,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (snippetTagsRefs)
                        await $_getPrefetchedData<
                          SnippetRow,
                          $SnippetsTable,
                          SnippetTagRow
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
                                (e) => e.snippetId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (snippetAutoRunOnRefs)
                        await $_getPrefetchedData<
                          SnippetRow,
                          $SnippetsTable,
                          SnippetAutoRunRow
                        >(
                          currentTable: table,
                          referencedTable: $$SnippetsTableReferences
                              ._snippetAutoRunOnRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SnippetsTableReferences(
                                db,
                                table,
                                p0,
                              ).snippetAutoRunOnRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.snippetId == item.id,
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
      SnippetRow,
      $$SnippetsTableFilterComposer,
      $$SnippetsTableOrderingComposer,
      $$SnippetsTableAnnotationComposer,
      $$SnippetsTableCreateCompanionBuilder,
      $$SnippetsTableUpdateCompanionBuilder,
      (SnippetRow, $$SnippetsTableReferences),
      SnippetRow,
      PrefetchHooks Function({bool snippetTagsRefs, bool snippetAutoRunOnRefs})
    >;
typedef $$SnippetTagsTableCreateCompanionBuilder =
    SnippetTagsCompanion Function({
      required String snippetId,
      required String tag,
    });
typedef $$SnippetTagsTableUpdateCompanionBuilder =
    SnippetTagsCompanion Function({Value<String> snippetId, Value<String> tag});

final class $$SnippetTagsTableReferences
    extends BaseReferences<_$AppDb, $SnippetTagsTable, SnippetTagRow> {
  $$SnippetTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SnippetsTable _snippetIdTable(_$AppDb db) =>
      db.snippets.createAlias('snippet_tag__snippet_id__snippet__id');

  $$SnippetsTableProcessedTableManager get snippetId {
    final $_column = $_itemColumn<String>('snippet_id')!;

    final manager = $$SnippetsTableTableManager(
      $_db,
      $_db.snippets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_snippetIdTable($_db));
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

  $$SnippetsTableFilterComposer get snippetId {
    final $$SnippetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snippetId,
      referencedTable: $db.snippets,
      getReferencedColumn: (t) => t.id,
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

  $$SnippetsTableOrderingComposer get snippetId {
    final $$SnippetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snippetId,
      referencedTable: $db.snippets,
      getReferencedColumn: (t) => t.id,
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

  $$SnippetsTableAnnotationComposer get snippetId {
    final $$SnippetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snippetId,
      referencedTable: $db.snippets,
      getReferencedColumn: (t) => t.id,
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
          SnippetTagRow,
          $$SnippetTagsTableFilterComposer,
          $$SnippetTagsTableOrderingComposer,
          $$SnippetTagsTableAnnotationComposer,
          $$SnippetTagsTableCreateCompanionBuilder,
          $$SnippetTagsTableUpdateCompanionBuilder,
          (SnippetTagRow, $$SnippetTagsTableReferences),
          SnippetTagRow,
          PrefetchHooks Function({bool snippetId})
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
                Value<String> snippetId = const Value.absent(),
                Value<String> tag = const Value.absent(),
              }) => SnippetTagsCompanion(snippetId: snippetId, tag: tag),
          createCompanionCallback:
              ({required String snippetId, required String tag}) =>
                  SnippetTagsCompanion.insert(snippetId: snippetId, tag: tag),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SnippetTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({snippetId = false}) {
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
                    if (snippetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.snippetId,
                                referencedTable: $$SnippetTagsTableReferences
                                    ._snippetIdTable(db),
                                referencedColumn: $$SnippetTagsTableReferences
                                    ._snippetIdTable(db)
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

typedef $$SnippetTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SnippetTagsTable,
      SnippetTagRow,
      $$SnippetTagsTableFilterComposer,
      $$SnippetTagsTableOrderingComposer,
      $$SnippetTagsTableAnnotationComposer,
      $$SnippetTagsTableCreateCompanionBuilder,
      $$SnippetTagsTableUpdateCompanionBuilder,
      (SnippetTagRow, $$SnippetTagsTableReferences),
      SnippetTagRow,
      PrefetchHooks Function({bool snippetId})
    >;
typedef $$SnippetAutoRunOnTableCreateCompanionBuilder =
    SnippetAutoRunOnCompanion Function({
      required String snippetId,
      required String serverId,
    });
typedef $$SnippetAutoRunOnTableUpdateCompanionBuilder =
    SnippetAutoRunOnCompanion Function({
      Value<String> snippetId,
      Value<String> serverId,
    });

final class $$SnippetAutoRunOnTableReferences
    extends BaseReferences<_$AppDb, $SnippetAutoRunOnTable, SnippetAutoRunRow> {
  $$SnippetAutoRunOnTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SnippetsTable _snippetIdTable(_$AppDb db) =>
      db.snippets.createAlias('snippet_auto_run_on__snippet_id__snippet__id');

  $$SnippetsTableProcessedTableManager get snippetId {
    final $_column = $_itemColumn<String>('snippet_id')!;

    final manager = $$SnippetsTableTableManager(
      $_db,
      $_db.snippets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_snippetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ServersTable _serverIdTable(_$AppDb db) =>
      db.servers.createAlias('snippet_auto_run_on__server_id__server__id');

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

class $$SnippetAutoRunOnTableFilterComposer
    extends Composer<_$AppDb, $SnippetAutoRunOnTable> {
  $$SnippetAutoRunOnTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SnippetsTableFilterComposer get snippetId {
    final $$SnippetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snippetId,
      referencedTable: $db.snippets,
      getReferencedColumn: (t) => t.id,
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

class $$SnippetAutoRunOnTableOrderingComposer
    extends Composer<_$AppDb, $SnippetAutoRunOnTable> {
  $$SnippetAutoRunOnTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SnippetsTableOrderingComposer get snippetId {
    final $$SnippetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snippetId,
      referencedTable: $db.snippets,
      getReferencedColumn: (t) => t.id,
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

class $$SnippetAutoRunOnTableAnnotationComposer
    extends Composer<_$AppDb, $SnippetAutoRunOnTable> {
  $$SnippetAutoRunOnTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SnippetsTableAnnotationComposer get snippetId {
    final $$SnippetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snippetId,
      referencedTable: $db.snippets,
      getReferencedColumn: (t) => t.id,
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

class $$SnippetAutoRunOnTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SnippetAutoRunOnTable,
          SnippetAutoRunRow,
          $$SnippetAutoRunOnTableFilterComposer,
          $$SnippetAutoRunOnTableOrderingComposer,
          $$SnippetAutoRunOnTableAnnotationComposer,
          $$SnippetAutoRunOnTableCreateCompanionBuilder,
          $$SnippetAutoRunOnTableUpdateCompanionBuilder,
          (SnippetAutoRunRow, $$SnippetAutoRunOnTableReferences),
          SnippetAutoRunRow,
          PrefetchHooks Function({bool snippetId, bool serverId})
        > {
  $$SnippetAutoRunOnTableTableManager(_$AppDb db, $SnippetAutoRunOnTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnippetAutoRunOnTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnippetAutoRunOnTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SnippetAutoRunOnTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> snippetId = const Value.absent(),
                Value<String> serverId = const Value.absent(),
              }) => SnippetAutoRunOnCompanion(
                snippetId: snippetId,
                serverId: serverId,
              ),
          createCompanionCallback:
              ({required String snippetId, required String serverId}) =>
                  SnippetAutoRunOnCompanion.insert(
                    snippetId: snippetId,
                    serverId: serverId,
                  ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SnippetAutoRunOnTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({snippetId = false, serverId = false}) {
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
                    if (snippetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.snippetId,
                                referencedTable:
                                    $$SnippetAutoRunOnTableReferences
                                        ._snippetIdTable(db),
                                referencedColumn:
                                    $$SnippetAutoRunOnTableReferences
                                        ._snippetIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (serverId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.serverId,
                                referencedTable:
                                    $$SnippetAutoRunOnTableReferences
                                        ._serverIdTable(db),
                                referencedColumn:
                                    $$SnippetAutoRunOnTableReferences
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

typedef $$SnippetAutoRunOnTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SnippetAutoRunOnTable,
      SnippetAutoRunRow,
      $$SnippetAutoRunOnTableFilterComposer,
      $$SnippetAutoRunOnTableOrderingComposer,
      $$SnippetAutoRunOnTableAnnotationComposer,
      $$SnippetAutoRunOnTableCreateCompanionBuilder,
      $$SnippetAutoRunOnTableUpdateCompanionBuilder,
      (SnippetAutoRunRow, $$SnippetAutoRunOnTableReferences),
      SnippetAutoRunRow,
      PrefetchHooks Function({bool snippetId, bool serverId})
    >;
typedef $$PortForwardsTableCreateCompanionBuilder =
    PortForwardsCompanion Function({
      Value<int> updatedAt,
      Value<int> rev,
      required String id,
      required String serverId,
      required String name,
      required String type,
      Value<String?> localHost,
      Value<int> localPort,
      Value<String?> remoteHost,
      Value<int?> remotePort,
    });
typedef $$PortForwardsTableUpdateCompanionBuilder =
    PortForwardsCompanion Function({
      Value<int> updatedAt,
      Value<int> rev,
      Value<String> id,
      Value<String> serverId,
      Value<String> name,
      Value<String> type,
      Value<String?> localHost,
      Value<int> localPort,
      Value<String?> remoteHost,
      Value<int?> remotePort,
    });

final class $$PortForwardsTableReferences
    extends BaseReferences<_$AppDb, $PortForwardsTable, PortForwardRow> {
  $$PortForwardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ServersTable _serverIdTable(_$AppDb db) =>
      db.servers.createAlias('port_forward__server_id__server__id');

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

class $$PortForwardsTableFilterComposer
    extends Composer<_$AppDb, $PortForwardsTable> {
  $$PortForwardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localHost => $composableBuilder(
    column: $table.localHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localPort => $composableBuilder(
    column: $table.localPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteHost => $composableBuilder(
    column: $table.remoteHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remotePort => $composableBuilder(
    column: $table.remotePort,
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

class $$PortForwardsTableOrderingComposer
    extends Composer<_$AppDb, $PortForwardsTable> {
  $$PortForwardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localHost => $composableBuilder(
    column: $table.localHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localPort => $composableBuilder(
    column: $table.localPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteHost => $composableBuilder(
    column: $table.remoteHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remotePort => $composableBuilder(
    column: $table.remotePort,
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

class $$PortForwardsTableAnnotationComposer
    extends Composer<_$AppDb, $PortForwardsTable> {
  $$PortForwardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rev =>
      $composableBuilder(column: $table.rev, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get localHost =>
      $composableBuilder(column: $table.localHost, builder: (column) => column);

  GeneratedColumn<int> get localPort =>
      $composableBuilder(column: $table.localPort, builder: (column) => column);

  GeneratedColumn<String> get remoteHost => $composableBuilder(
    column: $table.remoteHost,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remotePort => $composableBuilder(
    column: $table.remotePort,
    builder: (column) => column,
  );

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

class $$PortForwardsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $PortForwardsTable,
          PortForwardRow,
          $$PortForwardsTableFilterComposer,
          $$PortForwardsTableOrderingComposer,
          $$PortForwardsTableAnnotationComposer,
          $$PortForwardsTableCreateCompanionBuilder,
          $$PortForwardsTableUpdateCompanionBuilder,
          (PortForwardRow, $$PortForwardsTableReferences),
          PortForwardRow,
          PrefetchHooks Function({bool serverId})
        > {
  $$PortForwardsTableTableManager(_$AppDb db, $PortForwardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PortForwardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PortForwardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PortForwardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int> rev = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> localHost = const Value.absent(),
                Value<int> localPort = const Value.absent(),
                Value<String?> remoteHost = const Value.absent(),
                Value<int?> remotePort = const Value.absent(),
              }) => PortForwardsCompanion(
                updatedAt: updatedAt,
                rev: rev,
                id: id,
                serverId: serverId,
                name: name,
                type: type,
                localHost: localHost,
                localPort: localPort,
                remoteHost: remoteHost,
                remotePort: remotePort,
              ),
          createCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int> rev = const Value.absent(),
                required String id,
                required String serverId,
                required String name,
                required String type,
                Value<String?> localHost = const Value.absent(),
                Value<int> localPort = const Value.absent(),
                Value<String?> remoteHost = const Value.absent(),
                Value<int?> remotePort = const Value.absent(),
              }) => PortForwardsCompanion.insert(
                updatedAt: updatedAt,
                rev: rev,
                id: id,
                serverId: serverId,
                name: name,
                type: type,
                localHost: localHost,
                localPort: localPort,
                remoteHost: remoteHost,
                remotePort: remotePort,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PortForwardsTableReferences(db, table, e),
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
                                referencedTable: $$PortForwardsTableReferences
                                    ._serverIdTable(db),
                                referencedColumn: $$PortForwardsTableReferences
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

typedef $$PortForwardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $PortForwardsTable,
      PortForwardRow,
      $$PortForwardsTableFilterComposer,
      $$PortForwardsTableOrderingComposer,
      $$PortForwardsTableAnnotationComposer,
      $$PortForwardsTableCreateCompanionBuilder,
      $$PortForwardsTableUpdateCompanionBuilder,
      (PortForwardRow, $$PortForwardsTableReferences),
      PortForwardRow,
      PrefetchHooks Function({bool serverId})
    >;
typedef $$ContainerHostsTableCreateCompanionBuilder =
    ContainerHostsCompanion Function({
      required String serverId,
      required String type,
      required String host,
    });
typedef $$ContainerHostsTableUpdateCompanionBuilder =
    ContainerHostsCompanion Function({
      Value<String> serverId,
      Value<String> type,
      Value<String> host,
    });

final class $$ContainerHostsTableReferences
    extends BaseReferences<_$AppDb, $ContainerHostsTable, ContainerHostRow> {
  $$ContainerHostsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ServersTable _serverIdTable(_$AppDb db) =>
      db.servers.createAlias('container_host__server_id__server__id');

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

class $$ContainerHostsTableFilterComposer
    extends Composer<_$AppDb, $ContainerHostsTable> {
  $$ContainerHostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
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

class $$ContainerHostsTableOrderingComposer
    extends Composer<_$AppDb, $ContainerHostsTable> {
  $$ContainerHostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
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

class $$ContainerHostsTableAnnotationComposer
    extends Composer<_$AppDb, $ContainerHostsTable> {
  $$ContainerHostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

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

class $$ContainerHostsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ContainerHostsTable,
          ContainerHostRow,
          $$ContainerHostsTableFilterComposer,
          $$ContainerHostsTableOrderingComposer,
          $$ContainerHostsTableAnnotationComposer,
          $$ContainerHostsTableCreateCompanionBuilder,
          $$ContainerHostsTableUpdateCompanionBuilder,
          (ContainerHostRow, $$ContainerHostsTableReferences),
          ContainerHostRow,
          PrefetchHooks Function({bool serverId})
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
                Value<String> type = const Value.absent(),
                Value<String> host = const Value.absent(),
              }) => ContainerHostsCompanion(
                serverId: serverId,
                type: type,
                host: host,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String type,
                required String host,
              }) => ContainerHostsCompanion.insert(
                serverId: serverId,
                type: type,
                host: host,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ContainerHostsTableReferences(db, table, e),
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
                                referencedTable: $$ContainerHostsTableReferences
                                    ._serverIdTable(db),
                                referencedColumn:
                                    $$ContainerHostsTableReferences
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

typedef $$ContainerHostsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ContainerHostsTable,
      ContainerHostRow,
      $$ContainerHostsTableFilterComposer,
      $$ContainerHostsTableOrderingComposer,
      $$ContainerHostsTableAnnotationComposer,
      $$ContainerHostsTableCreateCompanionBuilder,
      $$ContainerHostsTableUpdateCompanionBuilder,
      (ContainerHostRow, $$ContainerHostsTableReferences),
      ContainerHostRow,
      PrefetchHooks Function({bool serverId})
    >;
typedef $$ContainerRuntimesTableCreateCompanionBuilder =
    ContainerRuntimesCompanion Function({
      required String serverId,
      required String type,
    });
typedef $$ContainerRuntimesTableUpdateCompanionBuilder =
    ContainerRuntimesCompanion Function({
      Value<String> serverId,
      Value<String> type,
    });

final class $$ContainerRuntimesTableReferences
    extends
        BaseReferences<_$AppDb, $ContainerRuntimesTable, ContainerRuntimeRow> {
  $$ContainerRuntimesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ServersTable _serverIdTable(_$AppDb db) =>
      db.servers.createAlias('container_runtime__server_id__server__id');

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

class $$ContainerRuntimesTableFilterComposer
    extends Composer<_$AppDb, $ContainerRuntimesTable> {
  $$ContainerRuntimesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
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

class $$ContainerRuntimesTableOrderingComposer
    extends Composer<_$AppDb, $ContainerRuntimesTable> {
  $$ContainerRuntimesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
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

class $$ContainerRuntimesTableAnnotationComposer
    extends Composer<_$AppDb, $ContainerRuntimesTable> {
  $$ContainerRuntimesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

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

class $$ContainerRuntimesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ContainerRuntimesTable,
          ContainerRuntimeRow,
          $$ContainerRuntimesTableFilterComposer,
          $$ContainerRuntimesTableOrderingComposer,
          $$ContainerRuntimesTableAnnotationComposer,
          $$ContainerRuntimesTableCreateCompanionBuilder,
          $$ContainerRuntimesTableUpdateCompanionBuilder,
          (ContainerRuntimeRow, $$ContainerRuntimesTableReferences),
          ContainerRuntimeRow,
          PrefetchHooks Function({bool serverId})
        > {
  $$ContainerRuntimesTableTableManager(
    _$AppDb db,
    $ContainerRuntimesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContainerRuntimesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContainerRuntimesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContainerRuntimesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> type = const Value.absent(),
              }) => ContainerRuntimesCompanion(serverId: serverId, type: type),
          createCompanionCallback:
              ({required String serverId, required String type}) =>
                  ContainerRuntimesCompanion.insert(
                    serverId: serverId,
                    type: type,
                  ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ContainerRuntimesTableReferences(db, table, e),
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
                                    $$ContainerRuntimesTableReferences
                                        ._serverIdTable(db),
                                referencedColumn:
                                    $$ContainerRuntimesTableReferences
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

typedef $$ContainerRuntimesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ContainerRuntimesTable,
      ContainerRuntimeRow,
      $$ContainerRuntimesTableFilterComposer,
      $$ContainerRuntimesTableOrderingComposer,
      $$ContainerRuntimesTableAnnotationComposer,
      $$ContainerRuntimesTableCreateCompanionBuilder,
      $$ContainerRuntimesTableUpdateCompanionBuilder,
      (ContainerRuntimeRow, $$ContainerRuntimesTableReferences),
      ContainerRuntimeRow,
      PrefetchHooks Function({bool serverId})
    >;
typedef $$ConnStatsTableCreateCompanionBuilder =
    ConnStatsCompanion Function({
      required String id,
      required String serverId,
      required String serverName,
      required int timestamp,
      required String result,
      Value<String> errorMessage,
      required int durationMs,
    });
typedef $$ConnStatsTableUpdateCompanionBuilder =
    ConnStatsCompanion Function({
      Value<String> id,
      Value<String> serverId,
      Value<String> serverName,
      Value<int> timestamp,
      Value<String> result,
      Value<String> errorMessage,
      Value<int> durationMs,
    });

final class $$ConnStatsTableReferences
    extends BaseReferences<_$AppDb, $ConnStatsTable, ConnStatRow> {
  $$ConnStatsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ServersTable _serverIdTable(_$AppDb db) =>
      db.servers.createAlias('conn_stat__server_id__server__id');

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

class $$ConnStatsTableFilterComposer
    extends Composer<_$AppDb, $ConnStatsTable> {
  $$ConnStatsTableFilterComposer({
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

  ColumnFilters<String> get serverName => $composableBuilder(
    column: $table.serverName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
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

class $$ConnStatsTableOrderingComposer
    extends Composer<_$AppDb, $ConnStatsTable> {
  $$ConnStatsTableOrderingComposer({
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

  ColumnOrderings<String> get serverName => $composableBuilder(
    column: $table.serverName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
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

class $$ConnStatsTableAnnotationComposer
    extends Composer<_$AppDb, $ConnStatsTable> {
  $$ConnStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverName => $composableBuilder(
    column: $table.serverName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

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

class $$ConnStatsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ConnStatsTable,
          ConnStatRow,
          $$ConnStatsTableFilterComposer,
          $$ConnStatsTableOrderingComposer,
          $$ConnStatsTableAnnotationComposer,
          $$ConnStatsTableCreateCompanionBuilder,
          $$ConnStatsTableUpdateCompanionBuilder,
          (ConnStatRow, $$ConnStatsTableReferences),
          ConnStatRow,
          PrefetchHooks Function({bool serverId})
        > {
  $$ConnStatsTableTableManager(_$AppDb db, $ConnStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConnStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConnStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConnStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<String> serverName = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<String> errorMessage = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
              }) => ConnStatsCompanion(
                id: id,
                serverId: serverId,
                serverName: serverName,
                timestamp: timestamp,
                result: result,
                errorMessage: errorMessage,
                durationMs: durationMs,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String serverId,
                required String serverName,
                required int timestamp,
                required String result,
                Value<String> errorMessage = const Value.absent(),
                required int durationMs,
              }) => ConnStatsCompanion.insert(
                id: id,
                serverId: serverId,
                serverName: serverName,
                timestamp: timestamp,
                result: result,
                errorMessage: errorMessage,
                durationMs: durationMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ConnStatsTableReferences(db, table, e),
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
                                referencedTable: $$ConnStatsTableReferences
                                    ._serverIdTable(db),
                                referencedColumn: $$ConnStatsTableReferences
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

typedef $$ConnStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ConnStatsTable,
      ConnStatRow,
      $$ConnStatsTableFilterComposer,
      $$ConnStatsTableOrderingComposer,
      $$ConnStatsTableAnnotationComposer,
      $$ConnStatsTableCreateCompanionBuilder,
      $$ConnStatsTableUpdateCompanionBuilder,
      (ConnStatRow, $$ConnStatsTableReferences),
      ConnStatRow,
      PrefetchHooks Function({bool serverId})
    >;
typedef $$AgentConversationsTableCreateCompanionBuilder =
    AgentConversationsCompanion Function({
      required String id,
      required String serverId,
      required int updatedAt,
      required String data,
    });
typedef $$AgentConversationsTableUpdateCompanionBuilder =
    AgentConversationsCompanion Function({
      Value<String> id,
      Value<String> serverId,
      Value<int> updatedAt,
      Value<String> data,
    });

final class $$AgentConversationsTableReferences
    extends
        BaseReferences<
          _$AppDb,
          $AgentConversationsTable,
          AgentConversationRow
        > {
  $$AgentConversationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $AgentActiveConversationsTable,
    List<AgentActiveConversationRow>
  >
  _agentActiveConversationsRefsTable(
    _$AppDb db,
  ) => MultiTypedResultKey.fromTable(
    db.agentActiveConversations,
    aliasName:
        'agent_conversation__id__agent_active_conversation__conversation_id',
  );

  $$AgentActiveConversationsTableProcessedTableManager
  get agentActiveConversationsRefs {
    final manager = $$AgentActiveConversationsTableTableManager(
      $_db,
      $_db.agentActiveConversations,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _agentActiveConversationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AgentConversationsTableFilterComposer
    extends Composer<_$AppDb, $AgentConversationsTable> {
  $$AgentConversationsTableFilterComposer({
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

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> agentActiveConversationsRefs(
    Expression<bool> Function($$AgentActiveConversationsTableFilterComposer f)
    f,
  ) {
    final $$AgentActiveConversationsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.agentActiveConversations,
          getReferencedColumn: (t) => t.conversationId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AgentActiveConversationsTableFilterComposer(
                $db: $db,
                $table: $db.agentActiveConversations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AgentConversationsTableOrderingComposer
    extends Composer<_$AppDb, $AgentConversationsTable> {
  $$AgentConversationsTableOrderingComposer({
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

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AgentConversationsTableAnnotationComposer
    extends Composer<_$AppDb, $AgentConversationsTable> {
  $$AgentConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  Expression<T> agentActiveConversationsRefs<T extends Object>(
    Expression<T> Function($$AgentActiveConversationsTableAnnotationComposer a)
    f,
  ) {
    final $$AgentActiveConversationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.agentActiveConversations,
          getReferencedColumn: (t) => t.conversationId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AgentActiveConversationsTableAnnotationComposer(
                $db: $db,
                $table: $db.agentActiveConversations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AgentConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $AgentConversationsTable,
          AgentConversationRow,
          $$AgentConversationsTableFilterComposer,
          $$AgentConversationsTableOrderingComposer,
          $$AgentConversationsTableAnnotationComposer,
          $$AgentConversationsTableCreateCompanionBuilder,
          $$AgentConversationsTableUpdateCompanionBuilder,
          (AgentConversationRow, $$AgentConversationsTableReferences),
          AgentConversationRow,
          PrefetchHooks Function({bool agentActiveConversationsRefs})
        > {
  $$AgentConversationsTableTableManager(
    _$AppDb db,
    $AgentConversationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentConversationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> data = const Value.absent(),
              }) => AgentConversationsCompanion(
                id: id,
                serverId: serverId,
                updatedAt: updatedAt,
                data: data,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String serverId,
                required int updatedAt,
                required String data,
              }) => AgentConversationsCompanion.insert(
                id: id,
                serverId: serverId,
                updatedAt: updatedAt,
                data: data,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AgentConversationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({agentActiveConversationsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (agentActiveConversationsRefs) db.agentActiveConversations,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (agentActiveConversationsRefs)
                    await $_getPrefetchedData<
                      AgentConversationRow,
                      $AgentConversationsTable,
                      AgentActiveConversationRow
                    >(
                      currentTable: table,
                      referencedTable: $$AgentConversationsTableReferences
                          ._agentActiveConversationsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AgentConversationsTableReferences(
                            db,
                            table,
                            p0,
                          ).agentActiveConversationsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.conversationId == item.id,
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

typedef $$AgentConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $AgentConversationsTable,
      AgentConversationRow,
      $$AgentConversationsTableFilterComposer,
      $$AgentConversationsTableOrderingComposer,
      $$AgentConversationsTableAnnotationComposer,
      $$AgentConversationsTableCreateCompanionBuilder,
      $$AgentConversationsTableUpdateCompanionBuilder,
      (AgentConversationRow, $$AgentConversationsTableReferences),
      AgentConversationRow,
      PrefetchHooks Function({bool agentActiveConversationsRefs})
    >;
typedef $$AgentActiveConversationsTableCreateCompanionBuilder =
    AgentActiveConversationsCompanion Function({
      required String serverId,
      required String conversationId,
    });
typedef $$AgentActiveConversationsTableUpdateCompanionBuilder =
    AgentActiveConversationsCompanion Function({
      Value<String> serverId,
      Value<String> conversationId,
    });

final class $$AgentActiveConversationsTableReferences
    extends
        BaseReferences<
          _$AppDb,
          $AgentActiveConversationsTable,
          AgentActiveConversationRow
        > {
  $$AgentActiveConversationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AgentConversationsTable _conversationIdTable(_$AppDb db) =>
      db.agentConversations.createAlias(
        'agent_active_conversation__conversation_id__agent_conversation__id',
      );

  $$AgentConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$AgentConversationsTableTableManager(
      $_db,
      $_db.agentConversations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AgentActiveConversationsTableFilterComposer
    extends Composer<_$AppDb, $AgentActiveConversationsTable> {
  $$AgentActiveConversationsTableFilterComposer({
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

  $$AgentConversationsTableFilterComposer get conversationId {
    final $$AgentConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.agentConversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentConversationsTableFilterComposer(
            $db: $db,
            $table: $db.agentConversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AgentActiveConversationsTableOrderingComposer
    extends Composer<_$AppDb, $AgentActiveConversationsTable> {
  $$AgentActiveConversationsTableOrderingComposer({
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

  $$AgentConversationsTableOrderingComposer get conversationId {
    final $$AgentConversationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.agentConversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentConversationsTableOrderingComposer(
            $db: $db,
            $table: $db.agentConversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AgentActiveConversationsTableAnnotationComposer
    extends Composer<_$AppDb, $AgentActiveConversationsTable> {
  $$AgentActiveConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  $$AgentConversationsTableAnnotationComposer get conversationId {
    final $$AgentConversationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.conversationId,
          referencedTable: $db.agentConversations,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AgentConversationsTableAnnotationComposer(
                $db: $db,
                $table: $db.agentConversations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$AgentActiveConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $AgentActiveConversationsTable,
          AgentActiveConversationRow,
          $$AgentActiveConversationsTableFilterComposer,
          $$AgentActiveConversationsTableOrderingComposer,
          $$AgentActiveConversationsTableAnnotationComposer,
          $$AgentActiveConversationsTableCreateCompanionBuilder,
          $$AgentActiveConversationsTableUpdateCompanionBuilder,
          (
            AgentActiveConversationRow,
            $$AgentActiveConversationsTableReferences,
          ),
          AgentActiveConversationRow,
          PrefetchHooks Function({bool conversationId})
        > {
  $$AgentActiveConversationsTableTableManager(
    _$AppDb db,
    $AgentActiveConversationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentActiveConversationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AgentActiveConversationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AgentActiveConversationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
              }) => AgentActiveConversationsCompanion(
                serverId: serverId,
                conversationId: conversationId,
              ),
          createCompanionCallback:
              ({required String serverId, required String conversationId}) =>
                  AgentActiveConversationsCompanion.insert(
                    serverId: serverId,
                    conversationId: conversationId,
                  ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AgentActiveConversationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({conversationId = false}) {
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
                    if (conversationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.conversationId,
                                referencedTable:
                                    $$AgentActiveConversationsTableReferences
                                        ._conversationIdTable(db),
                                referencedColumn:
                                    $$AgentActiveConversationsTableReferences
                                        ._conversationIdTable(db)
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

typedef $$AgentActiveConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $AgentActiveConversationsTable,
      AgentActiveConversationRow,
      $$AgentActiveConversationsTableFilterComposer,
      $$AgentActiveConversationsTableOrderingComposer,
      $$AgentActiveConversationsTableAnnotationComposer,
      $$AgentActiveConversationsTableCreateCompanionBuilder,
      $$AgentActiveConversationsTableUpdateCompanionBuilder,
      (AgentActiveConversationRow, $$AgentActiveConversationsTableReferences),
      AgentActiveConversationRow,
      PrefetchHooks Function({bool conversationId})
    >;
typedef $$TombstonesTableCreateCompanionBuilder =
    TombstonesCompanion Function({
      required String tbl,
      required String rowId,
      required int deletedAt,
    });
typedef $$TombstonesTableUpdateCompanionBuilder =
    TombstonesCompanion Function({
      Value<String> tbl,
      Value<String> rowId,
      Value<int> deletedAt,
    });

class $$TombstonesTableFilterComposer
    extends Composer<_$AppDb, $TombstonesTable> {
  $$TombstonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tbl => $composableBuilder(
    column: $table.tbl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TombstonesTableOrderingComposer
    extends Composer<_$AppDb, $TombstonesTable> {
  $$TombstonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tbl => $composableBuilder(
    column: $table.tbl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TombstonesTableAnnotationComposer
    extends Composer<_$AppDb, $TombstonesTable> {
  $$TombstonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tbl =>
      $composableBuilder(column: $table.tbl, builder: (column) => column);

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TombstonesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $TombstonesTable,
          TombstoneRow,
          $$TombstonesTableFilterComposer,
          $$TombstonesTableOrderingComposer,
          $$TombstonesTableAnnotationComposer,
          $$TombstonesTableCreateCompanionBuilder,
          $$TombstonesTableUpdateCompanionBuilder,
          (
            TombstoneRow,
            BaseReferences<_$AppDb, $TombstonesTable, TombstoneRow>,
          ),
          TombstoneRow,
          PrefetchHooks Function()
        > {
  $$TombstonesTableTableManager(_$AppDb db, $TombstonesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TombstonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TombstonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TombstonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tbl = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<int> deletedAt = const Value.absent(),
              }) => TombstonesCompanion(
                tbl: tbl,
                rowId: rowId,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                required String tbl,
                required String rowId,
                required int deletedAt,
              }) => TombstonesCompanion.insert(
                tbl: tbl,
                rowId: rowId,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TombstonesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $TombstonesTable,
      TombstoneRow,
      $$TombstonesTableFilterComposer,
      $$TombstonesTableOrderingComposer,
      $$TombstonesTableAnnotationComposer,
      $$TombstonesTableCreateCompanionBuilder,
      $$TombstonesTableUpdateCompanionBuilder,
      (TombstoneRow, BaseReferences<_$AppDb, $TombstonesTable, TombstoneRow>),
      TombstoneRow,
      PrefetchHooks Function()
    >;
typedef $$SyncStatesTableCreateCompanionBuilder =
    SyncStatesCompanion Function({required String k, required String v});
typedef $$SyncStatesTableUpdateCompanionBuilder =
    SyncStatesCompanion Function({Value<String> k, Value<String> v});

class $$SyncStatesTableFilterComposer
    extends Composer<_$AppDb, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get k => $composableBuilder(
    column: $table.k,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get v => $composableBuilder(
    column: $table.v,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$AppDb, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get k => $composableBuilder(
    column: $table.k,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get v => $composableBuilder(
    column: $table.v,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$AppDb, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get k =>
      $composableBuilder(column: $table.k, builder: (column) => column);

  GeneratedColumn<String> get v =>
      $composableBuilder(column: $table.v, builder: (column) => column);
}

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SyncStatesTable,
          SyncStateRow,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$AppDb, $SyncStatesTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStatesTableTableManager(_$AppDb db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> k = const Value.absent(),
                Value<String> v = const Value.absent(),
              }) => SyncStatesCompanion(k: k, v: v),
          createCompanionCallback: ({required String k, required String v}) =>
              SyncStatesCompanion.insert(k: k, v: v),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SyncStatesTable,
      SyncStateRow,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (SyncStateRow, BaseReferences<_$AppDb, $SyncStatesTable, SyncStateRow>),
      SyncStateRow,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$PrivateKeysTableTableManager get privateKeys =>
      $$PrivateKeysTableTableManager(_db, _db.privateKeys);
  $$BmcCredentialsTableTableManager get bmcCredentials =>
      $$BmcCredentialsTableTableManager(_db, _db.bmcCredentials);
  $$ServersTableTableManager get servers =>
      $$ServersTableTableManager(_db, _db.servers);
  $$ServerTagsTableTableManager get serverTags =>
      $$ServerTagsTableTableManager(_db, _db.serverTags);
  $$ServerEnvsTableTableManager get serverEnvs =>
      $$ServerEnvsTableTableManager(_db, _db.serverEnvs);
  $$ServerJumpsTableTableManager get serverJumps =>
      $$ServerJumpsTableTableManager(_db, _db.serverJumps);
  $$ServerDisabledCmdsTableTableManager get serverDisabledCmds =>
      $$ServerDisabledCmdsTableTableManager(_db, _db.serverDisabledCmds);
  $$ServerCustomCmdsTableTableManager get serverCustomCmds =>
      $$ServerCustomCmdsTableTableManager(_db, _db.serverCustomCmds);
  $$KnownHostsTableTableManager get knownHosts =>
      $$KnownHostsTableTableManager(_db, _db.knownHosts);
  $$SnippetsTableTableManager get snippets =>
      $$SnippetsTableTableManager(_db, _db.snippets);
  $$SnippetTagsTableTableManager get snippetTags =>
      $$SnippetTagsTableTableManager(_db, _db.snippetTags);
  $$SnippetAutoRunOnTableTableManager get snippetAutoRunOn =>
      $$SnippetAutoRunOnTableTableManager(_db, _db.snippetAutoRunOn);
  $$PortForwardsTableTableManager get portForwards =>
      $$PortForwardsTableTableManager(_db, _db.portForwards);
  $$ContainerHostsTableTableManager get containerHosts =>
      $$ContainerHostsTableTableManager(_db, _db.containerHosts);
  $$ContainerRuntimesTableTableManager get containerRuntimes =>
      $$ContainerRuntimesTableTableManager(_db, _db.containerRuntimes);
  $$ConnStatsTableTableManager get connStats =>
      $$ConnStatsTableTableManager(_db, _db.connStats);
  $$AgentConversationsTableTableManager get agentConversations =>
      $$AgentConversationsTableTableManager(_db, _db.agentConversations);
  $$AgentActiveConversationsTableTableManager get agentActiveConversations =>
      $$AgentActiveConversationsTableTableManager(
        _db,
        _db.agentActiveConversations,
      );
  $$TombstonesTableTableManager get tombstones =>
      $$TombstonesTableTableManager(_db, _db.tombstones);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
}
