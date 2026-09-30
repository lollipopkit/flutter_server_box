import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Drops the Agent's conversations from before fl_pi_llm.
///
/// The Agent's chats are fl_pi_llm sessions now (`pi_chunks`, and the chat
/// list in `kv`), a shape these rows have no path to: they held one app's
/// request items — Responses reasoning, encrypted, among them — and were never
/// backed up or synced, being terminal output and reasoning. So they go
/// rather than being half-carried over.
///
/// The active-conversation table first: it references the other one.
/// Idempotent by construction: `IF EXISTS`.
class DropAgentConversationsMigration implements SchemaMigration {
  const DropAgentConversationsMigration();

  @override
  int get from => 31;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    db.execute('DROP INDEX IF EXISTS idx_agent_conversation_server_updated;');
    db.execute('DROP TABLE IF EXISTS agent_active_conversation;');
    db.execute('DROP TABLE IF EXISTS agent_conversation;');
  }
}
