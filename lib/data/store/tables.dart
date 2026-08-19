import 'package:sqlite3/sqlite3.dart';

/// Every entity table, in dependency order.
///
/// One module rather than a `CREATE TABLE` inside each store, because foreign
/// keys impose an order: `server` cannot reference `private_key` before it
/// exists, and `server_tag` cannot reference `server`. Spreading the DDL across
/// the stores would make that order depend on which store happened to be
/// constructed first.
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
  /// Runs every `CREATE TABLE`/`CREATE INDEX`, in an order the foreign keys
  /// allow. Safe to re-run: everything is `IF NOT EXISTS`.
  static void createAll(Database db) {
    for (final statement in _ddl) {
      db.execute(statement);
    }
  }

  /// Tables holding one logical record each, and so the unit of sync.
  ///
  /// A server and its tags, envs and jump hosts move together: the children
  /// have no independent meaning and cascade with the parent, so only the
  /// parent carries [syncColumns] and editing a child bumps the parent's
  /// `updated_at`. Syncing children separately would mean a tag could arrive
  /// before the server it belongs to.
  static const syncRoots = [
    'private_key',
    'server',
    'snippet',
    'port_forward',
    'container_host',
    'agent_conversation',
  ];

  /// Appended to every table in [syncRoots].
  ///
  /// `updated_at` is what an incremental sync selects on. `rev` distinguishes
  /// two edits inside the same millisecond, which a clock alone cannot, and
  /// makes "has this actually changed" answerable without comparing every
  /// column.
  static const syncColumns = '''
  updated_at INTEGER NOT NULL DEFAULT 0,
  rev        INTEGER NOT NULL DEFAULT 0''';

  /// Every table this module owns, dependants after what they depend on.
  ///
  /// Used by the migration to write into them, and by tests to assert the
  /// database has nothing else in it.
  static const names = [
    'private_key',
    'server',
    'server_tag',
    'server_env',
    'server_jump',
    'server_disabled_cmd',
    'server_custom_cmd',
    'known_host',
    'snippet',
    'snippet_tag',
    'snippet_auto_run_on',
    'port_forward',
    'container_host',
    'conn_stat',
    'agent_conversation',
    'agent_active_conversation',
    'tombstone',
    'sync_state',
  ];

  static const _ddl = [
    // ---- private_key -----------------------------------------------------
    // `name` is what the user typed and what the UI lists; `id` is what
    // `server.ssh_key_id` points at, so a rename cannot orphan a server.
    '''
CREATE TABLE IF NOT EXISTS private_key (
  id   TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  key  TEXT NOT NULL,
  updated_at INTEGER NOT NULL DEFAULT 0,
  rev        INTEGER NOT NULL DEFAULT 0
) WITHOUT ROWID;
''',

    // ---- server ----------------------------------------------------------
    // The SSH and monitor credentials are columns on the server rather than
    // tables of their own: both are one-to-one and neither is ever queried
    // without it. `ServerConnectCredential.fromSpi` picks by which one is set,
    // and the CHECK is that rule written where it cannot be forgotten — the
    // app enforced it in `Spix.validate()` alone, so a record could be written
    // with both or neither and only fail later, at connect time.
    //
    // `ON DELETE SET NULL` for the key: deleting a private key must not delete
    // the servers that used it, it must leave them asking for a new one.
    '''
CREATE TABLE IF NOT EXISTS server (
  id                TEXT    NOT NULL PRIMARY KEY,
  name              TEXT    NOT NULL,
  auto_connect      INTEGER NOT NULL DEFAULT 1 CHECK (auto_connect IN (0, 1)),
  system_type       TEXT,

  ssh_ip            TEXT,
  ssh_port          INTEGER CHECK (ssh_port IS NULL OR ssh_port BETWEEN 1 AND 65535),
  ssh_user          TEXT,
  ssh_pwd           TEXT,
  ssh_key_id        TEXT REFERENCES private_key(id) ON DELETE SET NULL,
  ssh_key_path      TEXT,
  ssh_alter_url     TEXT,
  ssh_proxy_command TEXT,

  monitor_addr        TEXT,
  monitor_user        TEXT,
  monitor_pwd         TEXT,
  monitor_ignore_cert INTEGER CHECK (monitor_ignore_cert IN (0, 1)),

  wol_mac           TEXT,
  wol_ip            TEXT,
  wol_pwd           TEXT,

  pve_addr          TEXT,
  pve_ignore_cert   INTEGER NOT NULL DEFAULT 0 CHECK (pve_ignore_cert IN (0, 1)),
  pve_pwd           TEXT,
  prefer_temp_dev   TEXT,
  temp_is_celsius   INTEGER NOT NULL DEFAULT 1 CHECK (temp_is_celsius IN (0, 1)),
  logo_url          TEXT,
  net_dev           TEXT,
  script_dir        TEXT,

  updated_at        INTEGER NOT NULL DEFAULT 0,
  rev               INTEGER NOT NULL DEFAULT 0,

  -- Reached over SSH or over a monitor agent, never both and never neither.
  CHECK ((ssh_ip IS NOT NULL) <> (monitor_addr IS NOT NULL))
) WITHOUT ROWID;
''',
    'CREATE INDEX IF NOT EXISTS idx_server_key ON server(ssh_key_id);',

    // ---- server child tables ---------------------------------------------
    // A tag was an element of a JSON array, so "which servers have this tag"
    // meant decoding every server. It is an index lookup now, and the tag list
    // the UI builds is one `SELECT DISTINCT`.
    '''
CREATE TABLE IF NOT EXISTS server_tag (
  server_id TEXT NOT NULL REFERENCES server(id) ON DELETE CASCADE,
  tag       TEXT NOT NULL,
  PRIMARY KEY (server_id, tag)
) WITHOUT ROWID;
''',
    'CREATE INDEX IF NOT EXISTS idx_server_tag_tag ON server_tag(tag);',

    '''
CREATE TABLE IF NOT EXISTS server_env (
  server_id TEXT NOT NULL REFERENCES server(id) ON DELETE CASCADE,
  key       TEXT NOT NULL,
  value     TEXT NOT NULL,
  PRIMARY KEY (server_id, key)
) WITHOUT ROWID;
''',

    // `ord` keeps the order the user chose: at most the first two are used as
    // failover candidates, so which is first is meaningful.
    '''
CREATE TABLE IF NOT EXISTS server_jump (
  server_id TEXT    NOT NULL REFERENCES server(id) ON DELETE CASCADE,
  ord       INTEGER NOT NULL,
  jump_id   TEXT    NOT NULL REFERENCES server(id) ON DELETE CASCADE,
  PRIMARY KEY (server_id, ord)
) WITHOUT ROWID;
''',
    'CREATE INDEX IF NOT EXISTS idx_server_jump_target ON server_jump(jump_id);',

    '''
CREATE TABLE IF NOT EXISTS server_disabled_cmd (
  server_id TEXT NOT NULL REFERENCES server(id) ON DELETE CASCADE,
  cmd_type  TEXT NOT NULL,
  PRIMARY KEY (server_id, cmd_type)
) WITHOUT ROWID;
''',

    // `ServerCustom.cmds`, a map of name -> command.
    '''
CREATE TABLE IF NOT EXISTS server_custom_cmd (
  server_id TEXT NOT NULL REFERENCES server(id) ON DELETE CASCADE,
  name      TEXT NOT NULL,
  cmd       TEXT NOT NULL,
  PRIMARY KEY (server_id, name)
) WITHOUT ROWID;
''',

    // Was a JSON map in `setting`, keyed `<serverId>::<keyType>` — so deleting
    // a server left its trusted fingerprints behind for ever, and nothing
    // could tell whose they were.
    '''
CREATE TABLE IF NOT EXISTS known_host (
  server_id   TEXT NOT NULL REFERENCES server(id) ON DELETE CASCADE,
  key_type    TEXT NOT NULL,
  fingerprint TEXT NOT NULL,
  PRIMARY KEY (server_id, key_type)
) WITHOUT ROWID;
''',

    // ---- snippet ---------------------------------------------------------
    '''
CREATE TABLE IF NOT EXISTS snippet (
  id     TEXT NOT NULL PRIMARY KEY,
  name   TEXT NOT NULL UNIQUE,
  script TEXT NOT NULL,
  note   TEXT,
  updated_at INTEGER NOT NULL DEFAULT 0,
  rev        INTEGER NOT NULL DEFAULT 0
) WITHOUT ROWID;
''',
    '''
CREATE TABLE IF NOT EXISTS snippet_tag (
  snippet_id TEXT NOT NULL REFERENCES snippet(id) ON DELETE CASCADE,
  tag        TEXT NOT NULL,
  PRIMARY KEY (snippet_id, tag)
) WITHOUT ROWID;
''',
    'CREATE INDEX IF NOT EXISTS idx_snippet_tag_tag ON snippet_tag(tag);',

    // Both sides cascade: a deleted snippet stops being auto-run, and a
    // deleted server stops being a target. Neither used to happen.
    '''
CREATE TABLE IF NOT EXISTS snippet_auto_run_on (
  snippet_id TEXT NOT NULL REFERENCES snippet(id) ON DELETE CASCADE,
  server_id  TEXT NOT NULL REFERENCES server(id)  ON DELETE CASCADE,
  PRIMARY KEY (snippet_id, server_id)
) WITHOUT ROWID;
''',
    'CREATE INDEX IF NOT EXISTS idx_snippet_auto_run_server '
        'ON snippet_auto_run_on(server_id);',

    // ---- port_forward ----------------------------------------------------
    '''
CREATE TABLE IF NOT EXISTS port_forward (
  id          TEXT    NOT NULL PRIMARY KEY,
  server_id   TEXT    NOT NULL REFERENCES server(id) ON DELETE CASCADE,
  name        TEXT    NOT NULL,
  type        TEXT    NOT NULL CHECK (type IN ('local', 'remote', 'dynamic')),
  local_host  TEXT,
  local_port  INTEGER NOT NULL DEFAULT 0,
  remote_host TEXT,
  remote_port INTEGER,
  updated_at  INTEGER NOT NULL DEFAULT 0,
  rev         INTEGER NOT NULL DEFAULT 0
) WITHOUT ROWID;
''',
    'CREATE INDEX IF NOT EXISTS idx_port_forward_server '
        'ON port_forward(server_id);',

    // ---- container_host --------------------------------------------------
    // `server_id` is '' for the global default, which is why there is no
    // foreign key here: the empty id belongs to no server.
    '''
CREATE TABLE IF NOT EXISTS container_host (
  server_id  TEXT NOT NULL,
  type       TEXT NOT NULL CHECK (type IN ('docker', 'podman')),
  host       TEXT NOT NULL,
  updated_at INTEGER NOT NULL DEFAULT 0,
  rev        INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (server_id, type)
) WITHOUT ROWID;
''',

    // ---- conn_stat -------------------------------------------------------
    // `id` is generated, not `<serverId>_<millis>`: two attempts in the same
    // millisecond collided on that key and the second overwrote the first,
    // which the counters are computed from.
    //
    // `server_name` stays denormalised on purpose — it is what the server was
    // called at the time, and a renamed server must not rewrite its history.
    '''
CREATE TABLE IF NOT EXISTS conn_stat (
  id            TEXT    NOT NULL PRIMARY KEY,
  server_id     TEXT    NOT NULL REFERENCES server(id) ON DELETE CASCADE,
  server_name   TEXT    NOT NULL,
  timestamp     INTEGER NOT NULL,
  result        TEXT    NOT NULL,
  error_message TEXT    NOT NULL DEFAULT '',
  duration_ms   INTEGER NOT NULL
) WITHOUT ROWID;
''',
    'CREATE INDEX IF NOT EXISTS idx_conn_stat_server_ts '
        'ON conn_stat(server_id, timestamp DESC);',
    'CREATE INDEX IF NOT EXISTS idx_conn_stat_ts ON conn_stat(timestamp);',

    // ---- agent_conversation ----------------------------------------------
    // `data` stays JSON: a conversation is an ordered log of heterogeneous
    // items (messages, tool calls, tool output) that is only ever read whole,
    // never queried by field. Columns would buy nothing and cost a migration
    // every time a new item kind is added.
    //
    // `server_id` has no foreign key: the global agent uses a scope id that is
    // not a server.
    '''
CREATE TABLE IF NOT EXISTS agent_conversation (
  id         TEXT    NOT NULL PRIMARY KEY,
  server_id  TEXT    NOT NULL,
  updated_at INTEGER NOT NULL,
  data       TEXT    NOT NULL,
  rev        INTEGER NOT NULL DEFAULT 0
) WITHOUT ROWID;
''',
    'CREATE INDEX IF NOT EXISTS idx_agent_conversation_server_updated '
        'ON agent_conversation(server_id, updated_at DESC);',
    '''
CREATE TABLE IF NOT EXISTS agent_active_conversation (
  server_id       TEXT NOT NULL PRIMARY KEY,
  conversation_id TEXT NOT NULL REFERENCES agent_conversation(id) ON DELETE CASCADE
) WITHOUT ROWID;
''',

    // ---- sync bookkeeping ------------------------------------------------
    // A delete has to be a fact that can travel. Without a tombstone the peer
    // that still has the row treats it as an addition and puts it back, which
    // is how a deleted server reappears on the next sync.
    //
    // Swept once the row is older than every peer's watermark; until then it
    // is the only record that the deletion happened.
    '''
CREATE TABLE IF NOT EXISTS tombstone (
  tbl        TEXT    NOT NULL,
  row_id     TEXT    NOT NULL,
  deleted_at INTEGER NOT NULL,
  PRIMARY KEY (tbl, row_id)
) WITHOUT ROWID;
''',
    'CREATE INDEX IF NOT EXISTS idx_tombstone_deleted ON tombstone(deleted_at);',

    // This device's id, and how far it has read each peer's log. Key-value
    // because it is bookkeeping about sync rather than anything synced, and
    // it must never itself be uploaded.
    '''
CREATE TABLE IF NOT EXISTS sync_state (
  k TEXT NOT NULL PRIMARY KEY,
  v TEXT NOT NULL
) WITHOUT ROWID;
''',
  ];
}
