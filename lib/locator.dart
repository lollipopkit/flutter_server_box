import 'package:get_it/get_it.dart';
import 'package:toolbox/data/provider/app.dart';
import 'package:toolbox/data/provider/debug.dart';
import 'package:toolbox/data/service/app.dart';
import 'package:toolbox/data/store/setting.dart';

GetIt locator = GetIt.instance;

void setupLocatorForServices() {
  locator.registerLazySingleton(() => AppService());
}

void setupLocatorForProviders() {
  locator.registerSingleton(AppProvider());
  locator.registerSingleton(DebugProvider());
}

Future<void> setupLocatorForStores() async {
  final setting = SettingStore();
  await setting.init(boxName: 'setting');
  locator.registerSingleton(setting);
}

Future<void> setupLocator() async {
  await setupLocatorForStores();
  setupLocatorForProviders();
  setupLocatorForServices();
}
