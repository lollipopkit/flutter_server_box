import 'l10n.dart';

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get about => 'About';

  @override
  String get aboutThanks => 'Thanks to the following people who participated in.';

  @override
  String get add => 'Add';

  @override
  String get addAServer => 'add a server';

  @override
  String get addPrivateKey => 'Add private key';

  @override
  String get addSystemPrivateKeyTip => 'Currently don\'t have any private key, do you add the one that comes with the system (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Added to task list';

  @override
  String get all => 'All';

  @override
  String get alreadyLastDir => 'Already in last directory.';

  @override
  String get alterUrl => 'Alter url';

  @override
  String askContinue(Object msg) {
    return '$msg, continue?';
  }

  @override
  String get attention => 'Attention';

  @override
  String get authRequired => 'Auth required';

  @override
  String get auto => 'Auto';

  @override
  String get autoCheckUpdate => 'Auto check update';

  @override
  String get autoConnect => 'Auto connect';

  @override
  String get autoUpdateHomeWidget => 'Auto update home widget';

  @override
  String get backup => 'Backup';

  @override
  String get backupAndRestore => 'Backup and Restore';

  @override
  String get backupTip => 'The exported data is simply encrypted. \nPlease keep it safe.';

  @override
  String get backupVersionNotMatch => 'Backup version is not match.';

  @override
  String get bgRun => 'Run in backgroud';

  @override
  String get bioAuth => 'Biometric auth';

  @override
  String get canPullRefresh => 'You can pull to refresh.';

  @override
  String get cancel => 'Cancel';

  @override
  String get choose => 'Choose';

  @override
  String get chooseFontFile => 'Choose a font file';

  @override
  String get choosePrivateKey => 'Choose private key';

  @override
  String get clear => 'Clear';

  @override
  String get close => 'Close';

  @override
  String get cmd => 'Command';

  @override
  String get conn => 'Connection';

  @override
  String get connected => 'Connected';

  @override
  String get containerName => 'Container name';

  @override
  String get containerStatus => 'Container status';

  @override
  String get convert => 'Convert';

  @override
  String get copy => 'Copy';

  @override
  String get copyPath => 'Copy path';

  @override
  String get createFile => 'Create file';

  @override
  String get createFolder => 'Create folder';

  @override
  String get dark => 'Dark';

  @override
  String get debug => 'Debug';

  @override
  String get decode => 'Decode';

  @override
  String get decompress => 'Decompress';

  @override
  String get delete => 'Delete';

  @override
  String get deleteScripts => 'Delete server scripts at the same time';

  @override
  String get deleteServers => 'Batch delete servers';

  @override
  String get dirEmpty => 'Make sure dir is empty.';

  @override
  String get disabled => 'Disabled';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get disk => 'Disk';

  @override
  String get diskIgnorePath => 'Ignore path for disk';

  @override
  String get displayName => 'Display name';

  @override
  String dl2Local(Object fileName) {
    return 'Download $fileName to local?';
  }

  @override
  String get dockerEditHost => 'Edit DOCKER_HOST';

  @override
  String get dockerEmptyRunningItems => 'No running container. \nIt may be that the env DOCKER_HOST is not read correctly. You can found it by running `echo \$DOCKER_HOST` in terminal.';

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
  String get download => 'Download';

  @override
  String get edit => 'Edit';

  @override
  String get editVirtKeys => 'Edit virtual keys';

  @override
  String get editor => 'Editor';

  @override
  String get editorHighlightTip => 'The current code highlighting performance is worse and can be optionally turned off to improve.';

  @override
  String get encode => 'Encode';

  @override
  String get error => 'Error';

  @override
  String get exampleName => 'Example name';

  @override
  String get experimentalFeature => 'Experimental feature';

  @override
  String get export => 'Export';

  @override
  String get extraArgs => 'Extra args';

  @override
  String get failed => 'Failed';

  @override
  String get feedback => 'Feedback';

  @override
  String get feedbackOnGithub => 'If you have any questions, please feedback on Github.';

  @override
  String get fieldMustNotEmpty => 'These fields must not be empty.';

  @override
  String fileNotExist(Object file) {
    return '$file not exist';
  }

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'File \'$file\' too large $size, max $sizeMax';
  }

  @override
  String get files => 'Files';

  @override
  String get finished => 'Finished';

  @override
  String get followSystem => 'Follow system';

  @override
  String get font => 'Font';

  @override
  String get fontSize => 'Font size';

  @override
  String foundNUpdate(Object count) {
    return 'Found $count update';
  }

  @override
  String get fullScreen => 'Full screen mode';

  @override
  String get fullScreenJitter => 'Full screen jitter';

  @override
  String get fullScreenJitterHelp => 'To avoid screen burn-in';

  @override
  String get getPushTokenFailed => 'Can\'t fetch push token';

  @override
  String get gettingToken => 'Getting token...';

  @override
  String get goBackQ => 'Go back?';

  @override
  String get goto => 'Go to';

  @override
  String get highlight => 'Code highlight';

  @override
  String get homeWidgetUrlConfig => 'Config home widget url';

  @override
  String get host => 'Host';

  @override
  String httpFailedWithCode(Object code) {
    return 'request failed, status code: $code';
  }

  @override
  String get icloudSynced => 'iCloud wird synchronisiert und einige Einstellungen erfordern möglicherweise einen Neustart der App, um wirksam zu werden.';

  @override
  String get image => 'Image';

  @override
  String get imagesList => 'Images list';

  @override
  String get import => 'Import';

  @override
  String get inner => 'Inner';

  @override
  String get inputDomainHere => 'Input Domain here';

  @override
  String get install => 'install';

  @override
  String get installDockerWithUrl => 'Please https://docs.docker.com/engine/install docker first.';

  @override
  String get invalidJson => 'Invalid JSON';

  @override
  String get invalidVersion => 'Invalid version';

  @override
  String invalidVersionHelp(Object url) {
    return 'Please make sure that docker is installed correctly, or that you are using a non-self-compiled version. If you don\'t have the above issues, please submit an issue on $url.';
  }

  @override
  String get isBusy => 'Is busy now';

  @override
  String get jumpServer => 'Jump server';

  @override
  String get keepForeground => 'Keep app foreground!';

  @override
  String get keyAuth => 'Key Auth';

  @override
  String get keyboardCompatibility => 'Possible to improve input method compatibility';

  @override
  String get keyboardType => 'Keyborad type';

  @override
  String get language => 'Language';

  @override
  String get languageName => 'English';

  @override
  String get lastTry => 'Last try';

  @override
  String get launchPage => 'Launch page';

  @override
  String get license => 'License';

  @override
  String get light => 'Light';

  @override
  String get loadingFiles => 'Loading files...';

  @override
  String get location => 'Location';

  @override
  String get log => 'Log';

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
  String get maxRetryCount => 'Number of server reconnection';

  @override
  String get maxRetryCountEqual0 => 'Will retry again and again.';

  @override
  String get min => 'min';

  @override
  String get mission => 'Mission';

  @override
  String get moveOutServerFuncBtnsHelp => 'On: can be displayed below each card on the Server Tab page. Off: can be displayed at the top of the Server Details page.';

  @override
  String get ms => 'ms';

  @override
  String get name => 'Name';

  @override
  String get needRestart => 'Need to restart app';

  @override
  String get net => 'Net';

  @override
  String get netViewType => 'Net view type';

  @override
  String get newContainer => 'New container';

  @override
  String get noClient => 'No client';

  @override
  String get noInterface => 'No interface';

  @override
  String get noOptions => 'No options';

  @override
  String get noResult => 'No result';

  @override
  String get noSavedPrivateKey => 'No saved private keys.';

  @override
  String get noSavedSnippet => 'No saved snippets.';

  @override
  String get noServerAvailable => 'No server available.';

  @override
  String get noTask => 'No task';

  @override
  String get noUpdateAvailable => 'No update available';

  @override
  String get notSelected => 'Not selected';

  @override
  String get note => 'Note';

  @override
  String get nullToken => 'Null token';

  @override
  String get ok => 'OK';

  @override
  String get onServerDetailPage => 'On server detail page';

  @override
  String get open => 'Open';

  @override
  String get openLastPath => 'Open the last path';

  @override
  String get openLastPathTip => 'Different servers will have different logs, and the log is the path to the exit';

  @override
  String get paste => 'Paste';

  @override
  String get path => 'Path';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$percent% of $size';
  }

  @override
  String get pickFile => 'Pick file';

  @override
  String get pingAvg => 'Avg:';

  @override
  String get pingInputIP => 'Please input a target IP / domain.';

  @override
  String get pingNoServer => 'No server to ping.\nPlease add a server in server tab.';

  @override
  String get pkg => 'Pkg';

  @override
  String get platformNotSupportUpdate => 'Current platform does not support in app update.\nPlease build from source and install it.';

  @override
  String get plzEnterHost => 'Please enter host.';

  @override
  String get plzSelectKey => 'Please select a key.';

  @override
  String get port => 'Port';

  @override
  String get preview => 'Preview';

  @override
  String get primaryColorSeed => 'Primary color seed';

  @override
  String get privateKey => 'Private Key';

  @override
  String get process => 'Process';

  @override
  String get pushToken => 'Push token';

  @override
  String get pwd => 'Password';

  @override
  String get read => 'Read';

  @override
  String get reboot => 'Reboot';

  @override
  String get remotePath => 'Remote path';

  @override
  String get rename => 'Rename';

  @override
  String reportBugsOnGithubIssue(Object url) {
    return 'Please report bugs on $url';
  }

  @override
  String get restart => 'Restart';

  @override
  String get restore => 'Restore';

  @override
  String get restoreSuccess => 'Restore success. Restart app to apply.';

  @override
  String get result => 'Result';

  @override
  String get rotateAngel => 'Rotation angle';

  @override
  String get run => 'Run';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get second => 's';

  @override
  String get sequence => 'Sequence';

  @override
  String get server => 'Server';

  @override
  String get serverDetailOrder => 'Detail page widget order';

  @override
  String get serverFuncBtns => 'Server func buttons';

  @override
  String get serverOrder => 'Server order';

  @override
  String get serverTabConnecting => 'Connecting...';

  @override
  String get serverTabEmpty => 'There is no server.\nClick the fab to add one.';

  @override
  String get serverTabFailed => 'Failed';

  @override
  String get serverTabLoading => 'Loading...';

  @override
  String get serverTabPlzSave => 'Please \'save\' this private key again.';

  @override
  String get serverTabUnkown => 'Unknown state';

  @override
  String get setting => 'Settings';

  @override
  String get sftpDlPrepare => 'Preparing to connect...';

  @override
  String get sftpRmrDirSummary => 'Use `rm -r` to delete a folder in SFTP.';

  @override
  String get sftpSSHConnected => 'SFTP Connected';

  @override
  String get showDistLogo => 'Show distribution logo';

  @override
  String get shutdown => 'Shutdown';

  @override
  String get snippet => 'Snippet';

  @override
  String get speed => 'Speed';

  @override
  String spentTime(Object time) {
    return 'Spent time: $time';
  }

  @override
  String sshTip(Object url) {
    return 'This function is now in the experimental stage.\n\nPlease report bugs on $url or join our development.';
  }

  @override
  String get sshVirtualKeyAutoOff => 'Auto switching of virtual keys';

  @override
  String get start => 'Start';

  @override
  String get stats => 'Stats';

  @override
  String get stop => 'Stop';

  @override
  String get success => 'Success';

  @override
  String get suspend => 'Suspend';

  @override
  String get suspendTip => 'The suspend function requires root privileges and systemd support.';

  @override
  String get syncTip => 'A restart may be required for some changes to take effect.';

  @override
  String get system => 'System';

  @override
  String get tag => 'Tags';

  @override
  String get temperature => 'Temperature';

  @override
  String get terminal => 'Terminal';

  @override
  String get theme => 'Theme';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get times => 'Times';

  @override
  String get traffic => 'Traffic';

  @override
  String get ttl => 'ttl';

  @override
  String get unknown => 'Unknown';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get unkownConvertMode => 'Unknown convert mode';

  @override
  String get update => 'Update';

  @override
  String get updateAll => 'Update all';

  @override
  String get updateIntervalEqual0 => 'You set to 0, will not update automatically.\nCan\'t calculate CPU status.';

  @override
  String get updateServerStatusInterval => 'Server status update interval';

  @override
  String updateTip(Object newest) {
    return 'Update: v1.0.$newest';
  }

  @override
  String updateTipTooLow(Object newest) {
    return 'Current version is too low, please update to v1.0.$newest';
  }

  @override
  String get upload => 'Upload';

  @override
  String get upsideDown => 'Upside Down';

  @override
  String get urlOrJson => 'URL or JSON';

  @override
  String get useNoPwd => 'No password will be used.';

  @override
  String get user => 'User';

  @override
  String versionHaveUpdate(Object build) {
    return 'Found: v1.0.$build, click to update';
  }

  @override
  String versionUnknownUpdate(Object build) {
    return 'Current: v1.0.$build, click to check updates';
  }

  @override
  String versionUpdated(Object build) {
    return 'Current: v1.0.$build, is up to date';
  }

  @override
  String get viewErr => 'See error';

  @override
  String get virtKeyHelpClipboard => 'Copy to the clipboard if terminal selected is not empty, otherwise paste the contents of the clipboard to the terminal.';

  @override
  String get virtKeyHelpSFTP => 'Open current directory in SFTP.';

  @override
  String get waitConnection => 'Please wait for the connection to be established.';

  @override
  String get watchNotPaired => 'No paired Apple Watch';

  @override
  String get whenOpenApp => 'When opening the app';

  @override
  String get willTakEeffectImmediately => 'Will take effect immediately';

  @override
  String get write => 'Write';
}
