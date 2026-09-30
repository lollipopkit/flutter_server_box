import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m031_drop_agent_conversations.dart';
import 'package:server_box/data/store/schema.dart';

import '../helpers/test_db.dart';

/// The two tables as the release before this step created them — Drift's
/// DDL for `AgentConversations` and `AgentActiveConversations`, and the index
/// `createTables` added — with a conversation in each.
void _seedLastRelease() {
  final db = SqliteDb.instance;
  db.execute('''
    CREATE TABLE IF NOT EXISTS "agent_conversation" (
      "id" TEXT NOT NULL, "server_id" TEXT NOT NULL,
      "updated_at" INTEGER NOT NULL, "data" TEXT NOT NULL,
      PRIMARY KEY ("id")) WITHOUT ROWID;
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS "agent_active_conversation" (
      "server_id" TEXT NOT NULL,
      "conversation_id" TEXT NOT NULL
        REFERENCES agent_conversation (id) ON DELETE CASCADE,
      PRIMARY KEY ("server_id")) WITHOUT ROWID;
  ''');
  db.execute(
    'CREATE INDEX IF NOT EXISTS idx_agent_conversation_server_updated '
    'ON agent_conversation(server_id, updated_at DESC);',
  );
  db.execute(
    'INSERT INTO agent_conversation VALUES (?, ?, ?, ?);',
    ['conv-1', 'srv-1', 1, '{"id":"conv-1","server_id":"srv-1","items":[]}'],
  );
  db.execute('INSERT INTO agent_active_conversation VALUES (?, ?);', [
    'srv-1',
    'conv-1',
  ]);
}

List<String> _leftovers() => [
  for (final row in SqliteDb.instance.select(
    "SELECT name FROM sqlite_master WHERE name LIKE '%agent_%conversation%';",
  ))
    row['name'] as String,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(openTestDb);
  tearDown(SqliteDb.close);

  test('is the last registered schema step', () {
    expect(const DropAgentConversationsMigration().from, 31);
    expect(
      kSchemaMigrations.whereType<DropAgentConversationsMigration>(),
      hasLength(1),
    );
    expect(kSchemaMigrations.last.from, SchemaVersion.current - 1);
  });

  test('drops both tables and their index, with what was in them', () async {
    _seedLastRelease();
    expect(_leftovers(), isNotEmpty);

    await const DropAgentConversationsMigration().apply();

    expect(_leftovers(), isEmpty);
  });

  test('is idempotent, and a database without them is left alone', () async {
    await const DropAgentConversationsMigration().apply();
    _seedLastRelease();
    await const DropAgentConversationsMigration().apply();
    await const DropAgentConversationsMigration().apply();

    expect(_leftovers(), isEmpty);
  });
}
