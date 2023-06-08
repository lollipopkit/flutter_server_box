import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/core/utils/platform.dart';

import '../res/default.dart';

class SettingStore extends PersistentStore {
  StoreProperty<int> get primaryColor => property(
        'primaryColor',
        defaultValue: 4287106639,
      );

  StoreProperty<int> get serverStatusUpdateInterval => property(
        'serverStatusUpdateInterval',
        defaultValue: defaultUpdateInterval,
      );

  // Lanch page idx
  StoreProperty<int> get launchPage => property(
        'launchPage',
        defaultValue: defaultLaunchPageIdx,
      );

  // Version of store db
  StoreProperty<int> get storeVersion =>
      property('storeVersion', defaultValue: 0);

  StoreProperty<int> get termColorIdx =>
      property('termColorIdx', defaultValue: 0);

  // Max retry count when connect to server
  StoreProperty<int> get maxRetryCount =>
      property('maxRetryCount', defaultValue: 2);

  // Night mode: 0 -> auto, 1 -> light, 2 -> dark
  StoreProperty<int> get themeMode => property('themeMode', defaultValue: 0);

  // Font file path
  StoreProperty<String> get fontPath => property('fontPath');

  // Backgroud running (Android)
  StoreProperty<bool> get bgRun => property('bgRun', defaultValue: isAndroid);

  // Server order
  StoreProperty<List<String>> get serverOrder =>
      property('serverOrder', defaultValue: null);

  // Server details page cards order
  StoreProperty<List<String>> get detailCardOrder =>
      property('detailCardPrder', defaultValue: defaultDetailCardOrder);

  // SSH term font size
  StoreProperty<double> get termFontSize =>
      property('termFontSize', defaultValue: 13);

  // Server detail disk ignore path
  StoreProperty<List<String>> get diskIgnorePath =>
      property('diskIgnorePath', defaultValue: defaultDiskIgnorePath);

  // Locale
  StoreProperty<String> get locale => property('locale', defaultValue: null);

  // SSH virtual key (ctrl | alt) auto turn off
  StoreProperty<bool> get sshVirtualKeyAutoOff =>
      property('sshVirtualKeyAutoOff', defaultValue: true);

  // Editor theme
  StoreProperty<String> get editorTheme =>
      property('editorTheme', defaultValue: defaultEditorTheme);

  StoreProperty<bool> get fullScreen =>
      property('fullScreen', defaultValue: false);
}
