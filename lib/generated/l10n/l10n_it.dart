// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get aboutThanks =>
      'Grazie alle seguenti persone che hanno partecipato.';

  @override
  String get acceptBeta => 'Accetta aggiornamenti versione beta';

  @override
  String get addSystemPrivateKeyTip =>
      'Attualmente non esistono chiavi private, vuoi aggiungere quella fornita dal sistema (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Aggiunto alla lista delle attività';

  @override
  String get addr => 'Indirizzo';

  @override
  String get alreadyLastDir => 'Già nell\'ultima directory.';

  @override
  String get askAi => 'Chiedi all\'IA';

  @override
  String get askAiApiKey => 'Chiave API';

  @override
  String get askAiAwaitingResponse => 'In attesa della risposta dell\'IA...';

  @override
  String get askAiBaseUrl => 'URL base';

  @override
  String get askAiCommandInserted => 'Comando inserito nel terminale';

  @override
  String askAiConfigMissing(Object fields) {
    return 'Configura $fields in Impostazioni.';
  }

  @override
  String get askAiConfirmExecute => 'Conferma prima di eseguire';

  @override
  String get askAiConversation => 'Conversazione IA';

  @override
  String get askAiDisclaimer =>
      'L\'IA potrebbe essere errata. Rivedi attentamente prima di applicare.';

  @override
  String get askAiFollowUpHint => 'Fai una domanda di follow-up...';

  @override
  String get askAiInsertTerminal => 'Inserisci nel terminale';

  @override
  String get askAiNoResponse => 'Nessuna risposta';

  @override
  String get askAiRecommendedCommand => 'Comando suggerito dall\'IA';

  @override
  String get askAiSelectedContent => 'Contenuto selezionato';

  @override
  String get askAiUsageHint => 'Utilizzato nel Terminale SSH';

  @override
  String get atLeastOneTab => 'Deve essere selezionata almeno una scheda';

  @override
  String get authFailTip =>
      'Autenticazione fallita, verifica se le credenziali sono corrette';

  @override
  String get autoBackupConflict =>
      'Solo un backup automatico può essere attivato alla volta.';

  @override
  String get autoConnect => 'Connessione automatica';

  @override
  String get autoRun => 'Esecuzione automatica';

  @override
  String get autoUpdateHomeWidget => 'Aggiornamento automatico widget home';

  @override
  String get availableTabs => 'Schede disponibili';

  @override
  String get backupEncrypted => 'Il backup è crittografato';

  @override
  String get backupNotEncrypted => 'Il backup non è crittografato';

  @override
  String get backupPassword => 'Password di backup';

  @override
  String get backupPasswordRemoved => 'Password di backup rimossa';

  @override
  String get backupPasswordSet => 'Password di backup impostata';

  @override
  String get backupPasswordTip =>
      'Imposta una password per crittografare i file di backup. Lascia vuoto per disabilitare la crittografia.';

  @override
  String get backupPasswordWrong => 'Password di backup errata';

  @override
  String get backupTip =>
      'I dati esportati possono essere crittografati con password.\nConservali al sicuro.';

  @override
  String get backupVersionNotMatch => 'La versione del backup non corrisponde.';

  @override
  String get bgRun => 'Esegui in background';

  @override
  String get bgRunTip =>
      'Questa opzione significa solo che il programma cercherà di eseguire in background. Se può eseguire in background dipende dal fatto che il permesso sia abilitato o meno. Per le ROM Android basate su AOSP, disabilita \"Ottimizzazione batteria\" in questa app. Per MIUI/HyperOS, cambia la politica di risparmio energetico su \"Illimitato\".';

  @override
  String get clearAllStatsContent =>
      'Sei sicuro di voler cancellare tutte le statistiche di connessione del server? Questa azione non può essere annullata.';

  @override
  String get clearAllStatsTitle => 'Cancella tutte le statistiche';

  @override
  String clearServerStatsContent(Object serverName) {
    return 'Sei sicuro di voler cancellare le statistiche di connessione per il server \"$serverName\"? Questa azione non può essere annullata.';
  }

  @override
  String clearServerStatsTitle(Object serverName) {
    return 'Cancella statistiche $serverName';
  }

  @override
  String get clearThisServerStats => 'Cancella statistiche di questo server';

  @override
  String get compactDatabase => 'Compatta database';

  @override
  String compactDatabaseContent(Object size) {
    return 'Dimensione database: $size\n\nQuesto riorganizzerà il database per ridurre la dimensione del file. Nessun dato verrà eliminato.';
  }

  @override
  String get closeAfterSave => 'Salva e chiudi';

  @override
  String get collapseUITip =>
      'Se comprimere le liste lunghe presenti nell\'interfaccia utente per impostazione predefinita';

  @override
  String get connectionDetails => 'Dettagli connessione';

  @override
  String get connectionStats => 'Statistiche connessione';

  @override
  String get connectionStatsDesc =>
      'Visualizza il tasso di successo della connessione al server e la cronologia';

  @override
  String get containerTrySudoTip =>
      'Ad esempio: nell\'app, l\'utente è impostato su aaa, ma Docker è installato sotto l\'utente root. In questo caso, devi abilitare questa opzione.';

  @override
  String get containerSudoPasswordRequired =>
      'È richiesta la password sudo per accedere a Docker. Inserisci la tua password.';

  @override
  String get containerSudoPasswordIncorrect =>
      'La password sudo è errata o non consentita. Riprova.';

  @override
  String get convert => 'Converti';

  @override
  String get copyPath => 'Copia percorso';

  @override
  String get cpuViewAsProgressTip =>
      'Visualizza l\'utilizzo di ogni CPU in stile barra di avanzamento (stile vecchio)';

  @override
  String get cursorType => 'Tipo di cursore';

  @override
  String get customCmd => 'Comandi personalizzati';

  @override
  String get customCmdHint => '\"Nome comando\": \"Comando\"';

  @override
  String get deleteServers => 'Elimina server in blocco';

  @override
  String get desktopTerminalTip =>
      'Comando utilizzato per aprire l\'emulatore di terminale quando si avviano sessioni SSH.';

  @override
  String get dirEmpty => 'Assicurati che la cartella sia vuota.';

  @override
  String get discoverSshServers => 'Scopri server SSH';

  @override
  String get discoveryFailed => 'Scoperta fallita';

  @override
  String get discoverySettings => 'Impostazioni scoperta';

  @override
  String get discoverySummary => 'Riepilogo scoperta';

  @override
  String get diskHealth => 'Salute disco';

  @override
  String get diskIgnorePath => 'Ignora percorso per disco';

  @override
  String get displayCpuIndex => 'Mostra indice CPU';

  @override
  String dl2Local(Object fileName) {
    return 'Scaricare $fileName in locale?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'Non ci sono container in esecuzione.\nQuesto potrebbe essere perché:\n- L\'utente di installazione di Docker non è lo stesso del nome utente configurato nell\'App.\n- La variabile d\'ambiente DOCKER_HOST non è stata letta correttamente. Puoi ottenerla eseguendo `echo \$DOCKER_HOST` nel terminale.';

  @override
  String dockerImagesFmt(Object count) {
    return '$count immagini';
  }

  @override
  String get dockerNotInstalled => 'Docker non installato';

  @override
  String dockerStatusRunningAndStoppedFmt(
    Object runningCount,
    Object stoppedCount,
  ) {
    return '$runningCount in esecuzione, $stoppedCount container fermati.';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count container in esecuzione.';
  }

  @override
  String get doubleColumnMode => 'Modalità a doppia colonna';

  @override
  String get doubleColumnTip =>
      'Questa opzione abilita solo la funzione, se può essere effettivamente abilitata dipende dalla larghezza del dispositivo';

  @override
  String get editVirtKeys => 'Modifica tasti virtuali';

  @override
  String get editorHighlightTip =>
      'Le attuali prestazioni di evidenziazione del codice non sono ideali e possono essere disabilitate opzionalmente per migliorare.';

  @override
  String get enableMdns => 'Abilita mDNS';

  @override
  String get enableMdnsDesc => 'Usa mDNS/Bonjour per scoprire servizi SSH';

  @override
  String get envVars => 'Variabile d\'ambiente';

  @override
  String get experimentalFeature => 'Funzionalità sperimentale';

  @override
  String get extraArgs => 'Argomenti extra';

  @override
  String get fallbackSshDest => 'Destinazione SSH di fallback';

  @override
  String get fdroidReleaseTip =>
      'Se hai scaricato questa app da F-Droid, si consiglia di disattivare questa opzione.';

  @override
  String get fgService => 'Servizio in primo piano';

  @override
  String get fgServiceTip =>
      'Dopo l\'attivazione, alcuni modelli di dispositivo potrebbero arrestarsi in modo anomalo. Disabilitarlo potrebbe causare l\'impossibilità per alcuni modelli di mantenere le connessioni SSH in background. Consenti le autorizzazioni di notifica ServerBox, l\'esecuzione in background e l\'auto-riattivazione nelle impostazioni di sistema.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'File \'$file\' troppo grande $size, max $sizeMax';
  }

  @override
  String get finishedAt => 'Completato alle';

  @override
  String get followSystem => 'Segui sistema';

  @override
  String get fontSize => 'Dimensione carattere';

  @override
  String get fullScreen => 'Modalità schermo intero';

  @override
  String get fullScreenJitter => 'Jitter schermo intero';

  @override
  String get fullScreenJitterHelp => 'Per evitare il burn-in dello schermo';

  @override
  String get fullScreenTip =>
      'La modalità a schermo intero deve essere abilitata quando il dispositivo viene ruotato in modalità orizzontale? Questa opzione si applica solo alla scheda server.';

  @override
  String get goBackQ => 'Tornare indietro?';

  @override
  String get goto => 'Vai a';

  @override
  String get hideTitleBar => 'Nascondi barra del titolo';

  @override
  String get highlight => 'Evidenziazione codice';

  @override
  String get homeTabs => 'Schede home';

  @override
  String get homeTabsCustomizeDesc =>
      'Personalizza quali schede appaiono nella home page e il loro ordine';

  @override
  String get homeWidgetUrlConfig => 'Configura url widget home';

  @override
  String httpFailedWithCode(Object code) {
    return 'richiesta fallita, codice stato: $code';
  }

  @override
  String get ignoreCert => 'Ignora certificato';

  @override
  String get image => 'Immagine';

  @override
  String get imagesList => 'Elenco immagini';

  @override
  String get installDockerWithUrl =>
      'Installa prima docker da https://docs.docker.com/engine/install .';

  @override
  String get invalid => 'Non valido';

  @override
  String get invalidHostFormat =>
      'Formato host non valido. Sono consentiti solo caratteri IPv4, IPv6 e di dominio.';

  @override
  String get jumpServer => 'Server di salto';

  @override
  String get keepForeground => 'Mantieni l\'app in primo piano!';

  @override
  String get keepStatusWhenErr => 'Conserva l\'ultimo stato del server';

  @override
  String get keepStatusWhenErrTip =>
      'Solo in caso di errore durante l\'esecuzione dello script';

  @override
  String get keyAuth => 'Autenticazione chiave';

  @override
  String get lastFailure => 'Ultimo fallimento';

  @override
  String get lastSuccess => 'Ultimo successo';

  @override
  String get letterCache => 'Cache lettere';

  @override
  String get letterCacheTip =>
      'Si consiglia di disabilitare, ma dopo aver disabilitato, non sarà possibile inserire caratteri CJK.';

  @override
  String madeWithLove(Object myGithub) {
    return 'Realizzato con ❤️ da $myGithub';
  }

  @override
  String get max => 'max';

  @override
  String get maxConcurrency => 'Massima concorrenza';

  @override
  String get maxRetryCount => 'Numero di riconnessioni del server';

  @override
  String get maxRetryCountEqual0 => 'Proverà di nuovo e ancora.';

  @override
  String get min => 'min';

  @override
  String get more => 'Altro';

  @override
  String get moveOutServerFuncBtnsHelp =>
      'Attivo: può essere visualizzato sotto ogni carta nella pagina Scheda Server. Disattivato: può essere visualizzato nella parte superiore della pagina Dettagli Server.';

  @override
  String get needHomeDir =>
      'Se sei un utente Synology, [vedi qui](https://kb.synology.com/DSM/tutorial/user_enable_home_service). Gli utenti di altri sistemi devono cercare come creare una directory home.';

  @override
  String get needRestart => 'L\'app deve essere riavviata';

  @override
  String get netViewType => 'Tipo di visualizzazione rete';

  @override
  String get newContainer => 'Nuovo container';

  @override
  String get noConnectionStatsData =>
      'Nessun dato di statistiche di connessione';

  @override
  String get noLineChart => 'Non usare grafici a linee';

  @override
  String get noLineChartForCpu => 'Non usare grafici a linee per la CPU';

  @override
  String get noPrivateKeyTip =>
      'La chiave privata non esiste, potrebbe essere stata eliminata o c\'è un errore di configurazione.';

  @override
  String get noPromptAgain => 'Non chiedere di nuovo';

  @override
  String get onServerDetailPage => 'Nella pagina dettagli server';

  @override
  String get onlyOneLine => 'Visualizza solo come una riga (scorrevole)';

  @override
  String get onlyWhenCoreBiggerThan8 =>
      'Funziona solo quando il numero di core è maggiore di 8';

  @override
  String get openLastPath => 'Apri l\'ultimo percorso';

  @override
  String get openLastPathTip =>
      'Server diversi avranno log diversi e il log è il percorso di uscita';

  @override
  String get parseContainerStatsTip =>
      'L\'analisi dello stato di occupazione di Docker è relativamente lenta.';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$percent% di $size';
  }

  @override
  String get permission => 'Permessi';

  @override
  String get pingInputIP => 'Inserisci un IP / dominio di destinazione.';

  @override
  String get pingNoServer =>
      'Nessun server da pingare.\nAggiungi un server nella scheda server.';

  @override
  String get plugInType => 'Tipo di inserimento';

  @override
  String get preferDiskAmount => 'Priorità visualizzazione capacità disco';

  @override
  String get privateKey => 'Chiave privata';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
    return 'Chiave privata [$keyId] non trovata.';
  }

  @override
  String get pushToken => 'Token push';

  @override
  String get pveIgnoreCertTip =>
      'Non si consiglia di abilitare, attento ai rischi per la sicurezza! Se stai usando il certificato predefinito da PVE, devi abilitare questa opzione.';

  @override
  String get pveLoginFailed =>
      'Accesso fallito. Impossibile autenticarsi con nome utente/password dalla configurazione del server per l\'accesso Linux PAM.';

  @override
  String get pveVersionLow =>
      'Questa funzionalità è attualmente nella fase di test ed è stata testata solo su PVE 8+. Usala con cautela.';

  @override
  String get read => 'Leggi';

  @override
  String get recentConnections => 'Connessioni recenti';

  @override
  String get rememberPwdInMem => 'Ricorda password in memoria';

  @override
  String get rememberPwdInMemTip =>
      'Utilizzato per container, sospensione, ecc.';

  @override
  String get rememberWindowSize => 'Ricorda dimensione finestra';

  @override
  String get remotePath => 'Percorso remoto';

  @override
  String get result => 'Risultato';

  @override
  String get rotateAngel => 'Angolo di rotazione';

  @override
  String get sameIdServerExist => 'Esiste già un server con lo stesso ID';

  @override
  String get save => 'Salva';

  @override
  String get second => 's';

  @override
  String get serverDetailOrder => 'Ordine widget pagina dettagli';

  @override
  String get serverFuncBtns => 'Pulsanti funzione server';

  @override
  String get serverOrder => 'Ordine server';

  @override
  String get serverTabRequired => 'La scheda server non può essere rimossa';

  @override
  String get sftpDlPrepare => 'Preparazione alla connessione...';

  @override
  String get sftpEditorTip =>
      'Se vuoto, usa l\'editor di file integrato dell\'app. Se è presente un valore, usa l\'editor del server remoto, ad es. `vim` (si consiglia di rilevare automaticamente secondo `EDITOR`).';

  @override
  String get sftpRmrDirSummary =>
      'Usa `rm -r` per eliminare una cartella in SFTP.';

  @override
  String get sftpSSHConnected => 'SFTP connesso';

  @override
  String get sftpShowFoldersFirst => 'Mostra prima le cartelle';

  @override
  String get showDistLogo => 'Mostra logo distribuzione';

  @override
  String get size => 'Dimensione';

  @override
  String get softWrap => 'A capo automatico';

  @override
  String get specifyDev => 'Specifica dispositivo';

  @override
  String get specifyDevTip =>
      'Ad esempio, le statistiche del traffico di rete sono per impostazione predefinita per tutti i dispositivi. Puoi specificare un dispositivo particolare qui.';

  @override
  String get speed => 'Velocità';

  @override
  String spentTime(Object time) {
    return 'Tempo impiegato: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'Tutti i server esistono già ($duplicateCount duplicati trovati)';
  }

  @override
  String sshConfigDuplicatesSkipped(Object duplicateCount) {
    return '$duplicateCount duplicati verranno saltati';
  }

  @override
  String get sshConfigFound =>
      'Abbiamo trovato la configurazione SSH sul tuo sistema.';

  @override
  String sshConfigFoundServers(Object totalCount) {
    return 'Trovati $totalCount server';
  }

  @override
  String get sshConfigImport => 'Importa configurazione SSH';

  @override
  String get sshConfigImportHelp =>
      'Solo le informazioni di base possono essere importate, ad esempio: IP/Porta.';

  @override
  String get sshConfigImportPermission =>
      'Vuoi dare il permesso di leggere ~/.ssh/config e importare automaticamente le impostazioni del server?';

  @override
  String get sshConfigImportTip =>
      'Chiedi di leggere ~/.ssh/config alla prima creazione del server';

  @override
  String sshConfigImported(Object count) {
    return 'Importati $count server dalla configurazione SSH';
  }

  @override
  String sshHostKeyChangedDesc(Object serverName) {
    return 'La chiave host SSH è cambiata per $serverName. Continua solo se ti fidi di questo server.';
  }

  @override
  String sshHostKeyFingerprintMd5Base64(Object fingerprint) {
    return 'Impronta digitale (MD5 base64): $fingerprint';
  }

  @override
  String sshHostKeyFingerprintMd5Hex(Object fingerprint) {
    return 'Impronta digitale (MD5 hex): $fingerprint';
  }

  @override
  String get sshHostKeyType => 'Tipo chiave host SSH';

  @override
  String sshHostKeyNewDesc(Object serverName) {
    return 'È stata ricevuta una nuova chiave host SSH da $serverName. Rivedi l\'impronta digitale prima di fidarti.';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
    return 'Impronta digitale memorizzata: $fingerprint';
  }

  @override
  String get sshConfigManualSelect =>
      'Vuoi selezionare manualmente il file di configurazione SSH?';

  @override
  String get sshConfigNoServers =>
      'Nessun server trovato nella configurazione SSH';

  @override
  String get sshConfigPermissionDenied =>
      'Impossibile accedere al file di configurazione SSH a causa dei permessi macOS.';

  @override
  String sshConfigServersToImport(Object importCount) {
    return '$importCount server verranno importati';
  }

  @override
  String get sshTermHelp =>
      'Quando il terminale è scorrevole, trascinare orizzontalmente può selezionare il testo. Cliccando il pulsante tastiera accende/spegne la tastiera. L\'icona file apre il percorso corrente SFTP. Il pulsante appunti copia il contenuto quando il testo è selezionato e incolla il contenuto dagli appunti nel terminale quando nessun testo è selezionato e c\'è contenuto negli appunti. L\'icona codice incolla snippet di codice nel terminale ed esegue.';

  @override
  String sshTip(Object url) {
    return 'Questa funzione è ora nella fase sperimentale.\n\nSegnala i bug su $url o unisciti al nostro sviluppo.';
  }

  @override
  String get sshVirtualKeyAutoOff =>
      'Commutazione automatica dei tasti virtuali';

  @override
  String get stat => 'Statistiche';

  @override
  String get supportFmtArgs =>
      'Sono supportati i seguenti parametri di formattazione:';

  @override
  String get suspendTip =>
      'La funzione di sospensione richiede il permesso root e il supporto systemd.';

  @override
  String switchTo(Object val) {
    return 'Passa a $val';
  }

  @override
  String get syncTip =>
      'Potrebbe essere necessario un riavvio affinché alcune modifiche abbiano effetto.';

  @override
  String get system => 'Sistema';

  @override
  String get tag => 'Tag';

  @override
  String get tapToStartDiscovery =>
      'Tocca il pulsante di ricerca per scoprire i server SSH sulla tua rete';

  @override
  String get termFontSizeTip =>
      'Questa impostazione influirà sulla dimensione del terminale (larghezza e altezza). Puoi ingrandire la pagina del terminale per regolare la dimensione del carattere della sessione corrente.';

  @override
  String get textScaler => 'Scalatore testo';

  @override
  String get textScalerTip =>
      '1.0 => 100% (dimensione originale), funziona solo su parte del carattere della pagina server, non si consiglia di cambiare.';

  @override
  String get time => 'Tempo';

  @override
  String get times => 'Volte';

  @override
  String get trySudo => 'Prova a usare sudo';

  @override
  String get unknown => 'Sconosciuto';

  @override
  String get unkownConvertMode => 'Modalità di conversione sconosciuta';

  @override
  String get update => 'Aggiorna';

  @override
  String get updateIntervalEqual0 =>
      'Hai impostato a 0, non aggiornerà automaticamente.\nNon può calcolare lo stato della CPU.';

  @override
  String get updateServerStatusInterval =>
      'Intervallo di aggiornamento stato server';

  @override
  String get upsideDown => 'Capovolto';

  @override
  String get useCdn => 'Utilizzo CDN';

  @override
  String get useCdnTip =>
      'Si consiglia agli utenti non cinesi di usare CDN. Vuoi usarlo?';

  @override
  String get useNoPwd => 'Non verrà usata nessuna password';

  @override
  String get usePodmanByDefault => 'Usa Podman per impostazione predefinita';

  @override
  String get used => 'Usato';

  @override
  String get view => 'Visualizza';

  @override
  String get viewDetails => 'Visualizza dettagli';

  @override
  String get viewErr => 'Vedi errore';

  @override
  String get virtKeyHelpClipboard =>
      'Copia negli appunti se il terminale selezionato non è vuoto, altrimenti incolla il contenuto degli appunti nel terminale.';

  @override
  String get virtKeyHelpIME => 'Accendi/spegni la tastiera';

  @override
  String get virtKeyHelpSFTP => 'Apri la directory corrente in SFTP.';

  @override
  String get waitConnection => 'Attendi che la connessione venga stabilita.';

  @override
  String get wakeLock => 'Mantieni sveglio';

  @override
  String get watchNotPaired => 'Nessun Apple Watch associato';

  @override
  String get webdavSettingEmpty => 'Impostazione WebDav vuota';

  @override
  String get whenOpenApp => 'All\'apertura dell\'app';

  @override
  String get wolTip =>
      'Dopo aver configurato WOL (Wake-on-LAN), viene inviata una richiesta WOL ogni volta che il server è connesso.';

  @override
  String get write => 'Scrivi';

  @override
  String get writeScriptFailTip =>
      'Scrittura dello script fallita, forse a causa di mancanza di permessi o la directory non esiste.';

  @override
  String get writeScriptTip =>
      'Dopo essersi connessi al server, uno script verrà scritto in `~/.config/server_box` \n | `/tmp/server_box` per monitorare lo stato del sistema. Puoi rivedere il contenuto dello script.';

  @override
  String get menuGitHubRepository => 'Repository GitHub';

  @override
  String get podmanDockerEmulationDetected =>
      'Rilevata emulazione Docker Podman. Passa a Podman nelle impostazioni.';
}
