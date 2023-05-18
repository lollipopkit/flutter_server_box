import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_de.dart';
import 'l10n_en.dart';
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
    Locale('zh')
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

  /// No description provided for @addAServer.
  ///
  /// In en, this message translates to:
  /// **'add a server'**
  String get addAServer;

  /// No description provided for @addOne.
  ///
  /// In en, this message translates to:
  /// **'Add one'**
  String get addOne;

  /// No description provided for @addPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Add private key'**
  String get addPrivateKey;

  /// No description provided for @alreadyLastDir.
  ///
  /// In en, this message translates to:
  /// **'Already in last directory.'**
  String get alreadyLastDir;

  /// No description provided for @appPrimaryColor.
  ///
  /// In en, this message translates to:
  /// **'App primary color'**
  String get appPrimaryColor;

  /// No description provided for @attention.
  ///
  /// In en, this message translates to:
  /// **'Attention'**
  String get attention;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

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

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

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

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloadFinished.
  ///
  /// In en, this message translates to:
  /// **'Download finished'**
  String get downloadFinished;

  /// No description provided for @downloadStatus.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of {size}'**
  String downloadStatus(Object percent, Object size);

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

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

  /// No description provided for @foundNUpdate.
  ///
  /// In en, this message translates to:
  /// **'Found {count} update'**
  String foundNUpdate(Object count);

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

  /// No description provided for @goto.
  ///
  /// In en, this message translates to:
  /// **'Go to'**
  String get goto;

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

  /// No description provided for @privateKey.
  ///
  /// In en, this message translates to:
  /// **'Private Key'**
  String get privateKey;

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

  /// No description provided for @restoreSureWithDate.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to restore from {date} ?'**
  String restoreSureWithDate(Object date);

  /// No description provided for @result.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get result;

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

  /// No description provided for @second.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get second;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

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

  /// No description provided for @sftpNoDownloadTask.
  ///
  /// In en, this message translates to:
  /// **'No download task.'**
  String get sftpNoDownloadTask;

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

  /// No description provided for @snippet.
  ///
  /// In en, this message translates to:
  /// **'Snippet'**
  String get snippet;

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

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

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

  /// No description provided for @sureDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete [{name}]?'**
  String sureDelete(Object name);

  /// No description provided for @sureDirEmpty.
  ///
  /// In en, this message translates to:
  /// **'Make sure dir is empty.'**
  String get sureDirEmpty;

  /// No description provided for @sureNoPwd.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to use no password?'**
  String get sureNoPwd;

  /// No description provided for @sureToDeleteServer.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete server [{server}]?'**
  String sureToDeleteServer(Object server);

  /// No description provided for @termTheme.
  ///
  /// In en, this message translates to:
  /// **'Terminal theme'**
  String get termTheme;

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
  /// **'Current: v1.0.{build}'**
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

  /// No description provided for @waitConnection.
  ///
  /// In en, this message translates to:
  /// **'Please wait for the connection to be established.'**
  String get waitConnection;

  /// No description provided for @willTakEeffectImmediately.
  ///
  /// In en, this message translates to:
  /// **'Will take effect immediately'**
  String get willTakEeffectImmediately;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de': return SDe();
    case 'en': return SEn();
    case 'zh': return SZh();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
