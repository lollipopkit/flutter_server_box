// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appearanceSettings => 'Darstellung';

  @override
  String get appearancePreset => 'Designvorlage';

  @override
  String get appearanceThemeSchemaRange => 'Unterstütztes Theme-Schema';

  @override
  String get appearanceThemeInstall => 'Design installieren';

  @override
  String get appearanceThemeStore => 'Design-Store';

  @override
  String get appearanceInvalidTheme =>
      'Ungültiges Designpaket oder ungültiger Katalog';

  @override
  String get themeStoreRefreshFailed =>
      'Der Themenkatalog konnte nicht gelesen werden.';

  @override
  String themeStoreDeleteTheme(String name) {
    return '„$name“ löschen? Die Dateien werden von diesem Gerät entfernt. Ist es das verwendete Theme, kehrt die App zum Standard-Theme zurück.';
  }

  @override
  String appearanceThemeNeedsNewerApp(String version) {
    return 'Neuere App erforderlich: $version';
  }

  @override
  String get appearanceFontFamilies => 'Schriftfamilien der Oberfläche';

  @override
  String get appearanceFontFamiliesTip =>
      'Ein Name pro Zeile; Schriften werden der Reihe nach versucht.';

  @override
  String get appearanceFontImport =>
      'Schriftdatei für die Oberfläche importieren';

  @override
  String get appearanceGradient => 'Farbverlauf';

  @override
  String get appearanceNoBackground => 'Kein Hintergrund';

  @override
  String get appearanceIcons => 'Symbole in der App';

  @override
  String get appearanceCorners => 'Ecken';

  @override
  String get appearanceCardCorners => 'Kartenecken';

  @override
  String get appearanceTileCorners => 'Kachelecken';

  @override
  String get appearanceButtonCorners => 'Schaltflächenecken';

  @override
  String get crashCollect => 'Diagnosedaten';

  @override
  String get crashCollectIntro =>
      'ServerBox zeichnet während des Betriebs auf, was passiert, damit Probleme behoben werden können. Wählen Sie, wie viele Informationen gesendet werden.';

  @override
  String get crashCollectNone => 'Nichts';

  @override
  String get crashCollectNoneTip =>
      'Berichte bleiben auf diesem Gerät; nach einem Absturz können Sie manuell einen senden.';

  @override
  String get crashCollectBasic => 'Grundlegende Informationen';

  @override
  String get crashCollectBasicTip =>
      'Es werden nur Absturzinformationen erfasst; Protokoll- und Leistungsdaten sind nicht enthalten. **Damit helfen Sie uns, die App zu verbessern und Fehler zu beheben.**';

  @override
  String get crashCollectFull => 'Vollständige Informationen';

  @override
  String get crashCollectFullTip =>
      'Neben dem Absturzprotokoll werden Leistungsdaten und die Nutzung von Funktionen erfasst: **Damit lässt sich finden, was langsam ist und welche Funktionen tatsächlich genutzt werden.**';

  @override
  String get crashCollectFooter =>
      'Unabhängig von der Stufe werden bekannte Servernamen, -adressen und Benutzernamen bereits beim Aufzeichnen durch Platzhalter ersetzt. Die Erfassungsstufe kann später in den Einstellungen geändert werden.';

  @override
  String get privacy => 'Datenschutz';

  @override
  String get privacyPolicy => 'Datenschutzerklärung';

  @override
  String get crashLastRunFailed =>
      'ServerBox wurde beim letzten Ausführen unerwartet beendet.';

  @override
  String get crashReportTitle => 'Absturzbericht';

  @override
  String get crashReportHint =>
      'Dies ist das Protokoll des vorherigen Laufs. Bekannte Servernamen und -adressen wurden durch Platzhalter ersetzt, andere Angaben können jedoch verbleiben. Bitte lesen Sie es vor dem Absenden sorgfältig durch.';

  @override
  String get crashReportSubmit => 'Kopieren & melden';

  @override
  String get preReleaseUpdates => 'Vorabversions-Updates erhalten';

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
      'Domain oder vollständige URL. Der Pfad ergibt sich aus dem gewählten Protokoll.';

  @override
  String get askAiProtocolTip =>
      'Auto probiert Responses, dann Chat Completions.';

  @override
  String get askAiCommandInserted => 'Befehl ins Terminal eingefügt';

  @override
  String askAiConfigMissing(String fields) {
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
  String get remoteDesktop => 'Remotedesktop';

  @override
  String get askAiAgentWelcome => 'Was sollen wir auf diesem Server tun?';

  @override
  String get askAiAgentPromptHint =>
      'Bitte den Agenten, etwas zu prüfen oder zu beheben …';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Die ausgewählte Terminalausgabe analysieren und erklären, was passiert ist';

  @override
  String get askAiTerminalContext => 'Terminal-Kontext';

  @override
  String get askAiReviewNeeded => 'Prüfen';

  @override
  String get askAiReviewAction => 'Vorgeschlagenen Befehl prüfen';

  @override
  String get askAiReviewBeforeContinuing =>
      'Prüfe oder lehne den aktuellen Vorschlag zuerst ab';

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
  String get askAiResend => 'Resend';

  @override
  String get askAiResendTip =>
      'Alles nach dieser Nachricht wird verworfen: Antworten, Befehle und deren Ergebnisse.';

  @override
  String get askAiDeleteTip =>
      'Diese Nachricht und alles danach wird gelöscht: Antworten, Befehle und deren Ergebnisse.';

  @override
  String get askAiModelTable => 'Model table';

  @override
  String get askAiModelTableTip =>
      'Kontextgrößen nach Modellname von models.dev. Eine Version ist in der App enthalten; tippe, um eine neuere abzurufen.';

  @override
  String get askAiContextFallback => 'nicht in der Tabelle';

  @override
  String get askAiCompactAt => 'Summarise at';

  @override
  String get askAiCompactAtTip =>
      'Legt fest, wie voll der Modellkontext sein darf, bevor frühere Beiträge zusammengefasst werden. Eine frühe Zusammenfassung verliert eher Details; eine späte erhöht das Risiko, dass das Modell die Anfrage ablehnt.';

  @override
  String get askAiContextTokens => 'Context size';

  @override
  String get askAiContextTokensTip =>
      'Anzahl der Tokens, die dieses Modell aufnehmen kann. Automatisch sucht den Wert anhand des Modellnamens; gib eine Zahl an, wenn dein Anbieter ein kleineres Kontextfenster bereitstellt.';

  @override
  String get askAiConversationCompacted =>
      'Frühere Nachrichten wurden zusammengefasst, damit die Unterhaltung fortgesetzt werden kann.';

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
      'Dieser Befehl kann schwer rückgängig zu machende Änderungen bewirken. Prüfe ihn genau.';

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
      'Läuft nur, wenn Modell und lokale Prüfung ihn beide als lesend einstufen';

  @override
  String get askAiSendOnEnter => 'Enter sendet';

  @override
  String get askAiSendOnEnterTip =>
      'Enter sendet, Shift+Enter neue Zeile. Aus: Enter neue Zeile, Cmd/Strg+Enter sendet.';

  @override
  String get askAiApiKeyOptional =>
      'Leer lassen für lokal oder ohne Authentifizierung';

  @override
  String get askAiAllowInsecure => 'Unverschlüsseltes HTTP zulassen';

  @override
  String get askAiAllowInsecureTip =>
      'Erlaubt http://-Verbindungen zu selbst gehosteten Modellen an Adressen außerhalb von localhost. Der API-Schlüssel und etwaiger Terminalkontext werden unverschlüsselt übertragen; localhost ist nicht betroffen.';

  @override
  String get askAiInsecureEndpoint =>
      'Dieser Endpunkt verwendet http://. Aktiviere in den AI-Einstellungen „Unverschlüsseltes HTTP zulassen“, um ihn zu verwenden.';

  @override
  String get askAiHistory => 'Gesprächsverlauf';

  @override
  String get askAiNewConversation => 'Neues Gespräch';

  @override
  String get askAiNoHistory => 'Noch keine gespeicherten Unterhaltungen';

  @override
  String get askAiNoHistoryMessages => 'Noch keine Nachrichten';

  @override
  String get askAiUntitledConversation => 'Ohne Titel';

  @override
  String get askAiRenameConversation => 'Gespräch umbenennen';

  @override
  String get askAiDeleteConversationTitle => 'Dieses Gespräch löschen?';

  @override
  String get askAiDeleteConversationTip =>
      'Löscht sie von diesem Gerät. Nicht rückgängig zu machen.';

  @override
  String get askAiClearHistoryTitle => 'Agent-Verlauf dieses Servers löschen?';

  @override
  String get askAiClearHistoryTip =>
      'Alle gespeicherten Agent-Unterhaltungen dieses Servers werden gelöscht.';

  @override
  String get askAiRestoredReview =>
      'Dieser Befehl stammt aus dem Verlauf. Prüfe ihn erneut';

  @override
  String get agentWelcome => 'Was sollen wir auf deinen Servern tun?';

  @override
  String get agentWelcomeTip =>
      'Lass den Agent ein Problem untersuchen oder eine Aufgabe erledigen';

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
  String get agentToolFailed => 'Ausführung des Werkzeugs fehlgeschlagen.';

  @override
  String agentToolCallsFmt(int count) {
    return '$count Werkzeugaufrufe';
  }

  @override
  String get floatOverTabs => 'Über anderen Tabs schweben';

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
      'Der Agent will eine SSH-Verbindung. Gib das Passwort hier ein';

  @override
  String get agentAdHocSessions => 'Temporäre Verbindungen';

  @override
  String get agentSaveServerTitle => 'Als Server speichern';

  @override
  String get agentSaveServerTip =>
      'Dieser Host und das eingegebene Passwort werden auf diesem Gerät gespeichert';

  @override
  String get agentMonitorOptional => 'monitor-Agent (optional)';

  @override
  String get authFailTip =>
      'Authentifizierung fehlgeschlagen. Prüfe die Angaben';

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
  String get connectAll => 'Alle verbinden';

  @override
  String get disconnectAll => 'Alle trennen';

  @override
  String get distIcon => 'Distributions-Kennzeichen';

  @override
  String get distIconIntroLegal =>
      'Eine Marke sagt nur aus, was dieses Gerät vom entfernten System gelesen hat; das kann falsch oder veraltet sein und bezeichnet weder eine Ableitung noch einen Rebuild noch eine bestimmte Version. Lässt sie sich nicht bestimmen, wird ein schlichtes Symbol gezeichnet.\n\nJede Marke ist ein Warenzeichen ihres jeweiligen Inhabers und wird hier nur verwendet, um auf das System zu verweisen, das sie bezeichnet.';

  @override
  String get distIconTip =>
      'Neben jedem Server ein kleines Zeichen für das System anzeigen, das er offenbar ausführt';

  @override
  String get distNameMap => 'Namenszuordnung';

  @override
  String get distNameMapTip =>
      'Nur für eine Distribution, deren Datei dort, wo Sie die Marken ablegen, anders heißt. Der Schlüssel ist der Name, den diese App verwendet; der Wert ist der Name, der abgerufen werden soll. Lassen Sie es leer, solange keine Marke fehlt.';

  @override
  String get logoUrl => 'Logo-URL';

  @override
  String get logoUrlTip =>
      'Das große Bild oben auf der Seite eines Servers, in seinen eigenen Farben.';

  @override
  String get globe => 'Globus';

  @override
  String get locationTip =>
      'Wo dieser Server auf dem Globus gezeichnet wird. Breitengrad, dann Längengrad, in Grad — zum Beispiel 39.9042, 116.4074.';

  @override
  String get markUrl => 'Marken-URL';

  @override
  String get markUrlTip =>
      'Das kleine Zeichen neben dem Servernamen in Listen. Leer heißt: keins.\n\nNicht dasselbe Bild wie das Logo';

  @override
  String get navTabMenuTip =>
      'Tippe lange auf einen Tab – oder klicke ihn mit der rechten Maustaste an –, um alles darin auf einmal zu verbinden oder zu trennen.';

  @override
  String nTags(int count) {
    return '$count Tags';
  }

  @override
  String get remoteBackupPasswordRequired =>
      'Für entfernte Backups ist ein nicht leeres Backup-Passwort erforderlich';

  @override
  String get monitorHttpsRequired =>
      'Ein entfernter Monitor-Agent braucht HTTPS, sofern HTTP dafür nicht erlaubt ist.';

  @override
  String get monitorAllowInsecureHttp => 'HTTP erlauben';

  @override
  String get plainHttpTitle =>
      'Dieser Agent wird über unverschlüsseltes HTTP bereitgestellt';

  @override
  String get plainHttpTip =>
      'Das Passwort und alles, was diese App abruft, würde unverschlüsselt übertragen. Bisher wurde nichts gesendet.';

  @override
  String get allowForThisServer => 'Für diesen Server erlauben';

  @override
  String get viewError => 'Fehler ansehen';

  @override
  String get monitorAllowInsecureHttpTip =>
      'Nur in einem vertrauenswürdigen privaten Netz, das den Transport selbst verschlüsselt, etwa Tailscale';

  @override
  String monitorHttpTip(String url) {
    return 'Den Status dieses Servers über die HTTP-API eines **monitor**-Agenten lesen, statt Befehle über SSH auszuführen.\n\nDer Agent muss zuerst auf dem Server eingerichtet werden; Verläufe, die Watch-App und die Home-Widgets hängen davon ab.\n\n[Einen monitor-Agenten einrichten]($url)';
  }

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
  String icloudBackupStatusSummary(String lastModified, String remoteState) {
    return 'Letztes Backup: $lastModified\nStatus: $remoteState';
  }

  @override
  String get bgRun => 'Hintergrundaktualisierung';

  @override
  String get bgRunTip =>
      'Dieser Schalter bedeutet nur, dass die App versuchen wird, im Hintergrund zu laufen. Ob sie im Hintergrund laufen kann, hängt davon ab, ob die Berechtigungen aktiviert sind oder nicht. Bei nativem Android deaktivieren Sie bitte \"Batterieoptimierung\" in dieser App, und bei miui ändern Sie bitte die Energiesparrichtlinie auf \"Unbegrenzt\".';

  @override
  String get trayReadings => 'Messwerte';

  @override
  String get trayChart => 'Diagramm';

  @override
  String get trayChartNone => 'Keine';

  @override
  String get trayCompact => 'Kompakte Zeilen';

  @override
  String get trayCompactTip =>
      'Eine Zeile pro Server, ohne Diagramm. Linux verwendet immer ein einzeiliges Layout, da sein Panel-Menü über D-Bus übertragen wird, das ein Label statt eines benutzerdefinierten Layouts überträgt; das ausgewählte Diagramm kann jedoch als Bild eingebunden werden.';

  @override
  String get trayKeepRunning => 'Im Tray weiter ausführen';

  @override
  String get trayKeepRunningTip =>
      'Beim Schließen des Fensters bleibt die App in der Menüleiste oder im Infobereich aktiv und überwacht weiterhin Ihre Server. Deaktivieren Sie diese Option, damit der Schließen-Button die App beendet.';

  @override
  String get bgRunNeedsNotification =>
      'Das Laufen im Hintergrund braucht eine dauerhafte Benachrichtigung, und diese App hat keine Benachrichtigungsberechtigung. Zum Erlauben antippen.';

  @override
  String get clearAllStatsContent =>
      'Sind Sie sicher, dass Sie alle Server-Verbindungsstatistiken löschen möchten? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get clearAllStatsTitle => 'Alle Statistiken löschen';

  @override
  String clearServerStatsContent(String serverName) {
    return 'Sind Sie sicher, dass Sie die Verbindungsstatistiken für Server \"$serverName\" löschen möchten? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String clearServerStatsTitle(String serverName) {
    return '$serverName Statistiken löschen';
  }

  @override
  String get clearThisServerStats => 'Statistiken dieses Servers löschen';

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
  String get diskHealth => 'Festplattengesundheit';

  @override
  String get displayCpuIndex => 'Zeigen Sie den CPU-Index an';

  @override
  String dl2Local(String fileName) {
    return 'Datei \"$fileName\" herunterladen?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'Es gibt keine laufenden Container.\nDas könnte daran liegen:\n- Der Docker-Installationsbenutzer ist nicht mit dem in der App konfigurierten Benutzernamen identisch.\n- Die Umgebungsvariable DOCKER_HOST wurde nicht korrekt gelesen. Sie können sie ermitteln, indem Sie `echo \$DOCKER_HOST` im Terminal ausführen.';

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
  String fileTooLarge(String file, String size, String sizeMax) {
    return 'Datei \'$file\' ist zu groß $size, max $sizeMax';
  }

  @override
  String get fileDirGone => 'Dieser Ordner ist nicht mehr da';

  @override
  String get fileDirGoneTip => 'Es wurde gelöscht oder umbenannt';

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
  String get ignoreCert => 'Zertifikat ignorieren';

  @override
  String get image => 'Image';

  @override
  String get macDmgBody =>
      'Der App Store verlangt, dass diese App in einer Sandbox läuft, und eine Sandbox kann kein Terminal öffnen. Die DMG-Version kann es.\n\nDie App-Store-Version wird eventuell nicht mehr aktualisiert.';

  @override
  String get macDmgImportDenied =>
      'macOS ließ die Daten der vorherigen Version nicht lesen';

  @override
  String get macDmgImported => 'Daten der vorherigen Version importiert';

  @override
  String get macDmgImportFailed => 'Daten der vorherigen Version nicht lesbar';

  @override
  String get macDmgTip =>
      'Lokales Terminal und Snippets lokal ausführen (DMG-Version)';

  @override
  String get macDmgTitle => 'DMG-Build';

  @override
  String get showHiddenFiles => 'Versteckte Dateien anzeigen';

  @override
  String get sshKeyAlgorithm => 'Algorithmus';

  @override
  String get sshKeyComment => 'Kommentar';

  @override
  String get sshKeyGenerate => 'Schlüsselpaar erzeugen';

  @override
  String get sshKeyGenerating => 'Wird erzeugt…';

  @override
  String sshKeyLockedFmt(String name) {
    return 'Der private Schlüssel [$name] wurde nicht entsperrt.';
  }

  @override
  String get sshKeyPassphraseTip =>
      'Optional. Ein Schlüssel mit Passphrase wird verschlüsselt gespeichert und beim ersten Verbinden abgefragt.';

  @override
  String get sshKeyPassphraseWrong => 'Falsche Passphrase.';

  @override
  String get sshKeyPublicKey => 'Öffentlicher Schlüssel';

  @override
  String get sshKeyPublicKeyTip =>
      'Diese Zeile an ~/.ssh/authorized_keys auf dem Server anhängen.';

  @override
  String get sshKeyRecommended => 'Empfohlen';

  @override
  String sshKeyUnlockTip(String name) {
    return 'Passphrase für den privaten Schlüssel [$name] eingeben.';
  }

  @override
  String get ungrouped => 'Ohne Gruppe';

  @override
  String get containerReclaimable => 'Reclaimable';

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
  String get pruneDanglingImagesTip => 'Entfernt nur verwaiste Images.';

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
  String jumpServersNotFoundFmt(String serverName, String jumpIds) {
    return 'Jump-Server für $serverName nicht gefunden: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(String name) {
    return '„$name“ existiert bereits';
  }

  @override
  String get noJumpServerAvailable => 'Kein Jump-Server verfügbar.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Jump-Server und ProxyCommand können nicht zusammen verwendet werden.';

  @override
  String get noConnectionMethod =>
      'SSH, einen monitor-Agenten oder beides einrichten';

  @override
  String get preferredTransport => 'Zuerst versuchen';

  @override
  String get preferredTransportTip =>
      'Woher der Status gelesen wird und welche Verbindung ein Befehl zuerst öffnet. Die andere bleibt verfügbar.';

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
      'Mit welcher Shell ein Terminal startet. Leer stellt /bin/sh wieder her.';

  @override
  String get linuxNetTip =>
      'DNS-Server. Leer stellt die Standardwerte wieder her';

  @override
  String madeWithLove(String myGithub) {
    return 'Erstellt mit ❤️ von $myGithub';
  }

  @override
  String get maxConcurrency => 'Maximale Gleichzeitigkeit';

  @override
  String get maxRetryCount => 'Anzahl an Verbindungsversuchen';

  @override
  String mismatchSystem(String system) {
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
  String privateKeyNotFoundFmt(String keyId) {
    return 'Privater Schlüssel [$keyId] wurde nicht gefunden.';
  }

  @override
  String get bmcPowerOnAction => 'Einschalten';

  @override
  String get bmcShutdown => 'Herunterfahren';

  @override
  String get bmcForceOff => 'Hart ausschalten';

  @override
  String get restart => 'Neu starten';

  @override
  String get bmcPowerCycle => 'Strom aus und ein';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return 'An $server senden? Der Dienst wird um \"$resetType\" gebeten';
  }

  @override
  String get bmcPowerDone => 'Der Energiezustand hat sich geändert';

  @override
  String get bmcPowerAccepted =>
      'Angenommen, aber der Energiezustand hat sich nicht geändert. Ein sanfter Vorgang hängt vom Betriebssystem ab';

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
      'Noch nicht geprüft — tippen, um das Zertifikat zu sehen';

  @override
  String get bmcCertReview =>
      'Ein selbstsigniertes Zertifikat. Vergleiche es, bevor du es annimmst. Danach wird nur genau dieses vertraut.';

  @override
  String get bmcCertChanged => 'Das Zertifikat stimmt nicht überein. Prüfe es.';

  @override
  String get bmcCertExpired => 'Abgelaufen.';

  @override
  String bmcCertWas(String fingerprint) {
    return 'Zuvor angenommen: $fingerprint';
  }

  @override
  String get bmcAddrInvalid =>
      'Die BMC-Adresse muss eine URL sein, z. B. https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      'Diese Version läuft in einer Sandbox: der Befehl bekommt ein leeres Home, nicht deins, also scheitert alles, was ~/.ssh liest. Die DMG-Version nicht.';

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
  String get liveActivity => 'Live-Aktivität';

  @override
  String get liveActivityTip =>
      'Terminal-Sitzungen auf dem Sperrbildschirm und in der Dynamic Island anzeigen. Der Servername und der Verbindungsstatus sind dort ohne Entsperren sichtbar.';

  @override
  String get liveActivitySystemDisabled =>
      'iOS lässt derzeit keine zu. Die Schalter finden sich unter Einstellungen › ServerBox › Live-Aktivitäten und Einstellungen › Face ID & Code › Live-Aktivitäten.';

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
    String distro,
    String installed,
    String latest,
    String pm,
  ) {
    return '$distro $installed ist installiert, $latest ist verfügbar. Das Update ersetzt den ganzen Container: $pm-Daten gehen verloren';
  }

  @override
  String linuxSystemInUse(String name) {
    return 'Schließe die Terminals auf $name, bevor du es löschst';
  }

  @override
  String get rootfsSubtitle => 'Eine Linux-Userland-Umgebung auf diesem Gerät';

  @override
  String rootfsInstallTip(String distro, String version, int size) {
    return 'Lädt $distro $version (etwa $size MB) und entpackt es auf diesem Gerät.';
  }

  @override
  String get sameIdServerExist =>
      'Ein Server mit derselben ID existiert bereits';

  @override
  String get second => 's';

  @override
  String get serverFilesUnavailableTip =>
      'Braucht SSH zu diesem Server oder server_box_monitor mit aktivierter Datei-API.';

  @override
  String get back => 'Zurück';

  @override
  String get history => 'Verlauf';

  @override
  String get homeDir => 'Persönlicher Ordner';

  @override
  String selected(int count) {
    return '$count ausgewählt';
  }

  @override
  String get sendTo => 'Senden an …';

  @override
  String get serverFuncBtns => 'Server-Funktionsschaltflächen';

  @override
  String get serverOrder => 'Server-Bestellung';

  @override
  String get serverTabEmpty => 'Noch keine Server';

  @override
  String get serverTabRequired => 'Server-Tab kann nicht entfernt werden';

  @override
  String get shareCodeHint =>
      'Teilen Sie dem Empfänger diese Ziffern separat mit. Sie sind nicht im QR-Code enthalten.';

  @override
  String get shareCodePrompt => '6-stelliger Code';

  @override
  String get shareCodeTitle => 'Einmalcode';

  @override
  String get shareExpired =>
      'Diese Freigabe ist abgelaufen. Bitten Sie um eine neue.';

  @override
  String get shareImportFile => 'Aus einer geteilten Datei';

  @override
  String get shareImportTitle => 'Geteilten Server importieren';

  @override
  String get shareIncludesKey => 'Die Freigabe enthält den privaten Schlüssel.';

  @override
  String get shareOmittedBmc =>
      'BMC-Zugangsdaten. Die Adresse ist enthalten, die Zugangsdaten jedoch nicht.';

  @override
  String get shareOmittedJump =>
      'Der Jump-Server, da er auf diesem Gerät als separater Server gespeichert ist.';

  @override
  String get shareOmittedKeyPath =>
      'Die Schlüsseldatei, da ihr Pfad nur auf diesem Gerät gültig ist.';

  @override
  String get shareOmittedMissingKey =>
      'Der private Schlüssel, da er nicht im Schlüsselspeicher dieses Geräts vorhanden ist.';

  @override
  String get shareOmittedTip =>
      'Nicht enthalten; der Empfänger muss Folgendes konfigurieren:';

  @override
  String get sharePassphraseTip =>
      'Diese Passphrase verschlüsselt die Datei. Der Empfänger benötigt sie zum Importieren des Servers; sie kann nicht wiederhergestellt werden.';

  @override
  String shareQrTip(int minutes) {
    return 'Die Verbindungsdaten in diesem QR-Code sind verschlüsselt. Die Freigabe läuft in $minutes Minuten ab.';
  }

  @override
  String get shareScanQr => 'QR-Code scannen';

  @override
  String shareServerExists(String name) {
    return '„$name“ auf diesem Gerät verwendet bereits diese Adresse. Trotzdem importieren?';
  }

  @override
  String get shareTooBigForQr =>
      'Zu groß für einen QR-Code. Teilen Sie den Server stattdessen als Datei.';

  @override
  String get shareTooNew =>
      'Diese Freigabe wurde mit einer neueren Version von ServerBox erstellt. Aktualisieren Sie die App, um sie zu öffnen.';

  @override
  String get shareUnreadable => 'Dies ist keine gültige ServerBox-Freigabe.';

  @override
  String get shareVia => 'Teilen über';

  @override
  String get sftpDlPrepare => 'Verbindung vorbereiten...';

  @override
  String get sftpEditorTip =>
      'Leer nutzt den eingebauten Editor. Zum Beispiel `vim` (empfohlen: aus `EDITOR` lesen).';

  @override
  String get sftpRmrDirSummary =>
      'Verwenden Sie \"rm -r\", um das Verzeichnis in SFTP zu löschen.';

  @override
  String get sftpSSHConnected => 'SFTP Verbunden';

  @override
  String get sftpShowFoldersFirst => 'Ordner zuerst anzeigen';

  @override
  String get sftpUnavailableUseScp =>
      'Wenn dieser Host kein SFTP-Subsystem hat, wie es bei vielen eingebetteten Geräten der Fall ist, stell die Dateiübertragung in den Servereinstellungen auf SCP.';

  @override
  String get sshFileTransportTip =>
      'SFTP passt für alles Aktuelle. SCP ist für alte oder eingebettete Hosts, deren SSH-Server kein SFTP-Subsystem hat: es braucht den Befehl `scp` und eine Shell, die auch die üblichen Datei-Werkzeuge mitbringt (`find`, `stat`, `mv`, `chmod`).';

  @override
  String get specifyDev => 'Gerät angeben';

  @override
  String get specifyDevTip =>
      'Der Netzwerkverkehr zählt standardmäßig alle Geräte; hier eines angeben';

  @override
  String get tempIsCelsiusTip =>
      'Wenn aktiviert, wird der Temperaturwert als Celsius statt als Millicelsius behandelt. Nur einschalten, wenn die Temperatur falsch angezeigt wird (z. B. 0,1 °C statt 58 °C).';

  @override
  String spentTime(String time) {
    return 'Benötigte Zeit: $time';
  }

  @override
  String sshConfigAllExist(int duplicateCount) {
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
  String sshConfigDuplicatesSkipped(int duplicateCount) {
    return '$duplicateCount Duplikate werden übersprungen';
  }

  @override
  String get sshConfigFound =>
      'Wir haben SSH-Konfiguration auf Ihrem System gefunden.';

  @override
  String sshConfigFoundServers(int totalCount) {
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
  String sshConfigImported(int count) {
    return '$count Server aus SSH-Konfiguration importiert';
  }

  @override
  String sshHostKeyChangedDesc(String serverName) {
    return 'Der SSH-Hostschlüssel für $serverName hat sich geändert. Fahren Sie nur fort, wenn Sie diesem Server vertrauen.';
  }

  @override
  String get sshHostKeyType => 'SSH-Hostschlüsseltyp';

  @override
  String get sshKnownHostKeys => 'Bekannte Hosts';

  @override
  String get sshKnownHostKeysTip =>
      'Die Host-Schlüssel, die diese App akzeptiert hat';

  @override
  String sshHostKeyNewDesc(String serverName) {
    return 'Ein neuer SSH-Hostschlüssel wurde von $serverName empfangen. Prüfen Sie den Fingerabdruck, bevor Sie vertrauen.';
  }

  @override
  String sshHostKeyStoredFingerprint(String fingerprint) {
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
  String sshConfigServersToImport(int importCount) {
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
  String switchTo(String val) {
    return 'Wechseln zu $val';
  }

  @override
  String get syncAppSettings => 'App-Einstellungen synchronisieren';

  @override
  String get syncAppSettingsTip =>
      'Design, Layout, Editor, Terminal und weitere Geräteeinstellungen in die automatische Synchronisierung einbeziehen.';

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
  String get virtKeyRows => 'Gleichzeitig sichtbare Zeilen';

  @override
  String get virtKeyRowsTip =>
      'Der Rest liegt auf einer eigenen Seite, die zur Seite gewischt wird.';

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
  String portForward_deleteConfirmFmt(String name) {
    return '$name löschen?';
  }

  @override
  String get sponsor => 'Sponsor';

  @override
  String get sortByJoinTime => 'Nach Hinzufügedatum';

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
  String get processSearchHint => 'Name, Benutzer oder PID';

  @override
  String processShowKernelThreads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kernel-Threads anzeigen',
      one: '1 Kernel-Thread anzeigen',
    );
    return '$_temp0';
  }

  @override
  String get processForceKill => 'Force kill';

  @override
  String get processStarted => 'Started';

  @override
  String get processThreads => 'Threads';

  @override
  String get watchServers => 'Server auf der Watch';

  @override
  String get watchServersTip =>
      'Die Uhr holt die Daten selbst vom Monitor, daher sind nur Server mit einem wählbar.';

  @override
  String get watchNoMonitorServer =>
      'Kein Server hat einen monitor-Agenten konfiguriert';

  @override
  String get legacyStatusGoneTitle => 'Status-URLs funktionieren nicht mehr';

  @override
  String get legacyStatusGoneBody =>
      'Die Watch-App und die Home-Widgets lasen eine von Hand eingetragene `/status`-Adresse. Dieser Endpunkt ist entfallen: Er konnte nur aktuelle Werte als Text liefern, weshalb dort nie ein Diagramm möglich war.\n\nSie lesen jetzt die authentifizierte API des monitor-Agenten, zeichnen Verläufe und halten sich selbst mit der App im Einklang. Den Server einmal in der App einrichten, und jede Watch und jedes Widget übernimmt ihn.';

  @override
  String get services => 'Dienste';

  @override
  String get status => 'Status';

  @override
  String get enable => 'Aktivieren';

  @override
  String get disable => 'Deaktivieren';

  @override
  String get starting => 'Wird gestartet';

  @override
  String get stopping => 'Wird gestoppt';

  @override
  String get serviceManagerUnsupported => 'Nicht unterstützter Dienstmanager';

  @override
  String get serviceManagerUnsupportedTip =>
      'Dieser Server verwendet einen Dienstmanager, den ServerBox noch nicht unterstützt. Unterstützt werden systemd, procd und OpenRC.';

  @override
  String serviceManagerFmt(String manager) {
    return 'Verwaltet von $manager';
  }

  @override
  String get serviceListFailed => 'Dienste konnten nicht aufgelistet werden';

  @override
  String get serviceDetailsUnavailable =>
      'Einige Dienstdetails sind nicht verfügbar';

  @override
  String get serviceDetailsUnavailableTip =>
      'Die Dienstliste kann verwendet werden, aber der Manager hat nicht alle Status- oder Autostartinformationen geliefert.';

  @override
  String get systemdUserScopeMissing =>
      'Benutzer-Units werden nicht aufgelistet';

  @override
  String get systemdUserScopeMissingTip =>
      'Dieses Konto hat auf dem Server keinen Benutzer-Sitzungsbus, daher werden nur System-Units angezeigt.';

  @override
  String get serviceSearchHint => 'Unit name';

  @override
  String get serviceNeedsAttention => 'Needs attention';

  @override
  String serviceOtherUnits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weitere Units',
      one: '1 weitere Unit',
    );
    return '$_temp0';
  }

  @override
  String get serviceUnit => 'Unit';

  @override
  String get serviceUnitType => 'Type';

  @override
  String get serviceScope => 'Scope';

  @override
  String get serviceStartup => 'Startup';

  @override
  String serviceUpFor(String duration) {
    return 'up $duration';
  }

  @override
  String serviceDownFor(String duration) {
    return 'down $duration';
  }

  @override
  String serviceNextIn(String duration) {
    return 'next $duration';
  }

  @override
  String serviceStoppedAgo(String duration) {
    return 'Vor $duration beendet';
  }

  @override
  String serviceExitStatus(int code) {
    return 'Exit-Status $code';
  }

  @override
  String get serviceFullJournal => 'Full journal';

  @override
  String get serviceUnitFile => 'Unit file';

  @override
  String serviceJournalRecent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Letzte $count Zeilen',
      one: 'Letzte Zeile',
    );
    return '$_temp0';
  }

  @override
  String get serviceJournalUnreadable =>
      'Dieses Konto kann das Journal nicht lesen';

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
  String get fan => 'Lüfter';

  @override
  String get clockSpeed => 'Takt';

  @override
  String get vendor => 'Hersteller';

  @override
  String get continueInTerminal => 'Im Terminal fortfahren';

  @override
  String get askAiRiskUnknown => 'Nicht eingestuft';

  @override
  String get agentLocalExec => 'Befehle auf diesem Gerät ausführen';

  @override
  String get agentLocalExecTip =>
      'Lässt den Agent auf dem Rechner arbeiten, auf dem ServerBox läuft. Auch lesende Befehle werden geprüft';

  @override
  String get agentLocalExecRootfsTip =>
      'Lässt den Agent lokal arbeiten, begrenzt auf den von ServerBox installierten Linux-Container';

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

  @override
  String get bmcStaleWrite =>
      'Der BMC hat sich während des Schreibens geändert. Bitte erneut versuchen.';

  @override
  String get send => 'Senden';

  @override
  String get privacyBlur => 'Datenschutz im Hintergrund';

  @override
  String get privacyBlurTip => 'App-Inhalt in der App-Übersicht verbergen';

  @override
  String get floatReturnToTab => 'Zum Tab zurück';

  @override
  String get termInFloatWindow => 'Dieses Terminal ist im schwebenden Fenster';

  @override
  String get globeEnabledTip =>
      'Server auf einem Globus zeichnen, dort wo ihre Adressen liegen. Aus entfernt die Schaltfläche und beendet jede Abfrage.';

  @override
  String get geoShardsConsentAttribution =>
      'IP-Geolokalisierung von [DB-IP](https://db-ip.com), CC BY 4.0.';

  @override
  String get geoMissPrivate => 'Private Adresse';

  @override
  String get geoMissNoData => 'Keine Standortdaten';

  @override
  String get globeGuide =>
      'Hier tippen, um die Server auf einem Globus dort zu sehen, wo ihre Adressen liegen.';

  @override
  String get publicIp => 'Öffentliche IP';

  @override
  String get geoData => 'Daten auf Stadtebene';

  @override
  String get geoDataTip =>
      'Nach dem Download verwenden alle Standortabfragen die auf diesem Gerät gespeicherten Daten. Weder Serveradressen noch Abfrageaktivitäten werden an den Download-Dienst übertragen.';

  @override
  String get geoDataMissing => 'Nicht heruntergeladen';

  @override
  String get geoDataUnreachable => 'Die Daten konnten nicht geholt werden.';

  @override
  String get geoDataRemoveFailed => 'Die Daten konnten nicht gelöscht werden.';

  @override
  String geoDataCurrent(String month) {
    return '$month ist bereits installiert.';
  }

  @override
  String geoDataConsent(String download, String disk) {
    return '**Download: $download · Gerätespeicher: $disk.** Der vollständige Datensatz wird auf diesem Gerät gespeichert; alle späteren Standortabfragen erfolgen lokal. Weder Serveradressen noch Abfrageaktivitäten werden an den Download-Dienst übertragen.\n\nMonatlich aktualisiert. Eine neuere Version ersetzt die installierten Daten, ohne eine zusätzliche Kopie zu behalten. Sie können die Daten jederzeit löschen.';
  }

  @override
  String get benchmark => 'Benchmark';

  @override
  String get benchmarkIntro =>
      'Führt Yet Another Bench Script auf diesem Server aus und testet Datenträger, Netzwerk und CPU. Ein vollständiger Durchlauf dauert 10–20 Minuten und läuft weiter, wenn Sie diese Seite verlassen oder die App schließen.';

  @override
  String get benchmarkNoRuns => 'Noch keine Benchmarks.';

  @override
  String get benchmarkRunning => 'Benchmark läuft';

  @override
  String get benchmarkStartFailed => 'Benchmark konnte nicht gestartet werden';

  @override
  String get benchmarkCancelConfirm =>
      'Diesen Benchmark beenden? Alle bisherigen Messergebnisse gehen verloren.';

  @override
  String get benchmarkDeleteConfirm => 'Dieses Benchmark-Ergebnis löschen?';

  @override
  String get benchmarkNothingSelected =>
      'Alle Testphasen sind deaktiviert. Es werden nur Systeminformationen erfasst; dies dauert wenige Sekunden.';

  @override
  String get benchmarkDiskTip =>
      'fio mit vier Blockgrößen; etwa 3 Minuten. Schreibt eine 2-GB-Testdatei in das Arbeitsverzeichnis und benötigt entsprechend viel freien Speicherplatz.';

  @override
  String get benchmarkNetworkTip =>
      'iperf3 gegen öffentliche Server; etwa 4 Minuten.';

  @override
  String get benchmarkReducedNetwork => 'Weniger Standorte';

  @override
  String benchmarkReducedNetworkTip(String full, String reduced) {
    return 'Drei statt sieben Standorte. Der Datenverkehr sinkt von etwa $full auf $reduced.';
  }

  @override
  String get benchmarkCpuTip =>
      'Lädt Geekbench, ein proprietäres Programm, herunter und **veröffentlicht das Ergebnis auf einer öffentlichen Seite bei geekbench.com** – einschließlich CPU-Modell, Kernanzahl und Arbeitsspeicher.';

  @override
  String get benchmarkSensitiveOptions =>
      'Die folgenden Optionen laden Software von Drittanbietern auf diesen Server herunter und führen sie aus oder senden Serverinformationen an Dritte. Sie sind standardmäßig deaktiviert.';

  @override
  String get benchmarkIpInfoTip =>
      'Sendet die öffentliche Adresse dieses Servers über unverschlüsseltes HTTP an ip-api.com.';

  @override
  String get benchmarkIpInfo => 'IP-Inhaber ermitteln';

  @override
  String get benchmarkPreferBin => 'fio und iperf3 herunterladen';

  @override
  String get benchmarkPreferBinTip =>
      'Lädt die Programme von GitHub herunter, statt die Pakete des Hosts zu verwenden. Nur aktivieren, wenn keines der beiden Programme auf dem Host installiert ist.';

  @override
  String get benchmarkWorkDir => 'Arbeitsverzeichnis';

  @override
  String get benchmarkWorkDirTip =>
      'Legt fest, welches Dateisystem der Datenträgertest misst. Leer bedeutet das Home-Verzeichnis des Anmeldekontos.';

  @override
  String benchmarkEstimatedTime(int minutes) {
    return 'Etwa $minutes Min.';
  }

  @override
  String benchmarkEstimatedTraffic(String size) {
    return 'Etwa $size Datenverkehr';
  }

  @override
  String get benchmarkPhaseSystem => 'Systeminformationen werden gelesen';

  @override
  String get benchmarkPhaseDisk => 'Datenträger wird getestet';

  @override
  String get benchmarkPhaseNetwork => 'Netzwerk wird getestet';

  @override
  String get benchmarkPhaseCpu => 'CPU wird getestet';

  @override
  String get benchmarkPhaseDone => 'Abschluss';

  @override
  String get benchmarkResultUnreadable =>
      'Dieses Ergebnis konnte nicht als JSON gelesen werden. Der Rohtext steht unten.';

  @override
  String get benchmarkViewOnGeekbench => 'Auf Geekbench ansehen';

  @override
  String get benchmarkGeekbenchPublic =>
      'Dieses Ergebnis ist unter dem obigen Link öffentlich verfügbar.';

  @override
  String get benchmarkSingleCore => 'Einzelkern';

  @override
  String get benchmarkMultiCore => 'Mehrkern';

  @override
  String get benchmarkIops => 'IOPS';

  @override
  String get benchmarkSend => 'Upload';

  @override
  String get benchmarkRecv => 'Download';

  @override
  String get benchmarkLatency => 'Latenz';

  @override
  String get benchmarkVirt => 'Virtualisierung';

  @override
  String get benchmarkRawLog => 'Ausführungsprotokoll';

  @override
  String benchmarkUpstream(String version) {
    return 'Bereitgestellt von Yet Another Bench Script ($version)';
  }

  @override
  String get benchmarkPhaseStarting => 'Wird gestartet';

  @override
  String get benchmarkNoOutputYet =>
      'Noch keine Ausgabe. Vor der ersten Zeile prüft YABS, ob google.com und icanhazip.com erreichbar sind. In Netzwerken, die eine der beiden Websites blockieren, kann dies mehrere Minuten dauern.';

  @override
  String get tagsEmptyTip =>
      'Noch keine Tags. Füge beim Bearbeiten eines Servers einen hinzu, dann erscheint er hier.';

  @override
  String get benchmarkNoServers =>
      'Füge zuerst einen Server hinzu und kehre dann zurück, um ihn zu benchmarken.';

  @override
  String get schemaTooNewTitle => 'Diese Daten sind neuer als die App';

  @override
  String schemaTooNewBody(int stored, int supported) {
    return 'Die Daten wurden von einer neueren Version von ServerBox geschrieben (Speicherversion v$stored); diese Version kann bis v$supported lesen. Es wurde nichts geändert.';
  }

  @override
  String get schemaTooNewReinstall =>
      'Installiere die neuere Version erneut, dann werden alle Daten wie zuvor geöffnet.';

  @override
  String get schemaTooNewExportPlain => 'Ohne Passwort exportieren';

  @override
  String get schemaTooNewPlainWarn =>
      'Die Datei enthält alle privaten SSH-Schlüssel, Serverpasswörter und API-Schlüssel im Klartext. Wer die Datei erhält, erhält Zugriff auf alle diese Daten.';

  @override
  String get schemaTooNewWipe => 'Alle Daten löschen';

  @override
  String get schemaTooNewWipeConfirm =>
      'Alle Server, Schlüssel, Snippets und Einstellungen auf diesem Gerät werden gelöscht. Das kann nicht rückgängig gemacht werden. Eine hier exportierte Sicherung wäre die einzige verbleibende Kopie.';

  @override
  String get schemaTooNewWipeDone =>
      'Daten gelöscht. Öffne die App erneut, um neu zu beginnen.';

  @override
  String get schemaTooNewWipeFailed =>
      'Ein Teil der Daten konnte nicht gelöscht werden, und diese Version kann die verbleibenden Daten weiterhin nicht öffnen. Installiere die neuere Version erneut, um darauf zuzugreifen.';

  @override
  String get systemUsers => 'Users';

  @override
  String get userManagerLinuxOnly =>
      'Die Systembenutzerverwaltung unterstützt derzeit nur Linux-Server.';

  @override
  String get userRegularAccount => 'Regular';

  @override
  String get userCurrentAccount => 'Current account';

  @override
  String get userSystemAccount => 'System account';

  @override
  String get userUid => 'UID';

  @override
  String get userLoginStatus => 'Status';

  @override
  String get userLoginEnabled => 'Login enabled';

  @override
  String get userDetailAccount => 'Account';

  @override
  String get userDetailSecurity => 'Security';

  @override
  String get userSshKeys => 'SSH keys';

  @override
  String get userExpires => 'Expires';

  @override
  String get userNever => 'Never';

  @override
  String get userPasswordSet => 'Set';

  @override
  String get userPasswordLocked => 'Locked';

  @override
  String get userPasswordNone => 'None';

  @override
  String get userSuperuser => 'Superuser';

  @override
  String get userOpenShell => 'Open shell';

  @override
  String get userRootChangesWarning =>
      'Änderungen an root gelten sofort für alle Sitzungen.';

  @override
  String get userComment => 'Comment';

  @override
  String get userPrimaryGroup => 'Primary group';

  @override
  String get userSupplementaryGroups => 'Zusätzliche Gruppen';

  @override
  String get userLoginShell => 'Login shell';

  @override
  String get userCreateHome => 'Home-Verzeichnis erstellen';

  @override
  String get userMoveHome =>
      'Vorhandenes Home-Verzeichnis beim Ändern des Pfads verschieben';

  @override
  String get userRemoveHome => 'Home-Verzeichnis entfernen';

  @override
  String get userPasswordCreateTip =>
      'Lass das Passwort leer, um ein Konto mit gesperrter Passwortanmeldung zu erstellen.';

  @override
  String get userPasswordEditTip =>
      'Lass das Passwort leer, um das vorhandene Passwort beizubehalten.';

  @override
  String funcUnavailableFmt(String func) {
    return '$func ist über die Verbindung dieses Servers nicht verfügbar.';
  }

  @override
  String get rangeLive => 'Live';

  @override
  String get diskIo => 'Datenträger-E/A';

  @override
  String get peak => 'Spitze';

  @override
  String get hardware => 'Hardware';

  @override
  String get cores => 'Kerne';

  @override
  String get historyNoStored =>
      'Nur ein Monitor-Agent speichert den Verlauf. Diese Verbindung behält nur, was die App seit dem Verbinden gesehen hat.';

  @override
  String get noHistoryYet => 'Noch nichts gemessen';

  @override
  String get noData => 'keine Daten';

  @override
  String get from => 'Von';

  @override
  String get to => 'Bis';

  @override
  String get beyondRetention => 'weiter zurück als dieser Agent aufbewahrt';

  @override
  String agentRetentionFmt(String kept) {
    return 'Agent behält $kept';
  }

  @override
  String oldestSampleFmt(String time) {
    return 'älteste Messung $time';
  }

  @override
  String get rangeEndsBeforeItStarts =>
      'Das Ende des Bereichs muss nach seinem Anfang liegen.';

  @override
  String get samples => 'Messungen';

  @override
  String get unavailable => 'nicht verfügbar';

  @override
  String get metricUnavailableTip =>
      'Der Rest dieser Seite ist nicht betroffen. Prüfen Sie den zugehörigen Befehl auf dem Host.';

  @override
  String get waitingFirstSample => 'Warten auf die erste Messung';

  @override
  String atTimeFmt(String time) {
    return 'um $time';
  }

  @override
  String get stored => 'gespeichert';

  @override
  String lastSampleFmt(String ago) {
    return 'letzte Messung $ago';
  }

  @override
  String staleSinceFmt(String ago, String time) {
    return 'Alles darunter stammt von $time, $ago.';
  }

  @override
  String noDataBeforeFmt(String time) {
    return 'keine Daten vor $time';
  }

  @override
  String loadingRangeFmt(String range) {
    return '$range wird geladen…';
  }

  @override
  String noStoredHistoryFor(String metric) {
    return 'Kein gespeicherter Verlauf für $metric';
  }

  @override
  String devicesFmt(int count) {
    return '$count Geräte';
  }

  @override
  String devicesBusiestFmt(int count, String name) {
    return '$count Geräte · $name am stärksten ausgelastet';
  }

  @override
  String devicesPlottedFmt(int plotted, int total) {
    return '$plotted von $total Geräten';
  }

  @override
  String sensorsHottestFmt(int count, String name) {
    return '$count Sensoren · $name am heißesten';
  }

  @override
  String get oneDeviceAtLeast => 'Mindestens ein Gerät bleibt im Diagramm.';

  @override
  String shownOfFmt(int shown, int total, String what) {
    return '$shown von $total $what';
  }

  @override
  String countOfFmt(int count, String what) {
    return '$count $what';
  }

  @override
  String get unitDevices => 'Geräten';

  @override
  String get unitSensors => 'Sensoren';

  @override
  String get unitBatteries => 'Akkus';

  @override
  String get unitCommands => 'Befehlen';

  @override
  String get unitReadings => 'Messwerten';

  @override
  String get unitGpus => 'GPUs';

  @override
  String get hottest => 'am heißesten';

  @override
  String get oldest => 'am ältesten';

  @override
  String get notApplicable => 'nicht zutreffend';

  @override
  String get attributes => 'Attribute';

  @override
  String get powerOnHours => 'Betriebsstunden';

  @override
  String get powerCycles => 'Einschaltvorgänge';

  @override
  String get lifeLeft => 'Restlebensdauer';

  @override
  String get lifetimeWrite => 'Gesamt geschrieben';

  @override
  String get lifetimeRead => 'Gesamt gelesen';

  @override
  String get averageErase => 'Durchschnittliche Löschungen';

  @override
  String get unsafeShutdowns => 'Unsaubere Abschaltungen';

  @override
  String get diskAllPassed => 'alle PASSED';

  @override
  String diskWarningFmt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Warnungen',
      one: '1 Warnung',
    );
    return '$_temp0';
  }

  @override
  String diskWrongOfFmt(int total, int wrong) {
    return '$wrong von $total Geräten';
  }

  @override
  String get diskSmartSortedTip => 'Schlechteste zuerst';

  @override
  String readAgoFmt(String ago) {
    return 'gelesen $ago';
  }

  @override
  String processesFmt(int count) {
    return '$count Prozesse';
  }

  @override
  String diskFailingFmt(int count) {
    return '$count fehlerhaft';
  }

  @override
  String get diskSmartOpenTip => 'Für die Attribute antippen';

  @override
  String get cycle => 'Zyklen';

  @override
  String get window => 'Zeitfenster';

  @override
  String ofFmt(String total) {
    return 'von $total';
  }

  @override
  String get serverDetailCards => 'Karten der Detailseite';

  @override
  String get connection => 'Verbindung';

  @override
  String get connectionTip =>
      'Beide können gleichzeitig an sein. Die Reihenfolge ist die Reihenfolge, in der gewählt wird.';

  @override
  String transportOrderFmt(String first, String second) {
    return 'Zum Ändern der Reihenfolge ziehen. $first wird zuerst gewählt; antwortet es nicht, trägt $second die Sitzung allein.';
  }

  @override
  String transportOnlyFmt(String name) {
    return 'Nur $name ist an, es gibt also nichts, worauf ausgewichen werden könnte.';
  }

  @override
  String get transportNoneOn =>
      'Beide sind aus — dieser Server kann nicht verbunden werden.';

  @override
  String get transportOffKept =>
      'aus — Einstellungen bleiben, wird nie gewählt';

  @override
  String get transportDialledFirst => 'zuerst gewählt';

  @override
  String get transportFallback => 'Ausweichweg';

  @override
  String get transportOnlyMethod => 'einziger Weg';

  @override
  String get transportOff => 'aus';

  @override
  String get thisDevice => 'Dieses Gerät';

  @override
  String get localServerTip =>
      'Liest dieses Gerät direkt aus, indem das Statusskript hier ausgeführt wird. SSH und Monitor HTTP werden nicht verwendet; ihre Einstellungen bleiben erhalten.';

  @override
  String get localServerUnsupported =>
      'Auf dieser Plattform kann dieses Gerät nicht als Server gelesen werden. Linux, Windows und die macOS-DMG-Version unterstützen es.';

  @override
  String get remoteDesktopIntro =>
      'Öffnet den RDP- oder VNC-Desktop eines Servers in der App. Die Verbindung läuft über die SSH-Verbindung des Servers oder seinen Monitor-Agent, daher muss der Desktop-Port nicht aus dem Netzwerk erreichbar sein.';

  @override
  String get remoteDesktopIntroProfiles =>
      'Speichere ein Profil pro Desktop über die Schaltfläche „Remotedesktop“ eines Servers oder über den Tab „Remotedesktop“.';

  @override
  String get localServerIntro =>
      'Füge das Gerät, auf dem ServerBox läuft, als Server hinzu. Status, Prozesse, Dienste, Container, Terminal und Dateien funktionieren ohne SSH oder Monitor-Agent.';

  @override
  String get localServerAdd => 'Dieses Gerät hinzufügen';

  @override
  String get localServerIntroFooter =>
      'Das lässt sich auch später auf der Bearbeitungsseite eines Servers unter „Verbindung“ einschalten.';

  @override
  String get transportSectionOff =>
      'Aus. Die Felder darunter bleiben erhalten, bis Sie es wieder einschalten.';

  @override
  String get monitorAgent => 'Monitor-Agent';

  @override
  String get plainHttpEditTip =>
      'Zugangsdaten und Messwerte gehen unverschlüsselt über das Netz. Beschränken Sie das auf ein LAN oder eine Tailscale-Adresse, oder stellen Sie den Agenten hinter TLS.';

  @override
  String get behaviour => 'Verhalten';

  @override
  String get optional => 'Optional';

  @override
  String get optionalTip =>
      'Nichts hiervon ist zum Verbinden nötig. Öffnen Sie eines, und seine Felder übernehmen das Formular.';

  @override
  String get sshAdvanced => 'SSH erweitert';

  @override
  String get sshAdvancedTip =>
      'Ausweichziel, ProxyCommand, Sprungserver, Dateiübertragung, entfernter Pfad';

  @override
  String get sshLegacyAlgorithms => 'Veraltete Algorithmen';

  @override
  String get sshLegacyAlgorithmsTip =>
      'Für alte SSH-Server wie Router oder Switches, die nur einen SHA-1-`ssh-rsa`-Host-Schlüssel oder einen SHA-1-Schlüsselaustausch anbieten. Weniger sicher; nur für Hosts aktivieren, die dies benötigen.';

  @override
  String get appearanceAndPlace => 'Darstellung & Ort';

  @override
  String get appearanceAndPlaceTip => 'Logo, Koordinaten';

  @override
  String get statusCollection => 'Statuserfassung';

  @override
  String get statusCollectionTip =>
      'Welche Befehle laufen, eigene Befehle, welches Gerät gelesen wird';

  @override
  String get tagAllTags => 'Alle Tags';

  @override
  String get tagMatching => 'Treffer';

  @override
  String get tagNewHint => 'Neuer Tag';

  @override
  String tagCreateFmt(String tag) {
    return '#$tag erstellen';
  }

  @override
  String get tagOnThisServer => 'auf diesem Server';

  @override
  String tagServersFmt(int count) {
    return '$count Server';
  }

  @override
  String tagOnThisServerFmt(int count) {
    return '$count auf diesem Server';
  }

  @override
  String get tagMatchesTyped => 'passt zur Eingabe';

  @override
  String get tagEditorTip =>
      'Die Eingabe filtert die Liste; die Schaltfläche erstellt den Tag und setzt ihn in einem Schritt auf diesen Server. Das Stiftsymbol benennt ihn auf jedem Server um, der ihn trägt. Ein Tag, den kein Server trägt, verschwindet beim Speichern.';

  @override
  String get tagRenamesOnSave => 'Umbenennungen gelten beim Speichern';

  @override
  String get scheduledTasks => 'Scheduled tasks';

  @override
  String get scheduledTaskLinuxOnly =>
      'Die Verwaltung geplanter Aufgaben unterstützt derzeit nur Linux-Server.';

  @override
  String get scheduledTaskUnavailable =>
      'crontab ist auf diesem Server nicht verfügbar.';

  @override
  String get scheduledTaskPreserveTip =>
      'Kommentare, Umgebungsvariablen und nicht erkannte Zeilen in dieser crontab bleiben erhalten.';

  @override
  String get scheduledTaskSchedule => 'Schedule';

  @override
  String get scheduledTaskAdd => 'Add task';

  @override
  String get scheduledTaskNextRun => 'Next run';

  @override
  String scheduledTaskNextInFmt(String time) {
    return 'in $time';
  }

  @override
  String get scheduledTaskEnabled => 'Enabled';

  @override
  String get scheduledTaskCommentedOut => 'Commented out';

  @override
  String scheduledTaskSummaryFmt(int enabled, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total Aufgaben',
      one: '1 Aufgabe',
    );
    return '$_temp0 · $enabled aktiviert';
  }

  @override
  String get scheduledTaskFilterHint => 'Filter tasks';

  @override
  String get scheduledTaskPreserved => 'Preserved lines';

  @override
  String get scheduledTaskRaw => 'Raw crontab';

  @override
  String get scheduledTaskEnableNow => 'Enable now';

  @override
  String get scheduledTaskEnableNowTip =>
      'Wenn deaktiviert, wird die Zeile auskommentiert gespeichert.';

  @override
  String scheduledTaskEmptyFmt(String user) {
    return 'Keine geplanten Aufgaben für $user. Was hier hinzugefügt wird, wird in die crontab dieses Kontos geschrieben.';
  }

  @override
  String get scheduledTaskFieldMinute => 'Minute';

  @override
  String get scheduledTaskFieldHour => 'Hour';

  @override
  String get scheduledTaskFieldDayOfMonth => 'Day of month';

  @override
  String get scheduledTaskFieldMonth => 'Month';

  @override
  String get scheduledTaskFieldDayOfWeek => 'Day of week';

  @override
  String get cronErrScheduleEmpty => 'Ein Zeitplan ist erforderlich.';

  @override
  String get cronErrCommandEmpty => 'Ein Befehl ist erforderlich.';

  @override
  String get cronErrLineBreak =>
      'Eine crontab-Zeile darf keine Zeilenumbrüche enthalten.';

  @override
  String get cronErrMacro =>
      'Ein Makro besteht aus einem Wort, zum Beispiel @reboot.';

  @override
  String get cronErrFieldCount =>
      'Ein cron-Zeitplan hat fünf Felder oder ein Makro wie @reboot.';

  @override
  String get cronAtBoot => 'At boot';

  @override
  String get cronEveryMin => 'Every minute';

  @override
  String cronEveryMinsFmt(int minutes) {
    return 'Alle $minutes Minuten';
  }

  @override
  String cronHourlyAtFmt(String minute) {
    return 'Stündlich um :$minute';
  }

  @override
  String cronEveryHoursFmt(int hours) {
    return 'Alle $hours Stunden';
  }

  @override
  String cronEveryHoursAtFmt(int hours, String minute) {
    return 'Alle $hours Stunden um :$minute';
  }

  @override
  String cronDailyAtFmt(String time) {
    return 'Täglich um $time';
  }

  @override
  String cronWeekdaysAtFmt(String time) {
    return 'Werktags um $time';
  }

  @override
  String cronWeekdayAtFmt(String day, String time) {
    return 'Jeden $day um $time';
  }

  @override
  String cronMonthlyAtFmt(int day, String time) {
    return 'Am $day. jedes Monats um $time';
  }

  @override
  String get monitorSettings => 'Monitor settings';

  @override
  String get monitorAgentDefault => 'Agent default';

  @override
  String get monitorNeedsRestart =>
      'Wird nach einem Neustart des Agents wirksam';

  @override
  String get monitorCollection => 'Collection';

  @override
  String get extendedInterval => 'Intervall der erweiterten Erfassung';

  @override
  String get idlePause => 'Pausieren, wenn kein Client abfragt';

  @override
  String get idlePauseTip =>
      'Die erweiterte Erfassung führt smartctl, sensors und amd-smi aus. Eine Pause ohne aktive Client-Abfrage verhindert, dass ein Datenträger für ungelesene Daten aufgeweckt wird.';

  @override
  String get idlePauseThreshold => 'Idle after';

  @override
  String get monitorAlerts => 'Alerts';

  @override
  String get monitoringRules => 'Alert rules';

  @override
  String get ruleMonitorType => 'Metric';

  @override
  String get ruleThreshold => 'Threshold';

  @override
  String get ruleMatcher => 'Matcher';

  @override
  String get ruleTip =>
      'Messwert: cpu / memory / swap / disk / network / temperature. Ziel: cpu0 für einen Kern, used / free / avail für Speicher, rx / tx für Netzwerk; disk und temperature ignorieren dieses Feld. Schwellenwert: Vergleichsoperator und Wert, etwa >=80%, >=70c oder >10m/s.';

  @override
  String get pushChannels => 'Benachrichtigungskanäle';

  @override
  String get pushType => 'Type';

  @override
  String get pushRate => 'Rate limit';

  @override
  String get pushHeaders => 'Headers';

  @override
  String get pushSecretSet => 'Auf dem Agent gesetzt, nicht angezeigt';

  @override
  String get pushSecretKeep => 'Leer lassen, um den Wert beizubehalten';

  @override
  String get pushTestTip =>
      'Sendet eine Benachrichtigung mit den hier angezeigten Einstellungen über diesen Kanal, unabhängig davon, ob sie gespeichert sind.';

  @override
  String get pushTestSent => 'Der Kanal hat die Benachrichtigung angenommen';

  @override
  String get pushTestFailed => 'Der Kanal hat die Benachrichtigung abgelehnt';

  @override
  String get pushTestMessage => 'Testbenachrichtigung von ServerBox Monitor';

  @override
  String get pushUnknownType =>
      'Dieser Agent kann über diesen Kanaltyp nicht senden, daher werden seine Einstellungen nicht angezeigt. Er kann hier entfernt oder in der config.toml des Agents bearbeitet werden.';

  @override
  String get pushJsonInvalid => 'ist kein gültiges JSON';

  @override
  String get dataRetention => 'Data retention';

  @override
  String get dataRetentionTip =>
      'Wenn deaktiviert, löscht der Agent nichts und seine Datenbank wächst unbegrenzt.';

  @override
  String get retentionMetrics => 'Keep metrics';

  @override
  String get retentionAlerts => 'Keep alerts';

  @override
  String get retentionCleanup => 'Bereinigungsintervall';

  @override
  String get retentionMaxDbSize => 'Maximale Datenbankgröße';

  @override
  String get corsOrigins => 'Zulässige CORS-Ursprünge';

  @override
  String get corsOriginsTip =>
      'Ursprünge, von denen ein Browser-Panel diesen Agent aufrufen darf. Leer bedeutet, dass nur derselbe Ursprung zulässig ist.';

  @override
  String get monitorNoRemoteAccess =>
      'Dieser Agent ist nur für die Überwachung eingerichtet. Hier können Sie kein Terminal öffnen, keine Befehle ausführen und keine Dateien durchsuchen. Aktivieren Sie diese Funktionen unter [remote_access] in der config.toml des Agenten.';

  @override
  String get alerts => 'Warnungen';

  @override
  String get online => 'online';

  @override
  String get densityCards => 'Karten';

  @override
  String get densityRows => 'Zeilen';

  @override
  String get densityGrid => 'Raster';

  @override
  String get connect => 'Verbinden';

  @override
  String get disconnect => 'Trennen';

  @override
  String get searchServerTip =>
      'Sucht nach Namen und Adressen – den beiden Angaben, nach denen der Editor zuerst fragt.';

  @override
  String get addServerTip =>
      'Fülle eines aus, scanne einen QR-Code oder importiere eine Datei, die jemand geteilt hat.';

  @override
  String get move => 'Verschieben';

  @override
  String get moveToTop => 'Nach ganz oben';

  @override
  String get moveToBottom => 'Nach ganz unten';

  @override
  String get groupByTag => 'Nach Tag gruppieren';

  @override
  String get groupByTagTip => 'Tags werden im Editor des Servers gesetzt.';

  @override
  String get connecting => 'Verbinden…';

  @override
  String get authShort => 'Auth';

  @override
  String get remoteDesktopFitToWindow => 'An Fenster anpassen';

  @override
  String get remoteDesktopActualSize => 'Tatsächliche Größe';

  @override
  String get remoteDesktopZoom => 'Vergrößerung';

  @override
  String get remoteDesktopViewOnly => 'Nur Ansicht';

  @override
  String get remoteDesktopDisableViewOnly => 'Nur Ansicht deaktivieren';

  @override
  String get remoteDesktopSendClipboardText => 'Text aus Zwischenablage senden';

  @override
  String get remoteDesktopShowKeyboard => 'Tastatur anzeigen';

  @override
  String get remoteDesktopMoreControls => 'Weitere Steuerelemente';

  @override
  String get remoteDesktopUseDirectPointer => 'Direkten Zeiger verwenden';

  @override
  String get remoteDesktopUseTouchpadPointer => 'Touchpad-Zeiger verwenden';

  @override
  String get remoteDesktopSendCtrlAltDelete => 'Strg+Alt+Entf senden';

  @override
  String get remoteDesktopReconnect => 'Erneut verbinden';

  @override
  String get remoteDesktopFullScreen => 'Vollbild';

  @override
  String get remoteDesktopCloseSession => 'Sitzung schließen';

  @override
  String get remoteDesktopConnected => 'Verbunden';

  @override
  String get remoteDesktopConnecting => 'Verbindung wird hergestellt';

  @override
  String get remoteDesktopReconnecting => 'Verbindung wird wiederhergestellt';

  @override
  String get remoteDesktopDisconnected => 'Getrennt';

  @override
  String get remoteDesktopGuideTouch => 'Touchpad';

  @override
  String get remoteDesktopGuideTouchTip =>
      'Ein Finger bewegt den Zeiger wie ein Touchpad, Tippen klickt. Mit zwei Fingern tippen für Rechtsklick, mit zwei Fingern ziehen zum Scrollen, Finger spreizen zum Zoomen. Zweimal tippen und den Finger liegen lassen, um zu ziehen.';

  @override
  String get remoteDesktopGuideKeyboardTip =>
      'Öffnet die Bildschirmtastatur. Die Eingabe wird an den Remote-Desktop gesendet.';

  @override
  String get remoteDesktopGuideViewOnlyTip =>
      'Zeiger und Tasten werden nicht mehr gesendet, damit Sie sich umsehen können, ohne versehentlich zu klicken.';

  @override
  String get remoteDesktopGuideMoreTip =>
      'Strg+Alt+Entf, Neu verbinden und Vollbild finden Sie hier.';

  @override
  String get remoteDesktopGuidePointerTip =>
      'Ebenso den direkten Zeiger, bei dem ein Finger dort klickt, wo er tippt.';

  @override
  String get remoteDesktopVncClipboardLatin1Only =>
      'Die VNC-Zwischenablage unterstützt nur Latin-1-Text.';

  @override
  String get remoteDesktopAddProfile => 'Profil hinzufügen';

  @override
  String get remoteDesktopNoProfiles => 'Keine Remotedesktop-Profile';

  @override
  String get remoteDesktopAdd => 'Remotedesktop hinzufügen';

  @override
  String get remoteDesktopEdit => 'Remotedesktop bearbeiten';

  @override
  String get remoteDesktopTargetTip =>
      'Das Ziel wird über den SSH-Server oder den Monitor-Agent aufgelöst. localhost meint diese Maschine.';

  @override
  String get remoteDesktopDomain => 'Domäne (optional)';

  @override
  String get remoteDesktopPassword => 'Passwort (optional)';

  @override
  String get remoteDesktopSavePassword => 'Passwort speichern';

  @override
  String get remoteDesktopSavePasswordTip =>
      'Wird in der verschlüsselten Datenbank gespeichert. Backups enthalten gespeicherte Passwörter und sind nur verschlüsselt, wenn ein Backup-Passwort gesetzt ist.';

  @override
  String get remoteDesktopShareSession => 'Sitzung teilen';

  @override
  String get remoteDesktopProtocol => 'Protokoll';

  @override
  String get remoteDesktopUniqueName =>
      'Profilnamen müssen für diesen Server eindeutig sein.';

  @override
  String get remoteDesktopVncPasswordLength =>
      'Klassische VNC-Passwörter sind auf 8 ASCII-Bytes begrenzt.';

  @override
  String get remoteDesktopNameRequired => 'Geben Sie einen Profilnamen ein.';

  @override
  String get remoteDesktopHostRequired => 'Geben Sie einen Ziel-Host ein.';

  @override
  String get remoteDesktopPortRequired => 'Geben Sie einen gültigen Port ein.';

  @override
  String get remoteDesktopUsernameRequired =>
      'Geben Sie den RDP-Benutzernamen ein.';

  @override
  String get remoteDesktopVncPasswordAscii =>
      'Klassische VNC-Passwörter dürfen nur ASCII-Zeichen enthalten.';

  @override
  String get remoteDesktopCertificateRequired =>
      'Bestätigung des Zertifikats erforderlich';

  @override
  String get remoteDesktopWaiting => 'Warte auf Desktop…';

  @override
  String get remoteDesktopCertificateChanged =>
      'Zertifikat des Remotedesktops hat sich geändert';

  @override
  String get remoteDesktopTrustCertificate => 'Zertifikat vertrauen?';

  @override
  String get remoteDesktopCertificateChangedTip =>
      'Der Fingerabdruck des Zertifikats stimmt nicht mehr mit dem gespeicherten Wert überein. Prüfen Sie den neuen Fingerabdruck, bevor Sie das Vertrauen ersetzen.';

  @override
  String get remoteDesktopCertificateUnverifiedTip =>
      'Das System konnte dieses Zertifikat nicht verifizieren. Prüfen Sie seinen SHA-256-Fingerabdruck, bevor Sie fortfahren.';

  @override
  String get remoteDesktopReplaceTrust => 'Vertrauen ersetzen';

  @override
  String get remoteDesktopTrustReconnect => 'Vertrauen und neu verbinden';

  @override
  String remoteDesktopDeleteProfile(String name) {
    return 'Remotedesktop-Profil „$name“ löschen?';
  }

  @override
  String remoteDesktopReconnectAttempt(int attempt) {
    return 'Verbindung wird wiederhergestellt ($attempt/3)…';
  }

  @override
  String remoteDesktopPreviousCertificate(String fingerprint) {
    return 'Zuvor vertraut\n$fingerprint';
  }

  @override
  String remoteDesktopCertificateSubject(String subject) {
    return 'Subjekt: $subject';
  }

  @override
  String remoteDesktopCertificateIssuer(String issuer) {
    return 'Aussteller: $issuer';
  }

  @override
  String remoteDesktopCertificateValidity(String start, String end) {
    return 'Gültig: $start – $end';
  }

  @override
  String appearanceThemeModeLocked(String mode) {
    return 'Dieses Theme unterstützt nur $mode. Wähle ein anderes Theme, um den Modus zu ändern.';
  }
}
