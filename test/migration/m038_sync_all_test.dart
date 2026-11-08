import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show LlmStores;
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m038_sync_all.dart';
import 'package:server_box/data/store/schema.dart';

import '../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(openTestDb);
  tearDown(SqliteDb.close);

  test('is registered at its own step', () {
    expect(const SyncAllMigration().from, 38);
    expect(kSchemaMigrations.whereType<SyncAllMigration>(), hasLength(1));
    expect(SchemaVersion.current, greaterThan(38));
  });

  test('joins the logs again, keeping what they are bound to', () async {
    final db = SqliteDb.instance;
    db.execute('DROP TABLE IF EXISTS sync_passed;');
    // What v38 kept: the log's place, a device that left settings out, and
    // the account and store each is bound to.
    for (final (k, v) in [
      ('log.log', 'L1'),
      ('log.cursor', '12'),
      ('log.sent', 'h'),
      ('log.joined', 'L1'),
      ('log.partial', '1'),
      ('log.account', 'acct'),
      ('seg.store', 'webdav'),
      ('seg.n', '3'),
      ('seg.partial', '1'),
      ('device', 'abc'),
    ]) {
      db.execute('INSERT INTO sync_state (k, v) VALUES (?, ?);', [k, v]);
    }

    await const SyncAllMigration().apply();

    final left = {for (final r in db.select('SELECT k, v FROM sync_state;')) r['k'] as String: r['v'] as String};
    expect(left, {'log.account': 'acct', 'seg.store': 'webdav', 'device': 'abc'});
    db.execute("INSERT INTO sync_passed (e, c, id, h, d) VALUES ('log.', 'kv:setting', 'k', 'h', 'null');");
    expect(db.select('SELECT COUNT(*) AS n FROM sync_passed;').first['n'], 1);
    // Idempotent.
    await const SyncAllMigration().apply();
  });

  test("makes records of the Agent's stores", () async {
    LlmStores.tool.enabled.put(false);
    SqliteDb.instance.execute('DELETE FROM sync_record;');

    await const SyncAllMigration().apply();

    final ids = [
      for (final r in SqliteDb.instance.select("SELECT id FROM sync_record WHERE c = 'kv:tool';")) r['id'],
    ];
    expect(ids, ['enabled']);
  });
}
