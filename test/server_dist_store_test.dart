/// The cache of what each server was last seen running.
///
/// Two things it has to get right. m010 has to produce the same table Drift
/// creates for a fresh install — `createTables` is `IF NOT EXISTS` throughout,
/// so an upgrading install only ever gets the migration's version, and
/// `tables_schema_test.dart` only ever sees Drift's. And the reading has to
/// survive being written by a build that knew a `Dist` case this one does not.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/store/migrations/m010_server_dist.dart';
import 'package:server_box/data/store/server_dist.dart';
import 'package:server_box/data/store/tables.dart';

/// What SQLite reports about a table: its columns *and* its constraints.
///
/// The constraints are the half that matters here and the half a column list
/// cannot see. The whole delete story — a row going when its server does —
/// rests on `REFERENCES server(id) ON DELETE CASCADE`, and a primary key is
/// what stops two readings for one server. Hand-written DDL that dropped
/// either would have matched Drift's on `PRAGMA table_info`'s first three
/// fields and left the migration's version of the table quietly weaker.
({
  List<(String, String, bool, int)> columns,
  List<(String, String, String, String)> foreignKeys,
})
_schemaOf(String table) => (
  columns: [
    for (final row in SqliteDb.instance.select('PRAGMA table_info($table);'))
      (
        row['name'] as String,
        row['type'] as String,
        (row['notnull'] as int) == 1,
        row['pk'] as int,
      ),
  ],
  foreignKeys: [
    for (final row in SqliteDb.instance.select(
      'PRAGMA foreign_key_list($table);',
    ))
      (
        row['table'] as String,
        row['from'] as String,
        row['to'] as String,
        row['on_delete'] as String,
      ),
  ],
);

void main() {
  group('the migration', () {
    setUp(() => SqliteDb.openInMemory());
    tearDown(() async {
      await closeTables();
      await SqliteDb.close();
    });

    test('is the step that follows the one before it', () {
      expect(const ServerDistMigration().from, 10);
    });

    test('creates a table Drift would have created identically', () async {
      // Drift's version, from a fresh install.
      await createTables(SqliteDb.instance);
      final fromDrift = _schemaOf('server_dist');
      expect(fromDrift.columns, isNotEmpty, reason: 'Drift has to make it');
      expect(
        fromDrift.foreignKeys,
        contains(('server', 'server_id', 'id', 'CASCADE')),
        reason: 'the cascade is what makes a deleted server take its row',
      );

      // The migration's version, on a database that has the parent but not it.
      await closeTables();
      await SqliteDb.close();
      SqliteDb.openInMemory();
      await createTables(SqliteDb.instance);
      SqliteDb.instance.execute('DROP TABLE server_dist;');
      await const ServerDistMigration().apply();

      // Field by field: a record holding lists compares them by identity.
      final fromMigration = _schemaOf('server_dist');
      const why = 'an upgrading install only ever gets this version';
      expect(fromMigration.columns, fromDrift.columns, reason: why);
      expect(fromMigration.foreignKeys, fromDrift.foreignKeys, reason: why);
    });

    test('and running it again on the table it made changes nothing', () async {
      await createTables(SqliteDb.instance);
      final before = _schemaOf('server_dist');

      // The version is recorded only once apply() returns, so a process that
      // stops in between runs this again on the next launch.
      await const ServerDistMigration().apply();

      final after = _schemaOf('server_dist');
      expect(after.columns, before.columns);
      expect(after.foreignKeys, before.foreignKeys);
    });
  });

  group('the store', () {
    late ServerDistStore store;

    setUp(() async {
      SqliteDb.openInMemory();
      await createTables(SqliteDb.instance);
      SqliteDb.instance.execute('PRAGMA foreign_keys = ON;');
      // A reading is keyed by a server, so there has to be one to key it to.
      // A server is reached over SSH or over a monitor agent, never both and
      // never neither — the schema enforces it, so a row needs one of them.
      SqliteDb.instance.execute(
        "INSERT INTO server (id, name, ssh_ip) VALUES ('srv', 'prod', '10.0.0.1');",
      );
      SqliteDb.instance.execute(
        "INSERT INTO server (id, name, ssh_ip) VALUES ('srv2', 'web', '10.0.0.2');",
      );
      store = ServerDistStore();
    });

    tearDown(() async {
      await closeTables();
      await SqliteDb.close();
    });

    test('remembers a reading', () {
      store.put('srv', Dist.debian);
      expect(store.get('srv'), Dist.debian);
    });

    test('a server never seen has none', () {
      expect(store.get('srv2'), isNull);
      expect(store.get('no-such-server'), isNull);
    });

    test('a later reading replaces the earlier one', () {
      store.put('srv', Dist.debian);
      store.put('srv', Dist.ubuntu);
      expect(store.get('srv'), Dist.ubuntu);
      expect(
        SqliteDb.instance
            .select(
              "SELECT count(*) AS n FROM server_dist WHERE server_id = 'srv';",
            )
            .single['n'],
        1,
        reason: 'one row per server, replaced rather than appended',
      );
    });

    test('writing the same reading again does not touch the row', () {
      // A status poll runs every few seconds; a write and a cache drop per
      // tick would redraw every list in the app for nothing.
      store.put('srv', Dist.debian);
      final first = SqliteDb.instance
          .select(
            "SELECT updated_at AS t FROM server_dist WHERE server_id = 'srv';",
          )
          .single['t'];

      store.put('srv', Dist.debian);

      expect(
        SqliteDb.instance
            .select(
              "SELECT updated_at AS t FROM server_dist WHERE server_id = 'srv';",
            )
            .single['t'],
        first,
      );
    });

    test('it is stored by name, not by index', () {
      store.put('srv', Dist.rocky);
      expect(
        SqliteDb.instance
            .select(
              "SELECT dist AS d FROM server_dist WHERE server_id = 'srv';",
            )
            .single['d'],
        'rocky',
        reason: 'an index silently changes meaning when a case is inserted',
      );
    });

    test('a name this build does not know reads back as absent', () {
      // Written by a newer build that knew a case this one does not. Absent is
      // right: the row draws the neutral mark rather than throwing.
      SqliteDb.instance.execute(
        "INSERT INTO server_dist VALUES ('srv', 'somefuturedistro', 1);",
      );
      store.dropCache();
      expect(store.get('srv'), isNull);
    });

    test('deleting the server takes its reading with it', () {
      store.put('srv', Dist.debian);
      SqliteDb.instance.execute("DELETE FROM server WHERE id = 'srv';");
      store.dropCache();
      expect(store.get('srv'), isNull);
    });

    test('and a reading for a server that does not exist is refused', () {
      // The foreign key is what stops the cache outliving what it describes.
      expect(() => store.put('no-such-server', Dist.debian), throwsA(anything));
    });

    test('all() gives every reading at once', () {
      store.put('srv', Dist.debian);
      store.put('srv2', Dist.alpine);
      expect(store.all(), {'srv': Dist.debian, 'srv2': Dist.alpine});
    });

    test('remove forgets one without touching the others', () {
      store.put('srv', Dist.debian);
      store.put('srv2', Dist.alpine);

      store.remove('srv');

      expect(store.get('srv'), isNull);
      expect(store.get('srv2'), Dist.alpine);
    });
  });

  group('what a write announces', () {
    late ServerDistStore store;

    setUp(() async {
      SqliteDb.openInMemory();
      await createTables(SqliteDb.instance);
      SqliteDb.instance.execute('PRAGMA foreign_keys = ON;');
      SqliteDb.instance.execute(
        "INSERT INTO server (id, name, ssh_ip) VALUES ('a', 'prod', '10.0.0.1');",
      );
      store = ServerDistStore();
    });

    tearDown(() async {
      await closeTables();
      await SqliteDb.close();
    });

    // The stream is what every mark on screen redraws from, so an event that
    // says nothing changed is a redraw of every row for nothing.
    test('forgetting a reading nothing has is silent', () async {
      var events = 0;
      final sub = store.changes.listen((_) => events++);
      addTearDown(sub.cancel);

      store.remove('never-seen');
      await Future<void>.delayed(Duration.zero);
      expect(events, 0);

      // And forgetting one it does have is not.
      store.put('a', Dist.debian);
      await Future<void>.delayed(Duration.zero);
      store.remove('a');
      await Future<void>.delayed(Duration.zero);
      expect(events, 2);
      expect(store.get('a'), isNull);
    });
  });
}
