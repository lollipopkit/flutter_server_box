import 'package:get_it/get_it.dart';
import 'package:toolbox/data/provider/app.dart';
import 'package:toolbox/data/provider/apt.dart';
import 'package:toolbox/data/provider/debug.dart';
import 'package:toolbox/data/provider/docker.dart';
import 'package:toolbox/data/provider/private_key.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/provider/snippet.dart';
import 'package:toolbox/data/service/app.dart';
import 'package:toolbox/data/store/private_key.dart';
import 'package:toolbox/data/store/server.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/data/store/snippet.dart';

GetIt locator = GetIt.instance;

void setupLocatorForServices() {
  locator.registerLazySingleton(() => AppService());
}

void setupLocatorForProviders() {
  locator.registerSingleton(AppProvider());
  locator.registerSingleton(AptProvider());
  locator.registerSingleton(DebugProvider());
  locator.registerSingleton(DockerProvider());
  locator.registerSingleton(ServerProvider());
  locator.registerSingleton(SnippetProvider());
  locator.registerSingleton(PrivateKeyProvider());
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
}

Future<void> setupLocator() async {
  await setupLocatorForStores();
  setupLocatorForProviders();
  setupLocatorForServices();
}
