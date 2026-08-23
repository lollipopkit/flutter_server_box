// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get acceptBeta => 'Akzeptieren Sie Testversion-Updates';

  @override
  String get addSystemPrivateKeyTip =>
      'Derzeit haben Sie keinen privaten Schlüssel, fügen Sie den Schlüssel hinzu, der mit dem System geliefert wird (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Zur Aufgabenliste hinzugefügt';

  @override
  String get askAi => 'KI fragen';

  @override
  String get askAiAwaitingResponse => 'Warte auf KI-Antwort...';

  @override
  String get askAiEndpointTip =>
      'Gib eine Basis-URL des Dienstes oder einen vollständigen Chat-Completions- bzw. Responses-Endpunkt an. ServerBox ergänzt den Pfad passend zum gewählten Protokoll.';

  @override
  String get askAiProtocolTip =>
      'Auto verwendet Responses für den offiziellen OpenAI-Endpunkt und Chat Completions für kompatible Anbieter.';

  @override
  String get askAiProtocolChatCompletions => 'Chat Completions';

  @override
  String get askAiProtocolResponses => 'Responses';

  @override
  String get askAiCommandInserted => 'Befehl ins Terminal eingefügt';

  @override
  String askAiConfigMissing(Object fields) {
    return 'Bitte konfigurieren Sie $fields in den Einstellungen.';
  }

  @override
  String get askAiDisclaimer =>
      'KI kann Fehler machen. Bitte vorsichtig verwenden.';

  @override
  String get askAiInsertTerminal => 'In Terminal einfügen';

  @override
  String get askAiNoResponse => 'Keine Antwort';

  @override
  String get askAiAgentTitle => 'SSH-Agent';

  @override
  String get askAiAgentWelcome => 'Was sollen wir auf diesem Server tun?';

  @override
  String get askAiAgentWelcomeTip =>
      'Bitte um eine Diagnose oder eine Aufgabe. Der Agent schlägt einen Befehl nach dem anderen vor und wartet vor Änderungen auf deine Prüfung.';

  @override
  String get askAiAgentPromptHint =>
      'Bitte den Agenten, etwas zu prüfen oder zu beheben …';

  @override
  String get askAiAgentSend => 'An den Agenten senden';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Analysiere den ausgewählten Terminalinhalt, erkläre, was passiert ist, und schlage den sichersten nächsten Schritt vor, falls etwas zu tun ist.';

  @override
  String get askAiTerminalContext => 'Terminal-Kontext';

  @override
  String get askAiReviewNeeded => 'Prüfen';

  @override
  String get askAiReviewAction => 'Vorgeschlagenen Befehl prüfen';

  @override
  String get askAiReviewBeforeContinuing =>
      'Prüfe oder lehne zuerst den vorgeschlagenen Befehl ab';

  @override
  String get askAiApproveRun => 'Freigeben & ausführen';

  @override
  String get askAiDecline => 'Ablehnen';

  @override
  String get askAiActionDeclined =>
      'Der vorgeschlagene Befehl wurde abgelehnt.';

  @override
  String get askAiInterrupted => 'Die Antwort des Agenten wurde unterbrochen.';

  @override
  String get askAiRiskReadOnly => 'Nur lesend';

  @override
  String get askAiRiskCaution => 'Verändert das System';

  @override
  String get askAiRiskUnvetted => 'Ungeprüfter Host';

  @override
  String get askAiRiskDestructive => 'Hohes Risiko';

  @override
  String get askAiHighRiskConfirmTitle => 'Befehl mit hohem Risiko ausführen?';

  @override
  String get askAiHighRiskConfirmBody =>
      'Dieser Befehl kann Daten löschen, Dienste stoppen oder anderweitig schwer rückgängig zu machen sein. Prüfe ihn sorgfältig, bevor du ihn ausführst.';

  @override
  String get askAiNoCommandOutput => 'Befehl ohne Ausgabe abgeschlossen.';

  @override
  String get askAiOutputTruncated =>
      'Lange Ausgabe wurde gekürzt, bevor sie an den Agenten zurückging.';

  @override
  String get askAiAutoApproved => 'Automatisch freigegeben';

  @override
  String get askAiAutoRunSafeCommands =>
      'Nur lesende Befehle automatisch ausführen';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Nur automatisch ausführen, wenn sowohl das Modell als auch die lokale Sicherheitsprüfung den Befehl als nur lesend einstufen. Befehle, die das System verändern, müssen weiterhin geprüft werden.';

  @override
  String get askAiSendOnEnter => 'Enter sendet';

  @override
  String get askAiSendOnEnterTip =>
      'Enter sendet die Nachricht, Shift+Enter beginnt eine neue Zeile. Aus vertauscht beides: Enter beginnt eine neue Zeile, Cmd/Strg+Enter sendet.';

  @override
  String get askAiApiKeyOptional =>
      'Optional bei lokalen oder nicht authentifizierten Endpunkten';

  @override
  String get askAiHistory => 'Gesprächsverlauf';

  @override
  String get askAiNewConversation => 'Neues Gespräch';

  @override
  String get askAiNoHistory =>
      'Keine gespeicherten Gespräche für diesen Server';

  @override
  String get askAiNoHistoryMessages => 'Noch keine Nachrichten';

  @override
  String get askAiUntitledConversation => 'Neues Gespräch';

  @override
  String get askAiRenameConversation => 'Gespräch umbenennen';

  @override
  String get askAiDeleteConversationTitle => 'Dieses Gespräch löschen?';

  @override
  String get askAiDeleteConversationTip =>
      'Das Gespräch wird von diesem Gerät entfernt und kann nicht wiederhergestellt werden.';

  @override
  String get askAiClearHistoryTitle => 'Agent-Verlauf dieses Servers löschen?';

  @override
  String get askAiClearHistoryTip =>
      'Alle für diesen Server gespeicherten Agent-Gespräche werden von diesem Gerät entfernt.';

  @override
  String get askAiRestoredReview =>
      'Aus dem Verlauf wiederhergestellt. Prüfe ihn erneut vor dem Ausführen; automatisch läuft er nie.';

  @override
  String get agentTitle => 'Agent';

  @override
  String get agentWelcome => 'Was sollen wir auf deinen Servern tun?';

  @override
  String get agentWelcomeTip =>
      'Bitte um eine Diagnose oder eine Betriebsaufgabe. Der Agent nutzt den aktuellen ServerBox-Zustand und schlägt jeweils eine zu prüfende Aktion vor.';

  @override
  String get agentPromptHint =>
      'Bitte den Agenten, deine Server zu prüfen oder zu bedienen …';

  @override
  String get agentNoHistory => 'Keine gespeicherten globalen Agent-Gespräche';

  @override
  String get agentClearHistoryTitle => 'Globalen Agent-Verlauf löschen?';

  @override
  String get agentClearHistoryTip =>
      'Alle globalen Agent-Gespräche werden von diesem Gerät entfernt.';

  @override
  String get agentToolShell => 'Shell';

  @override
  String get agentToolReadFile => 'Datei lesen';

  @override
  String get agentToolWriteFile => 'Datei schreiben';

  @override
  String get agentToolServerBox => 'ServerBox';

  @override
  String get agentToolFailed => 'Ausführung des Werkzeugs fehlgeschlagen.';

  @override
  String agentToolCallsFmt(Object count) {
    return '$count Werkzeugaufrufe';
  }

  @override
  String get agentFloat => 'Über anderen Tabs schweben';

  @override
  String get agentToolSshConnect => 'SSH verbinden';

  @override
  String get agentToolSshDisconnect => 'SSH trennen';

  @override
  String get agentSshConnectTitle => 'Mit einem neuen Host verbinden';

  @override
  String get agentAuthMethod => 'Authentifizierung';

  @override
  String get agentSshConnectTip =>
      'Der Agent möchte eine SSH-Verbindung aufbauen. Gib das Passwort hier ein – niemals im Gespräch, wo es gespeichert und an das Modell geschickt würde.';

  @override
  String get agentAdHocSessions => 'Temporäre Verbindungen';

  @override
  String get agentSaveServerTitle => 'Als Server speichern';

  @override
  String get agentSaveServerTip =>
      'Dieser Host und das eingegebene Passwort werden auf diesem Gerät gespeichert.';

  @override
  String get agentMonitorOptional => 'monitor-Agent (optional)';

  @override
  String get authFailTip =>
      'Authentifizierung fehlgeschlagen, bitte überprüfen Sie, ob das Passwort/Schlüssel/Host/Benutzer usw. falsch sind.';

  @override
  String get autoBackupConflict =>
      'Es kann nur eine automatische Sicherung gleichzeitig aktiviert werden.';

  @override
  String get autoConnect => 'Automatisch verbinden';

  @override
  String get autoRun => 'Automatischer Start';

  @override
  String get autoUpdateHomeWidget => 'Home-Widget automatisch aktualisieren';

  @override
  String get availableTabs => 'Verfügbare Tabs';

  @override
  String get backupEncrypted => 'Backup ist verschlüsselt';

  @override
  String get backupNotEncrypted => 'Backup ist nicht verschlüsselt';

  @override
  String get backupPassword => 'Backup-Passwort';

  @override
  String get backupPasswordRemoved => 'Backup-Passwort entfernt';

  @override
  String get backupPasswordSet => 'Backup-Passwort gesetzt';

  @override
  String get backupPasswordTip =>
      'Setzen Sie ein Passwort, um Backup-Dateien zu verschlüsseln. Leer lassen, um Verschlüsselung zu deaktivieren.';

  @override
  String get backupPasswordWrong => 'Falsches Backup-Passwort';

  @override
  String get remoteBackupPasswordRequired =>
      'Remote backups require a non-empty backup password';

  @override
  String get monitorHttpsRequired =>
      'Remote monitor agents require HTTPS; HTTP is allowed only on loopback.';

  @override
  String get monitorAllowInsecureHttp => 'Allow insecure HTTP';

  @override
  String get monitorAllowInsecureHttpTip =>
      'Only enable for a trusted private network with transport encryption outside HTTP, such as Tailscale. The agent must also explicitly allow plaintext file access. Credentials and file contents may otherwise be exposed.';

  @override
  String get backupTip =>
      'Die exportierten Daten können mit einem Passwort verschlüsselt werden. \nBitte sicher aufbewahren.';

  @override
  String get icloudBackupStatusTitle => 'Backup-Status';

  @override
  String get icloudBackupStatusLoading => 'iCloud-Backup-Status wird geladen …';

  @override
  String get icloudBackupStatusError =>
      'iCloud-Backup-Metadaten können nicht gelesen werden';

  @override
  String get icloudBackupStatusEmpty =>
      'Noch keine iCloud-Backup-Datei gefunden';

  @override
  String get icloudBackupStateUploading => 'Wird hochgeladen';

  @override
  String get icloudBackupStateConflict => 'Konflikt erkannt';

  @override
  String get icloudBackupStateUploaded => 'Hochgeladen';

  @override
  String get icloudBackupStateWaiting => 'Wartet auf iCloud';

  @override
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return 'Letztes Backup: $lastModified\nStatus: $remoteState';
  }

  @override
  String get bgRun => 'Hintergrundaktualisierung';

  @override
  String get bgRunTip =>
      'Dieser Schalter bedeutet nur, dass die App versuchen wird, im Hintergrund zu laufen. Ob sie im Hintergrund laufen kann, hängt davon ab, ob die Berechtigungen aktiviert sind oder nicht. Bei nativem Android deaktivieren Sie bitte \"Batterieoptimierung\" in dieser App, und bei miui ändern Sie bitte die Energiesparrichtlinie auf \"Unbegrenzt\".';

  @override
  String get clearAllStatsContent =>
      'Sind Sie sicher, dass Sie alle Server-Verbindungsstatistiken löschen möchten? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get clearAllStatsTitle => 'Alle Statistiken löschen';

  @override
  String clearServerStatsContent(Object serverName) {
    return 'Sind Sie sicher, dass Sie die Verbindungsstatistiken für Server \"$serverName\" löschen möchten? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String clearServerStatsTitle(Object serverName) {
    return '$serverName Statistiken löschen';
  }

  @override
  String get clearThisServerStats => 'Statistiken dieses Servers löschen';

  @override
  String get compactDatabase => 'Datenbank komprimieren';

  @override
  String compactDatabaseContent(Object size) {
    return 'Datenbankgröße: $size\n\nDies wird die Datenbank neu organisieren, um die Dateigröße zu reduzieren. Es werden keine Daten gelöscht.';
  }

  @override
  String get closeAfterSave => 'Speichern und schließen';

  @override
  String get collapseUITip =>
      'Ob lange Listen in der Benutzeroberfläche standardmäßig eingeklappt werden sollen oder nicht';

  @override
  String get connectionDetails => 'Verbindungsdetails';

  @override
  String get connectionStats => 'Verbindungsstatistiken';

  @override
  String get connectionStatsDesc =>
      'Server-Verbindungserfolgsrate und Verlauf anzeigen';

  @override
  String get containerTrySudoTip =>
      'Zum Beispiel: In der App ist der Benutzer auf aaa eingestellt, aber Docker ist unter dem Root-Benutzer installiert. In diesem Fall müssen Sie diese Option aktivieren';

  @override
  String get containerSudoPasswordRequired =>
      'Ein sudo-Passwort ist erforderlich, um auf Docker zuzugreifen. Bitte geben Sie Ihr Passwort ein.';

  @override
  String get containerSudoPasswordIncorrect =>
      'Das sudo-Passwort ist falsch oder nicht erlaubt. Bitte versuchen Sie es erneut.';

  @override
  String get copyPath => 'Pfad kopieren';

  @override
  String get cpuViewAsProgressTip =>
      'Zeigen Sie die Auslastung jedes CPUs in einem Fortschrittsbalken-Stil an (alter Stil)';

  @override
  String get customCmd => 'Benutzerdefinierte Befehle';

  @override
  String get deleteServers => 'Batch-Löschung von Servern';

  @override
  String get deleteDirRecursive => 'Ordner mit dem gesamten Inhalt löschen';

  @override
  String get desktopTerminalTip =>
      'Befehl zum Öffnen des Terminal-Emulators beim Starten von SSH-Sitzungen.';

  @override
  String get dirEmpty => 'Stelle sicher, dass der Ordner leer ist.';

  @override
  String get discoverSshServers => 'SSH-Server entdecken';

  @override
  String get discoveryFailed => 'Entdeckung fehlgeschlagen';

  @override
  String get discoverySettings => 'Entdeckungseinstellungen';

  @override
  String get distro => 'Distribution';

  @override
  String distroSwitchTip(Object from, Object to) {
    return '$from durch $to ersetzen. Alles, was in $from installiert wurde, wird gelöscht, und $to wird stattdessen heruntergeladen und entpackt.';
  }

  @override
  String get diskHealth => 'Festplattengesundheit';

  @override
  String get displayCpuIndex => 'Zeigen Sie den CPU-Index an';

  @override
  String dl2Local(Object fileName) {
    return 'Datei \"$fileName\" herunterladen?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'Es gibt keine laufenden Container.\nDas könnte daran liegen:\n- Der Docker-Installationsbenutzer ist nicht mit dem in der App konfigurierten Benutzernamen identisch.\n- Die Umgebungsvariable DOCKER_HOST wurde nicht korrekt gelesen. Sie können sie ermitteln, indem Sie `echo \$DOCKER_HOST` im Terminal ausführen.';

  @override
  String dockerImagesFmt(Object count) {
    return '$count Image(s)';
  }

  @override
  String get dockerProjectOther => 'Andere';

  @override
  String get dockerPruneTip =>
      'Nicht verwendete Daten entfernen, um Speicherplatz freizugeben';

  @override
  String get dockerStatistics => 'Docker-Statistiken';

  @override
  String get doubleColumnMode => 'Doppelspaltiger Modus';

  @override
  String get doubleColumnTip =>
      'Diese Option aktiviert nur die Funktion, ob sie tatsächlich aktiviert werden kann, hängt auch von der Breite des Geräts ab';

  @override
  String get editVirtKeys => 'Virtuelle Tasten';

  @override
  String get editorHighlightTip =>
      'Die Leistung der aktuellen Codehervorhebung ist schlechter und kann zur Verbesserung optional ausgeschaltet werden.';

  @override
  String get enableMdns => 'mDNS aktivieren';

  @override
  String get enableMdnsDesc =>
      'mDNS/Bonjour verwenden, um SSH-Dienste zu entdecken';

  @override
  String get envVars => 'Umgebungsvariable';

  @override
  String get extraArgs => 'Extra args';

  @override
  String get fallbackSshDest => 'SSH-Fallback-Ziel';

  @override
  String get fdroidReleaseTip =>
      'Wenn Sie diese App von F-Droid heruntergeladen haben, wird empfohlen, diese Option zu deaktivieren.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'Datei \'$file\' ist zu groß $size, max $sizeMax';
  }

  @override
  String get fileDirGone => 'Dieser Ordner ist nicht mehr da';

  @override
  String get fileDirGoneTip =>
      'Er wurde gelöscht oder umbenannt. Nutze die Leiste unten, um zurückzugehen, zum Startordner zu springen oder woandershin zu wechseln.';

  @override
  String get fullScreen => 'Vollbild';

  @override
  String get fullScreenJitter => 'Jitter im Vollbildmodus';

  @override
  String get fullScreenJitterHelp => 'Einbrennen des Bildschirms verhindern';

  @override
  String get fullScreenTip =>
      'Soll der Vollbildmodus aktiviert werden, wenn das Gerät in den Quermodus gedreht wird? Diese Option gilt nur für die Server-Registerkarte.';

  @override
  String get githubGist => 'GitHub Gist';

  @override
  String get githubGistIdOptional => 'Gist-ID (optional)';

  @override
  String get githubGistToken => 'GitHub-Gist-Token';

  @override
  String get githubGistTokenEmpty => 'Token ist leer';

  @override
  String get goto => 'Pfad öffnen';

  @override
  String get homeTabs => 'Home-Tabs';

  @override
  String get homeTabsCustomizeDesc =>
      'Passen Sie an, welche Tabs auf der Startseite angezeigt werden und ihre Reihenfolge';

  @override
  String get homeWidgetUrlConfig => 'Home-Widget-Link konfigurieren';

  @override
  String get ignoreCert => 'Zertifikat ignorieren';

  @override
  String get image => 'Image';

  @override
  String get macDmgBody =>
      'Der App Store verlangt, dass diese App in der Sandbox läuft, und ein Prozess in der Sandbox kann kein Pseudo-Terminal öffnen. Der App-Store-Build hat deshalb kein Terminal auf diesem Mac und kann hier weder ein Snippet noch einen Agent-Befehl ausführen. Der DMG-Build ist dieselbe App, ohne Sandbox signiert, und kann beides.\n\nDer App-Store-Build funktioniert weiterhin und wird weiterhin aktualisiert. Später kann das enden.\n\nBeide Builds legen ihre Daten an unterschiedlichen Orten ab. Der DMG-Build kopiert sie beim ersten Start herüber, sodass Server, Schlüssel und Verlauf mitkommen. Schlägt das fehl, wird es gemeldet, und du kannst stattdessen eine Sicherungsdatei mitnehmen (Sicherung in den Einstellungen).';

  @override
  String get macDmgImportDenied =>
      'macOS hat das Lesen der Daten des zuvor installierten Builds nicht erlaubt. Erteile vollständigen Festplattenzugriff und öffne die App erneut, oder exportiere dort eine Sicherung und stelle sie hier wieder her.';

  @override
  String get macDmgImported =>
      'Daten des zuvor installierten Builds importiert.';

  @override
  String get macDmgImportFailed =>
      'Die Daten des zuvor installierten Builds konnten nicht gelesen werden. Exportiere dort eine Sicherung und stelle sie hier wieder her.';

  @override
  String get macDmgTip =>
      'Ein Terminal auf diesem Mac und das Ausführen von Snippets darauf gibt es nur im DMG-Build.';

  @override
  String get macDmgTitle => 'DMG-Build';

  @override
  String get showHiddenFiles => 'Versteckte Dateien anzeigen';

  @override
  String get unused => 'Ungenutzt';

  @override
  String get dangling => 'Verwaist';

  @override
  String get pruneUnusedImages => 'Ungenutzte Images bereinigen';

  @override
  String get pruneDanglingImages => 'Verwaiste Images bereinigen';

  @override
  String get pruneImages => 'Images bereinigen';

  @override
  String get unusedTaggedImages => 'Unbenutzt markiert';

  @override
  String get pruneDanglingImagesTip =>
      'Nur verwaiste Images (nicht getaggte Layer) entfernen.';

  @override
  String get pruneUnusedImagesTip =>
      'Zusätzlich getaggte Images entfernen, die von keinem Container verwendet werden.';

  @override
  String get includeUnusedVolumesTip =>
      'Zusätzlich Volumes entfernen, die von keinem Container verwendet werden.';

  @override
  String get pruneCommandPreview => 'Befehlsvorschau';

  @override
  String get pruneForceSshTip =>
      '-f überspringt die interaktive Bestätigung und ist bei SSH-Ausführung immer aktiviert.';

  @override
  String get pruneVolumes => 'Volumes bereinigen';

  @override
  String get pruneUnusedData => 'Ungenutzte Daten bereinigen';

  @override
  String get pull => 'Pull';

  @override
  String get invalidHostFormat =>
      'Ungültiges Host-Format. Erlaubt sind nur IPv4, IPv6 und Domain-Zeichen.';

  @override
  String get jumpServer => 'Server springen';

  @override
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return 'Jump-Server für $serverName nicht gefunden: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(Object name) {
    return '„$name“ existiert bereits';
  }

  @override
  String get noJumpServerAvailable => 'Kein Jump-Server verfügbar.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Jump-Server und ProxyCommand können nicht zusammen verwendet werden.';

  @override
  String get keepForeground => 'Stelle sicher, dass die App geöffnet bleibt.';

  @override
  String get keepStatusWhenErr => 'Den letzten Serverstatus beibehalten';

  @override
  String get keepStatusWhenErrTip =>
      'Nur im Fehlerfall während der Ausführung des Skripts';

  @override
  String get keyAuth => 'Schlüsselauthentifzierung';

  @override
  String get lastFailure => 'Letzter Fehler';

  @override
  String get lastSuccess => 'Letzter Erfolg';

  @override
  String get letterCache => 'Normale Tastatureingabe';

  @override
  String get letterCacheTip =>
      'Wenn aktiviert, läuft die Eingabe über die normale IME. Dadurch lassen sich auf manchen Systemen sichere Tastaturhinweise im Terminal vermeiden.';

  @override
  String get linuxShellTip =>
      'Was ein interaktives Terminal startet. Alpine hat kein chsh, und nichts im System liest /etc/passwd — das hier entscheidet also allein. Einzelne Befehle laufen weiterhin unter /bin/sh, weil App und Agent POSIX schreiben. Leer lassen, um /bin/sh wiederherzustellen.';

  @override
  String get linuxNetTip =>
      'Woher das Linux-System und seine Pakete geladen werden und welche DNS-Server eingetragen werden. Leer lassen, um den Standard wiederherzustellen. Beim Speichern werden beide auch in einem bereits installierten System überschrieben.';

  @override
  String madeWithLove(Object myGithub) {
    return 'Erstellt mit ❤️ von $myGithub';
  }

  @override
  String get maxConcurrency => 'Maximale Gleichzeitigkeit';

  @override
  String get maxRetryCount => 'Anzahl an Verbindungsversuchen';

  @override
  String mismatchSystem(Object system) {
    return 'Nicht übereinstimmendes System: $system';
  }

  @override
  String get mirror => 'Spiegelserver';

  @override
  String get needRestart => 'App muss neugestartet werden';

  @override
  String get netViewType => 'Netzwerkansicht Typ';

  @override
  String get newContainer => 'Neuer Container';

  @override
  String get noConnectionStatsData => 'Keine Verbindungsstatistikdaten';

  @override
  String get noLineChart => 'Verwenden Sie keine Liniendiagramme';

  @override
  String get noPrivateKeyTip =>
      'Der private Schlüssel existiert nicht, möglicherweise wurde er gelöscht oder es liegt ein Konfigurationsfehler vor.';

  @override
  String get noPromptAgain => 'Nicht mehr nachfragen';

  @override
  String get onlyOneLine => 'Nur als eine Zeile anzeigen (scrollbar)';

  @override
  String get openLastPath => 'Öffnen Sie den letzten Pfad';

  @override
  String get openLastPathTip =>
      'Verschiedene Server haben unterschiedliche Einträge, und der Eintrag ist der Pfad zum Ausgang';

  @override
  String get parseContainerStatsTip =>
      'Das Analysieren des Belegungsstatus durch Docker ist relativ langsam';

  @override
  String get plugInType => 'Einfügetyp';

  @override
  String get preferDiskAmount => 'Festplattenkapazität vorrangig anzeigen';

  @override
  String get privateKey => 'Private Key';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
    return 'Privater Schlüssel [$keyId] wurde nicht gefunden.';
  }

  @override
  String get bmcPowerOnAction => 'Einschalten';

  @override
  String get bmcShutdown => 'Herunterfahren';

  @override
  String get bmcForceOff => 'Hart ausschalten';

  @override
  String get bmcRestart => 'Neu starten';

  @override
  String get bmcPowerCycle => 'Strom aus und ein';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return 'An $server senden? Der Dienst wird um \"$resetType\" gebeten — das ist, was er für diese Aktion zulässt.';
  }

  @override
  String get bmcPowerDone => 'Der Energiezustand hat sich geändert';

  @override
  String get bmcPowerAccepted =>
      'Angenommen, aber der Energiezustand hat sich noch nicht geändert. Eine sanfte Operation hängt vom Betriebssystem ab, und manche Dienste unterscheiden sie nicht.';

  @override
  String get bmcPowerUnsupported =>
      'Dieser Dienst lässt für diese Aktion nichts zu';

  @override
  String get bmcUnauthorized => 'Der BMC hat das Konto abgelehnt';

  @override
  String get bmcAccountMissing => 'Für diesen BMC ist kein Konto festgelegt';

  @override
  String get bmcPowerOn => 'Eingeschaltet';

  @override
  String get bmcPowerOff => 'Ausgeschaltet';

  @override
  String get bmcCertRejected =>
      'Zertifikat abgelehnt — in den Servereinstellungen prüfen';

  @override
  String get bmcNotAService =>
      'Unter dieser Adresse gibt es keinen Redfish-Dienst';

  @override
  String get bmcNoSystem => 'Der Dienst meldet kein System';

  @override
  String get bmcSensorsTruncated =>
      'Es werden nur die ersten Sensoren angezeigt';

  @override
  String get bmcMultipleSystems => 'Nur das erste System wird angezeigt';

  @override
  String get bmcTip =>
      'Der BMC ist ein eigener Computer auf dem Mainboard, erreichbar auch wenn das Host-Betriebssystem es nicht ist. Hier eingerichtet, meldet er Energiezustand und Hardwaresensoren, während der Server aus oder hängen geblieben ist. Erfordert Redfish, das Enterprise-Hardware etwa ab 2016 mitbringt.';

  @override
  String get bmcCert => 'Zertifikat';

  @override
  String get bmcCertPinned => 'Geprüft und angeheftet';

  @override
  String get bmcCertUnreviewed =>
      'Noch nicht geprüft — tippen, um zu sehen, was der BMC vorlegt';

  @override
  String get bmcCertReview =>
      'BMCs verwenden selbstsignierte Zertifikate, für dieses bürgt also niemand. Vergleichen Sie es mit dem, was die Weboberfläche des BMC anzeigt. Nach der Annahme wird ausschließlich genau dieses Zertifikat vertraut.';

  @override
  String get bmcCertChanged =>
      'Dies ist nicht das zuvor angenommene Zertifikat. Das passiert, wenn der BMC sein Zertifikat neu erzeugt oder seine Firmware aktualisiert wird — genauso sähe aber auch ein Abfangen aus. Prüfen Sie es vor der Annahme.';

  @override
  String get bmcCertExpired =>
      'Dieses Zertifikat liegt außerhalb seiner Gültigkeitsdaten.';

  @override
  String bmcCertWas(String fingerprint) {
    return 'Zuvor angenommen: $fingerprint';
  }

  @override
  String get bmcAddrInvalid =>
      'Die BMC-Adresse muss eine URL sein, z. B. https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      'Dieser Build läuft in einer Sandbox: Der Befehl sieht statt Ihres Home-Verzeichnisses ein leeres, daher schlägt alles fehl, was ~/.ssh liest (ssh -W, cloudflared) — meist als Zeitüberschreitung mit dem falschen Host. Befehle, die nur das Netzwerk nutzen, funktionieren weiterhin. Der DMG-Build hat keine Sandbox.';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return 'Die Schlüsseldatei $path kann nicht gelesen werden: $reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return 'Dieser Build kann keine Dateien außerhalb seines Containers lesen, der Schlüssel unter $path ist daher nicht erreichbar. Importieren Sie den Schlüssel in den Einstellungen oder verwenden Sie den DMG-Build.';
  }

  @override
  String get pushToken => 'Push Token';

  @override
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand wird nur auf Desktop-Plattformen unterstützt.';

  @override
  String get pveIgnoreCertTip =>
      'Nicht empfohlen, Achten Sie auf Sicherheitsrisiken! Wenn Sie das Standardzertifikat von PVE verwenden, müssen Sie diese Option aktivieren.';

  @override
  String get pveServerClientMissing =>
      'Der SSH-Client für diesen Server ist nicht verfügbar.';

  @override
  String get pveAddressMissing =>
      'Die PVE-Adresse fehlt. Bitte konfiguriere sie in den Servereinstellungen.';

  @override
  String get pvePasswordRequired =>
      'Ein PVE-Passwort ist erforderlich. Bitte hinterlege es in den Servereinstellungen.';

  @override
  String get pveOtpRequired =>
      'Auf diesem PVE-Server ist die Zwei-Faktor-Authentifizierung aktiviert. Bitte gib den OTP-Code ein.';

  @override
  String get pveOtpChallengeExpired =>
      'Die OTP-Anfrage ist abgelaufen. Bitte aktualisiere und versuche es erneut.';

  @override
  String get pveOtpCodeRequired => 'OTP-Code ist erforderlich.';

  @override
  String get pveOtpVerificationFailed =>
      'OTP-Prüfung fehlgeschlagen. Bitte versuche es mit einem neuen Code.';

  @override
  String get pveOtpTitle => 'OTP-Prüfung';

  @override
  String get pveOtpLabel => 'OTP-Code';

  @override
  String get pveInvalidResponseBody =>
      'Die PVE-Anmeldung hat einen ungültigen Antworttext zurückgegeben.';

  @override
  String get pveInvalidResponseData =>
      'Die Antwort der PVE-Anmeldung enthielt keine gültigen Daten.';

  @override
  String get pveMissingAuthTicket =>
      'Die PVE-Anmeldung war erfolgreich, es wurde aber kein Authentifizierungsticket zurückgegeben.';

  @override
  String get pveVersionLow =>
      'Diese Funktion befindet sich derzeit in der Testphase und wurde nur auf PVE 8+ getestet. Bitte verwenden Sie sie mit Vorsicht.';

  @override
  String get pveLoadingForwarding => 'SSH-Tunnel wird aufgebaut …';

  @override
  String get pveLoadingLogin => 'Authentifizierung bei PVE …';

  @override
  String get pveLoadingData => 'Cluster-Daten werden abgerufen …';

  @override
  String get pveLoadingConnect => 'Verbinden …';

  @override
  String get pvePassword => 'PVE-Passwort';

  @override
  String get pvePasswordHint =>
      'Erforderlich bei SSH-Authentifizierung mit Schlüssel';

  @override
  String get read => 'Lesen';

  @override
  String get recentConnections => 'Kürzliche Verbindungen';

  @override
  String get rememberPwdInMem => 'Passwort im Speicher behalten';

  @override
  String get rememberPwdInMemTip => 'Für Container, Aufhängen usw.';

  @override
  String get remotePath => 'Entfernte Pfade';

  @override
  String rootfsUpdateTip(
    Object distro,
    Object installed,
    Object latest,
    Object pm,
  ) {
    return '$distro $installed ist installiert, $latest ist verfügbar. Beim Aktualisieren wird es erneut heruntergeladen und der Container ersetzt: Alles, was darin mit $pm installiert wurde, geht verloren. Beim Überspringen bleibt der aktuelle Container nutzbar.';
  }

  @override
  String linuxSystemInUse(Object name) {
    return '$name hat noch ein Terminal offen. Schließen Sie es, bevor Sie das System löschen.';
  }

  @override
  String get rootfsSubtitle => 'Eine Linux-Userland-Umgebung auf diesem Gerät';

  @override
  String rootfsInstallTip(Object distro, Object version, Object size) {
    return '$distro $version (etwa $size MB) herunterladen und auf diesem Gerät entpacken. Es gibt dieser App eine Shell mit Paketmanager und kann jederzeit gelöscht werden.';
  }

  @override
  String get sameIdServerExist =>
      'Ein Server mit derselben ID existiert bereits';

  @override
  String get second => 's';

  @override
  String get serverFilesUnavailableTip =>
      'Erreichbar entweder über SSH dieses Servers oder über einen Monitor-Agenten mit eingeschalteter Datei-API.';

  @override
  String get back => 'Zurück';

  @override
  String get history => 'Verlauf';

  @override
  String get homeDir => 'Persönlicher Ordner';

  @override
  String get selectItem => 'Auswählen';

  @override
  String selected(Object count) {
    return '$count ausgewählt';
  }

  @override
  String get sendTo => 'Senden an …';

  @override
  String get serverDetailOrder => 'Reihenfolge der Widgets auf der Detailseite';

  @override
  String get serverFuncBtns => 'Server-Funktionsschaltflächen';

  @override
  String get serverOrder => 'Server-Bestellung';

  @override
  String get serverTabRequired => 'Server-Tab kann nicht entfernt werden';

  @override
  String get shareServerRiskTip =>
      'Dieser QR-Code enthält die Verbindungseinstellungen des Servers im Klartext, einschließlich Passwörtern. Wer ihn scannt oder abfotografiert, kann sich mit diesem Server verbinden.';

  @override
  String get sftpDlPrepare => 'Verbindung vorbereiten...';

  @override
  String get sftpEditorTip =>
      'Wenn leer, verwenden Sie den im App integrierten Dateieditor. Wenn ein Wert vorhanden ist, wird der Editor des Remote-Servers verwendet, z.B. `vim` (es wird empfohlen, automatisch gemäß `EDITOR` zu ermitteln).';

  @override
  String get sftpRmrDirSummary =>
      'Verwenden Sie \"rm -r\", um das Verzeichnis in SFTP zu löschen.';

  @override
  String get sftpSSHConnected => 'SFTP Verbunden';

  @override
  String get sftp => 'SFTP';

  @override
  String get sftpShowFoldersFirst => 'Ordner zuerst anzeigen';

  @override
  String get specifyDev => 'Gerät angeben';

  @override
  String get specifyDevTip =>
      'Zum Beispiel bezieht sich die Standard-Netzwerkverkehrsstatistik auf alle Geräte. Hier können Sie ein bestimmtes Gerät angeben.';

  @override
  String get tempIsCelsiusTip =>
      'Wenn aktiviert, wird der Temperaturwert als Celsius statt als Millicelsius behandelt. Nur einschalten, wenn die Temperatur falsch angezeigt wird (z. B. 0,1 °C statt 58 °C).';

  @override
  String spentTime(Object time) {
    return 'Benötigte Zeit: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'Alle Server existieren bereits ($duplicateCount Duplikate gefunden)';
  }

  @override
  String get sshConnectionModeTip =>
      'Integriert: das Terminal der App verwenden. System-SSH: den ssh-Befehl des Systems in einem externen Terminal starten.';

  @override
  String get sshConnectionModeUseBuiltin => 'Integriertes Terminal verwenden';

  @override
  String get sshConnectionModeUseSystem => 'System-SSH verwenden';

  @override
  String sshConfigDuplicatesSkipped(Object duplicateCount) {
    return '$duplicateCount Duplikate werden übersprungen';
  }

  @override
  String get sshConfigFound =>
      'Wir haben SSH-Konfiguration auf Ihrem System gefunden.';

  @override
  String sshConfigFoundServers(Object totalCount) {
    return '$totalCount Server gefunden';
  }

  @override
  String get sshConfigImport => 'SSH-Konfiguration importieren';

  @override
  String get sshConfigImportPermission =>
      'Möchten Sie die Berechtigung erteilen, ~/.ssh/config zu lesen und Server-Einstellungen automatisch zu importieren?';

  @override
  String get sshConfigImportTip =>
      'Bei der ersten Server-Erstellung zum Lesen von ~/.ssh/config auffordern';

  @override
  String sshConfigImported(Object count) {
    return '$count Server aus SSH-Konfiguration importiert';
  }

  @override
  String sshHostKeyChangedDesc(Object serverName) {
    return 'Der SSH-Hostschlüssel für $serverName hat sich geändert. Fahren Sie nur fort, wenn Sie diesem Server vertrauen.';
  }

  @override
  String sshHostKeyFingerprintMd5Base64(Object fingerprint) {
    return 'Fingerabdruck (MD5 Base64): $fingerprint';
  }

  @override
  String sshHostKeyFingerprintMd5Hex(Object fingerprint) {
    return 'Fingerabdruck (SHA256): $fingerprint';
  }

  @override
  String get sshHostKeyType => 'SSH-Hostschlüsseltyp';

  @override
  String get sshKnownHostKeys => 'Bekannte Hosts';

  @override
  String get sshKnownHostKeysTip =>
      'Von dieser App akzeptierte Hostschlüssel. Wird einer entfernt, wird beim nächsten Verbinden erneut gefragt.';

  @override
  String sshHostKeyNewDesc(Object serverName) {
    return 'Ein neuer SSH-Hostschlüssel wurde von $serverName empfangen. Prüfen Sie den Fingerabdruck, bevor Sie vertrauen.';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
    return 'Gespeicherter Fingerabdruck: $fingerprint';
  }

  @override
  String get sshVerificationCode => 'Bestätigungscode';

  @override
  String get sshConfigManualSelect =>
      'Möchten Sie die SSH-Konfigurationsdatei manuell auswählen?';

  @override
  String get sshConfigNoServers =>
      'Keine Server in der SSH-Konfiguration gefunden';

  @override
  String get sshConfigPermissionDenied =>
      'Aufgrund der macOS-Berechtigungen kann nicht auf die SSH-Konfigurationsdatei zugegriffen werden.';

  @override
  String sshConfigServersToImport(Object importCount) {
    return '$importCount Server werden importiert';
  }

  @override
  String get sshTermHelp =>
      'Wenn das Terminal scrollbar ist, kann durch horizontales Ziehen Text ausgewählt werden. Durch Klicken auf die Tastentaste wird die Tastatur ein- oder ausgeschaltet. Das Dateisymbol öffnet den aktuellen Pfad SFTP. Die Zwischenablage-Schaltfläche kopiert den Inhalt, wenn Text ausgewählt ist, und fügt Inhalte aus der Zwischenablage in das Terminal ein, wenn kein Text ausgewählt ist und Inhalte in der Zwischenablage vorhanden sind. Das Codesymbol fügt Code-Schnipsel ins Terminal ein und führt sie aus.';

  @override
  String get sshVirtualKeyAutoOff =>
      'Automatische Umschaltung der virtuellen Tasten';

  @override
  String get supportFmtArgs =>
      'Die folgenden Formatierungsparameter werden unterstützt:';

  @override
  String get suspendTip =>
      'Die Suspend-Funktion erfordert Root-Rechte und systemd-Unterstützung.';

  @override
  String switchTo(Object val) {
    return 'Wechseln zu $val';
  }

  @override
  String get syncAppSettings => 'App-Einstellungen synchronisieren';

  @override
  String get syncAppSettingsTip =>
      'Design, Layout, Editor, Terminal und weitere Geräteeinstellungen in die automatische Synchronisierung einbeziehen.';

  @override
  String get system => 'Systeme';

  @override
  String get termFontSizeTip =>
      'Diese Einstellung beeinflusst die Größe des Terminals (Breite und Höhe). Sie können die Terminalseite zoomen, um die Schriftgröße der aktuellen Sitzung anzupassen.';

  @override
  String get textScalerTip =>
      '1.0 => 100% (Originalgröße), funktioniert nur auf der Serverseite Teil der Schrift, nicht empfohlen zu ändern.';

  @override
  String get times => 'x';

  @override
  String get trySudo => 'Versuche es mit sudo';

  @override
  String get sudoPromptNotFound =>
      'Aktuell wird kein sudo-Passwort-Prompt angezeigt.';

  @override
  String get updateServerStatusInterval =>
      'Aktualisierungsintervall des Serverstatus';

  @override
  String get useNoPwd => 'Es wird kein Passwort verwendet';

  @override
  String get usePodmanByDefault => 'Standardmäßige Verwendung von Podman';

  @override
  String get used => 'Gebraucht';

  @override
  String get view => 'Ansicht';

  @override
  String get viewDetails => 'Details anzeigen';

  @override
  String get virtKeyHelpClipboard =>
      'In die Zwischenablage kopieren, wenn das ausgewählte Terminal nicht leer ist, andernfalls den Inhalt der Zwischenablage in das Terminal einfügen.';

  @override
  String get virtKeyHelpIME => 'Tastatur ein-/ausschalten';

  @override
  String get virtKeyHelpSFTP => 'Aktuelles Verzeichnis in SFTP öffnen.';

  @override
  String get virtKeyHelpSnippet =>
      'Ein Snippet auswählen und in diesem Terminal ausführen.';

  @override
  String get virtKeyHelpTmux =>
      'Zwischen tmux-Sessions und -Fenstern wechseln.';

  @override
  String get virtKeyIntroActions => 'Kurzbefehle';

  @override
  String get virtKeyIntroActionsTip =>
      'Diese Tasten geben nichts ein, sondern öffnen etwas. Halte eine gedrückt, um zu lesen, was sie tut.';

  @override
  String get virtKeyIntroCustomizeTip =>
      'In den Terminal-Einstellungen lässt sich die Reihenfolge ändern oder ausblenden, was du nie brauchst.';

  @override
  String get virtKeyIntroModifiers => 'Modifikatoren';

  @override
  String get virtKeyIntroModifiersTip =>
      'Tippe eine an, um sie scharfzuschalten, und dann einen Buchstaben auf der Tastatur. Sie gilt für genau diese eine Taste.';

  @override
  String get virtKeyIntroNav => 'Navigation';

  @override
  String get virtKeyIntroNavTip =>
      'Diese Tasten bewegen den Cursor. Halte eine Pfeiltaste gedrückt, um sie zu wiederholen.';

  @override
  String get virtKeyIntroSelect =>
      'Solange das Terminal etwas zu scrollen hat, wählt seitliches Ziehen Text aus.';

  @override
  String get waitConnection =>
      'Bitte warte, bis die Verbindung hergestellt wurde.';

  @override
  String get wakeLock => 'Wach halten';

  @override
  String get watchNotPaired => 'Keine gekoppelte Apple Watch';

  @override
  String get webdavSettingEmpty => 'Webdav-Einstellungen sind leer';

  @override
  String get whenOpenApp => 'Beim Öffnen der App';

  @override
  String get wolTip =>
      'Nach der Konfiguration von WOL (Wake-on-LAN) wird jedes Mal, wenn der Server verbunden wird, eine WOL-Anfrage gesendet.';

  @override
  String get write => 'Schreiben';

  @override
  String get writeScriptFailTip =>
      'Das Schreiben des Skripts ist fehlgeschlagen, möglicherweise aufgrund fehlender Berechtigungen oder das Verzeichnis existiert nicht.';

  @override
  String get writeScriptTip =>
      'Nach der Verbindung mit dem Server wird ein Skript in `~/.config/server_box` \n | `/tmp/server_box` geschrieben, um den Systemstatus zu überwachen. Sie können den Skriptinhalt überprüfen.';

  @override
  String get menuGitHubRepository => 'GitHub-Repository';

  @override
  String get podmanDockerEmulationDetected =>
      'Podman Docker-Emulation erkannt. Bitte wechseln Sie in den Einstellungen zu Podman.';

  @override
  String get betaTip =>
      'Diese Funktion befindet sich noch in der Beta-Phase. Für die Funktionsfähigkeit wird nicht garantiert.';

  @override
  String get portForward_startPrompt =>
      'Füge eine Portweiterleitungsregel hinzu, um zu beginnen';

  @override
  String get portForward_localHost => 'Lokaler Host';

  @override
  String get portForward_localPort => 'Lokaler Port';

  @override
  String get portForward_remoteHost => 'Entfernter Host';

  @override
  String get portForward_remotePort => 'Entfernter Port';

  @override
  String portForward_deleteConfirmFmt(Object name) {
    return '$name löschen?';
  }

  @override
  String get sponsor => 'Sponsor';

  @override
  String get sortByJoinTime => 'Nach Hinzufügedatum';

  @override
  String get serverHistory => 'Serververlauf';

  @override
  String get portForwardBetaTitle => 'Port Forwarding (Beta)';

  @override
  String get tmuxAutoAttach => 'tmux automatisch verbinden';

  @override
  String get tmuxAuto => 'tmux automatisch';

  @override
  String get tmuxAutoTip =>
      'Beim Verbinden über SSH tmux automatisch starten oder anhängen';

  @override
  String get tmuxSessionSelector => 'Sitzungsauswahl';

  @override
  String get tmuxSessionSelectorTip =>
      'Beim Verbinden die Sitzungsauswahl anzeigen';

  @override
  String get tmuxDefaultSessionName => 'Standard-Sitzungsname';

  @override
  String get tmuxSessionName => 'Sitzungsname';

  @override
  String get tmuxExistingSessions => 'Vorhandene Sitzungen';

  @override
  String get tmuxNewSession => 'Neue Sitzung';

  @override
  String get tmuxWindows => 'Fenster';

  @override
  String get tmuxNewWindow => 'Neues Fenster';

  @override
  String get tmuxNoWindowsFound => 'Keine Fenster gefunden';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fenster',
      one: '1 Fenster',
    );
    return '$_temp0';
  }

  @override
  String tmuxPaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Panes',
      one: '1 Pane',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Verbunden';

  @override
  String get tmuxActive => 'Aktiv';

  @override
  String tmuxActiveAt(String time) {
    return 'aktiv: $time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return 'verbunden: $time';
  }

  @override
  String get tmuxSkip => 'Überspringen';

  @override
  String get tmuxNotAvailable => 'tmux ist nicht verfügbar';

  @override
  String containerSegmentsMismatch(int count) {
    return 'Unerwartete Anzahl von Segmenten in der Containerantwort: $count';
  }

  @override
  String get containerOperationInProgress =>
      'Ein anderer Container-Vorgang wird bereits ausgeführt';

  @override
  String get systemd => 'Systemd';

  @override
  String processCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Prozesse',
      one: '1 Prozess',
    );
    return '$_temp0';
  }

  @override
  String get processParseUnsupportedOutput =>
      'Das Format der Prozessliste wird nicht unterstützt.';

  @override
  String get processParseInvalidRows =>
      'Einige Prozesseinträge konnten nicht gelesen werden.';

  @override
  String get processParseInvalidWindowsJson =>
      'Die Windows-Prozessantwort konnte nicht gelesen werden.';

  @override
  String get processParseInvalidWindowsRows =>
      'Einige Windows-Prozesseinträge konnten nicht gelesen werden.';

  @override
  String get processKillTargetChanged =>
      'Der Prozess wurde geändert oder beendet. Aktualisieren Sie die Liste und versuchen Sie es erneut.';

  @override
  String get watchServers => 'Server auf der Watch';

  @override
  String get watchServersTip =>
      'Die Watch ruft diese Server selbst über deren monitor-Agent ab, daher lassen sich nur Server mit konfiguriertem monitor auswählen.';

  @override
  String get watchNoMonitorServer =>
      'Kein Server hat einen monitor-Agenten konfiguriert';

  @override
  String get watchLegacyUrls => 'Alte Status-URLs';

  @override
  String get accessoryWidgetServer => 'Server für Sperrbildschirm-Widget';

  @override
  String get systemdMissing => 'Kein systemd auf diesem Server';

  @override
  String get systemdMissingTip =>
      '`systemctl` ist hier nicht installiert, daher gibt es keine Units aufzulisten.';

  @override
  String initSystemFmt(String init) {
    return 'Dieser Rechner scheint $init zu verwenden.';
  }

  @override
  String get systemdListFailed => 'Units konnten nicht aufgelistet werden';

  @override
  String get systemdUserScopeMissing =>
      'Benutzer-Units werden nicht aufgelistet';

  @override
  String get systemdUserScopeMissingTip =>
      'Dieses Konto hat auf dem Server keinen Benutzer-Sitzungsbus, daher werden nur System-Units angezeigt.';

  @override
  String get serverUnreachable =>
      'Auf diesem Server konnte kein Befehl ausgeführt werden';

  @override
  String get containerNoRuntime => 'Keine Container-Laufzeitumgebung vorhanden';

  @override
  String get containerNoRuntimeTip =>
      'Weder `docker` noch `podman` hat auf diesem Rechner geantwortet. Falls eines davon für ein anderes Konto installiert ist, aktiviere „Versuche es mit sudo“ in den Einstellungen.';

  @override
  String get containerUnreadable =>
      'Die Container-Laufzeitumgebung hat in einem unerwarteten Format geantwortet';

  @override
  String get power => 'Energie';

  @override
  String get continueInTerminal => 'Im Terminal fortfahren';

  @override
  String get askAiRiskUnknown => 'Nicht eingestuft';

  @override
  String get agentLocalExec => 'Befehle auf diesem Gerät ausführen';

  @override
  String get agentLocalExecTip =>
      'Erlaubt dem Agent, auf dem Gerät zu arbeiten, auf dem ServerBox läuft, nicht nur auf Servern. Hier läuft nichts unbeaufsichtigt: Jeder Befehl muss geprüft werden.';

  @override
  String get agentLocalExecRootfsTip =>
      'Erlaubt dem Agent, auf diesem Gerät zu arbeiten, innerhalb des von ServerBox installierten Alpine-Linux-Containers. Er sieht weder das Dateisystem des Telefons noch die Daten der App oder Ihre Dateien. Jeder Befehl muss trotzdem geprüft werden.';

  @override
  String macDmgImportedPartly(String path) {
    return 'Die Daten der zuvor installierten Version wurden importiert. Heruntergeladene Dateien sind unter $path geblieben.';
  }

  @override
  String get bmcAccount => 'Konto';

  @override
  String get bmcAccountUnset =>
      'Keins ausgewählt – tippe, um eines zu wählen oder anzulegen';

  @override
  String bmcAccountShared(int count) {
    return 'Von $count Servern verwendet';
  }

  @override
  String get bmcAccounts => 'BMC-Konten';

  @override
  String get bmcAccountSharedTip => 'Eine Änderung hier gilt für alle davon.';

  @override
  String bmcAccountInUse(int count) {
    return '$count Server nutzen es. Sie behalten ihre Adresse und verlieren das Konto.';
  }
}
