import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/bak/backup.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/utils.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/schema.dart';

final bakSync = BakSyncer._();

final icloud = ICloud(containerId: 'iCloud.tech.lolli.serverbox');

bool get isICloudSupported => isMacOS || isIOS;

final class BakSyncer extends SyncIface {
  BakSyncer._() : super();

  /// Set by [fromFile] when the remote payload came from a newer build.
  ///
  /// `SyncIface._sync` catches merge failures, logs them, and then uploads
  /// unconditionally — so a device that could not read the remote data would
  /// overwrite it with its own older copy, silently discarding whatever it
  /// didn't understand. [backup] is the one hook available for refusing that
  /// without forking the whole cycle.
  ///
  /// Static because the syncer is a single instance shared by every caller.
  static SchemaTooNewException? _remoteTooNew;

  /// Whether the last sync attempt aborted because the remote data is newer
  /// than this build understands. The UI surfaces this — a silently skipped
  /// sync is indistinguishable from a working one.
  static SchemaTooNewException? get remoteTooNew => _remoteTooNew;

  @override
  Future<void> saveToFile() async {
    await writeEncryptedBackup(
      includeSettings: PrefProps.syncAppSettings.get(),
    );
  }

  /// Writes a backup that is safe to upload to remote storage.
  ///
  /// Remote writes are always encrypted. Reading remains backwards-compatible
  /// in [fromFile] so a plaintext backup created before this requirement can be
  /// merged and replaced by an encrypted backup on the next upload.
  Future<String> writeEncryptedBackup({
    String? name,
    bool includeSettings = true,
  }) async {
    final pwd = await SecureStoreProps.bakPwd.read();
    if (pwd == null || pwd.isEmpty) {
      throw StateError(l10n.remoteBackupPasswordRequired);
    }
    return BackupV2.backup(name, pwd, includeSettings);
  }

  @override
  Future<Mergeable> fromFile(String path) async {
    _remoteTooNew = null;
    final content = await File(path).readAsString();
    final pwd = await SecureStoreProps.bakPwd.read();
    final includeSettings = PrefProps.syncAppSettings.get();
    try {
      if (Cryptor.isEncrypted(content)) {
        final mergeable = MergeableUtils.fromJsonString(content, pwd).$1;
        return _normalizeSyncPayload(
          mergeable,
          includeSettings: includeSettings,
        );
      }
      // Backups uploaded before remote encryption became mandatory are
      // plaintext. Keep accepting them; only new remote writes are required
      // to be encrypted.
      final mergeable = MergeableUtils.fromJsonString(content).$1;
      return _normalizeSyncPayload(mergeable, includeSettings: includeSettings);
    } on SchemaTooNewException catch (e) {
      // Not a parse problem — retrying without the password would decode the
      // same too-new payload, and falling through to the v1 reader would
      // decode it wrong. Record it so `backup` refuses to upload over it.
      _remoteTooNew = e;
      rethrow;
    } catch (e, s) {
      Loggers.app.warning(
        'Failed to parse backup file with password, trying without password',
        e,
        s,
      );
      // Fallback: try without password if detection failed
      final mergeable = MergeableUtils.fromJsonString(content).$1;
      return _normalizeSyncPayload(mergeable, includeSettings: includeSettings);
    }
  }

  Mergeable _normalizeSyncPayload(
    Mergeable mergeable, {
    required bool includeSettings,
  }) {
    if (includeSettings) return mergeable;

    return switch (mergeable) {
      final BackupV2 backup => backup.copyWith(settings: const {}),
      final Backup backup => Backup(
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

    final tooNew = _remoteTooNew;
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
    return super.backup(rs);
  }

  /// The inherit in flight, awaited by [backup] so an upload cannot overtake
  /// it.
  Future<void>? _inheriting;

  /// Reads the pre-v3 remote file once, so upgrading doesn't look like a
  /// fresh start.
  ///
  /// The versioned name means this build ignores `srvbox_bak.json` from then
  /// on; a device still on an older build keeps updating it, and the two
  /// histories diverge from here. That divergence is the cost of not letting
  /// those builds overwrite data they cannot read — see the note at
  /// `Paths.init`.
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
  /// TODO: remove with the rest of the v2 compatibility shims.
  Future<void> inheritLegacyRemote() {
    final rs = remoteStorage;
    if (rs == null) return Future.value();
    return _inheriting ??= _inheritLegacyRemote(rs);
  }

  Future<void> _inheritLegacyRemote(RemoteStorage rs) async {
    try {
      if (await rs.exists(Paths.bakName)) return;
      if (!await rs.exists(Miscs.legacyBakFileName)) return;

      final localPath = Paths.doc.joinPath(Miscs.legacyBakFileName);
      await rs.download(
        relativePath: Miscs.legacyBakFileName,
        localPath: localPath,
      );
      final mergeable = await fromFile(localPath);
      await mergeable.merge();
      Loggers.app.info(
        'Inherited sync history from ${Miscs.legacyBakFileName}',
      );
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
  static Future<void> forgetCheckpoint() => _checkpoint.remove();

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
    // The switch changes *what* the payload contains without touching any
    // store, so a tag keyed on modification time alone would skip the upload
    // that was supposed to add the settings or take them away.
    return '$ts/${PrefProps.syncAppSettings.get()}';
  }

  @override
  RemoteStorage? get remoteStorage {
    final icloudEnabled = PrefProps.icloudSync.get();
    if (icloudEnabled && isICloudSupported) return icloud;

    final webdavEnabled = PrefProps.webdavSync.get();
    if (webdavEnabled) return Webdav.shared;

    final gistEnabled = PrefProps.gistSync.get();
    if (gistEnabled) return GistRs.shared;

    return null;
  }
}
