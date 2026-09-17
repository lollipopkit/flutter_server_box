/// The names of the entity tables, for code that has to talk about them
/// rather than query them.
///
/// The DDL itself lives in `db.dart`: Drift owns it, and `tables_schema_test
/// .dart` is the acceptance test that what Drift creates keeps every
/// guarantee — the SSH-xor-monitor CHECK, the cascades, the unique names.
/// Two sources for one schema is the failure this change exists to stop.
///
/// What is *not* here: `setting` and `history`. Those are key-value by nature —
/// 103 unrelated preferences with no relations between them and nothing that
/// queries by field — so they stay rows in `kv`, and adding a preference stays
/// a one-line change rather than a schema migration.
///
/// Conventions, both of which the old key-value layout could not hold:
///
/// - **A primary key is an id, never something the user typed.** Snippets were
///   keyed by their name and private keys by a "name as id", so renaming
///   either silently broke every reference to it — `Spi.ssh.keyId` pointed at
///   a private key's name. Names are ordinary columns now, `UNIQUE` where the
///   UI requires it, and rename is an `UPDATE` of one column.
/// - **A list or map field is a child table**, not a JSON array in a column.
///   That is what makes "every server with this tag" a query rather than a
///   decode of every row, and what lets `ON DELETE CASCADE` clean up after a
///   deleted server instead of the six hand-written calls that used to.
abstract final class Tables {
  /// Tables holding one logical record each, and so the unit of sync.
  ///
  /// A server and its tags, envs, jump hosts and container settings move
  /// together: the children have no independent meaning and cascade with the
  /// parent, so only the parent carries the sync columns and editing a child
  /// bumps the parent's `updated_at`. Syncing children separately would mean a
  /// tag could arrive before the server it belongs to.
  ///
  /// `conn_stat` and `agent_conversation` are absent on purpose. Connecting to
  /// a server is not an edit, and a conversation carries terminal output and
  /// reasoning — neither leaves the device.
  static const syncRoots = [
    'private_key',
    'bmc_credential',
    'server',
    'snippet',
    'port_forward',
    'remote_desktop_profile',
  ];

  /// Every table the app owns, dependants after what they depend on.
  ///
  /// Used by the migration to write into them, and by tests to assert the
  /// database has nothing else in it.
  static const names = [
    'private_key',
    'bmc_credential',
    'server',
    'server_tag',
    'server_env',
    'server_jump',
    'server_disabled_cmd',
    'server_custom_cmd',
    'known_host',
    'container_host',
    'container_runtime',
    'snippet',
    'snippet_tag',
    'snippet_auto_run_on',
    'port_forward',
    'remote_desktop_profile',
    'conn_stat',
    'server_dist',
    'benchmark_run',
    'agent_conversation',
    'agent_active_conversation',
    'tombstone',
    'sync_state',
  ];
}
