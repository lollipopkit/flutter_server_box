import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutThanks => 'Thanks to the following people who participated in.';

  @override
  String get acceptBeta => 'Accept beta version updates';

  @override
  String get addSystemPrivateKeyTip => 'Currently private keys don\'t exist, do you want to add the one that comes with the system (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Added to task list';

  @override
  String get addr => 'Address';

  @override
  String get alreadyLastDir => 'Already in last directory.';

  @override
  String get authFailTip => 'Authentication failed, please check whether credentials are correct';

  @override
  String get autoBackupConflict => 'Only one automatic backup can be turned on at the same time.';

  @override
  String get autoConnect => 'Auto connect';

  @override
  String get autoRun => 'Auto run';

  @override
  String get autoUpdateHomeWidget => 'Automatic home widget update';

  @override
  String get backupTip => 'The exported data is weakly encrypted. \nPlease keep it safe.';

  @override
  String get backupVersionNotMatch => 'Backup version is not match.';

  @override
  String get battery => 'Battery';

  @override
  String get bgRun => 'Run in background';

  @override
  String get bgRunTip => 'This switch only means the program will try to run in the background. Whether it can run in the background depends on whether the permission is enabled or not. For AOSP-based Android ROMs, please disable \"Battery Optimization\" in this app. For MIUI / HyperOS, please change the power saving policy to \"Unlimited\".';

  @override
  String get cmd => 'Command';

  @override
  String get collapseUITip => 'Whether to collapse long lists present in the UI by default';

  @override
  String get conn => 'Connection';

  @override
  String get container => 'Container';

  @override
  String get containerTrySudoTip => 'For example: In the app, the user is set to aaa, but Docker is installed under the root user. In this case, you need to enable this option.';

  @override
  String get convert => 'Convert';

  @override
  String get copyPath => 'Copy path';

  @override
  String get cpuViewAsProgressTip => 'Display the usage of each CPU in a progress bar style (old style)';

  @override
  String get cursorType => 'Cursor type';

  @override
  String get customCmd => 'Custom commands';

  @override
  String get customCmdDocUrl => 'https://github.com/lollipopkit/flutter_server_box/wiki#custom-commands';

  @override
  String get customCmdHint => '\"Command Name\": \"Command\"';

  @override
  String get decode => 'Decode';

  @override
  String get decompress => 'Decompress';

  @override
  String get deleteServers => 'Batch delete servers';

  @override
  String get dirEmpty => 'Make sure the folder is empty.';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get disk => 'Disk';

  @override
  String get diskIgnorePath => 'Ignore path for disk';

  @override
  String get displayCpuIndex => 'Display CPU index';

  @override
  String dl2Local(Object fileName) {
    return 'Download $fileName to local?';
  }

  @override
  String get dockerEmptyRunningItems => 'There are no running containers.\nThis could be because:\n- The Docker installation user is not the same as the username configured within the App.\n- The environment variable DOCKER_HOST was not read correctly. You can get it by running `echo \$DOCKER_HOST` in the terminal.';

  @override
  String dockerImagesFmt(Object count) {
    return '$count images';
  }

  @override
  String get dockerNotInstalled => 'Docker not installed';

  @override
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount) {
    return '$runningCount running, $stoppedCount container stopped.';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count container running.';
  }

  @override
  String get doubleColumnMode => 'Double column mode';

  @override
  String get doubleColumnTip => 'This option only enables the feature, whether it can actually be enabled depends on the width of the device';

  @override
  String get editVirtKeys => 'Edit virtual keys';

  @override
  String get editor => 'Editor';

  @override
  String get editorHighlightTip => 'The current code highlighting performance is not ideal and can be optionally turned off to improve.';

  @override
  String get encode => 'Encode';

  @override
  String get envVars => 'Environment variable';

  @override
  String get experimentalFeature => 'Experimental feature';

  @override
  String get extraArgs => 'Extra arguments';

  @override
  String get fallbackSshDest => 'Fallback SSH destination';

  @override
  String get fdroidReleaseTip => 'If you downloaded this app from F-Droid, it is recommended to turn off this option.';

  @override
  String get fgService => 'Foreground Service';

  @override
  String get fgServiceTip => 'After enabling, some device models may crash. Disabling it may cause some models to be unable to maintain SSH connections in the background. Please allow ServerBox notification permissions, background running, and self-wake-up in system settings.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'File \'$file\' too large $size, max $sizeMax';
  }

  @override
  String get followSystem => 'Follow system';

  @override
  String get font => 'Font';

  @override
  String get fontSize => 'Font size';

  @override
  String get force => 'Force';

  @override
  String get fullScreen => 'Full screen mode';

  @override
  String get fullScreenJitter => 'Full screen jitter';

  @override
  String get fullScreenJitterHelp => 'To avoid screen burn-in';

  @override
  String get fullScreenTip => 'Should full-screen mode be enabled when the device is rotated to landscape mode? This option only applies to the server tab.';

  @override
  String get goBackQ => 'Go back?';

  @override
  String get goto => 'Go to';

  @override
  String get hideTitleBar => 'Hide title bar';

  @override
  String get highlight => 'Code highlighting';

  @override
  String get homeWidgetUrlConfig => 'Config home widget url';

  @override
  String get host => 'Host';

  @override
  String httpFailedWithCode(Object code) {
    return 'request failed, status code: $code';
  }

  @override
  String get ignoreCert => 'Ignore certificate';

  @override
  String get image => 'Image';

  @override
  String get imagesList => 'Images list';

  @override
  String get init => 'Initialize';

  @override
  String get inner => 'Inner';

  @override
  String get install => 'install';

  @override
  String get installDockerWithUrl => 'Please https://docs.docker.com/engine/install docker first.';

  @override
  String get invalid => 'Invalid';

  @override
  String get jumpServer => 'Jump server';

  @override
  String get keepForeground => 'Keep app foreground!';

  @override
  String get keepStatusWhenErr => 'Preserve the last server state';

  @override
  String get keepStatusWhenErrTip => 'Only in the event of an error during script execution';

  @override
  String get keyAuth => 'Key Auth';

  @override
  String get letterCache => 'Letter caching';

  @override
  String get letterCacheTip => 'Recommended to disable, but after disabling, it will be impossible to input CJK characters.';

  @override
  String get license => 'License';

  @override
  String get location => 'Location';

  @override
  String get loss => 'loss';

  @override
  String madeWithLove(Object myGithub) {
    return 'Made with ❤️ by $myGithub';
  }

  @override
  String get manual => 'Manual';

  @override
  String get max => 'max';

  @override
  String get maxRetryCount => 'Number of server reconnections';

  @override
  String get maxRetryCountEqual0 => 'Will retry again and again.';

  @override
  String get min => 'min';

  @override
  String get mission => 'Mission';

  @override
  String get more => 'More';

  @override
  String get moveOutServerFuncBtnsHelp => 'On: can be displayed below each card on the Server Tab page. Off: can be displayed at the top of the Server Details page.';

  @override
  String get ms => 'ms';

  @override
  String get needHomeDir => 'If you are a Synology user, [see here](https://kb.synology.com/DSM/tutorial/user_enable_home_service). Users of other systems need to search for how to create a home directory.';

  @override
  String get needRestart => 'App needs to be restarted';

  @override
  String get net => 'Network';

  @override
  String get netViewType => 'Network view type';

  @override
  String get newContainer => 'New container';

  @override
  String get noLineChart => 'Do not use line charts';

  @override
  String get noLineChartForCpu => 'Do not use line charts for CPU';

  @override
  String get noPrivateKeyTip => 'The private key does not exist, it may have been deleted or there is a configuration error.';

  @override
  String get noPromptAgain => 'Do not prompt again';

  @override
  String get node => 'Node';

  @override
  String get notAvailable => 'Unavailable';

  @override
  String get onServerDetailPage => 'On server detail page';

  @override
  String get onlyOneLine => 'Only display as one line (scrollable)';

  @override
  String get onlyWhenCoreBiggerThan8 => 'Works only when the number of cores is greater than 8';

  @override
  String get openLastPath => 'Open the last path';

  @override
  String get openLastPathTip => 'Different servers will have different logs, and the log is the path to the exit';

  @override
  String get parseContainerStatsTip => 'Parsing the occupancy status of Docker is relatively slow.';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$percent% of $size';
  }

  @override
  String get permission => 'Permissions';

  @override
  String get pingAvg => 'Avg:';

  @override
  String get pingInputIP => 'Please input a target IP / domain.';

  @override
  String get pingNoServer => 'No server to ping.\nPlease add a server in server tab.';

  @override
  String get pkg => 'Pkg';

  @override
  String get plugInType => 'Insertion Type';

  @override
  String get port => 'Port';

  @override
  String get preview => 'Preview';

  @override
  String get privateKey => 'Private Key';

  @override
  String get process => 'Process';

  @override
  String get pushToken => 'Push token';

  @override
  String get pveIgnoreCertTip => 'Not recommended to enable, beware of security risks! If you are using the default certificate from PVE, you need to enable this option.';

  @override
  String get pveLoginFailed => 'Login failed. Unable to authenticate with username/password from server configuration for Linux PAM login.';

  @override
  String get pveVersionLow => 'This feature is currently in the testing phase and has only been tested on PVE 8+. Please use it with caution.';

  @override
  String get pwd => 'Password';

  @override
  String get read => 'Read';

  @override
  String get reboot => 'Reboot';

  @override
  String get rememberPwdInMem => 'Remember password in memory';

  @override
  String get rememberPwdInMemTip => 'Used for containers, suspending, etc.';

  @override
  String get rememberWindowSize => 'Remember window size';

  @override
  String get remotePath => 'Remote path';

  @override
  String get restart => 'Restart';

  @override
  String get result => 'Result';

  @override
  String get rotateAngel => 'Rotation angle';

  @override
  String get route => 'Routing';

  @override
  String get run => 'Run';

  @override
  String get running => 'Running';

  @override
  String get sameIdServerExist => 'A server with the same ID already exists';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get second => 's';

  @override
  String get sensors => 'Sensor';

  @override
  String get sequence => 'Sequence';

  @override
  String get server => 'Server';

  @override
  String get serverDetailOrder => 'Detail page widget order';

  @override
  String get serverFuncBtns => 'Server function buttons';

  @override
  String get serverOrder => 'Server order';

  @override
  String get sftpDlPrepare => 'Preparing to connect...';

  @override
  String get sftpEditorTip => 'If empty, use the built-in file editor of the app. If a value is present, use the remote server’s editor, e.g., `vim` (recommended to automatically detect according to `EDITOR`).';

  @override
  String get sftpRmrDirSummary => 'Use `rm -r` to delete a folder in SFTP.';

  @override
  String get sftpSSHConnected => 'SFTP Connected';

  @override
  String get sftpShowFoldersFirst => 'Display folders first';

  @override
  String get showDistLogo => 'Show distribution logo';

  @override
  String get shutdown => 'Shutdown';

  @override
  String get size => 'Size';

  @override
  String get snippet => 'Snippet';

  @override
  String get softWrap => 'Soft wrap';

  @override
  String get specifyDev => 'Specify device';

  @override
  String get specifyDevTip => 'For example, network traffic statistics are by default for all devices. You can specify a particular device here.';

  @override
  String get speed => 'Speed';

  @override
  String spentTime(Object time) {
    return 'Spent time: $time';
  }

  @override
  String get sshTermHelp => 'When the terminal is scrollable, dragging horizontally can select text. Clicking the keyboard button turns the keyboard on/off. The file icon opens the current path SFTP. The clipboard button copies the content when text is selected, and pastes content from the clipboard into the terminal when no text is selected and there is content on the clipboard. The code icon pastes code snippets into the terminal and executes them.';

  @override
  String sshTip(Object url) {
    return 'This function is now in the experimental stage.\n\nPlease report bugs on $url or join our development.';
  }

  @override
  String get sshVirtualKeyAutoOff => 'Auto switching of virtual keys';

  @override
  String get start => 'Start';

  @override
  String get stat => 'Statistics';

  @override
  String get stats => 'Statistics';

  @override
  String get stop => 'Stop';

  @override
  String get stopped => 'Stopped';

  @override
  String get storage => 'Storage';

  @override
  String get supportFmtArgs => 'The following formatting parameters are supported:';

  @override
  String get suspend => 'Suspend';

  @override
  String get suspendTip => 'The suspend function requires root permission and systemd support.';

  @override
  String switchTo(Object val) {
    return 'Switch to $val';
  }

  @override
  String get sync => 'Sync';

  @override
  String get syncTip => 'A restart may be required for some changes to take effect.';

  @override
  String get system => 'System';

  @override
  String get tag => 'Tags';

  @override
  String get temperature => 'Temperature';

  @override
  String get termFontSizeTip => 'This setting will affect the terminal size (width and height). You can zoom in on the terminal page to adjust the font size of the current session.';

  @override
  String get terminal => 'Terminal';

  @override
  String get test => 'Test';

  @override
  String get textScaler => 'Text scaler';

  @override
  String get textScalerTip => '1.0 => 100% (original size), only works on server page part of the font, not recommended to change.';

  @override
  String get theme => 'Theme';

  @override
  String get time => 'Time';

  @override
  String get times => 'Times';

  @override
  String get total => 'Total';

  @override
  String get traffic => 'Traffic';

  @override
  String get trySudo => 'Try using sudo';

  @override
  String get ttl => 'TTL';

  @override
  String get unknown => 'Unknown';

  @override
  String get unkownConvertMode => 'Unknown conversion mode';

  @override
  String get update => 'Update';

  @override
  String get updateIntervalEqual0 => 'You set to 0, will not update automatically.\nCan\'t calculate CPU status.';

  @override
  String get updateServerStatusInterval => 'Server status update interval';

  @override
  String get upload => 'Upload';

  @override
  String get upsideDown => 'Upside Down';

  @override
  String get uptime => 'Uptime';

  @override
  String get useCdn => 'Using CDN';

  @override
  String get useCdnTip => 'Non-Chinese users are recommended to use CDN. Would you like to use it?';

  @override
  String get useNoPwd => 'No password will be used';

  @override
  String get usePodmanByDefault => 'Use Podman by default';

  @override
  String get used => 'Used';

  @override
  String get view => 'View';

  @override
  String get viewErr => 'See error';

  @override
  String get virtKeyHelpClipboard => 'Copy to the clipboard if the selected terminal is not empty, otherwise paste the content of the clipboard to the terminal.';

  @override
  String get virtKeyHelpIME => 'Turn on/off the keyboard';

  @override
  String get virtKeyHelpSFTP => 'Open current directory in SFTP.';

  @override
  String get waitConnection => 'Please wait for the connection to be established.';

  @override
  String get wakeLock => 'Keep awake';

  @override
  String get watchNotPaired => 'No paired Apple Watch';

  @override
  String get webdavSettingEmpty => 'WebDav setting is empty';

  @override
  String get whenOpenApp => 'When opening the app';

  @override
  String get wolTip => 'After configuring WOL (Wake-on-LAN), a WOL request is sent each time the server is connected.';

  @override
  String get write => 'Write';

  @override
  String get writeScriptFailTip => 'Writing to the script failed, possibly due to lack of permissions or the directory does not exist.';

  @override
  String get writeScriptTip => 'After connecting to the server, a script will be written to ~/.config/server_box to monitor the system status. You can review the script content.';
}
