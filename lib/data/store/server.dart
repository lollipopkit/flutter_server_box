import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/store/agent_conversation.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:server_box/data/store/port_forward.dart';
import 'package:server_box/data/store/snippet.dart';
import 'package:sqlite3/sqlite3.dart';

/// Servers, as rows in `server` plus the child tables hanging off it.
///
/// A [Spi] is assembled from six tables, but never six queries per server:
/// [readAll] reads each child table once and groups in Dart, so the cost is
/// the number of tables rather than the number of servers.
class ServerStore extends EntityStore<Spi> {
  static const _identityFilesPrefix = 'server-box:identity-files:';

  ServerStore._()
    : _portForwards = PortForwardStore.instance,
      _snippets = SnippetStore.instance,
      _conversations = AgentConversationStore.instance;

  /// See [PrivateKeyStore.forTest].
  @visibleForTesting
  ServerStore.forTest({
    PortForwardStore? portForwards,
    SnippetStore? snippets,
    AgentConversationStore? conversations,
  }) : _portForwards = portForwards,
       _snippets = snippets,
       _conversations = conversations;

  static final instance = ServerStore._();

  final PortForwardStore? _portForwards;
  final SnippetStore? _snippets;
  final AgentConversationStore? _conversations;

  @override
  String get table => 'server';

  @override
  String idOf(Spi item) => item.id;

  @override
  String? nameOf(Spi item) => item.name;

  @override
  List<Spi> readAll() {
    final rows = db.select('SELECT * FROM server;');
    if (rows.isEmpty) return const [];

    final tags = _group('SELECT server_id, tag FROM server_tag;', 'tag');
    final disabled = _group(
      'SELECT server_id, cmd_type FROM server_disabled_cmd;',
      'cmd_type',
    );
    final jumps = _group(
      'SELECT server_id, jump_id FROM server_jump ORDER BY ord;',
      'jump_id',
    );
    final envs = _pairs('SELECT server_id, key, value FROM server_env;', 'key',
        'value');
    final cmds = _pairs(
      'SELECT server_id, name, cmd FROM server_custom_cmd;',
      'name',
      'cmd',
    );

    return [
      for (final row in rows)
        _toSpi(
          row,
          tags: tags[row['id']],
          disabled: disabled[row['id']],
          jumps: jumps[row['id']],
          envs: envs[row['id']],
          cmds: cmds[row['id']],
        ),
    ];
  }

  Map<String, List<String>> _group(String sql, String column) {
    final out = <String, List<String>>{};
    for (final row in db.select(sql)) {
      (out[row['server_id'] as String] ??= []).add(row[column] as String);
    }
    return out;
  }

  Map<String, Map<String, String>> _pairs(String sql, String k, String v) {
    final out = <String, Map<String, String>>{};
    for (final row in db.select(sql)) {
      (out[row['server_id'] as String] ??= {})[row[k] as String] =
          row[v] as String;
    }
    return out;
  }

  static Spi _toSpi(
    Row row, {
    List<String>? tags,
    List<String>? disabled,
    List<String>? jumps,
    Map<String, String>? envs,
    Map<String, String>? cmds,
  }) {
    final sshIp = row['ssh_ip'] as String?;
    final identityFiles = _decodeIdentityFiles(row['ssh_key_path'] as String?);
    final monitorAddr = row['monitor_addr'] as String?;
    return Spi(
      id: row['id'] as String,
      name: row['name'] as String,
      autoConnect: (row['auto_connect'] as int) == 1,
      customSystemType: SystemType.values.firstWhereOrNull(
        (e) => e.name == row['system_type'],
      ),
      tags: tags,
      disabledCmdTypes: disabled,
      envs: envs,
      ssh: sshIp == null
          ? null
          : SshCredential(
              ip: sshIp,
              port: row['ssh_port'] as int? ?? 22,
              user: row['ssh_user'] as String? ?? 'root',
              pwd: row['ssh_pwd'] as String?,
              keyId: row['ssh_key_id'] as String?,
              keyPath: identityFiles.$1,
              identityFiles: identityFiles.$2,
              alterUrl: row['ssh_alter_url'] as String?,
              proxyCommand: row['ssh_proxy_command'] as String?,
              jumpId: jumps?.firstOrNull,
              jumpIds: jumps,
            ),
      monitorHttp: monitorAddr == null
          ? null
          : MonitorHttpCredential(
              addr: monitorAddr,
              user: row['monitor_user'] as String?,
              pwd: row['monitor_pwd'] as String?,
              ignoreCert: (row['monitor_ignore_cert'] as int? ?? 0) == 1,
              allowInsecure:
                  (row['monitor_allow_insecure'] as int? ?? 0) == 1,
            ),
      wolCfg: row['wol_mac'] == null
          ? null
          : WakeOnLanCfg(
              mac: row['wol_mac'] as String,
              ip: row['wol_ip'] as String? ?? '',
              pwd: row['wol_pwd'] as String?,
            ),
      // Keyed off the address, which is the one field a BMC cannot be reached
      // without. A row carrying an address but no `bmc_cred_id` — because the
      // account it named was deleted, which sets this to null rather than
      // taking the server with it — comes back incomplete, so the editor shows
      // it and nothing tries to log in.
      bmc: row['bmc_addr'] == null
          ? null
          : BmcCfg(
              addr: row['bmc_addr'] as String,
              credId: row['bmc_cred_id'] as String?,
              certSha256: row['bmc_cert_sha256'] as String?,
            ),
      custom: _customOf(row, cmds),
    );
  }

  static (String?, List<String>?) _decodeIdentityFiles(String? stored) {
    if (stored == null || !stored.startsWith(_identityFilesPrefix)) {
      return (stored, null);
    }
    try {
      final decoded = jsonDecode(stored.substring(_identityFilesPrefix.length));
      if (decoded is! List) return (stored, null);
      final paths = decoded
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toList();
      if (paths.isEmpty) return (null, null);
      return (paths.first, paths);
    } catch (_) {
      // Preserve an old or manually edited literal rather than making its key
      // disappear because it happens to share the reserved prefix.
      return (stored, null);
    }
  }

  static String? _encodeIdentityFiles(SshCredential? ssh) {
    if (ssh == null) return null;
    final paths = ssh.resolvedIdentityFiles;
    if (paths.isEmpty) return null;
    if (paths.length == 1) return paths.first;
    return '$_identityFilesPrefix${jsonEncode(paths)}';
  }

  /// Null when the record says nothing beyond the defaults.
  ///
  /// The columns always have a value — `pve_ignore_cert` and `temp_is_celsius`
  /// are `NOT NULL` with one — so building a [ServerCustom] unconditionally
  /// would give every server a non-null `custom` it did not have before, and
  /// put it in every backup.
  static ServerCustom? _customOf(Row row, Map<String, String>? cmds) {
    const strings = [
      'pve_addr',
      'pve_pwd',
      'prefer_temp_dev',
      'logo_url',
      'net_dev',
      'script_dir',
    ];
    final pveIgnoreCert = (row['pve_ignore_cert'] as int) == 1;
    final tempIsCelsius = (row['temp_is_celsius'] as int) == 1;
    // Field by field rather than against `const ServerCustom()`: this is a
    // plain class with no `==`, so comparing would always say "different".
    if (cmds == null &&
        !pveIgnoreCert &&
        tempIsCelsius &&
        strings.every((c) => row[c] == null)) {
      return null;
    }
    return ServerCustom(
      pveAddr: row['pve_addr'] as String?,
      pveIgnoreCert: pveIgnoreCert,
      pvePwd: row['pve_pwd'] as String?,
      cmds: cmds,
      preferTempDev: row['prefer_temp_dev'] as String?,
      tempIsCelsius: tempIsCelsius,
      logoUrl: row['logo_url'] as String?,
      netDev: row['net_dev'] as String?,
      scriptDir: row['script_dir'] as String?,
    );
  }

  @override
  void write(Spi item) {
    final ssh = item.ssh;
    final monitor = item.monitorHttp;
    final bmc = item.bmc;
    final custom = item.custom;
    const columns = [
      'id', 'name', 'auto_connect', 'system_type',
      'ssh_ip', 'ssh_port', 'ssh_user', 'ssh_pwd', 'ssh_key_id',
      'ssh_key_path', 'ssh_alter_url', 'ssh_proxy_command',
      'monitor_addr', 'monitor_user', 'monitor_pwd', 'monitor_ignore_cert',
      'monitor_allow_insecure',
      'wol_mac', 'wol_ip', 'wol_pwd',
      'bmc_addr', 'bmc_cred_id', 'bmc_cert_sha256',
      'pve_addr', 'pve_ignore_cert', 'pve_pwd', 'prefer_temp_dev',
      'temp_is_celsius', 'logo_url', 'net_dev', 'script_dir',
    ];
    upsert(columns, [
      item.id,
      item.name,
      item.autoConnect ? 1 : 0,
      item.customSystemType?.name,
      ssh?.ip,
      ssh?.port,
      ssh?.user,
      ssh?.pwd,
      ssh?.keyId,
      _encodeIdentityFiles(ssh),
      ssh?.alterUrl,
      ssh?.proxyCommand,
      monitor?.addr,
      monitor?.user,
      monitor?.pwd,
      monitor == null ? null : (monitor.ignoreCert ? 1 : 0),
      monitor == null ? null : (monitor.allowInsecure ? 1 : 0),
      item.wolCfg?.mac,
      item.wolCfg?.ip,
      item.wolCfg?.pwd,
      bmc?.addr,
      bmc?.credId,
      bmc?.certSha256,
      custom?.pveAddr,
      (custom?.pveIgnoreCert ?? false) ? 1 : 0,
      custom?.pvePwd,
      custom?.preferTempDev,
      (custom?.tempIsCelsius ?? true) ? 1 : 0,
      custom?.logoUrl,
      custom?.netDev,
      custom?.scriptDir,
    ]);

    // Replaced wholesale rather than diffed: the record arrives as one object,
    // so what it does not carry is what was removed.
    for (final t in const [
      'server_tag',
      'server_env',
      'server_jump',
      'server_disabled_cmd',
      'server_custom_cmd',
    ]) {
      db.execute('DELETE FROM $t WHERE server_id = ?;', [item.id]);
    }

    for (final tag in item.tags ?? const <String>[]) {
      db.execute('INSERT OR IGNORE INTO server_tag VALUES (?, ?);', [
        item.id,
        tag,
      ]);
    }
    (item.envs ?? const <String, String>{}).forEach((k, v) {
      db.execute('INSERT OR IGNORE INTO server_env VALUES (?, ?, ?);', [
        item.id,
        k,
        v,
      ]);
    });
    for (final cmd in item.disabledCmdTypes ?? const <String>[]) {
      db.execute('INSERT OR IGNORE INTO server_disabled_cmd VALUES (?, ?);', [
        item.id,
        cmd,
      ]);
    }
    (custom?.cmds ?? const <String, String>{}).forEach((k, v) {
      db.execute('INSERT OR IGNORE INTO server_custom_cmd VALUES (?, ?, ?);', [
        item.id,
        k,
        v,
      ]);
    });

  }

  /// A jump host is a server, so the row it names may not have been written
  /// yet — during a restore the order is whatever the backup listed. This runs
  /// once every server exists.
  ///
  /// One that is still missing is dropped rather than written as a dangling
  /// reference; the foreign key would refuse it anyway, and refusing would
  /// fail the whole restore over a server deleted long ago.
  @override
  void writeLinks(Spi item) {
    var ord = 0;
    for (final jump in item.ssh?.resolvedJumpIds ?? const <String>[]) {
      final exists = db
          .select('SELECT 1 FROM server WHERE id = ?;', [jump])
          .isNotEmpty;
      if (!exists) continue;
      db.execute('INSERT INTO server_jump VALUES (?, ?, ?);', [
        item.id,
        ord++,
        jump,
      ]);
    }
  }

  @override
  Map<String, dynamic> toJson(Spi item) => item.toJson();

  @override
  Spi? fromJson(Map<String, dynamic> json) {
    try {
      return Spi.fromJson(json);
    } catch (e) {
      dprint('Parsing Spi from JSON', e);
      return null;
    }
  }

  /// Servers carrying [tag], as a query rather than a decode of every record.
  List<String> idsWithTag(String tag) => db
      .select('SELECT server_id FROM server_tag WHERE tag = ?;', [tag])
      .map((r) => r['server_id'] as String)
      .toList();

  /// Every tag in use, for the filter bar.
  List<String> allTags() => db
      .select('SELECT DISTINCT tag FROM server_tag ORDER BY tag;')
      .map((r) => r['tag'] as String)
      .toList();

  /// The trusted host keys for [serverId], which go when the server does.
  Map<String, String> knownHosts(String serverId) => {
    for (final row in db.select(
      'SELECT key_type, fingerprint FROM known_host WHERE server_id = ?;',
      [serverId],
    ))
      row['key_type'] as String: row['fingerprint'] as String,
  };

  void trustHost(String serverId, String keyType, String fingerprint) {
    SqliteStore.transact(() {
      db.execute('INSERT OR REPLACE INTO known_host VALUES (?, ?, ?);', [
        serverId,
        keyType,
        fingerprint,
      ]);
      synced.stamp(serverId);
    });
    invalidate();
  }

  void forgetHost(String serverId, String keyType) {
    SqliteStore.transact(() {
      db.execute(
        'DELETE FROM known_host WHERE server_id = ? AND key_type = ?;',
        [serverId, keyType],
      );
      synced.stamp(serverId);
    });
    invalidate();
  }

  @override
  void deleteById(String id) {
    final pfIds = db
        .select('SELECT id FROM port_forward WHERE server_id = ?;', [id])
        .map((r) => r['id'] as String)
        .toList();
    final snippetIds = _referencingIds(
      'SELECT snippet_id AS id FROM snippet_auto_run_on WHERE server_id = ?;',
      id,
    );
    final jumpOwnerIds = _referencingIds(
      'SELECT server_id AS id FROM server_jump WHERE jump_id = ?;',
      id,
    );
    SqliteStore.transact(() {
      final at = DateTimeX.timestamp;
      for (final pfId in pfIds) {
        db.execute(
          'INSERT OR REPLACE INTO tombstone (tbl, row_id, deleted_at) VALUES (?, ?, ?);',
          ['port_forward', pfId, at],
        );
      }
      final snippetSync = SyncedTable('snippet');
      for (final snippetId in snippetIds) {
        snippetSync.stamp(snippetId, at: at);
      }
      for (final ownerId in jumpOwnerIds) {
        if (ownerId != id) synced.stamp(ownerId, at: at);
      }
      db.execute('DELETE FROM port_forward WHERE server_id = ?;', [id]);
      db.execute('DELETE FROM $table WHERE $idColumn = ?;', [id]);
      synced.tombstone(id, at: at);
    });
    invalidate();
    if (pfIds.isNotEmpty) _portForwards?.invalidate();
    if (snippetIds.isNotEmpty) _snippets?.invalidate();
  }

  /// Changes a server's stable id without exposing a state in which either
  /// the parent or one of its dependent rows is missing.
  void rename(Spi old, Spi replacement) {
    if (old.id == replacement.id) {
      update(old, replacement);
      return;
    }
    if (db.select('SELECT 1 FROM server WHERE id = ?;', [
      replacement.id,
    ]).isNotEmpty) {
      throw StateError('server id already exists: ${replacement.id}');
    }

    final snippetIds = _referencingIds(
      'SELECT snippet_id AS id FROM snippet_auto_run_on WHERE server_id = ?;',
      old.id,
    );
    final portForwardIds = _referencingIds(
      'SELECT id FROM port_forward WHERE server_id = ?;',
      old.id,
    );
    final jumpOwnerIds = _referencingIds(
      'SELECT server_id AS id FROM server_jump WHERE jump_id = ?;',
      old.id,
    );

    try {
      SqliteStore.transact(() {
        final at = DateTimeX.timestamp;
        // Free a same-name replacement without deleting the old parent first.
        db.execute('UPDATE server SET name = ? WHERE id = ?;', [
          '__server_rename_${ShortId.generate()}',
          old.id,
        ]);
        write(replacement);
        writeLinks(replacement);

        for (final table in const [
          'known_host',
          'container_host',
          'container_runtime',
          'port_forward',
          'conn_stat',
        ]) {
          db.execute('UPDATE $table SET server_id = ? WHERE server_id = ?;', [
            replacement.id,
            old.id,
          ]);
        }
        db.execute(
          'UPDATE snippet_auto_run_on SET server_id = ? WHERE server_id = ?;',
          [replacement.id, old.id],
        );
        db.execute('UPDATE server_jump SET jump_id = ? WHERE jump_id = ?;', [
          replacement.id,
          old.id,
        ]);

        for (final row in db.select(
          'SELECT id, data FROM agent_conversation WHERE server_id = ?;',
          [old.id],
        )) {
          final data = json.decode(row['data'] as String);
          if (data is! Map) {
            throw const FormatException('agent conversation is not an object');
          }
          final updated = Map<String, Object?>.from(data)
            ..['server_id'] = replacement.id;
          db.execute(
            'UPDATE agent_conversation SET server_id = ?, data = ? WHERE id = ?;',
            [replacement.id, json.encode(updated), row['id']],
          );
        }
        db.execute(
          'UPDATE agent_active_conversation SET server_id = ? WHERE server_id = ?;',
          [replacement.id, old.id],
        );

        final snippetSync = SyncedTable('snippet');
        for (final snippetId in snippetIds) {
          snippetSync.stamp(snippetId, at: at);
        }
        final forwardSync = SyncedTable('port_forward');
        for (final forwardId in portForwardIds) {
          forwardSync.stamp(forwardId, at: at);
        }
        for (final ownerId in jumpOwnerIds) {
          if (ownerId != old.id) synced.stamp(ownerId, at: at);
        }

        db.execute('DELETE FROM server WHERE id = ?;', [old.id]);
        synced.tombstone(old.id, at: at);
        synced.stamp(replacement.id, at: at);
      });
    } on SqliteException catch (e) {
      if (e.extendedResultCode == 2067) {
        throw DuplicateNameException(replacement.name);
      }
      rethrow;
    }

    invalidate();
    if (portForwardIds.isNotEmpty) _portForwards?.invalidate();
    if (snippetIds.isNotEmpty) _snippets?.invalidate();
    _conversations?.notifyExternalChange();
  }

  List<String> _referencingIds(String sql, String serverId) => db
      .select(sql, [serverId])
      .map((row) => row['id'] as String)
      .toSet()
      .toList();
}
