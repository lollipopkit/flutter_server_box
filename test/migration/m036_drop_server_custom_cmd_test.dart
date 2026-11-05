/// The step that drops `server_custom_cmd`.
///
/// The v36 database is today's tables plus `server_custom_cmd` as Drift
/// created it from v4 to v36 (`createServerCustomCmdTable`): no SQLite
/// fixture written by a release exists (`test/fixtures/` holds Hive boxes
/// only).
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m036_drop_server_custom_cmd.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/server.dart';

import '../helpers/server_ddl.dart';
import '../helpers/test_db.dart';

void _seedV36(String id) {
  final db = SqliteDb.instance;
  createServerCustomCmdTable();
  db.execute(
    'INSERT INTO server (updated_at, rev, id, name, ssh_ip, ssh_port, '
    "ssh_user) VALUES (1700000000, 3, ?, 'router', '10.0.0.1', 22, 'root');",
    [id],
  );
  db.execute("INSERT INTO server_tag VALUES (?, 'prod');", [id]);
  db.execute("INSERT INTO server_env VALUES (?, 'TERM', 'xterm');", [id]);
  db.execute("INSERT INTO server_disabled_cmd VALUES (?, 'sensors');", [id]);
  db.execute("INSERT INTO server_custom_cmd VALUES (?, 'up', 'uptime');", [
    id,
  ]);
}

bool _hasTable() => SqliteDb.instance
    .select(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' "
      "AND name = 'server_custom_cmd';",
    )
    .isNotEmpty;

int _count(String table) =>
    SqliteDb.instance.select('SELECT count(*) AS n FROM $table;').single['n']
        as int;

void main() {
  setUp(openTestDb);
  tearDown(closeTestDb);

  test('is registered at its own step', () {
    expect(const DropServerCustomCmdMigration().from, 36);
    expect(
      kSchemaMigrations.whereType<DropServerCustomCmdMigration>(),
      hasLength(1),
    );
    expect(SchemaVersion.current, greaterThan(36));
  });

  test('a fresh install has no such table', () {
    expect(_hasTable(), isFalse);
  });

  test('drops the table and keeps the server with its other children', () async {
    _seedV36('s-1');
    expect(_hasTable(), isTrue);

    await const DropServerCustomCmdMigration().apply();
    await const DropServerCustomCmdMigration().apply();

    expect(_hasTable(), isFalse);
    expect(_count('server'), 1);
    expect(_count('server_tag'), 1);
    expect(_count('server_env'), 1);
    expect(_count('server_disabled_cmd'), 1);

    final spi = ServerStore.instance.fetchOneRaw('s-1')!;
    expect(spi.name, 'router');
    expect(spi.tags, ['prod']);
    expect(spi.envs, {'TERM': 'xterm'});
    expect(spi.disabledCmdTypes, ['sensors']);
    expect(spi.custom, isNull);
  });

  test('a database without the table is left alone', () async {
    await const DropServerCustomCmdMigration().apply();
    await const DropServerCustomCmdMigration().apply();

    expect(_hasTable(), isFalse);
  });
}
