import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/db.dart';
import 'package:server_box/data/store/tables.dart';
import 'package:sqlite3/sqlite3.dart';

/// What the schema itself guarantees, rather than what the Dart above it
/// remembers to do.
///
/// Each of these was previously a rule living in one call site: the SSH/monitor
/// exclusivity in `Spix.validate()`, the orphan cleanup in `delServer`, the
/// uniqueness of a snippet name in whatever dialog last checked. A rule in one
/// call site is a rule until someone adds a second call site.
void main() {
  late Database db;

  late AppDb appDb;

  // Created by Drift, asserted through the raw handle it was handed. Drift
  // owns the DDL; these are the guarantees it has to deliver.
  setUp(() async {
    db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON;');
    appDb = AppDb(NativeDatabase.opened(db));
    // Forces `onCreate`; nothing exists until the executor opens.
    await appDb.customStatement('SELECT 1;');
  });

  tearDown(() async {
    await appDb.close();
  });

  void addServer(
    String id, {
    String? sshIp = '10.0.0.1',
    String? monitorAddr,
    String? keyId,
  }) {
    db.execute(
      'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user, ssh_key_id, '
      'monitor_addr) VALUES (?, ?, ?, ?, ?, ?, ?);',
      [
        id,
        'srv $id',
        sshIp,
        sshIp == null ? null : 22,
        sshIp == null ? null : 'root',
        keyId,
        monitorAddr,
      ],
    );
  }

  test('Drift creates exactly the tables the app names', () {
    final tables = db
        .select("SELECT name FROM sqlite_master WHERE type='table';")
        .map((r) => r['name'] as String)
        .where((n) => !n.startsWith('sqlite_'));
    expect(tables.toSet(), Tables.names.toSet());
  });

  group('a server is reached one way or the other', () {
    test('SSH alone is accepted', () {
      expect(() => addServer('a'), returnsNormally);
    });

    test('a monitor agent alone is accepted', () {
      expect(
        () => addServer('b', sshIp: null, monitorAddr: 'https://h:3770'),
        returnsNormally,
      );
    });

    test('both at once is refused', () {
      expect(
        () => addServer('c', monitorAddr: 'https://h:3770'),
        throwsA(isA<SqliteException>()),
      );
    });

    test('neither is refused', () {
      expect(
        () => addServer('d', sshIp: null),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  test('deleting a server takes everything hanging off it', () {
    addServer('srv');
    db.execute("INSERT INTO server_tag VALUES ('srv', 'prod');");
    db.execute("INSERT INTO server_env VALUES ('srv', 'TERM', 'xterm');");
    db.execute("INSERT INTO server_disabled_cmd VALUES ('srv', 'sensors');");
    db.execute("INSERT INTO server_custom_cmd VALUES ('srv', 'up', 'uptime');");
    db.execute("INSERT INTO known_host VALUES ('srv', 'ssh-ed25519', 'SHA256:x');");
    db.execute(
      'INSERT INTO port_forward (id, server_id, name, type, local_port) '
      "VALUES ('pf', 'srv', 'pg', 'local', 15432);",
    );
    db.execute(
      "INSERT INTO conn_stat VALUES ('cs', 'srv', 'srv', 1, 'success', '', 5);",
    );

    db.execute("DELETE FROM server WHERE id = 'srv';");

    for (final t in const [
      'server_tag',
      'server_env',
      'server_disabled_cmd',
      'server_custom_cmd',
      'known_host',
      'port_forward',
      'conn_stat',
    ]) {
      expect(
        db.select('SELECT count(*) AS n FROM $t;').single['n'],
        0,
        reason: '$t still has rows for a server that is gone',
      );
    }
  });

  test('deleting a private key keeps the servers that used it', () {
    db.execute('INSERT INTO private_key (id, name, key) '
        "VALUES ('k1', 'work', 'PRIVATE');");
    addServer('srv', keyId: 'k1');

    db.execute("DELETE FROM private_key WHERE id = 'k1';");

    final row = db.select("SELECT ssh_key_id FROM server WHERE id = 'srv';");
    expect(row.length, 1, reason: 'the server must survive');
    expect(row.single['ssh_key_id'], isNull, reason: 'and ask for a new key');
  });

  test('a jump host that is deleted stops being one', () {
    addServer('a');
    addServer('b');
    db.execute("INSERT INTO server_jump VALUES ('a', 0, 'b');");

    db.execute("DELETE FROM server WHERE id = 'b';");

    expect(db.select('SELECT count(*) AS n FROM server_jump;').single['n'], 0);
    expect(db.select("SELECT count(*) AS n FROM server WHERE id = 'a';")
        .single['n'], 1);
  });

  test('an auto-run target that is deleted stops being one', () {
    addServer('srv');
    db.execute('INSERT INTO snippet (id, name, script) '
        "VALUES ('s1', 'deploy', 'echo');");
    db.execute("INSERT INTO snippet_auto_run_on VALUES ('s1', 'srv');");

    db.execute("DELETE FROM server WHERE id = 'srv';");

    expect(
      db.select('SELECT count(*) AS n FROM snippet_auto_run_on;').single['n'],
      0,
    );
    expect(db.select('SELECT count(*) AS n FROM snippet;').single['n'], 1,
        reason: 'the snippet itself is not a per-server thing');
  });

  test('a name the user typed is not a key, but is still unique', () {
    db.execute('INSERT INTO snippet (id, name, script) '
        "VALUES ('s1', 'deploy', 'echo a');");
    // A different snippet, same name.
    expect(
      () => db.execute('INSERT INTO snippet (id, name, script) '
          "VALUES ('s2', 'deploy', 'b');"),
      throwsA(isA<SqliteException>()),
    );
    // Renaming is one column, and s1 keeps its identity.
    db.execute("UPDATE snippet SET name = 'release' WHERE id = 's1';");
    expect(db.select("SELECT name FROM snippet WHERE id = 's1';")
        .single['name'], 'release');
  });

  test('a port forward names a real server and a real type', () {
    expect(
      () => db.execute(
        'INSERT INTO port_forward (id, server_id, name, type, local_port) '
        "VALUES ('pf', 'nope', 'x', 'local', 1);",
      ),
      throwsA(isA<SqliteException>()),
      reason: 'no such server',
    );

    addServer('srv');
    expect(
      () => db.execute(
        'INSERT INTO port_forward (id, server_id, name, type, local_port) '
        "VALUES ('pf', 'srv', 'x', 'sideways', 1);",
      ),
      throwsA(isA<SqliteException>()),
      reason: 'no such forward type',
    );
  });

  test('a port number has to be one', () {
    expect(
      () => db.execute(
        'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user) '
        "VALUES ('x', 'x', '10.0.0.1', 70000, 'root');",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  group('sync metadata', () {
    test('every sync root carries updated_at and rev', () {
      for (final t in Tables.syncRoots) {
        final cols = db
            .select('PRAGMA table_info($t);')
            .map((r) => r['name'] as String)
            .toSet();
        expect(cols, containsAll(['updated_at', 'rev']), reason: t);
      }
    });

    test('a child table has neither: it moves with its parent', () {
      for (final t in const ['server_tag', 'server_env', 'server_jump']) {
        final cols = db
            .select('PRAGMA table_info($t);')
            .map((r) => r['name'] as String)
            .toSet();
        expect(cols, isNot(contains('updated_at')), reason: t);
      }
    });

    test('an incremental pull is one indexed query per root', () {
      addServer('a');
      db.execute("UPDATE server SET updated_at = 100 WHERE id = 'a';");
      addServer('b');
      db.execute("UPDATE server SET updated_at = 300 WHERE id = 'b';");

      final since = db
          .select('SELECT id FROM server WHERE updated_at > ? ORDER BY id;', [200])
          .map((r) => r['id'])
          .toList();
      expect(since, ['b'], reason: 'only what changed since the watermark');
    });

    test('a deletion is a fact that survives, so it can travel', () {
      addServer('gone');
      db.execute("DELETE FROM server WHERE id = 'gone';");
      // The store records it; the schema is what makes the record possible.
      db.execute("INSERT INTO tombstone VALUES ('server', 'gone', 500);");

      final deleted = db
          .select('SELECT row_id FROM tombstone WHERE tbl = ? AND deleted_at > ?;',
              ['server', 400])
          .map((r) => r['row_id'])
          .toList();
      expect(deleted, ['gone'],
          reason: 'without this a peer re-adds the row it still has');
    });
  });

  test('tags are queryable, not decodable', () {
    addServer('a');
    addServer('b');
    db.execute("INSERT INTO server_tag VALUES ('a', 'prod'), ('b', 'prod'), "
        "('a', 'db');");

    // The question the server list asks, as one statement rather than a decode
    // of every record.
    final tagged = db
        .select("SELECT server_id FROM server_tag WHERE tag = 'prod' "
            'ORDER BY server_id;')
        .map((r) => r['server_id'])
        .toList();
    expect(tagged, ['a', 'b']);

    final allTags = db
        .select('SELECT DISTINCT tag FROM server_tag ORDER BY tag;')
        .map((r) => r['tag'])
        .toList();
    expect(allTags, ['db', 'prod']);
  });
}
