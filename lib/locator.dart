import 'package:get_it/get_it.dart';
import 'package:toolbox/data/provider/app.dart';
import 'package:toolbox/data/provider/debug.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/service/app.dart';
import 'package:toolbox/data/store/server.dart';
import 'package:toolbox/data/store/setting.dart';

GetIt locator = GetIt.instance;

void setupLocatorForServices() {
  locator.registerLazySingleton(() => AppService());
}

void setupLocatorForProviders() {
  locator.registerSingleton(AppProvider());
  locator.registerSingleton(DebugProvider());
  locator.registerSingleton(ServerProvider());
}

Future<void> setupLocatorForStores() async {
  final setting = SettingStore();
  await setting.init(boxName: 'setting');
  locator.registerSingleton(setting);

  final server = ServerStore();
  await server.init(boxName: 'server');
  locator.registerSingleton(server);
}

Future<void> setupLocator() async {
  await setupLocatorForStores();
  setupLocatorForProviders();
  setupLocatorForServices();
}
