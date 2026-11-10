import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show LlmStores;
import 'package:server_box/data/store/secret.dart';
import 'package:server_box/data/store/setting.dart';

/// What ServerBox records for fl_lib's [SyncRecorder]: the kv stores that
/// sync, and the sync roots' tables, whose rows [SyncedTable] stamps.
abstract final class SyncedStores {
  /// The kv stores that sync, by name: the settings, the Agent's providers,
  /// tool switches and memory, and the secrets. Every other one stays on the
  /// device: `history` (what was typed and visited here) and the chats.
  static final byName = <String, SqliteStore>{
    for (final store in [
      SettingStore.instance,
      LlmStores.llm,
      LlmStores.tool,
      LlmStores.memory,
      LlmStores.credential,
      LlmStores.mcpSecret,
      SudoPasswordStore.instance,
      KeyPassphraseStore.instance,
      SyncRemoteStore.instance,
    ])
      store.name: store,
  };

  /// The sync roots' tables, by name: a migration seeds from them before any
  /// store is registered. `Stores.syncedTables` answers the same
  /// (`sync_recorder_test.dart`).
  static const roots = [
    'server',
    'private_key',
    'bmc_credential',
    'snippet',
    'port_forward',
    'remote_desktop_profile',
  ];

  /// Takes the kv edits from now on: at launch, outside any transaction.
  static void install() => SyncRecorder.install(byName.values);

  /// Fills `sync_record` from what the whole-backup sync stamped: each root's
  /// rows and tombstones, and each synced kv store's keys, as no device's
  /// stamps. A record already there keeps its stamp.
  static void seed() {
    final db = SqliteDb.instance;
    for (final table in roots) {
      SyncRecorder.seedRecords(table, [
        for (final row in db.select('SELECT id, updated_at FROM $table;')) (row['id'] as String, row['updated_at'] as int),
        for (final row in db.select('SELECT row_id, deleted_at FROM tombstone WHERE tbl = ?;', [table]))
          (row['row_id'] as String, row['deleted_at'] as int),
      ]);
    }
    for (final store in byName.values) {
      SyncRecorder.seedRecords(SyncRecorder.kvOf(store), [
        for (final MapEntry(:key, :value) in (store.lastUpdateTs ?? const <String, int>{}).entries) (key, value),
      ]);
    }
  }
}
