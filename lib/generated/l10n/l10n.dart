import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_de.dart';
import 'l10n_en.dart';
import 'l10n_es.dart';
import 'l10n_fr.dart';
import 'l10n_id.dart';
import 'l10n_ja.dart';
import 'l10n_nl.dart';
import 'l10n_pt.dart';
import 'l10n_ru.dart';
import 'l10n_tr.dart';
import 'l10n_uk.dart';
import 'l10n_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('id'),
    Locale('ja'),
    Locale('nl'),
    Locale('pt'),
    Locale('ru'),
    Locale('tr'),
    Locale('uk'),
    Locale('zh'),
    Locale('zh', 'TW')
  ];

  /// No description provided for @aboutThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks to the following people who participated in.'**
  String get aboutThanks;

  /// No description provided for @acceptBeta.
  ///
  /// In en, this message translates to:
  /// **'Accept beta version updates'**
  String get acceptBeta;

  /// No description provided for @addSystemPrivateKeyTip.
  ///
  /// In en, this message translates to:
  /// **'Currently private keys don\'t exist, do you want to add the one that comes with the system (~/.ssh/id_rsa)?'**
  String get addSystemPrivateKeyTip;

  /// No description provided for @added2List.
  ///
  /// In en, this message translates to:
  /// **'Added to task list'**
  String get added2List;

  /// No description provided for @addr.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addr;

  /// No description provided for @alreadyLastDir.
  ///
  /// In en, this message translates to:
  /// **'Already in last directory.'**
  String get alreadyLastDir;

  /// No description provided for @authFailTip.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed, please check whether credentials are correct'**
  String get authFailTip;

  /// No description provided for @autoBackupConflict.
  ///
  /// In en, this message translates to:
  /// **'Only one automatic backup can be turned on at the same time.'**
  String get autoBackupConflict;

  /// No description provided for @autoConnect.
  ///
  /// In en, this message translates to:
  /// **'Auto connect'**
  String get autoConnect;

  /// No description provided for @autoRun.
  ///
  /// In en, this message translates to:
  /// **'Auto run'**
  String get autoRun;

  /// No description provided for @autoUpdateHomeWidget.
  ///
  /// In en, this message translates to:
  /// **'Automatic home widget update'**
  String get autoUpdateHomeWidget;

  /// No description provided for @backupTip.
  ///
  /// In en, this message translates to:
  /// **'The exported data is weakly encrypted. \nPlease keep it safe.'**
  String get backupTip;

  /// No description provided for @backupVersionNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Backup version is not match.'**
  String get backupVersionNotMatch;

  /// No description provided for @battery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get battery;

  /// No description provided for @bgRun.
  ///
  /// In en, this message translates to:
  /// **'Run in background'**
  String get bgRun;

  /// No description provided for @bgRunTip.
  ///
  /// In en, this message translates to:
  /// **'This switch only means the program will try to run in the background. Whether it can run in the background depends on whether the permission is enabled or not. For AOSP-based Android ROMs, please disable \"Battery Optimization\" in this app. For MIUI / HyperOS, please change the power saving policy to \"Unlimited\".'**
  String get bgRunTip;

  /// No description provided for @closeAfterSave.
  ///
  /// In en, this message translates to:
  /// **'Save and close'**
  String get closeAfterSave;

  /// No description provided for @cmd.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get cmd;

  /// No description provided for @collapseUITip.
  ///
  /// In en, this message translates to:
  /// **'Whether to collapse long lists present in the UI by default'**
  String get collapseUITip;

  /// No description provided for @conn.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get conn;

  /// No description provided for @container.
  ///
  /// In en, this message translates to:
  /// **'Container'**
  String get container;

  /// No description provided for @containerTrySudoTip.
  ///
  /// In en, this message translates to:
  /// **'For example: In the app, the user is set to aaa, but Docker is installed under the root user. In this case, you need to enable this option.'**
  String get containerTrySudoTip;

  /// No description provided for @convert.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get convert;

  /// No description provided for @copyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get copyPath;

  /// No description provided for @cpuViewAsProgressTip.
  ///
  /// In en, this message translates to:
  /// **'Display the usage of each CPU in a progress bar style (old style)'**
  String get cpuViewAsProgressTip;

  /// No description provided for @cursorType.
  ///
  /// In en, this message translates to:
  /// **'Cursor type'**
  String get cursorType;

  /// No description provided for @customCmd.
  ///
  /// In en, this message translates to:
  /// **'Custom commands'**
  String get customCmd;

  /// No description provided for @customCmdDocUrl.
  ///
  /// In en, this message translates to:
  /// **'https://github.com/lollipopkit/flutter_server_box/wiki#custom-commands'**
  String get customCmdDocUrl;

  /// No description provided for @customCmdHint.
  ///
  /// In en, this message translates to:
  /// **'\"Command Name\": \"Command\"'**
  String get customCmdHint;

  /// No description provided for @decode.
  ///
  /// In en, this message translates to:
  /// **'Decode'**
  String get decode;

  /// No description provided for @decompress.
  ///
  /// In en, this message translates to:
  /// **'Decompress'**
  String get decompress;

  /// No description provided for @deleteServers.
  ///
  /// In en, this message translates to:
  /// **'Batch delete servers'**
  String get deleteServers;

  /// No description provided for @dirEmpty.
  ///
  /// In en, this message translates to:
  /// **'Make sure the folder is empty.'**
  String get dirEmpty;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @disk.
  ///
  /// In en, this message translates to:
  /// **'Disk'**
  String get disk;

  /// No description provided for @diskIgnorePath.
  ///
  /// In en, this message translates to:
  /// **'Ignore path for disk'**
  String get diskIgnorePath;

  /// No description provided for @displayCpuIndex.
  ///
  /// In en, this message translates to:
  /// **'Display CPU index'**
  String get displayCpuIndex;

  /// No description provided for @dl2Local.
  ///
  /// In en, this message translates to:
  /// **'Download {fileName} to local?'**
  String dl2Local(Object fileName);

  /// No description provided for @dockerEmptyRunningItems.
  ///
  /// In en, this message translates to:
  /// **'There are no running containers.\nThis could be because:\n- The Docker installation user is not the same as the username configured within the App.\n- The environment variable DOCKER_HOST was not read correctly. You can get it by running `echo \$DOCKER_HOST` in the terminal.'**
  String get dockerEmptyRunningItems;

  /// No description provided for @dockerImagesFmt.
  ///
  /// In en, this message translates to:
  /// **'{count} images'**
  String dockerImagesFmt(Object count);

  /// No description provided for @dockerNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Docker not installed'**
  String get dockerNotInstalled;

  /// No description provided for @dockerStatusRunningAndStoppedFmt.
  ///
  /// In en, this message translates to:
  /// **'{runningCount} running, {stoppedCount} container stopped.'**
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount);

  /// No description provided for @dockerStatusRunningFmt.
  ///
  /// In en, this message translates to:
  /// **'{count} container running.'**
  String dockerStatusRunningFmt(Object count);

  /// No description provided for @doubleColumnMode.
  ///
  /// In en, this message translates to:
  /// **'Double column mode'**
  String get doubleColumnMode;

  /// No description provided for @doubleColumnTip.
  ///
  /// In en, this message translates to:
  /// **'This option only enables the feature, whether it can actually be enabled depends on the width of the device'**
  String get doubleColumnTip;

  /// No description provided for @editVirtKeys.
  ///
  /// In en, this message translates to:
  /// **'Edit virtual keys'**
  String get editVirtKeys;

  /// No description provided for @editor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get editor;

  /// No description provided for @editorHighlightTip.
  ///
  /// In en, this message translates to:
  /// **'The current code highlighting performance is not ideal and can be optionally turned off to improve.'**
  String get editorHighlightTip;

  /// No description provided for @encode.
  ///
  /// In en, this message translates to:
  /// **'Encode'**
  String get encode;

  /// No description provided for @envVars.
  ///
  /// In en, this message translates to:
  /// **'Environment variable'**
  String get envVars;

  /// No description provided for @experimentalFeature.
  ///
  /// In en, this message translates to:
  /// **'Experimental feature'**
  String get experimentalFeature;

  /// No description provided for @extraArgs.
  ///
  /// In en, this message translates to:
  /// **'Extra arguments'**
  String get extraArgs;

  /// No description provided for @fallbackSshDest.
  ///
  /// In en, this message translates to:
  /// **'Fallback SSH destination'**
  String get fallbackSshDest;

  /// No description provided for @fdroidReleaseTip.
  ///
  /// In en, this message translates to:
  /// **'If you downloaded this app from F-Droid, it is recommended to turn off this option.'**
  String get fdroidReleaseTip;

  /// No description provided for @fgService.
  ///
  /// In en, this message translates to:
  /// **'Foreground Service'**
  String get fgService;

  /// No description provided for @fgServiceTip.
  ///
  /// In en, this message translates to:
  /// **'After enabling, some device models may crash. Disabling it may cause some models to be unable to maintain SSH connections in the background. Please allow ServerBox notification permissions, background running, and self-wake-up in system settings.'**
  String get fgServiceTip;

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File \'{file}\' too large {size}, max {sizeMax}'**
  String fileTooLarge(Object file, Object size, Object sizeMax);

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @font.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get font;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @force.
  ///
  /// In en, this message translates to:
  /// **'Force'**
  String get force;

  /// No description provided for @fullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen mode'**
  String get fullScreen;

  /// No description provided for @fullScreenJitter.
  ///
  /// In en, this message translates to:
  /// **'Full screen jitter'**
  String get fullScreenJitter;

  /// No description provided for @fullScreenJitterHelp.
  ///
  /// In en, this message translates to:
  /// **'To avoid screen burn-in'**
  String get fullScreenJitterHelp;

  /// No description provided for @fullScreenTip.
  ///
  /// In en, this message translates to:
  /// **'Should full-screen mode be enabled when the device is rotated to landscape mode? This option only applies to the server tab.'**
  String get fullScreenTip;

  /// No description provided for @goBackQ.
  ///
  /// In en, this message translates to:
  /// **'Go back?'**
  String get goBackQ;

  /// No description provided for @goto.
  ///
  /// In en, this message translates to:
  /// **'Go to'**
  String get goto;

  /// No description provided for @hideTitleBar.
  ///
  /// In en, this message translates to:
  /// **'Hide title bar'**
  String get hideTitleBar;

  /// No description provided for @highlight.
  ///
  /// In en, this message translates to:
  /// **'Code highlighting'**
  String get highlight;

  /// No description provided for @homeWidgetUrlConfig.
  ///
  /// In en, this message translates to:
  /// **'Config home widget url'**
  String get homeWidgetUrlConfig;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @httpFailedWithCode.
  ///
  /// In en, this message translates to:
  /// **'request failed, status code: {code}'**
  String httpFailedWithCode(Object code);

  /// No description provided for @ignoreCert.
  ///
  /// In en, this message translates to:
  /// **'Ignore certificate'**
  String get ignoreCert;

  /// No description provided for @image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// No description provided for @imagesList.
  ///
  /// In en, this message translates to:
  /// **'Images list'**
  String get imagesList;

  /// No description provided for @init.
  ///
  /// In en, this message translates to:
  /// **'Initialize'**
  String get init;

  /// No description provided for @inner.
  ///
  /// In en, this message translates to:
  /// **'Inner'**
  String get inner;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'install'**
  String get install;

  /// No description provided for @installDockerWithUrl.
  ///
  /// In en, this message translates to:
  /// **'Please https://docs.docker.com/engine/install docker first.'**
  String get installDockerWithUrl;

  /// No description provided for @invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get invalid;

  /// No description provided for @jumpServer.
  ///
  /// In en, this message translates to:
  /// **'Jump server'**
  String get jumpServer;

  /// No description provided for @keepForeground.
  ///
  /// In en, this message translates to:
  /// **'Keep app foreground!'**
  String get keepForeground;

  /// No description provided for @keepStatusWhenErr.
  ///
  /// In en, this message translates to:
  /// **'Preserve the last server state'**
  String get keepStatusWhenErr;

  /// No description provided for @keepStatusWhenErrTip.
  ///
  /// In en, this message translates to:
  /// **'Only in the event of an error during script execution'**
  String get keepStatusWhenErrTip;

  /// No description provided for @keyAuth.
  ///
  /// In en, this message translates to:
  /// **'Key Auth'**
  String get keyAuth;

  /// No description provided for @letterCache.
  ///
  /// In en, this message translates to:
  /// **'Letter caching'**
  String get letterCache;

  /// No description provided for @letterCacheTip.
  ///
  /// In en, this message translates to:
  /// **'Recommended to disable, but after disabling, it will be impossible to input CJK characters.'**
  String get letterCacheTip;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @loss.
  ///
  /// In en, this message translates to:
  /// **'loss'**
  String get loss;

  /// No description provided for @madeWithLove.
  ///
  /// In en, this message translates to:
  /// **'Made with ❤️ by {myGithub}'**
  String madeWithLove(Object myGithub);

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manual;

  /// No description provided for @max.
  ///
  /// In en, this message translates to:
  /// **'max'**
  String get max;

  /// No description provided for @maxRetryCount.
  ///
  /// In en, this message translates to:
  /// **'Number of server reconnections'**
  String get maxRetryCount;

  /// No description provided for @maxRetryCountEqual0.
  ///
  /// In en, this message translates to:
  /// **'Will retry again and again.'**
  String get maxRetryCountEqual0;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get min;

  /// No description provided for @mission.
  ///
  /// In en, this message translates to:
  /// **'Mission'**
  String get mission;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @moveOutServerFuncBtnsHelp.
  ///
  /// In en, this message translates to:
  /// **'On: can be displayed below each card on the Server Tab page. Off: can be displayed at the top of the Server Details page.'**
  String get moveOutServerFuncBtnsHelp;

  /// No description provided for @ms.
  ///
  /// In en, this message translates to:
  /// **'ms'**
  String get ms;

  /// No description provided for @needHomeDir.
  ///
  /// In en, this message translates to:
  /// **'If you are a Synology user, [see here](https://kb.synology.com/DSM/tutorial/user_enable_home_service). Users of other systems need to search for how to create a home directory.'**
  String get needHomeDir;

  /// No description provided for @needRestart.
  ///
  /// In en, this message translates to:
  /// **'App needs to be restarted'**
  String get needRestart;

  /// No description provided for @net.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get net;

  /// No description provided for @netViewType.
  ///
  /// In en, this message translates to:
  /// **'Network view type'**
  String get netViewType;

  /// No description provided for @newContainer.
  ///
  /// In en, this message translates to:
  /// **'New container'**
  String get newContainer;

  /// No description provided for @noLineChart.
  ///
  /// In en, this message translates to:
  /// **'Do not use line charts'**
  String get noLineChart;

  /// No description provided for @noLineChartForCpu.
  ///
  /// In en, this message translates to:
  /// **'Do not use line charts for CPU'**
  String get noLineChartForCpu;

  /// No description provided for @noPrivateKeyTip.
  ///
  /// In en, this message translates to:
  /// **'The private key does not exist, it may have been deleted or there is a configuration error.'**
  String get noPrivateKeyTip;

  /// No description provided for @noPromptAgain.
  ///
  /// In en, this message translates to:
  /// **'Do not prompt again'**
  String get noPromptAgain;

  /// No description provided for @node.
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get node;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get notAvailable;

  /// No description provided for @onServerDetailPage.
  ///
  /// In en, this message translates to:
  /// **'On server detail page'**
  String get onServerDetailPage;

  /// No description provided for @onlyOneLine.
  ///
  /// In en, this message translates to:
  /// **'Only display as one line (scrollable)'**
  String get onlyOneLine;

  /// No description provided for @onlyWhenCoreBiggerThan8.
  ///
  /// In en, this message translates to:
  /// **'Works only when the number of cores is greater than 8'**
  String get onlyWhenCoreBiggerThan8;

  /// No description provided for @openLastPath.
  ///
  /// In en, this message translates to:
  /// **'Open the last path'**
  String get openLastPath;

  /// No description provided for @openLastPathTip.
  ///
  /// In en, this message translates to:
  /// **'Different servers will have different logs, and the log is the path to the exit'**
  String get openLastPathTip;

  /// No description provided for @parseContainerStatsTip.
  ///
  /// In en, this message translates to:
  /// **'Parsing the occupancy status of Docker is relatively slow.'**
  String get parseContainerStatsTip;

  /// No description provided for @percentOfSize.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of {size}'**
  String percentOfSize(Object percent, Object size);

  /// No description provided for @permission.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permission;

  /// No description provided for @pingAvg.
  ///
  /// In en, this message translates to:
  /// **'Avg:'**
  String get pingAvg;

  /// No description provided for @pingInputIP.
  ///
  /// In en, this message translates to:
  /// **'Please input a target IP / domain.'**
  String get pingInputIP;

  /// No description provided for @pingNoServer.
  ///
  /// In en, this message translates to:
  /// **'No server to ping.\nPlease add a server in server tab.'**
  String get pingNoServer;

  /// No description provided for @pkg.
  ///
  /// In en, this message translates to:
  /// **'Pkg'**
  String get pkg;

  /// No description provided for @plugInType.
  ///
  /// In en, this message translates to:
  /// **'Insertion Type'**
  String get plugInType;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @privateKey.
  ///
  /// In en, this message translates to:
  /// **'Private Key'**
  String get privateKey;

  /// No description provided for @process.
  ///
  /// In en, this message translates to:
  /// **'Process'**
  String get process;

  /// No description provided for @pushToken.
  ///
  /// In en, this message translates to:
  /// **'Push token'**
  String get pushToken;

  /// No description provided for @pveIgnoreCertTip.
  ///
  /// In en, this message translates to:
  /// **'Not recommended to enable, beware of security risks! If you are using the default certificate from PVE, you need to enable this option.'**
  String get pveIgnoreCertTip;

  /// No description provided for @pveLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Unable to authenticate with username/password from server configuration for Linux PAM login.'**
  String get pveLoginFailed;

  /// No description provided for @pveVersionLow.
  ///
  /// In en, this message translates to:
  /// **'This feature is currently in the testing phase and has only been tested on PVE 8+. Please use it with caution.'**
  String get pveVersionLow;

  /// No description provided for @pwd.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get pwd;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @reboot.
  ///
  /// In en, this message translates to:
  /// **'Reboot'**
  String get reboot;

  /// No description provided for @rememberPwdInMem.
  ///
  /// In en, this message translates to:
  /// **'Remember password in memory'**
  String get rememberPwdInMem;

  /// No description provided for @rememberPwdInMemTip.
  ///
  /// In en, this message translates to:
  /// **'Used for containers, suspending, etc.'**
  String get rememberPwdInMemTip;

  /// No description provided for @rememberWindowSize.
  ///
  /// In en, this message translates to:
  /// **'Remember window size'**
  String get rememberWindowSize;

  /// No description provided for @remotePath.
  ///
  /// In en, this message translates to:
  /// **'Remote path'**
  String get remotePath;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @result.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get result;

  /// No description provided for @rotateAngel.
  ///
  /// In en, this message translates to:
  /// **'Rotation angle'**
  String get rotateAngel;

  /// No description provided for @route.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get route;

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @sameIdServerExist.
  ///
  /// In en, this message translates to:
  /// **'A server with the same ID already exists'**
  String get sameIdServerExist;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @second.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get second;

  /// No description provided for @sensors.
  ///
  /// In en, this message translates to:
  /// **'Sensor'**
  String get sensors;

  /// No description provided for @sequence.
  ///
  /// In en, this message translates to:
  /// **'Sequence'**
  String get sequence;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @serverDetailOrder.
  ///
  /// In en, this message translates to:
  /// **'Detail page widget order'**
  String get serverDetailOrder;

  /// No description provided for @serverFuncBtns.
  ///
  /// In en, this message translates to:
  /// **'Server function buttons'**
  String get serverFuncBtns;

  /// No description provided for @serverOrder.
  ///
  /// In en, this message translates to:
  /// **'Server order'**
  String get serverOrder;

  /// No description provided for @sftpDlPrepare.
  ///
  /// In en, this message translates to:
  /// **'Preparing to connect...'**
  String get sftpDlPrepare;

  /// No description provided for @sftpEditorTip.
  ///
  /// In en, this message translates to:
  /// **'If empty, use the built-in file editor of the app. If a value is present, use the remote server’s editor, e.g., `vim` (recommended to automatically detect according to `EDITOR`).'**
  String get sftpEditorTip;

  /// No description provided for @sftpRmrDirSummary.
  ///
  /// In en, this message translates to:
  /// **'Use `rm -r` to delete a folder in SFTP.'**
  String get sftpRmrDirSummary;

  /// No description provided for @sftpSSHConnected.
  ///
  /// In en, this message translates to:
  /// **'SFTP Connected'**
  String get sftpSSHConnected;

  /// No description provided for @sftpShowFoldersFirst.
  ///
  /// In en, this message translates to:
  /// **'Display folders first'**
  String get sftpShowFoldersFirst;

  /// No description provided for @showDistLogo.
  ///
  /// In en, this message translates to:
  /// **'Show distribution logo'**
  String get showDistLogo;

  /// No description provided for @shutdown.
  ///
  /// In en, this message translates to:
  /// **'Shutdown'**
  String get shutdown;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @snippet.
  ///
  /// In en, this message translates to:
  /// **'Snippet'**
  String get snippet;

  /// No description provided for @softWrap.
  ///
  /// In en, this message translates to:
  /// **'Soft wrap'**
  String get softWrap;

  /// No description provided for @specifyDev.
  ///
  /// In en, this message translates to:
  /// **'Specify device'**
  String get specifyDev;

  /// No description provided for @specifyDevTip.
  ///
  /// In en, this message translates to:
  /// **'For example, network traffic statistics are by default for all devices. You can specify a particular device here.'**
  String get specifyDevTip;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @spentTime.
  ///
  /// In en, this message translates to:
  /// **'Spent time: {time}'**
  String spentTime(Object time);

  /// No description provided for @sshTermHelp.
  ///
  /// In en, this message translates to:
  /// **'When the terminal is scrollable, dragging horizontally can select text. Clicking the keyboard button turns the keyboard on/off. The file icon opens the current path SFTP. The clipboard button copies the content when text is selected, and pastes content from the clipboard into the terminal when no text is selected and there is content on the clipboard. The code icon pastes code snippets into the terminal and executes them.'**
  String get sshTermHelp;

  /// No description provided for @sshTip.
  ///
  /// In en, this message translates to:
  /// **'This function is now in the experimental stage.\n\nPlease report bugs on {url} or join our development.'**
  String sshTip(Object url);

  /// No description provided for @sshVirtualKeyAutoOff.
  ///
  /// In en, this message translates to:
  /// **'Auto switching of virtual keys'**
  String get sshVirtualKeyAutoOff;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @stat.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get stat;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get stats;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @stopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get stopped;

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @supportFmtArgs.
  ///
  /// In en, this message translates to:
  /// **'The following formatting parameters are supported:'**
  String get supportFmtArgs;

  /// No description provided for @suspend.
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get suspend;

  /// No description provided for @suspendTip.
  ///
  /// In en, this message translates to:
  /// **'The suspend function requires root permission and systemd support.'**
  String get suspendTip;

  /// No description provided for @switchTo.
  ///
  /// In en, this message translates to:
  /// **'Switch to {val}'**
  String switchTo(Object val);

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @syncTip.
  ///
  /// In en, this message translates to:
  /// **'A restart may be required for some changes to take effect.'**
  String get syncTip;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @tag.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tag;

  /// No description provided for @temperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperature;

  /// No description provided for @termFontSizeTip.
  ///
  /// In en, this message translates to:
  /// **'This setting will affect the terminal size (width and height). You can zoom in on the terminal page to adjust the font size of the current session.'**
  String get termFontSizeTip;

  /// No description provided for @terminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminal;

  /// No description provided for @test.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get test;

  /// No description provided for @textScaler.
  ///
  /// In en, this message translates to:
  /// **'Text scaler'**
  String get textScaler;

  /// No description provided for @textScalerTip.
  ///
  /// In en, this message translates to:
  /// **'1.0 => 100% (original size), only works on server page part of the font, not recommended to change.'**
  String get textScalerTip;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @times.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get times;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @traffic.
  ///
  /// In en, this message translates to:
  /// **'Traffic'**
  String get traffic;

  /// No description provided for @trySudo.
  ///
  /// In en, this message translates to:
  /// **'Try using sudo'**
  String get trySudo;

  /// No description provided for @ttl.
  ///
  /// In en, this message translates to:
  /// **'TTL'**
  String get ttl;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @unkownConvertMode.
  ///
  /// In en, this message translates to:
  /// **'Unknown conversion mode'**
  String get unkownConvertMode;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @updateIntervalEqual0.
  ///
  /// In en, this message translates to:
  /// **'You set to 0, will not update automatically.\nCan\'t calculate CPU status.'**
  String get updateIntervalEqual0;

  /// No description provided for @updateServerStatusInterval.
  ///
  /// In en, this message translates to:
  /// **'Server status update interval'**
  String get updateServerStatusInterval;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @upsideDown.
  ///
  /// In en, this message translates to:
  /// **'Upside Down'**
  String get upsideDown;

  /// No description provided for @uptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get uptime;

  /// No description provided for @useCdn.
  ///
  /// In en, this message translates to:
  /// **'Using CDN'**
  String get useCdn;

  /// No description provided for @useCdnTip.
  ///
  /// In en, this message translates to:
  /// **'Non-Chinese users are recommended to use CDN. Would you like to use it?'**
  String get useCdnTip;

  /// No description provided for @useNoPwd.
  ///
  /// In en, this message translates to:
  /// **'No password will be used'**
  String get useNoPwd;

  /// No description provided for @usePodmanByDefault.
  ///
  /// In en, this message translates to:
  /// **'Use Podman by default'**
  String get usePodmanByDefault;

  /// No description provided for @used.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get used;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @viewErr.
  ///
  /// In en, this message translates to:
  /// **'See error'**
  String get viewErr;

  /// No description provided for @virtKeyHelpClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to the clipboard if the selected terminal is not empty, otherwise paste the content of the clipboard to the terminal.'**
  String get virtKeyHelpClipboard;

  /// No description provided for @virtKeyHelpIME.
  ///
  /// In en, this message translates to:
  /// **'Turn on/off the keyboard'**
  String get virtKeyHelpIME;

  /// No description provided for @virtKeyHelpSFTP.
  ///
  /// In en, this message translates to:
  /// **'Open current directory in SFTP.'**
  String get virtKeyHelpSFTP;

  /// No description provided for @waitConnection.
  ///
  /// In en, this message translates to:
  /// **'Please wait for the connection to be established.'**
  String get waitConnection;

  /// No description provided for @wakeLock.
  ///
  /// In en, this message translates to:
  /// **'Keep awake'**
  String get wakeLock;

  /// No description provided for @watchNotPaired.
  ///
  /// In en, this message translates to:
  /// **'No paired Apple Watch'**
  String get watchNotPaired;

  /// No description provided for @webdavSettingEmpty.
  ///
  /// In en, this message translates to:
  /// **'WebDav setting is empty'**
  String get webdavSettingEmpty;

  /// No description provided for @whenOpenApp.
  ///
  /// In en, this message translates to:
  /// **'When opening the app'**
  String get whenOpenApp;

  /// No description provided for @wolTip.
  ///
  /// In en, this message translates to:
  /// **'After configuring WOL (Wake-on-LAN), a WOL request is sent each time the server is connected.'**
  String get wolTip;

  /// No description provided for @write.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get write;

  /// No description provided for @writeScriptFailTip.
  ///
  /// In en, this message translates to:
  /// **'Writing to the script failed, possibly due to lack of permissions or the directory does not exist.'**
  String get writeScriptFailTip;

  /// No description provided for @writeScriptTip.
  ///
  /// In en, this message translates to:
  /// **'After connecting to the server, a script will be written to ~/.config/server_box to monitor the system status. You can review the script content.'**
  String get writeScriptTip;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en', 'es', 'fr', 'id', 'ja', 'nl', 'pt', 'ru', 'tr', 'uk', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh': {
  switch (locale.countryCode) {
    case 'TW': return AppLocalizationsZhTw();
   }
  break;
   }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de': return AppLocalizationsDe();
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
    case 'fr': return AppLocalizationsFr();
    case 'id': return AppLocalizationsId();
    case 'ja': return AppLocalizationsJa();
    case 'nl': return AppLocalizationsNl();
    case 'pt': return AppLocalizationsPt();
    case 'ru': return AppLocalizationsRu();
    case 'tr': return AppLocalizationsTr();
    case 'uk': return AppLocalizationsUk();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
