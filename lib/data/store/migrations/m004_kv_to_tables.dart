import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:sqlite3/sqlite3.dart';

/// Moves the entities out of `kv` and into tables with columns.
///
/// Everything below is one transaction. A migration that stops half way is
/// worse than one that has not started: the records exist in two shapes at
/// once and nothing can tell which is authoritative.
///
/// The tables themselves are not created here — the schema is created when the
/// database is opened, so this step only ever reads `kv` and inserts. That is
/// also why it can stay inside one synchronous transaction: creating the schema
/// means opening Drift over the connection, which is asynchronous, and a
/// synchronous transaction block cannot await it.
///
/// Four things it does beyond copying:
///
/// - **Gives snippets and private keys real ids.** Both were keyed by a name
///   the user typed — a private key's `id` *was* its name — so `Spi.ssh.keyId`
///   pointed at a name, and renaming a key silently detached every server
///   using it. New ids are generated here and the references rewritten.
/// - **Gives a server with no id one.** A record from before 1155 was stored
///   under `user@ip:port` with an empty `id` field, which the app fixed up at
///   every launch afterwards. There is nowhere to keep an empty primary key,
///   so it happens here instead, once, with every reference rewritten.
/// - **Recovers an `IdentityFile` path out of `keyId`.** `~/.ssh/config` import
///   used to write a path into the field that names a private key. Mapping the
///   old key ids would turn that into a null and lose it, so a value naming no
///   key that looks like a path lands in `ssh_key_path`, which is what it meant.
/// - **Drops rows that point at nothing.** Every child table has a foreign key
///   now, and the old `delServer` cleaned up by hand and missed cases, so an
///   upgrading install has statistics and container hosts for servers deleted
///   long ago. They cannot be inserted and are not worth keeping.
class KvToTablesMigration implements SchemaMigration {
  const KvToTablesMigration();

  @override
  int get from => 4;

  Database get _db => SqliteDb.instance;

  /// The `kv` stores this consumes. Left behind they would be a second copy
  /// that nothing reads and a backup would still carry.
  static const _consumed = [
    'server',
    'key',
    'snippet',
    'port_forward',
    'docker',
    'conn_stat',
    'agent_conversation',
  ];

  @override
  Future<void> apply() async {
    SqliteStore.transact(() {
      final keyIds = _migratePrivateKeys();
      final serverIds = _migrateServers(keyIds);
      _migrateKnownHosts(serverIds);
      final snippetNames = _migrateSnippets(serverIds);
      _migratePortForwards(serverIds);
      _migrateContainer(serverIds);
      _migrateConnStats(serverIds);
      _migrateAgentConversations(serverIds);
      _rewriteOrder('serverOrder', (entry) => serverIds[entry]);
      // Occurrence by occurrence: two snippets could share a stored name, and
      // only one of them keeps it. A plain map would send both order entries
      // to whichever was de-duplicated last.
      _rewriteOrder('snippetOrder', (entry) {
        final queue = snippetNames[entry];
        return queue == null || queue.isEmpty ? null : queue.removeAt(0);
      });

      for (final store in _consumed) {
        _db.execute('DELETE FROM kv WHERE store = ?;', [store]);
      }
      _db.execute("DELETE FROM kv WHERE store = 'setting' AND key = ?;", [
        'sshKnownHostFingerprints',
      ]);
    });
  }

  /// Every row of one `kv` store, decoded, with the timestamp it was written.
  ///
  /// `updated_at` is carried across rather than stamped as now: an incremental
  /// sync reads it, and calling every record "changed today" would make the
  /// first sync after upgrading upload everything.
  List<({String key, Map<String, dynamic> value, int updatedAt})> _rows(
    String store,
  ) {
    final out = <({String key, Map<String, dynamic> value, int updatedAt})>[];
    for (final row in _raw(store)) {
      if (row.value is! Map) continue;
      out.add((
        key: row.key,
        value: Map<String, dynamic>.from(row.value as Map),
        updatedAt: row.updatedAt,
      ));
    }
    return out;
  }

  /// The same, without requiring the value to be an object: the agent box held
  /// a bare string under half of its keys.
  List<({String key, Object? value, int updatedAt})> _raw(String store) {
    final out = <({String key, Object? value, int updatedAt})>[];
    for (final row in _db.select(
      'SELECT key, value, updated_at FROM kv WHERE store = ?;',
      [store],
    )) {
      final key = row['key'] as String;
      if (key.startsWith(StoreDefaults.prefixKey)) continue;
      try {
        out.add((
          key: key,
          value: json.decode(row['value'] as String),
          updatedAt: row['updated_at'] as int? ?? 0,
        ));
      } catch (e) {
        Loggers.app.warning('m004: skipping unreadable $store/$key', e);
      }
    }
    return out;
  }

  static int _bool(Object? v, {bool fallback = false}) =>
      (v is bool ? v : fallback) ? 1 : 0;

  /// Old name-as-id -> new generated id.
  Map<String, String> _migratePrivateKeys() {
    final ids = <String, String>{};
    final names = <String>{};
    for (final row in _rows('key')) {
      final oldId = row.value['id'] as String? ?? row.key;
      // `private_key` is what the released model's `toJson` called it.
      final key = (row.value['private_key'] ?? row.value['key']) as String?;
      if (key == null) continue;

      // The old key was the name, and nothing enforced that it was unique
      // across the two places one could be created.
      var name = oldId;
      for (var n = 2; !names.add(name); n++) {
        name = '$oldId ($n)';
      }

      final id = ShortId.generate();
      ids[oldId] = id;
      _db.execute(
        'INSERT INTO private_key (id, name, key, updated_at) '
        'VALUES (?, ?, ?, ?);',
        [id, name, key, row.updatedAt],
      );
    }
    return ids;
  }

  /// Every way a server could be referred to before -> the id it has now.
  ///
  /// Two entries per server where the two differ: the `kv` key it was stored
  /// under, and the `id` field inside the record. They are the same for
  /// everything written since 1155, and for anything older the field is empty
  /// and the key is `user@ip:port` — which other records point at.
  Map<String, String> _migrateServers(Map<String, String> keyIds) {
    final ids = <String, String>{};
    final jumps = <String, List<String>>{};

    for (final row in _rows('server')) {
      final v = row.value;
      final stored = v['id'] as String?;
      final id = stored != null && stored.isNotEmpty
          ? stored
          : ShortId.generate();
      final ssh = v['ssh'] as Map?;
      final monitor = v['monitorHttp'] as Map?;
      final sshIp = ssh?['ip'] as String?;
      final monitorAddr = monitor?['addr'] as String?;

      // The schema now says a server is reached one way or the other. A record
      // with neither was already unusable — `genClient` had nothing to dial —
      // and one with both was ambiguous. Neither can be represented, so say so
      // rather than failing the whole migration.
      final hasSsh = sshIp != null && sshIp.isNotEmpty;
      final hasMonitor = monitorAddr != null && monitorAddr.isNotEmpty;
      if (hasSsh == hasMonitor) {
        Loggers.app.warning(
          'm004: server "$id" has ${hasSsh ? 'both' : 'neither'} SSH and '
          'monitor; it could not be connected to and is dropped',
        );
        continue;
      }

      final custom = v['custom'] as Map? ?? const {};
      final wol = v['wolCfg'] as Map?;

      // A key id that names no key. If it looks like a path it is one: the
      // `~/.ssh/config` import wrote `IdentityFile` into this field. Mapping it
      // to null would be the only record that it ever existed.
      // `pubKeyId` is what `SshCredential.toJson` calls it, kept from the
      // flat pre-v3 layout. Reading `keyId` alone found nothing and detached
      // every server from its key.
      final oldKeyId = (ssh?['pubKeyId'] ?? ssh?['keyId']) as String?;
      final newKeyId = keyIds[oldKeyId];
      final keyPath = newKeyId == null && oldKeyId != null && _isPath(oldKeyId)
          ? oldKeyId
          : ssh?['keyPath'] as String?;

      _db.execute(
        'INSERT INTO server ('
        'id, name, auto_connect, system_type, '
        'ssh_ip, ssh_port, ssh_user, ssh_pwd, ssh_key_id, ssh_key_path, '
        'ssh_alter_url, ssh_proxy_command, '
        'monitor_addr, monitor_user, monitor_pwd, monitor_ignore_cert, '
        'wol_mac, wol_ip, wol_pwd, '
        'pve_addr, pve_ignore_cert, pve_pwd, prefer_temp_dev, '
        'temp_is_celsius, logo_url, net_dev, script_dir, updated_at'
        ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '
        '?, ?, ?, ?, ?, ?, ?, ?, ?);',
        [
          id,
          v['name'] as String? ?? id,
          _bool(v['autoConnect'], fallback: true),
          v['customSystemType'] as String?,
          hasSsh ? sshIp : null,
          hasSsh ? ((ssh?['port'] as num?)?.toInt() ?? 22) : null,
          hasSsh ? ((ssh?['user'] as String?) ?? 'root') : null,
          ssh?['pwd'] as String?,
          // Points at the new id, so renaming the key later cannot detach it.
          newKeyId,
          keyPath,
          ssh?['alterUrl'] as String?,
          ssh?['proxyCommand'] as String?,
          hasMonitor ? monitorAddr : null,
          monitor?['user'] as String?,
          monitor?['pwd'] as String?,
          hasMonitor ? _bool(monitor?['ignoreCert']) : null,
          wol?['mac'] as String?,
          wol?['ip'] as String?,
          wol?['pwd'] as String?,
          custom['pveAddr'] as String?,
          _bool(custom['pveIgnoreCert']),
          custom['pvePwd'] as String?,
          custom['preferTempDev'] as String?,
          _bool(custom['tempIsCelsius'], fallback: true),
          custom['logoUrl'] as String?,
          custom['netDev'] as String?,
          custom['scriptDir'] as String?,
          row.updatedAt,
        ],
      );
      ids[row.key] = id;
      if (stored != null && stored.isNotEmpty) ids[stored] = id;

      for (final tag in (v['tags'] as List? ?? const []).whereType<String>()) {
        _db.execute('INSERT OR IGNORE INTO server_tag VALUES (?, ?);', [
          id,
          tag,
        ]);
      }
      (v['envs'] as Map? ?? const {}).forEach((k, val) {
        _db.execute('INSERT OR IGNORE INTO server_env VALUES (?, ?, ?);', [
          id,
          '$k',
          '$val',
        ]);
      });
      for (final cmd
          in (v['disabledCmdTypes'] as List? ?? const []).whereType<String>()) {
        _db.execute('INSERT OR IGNORE INTO server_disabled_cmd VALUES (?, ?);', [
          id,
          cmd,
        ]);
      }
      (custom['cmds'] as Map? ?? const {}).forEach((k, val) {
        _db.execute('INSERT OR IGNORE INTO server_custom_cmd VALUES (?, ?, ?);', [
          id,
          '$k',
          '$val',
        ]);
      });

      // Held back: a jump host is a server, so the row it points at may not
      // have been inserted yet — and its id may not be known yet either.
      final ordered = <String>[
        for (final j in [ssh?['jumpId'], ...?(ssh?['jumpIds'] as List?)])
          if (j is String && j.isNotEmpty) j,
      ];
      final seen = <String>{};
      final deduped = [
        for (final j in ordered)
          if (seen.add(j)) j,
      ];
      if (deduped.isNotEmpty) jumps[id] = deduped;
    }

    jumps.forEach((serverId, targets) {
      var ord = 0;
      for (final target in targets) {
        // A jump host that no longer exists is a dead reference the old shape
        // could hold and this one cannot.
        final resolved = ids[target];
        if (resolved == null) {
          Loggers.app.warning(
            'm004: server "$serverId" jumps via "$target", which does not '
            'exist; dropped',
          );
          continue;
        }
        _db.execute('INSERT INTO server_jump VALUES (?, ?, ?);', [
          serverId,
          ord++,
          resolved,
        ]);
      }
    });

    return ids;
  }

  /// Whether [value] is a filesystem path rather than a key id.
  ///
  /// `ShortId`'s alphabet is `0-9a-zA-Z-+`, so a generated id can match none of
  /// these; a user-typed key name can, which is why the caller checks that it
  /// names no key first.
  ///
  /// Known gap: `IdentityFile id_ed25519` with no separator at all is legal in
  /// an ssh config, and such a value is indistinguishable from a key the user
  /// has since deleted. It stays a dangling reference, which the edit page
  /// shows as "no key" — the same as before.
  static bool _isPath(String value) =>
      value.startsWith('~') || value.contains('/') || value.contains(r'\');

  /// `sshKnownHostFingerprints`, a JSON map in `setting` keyed
  /// `<serverId>::<keyType>`, becomes rows that cascade with their server.
  void _migrateKnownHosts(Map<String, String> serverIds) {
    final raw = _db.select(
      "SELECT value FROM kv WHERE store = 'setting' AND key = ?;",
      ['sshKnownHostFingerprints'],
    );
    if (raw.isEmpty) return;
    Object? decoded;
    try {
      decoded = json.decode(raw.single['value'] as String);
    } catch (e) {
      Loggers.app.warning('m004: known hosts unreadable', e);
      return;
    }
    if (decoded is! Map) return;

    decoded.forEach((k, v) {
      // Split once from the left: a key type never contains `::`, and an old
      // `user@ip:port` server id does contain colons.
      final at = '$k'.indexOf('::');
      if (at <= 0) return;
      final serverId = serverIds['$k'.substring(0, at)];
      if (serverId == null) return;
      _db.execute('INSERT OR IGNORE INTO known_host VALUES (?, ?, ?);', [
        serverId,
        '$k'.substring(at + 2),
        '$v',
      ]);
    });
  }

  /// Old name -> the names its records ended up with, in the order they were
  /// migrated. `snippetOrder` is a list of names, and a name that was not
  /// unique produced more than one.
  Map<String, List<String>> _migrateSnippets(Map<String, String> serverIds) {
    final renamed = <String, List<String>>{};
    final names = <String>{};
    for (final row in _rows('snippet')) {
      final v = row.value;
      final script = v['script'] as String?;
      if (script == null) continue;

      final oldName = v['name'] as String? ?? row.key;
      var name = oldName;
      for (var n = 2; !names.add(name); n++) {
        name = '$oldName ($n)';
      }
      (renamed[oldName] ??= []).add(name);

      final id = ShortId.generate();
      _db.execute(
        'INSERT INTO snippet (id, name, script, note, updated_at) '
        'VALUES (?, ?, ?, ?, ?);',
        [id, name, script, v['note'] as String?, row.updatedAt],
      );
      for (final tag in (v['tags'] as List? ?? const []).whereType<String>()) {
        _db.execute('INSERT OR IGNORE INTO snippet_tag VALUES (?, ?);', [
          id,
          tag,
        ]);
      }
      for (final target
          in (v['autoRunOn'] as List? ?? const []).whereType<String>()) {
        final serverId = serverIds[target];
        if (serverId == null) continue;
        _db.execute('INSERT OR IGNORE INTO snippet_auto_run_on VALUES (?, ?);', [
          id,
          serverId,
        ]);
      }
    }
    return renamed;
  }

  void _migratePortForwards(Map<String, String> serverIds) {
    for (final row in _rows('port_forward')) {
      final v = row.value;
      final id = v['id'] as String? ?? row.key;
      final serverId = serverIds[v['serverId'] as String?];
      if (serverId == null) {
        Loggers.app.warning(
          'm004: port forward "$id" names server "${v['serverId']}", which '
          'does not exist; dropped',
        );
        continue;
      }
      const types = {'local', 'remote', 'dynamic'};
      final type = v['type'] as String?;
      _db.execute(
        'INSERT INTO port_forward (id, server_id, name, type, local_host, '
        'local_port, remote_host, remote_port, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);',
        [
          id,
          serverId,
          v['name'] as String? ?? id,
          types.contains(type) ? type : 'local',
          v['localHost'] as String?,
          (v['localPort'] as num?)?.toInt() ?? 0,
          v['remoteHost'] as String?,
          (v['remotePort'] as num?)?.toInt(),
          row.updatedAt,
        ],
      );
    }
  }

  /// The `docker` store held three kinds of key under one namespace:
  ///
  /// - `containerHost<type><serverId>` -> the host for that runtime
  /// - `providerConfig<serverId>`      -> `ContainerType.podman`, from
  ///   `toString()` on the enum
  /// - `<serverId>`                    -> the Docker host, from before there
  ///   was a runtime to name
  void _migrateContainer(Map<String, String> serverIds) {
    const hostPrefix = 'containerHost';
    const typePrefix = 'providerConfig';
    const runtimes = ['docker', 'podman'];

    for (final row in _raw('docker')) {
      final value = row.value;
      if (value is! String || value.isEmpty) continue;

      if (row.key.startsWith(hostPrefix)) {
        final rest = row.key.substring(hostPrefix.length);
        final type = runtimes.firstWhereOrNull(rest.startsWith);
        if (type == null) continue;
        final serverId = serverIds[rest.substring(type.length)];
        if (serverId == null) continue;
        _db.execute(
          'INSERT OR REPLACE INTO container_host (server_id, type, host) '
          'VALUES (?, ?, ?);',
          [serverId, type, value],
        );
        continue;
      }

      if (row.key.startsWith(typePrefix)) {
        final serverId = serverIds[row.key.substring(typePrefix.length)];
        // `providerConfig` with no id was a global override on top of
        // `usePodman`, which says the same thing; it belongs to no server and
        // there is nowhere to put it.
        if (serverId == null) continue;
        final type = runtimes.firstWhereOrNull(value.endsWith);
        if (type == null) continue;
        _db.execute(
          'INSERT OR REPLACE INTO container_runtime (server_id, type) '
          'VALUES (?, ?);',
          [serverId, type],
        );
        continue;
      }

      // Bare server id: the Docker host as it was stored before per-runtime
      // hosts existed. `fetch` still fell back to it, so dropping it would
      // silently move those servers back to the local socket.
      final serverId = serverIds[row.key];
      if (serverId == null) continue;
      _db.execute(
        'INSERT OR IGNORE INTO container_host (server_id, type, host) '
        'VALUES (?, ?, ?);',
        [serverId, 'docker', value],
      );
    }
  }

  /// `ConnectionResult` as JSON -> as stored.
  ///
  /// The model's `@JsonValue`s are snake_case and the column holds the enum's
  /// `name`, which is not the same string for three of the five. Written out
  /// rather than read off the enum: this has to keep meaning what it meant when
  /// the data was written, whatever the model does later.
  static const _results = {
    'success': 'success',
    'timeout': 'timeout',
    'auth_failed': 'authFailed',
    'network_error': 'networkError',
    'unknown_error': 'unknownError',
  };

  void _migrateConnStats(Map<String, String> serverIds) {
    var dropped = 0;
    for (final row in _rows('conn_stat')) {
      final v = row.value;
      final serverId = serverIds[v['serverId'] as String?];
      if (serverId == null) {
        dropped++;
        continue;
      }
      final timestamp = DateTime.tryParse('${v['timestamp']}');
      if (timestamp == null) continue;
      // A fresh id: the old one was `<serverId>_<millis>`, so two attempts in
      // the same millisecond shared a key and the second overwrote the first.
      _db.execute(
        'INSERT INTO conn_stat (id, server_id, server_name, timestamp, '
        'result, error_message, duration_ms) VALUES (?, ?, ?, ?, ?, ?, ?);',
        [
          ShortId.generate(),
          serverId,
          v['serverName'] as String? ?? '',
          timestamp.millisecondsSinceEpoch,
          _results['${v['result']}'] ?? 'unknownError',
          v['errorMessage'] as String? ?? '',
          (v['durationMs'] as num?)?.toInt() ?? 0,
        ],
      );
    }
    if (dropped > 0) {
      Loggers.app.info('m004: dropped $dropped stats for deleted servers');
    }
  }

  /// The agent box held conversations and the per-server active one under one
  /// namespace, told apart by a key prefix.
  ///
  /// A scope that names a server follows that server's id, which this
  /// migration may have regenerated. One that names no server is kept as it
  /// is — the global agent's scope is not a server, which is also why the
  /// table has no foreign key.
  void _migrateAgentConversations(Map<String, String> serverIds) {
    const conversationPrefix = 'conversation::';
    const activePrefix = 'active::';
    final active = <String, String>{};

    for (final row in _raw('agent_conversation')) {
      if (row.key.startsWith(activePrefix)) {
        final id = row.value;
        if (id is String && id.isNotEmpty) {
          final scope = row.key.substring(activePrefix.length);
          active[serverIds[scope] ?? scope] = id;
        }
        continue;
      }
      if (!row.key.startsWith(conversationPrefix)) continue;
      final v = row.value;
      if (v is! Map) continue;
      // snake_case: `AgentConversation.toJson` is hand-written and that is
      // what it produces, so reading `serverId` here found nothing and every
      // conversation was dropped.
      final id = v['id'] as String?;
      final serverId = v['server_id'] as String?;
      if (id == null || id.isEmpty || serverId == null || serverId.isEmpty) {
        continue;
      }
      final updatedAt = DateTime.tryParse('${v['updated_at']}');
      final scope = serverIds[serverId] ?? serverId;
      // Inside the payload too, not only in the column. The store rebuilds a
      // conversation from `data` and then compares `conversation.serverId`
      // against the server it was asked about — `fetchActive`, `setActive` and
      // `deleteConversation` all do — so a record whose JSON still named the
      // old id would be unreachable by every one of them.
      v['server_id'] = scope;
      // `ON CONFLICT`, not `OR REPLACE`: the active row references this one and
      // cascades, so replacing would delete the record of which conversation
      // is open.
      _db.execute(
        'INSERT INTO agent_conversation (id, server_id, updated_at, data) '
        'VALUES (?, ?, ?, ?) ON CONFLICT (id) DO UPDATE SET '
        'server_id = excluded.server_id, updated_at = excluded.updated_at, '
        'data = excluded.data;',
        [
          id,
          scope,
          updatedAt?.millisecondsSinceEpoch ?? row.updatedAt,
          json.encode(v),
        ],
      );
    }

    active.forEach((serverId, conversationId) {
      // The active row references a real conversation now.
      final exists = _db
          .select('SELECT 1 FROM agent_conversation WHERE id = ?;', [
            conversationId,
          ])
          .isNotEmpty;
      if (!exists) return;
      _db.execute(
        'INSERT INTO agent_active_conversation (server_id, conversation_id) '
        'VALUES (?, ?) ON CONFLICT (server_id) DO UPDATE SET '
        'conversation_id = excluded.conversation_id;',
        [serverId, conversationId],
      );
    });
  }

  /// Rewrites one `setting` list whose entries this migration renamed.
  ///
  /// `serverOrder` holds ids and `snippetOrder` holds names, and both could
  /// change above. [resolve] answers what an entry became, or null if it named
  /// a record that is not here — those are dropped.
  void _rewriteOrder(String key, String? Function(String) resolve) {
    final rows = _db.select(
      "SELECT value FROM kv WHERE store = 'setting' AND key = ?;",
      [key],
    );
    if (rows.isEmpty) return;
    final List<String> entries;
    try {
      final decoded = json.decode(rows.single['value'] as String);
      if (decoded is! List) return;
      entries = decoded.whereType<String>().toList();
    } catch (e) {
      Loggers.app.warning('m004: $key unreadable', e);
      return;
    }

    final rewritten = [
      for (final entry in entries) ?resolve(entry),
    ];
    if (rewritten.length == entries.length &&
        rewritten.indexed.every((e) => e.$2 == entries[e.$1])) {
      return;
    }
    // Not an edit by the user, so the timestamp stays where it was: stamping
    // it would tell the next sync this device holds the newer copy.
    _db.execute(
      "UPDATE kv SET value = ? WHERE store = 'setting' AND key = ?;",
      [json.encode(rewritten), key],
    );
  }
}
