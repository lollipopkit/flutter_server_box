import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:server_box/core/utils/local_file_backend.dart';
import 'package:server_box/core/utils/ssh_key_unlock.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';
import 'package:server_box/data/model/server/bmc_credential.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/provider/bmc_credential.dart';
import 'package:server_box/data/provider/container.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/migrations/m008_settings_fixups.dart';
import 'package:server_box/data/store/migrations/m009_grouped_settings.dart';
import 'package:server_box/data/store/migrations/m011_virt_key_rows.dart';
import 'package:server_box/data/store/migrations/m013_virt_key_names.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';

part 'backup2.freezed.dart';
part 'backup2.g.dart';

final _loggerV2 = Logger('BackupV2');

@freezed
abstract class BackupV2 with _$BackupV2 implements Mergeable {
  const BackupV2._();

  /// Construct a backup with the latest format (v2).
  ///
  /// All `Map<String, dynamic>` are:
  /// ```json
  /// {
  ///   "key1": Model{},
  ///   "_lastModTime": {
  ///     "key1": 1234567890,
  ///   },
  /// }
  /// ```
  const factory BackupV2({
    required int version,
    required int date,
    required Map<String, Object?> spis,
    required Map<String, Object?> snippets,
    required Map<String, Object?> keys,
    required Map<String, Object?> container,
    required Map<String, Object?> history,
    required Map<String, Object?> settings,

    /// Absent from every file written before port forwards became a record of
    /// their own, so it defaults rather than being required — an older backup
    /// has to keep decoding.
    @Default(<String, Object?>{}) Map<String, Object?> portForwards,

    /// Same reason as [portForwards]: no file written before BMC support has
    /// one. A server whose `bmc.credId` names an account this map does not
    /// carry restores with the address and no account, which the editor shows.
    @Default(<String, Object?>{}) Map<String, Object?> bmcCredentials,
  }) = _BackupV2;

  /// Must stay a single expression with a cascade, not a block body.
  /// `Freezed.needsJsonSerializable` only enables JSON generation when the
  /// `fromJson` factory's body `is ExpressionFunctionBody`; with a block body
  /// it silently emits no `@JsonSerializable()`, json_serializable then writes
  /// no `backup2.g.dart`, and `toJson`/`_$BackupV2FromJson` stop existing. The
  /// checked-in generated files predate that check, so the breakage only shows
  /// up the next time codegen runs from scratch.
  factory BackupV2.fromJson(Map<String, dynamic> json) =>
      _$BackupV2FromJson(json).._validateRestorableTypedStores();

  @override
  Future<void> merge({bool force = false}) async {
    _validateRestorableTypedStores();
    _loggerV2.info('Merging...');

    late bool keysChanged;
    late bool credsChanged;
    late bool serversChanged;
    late bool snippetsChanged;
    late bool forwardsChanged;
    late bool containerChanged;
    late Set<String> historyNotifications;
    late Set<String> settingNotifications;

    // Every store shares this SQLite connection. Keep the reference order, but
    // commit the whole restore as one unit so a later failure cannot leave the
    // earlier stores visible without it.
    final restored = _restoredServerGraph();
    SqliteStore.transact(() {
      keysChanged = Stores.key.merge(keys, force: force, notify: false);
      credsChanged = Stores.bmcCredential.merge(
        bmcCredentials,
        force: force,
        notify: false,
      );
      serversChanged = Stores.server.merge(
        restored.servers,
        force: force,
        notify: false,
      );
      snippetsChanged = Stores.snippet.merge(
        _snippetsWithRestoredServerIds(restored.serverIds),
        force: force,
        notify: false,
      );
      forwardsChanged = Stores.portForward.merge(
        _portForwardsWithRestoredServerIds(restored.serverIds),
        force: force,
        notify: false,
      );

      final restoredContainer = _containerWithRestoredServerIds(
        restored.serverIds,
      );
      containerChanged = false;
      final containerIds = <String>{
        for (final key in restored.servers.keys)
          if (!_isInternalStoreKey(key)) key,
        for (final key in restoredContainer.keys)
          if (!_isInternalStoreKey(key)) key,
      };
      for (final serverId in containerIds) {
        if (Stores.container.restoreOne(
          serverId,
          restoredContainer[serverId] ?? const <String, Object?>{},
          notify: false,
        )) {
          containerChanged = true;
          serversChanged = true;
        }
      }

      historyNotifications = _mergeSqliteStore(
        Stores.history,
        _mergeDataForStore(
          Stores.history,
          _historyWithRestoredServerIds(restored.serverIds),
        ),
        force: force,
      );
      settingNotifications = settings.isEmpty
          ? const <String>{}
          : _mergeSqliteStore(
              Stores.setting,
              _mergeDataForStore(
                Stores.setting,
                settings,
                deviceLocal: SettingStore.deviceLocalKeys,
              ),
              force: force,
            );
      // Restoring does not run the schema migrator. Convert legacy setting
      // shapes in version order before this transaction can commit, so a
      // failed conversion rolls the entire restore back with it.
      if (settings.isNotEmpty) {
        const SettingsFixupsMigration().applySync();
        const GroupedSettingsMigration().applySync();
        const VirtKeyRowsMigration().applySync();
        const VirtKeyNamesMigration().applySync();
      }
    });

    // Notifications and provider reloads happen only after the outer
    // transaction commits. A failed restore therefore has no observable half.
    if (keysChanged) {
      Stores.key.invalidate();
      PrivateKeyUnlock.forgetAll();
    }
    if (credsChanged) Stores.bmcCredential.invalidate();
    if (serversChanged) {
      Stores.server.invalidate();
      // A server tombstone cascades these rows even when their own merge pass
      // has no later write to announce.
      Stores.portForward.invalidate();
      Stores.snippet.invalidate();
    }
    if (snippetsChanged && !serversChanged) Stores.snippet.invalidate();
    if (forwardsChanged && !serversChanged) Stores.portForward.invalidate();
    _notifySqliteStore(Stores.history, historyNotifications);
    _notifySqliteStore(Stores.setting, settingNotifications);

    if (serversChanged) GlobalRef.gRef?.read(serversProvider.notifier).reload();
    if (snippetsChanged) {
      GlobalRef.gRef?.read(snippetProvider.notifier).reload();
    }
    if (keysChanged) GlobalRef.gRef?.read(privateKeyProvider.notifier).reload();
    if (credsChanged) {
      GlobalRef.gRef?.read(bmcCredentialProvider.notifier).reload();
    }
    if (containerChanged) GlobalRef.gRef?.invalidate(containerProvider);

    _loggerV2.info('Merge completed');
  }

  /// Envelope version. Bumped to 3 with the nested `Spi.ssh` layout, so a
  /// reader can tell whether it understands the file before decoding it.
  ///
  /// Kept in step with [SchemaVersion.current]: the stores a backup carries
  /// are exactly the stores the schema describes, and two independent numbers
  /// would drift.
  static const formatVer = SchemaVersion.current;

  static Future<BackupV2> loadFromStore({bool includeSettings = true}) async {
    return BackupV2(
      version: formatVer,
      date: DateTimeX.timestamp,
      spis: Stores.server.getAllMap(),
      snippets: Stores.snippet.getAllMap(),
      keys: Stores.key.getAllMap(),
      bmcCredentials: Stores.bmcCredential.getAllMap(),
      portForwards: Stores.portForward.getAllMap(),
      container: Stores.container.getAllMap(),
      history: _backupStore(Stores.history),
      settings: includeSettings
          ? _backupStore(
              Stores.setting,
              deviceLocal: SettingStore.deviceLocalKeys,
            )
          : const {},
    );
  }

  static Future<String> backup([
    String? name,
    String? password,
    bool includeSettings = true,
  ]) async {
    final bak = await BackupV2.loadFromStore(includeSettings: includeSettings);
    var result = bak.toJsonString();

    if (password != null && password.isNotEmpty) {
      result = Cryptor.encrypt(result, password);
    }

    final path = Paths.doc.joinPath(name ?? Miscs.bakFileName);
    final bytes = utf8.encode(result);
    await const LocalFileBackend().write(
      path,
      Stream.value(bytes),
      size: bytes.length,
    );
    return path;
  }

  factory BackupV2.fromJsonString(String jsonString, [String? password]) {
    if (Cryptor.isEncrypted(jsonString)) {
      if (password == null || password.isEmpty) {
        throw Exception('Backup is encrypted but no password provided');
      }
      jsonString = Cryptor.decrypt(jsonString, password);
    }

    final map = json.decode(jsonString) as Map<String, dynamic>;

    // Checked before decoding. `version` was written from the beginning but
    // never read, so a newer file was decoded by whatever reader happened to
    // accept its shape — silently dropping the fields it didn't know.
    // `is num`, not `is int`: JSON has one number type, so a writer emitting
    // `13.0` reaches here as a `double` and skipped the check entirely, while
    // the generated decoder below reads it with `toInt()` and carries on as
    // though it were this format.
    final ver = map['version'];
    if (ver is num && ver > formatVer) {
      throw SchemaTooNewException(stored: ver.ceil(), supported: formatVer);
    }

    return BackupV2.fromJson(map);
  }

  String toJsonString() => json.encode(_toJsonValue(toJson()));

  void _validateRestorableTypedStores() {
    _validateRestorableStore('spis', spis);
    _validateRestorableStore('snippets', snippets);
    _validateRestorableStore('keys', keys);
    _validateRestorableStore('portForwards', portForwards);
    _validateRestorableStore('bmcCredentials', bmcCredentials);
  }

  /// A pre-table backup identifies a private key by its name. When that name
  /// already exists locally, [PrivateKeyStore.reconcile] correctly keeps the
  /// local generated id; the server's old reference must follow it before the
  /// foreign key can accept the server row.
  ///
  /// [BmcCredentialStore.reconcile] does the same thing for the same reason,
  /// so `bmc.credId` needs the same treatment — restoring one backup twice
  /// would otherwise leave every server pointing at an account id that the
  /// second restore did not create.
  ({Map<String, Object?> servers, Map<String, String> serverIds})
  _restoredServerGraph() {
    final keyIds = _restoredIds(
      keys,
      PrivateKeyInfo.fromJson,
      (key) => key.id,
      (key) => Stores.key.fetchByName(key.name)?.id,
    );
    final credIds = _restoredIds(
      bmcCredentials,
      BmcCredential.fromJson,
      (cred) => cred.id,
      (cred) => Stores.bmcCredential.fetchByName(cred.name)?.id,
    );
    final localByName = {
      for (final server in Stores.server.fetch()) server.name: server.id,
    };
    final serverIds = <String, String>{};
    final decoded = <String, Map<String, Object?>>{};
    final sourceOwners = <String, String>{};
    final destinationOwners = <String, String>{};

    void claimSourceId(String id, String sourceKey) {
      final owner = sourceOwners[id];
      if (owner != null && owner != sourceKey) {
        throw FormatException(
          'Backup server id $id is shared by $owner and $sourceKey',
        );
      }
      sourceOwners[id] = sourceKey;
    }

    for (final entry in spis.entries) {
      if (_isInternalStoreKey(entry.key) || entry.value is! Map) continue;
      final server = Map<String, Object?>.from(entry.value as Map);
      final embedded = server['id'];
      final backupId = embedded is String && embedded.isNotEmpty
          ? embedded
          : entry.key;
      final name = server['name'];
      final restoredId = name is String
          ? localByName[name] ?? backupId
          : backupId;
      claimSourceId(entry.key, entry.key);
      claimSourceId(backupId, entry.key);
      final destinationOwner = destinationOwners[restoredId];
      if (destinationOwner != null && destinationOwner != entry.key) {
        throw FormatException(
          'Backup servers $destinationOwner and ${entry.key} restore to the same id $restoredId',
        );
      }
      destinationOwners[restoredId] = entry.key;
      serverIds[entry.key] = restoredId;
      serverIds[backupId] = restoredId;
      server['id'] = restoredId;
      decoded[restoredId] = server;
    }

    final servers = <String, Object?>{
      for (final entry in spis.entries)
        if (_isInternalStoreKey(entry.key)) entry.key: entry.value,
      for (final entry in decoded.entries)
        entry.key: _serverWithRestoredIds(
          entry.value,
          keyIds,
          credIds,
          serverIds,
        ),
    };
    final timestamps = spis[StoreDefaults.defaultLastUpdateTsKey];
    if (timestamps is Map) {
      servers[StoreDefaults.defaultLastUpdateTsKey] = {
        for (final entry in timestamps.entries)
          serverIds['${entry.key}'] ?? '${entry.key}': entry.value,
      };
    }
    return (servers: servers, serverIds: serverIds);
  }

  /// Backup id -> local id, for the records of [store] whose name already
  /// exists here.
  ///
  /// A record that will not decode is skipped rather than failing the restore:
  /// `merge` skips it too, so leaving its server reference untouched is what
  /// makes the foreign key reject exactly the matching malformed record.
  /// [decode] runs once per record; [idOf] and [localIdOf] are handed the
  /// result. Passing them the raw map instead made each of them decode it
  /// again, which is two decodes per record for one lookup.
  Map<String, String> _restoredIds<T>(
    Map<String, Object?> store,
    T Function(Map<String, dynamic>) decode,
    String Function(T) idOf,
    String? Function(T) localIdOf,
  ) {
    final out = <String, String>{};
    for (final entry in store.entries) {
      if (_isInternalStoreKey(entry.key) || entry.value is! Map) continue;
      try {
        final json = Map<String, dynamic>.from(entry.value as Map);
        json['id'] ??= entry.key;
        final record = decode(json);
        final restored = localIdOf(record);
        if (restored != null) {
          out[entry.key] = restored;
          out[idOf(record)] = restored;
        }
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  Map<String, Object?> _snippetsWithRestoredServerIds(
    Map<String, String> serverIds,
  ) => {
    for (final entry in snippets.entries)
      entry.key: _snippetWithRestoredServerIds(entry.value, serverIds),
  };

  Map<String, Object?> _portForwardsWithRestoredServerIds(
    Map<String, String> serverIds,
  ) => {
    for (final entry in portForwards.entries)
      entry.key: _recordWithRestoredServerId(entry.value, serverIds),
  };

  Map<String, Object?> _containerWithRestoredServerIds(
    Map<String, String> serverIds,
  ) => {
    for (final entry in container.entries)
      serverIds[entry.key] ?? entry.key: entry.value,
  };

  Map<String, Object?> _historyWithRestoredServerIds(
    Map<String, String> serverIds,
  ) {
    final restored = Map<String, Object?>.from(history);
    final serverHistory = restored['sshServerHistory'];
    if (serverHistory is List) {
      restored['sshServerHistory'] = [
        for (final id in serverHistory) id is String ? serverIds[id] ?? id : id,
      ];
    }
    final lastPaths = restored['sftpLastPath'];
    if (lastPaths is Map) {
      restored['sftpLastPath'] = {
        for (final entry in lastPaths.entries)
          serverIds['${entry.key}'] ?? '${entry.key}': entry.value,
      };
    }
    for (final key in const ['sshTabs', 'fileTabs']) {
      final value = restored[key];
      if (value is! String || value.isEmpty) continue;
      try {
        restored[key] = json.encode(
          _jsonWithRestoredServerIds(json.decode(value), serverIds),
        );
      } catch (_) {}
    }
    return restored;
  }
}

Object? _serverWithRestoredIds(
  Object? value,
  Map<String, String> keyIds,
  Map<String, String> credIds,
  Map<String, String> serverIds,
) {
  if (value is! Map) return value;
  final server = Map<String, Object?>.from(value);
  final ssh = server['ssh'];
  if (ssh is Map) {
    server['ssh'] = _sshWithRestoredIds(ssh, keyIds, serverIds);
  } else {
    for (final key in const ['pubKeyId', 'keyId']) {
      final id = server[key];
      if (id is String && keyIds.containsKey(id)) server[key] = keyIds[id];
    }
  }
  final bmc = server['bmc'];
  if (bmc is Map) {
    final restored = Map<String, Object?>.from(bmc);
    final id = restored['credId'];
    if (id is String && credIds.containsKey(id)) {
      restored['credId'] = credIds[id];
    }
    server['bmc'] = restored;
  }
  return server;
}

Map<String, Object?> _sshWithRestoredKeyId(
  Map value,
  Map<String, String> keyIds,
) {
  final ssh = Map<String, Object?>.from(value);
  for (final key in const ['pubKeyId', 'keyId']) {
    final id = ssh[key];
    if (id is String && keyIds.containsKey(id)) ssh[key] = keyIds[id];
  }
  return ssh;
}

Map<String, Object?> _sshWithRestoredIds(
  Map value,
  Map<String, String> keyIds,
  Map<String, String> serverIds,
) {
  final ssh = _sshWithRestoredKeyId(value, keyIds);
  final jumpId = ssh['jumpId'];
  if (jumpId is String) ssh['jumpId'] = serverIds[jumpId] ?? jumpId;
  final jumpIds = ssh['jumpIds'];
  if (jumpIds is List) {
    ssh['jumpIds'] = [
      for (final id in jumpIds) id is String ? serverIds[id] ?? id : id,
    ];
  }
  return ssh;
}

Object? _snippetWithRestoredServerIds(
  Object? value,
  Map<String, String> serverIds,
) {
  if (value is! Map) return value;
  final snippet = Map<String, Object?>.from(value);
  final targets = snippet['autoRunOn'];
  if (targets is List) {
    snippet['autoRunOn'] = [
      for (final id in targets) id is String ? serverIds[id] ?? id : id,
    ];
  }
  return snippet;
}

Object? _recordWithRestoredServerId(
  Object? value,
  Map<String, String> serverIds,
) {
  if (value is! Map) return value;
  final record = Map<String, Object?>.from(value);
  final id = record['serverId'];
  if (id is String) record['serverId'] = serverIds[id] ?? id;
  return record;
}

Object? _jsonWithRestoredServerIds(
  Object? value,
  Map<String, String> serverIds,
) {
  if (value is List) {
    return [
      for (final item in value) _jsonWithRestoredServerIds(item, serverIds),
    ];
  }
  if (value is! Map) return value;
  return {
    for (final entry in value.entries)
      '${entry.key}': switch ('${entry.key}') {
        'sourceId' || 'serverId' when entry.value is String =>
          serverIds[entry.value] ?? entry.value,
        _ => _jsonWithRestoredServerIds(entry.value, serverIds),
      },
  };
}

/// Keeps the per-record modification map needed by sync, but not device-local
/// layout and migration markers. Restoring those markers from another device
/// can make this device skip a migration or claim a schema it does not have.
///
/// [deviceLocal] is the same idea for keys with ordinary names — see
/// [SettingStore.deviceLocalKeys], where a permission granted on one machine
/// must not be granted on another by restoring a file.
Map<String, Object?> _backupStore(
  SqliteStore store, {
  Set<String> deviceLocal = const {},
}) {
  final rows = store.getAllMap(includeInternalKeys: true);
  rows.removeWhere((key, _) => _isLocalOnly(store, key, deviceLocal));
  return rows;
}

Map<String, Object?> _mergeDataForStore(
  SqliteStore store,
  Map<String, Object?> rows, {
  Set<String> deviceLocal = const {},
}) {
  final result = Map<String, Object?>.from(rows)
    ..removeWhere((key, _) => _isLocalOnly(store, key, deviceLocal));

  // Mergeable treats an absent key as a deletion. Keep local-only state in
  // the input until fl_lib can expose an internal-key exclusion policy.
  for (final entry
      in store
          .getAllMap(includeInternalKeys: true)
          .entries
          .where((entry) => _isLocalOnly(store, entry.key, deviceLocal))) {
    result[entry.key] = entry.value;
  }
  return result;
}

/// Synchronous equivalent of `Mergeable.mergeStore` for the shared SQLite
/// database. The caller owns the outer transaction and delivers [Set] as
/// notifications only after commit.
Set<String> _mergeSqliteStore(
  SqliteStore store,
  Map<String, Object?> backupData, {
  required bool force,
}) {
  final incomingTimestamps = _kvTimestamps(
    backupData[store.lastUpdateTsKey],
    backupData.keys.where((key) => key != store.lastUpdateTsKey),
  );
  final timestamps = Map<String, int>.from(store.lastUpdateTs ?? const {});
  final current = store.getAllMap(includeInternalKeys: true);
  final currentKeys = current.keys
      .where((key) => key != store.lastUpdateTsKey)
      .toSet();
  final backupKeys = backupData.keys
      .where((key) => key != store.lastUpdateTsKey)
      .toSet();
  final notifications = <String>{};
  var timestampDirty = false;

  for (final key in {...backupKeys, ...currentKeys}) {
    final backupTimestamp = incomingTimestamps[key] ?? 0;
    final currentTimestamp = timestamps[key] ?? 0;
    final backupHasKey = backupKeys.contains(key);
    final currentHasKey = currentKeys.contains(key);

    if (backupHasKey && !currentHasKey) {
      if (!force && backupTimestamp <= currentTimestamp) continue;
      final value = backupData[key];
      if (value == null) continue;
      _writeKv(store, key, value);
      notifications.add(key);
      if (!store.isInternalKey(key)) {
        timestamps[key] = backupTimestamp;
        timestampDirty = true;
      }
      continue;
    }

    if (!backupHasKey && currentHasKey) {
      if (!force && backupTimestamp <= currentTimestamp) continue;
      _deleteKv(store, key);
      notifications.add(key);
      if (!store.isInternalKey(key)) {
        // Preserve the existing merge contract: a deletion keeps the local
        // timestamp entry unless the backup supplied a newer tombstone.
        timestamps[key] = backupTimestamp > currentTimestamp
            ? backupTimestamp
            : currentTimestamp;
        timestampDirty = true;
      }
      continue;
    }

    if (!backupHasKey || !currentHasKey) continue;
    if (!force && backupTimestamp <= currentTimestamp) continue;
    final value = backupData[key];
    if (value == current[key]) continue;
    if (value == null) {
      _deleteKv(store, key);
    } else {
      _writeKv(store, key, value);
    }
    notifications.add(key);
    if (!store.isInternalKey(key)) {
      timestamps[key] = backupTimestamp;
      timestampDirty = true;
    }
  }

  if (force && incomingTimestamps.isNotEmpty) {
    final maxTimestamp = incomingTimestamps.values.reduce(
      (left, right) => left > right ? left : right,
    );
    if (maxTimestamp > 0) {
      for (final key in timestamps.keys) {
        timestamps[key] = maxTimestamp;
      }
      timestampDirty = true;
    }
  }

  if (timestampDirty) {
    // KvStore persists the timestamp map as a JSON string inside the JSON
    // value column; retain that wire shape for existing readers.
    _writeKv(store, store.lastUpdateTsKey, json.encode(timestamps));
    notifications.add(store.lastUpdateTsKey);
  }
  return notifications;
}

Map<String, int> _kvTimestamps(Object? raw, Iterable<String> recordKeys) {
  Object? decoded = raw;
  if (raw is String) {
    try {
      decoded = json.decode(raw);
    } catch (_) {
      decoded = int.tryParse(raw);
    }
  }
  if (decoded is num) {
    final timestamp = decoded.toInt();
    return {for (final key in recordKeys) key: timestamp};
  }
  if (decoded is! Map) return const {};
  return {
    for (final entry in decoded.entries)
      if (entry.key is String && entry.value is num)
        entry.key as String: (entry.value as num).toInt(),
  };
}

void _writeKv(SqliteStore store, String key, Object value) {
  final encoded = json.encode(_toJsonValue(value));
  SqliteDb.instance.execute(
    'INSERT INTO kv (store, key, value, updated_at) VALUES (?, ?, ?, ?) '
    'ON CONFLICT (store, key) DO UPDATE SET '
    'value = excluded.value, updated_at = excluded.updated_at;',
    [store.name, key, encoded, DateTimeX.timestamp],
  );
}

void _deleteKv(SqliteStore store, String key) {
  SqliteDb.instance.execute('DELETE FROM kv WHERE store = ? AND key = ?;', [
    store.name,
    key,
  ]);
}

void _notifySqliteStore(SqliteStore store, Iterable<String> keys) {
  for (final key in keys) {
    final value = store.get<Object>(key);
    final notified = value == null
        ? store.remove(key, updateLastUpdateTsOnRemove: false)
        : store.set(key, value, updateLastUpdateTsOnSet: false);
    if (!notified) {
      _loggerV2.warning('Failed to notify ${store.name}/$key after restore');
    }
  }
}

/// Whether [key] belongs to this device rather than to the backup.
///
/// `lastUpdateTs` is internal and still travels: it is what sync compares.
bool _isLocalOnly(SqliteStore store, String key, Set<String> deviceLocal) =>
    (store.isInternalKey(key) && key != store.lastUpdateTsKey) ||
    deviceLocal.contains(key);

Object? _toEncodable(Object? value) {
  if (value is Enum) return value.name;

  return switch (value) {
    final Spi spi => spi.toJson(),
    final Snippet snippet => snippet.toJson(),
    final PrivateKeyInfo key => key.toJson(),
    final PortForwardConfig forward => forward.toJson(),
    final ServerCustom custom => custom.toJson(),
    final WakeOnLanCfg wolCfg => wolCfg.toJson(),
    // Nested on Spi. All three were missing, so backing up a server that used
    // any of them threw instead of producing a file. `_$SpiToJson` emits the
    // object itself for each, so every one of them has to be named here.
    final SshCredential ssh => ssh.toJson(),
    final MonitorHttpCredential monitor => monitor.toJson(),
    final BmcCfg bmc => bmc.toJson(),
    _ => throw UnsupportedError(
      'Cannot JSON-encode ${value.runtimeType}: missing supported toJson()',
    ),
  };
}

Object? _toJsonValue(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is Map) {
    return value.map((key, entryValue) {
      if (key is! String) {
        throw UnsupportedError(
          'Cannot JSON-encode map key ${key.runtimeType}: keys must be String',
        );
      }
      return MapEntry(key, _toJsonValue(entryValue));
    });
  }
  if (value is Iterable) {
    return value.map(_toJsonValue).toList(growable: false);
  }
  return _toJsonValue(_toEncodable(value));
}

void _validateRestorableStore(String storeName, Map<String, Object?> data) {
  for (final entry in data.entries) {
    if (_isInternalStoreKey(entry.key) || entry.value == null) continue;
    if (entry.value is Map) continue;

    throw FormatException(
      'Backup contains corrupted $storeName entry "${entry.key}": '
      'expected JSON object, got ${entry.value.runtimeType}. '
      'Backups created by app versions 1.0.1448-1.0.1450 may be affected '
      'and cannot be fully restored.',
    );
  }
}

bool _isInternalStoreKey(String key) =>
    key.startsWith(StoreDefaults.prefixKey) ||
    key.startsWith(StoreDefaults.prefixKeyOld);
