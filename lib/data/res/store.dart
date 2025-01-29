import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/history.dart';
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
  static final List<HiveStore> _allBackup = [
    SettingStore.instance,
    ServerStore.instance,
    ContainerStore.instance,
    PrivateKeyStore.instance,
    SnippetStore.instance,
    HistoryStore.instance,
  ];

  static Future<void> init() async {
    await Future.wait(_allBackup.map((store) => store.init()));
  }

  static DateTime? get lastModTime {
    DateTime? lastModTime;
    for (final store in _allBackup) {
      final last = store.lastUpdateTs;
      if (last == null) {
        continue;
      }
      if (lastModTime == null) {
        lastModTime = last;
      } else if (last.isAfter(lastModTime)) {
        lastModTime = last;
      }
    }
    return lastModTime;
  }
}
