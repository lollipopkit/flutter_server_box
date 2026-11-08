import 'dart:async';
import 'dart:math';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show LlmStores;
import 'package:flutter/foundation.dart' show Listenable;
import 'package:server_box/data/store/secret.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:sqlite3/sqlite3.dart';

/// Records every change a sync carries as its record's newest stamp in
/// `sync_record` (`fl_sync`'s hybrid logical clock).
///
/// Two ways in, the only two a synced change takes: [SyncedTable.stamp] and
/// [SyncedTable.tombstone] for a sync root's row, and [KvStore.onEdit] for a
/// key of a synced kv store. A record is `(c, id)`: the root's table and the
/// row's id, or `kv:<store>` and the key.
///
/// What this device still has to send is its own stamps after the last one
/// sent ([pending]); the value goes with it as the store holds it then, so a
/// child's edit, which stamps its parent, sends the parent whole.
abstract final class SyncRecorder {
  /// The kv stores that sync, by name: the settings, the Agent's
  /// providers, tool switches and memory, and the secrets. Every other one
  /// stays on the device: `history` (what was typed and visited here) and
  /// the chats.
  static final syncedStores = <String, SqliteStore>{
    for (final store in [
      SettingStore.instance,
      LlmStores.llm,
      LlmStores.tool,
      LlmStores.memory,
      LlmStores.credential,
      LlmStores.mcpSecret,
      SudoPasswordStore.instance,
      KeyPassphraseStore.instance,
      SyncRemoteStore.instance,
    ])
      store.name: store,
  };

  /// The sync roots' tables, by name: a migration seeds from them before any
  /// store is registered. `Stores.syncedTables` answers the same
  /// (`sync_recorder_test.dart`).
  static const roots = [
    'server',
    'private_key',
    'bmc_credential',
    'snippet',
    'port_forward',
    'remote_desktop_profile',
  ];

  /// This install's id, in `sync_state`.
  static const _deviceKey = 'device';

  static Database get _db => SqliteDb.instance;

  static int _applying = 0;
  static String? _receiving;
  static BigInt? _device;
  static String? _last;

  /// Notified of each record stamped by this device (not while [applying] or
  /// [receiving]): what makes the log syncs send.
  static final onLocal = <void Function()>[];

  /// Writes an op another device made, stamped [h]: every record [write]
  /// stamps gets [h] as it is, and the clock moves past it.
  static T receiving<T>(String h, T Function() write) {
    final previous = _receiving;
    _receiving = h;
    try {
      return write();
    } finally {
      _receiving = previous;
    }
  }

  /// Sets [key] of [store] to what an older build kept outside the stores,
  /// as no device's edit at no time, for the log and the whole backup alike:
  /// an edit made on any device wins over it, and two devices that adopted
  /// different ones each keep theirs until one is edited.
  /// TODO: remove with the keychain adoptions.
  static void adopt(SqliteStore store, String key, Object value) {
    store.set(key, value, updateLastUpdateTsOnSet: false);
    if (!_ready || !syncedStores.containsKey(store.name)) return;
    // As an edit is: one kept on this device is no record.
    if (store.isDeviceLocalKey(key) || store.isInternalKey(key)) return;
    receiving(syncStampOf(ms: BigInt.zero, device: legacy), () => record('kv:${store.name}', key));
  }

  /// A stamp's wall-clock part.
  static int msOf(String h) => int.parse(h.substring(0, 12), radix: 16);

  /// A stamp's device, as [pending] compares it.
  static String deviceHexOf(BigInt device) => device.toRadixString(16).padLeft(16, '0');

  /// Writes changes that came from elsewhere through [write]: their stamps
  /// are no device's ([legacy]) and never [pending].
  static T applying<T>(T Function() write) {
    _applying++;
    try {
      return write();
    } finally {
      _applying--;
    }
  }

  /// The device id a stamp of something not made here carries: the snapshot
  /// sync's changes, whose maker it does not record.
  static final legacy = BigInt.zero;

  /// This install's device id, made once: a random 63-bit number, never
  /// [legacy].
  static BigInt get device {
    if (_device case final device?) return device;
    final rows = _db.select('SELECT v FROM sync_state WHERE k = ?;', [_deviceKey]);
    if (rows.isNotEmpty) return _device = BigInt.parse(rows.first['v'] as String);
    final random = Random.secure();
    var id = BigInt.zero;
    while (id == BigInt.zero) {
      id = (BigInt.from(random.nextInt(1 << 31)) << 32) | BigInt.from(random.nextInt(1 << 32));
    }
    _db.execute('INSERT OR IGNORE INTO sync_state (k, v) VALUES (?, ?);', [_deviceKey, '$id']);
    final kept = BigInt.parse(_db.select('SELECT v FROM sync_state WHERE k = ?;', [_deviceKey]).first['v'] as String);
    // Inside a transaction the row may yet be rolled back: kept in memory
    // only once it is committed, or the next launch makes another id and
    // what was stamped under this one is never sent. [install] makes it at
    // launch, outside any.
    if (_db.autocommit) _device = kept;
    return kept;
  }

  /// Whether stamps can be made: fl_lib's Rust is loaded. Without it nothing
  /// is recorded, and the app still runs (the snapshot sync does not need it).
  static bool get _ready => FlRust.ready;

  /// The newest stamp held, made here or not: the clock resumes after it.
  static String get _newest =>
      _last ??= _db.select('SELECT MAX(hlc) AS h FROM sync_record;').first['h'] as String? ?? '';

  /// Takes kv edits from now on. At launch, outside any transaction, so this
  /// install's [device] id is made and committed first.
  static void install() {
    if (_ready) device;
    KvStore.onEdit = (store, key, _) {
      if (!syncedStores.containsKey(store.name)) return;
      record('kv:${store.name}', key);
    };
  }

  /// [c]/[id] changed: here at the clock's next stamp; while [receiving], at
  /// its stamp; while [applying], at [at] (milliseconds) as no device's
  /// change.
  ///
  /// Answers the stamp made, null when none can be (fl_lib's Rust is not
  /// loaded). A record keeps the greater of its stamp and this one: a stamp
  /// never moves back (the snapshot sync taking back this device's own edit
  /// stamps it as no device's, which sorts before it).
  /// [notify] false leaves out [onLocal]: for a stamp made by the send itself.
  static String? record(String c, String id, {int? at, bool notify = true}) {
    if (!_ready) return null;
    final String h;
    if (_receiving case final received?) {
      h = received;
      _last = syncLater(last: _newest, seen: h);
    } else if (_applying > 0) {
      h = syncStampOf(ms: BigInt.from(at ?? SyncClock.now()), device: legacy);
      // What came from elsewhere moves the clock too: the next change made
      // here is stamped after it.
      _last = syncLater(last: _newest, seen: h);
    } else {
      h = syncTick(device: device, last: _newest, nowMs: BigInt.from(SyncClock.now()));
      _last = h;
    }
    _db.execute(
      'INSERT INTO sync_record (c, id, hlc) VALUES (?, ?, ?) '
      'ON CONFLICT (c, id) DO UPDATE SET hlc = excluded.hlc WHERE excluded.hlc > sync_record.hlc;',
      [c, id, h],
    );
    if (notify && _receiving == null && _applying == 0) {
      for (final f in onLocal) {
        f();
      }
    }
    return h;
  }

  /// Each record's stamp, for the ones [ids] names: what an incoming op is
  /// compared against.
  static Map<(String, String), String> stampsOf(Iterable<(String, String)> ids) {
    final out = <(String, String), String>{};
    for (final (c, id) in ids) {
      final rows = _db.select('SELECT hlc FROM sync_record WHERE c = ? AND id = ?;', [c, id]);
      if (rows.isNotEmpty) out[(c, id)] = rows.first['hlc'] as String;
    }
    return out;
  }

  /// Every record and its stamp, the oldest first: what a snapshot holds.
  static List<({String c, String id, String hlc})> all() => [
    for (final row in _db.select('SELECT c, id, hlc FROM sync_record ORDER BY hlc;'))
      (c: row['c'] as String, id: row['id'] as String, hlc: row['hlc'] as String),
  ];

  /// Records made here and stamped after [after] (empty: all of them), the
  /// oldest first: what the next sync sends.
  static List<({String c, String id, String hlc})> pending(String after) {
    final mine = deviceHexOf(device);
    return [
      for (final row in _db.select(
        'SELECT c, id, hlc FROM sync_record WHERE hlc > ? AND substr(hlc, 17) = ? ORDER BY hlc;',
        [after, mine],
      ))
        (c: row['c'] as String, id: row['id'] as String, hlc: row['hlc'] as String),
    ];
  }

  /// Fills `sync_record` from what the snapshot sync stamped: each root's
  /// rows and tombstones, and each synced kv store's keys, as [legacy]
  /// stamps. A record already there keeps its stamp.
  static void seed() {
    if (!_ready) return;
    final rows = <(String, String, int)>[];
    for (final table in roots) {
      for (final row in _db.select('SELECT id, updated_at FROM $table;')) {
        rows.add((table, row['id'] as String, row['updated_at'] as int));
      }
      for (final row in _db.select('SELECT row_id, deleted_at FROM tombstone WHERE tbl = ?;', [table])) {
        rows.add((table, row['row_id'] as String, row['deleted_at'] as int));
      }
    }
    for (final store in syncedStores.values) {
      for (final MapEntry(:key, :value) in (store.lastUpdateTs ?? const <String, int>{}).entries) {
        rows.add(('kv:${store.name}', key, value));
      }
    }
    SqliteStore.transact(() {
      for (final (c, id, ms) in rows) {
        _db.execute(
          'INSERT OR IGNORE INTO sync_record (c, id, hlc) VALUES (?, ?, ?);',
          [c, id, syncStampOf(ms: BigInt.from(ms), device: legacy)],
        );
      }
    });
    _last = null;
  }

  /// Stamps each record of [c] whose fingerprint in [now] differs from the
  /// one last seen ([see]), and each seen one gone since: for records kept
  /// outside the stores (files), which no write stamps. [unknown] ones cannot
  /// be told now (a file that should be there is not): left as last seen, so
  /// nothing is sent as gone that may only be missing for a while.
  /// [notify] as [record]'s: true for a change made just now, which the
  /// syncs send without waiting for their next run.
  static void stampChanged(String c, Map<String, String> now, {Set<String> unknown = const {}, bool notify = false}) {
    final prefix = 'seen:$c:';
    final seen = {
      for (final row in _db.select('SELECT k, v FROM sync_state WHERE substr(k, 1, ?) = ?;', [prefix.length, prefix]))
        (row['k'] as String).substring(prefix.length): row['v'] as String,
    };
    // Lost meanwhile ([loseSeen]): one seen then and not here now went with
    // what was lost, and is not sent as removed.
    final lost = _db.select('SELECT 1 FROM sync_state WHERE k = ?;', ['lost:$c']).isNotEmpty;
    for (final id in {...seen.keys, ...now.keys}) {
      if (now[id] == seen[id] || unknown.contains(id)) continue;
      if (lost && !now.containsKey(id)) {
        see(c, id, null);
        continue;
      }
      record(c, id, notify: notify);
      see(c, id, now[id]);
    }
    if (lost) _db.execute('DELETE FROM sync_state WHERE k = ?;', ['lost:$c']);
  }

  /// Runs [stamp] after each change [changes] tells of, once for changes
  /// close together, for records kept outside the stores: changing one
  /// writes no store, which is what wakes the syncs. After the writes that
  /// told of it, so one a sync put here is already recorded as seen.
  static void follow(Listenable changes, void Function() stamp) {
    var pending = false;
    changes.addListener(() {
      if (pending) return;
      pending = true;
      scheduleMicrotask(() {
        pending = false;
        if (SqliteDb.isOpen) stamp();
      });
    });
  }

  /// What [stampChanged] saw of [c] may be lost here now (its list could
  /// not be read): the next one that reads it sends no removal of what is
  /// not there then. What is there unchanged is not sent again either.
  static void loseSeen(String c) => _db.execute(
    'INSERT INTO sync_state (k, v) VALUES (?, ?) ON CONFLICT (k) DO NOTHING;',
    ['lost:$c', '1'],
  );

  /// Notes [c]/[id] as [fingerprint] (null: not here) for [stampChanged]:
  /// what came from another device, which is not sent back.
  static void see(String c, String id, String? fingerprint) {
    if (fingerprint == null) {
      _db.execute('DELETE FROM sync_state WHERE k = ?;', ['seen:$c:$id']);
    } else {
      _db.execute(
        'INSERT INTO sync_state (k, v) VALUES (?, ?) ON CONFLICT (k) DO UPDATE SET v = excluded.v;',
        ['seen:$c:$id', fingerprint],
      );
    }
  }

  /// Empties [store] on this device as though it never held anything: its
  /// stamps and records go too, so no delete is sent and another device's
  /// values are taken again.
  static void forgetStore(SqliteStore store) => SqliteStore.transact(() {
    // Each removed as no edit (nothing sent), told to who watches the store;
    // the stamps go with them, and the other internal keys stay.
    for (final key in store.keys()) {
      store.remove(key, updateLastUpdateTsOnRemove: false);
    }
    _db.execute('DELETE FROM kv WHERE store = ? AND key = ?;', [store.name, store.lastUpdateTsKey]);
    _db.execute('DELETE FROM sync_record WHERE c = ?;', ['kv:${store.name}']);
  });

  /// Records [rows] (each an id and when it was last changed, ms) of [c]
  /// as [legacy] stamps, keeping a record already there: what existed before
  /// [c] synced.
  static void seedRecords(String c, Iterable<(String, int)> rows) {
    if (!_ready) return;
    SqliteStore.transact(() {
      for (final (id, ms) in rows) {
        _db.execute(
          'INSERT OR IGNORE INTO sync_record (c, id, hlc) VALUES (?, ?, ?);',
          [c, id, syncStampOf(ms: BigInt.from(ms), device: legacy)],
        );
      }
    });
    _last = null;
  }

  /// Forgets what was read, for a test's fresh database.
  static void resetForTest() {
    _device = null;
    _last = null;
    onLocal.clear();
  }
}
