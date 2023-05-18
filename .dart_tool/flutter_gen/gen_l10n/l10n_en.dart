import 'l10n.dart';

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get about => 'About';

  @override
  String get aboutThanks => 'Thanks to the following people who participated in.';

  @override
  String get addAServer => 'add a server';

  @override
  String get addOne => 'Add one';

  @override
  String get addPrivateKey => 'Add private key';

  @override
  String get alreadyLastDir => 'Already in last directory.';

  @override
  String get appPrimaryColor => 'App primary color';

  @override
  String get attention => 'Attention';

  @override
  String get auto => 'Auto';

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
  String get delete => 'Delete';

  @override
  String get disconnected => 'Disconnected';

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
  String get download => 'Download';

  @override
  String get downloadFinished => 'Download finished';

  @override
  String downloadStatus(Object percent, Object size) {
    return '$percent% of $size';
  }

  @override
  String get edit => 'Edit';

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
  String foundNUpdate(Object count) {
    return 'Found $count update';
  }

  @override
  String get getPushTokenFailed => 'Can\'t fetch push token';

  @override
  String get gettingToken => 'Getting token...';

  @override
  String get goto => 'Go to';

  @override
  String get host => 'Host';

  @override
  String httpFailedWithCode(Object code) {
    return 'request failed, status code: $code';
  }

  @override
  String get image => 'Image';

  @override
  String get imagesList => 'Images list';

  @override
  String get import => 'Import';

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
  String get keepForeground => 'Keep app foreground!';

  @override
  String get keyAuth => 'Key Auth';

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
  String get log => 'Log';

  @override
  String get loss => 'loss';

  @override
  String madeWithLove(Object myGithub) {
    return 'Made with ❤️ by $myGithub';
  }

  @override
  String get max => 'max';

  @override
  String get maxRetryCount => 'Number of server reconnection';

  @override
  String get maxRetryCountEqual0 => 'Will retry again and again.';

  @override
  String get min => 'min';

  @override
  String get ms => 'ms';

  @override
  String get name => 'Name';

  @override
  String get needRestart => 'Need to restart app';

  @override
  String get newContainer => 'New container';

  @override
  String get noClient => 'No client';

  @override
  String get noInterface => 'No interface';

  @override
  String get noResult => 'No result';

  @override
  String get noSavedPrivateKey => 'No saved private keys.';

  @override
  String get noSavedSnippet => 'No saved snippets.';

  @override
  String get noServerAvailable => 'No server available.';

  @override
  String get noUpdateAvailable => 'No update available';

  @override
  String get notSelected => 'Not selected';

  @override
  String get nullToken => 'Null token';

  @override
  String get ok => 'OK';

  @override
  String get onServerDetailPage => 'On server detail page';

  @override
  String get open => 'Open';

  @override
  String get paste => 'Paste';

  @override
  String get path => 'Path';

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
  String get privateKey => 'Private Key';

  @override
  String get pushToken => 'Push token';

  @override
  String get pwd => 'Password';

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
  String restoreSureWithDate(Object date) {
    return 'Are you sure to restore from $date ?';
  }

  @override
  String get result => 'Result';

  @override
  String get run => 'Run';

  @override
  String get save => 'Save';

  @override
  String get second => 's';

  @override
  String get server => 'Server';

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
  String get sftpNoDownloadTask => 'No download task.';

  @override
  String get sftpSSHConnected => 'SFTP Connected';

  @override
  String get showDistLogo => 'Show distribution logo';

  @override
  String get snippet => 'Snippet';

  @override
  String spentTime(Object time) {
    return 'Spent time: $time';
  }

  @override
  String sshTip(Object url) {
    return 'This function is now in the experimental stage.\n\nPlease report bugs on $url or join our development.';
  }

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get success => 'Success';

  @override
  String sureDelete(Object name) {
    return 'Are you sure to delete [$name]?';
  }

  @override
  String get sureDirEmpty => 'Make sure dir is empty.';

  @override
  String get sureNoPwd => 'Are you sure to use no password?';

  @override
  String sureToDeleteServer(Object server) {
    return 'Are you sure to delete server [$server]?';
  }

  @override
  String get termTheme => 'Terminal theme';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get times => 'Times';

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
  String get upsideDown => 'Upside Down';

  @override
  String get urlOrJson => 'URL or JSON';

  @override
  String get user => 'User';

  @override
  String versionHaveUpdate(Object build) {
    return 'Found: v1.0.$build, click to update';
  }

  @override
  String versionUnknownUpdate(Object build) {
    return 'Current: v1.0.$build';
  }

  @override
  String versionUpdated(Object build) {
    return 'Current: v1.0.$build, is up to date';
  }

  @override
  String get viewErr => 'See error';

  @override
  String get waitConnection => 'Please wait for the connection to be established.';

  @override
  String get willTakEeffectImmediately => 'Will take effect immediately';
}
