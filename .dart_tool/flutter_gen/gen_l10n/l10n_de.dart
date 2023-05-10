import 'l10n.dart';

/// The translations for German (`de`).
class SDe extends S {
  SDe([String locale = 'de']) : super(locale);

  @override
  String get about => 'Über';

  @override
  String get aboutThanks => '\nVielen Dank an die folgenden Personen, die zu dieser App beigetragen haben.';

  @override
  String get addAServer => 'Server hinzufügen';

  @override
  String get addOne => 'Add one';

  @override
  String get addPrivateKey => 'Private key hinzufügen';

  @override
  String get alreadyLastDir => 'Bereits im letzten Verzeichnis.';

  @override
  String get appPrimaryColor => 'Farbschema';

  @override
  String get attention => 'Achtung';

  @override
  String get auto => 'Auto';

  @override
  String get backup => 'Backup';

  @override
  String get backupAndRestore => 'Backup und Wiederherstellung';

  @override
  String get backupTip => 'Das Backup wird nur einfach verschlüsselt.\nBitte bewahre die Datei sicher auf.';

  @override
  String get backupVersionNotMatch => 'Die Backup-Version stimmt nicht überein.';

  @override
  String get bgRun => 'Hintergrundaktualisierung';

  @override
  String get canPullRefresh => 'You can pull to refresh.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get choose => 'Choose';

  @override
  String get chooseFontFile => 'Schriftart auswählen';

  @override
  String get choosePrivateKey => 'Private key auswählen';

  @override
  String get clear => 'Clear';

  @override
  String get clickSee => 'Hier klicken';

  @override
  String get close => 'Schließen';

  @override
  String get cmd => 'Command';

  @override
  String get containerName => 'Container name';

  @override
  String get containerStatus => 'Container status';

  @override
  String get convert => 'Konvertieren';

  @override
  String get copy => 'Kopieren';

  @override
  String get copyPath => 'Pfad kopieren';

  @override
  String get createFile => 'Datei erstellen';

  @override
  String get createFolder => 'Ordner erstellen';

  @override
  String get dark => 'Dunkel';

  @override
  String get debug => 'Debug';

  @override
  String get decode => 'Decode';

  @override
  String get delete => 'Löschen';

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
  String get edit => 'Bearbeiten';

  @override
  String get encode => 'Encode';

  @override
  String get error => 'Fehler';

  @override
  String get exampleName => 'Servername';

  @override
  String get experimentalFeature => 'Experimentelles Feature';

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
  String get files => 'Dateien';

  @override
  String foundNUpdate(Object count) {
    return 'Found $count update';
  }

  @override
  String get getPushTokenFailed => 'Can\'t fetch push token';

  @override
  String get gettingToken => 'Getting token...';

  @override
  String get goto => 'Pfad öffnen';

  @override
  String get host => 'Host';

  @override
  String httpFailedWithCode(Object code) {
    return 'request failed, status code: $code';
  }

  @override
  String get image => 'Bild';

  @override
  String get imagesList => 'Images list';

  @override
  String get import => 'Importieren';

  @override
  String get inputDomainHere => 'Domain eingeben';

  @override
  String get install => 'install';

  @override
  String get installDockerWithUrl => 'Please https://docs.docker.com/engine/install docker first.';

  @override
  String get invalidJson => 'Ungültige JSON';

  @override
  String get invalidVersion => 'Ungültige Version';

  @override
  String invalidVersionHelp(Object url) {
    return 'Please make sure that docker is installed correctly, or that you are using a non-self-compiled version. If you don\'t have the above issues, please submit an issue on $url.';
  }

  @override
  String get isBusy => 'Is busy now';

  @override
  String get keepForeground => 'Keep app foreground!';

  @override
  String get keyAuth => 'Schlüsselauthentifzierung';

  @override
  String get lastTry => 'Letzter Versuch';

  @override
  String get launchPage => 'Startseite';

  @override
  String get license => 'Lizenzen';

  @override
  String get light => 'Hell';

  @override
  String get loadingFiles => 'Lädt Dateien...';

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
  String get noSavedSnippet => 'Keine gespeicherten snippets.';

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
  String get open => 'Öffnen';

  @override
  String get paste => 'Einfügen';

  @override
  String get path => 'Pfad';

  @override
  String get pickFile => 'Datei wählen';

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
  String get pwd => 'Passwort';

  @override
  String get rename => 'Umbenennen';

  @override
  String reportBugsOnGithubIssue(Object url) {
    return 'Please report bugs on $url';
  }

  @override
  String get restart => 'Neustart';

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
  String get save => 'Speichern';

  @override
  String get second => 's';

  @override
  String get server => 'Server';

  @override
  String get serverTabConnecting => 'Verbinden...';

  @override
  String get serverTabEmpty => 'There is no server.\nClick the fab to add one.';

  @override
  String get serverTabFailed => 'Failed';

  @override
  String get serverTabLoading => 'Lädt...';

  @override
  String get serverTabPlzSave => 'Please \'save\' this private key again.';

  @override
  String get serverTabUnkown => 'Unknown state';

  @override
  String get setting => 'Einstellungen';

  @override
  String get sftpDlPrepare => 'Verbindung vorbereiten...';

  @override
  String get sftpNoDownloadTask => 'Keine aktiven Downloads.';

  @override
  String get sftpSSHConnected => 'SFTP Connected';

  @override
  String get showDistLogo => 'Distributionslogo anzeigen';

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
  String get themeMode => 'Thememodus';

  @override
  String get times => 'Times';

  @override
  String get ttl => 'ttl';

  @override
  String get unknown => 'Unbekannt';

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
  String get user => 'Benutzer';

  @override
  String versionHaveUpdate(Object build) {
    return 'Found: v1.0.$build, click to update';
  }

  @override
  String versionUnknownUpdate(Object build) {
    return 'Aktuell: v1.0.$build';
  }

  @override
  String versionUpdated(Object build) {
    return 'Aktuell: v1.0.$build, is up to date';
  }

  @override
  String get waitConnection => 'Bitte warte, bis die Verbindung hergestellt wurde.';

  @override
  String get willTakEeffectImmediately => 'Will take effect immediately';
}
