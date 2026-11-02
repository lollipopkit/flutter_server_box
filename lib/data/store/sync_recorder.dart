import 'dart:math';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:sqlite3/sqlite3.dart';

/// Records every change a sync carries as its record's newest stamp in
/// `sync_record` (`fl_sync`'s hybrid logical clock; `docs/dev/sync-log.md`).
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
  /// The kv stores that sync. Every other one stays on the device: `history`
  /// (what was typed and visited here), and fl_pi_llm's chats and providers.
  static const syncedStores = {'setting'};

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
  static BigInt? _device;
  static String? _last;

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
      if (!syncedStores.contains(store.name)) return;
      record('kv:${store.name}', key);
    };
  }

  /// [c]/[id] changed: here at the clock's next stamp, or, while [applying],
  /// at [at] (milliseconds) as no device's change.
  static void record(String c, String id, {int? at}) {
    if (!_ready) return;
    final String h;
    if (_applying > 0) {
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
      'ON CONFLICT (c, id) DO UPDATE SET hlc = excluded.hlc;',
      [c, id, h],
    );
  }

  /// Records made here and stamped after [after] (empty: all of them), the
  /// oldest first: what the next sync sends.
  static List<({String c, String id, String hlc})> pending(String after) {
    final mine = device.toRadixString(16).padLeft(16, '0');
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
    for (final store in [SettingStore.instance]) {
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

  /// Forgets what was read, for a test's fresh database.
  static void resetForTest() {
    _device = null;
    _last = null;
  }
}
