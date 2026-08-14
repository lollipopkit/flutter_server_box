// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
      'Enter a service base URL or a full Chat Completions or Responses endpoint. ServerBox completes the path for the selected protocol.';

  @override
  String get askAiProtocolTip =>
      'Auto uses Responses for the official OpenAI endpoint and Chat Completions for compatible providers.';

  @override
  String get askAiProtocolChatCompletions => 'Chat Completions';

  @override
  String get askAiProtocolResponses => 'Responses';

  @override
  String get askAiCommandInserted => 'Command inserted into terminal';

  @override
  String askAiConfigMissing(Object fields) {
    return 'Please configure $fields in Settings.';
  }

  @override
  String get askAiConfirmExecute => 'Confirm before executing';

  @override
  String get askAiConversation => 'AI conversation';

  @override
  String get askAiDisclaimer =>
      'AI may be incorrect. Review carefully before applying.';

  @override
  String get askAiFollowUpHint => 'Ask a follow-up...';

  @override
  String get askAiInsertTerminal => 'Insert into terminal';

  @override
  String get askAiNoResponse => 'No response';

  @override
  String get askAiRecommendedCommand => 'AI suggested command';

  @override
  String get askAiSelectedContent => 'Selected content';

  @override
  String get askAiUsageHint =>
      'Diagnose and operate the current SSH server with reviewed actions';

  @override
  String get askAiAgentTitle => 'SSH Agent';

  @override
  String get askAiAgentWelcome => 'What should we do on this server?';

  @override
  String get askAiAgentWelcomeTip =>
      'Ask for a diagnosis or a task. The Agent proposes one command at a time and waits for review before making changes.';

  @override
  String get askAiAgentPromptHint =>
      'Ask the Agent to inspect or fix something...';

  @override
  String get askAiAgentSend => 'Send to Agent';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Analyze the selected terminal content, explain what happened, and propose the safest next step if action is needed.';

  @override
  String get askAiTerminalContext => 'Terminal context';

  @override
  String get askAiReviewNeeded => 'Review';

  @override
  String get askAiReviewAction => 'Review proposed command';

  @override
  String get askAiReviewBeforeContinuing =>
      'Review or decline the proposed command first';

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
      'This command may delete data, stop services, or otherwise be difficult to undo. Review it carefully before running.';

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
      'Only auto-run when both the model and local safety checks classify the command as read-only. Commands that change the system still require review.';

  @override
  String get askAiSendOnEnter => 'Enter sends';

  @override
  String get askAiSendOnEnterTip =>
      'Enter sends the message, Shift+Enter starts a new line. Off swaps them: Enter starts a new line and Cmd/Ctrl+Enter sends.';

  @override
  String get askAiApiKeyOptional =>
      'Optional for local or unauthenticated endpoints';

  @override
  String get askAiHistory => 'Conversation history';

  @override
  String get askAiNewConversation => 'New conversation';

  @override
  String get askAiNoHistory => 'No saved conversations for this server';

  @override
  String get askAiNoHistoryMessages => 'No messages yet';

  @override
  String get askAiUntitledConversation => 'New conversation';

  @override
  String get askAiRenameConversation => 'Rename conversation';

  @override
  String get askAiDeleteConversationTitle => 'Delete this conversation?';

  @override
  String get askAiDeleteConversationTip =>
      'This removes the conversation from this device and cannot be undone.';

  @override
  String get askAiClearHistoryTitle => 'Clear this server\'s Agent history?';

  @override
  String get askAiClearHistoryTip =>
      'All Agent conversations saved for this server will be removed from this device.';

  @override
  String get askAiRestoredReview =>
      'Restored from history. Review it again before running; it will never run automatically.';

  @override
  String get agentTitle => 'Agent';

  @override
  String get agentWelcome => 'What should we do across your servers?';

  @override
  String get agentWelcomeTip =>
      'Ask for a diagnosis or an operational task. The Agent uses live ServerBox state and proposes one reviewed action at a time.';

  @override
  String get agentPromptHint =>
      'Ask the Agent to inspect or operate your servers...';

  @override
  String get agentNoServers => 'No configured servers';

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
  String get agentToolServerBox => 'ServerBox';

  @override
  String get agentToolFailed => 'Tool execution failed.';

  @override
  String agentToolCallsFmt(Object count) {
    return '$count tool calls';
  }

  @override
  String get agentFloat => 'Float over other tabs';

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
      'The Agent wants to open an SSH connection. Type the password here — never into the conversation, where it would be stored and sent to the model.';

  @override
  String get agentAdHocSessions => 'Temporary connections';

  @override
  String get agentSaveServerTitle => 'Save as a server';

  @override
  String get agentSaveServerTip =>
      'This host and the password you entered will be stored on this device.';

  @override
  String get agentMonitorOptional => 'Monitor agent (optional)';

  @override
  String get atLeastOneTab => 'At least one tab must be selected';

  @override
  String get authFailTip =>
      'Authentication failed, please check whether credentials are correct';

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
  String get discoverySummary => 'Discovery Summary';

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
  String dockerStatusRunningAndStoppedFmt(
    Object runningCount,
    Object stoppedCount,
  ) {
    return '$runningCount running, $stoppedCount container stopped.';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count container running.';
  }

  @override
  String get doubleColumnMode => 'Double column mode';

  @override
  String get doubleColumnTip =>
      'This option only enables the feature, whether it can actually be enabled depends on the width of the device';

  @override
  String get editVirtKeys => 'Edit virtual keys';

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
  String get fileDirGoneTip =>
      'It was deleted or renamed. Use the bar below to go back, go home, or jump elsewhere.';

  @override
  String get finishedAt => 'Finished at';

  @override
  String get fullScreen => 'Full screen mode';

  @override
  String get fullScreenJitter => 'Full screen jitter';

  @override
  String get fullScreenJitterHelp => 'To avoid screen burn-in';

  @override
  String get fullScreenTip =>
      'Should full-screen mode be enabled when the device is rotated to landscape mode? This option only applies to the server tab.';

  @override
  String get githubGist => 'GitHub Gist';

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
  String get homeWidgetUrlConfig => 'Config home widget url';

  @override
  String get ignoreCert => 'Ignore certificate';

  @override
  String get image => 'Image';

  @override
  String get imagesList => 'Images list';

  @override
  String get macDmgBody =>
      'The App Store requires this app to be sandboxed, and a sandboxed process cannot open a pseudo-terminal. So the App Store build has no terminal on this Mac and cannot run a snippet or an agent command here. The DMG build is the same app signed without the sandbox, and has both.\n\nThe App Store build still works and still updates. It may stop being updated later.\n\nThe two builds keep their data in different places. The DMG build copies it over on its first launch, so servers, keys and history come along. If that fails it says so, and you can carry a backup file across instead (Backup, in settings).';

  @override
  String get macDmgImportDenied =>
      'macOS did not allow reading the data of the previously installed build. Grant Full Disk Access and reopen the app, or export a backup there and restore it here.';

  @override
  String get macDmgImported =>
      'Imported the data of the previously installed build.';

  @override
  String get macDmgImportFailed =>
      'Could not read the data of the previously installed build. Export a backup there, then restore it here.';

  @override
  String get macDmgTip =>
      'A terminal on this Mac, and running snippets on it, exist only in the DMG build.';

  @override
  String get macDmgTitle => 'DMG build';

  @override
  String get showHiddenFiles => 'Show hidden files';

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
  String get pruneDanglingImagesTip =>
      'Only remove dangling images (untagged layers).';

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
  String get volume => 'Volume';

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
  String get noJumpServerAvailable => 'No jump server available.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Jump server and ProxyCommand cannot be used together.';

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
  String get onlyOneLine => 'Only display as one line (scrollable)';

  @override
  String get openLastPath => 'Open the last path';

  @override
  String get openLastPathTip =>
      'Different servers will have different logs, and the log is the path to the exit';

  @override
  String get parseContainerStatsTip =>
      'Parsing the occupancy status of Docker is relatively slow.';

  @override
  String get fullAccessRefused =>
      'This agent does not allow access without SSH.';

  @override
  String get fullAccessInsecure =>
      'This agent allows access without SSH over TLS or loopback only, and this connection is plain HTTP.';

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
  String get rootfsSubtitle => 'A Linux userland on this device';

  @override
  String rootfsInstallTip(Object version) {
    return 'Download Alpine Linux $version (about 3 MB) and unpack it on this device. It gives this app a shell with a package manager, and can be deleted at any time.';
  }

  @override
  String get sameIdServerExist => 'A server with the same ID already exists';

  @override
  String get second => 's';

  @override
  String get serverFilesUnavailableTip =>
      'Reachable either through this server\'s SSH, or through a monitor agent with its file API switched on.';

  @override
  String get back => 'Back';

  @override
  String get history => 'History';

  @override
  String get homeDir => 'Home';

  @override
  String get sendTo => 'Send to…';

  @override
  String get serverDetailOrder => 'Detail page widget order';

  @override
  String get serverFuncBtns => 'Server function buttons';

  @override
  String get serverOrder => 'Server order';

  @override
  String get serverTabRequired => 'Server tab cannot be removed';

  @override
  String get shareServerRiskTip =>
      'This QR code contains the server\'s connection settings in plain text, passwords included. Anyone who scans or photographs it can connect to this server.';

  @override
  String get sftpDlPrepare => 'Preparing to connect...';

  @override
  String get sftpEditorTip =>
      'If empty, use the built-in file editor of the app. If a value is present, use the remote server’s editor, e.g., `vim` (recommended to automatically detect according to `EDITOR`).';

  @override
  String get sftpRmrDirSummary => 'Use `rm -r` to delete a folder in SFTP.';

  @override
  String get sftpSSHConnected => 'SFTP Connected';

  @override
  String get sftp => 'SFTP';

  @override
  String get sftpShowFoldersFirst => 'Display folders first';

  @override
  String get specifyDev => 'Specify device';

  @override
  String get specifyDevTip =>
      'For example, network traffic statistics are by default for all devices. You can specify a particular device here.';

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
  String get ssh => 'SSH';

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
  String sshHostKeyFingerprintMd5Base64(Object fingerprint) {
    return 'Fingerprint (MD5 base64): $fingerprint';
  }

  @override
  String sshHostKeyFingerprintMd5Hex(Object fingerprint) {
    return 'Fingerprint (MD5 hex): $fingerprint';
  }

  @override
  String get sshHostKeyType => 'SSH host key type';

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
  String get system => 'System';

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
  String get portForwardBeta =>
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
  String get systemd => 'Systemd';

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
      'The watch reads these servers from their monitor agent by itself, so only servers with one configured can be picked.';

  @override
  String get watchNoMonitorServer => 'No server has a monitor agent configured';

  @override
  String get watchLegacyUrls => 'Legacy status URLs';

  @override
  String get accessoryWidgetServer => 'Lock screen widget server';

  @override
  String get systemdMissing => 'No systemd on this server';

  @override
  String get systemdMissingTip =>
      '`systemctl` is not installed here, so there are no units to list.';

  @override
  String initSystemFmt(String init) {
    return 'This machine appears to use $init.';
  }

  @override
  String get systemdListFailed => 'Could not list units';

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
      'Lets the Agent work on the machine ServerBox is running on, not only on servers. Nothing runs here unattended: every command needs review, however read-only it looks. This is where the app\'s data, your keys and your files are.';

  @override
  String macDmgImportedPartly(String path) {
    return 'Imported the data of the previously installed build. Downloaded files were left where they were, in $path.';
  }
}
