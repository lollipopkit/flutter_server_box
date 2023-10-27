import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/data/store/docker.dart';
import 'package:toolbox/data/store/history.dart';
import 'package:toolbox/data/store/private_key.dart';
import 'package:toolbox/data/store/server.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/data/store/snippet.dart';
import 'package:toolbox/locator.dart';

class Stores {
  const Stores._();

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
}
