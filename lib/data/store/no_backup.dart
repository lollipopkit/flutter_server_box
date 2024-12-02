// ignore_for_file: non_constant_identifier_names

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/res/store.dart';

final class NoBackupStore extends HiveStore {
  NoBackupStore._() : super('no_backup');

  static final instance = NoBackupStore._();

  /// Only valid on iOS and macOS
  late final _icloudSync = propertyDefault('icloudSync', false);

  /// Webdav sync
  late final webdavSync = propertyDefault('webdavSync', false);
  late final webdavUrl = propertyDefault('webdavUrl', '');
  late final webdavUser = propertyDefault('webdavUser', '');
  late final webdavPwd = propertyDefault('webdavPwd', '');

  void migrate(int lastVer) {
    if (lastVer > 1104) return;

    // Settings store -> NoBackup store
    final settings = Stores.setting;
    final icloudSync_ = settings.box.get('icloudSync');
    if (icloudSync_ is bool) {
      _icloudSync.set(icloudSync_);
      settings.box.delete('icloudSync');
    }
    final webdavSync_ = settings.box.get('webdavSync');
    if (webdavSync_ is bool) {
      webdavSync.set(webdavSync_);
      settings.box.delete('webdavSync');
    }
    final webdavUrl_ = settings.box.get('webdavUrl');
    if (webdavUrl_ is String) {
      webdavUrl.set(webdavUrl_);
      settings.box.delete('webdavUrl');
    }
    final webdavUser_ = settings.box.get('webdavUser');
    if (webdavUser_ is String) {
      webdavUser.set(webdavUser_);
      settings.box.delete('webdavUser');
    }
    final webdavPwd_ = settings.box.get('webdavPwd');
    if (webdavPwd_ is String) {
      webdavPwd.set(webdavPwd_);
      settings.box.delete('webdavPwd');
    }

    // NoBackup store -> Pref store
    final icloudSync__ = _icloudSync.get();
    PrefProps.icloudSync.set(icloudSync__);
    _icloudSync.remove();

    final webdavSync__ = webdavSync.get();
    PrefProps.webdavSync.set(webdavSync__);
    webdavSync.remove();

    final webdavUrl__ = webdavUrl.get();
    PrefProps.webdavUrl.set(webdavUrl__);
    webdavUrl.remove();

    final webdavUser__ = webdavUser.get();
    PrefProps.webdavUser.set(webdavUser__);
    webdavUser.remove();

    final webdavPwd__ = webdavPwd.get();
    PrefProps.webdavPwd.set(webdavPwd__);
    webdavPwd.remove();
  }
}
