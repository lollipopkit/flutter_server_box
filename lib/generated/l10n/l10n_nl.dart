// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get acceptBeta => 'Accepteer testversie-updates';

  @override
  String get addSystemPrivateKeyTip =>
      'Er is momenteel geen privésleutel, wilt u degene toevoegen die bij het systeem wordt geleverd (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Toegevoegd aan takenlijst';

  @override
  String get askAi => 'AI vragen';

  @override
  String get askAiAwaitingResponse => 'Wachten op AI-reactie...';

  @override
  String get askAiEndpointTip =>
      'Een domein of volledige URL. Het pad volgt uit het gekozen protocol.';

  @override
  String get askAiProtocolTip =>
      'Auto probeert Responses, daarna Chat Completions.';

  @override
  String get askAiCommandInserted => 'Commando in terminal ingevoegd';

  @override
  String askAiConfigMissing(Object fields) {
    return 'Configureer $fields in de instellingen.';
  }

  @override
  String get askAiDisclaimer => 'AI kan fouten maken. Gebruik het zorgvuldig.';

  @override
  String get askAiInsertTerminal => 'In terminal invoegen';

  @override
  String get askAiNoResponse => 'Geen reactie';

  @override
  String get askAiAgentWelcome => 'Wat gaan we op deze server doen?';

  @override
  String get askAiAgentPromptHint =>
      'Vraag de agent om iets te onderzoeken of te herstellen...';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Analyseer de geselecteerde terminaluitvoer en leg uit wat er gebeurde';

  @override
  String get askAiTerminalContext => 'Terminalcontext';

  @override
  String get askAiReviewNeeded => 'Beoordelen';

  @override
  String get askAiReviewAction => 'Voorgesteld commando beoordelen';

  @override
  String get askAiReviewBeforeContinuing =>
      'Beoordeel of weiger eerst de huidige suggestie';

  @override
  String get askAiApproveRun => 'Goedkeuren en uitvoeren';

  @override
  String get askAiDecline => 'Weigeren';

  @override
  String get askAiActionDeclined => 'Het voorgestelde commando is geweigerd.';

  @override
  String get askAiInterrupted => 'Het antwoord van de agent is onderbroken.';

  @override
  String get askAiRiskReadOnly => 'Alleen lezen';

  @override
  String get askAiRiskCaution => 'Wijzigt het systeem';

  @override
  String get askAiRiskUnvetted => 'Niet-geverifieerde host';

  @override
  String get askAiRiskDestructive => 'Hoog risico';

  @override
  String get askAiHighRiskConfirmTitle => 'Commando met hoog risico uitvoeren?';

  @override
  String get askAiHighRiskConfirmBody =>
      'Dit commando kan wijzigingen maken die lastig terug te draaien zijn. Controleer het goed.';

  @override
  String get askAiNoCommandOutput => 'Commando voltooid zonder uitvoer.';

  @override
  String get askAiOutputTruncated =>
      'Lange uitvoer is ingekort voordat die naar de agent terugging.';

  @override
  String get askAiAutoApproved => 'Automatisch goedgekeurd';

  @override
  String get askAiAutoRunSafeCommands =>
      'Alleen-lezen commando\'s automatisch uitvoeren';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Draait alleen als model én lokale controle het alleen-lezen noemen';

  @override
  String get askAiSendOnEnter => 'Enter verstuurt';

  @override
  String get askAiSendOnEnterTip =>
      'Enter verstuurt, Shift+Enter nieuwe regel. Uit: Enter nieuwe regel, Cmd/Ctrl+Enter verstuurt.';

  @override
  String get askAiApiKeyOptional =>
      'Leeg laten voor lokaal of zonder authenticatie';

  @override
  String get askAiHistory => 'Gespreksgeschiedenis';

  @override
  String get askAiNewConversation => 'Nieuw gesprek';

  @override
  String get askAiNoHistory => 'Nog geen opgeslagen gesprekken';

  @override
  String get askAiNoHistoryMessages => 'Nog geen berichten';

  @override
  String get askAiUntitledConversation => 'Naamloos';

  @override
  String get askAiRenameConversation => 'Gesprek hernoemen';

  @override
  String get askAiDeleteConversationTitle => 'Dit gesprek verwijderen?';

  @override
  String get askAiDeleteConversationTip =>
      'Verwijdert het van dit apparaat. Kan niet ongedaan worden gemaakt.';

  @override
  String get askAiClearHistoryTitle =>
      'Agentgeschiedenis van deze server wissen?';

  @override
  String get askAiClearHistoryTip =>
      'Alle opgeslagen Agent-gesprekken van deze server worden verwijderd.';

  @override
  String get askAiRestoredReview =>
      'Dit commando komt uit de geschiedenis. Beoordeel het opnieuw';

  @override
  String get agentWelcome => 'Wat gaan we op je servers doen?';

  @override
  String get agentWelcomeTip =>
      'Laat de Agent een probleem onderzoeken of een taak uitvoeren';

  @override
  String get agentPromptHint =>
      'Vraag de agent om je servers te onderzoeken of te bedienen...';

  @override
  String get agentNoHistory => 'Geen opgeslagen globale agentgesprekken';

  @override
  String get agentClearHistoryTitle => 'Globale agentgeschiedenis wissen?';

  @override
  String get agentClearHistoryTip =>
      'Alle globale agentgesprekken worden van dit apparaat verwijderd.';

  @override
  String get agentToolShell => 'Shell';

  @override
  String get agentToolReadFile => 'Bestand lezen';

  @override
  String get agentToolWriteFile => 'Bestand schrijven';

  @override
  String get agentToolFailed => 'Uitvoeren van het hulpmiddel is mislukt.';

  @override
  String agentToolCallsFmt(Object count) {
    return '$count hulpmiddelaanroepen';
  }

  @override
  String get agentFloat => 'Boven andere tabbladen zweven';

  @override
  String get agentToolSshConnect => 'SSH verbinden';

  @override
  String get agentToolSshDisconnect => 'SSH verbreken';

  @override
  String get agentSshConnectTitle => 'Met een nieuwe host verbinden';

  @override
  String get agentAuthMethod => 'Authenticatie';

  @override
  String get agentSshConnectTip =>
      'De Agent wil een SSH-verbinding. Voer het wachtwoord hier in';

  @override
  String get agentAdHocSessions => 'Tijdelijke verbindingen';

  @override
  String get agentSaveServerTitle => 'Als server opslaan';

  @override
  String get agentSaveServerTip =>
      'Deze host en het ingevoerde wachtwoord worden op dit apparaat bewaard';

  @override
  String get agentMonitorOptional => 'monitor-agent (optioneel)';

  @override
  String get authFailTip => 'Authenticatie mislukt. Controleer de gegevens';

  @override
  String get autoBackupConflict =>
      'Er kan slechts één automatische back-up tegelijk worden ingeschakeld.';

  @override
  String get autoConnect => 'Automatisch verbinden';

  @override
  String get autoRun => 'Automatisch uitvoeren';

  @override
  String get autoUpdateHomeWidget => 'Automatische update van home-widget';

  @override
  String get availableTabs => 'Beschikbare tabbladen';

  @override
  String get backupEncrypted => 'Back-up is versleuteld';

  @override
  String get backupNotEncrypted => 'Back-up is niet versleuteld';

  @override
  String get backupPassword => 'Back-up wachtwoord';

  @override
  String get backupPasswordRemoved => 'Back-up wachtwoord verwijderd';

  @override
  String get backupPasswordSet => 'Back-up wachtwoord ingesteld';

  @override
  String get backupPasswordTip =>
      'Stel een wachtwoord in om back-upbestanden te versleutelen. Laat leeg om versleuteling uit te schakelen.';

  @override
  String get backupPasswordWrong => 'Onjuist back-up wachtwoord';

  @override
  String get connectAll => 'Alles verbinden';

  @override
  String get disconnectAll => 'Alles verbreken';

  @override
  String get distIcon => 'Distributiemarkeringen';

  @override
  String get distIconConsent =>
      'Alleen om aan te geven welke distributie een server mogelijk draait.';

  @override
  String get distIconIntroLegal =>
      'Een merkteken zegt alleen wat dit apparaat van het externe systeem heeft gelezen; dat kan onjuist of verouderd zijn en duidt geen afgeleide, herbouw of specifieke versie aan. Kan het niet worden vastgesteld, dan wordt een neutraal pictogram getekend.\n\nElk merkteken is een handelsmerk van de betreffende eigenaar en wordt hier alleen gebruikt om te verwijzen naar het systeem dat het aanduidt.';

  @override
  String get distIconTip =>
      'Toon naast elke server een klein teken van het systeem dat er lijkt te draaien';

  @override
  String get distNameMap => 'Naamtoewijzing';

  @override
  String get distNameMapTip =>
      'Alleen voor een distributie waarvan het bestand anders heet op de plek waar u de merktekens host. De sleutel is de naam die deze app gebruikt; de waarde is de naam die opgehaald wordt. Laat het leeg zolang er geen merkteken ontbreekt.';

  @override
  String get logoUrl => 'Logo-URL';

  @override
  String get logoUrlTip =>
      'De grote afbeelding boven aan de pagina van een server, in de eigen kleuren.';

  @override
  String get markUrl => 'Merkteken-URL';

  @override
  String get markUrlTip =>
      'Het kleine teken naast een servernaam in lijsten. Leeg betekent geen.\n\nNiet dezelfde afbeelding als het logo';

  @override
  String get navTabMenuTip =>
      'Houd een tabblad ingedrukt — of klik er met rechts op — om alles erin in één keer te verbinden of te verbreken.';

  @override
  String nTags(Object count) {
    return '$count tags';
  }

  @override
  String get remoteBackupPasswordRequired =>
      'Externe back-ups vereisen een niet-leeg back-upwachtwoord';

  @override
  String get monitorHttpsRequired =>
      'Een externe monitor-agent vereist HTTPS, tenzij HTTP is toegestaan.';

  @override
  String get monitorAllowInsecureHttp => 'HTTP toestaan';

  @override
  String get monitorAllowInsecureHttpTip =>
      'Alleen op een vertrouwd privénetwerk dat het transport zelf versleutelt, zoals Tailscale';

  @override
  String get backupTip =>
      'De geëxporteerde gegevens kunnen worden versleuteld met een wachtwoord. \nBewaar deze aub veilig.';

  @override
  String get icloudBackupStatusTitle => 'Back-upstatus';

  @override
  String get icloudBackupStatusLoading => 'iCloud-back-upstatus laden...';

  @override
  String get icloudBackupStatusError =>
      'Kan de metadata van de iCloud-back-up niet lezen';

  @override
  String get icloudBackupStatusEmpty =>
      'Nog geen iCloud-back-upbestand gevonden';

  @override
  String get icloudBackupStateUploading => 'Uploaden';

  @override
  String get icloudBackupStateConflict => 'Conflict gevonden';

  @override
  String get icloudBackupStateUploaded => 'Geüpload';

  @override
  String get icloudBackupStateWaiting => 'Wacht op iCloud';

  @override
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return 'Laatste back-up: $lastModified\nStatus: $remoteState';
  }

  @override
  String get bgRun => 'Uitvoeren op de achtergrond';

  @override
  String get bgRunTip =>
      'Deze schakelaar betekent alleen dat het programma zal proberen op de achtergrond uit te voeren, of het in de achtergrond kan worden uitgevoerd, hangt af van of de toestemming is ingeschakeld of niet. Voor native Android, schakel \"Batterijoptimalisatie\" uit in deze app, en voor miui, wijzig de energiebesparingsbeleid naar \"Onbeperkt\".';

  @override
  String get clearAllStatsContent =>
      'Weet u zeker dat u alle serververbindingsstatistieken wilt wissen? Deze actie kan niet ongedaan worden gemaakt.';

  @override
  String get clearAllStatsTitle => 'Alle statistieken wissen';

  @override
  String clearServerStatsContent(Object serverName) {
    return 'Weet u zeker dat u de verbindingsstatistieken voor server \"$serverName\" wilt wissen? Deze actie kan niet ongedaan worden gemaakt.';
  }

  @override
  String clearServerStatsTitle(Object serverName) {
    return 'Statistieken van $serverName wissen';
  }

  @override
  String get clearThisServerStats => 'Statistieken van deze server wissen';

  @override
  String get compactDatabase => 'Database comprimeren';

  @override
  String compactDatabaseContent(Object size) {
    return 'Databasgrootte: $size\n\nDit zal de database opnieuw organiseren om de bestandsgrootte te verkleinen. Geen gegevens worden verwijderd.';
  }

  @override
  String get closeAfterSave => 'Opslaan en sluiten';

  @override
  String get collapseUITip =>
      'Of lange lijsten in de UI standaard moeten worden ingeklapt';

  @override
  String get connectionDetails => 'Verbindingsdetails';

  @override
  String get connectionStats => 'Verbindingsstatistieken';

  @override
  String get connectionStatsDesc =>
      'Bekijk server verbindingssucces ratio en geschiedenis';

  @override
  String get containerTrySudoTip =>
      'Bijvoorbeeld: in de app is de gebruiker ingesteld op aaa, maar Docker is geïnstalleerd onder de rootgebruiker. In dit geval moet u deze optie inschakelen.';

  @override
  String get containerSudoPasswordRequired =>
      'Een sudo-wachtwoord is vereist om toegang te krijgen tot Docker. Voer uw wachtwoord in.';

  @override
  String get containerSudoPasswordIncorrect =>
      'Het sudo-wachtwoord is onjuist of niet toegestaan. Probeer het opnieuw.';

  @override
  String get copyPath => 'Pad kopiëren';

  @override
  String get cpuViewAsProgressTip =>
      'Toon het gebruik van elke CPU in een voortgangsbalkstijl (oude stijl)';

  @override
  String get customCmd => 'Aangepaste opdrachten';

  @override
  String get deleteServers => 'Servers batchgewijs verwijderen';

  @override
  String get deleteDirRecursive => 'De map en alles erin verwijderen';

  @override
  String get desktopTerminalTip =>
      'Opdracht die wordt gebruikt om de terminalemulator te openen bij het starten van SSH-sessies.';

  @override
  String get dirEmpty => 'Zorg ervoor dat de map leeg is.';

  @override
  String get discoverSshServers => 'SSH-servers ontdekken';

  @override
  String get discoveryFailed => 'Ontdekking mislukt';

  @override
  String get discoverySettings => 'Ontdekkingsinstellingen';

  @override
  String get distro => 'Distributie';

  @override
  String distroSwitchTip(Object from, Object to) {
    return '$from vervangen door $to. Alles wat in $from is geïnstalleerd wordt verwijderd, en $to wordt in plaats daarvan gedownload en uitgepakt.';
  }

  @override
  String get diskHealth => 'Schijfgezondheid';

  @override
  String get displayCpuIndex => 'Toon de CPU-index';

  @override
  String dl2Local(Object fileName) {
    return 'Download $fileName naar lokaal?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'Er zijn geen actieve containers.\nDit kan komen doordat:\n- De Docker-installatiegebruiker niet overeenkomt met de gebruikersnaam die is geconfigureerd binnen de app.\n- De omgevingsvariabele DOCKER_HOST is niet correct gelezen. U kunt deze krijgen door `echo \$DOCKER_HOST` in de terminal uit te voeren.';

  @override
  String dockerImagesFmt(Object count) {
    return '$count afbeeldingen';
  }

  @override
  String get dockerProjectOther => 'Overig';

  @override
  String get dockerPruneTip =>
      'Verwijder ongebruikte gegevens om schijfruimte vrij te maken';

  @override
  String get dockerStatistics => 'Docker-statistieken';

  @override
  String get doubleColumnMode => 'Dubbele kolommodus';

  @override
  String get doubleColumnTip =>
      'Deze optie schakelt alleen de functie in, of deze daadwerkelijk kan worden ingeschakeld, hangt af van de breedte van het apparaat';

  @override
  String get editVirtKeys => 'Virtuele toetsen';

  @override
  String get editorHighlightTip =>
      'De huidige codehighlighting-prestaties zijn slechter en kunnen optioneel worden uitgeschakeld om te verbeteren.';

  @override
  String get enableMdns => 'mDNS inschakelen';

  @override
  String get enableMdnsDesc =>
      'Gebruik mDNS/Bonjour om SSH-services te ontdekken';

  @override
  String get envVars => 'Omgevingsvariabele';

  @override
  String get extraArgs => 'Extra argumenten';

  @override
  String get fallbackSshDest => 'Fallback SSH-bestemming';

  @override
  String get fdroidReleaseTip =>
      'Als u deze app van F-Droid heeft gedownload, wordt aanbevolen deze optie uit te schakelen.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'Bestand \'$file\' te groot $size, max $sizeMax';
  }

  @override
  String get fileDirGone => 'Deze map is er niet meer';

  @override
  String get fileDirGoneTip => 'Het is verwijderd of hernoemd';

  @override
  String get fullScreen => 'Volledig scherm';

  @override
  String get fullScreenJitter => 'Volledig scherm trilling';

  @override
  String get fullScreenJitterHelp => 'Om inbranden van het scherm te voorkomen';

  @override
  String get fullScreenTip =>
      'Moet de volledig schermmodus worden ingeschakeld wanneer het apparaat naar de liggende modus wordt gedraaid? Deze optie is alleen van toepassing op het servertabblad.';

  @override
  String get githubGistIdOptional => 'Gist-ID (optioneel)';

  @override
  String get githubGistToken => 'GitHub Gist-token';

  @override
  String get githubGistTokenEmpty => 'Token is leeg';

  @override
  String get goto => 'Ga naar';

  @override
  String get homeTabs => 'Home-tabbladen';

  @override
  String get homeTabsCustomizeDesc =>
      'Pas aan welke tabbladen op de startpagina worden weergegeven en hun volgorde';

  @override
  String get homeWidgetUrlConfig => 'Home-widget-url configureren';

  @override
  String get ignoreCert => 'Certificaat negeren';

  @override
  String get image => 'Afbeelding';

  @override
  String get macDmgBody =>
      'De App Store vereist een sandbox, en een sandbox kan geen terminal openen. De DMG-versie wel.\n\nDe App Store-versie wordt mogelijk niet meer bijgewerkt.';

  @override
  String get macDmgImportDenied =>
      'macOS liet de gegevens van de vorige versie niet lezen';

  @override
  String get macDmgImported => 'Gegevens van de vorige versie geïmporteerd';

  @override
  String get macDmgImportFailed =>
      'Kon de gegevens van de vorige versie niet lezen';

  @override
  String get macDmgTip =>
      'Lokale terminal en snippets lokaal uitvoeren (DMG-versie)';

  @override
  String get macDmgTitle => 'DMG-versie';

  @override
  String get showHiddenFiles => 'Verborgen bestanden tonen';

  @override
  String get sshKeyAlgorithm => 'Algoritme';

  @override
  String get sshKeyComment => 'Opmerking';

  @override
  String get sshKeyGenerate => 'Sleutelpaar genereren';

  @override
  String get sshKeyGenerating => 'Bezig met genereren…';

  @override
  String sshKeyLockedFmt(String name) {
    return 'De privésleutel [$name] is niet ontgrendeld.';
  }

  @override
  String get sshKeyPassphraseTip =>
      'Optioneel. Een sleutel met wachtwoordzin wordt versleuteld opgeslagen en wordt gevraagd zodra een verbinding de sleutel voor het eerst gebruikt.';

  @override
  String get sshKeyPassphraseWrong => 'Onjuiste wachtwoordzin.';

  @override
  String get sshKeyPublicKey => 'Publieke sleutel';

  @override
  String get sshKeyPublicKeyTip =>
      'Voeg deze regel toe aan ~/.ssh/authorized_keys op de server.';

  @override
  String get sshKeyRecommended => 'Aanbevolen';

  @override
  String sshKeyUnlockTip(String name) {
    return 'Voer de wachtwoordzin voor de privésleutel [$name] in.';
  }

  @override
  String get ungrouped => 'Zonder groep';

  @override
  String get unused => 'Ongebruikt';

  @override
  String get dangling => 'Bungelend';

  @override
  String get pruneUnusedImages => 'Ongebruikte images opschonen';

  @override
  String get pruneDanglingImages => 'Bungelende images opschonen';

  @override
  String get pruneImages => 'Images opschonen';

  @override
  String get unusedTaggedImages => 'Ongebruikte tags';

  @override
  String get pruneDanglingImagesTip => 'Verwijdert alleen loshangende images.';

  @override
  String get pruneUnusedImagesTip =>
      'Verwijder ook getagde images die door geen container worden gebruikt.';

  @override
  String get includeUnusedVolumesTip =>
      'Verwijder ook volumes die door geen container worden gebruikt.';

  @override
  String get pruneCommandPreview => 'Opdrachtvoorbeeld';

  @override
  String get pruneForceSshTip =>
      '-f slaat de interactieve bevestiging over en is bij SSH-uitvoering altijd ingeschakeld.';

  @override
  String get pruneVolumes => 'Volumes opschonen';

  @override
  String get pruneUnusedData => 'Ongebruikte gegevens opschonen';

  @override
  String get pull => 'Pull';

  @override
  String get invalidHostFormat =>
      'Ongeldige hostindeling. Alleen IPv4-, IPv6- en domeintekens zijn toegestaan.';

  @override
  String get jumpServer => 'Spring naar server';

  @override
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return 'Jumpservers niet gevonden voor $serverName: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(Object name) {
    return '\'$name\' bestaat al';
  }

  @override
  String get noJumpServerAvailable => 'Geen jumpserver beschikbaar.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Jumpserver en ProxyCommand kunnen niet samen worden gebruikt.';

  @override
  String get keepForeground => 'Houd de app op de voorgrond!';

  @override
  String get keepStatusWhenErr => 'Behoud de laatste serverstatus';

  @override
  String get keepStatusWhenErrTip =>
      'Alleen in geval van een fout tijdens de scriptuitvoering';

  @override
  String get keyAuth => 'Sleutelauthenticatie';

  @override
  String get lastFailure => 'Laatst gefaald';

  @override
  String get lastSuccess => 'Laatst succesvol';

  @override
  String get letterCache => 'Normale toetsenbordinvoer';

  @override
  String get letterCacheTip =>
      'Wanneer dit is ingeschakeld, gaat invoer via de normale IME, wat op sommige systemen beveiligde toetsenbordmeldingen in de terminal kan vermijden.';

  @override
  String get linuxShellTip =>
      'Met welke shell een terminal start. Leeg herstelt /bin/sh.';

  @override
  String get linuxNetTip => 'DNS-servers. Leeg herstelt de standaardwaarden';

  @override
  String madeWithLove(Object myGithub) {
    return 'Gemaakt met ❤️ door $myGithub';
  }

  @override
  String get maxConcurrency => 'Maximale gelijktijdigheid';

  @override
  String get maxRetryCount => 'Aantal serverherverbindingen';

  @override
  String mismatchSystem(Object system) {
    return 'Niet-overeenkomend systeem: $system';
  }

  @override
  String get mirror => 'Mirror';

  @override
  String get needRestart => 'App moet opnieuw worden gestart';

  @override
  String get netViewType => 'Netweergavetype';

  @override
  String get newContainer => 'Nieuwe container';

  @override
  String get noConnectionStatsData => 'Geen verbindingsstatistiekgegevens';

  @override
  String get noLineChart => 'lijndiagrammen gebruiken';

  @override
  String get noPrivateKeyTip =>
      'De privésleutel bestaat niet, deze is mogelijk verwijderd of er is een configuratiefout.';

  @override
  String get noPromptAgain => 'Niet meer vragen';

  @override
  String get openLastPath => 'Open het laatste pad';

  @override
  String get openLastPathTip =>
      'Verschillende servers hebben verschillende logs, en de log is het pad naar de uitgang';

  @override
  String get parseContainerStatsTip =>
      'Het parsen van de bezettingsstatus van Docker is relatief langzaam.';

  @override
  String get plugInType => 'Invoegingstype';

  @override
  String get preferDiskAmount =>
      'Geef de schijfcapaciteit prioriteit bij weergave';

  @override
  String get privateKey => 'Privésleutel';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
    return 'Privésleutel [$keyId] niet gevonden.';
  }

  @override
  String get bmcPowerOnAction => 'Inschakelen';

  @override
  String get bmcShutdown => 'Afsluiten';

  @override
  String get bmcForceOff => 'Geforceerd uitschakelen';

  @override
  String get restart => 'Opnieuw starten';

  @override
  String get bmcPowerCycle => 'Stroom uit en aan';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return 'Naar $server sturen? De service krijgt \"$resetType\"';
  }

  @override
  String get bmcPowerDone => 'De voedingsstatus is gewijzigd';

  @override
  String get bmcPowerAccepted =>
      'Geaccepteerd, maar de energiestatus is niet gewijzigd. Een nette operatie hangt van het besturingssysteem af';

  @override
  String get bmcPowerUnsupported =>
      'Deze service staat niets toe voor die actie';

  @override
  String get bmcUnauthorized => 'De BMC heeft het account geweigerd';

  @override
  String get bmcAccountMissing => 'Er is geen account ingesteld voor deze BMC';

  @override
  String get bmcPowerOn => 'Ingeschakeld';

  @override
  String get bmcPowerOff => 'Uitgeschakeld';

  @override
  String get bmcCertRejected =>
      'Certificaat geweigerd — controleer het in de serverinstellingen';

  @override
  String get bmcNotAService => 'Geen Redfish-service op dit adres';

  @override
  String get bmcNoSystem => 'De service meldt geen systeem';

  @override
  String get bmcSensorsTruncated => 'Alleen de eerste sensoren worden getoond';

  @override
  String get bmcMultipleSystems => 'Alleen het eerste systeem wordt getoond';

  @override
  String get bmcTip =>
      'De BMC is een aparte computer op het moederbord, bereikbaar wanneer het besturingssysteem van de host dat niet is. Hier ingesteld meldt hij de voedingsstatus en hardwaresensoren terwijl de server uit staat of vastloopt. Vereist Redfish, aanwezig op de meeste zakelijke hardware vanaf ongeveer 2016.';

  @override
  String get bmcCert => 'Certificaat';

  @override
  String get bmcCertPinned => 'Gecontroleerd en vastgezet';

  @override
  String get bmcCertUnreviewed =>
      'Nog niet beoordeeld — tik om het certificaat te zien';

  @override
  String get bmcCertReview =>
      'Een zelfondertekend certificaat. Vergelijk het voor je accepteert. Daarna wordt alleen dit vertrouwd.';

  @override
  String get bmcCertChanged =>
      'Het certificaat komt niet overeen. Controleer het.';

  @override
  String get bmcCertExpired => 'Verlopen.';

  @override
  String bmcCertWas(String fingerprint) {
    return 'Eerder geaccepteerd: $fingerprint';
  }

  @override
  String get bmcAddrInvalid =>
      'Het BMC-adres moet een URL zijn, bijv. https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      'Deze versie draait in een sandbox: het commando krijgt een lege home, niet die van jou, dus alles wat ~/.ssh leest faalt. De DMG-versie niet.';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return 'Kan het privésleutelbestand $path niet lezen: $reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return 'Deze build kan geen bestanden buiten de eigen container lezen, dus de sleutel op $path is onbereikbaar. Importeer de sleutel in Instellingen of gebruik de DMG-versie.';
  }

  @override
  String get pushToken => 'Push-token';

  @override
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand wordt alleen op desktopplatforms ondersteund.';

  @override
  String get pveIgnoreCertTip =>
      'Niet aanbevolen om in te schakelen, let op beveiligingsrisico\'s! Als u de standaardcertificaat van PVE gebruikt, moet u deze optie inschakelen.';

  @override
  String get pveServerClientMissing =>
      'De SSH-client voor deze server is niet beschikbaar.';

  @override
  String get pveAddressMissing =>
      'Het PVE-adres ontbreekt. Stel het in bij de serverinstellingen.';

  @override
  String get pvePasswordRequired =>
      'Het PVE-wachtwoord is vereist. Stel het in bij de serverinstellingen.';

  @override
  String get pveOtpRequired =>
      'Op deze PVE-server staat tweestapsverificatie aan. Voer de OTP-code in.';

  @override
  String get pveOtpChallengeExpired =>
      'De OTP-aanvraag is verlopen. Vernieuw en probeer het opnieuw.';

  @override
  String get pveOtpCodeRequired => 'OTP-code is vereist.';

  @override
  String get pveOtpVerificationFailed =>
      'OTP-verificatie mislukt. Probeer het opnieuw met een nieuwe code.';

  @override
  String get pveOtpTitle => 'OTP-verificatie';

  @override
  String get pveOtpLabel => 'OTP-code';

  @override
  String get pveInvalidResponseBody =>
      'De PVE-aanmelding gaf een ongeldige antwoordinhoud terug.';

  @override
  String get pveInvalidResponseData =>
      'Het antwoord van de PVE-aanmelding bevatte geen geldige gegevens.';

  @override
  String get pveMissingAuthTicket =>
      'De PVE-aanmelding is gelukt, maar er is geen authenticatieticket teruggegeven.';

  @override
  String get pveVersionLow =>
      'Deze functie bevindt zich momenteel in de testfase en is alleen getest op PVE 8+. Gebruik het met voorzichtigheid.';

  @override
  String get pveLoadingForwarding => 'SSH-tunnel opzetten...';

  @override
  String get pveLoadingLogin => 'Aanmelden bij PVE...';

  @override
  String get pveLoadingData => 'Clustergegevens ophalen...';

  @override
  String get pveLoadingConnect => 'Verbinden...';

  @override
  String get pvePassword => 'PVE-wachtwoord';

  @override
  String get pvePasswordHint => 'Vereist bij SSH-authenticatie met een sleutel';

  @override
  String get read => 'Lezen';

  @override
  String get recentConnections => 'Recente verbindingen';

  @override
  String get rememberPwdInMem => 'Wachtwoord onthouden in geheugen';

  @override
  String get rememberPwdInMemTip =>
      'Gebruikt voor containers, opschorting, enz.';

  @override
  String get remotePath => 'Extern pad';

  @override
  String rootfsUpdateTip(
    Object distro,
    Object installed,
    Object latest,
    Object pm,
  ) {
    return '$distro $installed is geïnstalleerd, $latest is beschikbaar. Bijwerken vervangt de hele container: $pm-gegevens gaan verloren';
  }

  @override
  String linuxSystemInUse(Object name) {
    return 'Sluit de terminals op $name voordat je het verwijdert';
  }

  @override
  String get rootfsSubtitle => 'Een Linux-userland op dit apparaat';

  @override
  String rootfsInstallTip(Object distro, Object version, Object size) {
    return 'Downloadt $distro $version (ongeveer $size MB) en pakt het uit op dit apparaat.';
  }

  @override
  String get sameIdServerExist => 'Er bestaat al een server met dezelfde ID';

  @override
  String get second => 's';

  @override
  String get serverFilesUnavailableTip =>
      'Vereist SSH naar deze server, of server_box_monitor met de bestands-API aan.';

  @override
  String get back => 'Terug';

  @override
  String get history => 'Geschiedenis';

  @override
  String get homeDir => 'Home';

  @override
  String selected(Object count) {
    return '$count geselecteerd';
  }

  @override
  String get sendTo => 'Verzenden naar…';

  @override
  String get serverDetailOrder => 'Volgorde van widget op detailpagina';

  @override
  String get serverFuncBtns => 'Server functieknoppen';

  @override
  String get serverOrder => 'Servervolgorde';

  @override
  String get serverTabRequired => 'Servertabblad kan niet worden verwijderd';

  @override
  String get shareServerRiskTip =>
      'Deze QR-code bevat de verbindingsinstellingen in leesbare tekst. Wie hem scant of fotografeert, kan verbinden.';

  @override
  String get sftpDlPrepare => 'Voorbereiden om verbinding te maken...';

  @override
  String get sftpEditorTip =>
      'Leeg gebruikt de ingebouwde editor. Bijvoorbeeld `vim` (lezen uit `EDITOR` aangeraden).';

  @override
  String get sftpRmrDirSummary =>
      'Gebruik `rm -r` om een map te verwijderen in SFTP.';

  @override
  String get sftpSSHConnected => 'SFTP Verbonden';

  @override
  String get sftpShowFoldersFirst => 'Mappen eerst weergeven';

  @override
  String get specifyDev => 'Apparaat specificeren';

  @override
  String get specifyDevTip =>
      'Netwerkverkeer telt standaard alle apparaten; noem er hier één';

  @override
  String get tempIsCelsiusTip =>
      'Als dit aanstaat, wordt de temperatuurwaarde als Celsius behandeld in plaats van millicelsius. Zet dit alleen aan als de temperatuur verkeerd wordt weergegeven (bijvoorbeeld 0,1 °C in plaats van 58 °C).';

  @override
  String spentTime(Object time) {
    return 'Gebruikte tijd: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'Alle servers bestaan al ($duplicateCount duplicaten gevonden)';
  }

  @override
  String get sshConnectionModeTip =>
      'Ingebouwd: de terminal van de app gebruiken. Systeem-SSH: het ssh-commando van het systeem in een externe terminal starten.';

  @override
  String get sshConnectionModeUseBuiltin => 'Ingebouwde terminal gebruiken';

  @override
  String get sshConnectionModeUseSystem => 'Systeem-SSH gebruiken';

  @override
  String sshConfigDuplicatesSkipped(Object duplicateCount) {
    return '$duplicateCount duplicaten worden overgeslagen';
  }

  @override
  String get sshConfigFound =>
      'We hebben SSH-configuratie op uw systeem gevonden';

  @override
  String sshConfigFoundServers(Object totalCount) {
    return '$totalCount servers gevonden';
  }

  @override
  String get sshConfigImport => 'SSH Configuratie Importeren';

  @override
  String get sshConfigImportPermission =>
      'Wilt u toestemming geven om ~/.ssh/config te lezen en automatisch serverinstellingen te importeren?';

  @override
  String get sshConfigImportTip =>
      'Prompt om ~/.ssh/config te lezen bij het aanmaken van de eerste server';

  @override
  String sshConfigImported(Object count) {
    return '$count servers geïmporteerd uit SSH-configuratie';
  }

  @override
  String sshHostKeyChangedDesc(Object serverName) {
    return 'De SSH-hostsleutel voor $serverName is gewijzigd. Ga alleen verder als u deze server vertrouwt.';
  }

  @override
  String get sshHostKeyType => 'Type SSH-hostsleutel';

  @override
  String get sshKnownHostKeys => 'Bekende hosts';

  @override
  String get sshKnownHostKeysTip =>
      'De hostsleutels die deze app heeft geaccepteerd';

  @override
  String sshHostKeyNewDesc(Object serverName) {
    return 'Er is een nieuwe SSH-hostsleutel ontvangen van $serverName. Controleer de vingerafdruk voordat u vertrouwt.';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
    return 'Opgeslagen vingerafdruk: $fingerprint';
  }

  @override
  String get sshVerificationCode => 'Verificatiecode';

  @override
  String get sshConfigManualSelect =>
      'Wilt u het SSH-configuratiebestand handmatig selecteren?';

  @override
  String get sshConfigNoServers => 'Geen servers gevonden in SSH-configuratie';

  @override
  String get sshConfigPermissionDenied =>
      'Kan geen toegang krijgen tot SSH-configuratiebestand vanwege macOS-rechten.';

  @override
  String sshConfigServersToImport(Object importCount) {
    return '$importCount servers worden geïmporteerd';
  }

  @override
  String get sshTermHelp =>
      'Wanneer het terminal scrollbaar is, kan horizontaal slepen tekst selecteren. Klikken op de toetsenbordknop schakelt het toetsenbord aan/uit. Het bestandsicoon opent de huidige pad SFTP. De klembordknop kopieert de inhoud wanneer tekst is geselecteerd en plakt inhoud van het klembord in de terminal wanneer geen tekst is geselecteerd en er inhoud op het klembord staat. Het code-icoon plakt codefragmenten in de terminal en voert ze uit.';

  @override
  String get sshVirtualKeyAutoOff =>
      'Automatisch schakelen van virtuele toetsen';

  @override
  String get supportFmtArgs =>
      'De volgende opmaakparameters worden ondersteund:';

  @override
  String get suspendTip =>
      'De opschortfunctie vereist rootrechten en systemd-ondersteuning.';

  @override
  String switchTo(Object val) {
    return 'Overschakelen naar $val';
  }

  @override
  String get syncAppSettings => 'App-instellingen synchroniseren';

  @override
  String get syncAppSettingsTip =>
      'Thema, indeling, editor, terminal en andere apparaatvoorkeuren meenemen in de automatische synchronisatie.';

  @override
  String get termFontSizeTip =>
      'Deze instelling heeft invloed op de terminalgrootte (breedte en hoogte). U kunt inzoomen op de terminalpagina om de lettergrootte van de huidige sessie aan te passen.';

  @override
  String get textScalerTip =>
      '1.0 => 100% (oorspronkelijke grootte), werkt alleen op het gedeelte van de serverpagina van het lettertype, niet aanbevolen om te wijzigen.';

  @override
  String get times => 'Keer';

  @override
  String get trySudo => 'Probeer sudo te gebruiken';

  @override
  String get sudoPromptNotFound => 'Er is geen sudo-wachtwoordprompt actief.';

  @override
  String get updateServerStatusInterval =>
      'Interne server status bijwerking interval';

  @override
  String get useNoPwd => 'Er zal geen wachtwoord gebruikt worden';

  @override
  String get usePodmanByDefault => 'Valt terug op Podman';

  @override
  String get used => 'Gebruikt';

  @override
  String get view => 'Weergave';

  @override
  String get viewDetails => 'Details bekijken';

  @override
  String get virtKeyHelpClipboard =>
      'Kopiëren naar het klembord als de geselecteerde terminal niet leeg is, anders de inhoud van het klembord plakken in de terminal.';

  @override
  String get virtKeyHelpIME => 'Toetsenbord aan/uit zetten';

  @override
  String get virtKeyHelpSFTP => 'Huidige map openen in SFTP.';

  @override
  String get virtKeyHelpSnippet =>
      'Kies een snippet en voer het uit in deze terminal.';

  @override
  String get virtKeyHelpTmux => 'Wissel tussen tmux-sessies en -vensters.';

  @override
  String get virtKeyIntroActions => 'Snelkoppelingen';

  @override
  String get virtKeyIntroActionsTip =>
      'Deze toetsen typen niets, ze openen iets. Houd er een ingedrukt om te lezen wat hij doet.';

  @override
  String get virtKeyIntroCustomizeTip =>
      'In de terminalinstellingen kun je ze herschikken of verbergen wat je nooit gebruikt.';

  @override
  String get virtKeyIntroModifiers => 'Modificatietoetsen';

  @override
  String get virtKeyIntroModifiersTip =>
      'Tik er een aan om hem in te schakelen en tik daarna een letter op het toetsenbord. Hij geldt voor die ene toets.';

  @override
  String get virtKeyIntroNav => 'Navigatie';

  @override
  String get virtKeyIntroNavTip =>
      'Deze toetsen verplaatsen de cursor. Houd een pijltoets ingedrukt om hem te herhalen.';

  @override
  String get virtKeyIntroSelect =>
      'Zolang de terminal iets te scrollen heeft, selecteer je tekst door opzij te slepen.';

  @override
  String get virtKeyRows => 'Rijen tegelijk zichtbaar';

  @override
  String get virtKeyRowsTip =>
      'De rest staat op een eigen pagina, die je opzij veegt.';

  @override
  String get waitConnection =>
      'Wacht alstublieft tot de verbinding tot stand is gebracht.';

  @override
  String get wakeLock => 'Wakker houden';

  @override
  String get watchNotPaired => 'Geen gekoppelde Apple Watch';

  @override
  String get webdavSettingEmpty => 'Webdav-instelling is leeg';

  @override
  String get whenOpenApp => 'Bij het openen van de app';

  @override
  String get wolTip =>
      'Na het configureren van WOL (Wake-on-LAN), wordt elke keer dat de server wordt verbonden een WOL-verzoek verzonden.';

  @override
  String get write => 'Schrijven';

  @override
  String get writeScriptFailTip =>
      'Het schrijven naar het script is mislukt, mogelijk door gebrek aan rechten of omdat de map niet bestaat.';

  @override
  String get writeScriptTip =>
      'Na het verbinden met de server wordt een script geschreven naar `~/.config/server_box` \n | `/tmp/server_box` om de systeemstatus te monitoren. U kunt de inhoud van het script controleren.';

  @override
  String get menuGitHubRepository => 'GitHub-repository';

  @override
  String get podmanDockerEmulationDetected =>
      'Podman Docker-emulatie gedetecteerd. Schakel over naar Podman in de instellingen.';

  @override
  String get betaTip =>
      'Deze functie is nog in bèta. De werking wordt niet gegarandeerd.';

  @override
  String get portForward_startPrompt =>
      'Voeg een poortdoorstuurregel toe om te beginnen';

  @override
  String get portForward_localHost => 'Lokale host';

  @override
  String get portForward_localPort => 'Lokale poort';

  @override
  String get portForward_remoteHost => 'Externe host';

  @override
  String get portForward_remotePort => 'Externe poort';

  @override
  String portForward_deleteConfirmFmt(Object name) {
    return '$name verwijderen?';
  }

  @override
  String get sponsor => 'Sponsor';

  @override
  String get sortByJoinTime => 'Op moment van toevoegen';

  @override
  String get serverHistory => 'Servergeschiedenis';

  @override
  String get portForwardBetaTitle => 'Port Forward (Beta)';

  @override
  String get tmuxAutoAttach => 'tmux automatisch koppelen';

  @override
  String get tmuxAuto => 'tmux automatisch';

  @override
  String get tmuxAutoTip =>
      'tmux automatisch starten of koppelen bij verbinden via SSH';

  @override
  String get tmuxSessionSelector => 'Sessiekiezer';

  @override
  String get tmuxSessionSelectorTip =>
      'De sessiekiezer tonen bij het verbinden';

  @override
  String get tmuxDefaultSessionName => 'Standaard sessienaam';

  @override
  String get tmuxSessionName => 'Sessienaam';

  @override
  String get tmuxExistingSessions => 'Bestaande sessies';

  @override
  String get tmuxNewSession => 'Nieuwe sessie';

  @override
  String get tmuxWindows => 'Vensters';

  @override
  String get tmuxNewWindow => 'Nieuw venster';

  @override
  String get tmuxNoWindowsFound => 'Geen vensters gevonden';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vensters',
      one: '1 venster',
    );
    return '$_temp0';
  }

  @override
  String tmuxPaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count panelen',
      one: '1 paneel',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Gekoppeld';

  @override
  String get tmuxActive => 'Actief';

  @override
  String tmuxActiveAt(String time) {
    return 'actief: $time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return 'gekoppeld: $time';
  }

  @override
  String get tmuxSkip => 'Overslaan';

  @override
  String get tmuxNotAvailable => 'tmux is niet beschikbaar';

  @override
  String containerSegmentsMismatch(int count) {
    return 'Onverwacht aantal segmenten in containerrespons: $count';
  }

  @override
  String get containerOperationInProgress =>
      'Er wordt al een andere containerbewerking uitgevoerd';

  @override
  String processCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count processen',
      one: '1 proces',
    );
    return '$_temp0';
  }

  @override
  String get processParseUnsupportedOutput =>
      'De indeling van de proceslijst wordt niet ondersteund.';

  @override
  String get processParseInvalidRows =>
      'Sommige procesvermeldingen konden niet worden gelezen.';

  @override
  String get processParseInvalidWindowsJson =>
      'Het Windows-procesantwoord kon niet worden gelezen.';

  @override
  String get processParseInvalidWindowsRows =>
      'Sommige Windows-procesvermeldingen konden niet worden gelezen.';

  @override
  String get processKillTargetChanged =>
      'Het proces is gewijzigd of beëindigd. Vernieuw de lijst en probeer het opnieuw.';

  @override
  String get watchServers => 'Servers op de watch';

  @override
  String get watchServersTip =>
      'De horloge haalt de gegevens zelf bij de monitor op, dus alleen servers met een monitor zijn kiesbaar.';

  @override
  String get watchNoMonitorServer =>
      'Geen enkele server heeft een monitor-agent geconfigureerd';

  @override
  String get watchLegacyUrls => 'Oude status-URL\'s';

  @override
  String get accessoryWidgetServer => 'Server voor vergrendelscherm-widget';

  @override
  String get systemdMissing => 'Geen systemd op deze server';

  @override
  String get systemdMissingTip =>
      '`systemctl` is hier niet geïnstalleerd, dus er zijn geen units om te tonen.';

  @override
  String initSystemFmt(String init) {
    return 'Deze machine lijkt $init te gebruiken.';
  }

  @override
  String get systemdListFailed => 'Kon units niet tonen';

  @override
  String get systemdUserScopeMissing => 'Gebruikers-units worden niet getoond';

  @override
  String get systemdUserScopeMissingTip =>
      'Dit account heeft geen gebruikerssessiebus op de server, dus alleen systeem-units worden getoond.';

  @override
  String get serverUnreachable => 'Kon geen opdracht uitvoeren op deze server';

  @override
  String get containerNoRuntime => 'Geen container-runtime hier';

  @override
  String get containerNoRuntimeTip =>
      'Noch `docker` noch `podman` reageerde op deze machine. Als er één voor een ander account is geïnstalleerd, schakel dan \"Probeer sudo te gebruiken\" in bij Instellingen.';

  @override
  String get containerUnreadable =>
      'De container-runtime antwoordde in een onverwachte vorm';

  @override
  String get power => 'Energie';

  @override
  String get continueInTerminal => 'Doorgaan in terminal';

  @override
  String get askAiRiskUnknown => 'Niet ingedeeld';

  @override
  String get agentLocalExec => 'Opdrachten op dit apparaat uitvoeren';

  @override
  String get agentLocalExecTip =>
      'Laat de Agent werken op de machine waarop ServerBox draait. Ook alleen-lezen commando’s worden beoordeeld';

  @override
  String get agentLocalExecRootfsTip =>
      'Laat de Agent lokaal werken, beperkt tot de Linux-container die ServerBox installeerde';

  @override
  String macDmgImportedPartly(String path) {
    return 'De gegevens van de eerder geïnstalleerde versie zijn geïmporteerd. Gedownloade bestanden zijn achtergebleven in $path.';
  }

  @override
  String get bmcAccount => 'Account';

  @override
  String get bmcAccountUnset =>
      'Geen gekozen — tik om er een te kiezen of aan te maken';

  @override
  String bmcAccountShared(int count) {
    return 'Gebruikt door $count servers';
  }

  @override
  String get bmcAccounts => 'BMC-accounts';

  @override
  String get bmcAccountSharedTip =>
      'Dit bewerken verandert wat ze allemaal gebruiken.';

  @override
  String bmcAccountInUse(int count) {
    return '$count servers gebruiken het. Ze houden hun adres en verliezen het account.';
  }

  @override
  String get bmcStaleWrite =>
      'De BMC is gewijzigd tijdens het schrijven. Probeer opnieuw.';

  @override
  String get send => 'Verzenden';
}
