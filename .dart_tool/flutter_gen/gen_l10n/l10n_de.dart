import 'l10n.dart';

/// The translations for German (`de`).
class SDe extends S {
  SDe([String locale = 'de']) : super(locale);

  @override
  String get about => 'Über';

  @override
  String get aboutThanks => 'Vielen Dank an die folgenden Personen, die daran teilgenommen haben.\n';

  @override
  String get add => 'Neu';

  @override
  String get addAServer => 'Server hinzufügen';

  @override
  String get addPrivateKey => 'Private key hinzufügen';

  @override
  String get addSystemPrivateKeyTip => 'Derzeit haben Sie keinen privaten Schlüssel, fügen Sie den Schlüssel hinzu, der mit dem System geliefert wird (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Zur Aufgabenliste hinzugefügt';

  @override
  String get all => 'Alle';

  @override
  String get alreadyLastDir => 'Bereits im letzten Verzeichnis.';

  @override
  String get alterUrl => 'Url ändern';

  @override
  String askContinue(Object msg) {
    return '$msg, weiter?';
  }

  @override
  String get attention => 'Achtung';

  @override
  String get authRequired => 'Autorisierung erforderlich';

  @override
  String get auto => 'System folgen';

  @override
  String get autoCheckUpdate => 'Aktualisierung automatisch prüfen';

  @override
  String get autoConnect => 'Automatisch verbinden';

  @override
  String get autoUpdateHomeWidget => 'Home-Widget automatisch aktualisieren';

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
  String get bioAuth => 'Biozertifizierung';

  @override
  String get canPullRefresh => 'Danach: herunterziehen zum Aktualisieren';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get choose => 'Auswählen';

  @override
  String get chooseFontFile => 'Schriftart auswählen';

  @override
  String get choosePrivateKey => 'Private key auswählen';

  @override
  String get clear => 'Entfernen';

  @override
  String get close => 'Schließen';

  @override
  String get cmd => 'Command';

  @override
  String get conn => 'Verbindung';

  @override
  String get connected => 'in Verbindung gebracht';

  @override
  String get containerName => 'Container Name';

  @override
  String get containerStatus => 'Container Status';

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
  String get decompress => 'Dekomprimieren';

  @override
  String get delete => 'Löschen';

  @override
  String get deleteScripts => 'Gleichzeitiges Löschen von Server-Skripten';

  @override
  String get deleteServers => 'Batch-Löschung von Servern';

  @override
  String get dirEmpty => 'Stelle sicher, dass der Ordner leer ist.';

  @override
  String get disabled => 'Behinderte';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get disk => 'Festplatte';

  @override
  String get diskIgnorePath => 'Pfad für Datenträger ignorieren';

  @override
  String get displayName => 'Name anzeigen';

  @override
  String dl2Local(Object fileName) {
    return 'Datei \"$fileName\" herunterladen?';
  }

  @override
  String get dockerEditHost => 'DOCKER_HOST bearbeiten';

  @override
  String get dockerEmptyRunningItems => 'Keine aktiven Container.\n\nWomöglich wird die Umgebungsvariable DOCKER_HOST nicht richtig erkannt. Du kannst sie finden, indem du `echo \$DOCKER_HOST` im Terminal ausführst.';

  @override
  String dockerImagesFmt(Object count) {
    return '$count Image(s)';
  }

  @override
  String get dockerNotInstalled => 'Docker ist nicht installiert';

  @override
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount) {
    return '$runningCount aktiv, $stoppedCount container gestoppt.';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count Container aktiv';
  }

  @override
  String get doubleColumnMode => 'Doppelspaltiger Modus';

  @override
  String get download => 'Download';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get editVirtKeys => 'Virtuelle Tasten bearbeiten';

  @override
  String get editor => 'Editor';

  @override
  String get editorHighlightTip => 'Die Leistung der aktuellen Codehervorhebung ist schlechter und kann zur Verbesserung optional ausgeschaltet werden.';

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
  String get feedbackOnGithub => 'Wenn du Fragen hast, stelle diese bitte auf Github.';

  @override
  String get fieldMustNotEmpty => 'Die Eingabefelder dürfen nicht leer sein.';

  @override
  String fileNotExist(Object file) {
    return '$file existiert nicht';
  }

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'Datei \'$file\' ist zu groß $size, max $sizeMax';
  }

  @override
  String get files => 'Dateien';

  @override
  String get finished => 'fertiggestellt';

  @override
  String get followSystem => 'System verfolgen';

  @override
  String get font => 'Schriftarten';

  @override
  String get fontSize => 'Schriftgröße';

  @override
  String foundNUpdate(Object count) {
    return 'Update $count gefunden';
  }

  @override
  String get fullScreen => 'Vollbildmodus';

  @override
  String get fullScreenJitter => 'Jitter im Vollbildmodus';

  @override
  String get fullScreenJitterHelp => 'Einbrennen des Bildschirms verhindern';

  @override
  String get getPushTokenFailed => 'Push-Token kann nicht abgerufen werden';

  @override
  String get gettingToken => 'Getting token...';

  @override
  String get goBackQ => 'Zurückkommen?';

  @override
  String get goto => 'Pfad öffnen';

  @override
  String get highlight => 'Code highlight';

  @override
  String get homeWidgetUrlConfig => 'Home-Widget-Link konfigurieren';

  @override
  String get host => 'Host';

  @override
  String httpFailedWithCode(Object code) {
    return 'Anfrage fehlgeschlagen, Statuscode: $code';
  }

  @override
  String get icloudSynced => 'iCloud wird synchronisiert und einige Einstellungen erfordern möglicherweise einen Neustart der App, um wirksam zu werden.';

  @override
  String get image => 'Image';

  @override
  String get imagesList => 'Images';

  @override
  String get import => 'Importieren';

  @override
  String get inner => 'Eingebaut';

  @override
  String get inputDomainHere => 'Domain eingeben';

  @override
  String get install => 'install';

  @override
  String get installDockerWithUrl => 'Bitte installiere docker zuerst. https://docs.docker.com/engine/install';

  @override
  String get invalidJson => 'Ungültige JSON';

  @override
  String get invalidVersion => 'Ungültige Version';

  @override
  String invalidVersionHelp(Object url) {
    return 'Bitte stelle sicher, dass Docker korrekt installiert ist oder dass du eine nicht selbstkompilierte Version verwendest. Wenn du die oben genannten Probleme nicht hast, melde bitte einen Fehler auf $url.';
  }

  @override
  String get isBusy => 'Is busy now';

  @override
  String get jumpServer => 'Server springen';

  @override
  String get keepForeground => 'Stelle sicher, dass die App geöffnet bleibt.';

  @override
  String get keyAuth => 'Schlüsselauthentifzierung';

  @override
  String get keyboardCompatibility => 'Mögliche Verbesserungen bei der Kompatibilität der Eingabemethoden';

  @override
  String get keyboardType => 'Tastatur Typ';

  @override
  String get language => 'Sprache';

  @override
  String get languageName => 'Deutsch';

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
  String get location => 'Standort';

  @override
  String get log => 'Log';

  @override
  String get loss => 'loss';

  @override
  String madeWithLove(Object myGithub) {
    return 'Erstellt mit ❤️ von $myGithub';
  }

  @override
  String get manual => 'Handbuch';

  @override
  String get max => 'max';

  @override
  String get maxRetryCount => 'Anzahl an Verbindungsversuchen';

  @override
  String get maxRetryCountEqual0 => 'Unbegrenzte Verbindungsversuche zum Server';

  @override
  String get min => 'min';

  @override
  String get mission => 'Mission';

  @override
  String get moveOutServerFuncBtnsHelp => 'Ein: kann unter jeder Karte auf der Registerkarte \"Server\" angezeigt werden. Aus: kann oben auf der Seite \"Serverdetails\" angezeigt werden.';

  @override
  String get ms => 'ms';

  @override
  String get name => 'Name';

  @override
  String get needRestart => 'App muss neugestartet werden';

  @override
  String get net => 'Netz';

  @override
  String get netViewType => 'Netzwerkansicht Typ';

  @override
  String get newContainer => 'Neuer Container';

  @override
  String get noClient => 'Kein Client';

  @override
  String get noInterface => 'Kein Interface';

  @override
  String get noOptions => 'Keine Optionen verfügbar';

  @override
  String get noResult => 'Kein Ergebnis';

  @override
  String get noSavedPrivateKey => 'Keine gespeicherten Private Keys';

  @override
  String get noSavedSnippet => 'Keine gespeicherten Snippets.';

  @override
  String get noServerAvailable => 'Kein Server verfügbar.';

  @override
  String get noTask => 'Nicht fragen';

  @override
  String get noUpdateAvailable => 'Kein Update verfügbar';

  @override
  String get notSelected => 'Nicht ausgewählt';

  @override
  String get note => 'Hinweis';

  @override
  String get nullToken => 'Null token';

  @override
  String get ok => 'OK';

  @override
  String get onServerDetailPage => 'in Detailansicht des Servers';

  @override
  String get open => 'Öffnen';

  @override
  String get openLastPath => 'Öffnen Sie den letzten Pfad';

  @override
  String get openLastPathTip => 'Verschiedene Server haben unterschiedliche Einträge, und der Eintrag ist der Pfad zum Ausgang';

  @override
  String get paste => 'Einfügen';

  @override
  String get path => 'Pfad';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$percent% von $size';
  }

  @override
  String get pickFile => 'Datei wählen';

  @override
  String get pingAvg => 'Avg:';

  @override
  String get pingInputIP => 'Bitte gib eine Ziel-IP/Domain ein.';

  @override
  String get pingNoServer => 'Kein Server zum Anpingen.\nBitte füge einen Server hinzu.';

  @override
  String get pkg => 'Pkg';

  @override
  String get platformNotSupportUpdate => 'Die aktuelle Plattform unterstützt keine In-App-Updates.\nBitte kompiliere vom Quellcode und installiere sie.';

  @override
  String get plzEnterHost => 'Bitte Host eingeben.';

  @override
  String get plzSelectKey => 'Wähle einen Key.';

  @override
  String get port => 'Port';

  @override
  String get preview => 'Vorschau';

  @override
  String get primaryColorSeed => 'Farbschema';

  @override
  String get privateKey => 'Private Key';

  @override
  String get process => 'Prozess';

  @override
  String get pushToken => 'Push Token';

  @override
  String get pwd => 'Passwort';

  @override
  String get read => 'Lesen';

  @override
  String get reboot => 'Neustart';

  @override
  String get remotePath => 'Entfernte Pfade';

  @override
  String get rename => 'Umbenennen';

  @override
  String reportBugsOnGithubIssue(Object url) {
    return 'Bitte Bugs auf $url melden';
  }

  @override
  String get restart => 'Neustart';

  @override
  String get restore => 'Wiederherstellen';

  @override
  String get restoreSuccess => 'Wiederherstellung erfolgreich. App neustarten um Änderungen anzuwenden.';

  @override
  String get result => 'Result';

  @override
  String get rotateAngel => 'Rotationswinkel';

  @override
  String get run => 'Ausführen';

  @override
  String get save => 'Speichern';

  @override
  String get saved => 'Gerettet';

  @override
  String get second => 's';

  @override
  String get sequence => 'Sequenz';

  @override
  String get server => 'Server';

  @override
  String get serverDetailOrder => 'Reihenfolge der Widgets auf der Detailseite';

  @override
  String get serverFuncBtns => 'Server-Funktionsschaltflächen';

  @override
  String get serverOrder => 'Server-Bestellung';

  @override
  String get serverTabConnecting => 'Verbinden...';

  @override
  String get serverTabEmpty => 'Keine Server vorhanden.';

  @override
  String get serverTabFailed => 'Fehlgeschlagen';

  @override
  String get serverTabLoading => 'Lädt...';

  @override
  String get serverTabPlzSave => 'Bitte \'speichere\' diesen privaten Schlüssel erneut.';

  @override
  String get serverTabUnkown => 'Unbekannter Status';

  @override
  String get setting => 'Einstellungen';

  @override
  String get sftpDlPrepare => 'Verbindung vorbereiten...';

  @override
  String get sftpRmrDirSummary => 'Verwenden Sie \"rm -r\", um das Verzeichnis in SFTP zu löschen.';

  @override
  String get sftpSSHConnected => 'SFTP Verbunden';

  @override
  String get showDistLogo => 'Distributionslogo anzeigen';

  @override
  String get shutdown => 'Abschaltung';

  @override
  String get snippet => 'Snippet';

  @override
  String get speed => 'Tempo';

  @override
  String spentTime(Object time) {
    return 'Benötigte Zeit: $time';
  }

  @override
  String sshTip(Object url) {
    return 'Diese Funktion befindet sich jetzt in der Experimentierphase.\n\nBitte melde Bugs auf $url oder mach mit bei der Entwicklung.';
  }

  @override
  String get sshVirtualKeyAutoOff => 'Automatische Umschaltung der virtuellen Tasten';

  @override
  String get start => 'Start';

  @override
  String get stats => 'Statistik';

  @override
  String get stop => 'Stop';

  @override
  String get success => 'Erfolgreich';

  @override
  String get suspend => 'Suspend';

  @override
  String get suspendTip => 'Die Suspend-Funktion erfordert Root-Rechte und systemd-Unterstützung.';

  @override
  String get syncTip => 'Damit einige Änderungen wirksam werden, kann ein Neustart erforderlich sein.';

  @override
  String get system => 'Systeme';

  @override
  String get tag => 'Tags';

  @override
  String get temperature => 'Temperatur';

  @override
  String get terminal => 'Terminal';

  @override
  String get theme => 'Themen';

  @override
  String get themeMode => 'Themen-Modus';

  @override
  String get times => 'x';

  @override
  String get traffic => 'Durchflussmenge';

  @override
  String get ttl => 'ttl';

  @override
  String get unknown => 'Unbekannt';

  @override
  String get unknownError => 'Unbekannter Fehler';

  @override
  String get unkownConvertMode => 'Unbekannter Konvertierungsmodus';

  @override
  String get update => 'Update';

  @override
  String get updateAll => 'Alle aktualisieren';

  @override
  String get updateIntervalEqual0 => 'Wenn du den Wert 0 einstellst, wird nicht automatisch aktualisiert.\nDer CPU-Status kann nicht berechnet werden.';

  @override
  String get updateServerStatusInterval => 'Aktualisierungsintervall des Serverstatus';

  @override
  String updateTip(Object newest) {
    return 'Update: v1.0.$newest';
  }

  @override
  String updateTipTooLow(Object newest) {
    return 'Aktuelle Version ist zu alt, bitte update auf v1.0.$newest';
  }

  @override
  String get upload => 'Hochladen';

  @override
  String get upsideDown => 'Upside Down';

  @override
  String get urlOrJson => 'URL oder JSON';

  @override
  String get useNoPwd => 'Es wird kein Passwort verwendet.';

  @override
  String get user => 'Benutzer';

  @override
  String versionHaveUpdate(Object build) {
    return 'Gefunden: v1.0.$build, klicke zum Aktualisieren';
  }

  @override
  String versionUnknownUpdate(Object build) {
    return 'Aktuell: v1.0.$build. Klicken Sie hier, um nach Updates zu suchen';
  }

  @override
  String versionUpdated(Object build) {
    return 'v1.0.$build ist bereits die neueste Version';
  }

  @override
  String get viewErr => 'Fehler anzeigen';

  @override
  String get virtKeyHelpClipboard => 'In die Zwischenablage kopieren, wenn das ausgewählte Terminal nicht leer ist, andernfalls den Inhalt der Zwischenablage in das Terminal einfügen.';

  @override
  String get virtKeyHelpSFTP => 'Aktuelles Verzeichnis in SFTP öffnen.';

  @override
  String get waitConnection => 'Bitte warte, bis die Verbindung hergestellt wurde.';

  @override
  String get watchNotPaired => 'Keine gekoppelte Apple Watch';

  @override
  String get whenOpenApp => 'Beim Öffnen der App';

  @override
  String get willTakEeffectImmediately => 'Wird sofort angewendet';

  @override
  String get write => 'Schreiben';
}
