import 'package:flutter/material.dart';
import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/core/utils/platform.dart';

import '../model/app/net_view.dart';
import '../res/default.dart';

class SettingStore extends PersistentStore {
  // ------BEGIN------
  // These settings are not displayed in the settings page
  // You can edit them in the settings json editor (by long press the settings
  // item in the drawer of the server tab page)

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

  /// Record history of SFTP path and etc.
  late final recordHistory = StoreProperty(
    box,
    'recordHistory',
    true,
  );
  // ------END------

  /// Convert all settings into json
  Map<String, dynamic> toJson() => {for (var e in box.keys) e: box.get(e)};

  late final primaryColor = StoreProperty(
    box,
    'primaryColor',
    4287106639,
  );

  late final serverStatusUpdateInterval = StoreProperty(
    box,
    'serverStatusUpdateInterval',
    defaultUpdateInterval,
  );

  // Lanch page idx
  late final launchPage = StoreProperty(
    box,
    'launchPage',
    defaultLaunchPageIdx,
  );

  // Version of store db
  late final storeVersion = StoreProperty(box, 'storeVersion', 0);

  late final termColorIdx = StoreProperty(box, 'termColorIdx', 0);

  // Max retry count when connect to server
  late final maxRetryCount = StoreProperty(box, 'maxRetryCount', 2);

  // Night mode: 0 -> auto, 1 -> light, 2 -> dark
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
      StoreListProperty(box, 'detailCardPrder', defaultDetailCardOrder);

  // SSH term font size
  late final termFontSize = StoreProperty(box, 'termFontSize', 13.0);

  // Server detail disk ignore path
  late final diskIgnorePath =
      StoreListProperty(box, 'diskIgnorePath', defaultDiskIgnorePath);

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
    defaultEditorTheme,
  );

  late final editorDarkTheme = StoreProperty(
    box,
    'editorDarkTheme',
    defaultEditorDarkTheme,
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
    defaultSSHVirtKeys,
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

  /// Whether use `rm -rf` to delete directory on SFTP
  late final sftpRmrfDir = StoreProperty(
    box,
    'sftpRmrfDir',
    true,
  );

  /// Duration of [timeout]
  Duration get timeoutD => Duration(seconds: timeout.fetch());
}
