import 'package:flutter/material.dart';
import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/core/utils/platform/base.dart';

import '../model/app/net_view.dart';
import '../res/default.dart';

class SettingStore extends PersistentStore {
  SettingStore() : super('setting');

  // ------BEGIN------
  //
  // These settings are not displayed in the settings page
  // You can edit them in the settings json editor (by long press the settings
  // item in the drawer of the home page)

  /// Discussion #146
  late final serverTabUseOldUI = StoreProperty(
    box,
    'serverTabUseOldUI',
    false,
  );

  /// Time out for server connect and more...
  late final timeout = StoreProperty(
    box,
    'timeOut',
    5,
  );

  /// Duration of [timeout]
  Duration get timeoutD => Duration(seconds: timeout.fetch());

  /// Record history of SFTP path and etc.
  late final recordHistory = StoreProperty(
    box,
    'recordHistory',
    true,
  );

  /// Bigger for bigger font size
  /// 1.0 means 100%
  /// Warning: This may cause some UI issues
  late final textFactor = StoreProperty(
    box,
    'textFactor',
    1.0,
  );

  /// Lanch page idx
  late final launchPage = StoreProperty(
    box,
    'launchPage',
    Defaults.launchPageIdx,
  );

  /// Server detail disk ignore path
  late final diskIgnorePath =
      StoreListProperty(box, 'diskIgnorePath', Defaults.diskIgnorePath);

  /// Use double column servers page on Desktop
  late final doubleColumnServersPage = StoreProperty(
    box,
    'doubleColumnServersPage',
    isDesktop,
  );

  // ------END------

  late final primaryColor = StoreProperty(
    box,
    'primaryColor',
    4287106639,
  );

  late final serverStatusUpdateInterval = StoreProperty(
    box,
    'serverStatusUpdateInterval',
    Defaults.updateInterval,
  );

  // Max retry count when connect to server
  late final maxRetryCount = StoreProperty(box, 'maxRetryCount', 2);

  // Night mode: 0 -> auto, 1 -> light, 2 -> dark, 3 -> AMOLED, 4 -> AUTO-AMOLED
  late final themeMode = StoreProperty(box, 'themeMode', 0);

  // Font file path
  late final fontPath = StoreProperty(box, 'fontPath', '');

  // Backgroud running (Android)
  late final bgRun = StoreProperty(box, 'bgRun', isAndroid);

  // Server order
  late final serverOrder = StoreListProperty<String>(box, 'serverOrder', []);

  late final snippetOrder = StoreListProperty<String>(box, 'snippetOrder', []);

  // Server details page cards order
  late final detailCardOrder =
      StoreListProperty(box, 'detailCardPrder', Defaults.detailCardOrder);

  // SSH term font size
  late final termFontSize = StoreProperty(box, 'termFontSize', 13.0);

  // Locale
  late final locale = StoreProperty<String>(box, 'locale', '');

  // SSH virtual key (ctrl | alt) auto turn off
  late final sshVirtualKeyAutoOff =
      StoreProperty(box, 'sshVirtualKeyAutoOff', true);

  late final editorFontSize = StoreProperty(box, 'editorFontSize', 13.0);

  // Editor theme
  late final editorTheme = StoreProperty(
    box,
    'editorTheme',
    Defaults.editorTheme,
  );

  late final editorDarkTheme = StoreProperty(
    box,
    'editorDarkTheme',
    Defaults.editorDarkTheme,
  );

  late final fullScreen = StoreProperty(
    box,
    'fullScreen',
    false,
  );

  late final fullScreenJitter = StoreProperty(
    box,
    'fullScreenJitter',
    true,
  );

  late final fullScreenRotateQuarter = StoreProperty(
    box,
    'fullScreenRotateQuarter',
    1,
  );

  late final keyboardType = StoreProperty(
    box,
    'keyboardType',
    TextInputType.text.index,
  );

  late final sshVirtKeys = StoreListProperty(
    box,
    'sshVirtKeys',
    Defaults.sshVirtKeys,
  );

  late final netViewType = StoreProperty(
    box,
    'netViewType',
    NetViewType.speed,
  );

  // Only valid on iOS
  late final autoUpdateHomeWidget = StoreProperty(
    box,
    'autoUpdateHomeWidget',
    isIOS,
  );

  late final autoCheckAppUpdate = StoreProperty(
    box,
    'autoCheckAppUpdate',
    true,
  );

  /// Display server tab function buttons on the bottom of each server card if [true]
  ///
  /// Otherwise, display them on the top of server detail page
  late final moveOutServerTabFuncBtns = StoreProperty(
    box,
    'moveOutServerTabFuncBtns',
    true,
  );

  /// Whether use `rm -r` to delete directory on SFTP
  late final sftpRmrDir = StoreProperty(
    box,
    'sftpRmrDir',
    false,
  );

  /// Whether use system's primary color as the app's primary color
  late final useSystemPrimaryColor = StoreProperty(
    box,
    'useSystemPrimaryColor',
    false,
  );

  /// Only valid on iOS and macOS
  late final icloudSync = StoreProperty(
    box,
    'icloudSync',
    false,
  );

  /// Only valid on iOS / Android / Windows
  late final useBioAuth = StoreProperty(
    box,
    'useBioAuth',
    false,
  );

  /// The performance of highlight is bad
  late final editorHighlight = StoreProperty(box, 'editorHighlight', true);

  /// Open SFTP with last viewed path
  late final sftpOpenLastPath = StoreProperty(box, 'sftpOpenLastPath', true);

  /// Show tip of suspend
  late final showSuspendTip = StoreProperty(box, 'showSuspendTip', true);

  /// Server func btns display name
  late final serverFuncBtnsDisplayName =
      StoreProperty(box, 'serverFuncBtnsDisplayName', true);

  // Never show these settings for users
  //
  // ------BEGIN------

  /// Version of store db
  late final storeVersion = StoreProperty(box, 'storeVersion', 0);

  // ------END------
}
