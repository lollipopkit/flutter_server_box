import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get aboutThanks => 'Met dank aan de volgende mensen die hebben deelgenomen aan.';

  @override
  String get acceptBeta => 'Accepteer testversie-updates';

  @override
  String get addSystemPrivateKeyTip => 'Er is momenteel geen privésleutel, wilt u degene toevoegen die bij het systeem wordt geleverd (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Toegevoegd aan takenlijst';

  @override
  String get addr => 'Adres';

  @override
  String get alreadyLastDir => 'Al in de laatst gebruikte map.';

  @override
  String get authFailTip => 'Authenticatie mislukt, controleer of het wachtwoord/sleutel/host/gebruiker, enz., incorrect zijn.';

  @override
  String get autoBackupConflict => 'Er kan slechts één automatische back-up tegelijk worden ingeschakeld.';

  @override
  String get autoConnect => 'Automatisch verbinden';

  @override
  String get autoRun => 'Automatisch uitvoeren';

  @override
  String get autoUpdateHomeWidget => 'Automatische update van home-widget';

  @override
  String get backupTip => 'De geëxporteerde gegevens zijn simpelweg versleuteld. \nBewaar deze aub veilig.';

  @override
  String get backupVersionNotMatch => 'Back-upversie komt niet overeen.';

  @override
  String get battery => 'Batterij';

  @override
  String get bgRun => 'Uitvoeren op de achtergrond';

  @override
  String get bgRunTip => 'Deze schakelaar betekent alleen dat het programma zal proberen op de achtergrond uit te voeren, of het in de achtergrond kan worden uitgevoerd, hangt af van of de toestemming is ingeschakeld of niet. Voor native Android, schakel \"Batterijoptimalisatie\" uit in deze app, en voor miui, wijzig de energiebesparingsbeleid naar \"Onbeperkt\".';

  @override
  String get closeAfterSave => 'Opslaan en sluiten';

  @override
  String get cmd => 'Opdracht';

  @override
  String get collapseUITip => 'Of lange lijsten in de UI standaard moeten worden ingeklapt';

  @override
  String get conn => 'Verbinding';

  @override
  String get container => 'Container';

  @override
  String get containerTrySudoTip => 'Bijvoorbeeld: in de app is de gebruiker ingesteld op aaa, maar Docker is geïnstalleerd onder de rootgebruiker. In dit geval moet u deze optie inschakelen.';

  @override
  String get convert => 'Converteren';

  @override
  String get copyPath => 'Pad kopiëren';

  @override
  String get cpuViewAsProgressTip => 'Toon het gebruik van elke CPU in een voortgangsbalkstijl (oude stijl)';

  @override
  String get cursorType => 'Cursortype';

  @override
  String get customCmd => 'Aangepaste opdrachten';

  @override
  String get customCmdDocUrl => 'https://github.com/lollipopkit/flutter_server_box/wiki#custom-commands';

  @override
  String get customCmdHint => '\"Opdrachtnaam\": \"Opdracht\"';

  @override
  String get decode => 'Decoderen';

  @override
  String get decompress => 'Decomprimeren';

  @override
  String get deleteServers => 'Servers batchgewijs verwijderen';

  @override
  String get dirEmpty => 'Zorg ervoor dat de map leeg is.';

  @override
  String get disconnected => 'Verbroken';

  @override
  String get disk => 'Schijf';

  @override
  String get diskIgnorePath => 'Pad negeren voor schijf';

  @override
  String get displayCpuIndex => 'Toon de CPU-index';

  @override
  String dl2Local(Object fileName) {
    return 'Download $fileName naar lokaal?';
  }

  @override
  String get dockerEmptyRunningItems => 'Er zijn geen actieve containers.\nDit kan komen doordat:\n- De Docker-installatiegebruiker niet overeenkomt met de gebruikersnaam die is geconfigureerd binnen de app.\n- De omgevingsvariabele DOCKER_HOST is niet correct gelezen. U kunt deze krijgen door `echo \$DOCKER_HOST` in de terminal uit te voeren.';

  @override
  String dockerImagesFmt(Object count) {
    return '$count afbeeldingen';
  }

  @override
  String get dockerNotInstalled => 'Docker niet geïnstalleerd';

  @override
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount) {
    return '$runningCount actief, $stoppedCount container gestopt.';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count container actief.';
  }

  @override
  String get doubleColumnMode => 'Dubbele kolommodus';

  @override
  String get doubleColumnTip => 'Deze optie schakelt alleen de functie in, of deze daadwerkelijk kan worden ingeschakeld, hangt af van de breedte van het apparaat';

  @override
  String get editVirtKeys => 'Virtuele toetsen bewerken';

  @override
  String get editor => 'Editor';

  @override
  String get editorHighlightTip => 'De huidige codehighlighting-prestaties zijn slechter en kunnen optioneel worden uitgeschakeld om te verbeteren.';

  @override
  String get encode => 'Coderen';

  @override
  String get envVars => 'Omgevingsvariabele';

  @override
  String get experimentalFeature => 'Experimentele functie';

  @override
  String get extraArgs => 'Extra argumenten';

  @override
  String get fallbackSshDest => 'Fallback SSH-bestemming';

  @override
  String get fdroidReleaseTip => 'Als u deze app van F-Droid heeft gedownload, wordt aanbevolen deze optie uit te schakelen.';

  @override
  String get fgService => 'Voorgrondservice';

  @override
  String get fgServiceTip => 'Na het inschakelen kunnen sommige apparaatmodellen crashen. Uitschakelen kan ertoe leiden dat sommige modellen SSH-verbindingen niet op de achtergrond kunnen behouden. Sta ServerBox notificatierechten, achtergronduitvoering en zelf-ontwaken toe in systeeminstellingen.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'Bestand \'$file\' te groot $size, max $sizeMax';
  }

  @override
  String get followSystem => 'Volg systeem';

  @override
  String get font => 'Lettertype';

  @override
  String get fontSize => 'Lettergrootte';

  @override
  String get force => 'Forceer';

  @override
  String get fullScreen => 'Volledig schermmodus';

  @override
  String get fullScreenJitter => 'Volledig scherm trilling';

  @override
  String get fullScreenJitterHelp => 'Om inbranden van het scherm te voorkomen';

  @override
  String get fullScreenTip => 'Moet de volledig schermmodus worden ingeschakeld wanneer het apparaat naar de liggende modus wordt gedraaid? Deze optie is alleen van toepassing op het servertabblad.';

  @override
  String get goBackQ => 'Terug gaan?';

  @override
  String get goto => 'Ga naar';

  @override
  String get hideTitleBar => 'Titelbalk verbergen';

  @override
  String get highlight => 'Code-highlight';

  @override
  String get homeWidgetUrlConfig => 'Home-widget-url configureren';

  @override
  String get host => 'Host';

  @override
  String httpFailedWithCode(Object code) {
    return 'verzoek mislukt, statuscode: $code';
  }

  @override
  String get ignoreCert => 'Certificaat negeren';

  @override
  String get image => 'Afbeelding';

  @override
  String get imagesList => 'Lijst met afbeeldingen';

  @override
  String get init => 'Initialiseren';

  @override
  String get inner => 'Intern';

  @override
  String get install => 'Installeren';

  @override
  String get installDockerWithUrl => 'Installeer eerst docker via https://docs.docker.com/engine/install.';

  @override
  String get invalid => 'Ongeldig';

  @override
  String get jumpServer => 'Spring naar server';

  @override
  String get keepForeground => 'Houd de app op de voorgrond!';

  @override
  String get keepStatusWhenErr => 'Behoud de laatste serverstatus';

  @override
  String get keepStatusWhenErrTip => 'Alleen in geval van een fout tijdens de scriptuitvoering';

  @override
  String get keyAuth => 'Sleutelauthenticatie';

  @override
  String get letterCache => 'Lettercaching';

  @override
  String get letterCacheTip => 'Aanbevolen om uit te schakelen, maar na het uitschakelen is het niet mogelijk om CJK-tekens in te voeren.';

  @override
  String get license => 'Licentie';

  @override
  String get location => 'Locatie';

  @override
  String get loss => 'verlies';

  @override
  String madeWithLove(Object myGithub) {
    return 'Gemaakt met ❤️ door $myGithub';
  }

  @override
  String get manual => 'Handleiding';

  @override
  String get max => 'max';

  @override
  String get maxRetryCount => 'Aantal serverherverbindingen';

  @override
  String get maxRetryCountEqual0 => 'Zal opnieuw blijven proberen.';

  @override
  String get min => 'min';

  @override
  String get mission => 'Missie';

  @override
  String get more => 'Meer';

  @override
  String get moveOutServerFuncBtnsHelp => 'Aan: kan worden weergegeven onder elke kaart op de Server-tabbladpagina. Uit: kan worden weergegeven bovenaan de Serverdetails-pagina.';

  @override
  String get ms => 'ms';

  @override
  String get needHomeDir => 'Als u een Synology-gebruiker bent, [zie hier](https://kb.synology.com/DSM/tutorial/user_enable_home_service). Gebruikers van andere systemen moeten zoeken hoe ze een home directory kunnen creëren.';

  @override
  String get needRestart => 'App moet opnieuw worden gestart';

  @override
  String get net => 'Netwerk';

  @override
  String get netViewType => 'Netweergavetype';

  @override
  String get newContainer => 'Nieuwe container';

  @override
  String get noLineChart => 'lijndiagrammen gebruiken';

  @override
  String get noLineChartForCpu => 'Gebruik geen lijndiagrammen voor CPU';

  @override
  String get noPrivateKeyTip => 'De privésleutel bestaat niet, deze is mogelijk verwijderd of er is een configuratiefout.';

  @override
  String get noPromptAgain => 'Niet meer vragen';

  @override
  String get node => 'Node';

  @override
  String get notAvailable => 'Niet beschikbaar';

  @override
  String get onServerDetailPage => 'Op serverdetailspagina';

  @override
  String get onlyOneLine => 'Alleen als één regel weergeven (scrollbaar)';

  @override
  String get onlyWhenCoreBiggerThan8 => 'Alleen effectief wanneer het aantal cores > 8';

  @override
  String get openLastPath => 'Open het laatste pad';

  @override
  String get openLastPathTip => 'Verschillende servers hebben verschillende logs, en de log is het pad naar de uitgang';

  @override
  String get parseContainerStatsTip => 'Het parsen van de bezettingsstatus van Docker is relatief langzaam.';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$percent% van $size';
  }

  @override
  String get permission => 'Machtigingen';

  @override
  String get pingAvg => 'Gem:';

  @override
  String get pingInputIP => 'Voer een doel-IP / domein in.';

  @override
  String get pingNoServer => 'Geen server om te pingen.\nVoeg een server toe in het servertabblad.';

  @override
  String get pkg => 'Pkg';

  @override
  String get plugInType => 'Invoegingstype';

  @override
  String get port => 'Poort';

  @override
  String get preview => 'Voorbeeld';

  @override
  String get privateKey => 'Privésleutel';

  @override
  String get process => 'Proces';

  @override
  String get pushToken => 'Push-token';

  @override
  String get pveIgnoreCertTip => 'Niet aanbevolen om in te schakelen, let op beveiligingsrisico\'s! Als u de standaardcertificaat van PVE gebruikt, moet u deze optie inschakelen.';

  @override
  String get pveLoginFailed => 'Aanmelden mislukt. Kan niet authenticeren met gebruikersnaam/wachtwoord van serverconfiguratie voor Linux PAM-login.';

  @override
  String get pveVersionLow => 'Deze functie bevindt zich momenteel in de testfase en is alleen getest op PVE 8+. Gebruik het met voorzichtigheid.';

  @override
  String get pwd => 'Wachtwoord';

  @override
  String get read => 'Lezen';

  @override
  String get reboot => 'Herstart';

  @override
  String get rememberPwdInMem => 'Wachtwoord onthouden in geheugen';

  @override
  String get rememberPwdInMemTip => 'Gebruikt voor containers, opschorting, enz.';

  @override
  String get rememberWindowSize => 'Venstergrootte onthouden';

  @override
  String get remotePath => 'Extern pad';

  @override
  String get restart => 'Herstarten';

  @override
  String get result => 'Resultaat';

  @override
  String get rotateAngel => 'Rotatiehoek';

  @override
  String get route => 'Route';

  @override
  String get run => 'Uitvoeren';

  @override
  String get running => 'Uitgevoerd';

  @override
  String get sameIdServerExist => 'Er bestaat al een server met dezelfde ID';

  @override
  String get save => 'Opslaan';

  @override
  String get saved => 'Opgeslagen';

  @override
  String get second => 's';

  @override
  String get sensors => 'Sensor';

  @override
  String get sequence => 'Volgorde';

  @override
  String get server => 'Server';

  @override
  String get serverDetailOrder => 'Volgorde van widget op detailpagina';

  @override
  String get serverFuncBtns => 'Server functieknoppen';

  @override
  String get serverOrder => 'Servervolgorde';

  @override
  String get sftpDlPrepare => 'Voorbereiden om verbinding te maken...';

  @override
  String get sftpEditorTip => 'Indien leeg, gebruik de ingebouwde bestandseditor van de app. Indien een waarde aanwezig is, gebruik de editor van de externe server, bijvoorbeeld `vim` (aanbevolen om automatisch te detecteren volgens `EDITOR`).';

  @override
  String get sftpRmrDirSummary => 'Gebruik `rm -r` om een map te verwijderen in SFTP.';

  @override
  String get sftpSSHConnected => 'SFTP Verbonden';

  @override
  String get sftpShowFoldersFirst => 'Mappen eerst weergeven';

  @override
  String get showDistLogo => 'Distributielogo weergeven';

  @override
  String get shutdown => 'Afsluiten';

  @override
  String get size => 'Grootte';

  @override
  String get snippet => 'Fragment';

  @override
  String get softWrap => 'Zachte wrap';

  @override
  String get specifyDev => 'Apparaat specificeren';

  @override
  String get specifyDevTip => 'Bijvoorbeeld, netwerkverkeersstatistieken zijn standaard voor alle apparaten. Hier kunt u een specifiek apparaat opgeven.';

  @override
  String get speed => 'Snelheid';

  @override
  String spentTime(Object time) {
    return 'Gebruikte tijd: $time';
  }

  @override
  String get sshTermHelp => 'Wanneer het terminal scrollbaar is, kan horizontaal slepen tekst selecteren. Klikken op de toetsenbordknop schakelt het toetsenbord aan/uit. Het bestandsicoon opent de huidige pad SFTP. De klembordknop kopieert de inhoud wanneer tekst is geselecteerd en plakt inhoud van het klembord in de terminal wanneer geen tekst is geselecteerd en er inhoud op het klembord staat. Het code-icoon plakt codefragmenten in de terminal en voert ze uit.';

  @override
  String sshTip(Object url) {
    return 'Deze functie bevindt zich momenteel in de experimentele fase.\n\nMeld alstublieft bugs op $url of sluit je aan bij onze ontwikkeling.';
  }

  @override
  String get sshVirtualKeyAutoOff => 'Automatisch schakelen van virtuele toetsen';

  @override
  String get start => 'Starten';

  @override
  String get stat => 'Statistieken';

  @override
  String get stats => 'Statistieken';

  @override
  String get stop => 'Stoppen';

  @override
  String get stopped => 'Gestopt';

  @override
  String get storage => 'Opslag';

  @override
  String get supportFmtArgs => 'De volgende opmaakparameters worden ondersteund:';

  @override
  String get suspend => 'Ophangen';

  @override
  String get suspendTip => 'De opschortfunctie vereist rootrechten en systemd-ondersteuning.';

  @override
  String switchTo(Object val) {
    return 'Overschakelen naar $val';
  }

  @override
  String get sync => 'Sync';

  @override
  String get syncTip => 'Een herstart kan nodig zijn voor sommige wijzigingen om van kracht te worden.';

  @override
  String get system => 'Systeem';

  @override
  String get tag => 'Labels';

  @override
  String get temperature => 'Temperatuur';

  @override
  String get termFontSizeTip => 'Deze instelling heeft invloed op de terminalgrootte (breedte en hoogte). U kunt inzoomen op de terminalpagina om de lettergrootte van de huidige sessie aan te passen.';

  @override
  String get terminal => 'Terminal';

  @override
  String get test => 'Testen';

  @override
  String get textScaler => 'Tekstschaler';

  @override
  String get textScalerTip => '1.0 => 100% (oorspronkelijke grootte), werkt alleen op het gedeelte van de serverpagina van het lettertype, niet aanbevolen om te wijzigen.';

  @override
  String get theme => 'Thema';

  @override
  String get time => 'Tijd';

  @override
  String get times => 'Keer';

  @override
  String get total => 'Totaal';

  @override
  String get traffic => 'Verkeer';

  @override
  String get trySudo => 'Probeer sudo te gebruiken';

  @override
  String get ttl => 'TTL';

  @override
  String get unknown => 'Onbekend';

  @override
  String get unkownConvertMode => 'Onbekende conversiemodus';

  @override
  String get update => 'Bijwerken';

  @override
  String get updateIntervalEqual0 => 'Het staat op 0, het zal niet automatisch bijwerken\nCPU status kan niet berekend worden.';

  @override
  String get updateServerStatusInterval => 'Interne server status bijwerking interval';

  @override
  String get upload => 'Upload';

  @override
  String get upsideDown => 'Ondersteboven';

  @override
  String get uptime => 'Uptime';

  @override
  String get useCdn => 'Gebruikt CDN';

  @override
  String get useCdnTip => 'Niet-chinese gebruikers worden aangeraden om deze CDN te gebruiken. Wil je dat?';

  @override
  String get useNoPwd => 'Er zal geen wachtwoord gebruikt worden';

  @override
  String get usePodmanByDefault => 'Valt terug op Podman';

  @override
  String get used => 'Gebruikt';

  @override
  String get view => 'Weergave';

  @override
  String get viewErr => 'Zie foutmelding';

  @override
  String get virtKeyHelpClipboard => 'Kopiëren naar het klembord als de geselecteerde terminal niet leeg is, anders de inhoud van het klembord plakken in de terminal.';

  @override
  String get virtKeyHelpIME => 'Toetsenbord aan/uit zetten';

  @override
  String get virtKeyHelpSFTP => 'Huidige map openen in SFTP.';

  @override
  String get waitConnection => 'Wacht alstublieft tot de verbinding tot stand is gebracht.';

  @override
  String get wakeLock => 'Wakker houden';

  @override
  String get watchNotPaired => 'Geen gekoppelde Apple Watch';

  @override
  String get webdavSettingEmpty => 'Webdav-instelling is leeg';

  @override
  String get whenOpenApp => 'Bij het openen van de app';

  @override
  String get wolTip => 'Na het configureren van WOL (Wake-on-LAN), wordt elke keer dat de server wordt verbonden een WOL-verzoek verzonden.';

  @override
  String get write => 'Schrijven';

  @override
  String get writeScriptFailTip => 'Het schrijven naar het script is mislukt, mogelijk door gebrek aan rechten of omdat de map niet bestaat.';

  @override
  String get writeScriptTip => 'Na het verbinden met de server wordt een script geschreven naar ~/.config/server_box om de systeemstatus te monitoren. U kunt de inhoud van het script controleren.';
}
