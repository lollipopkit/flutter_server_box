import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/hive/spi_legacy_adapter.dart';

/// Copies every Hive box into the SQLite stores, once per device.
///
/// Not a [SchemaMigration]: those run against one storage engine and are keyed
/// on a version number that itself lives in a store. This has to happen before
/// that number can be read at all, because on the launch that upgrades an
/// install the SQLite side is empty and would report a fresh install's default.
///
/// TODO: delete this, `lib/hive/`, the `hive_ce*` dependencies and the
/// `Hive.initFlutter()` call in `main.dart` once no supported install can still
/// be on Hive. Keep [SpiLegacyAdapter] until then — reading a pre-v3 record is
/// what [_toSpi] needs it for.
abstract final class HiveImport {
  /// Internal, so it stays out of backups and out of `lastUpdateTs`.
  static const _markerKey = '${StoreDefaults.prefixKey}hiveImported';

  /// Box name -> what takes one of its rows.
  ///
  /// Most go to a K-V store under the same key. The last two own tables now, so
  /// they take the row apart themselves.
  ///
  /// `conn_stats_index` is deliberately absent: it held nothing that is not
  /// derivable from the records, and it is the one box that was never
  /// encrypted — so it is deleted below rather than carried across.
  static Map<String, bool Function(String, Object)> get _boxes => {
    'setting': _intoKv(Stores.setting),
    'server': _intoKv(Stores.server),
    'docker': _intoKv(Stores.container),
    'key': _intoKv(Stores.key),
    'snippet': _intoKv(Stores.snippet),
    'history': _intoKv(Stores.history),
    'port_forward': _intoKv(Stores.portForward),
    'connection_stats': Stores.connectionStats.importRow,
    'agent_conversation': Stores.agentConversation.importRow,
  };

  /// `updateLastUpdateTsOnSet: false`: the timestamps are copied across with
  /// everything else, and stamping each row as it lands would overwrite them
  /// with "now" and tell the next sync that this device holds the newer copy of
  /// data it has just finished reading off its own disk.
  static bool Function(String, Object) _intoKv(SqliteStore store) =>
      (key, value) => store.set(key, value, updateLastUpdateTsOnSet: false);

  /// Runs the import if this device has data in Hive and none in SQLite yet.
  ///
  /// Safe to re-run: nothing is deleted from Hive, so a crash part-way through
  /// leaves the marker unwritten and the next launch copies everything again,
  /// overwriting whatever the interrupted attempt had managed to write.
  static Future<void> runIfNeeded() async {
    if (Stores.setting.get<bool>(_markerKey) == true) return;

    // The same directory `HiveStore.init` opens from, asked of it rather than
    // recomputed: the macOS sandbox and the mobile platforms each answer this
    // differently, and looking in the wrong one reads as "fresh install".
    final dir = await HiveStore.boxDir;
    final present = _boxes.keys
        .where((name) => File(dir.joinPath('${name}_enc.hive')).existsSync())
        .toList();
    if (present.isEmpty) {
      // A fresh install. Record the current layout so the migrator does not
      // walk it through steps written for data it never had.
      SchemaVersion.initFresh();
      Stores.setting.set(_markerKey, true);
      return;
    }

    Loggers.app.info('Importing ${present.length} Hive boxes into SQLite');
    var copied = 0;
    for (final name in present) {
      copied += await _importBox(name, _boxes[name]!);
    }
    Loggers.app.info('Imported $copied rows from Hive');

    _dropPlaintextIndex(dir);

    // The copy nests a pre-v3 server record on the way across, which is what
    // the v2 -> v3 step used to do in place, so what has landed is current by
    // construction.
    SchemaVersion.initFresh();
    Stores.setting.set(_markerKey, true);
  }

  static Future<int> _importBox(
    String name,
    bool Function(String, Object) into,
  ) async {
    final legacy = HiveStore(name);
    try {
      await legacy.init();
    } catch (e, s) {
      // One box that will not open must not stop the others: the alternative is
      // an install that keeps all of its data and can reach none of it.
      Loggers.app.warning('Hive box "$name" did not open; skipped', e, s);
      return 0;
    }

    var copied = 0;
    for (final key in legacy.box.keys) {
      if (key is! String) continue;
      final raw = legacy.box.get(key);
      if (raw == null) continue;

      final value = _toSpi(raw) ?? raw;
      final ok = into(key, _jsonSafe(value as Object));
      if (ok) {
        copied++;
      } else {
        Loggers.app.warning(
          'Could not import "$name/$key" (${value.runtimeType})',
        );
      }
    }

    await legacy.box.close();
    return copied;
  }

  /// A pre-v3 server record, nested into the current shape.
  ///
  /// Returns null for anything else, including a record already in the current
  /// shape — those encode themselves.
  static Object? _toSpi(Object raw) =>
      raw is LegacySpiV2 ? raw.toSpi() : null;

  /// The value as something made of maps, lists and primitives.
  ///
  /// A Hive box hands back whatever its adapter decoded — a `ConnectionStat`,
  /// not a map. The K-V stores would encode that on write, but the two
  /// table-backed stores parse what they are given with `fromJson`, so both
  /// kinds of destination are handed the same shape.
  static Object _jsonSafe(Object value) {
    if (value is Map || value is List || value is Enum) return value;
    if (value is num || value is String || value is bool) return value;
    try {
      final json = (value as dynamic).toJson();
      if (json is Object) return json;
    } catch (_) {
      // No `toJson`. Leave it be: the destination reports what it could not
      // take, naming the type.
    }
    return value;
  }

  /// Removes the one box that was never encrypted.
  ///
  /// The other files are kept so a bad import can be rolled back to, but this
  /// one holds no data that is not derivable from the records, and leaving it
  /// would leave `<serverId>_<millis>` for every connection sitting in
  /// plaintext beside a database that exists to not do that.
  static void _dropPlaintextIndex(String dir) {
    for (final suffix in const ['.hive', '.lock']) {
      final file = File(dir.joinPath('conn_stats_index$suffix'));
      try {
        if (file.existsSync()) file.deleteSync();
      } catch (e, s) {
        Loggers.app.warning('Could not delete ${file.path}', e, s);
      }
    }
  }
}
