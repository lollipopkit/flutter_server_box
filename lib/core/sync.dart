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
    if (pwd == null || pwd.isEmpty) {
      // Enforce password for non-clipboard backups
      throw Exception('Backup password not set');
    }
    await BackupV2.backup(null, pwd);
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
    } catch (_) {
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
