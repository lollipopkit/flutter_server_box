import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/res/store.dart';
import 'package:sqlite3/sqlite3.dart';

/// Each server's Proxmox VE configuration: the `server_pve` table.
///
/// Not an `EntityStore`, for `ContainerStore`'s reason: a row is a child of
/// `server`, with no `updated_at` of its own and nothing to tombstone. A
/// change is a change to the server — [put] and [remove] stamp it — which is
/// what makes the row travel with its server instead of arriving before it,
/// and what lets a deleted server take its row with it by cascade.
class PveStore {
  PveStore();

  static final instance = PveStore();

  Database get _db => SqliteDb.instance;

  final _changes = StreamController<void>.broadcast();

  /// An event after every change to any row, the way `EntityStore.watch`
  /// announces its own. What `pveConfigsProvider` re-reads on — and so what
  /// makes a server that gains or loses PVE switch backend in the
  /// Virtualization tab without a restart.
  ///
  /// [put] and [restoreOne] announce their own writes unless told not to
  /// (`notify: false`, inside a restore); whoever passed that calls
  /// [invalidate] once the writes are committed.
  Stream<void> watch() => _changes.stream;

  /// Announces a change made with `notify: false`.
  void invalidate() {
    if (!_changes.isClosed) _changes.add(null);
  }

  static const _columns =
      'server_id, addr, auth, pwd, token_id, token_secret, cert_sha256';

  /// The configuration for [serverId], or null when it has none.
  PveConfig? fetch(String? serverId) {
    if (serverId == null) return null;
    final row = _db.select(
      'SELECT $_columns FROM server_pve WHERE server_id = ?;',
      [serverId],
    ).singleOrNull;
    return row == null ? null : _fromRow(row);
  }

  /// Every server's configuration, by server id.
  Map<String, PveConfig> fetchAll() => {
    for (final row in _db.select('SELECT $_columns FROM server_pve;'))
      row['server_id'] as String: _fromRow(row),
  };

  static PveConfig _fromRow(Row row) => PveConfig(
    addr: row['addr'] as String,
    // The CHECK admits only known names; a row a newer build wrote with a
    // name added since reads as a password login rather than throwing.
    auth: PveAuth.fromName(row['auth']) ?? PveAuth.password,
    pwd: row['pwd'] as String?,
    tokenId: row['token_id'] as String?,
    tokenSecret: row['token_secret'] as String?,
    certSha256: row['cert_sha256'] as String?,
  );

  void _write(String serverId, PveConfig cfg) {
    _db.execute(
      'INSERT INTO server_pve ($_columns) VALUES (?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT (server_id) DO UPDATE SET addr = excluded.addr, '
      'auth = excluded.auth, pwd = excluded.pwd, '
      'token_id = excluded.token_id, token_secret = excluded.token_secret, '
      'cert_sha256 = excluded.cert_sha256;',
      [
        serverId,
        cfg.addr,
        cfg.auth.name,
        cfg.pwd,
        cfg.tokenId,
        cfg.tokenSecret,
        cfg.certSha256,
      ],
    );
  }

  /// Writes [cfg] for [serverId], or removes the row when [cfg] is null.
  ///
  /// Writing what is already there is not an edit and stamps nothing: a
  /// server saved from the editor without touching PVE must not look newer
  /// to a peer for it.
  void put(String serverId, PveConfig? cfg, {bool notify = true}) {
    if (fetch(serverId) == cfg) return;
    SqliteStore.transact(() {
      if (cfg == null) {
        _db.execute('DELETE FROM server_pve WHERE server_id = ?;', [serverId]);
      } else {
        _write(serverId, cfg);
      }
      Stores.server.synced.stamp(serverId);
    });
    if (notify) {
      Stores.server.invalidate();
      invalidate();
    }
  }

  void remove(String serverId, {bool notify = true}) =>
      put(serverId, null, notify: notify);

  /// Everything this store holds, keyed the way a backup carries it.
  Map<String, Object?> getAllMap() => {
    for (final MapEntry(:key, :value) in fetchAll().entries)
      key: value.toJson(),
  };

  /// Writes one entry of [getAllMap] back, the complete state for that
  /// server: a missing or empty entry removes the row. Skips a server that is
  /// not here — the table has a foreign key, and a backup can name a server
  /// this device deleted.
  ///
  /// Answers whether anything changed.
  bool restoreOne(String serverId, Object? value, {bool notify = true}) {
    if (!_known(serverId)) return false;
    final desired = _decode(value);
    if (fetch(serverId) == desired) return false;
    put(serverId, desired, notify: notify);
    return true;
  }

  static PveConfig? _decode(Object? value) {
    if (value is! Map || value.isEmpty) return null;
    try {
      // Through JSON, so a map decoded as `Map<dynamic, dynamic>` and one
      // built in code read the same.
      final map = json.decode(json.encode(value)) as Map<String, dynamic>;
      return PveConfig.fromJson(map);
    } catch (e, s) {
      // Loses the PVE configuration, not the server or the restore.
      Loggers.app.warning('Unreadable PVE configuration was skipped', e, s);
      return null;
    }
  }

  bool _known(String serverId) =>
      _db.select('SELECT 1 FROM server WHERE id = ?;', [serverId]).isNotEmpty;
}
