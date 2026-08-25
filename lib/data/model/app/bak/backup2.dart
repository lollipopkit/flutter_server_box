import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
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

    // Ordered by what references what: a server names a private key and a BMC
    // account, a snippet and a port forward name a server, and a container host
    // is a child of one. Merging a store before the one it points at would drop
    // every record whose foreign key has not arrived yet.
    final keysChanged = Stores.key.merge(keys, force: force);
    // A key whose bytes arrived from the other side is not the key that was
    // opened here. Left in the cache, the next connection would authenticate
    // with the one this merge replaced and say nothing about it.
    if (keysChanged) PrivateKeyUnlock.forgetAll();
    final credsChanged = Stores.bmcCredential.merge(bmcCredentials, force: force);
    final serversChanged = Stores.server.merge(
      _serversWithRestoredIds(),
      force: force,
    );
    final snippetsChanged = Stores.snippet.merge(snippets, force: force);
    Stores.portForward.merge(portForwards, force: force);
    for (final entry in container.entries) {
      if (entry.key.startsWith(StoreDefaults.prefixKey)) continue;
      Stores.container.restoreOne(entry.key, entry.value);
    }

    await Future.wait([
      Mergeable.mergeStore(
        backupData: _mergeDataForStore(Stores.history, history),
        store: Stores.history,
        force: force,
      ),
      if (settings.isNotEmpty)
        Mergeable.mergeStore(
          backupData: _mergeDataForStore(
            Stores.setting,
            settings,
            deviceLocal: SettingStore.deviceLocalKeys,
          ),
          store: Stores.setting,
          force: force,
        ),
    ]);

    // A restore is neither a launch nor a version bump, so the migrator will
    // not look at what just landed. A file written before the settings were
    // grouped carries the old per-field keys and no grouped row, and
    // `mergeStore` reads an absent key as a deletion — so without this the
    // restore would take `askAi` and `agentShell` out and put fourteen rows
    // nothing reads back in their place. Idempotent: a file that already has
    // the grouped shape leaves it with nothing to fold.
    //
    // Every settings migration that reads a key a backup can carry belongs
    // here for the same reason, not only the newest one. `virtKeyRows` is
    // one other: a file written before it restores `horizonVirtKey` and no
    // `virtKeyRows`, and the next launch's `removeRetiredKeys` — which sees
    // a `schemaVersion` the merge left past that step — deletes the old key
    // without anything having read it. `sshConnectionMode` is the third: a
    // file older than v9 carries it as the `int` it used to be, which
    // `propertyDefault('sshConnectionMode', false)` cannot read at all.
    // `sshVirtKeys` is the fourth: a file older than v14 carries the enum
    // indices, which every reader now sees as nothing at all.
    //
    // Only when the file brought settings. These convert what *arrived*; a
    // backup taken with `includeSettings: false` leaves the local settings
    // alone, and running the steps over them anyway is this device editing
    // itself for no reason — `_migrateHomeTabsAgent` would put Agent back for
    // somebody who had taken it out.
    //
    // In version order, which is the order the migrator would have run them in.
    if (settings.isNotEmpty) {
      await const SettingsFixupsMigration().apply();
      await const GroupedSettingsMigration().apply();
      await const VirtKeyRowsMigration().apply();
      await const VirtKeyNamesMigration().apply();
    }

    if (serversChanged) GlobalRef.gRef?.read(serversProvider.notifier).reload();
    if (snippetsChanged) {
      GlobalRef.gRef?.read(snippetProvider.notifier).reload();
    }
    if (keysChanged) GlobalRef.gRef?.read(privateKeyProvider.notifier).reload();
    if (credsChanged) {
      GlobalRef.gRef?.read(bmcCredentialProvider.notifier).reload();
    }

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
    await File(path).writeAsString(result);
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
      throw SchemaTooNewException(stored: ver.toInt(), supported: formatVer);
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
  Map<String, Object?> _serversWithRestoredIds() {
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
    if (keyIds.isEmpty && credIds.isEmpty) return spis;

    return {
      for (final entry in spis.entries)
        entry.key: _serverWithRestoredIds(entry.value, keyIds, credIds),
    };
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
        final record = decode(Map<String, dynamic>.from(entry.value as Map));
        final restored = localIdOf(record);
        if (restored != null) out[idOf(record)] = restored;
      } catch (_) {
        continue;
      }
    }
    return out;
  }
}

Object? _serverWithRestoredIds(
  Object? value,
  Map<String, String> keyIds,
  Map<String, String> credIds,
) {
  if (value is! Map) return value;
  final server = Map<String, Object?>.from(value);
  final ssh = server['ssh'];
  if (ssh is Map) {
    server['ssh'] = _sshWithRestoredKeyId(ssh, keyIds);
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
    if (id is String && credIds.containsKey(id)) restored['credId'] = credIds[id];
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
  rows.removeWhere(
    (key, _) => _isLocalOnly(store, key, deviceLocal),
  );
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
  for (final entry in store.getAllMap(includeInternalKeys: true).entries.where(
    (entry) => _isLocalOnly(store, entry.key, deviceLocal),
  )) {
    result[entry.key] = entry.value;
  }
  return result;
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
