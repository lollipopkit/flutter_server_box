import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/utils.dart';

const bakSync = BakSyncer._();

final icloud = ICloud(containerId: 'iCloud.tech.lolli.serverbox');

final class BakSyncer extends SyncIface {
  const BakSyncer._() : super();

  @override
  Future<void> saveToFile() async {
    final pwd = await SecureStoreProps.bakPwd.read();
    await BackupV2.backup(null, pwd?.isEmpty == true ? null : pwd);
  }

  @override
  Future<Mergeable> fromFile(String path) async {
    final content = await File(path).readAsString();
    final pwd = await SecureStoreProps.bakPwd.read();
    try {
      if (Cryptor.isEncrypted(content)) {
        return MergeableUtils.fromJsonString(content, pwd).$1;
      }
      return MergeableUtils.fromJsonString(content).$1;
    } catch (e, s) {
      Loggers.app.warning('Failed to parse backup file with password, trying without password', e, s);
      // Fallback: try without password if detection failed
      return MergeableUtils.fromJsonString(content).$1;
    }
  }

  @override
  RemoteStorage? get remoteStorage {
    final icloudEnabled = PrefProps.icloudSync.get();
    if (icloudEnabled) return icloud;

    final webdavEnabled = PrefProps.webdavSync.get();
    if (webdavEnabled) return Webdav.shared;

    final gistEnabled = PrefProps.gistSync.get();
    if (gistEnabled) return GistRs.shared;

    return null;
  }
}
