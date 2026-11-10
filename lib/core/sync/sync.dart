import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/lkc.dart';
import 'package:server_box/core/service/report_filter.dart';
import 'package:server_box/core/sync/category.dart';
import 'package:server_box/core/sync/file_log.dart';
import 'package:server_box/core/sync/lkc.dart';
import 'package:server_box/core/sync/lkc_log.dart';
import 'package:server_box/core/sync/lkc_prefs.dart';
import 'package:server_box/core/sync/remotes.dart';
import 'package:server_box/data/model/app/bak/backup.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/backup_reader.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/store/sync_recorder.dart';

final bakSync = BakSyncer._();

final icloud = ICloud(containerId: 'iCloud.tech.lolli.serverbox');

bool get isICloudSupported => isMacOS || isIOS;

final class BakSyncer extends SyncIface {
  BakSyncer._() : super();

  /// Set by [fromFile] when the remote payload came from a newer build.
  ///
  /// `SyncIface._sync` already skips the upload after a failed merge. The
  /// case left is `_inheritLegacyRemote`, which reads a remote file outside
  /// that cycle: after it found newer data, the next sync would upload this
  /// device's older copy, silently discarding whatever it didn't understand.
  /// [backup] is the one hook available for refusing that without forking the
  /// whole cycle.
  ///
  /// Static because the syncer is a single instance shared by every caller.
  /// Shown on the backup page: this device stops syncing until updated.
  static final remoteTooNew = ValueNotifier<SchemaTooNewException?>(null);

  /// Set by [backup] while it writes for LK Cloud, where theme packages are
  /// kept apart.
  LkcThemeBlobs? _themeBlobs;

  /// The sections of the remote backup [fromFile] last read that a category
  /// covers: what this device leaves out of its own is carried on from them.
  BackupV2? _remote;

  /// The key of the remote [backup] is writing to, which seals the backup
  /// there: resolved for the remote of that cycle, not the one [sync] was
  /// asked for, which a throttled or queued sync may not be.
  SyncKeyHandle? _key;

  /// [rs]'s sync key, opened with the password here: throws
  /// [SyncPasswordMismatch] while it does not open it.
  static Future<SyncKeyHandle> keyOf(RemoteStorage rs) => switch (rs) {
    _ when keyForTest != null => keyForTest!(rs),
    LkcRemoteStorage() => lkcLog.key(),
    _ => fileLog.keyOf(rs),
  };

  /// [keyOf] for a remote a test made.
  @visibleForTesting
  static Future<SyncKeyHandle> Function(RemoteStorage rs)? keyForTest;

  @override
  Future<void> saveToFile() async {
    final remote = _remote;
    final only = SyncCategory.onNow;
    if (remote != null && !only.contains(SyncCategory.settings)) {
      // Carried as they are: the packages they name stay.
      _themeBlobs?.keep(LkcThemeBlobs.namedBy(remote));
    }
    final key = _key ?? (throw StateError('Written outside a sync'));
    await BackupV2.backup(null, null, key: key, only: only, blobs: _themeBlobs, carry: remote);
  }

  /// The sync an edit starts, which nobody waits for.
  ///
  /// Its failures are nearly all the remote's — a WebDAV server that does not
  /// answer, iCloud signed out — and with no caller they reached the zone as
  /// uncaught errors (SERVERBOX-8B). Handled here instead: logged, and
  /// reported only when [ReportFilter] says it is a defect of this app.
  void syncSoon({
    RemoteStorage? rs,
    int milliDelay = 1000,
    int throttleMilli = 5000,
  }) {
    unawaited(
      sync(
        milliDelay: milliDelay,
        throttleMilli: throttleMilli,
        rs: rs,
      ).catchError((Object e, StackTrace s) {
        if (ReportFilter.isDefect(e)) {
          Diag.error(e, s, 'Background sync');
        } else {
          Loggers.app.warning('Background sync', e, s);
          Diag.crumb(SbDiag.sync, 'failed', data: {
            'error': e.runtimeType.toString(),
          });
        }
      }),
    );
  }

  /// Skipped outright without a backup password, rather than attempted.
  ///
  /// Syncs are started on every edit and nobody awaits them, so each attempt
  /// ended as an unhandled [RemoteBackupPasswordMissing] — hundreds per install
  /// — after downloading and trying to merge a remote it had no key for. The
  /// backup page already says the backup is unencrypted, which is the state
  /// to fix.
  ///
  /// Nor while the password does not open the remote's key: nothing syncs
  /// there then ([SyncPasswordMismatch], as [lastFailure]).
  @override
  Future<void> sync({
    int throttleMilli = 5000,
    RemoteStorage? rs,
    int milliDelay = 0,
  }) async {
    final target = rs ?? remoteStorage;
    // Only with somewhere to sync to: without a remote the base returns at
    // once, and there is no password question to ask.
    if (target == null) return super.sync(throttleMilli: throttleMilli, rs: rs, milliDelay: milliDelay);
    final pwd = await SecureStoreProps.bakPwd.read();
    if (pwd == null || pwd.isEmpty) {
      Diag.crumb(SbDiag.sync, 'skipped', data: {'why': 'no password'});
      return;
    }
    try {
      // Nothing is read or written while the password does not open it.
      await keyOf(target);
    } catch (e, s) {
      // Said as the sync's failure, as one the base runs into is.
      lastFailure.value = e;
      if (e is SyncPasswordMismatch) {
        Diag.crumb(SbDiag.sync, 'skipped', data: {'why': 'password mismatch'});
      } else if (ReportFilter.isDefect(e)) {
        Diag.error(e, s, 'Sync key');
      } else {
        Loggers.app.warning('Sync key', e, s);
      }
      return;
    }
    return super.sync(throttleMilli: throttleMilli, rs: rs, milliDelay: milliDelay);
  }

  @override
  Future<Mergeable> fromFile(String path) async {
    remoteTooNew.value = null;
    _remote = null;
    final content = await File(path).readAsBytes();
    final pwd = await SecureStoreProps.bakPwd.read();
    try {
      // Only decrypting (in rage's isolate) and decoding leave this isolate:
      // they read nothing but their arguments. Prefs, secure storage and
      // [remoteTooNew] belong to this one — in a worker the pref answered
      // its default and dropped every synced setting, with no error anywhere
      // (#1562).
      //
      // Sealed to the remote's key; one an older build synced (v4, sealed
      // with the password, or plaintext from before encryption was
      // mandatory) is inherited once ([inheritLegacyRemote]).
      final Uint8List plain;
      if (SyncKeyring.sealedToKey(content)) {
        // With the keys of the syncs on here: the remote of the cycle that
        // downloaded it is one of them, whichever that was. The one it is
        // set to now is opened first, so a password it refuses stops here.
        if (remoteStorage case final rs?) await keyOf(rs);
        plain = await SyncKeyring.openAny(content);
      } else {
        plain = await BackupV2.unlock(content, pwd);
      }
      return await _read(plain, pwd);
    } on SchemaTooNewException catch (e) {
      // Recorded so `backup` refuses to upload over data this build cannot
      // read.
      remoteTooNew.value = e;
      rethrow;
    }
  }

  /// [plain], the remote backup, read; [pwd] is the password here.
  Future<Mergeable> _read(Uint8List plain, String? pwd) async {
    // It opens what the devices share, so it is theirs: one kept on this
    // device only (set by an older build) goes to iCloud Keychain now,
    // where it cannot be replacing another device's newer one.
    if (pwd != null &&
        pwd.isNotEmpty &&
        await SecureStoreProps.bakPwd.inLegacyOnly()) {
      try {
        await SecureStoreProps.bakPwd.write(pwd);
      } catch (e, s) {
        Loggers.app.warning('Backup password not moved to iCloud', e, s);
      }
    }
    final mergeable = await compute(_parse, plain);
    if (mergeable is BackupV2) {
      _remote = mergeable.copyWith(
        spis: const {},
        snippets: const {},
        keys: const {},
        container: const {},
        history: const {},
        portForwards: const {},
        remoteDesktopProfiles: const {},
        bmcCredentials: const {},
        pve: const {},
      );
    }
    return _normalizeSyncPayload(mergeable);
  }

  static Mergeable _parse(Uint8List plain) =>
      BackupReader.fromBytes(plain).$1;

  /// [mergeable] without what this device does not sync.
  static Mergeable _normalizeSyncPayload(Mergeable mergeable) {
    return switch (mergeable) {
      final BackupV2 backup => backup.only(SyncCategory.onNow),
      final BackupV1 backup when !SyncCategory.settings.on => BackupV1(
        version: backup.version,
        date: backup.date,
        spis: backup.spis,
        snippets: backup.snippets,
        keys: backup.keys,
        container: backup.container,
        history: backup.history,
        settings: null,
        lastModTime: backup.lastModTime,
      ),
      _ => mergeable,
    };
  }

  /// Calls [onEdit] on each edit to a synced setting or other synced kv store
  /// (`SyncedStores.byName`), which no provider syncs on as the entity
  /// stores' do. Every such edit stamps the store, so what is watched is the
  /// stamps' row: device-local keys and internal keys stamp nothing. Only
  /// while the store's category is synced.
  ///
  /// Not the history: tabs, workspaces and the last SFTP path change with
  /// every move, and each would be an upload and a merge on every device
  /// listening. It goes with the next sync.
  static List<StreamSubscription<String>> watchEdits(VoidCallback onEdit) => [
    for (final store in SyncedStores.byName.values)
      store.watch().listen((key) {
        if (key == store.lastUpdateTsKey &&
            SyncCategory.carries('kv:${store.name}')) {
          onEdit();
        }
      }),
  ];

  /// See [SyncIface.lacks] and [BackupV2.lacksLocal]; an older format is
  /// always written over.
  @override
  bool lacks(Mergeable downloaded) =>
      downloaded is! BackupV2 ||
      downloaded.lacksLocal(categories: SyncCategory.onNow);

  /// Refuses to upload after a failed read of newer remote data, and waits for
  /// [inheritLegacyRemote] to finish deciding. Everything else defers to the
  /// base implementation.
  @override
  Future<void> backup([RemoteStorage? rs]) async {
    // An upload is what creates the versioned remote file, and that file is
    // exactly what `inheritLegacyRemote` reads as "already inherited" — so a
    // sync overtaking it ends the one-shot without it ever having happened,
    // and the history under the old name is never read. Launch starts the
    // inherit without awaiting it, so the wait belongs here rather than there.
    //
    // Bounded, because nothing underneath it has a timeout: an unreachable
    // remote must not leave this session unable to upload at all. Going ahead
    // then costs the inheritance, which is what an unreadable remote costs
    // anyway.
    // Again if the last one could not open the remote's key: the password
    // may be the right one by now.
    await inheritLegacyRemote().timeout(const Duration(seconds: 30), onTimeout: () {});

    final tooNew = remoteTooNew.value;
    if (tooNew != null) {
      // Its own outcome, not a failure: the upload was refused because the
      // remote is newer than what this device last read. It is the one that
      // says a user has two devices disagreeing, which no error path reports
      // because nothing here went wrong.
      Diag.crumb(SbDiag.sync, 'upload skipped', data: {'why': 'remote newer'});
      Loggers.app.warning('Sync upload aborted: $tooNew');
      return;
    }
    Diag.crumb(SbDiag.sync, 'upload');
    final target = rs ?? remoteStorage;
    if (target == null) return super.backup(target);
    // The cycle's own remote: a password that does not open its key stops
    // the upload here.
    _key = await keyOf(target);
    if (target is! LkcRemoteStorage) {
      try {
        return await super.backup(target);
      } finally {
        _key = null;
      }
    }
    final blobs = _themeBlobs = LkcThemeBlobs.shared..begin();
    try {
      await super.backup(target);
    } finally {
      _themeBlobs = null;
      _key = null;
    }
    // Only once the backup naming them is written.
    await blobs.sweep();
  }

  /// The inherit in flight, awaited by [backup] so an upload cannot overtake
  /// it.
  Future<void>? _inheriting;

  /// A new launch, as far as [inheritLegacyRemote] is concerned.
  @visibleForTesting
  void forgetInheritForTest() => _inheriting = null;

  /// Reads the newest remote file an older build synced to, once, so
  /// upgrading doesn't look like a fresh start.
  ///
  /// The versioned name means this build ignores the older names from then
  /// on; a device still on an older build keeps updating its own, and the
  /// two histories diverge until it is updated and merges this build's file
  /// with what it has. That divergence is the cost of not letting those
  /// builds overwrite data they cannot read — see the note at `Paths.init`.
  ///
  /// A no-op once the versioned file exists remotely, so it runs at most once
  /// per remote. An attempt is memoized for the same reason within a launch: a
  /// second call would ask the remote a question this one is already
  /// answering.
  ///
  /// Having no remote is not an attempt and is not memoized. It is an answer
  /// about this moment only — sync is configured from a settings page, so the
  /// next call may well have somewhere to look — and memoizing it would turn
  /// "not yet" into "never" for the rest of the launch.
  ///
  /// TODO: remove with the rest of the v2/v3 compatibility shims.
  Future<void> inheritLegacyRemote() {
    final rs = remoteStorage;
    if (rs == null) return Future.value();
    return _inheriting ??= _inheritLegacyRemote(rs);
  }

  Future<void> _inheritLegacyRemote(RemoteStorage rs) async {
    try {
      if (await rs.exists(Paths.bakName)) return;
      // Only with the password the remote's key opens with: one that does
      // not would merge nothing, or another person's backup.
      await keyOf(rs);
      for (final name in Miscs.legacyBakFileNames) {
        if (!await rs.exists(name)) continue;
        final localPath = Paths.doc.joinPath(name);
        await rs.download(relativePath: name, localPath: localPath);
        final mergeable = await fromFile(localPath);
        await mergeable.merge();
        Loggers.app.info('Inherited sync history from $name');
        return;
      }
    } on SyncPasswordMismatch {
      // Not an attempt: tried again once the password opens the key, before
      // the first upload makes the versioned file.
      _inheriting = null;
    } on SyncKeyNotHere {
      _inheriting = null;
    } on RemoteBackupPasswordMissing {
      _inheriting = null;
    } on SyncPasswordMissing {
      _inheriting = null;
    } catch (e, s) {
      // Best-effort: failing to inherit leaves the user with an empty remote
      // they can populate by syncing, which is recoverable. Failing loudly
      // here would block startup over a file that may not even be theirs.
      Loggers.app.warning('Inherit legacy sync file', e, s);
    }
  }

  /// Where this device's last sync position is kept.
  ///
  /// A `PrefProp` and not a store key on purpose: it describes *this device*
  /// and would be wrong on any other, so it must stay out of the backup. The
  /// three fields are joined by a NUL, which is the one byte neither an ETag
  /// nor a timestamp can contain.
  static const _checkpoint = PrefProp<String>('sync_checkpoint');

  static const _checkpointSep = '\u0000';

  @override
  (String, String, int)? get syncCheckpoint {
    final raw = _checkpoint.get();
    if (raw == null) return null;
    final parts = raw.split(_checkpointSep);
    if (parts.length != 3) return null;
    final at = int.tryParse(parts[2]);
    // A record this cannot read is one written by a build with a different
    // shape. Answered as absent rather than repaired: the cost is one full
    // sync, and guessing at the missing half would be a checkpoint nothing
    // stands behind.
    if (at == null) return null;
    return (parts[0], parts[1], at);
  }

  @override
  Future<void> saveSyncCheckpoint(String remote, String local, int atMs) =>
      _checkpoint.set('$remote$_checkpointSep$local$_checkpointSep$atMs');

  /// Forgets where this device was, so the next sync does the full cycle.
  ///
  /// Called when the *remote* is reconfigured. The checkpoint carries the
  /// backend's runtime type, which does not change when a WebDAV URL is
  /// pointed at a different server — and pointing it somewhere new is exactly
  /// when the shortcut would skip the sync that had everything to do.
  /// The remote read last is another's then too.
  static Future<void> forgetCheckpoint() {
    bakSync._remote = null;
    remoteTooNew.value = null;
    return _checkpoint.remove();
  }

  /// When the user last changed anything that gets synced.
  ///
  /// [Stores.lastModTime] is already the number sync uses to decide which side
  /// wins, so a change it cannot see is one the merge would discard anyway —
  /// which is what makes it safe to skip an upload on. It covers deletions:
  /// `EntityStore.lastModTime` takes the max over the table *and* its
  /// tombstones, so removing a server moves it.
  ///
  /// Zero means nothing has ever been edited on this device, and answers null
  /// so a fresh install always does the full cycle.
  @override
  String? get localVersionTag {
    final ts = Stores.lastModTime;
    if (ts == 0) return null;
    // The switches change *what* the payload contains without touching any
    // store, so a tag keyed on modification time alone would skip the upload
    // that was supposed to add a category or take it away.
    return '$ts/${[for (final c in SyncCategory.onNow) c.name].join(',')}';
  }

  @override
  RemoteStorage? get remoteStorage {
    final icloudEnabled = PrefProps.icloudSync.get();
    if (icloudEnabled && isICloudSupported) return icloud;

    final webdavEnabled = PrefProps.webdavSync.get();
    if (webdavEnabled) return SyncRemotes.webdav;

    if (Lkc.enabled && LkcSyncPrefs.enabled.get() && Lkc.client.signedIn && Lkc.client.user.value != null) {
      return LkcSyncPrefs.storage;
    }

    return null;
  }
}
