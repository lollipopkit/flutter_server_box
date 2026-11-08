part of 'backup2.dart';

/// Restoring a [BackupV2] into this device's stores: one transaction for every
/// store, then the migrations the file predates, then the providers told.
///
/// A part of `backup2.dart` rather than a library of its own, so the helpers
/// it shares with encoding stay private and nothing imports back.
extension BackupV2Restore on BackupV2 {
  /// [BackupV2.merge], answering what became of [themes]: which came back,
  /// and which could not — for a restore the user started to say so.
  Future<ThemeRestoreReport?> restoreStores({bool force = false}) async {
    _validateRestorableTypedStores();
    _loggerV2.info('Merging...');

    // Before the settings that select one: the network is not something to
    // hold the transaction open for, and a selection is only restored onto a
    // theme that is there.
    final themeReport = themes.isEmpty
        ? null
        : await ThemeBackup.restore(themes, blobs: BackupThemeBlobs.available);
    if (themeReport != null && themeReport.failed.isNotEmpty) {
      _loggerV2.warning('Themes not restored: ${themeReport.failed}');
    }

    // Every store shares this SQLite connection. Keep the reference order, but
    // commit the whole restore as one unit so a later failure cannot leave the
    // earlier stores visible without it.
    final restored = _restoredServerGraph();
    final keysBefore = [for (final k in Stores.key.fetch()) k.key];
    // A restore the user started ([force]) is their change, and syncs out; a
    // sync's merge is another device's, stamped as no device's
    // (`SyncRecorder.applying`).
    T asChanged<T>(T Function() write) =>
        force ? write() : SyncRecorder.applying(write);
    final changed = asChanged(() => SqliteStore.transact(() {
      final keysChanged = Stores.key.merge(keys, force: force, notify: false);
      final credsChanged = Stores.bmcCredential.merge(
        bmcCredentials,
        force: force,
        notify: false,
      );
      final appliedServerIds = <String>{};
      var serversChanged = Stores.server.merge(
        restored.servers,
        force: force,
        notify: false,
        appliedIds: appliedServerIds,
      );
      final snippetsChanged = Stores.snippet.merge(
        _snippetsWithRestoredServerIds(restored.serverIds),
        force: force,
        notify: false,
      );
      final forwardsChanged = Stores.portForward.merge(
        _portForwardsWithRestoredServerIds(restored.serverIds),
        force: force,
        notify: false,
      );
      final remoteDesktopsChanged = Stores.remoteDesktop.merge(
        _remoteDesktopsWithRestoredServerIds(restored.serverIds),
        force: force,
        notify: false,
      );

      final restoredContainer = _containerWithRestoredServerIds(
        restored.serverIds,
      );
      var containerChanged = false;
      final containerIds = <String>{
        for (final key in restored.servers.keys)
          if (!_isInternalStoreKey(key)) key,
        for (final key in restoredContainer.keys)
          if (!_isInternalStoreKey(key)) key,
      };
      for (final serverId in containerIds) {
        // A container host is a child of its server and carries no timestamp
        // of its own — editing one stamps the parent. So the backup speaks for
        // it exactly where it spoke for the parent. Applied to every server
        // instead, this deleted a host configured here after the backup was
        // taken, on a server `merge` had just correctly decided to keep.
        if (!appliedServerIds.contains(serverId)) continue;
        if (Stores.container.restoreOne(
          serverId,
          restoredContainer[serverId] ?? const <String, Object?>{},
          notify: false,
        )) {
          containerChanged = true;
          serversChanged = true;
        }
      }

      // Same rule as the container host just above: a child of its server,
      // restored exactly where the server was — and only as far as the file
      // can speak for it, see [_pveToRestore].
      final restoredPve = _pveWithRestoredServerIds(restored.serverIds);
      for (final serverId in containerIds.union(restoredPve.keys.toSet())) {
        if (!appliedServerIds.contains(serverId)) continue;
        final value = _pveToRestore(serverId, restoredPve, force: force);
        if (value == null) continue;
        if (Stores.pve.restoreOne(serverId, value, notify: false)) {
          serversChanged = true;
        }
      }

      final historyNotifications = _mergeSqliteStore(
        Stores.history,
        _mergeDataForStore(
          Stores.history,
          _historyWithRestoredServerIds(restored.serverIds),
        ),
        force: force,
      );
      final settingNotifications = settings.isEmpty
          ? const <String>{}
          : _mergeSqliteStore(
              Stores.setting,
              _mergeDataForStore(Stores.setting, settings),
              force: force,
            );
      final storeNotifications = <SqliteStore, Set<String>>{
        for (final MapEntry(key: name, value: store)
            in BackupV2._syncedStores.entries)
          // Not kept by a device that keeps none.
          if (stores.containsKey(name) &&
              (store != Stores.keyPassphrase ||
                  Stores.setting.rememberKeyPassphrase.fetch()))
            store: _mergeSqliteStore(
              store,
              _mergeDataForStore(store, _storeRows(name)),
              force: force,
            ),
      };
      // Restoring does not run the schema migrator. Convert legacy setting
      // shapes in version order before this transaction can commit, so a
      // failed conversion rolls the entire restore back with it.
      if (settings.isNotEmpty) {
        for (final step in restoreSettingsMigrationsFor(version)) {
          step.applySync();
        }
      }
      return (
        keys: keysChanged,
        creds: credsChanged,
        servers: serversChanged,
        snippets: snippetsChanged,
        forwards: forwardsChanged,
        remoteDesktops: remoteDesktopsChanged,
        container: containerChanged,
        history: historyNotifications,
        settings: settingNotifications,
        stores: storeNotifications,
      );
    }));

    // Notifications and provider reloads happen only after the outer
    // transaction commits, so a failed restore leaves every store as it was.
    // The themes installed before it stay installed, selected by nothing.
    if (changed.keys) {
      Stores.key.invalidate();
      PrivateKeyUnlock.forgetAll();
      forgetParsedIdentities();
      KeyPassphrases.forgetGone(keysBefore, Stores.key.fetch().map((e) => e.key));
    }
    if (changed.creds) Stores.bmcCredential.invalidate();
    if (changed.servers) {
      Stores.server.invalidate();
      // A server tombstone cascades these rows even when their own merge pass
      // has no later write to announce.
      Stores.portForward.invalidate();
      Stores.remoteDesktop.invalidate();
      Stores.snippet.invalidate();
      // A PVE write sets `servers`; a deleted server's row cascades
      // without one, since `restoreOne` answers false for a server not here.
      Stores.pve.invalidate();
    }
    if (changed.snippets && !changed.servers) Stores.snippet.invalidate();
    if (changed.forwards && !changed.servers) Stores.portForward.invalidate();
    if (changed.remoteDesktops && !changed.servers) {
      Stores.remoteDesktop.invalidate();
    }
    _notifySqliteStore(Stores.history, changed.history);
    _notifySqliteStore(Stores.setting, changed.settings);
    for (final MapEntry(key: store, value: keys) in changed.stores.entries) {
      _notifySqliteStore(store, keys);
    }

    StoreReload.after({
      if (changed.servers) ReloadedStore.servers,
      if (changed.snippets) ReloadedStore.snippets,
      if (changed.keys) ReloadedStore.keys,
      if (changed.creds) ReloadedStore.bmcCredentials,
      if (changed.container) ReloadedStore.containers,
    });

    // After the settings: it points what they restored at this device's
    // installations, and falls back where a theme did not come back.
    if (themeReport != null) ThemeBackup.reselect(themeReport);

    _loggerV2.info('Merge completed');
    return themeReport;
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
    // Every local id per name, not one: a server's name is not unique, and a
    // map keyed by it answers with whichever record happened to be last.
    final localByName = <String, List<String>>{};
    for (final server in Stores.server.fetch()) {
      (localByName[server.name] ??= <String>[]).add(server.id);
    }
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
      // An id this device already holds is the identity; a name only stands in
      // for a record that carries none. A name is ambiguous when more than one
      // local server has it, and resolves to nothing then — the same rule
      // `ServerStore.reconcile` applies, and it has to be the same one, since
      // the id decided here is what reconcile is later handed. Resolving it to
      // one of them instead overwrote whichever the lookup answered with.
      final namedLocally = name is String ? localByName[name] : null;
      final restoredId = Stores.server.fetchOneRaw(backupId) != null
          ? backupId
          : (namedLocally != null && namedLocally.length == 1
                ? namedLocally.single
                : backupId);
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

  Map<String, Object?> _remoteDesktopsWithRestoredServerIds(
    Map<String, String> serverIds,
  ) => {
    for (final entry in remoteDesktopProfiles.entries)
      entry.key: _recordWithRestoredServerId(entry.value, serverIds),
  };

  Map<String, Object?> _containerWithRestoredServerIds(
    Map<String, String> serverIds,
  ) => {
    for (final entry in container.entries)
      serverIds[entry.key] ?? entry.key: entry.value,
  };

  Map<String, Object?> _pveWithRestoredServerIds(
    Map<String, String> serverIds,
  ) => {
    for (final entry in pve.entries)
      if (!_isInternalStoreKey(entry.key))
        serverIds[entry.key] ?? entry.key: entry.value,
  };

  /// What restoring [serverId]'s PVE configuration writes: an entry for
  /// `PveStore.restoreOne` (empty removes the row, unreadable is skipped
  /// there), or null to leave the row as it is.
  ///
  /// **A file with a [pve] section** ([carriesPveSection]) is the whole
  /// truth: its entry, or none, which removes the row. That is how removing
  /// PVE on one device reaches the others.
  ///
  /// **A file from an older build** has no section and cannot say "removed"
  /// any other way than it says "never had", so a sync leaves the row alone.
  /// Restoring one ([force]) is the file's state, and at the time it was
  /// written the server had no PVE here. The `custom.pveAddr`/`pvePwd` such a
  /// file may carry are not read.
  Object? _pveToRestore(
    String serverId,
    Map<String, Object?> restoredPve, {
    required bool force,
  }) {
    if (!carriesPveSection) return force ? const <String, Object?>{} : null;
    // A malformed entry is passed on for `PveStore.restoreOne` to skip:
    // read as "none", it would delete the credentials here.
    return restoredPve[serverId] ?? const <String, Object?>{};
  }

  Map<String, Object?> _historyWithRestoredServerIds(
    Map<String, String> serverIds,
  ) {
    final restored = Map<String, Object?>.from(history);
    // This key belonged to the retired recent-server dialog. Older backups
    // may still contain it, but restoring one must not put unused history back
    // into the database after the local migration removed it.
    // TODO: Remove once supported backups can no longer contain this key.
    restored.remove('sshServerHistory');
    final lastPaths = restored['sftpLastPath'];
    if (lastPaths is Map) {
      restored['sftpLastPath'] = {
        for (final entry in lastPaths.entries)
          serverIds['${entry.key}'] ?? '${entry.key}': entry.value,
      };
    }
    // The terminal and file tabs' saved sessions, which a cold start no longer
    // reopens (m037).
    // TODO: Remove once supported backups can no longer contain these keys.
    restored.remove('sshTabs');
    restored.remove('fileTabs');
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

Map<String, Object?> _mergeDataForStore(
  SqliteStore store,
  Map<String, Object?> rows,
) {
  final result = Map<String, Object?>.from(rows)
    ..removeWhere((key, _) => _isLocalOnly(store, key));
  // An older build's stamp on a device-local key would make the merge rewrite
  // this device's own value and take that stamp.
  // TODO: rm once no build that stamps device-local keys is around.
  final ts = result[store.lastUpdateTsKey];
  if (ts != null) {
    result[store.lastUpdateTsKey] = {
      for (final MapEntry(:key, :value) in _kvTimestamps(
        ts,
        result.keys.where((key) => key != store.lastUpdateTsKey),
      ).entries)
        if (!store.isDeviceLocalKey(key)) key: value,
    };
  }

  // Mergeable treats an absent key as a deletion. Keep local-only state in
  // the input until fl_lib can expose an internal-key exclusion policy.
  for (final entry
      in store
          .getAllMap(includeInternalKeys: true)
          .entries
          .where((entry) => _isLocalOnly(store, entry.key))) {
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
      // Nothing here to protect. A key this device does not hold and has no
      // timestamp for was never written and never deleted, so the backup's
      // copy is the only copy — `0 <= 0` used to drop it, which is every entry
      // of every envelope that carries no timestamps.
      if (!force &&
          currentTimestamp > 0 &&
          backupTimestamp <= currentTimestamp) {
        continue;
      }
      final value = backupData[key];
      if (value == null) continue;
      _writeKv(store, key, value, at: backupTimestamp);
      notifications.add(key);
      if (!store.isInternalKey(key)) {
        timestamps[key] = backupTimestamp;
        timestampDirty = true;
      }
      continue;
    }

    if (!backupHasKey && currentHasKey) {
      if (!force && backupTimestamp <= currentTimestamp) continue;
      _deleteKv(store, key, at: backupTimestamp);
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
    if (const DeepCollectionEquality().equals(value, current[key])) {
      // The same, edited later there: the later stamp, or the two devices'
      // stamps differ for good and so does every backup they write.
      if (!store.isInternalKey(key) && backupTimestamp > currentTimestamp) {
        timestamps[key] = backupTimestamp;
        timestampDirty = true;
      }
      continue;
    }
    if (value == null) {
      _deleteKv(store, key, at: backupTimestamp);
    } else {
      _writeKv(store, key, value, at: backupTimestamp);
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
    // The map itself, as `KvStore` writes it: a string holding it read the
    // same but made the next backup differ in shape from the other device's.
    _writeKv(store, store.lastUpdateTsKey, timestamps);
    notifications.add(store.lastUpdateTsKey);
  }
  return notifications;
}

/// Writes [key] as the merge decided; when it is a key that syncs, stamps it
/// too ([at]: the backup's time for it), as `KvStore.onEdit` would.
void _writeKv(SqliteStore store, String key, Object value, {int? at}) {
  final encoded = json.encode(_toJsonValue(value));
  SqliteDb.instance.execute(
    'INSERT INTO kv (store, key, value, updated_at) VALUES (?, ?, ?, ?) '
    'ON CONFLICT (store, key) DO UPDATE SET '
    'value = excluded.value, updated_at = excluded.updated_at;',
    [store.name, key, encoded, SyncClock.now()],
  );
  _recordKv(store, key, at);
}

void _deleteKv(SqliteStore store, String key, {int? at}) {
  SqliteDb.instance.execute('DELETE FROM kv WHERE store = ? AND key = ?;', [
    store.name,
    key,
  ]);
  _recordKv(store, key, at);
}

void _recordKv(SqliteStore store, String key, int? at) {
  if (!SyncRecorder.syncedStores.containsKey(store.name)) return;
  if (store.isInternalKey(key) || store.isDeviceLocalKey(key)) return;
  SyncRecorder.record('kv:${store.name}', key, at: at);
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
