import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m024_remote_desktop_profiles.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/tables.dart';

List<(String, String, bool, int)> _columns() => [
  for (final row in SqliteDb.instance.select(
    'PRAGMA table_info(remote_desktop_profile);',
  ))
    (
      row['name'] as String,
      row['type'] as String,
      (row['notnull'] as int) == 1,
      row['pk'] as int,
    ),
];

void main() {
  setUp(() => SqliteDb.openInMemory());

  tearDown(() async {
    await closeTables();
    await SqliteDb.close();
  });

  test('is the registered final step', () {
    expect(const RemoteDesktopProfilesMigration().from, 24);
    expect(SchemaVersion.current, 25);
    expect(kSchemaMigrations.last, isA<RemoteDesktopProfilesMigration>());
    expect(kSchemaMigrations.last.from, SchemaVersion.current - 1);
  });

  test('creates the same columns as a fresh database', () async {
    await createTables(SqliteDb.instance);
    final fresh = _columns();

    await closeTables();
    await SqliteDb.close();
    SqliteDb.openInMemory();
    SqliteDb.instance.execute('PRAGMA foreign_keys = ON;');
    await createTables(SqliteDb.instance);
    SqliteDb.instance.execute('DROP TABLE remote_desktop_profile;');
    await const RemoteDesktopProfilesMigration().apply();

    expect(_columns(), fresh);
    expect(Tables.syncRoots, contains('remote_desktop_profile'));
  });

  test('is safe to resume after the table was already created', () async {
    await createTables(SqliteDb.instance);
    final before = _columns();
    await const RemoteDesktopProfilesMigration().apply();
    expect(_columns(), before);
  });
}
