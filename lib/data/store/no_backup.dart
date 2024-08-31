import 'package:fl_lib/fl_lib.dart';

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
}
