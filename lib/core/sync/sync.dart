import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/theme.dart' show ThemeBlobStore;
import 'package:flutter/foundation.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/lkc.dart';
import 'package:server_box/core/monitor/backup_storage.dart';
import 'package:server_box/core/service/report_filter.dart';
import 'package:server_box/core/sync/category.dart';
import 'package:server_box/core/sync/key.dart';
import 'package:server_box/core/sync/lkc.dart';
import 'package:server_box/core/sync/lkc_prefs.dart';
import 'package:server_box/core/sync/remotes.dart';
import 'package:server_box/data/model/app/bak/backup.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/backup_reader.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
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

  /// Whether the last sync that ran ended on a backup the password here
  /// does not open. As each one ends, unlike [SyncIface.lastFailure], which
  /// a sync clears as it starts: shown from this, it does not blink.
  static final passwordRefused = ValueNotifier(false);

  /// Set by [backup] while it writes for LK Cloud, where theme packages are
  /// kept apart.
  LkcThemeBlobs? _themeBlobs;

  /// The sections of the remote backup [fromFile] last read that a category
  /// covers: what this device leaves out of its own is carried on from them.
  BackupV2? _remote;

  @override
  Future<void> saveToFile() async {
    final remote = _remote;
    final only = SyncCategory.onNow;
    if (remote != null && !only.contains(SyncCategory.settings)) {
      // Carried as they are: the packages they name stay.
      _themeBlobs?.keep(LkcThemeBlobs.namedBy(remote));
    }
    await writeEncryptedBackup(only: only, blobs: _themeBlobs, carry: remote);
  }

  /// Writes a backup that is safe to upload to remote storage.
  ///
  /// Remote writes are always encrypted. Reading remains backwards-compatible
  /// in [fromFile] so a plaintext backup created before this requirement can be
  /// merged and replaced by an encrypted backup on the next upload.
  ///
  /// [only], [blobs] and [carry] as [BackupV2.backup].
  Future<String> writeEncryptedBackup({
    String? name,
    Set<SyncCategory>? only,
    ThemeBlobStore? blobs,
    BackupV2? carry,
  }) async {
    final pwd = await SecureStoreProps.bakPwd.read();
    if (pwd == null || pwd.isEmpty) throw const RemoteBackupPasswordMissing();
    return BackupV2.backup(name, pwd, only: only, blobs: blobs, carry: carry);
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
  @override
  Future<void> sync({
    int throttleMilli = 5000,
    RemoteStorage? rs,
    int milliDelay = 0,
  }) async {
    // Only with somewhere to sync to: without a remote the base returns at
    // once, and there is no password question to ask.
    if ((rs ?? remoteStorage) != null) {
      final pwd = await SecureStoreProps.bakPwd.read();
      if (pwd == null || pwd.isEmpty) {
        Diag.crumb(SbDiag.sync, 'skipped', data: {'why': 'no password'});
        return;
      }
      await _followPassword(pwd);
    }
    try {
      return await super.sync(
        throttleMilli: throttleMilli,
        rs: rs,
        milliDelay: milliDelay,
      );
    } finally {
      passwordRefused.value = lastFailure.value is WrongPasswordException;
    }
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
      // A plaintext backup, uploaded before remote encryption became
      // mandatory, is still accepted: the password is only used on an
      // encrypted payload.
      final Uint8List plain;
      try {
        plain = await BackupV2.unlock(content, pwd);
      } on WrongPasswordException {
        // Sealed with the password this device changed from: opened with
        // it, and sealed with the new one by this sync's upload (what that
        // change forgot makes it upload).
        for (final previous in await SyncKey.previousPasswords()) {
          try {
            return await _read(await BackupV2.unlock(content, previous), pwd);
          } on WrongPasswordException {
            continue;
          }
        }
        rethrow;
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
  /// (`SyncRecorder.syncedStores`), which no provider syncs on as the entity
  /// stores' do. Every such edit stamps the store, so what is watched is the
  /// stamps' row: device-local keys and internal keys stamp nothing. Only
  /// while the store's category is synced.
  ///
  /// Not the history: tabs, workspaces and the last SFTP path change with
  /// every move, and each would be an upload and a merge on every device
  /// listening. It goes with the next sync.
  static List<StreamSubscription<String>> watchEdits(VoidCallback onEdit) => [
    for (final store in SyncRecorder.syncedStores.values)
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

  /// The password this device last synced with, kept on this device only.
  ///
  /// One set on another device arrives through iCloud Keychain, and what
  /// setting it here forgets ([forgetPasswordState]) has to be forgotten here
  /// too: the checkpoint stands for a file sealed with the old one, and the
  /// theme packages' names for packages sealed with it.
  static const _pwdSeen = SecureProp('bakPwdSeen');

  static Future<void> _followPassword(String pwd) async {
    // Past the rate limit: a sync is not a user asking, and runs on its own.
    final seen = await _pwdSeen.storage.read(key: _pwdSeen.key);
    if (seen == pwd) return;
    // None on the first sync of this build: nothing known to forget.
    if (seen != null) await forgetPasswordState();
    await _pwdSeen.storage.write(key: _pwdSeen.key, value: pwd);
  }

  /// What a backup password sealed: see [_followPassword].
  static Future<void> forgetPasswordState() async {
    await forgetCheckpoint();
    await LkcThemeBlobs.forgetNames();
  }

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
    final inheriting = _inheriting;
    if (inheriting != null) {
      await inheriting.timeout(const Duration(seconds: 30), onTimeout: () {});
    }

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
    if (target is! LkcRemoteStorage) {
      await super.backup(target);
      // Uploaded: sealed with the password here now.
      return SyncKey.backupResealed();
    }
    final blobs = _themeBlobs = LkcThemeBlobs.shared..begin();
    try {
      await super.backup(target);
    } finally {
      _themeBlobs = null;
    }
    await SyncKey.backupResealed();
    // Only once the backup naming them is written.
    await blobs.sweep();
  }

  /// The inherit in flight, awaited by [backup] so an upload cannot overtake
  /// it.
  Future<void>? _inheriting;

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
      for (final name in Miscs.legacyBakFileNames) {
        if (!await rs.exists(name)) continue;
        final localPath = Paths.doc.joinPath(name);
        await rs.download(relativePath: name, localPath: localPath);
        final mergeable = await fromFile(localPath);
        await mergeable.merge();
        Loggers.app.info('Inherited sync history from $name');
        return;
      }
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

    final gistEnabled = PrefProps.gistSync.get();
    if (gistEnabled) return SyncRemotes.gist;

    if (monitorSync.get()) return monitorStorage();

    if (Lkc.enabled && LkcSyncPrefs.enabled.get() && Lkc.client.signedIn) return LkcSyncPrefs.storage;

    return null;
  }

  /// Whether the backup syncs to one of this app's own monitor agents, and to
  /// which server's. Device-local prefs like the other three switches, and
  /// beside them rather than in fl_lib's `PrefProps`, since a server id is
  /// this app's concept. Keys are permanent.
  static const monitorSync = PrefPropDefault(
    'monitor_sync',
    false,
    updateLastUpdateTsOnSetProp: false,
  );
  static const monitorSyncServer = PrefProp<String>(
    'monitor_sync_server',
    updateLastUpdateTsOnSetProp: false,
  );

  /// Kept while the chosen server and its agent settings stay the same: it
  /// owns an HTTP client, and [remoteStorage] is read on every sync.
  MonitorBackupStorage? _monitorStorage;

  /// The chosen server's agent store, or null when none is chosen, the record
  /// is gone, or its agent is not configured or switched off ([Spix.monitorOn]).
  ///
  /// A method, not a getter: a server's agent settings change wherever it is
  /// edited, so this is where a stale store is noticed — closed, and its HTTP
  /// client with it, before a new one is made.
  MonitorBackupStorage? monitorStorage() {
    final id = monitorSyncServer.get();
    final monitor = id == null ? null : Stores.server.fetchOneRaw(id)?.monitorOn;
    final cached = _monitorStorage;
    if (id != null && monitor != null && cached != null && cached.matches(id, monitor)) {
      return cached;
    }
    cached?.close();
    _monitorStorage = null;
    if (id == null || monitor == null) return null;
    return _monitorStorage = MonitorBackupStorage(id, monitor);
  }
}
