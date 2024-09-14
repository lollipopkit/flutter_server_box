import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/backup.dart';
import 'package:server_box/data/store/no_backup.dart';

const bakSync = BakSyncer._();

final class BakSyncer extends SyncIface<Backup> {
  const BakSyncer._() : super();

  @override
  Future<void> saveToFile() => Backup.backup();

  @override
  Future<Backup> fromFile(String path) async {
    final content = await File(path).readAsString();
    return Backup.fromJsonString(content);
  }

  @override
  Future<RemoteStorage?> get remoteStorage async {
    if (isMacOS || isIOS) await icloud.init('iCloud.tech.lolli.serverbox');
    final settings = NoBackupStore.instance;
    await webdav.init(WebdavInitArgs(
      url: settings.webdavUrl.fetch(),
      user: settings.webdavUser.fetch(),
      pwd: settings.webdavPwd.fetch(),
      prefix: 'serverbox/',
    ));

    final icloudEnabled = settings.icloudSync.fetch();
    if (icloudEnabled) return icloud;

    final webdavEnabled = settings.webdavSync.fetch();
    if (webdavEnabled) return webdav;

    return null;
  }
}
