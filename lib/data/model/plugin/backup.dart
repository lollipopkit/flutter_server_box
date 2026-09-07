import 'package:fl_lib/fl_lib.dart';
import 'package:sqlite3/sqlite3.dart';

/// A plugin's data in a backup. PLUGINS.md section 7's `plugins` field.
///
/// **Data, not installs.** A backup restores records, not files, so carrying
/// the install record would restore a row naming a directory that is not
/// there — a plugin that fails to load on every launch. What travels is the
/// configuration typed into each server and whatever the plugin stored, both
/// of which survive until the plugin is installed again. That is also what
/// makes an id nothing currently claims worth keeping rather than dropping.
///
/// **A share is not a backup and does not carry this.** `ServerShare` is its
/// own model, deliberately, and a plugin's configuration can hold a field the
/// manifest marked `secret` — a BMC password. If a share ever grows a plugin's
/// configuration, that is where PLUGINS.md section 7's "remove the `secret`
/// fields when sharing" has to be applied, and it is not a rule this file can
/// enforce on its behalf.
///
/// ```json
/// "plugins": {
///   "app.serverbox.bmc": {
///     "cfg": [{"server": "srv-1", "values": {"addr": "https://..."}, "ver": 1}],
///     "kv":  [{"server": null, "key": "acct/a", "value": "..."}]
///   }
/// }
/// ```
abstract final class PluginBackup {
  static Database get _db => SqliteDb.instance;

  /// Everything every plugin has stored, by plugin id.
  static Map<String, Object?> load() {
    final out = <String, Map<String, Object?>>{};
    Map<String, Object?> of(String id) =>
        out[id] ??= {'cfg': <Object?>[], 'kv': <Object?>[]};

    for (final row in _db.select(
      'SELECT plugin_id, server_id, cfg, cfg_ver FROM server_plugin_cfg '
      'ORDER BY plugin_id, server_id;',
    )) {
      (of(row['plugin_id'] as String)['cfg']! as List).add({
        'server': row['server_id'],
        'values': row['cfg'],
        'ver': row['cfg_ver'],
      });
    }
    for (final row in _db.select(
      'SELECT plugin_id, key, value FROM plugin_kv ORDER BY plugin_id, key;',
    )) {
      (of(row['plugin_id'] as String)['kv']! as List).add({
        'server': null,
        'key': row['key'],
        'value': row['value'],
      });
    }
    for (final row in _db.select(
      'SELECT plugin_id, server_id, key, value FROM server_plugin_kv '
      'ORDER BY plugin_id, server_id, key;',
    )) {
      (of(row['plugin_id'] as String)['kv']! as List).add({
        'server': row['server_id'],
        'key': row['key'],
        'value': row['value'],
      });
    }
    return out;
  }

  /// Writes back what [load] produced.
  ///
  /// [serverIds] remaps the ids in the file onto the ones this device ended up
  /// with, the same mapping snippets and port forwards go through — a server
  /// matched by name may already exist here under a different id.
  ///
  /// **Added to, never replacing.** Unlike `container`, this is not the
  /// complete state of anything the backup also carries: a plugin's data is
  /// its own, the file may have been written by a device with a different set
  /// of plugins installed, and deleting what it does not mention would make
  /// restoring an old backup a way to lose a newer plugin's data. The file
  /// wins where the two name the same thing, which is what restoring means.
  ///
  /// An entry for a server that is not here is skipped: both tables have a
  /// foreign key, and a backup can name a server this device deleted.
  ///
  /// Answers whether anything was written, so the caller can decide what to
  /// notify. Runs inside the caller's transaction.
  static bool restore(
    Object? raw, {
    Map<String, String> serverIds = const {},
  }) {
    if (raw is! Map) return false;
    var changed = false;

    for (final e in raw.entries) {
      final pluginId = e.key;
      final data = e.value;
      if (pluginId is! String || pluginId.isEmpty || data is! Map) continue;

      for (final entry in _entries(data['cfg'])) {
        final serverId = _server(entry['server'], serverIds);
        // Configuration belongs to a server; there is no global form.
        if (serverId == null || !_knownServer(serverId)) continue;
        final values = entry['values'];
        if (values is! String) continue;
        _db.execute(
          'INSERT INTO server_plugin_cfg (server_id, plugin_id, cfg, cfg_ver) '
          'VALUES (?, ?, ?, ?) '
          'ON CONFLICT (server_id, plugin_id) DO UPDATE SET '
          'cfg = excluded.cfg, cfg_ver = excluded.cfg_ver;',
          [serverId, pluginId, values, _int(entry['ver'])],
        );
        changed = true;
      }

      for (final entry in _entries(data['kv'])) {
        final key = entry['key'];
        final value = entry['value'];
        if (key is! String || key.isEmpty || value is! String) continue;
        final serverId = _server(entry['server'], serverIds);
        final now = DateTime.now().millisecondsSinceEpoch;
        if (serverId == null) {
          _db.execute(
            'INSERT INTO plugin_kv (plugin_id, key, value, updated_at) '
            'VALUES (?, ?, ?, ?) '
            'ON CONFLICT (plugin_id, key) DO UPDATE SET '
            'value = excluded.value, updated_at = excluded.updated_at;',
            [pluginId, key, value, now],
          );
          changed = true;
          continue;
        }
        if (!_knownServer(serverId)) continue;
        _db.execute(
          'INSERT INTO server_plugin_kv '
          '(server_id, plugin_id, key, value, updated_at) '
          'VALUES (?, ?, ?, ?, ?) '
          'ON CONFLICT (server_id, plugin_id, key) DO UPDATE SET '
          'value = excluded.value, updated_at = excluded.updated_at;',
          [serverId, pluginId, key, value, now],
        );
        changed = true;
      }
    }
    return changed;
  }

  static Iterable<Map<Object?, Object?>> _entries(Object? raw) sync* {
    if (raw is! List) return;
    for (final entry in raw) {
      if (entry is Map) yield entry;
    }
  }

  static String? _server(Object? raw, Map<String, String> serverIds) {
    if (raw is! String || raw.isEmpty) return null;
    return serverIds[raw] ?? raw;
  }

  static int _int(Object? raw) => raw is int ? raw : 1;

  static bool _knownServer(String id) =>
      _db.select('SELECT 1 FROM server WHERE id = ? LIMIT 1;', [id]).isNotEmpty;
}
