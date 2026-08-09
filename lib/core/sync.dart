import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/bak/backup.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/utils.dart';
import 'package:server_box/data/store/schema.dart';

const bakSync = BakSyncer._();

final icloud = ICloud(containerId: 'iCloud.tech.lolli.serverbox');

bool get isICloudSupported => isMacOS || isIOS;

final class BakSyncer extends SyncIface {
  const BakSyncer._() : super();

  /// Set by [fromFile] when the remote payload came from a newer build.
  ///
  /// `SyncIface._sync` catches merge failures, logs them, and then uploads
  /// unconditionally — so a device that could not read the remote data would
  /// overwrite it with its own older copy, silently discarding whatever it
  /// didn't understand. [backup] is the one hook available for refusing that
  /// without forking the whole cycle.
  ///
  /// Static because the syncer is a const singleton.
  static SchemaTooNewException? _remoteTooNew;

  /// Whether the last sync attempt aborted because the remote data is newer
  /// than this build understands. The UI surfaces this — a silently skipped
  /// sync is indistinguishable from a working one.
  static SchemaTooNewException? get remoteTooNew => _remoteTooNew;

  @override
  Future<void> saveToFile() async {
    final pwd = await SecureStoreProps.bakPwd.read();
    final includeSettings = PrefProps.syncAppSettings.get();
    await BackupV2.backup(
      null,
      pwd?.isEmpty == true ? null : pwd,
      includeSettings,
    );
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

  /// Refuses to upload after a failed read of newer remote data. Everything
  /// else defers to the base implementation.
  @override
  Future<void> backup([RemoteStorage? rs]) async {
    final tooNew = _remoteTooNew;
    if (tooNew != null) {
      Loggers.app.warning('Sync upload aborted: $tooNew');
      return;
    }
    return super.backup(rs);
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
