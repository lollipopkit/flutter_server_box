import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/utils.dart';

const bakSync = BakSyncer._();

final icloud = ICloud(containerId: 'iCloud.tech.lolli.serverbox');

final class BakSyncer extends SyncIface {
  const BakSyncer._() : super();

  @override
  Future<void> saveToFile() => BackupV2.backup();

  @override
  Future<Mergeable> fromFile(String path) async {
    final content = await File(path).readAsString();
    return MergeableUtils.fromJsonString(content).$1;
  }

  @override
  RemoteStorage? get remoteStorage {
    final icloudEnabled = PrefProps.icloudSync.get();
    if (icloudEnabled) return icloud;

    final webdavEnabled = PrefProps.webdavSync.get();
    if (webdavEnabled) return Webdav.shared;

    return null;
  }
}
