import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart' as sqlite_open;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

part 'app_db.g.dart';

class Servers extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get ip => text()();

  IntColumn get port => integer()();

  TextColumn get user => text()();

  TextColumn get pwd => text().nullable()();

  TextColumn get keyId => text().named('key_id').nullable()();

  TextColumn get alterUrl => text().named('alter_url').nullable()();

  BoolColumn get autoConnect =>
      boolean().named('auto_connect').withDefault(const Constant(true))();

  TextColumn get jumpId => text().named('jump_id').nullable()();

  TextColumn get customSystemType =>
      text().named('custom_system_type').nullable()();

  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ServerCustoms extends Table {
  TextColumn get serverId => text()
      .named('server_id')
      .customConstraint('NOT NULL REFERENCES servers(id) ON DELETE CASCADE')();

  TextColumn get pveAddr => text().named('pve_addr').nullable()();

  BoolColumn get pveIgnoreCert =>
      boolean().named('pve_ignore_cert').withDefault(const Constant(false))();

  TextColumn get cmdsJson => text().named('cmds_json').nullable()();

  TextColumn get preferTempDev => text().named('prefer_temp_dev').nullable()();

  TextColumn get logoUrl => text().named('logo_url').nullable()();

  TextColumn get netDev => text().named('net_dev').nullable()();

  TextColumn get scriptDir => text().named('script_dir').nullable()();

  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {serverId};
}

class ServerWolCfgs extends Table {
  TextColumn get serverId => text()
      .named('server_id')
      .customConstraint('NOT NULL REFERENCES servers(id) ON DELETE CASCADE')();

  TextColumn get mac => text()();

  TextColumn get ip => text()();

  TextColumn get pwd => text().nullable()();

  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {serverId};
}

class ServerTags extends Table {
  TextColumn get serverId => text()
      .named('server_id')
      .customConstraint('NOT NULL REFERENCES servers(id) ON DELETE CASCADE')();

  TextColumn get tag => text()();

  @override
  Set<Column<Object>> get primaryKey => {serverId, tag};
}

class ServerEnvs extends Table {
  TextColumn get serverId => text()
      .named('server_id')
      .customConstraint('NOT NULL REFERENCES servers(id) ON DELETE CASCADE')();

  TextColumn get envKey => text().named('env_key')();

  TextColumn get envVal => text().named('env_val')();

  @override
  Set<Column<Object>> get primaryKey => {serverId, envKey};
}

class ServerDisabledCmdTypes extends Table {
  TextColumn get serverId => text()
      .named('server_id')
      .customConstraint('NOT NULL REFERENCES servers(id) ON DELETE CASCADE')();

  TextColumn get cmdType => text().named('cmd_type')();

  @override
  Set<Column<Object>> get primaryKey => {serverId, cmdType};
}

class Snippets extends Table {
  TextColumn get name => text()();

  TextColumn get script => text()();

  TextColumn get note => text().nullable()();

  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {name};
}

class SnippetTags extends Table {
  TextColumn get snippetName => text()
      .named('snippet_name')
      .customConstraint(
        'NOT NULL REFERENCES snippets(name) ON DELETE CASCADE',
      )();

  TextColumn get tag => text()();

  @override
  Set<Column<Object>> get primaryKey => {snippetName, tag};
}

class SnippetAutoRuns extends Table {
  TextColumn get snippetName => text()
      .named('snippet_name')
      .customConstraint(
        'NOT NULL REFERENCES snippets(name) ON DELETE CASCADE',
      )();

  TextColumn get serverId => text().named('server_id')();

  @override
  Set<Column<Object>> get primaryKey => {snippetName, serverId};
}

class PrivateKeys extends Table {
  TextColumn get id => text()();

  TextColumn get privateKey => text().named('private_key')();

  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ContainerHosts extends Table {
  TextColumn get serverId => text().named('server_id')();

  TextColumn get host => text()();

  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {serverId};
}

class ConnectionStatsRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get serverId => text().named('server_id')();

  TextColumn get serverName => text().named('server_name')();

  IntColumn get timestampMs => integer().named('timestamp_ms')();

  TextColumn get result => text()();

  TextColumn get errorMessage => text().named('error_message')();

  IntColumn get durationMs => integer().named('duration_ms')();

  IntColumn get updatedAt => integer().named('updated_at')();
}

@DriftDatabase(
  tables: [
    Servers,
    ServerCustoms,
    ServerWolCfgs,
    ServerTags,
    ServerEnvs,
    ServerDisabledCmdTypes,
    Snippets,
    SnippetTags,
    SnippetAutoRuns,
    PrivateKeys,
    ContainerHosts,
    ConnectionStatsRecords,
  ],
)
class AppDb extends _$AppDb {
  AppDb._() : super(_openConnection());

  static final instance = AppDb._();
  static const dbFileName = 'app.db';

  static Future<String> resolveDbPath() async {
    final rootPath = switch (Pfs.type) {
      Pfs.linux || Pfs.windows => Paths.doc,
      _ => (await getApplicationDocumentsDirectory()).path,
    };
    return rootPath.joinPath(dbFileName);
  }

  static Future<File> resolveDbFile() async {
    return File(await resolveDbPath());
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      await _SqlCipherBootstrap.ensureConfigured();
      final cipherKey = await _SqlCipherBootstrap.loadOrCreateKey();
      final file = await resolveDbFile();

      return NativeDatabase(
        file,
        setup: (db) => _setupCipherDatabase(db, cipherKey),
      );
    });
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_connection_stats_server_time ON connection_stats_records(server_id, timestamp_ms DESC)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_server_tags_server ON server_tags(server_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_snippet_auto_runs_server ON snippet_auto_runs(server_id)',
      );
    },
    onUpgrade: (m, from, to) async {
      // Reserved for future migrations.
      if (from < 1) {
        await m.createAll();
      }
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_connection_stats_server_time ON connection_stats_records(server_id, timestamp_ms DESC)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_server_tags_server ON server_tags(server_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_snippet_auto_runs_server ON snippet_auto_runs(server_id)',
      );
    },
  );
}

void _setupCipherDatabase(sqlite3.Database database, String cipherKey) {
  final escapedKey = cipherKey.replaceAll("'", "''");
  database.execute("PRAGMA key = '$escapedKey';");

  final cipherVersionRows = database.select('PRAGMA cipher_version;');
  final cipherVersion =
      cipherVersionRows.isEmpty || cipherVersionRows.first.values.isEmpty
      ? null
      : cipherVersionRows.first.values.first?.toString();
  if (cipherVersion == null || cipherVersion.isEmpty) {
    throw StateError(
      'SQLCipher is not available. Please ensure sqlcipher_flutter_libs is linked correctly.',
    );
  }

  database.execute('PRAGMA foreign_keys = ON;');
  database.execute('PRAGMA journal_mode = WAL;');
}

abstract final class _SqlCipherBootstrap {
  static bool _configured = false;

  static Future<void> ensureConfigured() async {
    if (_configured) return;
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    sqlite_open.open.overrideFor(
      sqlite_open.OperatingSystem.android,
      openCipherOnAndroid,
    );
    _configured = true;
  }

  static Future<String> loadOrCreateKey() async {
    final existing = await SecureStoreProps.sqlitePwd.read();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    // Keep compatible with historical key source.
    // ignore: deprecated_member_use
    final oldHiveKey = await SecureStoreProps.hivePwd.read();
    final generated = oldHiveKey?.isNotEmpty == true
        ? oldHiveKey!
        : _generateKey();
    await SecureStoreProps.sqlitePwd.write(generated);
    return generated;
  }

  static String _generateKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
