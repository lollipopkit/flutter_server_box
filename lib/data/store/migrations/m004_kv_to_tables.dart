import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/tables.dart';
import 'package:sqlite3/sqlite3.dart';

/// Moves the entities out of `kv` and into tables with columns.
///
/// Everything below is one transaction. A migration that stops half way is
/// worse than one that has not started: the records exist in two shapes at
/// once and nothing can tell which is authoritative.
///
/// Two things it does beyond copying:
///
/// - **Gives snippets and private keys real ids.** Both were keyed by a name
///   the user typed — a private key's `id` *was* its name — so `Spi.ssh.keyId`
///   pointed at a name, and renaming a key silently detached every server
///   using it. New ids are generated here and the references rewritten.
/// - **Drops rows that point at nothing.** `conn_stat` has a foreign key now,
///   and the old `delServer` cleaned up by hand and missed cases, so an
///   upgrading install has statistics for servers deleted long ago. They
///   cannot be inserted and are not worth keeping.
class KvToTablesMigration implements SchemaMigration {
  const KvToTablesMigration();

  @override
  int get from => 4;

  Database get _db => SqliteDb.instance;

  @override
  Future<void> apply() async {
    // The three tables that already exist under these names, from before this
    // step. `Tables.createAll` is `IF NOT EXISTS`, so it would leave the old
    // shape in place — they have to move out of the way first.
    const renamed = {
      'conn_stat': '_m004_old_conn_stat',
      'agent_conversation': '_m004_old_agent_conversation',
      'agent_active': '_m004_old_agent_active',
    };

    SqliteStore.transact(() {
      for (final entry in renamed.entries) {
        if (_tableExists(entry.key)) {
          _db.execute('ALTER TABLE ${entry.key} RENAME TO ${entry.value};');
        }
      }

      // Drift owns the DDL, so the tables are created by opening the
      // database rather than by this step. `createTables` is the seam that
      // makes the migration runnable against a connection Drift has not
      // opened yet — a test, and the first launch after upgrading.
      createTables(_db);

      final keyIds = _migratePrivateKeys();
      final serverIds = _migrateServers(keyIds);
      _migrateKnownHosts(serverIds);
      _migrateSnippets(serverIds);
      _migratePortForwards(serverIds);
      _migrateContainerHosts();
      _migrateConnStats(serverIds);
      _migrateAgentConversations();

      for (final old in renamed.values) {
        if (_tableExists(old)) _db.execute('DROP TABLE $old;');
      }
      // The rows these came from. Left behind they are a second copy that
      // nothing reads and a backup would still carry.
      for (final store in const [
        'server',
        'key',
        'snippet',
        'port_forward',
        'docker',
      ]) {
        _db.execute('DELETE FROM kv WHERE store = ?;', [store]);
      }
      _db.execute(
        "DELETE FROM kv WHERE store = 'setting' AND key = ?;",
        ['sshKnownHostFingerprints'],
      );
    });
  }

  bool _tableExists(String name) => _db
      .select("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?;", [
        name,
      ])
      .isNotEmpty;

  /// Every row of one `kv` store, decoded, with the timestamp it was written.
  ///
  /// `updated_at` is carried across rather than stamped as now: an incremental
  /// sync reads it, and calling every record "changed today" would make the
  /// first sync after upgrading upload everything.
  List<({String key, Map<String, dynamic> value, int updatedAt})> _rows(
    String store,
  ) {
    final out = <({String key, Map<String, dynamic> value, int updatedAt})>[];
    for (final row in _db.select(
      'SELECT key, value, updated_at FROM kv WHERE store = ?;',
      [store],
    )) {
      final key = row['key'] as String;
      if (key.startsWith(StoreDefaults.prefixKey)) continue;
      try {
        final decoded = json.decode(row['value'] as String);
        if (decoded is! Map) continue;
        out.add((
          key: key,
          value: Map<String, dynamic>.from(decoded),
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
      final key = row.value['key'] as String?;
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

  /// The set of server ids that made it across, for the tables keyed on them.
  Set<String> _migrateServers(Map<String, String> keyIds) {
    final kept = <String>{};
    final jumps = <String, List<String>>{};

    for (final row in _rows('server')) {
      final v = row.value;
      final id = (v['id'] as String?)?.isNotEmpty == true
          ? v['id'] as String
          : row.key;
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
          keyIds[ssh?['keyId'] as String?],
          ssh?['keyPath'] as String?,
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
      kept.add(id);

      for (final tag in (v['tags'] as List? ?? const []).whereType<String>()) {
        _db.execute(
          'INSERT OR IGNORE INTO server_tag VALUES (?, ?);',
          [id, tag],
        );
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
        _db.execute(
          'INSERT OR IGNORE INTO server_disabled_cmd VALUES (?, ?);',
          [id, cmd],
        );
      }
      (custom['cmds'] as Map? ?? const {}).forEach((k, val) {
        _db.execute(
          'INSERT OR IGNORE INTO server_custom_cmd VALUES (?, ?, ?);',
          [id, '$k', '$val'],
        );
      });

      // Held back: a jump host is a server, so the row it points at may not
      // have been inserted yet.
      final ordered = <String>[
        for (final j in [
          ssh?['jumpId'],
          ...?(ssh?['jumpIds'] as List?),
        ])
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
        if (!kept.contains(target)) {
          Loggers.app.warning(
            'm004: server "$serverId" jumps via "$target", which does not '
            'exist; dropped',
          );
          continue;
        }
        _db.execute('INSERT INTO server_jump VALUES (?, ?, ?);', [
          serverId,
          ord++,
          target,
        ]);
      }
    });

    return kept;
  }

  /// `sshKnownHostFingerprints`, a JSON map in `setting` keyed
  /// `<serverId>::<keyType>`, becomes rows that cascade with their server.
  void _migrateKnownHosts(Set<String> serverIds) {
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
      final parts = '$k'.split('::');
      if (parts.length != 2) return;
      if (!serverIds.contains(parts[0])) return;
      _db.execute('INSERT OR IGNORE INTO known_host VALUES (?, ?, ?);', [
        parts[0],
        parts[1],
        '$v',
      ]);
    });
  }

  void _migrateSnippets(Set<String> serverIds) {
    final names = <String>{};
    for (final row in _rows('snippet')) {
      final v = row.value;
      final script = v['script'] as String?;
      if (script == null) continue;

      var name = v['name'] as String? ?? row.key;
      for (var n = 2; !names.add(name); n++) {
        name = '${v['name'] ?? row.key} ($n)';
      }

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
        if (!serverIds.contains(target)) continue;
        _db.execute(
          'INSERT OR IGNORE INTO snippet_auto_run_on VALUES (?, ?);',
          [id, target],
        );
      }
    }
  }

  void _migratePortForwards(Set<String> serverIds) {
    for (final row in _rows('port_forward')) {
      final v = row.value;
      final id = v['id'] as String? ?? row.key;
      final serverId = v['serverId'] as String?;
      if (serverId == null || !serverIds.contains(serverId)) {
        Loggers.app.warning(
          'm004: port forward "$id" names server "$serverId", which does not '
          'exist; dropped',
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

  /// `containerHost<type><serverId>` -> a row keyed by the two of them.
  void _migrateContainerHosts() {
    const prefix = 'containerHost';
    for (final row in _db.select(
      "SELECT key, value, updated_at FROM kv WHERE store = 'docker';",
    )) {
      final key = row['key'] as String;
      if (!key.startsWith(prefix)) continue;
      final rest = key.substring(prefix.length);
      final type = const ['docker', 'podman'].firstWhereOrNull(rest.startsWith);
      if (type == null) continue;

      Object? host;
      try {
        host = json.decode(row['value'] as String);
      } catch (_) {
        continue;
      }
      if (host is! String || host.isEmpty) continue;

      _db.execute(
        'INSERT OR REPLACE INTO container_host '
        '(server_id, type, host, updated_at) VALUES (?, ?, ?, ?);',
        [rest.substring(type.length), type, host, row['updated_at'] as int? ?? 0],
      );
    }
  }

  void _migrateConnStats(Set<String> serverIds) {
    if (!_tableExists('_m004_old_conn_stat')) return;
    var dropped = 0;
    for (final row in _db.select('SELECT * FROM _m004_old_conn_stat;')) {
      final serverId = row['server_id'] as String;
      if (!serverIds.contains(serverId)) {
        dropped++;
        continue;
      }
      // A fresh id: the old one was `<serverId>_<millis>`, so two attempts in
      // the same millisecond shared a key and the second overwrote the first.
      _db.execute(
        'INSERT INTO conn_stat (id, server_id, server_name, timestamp, '
        'result, error_message, duration_ms) VALUES (?, ?, ?, ?, ?, ?, ?);',
        [
          ShortId.generate(),
          serverId,
          row['server_name'],
          row['timestamp'],
          row['result'],
          row['error_message'] ?? '',
          row['duration_ms'],
        ],
      );
    }
    if (dropped > 0) {
      Loggers.app.info('m004: dropped $dropped stats for deleted servers');
    }
  }

  void _migrateAgentConversations() {
    if (_tableExists('_m004_old_agent_conversation')) {
      for (final row in _db.select(
        'SELECT * FROM _m004_old_agent_conversation;',
      )) {
        _db.execute(
          'INSERT OR REPLACE INTO agent_conversation '
          '(id, server_id, updated_at, data) VALUES (?, ?, ?, ?);',
          [row['id'], row['server_id'], row['updated_at'], row['data']],
        );
      }
    }
    if (!_tableExists('_m004_old_agent_active')) return;
    for (final row in _db.select('SELECT * FROM _m004_old_agent_active;')) {
      final conversationId = row['conversation_id'];
      // The active row now references a real conversation.
      final exists = _db
          .select('SELECT 1 FROM agent_conversation WHERE id = ?;', [
            conversationId,
          ])
          .isNotEmpty;
      if (!exists) continue;
      _db.execute(
        'INSERT OR REPLACE INTO agent_active_conversation VALUES (?, ?);',
        [row['server_id'], conversationId],
      );
    }
  }
}
