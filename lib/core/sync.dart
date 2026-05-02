import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/bak/backup.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/utils.dart';

const bakSync = BakSyncer._();

final icloud = ICloud(containerId: 'iCloud.tech.lolli.serverbox');

bool get isICloudSupported => isMacOS || isIOS;

final class BakSyncer extends SyncIface {
  const BakSyncer._() : super();

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
