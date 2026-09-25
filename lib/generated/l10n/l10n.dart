import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_az.dart';
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
    Locale('az'),
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

  /// User-facing label or message for appearance settings.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSettings;

  /// User-facing label or message for appearance preset.
  ///
  /// In en, this message translates to:
  /// **'Theme preset'**
  String get appearancePreset;

  /// User-facing label or message for appearance theme schema range.
  ///
  /// In en, this message translates to:
  /// **'Supported theme schema'**
  String get appearanceThemeSchemaRange;

  /// User-facing label or message for appearance theme install.
  ///
  /// In en, this message translates to:
  /// **'Install theme'**
  String get appearanceThemeInstall;

  /// User-facing label or message for appearance theme store.
  ///
  /// In en, this message translates to:
  /// **'Theme store'**
  String get appearanceThemeStore;

  /// User-facing label or message for appearance invalid theme.
  ///
  /// In en, this message translates to:
  /// **'Invalid theme package or catalog'**
  String get appearanceInvalidTheme;

  /// Shown when a manual refresh of the theme store could not read the catalog or any of its repositories.
  ///
  /// In en, this message translates to:
  /// **'Could not read the theme catalog.'**
  String get themeStoreRefreshFailed;

  /// Confirm dialog for deleting one installed theme. It also names what happens when that theme is the one in use.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”? Its files are removed from this device. If it is the theme in use, the app returns to the default theme.'**
  String themeStoreDeleteTheme(String name);

  /// How long ago the catalog on screen was read, under the repository names. {ago} is a phrase such as "5 minutes ago".
  ///
  /// In en, this message translates to:
  /// **'updated {ago}'**
  String themeStoreUpdatedFmt(String ago);

  /// How long ago the catalog on screen was read, when that was under a minute. Spelled out rather than composed with themeStoreUpdatedFmt because "just now" is a sentence of its own in every language.
  ///
  /// In en, this message translates to:
  /// **'updated just now'**
  String get themeStoreUpdatedJustNow;

  /// Sort option for the theme store: the theme in use, then the themes on this device, then what only the catalog offers.
  ///
  /// In en, this message translates to:
  /// **'In use first'**
  String get themeStoreSortInUse;

  /// At the end of the theme store's list, under the last theme. Markdown: the document is a link rather than an address the reader has to copy.
  ///
  /// In en, this message translates to:
  /// **'Want to make your own theme? [How to author one]({doc}) — thank you for contributing!'**
  String themeStoreMakeOwnFmt(String doc);

  /// Shown when a selected theme requires a newer app version. {version} is the required version.
  ///
  /// In en, this message translates to:
  /// **'Needs a newer app: {version}'**
  String appearanceThemeNeedsNewerApp(String version);

  /// User-facing label or message for appearance font families.
  ///
  /// In en, this message translates to:
  /// **'UI font families'**
  String get appearanceFontFamilies;

  /// Help text for the appearance font families setting or action.
  ///
  /// In en, this message translates to:
  /// **'One name per line; fonts are tried in order.'**
  String get appearanceFontFamiliesTip;

  /// User-facing label or message for appearance font import.
  ///
  /// In en, this message translates to:
  /// **'Import UI font file'**
  String get appearanceFontImport;

  /// User-facing label or message for appearance gradient.
  ///
  /// In en, this message translates to:
  /// **'Gradient'**
  String get appearanceGradient;

  /// User-facing label or message for appearance no background.
  ///
  /// In en, this message translates to:
  /// **'No background'**
  String get appearanceNoBackground;

  /// User-facing label or message for appearance icons.
  ///
  /// In en, this message translates to:
  /// **'In-app icons'**
  String get appearanceIcons;

  /// User-facing label or message for appearance corners.
  ///
  /// In en, this message translates to:
  /// **'Corners'**
  String get appearanceCorners;

  /// User-facing label or message for appearance card corners.
  ///
  /// In en, this message translates to:
  /// **'Card corners'**
  String get appearanceCardCorners;

  /// User-facing label or message for appearance tile corners.
  ///
  /// In en, this message translates to:
  /// **'Tile corners'**
  String get appearanceTileCorners;

  /// User-facing label or message for appearance button corners.
  ///
  /// In en, this message translates to:
  /// **'Button corners'**
  String get appearanceButtonCorners;

  /// User-facing label or message for crash collect.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic data'**
  String get crashCollect;

  /// Introductory text for the crash collect screen or section.
  ///
  /// In en, this message translates to:
  /// **'ServerBox records what happens while it runs so problems can be fixed. Choose how much information to send.'**
  String get crashCollectIntro;

  /// Empty-state message for crash collect none.
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get crashCollectNone;

  /// Help text for the crash collect none setting or action.
  ///
  /// In en, this message translates to:
  /// **'Reports remain on this device; after a crash, you can send one manually.'**
  String get crashCollectNoneTip;

  /// User-facing label or message for crash collect basic.
  ///
  /// In en, this message translates to:
  /// **'Basic information'**
  String get crashCollectBasic;

  /// Help text for the crash collect basic setting or action.
  ///
  /// In en, this message translates to:
  /// **'Only crash information is included; logs and performance data are not. **This helps us improve the app and fix bugs.**'**
  String get crashCollectBasicTip;

  /// User-facing label or message for crash collect full.
  ///
  /// In en, this message translates to:
  /// **'Full information'**
  String get crashCollectFull;

  /// Help text for the crash collect full setting or action.
  ///
  /// In en, this message translates to:
  /// **'Along with the crash log, performance data and which features are used are included: **they show what is slow, and which features are worth keeping.**'**
  String get crashCollectFullTip;

  /// User-facing label or message for crash collect footer.
  ///
  /// In en, this message translates to:
  /// **'At every level, known server names, addresses and usernames are replaced with placeholders when recorded. You can change the collection level later in Settings.'**
  String get crashCollectFooter;

  /// User-facing label or message for privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// User-facing label or message for privacy policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// Error message shown when crash last run failed.
  ///
  /// In en, this message translates to:
  /// **'ServerBox exited unexpectedly during its last run.'**
  String get crashLastRunFailed;

  /// Title shown for the crash report dialog or section.
  ///
  /// In en, this message translates to:
  /// **'Crash report'**
  String get crashReportTitle;

  /// Hint shown in the crash report field or section.
  ///
  /// In en, this message translates to:
  /// **'This is the log from the previous run. Known server names and addresses have been replaced with placeholders, but other details may remain. Please read it carefully before submitting.'**
  String get crashReportHint;

  /// User-facing label or message for crash report submit.
  ///
  /// In en, this message translates to:
  /// **'Copy & report'**
  String get crashReportSubmit;

  /// User-facing label or message for pre release updates.
  ///
  /// In en, this message translates to:
  /// **'Receive pre-release updates'**
  String get preReleaseUpdates;

  /// Help text for the add system private key setting or action.
  ///
  /// In en, this message translates to:
  /// **'Currently private keys don\'t exist, do you want to add the one that comes with the system (~/.ssh/id_rsa)?'**
  String get addSystemPrivateKeyTip;

  /// Action label for added 2 list.
  ///
  /// In en, this message translates to:
  /// **'Added to task list'**
  String get added2List;

  /// User-facing label or message for ask AI.
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get askAi;

  /// User-facing label or message for ask AI awaiting response.
  ///
  /// In en, this message translates to:
  /// **'Waiting for AI response...'**
  String get askAiAwaitingResponse;

  /// Help text for the ask AI endpoint setting or action.
  ///
  /// In en, this message translates to:
  /// **'Include the API version, such as /v1 — Zhipu uses /api/paas/v4. Only /chat/completions or /responses is added, from the protocol you pick.'**
  String get askAiEndpointTip;

  /// Help text for the ask AI protocol setting or action.
  ///
  /// In en, this message translates to:
  /// **'Auto tries Responses, then Chat Completions.'**
  String get askAiProtocolTip;

  /// User-facing label or message for ask AI command inserted.
  ///
  /// In en, this message translates to:
  /// **'Command inserted into terminal'**
  String get askAiCommandInserted;

  /// User-facing label or message for ask AI config missing.
  ///
  /// In en, this message translates to:
  /// **'Please configure {fields} in Settings.'**
  String askAiConfigMissing(String fields);

  /// User-facing label or message for ask AI disclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI may be incorrect. Review carefully before applying.'**
  String get askAiDisclaimer;

  /// User-facing label or message for ask AI insert terminal.
  ///
  /// In en, this message translates to:
  /// **'Insert into terminal'**
  String get askAiInsertTerminal;

  /// User-facing label or message for ask AI no response.
  ///
  /// In en, this message translates to:
  /// **'No response'**
  String get askAiNoResponse;

  /// User-facing label or message for remote desktop.
  ///
  /// In en, this message translates to:
  /// **'Remote desktop'**
  String get remoteDesktop;

  /// User-facing label or message for ask AI agent welcome.
  ///
  /// In en, this message translates to:
  /// **'What should we do on this server?'**
  String get askAiAgentWelcome;

  /// Hint shown in the ask AI agent prompt field or section.
  ///
  /// In en, this message translates to:
  /// **'Ask the Agent to inspect or fix something...'**
  String get askAiAgentPromptHint;

  /// User-facing label or message for ask AI analyze selection prompt.
  ///
  /// In en, this message translates to:
  /// **'Analyse the selected terminal output and explain what happened'**
  String get askAiAnalyzeSelectionPrompt;

  /// User-facing label or message for ask AI terminal context.
  ///
  /// In en, this message translates to:
  /// **'Terminal context'**
  String get askAiTerminalContext;

  /// User-facing label or message for ask AI review needed.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get askAiReviewNeeded;

  /// User-facing label or message for ask AI review action.
  ///
  /// In en, this message translates to:
  /// **'Review proposed command'**
  String get askAiReviewAction;

  /// User-facing label or message for ask AI review before continuing.
  ///
  /// In en, this message translates to:
  /// **'Review or decline the current suggestion first'**
  String get askAiReviewBeforeContinuing;

  /// User-facing label or message for ask AI approve run.
  ///
  /// In en, this message translates to:
  /// **'Approve & run'**
  String get askAiApproveRun;

  /// User-facing label or message for ask AI decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get askAiDecline;

  /// User-facing label or message for ask AI action declined.
  ///
  /// In en, this message translates to:
  /// **'The proposed command was declined.'**
  String get askAiActionDeclined;

  /// User-facing label or message for ask AI interrupted.
  ///
  /// In en, this message translates to:
  /// **'Agent response was interrupted.'**
  String get askAiInterrupted;

  /// User-facing label or message for ask AI resend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get askAiResend;

  /// Help text for the ask AI resend setting or action.
  ///
  /// In en, this message translates to:
  /// **'Everything after this message is discarded — the replies, the commands and their results.'**
  String get askAiResendTip;

  /// Help text for the ask AI delete setting or action.
  ///
  /// In en, this message translates to:
  /// **'This message and everything after it are removed — the replies, the commands and their results.'**
  String get askAiDeleteTip;

  /// User-facing label or message for ask AI model table.
  ///
  /// In en, this message translates to:
  /// **'Model table'**
  String get askAiModelTable;

  /// Help text for the ask AI model table setting or action.
  ///
  /// In en, this message translates to:
  /// **'Context sizes by model name, from models.dev. One ships with the app; tap to fetch a newer one.'**
  String get askAiModelTableTip;

  /// User-facing label or message for ask AI context fallback.
  ///
  /// In en, this message translates to:
  /// **'not in the table'**
  String get askAiContextFallback;

  /// User-facing label or message for ask AI compact at.
  ///
  /// In en, this message translates to:
  /// **'Summarise at'**
  String get askAiCompactAt;

  /// Help text for the ask AI compact at setting or action.
  ///
  /// In en, this message translates to:
  /// **'How full the model’s context gets before earlier turns are summarised. Earlier loses detail sooner; later risks a request the model refuses.'**
  String get askAiCompactAtTip;

  /// User-facing label or message for ask AI context tokens.
  ///
  /// In en, this message translates to:
  /// **'Context size'**
  String get askAiContextTokens;

  /// Help text for the ask AI context tokens setting or action.
  ///
  /// In en, this message translates to:
  /// **'How many tokens this model holds. Automatic looks it up by name; set a number when your provider serves a shorter window than the model has.'**
  String get askAiContextTokensTip;

  /// User-facing label or message for ask AI conversation compacted.
  ///
  /// In en, this message translates to:
  /// **'Earlier messages were summarised to keep the conversation going.'**
  String get askAiConversationCompacted;

  /// User-facing label or message for ask AI risk read only.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get askAiRiskReadOnly;

  /// User-facing label or message for ask AI risk caution.
  ///
  /// In en, this message translates to:
  /// **'Changes system'**
  String get askAiRiskCaution;

  /// User-facing label or message for ask AI risk unvetted.
  ///
  /// In en, this message translates to:
  /// **'Unvetted host'**
  String get askAiRiskUnvetted;

  /// User-facing label or message for ask AI risk destructive.
  ///
  /// In en, this message translates to:
  /// **'High risk'**
  String get askAiRiskDestructive;

  /// Title shown for the ask AI high risk confirm dialog or section.
  ///
  /// In en, this message translates to:
  /// **'Run high-risk command?'**
  String get askAiHighRiskConfirmTitle;

  /// Explanatory message shown in the ask AI high risk confirm dialog or notice.
  ///
  /// In en, this message translates to:
  /// **'This command may make changes that are hard to undo. Check it carefully.'**
  String get askAiHighRiskConfirmBody;

  /// User-facing label or message for ask AI no command output.
  ///
  /// In en, this message translates to:
  /// **'Command completed without output.'**
  String get askAiNoCommandOutput;

  /// User-facing label or message for ask AI output truncated.
  ///
  /// In en, this message translates to:
  /// **'Long output was truncated before it was sent back to the Agent.'**
  String get askAiOutputTruncated;

  /// User-facing label or message for ask AI auto approved.
  ///
  /// In en, this message translates to:
  /// **'Auto-approved'**
  String get askAiAutoApproved;

  /// User-facing label or message for ask AI auto run safe commands.
  ///
  /// In en, this message translates to:
  /// **'Auto-run read-only commands'**
  String get askAiAutoRunSafeCommands;

  /// Help text for the ask AI auto run safe commands setting or action.
  ///
  /// In en, this message translates to:
  /// **'Runs only when both the model and the local check call it read-only'**
  String get askAiAutoRunSafeCommandsTip;

  /// User-facing label or message for ask AI send on enter.
  ///
  /// In en, this message translates to:
  /// **'Enter sends'**
  String get askAiSendOnEnter;

  /// Help text for the ask AI send on enter setting or action.
  ///
  /// In en, this message translates to:
  /// **'Enter sends, Shift+Enter for a new line. Off: Enter for a new line, Cmd/Ctrl+Enter sends.'**
  String get askAiSendOnEnterTip;

  /// User-facing label or message for ask AI API key optional.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for local or unauthenticated'**
  String get askAiApiKeyOptional;

  /// User-facing label or message for ask AI allow insecure.
  ///
  /// In en, this message translates to:
  /// **'Allow plain HTTP'**
  String get askAiAllowInsecure;

  /// Help text for the ask AI allow insecure setting or action.
  ///
  /// In en, this message translates to:
  /// **'Allows http:// connections to self-hosted models at non-localhost addresses. The API key and any terminal context are sent unencrypted; localhost is unaffected.'**
  String get askAiAllowInsecureTip;

  /// User-facing label or message for ask AI insecure endpoint.
  ///
  /// In en, this message translates to:
  /// **'This endpoint uses http://. Turn on “Allow plain HTTP” in AI settings to use it.'**
  String get askAiInsecureEndpoint;

  /// User-facing label or message for ask AI history.
  ///
  /// In en, this message translates to:
  /// **'Conversation history'**
  String get askAiHistory;

  /// User-facing label or message for ask AI new conversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get askAiNewConversation;

  /// User-facing label or message for ask AI no history.
  ///
  /// In en, this message translates to:
  /// **'No saved conversations yet'**
  String get askAiNoHistory;

  /// User-facing label or message for ask AI no history messages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get askAiNoHistoryMessages;

  /// User-facing label or message for ask AI untitled conversation.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get askAiUntitledConversation;

  /// User-facing label or message for ask AI rename conversation.
  ///
  /// In en, this message translates to:
  /// **'Rename conversation'**
  String get askAiRenameConversation;

  /// Title shown for the ask AI delete conversation dialog or section.
  ///
  /// In en, this message translates to:
  /// **'Delete this conversation?'**
  String get askAiDeleteConversationTitle;

  /// Help text for the ask AI delete conversation setting or action.
  ///
  /// In en, this message translates to:
  /// **'Deletes it from this device. Cannot be undone.'**
  String get askAiDeleteConversationTip;

  /// Title shown for the ask AI clear history dialog or section.
  ///
  /// In en, this message translates to:
  /// **'Clear this server\'s Agent history?'**
  String get askAiClearHistoryTitle;

  /// Help text for the ask AI clear history setting or action.
  ///
  /// In en, this message translates to:
  /// **'Every saved Agent conversation for this server will be deleted.'**
  String get askAiClearHistoryTip;

  /// User-facing label or message for ask AI restored review.
  ///
  /// In en, this message translates to:
  /// **'This command came from history. Review it again'**
  String get askAiRestoredReview;

  /// User-facing label or message for agent welcome.
  ///
  /// In en, this message translates to:
  /// **'What should we do across your servers?'**
  String get agentWelcome;

  /// Help text for the agent welcome setting or action.
  ///
  /// In en, this message translates to:
  /// **'Have the Agent diagnose a problem or carry out a task'**
  String get agentWelcomeTip;

  /// Hint shown in the agent prompt field or section.
  ///
  /// In en, this message translates to:
  /// **'Ask the Agent to inspect or operate your servers...'**
  String get agentPromptHint;

  /// User-facing label or message for agent no history.
  ///
  /// In en, this message translates to:
  /// **'No saved global Agent conversations'**
  String get agentNoHistory;

  /// Title shown for the agent clear history dialog or section.
  ///
  /// In en, this message translates to:
  /// **'Clear global Agent history?'**
  String get agentClearHistoryTitle;

  /// Help text for the agent clear history setting or action.
  ///
  /// In en, this message translates to:
  /// **'All global Agent conversations will be removed from this device.'**
  String get agentClearHistoryTip;

  /// User-facing label or message for agent tool shell.
  ///
  /// In en, this message translates to:
  /// **'Shell'**
  String get agentToolShell;

  /// User-facing label or message for agent tool read file.
  ///
  /// In en, this message translates to:
  /// **'Read file'**
  String get agentToolReadFile;

  /// User-facing label or message for agent tool write file.
  ///
  /// In en, this message translates to:
  /// **'Write file'**
  String get agentToolWriteFile;

  /// Error message shown when agent tool failed.
  ///
  /// In en, this message translates to:
  /// **'Tool execution failed.'**
  String get agentToolFailed;

  /// Formatted user-facing message for agent tool calls; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'{count} tool calls'**
  String agentToolCallsFmt(int count);

  /// User-facing label or message for float over tabs.
  ///
  /// In en, this message translates to:
  /// **'Float over other tabs'**
  String get floatOverTabs;

  /// User-facing label or message for agent tool SSH connect.
  ///
  /// In en, this message translates to:
  /// **'SSH connect'**
  String get agentToolSshConnect;

  /// User-facing label or message for agent tool SSH disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect SSH'**
  String get agentToolSshDisconnect;

  /// Title shown for the agent SSH connect dialog or section.
  ///
  /// In en, this message translates to:
  /// **'Connect to a new host'**
  String get agentSshConnectTitle;

  /// User-facing label or message for agent auth method.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get agentAuthMethod;

  /// Help text for the agent SSH connect setting or action.
  ///
  /// In en, this message translates to:
  /// **'The Agent wants an SSH connection. Enter the password here'**
  String get agentSshConnectTip;

  /// User-facing label or message for agent ad hoc sessions.
  ///
  /// In en, this message translates to:
  /// **'Temporary connections'**
  String get agentAdHocSessions;

  /// Title shown for the agent save server dialog or section.
  ///
  /// In en, this message translates to:
  /// **'Save as a server'**
  String get agentSaveServerTitle;

  /// Help text for the agent save server setting or action.
  ///
  /// In en, this message translates to:
  /// **'This host and the password you enter are saved on this device'**
  String get agentSaveServerTip;

  /// User-facing label or message for agent monitor optional.
  ///
  /// In en, this message translates to:
  /// **'Monitor agent (optional)'**
  String get agentMonitorOptional;

  /// Help text for the auth fail setting or action.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Check the details'**
  String get authFailTip;

  /// User-facing label or message for auto backup conflict.
  ///
  /// In en, this message translates to:
  /// **'Only one automatic backup can be turned on at the same time.'**
  String get autoBackupConflict;

  /// User-facing label or message for auto connect.
  ///
  /// In en, this message translates to:
  /// **'Auto connect'**
  String get autoConnect;

  /// User-facing label or message for auto run.
  ///
  /// In en, this message translates to:
  /// **'Auto run'**
  String get autoRun;

  /// User-facing label or message for auto update home widget.
  ///
  /// In en, this message translates to:
  /// **'Automatic home widget update'**
  String get autoUpdateHomeWidget;

  /// User-facing label or message for available tabs.
  ///
  /// In en, this message translates to:
  /// **'Available Tabs'**
  String get availableTabs;

  /// User-facing label or message for backup encrypted.
  ///
  /// In en, this message translates to:
  /// **'Backup is encrypted'**
  String get backupEncrypted;

  /// User-facing label or message for backup not encrypted.
  ///
  /// In en, this message translates to:
  /// **'Backup is not encrypted'**
  String get backupNotEncrypted;

  /// User-facing label or message for backup password.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get backupPassword;

  /// User-facing label or message for backup password removed.
  ///
  /// In en, this message translates to:
  /// **'Backup password removed'**
  String get backupPasswordRemoved;

  /// User-facing label or message for backup password set.
  ///
  /// In en, this message translates to:
  /// **'Backup password set'**
  String get backupPasswordSet;

  /// Help text for the backup password setting or action.
  ///
  /// In en, this message translates to:
  /// **'Set a password to encrypt backup files. Leave empty to disable encryption.'**
  String get backupPasswordTip;

  /// User-facing label or message for backup password wrong.
  ///
  /// In en, this message translates to:
  /// **'Incorrect backup password'**
  String get backupPasswordWrong;

  /// Action label for connect all.
  ///
  /// In en, this message translates to:
  /// **'Connect all'**
  String get connectAll;

  /// Action label for disconnect all.
  ///
  /// In en, this message translates to:
  /// **'Disconnect all'**
  String get disconnectAll;

  /// User-facing label or message for dist icon.
  ///
  /// In en, this message translates to:
  /// **'Distribution marks'**
  String get distIcon;

  /// User-facing label or message for dist icon intro legal.
  ///
  /// In en, this message translates to:
  /// **'A mark says only what this device read from the remote system, which can be wrong or out of date, and identifies neither a derivative, a rebuild, nor any particular version. Where it cannot be identified, a plain icon is drawn.\n\nEach mark is a trademark of its respective owner and is used only to refer to the system it identifies.'**
  String get distIconIntroLegal;

  /// Help text for the dist icon setting or action.
  ///
  /// In en, this message translates to:
  /// **'Show a small mark beside each server for the system it appears to be running.'**
  String get distIconTip;

  /// User-facing label or message for dist name map.
  ///
  /// In en, this message translates to:
  /// **'Name overrides'**
  String get distNameMap;

  /// Help text for the dist name map setting or action.
  ///
  /// In en, this message translates to:
  /// **'Only for a distribution whose file is named something else where you host the marks. The key is the name this app uses; the value is the name to fetch. Leave it empty unless a mark is missing.'**
  String get distNameMapTip;

  /// User-facing label or message for logo URL.
  ///
  /// In en, this message translates to:
  /// **'Logo URL'**
  String get logoUrl;

  /// Help text for the logo URL setting or action.
  ///
  /// In en, this message translates to:
  /// **'The large image at the top of a server\'s own page, drawn in its own colours.'**
  String get logoUrlTip;

  /// User-facing label or message for globe.
  ///
  /// In en, this message translates to:
  /// **'Globe'**
  String get globe;

  /// Help text for the location setting or action.
  ///
  /// In en, this message translates to:
  /// **'Where this server is drawn on the globe. Latitude then longitude, in degrees — for example 39.9042, 116.4074.'**
  String get locationTip;

  /// User-facing label or message for mark URL.
  ///
  /// In en, this message translates to:
  /// **'Mark URL'**
  String get markUrl;

  /// Help text for the mark URL setting or action.
  ///
  /// In en, this message translates to:
  /// **'The small mark beside a server\'s name in lists. Empty means none is drawn.\n\nNot the same picture as the logo'**
  String get markUrlTip;

  /// Help text for the nav tab menu setting or action.
  ///
  /// In en, this message translates to:
  /// **'Long press a tab — or right-click it — to connect or disconnect everything on it at once.'**
  String get navTabMenuTip;

  /// User-facing label or message for n tags.
  ///
  /// In en, this message translates to:
  /// **'{count} Tags'**
  String nTags(int count);

  /// User-facing label or message for remote backup password required.
  ///
  /// In en, this message translates to:
  /// **'Remote backups require a non-empty backup password'**
  String get remoteBackupPasswordRequired;

  /// User-facing label or message for monitor HTTPS required.
  ///
  /// In en, this message translates to:
  /// **'A remote monitor agent needs HTTPS, unless HTTP is allowed for it.'**
  String get monitorHttpsRequired;

  /// User-facing label or message for monitor allow insecure HTTP.
  ///
  /// In en, this message translates to:
  /// **'Allow HTTP'**
  String get monitorAllowInsecureHttp;

  /// Title shown for the plain HTTP dialog or section.
  ///
  /// In en, this message translates to:
  /// **'This agent is served over plain HTTP'**
  String get plainHttpTitle;

  /// Help text for the plain HTTP setting or action.
  ///
  /// In en, this message translates to:
  /// **'The password and everything this app asks for would travel unencrypted. Nothing has been sent yet.'**
  String get plainHttpTip;

  /// User-facing label or message for allow for this server.
  ///
  /// In en, this message translates to:
  /// **'Allow for this server'**
  String get allowForThisServer;

  /// Error message shown when view error.
  ///
  /// In en, this message translates to:
  /// **'View error'**
  String get viewError;

  /// Help text for the monitor allow insecure HTTP setting or action.
  ///
  /// In en, this message translates to:
  /// **'Only on a trusted private network that encrypts the transport itself, such as Tailscale'**
  String get monitorAllowInsecureHttpTip;

  /// Help text for the monitor HTTP setting or action.
  ///
  /// In en, this message translates to:
  /// **'Read this server\'s status from a **monitor** agent\'s HTTP API instead of running commands over SSH.\n\nThe agent has to be installed on the server first, and it is what makes trends, the watch app and the home-screen widgets possible.\n\n[Setting up a monitor agent]({url})'**
  String monitorHttpTip(String url);

  /// Help text for the backup setting or action.
  ///
  /// In en, this message translates to:
  /// **'The exported data can be encrypted with password. \nPlease keep it safe.'**
  String get backupTip;

  /// Title shown for the iCloud backup status dialog or section.
  ///
  /// In en, this message translates to:
  /// **'Backup status'**
  String get icloudBackupStatusTitle;

  /// Status message shown while iCloud backup status loading.
  ///
  /// In en, this message translates to:
  /// **'Loading iCloud backup status...'**
  String get icloudBackupStatusLoading;

  /// Error message shown when iCloud backup status error.
  ///
  /// In en, this message translates to:
  /// **'Unable to read iCloud backup metadata'**
  String get icloudBackupStatusError;

  /// Empty-state message for iCloud backup status empty.
  ///
  /// In en, this message translates to:
  /// **'No iCloud backup file found yet'**
  String get icloudBackupStatusEmpty;

  /// User-facing label or message for iCloud backup state uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get icloudBackupStateUploading;

  /// User-facing label or message for iCloud backup state conflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict detected'**
  String get icloudBackupStateConflict;

  /// User-facing label or message for iCloud backup state uploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get icloudBackupStateUploaded;

  /// User-facing label or message for iCloud backup state waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for iCloud'**
  String get icloudBackupStateWaiting;

  /// User-facing label or message for iCloud backup status summary.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {lastModified}\nStatus: {remoteState}'**
  String icloudBackupStatusSummary(String lastModified, String remoteState);

  /// User-facing label or message for bg run.
  ///
  /// In en, this message translates to:
  /// **'Run in background'**
  String get bgRun;

  /// Help text for the bg run setting or action.
  ///
  /// In en, this message translates to:
  /// **'This switch only means the program will try to run in the background. Whether it can run in the background depends on whether the permission is enabled or not. For AOSP-based Android ROMs, please disable \"Battery Optimization\" in this app. For MIUI / HyperOS, please change the power saving policy to \"Unlimited\".'**
  String get bgRunTip;

  /// User-facing label or message for tray readings.
  ///
  /// In en, this message translates to:
  /// **'Readings'**
  String get trayReadings;

  /// User-facing label or message for tray chart.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get trayChart;

  /// Empty-state message for tray chart none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get trayChartNone;

  /// User-facing label or message for tray compact.
  ///
  /// In en, this message translates to:
  /// **'Compact rows'**
  String get trayCompact;

  /// Help text for the tray compact setting or action.
  ///
  /// In en, this message translates to:
  /// **'One line per server, without the chart. Linux always uses a single-line layout because its panel menu is sent over D-Bus, which carries a label rather than a custom layout; it may still include the selected chart as an image.'**
  String get trayCompactTip;

  /// Status message shown while tray keep running.
  ///
  /// In en, this message translates to:
  /// **'Keep running in the tray'**
  String get trayKeepRunning;

  /// Help text for the tray keep running setting or action.
  ///
  /// In en, this message translates to:
  /// **'Closing the window leaves the app in the menu bar or notification area, still watching your servers. Turn this off to have the close button end the app.'**
  String get trayKeepRunningTip;

  /// User-facing label or message for bg run needs notification.
  ///
  /// In en, this message translates to:
  /// **'Running in the background needs an ongoing notification, and this app has no notification permission. Tap to allow notifications.'**
  String get bgRunNeedsNotification;

  /// Action label for clear all stats content.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all server connection statistics? This action cannot be undone.'**
  String get clearAllStatsContent;

  /// Title shown for the clear all stats dialog or section.
  ///
  /// In en, this message translates to:
  /// **'Clear All Statistics'**
  String get clearAllStatsTitle;

  /// Action label for clear server stats content.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear connection statistics for server \"{serverName}\"? This action cannot be undone.'**
  String clearServerStatsContent(String serverName);

  /// Title shown for the clear server stats dialog or section.
  ///
  /// In en, this message translates to:
  /// **'Clear {serverName} Statistics'**
  String clearServerStatsTitle(String serverName);

  /// Action label for clear this server stats.
  ///
  /// In en, this message translates to:
  /// **'Clear This Server Statistics'**
  String get clearThisServerStats;

  /// Action label for close after save.
  ///
  /// In en, this message translates to:
  /// **'Save and close'**
  String get closeAfterSave;

  /// Help text for the collapse UI setting or action.
  ///
  /// In en, this message translates to:
  /// **'Whether to collapse long lists present in the UI by default'**
  String get collapseUITip;

  /// Action label for connection details.
  ///
  /// In en, this message translates to:
  /// **'Connection Details'**
  String get connectionDetails;

  /// Action label for connection stats.
  ///
  /// In en, this message translates to:
  /// **'Connection Statistics'**
  String get connectionStats;

  /// Description of the connection stats desc feature or option.
  ///
  /// In en, this message translates to:
  /// **'View server connection success rate and history'**
  String get connectionStatsDesc;

  /// Help text for the container try sudo setting or action.
  ///
  /// In en, this message translates to:
  /// **'For example: In the app, the user is set to aaa, but Docker is installed under the root user. In this case, you need to enable this option.'**
  String get containerTrySudoTip;

  /// User-facing label or message for container sudo password required.
  ///
  /// In en, this message translates to:
  /// **'Sudo password is required to access Docker. Please enter your password.'**
  String get containerSudoPasswordRequired;

  /// User-facing label or message for container sudo password incorrect.
  ///
  /// In en, this message translates to:
  /// **'Sudo password is incorrect or not allowed. Please try again.'**
  String get containerSudoPasswordIncorrect;

  /// Action label for copy path.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get copyPath;

  /// Help text for the CPU view as progress setting or action.
  ///
  /// In en, this message translates to:
  /// **'Display the usage of each CPU in a progress bar style (old style)'**
  String get cpuViewAsProgressTip;

  /// User-facing label or message for custom cmd.
  ///
  /// In en, this message translates to:
  /// **'Custom commands'**
  String get customCmd;

  /// Action label for delete servers.
  ///
  /// In en, this message translates to:
  /// **'Batch delete servers'**
  String get deleteServers;

  /// Action label for delete dir recursive.
  ///
  /// In en, this message translates to:
  /// **'Delete the folder and everything in it'**
  String get deleteDirRecursive;

  /// Help text for the desktop terminal setting or action.
  ///
  /// In en, this message translates to:
  /// **'Command used to open the terminal emulator when launching SSH sessions.'**
  String get desktopTerminalTip;

  /// Empty-state message for dir empty.
  ///
  /// In en, this message translates to:
  /// **'Make sure the folder is empty.'**
  String get dirEmpty;

  /// User-facing label or message for discover SSH servers.
  ///
  /// In en, this message translates to:
  /// **'Discover SSH Servers'**
  String get discoverSshServers;

  /// Error message shown when discovery failed.
  ///
  /// In en, this message translates to:
  /// **'Discovery failed'**
  String get discoveryFailed;

  /// User-facing label or message for discovery settings.
  ///
  /// In en, this message translates to:
  /// **'Discovery Settings'**
  String get discoverySettings;

  /// User-facing label or message for distro.
  ///
  /// In en, this message translates to:
  /// **'Distribution'**
  String get distro;

  /// User-facing label or message for disk health.
  ///
  /// In en, this message translates to:
  /// **'Disk Health'**
  String get diskHealth;

  /// User-facing label or message for display CPU index.
  ///
  /// In en, this message translates to:
  /// **'Display CPU index'**
  String get displayCpuIndex;

  /// User-facing label or message for dl 2 local.
  ///
  /// In en, this message translates to:
  /// **'Download {fileName} to local?'**
  String dl2Local(String fileName);

  /// User-facing label or message for docker empty running items.
  ///
  /// In en, this message translates to:
  /// **'There are no running containers.\nThis could be because:\n- The Docker installation user is not the same as the username configured within the App.\n- The environment variable DOCKER_HOST was not read correctly. You can get it by running `echo \$DOCKER_HOST` in the terminal.'**
  String get dockerEmptyRunningItems;

  /// User-facing label or message for docker project other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get dockerProjectOther;

  /// Help text for the docker prune setting or action.
  ///
  /// In en, this message translates to:
  /// **'Remove unused data to free up disk space'**
  String get dockerPruneTip;

  /// User-facing label or message for docker statistics.
  ///
  /// In en, this message translates to:
  /// **'Docker Statistics'**
  String get dockerStatistics;

  /// User-facing label or message for double column mode.
  ///
  /// In en, this message translates to:
  /// **'Double column mode'**
  String get doubleColumnMode;

  /// Help text for the double column setting or action.
  ///
  /// In en, this message translates to:
  /// **'This option only enables the feature, whether it can actually be enabled depends on the width of the device'**
  String get doubleColumnTip;

  /// Action label for edit virt keys.
  ///
  /// In en, this message translates to:
  /// **'Virtual keys'**
  String get editVirtKeys;

  /// Help text for the editor highlight setting or action.
  ///
  /// In en, this message translates to:
  /// **'The current code highlighting performance is not ideal and can be optionally turned off to improve.'**
  String get editorHighlightTip;

  /// Action label for enable mDNS.
  ///
  /// In en, this message translates to:
  /// **'Enable mDNS'**
  String get enableMdns;

  /// Description of the enable mDNS desc feature or option.
  ///
  /// In en, this message translates to:
  /// **'Use mDNS/Bonjour to discover SSH services'**
  String get enableMdnsDesc;

  /// User-facing label or message for env vars.
  ///
  /// In en, this message translates to:
  /// **'Environment variable'**
  String get envVars;

  /// User-facing label or message for extra args.
  ///
  /// In en, this message translates to:
  /// **'Extra arguments'**
  String get extraArgs;

  /// User-facing label or message for fallback SSH dest.
  ///
  /// In en, this message translates to:
  /// **'Fallback SSH destination'**
  String get fallbackSshDest;

  /// Help text for the F-Droid release setting or action.
  ///
  /// In en, this message translates to:
  /// **'If you downloaded this app from F-Droid, it is recommended to turn off this option.'**
  String get fdroidReleaseTip;

  /// User-facing label or message for file too large.
  ///
  /// In en, this message translates to:
  /// **'File \'{file}\' too large {size}, max {sizeMax}'**
  String fileTooLarge(String file, String size, String sizeMax);

  /// User-facing label or message for file dir gone.
  ///
  /// In en, this message translates to:
  /// **'This folder is no longer here'**
  String get fileDirGone;

  /// Help text for the file dir gone setting or action.
  ///
  /// In en, this message translates to:
  /// **'It was deleted or renamed'**
  String get fileDirGoneTip;

  /// User-facing label or message for full screen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get fullScreen;

  /// User-facing label or message for full screen jitter.
  ///
  /// In en, this message translates to:
  /// **'Full screen jitter'**
  String get fullScreenJitter;

  /// User-facing label or message for full screen jitter help.
  ///
  /// In en, this message translates to:
  /// **'To avoid screen burn-in'**
  String get fullScreenJitterHelp;

  /// Help text for the full screen setting or action.
  ///
  /// In en, this message translates to:
  /// **'Should full-screen mode be enabled when the device is rotated to landscape mode? This option only applies to the server tab.'**
  String get fullScreenTip;

  /// User-facing label or message for github gist id optional.
  ///
  /// In en, this message translates to:
  /// **'Gist ID (optional)'**
  String get githubGistIdOptional;

  /// User-facing label or message for github gist token.
  ///
  /// In en, this message translates to:
  /// **'GitHub Gist token'**
  String get githubGistToken;

  /// Empty-state message for github gist token empty.
  ///
  /// In en, this message translates to:
  /// **'Token is empty'**
  String get githubGistTokenEmpty;

  /// User-facing label or message for goto.
  ///
  /// In en, this message translates to:
  /// **'Go to'**
  String get goto;

  /// User-facing label or message for home tabs.
  ///
  /// In en, this message translates to:
  /// **'Home Tabs'**
  String get homeTabs;

  /// Description of the home tabs customize desc feature or option.
  ///
  /// In en, this message translates to:
  /// **'Customize which tabs appear on the home page and their order'**
  String get homeTabsCustomizeDesc;

  /// User-facing label or message for ignore cert.
  ///
  /// In en, this message translates to:
  /// **'Ignore certificate'**
  String get ignoreCert;

  /// A container image, as in Docker. NOT a picture — do not replace this with libL10n.image, whose German is "Bild" and Japanese "画像".
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// Explanatory message shown in the mac DMG dialog or notice.
  ///
  /// In en, this message translates to:
  /// **'The App Store requires this app to be sandboxed, and a sandbox cannot open a terminal. The DMG build can.\n\nThe App Store build may stop being updated.'**
  String get macDmgBody;

  /// User-facing label or message for mac DMG import denied.
  ///
  /// In en, this message translates to:
  /// **'macOS would not let this read the previous build’s data'**
  String get macDmgImportDenied;

  /// User-facing label or message for mac DMG imported.
  ///
  /// In en, this message translates to:
  /// **'Imported the previous build’s data'**
  String get macDmgImported;

  /// Error message shown when mac DMG import failed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the previous build’s data'**
  String get macDmgImportFailed;

  /// Help text for the mac DMG setting or action.
  ///
  /// In en, this message translates to:
  /// **'Local terminal and running snippets locally (DMG build)'**
  String get macDmgTip;

  /// Title shown for the mac DMG dialog or section.
  ///
  /// In en, this message translates to:
  /// **'DMG build'**
  String get macDmgTitle;

  /// User-facing label or message for show hidden files.
  ///
  /// In en, this message translates to:
  /// **'Show hidden files'**
  String get showHiddenFiles;

  /// User-facing label or message for SSH key algorithm.
  ///
  /// In en, this message translates to:
  /// **'Algorithm'**
  String get sshKeyAlgorithm;

  /// User-facing label or message for SSH key comment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get sshKeyComment;

  /// User-facing label or message for SSH key generate.
  ///
  /// In en, this message translates to:
  /// **'Generate key pair'**
  String get sshKeyGenerate;

  /// User-facing label or message for SSH key generating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get sshKeyGenerating;

  /// Formatted user-facing message for SSH key locked; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'The private key [{name}] was not unlocked.'**
  String sshKeyLockedFmt(String name);

  /// Help text for the SSH key passphrase setting or action.
  ///
  /// In en, this message translates to:
  /// **'Optional. A key with a passphrase is stored encrypted, and you are asked for it the first time a connection uses the key.'**
  String get sshKeyPassphraseTip;

  /// User-facing label or message for SSH key passphrase wrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong passphrase.'**
  String get sshKeyPassphraseWrong;

  /// User-facing label or message for SSH key public key.
  ///
  /// In en, this message translates to:
  /// **'Public key'**
  String get sshKeyPublicKey;

  /// Help text for the SSH key public key setting or action.
  ///
  /// In en, this message translates to:
  /// **'Append this line to ~/.ssh/authorized_keys on the server.'**
  String get sshKeyPublicKeyTip;

  /// User-facing label or message for SSH key recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get sshKeyRecommended;

  /// Help text for the SSH key unlock setting or action.
  ///
  /// In en, this message translates to:
  /// **'Enter the passphrase for the private key [{name}].'**
  String sshKeyUnlockTip(String name);

  /// User-facing label or message for ungrouped.
  ///
  /// In en, this message translates to:
  /// **'Ungrouped'**
  String get ungrouped;

  /// User-facing label or message for container reclaimable.
  ///
  /// In en, this message translates to:
  /// **'Reclaimable'**
  String get containerReclaimable;

  /// User-facing label or message for unused.
  ///
  /// In en, this message translates to:
  /// **'Unused'**
  String get unused;

  /// User-facing label or message for dangling.
  ///
  /// In en, this message translates to:
  /// **'Dangling'**
  String get dangling;

  /// User-facing label or message for prune unused images.
  ///
  /// In en, this message translates to:
  /// **'Prune unused images'**
  String get pruneUnusedImages;

  /// User-facing label or message for prune dangling images.
  ///
  /// In en, this message translates to:
  /// **'Prune dangling images'**
  String get pruneDanglingImages;

  /// User-facing label or message for prune images.
  ///
  /// In en, this message translates to:
  /// **'Prune images'**
  String get pruneImages;

  /// User-facing label or message for unused tagged images.
  ///
  /// In en, this message translates to:
  /// **'Unused tagged'**
  String get unusedTaggedImages;

  /// Help text for the prune dangling images setting or action.
  ///
  /// In en, this message translates to:
  /// **'Removes dangling images only.'**
  String get pruneDanglingImagesTip;

  /// Help text for the prune unused images setting or action.
  ///
  /// In en, this message translates to:
  /// **'Also remove tagged images not used by any container.'**
  String get pruneUnusedImagesTip;

  /// Help text for the include unused volumes setting or action.
  ///
  /// In en, this message translates to:
  /// **'Also remove volumes not used by any container.'**
  String get includeUnusedVolumesTip;

  /// User-facing label or message for prune command preview.
  ///
  /// In en, this message translates to:
  /// **'Command preview'**
  String get pruneCommandPreview;

  /// Help text for the prune force SSH setting or action.
  ///
  /// In en, this message translates to:
  /// **'-f skips the interactive prompt and is always enabled for SSH execution.'**
  String get pruneForceSshTip;

  /// User-facing label or message for prune volumes.
  ///
  /// In en, this message translates to:
  /// **'Prune volumes'**
  String get pruneVolumes;

  /// User-facing label or message for prune unused data.
  ///
  /// In en, this message translates to:
  /// **'Prune unused data'**
  String get pruneUnusedData;

  /// User-facing label or message for pull.
  ///
  /// In en, this message translates to:
  /// **'Pull'**
  String get pull;

  /// User-facing label or message for invalid host format.
  ///
  /// In en, this message translates to:
  /// **'Invalid host format. Only IPv4, IPv6, and domain characters are allowed.'**
  String get invalidHostFormat;

  /// User-facing label or message for jump server.
  ///
  /// In en, this message translates to:
  /// **'Jump server'**
  String get jumpServer;

  /// Formatted user-facing message for jump servers not found; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Jump servers not found for {serverName}: {jumpIds}'**
  String jumpServersNotFoundFmt(String serverName, String jumpIds);

  /// Formatted user-facing message for name already exists; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" already exists'**
  String nameAlreadyExistsFmt(String name);

  /// User-facing label or message for no jump server available.
  ///
  /// In en, this message translates to:
  /// **'No jump server available.'**
  String get noJumpServerAvailable;

  /// User-facing label or message for jump server and proxy command cannot be used together.
  ///
  /// In en, this message translates to:
  /// **'Jump server and ProxyCommand cannot be used together.'**
  String get jumpServerAndProxyCommandCannotBeUsedTogether;

  /// User-facing label or message for no connection method.
  ///
  /// In en, this message translates to:
  /// **'Configure SSH, a monitor agent, or both'**
  String get noConnectionMethod;

  /// User-facing label or message for preferred transport.
  ///
  /// In en, this message translates to:
  /// **'Try first'**
  String get preferredTransport;

  /// Help text for the preferred transport setting or action.
  ///
  /// In en, this message translates to:
  /// **'Where status is read from, and which connection a command opens first. The other stays available.'**
  String get preferredTransportTip;

  /// User-facing label or message for keep foreground.
  ///
  /// In en, this message translates to:
  /// **'Keep app foreground!'**
  String get keepForeground;

  /// User-facing label or message for keep status when err.
  ///
  /// In en, this message translates to:
  /// **'Preserve the last server state'**
  String get keepStatusWhenErr;

  /// Help text for the keep status when err setting or action.
  ///
  /// In en, this message translates to:
  /// **'Only in the event of an error during script execution'**
  String get keepStatusWhenErrTip;

  /// User-facing label or message for key auth.
  ///
  /// In en, this message translates to:
  /// **'Key Auth'**
  String get keyAuth;

  /// Error message shown when last failure.
  ///
  /// In en, this message translates to:
  /// **'Last Failure'**
  String get lastFailure;

  /// User-facing label or message for last success.
  ///
  /// In en, this message translates to:
  /// **'Last Success'**
  String get lastSuccess;

  /// User-facing label or message for letter cache.
  ///
  /// In en, this message translates to:
  /// **'Normal keyboard input'**
  String get letterCache;

  /// Help text for the letter cache setting or action.
  ///
  /// In en, this message translates to:
  /// **'When enabled, input goes through the regular IME, which can avoid secure keyboard prompts in the terminal on some systems.'**
  String get letterCacheTip;

  /// Help text for the linux shell setting or action.
  ///
  /// In en, this message translates to:
  /// **'Which shell a terminal starts. Empty restores /bin/sh.'**
  String get linuxShellTip;

  /// Help text for the linux net setting or action.
  ///
  /// In en, this message translates to:
  /// **'DNS servers. Empty restores the defaults'**
  String get linuxNetTip;

  /// User-facing label or message for made with love.
  ///
  /// In en, this message translates to:
  /// **'Made with ❤️ by {myGithub}'**
  String madeWithLove(String myGithub);

  /// User-facing label or message for max concurrency.
  ///
  /// In en, this message translates to:
  /// **'Max Concurrency'**
  String get maxConcurrency;

  /// User-facing label or message for max retry count.
  ///
  /// In en, this message translates to:
  /// **'Number of server reconnections'**
  String get maxRetryCount;

  /// User-facing label or message for mismatch system.
  ///
  /// In en, this message translates to:
  /// **'Mismatch system: {system}'**
  String mismatchSystem(String system);

  /// User-facing label or message for mirror.
  ///
  /// In en, this message translates to:
  /// **'Mirror'**
  String get mirror;

  /// User-facing label or message for need restart.
  ///
  /// In en, this message translates to:
  /// **'App needs to be restarted'**
  String get needRestart;

  /// User-facing label or message for net view type.
  ///
  /// In en, this message translates to:
  /// **'Network view type'**
  String get netViewType;

  /// User-facing label or message for new container.
  ///
  /// In en, this message translates to:
  /// **'New container'**
  String get newContainer;

  /// User-facing label or message for no connection stats data.
  ///
  /// In en, this message translates to:
  /// **'No connection statistics data'**
  String get noConnectionStatsData;

  /// User-facing label or message for no line chart.
  ///
  /// In en, this message translates to:
  /// **'Do not use line charts'**
  String get noLineChart;

  /// Help text for the no private key setting or action.
  ///
  /// In en, this message translates to:
  /// **'The private key does not exist, it may have been deleted or there is a configuration error.'**
  String get noPrivateKeyTip;

  /// User-facing label or message for no prompt again.
  ///
  /// In en, this message translates to:
  /// **'Do not prompt again'**
  String get noPromptAgain;

  /// Action label for open last path.
  ///
  /// In en, this message translates to:
  /// **'Open the last path'**
  String get openLastPath;

  /// Help text for the open last path setting or action.
  ///
  /// In en, this message translates to:
  /// **'Different servers will have different logs, and the log is the path to the exit'**
  String get openLastPathTip;

  /// Help text for the parse container stats setting or action.
  ///
  /// In en, this message translates to:
  /// **'Parsing the occupancy status of Docker is relatively slow.'**
  String get parseContainerStatsTip;

  /// User-facing label or message for prefer disk amount.
  ///
  /// In en, this message translates to:
  /// **'Prioritize displaying disk capacity'**
  String get preferDiskAmount;

  /// User-facing label or message for private key.
  ///
  /// In en, this message translates to:
  /// **'Private Key'**
  String get privateKey;

  /// Formatted user-facing message for private key not found; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Private key [{keyId}] not found.'**
  String privateKeyNotFoundFmt(String keyId);

  /// User-facing label or message for BMC power on action.
  ///
  /// In en, this message translates to:
  /// **'Power on'**
  String get bmcPowerOnAction;

  /// User-facing label or message for BMC shutdown.
  ///
  /// In en, this message translates to:
  /// **'Shut down'**
  String get bmcShutdown;

  /// User-facing label or message for BMC force off.
  ///
  /// In en, this message translates to:
  /// **'Force off'**
  String get bmcForceOff;

  /// Action label for restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// User-facing label or message for BMC power cycle.
  ///
  /// In en, this message translates to:
  /// **'Power cycle'**
  String get bmcPowerCycle;

  /// Confirmation prompt for BMC power confirm.
  ///
  /// In en, this message translates to:
  /// **'Send this to {server}? The service will be asked for \"{resetType}\"'**
  String bmcPowerConfirm(String server, String resetType);

  /// User-facing label or message for BMC power done.
  ///
  /// In en, this message translates to:
  /// **'The power state changed'**
  String get bmcPowerDone;

  /// User-facing label or message for BMC power accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted, but the power state has not changed. A graceful operation depends on the OS'**
  String get bmcPowerAccepted;

  /// User-facing label or message for BMC power unsupported.
  ///
  /// In en, this message translates to:
  /// **'This service allows nothing for that action'**
  String get bmcPowerUnsupported;

  /// User-facing label or message for BMC unauthorized.
  ///
  /// In en, this message translates to:
  /// **'The BMC refused the account'**
  String get bmcUnauthorized;

  /// User-facing label or message for BMC account missing.
  ///
  /// In en, this message translates to:
  /// **'No account is set for this BMC'**
  String get bmcAccountMissing;

  /// User-facing label or message for BMC power on.
  ///
  /// In en, this message translates to:
  /// **'Powered on'**
  String get bmcPowerOn;

  /// User-facing label or message for BMC power off.
  ///
  /// In en, this message translates to:
  /// **'Powered off'**
  String get bmcPowerOff;

  /// User-facing label or message for BMC cert rejected.
  ///
  /// In en, this message translates to:
  /// **'Certificate refused — review it in the server settings'**
  String get bmcCertRejected;

  /// User-facing label or message for BMC not a service.
  ///
  /// In en, this message translates to:
  /// **'No Redfish service at this address'**
  String get bmcNotAService;

  /// User-facing label or message for BMC no system.
  ///
  /// In en, this message translates to:
  /// **'The service reports no system'**
  String get bmcNoSystem;

  /// User-facing label or message for BMC sensors truncated.
  ///
  /// In en, this message translates to:
  /// **'Only the first sensors are shown'**
  String get bmcSensorsTruncated;

  /// User-facing label or message for BMC multiple systems.
  ///
  /// In en, this message translates to:
  /// **'Only the first system is shown'**
  String get bmcMultipleSystems;

  /// Help text for the BMC setting or action.
  ///
  /// In en, this message translates to:
  /// **'The BMC is a separate computer on the motherboard, reachable when the host OS is not. Configured here, it can report power state and hardware sensors while the server is off or hung. Needs Redfish, which most enterprise hardware from about 2016 on has.'**
  String get bmcTip;

  /// User-facing label or message for BMC cert.
  ///
  /// In en, this message translates to:
  /// **'Certificate'**
  String get bmcCert;

  /// User-facing label or message for BMC cert pinned.
  ///
  /// In en, this message translates to:
  /// **'Reviewed and pinned'**
  String get bmcCertPinned;

  /// User-facing label or message for BMC cert unreviewed.
  ///
  /// In en, this message translates to:
  /// **'Not reviewed yet — tap to see the certificate'**
  String get bmcCertUnreviewed;

  /// User-facing label or message for BMC cert review.
  ///
  /// In en, this message translates to:
  /// **'A self-signed certificate. Compare it before accepting. Only this exact one is trusted afterwards.'**
  String get bmcCertReview;

  /// User-facing label or message for BMC cert changed.
  ///
  /// In en, this message translates to:
  /// **'The certificate does not match. Check it.'**
  String get bmcCertChanged;

  /// User-facing label or message for BMC cert expired.
  ///
  /// In en, this message translates to:
  /// **'Expired.'**
  String get bmcCertExpired;

  /// User-facing label or message for BMC cert was.
  ///
  /// In en, this message translates to:
  /// **'Previously accepted: {fingerprint}'**
  String bmcCertWas(String fingerprint);

  /// User-facing label or message for BMC addr invalid.
  ///
  /// In en, this message translates to:
  /// **'The BMC address must be a URL, e.g. https://10.0.0.9'**
  String get bmcAddrInvalid;

  /// User-facing label or message for proxy command sandboxed.
  ///
  /// In en, this message translates to:
  /// **'This build is sandboxed: the command gets an empty home, not yours, so anything reading ~/.ssh fails. The DMG build is not.'**
  String get proxyCommandSandboxed;

  /// User-facing label or message for private key file unreadable.
  ///
  /// In en, this message translates to:
  /// **'Cannot read the private key file {path}: {reason}'**
  String privateKeyFileUnreadable(String path, String reason);

  /// User-facing label or message for private key file sandboxed.
  ///
  /// In en, this message translates to:
  /// **'This build cannot read files outside its own container, so the key at {path} is unreachable. Import the key in Settings, or use the DMG build.'**
  String privateKeyFileSandboxed(String path);

  /// User-facing label or message for push token.
  ///
  /// In en, this message translates to:
  /// **'Push token'**
  String get pushToken;

  /// User-facing label or message for live activity.
  ///
  /// In en, this message translates to:
  /// **'Live Activity'**
  String get liveActivity;

  /// Help text for the live activity setting or action.
  ///
  /// In en, this message translates to:
  /// **'Show terminal sessions on the Lock Screen and Dynamic Island. Without unlocking, the server name and connection state are visible there.'**
  String get liveActivityTip;

  /// User-facing label or message for live activity system disabled.
  ///
  /// In en, this message translates to:
  /// **'iOS is not allowing one. The switches are at Settings › ServerBox › Live Activities and Settings › Face ID & Passcode › Live Activities.'**
  String get liveActivitySystemDisabled;

  /// User-facing label or message for proxy command only supported on desktop.
  ///
  /// In en, this message translates to:
  /// **'ProxyCommand is only supported on desktop platforms.'**
  String get proxyCommandOnlySupportedOnDesktop;

  /// Help text for the pve ignore cert setting or action.
  ///
  /// In en, this message translates to:
  /// **'Not recommended to enable, beware of security risks! If you are using the default certificate from PVE, you need to enable this option.'**
  String get pveIgnoreCertTip;

  /// User-facing label or message for pve password required.
  ///
  /// In en, this message translates to:
  /// **'PVE password is required. Please set it in server settings.'**
  String get pvePasswordRequired;

  /// User-facing label or message for pve otp required.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication is enabled on this PVE server. Please enter the OTP code.'**
  String get pveOtpRequired;

  /// User-facing label or message for pve otp code required.
  ///
  /// In en, this message translates to:
  /// **'OTP code is required.'**
  String get pveOtpCodeRequired;

  /// Error message shown when pve otp verification failed.
  ///
  /// In en, this message translates to:
  /// **'OTP verification failed. Please try again with a fresh code.'**
  String get pveOtpVerificationFailed;

  /// Title shown for the pve otp dialog or section.
  ///
  /// In en, this message translates to:
  /// **'OTP Verification'**
  String get pveOtpTitle;

  /// User-facing label or message for pve otp label.
  ///
  /// In en, this message translates to:
  /// **'OTP Code'**
  String get pveOtpLabel;

  /// Explanatory message shown in the pve invalid response dialog or notice.
  ///
  /// In en, this message translates to:
  /// **'PVE login returned an invalid response body.'**
  String get pveInvalidResponseBody;

  /// User-facing label or message for pve invalid response data.
  ///
  /// In en, this message translates to:
  /// **'PVE login response did not contain a valid data payload.'**
  String get pveInvalidResponseData;

  /// User-facing label or message for pve missing auth ticket.
  ///
  /// In en, this message translates to:
  /// **'PVE login succeeded but no authentication ticket was returned.'**
  String get pveMissingAuthTicket;

  /// User-facing label or message for pve loading connect.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get pveLoadingConnect;

  /// User-facing label or message for pve password.
  ///
  /// In en, this message translates to:
  /// **'PVE Password'**
  String get pvePassword;

  /// Hint shown in the pve password field or section.
  ///
  /// In en, this message translates to:
  /// **'Required when using key-based SSH authentication'**
  String get pvePasswordHint;

  /// User-facing label or message for read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// User-facing label or message for recent connections.
  ///
  /// In en, this message translates to:
  /// **'Recent Connections'**
  String get recentConnections;

  /// User-facing label or message for remember pwd in mem.
  ///
  /// In en, this message translates to:
  /// **'Remember password in memory'**
  String get rememberPwdInMem;

  /// Help text for the remember pwd in mem setting or action.
  ///
  /// In en, this message translates to:
  /// **'Used for containers, suspending, etc.'**
  String get rememberPwdInMemTip;

  /// User-facing label or message for remote path.
  ///
  /// In en, this message translates to:
  /// **'Remote path'**
  String get remotePath;

  /// Help text for the rootfs update setting or action.
  ///
  /// In en, this message translates to:
  /// **'{distro} {installed} is installed; {latest} is available. Updating replaces the whole container: {pm} data is lost'**
  String rootfsUpdateTip(
    String distro,
    String installed,
    String latest,
    String pm,
  );

  /// User-facing label or message for linux system in use.
  ///
  /// In en, this message translates to:
  /// **'Close the terminals on {name} before deleting it'**
  String linuxSystemInUse(String name);

  /// User-facing label or message for rootfs subtitle.
  ///
  /// In en, this message translates to:
  /// **'A Linux userland on this device'**
  String get rootfsSubtitle;

  /// Help text for the rootfs install setting or action.
  ///
  /// In en, this message translates to:
  /// **'Downloads {distro} {version} (about {size} MB) and unpacks it on this device.'**
  String rootfsInstallTip(String distro, String version, int size);

  /// User-facing label or message for same id server exist.
  ///
  /// In en, this message translates to:
  /// **'A server with the same ID already exists'**
  String get sameIdServerExist;

  /// User-facing label or message for second.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get second;

  /// Help text for the server files unavailable setting or action.
  ///
  /// In en, this message translates to:
  /// **'Needs SSH to this server, or server_box_monitor installed with its file API on.'**
  String get serverFilesUnavailableTip;

  /// User-facing label or message for back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// User-facing label or message for history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// User-facing label or message for home dir.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeDir;

  /// User-facing label or message for selected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selected(int count);

  /// Action label for send to.
  ///
  /// In en, this message translates to:
  /// **'Send to…'**
  String get sendTo;

  /// User-facing label or message for server func btns.
  ///
  /// In en, this message translates to:
  /// **'Server function buttons'**
  String get serverFuncBtns;

  /// User-facing label or message for server order.
  ///
  /// In en, this message translates to:
  /// **'Server order'**
  String get serverOrder;

  /// Empty-state message for server tab empty.
  ///
  /// In en, this message translates to:
  /// **'No servers yet'**
  String get serverTabEmpty;

  /// User-facing label or message for server tab required.
  ///
  /// In en, this message translates to:
  /// **'Server tab cannot be removed'**
  String get serverTabRequired;

  /// Hint shown in the share code field or section.
  ///
  /// In en, this message translates to:
  /// **'Tell the recipient these digits separately. They are not included in the QR code.'**
  String get shareCodeHint;

  /// User-facing label or message for share code prompt.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get shareCodePrompt;

  /// Title shown for the share code dialog or section.
  ///
  /// In en, this message translates to:
  /// **'One-time code'**
  String get shareCodeTitle;

  /// User-facing label or message for share expired.
  ///
  /// In en, this message translates to:
  /// **'This share has expired. Ask for a new one.'**
  String get shareExpired;

  /// User-facing label or message for share import file.
  ///
  /// In en, this message translates to:
  /// **'From a shared file'**
  String get shareImportFile;

  /// Title shown for the share import dialog or section.
  ///
  /// In en, this message translates to:
  /// **'Import shared server'**
  String get shareImportTitle;

  /// User-facing label or message for share includes key.
  ///
  /// In en, this message translates to:
  /// **'The share includes the private key.'**
  String get shareIncludesKey;

  /// User-facing label or message for share omitted BMC.
  ///
  /// In en, this message translates to:
  /// **'BMC credentials. The address is included, but the credentials are not.'**
  String get shareOmittedBmc;

  /// User-facing label or message for share omitted jump.
  ///
  /// In en, this message translates to:
  /// **'The jump server, because it is stored as a separate server on this device.'**
  String get shareOmittedJump;

  /// User-facing label or message for share omitted key path.
  ///
  /// In en, this message translates to:
  /// **'The key file, because its path is only valid on this device.'**
  String get shareOmittedKeyPath;

  /// User-facing label or message for share omitted missing key.
  ///
  /// In en, this message translates to:
  /// **'The private key, because it is not in this device’s key store.'**
  String get shareOmittedMissingKey;

  /// Help text for the share omitted setting or action.
  ///
  /// In en, this message translates to:
  /// **'Not included; the recipient must configure:'**
  String get shareOmittedTip;

  /// Help text for the share passphrase setting or action.
  ///
  /// In en, this message translates to:
  /// **'This passphrase encrypts the file. The recipient needs it to import the server, and it cannot be recovered.'**
  String get sharePassphraseTip;

  /// Help text for the share qr setting or action.
  ///
  /// In en, this message translates to:
  /// **'The connection details in this QR code are encrypted. The share expires in {minutes} minutes.'**
  String shareQrTip(int minutes);

  /// User-facing label or message for share scan qr.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code'**
  String get shareScanQr;

  /// User-facing label or message for share server exists.
  ///
  /// In en, this message translates to:
  /// **'“{name}” on this device already uses this address. Import anyway?'**
  String shareServerExists(String name);

  /// User-facing label or message for share too big for qr.
  ///
  /// In en, this message translates to:
  /// **'Too large for a QR code. Share it as a file instead.'**
  String get shareTooBigForQr;

  /// User-facing label or message for share too new.
  ///
  /// In en, this message translates to:
  /// **'This share was created with a newer version of ServerBox. Update the app to open it.'**
  String get shareTooNew;

  /// User-facing label or message for share unreadable.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid ServerBox share.'**
  String get shareUnreadable;

  /// User-facing label or message for share via.
  ///
  /// In en, this message translates to:
  /// **'Share via'**
  String get shareVia;

  /// User-facing label or message for sftp dl prepare.
  ///
  /// In en, this message translates to:
  /// **'Preparing to connect...'**
  String get sftpDlPrepare;

  /// Help text for the sftp editor setting or action.
  ///
  /// In en, this message translates to:
  /// **'Empty uses the built-in editor. For example `vim` (reading `EDITOR` is suggested).'**
  String get sftpEditorTip;

  /// User-facing label or message for sftp rmr dir summary.
  ///
  /// In en, this message translates to:
  /// **'Use `rm -r` to delete a folder in SFTP.'**
  String get sftpRmrDirSummary;

  /// User-facing label or message for sftp SSH connected.
  ///
  /// In en, this message translates to:
  /// **'SFTP Connected'**
  String get sftpSSHConnected;

  /// User-facing label or message for sftp show folders first.
  ///
  /// In en, this message translates to:
  /// **'Display folders first'**
  String get sftpShowFoldersFirst;

  /// User-facing label or message for sftp unavailable use scp.
  ///
  /// In en, this message translates to:
  /// **'If this host has no SFTP subsystem, as many embedded devices do not, set its file transfer to SCP in the server settings.'**
  String get sftpUnavailableUseScp;

  /// Help text for the SSH file transport setting or action.
  ///
  /// In en, this message translates to:
  /// **'SFTP suits anything current. Choose SCP for an old or embedded host whose SSH server has no SFTP subsystem: it needs the `scp` command and a shell that also has the usual file utilities (`find`, `stat`, `mv`, `chmod`).'**
  String get sshFileTransportTip;

  /// User-facing label or message for specify dev.
  ///
  /// In en, this message translates to:
  /// **'Specify device'**
  String get specifyDev;

  /// Help text for the specify dev setting or action.
  ///
  /// In en, this message translates to:
  /// **'Network traffic counts every device by default; name one here instead'**
  String get specifyDevTip;

  /// Help text for the temp is celsius setting or action.
  ///
  /// In en, this message translates to:
  /// **'When enabled, the temperature value will be treated as Celsius instead of millicelsius. Turn on only if the temperature displays incorrectly (e.g., showing 0.1°C instead of 58°C).'**
  String get tempIsCelsiusTip;

  /// User-facing label or message for spent time.
  ///
  /// In en, this message translates to:
  /// **'Spent time: {time}'**
  String spentTime(String time);

  /// User-facing label or message for SSH config all exist.
  ///
  /// In en, this message translates to:
  /// **'All servers already exist ({duplicateCount} duplicates found)'**
  String sshConfigAllExist(int duplicateCount);

  /// Help text for the SSH connection mode setting or action.
  ///
  /// In en, this message translates to:
  /// **'Built-in: use the app\'s terminal. System SSH: launch the system ssh command in an external terminal.'**
  String get sshConnectionModeTip;

  /// User-facing label or message for SSH connection mode use builtin.
  ///
  /// In en, this message translates to:
  /// **'Use built-in terminal'**
  String get sshConnectionModeUseBuiltin;

  /// User-facing label or message for SSH connection mode use system.
  ///
  /// In en, this message translates to:
  /// **'Use system SSH'**
  String get sshConnectionModeUseSystem;

  /// User-facing label or message for SSH config duplicates skipped.
  ///
  /// In en, this message translates to:
  /// **'{duplicateCount} duplicates will be skipped'**
  String sshConfigDuplicatesSkipped(int duplicateCount);

  /// User-facing label or message for SSH config found.
  ///
  /// In en, this message translates to:
  /// **'We found SSH configuration on your system.'**
  String get sshConfigFound;

  /// User-facing label or message for SSH config found servers.
  ///
  /// In en, this message translates to:
  /// **'Found {totalCount} servers'**
  String sshConfigFoundServers(int totalCount);

  /// User-facing label or message for SSH config import.
  ///
  /// In en, this message translates to:
  /// **'SSH Config Import'**
  String get sshConfigImport;

  /// User-facing label or message for SSH config import permission.
  ///
  /// In en, this message translates to:
  /// **'Would you like to give permission to read ~/.ssh/config and automatically import server settings?'**
  String get sshConfigImportPermission;

  /// Help text for the SSH config import setting or action.
  ///
  /// In en, this message translates to:
  /// **'Prompt to read ~/.ssh/config on first server creation'**
  String get sshConfigImportTip;

  /// User-facing label or message for SSH config imported.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} servers from SSH config'**
  String sshConfigImported(int count);

  /// Description of the SSH host key changed desc feature or option.
  ///
  /// In en, this message translates to:
  /// **'The SSH host key changed for {serverName}. Only continue if you trust this server.'**
  String sshHostKeyChangedDesc(String serverName);

  /// Label for the SSH host key type displayed in the host key verification dialog.
  ///
  /// In en, this message translates to:
  /// **'SSH host key type'**
  String get sshHostKeyType;

  /// User-facing label or message for SSH known host keys.
  ///
  /// In en, this message translates to:
  /// **'Known hosts'**
  String get sshKnownHostKeys;

  /// Help text for the SSH known host keys setting or action.
  ///
  /// In en, this message translates to:
  /// **'The host keys this app has accepted'**
  String get sshKnownHostKeysTip;

  /// Description of the SSH host key new desc feature or option.
  ///
  /// In en, this message translates to:
  /// **'A new SSH host key was received from {serverName}. Review the fingerprint before trusting.'**
  String sshHostKeyNewDesc(String serverName);

  /// User-facing label or message for SSH host key stored fingerprint.
  ///
  /// In en, this message translates to:
  /// **'Stored fingerprint: {fingerprint}'**
  String sshHostKeyStoredFingerprint(String fingerprint);

  /// Label for a one-time verification code requested during SSH keyboard-interactive authentication.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get sshVerificationCode;

  /// User-facing label or message for SSH config manual select.
  ///
  /// In en, this message translates to:
  /// **'Would you like to select the SSH config file manually?'**
  String get sshConfigManualSelect;

  /// User-facing label or message for SSH config no servers.
  ///
  /// In en, this message translates to:
  /// **'No servers found in SSH config'**
  String get sshConfigNoServers;

  /// User-facing label or message for SSH config permission denied.
  ///
  /// In en, this message translates to:
  /// **'Cannot access SSH config file due to macOS permissions.'**
  String get sshConfigPermissionDenied;

  /// User-facing label or message for SSH config servers to import.
  ///
  /// In en, this message translates to:
  /// **'{importCount} servers will be imported'**
  String sshConfigServersToImport(int importCount);

  /// User-facing label or message for SSH term help.
  ///
  /// In en, this message translates to:
  /// **'When the terminal is scrollable, dragging horizontally can select text. Clicking the keyboard button turns the keyboard on/off. The file icon opens the current path SFTP. The clipboard button copies the content when text is selected, and pastes content from the clipboard into the terminal when no text is selected and there is content on the clipboard. The code icon pastes code snippets into the terminal and executes them.'**
  String get sshTermHelp;

  /// User-facing label or message for SSH virtual key auto off.
  ///
  /// In en, this message translates to:
  /// **'Auto switching of virtual keys'**
  String get sshVirtualKeyAutoOff;

  /// User-facing label or message for support fmt args.
  ///
  /// In en, this message translates to:
  /// **'The following formatting parameters are supported:'**
  String get supportFmtArgs;

  /// Help text for the suspend setting or action.
  ///
  /// In en, this message translates to:
  /// **'The suspend function requires root permission and systemd support.'**
  String get suspendTip;

  /// User-facing label or message for switch to.
  ///
  /// In en, this message translates to:
  /// **'Switch to {val}'**
  String switchTo(String val);

  /// User-facing label or message for sync app settings.
  ///
  /// In en, this message translates to:
  /// **'Sync app settings'**
  String get syncAppSettings;

  /// Help text for the sync app settings setting or action.
  ///
  /// In en, this message translates to:
  /// **'Include theme, layout, editor, terminal and other device preferences in automatic sync.'**
  String get syncAppSettingsTip;

  /// Help text for the term font size setting or action.
  ///
  /// In en, this message translates to:
  /// **'This setting will affect the terminal size (width and height). You can zoom in on the terminal page to adjust the font size of the current session.'**
  String get termFontSizeTip;

  /// Help text for the text scaler setting or action.
  ///
  /// In en, this message translates to:
  /// **'1.0 => 100% (original size), only works on server page part of the font, not recommended to change.'**
  String get textScalerTip;

  /// User-facing label or message for times.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get times;

  /// User-facing label or message for try sudo.
  ///
  /// In en, this message translates to:
  /// **'Try using sudo'**
  String get trySudo;

  /// User-facing label or message for sudo prompt not found.
  ///
  /// In en, this message translates to:
  /// **'No sudo password prompt is active.'**
  String get sudoPromptNotFound;

  /// Action label for update server status interval.
  ///
  /// In en, this message translates to:
  /// **'Server status update interval'**
  String get updateServerStatusInterval;

  /// User-facing label or message for use no pwd.
  ///
  /// In en, this message translates to:
  /// **'No password will be used'**
  String get useNoPwd;

  /// User-facing label or message for use podman by default.
  ///
  /// In en, this message translates to:
  /// **'Use Podman by default'**
  String get usePodmanByDefault;

  /// User-facing label or message for used.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get used;

  /// User-facing label or message for view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// User-facing label or message for view details.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// User-facing label or message for virt key help clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to the clipboard if the selected terminal is not empty, otherwise paste the content of the clipboard to the terminal.'**
  String get virtKeyHelpClipboard;

  /// User-facing label or message for virt key help ime.
  ///
  /// In en, this message translates to:
  /// **'Turn on/off the keyboard'**
  String get virtKeyHelpIME;

  /// User-facing label or message for virt key help sftp.
  ///
  /// In en, this message translates to:
  /// **'Open current directory in SFTP.'**
  String get virtKeyHelpSFTP;

  /// User-facing label or message for virt key help snippet.
  ///
  /// In en, this message translates to:
  /// **'Pick a snippet and run it in this terminal.'**
  String get virtKeyHelpSnippet;

  /// User-facing label or message for virt key help tmux.
  ///
  /// In en, this message translates to:
  /// **'Switch between tmux sessions and windows.'**
  String get virtKeyHelpTmux;

  /// User-facing label or message for virt key intro actions.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get virtKeyIntroActions;

  /// Help text for the virt key intro actions setting or action.
  ///
  /// In en, this message translates to:
  /// **'These open something instead of typing. Hold one to read what it does.'**
  String get virtKeyIntroActionsTip;

  /// Help text for the virt key intro customize setting or action.
  ///
  /// In en, this message translates to:
  /// **'Reorder these keys, or hide the ones you never reach for, in the terminal settings.'**
  String get virtKeyIntroCustomizeTip;

  /// User-facing label or message for virt key intro modifiers.
  ///
  /// In en, this message translates to:
  /// **'Modifiers'**
  String get virtKeyIntroModifiers;

  /// Help text for the virt key intro modifiers setting or action.
  ///
  /// In en, this message translates to:
  /// **'Tap one to arm it, then tap a letter on the keyboard. It stays on for that one key.'**
  String get virtKeyIntroModifiersTip;

  /// User-facing label or message for virt key intro nav.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get virtKeyIntroNav;

  /// Help text for the virt key intro nav setting or action.
  ///
  /// In en, this message translates to:
  /// **'These move the cursor. Hold an arrow to repeat it.'**
  String get virtKeyIntroNavTip;

  /// User-facing label or message for virt key intro select.
  ///
  /// In en, this message translates to:
  /// **'Drag sideways over the terminal to select text, whenever it has something to scroll.'**
  String get virtKeyIntroSelect;

  /// User-facing label or message for virt key rows.
  ///
  /// In en, this message translates to:
  /// **'Rows shown at once'**
  String get virtKeyRows;

  /// Help text for the virt key rows setting or action.
  ///
  /// In en, this message translates to:
  /// **'The rest go on a page of their own, swiped sideways.'**
  String get virtKeyRowsTip;

  /// User-facing label or message for wait connection.
  ///
  /// In en, this message translates to:
  /// **'Please wait for the connection to be established.'**
  String get waitConnection;

  /// User-facing label or message for wake lock.
  ///
  /// In en, this message translates to:
  /// **'Keep awake'**
  String get wakeLock;

  /// User-facing label or message for watch not paired.
  ///
  /// In en, this message translates to:
  /// **'No paired Apple Watch'**
  String get watchNotPaired;

  /// Empty-state message for webdav setting empty.
  ///
  /// In en, this message translates to:
  /// **'WebDav setting is empty'**
  String get webdavSettingEmpty;

  /// User-facing label or message for when open app.
  ///
  /// In en, this message translates to:
  /// **'When opening the app'**
  String get whenOpenApp;

  /// Help text for the wol setting or action.
  ///
  /// In en, this message translates to:
  /// **'After configuring WOL (Wake-on-LAN), a WOL request is sent each time the server is connected.'**
  String get wolTip;

  /// User-facing label or message for write.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get write;

  /// Help text for the write script fail setting or action.
  ///
  /// In en, this message translates to:
  /// **'Writing to the script failed, possibly due to lack of permissions or the directory does not exist.'**
  String get writeScriptFailTip;

  /// Help text for the write script setting or action.
  ///
  /// In en, this message translates to:
  /// **'After connecting to the server, a script will be written to `~/.config/server_box` \n | `/tmp/server_box` to monitor the system status. You can review the script content.'**
  String get writeScriptTip;

  /// User-facing label or message for menu git hub repository.
  ///
  /// In en, this message translates to:
  /// **'GitHub Repository'**
  String get menuGitHubRepository;

  /// User-facing label or message for podman docker emulation detected.
  ///
  /// In en, this message translates to:
  /// **'Podman Docker emulation detected. Please switch to Podman in settings.'**
  String get podmanDockerEmulationDetected;

  /// Help text for the beta setting or action.
  ///
  /// In en, this message translates to:
  /// **'This feature is still in beta testing. Functionality is not guaranteed.'**
  String get betaTip;

  /// User-facing label or message for port forward start prompt.
  ///
  /// In en, this message translates to:
  /// **'Add a port forward rule to get started'**
  String get portForward_startPrompt;

  /// User-facing label or message for port forward local host.
  ///
  /// In en, this message translates to:
  /// **'Local Host'**
  String get portForward_localHost;

  /// User-facing label or message for port forward local port.
  ///
  /// In en, this message translates to:
  /// **'Local Port'**
  String get portForward_localPort;

  /// User-facing label or message for port forward remote host.
  ///
  /// In en, this message translates to:
  /// **'Remote Host'**
  String get portForward_remoteHost;

  /// User-facing label or message for port forward remote port.
  ///
  /// In en, this message translates to:
  /// **'Remote Port'**
  String get portForward_remotePort;

  /// Formatted user-facing message for port forward delete confirm; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String portForward_deleteConfirmFmt(String name);

  /// User-facing label or message for sponsor.
  ///
  /// In en, this message translates to:
  /// **'Sponsor'**
  String get sponsor;

  /// User-facing label or message for sort by join time.
  ///
  /// In en, this message translates to:
  /// **'By join time'**
  String get sortByJoinTime;

  /// Title shown for the port forward beta dialog or section.
  ///
  /// In en, this message translates to:
  /// **'Port Forward (Beta)'**
  String get portForwardBetaTitle;

  /// User-facing label or message for tmux auto attach.
  ///
  /// In en, this message translates to:
  /// **'tmux auto-attach'**
  String get tmuxAutoAttach;

  /// User-facing label or message for tmux auto.
  ///
  /// In en, this message translates to:
  /// **'Auto tmux'**
  String get tmuxAuto;

  /// Help text for the tmux auto setting or action.
  ///
  /// In en, this message translates to:
  /// **'Automatically start or attach tmux when connecting over SSH'**
  String get tmuxAutoTip;

  /// User-facing label or message for tmux session selector.
  ///
  /// In en, this message translates to:
  /// **'Session selector'**
  String get tmuxSessionSelector;

  /// Help text for the tmux session selector setting or action.
  ///
  /// In en, this message translates to:
  /// **'Show the session picker when connecting'**
  String get tmuxSessionSelectorTip;

  /// User-facing label or message for tmux default session name.
  ///
  /// In en, this message translates to:
  /// **'Default session name'**
  String get tmuxDefaultSessionName;

  /// User-facing label or message for tmux session name.
  ///
  /// In en, this message translates to:
  /// **'Session name'**
  String get tmuxSessionName;

  /// User-facing label or message for tmux existing sessions.
  ///
  /// In en, this message translates to:
  /// **'Existing sessions'**
  String get tmuxExistingSessions;

  /// User-facing label or message for tmux new session.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get tmuxNewSession;

  /// User-facing label or message for tmux windows.
  ///
  /// In en, this message translates to:
  /// **'Windows'**
  String get tmuxWindows;

  /// User-facing label or message for tmux new window.
  ///
  /// In en, this message translates to:
  /// **'New window'**
  String get tmuxNewWindow;

  /// User-facing label or message for tmux no windows found.
  ///
  /// In en, this message translates to:
  /// **'No windows found'**
  String get tmuxNoWindowsFound;

  /// User-facing label or message for tmux window count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 window} other{{count} windows}}'**
  String tmuxWindowCount(int count);

  /// User-facing label or message for tmux pane count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 pane} other{{count} panes}}'**
  String tmuxPaneCount(int count);

  /// User-facing label or message for tmux attached.
  ///
  /// In en, this message translates to:
  /// **'Attached'**
  String get tmuxAttached;

  /// User-facing label or message for tmux active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get tmuxActive;

  /// User-facing label or message for tmux active at.
  ///
  /// In en, this message translates to:
  /// **'active: {time}'**
  String tmuxActiveAt(String time);

  /// User-facing label or message for tmux attached at.
  ///
  /// In en, this message translates to:
  /// **'attached: {time}'**
  String tmuxAttachedAt(String time);

  /// User-facing label or message for tmux skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tmuxSkip;

  /// User-facing label or message for tmux not available.
  ///
  /// In en, this message translates to:
  /// **'tmux is not available'**
  String get tmuxNotAvailable;

  /// User-facing label or message for container segments mismatch.
  ///
  /// In en, this message translates to:
  /// **'Unexpected container response segment count: {count}'**
  String containerSegmentsMismatch(int count);

  /// User-facing label or message for container operation in progress.
  ///
  /// In en, this message translates to:
  /// **'Another container operation is already in progress'**
  String get containerOperationInProgress;

  /// User-facing label or message for process count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 process} other{{count} processes}}'**
  String processCount(int count);

  /// User-facing label or message for process parse unsupported output.
  ///
  /// In en, this message translates to:
  /// **'The process list format is not supported.'**
  String get processParseUnsupportedOutput;

  /// User-facing label or message for process parse invalid rows.
  ///
  /// In en, this message translates to:
  /// **'Some process entries could not be read.'**
  String get processParseInvalidRows;

  /// User-facing label or message for process parse invalid windows json.
  ///
  /// In en, this message translates to:
  /// **'The Windows process response could not be read.'**
  String get processParseInvalidWindowsJson;

  /// User-facing label or message for process parse invalid windows rows.
  ///
  /// In en, this message translates to:
  /// **'Some Windows process entries could not be read.'**
  String get processParseInvalidWindowsRows;

  /// User-facing label or message for process kill target changed.
  ///
  /// In en, this message translates to:
  /// **'The process changed or exited. Refresh and try again.'**
  String get processKillTargetChanged;

  /// Hint shown in the process search field or section.
  ///
  /// In en, this message translates to:
  /// **'Name, user or PID'**
  String get processSearchHint;

  /// User-facing label or message for process show kernel threads.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Show 1 kernel thread} other{Show {count} kernel threads}}'**
  String processShowKernelThreads(int count);

  /// User-facing label or message for process force kill.
  ///
  /// In en, this message translates to:
  /// **'Force kill'**
  String get processForceKill;

  /// User-facing label or message for process started.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get processStarted;

  /// User-facing label or message for process threads.
  ///
  /// In en, this message translates to:
  /// **'Threads'**
  String get processThreads;

  /// User-facing label or message for watch servers.
  ///
  /// In en, this message translates to:
  /// **'Servers on the watch'**
  String get watchServers;

  /// Help text for the watch servers setting or action.
  ///
  /// In en, this message translates to:
  /// **'The watch fetches from the monitor on its own, so only servers with one can be picked.'**
  String get watchServersTip;

  /// User-facing label or message for watch no monitor server.
  ///
  /// In en, this message translates to:
  /// **'No server has a monitor agent configured'**
  String get watchNoMonitorServer;

  /// Title shown for the legacy status gone dialog or section.
  ///
  /// In en, this message translates to:
  /// **'Status URLs no longer work'**
  String get legacyStatusGoneTitle;

  /// Explanatory message shown in the legacy status gone dialog or notice.
  ///
  /// In en, this message translates to:
  /// **'The watch app and home widgets used to read a `/status` address typed by hand. That endpoint is gone: it could only report current values as text, which is why they could never show a chart.\n\nThey now read the monitor agent\'s authenticated API, so they draw trends and stay in step with the app on their own. Configure the server in the app once, and every watch and widget picks it up.'**
  String get legacyStatusGoneBody;

  /// User-facing label or message for services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// User-facing label or message for status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// Action label for enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// User-facing label or message for disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// Action label for starting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get starting;

  /// Action label for stopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get stopping;

  /// User-facing label or message for service manager unsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported service manager'**
  String get serviceManagerUnsupported;

  /// Help text for the service manager unsupported setting or action.
  ///
  /// In en, this message translates to:
  /// **'This server uses a service manager that ServerBox does not support yet. Supported managers: systemd, procd, and OpenRC.'**
  String get serviceManagerUnsupportedTip;

  /// Formatted user-facing message for service manager; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Managed by {manager}'**
  String serviceManagerFmt(String manager);

  /// Error message shown when service list failed.
  ///
  /// In en, this message translates to:
  /// **'Could not list services'**
  String get serviceListFailed;

  /// User-facing label or message for service details unavailable.
  ///
  /// In en, this message translates to:
  /// **'Some service details are unavailable'**
  String get serviceDetailsUnavailable;

  /// Help text for the service details unavailable setting or action.
  ///
  /// In en, this message translates to:
  /// **'The service list is usable, but the manager did not return all status or startup information.'**
  String get serviceDetailsUnavailableTip;

  /// User-facing label or message for systemd user scope missing.
  ///
  /// In en, this message translates to:
  /// **'User units are not listed'**
  String get systemdUserScopeMissing;

  /// Help text for the systemd user scope missing setting or action.
  ///
  /// In en, this message translates to:
  /// **'This account has no user session bus on the server, so only system units are shown.'**
  String get systemdUserScopeMissingTip;

  /// Hint shown in the service search field or section.
  ///
  /// In en, this message translates to:
  /// **'Unit name'**
  String get serviceSearchHint;

  /// User-facing label or message for service needs attention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get serviceNeedsAttention;

  /// User-facing label or message for service other units.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 other unit} other{{count} other units}}'**
  String serviceOtherUnits(int count);

  /// User-facing label or message for service unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get serviceUnit;

  /// User-facing label or message for service unit type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get serviceUnitType;

  /// User-facing label or message for service scope.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get serviceScope;

  /// User-facing label or message for service startup.
  ///
  /// In en, this message translates to:
  /// **'Startup'**
  String get serviceStartup;

  /// User-facing label or message for service up for.
  ///
  /// In en, this message translates to:
  /// **'up {duration}'**
  String serviceUpFor(String duration);

  /// User-facing label or message for service down for.
  ///
  /// In en, this message translates to:
  /// **'down {duration}'**
  String serviceDownFor(String duration);

  /// User-facing label or message for service next in.
  ///
  /// In en, this message translates to:
  /// **'next {duration}'**
  String serviceNextIn(String duration);

  /// User-facing label or message for service stopped ago.
  ///
  /// In en, this message translates to:
  /// **'Stopped {duration} ago'**
  String serviceStoppedAgo(String duration);

  /// User-facing label or message for service exit status.
  ///
  /// In en, this message translates to:
  /// **'exit status {code}'**
  String serviceExitStatus(int code);

  /// User-facing label or message for service full journal.
  ///
  /// In en, this message translates to:
  /// **'Full journal'**
  String get serviceFullJournal;

  /// User-facing label or message for service unit file.
  ///
  /// In en, this message translates to:
  /// **'Unit file'**
  String get serviceUnitFile;

  /// User-facing label or message for service journal recent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Last line} other{Last {count} lines}}'**
  String serviceJournalRecent(int count);

  /// User-facing label or message for service journal unreadable.
  ///
  /// In en, this message translates to:
  /// **'This account cannot read the journal'**
  String get serviceJournalUnreadable;

  /// User-facing label or message for server unreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not run a command on this server'**
  String get serverUnreachable;

  /// User-facing label or message for container no runtime.
  ///
  /// In en, this message translates to:
  /// **'No container runtime here'**
  String get containerNoRuntime;

  /// Help text for the container no runtime setting or action.
  ///
  /// In en, this message translates to:
  /// **'Neither `docker` nor `podman` answered on this machine. If one is installed for another account, turn on \"Try using sudo\" in Settings.'**
  String get containerNoRuntimeTip;

  /// User-facing label or message for container unreadable.
  ///
  /// In en, this message translates to:
  /// **'The container runtime answered in an unexpected form'**
  String get containerUnreadable;

  /// User-facing label or message for power.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get power;

  /// User-facing label or message for fan.
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get fan;

  /// User-facing label or message for clock speed.
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get clockSpeed;

  /// User-facing label or message for vendor.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get vendor;

  /// User-facing label or message for continue in terminal.
  ///
  /// In en, this message translates to:
  /// **'Continue in terminal'**
  String get continueInTerminal;

  /// User-facing label or message for ask AI risk unknown.
  ///
  /// In en, this message translates to:
  /// **'Unclassified'**
  String get askAiRiskUnknown;

  /// User-facing label or message for agent local exec.
  ///
  /// In en, this message translates to:
  /// **'Run commands on this device'**
  String get agentLocalExec;

  /// Help text for the agent local exec setting or action.
  ///
  /// In en, this message translates to:
  /// **'Lets the Agent work on the machine running ServerBox. Even read-only commands are reviewed'**
  String get agentLocalExecTip;

  /// Help text for the agent local exec rootfs setting or action.
  ///
  /// In en, this message translates to:
  /// **'Lets the Agent work locally, confined to the Linux container ServerBox installed'**
  String get agentLocalExecRootfsTip;

  /// User-facing label or message for mac DMG imported partly.
  ///
  /// In en, this message translates to:
  /// **'Imported the data of the previously installed build. Downloaded files were left where they were, in {path}.'**
  String macDmgImportedPartly(String path);

  /// User-facing label or message for BMC account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get bmcAccount;

  /// User-facing label or message for BMC account unset.
  ///
  /// In en, this message translates to:
  /// **'None picked - tap to choose or create one'**
  String get bmcAccountUnset;

  /// User-facing label or message for BMC account shared.
  ///
  /// In en, this message translates to:
  /// **'Used by {count} servers'**
  String bmcAccountShared(int count);

  /// User-facing label or message for BMC accounts.
  ///
  /// In en, this message translates to:
  /// **'BMC accounts'**
  String get bmcAccounts;

  /// Help text for the BMC account shared setting or action.
  ///
  /// In en, this message translates to:
  /// **'Editing this changes what all of them use.'**
  String get bmcAccountSharedTip;

  /// User-facing label or message for BMC account in use.
  ///
  /// In en, this message translates to:
  /// **'{count} servers use it. They keep their address and lose the account.'**
  String bmcAccountInUse(int count);

  /// User-facing label or message for BMC stale write.
  ///
  /// In en, this message translates to:
  /// **'The BMC changed while this was being written. Try again.'**
  String get bmcStaleWrite;

  /// Action label for send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// User-facing label or message for privacy blur.
  ///
  /// In en, this message translates to:
  /// **'Background privacy'**
  String get privacyBlur;

  /// Help text for the privacy blur setting or action.
  ///
  /// In en, this message translates to:
  /// **'Hide app content in the app switcher'**
  String get privacyBlurTip;

  /// User-facing label or message for float return to tab.
  ///
  /// In en, this message translates to:
  /// **'Return to tab'**
  String get floatReturnToTab;

  /// User-facing label or message for term in float window.
  ///
  /// In en, this message translates to:
  /// **'This terminal is in the floating window'**
  String get termInFloatWindow;

  /// Help text for the globe enabled setting or action.
  ///
  /// In en, this message translates to:
  /// **'Draw servers on a globe, at where their addresses are. Off removes the button from the server tab and stops every lookup.'**
  String get globeEnabledTip;

  /// User-facing label or message for geo shards consent attribution.
  ///
  /// In en, this message translates to:
  /// **'IP geolocation by [DB-IP](https://db-ip.com), CC BY 4.0.'**
  String get geoShardsConsentAttribution;

  /// User-facing label or message for geo miss private.
  ///
  /// In en, this message translates to:
  /// **'Private address'**
  String get geoMissPrivate;

  /// Empty-state message for geo miss no data.
  ///
  /// In en, this message translates to:
  /// **'No location data'**
  String get geoMissNoData;

  /// User-facing label or message for globe guide.
  ///
  /// In en, this message translates to:
  /// **'Tap here to see your servers on a globe, at where their addresses are.'**
  String get globeGuide;

  /// User-facing label or message for public IP.
  ///
  /// In en, this message translates to:
  /// **'Public IP'**
  String get publicIp;

  /// User-facing label or message for geo data.
  ///
  /// In en, this message translates to:
  /// **'City-level data'**
  String get geoData;

  /// Help text for the geo data setting or action.
  ///
  /// In en, this message translates to:
  /// **'After download, every geolocation lookup uses data stored on this device. Server addresses and lookup activity are not sent to the download service.'**
  String get geoDataTip;

  /// User-facing label or message for geo data missing.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get geoDataMissing;

  /// User-facing label or message for geo data unreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch the data.'**
  String get geoDataUnreachable;

  /// Error message shown when geo data remove failed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the data.'**
  String get geoDataRemoveFailed;

  /// User-facing label or message for geo data current.
  ///
  /// In en, this message translates to:
  /// **'{month} is already installed.'**
  String geoDataCurrent(String month);

  /// User-facing label or message for geo data consent.
  ///
  /// In en, this message translates to:
  /// **'**Download: {download} · On-device storage: {disk}.** The complete dataset is stored on this device, and every later geolocation lookup is performed locally. Server addresses and lookup activity are not sent to the download service.\n\nUpdated monthly. A newer version replaces the installed data without keeping an extra copy. You can delete it at any time.'**
  String geoDataConsent(String download, String disk);

  /// User-facing label or message for benchmark.
  ///
  /// In en, this message translates to:
  /// **'Benchmark'**
  String get benchmark;

  /// Introductory text for the benchmark screen or section.
  ///
  /// In en, this message translates to:
  /// **'Runs Yet Another Bench Script on this server: disk, network and CPU. A full run takes 10–20 minutes and keeps going if you leave this page or close the app.'**
  String get benchmarkIntro;

  /// User-facing label or message for benchmark no runs.
  ///
  /// In en, this message translates to:
  /// **'No benchmarks yet.'**
  String get benchmarkNoRuns;

  /// Status message shown while benchmark running.
  ///
  /// In en, this message translates to:
  /// **'Benchmark running'**
  String get benchmarkRunning;

  /// Error message shown when benchmark start failed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the benchmark'**
  String get benchmarkStartFailed;

  /// Confirmation prompt for benchmark cancel confirm.
  ///
  /// In en, this message translates to:
  /// **'Stop this benchmark? What it has measured so far is lost.'**
  String get benchmarkCancelConfirm;

  /// Confirmation prompt for benchmark delete confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this benchmark result?'**
  String get benchmarkDeleteConfirm;

  /// User-facing label or message for benchmark nothing selected.
  ///
  /// In en, this message translates to:
  /// **'Every phase is off. The run will collect system information only, and take a few seconds.'**
  String get benchmarkNothingSelected;

  /// Help text for the benchmark disk setting or action.
  ///
  /// In en, this message translates to:
  /// **'fio at four block sizes, about 3 minutes. Writes a 2 GB test file into the working directory and needs that much free.'**
  String get benchmarkDiskTip;

  /// Help text for the benchmark network setting or action.
  ///
  /// In en, this message translates to:
  /// **'iperf3 against public servers, about 4 minutes.'**
  String get benchmarkNetworkTip;

  /// User-facing label or message for benchmark reduced network.
  ///
  /// In en, this message translates to:
  /// **'Fewer locations'**
  String get benchmarkReducedNetwork;

  /// Help text for the benchmark reduced network setting or action.
  ///
  /// In en, this message translates to:
  /// **'Three locations instead of seven. Roughly {full} of traffic becomes {reduced}.'**
  String benchmarkReducedNetworkTip(String full, String reduced);

  /// Help text for the benchmark CPU setting or action.
  ///
  /// In en, this message translates to:
  /// **'Downloads Geekbench, a proprietary program, and **publishes the result to a public page on geekbench.com** — CPU model, core count and memory included.'**
  String get benchmarkCpuTip;

  /// User-facing label or message for benchmark sensitive options.
  ///
  /// In en, this message translates to:
  /// **'The options below download and run third-party software on this server or send server information to third parties. They are off by default.'**
  String get benchmarkSensitiveOptions;

  /// Help text for the benchmark IP info setting or action.
  ///
  /// In en, this message translates to:
  /// **'Sends this server\'s public address to ip-api.com over plain HTTP.'**
  String get benchmarkIpInfoTip;

  /// User-facing label or message for benchmark IP info.
  ///
  /// In en, this message translates to:
  /// **'Look up IP owner'**
  String get benchmarkIpInfo;

  /// User-facing label or message for benchmark prefer bin.
  ///
  /// In en, this message translates to:
  /// **'Download fio and iperf3'**
  String get benchmarkPreferBin;

  /// Help text for the benchmark prefer bin setting or action.
  ///
  /// In en, this message translates to:
  /// **'Downloads them from GitHub instead of using the host\'s packages. Turn on only if the host has neither installed.'**
  String get benchmarkPreferBinTip;

  /// User-facing label or message for benchmark work dir.
  ///
  /// In en, this message translates to:
  /// **'Working directory'**
  String get benchmarkWorkDir;

  /// Help text for the benchmark work dir setting or action.
  ///
  /// In en, this message translates to:
  /// **'Decides which filesystem the disk test measures. Empty means the login account\'s home directory.'**
  String get benchmarkWorkDirTip;

  /// User-facing label or message for benchmark estimated time.
  ///
  /// In en, this message translates to:
  /// **'About {minutes} min'**
  String benchmarkEstimatedTime(int minutes);

  /// User-facing label or message for benchmark estimated traffic.
  ///
  /// In en, this message translates to:
  /// **'About {size} of traffic'**
  String benchmarkEstimatedTraffic(String size);

  /// User-facing label or message for benchmark phase system.
  ///
  /// In en, this message translates to:
  /// **'Reading system information'**
  String get benchmarkPhaseSystem;

  /// User-facing label or message for benchmark phase disk.
  ///
  /// In en, this message translates to:
  /// **'Testing disk'**
  String get benchmarkPhaseDisk;

  /// User-facing label or message for benchmark phase network.
  ///
  /// In en, this message translates to:
  /// **'Testing network'**
  String get benchmarkPhaseNetwork;

  /// User-facing label or message for benchmark phase CPU.
  ///
  /// In en, this message translates to:
  /// **'Testing CPU'**
  String get benchmarkPhaseCpu;

  /// User-facing label or message for benchmark phase done.
  ///
  /// In en, this message translates to:
  /// **'Finishing'**
  String get benchmarkPhaseDone;

  /// User-facing label or message for benchmark result unreadable.
  ///
  /// In en, this message translates to:
  /// **'This result could not be read as JSON. The raw text is below.'**
  String get benchmarkResultUnreadable;

  /// User-facing label or message for benchmark view on geekbench.
  ///
  /// In en, this message translates to:
  /// **'View on Geekbench'**
  String get benchmarkViewOnGeekbench;

  /// User-facing label or message for benchmark geekbench public.
  ///
  /// In en, this message translates to:
  /// **'This result is published publicly at the link above.'**
  String get benchmarkGeekbenchPublic;

  /// User-facing label or message for benchmark single core.
  ///
  /// In en, this message translates to:
  /// **'Single core'**
  String get benchmarkSingleCore;

  /// User-facing label or message for benchmark multi core.
  ///
  /// In en, this message translates to:
  /// **'Multi core'**
  String get benchmarkMultiCore;

  /// User-facing label or message for benchmark IOPS.
  ///
  /// In en, this message translates to:
  /// **'IOPS'**
  String get benchmarkIops;

  /// User-facing label or message for benchmark send.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get benchmarkSend;

  /// User-facing label or message for benchmark recv.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get benchmarkRecv;

  /// User-facing label or message for benchmark latency.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get benchmarkLatency;

  /// User-facing label or message for benchmark virt.
  ///
  /// In en, this message translates to:
  /// **'Virtualization'**
  String get benchmarkVirt;

  /// User-facing label or message for benchmark raw log.
  ///
  /// In en, this message translates to:
  /// **'Run log'**
  String get benchmarkRawLog;

  /// User-facing label or message for benchmark upstream.
  ///
  /// In en, this message translates to:
  /// **'Powered by Yet Another Bench Script ({version})'**
  String benchmarkUpstream(String version);

  /// User-facing label or message for benchmark phase starting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get benchmarkPhaseStarting;

  /// User-facing label or message for benchmark no output yet.
  ///
  /// In en, this message translates to:
  /// **'No output yet. Before printing its first line, YABS checks whether google.com and icanhazip.com are reachable. On networks that block either site, this can take several minutes.'**
  String get benchmarkNoOutputYet;

  /// Help text for the tags empty setting or action.
  ///
  /// In en, this message translates to:
  /// **'No tags yet. Add one while editing a server and it will appear here.'**
  String get tagsEmptyTip;

  /// User-facing label or message for benchmark no servers.
  ///
  /// In en, this message translates to:
  /// **'Add a server first, then return here to benchmark it.'**
  String get benchmarkNoServers;

  /// Title shown for the schema too new dialog or section.
  ///
  /// In en, this message translates to:
  /// **'This data is newer than the app'**
  String get schemaTooNewTitle;

  /// Explanatory message shown in the schema too new dialog or notice.
  ///
  /// In en, this message translates to:
  /// **'It was written by a newer version of ServerBox (storage v{stored}). This version reads up to v{supported}; nothing has been changed.'**
  String schemaTooNewBody(int stored, int supported);

  /// User-facing label or message for schema too new reinstall.
  ///
  /// In en, this message translates to:
  /// **'Reinstall the newer version to open all your data again.'**
  String get schemaTooNewReinstall;

  /// User-facing label or message for schema too new export plain.
  ///
  /// In en, this message translates to:
  /// **'Export without a password'**
  String get schemaTooNewExportPlain;

  /// User-facing label or message for schema too new plain warn.
  ///
  /// In en, this message translates to:
  /// **'The file will contain every SSH private key, server password and API key in plain text. Anyone who gets the file can access them all.'**
  String get schemaTooNewPlainWarn;

  /// User-facing label or message for schema too new wipe.
  ///
  /// In en, this message translates to:
  /// **'Delete all data'**
  String get schemaTooNewWipe;

  /// Confirmation prompt for schema too new wipe confirm.
  ///
  /// In en, this message translates to:
  /// **'All servers, keys, snippets and settings on this device will be deleted. This cannot be undone. A backup exported here would be the only copy left.'**
  String get schemaTooNewWipeConfirm;

  /// User-facing label or message for schema too new wipe done.
  ///
  /// In en, this message translates to:
  /// **'Data deleted. Open the app again to start fresh.'**
  String get schemaTooNewWipeDone;

  /// Error message shown when schema too new wipe failed.
  ///
  /// In en, this message translates to:
  /// **'Some of the data could not be deleted, and this build still cannot open what is left. Reinstall the newer version to reach it.'**
  String get schemaTooNewWipeFailed;

  /// User-facing label or message for system users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get systemUsers;

  /// User-facing label or message for user manager linux only.
  ///
  /// In en, this message translates to:
  /// **'System user management currently supports Linux servers.'**
  String get userManagerLinuxOnly;

  /// User-facing label or message for user regular account.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get userRegularAccount;

  /// User-facing label or message for user current account.
  ///
  /// In en, this message translates to:
  /// **'Current account'**
  String get userCurrentAccount;

  /// User-facing label or message for user system account.
  ///
  /// In en, this message translates to:
  /// **'System account'**
  String get userSystemAccount;

  /// User-facing label or message for user UID.
  ///
  /// In en, this message translates to:
  /// **'UID'**
  String get userUid;

  /// User-facing label or message for user login status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get userLoginStatus;

  /// User-facing label or message for user login enabled.
  ///
  /// In en, this message translates to:
  /// **'Login enabled'**
  String get userLoginEnabled;

  /// User-facing label or message for user detail account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get userDetailAccount;

  /// User-facing label or message for user detail security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get userDetailSecurity;

  /// User-facing label or message for user SSH keys.
  ///
  /// In en, this message translates to:
  /// **'SSH keys'**
  String get userSshKeys;

  /// User-facing label or message for user expires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get userExpires;

  /// User-facing label or message for user never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get userNever;

  /// User-facing label or message for user password set.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get userPasswordSet;

  /// User-facing label or message for user password locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get userPasswordLocked;

  /// Empty-state message for user password none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get userPasswordNone;

  /// User-facing label or message for user superuser.
  ///
  /// In en, this message translates to:
  /// **'Superuser'**
  String get userSuperuser;

  /// User-facing label or message for user open shell.
  ///
  /// In en, this message translates to:
  /// **'Open shell'**
  String get userOpenShell;

  /// User-facing label or message for user root changes warning.
  ///
  /// In en, this message translates to:
  /// **'Changes to root take effect in every session at once.'**
  String get userRootChangesWarning;

  /// User-facing label or message for user comment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get userComment;

  /// User-facing label or message for user primary group.
  ///
  /// In en, this message translates to:
  /// **'Primary group'**
  String get userPrimaryGroup;

  /// User-facing label or message for user supplementary groups.
  ///
  /// In en, this message translates to:
  /// **'Supplementary groups'**
  String get userSupplementaryGroups;

  /// User-facing label or message for user login shell.
  ///
  /// In en, this message translates to:
  /// **'Login shell'**
  String get userLoginShell;

  /// User-facing label or message for user create home.
  ///
  /// In en, this message translates to:
  /// **'Create home directory'**
  String get userCreateHome;

  /// User-facing label or message for user move home.
  ///
  /// In en, this message translates to:
  /// **'Move the existing home directory when the path changes'**
  String get userMoveHome;

  /// User-facing label or message for user remove home.
  ///
  /// In en, this message translates to:
  /// **'Remove the home directory'**
  String get userRemoveHome;

  /// Help text for the user password create setting or action.
  ///
  /// In en, this message translates to:
  /// **'Leave the password empty to create a password-locked account.'**
  String get userPasswordCreateTip;

  /// Help text for the user password edit setting or action.
  ///
  /// In en, this message translates to:
  /// **'Leave the password empty to keep the existing password.'**
  String get userPasswordEditTip;

  /// Formatted user-facing message for func unavailable; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'{func} is not available over this server\'s connection.'**
  String funcUnavailableFmt(String func);

  /// User-facing label or message for range live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get rangeLive;

  /// User-facing label or message for disk io.
  ///
  /// In en, this message translates to:
  /// **'Disk I/O'**
  String get diskIo;

  /// User-facing label or message for peak.
  ///
  /// In en, this message translates to:
  /// **'peak'**
  String get peak;

  /// User-facing label or message for hardware.
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get hardware;

  /// User-facing label or message for cores.
  ///
  /// In en, this message translates to:
  /// **'Cores'**
  String get cores;

  /// User-facing label or message for history no stored.
  ///
  /// In en, this message translates to:
  /// **'Only a monitor agent stores history. This connection keeps what this app has seen since it connected.'**
  String get historyNoStored;

  /// User-facing label or message for no history yet.
  ///
  /// In en, this message translates to:
  /// **'Nothing measured yet'**
  String get noHistoryYet;

  /// User-facing label or message for no data.
  ///
  /// In en, this message translates to:
  /// **'no data'**
  String get noData;

  /// User-facing label or message for from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// User-facing label or message for to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// User-facing label or message for beyond retention.
  ///
  /// In en, this message translates to:
  /// **'beyond what this agent kept'**
  String get beyondRetention;

  /// Formatted user-facing message for agent retention; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Agent keeps {kept}'**
  String agentRetentionFmt(String kept);

  /// Formatted user-facing message for oldest sample; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'oldest sample {time}'**
  String oldestSampleFmt(String time);

  /// User-facing label or message for range ends before it starts.
  ///
  /// In en, this message translates to:
  /// **'The end of the range has to be after its start.'**
  String get rangeEndsBeforeItStarts;

  /// User-facing label or message for samples.
  ///
  /// In en, this message translates to:
  /// **'samples'**
  String get samples;

  /// User-facing label or message for unavailable.
  ///
  /// In en, this message translates to:
  /// **'unavailable'**
  String get unavailable;

  /// Help text for the metric unavailable setting or action.
  ///
  /// In en, this message translates to:
  /// **'The rest of this page is unaffected. Check the command this reading comes from on the host.'**
  String get metricUnavailableTip;

  /// User-facing label or message for waiting first sample.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the first sample'**
  String get waitingFirstSample;

  /// Formatted user-facing message for at time; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'at {time}'**
  String atTimeFmt(String time);

  /// User-facing label or message for stored.
  ///
  /// In en, this message translates to:
  /// **'stored'**
  String get stored;

  /// Formatted user-facing message for last sample; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'last sample {ago}'**
  String lastSampleFmt(String ago);

  /// Formatted user-facing message for stale since; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Everything below is from {time}, {ago}.'**
  String staleSinceFmt(String ago, String time);

  /// Formatted user-facing message for no data before; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'no data before {time}'**
  String noDataBeforeFmt(String time);

  /// Formatted user-facing message for loading range; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Loading {range}…'**
  String loadingRangeFmt(String range);

  /// User-facing label or message for no stored history for.
  ///
  /// In en, this message translates to:
  /// **'No stored history for {metric}'**
  String noStoredHistoryFor(String metric);

  /// Formatted user-facing message for devices; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'{count} devices'**
  String devicesFmt(int count);

  /// Formatted user-facing message for devices busiest; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'{count} devices · {name} busiest'**
  String devicesBusiestFmt(int count, String name);

  /// Formatted user-facing message for devices plotted; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'{plotted} of {total} devices'**
  String devicesPlottedFmt(int plotted, int total);

  /// Formatted user-facing message for sensors hottest; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'{count} sensors · {name} hottest'**
  String sensorsHottestFmt(int count, String name);

  /// User-facing label or message for one device at least.
  ///
  /// In en, this message translates to:
  /// **'At least one device stays on the chart.'**
  String get oneDeviceAtLeast;

  /// Formatted user-facing message for shown of; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} {what}'**
  String shownOfFmt(int shown, int total, String what);

  /// Formatted user-facing message for count of; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'{count} {what}'**
  String countOfFmt(int count, String what);

  /// User-facing label or message for unit devices.
  ///
  /// In en, this message translates to:
  /// **'devices'**
  String get unitDevices;

  /// User-facing label or message for unit sensors.
  ///
  /// In en, this message translates to:
  /// **'sensors'**
  String get unitSensors;

  /// User-facing label or message for unit batteries.
  ///
  /// In en, this message translates to:
  /// **'batteries'**
  String get unitBatteries;

  /// User-facing label or message for unit commands.
  ///
  /// In en, this message translates to:
  /// **'commands'**
  String get unitCommands;

  /// User-facing label or message for unit readings.
  ///
  /// In en, this message translates to:
  /// **'readings'**
  String get unitReadings;

  /// User-facing label or message for unit gpus.
  ///
  /// In en, this message translates to:
  /// **'GPUs'**
  String get unitGpus;

  /// User-facing label or message for hottest.
  ///
  /// In en, this message translates to:
  /// **'hottest'**
  String get hottest;

  /// User-facing label or message for oldest.
  ///
  /// In en, this message translates to:
  /// **'oldest'**
  String get oldest;

  /// User-facing label or message for not applicable.
  ///
  /// In en, this message translates to:
  /// **'not applicable'**
  String get notApplicable;

  /// User-facing label or message for attributes.
  ///
  /// In en, this message translates to:
  /// **'attributes'**
  String get attributes;

  /// User-facing label or message for power on hours.
  ///
  /// In en, this message translates to:
  /// **'Power-on hours'**
  String get powerOnHours;

  /// User-facing label or message for power cycles.
  ///
  /// In en, this message translates to:
  /// **'Power cycles'**
  String get powerCycles;

  /// User-facing label or message for life left.
  ///
  /// In en, this message translates to:
  /// **'Life left'**
  String get lifeLeft;

  /// User-facing label or message for lifetime write.
  ///
  /// In en, this message translates to:
  /// **'Lifetime write'**
  String get lifetimeWrite;

  /// User-facing label or message for lifetime read.
  ///
  /// In en, this message translates to:
  /// **'Lifetime read'**
  String get lifetimeRead;

  /// User-facing label or message for average erase.
  ///
  /// In en, this message translates to:
  /// **'Average erase'**
  String get averageErase;

  /// User-facing label or message for unsafe shutdowns.
  ///
  /// In en, this message translates to:
  /// **'Unsafe shutdowns'**
  String get unsafeShutdowns;

  /// User-facing label or message for disk all passed.
  ///
  /// In en, this message translates to:
  /// **'all PASSED'**
  String get diskAllPassed;

  /// Formatted user-facing message for disk warning; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 warning} other{{count} warnings}}'**
  String diskWarningFmt(int count);

  /// Formatted user-facing message for disk wrong of; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'{wrong} of {total} devices'**
  String diskWrongOfFmt(int total, int wrong);

  /// Help text for the disk smart sorted setting or action.
  ///
  /// In en, this message translates to:
  /// **'Sorted worst first'**
  String get diskSmartSortedTip;

  /// Formatted user-facing message for read ago; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'read {ago}'**
  String readAgoFmt(String ago);

  /// Formatted user-facing message for processes; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'{count} processes'**
  String processesFmt(int count);

  /// Formatted user-facing message for disk failing; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'{count} failing'**
  String diskFailingFmt(int count);

  /// Help text for the disk smart open setting or action.
  ///
  /// In en, this message translates to:
  /// **'Open one for its attributes'**
  String get diskSmartOpenTip;

  /// User-facing label or message for cycle.
  ///
  /// In en, this message translates to:
  /// **'Cycle'**
  String get cycle;

  /// User-facing label or message for window.
  ///
  /// In en, this message translates to:
  /// **'window'**
  String get window;

  /// Formatted user-facing message for of; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String ofFmt(String total);

  /// User-facing label or message for server detail cards.
  ///
  /// In en, this message translates to:
  /// **'Detail page cards'**
  String get serverDetailCards;

  /// Action label for connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// Help text for the connection setting or action.
  ///
  /// In en, this message translates to:
  /// **'Both can be on at once. The order is the order they are dialled.'**
  String get connectionTip;

  /// Formatted user-facing message for transport order; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Drag to change the order. {first} is dialled first; if it does not answer, {second} carries the session on its own.'**
  String transportOrderFmt(String first, String second);

  /// Formatted user-facing message for transport only; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Only {name} is on, so there is nothing to fall back to.'**
  String transportOnlyFmt(String name);

  /// User-facing label or message for transport none on.
  ///
  /// In en, this message translates to:
  /// **'Both are off — this server cannot be connected.'**
  String get transportNoneOn;

  /// User-facing label or message for transport off kept.
  ///
  /// In en, this message translates to:
  /// **'off — settings kept, never dialled'**
  String get transportOffKept;

  /// User-facing label or message for transport dialled first.
  ///
  /// In en, this message translates to:
  /// **'dialled first'**
  String get transportDialledFirst;

  /// User-facing label or message for transport fallback.
  ///
  /// In en, this message translates to:
  /// **'fallback'**
  String get transportFallback;

  /// User-facing label or message for transport only method.
  ///
  /// In en, this message translates to:
  /// **'only method'**
  String get transportOnlyMethod;

  /// User-facing label or message for transport off.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get transportOff;

  /// User-facing label or message for this device.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// Help text for the local server setting or action.
  ///
  /// In en, this message translates to:
  /// **'Reads this device directly, by running the status script here. SSH and Monitor HTTP are not used, and their settings are kept.'**
  String get localServerTip;

  /// User-facing label or message for local server unsupported.
  ///
  /// In en, this message translates to:
  /// **'This platform cannot read this device as a server. Linux, Windows and the macOS DMG build can.'**
  String get localServerUnsupported;

  /// Introductory text for the remote desktop screen or section.
  ///
  /// In en, this message translates to:
  /// **'Open a server\'s RDP or VNC desktop inside the app. The connection goes through the server\'s SSH connection or its Monitor agent, so the desktop port does not have to be reachable from the network.'**
  String get remoteDesktopIntro;

  /// User-facing label or message for remote desktop intro profiles.
  ///
  /// In en, this message translates to:
  /// **'Save a profile per desktop from the Remote desktop button on a server, or from the Remote desktop tab.'**
  String get remoteDesktopIntroProfiles;

  /// Introductory text for the local server screen or section.
  ///
  /// In en, this message translates to:
  /// **'Add the device running ServerBox as a server. Status, processes, services, containers, the terminal and files all work without SSH or a Monitor agent.'**
  String get localServerIntro;

  /// User-facing label or message for local server add.
  ///
  /// In en, this message translates to:
  /// **'Add this device'**
  String get localServerAdd;

  /// User-facing label or message for local server intro footer.
  ///
  /// In en, this message translates to:
  /// **'It can also be turned on later, in a server\'s edit page under Connection.'**
  String get localServerIntroFooter;

  /// User-facing label or message for transport section off.
  ///
  /// In en, this message translates to:
  /// **'Off. The fields below are kept for when you turn it back on.'**
  String get transportSectionOff;

  /// User-facing label or message for monitor agent.
  ///
  /// In en, this message translates to:
  /// **'Monitor agent'**
  String get monitorAgent;

  /// Help text for the plain HTTP edit setting or action.
  ///
  /// In en, this message translates to:
  /// **'Credentials and metrics cross the network unencrypted. Keep it to a LAN or a Tailscale address, or put the agent behind TLS.'**
  String get plainHttpEditTip;

  /// User-facing label or message for behaviour.
  ///
  /// In en, this message translates to:
  /// **'Behaviour'**
  String get behaviour;

  /// User-facing label or message for optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// Help text for the optional setting or action.
  ///
  /// In en, this message translates to:
  /// **'Nothing here is needed to connect. Open one and its fields take over the form.'**
  String get optionalTip;

  /// User-facing label or message for SSH advanced.
  ///
  /// In en, this message translates to:
  /// **'SSH advanced'**
  String get sshAdvanced;

  /// Help text for the SSH advanced setting or action.
  ///
  /// In en, this message translates to:
  /// **'Fallback destination, ProxyCommand, jump server, file transport, remote path'**
  String get sshAdvancedTip;

  /// User-facing label or message for SSH legacy algorithms.
  ///
  /// In en, this message translates to:
  /// **'Legacy algorithms'**
  String get sshLegacyAlgorithms;

  /// Help text for the SSH legacy algorithms setting or action.
  ///
  /// In en, this message translates to:
  /// **'For an old SSH daemon (a router, a switch) that only offers the SHA-1 `ssh-rsa` host key or a SHA-1 key exchange. Less secure; turn it on only for a host that needs it.'**
  String get sshLegacyAlgorithmsTip;

  /// User-facing label or message for appearance and place.
  ///
  /// In en, this message translates to:
  /// **'Appearance & location'**
  String get appearanceAndPlace;

  /// Help text for the appearance and place setting or action.
  ///
  /// In en, this message translates to:
  /// **'Logo, coordinates'**
  String get appearanceAndPlaceTip;

  /// User-facing label or message for status collection.
  ///
  /// In en, this message translates to:
  /// **'Status collection'**
  String get statusCollection;

  /// Help text for the status collection setting or action.
  ///
  /// In en, this message translates to:
  /// **'Which commands run, custom commands, which device to read'**
  String get statusCollectionTip;

  /// User-facing label or message for tag all tags.
  ///
  /// In en, this message translates to:
  /// **'All tags'**
  String get tagAllTags;

  /// User-facing label or message for tag matching.
  ///
  /// In en, this message translates to:
  /// **'Matching'**
  String get tagMatching;

  /// Hint shown in the tag new field or section.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get tagNewHint;

  /// Formatted user-facing message for tag create; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Create #{tag}'**
  String tagCreateFmt(String tag);

  /// User-facing label or message for tag on this server.
  ///
  /// In en, this message translates to:
  /// **'on this server'**
  String get tagOnThisServer;

  /// Formatted user-facing message for tag servers; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'{count} servers'**
  String tagServersFmt(int count);

  /// Formatted user-facing message for tag on this server; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'{count} on this server'**
  String tagOnThisServerFmt(int count);

  /// User-facing label or message for tag matches typed.
  ///
  /// In en, this message translates to:
  /// **'matches what you typed'**
  String get tagMatchesTyped;

  /// Help text for the tag editor setting or action.
  ///
  /// In en, this message translates to:
  /// **'Typing filters the list; the button creates the tag and puts it on this server in one step. Renaming from the pencil renames it on every server that carries it. A tag no server carries disappears on save.'**
  String get tagEditorTip;

  /// User-facing label or message for tag renames on save.
  ///
  /// In en, this message translates to:
  /// **'Renames apply on save'**
  String get tagRenamesOnSave;

  /// User-facing label or message for scheduled tasks.
  ///
  /// In en, this message translates to:
  /// **'Scheduled tasks'**
  String get scheduledTasks;

  /// User-facing label or message for scheduled task linux only.
  ///
  /// In en, this message translates to:
  /// **'Scheduled task management currently supports Linux servers.'**
  String get scheduledTaskLinuxOnly;

  /// User-facing label or message for scheduled task unavailable.
  ///
  /// In en, this message translates to:
  /// **'crontab is not available on this server.'**
  String get scheduledTaskUnavailable;

  /// Help text for the scheduled task preserve setting or action.
  ///
  /// In en, this message translates to:
  /// **'Comments, environment variables, and unrecognized lines in this crontab are preserved.'**
  String get scheduledTaskPreserveTip;

  /// User-facing label or message for scheduled task schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduledTaskSchedule;

  /// User-facing label or message for scheduled task add.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get scheduledTaskAdd;

  /// User-facing label or message for scheduled task next run.
  ///
  /// In en, this message translates to:
  /// **'Next run'**
  String get scheduledTaskNextRun;

  /// Formatted user-facing message for scheduled task next in; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'in {time}'**
  String scheduledTaskNextInFmt(String time);

  /// User-facing label or message for scheduled task enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get scheduledTaskEnabled;

  /// User-facing label or message for scheduled task commented out.
  ///
  /// In en, this message translates to:
  /// **'Commented out'**
  String get scheduledTaskCommentedOut;

  /// Formatted user-facing message for scheduled task summary; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'{total} tasks · {enabled} enabled'**
  String scheduledTaskSummaryFmt(int enabled, int total);

  /// Hint shown in the scheduled task filter field or section.
  ///
  /// In en, this message translates to:
  /// **'Filter tasks'**
  String get scheduledTaskFilterHint;

  /// User-facing label or message for scheduled task preserved.
  ///
  /// In en, this message translates to:
  /// **'Preserved lines'**
  String get scheduledTaskPreserved;

  /// User-facing label or message for scheduled task raw.
  ///
  /// In en, this message translates to:
  /// **'Raw crontab'**
  String get scheduledTaskRaw;

  /// User-facing label or message for scheduled task enable now.
  ///
  /// In en, this message translates to:
  /// **'Enable now'**
  String get scheduledTaskEnableNow;

  /// Help text for the scheduled task enable now setting or action.
  ///
  /// In en, this message translates to:
  /// **'Off writes the line commented out.'**
  String get scheduledTaskEnableNowTip;

  /// Formatted user-facing message for scheduled task empty; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'No scheduled tasks for {user}. What is added here is written into that account\'s crontab.'**
  String scheduledTaskEmptyFmt(String user);

  /// User-facing label or message for scheduled task field minute.
  ///
  /// In en, this message translates to:
  /// **'Minute'**
  String get scheduledTaskFieldMinute;

  /// User-facing label or message for scheduled task field hour.
  ///
  /// In en, this message translates to:
  /// **'Hour'**
  String get scheduledTaskFieldHour;

  /// User-facing label or message for scheduled task field day of month.
  ///
  /// In en, this message translates to:
  /// **'Day of month'**
  String get scheduledTaskFieldDayOfMonth;

  /// User-facing label or message for scheduled task field month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get scheduledTaskFieldMonth;

  /// User-facing label or message for scheduled task field day of week.
  ///
  /// In en, this message translates to:
  /// **'Day of week'**
  String get scheduledTaskFieldDayOfWeek;

  /// Empty-state message for cron err schedule empty.
  ///
  /// In en, this message translates to:
  /// **'A schedule is required.'**
  String get cronErrScheduleEmpty;

  /// Empty-state message for cron err command empty.
  ///
  /// In en, this message translates to:
  /// **'A command is required.'**
  String get cronErrCommandEmpty;

  /// User-facing label or message for cron err line break.
  ///
  /// In en, this message translates to:
  /// **'A crontab line cannot contain line breaks.'**
  String get cronErrLineBreak;

  /// User-facing label or message for cron err macro.
  ///
  /// In en, this message translates to:
  /// **'A macro is one word, such as @reboot.'**
  String get cronErrMacro;

  /// User-facing label or message for cron err field count.
  ///
  /// In en, this message translates to:
  /// **'A cron schedule has five fields, or a macro such as @reboot.'**
  String get cronErrFieldCount;

  /// User-facing label or message for cron at boot.
  ///
  /// In en, this message translates to:
  /// **'At boot'**
  String get cronAtBoot;

  /// User-facing label or message for cron every min.
  ///
  /// In en, this message translates to:
  /// **'Every minute'**
  String get cronEveryMin;

  /// Formatted user-facing message for cron every mins; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Every {minutes} minutes'**
  String cronEveryMinsFmt(int minutes);

  /// Formatted user-facing message for cron hourly at; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Every hour at :{minute}'**
  String cronHourlyAtFmt(String minute);

  /// Formatted user-facing message for cron every hours; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Every {hours} hours'**
  String cronEveryHoursFmt(int hours);

  /// Formatted user-facing message for cron every hours at; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Every {hours} hours at :{minute}'**
  String cronEveryHoursAtFmt(int hours, String minute);

  /// Formatted user-facing message for cron daily at; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Every day at {time}'**
  String cronDailyAtFmt(String time);

  /// Formatted user-facing message for cron weekdays at; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'On weekdays at {time}'**
  String cronWeekdaysAtFmt(String time);

  /// Formatted user-facing message for cron weekday at; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Every {day} at {time}'**
  String cronWeekdayAtFmt(String day, String time);

  /// Formatted user-facing message for cron monthly at; runtime values are supplied by placeholders.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of every month at {time}'**
  String cronMonthlyAtFmt(int day, String time);

  /// User-facing label or message for monitor settings.
  ///
  /// In en, this message translates to:
  /// **'Monitor settings'**
  String get monitorSettings;

  /// User-facing label or message for monitor agent default.
  ///
  /// In en, this message translates to:
  /// **'Agent default'**
  String get monitorAgentDefault;

  /// User-facing label or message for monitor needs restart.
  ///
  /// In en, this message translates to:
  /// **'Takes effect after the agent restarts'**
  String get monitorNeedsRestart;

  /// User-facing label or message for monitor collection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get monitorCollection;

  /// User-facing label or message for extended interval.
  ///
  /// In en, this message translates to:
  /// **'Extended cycle interval'**
  String get extendedInterval;

  /// User-facing label or message for idle pause.
  ///
  /// In en, this message translates to:
  /// **'Pause when nothing is watching'**
  String get idlePause;

  /// Help text for the idle pause setting or action.
  ///
  /// In en, this message translates to:
  /// **'The extended cycle runs smartctl, sensors and amd-smi. Pausing it while no client is polling keeps a disk from being woken for data nobody is reading.'**
  String get idlePauseTip;

  /// User-facing label or message for idle pause threshold.
  ///
  /// In en, this message translates to:
  /// **'Idle after'**
  String get idlePauseThreshold;

  /// User-facing label or message for monitor alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get monitorAlerts;

  /// User-facing label or message for monitoring rules.
  ///
  /// In en, this message translates to:
  /// **'Alert rules'**
  String get monitoringRules;

  /// User-facing label or message for rule monitor type.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get ruleMonitorType;

  /// User-facing label or message for rule threshold.
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get ruleThreshold;

  /// User-facing label or message for rule matcher.
  ///
  /// In en, this message translates to:
  /// **'Matcher'**
  String get ruleMatcher;

  /// Help text for the rule setting or action.
  ///
  /// In en, this message translates to:
  /// **'Metric: cpu / memory / swap / disk / network / temperature. Matcher: cpu0 for one core, used / free / avail for memory, rx / tx for network; disk and temperature ignore it. Threshold: a comparator and a value, such as >=80%, >=70c or >10m/s.'**
  String get ruleTip;

  /// User-facing label or message for push channels.
  ///
  /// In en, this message translates to:
  /// **'Notification channels'**
  String get pushChannels;

  /// User-facing label or message for push type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get pushType;

  /// User-facing label or message for push rate.
  ///
  /// In en, this message translates to:
  /// **'Rate limit'**
  String get pushRate;

  /// User-facing label or message for push headers.
  ///
  /// In en, this message translates to:
  /// **'Headers'**
  String get pushHeaders;

  /// User-facing label or message for push secret set.
  ///
  /// In en, this message translates to:
  /// **'Set on the agent, not shown'**
  String get pushSecretSet;

  /// User-facing label or message for push secret keep.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep'**
  String get pushSecretKeep;

  /// Help text for the push test setting or action.
  ///
  /// In en, this message translates to:
  /// **'Sends one notification through this channel as it stands here, saved or not.'**
  String get pushTestTip;

  /// User-facing label or message for push test sent.
  ///
  /// In en, this message translates to:
  /// **'The channel accepted it'**
  String get pushTestSent;

  /// Error message shown when push test failed.
  ///
  /// In en, this message translates to:
  /// **'The channel refused it'**
  String get pushTestFailed;

  /// User-facing label or message for push test message.
  ///
  /// In en, this message translates to:
  /// **'Test notification from ServerBox Monitor'**
  String get pushTestMessage;

  /// User-facing label or message for push unknown type.
  ///
  /// In en, this message translates to:
  /// **'This agent has no sender for this channel type, so its settings are not shown. It can be removed here, or edited in the agent\'s config.toml.'**
  String get pushUnknownType;

  /// User-facing label or message for push json invalid.
  ///
  /// In en, this message translates to:
  /// **'is not valid JSON'**
  String get pushJsonInvalid;

  /// User-facing label or message for data retention.
  ///
  /// In en, this message translates to:
  /// **'Data retention'**
  String get dataRetention;

  /// Help text for the data retention setting or action.
  ///
  /// In en, this message translates to:
  /// **'Off means the agent never deletes anything and its database grows without limit.'**
  String get dataRetentionTip;

  /// User-facing label or message for retention metrics.
  ///
  /// In en, this message translates to:
  /// **'Keep metrics'**
  String get retentionMetrics;

  /// User-facing label or message for retention alerts.
  ///
  /// In en, this message translates to:
  /// **'Keep alerts'**
  String get retentionAlerts;

  /// User-facing label or message for retention cleanup.
  ///
  /// In en, this message translates to:
  /// **'Run cleanup every'**
  String get retentionCleanup;

  /// User-facing label or message for retention max db size.
  ///
  /// In en, this message translates to:
  /// **'Database size cap'**
  String get retentionMaxDbSize;

  /// User-facing label or message for cors origins.
  ///
  /// In en, this message translates to:
  /// **'CORS allowed origins'**
  String get corsOrigins;

  /// Help text for the cors origins setting or action.
  ///
  /// In en, this message translates to:
  /// **'Origins a browser panel may call this agent from. Empty means same-origin only.'**
  String get corsOriginsTip;

  /// User-facing label or message for monitor no remote access.
  ///
  /// In en, this message translates to:
  /// **'This agent is set up for monitoring only. You can\'t open a terminal, run commands, or browse files here. To enable these features, edit [remote_access] in the agent\'s config.toml.'**
  String get monitorNoRemoteAccess;

  /// User-facing label or message for alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// User-facing label or message for online.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get online;

  /// User-facing label or message for density cards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get densityCards;

  /// User-facing label or message for density rows.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get densityRows;

  /// User-facing label or message for density grid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get densityGrid;

  /// Action label for connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// Action label for disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// Help text for the search server setting or action.
  ///
  /// In en, this message translates to:
  /// **'Searches names and addresses — the two the editor asks for first.'**
  String get searchServerTip;

  /// Help text for the add server setting or action.
  ///
  /// In en, this message translates to:
  /// **'Fill one in, scan a QR code, or import a file somebody shared.'**
  String get addServerTip;

  /// User-facing label or message for move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// User-facing label or message for move to top.
  ///
  /// In en, this message translates to:
  /// **'Move to top'**
  String get moveToTop;

  /// User-facing label or message for move to bottom.
  ///
  /// In en, this message translates to:
  /// **'Move to bottom'**
  String get moveToBottom;

  /// User-facing label or message for group by tag.
  ///
  /// In en, this message translates to:
  /// **'Group by tag'**
  String get groupByTag;

  /// Help text for the group by tag setting or action.
  ///
  /// In en, this message translates to:
  /// **'Tags are set in a server’s own editor.'**
  String get groupByTagTip;

  /// Action label for connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// User-facing label or message for auth short.
  ///
  /// In en, this message translates to:
  /// **'Auth'**
  String get authShort;

  /// User-facing label or message for remote desktop fit to window.
  ///
  /// In en, this message translates to:
  /// **'Fit to window'**
  String get remoteDesktopFitToWindow;

  /// User-facing label or message for remote desktop actual size.
  ///
  /// In en, this message translates to:
  /// **'Actual size'**
  String get remoteDesktopActualSize;

  /// User-facing label or message for remote desktop zoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get remoteDesktopZoom;

  /// User-facing label or message for remote desktop view only.
  ///
  /// In en, this message translates to:
  /// **'View only'**
  String get remoteDesktopViewOnly;

  /// User-facing label or message for remote desktop disable view only.
  ///
  /// In en, this message translates to:
  /// **'Disable view only'**
  String get remoteDesktopDisableViewOnly;

  /// User-facing label or message for remote desktop send clipboard text.
  ///
  /// In en, this message translates to:
  /// **'Send clipboard text'**
  String get remoteDesktopSendClipboardText;

  /// User-facing label or message for remote desktop show keyboard.
  ///
  /// In en, this message translates to:
  /// **'Show keyboard'**
  String get remoteDesktopShowKeyboard;

  /// User-facing label or message for remote desktop more controls.
  ///
  /// In en, this message translates to:
  /// **'More controls'**
  String get remoteDesktopMoreControls;

  /// User-facing label or message for remote desktop use direct pointer.
  ///
  /// In en, this message translates to:
  /// **'Use direct pointer'**
  String get remoteDesktopUseDirectPointer;

  /// User-facing label or message for remote desktop use touchpad pointer.
  ///
  /// In en, this message translates to:
  /// **'Use touchpad pointer'**
  String get remoteDesktopUseTouchpadPointer;

  /// User-facing label or message for remote desktop send ctrl alt delete.
  ///
  /// In en, this message translates to:
  /// **'Send Ctrl+Alt+Delete'**
  String get remoteDesktopSendCtrlAltDelete;

  /// User-facing label or message for remote desktop reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get remoteDesktopReconnect;

  /// User-facing label or message for remote desktop full screen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get remoteDesktopFullScreen;

  /// User-facing label or message for remote desktop close session.
  ///
  /// In en, this message translates to:
  /// **'Close session'**
  String get remoteDesktopCloseSession;

  /// User-facing label or message for remote desktop connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get remoteDesktopConnected;

  /// Status message shown while remote desktop connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get remoteDesktopConnecting;

  /// User-facing label or message for remote desktop reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get remoteDesktopReconnecting;

  /// User-facing label or message for remote desktop disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get remoteDesktopDisconnected;

  /// User-facing label or message for remote desktop guide touch.
  ///
  /// In en, this message translates to:
  /// **'Touchpad'**
  String get remoteDesktopGuideTouch;

  /// Help text for the remote desktop guide touch setting or action.
  ///
  /// In en, this message translates to:
  /// **'One finger moves the pointer like a touchpad, and a tap clicks. Tap with two fingers to right-click, drag with two to scroll, and pinch to zoom. Tap twice and keep the finger down to drag.'**
  String get remoteDesktopGuideTouchTip;

  /// Help text for the remote desktop guide keyboard setting or action.
  ///
  /// In en, this message translates to:
  /// **'Opens the on-screen keyboard. What you type is sent to the remote desktop.'**
  String get remoteDesktopGuideKeyboardTip;

  /// Help text for the remote desktop guide view only setting or action.
  ///
  /// In en, this message translates to:
  /// **'Stops sending the pointer and keys, so you can look without clicking anything by accident.'**
  String get remoteDesktopGuideViewOnlyTip;

  /// Help text for the remote desktop guide more setting or action.
  ///
  /// In en, this message translates to:
  /// **'Ctrl+Alt+Delete, reconnecting and full screen are in here.'**
  String get remoteDesktopGuideMoreTip;

  /// Help text for the remote desktop guide pointer setting or action.
  ///
  /// In en, this message translates to:
  /// **'So is a direct pointer, where a finger clicks what it touches.'**
  String get remoteDesktopGuidePointerTip;

  /// User-facing label or message for remote desktop VNC clipboard latin 1 only.
  ///
  /// In en, this message translates to:
  /// **'VNC clipboard supports Latin-1 text only.'**
  String get remoteDesktopVncClipboardLatin1Only;

  /// No description provided for @remoteDesktopAddProfile.
  ///
  /// In en, this message translates to:
  /// **'Add profile'**
  String get remoteDesktopAddProfile;

  /// No description provided for @remoteDesktopNoProfiles.
  ///
  /// In en, this message translates to:
  /// **'No remote desktop profiles'**
  String get remoteDesktopNoProfiles;

  /// No description provided for @remoteDesktopAdd.
  ///
  /// In en, this message translates to:
  /// **'Add remote desktop'**
  String get remoteDesktopAdd;

  /// No description provided for @remoteDesktopEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit remote desktop'**
  String get remoteDesktopEdit;

  /// No description provided for @remoteDesktopTargetTip.
  ///
  /// In en, this message translates to:
  /// **'The target is resolved from the SSH server or monitor agent. Localhost refers to that machine.'**
  String get remoteDesktopTargetTip;

  /// No description provided for @remoteDesktopDomain.
  ///
  /// In en, this message translates to:
  /// **'Domain (optional)'**
  String get remoteDesktopDomain;

  /// No description provided for @remoteDesktopPassword.
  ///
  /// In en, this message translates to:
  /// **'Password (optional)'**
  String get remoteDesktopPassword;

  /// No description provided for @remoteDesktopSavePassword.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get remoteDesktopSavePassword;

  /// No description provided for @remoteDesktopSavePasswordTip.
  ///
  /// In en, this message translates to:
  /// **'Stored in the encrypted database. Backups include saved passwords, and are encrypted only when a backup password is set.'**
  String get remoteDesktopSavePasswordTip;

  /// No description provided for @remoteDesktopShareSession.
  ///
  /// In en, this message translates to:
  /// **'Share session'**
  String get remoteDesktopShareSession;

  /// No description provided for @remoteDesktopProtocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get remoteDesktopProtocol;

  /// No description provided for @remoteDesktopUniqueName.
  ///
  /// In en, this message translates to:
  /// **'Profile names must be unique for this server.'**
  String get remoteDesktopUniqueName;

  /// No description provided for @remoteDesktopVncPasswordLength.
  ///
  /// In en, this message translates to:
  /// **'Classic VNC passwords are limited to 8 ASCII bytes.'**
  String get remoteDesktopVncPasswordLength;

  /// No description provided for @remoteDesktopNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a profile name.'**
  String get remoteDesktopNameRequired;

  /// No description provided for @remoteDesktopHostRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a target host.'**
  String get remoteDesktopHostRequired;

  /// No description provided for @remoteDesktopPortRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid port.'**
  String get remoteDesktopPortRequired;

  /// No description provided for @remoteDesktopUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the RDP username.'**
  String get remoteDesktopUsernameRequired;

  /// No description provided for @remoteDesktopVncPasswordAscii.
  ///
  /// In en, this message translates to:
  /// **'Classic VNC passwords must contain ASCII characters only.'**
  String get remoteDesktopVncPasswordAscii;

  /// No description provided for @remoteDesktopCertificateRequired.
  ///
  /// In en, this message translates to:
  /// **'Certificate confirmation required'**
  String get remoteDesktopCertificateRequired;

  /// No description provided for @remoteDesktopWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for desktop…'**
  String get remoteDesktopWaiting;

  /// No description provided for @remoteDesktopCertificateChanged.
  ///
  /// In en, this message translates to:
  /// **'Remote desktop certificate changed'**
  String get remoteDesktopCertificateChanged;

  /// No description provided for @remoteDesktopTrustCertificate.
  ///
  /// In en, this message translates to:
  /// **'Trust certificate?'**
  String get remoteDesktopTrustCertificate;

  /// No description provided for @remoteDesktopCertificateChangedTip.
  ///
  /// In en, this message translates to:
  /// **'The certificate fingerprint no longer matches the saved value. Verify the new fingerprint before replacing trust.'**
  String get remoteDesktopCertificateChangedTip;

  /// No description provided for @remoteDesktopCertificateUnverifiedTip.
  ///
  /// In en, this message translates to:
  /// **'The system could not verify this certificate. Verify its SHA-256 fingerprint before continuing.'**
  String get remoteDesktopCertificateUnverifiedTip;

  /// No description provided for @remoteDesktopReplaceTrust.
  ///
  /// In en, this message translates to:
  /// **'Replace trust'**
  String get remoteDesktopReplaceTrust;

  /// No description provided for @remoteDesktopTrustReconnect.
  ///
  /// In en, this message translates to:
  /// **'Trust and reconnect'**
  String get remoteDesktopTrustReconnect;

  /// No description provided for @remoteDesktopDeleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Delete remote desktop profile “{name}”?'**
  String remoteDesktopDeleteProfile(String name);

  /// No description provided for @remoteDesktopReconnectAttempt.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting ({attempt}/3)…'**
  String remoteDesktopReconnectAttempt(int attempt);

  /// No description provided for @remoteDesktopPreviousCertificate.
  ///
  /// In en, this message translates to:
  /// **'Previously trusted\n{fingerprint}'**
  String remoteDesktopPreviousCertificate(String fingerprint);

  /// No description provided for @remoteDesktopCertificateSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject: {subject}'**
  String remoteDesktopCertificateSubject(String subject);

  /// No description provided for @remoteDesktopCertificateIssuer.
  ///
  /// In en, this message translates to:
  /// **'Issuer: {issuer}'**
  String remoteDesktopCertificateIssuer(String issuer);

  /// No description provided for @remoteDesktopCertificateValidity.
  ///
  /// In en, this message translates to:
  /// **'Valid: {start} – {end}'**
  String remoteDesktopCertificateValidity(String start, String end);

  /// User-facing label or message for appearance theme mode locked.
  ///
  /// In en, this message translates to:
  /// **'This theme only supports {mode}. Select another theme to change the mode.'**
  String appearanceThemeModeLocked(String mode);

  /// Label for logging in to Proxmox VE with an API token.
  ///
  /// In en, this message translates to:
  /// **'API token'**
  String get pveAuthToken;

  /// Notice on a Proxmox VE host older than 8.0: the feature was only tested on PVE 8 and later.
  ///
  /// In en, this message translates to:
  /// **'This feature is currently in the testing phase and has only been tested on PVE 8+. Please use it with caution.'**
  String get pveVersionLow;

  /// Label for the Proxmox VE API token ID field (user@realm!tokenid).
  ///
  /// In en, this message translates to:
  /// **'Token ID'**
  String get pveTokenId;

  /// Label for the Proxmox VE API token secret field.
  ///
  /// In en, this message translates to:
  /// **'Token secret'**
  String get pveTokenSecret;

  /// Help text explaining how to create a Proxmox VE API token and which privileges it needs.
  ///
  /// In en, this message translates to:
  /// **'Create one in PVE under Datacenter → Permissions → API Tokens. It needs VM.Audit, VM.PowerMgmt, VM.Console, VM.Snapshot, VM.Snapshot.Rollback, Datastore.Audit and Sys.Audit on the paths to show; with privilege separation on, grant them to the token itself.'**
  String get pveTokenTip;

  /// A PVE API token that may see nothing: explains privilege separation and gives the command that grants it permissions.
  ///
  /// In en, this message translates to:
  /// **'The token {account} may not see anything on this host. A token with privilege separation does not have its user\'s permissions; grant it some, on the PVE host:\n{command}\nor untick \"Privilege Separation\" for the token.'**
  String pveTokenNoPrivileges(String account, String command);

  /// A PVE user that may see nothing: gives the command that grants it permissions.
  ///
  /// In en, this message translates to:
  /// **'{account} may not see anything on this host. Grant it permissions, on the PVE host:\n{command}'**
  String pveUserNoPrivileges(String account, String command);

  /// Error shown when the Proxmox VE API token ID has the wrong format.
  ///
  /// In en, this message translates to:
  /// **'The token ID must look like user@realm!tokenid'**
  String get pveTokenIdInvalid;

  /// Help text for logging in to Proxmox VE with a password.
  ///
  /// In en, this message translates to:
  /// **'Logs in as the SSH user in the PAM realm, with the SSH password, or with the PVE password below when SSH uses a key. A two-factor code is asked for when needed.'**
  String get pvePasswordAuthTip;

  /// Shown when no Proxmox VE certificate has been confirmed yet.
  ///
  /// In en, this message translates to:
  /// **'None confirmed yet. Unless a trusted CA signed it, the next connection shows the certificate for confirmation.'**
  String get pveCertUnpinned;

  /// Action that forgets the confirmed Proxmox VE certificate.
  ///
  /// In en, this message translates to:
  /// **'Forget certificate'**
  String get pveCertForget;

  /// Confirmation text for forgetting the confirmed Proxmox VE certificate.
  ///
  /// In en, this message translates to:
  /// **'The next connection will show the PVE certificate for confirmation again.'**
  String get pveCertForgetTip;

  /// Name of the Virtualization tab.
  ///
  /// In en, this message translates to:
  /// **'Virtualization'**
  String get virtualization;

  /// Intro page text describing the Virtualization tab.
  ///
  /// In en, this message translates to:
  /// **'Manage virtual machines and containers on Proxmox VE and libvirt/KVM hosts: their state, power actions and consoles.'**
  String get virtIntro;

  /// Intro page text telling Proxmox VE users where PVE moved.
  ///
  /// In en, this message translates to:
  /// **'Proxmox VE has moved from the server page into this tab. A server\'s PVE card opens it there.'**
  String get virtIntroPveMoved;

  /// Intro page text about libvirt/KVM hosts.
  ///
  /// In en, this message translates to:
  /// **'A server with libvirt\'s virsh installed shows up as a host, with its QEMU/KVM virtual machines.'**
  String get virtIntroLibvirt;

  /// Intro page text about the transports the Virtualization tab works over.
  ///
  /// In en, this message translates to:
  /// **'Both work over SSH, through a Monitor agent, or on this device.'**
  String get virtIntroTransports;

  /// Intro page text about Proxmox VE API token support.
  ///
  /// In en, this message translates to:
  /// **'PVE can log in with an API token instead of a password. Set it in a server\'s edit page, under PVE.'**
  String get virtIntroTokens;

  /// Intro page text saying the Virtualization tab is in the tab bar.
  ///
  /// In en, this message translates to:
  /// **'It has been added to the tab bar.'**
  String get virtIntroInBar;

  /// Intro page text saying the Virtualization tab is under More.
  ///
  /// In en, this message translates to:
  /// **'It is under More. Home Tabs in Settings can move it to the tab bar.'**
  String get virtIntroInMore;

  /// Section of the Virtualization tab listing virtual machines.
  ///
  /// In en, this message translates to:
  /// **'Virtual machines'**
  String get virtGuests;

  /// Heading over the virtualization hosts in the host switcher.
  ///
  /// In en, this message translates to:
  /// **'Hosts'**
  String get virtHosts;

  /// Heading over servers not known to be virtualization hosts; tapping one checks it for virsh.
  ///
  /// In en, this message translates to:
  /// **'Check this server'**
  String get virtCheckServer;

  /// Action that checks every server for libvirt again.
  ///
  /// In en, this message translates to:
  /// **'Check all servers'**
  String get virtCheckAll;

  /// A server not yet checked for libvirt.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get virtProbeNotChecked;

  /// A server checked for virtualization that has neither Proxmox VE nor virsh.
  ///
  /// In en, this message translates to:
  /// **'Not a host'**
  String get virtProbeAbsent;

  /// A checked server that is itself a container (a guest), e.g. 'LXC container'.
  ///
  /// In en, this message translates to:
  /// **'{kind} container'**
  String virtProbeContainer(String kind);

  /// Tooltip on a checked server that runs in a container.
  ///
  /// In en, this message translates to:
  /// **'This server runs in a container, so it is a guest rather than a host. It is managed from the host that runs it.'**
  String get virtProbeContainerTip;

  /// A checked server that runs Proxmox VE but has no PVE API access configured.
  ///
  /// In en, this message translates to:
  /// **'PVE, not set up'**
  String get virtProbePve;

  /// Dialog body offering to configure PVE API access for a server found running Proxmox VE.
  ///
  /// In en, this message translates to:
  /// **'{version} is running on this server. Fill in its API access in the server\'s settings (an API token is recommended) to manage its virtual machines and containers here.'**
  String virtPveSetupTip(String version);

  /// Shown when no server is a virtualization host.
  ///
  /// In en, this message translates to:
  /// **'No virtualization hosts'**
  String get virtNoHosts;

  /// Explains which servers count as virtualization hosts.
  ///
  /// In en, this message translates to:
  /// **'A server running Proxmox VE, with its API access filled in, is a host, and so is one where virsh answers. The other servers can be checked from the host switcher.'**
  String get virtNoHostsTip;

  /// Shown when a virtualization host has no guests.
  ///
  /// In en, this message translates to:
  /// **'No virtual machines or containers'**
  String get virtNoGuests;

  /// A guest that is paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get virtPaused;

  /// A guest that is starting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get virtStarting;

  /// A guest that is stopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping…'**
  String get virtStopping;

  /// A guest that is rebooting.
  ///
  /// In en, this message translates to:
  /// **'Rebooting…'**
  String get virtRebooting;

  /// A guest that is migrating to another node.
  ///
  /// In en, this message translates to:
  /// **'Migrating…'**
  String get virtMigrating;

  /// A guest held by a running backup.
  ///
  /// In en, this message translates to:
  /// **'Backing up…'**
  String get virtBackingUp;

  /// Power action that resumes a paused guest.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get virtResume;

  /// View of a guest with its readings and facts.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get virtOverview;

  /// View of a guest with its console.
  ///
  /// In en, this message translates to:
  /// **'Console'**
  String get virtConsole;

  /// Shown in a guest's console view when it has neither a text nor a graphical console.
  ///
  /// In en, this message translates to:
  /// **'No console is configured for this guest'**
  String get virtConsoleNone;

  /// Toggle for a guest's graphical (VNC) console, beside the text one.
  ///
  /// In en, this message translates to:
  /// **'Graphical'**
  String get virtConsoleGraphical;

  /// Over a guest's graphical console whose VNC server refused the connection for a password; beside a button to enter it.
  ///
  /// In en, this message translates to:
  /// **'This display asks for a password'**
  String get virtVncPasswordNeeded;

  /// Under the button that opens a libvirt guest's serial console in the terminal.
  ///
  /// In en, this message translates to:
  /// **'Opens the guest\'s serial console with virsh on the host. Disconnect, or Ctrl+], returns to the host\'s shell.'**
  String get virtConsoleSerialTip;

  /// Under a guest's text console: what the connection goes through, e.g. 'via SSH'.
  ///
  /// In en, this message translates to:
  /// **'via {transport}'**
  String virtConsoleVia(String transport);

  /// Under a guest's text console: a serial console prints nothing until it is sent a key, so Enter brings up its prompt.
  ///
  /// In en, this message translates to:
  /// **'No output? Press Enter'**
  String get virtConsoleEnterTip;

  /// Countdown under a silent serial console: Enter will be pressed automatically to make the guest draw its login prompt.
  ///
  /// In en, this message translates to:
  /// **'Pressing Enter in {seconds, plural, =1{1 second} other{{seconds} seconds}} to bring up the prompt'**
  String virtConsoleAutoEnter(int seconds);

  /// Button beside the auto-Enter countdown: press Enter now instead of waiting.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get virtConsoleEnterNow;

  /// Shown for a guest that is not running, in place of its charts.
  ///
  /// In en, this message translates to:
  /// **'Start it to see live CPU, memory, disk and network here.'**
  String get virtOffTip;

  /// Card showing what running guests hold of the host.
  ///
  /// In en, this message translates to:
  /// **'Allocated'**
  String get virtAllocated;

  /// How many guests are running, of how many.
  ///
  /// In en, this message translates to:
  /// **'{running} running · {total} in total'**
  String virtRunningCount(int running, int total);

  /// A PVE template: a guest image that does not run.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get virtTemplate;

  /// A guest that starts with its host.
  ///
  /// In en, this message translates to:
  /// **'Starts with the host'**
  String get virtAutostart;

  /// Error: the virtualization host could not be reached.
  ///
  /// In en, this message translates to:
  /// **'Could not reach this host'**
  String get virtErrUnreachable;

  /// Error: the PVE configuration of a server is incomplete.
  ///
  /// In en, this message translates to:
  /// **'The PVE settings of this server are incomplete'**
  String get virtErrNotConfigured;

  /// What to do about incomplete PVE settings.
  ///
  /// In en, this message translates to:
  /// **'Check the address, and the password or API token, in the server\'s settings.'**
  String get virtErrNotConfiguredTip;

  /// Error: the virtualization host refused the login.
  ///
  /// In en, this message translates to:
  /// **'The host refused the login'**
  String get virtErrAuthFailed;

  /// Error: the PVE certificate has to be confirmed first.
  ///
  /// In en, this message translates to:
  /// **'Confirm the host\'s certificate'**
  String get virtErrCertUnconfirmed;

  /// Error: the PVE certificate is not the one confirmed before.
  ///
  /// In en, this message translates to:
  /// **'The host\'s certificate has changed'**
  String get virtErrCertChanged;

  /// Error: the Monitor agent does not relay TCP connections to PVE.
  ///
  /// In en, this message translates to:
  /// **'The Monitor agent does not relay connections'**
  String get virtErrRelayNotGranted;

  /// Error: the Monitor agent does not run commands (its full access is off), so libvirt cannot be reached through it.
  ///
  /// In en, this message translates to:
  /// **'The Monitor agent does not run commands'**
  String get virtErrExecNotGranted;

  /// Error: virsh is not installed on the server.
  ///
  /// In en, this message translates to:
  /// **'virsh is not installed on this server'**
  String get virtErrNotInstalled;

  /// Error: the server this virtualization host belonged to has been deleted.
  ///
  /// In en, this message translates to:
  /// **'This server no longer exists'**
  String get virtErrServerRemoved;

  /// Error: reaching libvirt needs sudo, and sudo needs a password.
  ///
  /// In en, this message translates to:
  /// **'sudo needs a password to reach libvirt'**
  String get virtErrSudoRequired;

  /// Error: sudo rejected the password given.
  ///
  /// In en, this message translates to:
  /// **'sudo rejected the password'**
  String get virtErrSudoRejected;

  /// Error: the virtualization host answered with something unreadable.
  ///
  /// In en, this message translates to:
  /// **'The host answered in an unexpected form'**
  String get virtErrInvalidResponse;

  /// Error: the host refused a power action or it failed.
  ///
  /// In en, this message translates to:
  /// **'The host refused the action'**
  String get virtErrActionFailed;

  /// Settings row: how long a remote desktop or guest console stays connected after the user leaves it.
  ///
  /// In en, this message translates to:
  /// **'Close when left idle'**
  String get remoteSessionIdleTimeout;

  /// Help text for the remote session idle timeout setting.
  ///
  /// In en, this message translates to:
  /// **'How long a remote desktop or a guest\'s console stays connected after you leave it. Before it closes, a notice gives you 10 seconds to keep it.'**
  String get remoteSessionIdleTimeoutTip;

  /// Button on the notice before an idle remote session closes: keeps it open for another full timeout.
  ///
  /// In en, this message translates to:
  /// **'Keep alive'**
  String get remoteSessionKeepAlive;

  /// Toast title when the app comes back: an idle remote session (remote desktop, guest console) was closed while the app was in the background. The body names the session.
  ///
  /// In en, this message translates to:
  /// **'Closed while you were away'**
  String get remoteSessionClosedAway;

  /// Countdown on the notice before an idle remote session closes.
  ///
  /// In en, this message translates to:
  /// **'Closing in {seconds} s'**
  String remoteSessionClosingIn(int seconds);

  /// Button: show a console that is still running again.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get reopen;

  /// A guest view and its heading: the guest's snapshots.
  ///
  /// In en, this message translates to:
  /// **'Snapshots'**
  String get virtSnapshots;

  /// Button that opens the form for a new snapshot, and the form's confirm button.
  ///
  /// In en, this message translates to:
  /// **'Take a snapshot'**
  String get virtSnapshotCreate;

  /// Shown when a guest has no snapshots.
  ///
  /// In en, this message translates to:
  /// **'No snapshots yet'**
  String get virtSnapshotNone;

  /// What a snapshot holds: the disks and the running memory.
  ///
  /// In en, this message translates to:
  /// **'Disks and memory'**
  String get virtSnapshotWithMemory;

  /// What a snapshot holds: the disks only, no memory.
  ///
  /// In en, this message translates to:
  /// **'Disks only'**
  String get virtSnapshotDiskOnly;

  /// The snapshot another one was taken on top of.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get virtSnapshotParent;

  /// Action: revert the guest to a snapshot.
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get virtSnapshotRevert;

  /// Switch in the snapshot form: also save the guest's memory.
  ///
  /// In en, this message translates to:
  /// **'Include memory'**
  String get virtSnapshotMemory;

  /// Under the memory switch: what saving memory gives.
  ///
  /// In en, this message translates to:
  /// **'Reverting resumes the guest at this moment.'**
  String get virtSnapshotMemoryTip;

  /// Under the memory switch on libvirt: an internal snapshot of a running guest always includes its memory.
  ///
  /// In en, this message translates to:
  /// **'A snapshot of a running guest always includes its memory here.'**
  String get virtSnapshotMemoryAlways;

  /// Snapshot form of a guest that is not running: only disks are saved.
  ///
  /// In en, this message translates to:
  /// **'The guest is not running, so only its disks are saved.'**
  String get virtSnapshotMemoryOff;

  /// Error under the snapshot name field.
  ///
  /// In en, this message translates to:
  /// **'A letter first, then letters, digits, - or _; 2 to 40 characters.'**
  String get virtSnapshotNameInvalid;

  /// Error under the snapshot name field.
  ///
  /// In en, this message translates to:
  /// **'A snapshot with this name exists.'**
  String get virtSnapshotNameTaken;

  /// Note under the snapshot list.
  ///
  /// In en, this message translates to:
  /// **'Reverting discards every change made since the snapshot.'**
  String get virtSnapshotRevertTip;

  /// Revert confirmation.
  ///
  /// In en, this message translates to:
  /// **'Revert {guest} to {snapshot}? Every change since it was taken is lost.'**
  String virtSnapshotRevertAsk(String guest, String snapshot);

  /// Revert confirmation when the snapshot has no memory and the guest is running.
  ///
  /// In en, this message translates to:
  /// **'This snapshot has no memory: {guest} will be stopped.'**
  String virtSnapshotRevertStops(String guest);

  /// Switch in the revert confirmation: start the guest after reverting to a snapshot without memory.
  ///
  /// In en, this message translates to:
  /// **'Start it afterwards'**
  String get virtSnapshotStartAfter;

  /// Heading over the volumes of a storage pool.
  ///
  /// In en, this message translates to:
  /// **'Volumes'**
  String get virtVolumes;

  /// Shown when a host has no storage pools.
  ///
  /// In en, this message translates to:
  /// **'No storage pools'**
  String get virtNoPools;

  /// Shown when a host has no networks.
  ///
  /// In en, this message translates to:
  /// **'No networks'**
  String get virtNoNetworks;

  /// A storage pool that is not active: its volumes cannot be listed.
  ///
  /// In en, this message translates to:
  /// **'The pool is not active, so its volumes cannot be listed.'**
  String get virtPoolInactive;

  /// A PVE storage shared between cluster nodes.
  ///
  /// In en, this message translates to:
  /// **'Shared between nodes'**
  String get virtShared;

  /// The file a qcow2 volume is layered on.
  ///
  /// In en, this message translates to:
  /// **'Backing file'**
  String get virtBackingFile;

  /// libvirt network mode: guests reach each other and the host only.
  ///
  /// In en, this message translates to:
  /// **'Isolated'**
  String get virtNetIsolated;

  /// libvirt network mode: guests are on a host bridge.
  ///
  /// In en, this message translates to:
  /// **'Bridged'**
  String get virtNetBridged;

  /// libvirt network mode: routed without NAT.
  ///
  /// In en, this message translates to:
  /// **'Routed'**
  String get virtNetRouted;

  /// A network's bridge device.
  ///
  /// In en, this message translates to:
  /// **'Bridge'**
  String get virtBridge;

  /// The devices a bridge or bond uses.
  ///
  /// In en, this message translates to:
  /// **'Ports'**
  String get virtPorts;

  /// Heading over the guests with a NIC on a network.
  ///
  /// In en, this message translates to:
  /// **'Guests on it'**
  String get virtAttachedGuests;

  /// No guest has a NIC on this network.
  ///
  /// In en, this message translates to:
  /// **'No guest is on it'**
  String get virtNoAttachedGuests;

  /// Title and action: create a new virtual machine.
  ///
  /// In en, this message translates to:
  /// **'New virtual machine'**
  String get virtCreateVm;

  /// Title: create a new Proxmox VE container.
  ///
  /// In en, this message translates to:
  /// **'New container'**
  String get virtCreateLxc;

  /// Tooltip of the add button on a PVE host, where a VM or a container can be created.
  ///
  /// In en, this message translates to:
  /// **'New virtual machine or container'**
  String get virtCreateGuest;

  /// Segment choosing to create a virtual machine.
  ///
  /// In en, this message translates to:
  /// **'Virtual machine'**
  String get virtKindVm;

  /// Segment choosing to create a container.
  ///
  /// In en, this message translates to:
  /// **'Container'**
  String get virtKindLxc;

  /// Label: a new container's hostname.
  ///
  /// In en, this message translates to:
  /// **'Hostname'**
  String get virtHostname;

  /// Heading: the ISO a new VM boots from.
  ///
  /// In en, this message translates to:
  /// **'Install media'**
  String get virtInstallMedia;

  /// Shown when the host has no ISO images to install from.
  ///
  /// In en, this message translates to:
  /// **'No ISO images on this host'**
  String get virtNoIsos;

  /// Shown when the PVE host has no container templates.
  ///
  /// In en, this message translates to:
  /// **'No container templates on this host. A storage\'s CT Templates in PVE can download one.'**
  String get virtNoTemplates;

  /// Shown when no storage on the host can hold a new disk.
  ///
  /// In en, this message translates to:
  /// **'Nowhere on this host takes a new disk'**
  String get virtNoDiskStorage;

  /// Switch: start the new guest once it is created.
  ///
  /// In en, this message translates to:
  /// **'Start it once created'**
  String get virtStartAfterCreate;

  /// Switch: create an unprivileged container.
  ///
  /// In en, this message translates to:
  /// **'Unprivileged container'**
  String get virtUnprivileged;

  /// Explains what an unprivileged container is.
  ///
  /// In en, this message translates to:
  /// **'Its root is an ordinary user on the host.'**
  String get virtUnprivilegedTip;

  /// Label: SSH public keys for a new container's root.
  ///
  /// In en, this message translates to:
  /// **'SSH public keys'**
  String get virtSshKeys;

  /// Explains a new container needs a root password, SSH keys or both.
  ///
  /// In en, this message translates to:
  /// **'A root password, SSH keys, or both.'**
  String get virtCredentialsTip;

  /// Toast after a guest was created.
  ///
  /// In en, this message translates to:
  /// **'{name} created'**
  String virtCreated(String name);

  /// Toast title when a guest was created but failed to start; the host's error follows.
  ///
  /// In en, this message translates to:
  /// **'{name} was created but did not start'**
  String virtCreatedNotStarted(String name);

  /// Error title: the new guest's name, VMID or disk already exists on the host.
  ///
  /// In en, this message translates to:
  /// **'A guest or disk with this name already exists'**
  String get virtErrExists;

  /// Rule for a new libvirt guest's name.
  ///
  /// In en, this message translates to:
  /// **'Letters, digits, ., _ and -, starting with a letter or digit; up to 63 characters.'**
  String get virtCreateNameInvalidLibvirt;

  /// Rule for a new PVE guest's name (a DNS name).
  ///
  /// In en, this message translates to:
  /// **'Letters, digits and -, in parts separated by dots; up to 63 characters.'**
  String get virtCreateNameInvalidPve;

  /// The new guest's name is already used.
  ///
  /// In en, this message translates to:
  /// **'A guest with this name exists.'**
  String get virtCreateNameTaken;

  /// The VMID is out of PVE's range.
  ///
  /// In en, this message translates to:
  /// **'From 100 to 999999999.'**
  String get virtCreateVmidInvalid;

  /// The VMID is already used.
  ///
  /// In en, this message translates to:
  /// **'This VMID is taken.'**
  String get virtCreateVmidTaken;

  /// More cores than the host allows.
  ///
  /// In en, this message translates to:
  /// **'More cores than this host allows.'**
  String get virtCreateCoresInvalid;

  /// Too little memory for a new guest.
  ///
  /// In en, this message translates to:
  /// **'Not enough memory.'**
  String get virtCreateMemoryInvalid;

  /// No storage chosen for the new disk.
  ///
  /// In en, this message translates to:
  /// **'Choose where its disk goes.'**
  String get virtCreateStorageMissing;

  /// Disk size out of range.
  ///
  /// In en, this message translates to:
  /// **'From 1 GiB to 64 TiB.'**
  String get virtCreateDiskInvalid;

  /// No container template chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose a template.'**
  String get virtCreateTemplateMissing;

  /// A new container needs a root password or an SSH key.
  ///
  /// In en, this message translates to:
  /// **'Set a root password or an SSH key.'**
  String get virtCreateCredentialsMissing;

  /// The container's root password is too short.
  ///
  /// In en, this message translates to:
  /// **'At least {min} characters.'**
  String virtCreatePasswordShort(int min);

  /// The SSH keys field has a line that is not an OpenSSH public key.
  ///
  /// In en, this message translates to:
  /// **'One OpenSSH public key per line.'**
  String get virtCreateSshKeysInvalid;

  /// Delete confirmation for a guest.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? This cannot be undone.'**
  String virtDeleteAsk(String name);

  /// Label of the field where the guest's name is typed to confirm deleting it.
  ///
  /// In en, this message translates to:
  /// **'Type {name} to confirm'**
  String virtDeleteTypeName(String name);

  /// Checkbox: delete the guest's disks as well.
  ///
  /// In en, this message translates to:
  /// **'Delete its disks too'**
  String get virtDeleteDisks;

  /// Install media attached to the guest is not deleted.
  ///
  /// In en, this message translates to:
  /// **'Install media attached to it is kept.'**
  String get virtDeleteDisksTip;

  /// On PVE a guest's disks always go with it.
  ///
  /// In en, this message translates to:
  /// **'Its disks are deleted with it; install media is kept.'**
  String get virtDeleteDisksPve;

  /// A running guest must be stopped before it is deleted; asks to force it off.
  ///
  /// In en, this message translates to:
  /// **'{name} is running. It must be stopped before it can be deleted. Force it off now?'**
  String virtDeleteStopFirst(String name);

  /// Toast after a guest was deleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted'**
  String virtDeleted(String name);

  /// Second part of the PVE API token help: the extra privileges creating and deleting guests needs.
  ///
  /// In en, this message translates to:
  /// **'Creating and deleting guests also needs VM.Allocate, VM.Config.*, Datastore.AllocateSpace and SDN.Use.'**
  String get pveTokenTipCreate;
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
    'az',
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
    case 'az':
      return AppLocalizationsAz();
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
