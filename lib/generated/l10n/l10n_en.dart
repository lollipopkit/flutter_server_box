// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get crashCollect => 'Diagnostic data';

  @override
  String get crashCollectIntro =>
      'ServerBox records what happens while it runs so problems can be fixed. Choose how much information to send.';

  @override
  String get crashCollectNone => 'Nothing';

  @override
  String get crashCollectNoneTip =>
      'Reports remain on this device; after a crash, you can send one manually.';

  @override
  String get crashCollectBasic => 'Basic information';

  @override
  String get crashCollectBasicTip =>
      'Only crash information is included; logs and performance data are not. **This helps us improve the app and fix bugs.**';

  @override
  String get crashCollectFull => 'Full information';

  @override
  String get crashCollectFullTip =>
      'Along with the crash log, performance data and which features are used are included: **they show what is slow, and which features are worth keeping.**';

  @override
  String get crashCollectFooter =>
      'At every level, known server names, addresses and usernames are replaced with placeholders when recorded. You can change the collection level later in Settings.';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get crashUpload => 'Upload crash reports';

  @override
  String get crashUploadTip =>
      'Send crash reports to the developer. Known server names and addresses are replaced with placeholders. Off by default; you can turn it off at any time.';

  @override
  String get crashNoticeBody =>
      'ServerBox exited unexpectedly during its last run. Would you like to view the crash report?';

  @override
  String get crashReportTitle => 'Crash report';

  @override
  String get crashReportHint =>
      'This is the log from the previous run. Known server names and addresses have been replaced with placeholders, but other details may remain. Please read it carefully before submitting.';

  @override
  String get crashReportSubmit => 'Copy & report';

  @override
  String get acceptBeta => 'Accept beta version updates';

  @override
  String get addSystemPrivateKeyTip =>
      'Currently private keys don\'t exist, do you want to add the one that comes with the system (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Added to task list';

  @override
  String get askAi => 'Ask AI';

  @override
  String get askAiAwaitingResponse => 'Waiting for AI response...';

  @override
  String get askAiEndpointTip =>
      'Enter a domain or a full URL. The path is completed from the protocol you pick.';

  @override
  String get askAiProtocolTip => 'Auto tries Responses, then Chat Completions.';

  @override
  String get askAiCommandInserted => 'Command inserted into terminal';

  @override
  String askAiConfigMissing(Object fields) {
    return 'Please configure $fields in Settings.';
  }

  @override
  String get askAiDisclaimer =>
      'AI may be incorrect. Review carefully before applying.';

  @override
  String get askAiInsertTerminal => 'Insert into terminal';

  @override
  String get askAiNoResponse => 'No response';

  @override
  String get askAiAgentWelcome => 'What should we do on this server?';

  @override
  String get askAiAgentPromptHint =>
      'Ask the Agent to inspect or fix something...';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Analyse the selected terminal output and explain what happened';

  @override
  String get askAiTerminalContext => 'Terminal context';

  @override
  String get askAiReviewNeeded => 'Review';

  @override
  String get askAiReviewAction => 'Review proposed command';

  @override
  String get askAiReviewBeforeContinuing =>
      'Review or decline the current suggestion first';

  @override
  String get askAiApproveRun => 'Approve & run';

  @override
  String get askAiDecline => 'Decline';

  @override
  String get askAiActionDeclined => 'The proposed command was declined.';

  @override
  String get askAiInterrupted => 'Agent response was interrupted.';

  @override
  String get askAiRiskReadOnly => 'Read-only';

  @override
  String get askAiRiskCaution => 'Changes system';

  @override
  String get askAiRiskUnvetted => 'Unvetted host';

  @override
  String get askAiRiskDestructive => 'High risk';

  @override
  String get askAiHighRiskConfirmTitle => 'Run high-risk command?';

  @override
  String get askAiHighRiskConfirmBody =>
      'This command may make changes that are hard to undo. Check it carefully.';

  @override
  String get askAiNoCommandOutput => 'Command completed without output.';

  @override
  String get askAiOutputTruncated =>
      'Long output was truncated before it was sent back to the Agent.';

  @override
  String get askAiAutoApproved => 'Auto-approved';

  @override
  String get askAiAutoRunSafeCommands => 'Auto-run read-only commands';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Runs only when both the model and the local check call it read-only';

  @override
  String get askAiSendOnEnter => 'Enter sends';

  @override
  String get askAiSendOnEnterTip =>
      'Enter sends, Shift+Enter for a new line. Off: Enter for a new line, Cmd/Ctrl+Enter sends.';

  @override
  String get askAiApiKeyOptional => 'Leave empty for local or unauthenticated';

  @override
  String get askAiHistory => 'Conversation history';

  @override
  String get askAiNewConversation => 'New conversation';

  @override
  String get askAiNoHistory => 'No saved conversations yet';

  @override
  String get askAiNoHistoryMessages => 'No messages yet';

  @override
  String get askAiUntitledConversation => 'Untitled';

  @override
  String get askAiRenameConversation => 'Rename conversation';

  @override
  String get askAiDeleteConversationTitle => 'Delete this conversation?';

  @override
  String get askAiDeleteConversationTip =>
      'Deletes it from this device. Cannot be undone.';

  @override
  String get askAiClearHistoryTitle => 'Clear this server\'s Agent history?';

  @override
  String get askAiClearHistoryTip =>
      'Every saved Agent conversation for this server will be deleted.';

  @override
  String get askAiRestoredReview =>
      'This command came from history. Review it again';

  @override
  String get agentWelcome => 'What should we do across your servers?';

  @override
  String get agentWelcomeTip =>
      'Have the Agent diagnose a problem or carry out a task';

  @override
  String get agentPromptHint =>
      'Ask the Agent to inspect or operate your servers...';

  @override
  String get agentNoHistory => 'No saved global Agent conversations';

  @override
  String get agentClearHistoryTitle => 'Clear global Agent history?';

  @override
  String get agentClearHistoryTip =>
      'All global Agent conversations will be removed from this device.';

  @override
  String get agentToolShell => 'Shell';

  @override
  String get agentToolReadFile => 'Read file';

  @override
  String get agentToolWriteFile => 'Write file';

  @override
  String get agentToolFailed => 'Tool execution failed.';

  @override
  String agentToolCallsFmt(Object count) {
    return '$count tool calls';
  }

  @override
  String get floatOverTabs => 'Float over other tabs';

  @override
  String get agentToolSshConnect => 'SSH connect';

  @override
  String get agentToolSshDisconnect => 'Disconnect SSH';

  @override
  String get agentSshConnectTitle => 'Connect to a new host';

  @override
  String get agentAuthMethod => 'Authentication';

  @override
  String get agentSshConnectTip =>
      'The Agent wants an SSH connection. Enter the password here';

  @override
  String get agentAdHocSessions => 'Temporary connections';

  @override
  String get agentSaveServerTitle => 'Save as a server';

  @override
  String get agentSaveServerTip =>
      'This host and the password you enter are saved on this device';

  @override
  String get agentMonitorOptional => 'Monitor agent (optional)';

  @override
  String get authFailTip => 'Authentication failed. Check the details';

  @override
  String get autoBackupConflict =>
      'Only one automatic backup can be turned on at the same time.';

  @override
  String get autoConnect => 'Auto connect';

  @override
  String get autoRun => 'Auto run';

  @override
  String get autoUpdateHomeWidget => 'Automatic home widget update';

  @override
  String get availableTabs => 'Available Tabs';

  @override
  String get backupEncrypted => 'Backup is encrypted';

  @override
  String get backupNotEncrypted => 'Backup is not encrypted';

  @override
  String get backupPassword => 'Backup password';

  @override
  String get backupPasswordRemoved => 'Backup password removed';

  @override
  String get backupPasswordSet => 'Backup password set';

  @override
  String get backupPasswordTip =>
      'Set a password to encrypt backup files. Leave empty to disable encryption.';

  @override
  String get backupPasswordWrong => 'Incorrect backup password';

  @override
  String get connectAll => 'Connect all';

  @override
  String get disconnectAll => 'Disconnect all';

  @override
  String get distIcon => 'Distribution marks';

  @override
  String get distIconIntroLegal =>
      'A mark says only what this device read from the remote system, which can be wrong or out of date, and identifies neither a derivative, a rebuild, nor any particular version. Where it cannot be identified, a plain icon is drawn.\n\nEach mark is a trademark of its respective owner and is used only to refer to the system it identifies.';

  @override
  String get distIconTip =>
      'Show a small mark beside each server for the system it appears to be running.';

  @override
  String get distNameMap => 'Name overrides';

  @override
  String get distNameMapTip =>
      'Only for a distribution whose file is named something else where you host the marks. The key is the name this app uses; the value is the name to fetch. Leave it empty unless a mark is missing.';

  @override
  String get logoUrl => 'Logo URL';

  @override
  String get logoUrlTip =>
      'The large image at the top of a server\'s own page, drawn in its own colours.';

  @override
  String get markUrl => 'Mark URL';

  @override
  String get markUrlTip =>
      'The small mark beside a server\'s name in lists. Empty means none is drawn.\n\nNot the same picture as the logo';

  @override
  String get navTabMenuTip =>
      'Long press a tab — or right-click it — to connect or disconnect everything on it at once.';

  @override
  String nTags(Object count) {
    return '$count Tags';
  }

  @override
  String get remoteBackupPasswordRequired =>
      'Remote backups require a non-empty backup password';

  @override
  String get monitorHttpsRequired =>
      'A remote monitor agent needs HTTPS, unless HTTP is allowed for it.';

  @override
  String get monitorAllowInsecureHttp => 'Allow HTTP';

  @override
  String get monitorAllowInsecureHttpTip =>
      'Only on a trusted private network that encrypts the transport itself, such as Tailscale';

  @override
  String monitorHttpTip(String url) {
    return 'Read this server\'s status from a **monitor** agent\'s HTTP API instead of running commands over SSH.\n\nThe agent has to be installed on the server first, and it is what makes trends, the watch app and the home-screen widgets possible.\n\n[Setting up a monitor agent]($url)';
  }

  @override
  String get backupTip =>
      'The exported data can be encrypted with password. \nPlease keep it safe.';

  @override
  String get icloudBackupStatusTitle => 'Backup status';

  @override
  String get icloudBackupStatusLoading => 'Loading iCloud backup status...';

  @override
  String get icloudBackupStatusError => 'Unable to read iCloud backup metadata';

  @override
  String get icloudBackupStatusEmpty => 'No iCloud backup file found yet';

  @override
  String get icloudBackupStateUploading => 'Uploading';

  @override
  String get icloudBackupStateConflict => 'Conflict detected';

  @override
  String get icloudBackupStateUploaded => 'Uploaded';

  @override
  String get icloudBackupStateWaiting => 'Waiting for iCloud';

  @override
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return 'Last backup: $lastModified\nStatus: $remoteState';
  }

  @override
  String get bgRun => 'Run in background';

  @override
  String get bgRunTip =>
      'This switch only means the program will try to run in the background. Whether it can run in the background depends on whether the permission is enabled or not. For AOSP-based Android ROMs, please disable \"Battery Optimization\" in this app. For MIUI / HyperOS, please change the power saving policy to \"Unlimited\".';

  @override
  String get trayKeepRunning => 'Keep running in the tray';

  @override
  String get trayKeepRunningTip =>
      'Closing the window leaves the app in the menu bar or notification area, still watching your servers. Turn this off to have the close button end the app.';

  @override
  String get bgRunNeedsNotification =>
      'Running in the background needs an ongoing notification, and this app has no notification permission. Tap to allow notifications.';

  @override
  String get clearAllStatsContent =>
      'Are you sure you want to clear all server connection statistics? This action cannot be undone.';

  @override
  String get clearAllStatsTitle => 'Clear All Statistics';

  @override
  String clearServerStatsContent(Object serverName) {
    return 'Are you sure you want to clear connection statistics for server \"$serverName\"? This action cannot be undone.';
  }

  @override
  String clearServerStatsTitle(Object serverName) {
    return 'Clear $serverName Statistics';
  }

  @override
  String get clearThisServerStats => 'Clear This Server Statistics';

  @override
  String get compactDatabase => 'Compact Database';

  @override
  String compactDatabaseContent(Object size) {
    return 'Database size: $size\n\nThis will reorganize the database to reduce file size. No data will be deleted.';
  }

  @override
  String get closeAfterSave => 'Save and close';

  @override
  String get collapseUITip =>
      'Whether to collapse long lists present in the UI by default';

  @override
  String get connectionDetails => 'Connection Details';

  @override
  String get connectionStats => 'Connection Statistics';

  @override
  String get connectionStatsDesc =>
      'View server connection success rate and history';

  @override
  String get containerTrySudoTip =>
      'For example: In the app, the user is set to aaa, but Docker is installed under the root user. In this case, you need to enable this option.';

  @override
  String get containerSudoPasswordRequired =>
      'Sudo password is required to access Docker. Please enter your password.';

  @override
  String get containerSudoPasswordIncorrect =>
      'Sudo password is incorrect or not allowed. Please try again.';

  @override
  String get copyPath => 'Copy path';

  @override
  String get cpuViewAsProgressTip =>
      'Display the usage of each CPU in a progress bar style (old style)';

  @override
  String get customCmd => 'Custom commands';

  @override
  String get deleteServers => 'Batch delete servers';

  @override
  String get deleteDirRecursive => 'Delete the folder and everything in it';

  @override
  String get desktopTerminalTip =>
      'Command used to open the terminal emulator when launching SSH sessions.';

  @override
  String get dirEmpty => 'Make sure the folder is empty.';

  @override
  String get discoverSshServers => 'Discover SSH Servers';

  @override
  String get discoveryFailed => 'Discovery failed';

  @override
  String get discoverySettings => 'Discovery Settings';

  @override
  String get distro => 'Distribution';

  @override
  String get diskHealth => 'Disk Health';

  @override
  String get displayCpuIndex => 'Display CPU index';

  @override
  String dl2Local(Object fileName) {
    return 'Download $fileName to local?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'There are no running containers.\nThis could be because:\n- The Docker installation user is not the same as the username configured within the App.\n- The environment variable DOCKER_HOST was not read correctly. You can get it by running `echo \$DOCKER_HOST` in the terminal.';

  @override
  String dockerImagesFmt(Object count) {
    return '$count images';
  }

  @override
  String get dockerProjectOther => 'Other';

  @override
  String get dockerPruneTip => 'Remove unused data to free up disk space';

  @override
  String get dockerStatistics => 'Docker Statistics';

  @override
  String get doubleColumnMode => 'Double column mode';

  @override
  String get doubleColumnTip =>
      'This option only enables the feature, whether it can actually be enabled depends on the width of the device';

  @override
  String get editVirtKeys => 'Virtual keys';

  @override
  String get editorHighlightTip =>
      'The current code highlighting performance is not ideal and can be optionally turned off to improve.';

  @override
  String get enableMdns => 'Enable mDNS';

  @override
  String get enableMdnsDesc => 'Use mDNS/Bonjour to discover SSH services';

  @override
  String get envVars => 'Environment variable';

  @override
  String get extraArgs => 'Extra arguments';

  @override
  String get fallbackSshDest => 'Fallback SSH destination';

  @override
  String get fdroidReleaseTip =>
      'If you downloaded this app from F-Droid, it is recommended to turn off this option.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'File \'$file\' too large $size, max $sizeMax';
  }

  @override
  String get fileDirGone => 'This folder is no longer here';

  @override
  String get fileDirGoneTip => 'It was deleted or renamed';

  @override
  String get fullScreen => 'Full screen';

  @override
  String get fullScreenJitter => 'Full screen jitter';

  @override
  String get fullScreenJitterHelp => 'To avoid screen burn-in';

  @override
  String get fullScreenTip =>
      'Should full-screen mode be enabled when the device is rotated to landscape mode? This option only applies to the server tab.';

  @override
  String get githubGistIdOptional => 'Gist ID (optional)';

  @override
  String get githubGistToken => 'GitHub Gist token';

  @override
  String get githubGistTokenEmpty => 'Token is empty';

  @override
  String get goto => 'Go to';

  @override
  String get homeTabs => 'Home Tabs';

  @override
  String get homeTabsCustomizeDesc =>
      'Customize which tabs appear on the home page and their order';

  @override
  String get ignoreCert => 'Ignore certificate';

  @override
  String get image => 'Image';

  @override
  String get macDmgBody =>
      'The App Store requires this app to be sandboxed, and a sandbox cannot open a terminal. The DMG build can.\n\nThe App Store build may stop being updated.';

  @override
  String get macDmgImportDenied =>
      'macOS would not let this read the previous build’s data';

  @override
  String get macDmgImported => 'Imported the previous build’s data';

  @override
  String get macDmgImportFailed => 'Could not read the previous build’s data';

  @override
  String get macDmgTip =>
      'Local terminal and running snippets locally (DMG build)';

  @override
  String get macDmgTitle => 'DMG build';

  @override
  String get showHiddenFiles => 'Show hidden files';

  @override
  String get sshKeyAlgorithm => 'Algorithm';

  @override
  String get sshKeyComment => 'Comment';

  @override
  String get sshKeyGenerate => 'Generate key pair';

  @override
  String get sshKeyGenerating => 'Generating…';

  @override
  String sshKeyLockedFmt(String name) {
    return 'The private key [$name] was not unlocked.';
  }

  @override
  String get sshKeyPassphraseTip =>
      'Optional. A key with a passphrase is stored encrypted, and you are asked for it the first time a connection uses the key.';

  @override
  String get sshKeyPassphraseWrong => 'Wrong passphrase.';

  @override
  String get sshKeyPublicKey => 'Public key';

  @override
  String get sshKeyPublicKeyTip =>
      'Append this line to ~/.ssh/authorized_keys on the server.';

  @override
  String get sshKeyRecommended => 'Recommended';

  @override
  String sshKeyUnlockTip(String name) {
    return 'Enter the passphrase for the private key [$name].';
  }

  @override
  String get ungrouped => 'Ungrouped';

  @override
  String get unused => 'Unused';

  @override
  String get dangling => 'Dangling';

  @override
  String get pruneUnusedImages => 'Prune unused images';

  @override
  String get pruneDanglingImages => 'Prune dangling images';

  @override
  String get pruneImages => 'Prune images';

  @override
  String get unusedTaggedImages => 'Unused tagged';

  @override
  String get pruneDanglingImagesTip => 'Removes dangling images only.';

  @override
  String get pruneUnusedImagesTip =>
      'Also remove tagged images not used by any container.';

  @override
  String get includeUnusedVolumesTip =>
      'Also remove volumes not used by any container.';

  @override
  String get pruneCommandPreview => 'Command preview';

  @override
  String get pruneForceSshTip =>
      '-f skips the interactive prompt and is always enabled for SSH execution.';

  @override
  String get pruneVolumes => 'Prune volumes';

  @override
  String get pruneUnusedData => 'Prune unused data';

  @override
  String get pull => 'Pull';

  @override
  String get invalidHostFormat =>
      'Invalid host format. Only IPv4, IPv6, and domain characters are allowed.';

  @override
  String get jumpServer => 'Jump server';

  @override
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return 'Jump servers not found for $serverName: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(Object name) {
    return '\"$name\" already exists';
  }

  @override
  String get noJumpServerAvailable => 'No jump server available.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Jump server and ProxyCommand cannot be used together.';

  @override
  String get noConnectionMethod => 'Configure SSH, a monitor agent, or both';

  @override
  String get preferredTransport => 'Try first';

  @override
  String get preferredTransportTip =>
      'Where status is read from, and which connection a command opens first. The other stays available.';

  @override
  String get keepForeground => 'Keep app foreground!';

  @override
  String get keepStatusWhenErr => 'Preserve the last server state';

  @override
  String get keepStatusWhenErrTip =>
      'Only in the event of an error during script execution';

  @override
  String get keyAuth => 'Key Auth';

  @override
  String get lastFailure => 'Last Failure';

  @override
  String get lastSuccess => 'Last Success';

  @override
  String get letterCache => 'Normal keyboard input';

  @override
  String get letterCacheTip =>
      'When enabled, input goes through the regular IME, which can avoid secure keyboard prompts in the terminal on some systems.';

  @override
  String get linuxShellTip =>
      'Which shell a terminal starts. Empty restores /bin/sh.';

  @override
  String get linuxNetTip => 'DNS servers. Empty restores the defaults';

  @override
  String madeWithLove(Object myGithub) {
    return 'Made with ❤️ by $myGithub';
  }

  @override
  String get maxConcurrency => 'Max Concurrency';

  @override
  String get maxRetryCount => 'Number of server reconnections';

  @override
  String mismatchSystem(Object system) {
    return 'Mismatch system: $system';
  }

  @override
  String get mirror => 'Mirror';

  @override
  String get needRestart => 'App needs to be restarted';

  @override
  String get netViewType => 'Network view type';

  @override
  String get newContainer => 'New container';

  @override
  String get noConnectionStatsData => 'No connection statistics data';

  @override
  String get noLineChart => 'Do not use line charts';

  @override
  String get noPrivateKeyTip =>
      'The private key does not exist, it may have been deleted or there is a configuration error.';

  @override
  String get noPromptAgain => 'Do not prompt again';

  @override
  String get openLastPath => 'Open the last path';

  @override
  String get openLastPathTip =>
      'Different servers will have different logs, and the log is the path to the exit';

  @override
  String get parseContainerStatsTip =>
      'Parsing the occupancy status of Docker is relatively slow.';

  @override
  String get plugInType => 'Insertion Type';

  @override
  String get preferDiskAmount => 'Prioritize displaying disk capacity';

  @override
  String get privateKey => 'Private Key';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
    return 'Private key [$keyId] not found.';
  }

  @override
  String get bmcPowerOnAction => 'Power on';

  @override
  String get bmcShutdown => 'Shut down';

  @override
  String get bmcForceOff => 'Force off';

  @override
  String get restart => 'Restart';

  @override
  String get bmcPowerCycle => 'Power cycle';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return 'Send this to $server? The service will be asked for \"$resetType\"';
  }

  @override
  String get bmcPowerDone => 'The power state changed';

  @override
  String get bmcPowerAccepted =>
      'Accepted, but the power state has not changed. A graceful operation depends on the OS';

  @override
  String get bmcPowerUnsupported =>
      'This service allows nothing for that action';

  @override
  String get bmcUnauthorized => 'The BMC refused the account';

  @override
  String get bmcAccountMissing => 'No account is set for this BMC';

  @override
  String get bmcPowerOn => 'Powered on';

  @override
  String get bmcPowerOff => 'Powered off';

  @override
  String get bmcCertRejected =>
      'Certificate refused — review it in the server settings';

  @override
  String get bmcNotAService => 'No Redfish service at this address';

  @override
  String get bmcNoSystem => 'The service reports no system';

  @override
  String get bmcSensorsTruncated => 'Only the first sensors are shown';

  @override
  String get bmcMultipleSystems => 'Only the first system is shown';

  @override
  String get bmcTip =>
      'The BMC is a separate computer on the motherboard, reachable when the host OS is not. Configured here, it can report power state and hardware sensors while the server is off or hung. Needs Redfish, which most enterprise hardware from about 2016 on has.';

  @override
  String get bmcCert => 'Certificate';

  @override
  String get bmcCertPinned => 'Reviewed and pinned';

  @override
  String get bmcCertUnreviewed =>
      'Not reviewed yet — tap to see the certificate';

  @override
  String get bmcCertReview =>
      'A self-signed certificate. Compare it before accepting. Only this exact one is trusted afterwards.';

  @override
  String get bmcCertChanged => 'The certificate does not match. Check it.';

  @override
  String get bmcCertExpired => 'Expired.';

  @override
  String bmcCertWas(String fingerprint) {
    return 'Previously accepted: $fingerprint';
  }

  @override
  String get bmcAddrInvalid =>
      'The BMC address must be a URL, e.g. https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      'This build is sandboxed: the command gets an empty home, not yours, so anything reading ~/.ssh fails. The DMG build is not.';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return 'Cannot read the private key file $path: $reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return 'This build cannot read files outside its own container, so the key at $path is unreachable. Import the key in Settings, or use the DMG build.';
  }

  @override
  String get pushToken => 'Push token';

  @override
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand is only supported on desktop platforms.';

  @override
  String get pveIgnoreCertTip =>
      'Not recommended to enable, beware of security risks! If you are using the default certificate from PVE, you need to enable this option.';

  @override
  String get pveServerClientMissing =>
      'The SSH client for this server is not available.';

  @override
  String get pveAddressMissing =>
      'The PVE address is missing. Please configure it in server settings.';

  @override
  String get pvePasswordRequired =>
      'PVE password is required. Please set it in server settings.';

  @override
  String get pveOtpRequired =>
      'Two-factor authentication is enabled on this PVE server. Please enter the OTP code.';

  @override
  String get pveOtpChallengeExpired =>
      'The OTP challenge has expired. Please refresh and try again.';

  @override
  String get pveOtpCodeRequired => 'OTP code is required.';

  @override
  String get pveOtpVerificationFailed =>
      'OTP verification failed. Please try again with a fresh code.';

  @override
  String get pveOtpTitle => 'OTP Verification';

  @override
  String get pveOtpLabel => 'OTP Code';

  @override
  String get pveInvalidResponseBody =>
      'PVE login returned an invalid response body.';

  @override
  String get pveInvalidResponseData =>
      'PVE login response did not contain a valid data payload.';

  @override
  String get pveMissingAuthTicket =>
      'PVE login succeeded but no authentication ticket was returned.';

  @override
  String get pveVersionLow =>
      'This feature is currently in the testing phase and has only been tested on PVE 8+. Please use it with caution.';

  @override
  String get pveLoadingForwarding => 'Establishing SSH tunnel...';

  @override
  String get pveLoadingLogin => 'Authenticating with PVE...';

  @override
  String get pveLoadingData => 'Fetching cluster data...';

  @override
  String get pveLoadingConnect => 'Connecting...';

  @override
  String get pvePassword => 'PVE Password';

  @override
  String get pvePasswordHint =>
      'Required when using key-based SSH authentication';

  @override
  String get read => 'Read';

  @override
  String get recentConnections => 'Recent Connections';

  @override
  String get rememberPwdInMem => 'Remember password in memory';

  @override
  String get rememberPwdInMemTip => 'Used for containers, suspending, etc.';

  @override
  String get remotePath => 'Remote path';

  @override
  String rootfsUpdateTip(
    Object distro,
    Object installed,
    Object latest,
    Object pm,
  ) {
    return '$distro $installed is installed; $latest is available. Updating replaces the whole container: $pm data is lost';
  }

  @override
  String linuxSystemInUse(Object name) {
    return 'Close the terminals on $name before deleting it';
  }

  @override
  String get rootfsSubtitle => 'A Linux userland on this device';

  @override
  String rootfsInstallTip(Object distro, Object version, Object size) {
    return 'Downloads $distro $version (about $size MB) and unpacks it on this device.';
  }

  @override
  String get sameIdServerExist => 'A server with the same ID already exists';

  @override
  String get second => 's';

  @override
  String get serverFilesUnavailableTip =>
      'Needs SSH to this server, or server_box_monitor installed with its file API on.';

  @override
  String get back => 'Back';

  @override
  String get history => 'History';

  @override
  String get homeDir => 'Home';

  @override
  String selected(Object count) {
    return '$count selected';
  }

  @override
  String get sendTo => 'Send to…';

  @override
  String get serverDetailOrder => 'Detail page widget order';

  @override
  String get serverFuncBtns => 'Server function buttons';

  @override
  String get serverOrder => 'Server order';

  @override
  String get serverTabEmpty => 'No servers yet';

  @override
  String get serverTabRequired => 'Server tab cannot be removed';

  @override
  String get shareServerRiskTip =>
      'This QR code holds the server’s connection settings in clear text. Anyone who scans or photographs it can connect.';

  @override
  String get sftpDlPrepare => 'Preparing to connect...';

  @override
  String get sftpEditorTip =>
      'Empty uses the built-in editor. For example `vim` (reading `EDITOR` is suggested).';

  @override
  String get sftpRmrDirSummary => 'Use `rm -r` to delete a folder in SFTP.';

  @override
  String get sftpSSHConnected => 'SFTP Connected';

  @override
  String get sftpShowFoldersFirst => 'Display folders first';

  @override
  String get sftpUnavailableUseScp =>
      'If this host has no SFTP subsystem, as many embedded devices do not, set its file transfer to SCP in the server settings.';

  @override
  String get sshFileTransportTip =>
      'SFTP suits anything current. Choose SCP for an old or embedded host whose SSH server has no SFTP subsystem: it needs the `scp` command and a shell that also has the usual file utilities (`find`, `stat`, `mv`, `chmod`).';

  @override
  String get specifyDev => 'Specify device';

  @override
  String get specifyDevTip =>
      'Network traffic counts every device by default; name one here instead';

  @override
  String get tempIsCelsiusTip =>
      'When enabled, the temperature value will be treated as Celsius instead of millicelsius. Turn on only if the temperature displays incorrectly (e.g., showing 0.1°C instead of 58°C).';

  @override
  String spentTime(Object time) {
    return 'Spent time: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'All servers already exist ($duplicateCount duplicates found)';
  }

  @override
  String get sshConnectionModeTip =>
      'Built-in: use the app\'s terminal. System SSH: launch the system ssh command in an external terminal.';

  @override
  String get sshConnectionModeUseBuiltin => 'Use built-in terminal';

  @override
  String get sshConnectionModeUseSystem => 'Use system SSH';

  @override
  String sshConfigDuplicatesSkipped(Object duplicateCount) {
    return '$duplicateCount duplicates will be skipped';
  }

  @override
  String get sshConfigFound => 'We found SSH configuration on your system.';

  @override
  String sshConfigFoundServers(Object totalCount) {
    return 'Found $totalCount servers';
  }

  @override
  String get sshConfigImport => 'SSH Config Import';

  @override
  String get sshConfigImportPermission =>
      'Would you like to give permission to read ~/.ssh/config and automatically import server settings?';

  @override
  String get sshConfigImportTip =>
      'Prompt to read ~/.ssh/config on first server creation';

  @override
  String sshConfigImported(Object count) {
    return 'Imported $count servers from SSH config';
  }

  @override
  String sshHostKeyChangedDesc(Object serverName) {
    return 'The SSH host key changed for $serverName. Only continue if you trust this server.';
  }

  @override
  String get sshHostKeyType => 'SSH host key type';

  @override
  String get sshKnownHostKeys => 'Known hosts';

  @override
  String get sshKnownHostKeysTip => 'The host keys this app has accepted';

  @override
  String sshHostKeyNewDesc(Object serverName) {
    return 'A new SSH host key was received from $serverName. Review the fingerprint before trusting.';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
    return 'Stored fingerprint: $fingerprint';
  }

  @override
  String get sshVerificationCode => 'Verification code';

  @override
  String get sshConfigManualSelect =>
      'Would you like to select the SSH config file manually?';

  @override
  String get sshConfigNoServers => 'No servers found in SSH config';

  @override
  String get sshConfigPermissionDenied =>
      'Cannot access SSH config file due to macOS permissions.';

  @override
  String sshConfigServersToImport(Object importCount) {
    return '$importCount servers will be imported';
  }

  @override
  String get sshTermHelp =>
      'When the terminal is scrollable, dragging horizontally can select text. Clicking the keyboard button turns the keyboard on/off. The file icon opens the current path SFTP. The clipboard button copies the content when text is selected, and pastes content from the clipboard into the terminal when no text is selected and there is content on the clipboard. The code icon pastes code snippets into the terminal and executes them.';

  @override
  String get sshVirtualKeyAutoOff => 'Auto switching of virtual keys';

  @override
  String get supportFmtArgs =>
      'The following formatting parameters are supported:';

  @override
  String get suspendTip =>
      'The suspend function requires root permission and systemd support.';

  @override
  String switchTo(Object val) {
    return 'Switch to $val';
  }

  @override
  String get syncAppSettings => 'Sync app settings';

  @override
  String get syncAppSettingsTip =>
      'Include theme, layout, editor, terminal and other device preferences in automatic sync.';

  @override
  String get termFontSizeTip =>
      'This setting will affect the terminal size (width and height). You can zoom in on the terminal page to adjust the font size of the current session.';

  @override
  String get textScalerTip =>
      '1.0 => 100% (original size), only works on server page part of the font, not recommended to change.';

  @override
  String get times => 'Times';

  @override
  String get trySudo => 'Try using sudo';

  @override
  String get sudoPromptNotFound => 'No sudo password prompt is active.';

  @override
  String get updateServerStatusInterval => 'Server status update interval';

  @override
  String get useNoPwd => 'No password will be used';

  @override
  String get usePodmanByDefault => 'Use Podman by default';

  @override
  String get used => 'Used';

  @override
  String get view => 'View';

  @override
  String get viewDetails => 'View Details';

  @override
  String get virtKeyHelpClipboard =>
      'Copy to the clipboard if the selected terminal is not empty, otherwise paste the content of the clipboard to the terminal.';

  @override
  String get virtKeyHelpIME => 'Turn on/off the keyboard';

  @override
  String get virtKeyHelpSFTP => 'Open current directory in SFTP.';

  @override
  String get virtKeyHelpSnippet =>
      'Pick a snippet and run it in this terminal.';

  @override
  String get virtKeyHelpTmux => 'Switch between tmux sessions and windows.';

  @override
  String get virtKeyIntroActions => 'Shortcuts';

  @override
  String get virtKeyIntroActionsTip =>
      'These open something instead of typing. Hold one to read what it does.';

  @override
  String get virtKeyIntroCustomizeTip =>
      'Reorder these keys, or hide the ones you never reach for, in the terminal settings.';

  @override
  String get virtKeyIntroModifiers => 'Modifiers';

  @override
  String get virtKeyIntroModifiersTip =>
      'Tap one to arm it, then tap a letter on the keyboard. It stays on for that one key.';

  @override
  String get virtKeyIntroNav => 'Navigation';

  @override
  String get virtKeyIntroNavTip =>
      'These move the cursor. Hold an arrow to repeat it.';

  @override
  String get virtKeyIntroSelect =>
      'Drag sideways over the terminal to select text, whenever it has something to scroll.';

  @override
  String get virtKeyRows => 'Rows shown at once';

  @override
  String get virtKeyRowsTip =>
      'The rest go on a page of their own, swiped sideways.';

  @override
  String get waitConnection =>
      'Please wait for the connection to be established.';

  @override
  String get wakeLock => 'Keep awake';

  @override
  String get watchNotPaired => 'No paired Apple Watch';

  @override
  String get webdavSettingEmpty => 'WebDav setting is empty';

  @override
  String get whenOpenApp => 'When opening the app';

  @override
  String get wolTip =>
      'After configuring WOL (Wake-on-LAN), a WOL request is sent each time the server is connected.';

  @override
  String get write => 'Write';

  @override
  String get writeScriptFailTip =>
      'Writing to the script failed, possibly due to lack of permissions or the directory does not exist.';

  @override
  String get writeScriptTip =>
      'After connecting to the server, a script will be written to `~/.config/server_box` \n | `/tmp/server_box` to monitor the system status. You can review the script content.';

  @override
  String get menuGitHubRepository => 'GitHub Repository';

  @override
  String get podmanDockerEmulationDetected =>
      'Podman Docker emulation detected. Please switch to Podman in settings.';

  @override
  String get betaTip =>
      'This feature is still in beta testing. Functionality is not guaranteed.';

  @override
  String get portForward_startPrompt =>
      'Add a port forward rule to get started';

  @override
  String get portForward_localHost => 'Local Host';

  @override
  String get portForward_localPort => 'Local Port';

  @override
  String get portForward_remoteHost => 'Remote Host';

  @override
  String get portForward_remotePort => 'Remote Port';

  @override
  String portForward_deleteConfirmFmt(Object name) {
    return 'Delete $name?';
  }

  @override
  String get sponsor => 'Sponsor';

  @override
  String get sortByJoinTime => 'By join time';

  @override
  String get serverHistory => 'Server history';

  @override
  String get portForwardBetaTitle => 'Port Forward (Beta)';

  @override
  String get tmuxAutoAttach => 'tmux auto-attach';

  @override
  String get tmuxAuto => 'Auto tmux';

  @override
  String get tmuxAutoTip =>
      'Automatically start or attach tmux when connecting over SSH';

  @override
  String get tmuxSessionSelector => 'Session selector';

  @override
  String get tmuxSessionSelectorTip =>
      'Show the session picker when connecting';

  @override
  String get tmuxDefaultSessionName => 'Default session name';

  @override
  String get tmuxSessionName => 'Session name';

  @override
  String get tmuxExistingSessions => 'Existing sessions';

  @override
  String get tmuxNewSession => 'New session';

  @override
  String get tmuxWindows => 'Windows';

  @override
  String get tmuxNewWindow => 'New window';

  @override
  String get tmuxNoWindowsFound => 'No windows found';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count windows',
      one: '1 window',
    );
    return '$_temp0';
  }

  @override
  String tmuxPaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count panes',
      one: '1 pane',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Attached';

  @override
  String get tmuxActive => 'Active';

  @override
  String tmuxActiveAt(String time) {
    return 'active: $time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return 'attached: $time';
  }

  @override
  String get tmuxSkip => 'Skip';

  @override
  String get tmuxNotAvailable => 'tmux is not available';

  @override
  String containerSegmentsMismatch(int count) {
    return 'Unexpected container response segment count: $count';
  }

  @override
  String get containerOperationInProgress =>
      'Another container operation is already in progress';

  @override
  String processCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count processes',
      one: '1 process',
    );
    return '$_temp0';
  }

  @override
  String get processParseUnsupportedOutput =>
      'The process list format is not supported.';

  @override
  String get processParseInvalidRows =>
      'Some process entries could not be read.';

  @override
  String get processParseInvalidWindowsJson =>
      'The Windows process response could not be read.';

  @override
  String get processParseInvalidWindowsRows =>
      'Some Windows process entries could not be read.';

  @override
  String get processKillTargetChanged =>
      'The process changed or exited. Refresh and try again.';

  @override
  String get watchServers => 'Servers on the watch';

  @override
  String get watchServersTip =>
      'The watch fetches from the monitor on its own, so only servers with one can be picked.';

  @override
  String get watchNoMonitorServer => 'No server has a monitor agent configured';

  @override
  String get legacyStatusGoneTitle => 'Status URLs no longer work';

  @override
  String get legacyStatusGoneBody =>
      'The watch app and home widgets used to read a `/status` address typed by hand. That endpoint is gone: it could only report current values as text, which is why they could never show a chart.\n\nThey now read the monitor agent\'s authenticated API, so they draw trends and stay in step with the app on their own. Configure the server in the app once, and every watch and widget picks it up.';

  @override
  String get services => 'Services';

  @override
  String get status => 'Status';

  @override
  String get enable => 'Enable';

  @override
  String get disable => 'Disable';

  @override
  String get starting => 'Starting';

  @override
  String get stopping => 'Stopping';

  @override
  String get serviceManagerUnsupported => 'Unsupported service manager';

  @override
  String get serviceManagerUnsupportedTip =>
      'This server uses a service manager that ServerBox does not support yet. Supported managers: systemd, procd, and OpenRC.';

  @override
  String serviceManagerFmt(String manager) {
    return 'Managed by $manager';
  }

  @override
  String get serviceListFailed => 'Could not list services';

  @override
  String get serviceDetailsUnavailable =>
      'Some service details are unavailable';

  @override
  String get serviceDetailsUnavailableTip =>
      'The service list is usable, but the manager did not return all status or startup information.';

  @override
  String get serviceEnabled => 'Enabled at startup';

  @override
  String get systemdUserScopeMissing => 'User units are not listed';

  @override
  String get systemdUserScopeMissingTip =>
      'This account has no user session bus on the server, so only system units are shown.';

  @override
  String get serverUnreachable => 'Could not run a command on this server';

  @override
  String get containerNoRuntime => 'No container runtime here';

  @override
  String get containerNoRuntimeTip =>
      'Neither `docker` nor `podman` answered on this machine. If one is installed for another account, turn on \"Try using sudo\" in Settings.';

  @override
  String get containerUnreadable =>
      'The container runtime answered in an unexpected form';

  @override
  String get power => 'Power';

  @override
  String get continueInTerminal => 'Continue in terminal';

  @override
  String get askAiRiskUnknown => 'Unclassified';

  @override
  String get agentLocalExec => 'Run commands on this device';

  @override
  String get agentLocalExecTip =>
      'Lets the Agent work on the machine running ServerBox. Even read-only commands are reviewed';

  @override
  String get agentLocalExecRootfsTip =>
      'Lets the Agent work locally, confined to the Linux container ServerBox installed';

  @override
  String macDmgImportedPartly(String path) {
    return 'Imported the data of the previously installed build. Downloaded files were left where they were, in $path.';
  }

  @override
  String get bmcAccount => 'Account';

  @override
  String get bmcAccountUnset => 'None picked - tap to choose or create one';

  @override
  String bmcAccountShared(int count) {
    return 'Used by $count servers';
  }

  @override
  String get bmcAccounts => 'BMC accounts';

  @override
  String get bmcAccountSharedTip =>
      'Editing this changes what all of them use.';

  @override
  String bmcAccountInUse(int count) {
    return '$count servers use it. They keep their address and lose the account.';
  }

  @override
  String get bmcStaleWrite =>
      'The BMC changed while this was being written. Try again.';

  @override
  String get send => 'Send';

  @override
  String get privacyBlur => 'Background privacy';

  @override
  String get privacyBlurTip => 'Hide app content in the app switcher';

  @override
  String get floatReturnToTab => 'Return to tab';

  @override
  String get termInFloatWindow => 'This terminal is in the floating window';
}
