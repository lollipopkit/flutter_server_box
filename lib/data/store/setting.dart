import 'package:flutter/material.dart';
import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/data/model/app/menu/server_func.dart';

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
  late final serverTabUseOldUI = property(
    'serverTabUseOldUI',
    false,
  );

  /// Time out for server connect and more...
  late final timeout = property(
    'timeOut',
    5,
  );

  /// Record history of SFTP path and etc.
  late final recordHistory = property(
    'recordHistory',
    true,
  );

  /// Lanch page idx
  late final launchPage = property(
    'launchPage',
    Defaults.launchPageIdx,
  );

  /// Server detail disk ignore path
  late final diskIgnorePath =
      property('diskIgnorePath', Defaults.diskIgnorePath);

  /// Use double column servers page on Desktop
  // late final doubleColumnServersPage = property(
  //   'doubleColumnServersPage',
  //   isDesktop,
  // );

  /// Disk view: amount / IO
  late final serverTabPreferDiskAmount = property(
    'serverTabPreferDiskAmount',
    false,
  );

  // ------END------

  /// Bigger for bigger font size
  /// 1.0 means 100%
  /// Warning: This may cause some UI issues
  late final textFactor = property(
    'textFactor',
    1.0,
  );

  late final primaryColor = property(
    'primaryColor',
    4287106639,
  );

  late final serverStatusUpdateInterval = property(
    'serverStatusUpdateInterval',
    Defaults.updateInterval,
  );

  // Max retry count when connect to server
  late final maxRetryCount = property('maxRetryCount', 2);

  // Night mode: 0 -> auto, 1 -> light, 2 -> dark, 3 -> AMOLED, 4 -> AUTO-AMOLED
  late final themeMode = property('themeMode', 0);

  // Font file path
  late final fontPath = property('fontPath', '');

  // Backgroud running (Android)
  late final bgRun = property('bgRun', isAndroid);

  // Server order
  late final serverOrder = listProperty<String>('serverOrder', []);

  late final snippetOrder = listProperty<String>('snippetOrder', []);

  // Server details page cards order
  late final detailCardOrder =
      listProperty('detailCardOrder', Defaults.detailCardOrder);

  // SSH term font size
  late final termFontSize = property('termFontSize', 13.0);

  // Locale
  late final locale = property('locale', '');

  // SSH virtual key (ctrl | alt) auto turn off
  late final sshVirtualKeyAutoOff = property('sshVirtualKeyAutoOff', true);

  late final editorFontSize = property('editorFontSize', 13.0);

  // Editor theme
  late final editorTheme = property(
    'editorTheme',
    Defaults.editorTheme,
  );

  late final editorDarkTheme = property(
    'editorDarkTheme',
    Defaults.editorDarkTheme,
  );

  // late final fullScreen = property(
  //   'fullScreen',
  //   false,
  // );

  // late final fullScreenJitter = property(
  //   'fullScreenJitter',
  //   true,
  // );

  // late final fullScreenRotateQuarter = property(
  //   'fullScreenRotateQuarter',
  //   1,
  // );

  late final keyboardType = property(
    'keyboardType',
    TextInputType.text.index,
  );

  late final sshVirtKeys = listProperty(
    'sshVirtKeys',
    Defaults.sshVirtKeys.map((e) => e.index).toList(),
  );

  late final netViewType = property(
    'netViewType',
    NetViewType.speed,
  );

  // Only valid on iOS
  late final autoUpdateHomeWidget = property(
    'autoUpdateHomeWidget',
    isIOS,
  );

  late final autoCheckAppUpdate = property(
    'autoCheckAppUpdate',
    true,
  );

  /// Display server tab function buttons on the bottom of each server card if [true]
  ///
  /// Otherwise, display them on the top of server detail page
  late final moveOutServerTabFuncBtns = property(
    'moveOutServerTabFuncBtns',
    true,
  );

  /// Whether use `rm -r` to delete directory on SFTP
  late final sftpRmrDir = property(
    'sftpRmrDir',
    false,
  );

  /// Whether use system's primary color as the app's primary color
  late final useSystemPrimaryColor = property(
    'useSystemPrimaryColor',
    false,
  );

  /// Only valid on iOS and macOS
  late final icloudSync = property(
    'icloudSync',
    false,
  );

  /// Only valid on iOS / Android / Windows
  late final useBioAuth = property(
    'useBioAuth',
    false,
  );

  /// The performance of highlight is bad
  late final editorHighlight = property('editorHighlight', true);

  /// Open SFTP with last viewed path
  late final sftpOpenLastPath = property('sftpOpenLastPath', true);

  /// Show folders first in SFTP file browser
  late final sftpShowFoldersFirst = property('sftpShowFoldersFirst', true);

  /// Show tip of suspend
  late final showSuspendTip = property('showSuspendTip', true);

  /// Webdav sync
  late final webdavSync = property('webdavSync', false);
  late final webdavUrl = property('webdavUrl', '');
  late final webdavUser = property('webdavUser', '');
  late final webdavPwd = property('webdavPwd', '');

  /// Whether collapse UI items by default
  late final collapseUIDefault = property('collapseUIDefault', true);

  late final serverFuncBtns = listProperty(
    'serverBtns',
    [
      ServerFuncBtn.terminal,
      ServerFuncBtn.sftp,
      ServerFuncBtn.container,
      ServerFuncBtn.process,
      ServerFuncBtn.pkg,
      ServerFuncBtn.snippet,
    ].map((e) => e.index).toList(),
  );

  // Never show these settings for users
  //
  // ------BEGIN------

  /// Version of store db
  late final storeVersion = property('storeVersion', 0);

  // ------END------
}
