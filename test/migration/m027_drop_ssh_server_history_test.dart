import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m027_drop_ssh_server_history.dart';
import 'package:server_box/data/store/schema.dart';

import '../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(openTestDb);
  tearDown(SqliteDb.close);

  test('is the last registered schema step', () {
    expect(const DropSshServerHistoryMigration().from, 27);
    expect(
      kSchemaMigrations.whereType<DropSshServerHistoryMigration>(),
      hasLength(1),
    );
    expect(kSchemaMigrations.last.from, SchemaVersion.current - 1);
  });

  test('deletes only the retired history value', () async {
    final history = SqliteStore('history');
    history.set('sshServerHistory', ['server-1']);
    history.set('sshTabs', '[{"sourceId":"server-1"}]');

    await const DropSshServerHistoryMigration().apply();

    expect(history.get<List>('sshServerHistory'), isNull);
    expect(history.get<String>('sshTabs'), isNotNull);
  });

  test('is idempotent', () async {
    await const DropSshServerHistoryMigration().apply();
    await const DropSshServerHistoryMigration().apply();

    expect(SqliteStore('history').get<List>('sshServerHistory'), isNull);
  });
}
