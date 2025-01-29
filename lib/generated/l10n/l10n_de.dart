import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get aboutThanks => 'Vielen Dank an die folgenden Personen, die daran teilgenommen haben.\n';

  @override
  String get acceptBeta => 'Akzeptieren Sie Testversion-Updates';

  @override
  String get addSystemPrivateKeyTip => 'Derzeit haben Sie keinen privaten Schlüssel, fügen Sie den Schlüssel hinzu, der mit dem System geliefert wird (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Zur Aufgabenliste hinzugefügt';

  @override
  String get addr => 'Adresse';

  @override
  String get alreadyLastDir => 'Bereits im letzten Verzeichnis.';

  @override
  String get authFailTip => 'Authentifizierung fehlgeschlagen, bitte überprüfen Sie, ob das Passwort/Schlüssel/Host/Benutzer usw. falsch sind.';

  @override
  String get autoBackupConflict => 'Es kann nur eine automatische Sicherung gleichzeitig aktiviert werden.';

  @override
  String get autoConnect => 'Automatisch verbinden';

  @override
  String get autoRun => 'Automatischer Start';

  @override
  String get autoUpdateHomeWidget => 'Home-Widget automatisch aktualisieren';

  @override
  String get backupTip => 'Das Backup wird nur einfach verschlüsselt.\nBitte bewahre die Datei sicher auf.';

  @override
  String get backupVersionNotMatch => 'Die Backup-Version stimmt nicht überein.';

  @override
  String get battery => 'Batterie';

  @override
  String get bgRun => 'Hintergrundaktualisierung';

  @override
  String get bgRunTip => 'Dieser Schalter bedeutet nur, dass die App versuchen wird, im Hintergrund zu laufen. Ob sie im Hintergrund laufen kann, hängt davon ab, ob die Berechtigungen aktiviert sind oder nicht. Bei nativem Android deaktivieren Sie bitte \"Batterieoptimierung\" in dieser App, und bei miui ändern Sie bitte die Energiesparrichtlinie auf \"Unbegrenzt\".';

  @override
  String get closeAfterSave => 'Speichern und schließen';

  @override
  String get cmd => 'Command';

  @override
  String get collapseUITip => 'Ob lange Listen in der Benutzeroberfläche standardmäßig eingeklappt werden sollen oder nicht';

  @override
  String get conn => 'Verbindung';

  @override
  String get container => 'Container';

  @override
  String get containerTrySudoTip => 'Zum Beispiel: In der App ist der Benutzer auf aaa eingestellt, aber Docker ist unter dem Root-Benutzer installiert. In diesem Fall müssen Sie diese Option aktivieren';

  @override
  String get convert => 'Konvertieren';

  @override
  String get copyPath => 'Pfad kopieren';

  @override
  String get cpuViewAsProgressTip => 'Zeigen Sie die Auslastung jedes CPUs in einem Fortschrittsbalken-Stil an (alter Stil)';

  @override
  String get cursorType => 'Cursor-Typ';

  @override
  String get customCmd => 'Benutzerdefinierte Befehle';

  @override
  String get customCmdDocUrl => 'https://github.com/lollipopkit/flutter_server_box/wiki#custom-commands';

  @override
  String get customCmdHint => '\"Befehlsname\": \"Befehl\"';

  @override
  String get decode => 'Decode';

  @override
  String get decompress => 'Dekomprimieren';

  @override
  String get deleteServers => 'Batch-Löschung von Servern';

  @override
  String get dirEmpty => 'Stelle sicher, dass der Ordner leer ist.';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get disk => 'Festplatte';

  @override
  String get diskIgnorePath => 'Pfad für Datenträger ignorieren';

  @override
  String get displayCpuIndex => 'Zeigen Sie den CPU-Index an';

  @override
  String dl2Local(Object fileName) {
    return 'Datei \"$fileName\" herunterladen?';
  }

  @override
  String get dockerEmptyRunningItems => 'Es gibt keine laufenden Container.\nDas könnte daran liegen:\n- Der Docker-Installationsbenutzer ist nicht mit dem in der App konfigurierten Benutzernamen identisch.\n- Die Umgebungsvariable DOCKER_HOST wurde nicht korrekt gelesen. Sie können sie ermitteln, indem Sie `echo \$DOCKER_HOST` im Terminal ausführen.';

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
  String get doubleColumnTip => 'Diese Option aktiviert nur die Funktion, ob sie tatsächlich aktiviert werden kann, hängt auch von der Breite des Geräts ab';

  @override
  String get editVirtKeys => 'Virtuelle Tasten bearbeiten';

  @override
  String get editor => 'Editor';

  @override
  String get editorHighlightTip => 'Die Leistung der aktuellen Codehervorhebung ist schlechter und kann zur Verbesserung optional ausgeschaltet werden.';

  @override
  String get encode => 'Encode';

  @override
  String get envVars => 'Umgebungsvariable';

  @override
  String get experimentalFeature => 'Experimentelles Feature';

  @override
  String get extraArgs => 'Extra args';

  @override
  String get fallbackSshDest => 'SSH-Fallback-Ziel';

  @override
  String get fdroidReleaseTip => 'Wenn Sie diese App von F-Droid heruntergeladen haben, wird empfohlen, diese Option zu deaktivieren.';

  @override
  String get fgService => 'Vordergrund-Dienst';

  @override
  String get fgServiceTip => 'Nach dem Einschalten kann es bei einigen Gerätemodellen zu Abstürzen kommen. Das Ausschalten kann bei einigen Modellen dazu führen, dass SSH-Verbindungen im Hintergrund nicht aufrechterhalten werden können. Bitte erlauben Sie ServerBox in den Systemeinstellungen Benachrichtigungsrechte, Hintergrundausführung und Selbstaktivierung.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'Datei \'$file\' ist zu groß $size, max $sizeMax';
  }

  @override
  String get followSystem => 'System verfolgen';

  @override
  String get font => 'Schriftarten';

  @override
  String get fontSize => 'Schriftgröße';

  @override
  String get force => 'freiwillig';

  @override
  String get fullScreen => 'Vollbildmodus';

  @override
  String get fullScreenJitter => 'Jitter im Vollbildmodus';

  @override
  String get fullScreenJitterHelp => 'Einbrennen des Bildschirms verhindern';

  @override
  String get fullScreenTip => 'Soll der Vollbildmodus aktiviert werden, wenn das Gerät in den Quermodus gedreht wird? Diese Option gilt nur für die Server-Registerkarte.';

  @override
  String get goBackQ => 'Zurückkommen?';

  @override
  String get goto => 'Pfad öffnen';

  @override
  String get hideTitleBar => 'Titelleiste ausblenden';

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
  String get ignoreCert => 'Zertifikat ignorieren';

  @override
  String get image => 'Image';

  @override
  String get imagesList => 'Images';

  @override
  String get init => 'Initialisieren';

  @override
  String get inner => 'Eingebaut';

  @override
  String get install => 'install';

  @override
  String get installDockerWithUrl => 'Bitte installiere docker zuerst. https://docs.docker.com/engine/install';

  @override
  String get invalid => 'Ungültig';

  @override
  String get jumpServer => 'Server springen';

  @override
  String get keepForeground => 'Stelle sicher, dass die App geöffnet bleibt.';

  @override
  String get keepStatusWhenErr => 'Den letzten Serverstatus beibehalten';

  @override
  String get keepStatusWhenErrTip => 'Nur im Fehlerfall während der Ausführung des Skripts';

  @override
  String get keyAuth => 'Schlüsselauthentifzierung';

  @override
  String get letterCache => 'Buchstaben-Caching';

  @override
  String get letterCacheTip => 'Empfohlen, zu deaktivieren, aber nach dem Deaktivieren können keine CJK-Zeichen eingegeben werden.';

  @override
  String get license => 'Lizenzen';

  @override
  String get location => 'Standort';

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
  String get more => 'Mehr';

  @override
  String get moveOutServerFuncBtnsHelp => 'Ein: kann unter jeder Karte auf der Registerkarte \"Server\" angezeigt werden. Aus: kann oben auf der Seite \"Serverdetails\" angezeigt werden.';

  @override
  String get ms => 'ms';

  @override
  String get needHomeDir => 'Wenn Sie ein Synology-Benutzer sind, [sehen Sie hier](https://kb.synology.com/DSM/tutorial/user_enable_home_service). Benutzer anderer Systeme müssen suchen, wie man ein Home-Verzeichnis erstellt.';

  @override
  String get needRestart => 'App muss neugestartet werden';

  @override
  String get net => 'Netzwerk';

  @override
  String get netViewType => 'Netzwerkansicht Typ';

  @override
  String get newContainer => 'Neuer Container';

  @override
  String get noLineChart => 'Verwenden Sie keine Liniendiagramme';

  @override
  String get noLineChartForCpu => 'Verwenden Sie keine Liniendiagramme für CPU';

  @override
  String get noPrivateKeyTip => 'Der private Schlüssel existiert nicht, möglicherweise wurde er gelöscht oder es liegt ein Konfigurationsfehler vor.';

  @override
  String get noPromptAgain => 'Nicht mehr nachfragen';

  @override
  String get node => 'Knoten';

  @override
  String get notAvailable => 'Nicht verfügbar';

  @override
  String get onServerDetailPage => 'in Detailansicht des Servers';

  @override
  String get onlyOneLine => 'Nur als eine Zeile anzeigen (scrollbar)';

  @override
  String get onlyWhenCoreBiggerThan8 => 'Wirksam nur, wenn die Anzahl der Kerne > 8 ist.';

  @override
  String get openLastPath => 'Öffnen Sie den letzten Pfad';

  @override
  String get openLastPathTip => 'Verschiedene Server haben unterschiedliche Einträge, und der Eintrag ist der Pfad zum Ausgang';

  @override
  String get parseContainerStatsTip => 'Das Analysieren des Belegungsstatus durch Docker ist relativ langsam';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$percent% von $size';
  }

  @override
  String get permission => 'Berechtigungen';

  @override
  String get pingAvg => 'Avg:';

  @override
  String get pingInputIP => 'Bitte gib eine Ziel-IP/Domain ein.';

  @override
  String get pingNoServer => 'Kein Server zum Anpingen.\nBitte füge einen Server hinzu.';

  @override
  String get pkg => 'Pkg';

  @override
  String get plugInType => 'Einfügetyp';

  @override
  String get port => 'Port';

  @override
  String get preview => 'Vorschau';

  @override
  String get privateKey => 'Private Key';

  @override
  String get process => 'Prozess';

  @override
  String get pushToken => 'Push Token';

  @override
  String get pveIgnoreCertTip => 'Nicht empfohlen, Achten Sie auf Sicherheitsrisiken! Wenn Sie das Standardzertifikat von PVE verwenden, müssen Sie diese Option aktivieren.';

  @override
  String get pveLoginFailed => 'Anmeldung fehlgeschlagen. Kann nicht mit Benutzername/Passwort aus der Serverkonfiguration angemeldet werden, um sich über Linux PAM anzumelden.';

  @override
  String get pveVersionLow => 'Diese Funktion befindet sich derzeit in der Testphase und wurde nur auf PVE 8+ getestet. Bitte verwenden Sie sie mit Vorsicht.';

  @override
  String get pwd => 'Passwort';

  @override
  String get read => 'Lesen';

  @override
  String get reboot => 'Neustart';

  @override
  String get rememberPwdInMem => 'Passwort im Speicher behalten';

  @override
  String get rememberPwdInMemTip => 'Für Container, Aufhängen usw.';

  @override
  String get rememberWindowSize => 'Fenstergröße merken';

  @override
  String get remotePath => 'Entfernte Pfade';

  @override
  String get restart => 'Neustart';

  @override
  String get result => 'Result';

  @override
  String get rotateAngel => 'Rotationswinkel';

  @override
  String get route => 'Routen';

  @override
  String get run => 'Ausführen';

  @override
  String get running => 'läuft';

  @override
  String get sameIdServerExist => 'Ein Server mit derselben ID existiert bereits';

  @override
  String get save => 'Speichern';

  @override
  String get saved => 'Gerettet';

  @override
  String get second => 's';

  @override
  String get sensors => 'Sensor';

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
  String get sftpDlPrepare => 'Verbindung vorbereiten...';

  @override
  String get sftpEditorTip => 'Wenn leer, verwenden Sie den im App integrierten Dateieditor. Wenn ein Wert vorhanden ist, wird der Editor des Remote-Servers verwendet, z.B. `vim` (es wird empfohlen, automatisch gemäß `EDITOR` zu ermitteln).';

  @override
  String get sftpRmrDirSummary => 'Verwenden Sie \"rm -r\", um das Verzeichnis in SFTP zu löschen.';

  @override
  String get sftpSSHConnected => 'SFTP Verbunden';

  @override
  String get sftpShowFoldersFirst => 'Ordner zuerst anzeigen';

  @override
  String get showDistLogo => 'Distributionslogo anzeigen';

  @override
  String get shutdown => 'Abschaltung';

  @override
  String get size => 'Größe';

  @override
  String get snippet => 'Snippet';

  @override
  String get softWrap => 'Weicher Umbruch';

  @override
  String get specifyDev => 'Gerät angeben';

  @override
  String get specifyDevTip => 'Zum Beispiel bezieht sich die Standard-Netzwerkverkehrsstatistik auf alle Geräte. Hier können Sie ein bestimmtes Gerät angeben.';

  @override
  String get speed => 'Tempo';

  @override
  String spentTime(Object time) {
    return 'Benötigte Zeit: $time';
  }

  @override
  String get sshTermHelp => 'Wenn das Terminal scrollbar ist, kann durch horizontales Ziehen Text ausgewählt werden. Durch Klicken auf die Tastentaste wird die Tastatur ein- oder ausgeschaltet. Das Dateisymbol öffnet den aktuellen Pfad SFTP. Die Zwischenablage-Schaltfläche kopiert den Inhalt, wenn Text ausgewählt ist, und fügt Inhalte aus der Zwischenablage in das Terminal ein, wenn kein Text ausgewählt ist und Inhalte in der Zwischenablage vorhanden sind. Das Codesymbol fügt Code-Schnipsel ins Terminal ein und führt sie aus.';

  @override
  String sshTip(Object url) {
    return 'Diese Funktion befindet sich jetzt in der Experimentierphase.\n\nBitte melde Bugs auf $url oder mach mit bei der Entwicklung.';
  }

  @override
  String get sshVirtualKeyAutoOff => 'Automatische Umschaltung der virtuellen Tasten';

  @override
  String get start => 'Start';

  @override
  String get stat => 'Statistik';

  @override
  String get stats => 'Statistik';

  @override
  String get stop => 'Stop';

  @override
  String get stopped => 'Ausgelaufen';

  @override
  String get storage => 'Speicher';

  @override
  String get supportFmtArgs => 'Die folgenden Formatierungsparameter werden unterstützt:';

  @override
  String get suspend => 'Suspend';

  @override
  String get suspendTip => 'Die Suspend-Funktion erfordert Root-Rechte und systemd-Unterstützung.';

  @override
  String switchTo(Object val) {
    return 'Wechseln zu $val';
  }

  @override
  String get sync => 'Sync';

  @override
  String get syncTip => 'Damit einige Änderungen wirksam werden, kann ein Neustart erforderlich sein.';

  @override
  String get system => 'Systeme';

  @override
  String get tag => 'Tags';

  @override
  String get temperature => 'Temperatur';

  @override
  String get termFontSizeTip => 'Diese Einstellung beeinflusst die Größe des Terminals (Breite und Höhe). Sie können die Terminalseite zoomen, um die Schriftgröße der aktuellen Sitzung anzupassen.';

  @override
  String get terminal => 'Terminal';

  @override
  String get test => 'Prüfung';

  @override
  String get textScaler => 'Skalierung der Schriftart';

  @override
  String get textScalerTip => '1.0 => 100% (Originalgröße), funktioniert nur auf der Serverseite Teil der Schrift, nicht empfohlen zu ändern.';

  @override
  String get theme => 'Themen';

  @override
  String get time => 'Zeit';

  @override
  String get times => 'x';

  @override
  String get total => 'Total';

  @override
  String get traffic => 'Durchflussmenge';

  @override
  String get trySudo => 'Versuche es mit sudo';

  @override
  String get ttl => 'TTL';

  @override
  String get unknown => 'Unbekannt';

  @override
  String get unkownConvertMode => 'Unbekannter Konvertierungsmodus';

  @override
  String get update => 'Update';

  @override
  String get updateIntervalEqual0 => 'Wenn du den Wert 0 einstellst, wird nicht automatisch aktualisiert.\nDer CPU-Status kann nicht berechnet werden.';

  @override
  String get updateServerStatusInterval => 'Aktualisierungsintervall des Serverstatus';

  @override
  String get upload => 'Hochladen';

  @override
  String get upsideDown => 'Upside Down';

  @override
  String get uptime => 'Betriebszeit';

  @override
  String get useCdn => 'Verwenden von CDN';

  @override
  String get useCdnTip => 'Nicht-chinesischen Benutzern wird die Verwendung eines CDN empfohlen. Möchten Sie es verwenden?';

  @override
  String get useNoPwd => 'Es wird kein Passwort verwendet';

  @override
  String get usePodmanByDefault => 'Standardmäßige Verwendung von Podman';

  @override
  String get used => 'Gebraucht';

  @override
  String get view => 'Ansicht';

  @override
  String get viewErr => 'Fehler anzeigen';

  @override
  String get virtKeyHelpClipboard => 'In die Zwischenablage kopieren, wenn das ausgewählte Terminal nicht leer ist, andernfalls den Inhalt der Zwischenablage in das Terminal einfügen.';

  @override
  String get virtKeyHelpIME => 'Tastatur ein-/ausschalten';

  @override
  String get virtKeyHelpSFTP => 'Aktuelles Verzeichnis in SFTP öffnen.';

  @override
  String get waitConnection => 'Bitte warte, bis die Verbindung hergestellt wurde.';

  @override
  String get wakeLock => 'Wach halten';

  @override
  String get watchNotPaired => 'Keine gekoppelte Apple Watch';

  @override
  String get webdavSettingEmpty => 'Webdav-Einstellungen sind leer';

  @override
  String get whenOpenApp => 'Beim Öffnen der App';

  @override
  String get wolTip => 'Nach der Konfiguration von WOL (Wake-on-LAN) wird jedes Mal, wenn der Server verbunden wird, eine WOL-Anfrage gesendet.';

  @override
  String get write => 'Schreiben';

  @override
  String get writeScriptFailTip => 'Das Schreiben des Skripts ist fehlgeschlagen, möglicherweise aufgrund fehlender Berechtigungen oder das Verzeichnis existiert nicht.';

  @override
  String get writeScriptTip => 'Nach der Verbindung mit dem Server wird ein Skript in ~/.config/server_box geschrieben, um den Systemstatus zu überwachen. Sie können den Skriptinhalt überprüfen.';
}
