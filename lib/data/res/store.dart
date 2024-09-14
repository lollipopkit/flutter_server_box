import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/no_backup.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';

abstract final class Stores {
  static final setting = SettingStore.instance;
  static final server = ServerStore.instance;
  static final container = ContainerStore.instance;
  static final key = PrivateKeyStore.instance;
  static final snippet = SnippetStore.instance;
  static final history = HistoryStore.instance;

  /// All stores that need backup
  static final List<PersistentStore> _allBackup = [
    SettingStore.instance,
    ServerStore.instance,
    ContainerStore.instance,
    PrivateKeyStore.instance,
    SnippetStore.instance,
    HistoryStore.instance,
  ];

  static Future<void> init() async {
    await Future.wait(_allBackup.map((store) => store.init()));
    await NoBackupStore.instance.init();
  }

  static int? get lastModTime {
    int? lastModTime = 0;
    for (final store in _allBackup) {
      final last = store.box.lastModified ?? 0;
      if (last > (lastModTime ?? 0)) {
        lastModTime = last;
      }
    }
    return lastModTime;
  }
}
