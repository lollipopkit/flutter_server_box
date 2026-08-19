import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:sqlite3/sqlite3.dart';

/// Servers, as rows in `server` plus the child tables hanging off it.
///
/// A [Spi] is assembled from six tables, but never six queries per server:
/// [readAll] reads each child table once and groups in Dart, so the cost is
/// the number of tables rather than the number of servers.
class ServerStore extends EntityStore<Spi> {
  ServerStore._() : super('server');

  static final instance = ServerStore._();

  @override
  String idOf(Spi item) => item.id;

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
              keyPath: row['ssh_key_path'] as String?,
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
            ),
      wolCfg: row['wol_mac'] == null
          ? null
          : WakeOnLanCfg(
              mac: row['wol_mac'] as String,
              ip: row['wol_ip'] as String? ?? '',
              pwd: row['wol_pwd'] as String?,
            ),
      custom: ServerCustom(
        pveAddr: row['pve_addr'] as String?,
        pveIgnoreCert: (row['pve_ignore_cert'] as int) == 1,
        pvePwd: row['pve_pwd'] as String?,
        cmds: cmds,
        preferTempDev: row['prefer_temp_dev'] as String?,
        tempIsCelsius: (row['temp_is_celsius'] as int) == 1,
        logoUrl: row['logo_url'] as String?,
        netDev: row['net_dev'] as String?,
        scriptDir: row['script_dir'] as String?,
      ),
    );
  }

  @override
  void write(Spi item) {
    final ssh = item.ssh;
    final monitor = item.monitorHttp;
    final custom = item.custom;
    const columns = [
      'id', 'name', 'auto_connect', 'system_type',
      'ssh_ip', 'ssh_port', 'ssh_user', 'ssh_pwd', 'ssh_key_id',
      'ssh_key_path', 'ssh_alter_url', 'ssh_proxy_command',
      'monitor_addr', 'monitor_user', 'monitor_pwd', 'monitor_ignore_cert',
      'wol_mac', 'wol_ip', 'wol_pwd',
      'pve_addr', 'pve_ignore_cert', 'pve_pwd', 'prefer_temp_dev',
      'temp_is_celsius', 'logo_url', 'net_dev', 'script_dir',
    ];
    upsert(table, columns, [
      item.id,
      item.name,
      item.autoConnect ? 1 : 0,
      item.customSystemType?.name,
      ssh?.ip,
      ssh?.port,
      ssh?.user,
      ssh?.pwd,
      ssh?.keyId,
      ssh?.keyPath,
      ssh?.alterUrl,
      ssh?.proxyCommand,
      monitor?.addr,
      monitor?.user,
      monitor?.pwd,
      monitor == null ? null : (monitor.ignoreCert ? 1 : 0),
      item.wolCfg?.mac,
      item.wolCfg?.ip,
      item.wolCfg?.pwd,
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

    var ord = 0;
    for (final jump in ssh?.resolvedJumpIds ?? const <String>[]) {
      // A jump host is a server, and the schema says so. One that is not there
      // is dropped rather than written as a dangling reference.
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
  Map<String, Object?> getAllMap() => {
    for (final spi in fetch()) spi.id: spi.toJson(),
  };

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
    db.execute('INSERT OR REPLACE INTO known_host VALUES (?, ?, ?);', [
      serverId,
      keyType,
      fingerprint,
    ]);
    touch(serverId);
  }

  void forgetHost(String serverId, String keyType) {
    db.execute('DELETE FROM known_host WHERE server_id = ? AND key_type = ?;', [
      serverId,
      keyType,
    ]);
    touch(serverId);
  }
}
