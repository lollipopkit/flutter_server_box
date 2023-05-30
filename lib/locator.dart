import 'package:get_it/get_it.dart';

import 'data/provider/app.dart';
import 'data/provider/debug.dart';
import 'data/provider/docker.dart';
import 'data/provider/pkg.dart';
import 'data/provider/private_key.dart';
import 'data/provider/server.dart';
import 'data/provider/sftp.dart';
import 'data/provider/snippet.dart';
import 'data/provider/virtual_keyboard.dart';
import 'data/service/app.dart';
import 'data/store/docker.dart';
import 'data/store/private_key.dart';
import 'data/store/server.dart';
import 'data/store/setting.dart';
import 'data/store/snippet.dart';

GetIt locator = GetIt.instance;

void setupLocatorForServices() {
  locator.registerLazySingleton(() => AppService());
}

void setupLocatorForProviders() {
  locator.registerSingleton(AppProvider());
  locator.registerSingleton(PkgProvider());
  locator.registerSingleton(DebugProvider());
  locator.registerSingleton(DockerProvider());
  locator.registerSingleton(ServerProvider());
  locator.registerSingleton(VirtualKeyboard());
  locator.registerSingleton(SnippetProvider());
  locator.registerSingleton(PrivateKeyProvider());
  locator.registerSingleton(SftpProvider());
}

Future<void> setupLocatorForStores() async {
  final setting = SettingStore();
  await setting.init(boxName: 'setting');
  locator.registerSingleton(setting);

  final server = ServerStore();
  await server.init(boxName: 'server');
  locator.registerSingleton(server);

  final key = PrivateKeyStore();
  await key.init(boxName: 'key');
  locator.registerSingleton(key);

  final snippet = SnippetStore();
  await snippet.init(boxName: 'snippet');
  locator.registerSingleton(snippet);

  final docker = DockerStore();
  await docker.init(boxName: 'docker');
  locator.registerSingleton(docker);
}

Future<void> setupLocator() async {
  await setupLocatorForStores();
  setupLocatorForProviders();
  setupLocatorForServices();
}
