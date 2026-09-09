import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/plugin/install.dart';
import 'package:server_box/data/model/plugin/repo_record.dart';
import 'package:server_box/data/res/store.dart';
import 'package:sqlite3/sqlite3.dart';

/// What the app knows about the plugins on this device. PLUGINS.md section 7.
///
/// Not an [EntityStore], not a sync root, and not in a backup. Installing puts
/// files on *this* device; a row arriving on another one would name a plugin
/// that is not there, and `granted` would be consent the user gave on a
/// different device to code this one has never seen. What travels is the
/// plugin's *data* — see PLUGINS.md section 7's `plugins` field — which
/// survives until the plugin is installed again.
class PluginInstallStore {
  PluginInstallStore();

  static final instance = PluginInstallStore();

  Database get _db => SqliteDb.instance;

  /// Every install, oldest first — which is the order they were added in and
  /// the order a list of them reads best in.
  List<PluginInstall> readAll() {
    final rows = _db.select(
      'SELECT id, version, repo, enabled, granted, installed_at '
      'FROM plugin_install ORDER BY installed_at, id;',
    );
    return [for (final row in rows) _fromRow(row)];
  }

  PluginInstall? fetch(String id) {
    final rows = _db.select(
      'SELECT id, version, repo, enabled, granted, installed_at '
      'FROM plugin_install WHERE id = ?;',
      [id],
    );
    final row = rows.singleOrNull;
    return row == null ? null : _fromRow(row);
  }

  /// Whether this plugin is installed *and* switched on.
  ///
  /// The question every caller actually has. Asking `fetch(id) != null` gets
  /// a plugin the user turned off, which is the same as one that is not there
  /// for every purpose except the settings page that turns it back on.
  bool isActive(String id) => fetch(id)?.enabled ?? false;

  /// Writes the record, replacing any earlier one for the same plugin.
  ///
  /// `ON CONFLICT DO UPDATE` naming the data columns, never `INSERT OR
  /// REPLACE`: the latter deletes and reinserts, which would reset every
  /// column this statement does not name — see `EntityStore.upsert`.
  void put(PluginInstall install) {
    _db.execute(
      'INSERT INTO plugin_install '
      '(id, version, repo, enabled, granted, installed_at) '
      'VALUES (?, ?, ?, ?, ?, ?) '
      'ON CONFLICT (id) DO UPDATE SET '
      'version = excluded.version, repo = excluded.repo, '
      'enabled = excluded.enabled, granted = excluded.granted, '
      'installed_at = excluded.installed_at;',
      [
        install.id,
        install.version,
        install.repo,
        install.enabled ? 1 : 0,
        jsonEncode(install.granted.toList()..sort()),
        install.installedAt.millisecondsSinceEpoch,
      ],
    );
  }

  void setEnabled(String id, bool enabled) {
    _db.execute('UPDATE plugin_install SET enabled = ? WHERE id = ?;', [
      enabled ? 1 : 0,
      id,
    ]);
  }

  /// Removes the record, and optionally everything the plugin stored.
  ///
  /// [keepData] is the user's choice at uninstall: a plugin removed to be
  /// reinstalled — an update that went wrong, a repository being switched —
  /// should not take the configuration typed into every server with it.
  ///
  /// One transaction, because a half-removed plugin is a set of rows keyed by
  /// an id nothing resolves.
  void remove(String id, {bool keepData = false}) {
    SqliteStore.transact(() {
      _db.execute('DELETE FROM plugin_install WHERE id = ?;', [id]);
      if (!keepData) {
        PluginCfgStore.instance.removePlugin(id);
        PluginKvStore.instance.removePlugin(id);
      }
    });
  }

  PluginInstall _fromRow(Row row) => PluginInstall(
    id: row['id'] as String,
    version: row['version'] as String,
    repo: row['repo'] as String?,
    enabled: (row['enabled'] as int? ?? 1) != 0,
    granted: PluginInstall.parseGranted(row['granted']),
    installedAt: DateTime.fromMillisecondsSinceEpoch(
      row['installed_at'] as int? ?? 0,
    ),
  );
}

/// One server's configuration for one plugin.
///
/// A child of `server`, like `container_host`: it has no meaning without the
/// server, it cascades with it, and a write stamps the parent rather than
/// carrying sync columns of its own — which is what makes it travel with the
/// server instead of arriving before it.
class PluginCfgStore {
  PluginCfgStore();

  static final instance = PluginCfgStore();

  Database get _db => SqliteDb.instance;

  /// What was typed into [serverId]'s form for [pluginId].
  ///
  /// An empty map for a server that has none, which is what an unconfigured
  /// plugin sees — the editor fills the defaults from `config.fields`, so
  /// there is nothing to distinguish "never opened" from "opened and left
  /// alone".
  Map<String, String> fetch(String serverId, String pluginId) {
    final rows = _db.select(
      'SELECT cfg FROM server_plugin_cfg WHERE server_id = ? AND plugin_id = ?;',
      [serverId, pluginId],
    );
    final raw = rows.singleOrNull?['cfg'] as String?;
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final e in decoded.entries)
          if (e.key is String) e.key as String: '${e.value}',
      };
    } catch (_) {
      // A row this build cannot decode reads as no configuration rather than
      // as a failure: the plugin then behaves as it does on a server that has
      // none, and the editor writes a readable one over it.
      return const {};
    }
  }

  /// Whether this server has been configured for this plugin at all.
  ///
  /// What `contributes.*.requires_config` asks. Distinct from [fetch] being
  /// empty: a form saved with every field left blank is still a decision, and
  /// a card that appeared on every server to say "not configured" would be a
  /// row of noise on the machines that have no BMC, which is most of them.
  bool has(String serverId, String pluginId) =>
      _db
          .select(
            'SELECT 1 FROM server_plugin_cfg '
            'WHERE server_id = ? AND plugin_id = ? LIMIT 1;',
            [serverId, pluginId],
          )
          .isNotEmpty;

  /// Every plugin this server is configured for.
  List<String> pluginsFor(String serverId) {
    final rows = _db.select(
      'SELECT plugin_id FROM server_plugin_cfg WHERE server_id = ? '
      'ORDER BY plugin_id;',
      [serverId],
    );
    return [for (final row in rows) row['plugin_id'] as String];
  }

  /// [cfgVer] is the ABI the manifest declared, which is the one thing a
  /// later host-side conversion would have to branch on and the only moment
  /// it is knowable.
  void put(
    String serverId,
    String pluginId,
    Map<String, String> cfg, {
    required int cfgVer,
  }) {
    SqliteStore.transact(() {
      _db.execute(
        'INSERT INTO server_plugin_cfg (server_id, plugin_id, cfg, cfg_ver) '
        'VALUES (?, ?, ?, ?) '
        'ON CONFLICT (server_id, plugin_id) DO UPDATE SET '
        'cfg = excluded.cfg, cfg_ver = excluded.cfg_ver;',
        [serverId, pluginId, jsonEncode(cfg), cfgVer],
      );
      Stores.server.synced.stamp(serverId);
    });
    Stores.server.invalidate();
  }

  void remove(String serverId, String pluginId) {
    SqliteStore.transact(() {
      _db.execute(
        'DELETE FROM server_plugin_cfg WHERE server_id = ? AND plugin_id = ?;',
        [serverId, pluginId],
      );
      Stores.server.synced.stamp(serverId);
    });
    Stores.server.invalidate();
  }

  /// Every server's configuration for this plugin, for an uninstall.
  ///
  /// No stamp: the servers are unchanged as records — what went away is a
  /// plugin this device no longer has, which is not something to tell another
  /// device about.
  void removePlugin(String pluginId) {
    _db.execute('DELETE FROM server_plugin_cfg WHERE plugin_id = ?;', [
      pluginId,
    ]);
  }
}

/// A plugin's own key-value data, global or against one server.
///
/// Two tables behind one store, for the reason `db.dart` gives: a nullable
/// `server_id` in a primary key is either refused outright (`WITHOUT ROWID`)
/// or silently non-unique (SQLite counts two NULLs as different), so "global"
/// gets a table where it can have an honest key.
class PluginKvStore {
  PluginKvStore();

  static final instance = PluginKvStore();

  Database get _db => SqliteDb.instance;

  /// [serverId] null is the plugin's global namespace.
  String? fetch(String pluginId, String key, {String? serverId}) {
    final rows = serverId == null
        ? _db.select(
            'SELECT value FROM plugin_kv WHERE plugin_id = ? AND key = ?;',
            [pluginId, key],
          )
        : _db.select(
            'SELECT value FROM server_plugin_kv '
            'WHERE server_id = ? AND plugin_id = ? AND key = ?;',
            [serverId, pluginId, key],
          );
    return rows.singleOrNull?['value'] as String?;
  }

  void put(String pluginId, String key, String value, {String? serverId}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (serverId == null) {
      _db.execute(
        'INSERT INTO plugin_kv (plugin_id, key, value, updated_at) '
        'VALUES (?, ?, ?, ?) '
        'ON CONFLICT (plugin_id, key) DO UPDATE SET '
        'value = excluded.value, updated_at = excluded.updated_at;',
        [pluginId, key, value, now],
      );
      return;
    }
    _db.execute(
      'INSERT INTO server_plugin_kv '
      '(server_id, plugin_id, key, value, updated_at) VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT (server_id, plugin_id, key) DO UPDATE SET '
      'value = excluded.value, updated_at = excluded.updated_at;',
      [serverId, pluginId, key, value, now],
    );
  }

  void remove(String pluginId, String key, {String? serverId}) {
    if (serverId == null) {
      _db.execute('DELETE FROM plugin_kv WHERE plugin_id = ? AND key = ?;', [
        pluginId,
        key,
      ]);
      return;
    }
    _db.execute(
      'DELETE FROM server_plugin_kv '
      'WHERE server_id = ? AND plugin_id = ? AND key = ?;',
      [serverId, pluginId, key],
    );
  }

  /// Every key in one namespace, sorted.
  List<String> keys(String pluginId, {String? serverId}) {
    final rows = serverId == null
        ? _db.select(
            'SELECT key FROM plugin_kv WHERE plugin_id = ? ORDER BY key;',
            [pluginId],
          )
        : _db.select(
            'SELECT key FROM server_plugin_kv '
            'WHERE server_id = ? AND plugin_id = ? ORDER BY key;',
            [serverId, pluginId],
          );
    return [for (final row in rows) row['key'] as String];
  }

  /// Everything this plugin ever stored, in both namespaces, for an uninstall.
  void removePlugin(String pluginId) {
    _db.execute('DELETE FROM plugin_kv WHERE plugin_id = ?;', [pluginId]);
    _db.execute('DELETE FROM server_plugin_kv WHERE plugin_id = ?;', [
      pluginId,
    ]);
  }
}

/// The repositories this device reads. PLUGINS.md section 7.
///
/// Keyed by the `index.json` URL, because the URL is the identity — see
/// `PluginRepos` in `db.dart` for why the name would be the wrong key.
class PluginRepoStore {
  PluginRepoStore();

  static final instance = PluginRepoStore();

  Database get _db => SqliteDb.instance;

  /// The repositories this build ships with, added once each — see
  /// [seedOfficial].
  ///
  /// **The repository itself, not a file in it.** What the app fetches is a
  /// tarball of its latest tree, which carries the plugin files and the packages
  /// together — so the digests in it are a consistency check rather than a trust
  /// boundary, and TLS plus that repository's owner is the trust anchor. See
  /// `PluginRepoSource.archiveUrlOf` for what this address turns into.
  static const List<String> officialUrls = [
    'https://github.com/lollipopkit/serverbox-plugins',
  ];

  /// Adds each of [officialUrls] the first time this build sees it.
  ///
  /// **Recorded per URL, not as one flag.** Two things have to be true at once:
  /// a later build that adds a second official repository can add it, and a
  /// repository the user removed stays removed. A bool cannot tell those apart,
  /// and neither can "add it when the list is empty" — an empty list is exactly
  /// what removing the only repository looks like.
  ///
  /// Runs at launch rather than when the store page opens, so the row is there
  /// before anything asks what repositories exist.
  void seedOfficial() {
    final prop = Stores.setting.pluginReposSeeded;
    final seeded = prop.fetch();
    final now = DateTime.now();
    final added = <String>[];
    for (final url in officialUrls) {
      if (seeded.contains(url)) continue;
      added.add(url);
      // Not overwritten if the user typed it in themselves: `put` would keep
      // `added_at`, but there is nothing to write either way.
      if (fetch(url) == null) put(PluginRepoRecord(url: url, addedAt: now));
    }
    if (added.isNotEmpty) prop.put([...seeded, ...added]);
  }

  /// Oldest first, which is the order they were added in and the order that
  /// decides a conflict: two repositories offering the same plugin id, and the
  /// one added first wins.
  List<PluginRepoRecord> readAll() {
    final rows = _db.select(
      'SELECT url, name, enabled, added_at, last_fetched_at '
      'FROM plugin_repo ORDER BY added_at, url;',
    );
    return [for (final row in rows) _fromRow(row)];
  }

  PluginRepoRecord? fetch(String url) {
    final row = _db
        .select(
          'SELECT url, name, enabled, added_at, last_fetched_at '
          'FROM plugin_repo WHERE url = ?;',
          [url],
        )
        .singleOrNull;
    return row == null ? null : _fromRow(row);
  }

  /// Adds or replaces one.
  ///
  /// `ON CONFLICT DO UPDATE` naming only the columns that move, so re-adding a
  /// URL keeps when it was first added rather than resetting it — which is
  /// what decides a plugin-id conflict.
  void put(PluginRepoRecord repo) {
    _db.execute(
      'INSERT INTO plugin_repo (url, name, enabled, added_at, last_fetched_at) '
      'VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT (url) DO UPDATE SET '
      'name = excluded.name, enabled = excluded.enabled, '
      'last_fetched_at = excluded.last_fetched_at;',
      [
        repo.url,
        repo.name,
        repo.enabled ? 1 : 0,
        repo.addedAt.millisecondsSinceEpoch,
        repo.lastFetchedAt?.millisecondsSinceEpoch,
      ],
    );
  }

  void remove(String url) =>
      _db.execute('DELETE FROM plugin_repo WHERE url = ?;', [url]);

  void setEnabled(String url, bool enabled) => _db.execute(
    'UPDATE plugin_repo SET enabled = ? WHERE url = ?;',
    [enabled ? 1 : 0, url],
  );

  PluginRepoRecord _fromRow(Row row) => PluginRepoRecord(
    url: row['url'] as String,
    name: row['name'] as String?,
    enabled: (row['enabled'] as int? ?? 1) != 0,
    addedAt: DateTime.fromMillisecondsSinceEpoch(row['added_at'] as int? ?? 0),
    lastFetchedAt: row['last_fetched_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row['last_fetched_at'] as int),
  );
}
