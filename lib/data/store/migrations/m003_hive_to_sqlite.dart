import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/migrations/m004_kv_to_tables.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/hive/legacy_adapters.dart';
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
/// be on Hive. Keep the frozen adapters until then — reading what a released
/// build wrote is what [_fromLegacy] needs them for.
abstract final class HiveImport {
  /// Internal, so it stays out of backups and out of `lastUpdateTs`.
  static const _markerKey = '${StoreDefaults.prefixKey}hiveImported';

  /// Which boxes have been copied, for an import finishing across launches.
  ///
  /// Removed once [_markerKey] is written, since it answers nothing after that.
  static const _doneKey = '${StoreDefaults.prefixKey}hiveImportedBoxes';

  /// Box name -> what takes one of its rows.
  ///
  /// Every box lands in `kv` under its own store name, one row per Hive key.
  /// That is the whole of the v4 shape, and it is all this step knows how to
  /// produce: taking a record apart into columns is m004's job, against data
  /// that is already off Hive.
  ///
  /// Straight into `kv` rather than through the store objects, because those
  /// stores have moved on to tables — a migration that calls today's code
  /// changes meaning every time that code does.
  ///
  /// `conn_stats_index` is deliberately absent: it held nothing that is not
  /// derivable from the records, and it is the one box that was never
  /// encrypted — so it is deleted below rather than carried across.
  static Map<String, bool Function(String, Object)> get _boxes => {
    'setting': _intoKv(Stores.setting),
    'history': _intoKv(Stores.history),
    'key': _intoKvTable('key'),
    'server': _intoKvTable('server'),
    'docker': _intoKvTable('docker'),
    'snippet': _intoKvTable('snippet'),
    'port_forward': _intoKvTable('port_forward'),
    'connection_stats': _intoKvTable('conn_stat'),
    'agent_conversation': _intoKvTable('agent_conversation'),
  };

  static const _dependencies = <String, List<String>>{
    'server': ['key'],
    'docker': ['server'],
    'snippet': ['server'],
    'port_forward': ['server'],
    'connection_stats': ['server'],
    'agent_conversation': ['server'],
  };

  /// `updateLastUpdateTsOnSet: false`: the timestamps are copied across with
  /// everything else, and stamping each row as it lands would overwrite them
  /// with "now" and tell the next sync that this device holds the newer copy of
  /// data it has just finished reading off its own disk.
  static bool Function(String, Object) _intoKv(SqliteStore store) =>
      (key, value) => store.set(key, value, updateLastUpdateTsOnSet: false);

  /// Writes a row of the v4 key-value layout directly.
  ///
  /// `updated_at` is 0, not now: m004 carries these timestamps into the entity
  /// tables, and stamping them as today would make the first sync after
  /// upgrading read as "everything changed".
  static bool Function(String, Object) _intoKvTable(String store) =>
      (key, value) {
        try {
          SqliteDb.instance.execute(
            'INSERT OR REPLACE INTO kv (store, key, value, updated_at) '
            'VALUES (?, ?, ?, 0);',
            [store, key, json.encode(value)],
          );
          return true;
        } catch (e) {
          Loggers.app.warning('m003: could not write $store/$key', e);
          return false;
        }
      };

  /// Runs the import if this device has data in Hive and none in SQLite yet.
  ///
  /// Safe to re-run: nothing is deleted from Hive, so a crash part-way through
  /// leaves the marker unwritten and the next launch copies what it had not
  /// got to yet.
  ///
  /// Progress is per box rather than all-or-nothing, because neither end of
  /// that choice is safe. Marking the import done when only some boxes opened
  /// drops the rest for good — the marker is the first thing checked, so no
  /// later launch retries them. Leaving the marker unwritten instead re-copies
  /// the boxes that *did* open, and the app is usable in the meantime, so that
  /// overwrites whatever the user changed between the two launches. Recording
  /// which boxes landed avoids both: a box is copied once, and one that could
  /// not be read is retried until it can.
  static Future<void> runIfNeeded() async {
    if (Stores.setting.get<bool>(_markerKey) == true) return;
    final schemaAtStart = SchemaVersion.stored;

    // The same directory `HiveStore.init` opens from, asked of it rather than
    // recomputed: the macOS sandbox and the mobile platforms each answer this
    // differently, and looking in the wrong one reads as "fresh install".
    final dir = await HiveStore.boxDir;
    // Both names. `HiveStore.init` opens `<name>_enc` and *then* folds an
    // existing plain `<name>.hive` into it, so an install old enough to predate
    // box encryption has only the plain files — and looking for `_enc` alone
    // read that device as a fresh install and dropped everything it had.
    // `_importBox` goes through `HiveStore`, so it handles either.
    final present = <String>[];
    for (final name in _boxes.keys) {
      if (await File(dir.joinPath('${name}_enc.hive')).exists() ||
          await File(dir.joinPath('$name.hive')).exists()) {
        present.add(name);
      }
    }
    if (present.isEmpty) {
      // A fresh install. Record the current layout so the migrator does not
      // walk it through steps written for data it never had.
      SchemaVersion.initFresh();
      if (!_dropPlaintextIndex(dir)) return;
      Stores.setting.set(_markerKey, true);
      return;
    }

    final done = _doneBoxes();
    final pending = present.where((name) => !done.contains(name)).toList();
    Loggers.app.info(
      'Importing ${pending.length} Hive boxes into SQLite, '
      '${done.length} already copied',
    );

    var copied = 0;
    var hadWriteFailures = false;
    for (final name in pending) {
      final waitingFor = (_dependencies[name] ?? const <String>[]).where(
        (dependency) =>
            present.contains(dependency) && !done.contains(dependency),
      );
      if (waitingFor.isNotEmpty) {
        Loggers.app.warning(
          'Hive box "$name" waits for ${waitingFor.join(', ')}',
        );
        continue;
      }
      final result = await _importBox(name, _boxes[name]!);
      copied += result.copied;
      if (result.opened && !result.hadWriteFailures) {
        done.add(name);
      } else if (result.hadWriteFailures) {
        hadWriteFailures = true;
      }
    }

    final unread = present.where((name) => !done.contains(name)).toList();
    if (unread.isNotEmpty) {
      // A box fails to open when the keychain is briefly unavailable — the
      // device still locked at launch, on iOS — and an install old enough to
      // predate box encryption has some boxes that need it and some that do
      // not, so this is reached with part of the data across and part not.
      _setDoneBoxes(done);
      Loggers.app.warning(
        'Imported $copied rows from Hive; $unread unread, '
        'left to the next launch',
      );
      // Remove the plaintext index when possible even while some encrypted
      // boxes remain unread: it holds no data that is not derivable from the
      // records and must not stay plaintext beside the encrypted database.
      _dropPlaintextIndex(dir);
      // Even when nothing succeeded we must advance the schema version away
      // from the default 2, otherwise the subsequent SchemaVersion.migrate
      // from 2 has no v2->v3/v3->v4 steps (HiveImport is supposed to establish
      // v4) and the app crashes on every launch. Any future successful import
      // of the still-unread boxes will land rows in kv at v4 shape; those
      // rows will be picked up by the next m004 run via a re-entrant check.
      await _prepareSchemaAfterImport(schemaAtStart, copied);
      return;
    }
    if (hadWriteFailures) {
      _setDoneBoxes(done);
      Loggers.app.warning(
        'Imported $copied rows from Hive; some rows failed to persist, '
        'will retry failed boxes',
      );
      _dropPlaintextIndex(dir);
      await _prepareSchemaAfterImport(schemaAtStart, copied);
      return;
    }

    Loggers.app.info('Imported $copied rows from Hive, every box read');
    if (!_dropPlaintextIndex(dir)) {
      _setDoneBoxes(done);
      return;
    }

    // The copy nests a pre-v3 server record on the way across, which is what
    // the v2 -> v3 step used to do in place. What has landed is the layout of
    // the build that dropped Hive, not the current one — the steps after this
    // still have to run over it.
    // Persist this before schema migration: if that succeeds and the process
    // dies before the final marker, the next launch must not copy every box a
    // second time into an already-current database.
    _setDoneBoxes(done);
    await _prepareSchemaAfterImport(schemaAtStart, copied);
    Stores.setting.set(_markerKey, true);
    Stores.setting.remove(_doneKey);
  }

  static Future<void> _prepareSchemaAfterImport(
    int schemaAtStart,
    int copied,
  ) async {
    if (schemaAtStart <= SchemaVersion.hiveImportProduces) {
      SchemaVersion.initAtHiveImport();
      return;
    }
    if (copied > 0) {
      // A box that became readable after the normal migration chain completed
      // lands in the old v4 kv shape. Convert only those late rows without
      // moving an already-current database back to v4 and replaying m005+.
      await const KvToTablesMigration().apply();
    }
  }

  static Set<String> _doneBoxes() {
    final raw = Stores.setting.get<List>(_doneKey);
    if (raw == null) return <String>{};
    return raw.whereType<String>().toSet();
  }

  static void _setDoneBoxes(Set<String> names) =>
      Stores.setting.set(_doneKey, names.toList());

  static Future<({bool opened, int copied, bool hadWriteFailures})> _importBox(
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
      return (opened: false, copied: 0, hadWriteFailures: false);
    }

    var copied = 0;
    var hadWriteFailures = false;
    try {
      // One transaction per box. A connection-stats box can hold thousands of
      // rows, and a commit each would be thousands of durability barriers. A
      // destination failure rolls the whole box back: m004 can consume and
      // delete successful kv rows later in this launch, so retrying a box that
      // partly committed would reinsert those rows on the next launch.
      try {
        copied = SqliteStore.transact(() {
          var boxCopied = 0;
          for (final key in legacy.box.keys) {
            if (key is! String) continue;
            // Permanent legacy corruption costs that record, not every later
            // launch. A destination write failure is different and rolls the
            // box back for a clean retry.
            try {
              final raw = legacy.box.get(key);
              if (raw == null) continue;

              final value = _fromLegacy(raw) ?? raw;
              final safe = _jsonSafe(value as Object);
              json.encode(safe);
              final ok = into(key, safe);
              if (!ok) {
                Loggers.app.warning(
                  'Could not import "$name/$key" (${value.runtimeType})',
                );
                throw const _BoxWriteFailure();
              }
              boxCopied++;
            } on _BoxWriteFailure {
              rethrow;
            } catch (e, s) {
              Loggers.app.warning(
                'Skipping unreadable record "$name/$key"',
                e,
                s,
              );
            }
          }
          return boxCopied;
        });
      } on _BoxWriteFailure {
        copied = 0;
        hadWriteFailures = true;
      }
    } finally {
      await legacy.box.close();
    }
    return (opened: true, copied: copied, hadWriteFailures: hadWriteFailures);
  }

  /// A record that a released build wrote, as the JSON that build produced.
  ///
  /// Returns null for anything else, including a record whose adapter is still
  /// generated from the live model — those encode themselves.
  static Object? _fromLegacy(Object raw) => switch (raw) {
    final LegacySpiV2 spi => spi.toSpi(),
    final LegacySpiV3 spi => spi.toSpi(),
    final LegacyMonitorHttpCredentialV1 monitor => monitor.toJson(),
    final LegacyPrivateKeyV1 key => key.toJson(),
    final LegacySnippetV1 snippet => snippet.toJson(),
    _ => null,
  };

  /// The value as something made of maps, lists and primitives.
  ///
  /// A Hive box hands back whatever its adapter decoded — a `ConnectionStat`,
  /// not a map — and every destination here is a JSON column, so the value has
  /// to be reduced to maps, lists and primitives before it can be encoded.
  static Object _jsonSafe(Object value) {
    if (value is Map || value is List || value is Enum) return value;
    if (value is num || value is String || value is bool) return value;
    try {
      final json = (value as dynamic).toJson();
      if (json is Object) return json;
    } catch (e) {
      // Usually just "no `toJson`", but not always — a model whose `toJson`
      // throws looks the same from here, and the destination's own warning
      // only names the type.
      Loggers.app.warning('No JSON form for ${value.runtimeType}', e);
    }
    return value;
  }

  /// Removes the one box that was never encrypted.
  ///
  /// The other files are kept so a bad import can be rolled back to, but this
  /// one holds no data that is not derivable from the records, and leaving it
  /// would leave `<serverId>_<millis>` for every connection sitting in
  /// plaintext beside a database that exists to not do that.
  static bool _dropPlaintextIndex(String dir) {
    var removed = true;
    for (final suffix in const ['.hive', '.lock']) {
      final file = File(dir.joinPath('conn_stats_index$suffix'));
      try {
        if (file.existsSync()) file.deleteSync();
      } catch (e, s) {
        removed = false;
        Loggers.app.warning('Could not delete ${file.path}', e, s);
      }
    }
    return removed;
  }
}

class _BoxWriteFailure implements Exception {
  const _BoxWriteFailure();
}
