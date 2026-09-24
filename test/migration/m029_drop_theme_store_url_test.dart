import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m029_drop_theme_store_url.dart';
import 'package:server_box/data/store/schema.dart';

import '../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(openTestDb);
  tearDown(SqliteDb.close);

  test('is the last registered schema step', () {
    expect(const DropThemeStoreUrlMigration().from, 29);
    expect(
      kSchemaMigrations.whereType<DropThemeStoreUrlMigration>(),
      hasLength(1),
    );
    expect(kSchemaMigrations.last.from, SchemaVersion.current - 1);
  });

  test('deletes only the retired catalog address', () async {
    final setting = SqliteStore('setting');
    setting.set('themeStoreUrl', 'https://example.com/repos.toml');
    setting.set('themeStoreCache', '{"repos":[]}');

    await const DropThemeStoreUrlMigration().apply();

    expect(setting.get<String>('themeStoreUrl'), isNull);
    expect(setting.get<String>('themeStoreCache'), isNotNull);
  });

  test('is idempotent', () async {
    await const DropThemeStoreUrlMigration().apply();
    await const DropThemeStoreUrlMigration().apply();

    expect(SqliteStore('setting').get<String>('themeStoreUrl'), isNull);
  });
}
