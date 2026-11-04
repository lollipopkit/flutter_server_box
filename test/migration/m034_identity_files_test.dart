import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m034_identity_files.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/tables.dart';

/// The table as SQLite describes it, columns and foreign keys.
String _shape() => '${(
  [
    for (final r in SqliteDb.instance.select('PRAGMA table_info(server_identity_file);'))
      (r['name'], r['type'], r['notnull'], r['pk']),
  ],
  [
    for (final r in SqliteDb.instance.select('PRAGMA foreign_key_list(server_identity_file);'))
      (r['table'], r['from'], r['to'], r['on_delete']),
  ],
)}';

/// What a v34 database looks like: no child table, the paths in the column.
Future<void> _v34() async {
  await createTables(SqliteDb.instance);
  SqliteDb.instance.execute('DROP TABLE server_identity_file;');
}

void _server(String id, String? keyPath) => SqliteDb.instance.execute(
  'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user, ssh_key_path) '
  'VALUES (?, ?, ?, 22, ?, ?);',
  [id, id, '10.0.0.1', 'root', keyPath],
);

void main() {
  setUp(() => SqliteDb.openInMemory());

  tearDown(() async {
    await closeTables();
    await SqliteDb.close();
  });

  test('is registered once, from 34', () {
    expect(const IdentityFilesMigration().from, 34);
    expect(kSchemaMigrations.whereType<IdentityFilesMigration>(), hasLength(1));
  });

  test('creates the table a fresh database has', () async {
    await createTables(SqliteDb.instance);
    final fresh = _shape();
    await closeTables();
    await SqliteDb.close();
    SqliteDb.openInMemory();
    await _v34();

    await const IdentityFilesMigration().apply();

    expect(_shape(), fresh);
  });

  /// The two shapes the store wrote before this step: one path as itself,
  /// several as JSON behind the prefix — and a literal that only shares it.
  test('moves what the column held into rows, in order', () async {
    await _v34();
    _server('one', '~/.ssh/id_ed25519');
    _server('many', '${IdentityFilesMigration.legacyPrefix}["~/.ssh/a","","~/.ssh/b"]');
    _server('odd', '${IdentityFilesMigration.legacyPrefix}not json');
    _server('none', null);

    await const IdentityFilesMigration().apply();

    final store = ServerStore();
    expect(store.fetchOneRaw('one')!.ssh!.resolvedIdentityFiles, ['~/.ssh/id_ed25519']);
    expect(store.fetchOneRaw('many')!.ssh!.resolvedIdentityFiles, ['~/.ssh/a', '~/.ssh/b']);
    expect(
      store.fetchOneRaw('odd')!.ssh!.resolvedIdentityFiles,
      ['${IdentityFilesMigration.legacyPrefix}not json'],
    );
    expect(store.fetchOneRaw('none')!.ssh!.resolvedIdentityFiles, isEmpty);
    expect(
      SqliteDb.instance.select('SELECT 1 FROM server WHERE ssh_key_path IS NOT NULL;'),
      isEmpty,
    );
  });

  test('is safe to run again', () async {
    await _v34();
    _server('many', '${IdentityFilesMigration.legacyPrefix}["~/.ssh/a","~/.ssh/b"]');
    await const IdentityFilesMigration().apply();
    await const IdentityFilesMigration().apply();

    expect(ServerStore().fetchOneRaw('many')!.ssh!.resolvedIdentityFiles, ['~/.ssh/a', '~/.ssh/b']);
  });

  test('the rows go with their server', () async {
    await _v34();
    _server('one', '~/.ssh/id');
    await const IdentityFilesMigration().apply();

    SqliteDb.instance.execute('PRAGMA foreign_keys = ON;');
    SqliteDb.instance.execute("DELETE FROM server WHERE id = 'one';");

    expect(SqliteDb.instance.select('SELECT 1 FROM server_identity_file;'), isEmpty);
  });
}
