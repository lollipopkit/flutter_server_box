import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_de.dart';
import 'l10n_en.dart';
import 'l10n_id.dart';
import 'l10n_zh.dart';

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen_l10n/l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
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
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

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
    Locale('id'),
    Locale('zh'),
    Locale('zh', 'TW')
  ];

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks to the following people who participated in.'**
  String get aboutThanks;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addAServer.
  ///
  /// In en, this message translates to:
  /// **'add a server'**
  String get addAServer;

  /// No description provided for @addPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Add private key'**
  String get addPrivateKey;

  /// No description provided for @addSystemPrivateKeyTip.
  ///
  /// In en, this message translates to:
  /// **'Currently don\'t have any private key, do you add the one that comes with the system (~/.ssh/id_rsa)?'**
  String get addSystemPrivateKeyTip;

  /// No description provided for @added2List.
  ///
  /// In en, this message translates to:
  /// **'Added to task list'**
  String get added2List;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @alreadyLastDir.
  ///
  /// In en, this message translates to:
  /// **'Already in last directory.'**
  String get alreadyLastDir;

  /// No description provided for @alterUrl.
  ///
  /// In en, this message translates to:
  /// **'Alter url'**
  String get alterUrl;

  /// No description provided for @askContinue.
  ///
  /// In en, this message translates to:
  /// **'{msg}, continue?'**
  String askContinue(Object msg);

  /// No description provided for @attention.
  ///
  /// In en, this message translates to:
  /// **'Attention'**
  String get attention;

  /// No description provided for @authRequired.
  ///
  /// In en, this message translates to:
  /// **'Auth required'**
  String get authRequired;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @autoCheckUpdate.
  ///
  /// In en, this message translates to:
  /// **'Auto check update'**
  String get autoCheckUpdate;

  /// No description provided for @autoConnect.
  ///
  /// In en, this message translates to:
  /// **'Auto connect'**
  String get autoConnect;

  /// No description provided for @autoUpdateHomeWidget.
  ///
  /// In en, this message translates to:
  /// **'Auto update home widget'**
  String get autoUpdateHomeWidget;

  /// No description provided for @backup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @backupAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup and Restore'**
  String get backupAndRestore;

  /// No description provided for @backupTip.
  ///
  /// In en, this message translates to:
  /// **'The exported data is simply encrypted. \nPlease keep it safe.'**
  String get backupTip;

  /// No description provided for @backupVersionNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Backup version is not match.'**
  String get backupVersionNotMatch;

  /// No description provided for @bgRun.
  ///
  /// In en, this message translates to:
  /// **'Run in backgroud'**
  String get bgRun;

  /// No description provided for @bioAuth.
  ///
  /// In en, this message translates to:
  /// **'Biometric auth'**
  String get bioAuth;

  /// No description provided for @canPullRefresh.
  ///
  /// In en, this message translates to:
  /// **'You can pull to refresh.'**
  String get canPullRefresh;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// No description provided for @chooseFontFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a font file'**
  String get chooseFontFile;

  /// No description provided for @choosePrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Choose private key'**
  String get choosePrivateKey;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @cmd.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get cmd;

  /// No description provided for @conn.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get conn;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @containerName.
  ///
  /// In en, this message translates to:
  /// **'Container name'**
  String get containerName;

  /// No description provided for @containerStatus.
  ///
  /// In en, this message translates to:
  /// **'Container status'**
  String get containerStatus;

  /// No description provided for @convert.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get convert;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get copyPath;

  /// No description provided for @createFile.
  ///
  /// In en, this message translates to:
  /// **'Create file'**
  String get createFile;

  /// No description provided for @createFolder.
  ///
  /// In en, this message translates to:
  /// **'Create folder'**
  String get createFolder;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @debug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debug;

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

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteScripts.
  ///
  /// In en, this message translates to:
  /// **'Delete server scripts at the same time'**
  String get deleteScripts;

  /// No description provided for @deleteServers.
  ///
  /// In en, this message translates to:
  /// **'Batch delete servers'**
  String get deleteServers;

  /// No description provided for @dirEmpty.
  ///
  /// In en, this message translates to:
  /// **'Make sure dir is empty.'**
  String get dirEmpty;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

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

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @dl2Local.
  ///
  /// In en, this message translates to:
  /// **'Download {fileName} to local?'**
  String dl2Local(Object fileName);

  /// No description provided for @dockerEditHost.
  ///
  /// In en, this message translates to:
  /// **'Edit DOCKER_HOST'**
  String get dockerEditHost;

  /// No description provided for @dockerEmptyRunningItems.
  ///
  /// In en, this message translates to:
  /// **'No running container. \nIt may be that the env DOCKER_HOST is not read correctly. You can found it by running `echo \$DOCKER_HOST` in terminal.'**
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

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

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
  /// **'The current code highlighting performance is worse and can be optionally turned off to improve.'**
  String get editorHighlightTip;

  /// No description provided for @encode.
  ///
  /// In en, this message translates to:
  /// **'Encode'**
  String get encode;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @exampleName.
  ///
  /// In en, this message translates to:
  /// **'Example name'**
  String get exampleName;

  /// No description provided for @experimentalFeature.
  ///
  /// In en, this message translates to:
  /// **'Experimental feature'**
  String get experimentalFeature;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @extraArgs.
  ///
  /// In en, this message translates to:
  /// **'Extra args'**
  String get extraArgs;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @feedbackOnGithub.
  ///
  /// In en, this message translates to:
  /// **'If you have any questions, please feedback on Github.'**
  String get feedbackOnGithub;

  /// No description provided for @fieldMustNotEmpty.
  ///
  /// In en, this message translates to:
  /// **'These fields must not be empty.'**
  String get fieldMustNotEmpty;

  /// No description provided for @fileNotExist.
  ///
  /// In en, this message translates to:
  /// **'{file} not exist'**
  String fileNotExist(Object file);

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File \'{file}\' too large {size}, max {sizeMax}'**
  String fileTooLarge(Object file, Object size, Object sizeMax);

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @finished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get finished;

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

  /// No description provided for @foundNUpdate.
  ///
  /// In en, this message translates to:
  /// **'Found {count} update'**
  String foundNUpdate(Object count);

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

  /// No description provided for @getPushTokenFailed.
  ///
  /// In en, this message translates to:
  /// **'Can\'t fetch push token'**
  String get getPushTokenFailed;

  /// No description provided for @gettingToken.
  ///
  /// In en, this message translates to:
  /// **'Getting token...'**
  String get gettingToken;

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

  /// No description provided for @highlight.
  ///
  /// In en, this message translates to:
  /// **'Code highlight'**
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

  /// No description provided for @icloudSynced.
  ///
  /// In en, this message translates to:
  /// **'iCloud wird synchronisiert und einige Einstellungen erfordern möglicherweise einen Neustart der App, um wirksam zu werden.'**
  String get icloudSynced;

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

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @inner.
  ///
  /// In en, this message translates to:
  /// **'Inner'**
  String get inner;

  /// No description provided for @inputDomainHere.
  ///
  /// In en, this message translates to:
  /// **'Input Domain here'**
  String get inputDomainHere;

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

  /// No description provided for @invalidJson.
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON'**
  String get invalidJson;

  /// No description provided for @invalidVersion.
  ///
  /// In en, this message translates to:
  /// **'Invalid version'**
  String get invalidVersion;

  /// No description provided for @invalidVersionHelp.
  ///
  /// In en, this message translates to:
  /// **'Please make sure that docker is installed correctly, or that you are using a non-self-compiled version. If you don\'t have the above issues, please submit an issue on {url}.'**
  String invalidVersionHelp(Object url);

  /// No description provided for @isBusy.
  ///
  /// In en, this message translates to:
  /// **'Is busy now'**
  String get isBusy;

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

  /// No description provided for @keyAuth.
  ///
  /// In en, this message translates to:
  /// **'Key Auth'**
  String get keyAuth;

  /// No description provided for @keyboardCompatibility.
  ///
  /// In en, this message translates to:
  /// **'Possible to improve input method compatibility'**
  String get keyboardCompatibility;

  /// No description provided for @keyboardType.
  ///
  /// In en, this message translates to:
  /// **'Keyborad type'**
  String get keyboardType;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageName.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @lastTry.
  ///
  /// In en, this message translates to:
  /// **'Last try'**
  String get lastTry;

  /// No description provided for @launchPage.
  ///
  /// In en, this message translates to:
  /// **'Launch page'**
  String get launchPage;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @loadingFiles.
  ///
  /// In en, this message translates to:
  /// **'Loading files...'**
  String get loadingFiles;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @log.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get log;

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
  /// **'Number of server reconnection'**
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

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @needRestart.
  ///
  /// In en, this message translates to:
  /// **'Need to restart app'**
  String get needRestart;

  /// No description provided for @net.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get net;

  /// No description provided for @netViewType.
  ///
  /// In en, this message translates to:
  /// **'Net view type'**
  String get netViewType;

  /// No description provided for @newContainer.
  ///
  /// In en, this message translates to:
  /// **'New container'**
  String get newContainer;

  /// No description provided for @noClient.
  ///
  /// In en, this message translates to:
  /// **'No client'**
  String get noClient;

  /// No description provided for @noInterface.
  ///
  /// In en, this message translates to:
  /// **'No interface'**
  String get noInterface;

  /// No description provided for @noOptions.
  ///
  /// In en, this message translates to:
  /// **'No options'**
  String get noOptions;

  /// No description provided for @noResult.
  ///
  /// In en, this message translates to:
  /// **'No result'**
  String get noResult;

  /// No description provided for @noSavedPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'No saved private keys.'**
  String get noSavedPrivateKey;

  /// No description provided for @noSavedSnippet.
  ///
  /// In en, this message translates to:
  /// **'No saved snippets.'**
  String get noSavedSnippet;

  /// No description provided for @noServerAvailable.
  ///
  /// In en, this message translates to:
  /// **'No server available.'**
  String get noServerAvailable;

  /// No description provided for @noTask.
  ///
  /// In en, this message translates to:
  /// **'No task'**
  String get noTask;

  /// No description provided for @noUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'No update available'**
  String get noUpdateAvailable;

  /// No description provided for @notSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get notSelected;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @nullToken.
  ///
  /// In en, this message translates to:
  /// **'Null token'**
  String get nullToken;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @onServerDetailPage.
  ///
  /// In en, this message translates to:
  /// **'On server detail page'**
  String get onServerDetailPage;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

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

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @path.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get path;

  /// No description provided for @percentOfSize.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of {size}'**
  String percentOfSize(Object percent, Object size);

  /// No description provided for @pickFile.
  ///
  /// In en, this message translates to:
  /// **'Pick file'**
  String get pickFile;

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

  /// No description provided for @platformNotSupportUpdate.
  ///
  /// In en, this message translates to:
  /// **'Current platform does not support in app update.\nPlease build from source and install it.'**
  String get platformNotSupportUpdate;

  /// No description provided for @plzEnterHost.
  ///
  /// In en, this message translates to:
  /// **'Please enter host.'**
  String get plzEnterHost;

  /// No description provided for @plzSelectKey.
  ///
  /// In en, this message translates to:
  /// **'Please select a key.'**
  String get plzSelectKey;

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

  /// No description provided for @primaryColorSeed.
  ///
  /// In en, this message translates to:
  /// **'Primary color seed'**
  String get primaryColorSeed;

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

  /// No description provided for @remotePath.
  ///
  /// In en, this message translates to:
  /// **'Remote path'**
  String get remotePath;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @reportBugsOnGithubIssue.
  ///
  /// In en, this message translates to:
  /// **'Please report bugs on {url}'**
  String reportBugsOnGithubIssue(Object url);

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @restoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Restore success. Restart app to apply.'**
  String get restoreSuccess;

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

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

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
  /// **'Server func buttons'**
  String get serverFuncBtns;

  /// No description provided for @serverOrder.
  ///
  /// In en, this message translates to:
  /// **'Server order'**
  String get serverOrder;

  /// No description provided for @serverTabConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get serverTabConnecting;

  /// No description provided for @serverTabEmpty.
  ///
  /// In en, this message translates to:
  /// **'There is no server.\nClick the fab to add one.'**
  String get serverTabEmpty;

  /// No description provided for @serverTabFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get serverTabFailed;

  /// No description provided for @serverTabLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get serverTabLoading;

  /// No description provided for @serverTabPlzSave.
  ///
  /// In en, this message translates to:
  /// **'Please \'save\' this private key again.'**
  String get serverTabPlzSave;

  /// No description provided for @serverTabUnkown.
  ///
  /// In en, this message translates to:
  /// **'Unknown state'**
  String get serverTabUnkown;

  /// No description provided for @setting.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get setting;

  /// No description provided for @sftpDlPrepare.
  ///
  /// In en, this message translates to:
  /// **'Preparing to connect...'**
  String get sftpDlPrepare;

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

  /// No description provided for @snippet.
  ///
  /// In en, this message translates to:
  /// **'Snippet'**
  String get snippet;

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

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @suspend.
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get suspend;

  /// No description provided for @suspendTip.
  ///
  /// In en, this message translates to:
  /// **'The suspend function requires root privileges and systemd support.'**
  String get suspendTip;

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

  /// No description provided for @terminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminal;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeMode;

  /// No description provided for @times.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get times;

  /// No description provided for @traffic.
  ///
  /// In en, this message translates to:
  /// **'Traffic'**
  String get traffic;

  /// No description provided for @ttl.
  ///
  /// In en, this message translates to:
  /// **'ttl'**
  String get ttl;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @unkownConvertMode.
  ///
  /// In en, this message translates to:
  /// **'Unknown convert mode'**
  String get unkownConvertMode;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @updateAll.
  ///
  /// In en, this message translates to:
  /// **'Update all'**
  String get updateAll;

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

  /// No description provided for @updateTip.
  ///
  /// In en, this message translates to:
  /// **'Update: v1.0.{newest}'**
  String updateTip(Object newest);

  /// No description provided for @updateTipTooLow.
  ///
  /// In en, this message translates to:
  /// **'Current version is too low, please update to v1.0.{newest}'**
  String updateTipTooLow(Object newest);

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

  /// No description provided for @urlOrJson.
  ///
  /// In en, this message translates to:
  /// **'URL or JSON'**
  String get urlOrJson;

  /// No description provided for @useNoPwd.
  ///
  /// In en, this message translates to:
  /// **'No password will be used.'**
  String get useNoPwd;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @versionHaveUpdate.
  ///
  /// In en, this message translates to:
  /// **'Found: v1.0.{build}, click to update'**
  String versionHaveUpdate(Object build);

  /// No description provided for @versionUnknownUpdate.
  ///
  /// In en, this message translates to:
  /// **'Current: v1.0.{build}, click to check updates'**
  String versionUnknownUpdate(Object build);

  /// No description provided for @versionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Current: v1.0.{build}, is up to date'**
  String versionUpdated(Object build);

  /// No description provided for @viewErr.
  ///
  /// In en, this message translates to:
  /// **'See error'**
  String get viewErr;

  /// No description provided for @virtKeyHelpClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to the clipboard if terminal selected is not empty, otherwise paste the contents of the clipboard to the terminal.'**
  String get virtKeyHelpClipboard;

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

  /// No description provided for @watchNotPaired.
  ///
  /// In en, this message translates to:
  /// **'No paired Apple Watch'**
  String get watchNotPaired;

  /// No description provided for @whenOpenApp.
  ///
  /// In en, this message translates to:
  /// **'When opening the app'**
  String get whenOpenApp;

  /// No description provided for @willTakEeffectImmediately.
  ///
  /// In en, this message translates to:
  /// **'Will take effect immediately'**
  String get willTakEeffectImmediately;

  /// No description provided for @write.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get write;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en', 'id', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh': {
  switch (locale.countryCode) {
    case 'TW': return SZhTw();
   }
  break;
   }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de': return SDe();
    case 'en': return SEn();
    case 'id': return SId();
    case 'zh': return SZh();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
