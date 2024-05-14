import 'package:fl_lib/fl_lib.dart';
import 'package:toolbox/data/store/container.dart';
import 'package:toolbox/data/store/history.dart';
import 'package:toolbox/data/store/private_key.dart';
import 'package:toolbox/data/store/server.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/data/store/snippet.dart';

abstract final class Stores {
  static final setting = SettingStore();
  static final server = ServerStore();
  static final container = ContainerStore();
  static final history = HistoryStore();
  static final key = PrivateKeyStore();
  static final snippet = SnippetStore();

  static final List<PersistentStore> all = [
    setting,
    server,
    container,
    history,
    key,
    snippet,
  ];

  static int? get lastModTime {
    int? lastModTime = 0;
    for (final store in all) {
      final last = store.box.lastModified ?? 0;
      if (last > (lastModTime ?? 0)) {
        lastModTime = last;
      }
    }
    return lastModTime;
  }
}
