import 'package:drift/drift.dart';

part 'db.g.dart';

/// The entity schema, as Drift sees it.
///
/// Drift owns the DDL: two sources for one schema is the failure this whole
/// change exists to stop, and `tables_schema_test.dart` is the acceptance
/// test — every guarantee it asserts has to hold against what Drift creates.
///
/// Data classes carry a `Row` suffix because the app's own models are the
/// external interface and several share these names: a Drift `Snippet` and
/// the freezed `Snippet` in the same file would be unreadable.
///
/// What is *not* here: `setting` and `history`. Those stay rows in `kv` — 103
/// unrelated preferences with no relations and nothing that queries by field,
/// where adding one should stay a one-line change rather than a migration.

/// Columns every syncable record carries.
///
/// `updatedAt` is what an incremental pull selects on; `rev` separates two
/// edits inside one millisecond, which a clock cannot.
mixin SyncMeta on Table {
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  IntColumn get rev => integer().withDefault(const Constant(0))();
}

/// `name` is what the user typed and what the UI lists; `id` is what
/// [Servers.sshKeyId] points at, so renaming a key cannot orphan a server.
@DataClassName('PrivateKeyRow')
class PrivateKeys extends Table with SyncMeta {
  @override
  String get tableName => 'private_key';
  @override
  bool get withoutRowId => true;

  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get key => text()();

  /// The OpenSSH comment to put at the end of the public key line.
  ///
  /// Held here rather than rewritten into the key: the key file carries its own
  /// copy, inside the part that gets encrypted, so changing that one means
  /// opening the key and writing it out again — a passphrase prompt and a
  /// rewrite of key material, to edit a label.
  ///
  /// Null for a key stored before this column, and for one whose comment has
  /// never been edited. The key's own comment is read in that case, which is
  /// what keeps an imported key showing what it arrived with.
  TextColumn get comment => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A BMC account, referenced by the servers whose BMC it opens.
///
/// A table rather than columns on `server`, which is what separates it from
/// the SSH and monitor credentials below: those are one-to-one, this is not.
/// BMCs are provisioned a rack at a time and answer to one directory or one
/// factory password, so the normal case is many servers to one account —
/// stored per server it would be typed once per machine and, on a rotation,
/// changed once per machine.
///
/// The address and the pinned certificate stay on `server`. Both belong to one
/// device: two BMCs never present the same certificate, so a fingerprint here
/// would be the first device's, used to verify the second.
@DataClassName('BmcCredentialRow')
class BmcCredentials extends Table with SyncMeta {
  @override
  String get tableName => 'bmc_credential';
  @override
  bool get withoutRowId => true;

  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get user => text()();
  TextColumn get pwd => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The SSH and monitor credentials are columns rather than tables of their
/// own: both are one-to-one and neither is ever read without the server.
///
/// The final constraint is `ServerConnectCredential.fromSpi`'s rule written
/// where it cannot be forgotten. The app enforced it in `Spix.validate()`
/// alone, so a record could be stored with both or neither and only fail
/// later, at connect time.
@DataClassName('ServerRow')
class Servers extends Table with SyncMeta {
  @override
  String get tableName => 'server';
  @override
  bool get withoutRowId => true;

  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get autoConnect => boolean().withDefault(const Constant(true))();
  TextColumn get systemType => text().nullable()();

  TextColumn get sshIp => text().nullable()();
  // The range check is a table constraint: a column cannot reference itself
  // in its own `check()`.
  IntColumn get sshPort => integer().nullable()();
  TextColumn get sshUser => text().nullable()();
  TextColumn get sshPwd => text().nullable()();

  /// Deleting a key must not delete the servers that used it; it must leave
  /// them asking for a new one.
  TextColumn get sshKeyId => text()
      .nullable()
      .references(PrivateKeys, #id, onDelete: KeyAction.setNull)();
  TextColumn get sshKeyPath => text().nullable()();
  TextColumn get sshAlterUrl => text().nullable()();
  TextColumn get sshProxyCommand => text().nullable()();

  /// `SshFileTransport`, by name. Null is `sftp`, which is what every row
  /// written before the column existed meant — see `m014`.
  TextColumn get sshFileTransport => text().nullable()();

  TextColumn get monitorAddr => text().nullable()();
  TextColumn get monitorUser => text().nullable()();
  TextColumn get monitorPwd => text().nullable()();
  BoolColumn get monitorIgnoreCert => boolean().nullable()();
  BoolColumn get monitorAllowInsecure => boolean().nullable()();

  TextColumn get wolMac => text().nullable()();
  TextColumn get wolIp => text().nullable()();
  TextColumn get wolPwd => text().nullable()();

  /// The BMC, a side channel beside the Wake-on-LAN fields above.
  ///
  /// Deliberately outside the SSH/monitor constraint below: a BMC is not a way
  /// of reaching the host, so it neither satisfies that requirement nor
  /// conflicts with either side of it. A server may carry one alongside SSH or
  /// alongside a monitor agent.
  ///
  /// [bmcCertSha256] is what the user reviewed, not what a CA said — see
  /// `BmcCfg.certSha256`. Null means nothing has been reviewed and a
  /// connection is refused rather than trusted.
  TextColumn get bmcAddr => text().nullable()();
  TextColumn get bmcCertSha256 => text().nullable()();

  /// Deleting an account must not delete the servers that used it; it must
  /// leave them with an address and nothing to log in with, which the editor
  /// can then say. Same rule as [sshKeyId].
  TextColumn get bmcCredId => text()
      .nullable()
      .references(BmcCredentials, #id, onDelete: KeyAction.setNull)();

  TextColumn get pveAddr => text().nullable()();
  BoolColumn get pveIgnoreCert => boolean().withDefault(const Constant(false))();
  TextColumn get pvePwd => text().nullable()();
  TextColumn get preferTempDev => text().nullable()();
  BoolColumn get tempIsCelsius => boolean().withDefault(const Constant(true))();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get netDev => text().nullable()();
  TextColumn get scriptDir => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    // Reached over SSH or over a monitor agent, never both and never neither.
    'CHECK ((ssh_ip IS NOT NULL) <> (monitor_addr IS NOT NULL))',
    'CHECK (ssh_port IS NULL OR ssh_port BETWEEN 1 AND 65535)',
  ];
}

/// A tag was an element of a JSON array, so "which servers have this tag"
/// meant decoding every server. It is an index lookup now.
@DataClassName('ServerTagRow')
class ServerTags extends Table {
  @override
  String get tableName => 'server_tag';
  @override
  bool get withoutRowId => true;

  TextColumn get serverId =>
      text().references(Servers, #id, onDelete: KeyAction.cascade)();
  TextColumn get tag => text()();

  @override
  Set<Column> get primaryKey => {serverId, tag};
}

@DataClassName('ServerEnvRow')
class ServerEnvs extends Table {
  @override
  String get tableName => 'server_env';
  @override
  bool get withoutRowId => true;

  TextColumn get serverId =>
      text().references(Servers, #id, onDelete: KeyAction.cascade)();
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {serverId, key};
}

/// `ord` keeps the order the user chose: at most the first two are used as
/// failover candidates, so which comes first is meaningful.
@DataClassName('ServerJumpRow')
class ServerJumps extends Table {
  @override
  String get tableName => 'server_jump';
  @override
  bool get withoutRowId => true;

  TextColumn get serverId =>
      text().references(Servers, #id, onDelete: KeyAction.cascade)();
  IntColumn get ord => integer()();
  TextColumn get jumpId =>
      text().references(Servers, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {serverId, ord};
}

@DataClassName('ServerDisabledCmdRow')
class ServerDisabledCmds extends Table {
  @override
  String get tableName => 'server_disabled_cmd';
  @override
  bool get withoutRowId => true;

  TextColumn get serverId =>
      text().references(Servers, #id, onDelete: KeyAction.cascade)();
  TextColumn get cmdType => text()();

  @override
  Set<Column> get primaryKey => {serverId, cmdType};
}

/// `ServerCustom.cmds`, a map of name -> command.
@DataClassName('ServerCustomCmdRow')
class ServerCustomCmds extends Table {
  @override
  String get tableName => 'server_custom_cmd';
  @override
  bool get withoutRowId => true;

  TextColumn get serverId =>
      text().references(Servers, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get cmd => text()();

  @override
  Set<Column> get primaryKey => {serverId, name};
}

/// Was a JSON map in `setting` keyed `<serverId>::<keyType>`, so deleting a
/// server left its trusted fingerprints behind for ever with nothing to say
/// whose they were.
@DataClassName('KnownHostRow')
class KnownHosts extends Table {
  @override
  String get tableName => 'known_host';
  @override
  bool get withoutRowId => true;

  TextColumn get serverId =>
      text().references(Servers, #id, onDelete: KeyAction.cascade)();
  TextColumn get keyType => text()();
  TextColumn get fingerprint => text()();

  @override
  Set<Column> get primaryKey => {serverId, keyType};
}

@DataClassName('SnippetRow')
class Snippets extends Table with SyncMeta {
  @override
  String get tableName => 'snippet';
  @override
  bool get withoutRowId => true;

  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get script => text()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SnippetTagRow')
class SnippetTags extends Table {
  @override
  String get tableName => 'snippet_tag';
  @override
  bool get withoutRowId => true;

  TextColumn get snippetId =>
      text().references(Snippets, #id, onDelete: KeyAction.cascade)();
  TextColumn get tag => text()();

  @override
  Set<Column> get primaryKey => {snippetId, tag};
}

/// Both sides cascade: a deleted snippet stops being auto-run, and a deleted
/// server stops being a target. Neither used to happen.
@DataClassName('SnippetAutoRunRow')
class SnippetAutoRunOn extends Table {
  @override
  String get tableName => 'snippet_auto_run_on';
  @override
  bool get withoutRowId => true;

  TextColumn get snippetId =>
      text().references(Snippets, #id, onDelete: KeyAction.cascade)();
  TextColumn get serverId =>
      text().references(Servers, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {snippetId, serverId};
}

@DataClassName('PortForwardRow')
class PortForwards extends Table with SyncMeta {
  @override
  String get tableName => 'port_forward';
  @override
  bool get withoutRowId => true;

  TextColumn get id => text()();
  TextColumn get serverId =>
      text().references(Servers, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get localHost => text().nullable()();
  IntColumn get localPort => integer().withDefault(const Constant(0))();
  TextColumn get remoteHost => text().nullable()();
  IntColumn get remotePort => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('local', 'remote', 'dynamic'))",
  ];
}

/// `DOCKER_HOST` (or the podman equivalent) for one server.
///
/// A child of `server` rather than a record of its own: it is per-server
/// configuration with no meaning apart from the server, so it cascades with it
/// and the parent's `updated_at` is what moves when it changes — the same rule
/// tags and envs follow.
@DataClassName('ContainerHostRow')
class ContainerHosts extends Table {
  @override
  String get tableName => 'container_host';
  @override
  bool get withoutRowId => true;

  TextColumn get serverId =>
      text().references(Servers, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()();
  TextColumn get host => text()();

  @override
  Set<Column> get primaryKey => {serverId, type};

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('docker', 'podman'))",
  ];
}

/// Which runtime the user picked for one server, where absent means the global
/// default (`SettingStore.usePodman`).
///
/// Was `providerConfig<serverId>` in the `docker` K-V store, holding
/// `ContainerType.podman` — the result of `toString()` on an enum, so a
/// renamed case would have read as the default without saying so.
@DataClassName('ContainerRuntimeRow')
class ContainerRuntimes extends Table {
  @override
  String get tableName => 'container_runtime';
  @override
  bool get withoutRowId => true;

  TextColumn get serverId =>
      text().references(Servers, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()();

  @override
  Set<Column> get primaryKey => {serverId};

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('docker', 'podman'))",
  ];
}

/// `id` is generated rather than `<serverId>_<millis>`: two attempts in the
/// same millisecond shared that key and the second overwrote the first, which
/// the counters are computed from.
///
/// `serverName` stays denormalised on purpose — it is what the server was
/// called at the time, and renaming it must not rewrite its history.
@DataClassName('ConnStatRow')
class ConnStats extends Table {
  @override
  String get tableName => 'conn_stat';
  @override
  bool get withoutRowId => true;

  TextColumn get id => text()();
  TextColumn get serverId =>
      text().references(Servers, #id, onDelete: KeyAction.cascade)();
  TextColumn get serverName => text()();
  IntColumn get timestamp => integer()();
  TextColumn get result => text()();
  TextColumn get errorMessage => text().withDefault(const Constant(''))();
  IntColumn get durationMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// What each server was last seen running, so a row can show its mark before
/// the machine has been asked again.
///
/// A cache and not a field of the record: the distribution is a fact about the
/// far end, observed rather than configured, and a server the user has just
/// added has none until it connects. Keeping it here means the pickers, the
/// known-hosts page and the order page can all draw the right mark without
/// holding a live status — which none of them does.
///
/// One row per server, keyed by the server, cascading with it: a cache entry
/// for a server that no longer exists is a row nothing can ever read.
///
/// No sync columns, and deliberately not a sync root. What this device last
/// observed is not an edit anybody made, and a peer's observation is not more
/// authoritative than this one's — syncing it would let a stale reading from
/// another device overwrite a fresh one here.
@DataClassName('ServerDistRow')
class ServerDists extends Table {
  @override
  String get tableName => 'server_dist';
  @override
  bool get withoutRowId => true;

  TextColumn get serverId =>
      text().references(Servers, #id, onDelete: KeyAction.cascade)();

  /// A `Dist` name. By name, never by index — an index silently changes
  /// meaning when a case is inserted, and this outlives the build that wrote
  /// it. A name no build knows reads back as null, which draws the fallback.
  TextColumn get dist => text()();

  /// When it was last seen, so a reading can be aged out if that is ever
  /// wanted. Nothing reads it yet.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {serverId};
}

/// `data` stays JSON: a conversation is an ordered log of heterogeneous items
/// read only ever whole, never queried by field. Columns would buy nothing and
/// cost a migration for every new item kind.
///
/// `serverId` has no foreign key: the global agent uses a scope id that is not
/// a server.
///
/// No sync columns, and not a sync root: a conversation carries terminal output
/// and reasoning, so it is deliberately left out of backup and sync. Its
/// `updatedAt` is the conversation's own timestamp — what the list is ordered
/// by and what the per-server cap keeps — rather than a record of when this
/// device last touched the row.
@DataClassName('AgentConversationRow')
class AgentConversations extends Table {
  @override
  String get tableName => 'agent_conversation';
  @override
  bool get withoutRowId => true;

  TextColumn get id => text()();
  TextColumn get serverId => text()();
  IntColumn get updatedAt => integer()();
  TextColumn get data => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AgentActiveConversationRow')
class AgentActiveConversations extends Table {
  @override
  String get tableName => 'agent_active_conversation';
  @override
  bool get withoutRowId => true;

  TextColumn get serverId => text()();
  TextColumn get conversationId => text()
      .references(AgentConversations, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {serverId};
}

/// A delete has to be a fact that can travel. Without this the peer that still
/// holds the row reads its absence as an addition and puts it back, which is
/// how a deleted server returns on the next sync.
@DataClassName('TombstoneRow')
class Tombstones extends Table {
  @override
  String get tableName => 'tombstone';
  @override
  bool get withoutRowId => true;

  TextColumn get tbl => text()();
  TextColumn get rowId => text()();
  IntColumn get deletedAt => integer()();

  @override
  Set<Column> get primaryKey => {tbl, rowId};
}

/// This device's id and how far it has read each peer's log. Key-value because
/// it is bookkeeping *about* sync rather than anything synced, and it must
/// never itself be uploaded.
@DataClassName('SyncStateRow')
class SyncStates extends Table {
  @override
  String get tableName => 'sync_state';
  @override
  bool get withoutRowId => true;

  TextColumn get k => text()();
  TextColumn get v => text()();

  @override
  Set<Column> get primaryKey => {k};
}

/// The database, over the connection the app already opened and keyed.
///
/// Drift is a query and mapping layer here, not the owner of the connection:
/// `SqliteDb` opens the file, applies `PRAGMA cipher`/`PRAGMA key` and
/// `foreign_keys`, and hands the live handle over. Letting Drift open its own
/// would mean an unencrypted database and a connection without the pragmas —
/// `foreign_keys` is per-connection.
///
/// [schemaVersion] is 1 and stays there. Version is tracked by
/// `SchemaVersion`, because the steps that matter are outside what a Drift
/// migration can say: m003 reads Hive boxes, m004 remaps ids and rewrites the
/// references between them. Two mechanisms each advancing the same number
/// would be the ambiguity this file exists to remove.
@DriftDatabase(
  tables: [
    PrivateKeys,
    // Named rather than left to be pulled in by `Servers.bmcCredId`. Drift does
    // follow that reference today, so the table is created either way, but a
    // schema that exists only as a side effect of a foreign key disappears from
    // fresh installs the moment the key is changed — while every migrated
    // install keeps it, so the failure would be `no such table` on new devices
    // alone.
    BmcCredentials,
    Servers,
    ServerTags,
    ServerEnvs,
    ServerJumps,
    ServerDisabledCmds,
    ServerCustomCmds,
    KnownHosts,
    Snippets,
    SnippetTags,
    SnippetAutoRunOn,
    PortForwards,
    ContainerHosts,
    ContainerRuntimes,
    ConnStats,
    ServerDists,
    AgentConversations,
    AgentActiveConversations,
    Tombstones,
    SyncStates,
  ],
)
class AppDb extends _$AppDb {
  AppDb(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      for (final statement in _indexes) {
        await customStatement(statement);
      }
    },
  );

  /// Indexes the read patterns need, which the table definitions do not carry.
  static const _indexes = [
    'CREATE INDEX IF NOT EXISTS idx_server_key ON server(ssh_key_id);',
    // Same read as `ssh_key_id`: "how many servers use this account", asked
    // once per row of the account list and on every rebuild of the server
    // editor. It also serves the ON DELETE SET NULL, which without it scans
    // `server` once per deleted account.
    'CREATE INDEX IF NOT EXISTS idx_server_bmc_cred ON server(bmc_cred_id);',
    'CREATE INDEX IF NOT EXISTS idx_server_tag_tag ON server_tag(tag);',
    'CREATE INDEX IF NOT EXISTS idx_server_jump_target ON server_jump(jump_id);',
    'CREATE INDEX IF NOT EXISTS idx_snippet_tag_tag ON snippet_tag(tag);',
    'CREATE INDEX IF NOT EXISTS idx_snippet_auto_run_server '
        'ON snippet_auto_run_on(server_id);',
    'CREATE INDEX IF NOT EXISTS idx_port_forward_server '
        'ON port_forward(server_id);',
    // Every read is "this server, newest first"; the per-server cap is the
    // same order with a LIMIT.
    'CREATE INDEX IF NOT EXISTS idx_conn_stat_server_ts '
        'ON conn_stat(server_id, timestamp DESC);',
    // The age sweep asks about `timestamp` alone, which the index above
    // cannot serve — its leading column is `server_id`.
    'CREATE INDEX IF NOT EXISTS idx_conn_stat_ts ON conn_stat(timestamp);',
    'CREATE INDEX IF NOT EXISTS idx_agent_conversation_server_updated '
        'ON agent_conversation(server_id, updated_at DESC);',
    'CREATE INDEX IF NOT EXISTS idx_tombstone_deleted '
        'ON tombstone(deleted_at);',
  ];
}
