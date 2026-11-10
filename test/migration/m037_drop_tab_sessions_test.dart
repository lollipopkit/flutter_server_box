import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m037_drop_tab_sessions.dart';
import 'package:server_box/data/store/schema.dart';

import '../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(openTestDb);
  tearDown(SqliteDb.close);

  test('is registered at its own step', () {
    expect(const DropTabSessionsMigration().from, 37);
    expect(
      kSchemaMigrations.whereType<DropTabSessionsMigration>(),
      hasLength(1),
    );
    expect(SchemaVersion.current, greaterThan(37));
  });

  test('deletes only the saved tab sessions', () async {
    // The shapes v37 wrote.
    final history = SqliteStore('history');
    history.set(
      'sshTabs',
      '[{"sourceId":"server-1","tmuxSession":"main","tmuxWindow":0}]',
    );
    history.set('fileTabs', '[{"kind":"local","path":"/tmp"}]');
    history.set('workspaces', '[]');

    await const DropTabSessionsMigration().apply();

    expect(history.get<String>('sshTabs'), isNull);
    expect(history.get<String>('fileTabs'), isNull);
    expect(history.get<String>('workspaces'), '[]');
  });

  test('is idempotent', () async {
    await const DropTabSessionsMigration().apply();
    await const DropTabSessionsMigration().apply();

    expect(SqliteStore('history').get<String>('sshTabs'), isNull);
  });
}
