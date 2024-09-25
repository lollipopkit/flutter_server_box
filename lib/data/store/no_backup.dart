import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';

final class NoBackupStore extends PersistentStore {
  NoBackupStore._() : super('no_backup');

  static final instance = NoBackupStore._();

  /// Only valid on iOS and macOS
  late final icloudSync = property('icloudSync', false);

  /// Webdav sync
  late final webdavSync = property('webdavSync', false);
  late final webdavUrl = property('webdavUrl', '');
  late final webdavUser = property('webdavUser', '');
  late final webdavPwd = property('webdavPwd', '');

  void migrate() {
    if (BuildData.build > 1076) return;

    final settings = Stores.setting;
    final icloudSync_ = settings.box.get('icloudSync');
    if (icloudSync_ is bool) {
      icloudSync.put(icloudSync_);
      settings.box.delete('icloudSync');
    }
    final webdavSync_ = settings.box.get('webdavSync');
    if (webdavSync_ is bool) {
      webdavSync.put(webdavSync_);
      settings.box.delete('webdavSync');
    }
    final webdavUrl_ = settings.box.get('webdavUrl');
    if (webdavUrl_ is String) {
      webdavUrl.put(webdavUrl_);
      settings.box.delete('webdavUrl');
    }
    final webdavUser_ = settings.box.get('webdavUser');
    if (webdavUser_ is String) {
      webdavUser.put(webdavUser_);
      settings.box.delete('webdavUser');
    }
    final webdavPwd_ = settings.box.get('webdavPwd');
    if (webdavPwd_ is String) {
      webdavPwd.put(webdavPwd_);
      settings.box.delete('webdavPwd');
    }
  }
}
