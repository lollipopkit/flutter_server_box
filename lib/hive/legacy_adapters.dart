import 'package:hive_ce/hive.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/hive/spi_legacy_adapter.dart';

/// Hive records as the released builds wrote them, frozen.
///
/// Nothing writes Hive; these exist only so `HiveImport` can read what an
/// upgrading install has. That makes generating an adapter from a live model a
/// trap: the generator emits `fields[n] as String` for every non-nullable
/// field, so **adding one to a model makes every box written before it
/// unreadable** — the field is absent, the cast gets null, and the box fails to
/// open. `test/hive_release_migration_test.dart` is what catches it, and it
/// caught exactly this when `Snippet` gained an id and `PrivateKeyInfo` gained
/// a name.
///
/// So a model that Hive still has an adapter for gets a frozen type here
/// instead, the same way `LegacySpiV2` was already handled. Each one:
///
/// - carries the fields the release wrote, at the field numbers it wrote them
/// - is a type of its own, because Hive resolves *writes* by runtime type and
///   two adapters claiming one type make every write depend on registration
///   order
/// - converts to JSON in the shape that release's `toJson` produced, which is
///   what `KvToTablesMigration` reads. Not to today's model: a migration that
///   goes through the current code changes meaning every time that code does.
///
/// TODO: delete this file, `lib/hive/` and the `hive_ce*` dependencies with
/// `HiveImport`, once no supported install can still be on Hive.
void registerHiveLegacyAdapters() {
  Hive.registerAdapter(SpiLegacyAdapter());
  Hive.registerAdapter(SpiNestedLegacyAdapter());
  Hive.registerAdapter(LegacyPrivateKeyAdapter());
  Hive.registerAdapter(LegacySnippetAdapter());
  Hive.registerAdapter(LegacyMonitorHttpCredentialAdapter());
  Hive.registerAdapter(LegacySshCredentialAdapter());
  Hive.registerAdapter(LegacyServerCustomAdapter());
}

/// typeId 1, as written up to and including v1.0.1491: an id that was also the
/// name, and the key itself.
class LegacyPrivateKeyV1 {
  const LegacyPrivateKeyV1({required this.id, required this.key});

  final String id;
  final String key;

  /// `private_key`, not `key`: the released model carried
  /// `@JsonKey(name: 'private_key')`.
  Map<String, dynamic> toJson() => {'id': id, 'private_key': key};
}

class LegacyPrivateKeyAdapter extends TypeAdapter<LegacyPrivateKeyV1> {
  @override
  final typeId = 1;

  @override
  LegacyPrivateKeyV1 read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LegacyPrivateKeyV1(
      id: fields[0] as String,
      key: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, LegacyPrivateKeyV1 obj) =>
      throw UnsupportedError('Hive is read-only');
}

/// typeId 2, as written up to and including v1.0.1491: no id, because a snippet
/// was keyed by its name.
class LegacySnippetV1 {
  const LegacySnippetV1({
    required this.name,
    required this.script,
    required this.tags,
    required this.note,
    required this.autoRunOn,
  });

  final String name;
  final String script;
  final List<String>? tags;
  final String? note;
  final List<String>? autoRunOn;

  Map<String, dynamic> toJson() => {
    'name': name,
    'script': script,
    'tags': tags,
    'note': note,
    'autoRunOn': autoRunOn,
  };
}

class LegacySnippetAdapter extends TypeAdapter<LegacySnippetV1> {
  @override
  final typeId = 2;

  @override
  LegacySnippetV1 read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LegacySnippetV1(
      name: fields[0] as String,
      script: fields[1] as String,
      tags: (fields[2] as List?)?.cast<String>(),
      note: fields[3] as String?,
      autoRunOn: (fields[4] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, LegacySnippetV1 obj) =>
      throw UnsupportedError('Hive is read-only');
}

/// typeId 16, as written up to and including v1.0.1491: ten fields, at the nine
/// indexes those builds used, with 9 skipped where a field was dropped.
///
/// Frozen for the reason at the top of this file, and it is worth spelling out
/// here because the generated adapter did *not* break when `fileTransport` was
/// added — the field has a default, so the generator emitted a null check
/// rather than a bare cast. It was still wrong to keep generating it. Hive is
/// the old database and SQLite is the new one: no Hive box has ever carried a
/// field added after the last Hive release, and an adapter that knows about one
/// is an adapter tracking a model it does not describe. The next field without
/// a default is the one that would have made this an unreadable box and a
/// silently dropped store.
class LegacySshCredentialV1 {
  const LegacySshCredentialV1({
    required this.ip,
    required this.port,
    required this.user,
    required this.pwd,
    required this.keyId,
    required this.keyPath,
    required this.alterUrl,
    required this.jumpId,
    required this.jumpIds,
    required this.proxyCommand,
  });

  final String ip;
  final int port;
  final String user;
  final String? pwd;
  final String? keyId;
  final String? keyPath;
  final String? alterUrl;
  final String? jumpId;
  final List<String>? jumpIds;
  final String? proxyCommand;

  /// Today's model, with everything those builds could not express left at its
  /// default — `fileTransport` is SFTP because SFTP is all they had.
  SshCredential toCredential() => SshCredential(
    ip: ip,
    port: port,
    user: user,
    pwd: pwd,
    keyId: keyId,
    keyPath: keyPath,
    alterUrl: alterUrl,
    jumpId: jumpId,
    jumpIds: jumpIds,
    proxyCommand: proxyCommand,
  );
}

/// typeId 7, as written up to and including v1.0.1491: nine fields, at the
/// indexes those builds used, which start at 1 rather than 0.
///
/// Frozen the moment `ServerCustom` gained `geo`, and that field is worth
/// describing because it is the *other* way a generated adapter goes wrong.
/// The read was safe — a nullable field gets a null cast, and no box carries
/// one — but `write` had become `writer.write(obj.geo)` for a type with no
/// adapter registered anywhere, so the first thing to write a record would
/// have failed with `unknown type: GeoCoord`. Nothing writes Hive, so it would
/// have sat there being fine until something did.
class LegacyServerCustomV1 {
  const LegacyServerCustomV1({
    required this.pveAddr,
    required this.pveIgnoreCert,
    required this.pvePwd,
    required this.cmds,
    required this.preferTempDev,
    required this.tempIsCelsius,
    required this.logoUrl,
    required this.netDev,
    required this.scriptDir,
  });

  final String? pveAddr;
  final bool pveIgnoreCert;
  final String? pvePwd;
  final Map<String, String>? cmds;
  final String? preferTempDev;
  final bool tempIsCelsius;
  final String? logoUrl;
  final String? netDev;
  final String? scriptDir;

  /// Today's model, with everything those builds could not express left at its
  /// default — `geo` is null, because a coordinate is something the user gives
  /// a server and no Hive install was ever asked for one.
  ServerCustom toCustom() => ServerCustom(
    pveAddr: pveAddr,
    pveIgnoreCert: pveIgnoreCert,
    pvePwd: pvePwd,
    cmds: cmds,
    preferTempDev: preferTempDev,
    tempIsCelsius: tempIsCelsius,
    logoUrl: logoUrl,
    netDev: netDev,
    scriptDir: scriptDir,
  );
}

class LegacyServerCustomAdapter extends TypeAdapter<LegacyServerCustomV1> {
  @override
  final typeId = 7;

  @override
  LegacyServerCustomV1 read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LegacyServerCustomV1(
      pveAddr: fields[1] as String?,
      pveIgnoreCert: fields[2] == null ? false : fields[2] as bool,
      cmds: (fields[3] as Map?)?.cast<String, String>(),
      preferTempDev: fields[4] as String?,
      logoUrl: fields[5] as String?,
      netDev: fields[6] as String?,
      scriptDir: fields[7] as String?,
      pvePwd: fields[8] as String?,
      // False, not true, and not the model's default either: it is what the
      // generated adapter answered for a record written before the field
      // existed, and this type's job is to say what those builds wrote.
      tempIsCelsius: fields[9] == null ? false : fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LegacyServerCustomV1 obj) =>
      throw UnsupportedError('Hive is read-only');
}

class LegacySshCredentialAdapter extends TypeAdapter<LegacySshCredentialV1> {
  @override
  final typeId = 16;

  @override
  LegacySshCredentialV1 read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LegacySshCredentialV1(
      ip: fields[0] as String,
      port: fields[1] == null ? 22 : (fields[1] as num).toInt(),
      user: fields[2] == null ? 'root' : fields[2] as String,
      pwd: fields[3] as String?,
      keyId: fields[4] as String?,
      alterUrl: fields[5] as String?,
      jumpId: fields[6] as String?,
      jumpIds: (fields[7] as List?)?.cast<String>(),
      proxyCommand: fields[8] as String?,
      keyPath: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LegacySshCredentialV1 obj) =>
      throw UnsupportedError('Hive is read-only');
}
