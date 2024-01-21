import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/data/store/container.dart';
import 'package:toolbox/data/store/history.dart';
import 'package:toolbox/data/store/private_key.dart';
import 'package:toolbox/data/store/server.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/data/store/snippet.dart';
import 'package:toolbox/locator.dart';

abstract final class Stores {
  static final setting = locator<SettingStore>();
  static final server = locator<ServerStore>();
  static final docker = locator<DockerStore>();
  static final history = locator<HistoryStore>();
  static final key = locator<PrivateKeyStore>();
  static final snippet = locator<SnippetStore>();

  static final List<PersistentStore> all = [
    setting,
    server,
    docker,
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
