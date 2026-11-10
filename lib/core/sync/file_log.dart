import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/sync/remotes.dart';
import 'package:server_box/core/sync/sync.dart';

/// fl_lib's segment sync while the backup syncs to WebDAV or iCloud, in
/// `<prefix>srvbox_sync/` beside the backup.
final fileLog = FileLogSync(
  remote: () => bakSync.remoteStorage,
  folder: 'srvbox_sync',
  on: () => (PrefProps.icloudSync.get() && isICloudSupported) || PrefProps.webdavSync.get(),
  // "null" without a user: the id the shipped builds made, so the store is
  // the one they joined.
  webdavAccount: () => SyncRemotes.webdavUser ?? 'null',
  changes: [PrefProps.icloudSync.listenable(), PrefProps.webdavSync.listenable()],
);
