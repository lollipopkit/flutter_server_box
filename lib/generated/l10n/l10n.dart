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
import 'l10n_it.dart';
import 'l10n_ja.dart';
import 'l10n_ko.dart';
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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
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
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('nl'),
    Locale('pt'),
    Locale('ru'),
    Locale('tr'),
    Locale('uk'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @crashCollect.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic data'**
  String get crashCollect;

  /// No description provided for @crashCollectIntro.
  ///
  /// In en, this message translates to:
  /// **'ServerBox records what happens while it runs so problems can be fixed. Choose how much information to send.'**
  String get crashCollectIntro;

  /// No description provided for @crashCollectNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get crashCollectNone;

  /// No description provided for @crashCollectNoneTip.
  ///
  /// In en, this message translates to:
  /// **'Reports remain on this device; after a crash, you can send one manually.'**
  String get crashCollectNoneTip;

  /// No description provided for @crashCollectBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic information'**
  String get crashCollectBasic;

  /// No description provided for @crashCollectBasicTip.
  ///
  /// In en, this message translates to:
  /// **'Only crash information is included; logs and performance data are not. **This helps us improve the app and fix bugs.**'**
  String get crashCollectBasicTip;

  /// No description provided for @crashCollectFull.
  ///
  /// In en, this message translates to:
  /// **'Full information'**
  String get crashCollectFull;

  /// No description provided for @crashCollectFullTip.
  ///
  /// In en, this message translates to:
  /// **'Along with the crash log, performance data and which features are used are included: **they show what is slow, and which features are worth keeping.**'**
  String get crashCollectFullTip;

  /// No description provided for @crashCollectFooter.
  ///
  /// In en, this message translates to:
  /// **'At every level, known server names, addresses and usernames are replaced with placeholders when recorded. You can change the collection level later in Settings.'**
  String get crashCollectFooter;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @crashUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload crash reports'**
  String get crashUpload;

  /// No description provided for @crashUploadTip.
  ///
  /// In en, this message translates to:
  /// **'Send crash reports to the developer. Known server names and addresses are replaced with placeholders. Off by default; you can turn it off at any time.'**
  String get crashUploadTip;

  /// No description provided for @crashNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'ServerBox exited unexpectedly during its last run. Would you like to view the crash report?'**
  String get crashNoticeBody;

  /// No description provided for @crashReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Crash report'**
  String get crashReportTitle;

  /// No description provided for @crashReportHint.
  ///
  /// In en, this message translates to:
  /// **'This is the log from the previous run. Known server names and addresses have been replaced with placeholders, but other details may remain. Please read it carefully before submitting.'**
  String get crashReportHint;

  /// No description provided for @crashReportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Copy & report'**
  String get crashReportSubmit;

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

  /// No description provided for @askAi.
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get askAi;

  /// No description provided for @askAiAwaitingResponse.
  ///
  /// In en, this message translates to:
  /// **'Waiting for AI response...'**
  String get askAiAwaitingResponse;

  /// No description provided for @askAiEndpointTip.
  ///
  /// In en, this message translates to:
  /// **'Enter a domain or a full URL. The path is completed from the protocol you pick.'**
  String get askAiEndpointTip;

  /// No description provided for @askAiProtocolTip.
  ///
  /// In en, this message translates to:
  /// **'Auto tries Responses, then Chat Completions.'**
  String get askAiProtocolTip;

  /// No description provided for @askAiCommandInserted.
  ///
  /// In en, this message translates to:
  /// **'Command inserted into terminal'**
  String get askAiCommandInserted;

  /// No description provided for @askAiConfigMissing.
  ///
  /// In en, this message translates to:
  /// **'Please configure {fields} in Settings.'**
  String askAiConfigMissing(Object fields);

  /// No description provided for @askAiDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI may be incorrect. Review carefully before applying.'**
  String get askAiDisclaimer;

  /// No description provided for @askAiInsertTerminal.
  ///
  /// In en, this message translates to:
  /// **'Insert into terminal'**
  String get askAiInsertTerminal;

  /// No description provided for @askAiNoResponse.
  ///
  /// In en, this message translates to:
  /// **'No response'**
  String get askAiNoResponse;

  /// No description provided for @askAiAgentWelcome.
  ///
  /// In en, this message translates to:
  /// **'What should we do on this server?'**
  String get askAiAgentWelcome;

  /// No description provided for @askAiAgentPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Ask the Agent to inspect or fix something...'**
  String get askAiAgentPromptHint;

  /// No description provided for @askAiAnalyzeSelectionPrompt.
  ///
  /// In en, this message translates to:
  /// **'Analyse the selected terminal output and explain what happened'**
  String get askAiAnalyzeSelectionPrompt;

  /// No description provided for @askAiTerminalContext.
  ///
  /// In en, this message translates to:
  /// **'Terminal context'**
  String get askAiTerminalContext;

  /// No description provided for @askAiReviewNeeded.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get askAiReviewNeeded;

  /// No description provided for @askAiReviewAction.
  ///
  /// In en, this message translates to:
  /// **'Review proposed command'**
  String get askAiReviewAction;

  /// No description provided for @askAiReviewBeforeContinuing.
  ///
  /// In en, this message translates to:
  /// **'Review or decline the current suggestion first'**
  String get askAiReviewBeforeContinuing;

  /// No description provided for @askAiApproveRun.
  ///
  /// In en, this message translates to:
  /// **'Approve & run'**
  String get askAiApproveRun;

  /// No description provided for @askAiDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get askAiDecline;

  /// No description provided for @askAiActionDeclined.
  ///
  /// In en, this message translates to:
  /// **'The proposed command was declined.'**
  String get askAiActionDeclined;

  /// No description provided for @askAiInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Agent response was interrupted.'**
  String get askAiInterrupted;

  /// No description provided for @askAiRiskReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get askAiRiskReadOnly;

  /// No description provided for @askAiRiskCaution.
  ///
  /// In en, this message translates to:
  /// **'Changes system'**
  String get askAiRiskCaution;

  /// No description provided for @askAiRiskUnvetted.
  ///
  /// In en, this message translates to:
  /// **'Unvetted host'**
  String get askAiRiskUnvetted;

  /// No description provided for @askAiRiskDestructive.
  ///
  /// In en, this message translates to:
  /// **'High risk'**
  String get askAiRiskDestructive;

  /// No description provided for @askAiHighRiskConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Run high-risk command?'**
  String get askAiHighRiskConfirmTitle;

  /// No description provided for @askAiHighRiskConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This command may make changes that are hard to undo. Check it carefully.'**
  String get askAiHighRiskConfirmBody;

  /// No description provided for @askAiNoCommandOutput.
  ///
  /// In en, this message translates to:
  /// **'Command completed without output.'**
  String get askAiNoCommandOutput;

  /// No description provided for @askAiOutputTruncated.
  ///
  /// In en, this message translates to:
  /// **'Long output was truncated before it was sent back to the Agent.'**
  String get askAiOutputTruncated;

  /// No description provided for @askAiAutoApproved.
  ///
  /// In en, this message translates to:
  /// **'Auto-approved'**
  String get askAiAutoApproved;

  /// No description provided for @askAiAutoRunSafeCommands.
  ///
  /// In en, this message translates to:
  /// **'Auto-run read-only commands'**
  String get askAiAutoRunSafeCommands;

  /// No description provided for @askAiAutoRunSafeCommandsTip.
  ///
  /// In en, this message translates to:
  /// **'Runs only when both the model and the local check call it read-only'**
  String get askAiAutoRunSafeCommandsTip;

  /// No description provided for @askAiSendOnEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter sends'**
  String get askAiSendOnEnter;

  /// No description provided for @askAiSendOnEnterTip.
  ///
  /// In en, this message translates to:
  /// **'Enter sends, Shift+Enter for a new line. Off: Enter for a new line, Cmd/Ctrl+Enter sends.'**
  String get askAiSendOnEnterTip;

  /// No description provided for @askAiApiKeyOptional.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for local or unauthenticated'**
  String get askAiApiKeyOptional;

  /// No description provided for @askAiHistory.
  ///
  /// In en, this message translates to:
  /// **'Conversation history'**
  String get askAiHistory;

  /// No description provided for @askAiNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get askAiNewConversation;

  /// No description provided for @askAiNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No saved conversations yet'**
  String get askAiNoHistory;

  /// No description provided for @askAiNoHistoryMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get askAiNoHistoryMessages;

  /// No description provided for @askAiUntitledConversation.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get askAiUntitledConversation;

  /// No description provided for @askAiRenameConversation.
  ///
  /// In en, this message translates to:
  /// **'Rename conversation'**
  String get askAiRenameConversation;

  /// No description provided for @askAiDeleteConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this conversation?'**
  String get askAiDeleteConversationTitle;

  /// No description provided for @askAiDeleteConversationTip.
  ///
  /// In en, this message translates to:
  /// **'Deletes it from this device. Cannot be undone.'**
  String get askAiDeleteConversationTip;

  /// No description provided for @askAiClearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear this server\'s Agent history?'**
  String get askAiClearHistoryTitle;

  /// No description provided for @askAiClearHistoryTip.
  ///
  /// In en, this message translates to:
  /// **'Every saved Agent conversation for this server will be deleted.'**
  String get askAiClearHistoryTip;

  /// No description provided for @askAiRestoredReview.
  ///
  /// In en, this message translates to:
  /// **'This command came from history. Review it again'**
  String get askAiRestoredReview;

  /// No description provided for @agentWelcome.
  ///
  /// In en, this message translates to:
  /// **'What should we do across your servers?'**
  String get agentWelcome;

  /// No description provided for @agentWelcomeTip.
  ///
  /// In en, this message translates to:
  /// **'Have the Agent diagnose a problem or carry out a task'**
  String get agentWelcomeTip;

  /// No description provided for @agentPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Ask the Agent to inspect or operate your servers...'**
  String get agentPromptHint;

  /// No description provided for @agentNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No saved global Agent conversations'**
  String get agentNoHistory;

  /// No description provided for @agentClearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear global Agent history?'**
  String get agentClearHistoryTitle;

  /// No description provided for @agentClearHistoryTip.
  ///
  /// In en, this message translates to:
  /// **'All global Agent conversations will be removed from this device.'**
  String get agentClearHistoryTip;

  /// No description provided for @agentToolShell.
  ///
  /// In en, this message translates to:
  /// **'Shell'**
  String get agentToolShell;

  /// No description provided for @agentToolReadFile.
  ///
  /// In en, this message translates to:
  /// **'Read file'**
  String get agentToolReadFile;

  /// No description provided for @agentToolWriteFile.
  ///
  /// In en, this message translates to:
  /// **'Write file'**
  String get agentToolWriteFile;

  /// No description provided for @agentToolFailed.
  ///
  /// In en, this message translates to:
  /// **'Tool execution failed.'**
  String get agentToolFailed;

  /// No description provided for @agentToolCallsFmt.
  ///
  /// In en, this message translates to:
  /// **'{count} tool calls'**
  String agentToolCallsFmt(Object count);

  /// No description provided for @floatOverTabs.
  ///
  /// In en, this message translates to:
  /// **'Float over other tabs'**
  String get floatOverTabs;

  /// No description provided for @agentToolSshConnect.
  ///
  /// In en, this message translates to:
  /// **'SSH connect'**
  String get agentToolSshConnect;

  /// No description provided for @agentToolSshDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect SSH'**
  String get agentToolSshDisconnect;

  /// No description provided for @agentSshConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to a new host'**
  String get agentSshConnectTitle;

  /// No description provided for @agentAuthMethod.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get agentAuthMethod;

  /// No description provided for @agentSshConnectTip.
  ///
  /// In en, this message translates to:
  /// **'The Agent wants an SSH connection. Enter the password here'**
  String get agentSshConnectTip;

  /// No description provided for @agentAdHocSessions.
  ///
  /// In en, this message translates to:
  /// **'Temporary connections'**
  String get agentAdHocSessions;

  /// No description provided for @agentSaveServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Save as a server'**
  String get agentSaveServerTitle;

  /// No description provided for @agentSaveServerTip.
  ///
  /// In en, this message translates to:
  /// **'This host and the password you enter are saved on this device'**
  String get agentSaveServerTip;

  /// No description provided for @agentMonitorOptional.
  ///
  /// In en, this message translates to:
  /// **'Monitor agent (optional)'**
  String get agentMonitorOptional;

  /// No description provided for @authFailTip.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Check the details'**
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

  /// No description provided for @availableTabs.
  ///
  /// In en, this message translates to:
  /// **'Available Tabs'**
  String get availableTabs;

  /// No description provided for @backupEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Backup is encrypted'**
  String get backupEncrypted;

  /// No description provided for @backupNotEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Backup is not encrypted'**
  String get backupNotEncrypted;

  /// No description provided for @backupPassword.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get backupPassword;

  /// No description provided for @backupPasswordRemoved.
  ///
  /// In en, this message translates to:
  /// **'Backup password removed'**
  String get backupPasswordRemoved;

  /// No description provided for @backupPasswordSet.
  ///
  /// In en, this message translates to:
  /// **'Backup password set'**
  String get backupPasswordSet;

  /// No description provided for @backupPasswordTip.
  ///
  /// In en, this message translates to:
  /// **'Set a password to encrypt backup files. Leave empty to disable encryption.'**
  String get backupPasswordTip;

  /// No description provided for @backupPasswordWrong.
  ///
  /// In en, this message translates to:
  /// **'Incorrect backup password'**
  String get backupPasswordWrong;

  /// No description provided for @connectAll.
  ///
  /// In en, this message translates to:
  /// **'Connect all'**
  String get connectAll;

  /// No description provided for @disconnectAll.
  ///
  /// In en, this message translates to:
  /// **'Disconnect all'**
  String get disconnectAll;

  /// No description provided for @distIcon.
  ///
  /// In en, this message translates to:
  /// **'Distribution marks'**
  String get distIcon;

  /// No description provided for @distIconConsent.
  ///
  /// In en, this message translates to:
  /// **'Only to indicate the distribution a server may be running.'**
  String get distIconConsent;

  /// No description provided for @distIconIntroLegal.
  ///
  /// In en, this message translates to:
  /// **'A mark says only what this device read from the remote system, which can be wrong or out of date, and identifies neither a derivative, a rebuild, nor any particular version. Where it cannot be identified, a plain icon is drawn.\n\nEach mark is a trademark of its respective owner and is used only to refer to the system it identifies.'**
  String get distIconIntroLegal;

  /// No description provided for @distIconTip.
  ///
  /// In en, this message translates to:
  /// **'Show a small mark beside each server for the system it appears to be running.'**
  String get distIconTip;

  /// No description provided for @distNameMap.
  ///
  /// In en, this message translates to:
  /// **'Name overrides'**
  String get distNameMap;

  /// No description provided for @distNameMapTip.
  ///
  /// In en, this message translates to:
  /// **'Only for a distribution whose file is named something else where you host the marks. The key is the name this app uses; the value is the name to fetch. Leave it empty unless a mark is missing.'**
  String get distNameMapTip;

  /// No description provided for @logoUrl.
  ///
  /// In en, this message translates to:
  /// **'Logo URL'**
  String get logoUrl;

  /// No description provided for @logoUrlTip.
  ///
  /// In en, this message translates to:
  /// **'The large image at the top of a server\'s own page, drawn in its own colours.'**
  String get logoUrlTip;

  /// No description provided for @markUrl.
  ///
  /// In en, this message translates to:
  /// **'Mark URL'**
  String get markUrl;

  /// No description provided for @markUrlTip.
  ///
  /// In en, this message translates to:
  /// **'The small mark beside a server\'s name in lists. Empty means none is drawn.\n\nNot the same picture as the logo'**
  String get markUrlTip;

  /// No description provided for @navTabMenuTip.
  ///
  /// In en, this message translates to:
  /// **'Long press a tab — or right-click it — to connect or disconnect everything on it at once.'**
  String get navTabMenuTip;

  /// No description provided for @nTags.
  ///
  /// In en, this message translates to:
  /// **'{count} Tags'**
  String nTags(Object count);

  /// No description provided for @remoteBackupPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Remote backups require a non-empty backup password'**
  String get remoteBackupPasswordRequired;

  /// No description provided for @monitorHttpsRequired.
  ///
  /// In en, this message translates to:
  /// **'A remote monitor agent needs HTTPS, unless HTTP is allowed for it.'**
  String get monitorHttpsRequired;

  /// No description provided for @monitorAllowInsecureHttp.
  ///
  /// In en, this message translates to:
  /// **'Allow HTTP'**
  String get monitorAllowInsecureHttp;

  /// No description provided for @monitorAllowInsecureHttpTip.
  ///
  /// In en, this message translates to:
  /// **'Only on a trusted private network that encrypts the transport itself, such as Tailscale'**
  String get monitorAllowInsecureHttpTip;

  /// No description provided for @monitorHttpTip.
  ///
  /// In en, this message translates to:
  /// **'Read this server\'s status from a **monitor** agent\'s HTTP API instead of running commands over SSH.\n\nThe agent has to be installed on the server first, and it is what makes trends, the watch app and the home-screen widgets possible.\n\n[Setting up a monitor agent]({url})'**
  String monitorHttpTip(String url);

  /// No description provided for @backupTip.
  ///
  /// In en, this message translates to:
  /// **'The exported data can be encrypted with password. \nPlease keep it safe.'**
  String get backupTip;

  /// No description provided for @icloudBackupStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup status'**
  String get icloudBackupStatusTitle;

  /// No description provided for @icloudBackupStatusLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading iCloud backup status...'**
  String get icloudBackupStatusLoading;

  /// No description provided for @icloudBackupStatusError.
  ///
  /// In en, this message translates to:
  /// **'Unable to read iCloud backup metadata'**
  String get icloudBackupStatusError;

  /// No description provided for @icloudBackupStatusEmpty.
  ///
  /// In en, this message translates to:
  /// **'No iCloud backup file found yet'**
  String get icloudBackupStatusEmpty;

  /// No description provided for @icloudBackupStateUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get icloudBackupStateUploading;

  /// No description provided for @icloudBackupStateConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict detected'**
  String get icloudBackupStateConflict;

  /// No description provided for @icloudBackupStateUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get icloudBackupStateUploaded;

  /// No description provided for @icloudBackupStateWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for iCloud'**
  String get icloudBackupStateWaiting;

  /// No description provided for @icloudBackupStatusSummary.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {lastModified}\nStatus: {remoteState}'**
  String icloudBackupStatusSummary(Object lastModified, Object remoteState);

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

  /// No description provided for @bgRunNeedsNotification.
  ///
  /// In en, this message translates to:
  /// **'Running in the background needs an ongoing notification, and this app has no notification permission. Tap to allow notifications.'**
  String get bgRunNeedsNotification;

  /// No description provided for @clearAllStatsContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all server connection statistics? This action cannot be undone.'**
  String get clearAllStatsContent;

  /// No description provided for @clearAllStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All Statistics'**
  String get clearAllStatsTitle;

  /// No description provided for @clearServerStatsContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear connection statistics for server \"{serverName}\"? This action cannot be undone.'**
  String clearServerStatsContent(Object serverName);

  /// No description provided for @clearServerStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear {serverName} Statistics'**
  String clearServerStatsTitle(Object serverName);

  /// No description provided for @clearThisServerStats.
  ///
  /// In en, this message translates to:
  /// **'Clear This Server Statistics'**
  String get clearThisServerStats;

  /// No description provided for @compactDatabase.
  ///
  /// In en, this message translates to:
  /// **'Compact Database'**
  String get compactDatabase;

  /// No description provided for @compactDatabaseContent.
  ///
  /// In en, this message translates to:
  /// **'Database size: {size}\n\nThis will reorganize the database to reduce file size. No data will be deleted.'**
  String compactDatabaseContent(Object size);

  /// No description provided for @closeAfterSave.
  ///
  /// In en, this message translates to:
  /// **'Save and close'**
  String get closeAfterSave;

  /// No description provided for @collapseUITip.
  ///
  /// In en, this message translates to:
  /// **'Whether to collapse long lists present in the UI by default'**
  String get collapseUITip;

  /// No description provided for @connectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Connection Details'**
  String get connectionDetails;

  /// No description provided for @connectionStats.
  ///
  /// In en, this message translates to:
  /// **'Connection Statistics'**
  String get connectionStats;

  /// No description provided for @connectionStatsDesc.
  ///
  /// In en, this message translates to:
  /// **'View server connection success rate and history'**
  String get connectionStatsDesc;

  /// No description provided for @containerTrySudoTip.
  ///
  /// In en, this message translates to:
  /// **'For example: In the app, the user is set to aaa, but Docker is installed under the root user. In this case, you need to enable this option.'**
  String get containerTrySudoTip;

  /// No description provided for @containerSudoPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Sudo password is required to access Docker. Please enter your password.'**
  String get containerSudoPasswordRequired;

  /// No description provided for @containerSudoPasswordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Sudo password is incorrect or not allowed. Please try again.'**
  String get containerSudoPasswordIncorrect;

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

  /// No description provided for @customCmd.
  ///
  /// In en, this message translates to:
  /// **'Custom commands'**
  String get customCmd;

  /// No description provided for @deleteServers.
  ///
  /// In en, this message translates to:
  /// **'Batch delete servers'**
  String get deleteServers;

  /// No description provided for @deleteDirRecursive.
  ///
  /// In en, this message translates to:
  /// **'Delete the folder and everything in it'**
  String get deleteDirRecursive;

  /// No description provided for @desktopTerminalTip.
  ///
  /// In en, this message translates to:
  /// **'Command used to open the terminal emulator when launching SSH sessions.'**
  String get desktopTerminalTip;

  /// No description provided for @dirEmpty.
  ///
  /// In en, this message translates to:
  /// **'Make sure the folder is empty.'**
  String get dirEmpty;

  /// No description provided for @discoverSshServers.
  ///
  /// In en, this message translates to:
  /// **'Discover SSH Servers'**
  String get discoverSshServers;

  /// No description provided for @discoveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Discovery failed'**
  String get discoveryFailed;

  /// No description provided for @discoverySettings.
  ///
  /// In en, this message translates to:
  /// **'Discovery Settings'**
  String get discoverySettings;

  /// No description provided for @distro.
  ///
  /// In en, this message translates to:
  /// **'Distribution'**
  String get distro;

  /// No description provided for @distroSwitchTip.
  ///
  /// In en, this message translates to:
  /// **'Replace {from} with {to}. Everything installed inside {from} is deleted, and {to} is downloaded and unpacked in its place.'**
  String distroSwitchTip(Object from, Object to);

  /// No description provided for @diskHealth.
  ///
  /// In en, this message translates to:
  /// **'Disk Health'**
  String get diskHealth;

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

  /// No description provided for @dockerProjectOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get dockerProjectOther;

  /// No description provided for @dockerPruneTip.
  ///
  /// In en, this message translates to:
  /// **'Remove unused data to free up disk space'**
  String get dockerPruneTip;

  /// No description provided for @dockerStatistics.
  ///
  /// In en, this message translates to:
  /// **'Docker Statistics'**
  String get dockerStatistics;

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
  /// **'Virtual keys'**
  String get editVirtKeys;

  /// No description provided for @editorHighlightTip.
  ///
  /// In en, this message translates to:
  /// **'The current code highlighting performance is not ideal and can be optionally turned off to improve.'**
  String get editorHighlightTip;

  /// No description provided for @enableMdns.
  ///
  /// In en, this message translates to:
  /// **'Enable mDNS'**
  String get enableMdns;

  /// No description provided for @enableMdnsDesc.
  ///
  /// In en, this message translates to:
  /// **'Use mDNS/Bonjour to discover SSH services'**
  String get enableMdnsDesc;

  /// No description provided for @envVars.
  ///
  /// In en, this message translates to:
  /// **'Environment variable'**
  String get envVars;

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

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File \'{file}\' too large {size}, max {sizeMax}'**
  String fileTooLarge(Object file, Object size, Object sizeMax);

  /// No description provided for @fileDirGone.
  ///
  /// In en, this message translates to:
  /// **'This folder is no longer here'**
  String get fileDirGone;

  /// No description provided for @fileDirGoneTip.
  ///
  /// In en, this message translates to:
  /// **'It was deleted or renamed'**
  String get fileDirGoneTip;

  /// No description provided for @fullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
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

  /// No description provided for @githubGistIdOptional.
  ///
  /// In en, this message translates to:
  /// **'Gist ID (optional)'**
  String get githubGistIdOptional;

  /// No description provided for @githubGistToken.
  ///
  /// In en, this message translates to:
  /// **'GitHub Gist token'**
  String get githubGistToken;

  /// No description provided for @githubGistTokenEmpty.
  ///
  /// In en, this message translates to:
  /// **'Token is empty'**
  String get githubGistTokenEmpty;

  /// No description provided for @goto.
  ///
  /// In en, this message translates to:
  /// **'Go to'**
  String get goto;

  /// No description provided for @homeTabs.
  ///
  /// In en, this message translates to:
  /// **'Home Tabs'**
  String get homeTabs;

  /// No description provided for @homeTabsCustomizeDesc.
  ///
  /// In en, this message translates to:
  /// **'Customize which tabs appear on the home page and their order'**
  String get homeTabsCustomizeDesc;

  /// No description provided for @ignoreCert.
  ///
  /// In en, this message translates to:
  /// **'Ignore certificate'**
  String get ignoreCert;

  /// A container image, as in Docker. NOT a picture — do not replace this with libL10n.image, whose German is "Bild" and Japanese "画像".
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// No description provided for @macDmgBody.
  ///
  /// In en, this message translates to:
  /// **'The App Store requires this app to be sandboxed, and a sandbox cannot open a terminal. The DMG build can.\n\nThe App Store build may stop being updated.'**
  String get macDmgBody;

  /// No description provided for @macDmgImportDenied.
  ///
  /// In en, this message translates to:
  /// **'macOS would not let this read the previous build’s data'**
  String get macDmgImportDenied;

  /// No description provided for @macDmgImported.
  ///
  /// In en, this message translates to:
  /// **'Imported the previous build’s data'**
  String get macDmgImported;

  /// No description provided for @macDmgImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the previous build’s data'**
  String get macDmgImportFailed;

  /// No description provided for @macDmgTip.
  ///
  /// In en, this message translates to:
  /// **'Local terminal and running snippets locally (DMG build)'**
  String get macDmgTip;

  /// No description provided for @macDmgTitle.
  ///
  /// In en, this message translates to:
  /// **'DMG build'**
  String get macDmgTitle;

  /// No description provided for @showHiddenFiles.
  ///
  /// In en, this message translates to:
  /// **'Show hidden files'**
  String get showHiddenFiles;

  /// No description provided for @sshKeyAlgorithm.
  ///
  /// In en, this message translates to:
  /// **'Algorithm'**
  String get sshKeyAlgorithm;

  /// No description provided for @sshKeyComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get sshKeyComment;

  /// No description provided for @sshKeyGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate key pair'**
  String get sshKeyGenerate;

  /// No description provided for @sshKeyGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get sshKeyGenerating;

  /// No description provided for @sshKeyLockedFmt.
  ///
  /// In en, this message translates to:
  /// **'The private key [{name}] was not unlocked.'**
  String sshKeyLockedFmt(String name);

  /// No description provided for @sshKeyPassphraseTip.
  ///
  /// In en, this message translates to:
  /// **'Optional. A key with a passphrase is stored encrypted, and you are asked for it the first time a connection uses the key.'**
  String get sshKeyPassphraseTip;

  /// No description provided for @sshKeyPassphraseWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong passphrase.'**
  String get sshKeyPassphraseWrong;

  /// No description provided for @sshKeyPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Public key'**
  String get sshKeyPublicKey;

  /// No description provided for @sshKeyPublicKeyTip.
  ///
  /// In en, this message translates to:
  /// **'Append this line to ~/.ssh/authorized_keys on the server.'**
  String get sshKeyPublicKeyTip;

  /// No description provided for @sshKeyRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get sshKeyRecommended;

  /// No description provided for @sshKeyUnlockTip.
  ///
  /// In en, this message translates to:
  /// **'Enter the passphrase for the private key [{name}].'**
  String sshKeyUnlockTip(String name);

  /// No description provided for @ungrouped.
  ///
  /// In en, this message translates to:
  /// **'Ungrouped'**
  String get ungrouped;

  /// No description provided for @unused.
  ///
  /// In en, this message translates to:
  /// **'Unused'**
  String get unused;

  /// No description provided for @dangling.
  ///
  /// In en, this message translates to:
  /// **'Dangling'**
  String get dangling;

  /// No description provided for @pruneUnusedImages.
  ///
  /// In en, this message translates to:
  /// **'Prune unused images'**
  String get pruneUnusedImages;

  /// No description provided for @pruneDanglingImages.
  ///
  /// In en, this message translates to:
  /// **'Prune dangling images'**
  String get pruneDanglingImages;

  /// No description provided for @pruneImages.
  ///
  /// In en, this message translates to:
  /// **'Prune images'**
  String get pruneImages;

  /// No description provided for @unusedTaggedImages.
  ///
  /// In en, this message translates to:
  /// **'Unused tagged'**
  String get unusedTaggedImages;

  /// No description provided for @pruneDanglingImagesTip.
  ///
  /// In en, this message translates to:
  /// **'Removes dangling images only.'**
  String get pruneDanglingImagesTip;

  /// No description provided for @pruneUnusedImagesTip.
  ///
  /// In en, this message translates to:
  /// **'Also remove tagged images not used by any container.'**
  String get pruneUnusedImagesTip;

  /// No description provided for @includeUnusedVolumesTip.
  ///
  /// In en, this message translates to:
  /// **'Also remove volumes not used by any container.'**
  String get includeUnusedVolumesTip;

  /// No description provided for @pruneCommandPreview.
  ///
  /// In en, this message translates to:
  /// **'Command preview'**
  String get pruneCommandPreview;

  /// No description provided for @pruneForceSshTip.
  ///
  /// In en, this message translates to:
  /// **'-f skips the interactive prompt and is always enabled for SSH execution.'**
  String get pruneForceSshTip;

  /// No description provided for @pruneVolumes.
  ///
  /// In en, this message translates to:
  /// **'Prune volumes'**
  String get pruneVolumes;

  /// No description provided for @pruneUnusedData.
  ///
  /// In en, this message translates to:
  /// **'Prune unused data'**
  String get pruneUnusedData;

  /// No description provided for @pull.
  ///
  /// In en, this message translates to:
  /// **'Pull'**
  String get pull;

  /// No description provided for @invalidHostFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid host format. Only IPv4, IPv6, and domain characters are allowed.'**
  String get invalidHostFormat;

  /// No description provided for @jumpServer.
  ///
  /// In en, this message translates to:
  /// **'Jump server'**
  String get jumpServer;

  /// No description provided for @jumpServersNotFoundFmt.
  ///
  /// In en, this message translates to:
  /// **'Jump servers not found for {serverName}: {jumpIds}'**
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds);

  /// No description provided for @nameAlreadyExistsFmt.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" already exists'**
  String nameAlreadyExistsFmt(Object name);

  /// No description provided for @noJumpServerAvailable.
  ///
  /// In en, this message translates to:
  /// **'No jump server available.'**
  String get noJumpServerAvailable;

  /// No description provided for @jumpServerAndProxyCommandCannotBeUsedTogether.
  ///
  /// In en, this message translates to:
  /// **'Jump server and ProxyCommand cannot be used together.'**
  String get jumpServerAndProxyCommandCannotBeUsedTogether;

  /// No description provided for @noConnectionMethod.
  ///
  /// In en, this message translates to:
  /// **'Configure SSH, a monitor agent, or both'**
  String get noConnectionMethod;

  /// No description provided for @preferredTransport.
  ///
  /// In en, this message translates to:
  /// **'Try first'**
  String get preferredTransport;

  /// No description provided for @preferredTransportTip.
  ///
  /// In en, this message translates to:
  /// **'Where status is read from, and which connection a command opens first. The other stays available.'**
  String get preferredTransportTip;

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

  /// No description provided for @lastFailure.
  ///
  /// In en, this message translates to:
  /// **'Last Failure'**
  String get lastFailure;

  /// No description provided for @lastSuccess.
  ///
  /// In en, this message translates to:
  /// **'Last Success'**
  String get lastSuccess;

  /// No description provided for @letterCache.
  ///
  /// In en, this message translates to:
  /// **'Normal keyboard input'**
  String get letterCache;

  /// No description provided for @letterCacheTip.
  ///
  /// In en, this message translates to:
  /// **'When enabled, input goes through the regular IME, which can avoid secure keyboard prompts in the terminal on some systems.'**
  String get letterCacheTip;

  /// No description provided for @linuxShellTip.
  ///
  /// In en, this message translates to:
  /// **'Which shell a terminal starts. Empty restores /bin/sh.'**
  String get linuxShellTip;

  /// No description provided for @linuxNetTip.
  ///
  /// In en, this message translates to:
  /// **'DNS servers. Empty restores the defaults'**
  String get linuxNetTip;

  /// No description provided for @madeWithLove.
  ///
  /// In en, this message translates to:
  /// **'Made with ❤️ by {myGithub}'**
  String madeWithLove(Object myGithub);

  /// No description provided for @maxConcurrency.
  ///
  /// In en, this message translates to:
  /// **'Max Concurrency'**
  String get maxConcurrency;

  /// No description provided for @maxRetryCount.
  ///
  /// In en, this message translates to:
  /// **'Number of server reconnections'**
  String get maxRetryCount;

  /// No description provided for @mismatchSystem.
  ///
  /// In en, this message translates to:
  /// **'Mismatch system: {system}'**
  String mismatchSystem(Object system);

  /// No description provided for @mirror.
  ///
  /// In en, this message translates to:
  /// **'Mirror'**
  String get mirror;

  /// No description provided for @needRestart.
  ///
  /// In en, this message translates to:
  /// **'App needs to be restarted'**
  String get needRestart;

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

  /// No description provided for @noConnectionStatsData.
  ///
  /// In en, this message translates to:
  /// **'No connection statistics data'**
  String get noConnectionStatsData;

  /// No description provided for @noLineChart.
  ///
  /// In en, this message translates to:
  /// **'Do not use line charts'**
  String get noLineChart;

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

  /// No description provided for @plugInType.
  ///
  /// In en, this message translates to:
  /// **'Insertion Type'**
  String get plugInType;

  /// No description provided for @preferDiskAmount.
  ///
  /// In en, this message translates to:
  /// **'Prioritize displaying disk capacity'**
  String get preferDiskAmount;

  /// No description provided for @privateKey.
  ///
  /// In en, this message translates to:
  /// **'Private Key'**
  String get privateKey;

  /// No description provided for @privateKeyNotFoundFmt.
  ///
  /// In en, this message translates to:
  /// **'Private key [{keyId}] not found.'**
  String privateKeyNotFoundFmt(Object keyId);

  /// No description provided for @bmcPowerOnAction.
  ///
  /// In en, this message translates to:
  /// **'Power on'**
  String get bmcPowerOnAction;

  /// No description provided for @bmcShutdown.
  ///
  /// In en, this message translates to:
  /// **'Shut down'**
  String get bmcShutdown;

  /// No description provided for @bmcForceOff.
  ///
  /// In en, this message translates to:
  /// **'Force off'**
  String get bmcForceOff;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @bmcPowerCycle.
  ///
  /// In en, this message translates to:
  /// **'Power cycle'**
  String get bmcPowerCycle;

  /// No description provided for @bmcPowerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Send this to {server}? The service will be asked for \"{resetType}\"'**
  String bmcPowerConfirm(String server, String resetType);

  /// No description provided for @bmcPowerDone.
  ///
  /// In en, this message translates to:
  /// **'The power state changed'**
  String get bmcPowerDone;

  /// No description provided for @bmcPowerAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted, but the power state has not changed. A graceful operation depends on the OS'**
  String get bmcPowerAccepted;

  /// No description provided for @bmcPowerUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This service allows nothing for that action'**
  String get bmcPowerUnsupported;

  /// No description provided for @bmcUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'The BMC refused the account'**
  String get bmcUnauthorized;

  /// No description provided for @bmcAccountMissing.
  ///
  /// In en, this message translates to:
  /// **'No account is set for this BMC'**
  String get bmcAccountMissing;

  /// No description provided for @bmcPowerOn.
  ///
  /// In en, this message translates to:
  /// **'Powered on'**
  String get bmcPowerOn;

  /// No description provided for @bmcPowerOff.
  ///
  /// In en, this message translates to:
  /// **'Powered off'**
  String get bmcPowerOff;

  /// No description provided for @bmcCertRejected.
  ///
  /// In en, this message translates to:
  /// **'Certificate refused — review it in the server settings'**
  String get bmcCertRejected;

  /// No description provided for @bmcNotAService.
  ///
  /// In en, this message translates to:
  /// **'No Redfish service at this address'**
  String get bmcNotAService;

  /// No description provided for @bmcNoSystem.
  ///
  /// In en, this message translates to:
  /// **'The service reports no system'**
  String get bmcNoSystem;

  /// No description provided for @bmcSensorsTruncated.
  ///
  /// In en, this message translates to:
  /// **'Only the first sensors are shown'**
  String get bmcSensorsTruncated;

  /// No description provided for @bmcMultipleSystems.
  ///
  /// In en, this message translates to:
  /// **'Only the first system is shown'**
  String get bmcMultipleSystems;

  /// No description provided for @bmcTip.
  ///
  /// In en, this message translates to:
  /// **'The BMC is a separate computer on the motherboard, reachable when the host OS is not. Configured here, it can report power state and hardware sensors while the server is off or hung. Needs Redfish, which most enterprise hardware from about 2016 on has.'**
  String get bmcTip;

  /// No description provided for @bmcCert.
  ///
  /// In en, this message translates to:
  /// **'Certificate'**
  String get bmcCert;

  /// No description provided for @bmcCertPinned.
  ///
  /// In en, this message translates to:
  /// **'Reviewed and pinned'**
  String get bmcCertPinned;

  /// No description provided for @bmcCertUnreviewed.
  ///
  /// In en, this message translates to:
  /// **'Not reviewed yet — tap to see the certificate'**
  String get bmcCertUnreviewed;

  /// No description provided for @bmcCertReview.
  ///
  /// In en, this message translates to:
  /// **'A self-signed certificate. Compare it before accepting. Only this exact one is trusted afterwards.'**
  String get bmcCertReview;

  /// No description provided for @bmcCertChanged.
  ///
  /// In en, this message translates to:
  /// **'The certificate does not match. Check it.'**
  String get bmcCertChanged;

  /// No description provided for @bmcCertExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired.'**
  String get bmcCertExpired;

  /// No description provided for @bmcCertWas.
  ///
  /// In en, this message translates to:
  /// **'Previously accepted: {fingerprint}'**
  String bmcCertWas(String fingerprint);

  /// No description provided for @bmcAddrInvalid.
  ///
  /// In en, this message translates to:
  /// **'The BMC address must be a URL, e.g. https://10.0.0.9'**
  String get bmcAddrInvalid;

  /// No description provided for @proxyCommandSandboxed.
  ///
  /// In en, this message translates to:
  /// **'This build is sandboxed: the command gets an empty home, not yours, so anything reading ~/.ssh fails. The DMG build is not.'**
  String get proxyCommandSandboxed;

  /// No description provided for @privateKeyFileUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Cannot read the private key file {path}: {reason}'**
  String privateKeyFileUnreadable(String path, String reason);

  /// No description provided for @privateKeyFileSandboxed.
  ///
  /// In en, this message translates to:
  /// **'This build cannot read files outside its own container, so the key at {path} is unreachable. Import the key in Settings, or use the DMG build.'**
  String privateKeyFileSandboxed(String path);

  /// No description provided for @pushToken.
  ///
  /// In en, this message translates to:
  /// **'Push token'**
  String get pushToken;

  /// No description provided for @proxyCommandOnlySupportedOnDesktop.
  ///
  /// In en, this message translates to:
  /// **'ProxyCommand is only supported on desktop platforms.'**
  String get proxyCommandOnlySupportedOnDesktop;

  /// No description provided for @pveIgnoreCertTip.
  ///
  /// In en, this message translates to:
  /// **'Not recommended to enable, beware of security risks! If you are using the default certificate from PVE, you need to enable this option.'**
  String get pveIgnoreCertTip;

  /// No description provided for @pveServerClientMissing.
  ///
  /// In en, this message translates to:
  /// **'The SSH client for this server is not available.'**
  String get pveServerClientMissing;

  /// No description provided for @pveAddressMissing.
  ///
  /// In en, this message translates to:
  /// **'The PVE address is missing. Please configure it in server settings.'**
  String get pveAddressMissing;

  /// No description provided for @pvePasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'PVE password is required. Please set it in server settings.'**
  String get pvePasswordRequired;

  /// No description provided for @pveOtpRequired.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication is enabled on this PVE server. Please enter the OTP code.'**
  String get pveOtpRequired;

  /// No description provided for @pveOtpChallengeExpired.
  ///
  /// In en, this message translates to:
  /// **'The OTP challenge has expired. Please refresh and try again.'**
  String get pveOtpChallengeExpired;

  /// No description provided for @pveOtpCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'OTP code is required.'**
  String get pveOtpCodeRequired;

  /// No description provided for @pveOtpVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'OTP verification failed. Please try again with a fresh code.'**
  String get pveOtpVerificationFailed;

  /// No description provided for @pveOtpTitle.
  ///
  /// In en, this message translates to:
  /// **'OTP Verification'**
  String get pveOtpTitle;

  /// No description provided for @pveOtpLabel.
  ///
  /// In en, this message translates to:
  /// **'OTP Code'**
  String get pveOtpLabel;

  /// No description provided for @pveInvalidResponseBody.
  ///
  /// In en, this message translates to:
  /// **'PVE login returned an invalid response body.'**
  String get pveInvalidResponseBody;

  /// No description provided for @pveInvalidResponseData.
  ///
  /// In en, this message translates to:
  /// **'PVE login response did not contain a valid data payload.'**
  String get pveInvalidResponseData;

  /// No description provided for @pveMissingAuthTicket.
  ///
  /// In en, this message translates to:
  /// **'PVE login succeeded but no authentication ticket was returned.'**
  String get pveMissingAuthTicket;

  /// No description provided for @pveVersionLow.
  ///
  /// In en, this message translates to:
  /// **'This feature is currently in the testing phase and has only been tested on PVE 8+. Please use it with caution.'**
  String get pveVersionLow;

  /// No description provided for @pveLoadingForwarding.
  ///
  /// In en, this message translates to:
  /// **'Establishing SSH tunnel...'**
  String get pveLoadingForwarding;

  /// No description provided for @pveLoadingLogin.
  ///
  /// In en, this message translates to:
  /// **'Authenticating with PVE...'**
  String get pveLoadingLogin;

  /// No description provided for @pveLoadingData.
  ///
  /// In en, this message translates to:
  /// **'Fetching cluster data...'**
  String get pveLoadingData;

  /// No description provided for @pveLoadingConnect.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get pveLoadingConnect;

  /// No description provided for @pvePassword.
  ///
  /// In en, this message translates to:
  /// **'PVE Password'**
  String get pvePassword;

  /// No description provided for @pvePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Required when using key-based SSH authentication'**
  String get pvePasswordHint;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @recentConnections.
  ///
  /// In en, this message translates to:
  /// **'Recent Connections'**
  String get recentConnections;

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

  /// No description provided for @remotePath.
  ///
  /// In en, this message translates to:
  /// **'Remote path'**
  String get remotePath;

  /// No description provided for @rootfsUpdateTip.
  ///
  /// In en, this message translates to:
  /// **'{distro} {installed} is installed; {latest} is available. Updating replaces the whole container: {pm} data is lost'**
  String rootfsUpdateTip(
    Object distro,
    Object installed,
    Object latest,
    Object pm,
  );

  /// No description provided for @linuxSystemInUse.
  ///
  /// In en, this message translates to:
  /// **'Close the terminals on {name} before deleting it'**
  String linuxSystemInUse(Object name);

  /// No description provided for @rootfsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A Linux userland on this device'**
  String get rootfsSubtitle;

  /// No description provided for @rootfsInstallTip.
  ///
  /// In en, this message translates to:
  /// **'Downloads {distro} {version} (about {size} MB) and unpacks it on this device.'**
  String rootfsInstallTip(Object distro, Object version, Object size);

  /// No description provided for @sameIdServerExist.
  ///
  /// In en, this message translates to:
  /// **'A server with the same ID already exists'**
  String get sameIdServerExist;

  /// No description provided for @second.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get second;

  /// No description provided for @serverFilesUnavailableTip.
  ///
  /// In en, this message translates to:
  /// **'Needs SSH to this server, or server_box_monitor installed with its file API on.'**
  String get serverFilesUnavailableTip;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @homeDir.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeDir;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selected(Object count);

  /// No description provided for @sendTo.
  ///
  /// In en, this message translates to:
  /// **'Send to…'**
  String get sendTo;

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

  /// No description provided for @serverTabRequired.
  ///
  /// In en, this message translates to:
  /// **'Server tab cannot be removed'**
  String get serverTabRequired;

  /// No description provided for @shareServerRiskTip.
  ///
  /// In en, this message translates to:
  /// **'This QR code holds the server’s connection settings in clear text. Anyone who scans or photographs it can connect.'**
  String get shareServerRiskTip;

  /// No description provided for @sftpDlPrepare.
  ///
  /// In en, this message translates to:
  /// **'Preparing to connect...'**
  String get sftpDlPrepare;

  /// No description provided for @sftpEditorTip.
  ///
  /// In en, this message translates to:
  /// **'Empty uses the built-in editor. For example `vim` (reading `EDITOR` is suggested).'**
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

  /// No description provided for @sftpUnavailableUseScp.
  ///
  /// In en, this message translates to:
  /// **'If this host has no SFTP subsystem, as many embedded devices do not, set its file transfer to SCP in the server settings.'**
  String get sftpUnavailableUseScp;

  /// No description provided for @sshFileTransportTip.
  ///
  /// In en, this message translates to:
  /// **'SFTP suits anything current. Choose SCP for an old or embedded host whose SSH server has no SFTP subsystem: it needs the `scp` command and a shell that also has the usual file utilities (`find`, `stat`, `mv`, `chmod`).'**
  String get sshFileTransportTip;

  /// No description provided for @specifyDev.
  ///
  /// In en, this message translates to:
  /// **'Specify device'**
  String get specifyDev;

  /// No description provided for @specifyDevTip.
  ///
  /// In en, this message translates to:
  /// **'Network traffic counts every device by default; name one here instead'**
  String get specifyDevTip;

  /// No description provided for @tempIsCelsiusTip.
  ///
  /// In en, this message translates to:
  /// **'When enabled, the temperature value will be treated as Celsius instead of millicelsius. Turn on only if the temperature displays incorrectly (e.g., showing 0.1°C instead of 58°C).'**
  String get tempIsCelsiusTip;

  /// No description provided for @spentTime.
  ///
  /// In en, this message translates to:
  /// **'Spent time: {time}'**
  String spentTime(Object time);

  /// No description provided for @sshConfigAllExist.
  ///
  /// In en, this message translates to:
  /// **'All servers already exist ({duplicateCount} duplicates found)'**
  String sshConfigAllExist(Object duplicateCount);

  /// No description provided for @sshConnectionModeTip.
  ///
  /// In en, this message translates to:
  /// **'Built-in: use the app\'s terminal. System SSH: launch the system ssh command in an external terminal.'**
  String get sshConnectionModeTip;

  /// No description provided for @sshConnectionModeUseBuiltin.
  ///
  /// In en, this message translates to:
  /// **'Use built-in terminal'**
  String get sshConnectionModeUseBuiltin;

  /// No description provided for @sshConnectionModeUseSystem.
  ///
  /// In en, this message translates to:
  /// **'Use system SSH'**
  String get sshConnectionModeUseSystem;

  /// No description provided for @sshConfigDuplicatesSkipped.
  ///
  /// In en, this message translates to:
  /// **'{duplicateCount} duplicates will be skipped'**
  String sshConfigDuplicatesSkipped(Object duplicateCount);

  /// No description provided for @sshConfigFound.
  ///
  /// In en, this message translates to:
  /// **'We found SSH configuration on your system.'**
  String get sshConfigFound;

  /// No description provided for @sshConfigFoundServers.
  ///
  /// In en, this message translates to:
  /// **'Found {totalCount} servers'**
  String sshConfigFoundServers(Object totalCount);

  /// No description provided for @sshConfigImport.
  ///
  /// In en, this message translates to:
  /// **'SSH Config Import'**
  String get sshConfigImport;

  /// No description provided for @sshConfigImportPermission.
  ///
  /// In en, this message translates to:
  /// **'Would you like to give permission to read ~/.ssh/config and automatically import server settings?'**
  String get sshConfigImportPermission;

  /// No description provided for @sshConfigImportTip.
  ///
  /// In en, this message translates to:
  /// **'Prompt to read ~/.ssh/config on first server creation'**
  String get sshConfigImportTip;

  /// No description provided for @sshConfigImported.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} servers from SSH config'**
  String sshConfigImported(Object count);

  /// No description provided for @sshHostKeyChangedDesc.
  ///
  /// In en, this message translates to:
  /// **'The SSH host key changed for {serverName}. Only continue if you trust this server.'**
  String sshHostKeyChangedDesc(Object serverName);

  /// Label for the SSH host key type displayed in the host key verification dialog.
  ///
  /// In en, this message translates to:
  /// **'SSH host key type'**
  String get sshHostKeyType;

  /// No description provided for @sshKnownHostKeys.
  ///
  /// In en, this message translates to:
  /// **'Known hosts'**
  String get sshKnownHostKeys;

  /// No description provided for @sshKnownHostKeysTip.
  ///
  /// In en, this message translates to:
  /// **'The host keys this app has accepted'**
  String get sshKnownHostKeysTip;

  /// No description provided for @sshHostKeyNewDesc.
  ///
  /// In en, this message translates to:
  /// **'A new SSH host key was received from {serverName}. Review the fingerprint before trusting.'**
  String sshHostKeyNewDesc(Object serverName);

  /// No description provided for @sshHostKeyStoredFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Stored fingerprint: {fingerprint}'**
  String sshHostKeyStoredFingerprint(Object fingerprint);

  /// Label for a one-time verification code requested during SSH keyboard-interactive authentication.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get sshVerificationCode;

  /// No description provided for @sshConfigManualSelect.
  ///
  /// In en, this message translates to:
  /// **'Would you like to select the SSH config file manually?'**
  String get sshConfigManualSelect;

  /// No description provided for @sshConfigNoServers.
  ///
  /// In en, this message translates to:
  /// **'No servers found in SSH config'**
  String get sshConfigNoServers;

  /// No description provided for @sshConfigPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Cannot access SSH config file due to macOS permissions.'**
  String get sshConfigPermissionDenied;

  /// No description provided for @sshConfigServersToImport.
  ///
  /// In en, this message translates to:
  /// **'{importCount} servers will be imported'**
  String sshConfigServersToImport(Object importCount);

  /// No description provided for @sshTermHelp.
  ///
  /// In en, this message translates to:
  /// **'When the terminal is scrollable, dragging horizontally can select text. Clicking the keyboard button turns the keyboard on/off. The file icon opens the current path SFTP. The clipboard button copies the content when text is selected, and pastes content from the clipboard into the terminal when no text is selected and there is content on the clipboard. The code icon pastes code snippets into the terminal and executes them.'**
  String get sshTermHelp;

  /// No description provided for @sshVirtualKeyAutoOff.
  ///
  /// In en, this message translates to:
  /// **'Auto switching of virtual keys'**
  String get sshVirtualKeyAutoOff;

  /// No description provided for @supportFmtArgs.
  ///
  /// In en, this message translates to:
  /// **'The following formatting parameters are supported:'**
  String get supportFmtArgs;

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

  /// No description provided for @syncAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Sync app settings'**
  String get syncAppSettings;

  /// No description provided for @syncAppSettingsTip.
  ///
  /// In en, this message translates to:
  /// **'Include theme, layout, editor, terminal and other device preferences in automatic sync.'**
  String get syncAppSettingsTip;

  /// No description provided for @termFontSizeTip.
  ///
  /// In en, this message translates to:
  /// **'This setting will affect the terminal size (width and height). You can zoom in on the terminal page to adjust the font size of the current session.'**
  String get termFontSizeTip;

  /// No description provided for @textScalerTip.
  ///
  /// In en, this message translates to:
  /// **'1.0 => 100% (original size), only works on server page part of the font, not recommended to change.'**
  String get textScalerTip;

  /// No description provided for @times.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get times;

  /// No description provided for @trySudo.
  ///
  /// In en, this message translates to:
  /// **'Try using sudo'**
  String get trySudo;

  /// No description provided for @sudoPromptNotFound.
  ///
  /// In en, this message translates to:
  /// **'No sudo password prompt is active.'**
  String get sudoPromptNotFound;

  /// No description provided for @updateServerStatusInterval.
  ///
  /// In en, this message translates to:
  /// **'Server status update interval'**
  String get updateServerStatusInterval;

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

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

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

  /// No description provided for @virtKeyHelpSnippet.
  ///
  /// In en, this message translates to:
  /// **'Pick a snippet and run it in this terminal.'**
  String get virtKeyHelpSnippet;

  /// No description provided for @virtKeyHelpTmux.
  ///
  /// In en, this message translates to:
  /// **'Switch between tmux sessions and windows.'**
  String get virtKeyHelpTmux;

  /// No description provided for @virtKeyIntroActions.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get virtKeyIntroActions;

  /// No description provided for @virtKeyIntroActionsTip.
  ///
  /// In en, this message translates to:
  /// **'These open something instead of typing. Hold one to read what it does.'**
  String get virtKeyIntroActionsTip;

  /// No description provided for @virtKeyIntroCustomizeTip.
  ///
  /// In en, this message translates to:
  /// **'Reorder these keys, or hide the ones you never reach for, in the terminal settings.'**
  String get virtKeyIntroCustomizeTip;

  /// No description provided for @virtKeyIntroModifiers.
  ///
  /// In en, this message translates to:
  /// **'Modifiers'**
  String get virtKeyIntroModifiers;

  /// No description provided for @virtKeyIntroModifiersTip.
  ///
  /// In en, this message translates to:
  /// **'Tap one to arm it, then tap a letter on the keyboard. It stays on for that one key.'**
  String get virtKeyIntroModifiersTip;

  /// No description provided for @virtKeyIntroNav.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get virtKeyIntroNav;

  /// No description provided for @virtKeyIntroNavTip.
  ///
  /// In en, this message translates to:
  /// **'These move the cursor. Hold an arrow to repeat it.'**
  String get virtKeyIntroNavTip;

  /// No description provided for @virtKeyIntroSelect.
  ///
  /// In en, this message translates to:
  /// **'Drag sideways over the terminal to select text, whenever it has something to scroll.'**
  String get virtKeyIntroSelect;

  /// No description provided for @virtKeyRows.
  ///
  /// In en, this message translates to:
  /// **'Rows shown at once'**
  String get virtKeyRows;

  /// No description provided for @virtKeyRowsTip.
  ///
  /// In en, this message translates to:
  /// **'The rest go on a page of their own, swiped sideways.'**
  String get virtKeyRowsTip;

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
  /// **'After connecting to the server, a script will be written to `~/.config/server_box` \n | `/tmp/server_box` to monitor the system status. You can review the script content.'**
  String get writeScriptTip;

  /// No description provided for @menuGitHubRepository.
  ///
  /// In en, this message translates to:
  /// **'GitHub Repository'**
  String get menuGitHubRepository;

  /// No description provided for @podmanDockerEmulationDetected.
  ///
  /// In en, this message translates to:
  /// **'Podman Docker emulation detected. Please switch to Podman in settings.'**
  String get podmanDockerEmulationDetected;

  /// No description provided for @betaTip.
  ///
  /// In en, this message translates to:
  /// **'This feature is still in beta testing. Functionality is not guaranteed.'**
  String get betaTip;

  /// No description provided for @portForward_startPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add a port forward rule to get started'**
  String get portForward_startPrompt;

  /// No description provided for @portForward_localHost.
  ///
  /// In en, this message translates to:
  /// **'Local Host'**
  String get portForward_localHost;

  /// No description provided for @portForward_localPort.
  ///
  /// In en, this message translates to:
  /// **'Local Port'**
  String get portForward_localPort;

  /// No description provided for @portForward_remoteHost.
  ///
  /// In en, this message translates to:
  /// **'Remote Host'**
  String get portForward_remoteHost;

  /// No description provided for @portForward_remotePort.
  ///
  /// In en, this message translates to:
  /// **'Remote Port'**
  String get portForward_remotePort;

  /// No description provided for @portForward_deleteConfirmFmt.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String portForward_deleteConfirmFmt(Object name);

  /// No description provided for @sponsor.
  ///
  /// In en, this message translates to:
  /// **'Sponsor'**
  String get sponsor;

  /// No description provided for @sortByJoinTime.
  ///
  /// In en, this message translates to:
  /// **'By join time'**
  String get sortByJoinTime;

  /// No description provided for @serverHistory.
  ///
  /// In en, this message translates to:
  /// **'Server history'**
  String get serverHistory;

  /// No description provided for @portForwardBetaTitle.
  ///
  /// In en, this message translates to:
  /// **'Port Forward (Beta)'**
  String get portForwardBetaTitle;

  /// No description provided for @tmuxAutoAttach.
  ///
  /// In en, this message translates to:
  /// **'tmux auto-attach'**
  String get tmuxAutoAttach;

  /// No description provided for @tmuxAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto tmux'**
  String get tmuxAuto;

  /// No description provided for @tmuxAutoTip.
  ///
  /// In en, this message translates to:
  /// **'Automatically start or attach tmux when connecting over SSH'**
  String get tmuxAutoTip;

  /// No description provided for @tmuxSessionSelector.
  ///
  /// In en, this message translates to:
  /// **'Session selector'**
  String get tmuxSessionSelector;

  /// No description provided for @tmuxSessionSelectorTip.
  ///
  /// In en, this message translates to:
  /// **'Show the session picker when connecting'**
  String get tmuxSessionSelectorTip;

  /// No description provided for @tmuxDefaultSessionName.
  ///
  /// In en, this message translates to:
  /// **'Default session name'**
  String get tmuxDefaultSessionName;

  /// No description provided for @tmuxSessionName.
  ///
  /// In en, this message translates to:
  /// **'Session name'**
  String get tmuxSessionName;

  /// No description provided for @tmuxExistingSessions.
  ///
  /// In en, this message translates to:
  /// **'Existing sessions'**
  String get tmuxExistingSessions;

  /// No description provided for @tmuxNewSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get tmuxNewSession;

  /// No description provided for @tmuxWindows.
  ///
  /// In en, this message translates to:
  /// **'Windows'**
  String get tmuxWindows;

  /// No description provided for @tmuxNewWindow.
  ///
  /// In en, this message translates to:
  /// **'New window'**
  String get tmuxNewWindow;

  /// No description provided for @tmuxNoWindowsFound.
  ///
  /// In en, this message translates to:
  /// **'No windows found'**
  String get tmuxNoWindowsFound;

  /// No description provided for @tmuxWindowCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 window} other{{count} windows}}'**
  String tmuxWindowCount(int count);

  /// No description provided for @tmuxPaneCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 pane} other{{count} panes}}'**
  String tmuxPaneCount(int count);

  /// No description provided for @tmuxAttached.
  ///
  /// In en, this message translates to:
  /// **'Attached'**
  String get tmuxAttached;

  /// No description provided for @tmuxActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get tmuxActive;

  /// No description provided for @tmuxActiveAt.
  ///
  /// In en, this message translates to:
  /// **'active: {time}'**
  String tmuxActiveAt(String time);

  /// No description provided for @tmuxAttachedAt.
  ///
  /// In en, this message translates to:
  /// **'attached: {time}'**
  String tmuxAttachedAt(String time);

  /// No description provided for @tmuxSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tmuxSkip;

  /// No description provided for @tmuxNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'tmux is not available'**
  String get tmuxNotAvailable;

  /// No description provided for @containerSegmentsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Unexpected container response segment count: {count}'**
  String containerSegmentsMismatch(int count);

  /// No description provided for @containerOperationInProgress.
  ///
  /// In en, this message translates to:
  /// **'Another container operation is already in progress'**
  String get containerOperationInProgress;

  /// No description provided for @processCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 process} other{{count} processes}}'**
  String processCount(int count);

  /// No description provided for @processParseUnsupportedOutput.
  ///
  /// In en, this message translates to:
  /// **'The process list format is not supported.'**
  String get processParseUnsupportedOutput;

  /// No description provided for @processParseInvalidRows.
  ///
  /// In en, this message translates to:
  /// **'Some process entries could not be read.'**
  String get processParseInvalidRows;

  /// No description provided for @processParseInvalidWindowsJson.
  ///
  /// In en, this message translates to:
  /// **'The Windows process response could not be read.'**
  String get processParseInvalidWindowsJson;

  /// No description provided for @processParseInvalidWindowsRows.
  ///
  /// In en, this message translates to:
  /// **'Some Windows process entries could not be read.'**
  String get processParseInvalidWindowsRows;

  /// No description provided for @processKillTargetChanged.
  ///
  /// In en, this message translates to:
  /// **'The process changed or exited. Refresh and try again.'**
  String get processKillTargetChanged;

  /// No description provided for @watchServers.
  ///
  /// In en, this message translates to:
  /// **'Servers on the watch'**
  String get watchServers;

  /// No description provided for @watchServersTip.
  ///
  /// In en, this message translates to:
  /// **'The watch fetches from the monitor on its own, so only servers with one can be picked.'**
  String get watchServersTip;

  /// No description provided for @watchNoMonitorServer.
  ///
  /// In en, this message translates to:
  /// **'No server has a monitor agent configured'**
  String get watchNoMonitorServer;

  /// No description provided for @legacyStatusGoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Status URLs no longer work'**
  String get legacyStatusGoneTitle;

  /// No description provided for @legacyStatusGoneBody.
  ///
  /// In en, this message translates to:
  /// **'The watch app and home widgets used to read a `/status` address typed by hand. That endpoint is gone: it could only report current values as text, which is why they could never show a chart.\n\nThey now read the monitor agent\'s authenticated API, so they draw trends and stay in step with the app on their own. Configure the server in the app once, and every watch and widget picks it up.'**
  String get legacyStatusGoneBody;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// No description provided for @starting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get starting;

  /// No description provided for @stopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get stopping;

  /// No description provided for @serviceManagerUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported service manager'**
  String get serviceManagerUnsupported;

  /// No description provided for @serviceManagerUnsupportedTip.
  ///
  /// In en, this message translates to:
  /// **'This server uses a service manager that ServerBox does not support yet. Supported managers: systemd, procd, and OpenRC.'**
  String get serviceManagerUnsupportedTip;

  /// No description provided for @serviceManagerFmt.
  ///
  /// In en, this message translates to:
  /// **'Managed by {manager}'**
  String serviceManagerFmt(String manager);

  /// No description provided for @serviceListFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not list services'**
  String get serviceListFailed;

  /// No description provided for @serviceDetailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Some service details are unavailable'**
  String get serviceDetailsUnavailable;

  /// No description provided for @serviceDetailsUnavailableTip.
  ///
  /// In en, this message translates to:
  /// **'The service list is usable, but the manager did not return all status or startup information.'**
  String get serviceDetailsUnavailableTip;

  /// No description provided for @serviceEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled at startup'**
  String get serviceEnabled;

  /// No description provided for @systemdMissing.
  ///
  /// In en, this message translates to:
  /// **'No systemd on this server'**
  String get systemdMissing;

  /// No description provided for @systemdMissingTip.
  ///
  /// In en, this message translates to:
  /// **'`systemctl` is not installed here, so there are no units to list.'**
  String get systemdMissingTip;

  /// No description provided for @initSystemFmt.
  ///
  /// In en, this message translates to:
  /// **'This machine appears to use {init}.'**
  String initSystemFmt(String init);

  /// No description provided for @systemdListFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not list units'**
  String get systemdListFailed;

  /// No description provided for @systemdUserScopeMissing.
  ///
  /// In en, this message translates to:
  /// **'User units are not listed'**
  String get systemdUserScopeMissing;

  /// No description provided for @systemdUserScopeMissingTip.
  ///
  /// In en, this message translates to:
  /// **'This account has no user session bus on the server, so only system units are shown.'**
  String get systemdUserScopeMissingTip;

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not run a command on this server'**
  String get serverUnreachable;

  /// No description provided for @containerNoRuntime.
  ///
  /// In en, this message translates to:
  /// **'No container runtime here'**
  String get containerNoRuntime;

  /// No description provided for @containerNoRuntimeTip.
  ///
  /// In en, this message translates to:
  /// **'Neither `docker` nor `podman` answered on this machine. If one is installed for another account, turn on \"Try using sudo\" in Settings.'**
  String get containerNoRuntimeTip;

  /// No description provided for @containerUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The container runtime answered in an unexpected form'**
  String get containerUnreadable;

  /// No description provided for @power.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get power;

  /// No description provided for @continueInTerminal.
  ///
  /// In en, this message translates to:
  /// **'Continue in terminal'**
  String get continueInTerminal;

  /// No description provided for @askAiRiskUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unclassified'**
  String get askAiRiskUnknown;

  /// No description provided for @agentLocalExec.
  ///
  /// In en, this message translates to:
  /// **'Run commands on this device'**
  String get agentLocalExec;

  /// No description provided for @agentLocalExecTip.
  ///
  /// In en, this message translates to:
  /// **'Lets the Agent work on the machine running ServerBox. Even read-only commands are reviewed'**
  String get agentLocalExecTip;

  /// No description provided for @agentLocalExecRootfsTip.
  ///
  /// In en, this message translates to:
  /// **'Lets the Agent work locally, confined to the Linux container ServerBox installed'**
  String get agentLocalExecRootfsTip;

  /// No description provided for @macDmgImportedPartly.
  ///
  /// In en, this message translates to:
  /// **'Imported the data of the previously installed build. Downloaded files were left where they were, in {path}.'**
  String macDmgImportedPartly(String path);

  /// No description provided for @bmcAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get bmcAccount;

  /// No description provided for @bmcAccountUnset.
  ///
  /// In en, this message translates to:
  /// **'None picked - tap to choose or create one'**
  String get bmcAccountUnset;

  /// No description provided for @bmcAccountShared.
  ///
  /// In en, this message translates to:
  /// **'Used by {count} servers'**
  String bmcAccountShared(int count);

  /// No description provided for @bmcAccounts.
  ///
  /// In en, this message translates to:
  /// **'BMC accounts'**
  String get bmcAccounts;

  /// No description provided for @bmcAccountSharedTip.
  ///
  /// In en, this message translates to:
  /// **'Editing this changes what all of them use.'**
  String get bmcAccountSharedTip;

  /// No description provided for @bmcAccountInUse.
  ///
  /// In en, this message translates to:
  /// **'{count} servers use it. They keep their address and lose the account.'**
  String bmcAccountInUse(int count);

  /// No description provided for @bmcStaleWrite.
  ///
  /// In en, this message translates to:
  /// **'The BMC changed while this was being written. Try again.'**
  String get bmcStaleWrite;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @privacyBlur.
  ///
  /// In en, this message translates to:
  /// **'Background privacy'**
  String get privacyBlur;

  /// No description provided for @privacyBlurTip.
  ///
  /// In en, this message translates to:
  /// **'Hide app content in the app switcher'**
  String get privacyBlurTip;

  /// No description provided for @floatReturnToTab.
  ///
  /// In en, this message translates to:
  /// **'Return to tab'**
  String get floatReturnToTab;

  /// No description provided for @termInFloatWindow.
  ///
  /// In en, this message translates to:
  /// **'This terminal is in the floating window'**
  String get termInFloatWindow;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'id',
    'it',
    'ja',
    'ko',
    'nl',
    'pt',
    'ru',
    'tr',
    'uk',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'nl':
      return AppLocalizationsNl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'uk':
      return AppLocalizationsUk();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
