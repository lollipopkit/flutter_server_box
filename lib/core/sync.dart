import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/backup.dart';

const bakSync = BakSyncer._();

final icloud = ICloud(containerId: 'iCloud.tech.lolli.serverbox');

final class BakSyncer extends SyncIface<Backup> {
  const BakSyncer._() : super();

  @override
  void init() {
    Webdav.shared.prefix = 'serverbox/';
  }

  @override
  Future<void> saveToFile() => Backup.backup();

  @override
  Future<Backup> fromFile(String path) async {
    final content = await File(path).readAsString();
    return Backup.fromJsonString(content);
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
