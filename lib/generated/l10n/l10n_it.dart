// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get crashCollect => 'Dati diagnostici';

  @override
  String get crashCollectIntro =>
      'ServerBox registra ciò che accade durante l\'esecuzione per poter risolvere i problemi. Scegli quanti dati inviare.';

  @override
  String get crashCollectNone => 'Niente';

  @override
  String get crashCollectNoneTip =>
      'I rapporti restano su questo dispositivo; dopo un arresto anomalo puoi inviarne uno manualmente.';

  @override
  String get crashCollectBasic => 'Informazioni di base';

  @override
  String get crashCollectBasicTip =>
      'Include solo le informazioni sull\'arresto anomalo; non include log o dati sulle prestazioni. **Questo ci aiuta a migliorare l\'app e a correggere i bug.**';

  @override
  String get crashCollectFull => 'Informazioni complete';

  @override
  String get crashCollectFullTip =>
      'Oltre al registro dell\'arresto anomalo, include dati sulle prestazioni e l\'uso delle funzioni: **Servono a individuare cosa è lento e quali funzioni vengono davvero usate.**';

  @override
  String get crashCollectFooter =>
      'A ogni livello, i nomi dei server noti, i relativi indirizzi e nomi utente vengono sostituiti da segnaposto al momento della registrazione. Puoi modificare il livello di raccolta in seguito nelle impostazioni.';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacyPolicy => 'Informativa sulla privacy';

  @override
  String get crashLastRunFailed =>
      'ServerBox si è chiuso inaspettatamente durante l\'ultima esecuzione.';

  @override
  String get crashReportTitle => 'Rapporto di arresto anomalo';

  @override
  String get crashReportHint =>
      'Questo è il registro dell\'esecuzione precedente. I nomi e gli indirizzi dei server noti sono stati sostituiti da segnaposto, ma altri dettagli possono rimanere. Leggilo attentamente prima di inviarlo.';

  @override
  String get crashReportSubmit => 'Copia e segnala';

  @override
  String get preReleaseUpdates => 'Ricevi aggiornamenti pre-release';

  @override
  String get addSystemPrivateKeyTip =>
      'Attualmente non esistono chiavi private, vuoi aggiungere quella fornita dal sistema (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Aggiunto alla lista delle attività';

  @override
  String get askAi => 'Chiedi all\'IA';

  @override
  String get askAiInsertTerminal => 'Inserisci nel terminale';

  @override
  String get remoteDesktop => 'Desktop remoto';

  @override
  String get askAiRiskReadOnly => 'Sola lettura';

  @override
  String get askAiRiskCaution => 'Modifica il sistema';

  @override
  String get askAiRiskUnvetted => 'Host non verificato';

  @override
  String get askAiRiskDestructive => 'Rischio alto';

  @override
  String get askAiAutoRunSafeCommands =>
      'Esegui automaticamente i comandi di sola lettura';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Viene eseguito solo se modello e controllo locale lo dicono di sola lettura';

  @override
  String get askAiHistory => 'Cronologia conversazioni';

  @override
  String get askAiNewConversation => 'Nuova conversazione';

  @override
  String get askAiUntitledConversation => 'Senza titolo';

  @override
  String get askAiRenameConversation => 'Rinomina conversazione';

  @override
  String get askAiDeleteConversationTitle => 'Eliminare questa conversazione?';

  @override
  String get askAiDeleteConversationTip =>
      'La elimina da questo dispositivo. Non annullabile.';

  @override
  String get agentNoHistory =>
      'Nessuna conversazione globale dell\'Agente salvata';

  @override
  String get agentClearHistoryTitle =>
      'Cancellare la cronologia globale dell\'Agente?';

  @override
  String get agentClearHistoryTip =>
      'Tutte le conversazioni globali dell\'Agente verranno rimosse da questo dispositivo.';

  @override
  String get agentToolShell => 'Shell';

  @override
  String get agentToolReadFile => 'Leggi file';

  @override
  String get agentToolWriteFile => 'Scrivi file';

  @override
  String get floatOverTabs => 'In sovrimpressione sulle altre schede';

  @override
  String get agentToolSshConnect => 'Connetti SSH';

  @override
  String get agentToolSshDisconnect => 'Disconnetti SSH';

  @override
  String get agentSshConnectTitle => 'Connettersi a un nuovo host';

  @override
  String get agentAuthMethod => 'Autenticazione';

  @override
  String get agentSshConnectTip =>
      'L’Agent vuole una connessione SSH. Inserisci qui la password';

  @override
  String get agentAdHocSessions => 'Connessioni temporanee';

  @override
  String get agentSaveServerTitle => 'Salva come server';

  @override
  String get agentSaveServerTip =>
      'Questo host e la password inserita sono salvati su questo dispositivo';

  @override
  String get agentMonitorOptional => 'Agente monitor (facoltativo)';

  @override
  String get authFailTip => 'Autenticazione fallita. Controlla i dati';

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
  String get connectAll => 'Connetti tutti';

  @override
  String get disconnectAll => 'Disconnetti tutti';

  @override
  String get distIcon => 'Contrassegni di distribuzione';

  @override
  String get distIconIntroLegal =>
      'Un marchio indica solo ciò che questo dispositivo ha letto dal sistema remoto, informazione che può essere errata o non aggiornata, e non identifica né un derivato, né una ricompilazione, né una versione specifica. Quando non è identificabile, viene disegnata un\'icona generica.\n\nOgni marchio appartiene al rispettivo proprietario ed è usato qui solo per riferirsi al sistema che identifica.';

  @override
  String get distIconTip =>
      'Mostra accanto a ogni server un piccolo contrassegno del sistema che sembra eseguire';

  @override
  String get distNameMap => 'Corrispondenza dei nomi';

  @override
  String get distNameMapTip =>
      'Solo per una distribuzione il cui file ha un altro nome dove ospiti i marchi. La chiave è il nome usato da questa app; il valore è il nome da scaricare. Lascialo vuoto finché non manca alcun marchio.';

  @override
  String get logoUrl => 'URL del logo';

  @override
  String get logoUrlTip =>
      'L\'immagine grande in cima alla pagina di un server, nei suoi colori originali.';

  @override
  String get globe => 'Globo';

  @override
  String get locationTip =>
      'Dove questo server viene disegnato sul globo. Latitudine e poi longitudine, in gradi — ad esempio 39.9042, 116.4074.';

  @override
  String get markUrl => 'URL del marchio';

  @override
  String get markUrlTip =>
      'Il piccolo marchio accanto al nome di un server negli elenchi. Vuoto: nessuno.\n\nNon è la stessa immagine del logo';

  @override
  String get navTabMenuTip =>
      'Tieni premuta una scheda — o fai clic destro — per connettere o disconnettere in una volta tutto ciò che contiene.';

  @override
  String nTags(int count) {
    return '$count tag';
  }

  @override
  String get remoteBackupPasswordRequired =>
      'I backup remoti richiedono una password di backup non vuota';

  @override
  String get monitorHttpsRequired =>
      'Un agente monitor remoto richiede HTTPS, salvo che HTTP sia consentito.';

  @override
  String get monitorAllowInsecureHttp => 'Consenti HTTP';

  @override
  String get plainHttpTitle => 'Questo agent è servito su HTTP in chiaro';

  @override
  String get plainHttpTip =>
      'La password e tutto ciò che questa app chiede viaggerebbero in chiaro. Non è stato ancora inviato nulla.';

  @override
  String get allowForThisServer => 'Consenti per questo server';

  @override
  String get viewError => 'Vedi l\'errore';

  @override
  String get monitorAllowInsecureHttpTip =>
      'Solo su una rete privata fidata che cifra da sé il trasporto, come Tailscale';

  @override
  String monitorHttpTip(String url) {
    return 'Leggere lo stato di questo server dall\'API HTTP di un agente **monitor**, invece di eseguire comandi via SSH.\n\nL\'agente va prima installato sul server; andamenti, app per l\'orologio e widget dipendono da esso.\n\n[Installare un agente monitor]($url)';
  }

  @override
  String get backupTip =>
      'I dati esportati possono essere crittografati con password.\nConservali al sicuro.';

  @override
  String get icloudBackupStatusTitle => 'Stato del backup';

  @override
  String get icloudBackupStatusLoading =>
      'Caricamento dello stato del backup iCloud...';

  @override
  String get icloudBackupStatusError =>
      'Impossibile leggere i metadati del backup iCloud';

  @override
  String get icloudBackupStatusEmpty =>
      'Nessun file di backup iCloud trovato per ora';

  @override
  String get icloudBackupStateUploading => 'Caricamento';

  @override
  String get icloudBackupStateConflict => 'Conflitto rilevato';

  @override
  String get icloudBackupStateUploaded => 'Caricato';

  @override
  String get icloudBackupStateWaiting => 'In attesa di iCloud';

  @override
  String icloudBackupStatusSummary(String lastModified, String remoteState) {
    return 'Ultimo backup: $lastModified\nStato: $remoteState';
  }

  @override
  String get bgRun => 'Esegui in background';

  @override
  String get bgRunTip =>
      'Questa opzione significa solo che il programma cercherà di eseguire in background. Se può eseguire in background dipende dal fatto che il permesso sia abilitato o meno. Per le ROM Android basate su AOSP, disabilita \"Ottimizzazione batteria\" in questa app. Per MIUI/HyperOS, cambia la politica di risparmio energetico su \"Illimitato\".';

  @override
  String get trayReadings => 'Valori';

  @override
  String get trayChart => 'Grafico';

  @override
  String get trayChartNone => 'Nessuno';

  @override
  String get trayCompact => 'Righe compatte';

  @override
  String get trayCompactTip =>
      'Una riga per server, senza grafico. Linux usa sempre un layout a riga singola perché il menu del pannello viene inviato tramite D-Bus, che trasporta un’etichetta invece di un layout personalizzato; può comunque includere il grafico selezionato come immagine.';

  @override
  String get trayKeepRunning => 'Continua a funzionare nell’area di notifica';

  @override
  String get trayKeepRunningTip =>
      'Chiudendo la finestra, l’app rimane nella barra dei menu o nell’area di notifica e continua a monitorare i server. Disattiva questa opzione per fare in modo che il pulsante di chiusura termini l’app.';

  @override
  String get bgRunNeedsNotification =>
      'Restare in esecuzione in background richiede una notifica permanente, e questa app non ha il permesso per le notifiche. Tocca per concederlo.';

  @override
  String get clearAllStatsContent =>
      'Sei sicuro di voler cancellare tutte le statistiche di connessione del server? Questa azione non può essere annullata.';

  @override
  String get clearAllStatsTitle => 'Cancella tutte le statistiche';

  @override
  String clearServerStatsContent(String serverName) {
    return 'Sei sicuro di voler cancellare le statistiche di connessione per il server \"$serverName\"? Questa azione non può essere annullata.';
  }

  @override
  String clearServerStatsTitle(String serverName) {
    return 'Cancella statistiche $serverName';
  }

  @override
  String get clearThisServerStats => 'Cancella statistiche di questo server';

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
  String get copyPath => 'Copia percorso';

  @override
  String get customCmd => 'Comandi personalizzati';

  @override
  String get deleteServers => 'Elimina server in blocco';

  @override
  String get deleteDirRecursive =>
      'Elimina la cartella e tutto il suo contenuto';

  @override
  String get dirEmpty => 'Assicurati che la cartella sia vuota.';

  @override
  String get discoverSshServers => 'Scopri server SSH';

  @override
  String get discoveryFailed => 'Scoperta fallita';

  @override
  String get discoverySettings => 'Impostazioni scoperta';

  @override
  String get distro => 'Distribuzione';

  @override
  String get diskHealth => 'Salute disco';

  @override
  String dl2Local(String fileName) {
    return 'Scaricare $fileName in locale?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'Non ci sono container in esecuzione.\nQuesto potrebbe essere perché:\n- L\'utente di installazione di Docker non è lo stesso del nome utente configurato nell\'App.\n- La variabile d\'ambiente DOCKER_HOST non è stata letta correttamente. Puoi ottenerla eseguendo `echo \$DOCKER_HOST` nel terminale.';

  @override
  String get dockerProjectOther => 'Altri';

  @override
  String get dockerPruneTip =>
      'Rimuovi i dati inutilizzati per liberare spazio su disco';

  @override
  String get dockerStatistics => 'Statistiche Docker';

  @override
  String get editVirtKeys => 'Tasti virtuali';

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
  String get extraArgs => 'Argomenti extra';

  @override
  String get fallbackSshDest => 'Destinazione SSH di fallback';

  @override
  String get fdroidReleaseTip =>
      'Se hai scaricato questa app da F-Droid, si consiglia di disattivare questa opzione.';

  @override
  String fileTooLarge(String file, String size, String sizeMax) {
    return 'File \'$file\' troppo grande $size, max $sizeMax';
  }

  @override
  String get fileDirGone => 'Questa cartella non è più qui';

  @override
  String get fileDirGoneTip => 'È stato eliminato o rinominato';

  @override
  String get fullScreen => 'Schermo intero';

  @override
  String get fullScreenJitter => 'Jitter schermo intero';

  @override
  String get fullScreenJitterHelp => 'Per evitare il burn-in dello schermo';

  @override
  String get fullScreenTip =>
      'La modalità a schermo intero deve essere abilitata quando il dispositivo viene ruotato in modalità orizzontale? Questa opzione si applica solo alla scheda server.';

  @override
  String get githubGistIdOptional => 'ID del Gist (facoltativo)';

  @override
  String get githubGistToken => 'Token GitHub Gist';

  @override
  String get githubGistTokenEmpty => 'Il token è vuoto';

  @override
  String get goto => 'Vai a';

  @override
  String get homeTabs => 'Schede home';

  @override
  String get homeTabsCustomizeDesc =>
      'Personalizza quali schede appaiono nella home page e il loro ordine';

  @override
  String get ignoreCert => 'Ignora certificato';

  @override
  String get image => 'Immagine';

  @override
  String get macDmgBody =>
      'L’App Store richiede che questa app sia in sandbox, e una sandbox non può aprire un terminale. La versione DMG sì.\n\nLa versione App Store potrebbe non essere più aggiornata.';

  @override
  String get macDmgImportDenied =>
      'macOS non ha permesso di leggere i dati della versione precedente';

  @override
  String get macDmgImported => 'Dati della versione precedente importati';

  @override
  String get macDmgImportFailed =>
      'Impossibile leggere i dati della versione precedente';

  @override
  String get macDmgTip =>
      'Terminale locale ed esecuzione locale degli snippet (versione DMG)';

  @override
  String get macDmgTitle => 'Versione DMG';

  @override
  String get showHiddenFiles => 'Mostra i file nascosti';

  @override
  String get sshKeyAlgorithm => 'Algoritmo';

  @override
  String get sshKeyComment => 'Commento';

  @override
  String get sshKeyGenerate => 'Genera coppia di chiavi';

  @override
  String get sshKeyGenerating => 'Generazione…';

  @override
  String sshKeyLockedFmt(String name) {
    return 'La chiave privata [$name] non è stata sbloccata.';
  }

  @override
  String get sshKeyPassphraseTip =>
      'Facoltativo. Una chiave con passphrase viene salvata cifrata e la passphrase è richiesta al primo uso della chiave.';

  @override
  String get sshKeyPassphraseWrong => 'Passphrase errata.';

  @override
  String get sshKeyPublicKey => 'Chiave pubblica';

  @override
  String get sshKeyPublicKeyTip =>
      'Aggiungi questa riga a ~/.ssh/authorized_keys sul server.';

  @override
  String get sshKeyRecommended => 'Consigliato';

  @override
  String sshKeyUnlockTip(String name) {
    return 'Inserisci la passphrase della chiave privata [$name].';
  }

  @override
  String get ungrouped => 'Senza gruppo';

  @override
  String get containerReclaimable => 'Recuperabile';

  @override
  String get unused => 'Inutilizzato';

  @override
  String get dangling => 'Orfana';

  @override
  String get pruneUnusedImages => 'Rimuovi immagini inutilizzate';

  @override
  String get pruneDanglingImages => 'Rimuovi immagini orfane';

  @override
  String get pruneImages => 'Rimuovi immagini';

  @override
  String get unusedTaggedImages => 'Etichettate inutilizzate';

  @override
  String get pruneDanglingImagesTip => 'Rimuove solo le immagini orfane.';

  @override
  String get pruneUnusedImagesTip =>
      'Rimuove anche le immagini con tag non usate da alcun container.';

  @override
  String get includeUnusedVolumesTip =>
      'Rimuove anche i volumi non usati da alcun container.';

  @override
  String get pruneCommandPreview => 'Anteprima comando';

  @override
  String get pruneForceSshTip =>
      '-f salta la conferma interattiva ed è sempre attivo durante l\'esecuzione SSH.';

  @override
  String get pruneVolumes => 'Rimuovi volumi inutilizzati';

  @override
  String get pruneUnusedData => 'Rimuovi dati inutilizzati';

  @override
  String get pull => 'Pull';

  @override
  String get invalidHostFormat =>
      'Formato host non valido. Sono consentiti solo caratteri IPv4, IPv6 e di dominio.';

  @override
  String get jumpServer => 'Server di salto';

  @override
  String jumpServersNotFoundFmt(String serverName, String jumpIds) {
    return 'Jump server non trovati per $serverName: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(String name) {
    return '«$name» esiste già';
  }

  @override
  String get noJumpServerAvailable => 'Nessun jump server disponibile.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Jump server e ProxyCommand non possono essere usati insieme.';

  @override
  String get noConnectionMethod =>
      'Configura SSH, un agente monitor, o entrambi';

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
  String get letterCache => 'Input da tastiera normale';

  @override
  String get letterCacheTip =>
      'Quando è attiva, l\'input passa attraverso l\'IME normale, il che può evitare i prompt della tastiera sicura nel terminale su alcuni sistemi.';

  @override
  String get linuxShellTip =>
      'Con quale shell parte un terminale. Vuoto ripristina /bin/sh.';

  @override
  String get linuxNetTip => 'Server DNS. Vuoto ripristina i valori predefiniti';

  @override
  String madeWithLove(String myGithub) {
    return 'Realizzato con ❤️ da $myGithub';
  }

  @override
  String get maxConcurrency => 'Massima concorrenza';

  @override
  String get maxRetryCount => 'Numero di riconnessioni del server';

  @override
  String get mirror => 'Mirror';

  @override
  String get needRestart => 'L\'app deve essere riavviata';

  @override
  String get newContainer => 'Nuovo container';

  @override
  String get noConnectionStatsData =>
      'Nessun dato di statistiche di connessione';

  @override
  String get noPrivateKeyTip =>
      'La chiave privata non esiste, potrebbe essere stata eliminata o c\'è un errore di configurazione.';

  @override
  String get noPromptAgain => 'Non chiedere di nuovo';

  @override
  String get openLastPath => 'Apri l\'ultimo percorso';

  @override
  String get openLastPathTip =>
      'Server diversi avranno log diversi e il log è il percorso di uscita';

  @override
  String get parseContainerStatsTip =>
      'L\'analisi dello stato di occupazione di Docker è relativamente lenta.';

  @override
  String get privateKey => 'Chiave privata';

  @override
  String privateKeyNotFoundFmt(String keyId) {
    return 'Chiave privata [$keyId] non trovata.';
  }

  @override
  String get bmcPowerOnAction => 'Accendi';

  @override
  String get bmcShutdown => 'Spegni';

  @override
  String get bmcForceOff => 'Spegnimento forzato';

  @override
  String get restart => 'Riavvia';

  @override
  String get bmcPowerCycle => 'Ciclo di alimentazione';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return 'Inviare a $server? Al servizio verrà chiesto \"$resetType\"';
  }

  @override
  String get bmcPowerDone => 'Lo stato di alimentazione è cambiato';

  @override
  String get bmcPowerAccepted =>
      'Accettato, ma lo stato di alimentazione non è cambiato. Un’operazione graduale dipende dal sistema operativo';

  @override
  String get bmcPowerUnsupported =>
      'Questo servizio non consente nulla per quell\'azione';

  @override
  String get bmcUnauthorized => 'Il BMC ha rifiutato l\'account';

  @override
  String get bmcAccountMissing => 'Nessun account impostato per questo BMC';

  @override
  String get bmcPowerOn => 'Acceso';

  @override
  String get bmcPowerOff => 'Spento';

  @override
  String get bmcCertRejected =>
      'Certificato rifiutato — verificalo nelle impostazioni del server';

  @override
  String get bmcNotAService => 'Nessun servizio Redfish a questo indirizzo';

  @override
  String get bmcNoSystem => 'Il servizio non riporta alcun sistema';

  @override
  String get bmcSensorsTruncated => 'Sono mostrati solo i primi sensori';

  @override
  String get bmcMultipleSystems => 'Viene mostrato solo il primo sistema';

  @override
  String get bmcTip =>
      'Il BMC è un computer a sé sulla scheda madre, raggiungibile quando il sistema operativo dell\'host non lo è. Configurato qui, riporta stato di alimentazione e sensori hardware mentre il server è spento o bloccato. Richiede Redfish, presente sulla maggior parte dell\'hardware enterprise dal 2016 circa.';

  @override
  String get bmcCert => 'Certificato';

  @override
  String get bmcCertPinned => 'Verificato e fissato';

  @override
  String get bmcCertUnreviewed =>
      'Non ancora verificato — tocca per vedere il certificato';

  @override
  String get bmcCertReview =>
      'Un certificato autofirmato. Confrontalo prima di accettarlo. Dopo si fida solo di quello.';

  @override
  String get bmcCertChanged => 'Il certificato non corrisponde. Controllalo.';

  @override
  String get bmcCertExpired => 'Scaduto.';

  @override
  String bmcCertWas(String fingerprint) {
    return 'Accettato in precedenza: $fingerprint';
  }

  @override
  String get bmcAddrInvalid =>
      'L\'indirizzo del BMC deve essere un URL, ad es. https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      'Questa versione è in sandbox: il comando riceve una home vuota, non la tua, quindi fallisce tutto ciò che legge ~/.ssh. La versione DMG no.';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return 'Impossibile leggere il file della chiave privata $path: $reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return 'Questa build non può leggere file fuori dal proprio container, quindi la chiave in $path non è raggiungibile. Importa la chiave nelle impostazioni oppure usa la versione DMG.';
  }

  @override
  String get pushToken => 'Token push';

  @override
  String get liveActivity => 'Attività live';

  @override
  String get liveActivityTip =>
      'Mostra le sessioni del terminale sulla schermata di blocco e nella Dynamic Island. Il nome del server e lo stato della connessione sono visibili senza sbloccare il dispositivo.';

  @override
  String get liveActivitySystemDisabled =>
      'iOS non lo consente. Gli interruttori si trovano in Impostazioni › ServerBox › Attività live e Impostazioni › Face ID e codice › Attività live.';

  @override
  String get proxyCommandNeedsLinux =>
      'ProxyCommand viene eseguito nell\'ambiente Linux di questo dispositivo. Installa prima un sistema Linux.';

  @override
  String get proxyCommandMobileTip =>
      'Su un telefono, il comando viene eseguito nel sistema Linux selezionato. Installa prima lì gli strumenti che usa (nc, socat, …).';

  @override
  String get pveIgnoreCertTip =>
      'Non si consiglia di abilitare, attento ai rischi per la sicurezza! Se stai usando il certificato predefinito da PVE, devi abilitare questa opzione.';

  @override
  String get pvePasswordRequired =>
      'È richiesta la password PVE. Impostala nelle impostazioni del server.';

  @override
  String get pveOtpRequired =>
      'Su questo server PVE è attiva l\'autenticazione a due fattori. Inserisci il codice OTP.';

  @override
  String get pveOtpCodeRequired => 'Il codice OTP è obbligatorio.';

  @override
  String get pveOtpVerificationFailed =>
      'Verifica OTP non riuscita. Riprova con un codice nuovo.';

  @override
  String get pveOtpTitle => 'Verifica OTP';

  @override
  String get pveOtpLabel => 'Codice OTP';

  @override
  String get pveInvalidResponseBody =>
      'Il login PVE ha restituito un corpo della risposta non valido.';

  @override
  String get pveInvalidResponseData =>
      'La risposta del login PVE non conteneva dati validi.';

  @override
  String get pveMissingAuthTicket =>
      'Il login PVE è riuscito ma non è stato restituito alcun ticket di autenticazione.';

  @override
  String get pveLoadingConnect => 'Connessione...';

  @override
  String get pvePassword => 'Password PVE';

  @override
  String get pvePasswordHint =>
      'Necessaria quando si usa l\'autenticazione SSH con chiave';

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
  String get remotePath => 'Percorso remoto';

  @override
  String rootfsUpdateTip(
    String distro,
    String installed,
    String latest,
    String pm,
  ) {
    return '$distro $installed è installato, $latest è disponibile. L’aggiornamento sostituisce l’intero container: i dati $pm vanno persi';
  }

  @override
  String linuxSystemInUse(String name) {
    return 'Chiudi i terminali su $name prima di eliminarlo';
  }

  @override
  String get rootfsSubtitle => 'Uno spazio utente Linux su questo dispositivo';

  @override
  String rootfsInstallTip(String distro, String version, int size) {
    return 'Scarica $distro $version (circa $size MB) e lo estrae su questo dispositivo.';
  }

  @override
  String get sameIdServerExist => 'Esiste già un server con lo stesso ID';

  @override
  String get second => 's';

  @override
  String get serverFilesUnavailableTip =>
      'Richiede SSH verso questo server, o server_box_monitor con la sua API file attiva.';

  @override
  String get back => 'Indietro';

  @override
  String get history => 'Cronologia';

  @override
  String get homeDir => 'Home';

  @override
  String selected(int count) {
    return '$count selezionati';
  }

  @override
  String get sendTo => 'Invia a…';

  @override
  String get serverFuncBtns => 'Pulsanti funzione server';

  @override
  String get serverOrder => 'Ordine server';

  @override
  String get serverOverview => 'Panoramica dei server';

  @override
  String get serverOverviewTip =>
      'Mostra il riepilogo in cima all\'elenco dei server e la barra dei server sopra un server aperto';

  @override
  String get serverTabEmpty => 'Ancora nessun server';

  @override
  String get serverTabRequired => 'La scheda server non può essere rimossa';

  @override
  String get shareCodeHint =>
      'Comunica queste cifre separatamente al destinatario. Non sono incluse nel codice QR.';

  @override
  String get shareCodePrompt => 'Codice a 6 cifre';

  @override
  String get shareCodeTitle => 'Codice monouso';

  @override
  String get shareExpired =>
      'Questa condivisione è scaduta. Richiedine una nuova.';

  @override
  String get shareImportFile => 'Da un file condiviso';

  @override
  String get shareImportTitle => 'Importa server condiviso';

  @override
  String get shareIncludesKey => 'La condivisione include la chiave privata.';

  @override
  String get shareOmittedBmc =>
      'Le credenziali BMC. L’indirizzo è incluso, ma le credenziali no.';

  @override
  String get shareOmittedJump =>
      'Il jump server, perché è salvato come server separato su questo dispositivo.';

  @override
  String get shareOmittedKeyPath =>
      'Il file della chiave, perché il suo percorso è valido solo su questo dispositivo.';

  @override
  String get shareOmittedMissingKey =>
      'La chiave privata, perché non è presente nell’archivio chiavi di questo dispositivo.';

  @override
  String get shareOmittedTip =>
      'Non incluso; il destinatario deve configurare:';

  @override
  String get sharePassphraseTip =>
      'Questa passphrase cifra il file. Il destinatario ne ha bisogno per importare il server e non può essere recuperata.';

  @override
  String shareQrTip(int minutes) {
    return 'I dati di connessione in questo codice QR sono cifrati. La condivisione scade tra $minutes minuti.';
  }

  @override
  String get shareScanQr => 'Scansiona un codice QR';

  @override
  String shareServerExists(String name) {
    return '“$name” su questo dispositivo usa già questo indirizzo. Importare comunque?';
  }

  @override
  String get shareTooBigForQr =>
      'Troppo grande per un codice QR. Condividilo invece come file.';

  @override
  String get shareTooNew =>
      'Questa condivisione è stata creata con una versione più recente di ServerBox. Aggiorna l’app per aprirla.';

  @override
  String get shareUnreadable =>
      'Questa non è una condivisione ServerBox valida.';

  @override
  String get shareVia => 'Condividi tramite';

  @override
  String get sftpDlPrepare => 'Preparazione alla connessione...';

  @override
  String get sftpEditorTip =>
      'Vuoto usa l’editor integrato. Per esempio `vim` (consigliato leggere `EDITOR`).';

  @override
  String get sftpRmrDirSummary =>
      'Usa `rm -r` per eliminare una cartella in SFTP.';

  @override
  String get sftpSSHConnected => 'SFTP connesso';

  @override
  String get sftpShowFoldersFirst => 'Mostra prima le cartelle';

  @override
  String get sftpUnavailableUseScp =>
      'Se questo host non ha il sottosistema SFTP, come molti dispositivi embedded, imposta il trasferimento file su SCP nelle impostazioni del server.';

  @override
  String get sshFileTransportTip =>
      'SFTP va bene per qualsiasi macchina attuale. Scegli SCP per un host vecchio o embedded il cui server SSH non ha il sottosistema SFTP: gli serve il comando `scp` e una shell che abbia anche le solite utilità per i file (`find`, `stat`, `mv`, `chmod`).';

  @override
  String get specifyDev => 'Specifica dispositivo';

  @override
  String get specifyDevTip =>
      'Il traffico di rete conta tutti i dispositivi; indicane uno qui';

  @override
  String get tempIsCelsiusTip =>
      'Se attivo, il valore della temperatura viene trattato come Celsius anziché millicelsius. Attivalo solo se la temperatura è visualizzata in modo errato (ad esempio 0,1 °C invece di 58 °C).';

  @override
  String spentTime(String time) {
    return 'Tempo impiegato: $time';
  }

  @override
  String sshConfigAllExist(int duplicateCount) {
    return 'Tutti i server esistono già ($duplicateCount duplicati trovati)';
  }

  @override
  String sshConfigDuplicatesSkipped(int duplicateCount) {
    return '$duplicateCount duplicati verranno saltati';
  }

  @override
  String get sshConfigFound =>
      'Abbiamo trovato la configurazione SSH sul tuo sistema.';

  @override
  String sshConfigFoundServers(int totalCount) {
    return 'Trovati $totalCount server';
  }

  @override
  String get sshConfigImport => 'Importa configurazione SSH';

  @override
  String get sshConfigImportPermission =>
      'Vuoi dare il permesso di leggere ~/.ssh/config e importare automaticamente le impostazioni del server?';

  @override
  String get sshConfigImportTip =>
      'Chiedi di leggere ~/.ssh/config alla prima creazione del server';

  @override
  String sshConfigImported(int count) {
    return 'Importati $count server dalla configurazione SSH';
  }

  @override
  String sshHostKeyChangedDesc(String serverName) {
    return 'La chiave host SSH è cambiata per $serverName. Continua solo se ti fidi di questo server.';
  }

  @override
  String get sshHostKeyType => 'Tipo chiave host SSH';

  @override
  String get sshKnownHostKeys => 'Host conosciuti';

  @override
  String get sshKnownHostKeysTip =>
      'Le chiavi host che questa app ha accettato';

  @override
  String sshHostKeyNewDesc(String serverName) {
    return 'È stata ricevuta una nuova chiave host SSH da $serverName. Rivedi l\'impronta digitale prima di fidarti.';
  }

  @override
  String sshHostKeyStoredFingerprint(String fingerprint) {
    return 'Impronta digitale memorizzata: $fingerprint';
  }

  @override
  String get sshVerificationCode => 'Codice di verifica';

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
  String sshConfigServersToImport(int importCount) {
    return '$importCount server verranno importati';
  }

  @override
  String get sshTermHelp =>
      'Quando il terminale è scorrevole, trascinare orizzontalmente può selezionare il testo. Cliccando il pulsante tastiera accende/spegne la tastiera. L\'icona file apre il percorso corrente SFTP. Il pulsante appunti copia il contenuto quando il testo è selezionato e incolla il contenuto dagli appunti nel terminale quando nessun testo è selezionato e c\'è contenuto negli appunti. L\'icona codice incolla snippet di codice nel terminale ed esegue.';

  @override
  String get sshVirtualKeyAutoOff =>
      'Commutazione automatica dei tasti virtuali';

  @override
  String get supportFmtArgs =>
      'Sono supportati i seguenti parametri di formattazione:';

  @override
  String get suspendTip =>
      'La funzione di sospensione richiede il permesso root e il supporto systemd.';

  @override
  String switchTo(String val) {
    return 'Passa a $val';
  }

  @override
  String get syncAppSettings => 'Sincronizza le impostazioni dell\'app';

  @override
  String get syncAppSettingsTip =>
      'Includi tema, layout, editor, terminale e altre preferenze del dispositivo nella sincronizzazione automatica.';

  @override
  String get termFontSizeTip =>
      'Questa impostazione influirà sulla dimensione del terminale (larghezza e altezza). Puoi ingrandire la pagina del terminale per regolare la dimensione del carattere della sessione corrente.';

  @override
  String get textScalerTip =>
      '1.0 => 100% (dimensione originale), funziona solo su parte del carattere della pagina server, non si consiglia di cambiare.';

  @override
  String get times => 'Volte';

  @override
  String get trySudo => 'Prova a usare sudo';

  @override
  String get sudoPromptNotFound =>
      'Nessuna richiesta di password sudo è attiva.';

  @override
  String get updateServerStatusInterval =>
      'Intervallo di aggiornamento stato server';

  @override
  String get useNoPwd => 'Non verrà usata nessuna password';

  @override
  String get usePodmanByDefault => 'Usa Podman per impostazione predefinita';

  @override
  String get used => 'Usato';

  @override
  String get viewDetails => 'Visualizza dettagli';

  @override
  String get virtKeyHelpIME => 'Accendi/spegni la tastiera';

  @override
  String get virtKeyHelpSFTP => 'Apri la directory corrente in SFTP.';

  @override
  String get virtKeyHelpSnippet =>
      'Scegli uno snippet ed eseguilo in questo terminale.';

  @override
  String get virtKeyHelpTmux =>
      'Passa da una sessione o finestra tmux all\'altra.';

  @override
  String get virtKeyIntroActions => 'Scorciatoie';

  @override
  String get virtKeyIntroActionsTip =>
      'Questi tasti non scrivono, aprono qualcosa. Tienine premuto uno per leggere cosa fa.';

  @override
  String get virtKeyIntroCustomizeTip =>
      'Nelle impostazioni del terminale puoi riordinarli, attivarne altri (file, sudo, F1–F12…) o nascondere quelli che non usi mai.';

  @override
  String get virtKeyIntroModifiers => 'Modificatori';

  @override
  String get virtKeyIntroModifiersTip =>
      'Toccane uno per attivarlo, poi tocca una lettera sulla tastiera. Vale solo per quel tasto.';

  @override
  String get virtKeyIntroNav => 'Navigazione';

  @override
  String get virtKeyIntroNavTip =>
      'Questi tasti spostano il cursore. Tieni premuta una freccia per ripeterla.';

  @override
  String get virtKeyIntroSelect =>
      'Finché il terminale ha qualcosa da scorrere, trascinando in orizzontale selezioni il testo.';

  @override
  String get virtKeyRows => 'Righe mostrate insieme';

  @override
  String get virtKeyRowsTip =>
      'Il resto va su una pagina a parte, che si scorre lateralmente.';

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

  @override
  String get betaTip =>
      'Questa funzione è ancora in beta. Il funzionamento non è garantito.';

  @override
  String get portForward_startPrompt =>
      'Aggiungi una regola di port forwarding per iniziare';

  @override
  String get portForward_localHost => 'Host locale';

  @override
  String get portForward_localPort => 'Porta locale';

  @override
  String get portForward_remoteHost => 'Host remoto';

  @override
  String get portForward_remotePort => 'Porta remota';

  @override
  String portForward_deleteConfirmFmt(String name) {
    return 'Eliminare $name?';
  }

  @override
  String get sponsor => 'Sponsor';

  @override
  String get sortByJoinTime => 'Per data di aggiunta';

  @override
  String get tmuxAutoAttach => 'Collegamento automatico a tmux';

  @override
  String get tmuxAuto => 'tmux automatico';

  @override
  String get tmuxAutoTip =>
      'Avvia o collega tmux automaticamente quando ci si connette via SSH';

  @override
  String get tmuxSessionSelector => 'Selettore di sessione';

  @override
  String get tmuxSessionSelectorTip =>
      'Mostra il selettore di sessione alla connessione';

  @override
  String get tmuxDefaultSessionName => 'Nome sessione predefinito';

  @override
  String get tmuxSessionName => 'Nome della sessione';

  @override
  String get tmuxNewSession => 'Nuova sessione';

  @override
  String get tmuxNewWindow => 'Nuova finestra';

  @override
  String get tmuxNoWindowsFound => 'Nessuna finestra trovata';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count finestre',
      one: '1 finestra',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Collegata';

  @override
  String get tmuxSkip => 'Salta';

  @override
  String get tmuxNotAvailable => 'tmux non è disponibile';

  @override
  String containerSegmentsMismatch(int count) {
    return 'Numero imprevisto di segmenti nella risposta del container: $count';
  }

  @override
  String get containerOperationInProgress =>
      'È già in corso un\'altra operazione sul container';

  @override
  String processCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count processi',
      one: '1 processo',
    );
    return '$_temp0';
  }

  @override
  String get processParseUnsupportedOutput =>
      'Il formato dell’elenco dei processi non è supportato.';

  @override
  String get processParseInvalidRows =>
      'Non è stato possibile leggere alcune voci dei processi.';

  @override
  String get processParseInvalidWindowsJson =>
      'Non è stato possibile leggere la risposta dei processi Windows.';

  @override
  String get processParseInvalidWindowsRows =>
      'Non è stato possibile leggere alcune voci dei processi Windows.';

  @override
  String get processKillTargetChanged =>
      'Il processo è cambiato o terminato. Aggiorna l’elenco e riprova.';

  @override
  String get processSearchHint => 'Nome, utente o PID';

  @override
  String processShowKernelThreads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostra $count thread del kernel',
      one: 'Mostra 1 thread del kernel',
    );
    return '$_temp0';
  }

  @override
  String get processForceKill => 'Termina forzatamente';

  @override
  String get processStarted => 'Avviato';

  @override
  String get processThreads => 'Thread';

  @override
  String get watchServers => 'Server sull\'orologio';

  @override
  String get watchServersTip =>
      'L’orologio interroga il monitor da solo, quindi si possono scegliere solo i server che ne hanno uno.';

  @override
  String get watchNoMonitorServer =>
      'Nessun server ha un agente monitor configurato';

  @override
  String get legacyStatusGoneTitle => 'Gli URL di stato non funzionano più';

  @override
  String get legacyStatusGoneBody =>
      'L\'app per l\'orologio e i widget leggevano un indirizzo `/status` scritto a mano. Quell\'endpoint è stato rimosso: restituiva solo valori correnti come testo, ed è per questo che non hanno mai potuto mostrare un grafico.\n\nOra leggono l\'API autenticata dell\'agente monitor, disegnano gli andamenti e restano sincronizzati con l\'app da soli. Configura il server una volta nell\'app e ogni orologio e widget lo riprenderà.';

  @override
  String get services => 'Servizi';

  @override
  String get status => 'Stato';

  @override
  String get enable => 'Abilita';

  @override
  String get disable => 'Disabilita';

  @override
  String get starting => 'Avvio in corso';

  @override
  String get stopping => 'Arresto in corso';

  @override
  String get serviceManagerUnsupported => 'Gestore dei servizi non supportato';

  @override
  String get serviceManagerUnsupportedTip =>
      'Questo server usa un gestore che ServerBox non supporta ancora. Sono supportati systemd, procd e OpenRC.';

  @override
  String serviceManagerFmt(String manager) {
    return 'Gestito da $manager';
  }

  @override
  String get serviceListFailed => 'Impossibile elencare i servizi';

  @override
  String get serviceDetailsUnavailable =>
      'Alcuni dettagli dei servizi non sono disponibili';

  @override
  String get serviceDetailsUnavailableTip =>
      'L\'elenco è utilizzabile, ma il gestore non ha restituito tutte le informazioni sullo stato o sull\'avvio.';

  @override
  String get systemdUserScopeMissing => 'Le unità utente non sono elencate';

  @override
  String get systemdUserScopeMissingTip =>
      'Questo account non ha un bus di sessione utente sul server, quindi vengono mostrate solo le unità di sistema.';

  @override
  String get serviceSearchHint => 'Nome dell\'unità';

  @override
  String get serviceNeedsAttention => 'Richiede attenzione';

  @override
  String serviceOtherUnits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count altre unità',
      one: '1 altra unità',
    );
    return '$_temp0';
  }

  @override
  String get serviceUnit => 'Unit';

  @override
  String get serviceUnitType => 'Tipo';

  @override
  String get serviceScope => 'Ambito';

  @override
  String get serviceStartup => 'Avvio';

  @override
  String serviceUpFor(String duration) {
    return 'attivo da $duration';
  }

  @override
  String serviceDownFor(String duration) {
    return 'inattivo da $duration';
  }

  @override
  String serviceNextIn(String duration) {
    return 'prossimo tra $duration';
  }

  @override
  String serviceStoppedAgo(String duration) {
    return 'Arrestato $duration fa';
  }

  @override
  String serviceExitStatus(int code) {
    return 'stato di uscita $code';
  }

  @override
  String get serviceFullJournal => 'Journal completo';

  @override
  String get serviceUnitFile => 'File dell\'unità';

  @override
  String serviceJournalRecent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ultime $count righe',
      one: 'Ultima riga',
    );
    return '$_temp0';
  }

  @override
  String get serviceJournalUnreadable =>
      'Questo account non può leggere il journal';

  @override
  String get serverUnreachable =>
      'Impossibile eseguire un comando su questo server';

  @override
  String get containerNoRuntime => 'Nessun runtime per container qui';

  @override
  String get containerNoRuntimeTip =>
      'Né `docker` né `podman` hanno risposto su questa macchina. Se uno dei due è installato per un altro account, attiva «Prova a usare sudo» nelle impostazioni.';

  @override
  String get containerUnreadable =>
      'Il runtime dei container ha risposto in un formato inatteso';

  @override
  String get power => 'Alimentazione';

  @override
  String get fan => 'Ventola';

  @override
  String get clockSpeed => 'Clock';

  @override
  String get vendor => 'Produttore';

  @override
  String get continueInTerminal => 'Continua nel terminale';

  @override
  String get askAiRiskUnknown => 'Non classificato';

  @override
  String get agentLocalExec => 'Esegui comandi su questo dispositivo';

  @override
  String get agentLocalExecTip =>
      'Lascia che l’Agent lavori sulla macchina che esegue ServerBox. Anche i comandi di sola lettura sono esaminati';

  @override
  String get agentLocalExecRootfsTip =>
      'Lascia che l’Agent lavori in locale, limitato al container Linux installato da ServerBox';

  @override
  String macDmgImportedPartly(String path) {
    return 'Dati della versione installata in precedenza importati. I file scaricati sono rimasti in $path.';
  }

  @override
  String get bmcAccount => 'Account';

  @override
  String get bmcAccountUnset =>
      'Nessuno selezionato: tocca per sceglierne o crearne uno';

  @override
  String bmcAccountShared(int count) {
    return 'Usato da $count server';
  }

  @override
  String get bmcAccounts => 'Account BMC';

  @override
  String get bmcAccountSharedTip => 'Modificarlo cambia ciò che usano tutti.';

  @override
  String bmcAccountInUse(int count) {
    return '$count server lo usano. Mantengono l\'indirizzo e perdono l\'account.';
  }

  @override
  String get bmcStaleWrite =>
      'Il BMC è cambiato durante la scrittura. Riprova.';

  @override
  String get privacyBlur => 'Privacy in background';

  @override
  String get privacyBlurTip =>
      'Nascondi il contenuto dell\'app nel selettore app';

  @override
  String get floatReturnToTab => 'Torna alla scheda';

  @override
  String get termInFloatWindow => 'Questo terminale è nella finestra mobile';

  @override
  String get globeEnabledTip =>
      'Disegna i server su un globo, dove sono i loro indirizzi. Spento rimuove il pulsante e ferma ogni ricerca.';

  @override
  String get geoShardsConsentAttribution =>
      'Geolocalizzazione IP di [DB-IP](https://db-ip.com), CC BY 4.0.';

  @override
  String get geoMissPrivate => 'Indirizzo privato';

  @override
  String get geoMissNoData => 'Nessun dato di posizione';

  @override
  String get globeGuide =>
      'Tocca qui per vedere i server su un globo, dove si trovano i loro indirizzi.';

  @override
  String get publicIp => 'IP pubblico';

  @override
  String get geoData => 'Dati a livello di città';

  @override
  String get geoDataTip =>
      'Dopo il download, tutte le ricerche geografiche usano i dati archiviati su questo dispositivo. Al servizio di download non vengono inviati né gli indirizzi dei server né l’attività di ricerca.';

  @override
  String get geoDataMissing => 'Non scaricati';

  @override
  String get geoDataUnreachable => 'Impossibile recuperare i dati.';

  @override
  String get geoDataRemoveFailed => 'Impossibile eliminare i dati.';

  @override
  String geoDataCurrent(String month) {
    return '$month è già installato.';
  }

  @override
  String geoDataConsent(String download, String disk) {
    return '**Download: $download · Spazio sul dispositivo: $disk.** Il set di dati completo viene archiviato su questo dispositivo e tutte le successive ricerche geografiche avvengono in locale. Al servizio di download non vengono inviati né gli indirizzi dei server né l’attività di ricerca.\n\nAggiornato ogni mese. Una versione più recente sostituisce i dati installati senza conservare una copia aggiuntiva. Puoi eliminarli in qualsiasi momento.';
  }

  @override
  String get benchmark => 'Benchmark';

  @override
  String get benchmarkIntro =>
      'Esegue Yet Another Bench Script su questo server per testare disco, rete e CPU. Un\'esecuzione completa richiede 10–20 minuti e continua anche se lasci questa pagina o chiudi l\'app.';

  @override
  String get benchmarkNoRuns => 'Nessun benchmark eseguito.';

  @override
  String get benchmarkRunning => 'Benchmark in corso';

  @override
  String get benchmarkStartFailed => 'Impossibile avviare il benchmark';

  @override
  String get benchmarkCancelConfirm =>
      'Interrompere questo benchmark? Tutte le misurazioni raccolte finora andranno perse.';

  @override
  String get benchmarkDeleteConfirm =>
      'Eliminare il risultato di questo benchmark?';

  @override
  String get benchmarkNothingSelected =>
      'Tutte le fasi sono disattivate. Verranno raccolte solo le informazioni di sistema e saranno necessari pochi secondi.';

  @override
  String get benchmarkDiskTip =>
      'fio con quattro dimensioni dei blocchi; circa 3 minuti. Scrive un file di test da 2 GB nella directory di lavoro e richiede altrettanto spazio libero.';

  @override
  String get benchmarkNetworkTip =>
      'iperf3 verso server pubblici; circa 4 minuti.';

  @override
  String get benchmarkReducedNetwork => 'Meno località';

  @override
  String benchmarkReducedNetworkTip(String full, String reduced) {
    return 'Tre località invece di sette. Il traffico stimato scende da $full a $reduced.';
  }

  @override
  String get benchmarkCpuTip =>
      'Scarica Geekbench, un programma proprietario, e **pubblica il risultato su una pagina pubblica di geekbench.com**, inclusi modello della CPU, numero di core e memoria.';

  @override
  String get benchmarkSensitiveOptions =>
      'Le opzioni seguenti scaricano ed eseguono software di terze parti su questo server oppure inviano informazioni sul server a terzi. Sono disattivate per impostazione predefinita.';

  @override
  String get benchmarkIpInfoTip =>
      'Invia l\'indirizzo pubblico di questo server a ip-api.com tramite HTTP non crittografato.';

  @override
  String get benchmarkIpInfo => 'Cerca proprietario IP';

  @override
  String get benchmarkPreferBin => 'Scarica fio e iperf3';

  @override
  String get benchmarkPreferBinTip =>
      'Li scarica da GitHub invece di usare i pacchetti dell\'host. Attiva questa opzione solo se nessuno dei due è installato sull\'host.';

  @override
  String get benchmarkWorkDir => 'Directory di lavoro';

  @override
  String get benchmarkWorkDirTip =>
      'Determina quale file system viene misurato dal test del disco. Se vuota, usa la directory home dell\'account di accesso.';

  @override
  String benchmarkEstimatedTime(int minutes) {
    return 'Circa $minutes min';
  }

  @override
  String benchmarkEstimatedTraffic(String size) {
    return 'Circa $size di traffico';
  }

  @override
  String get benchmarkPhaseSystem => 'Lettura delle informazioni di sistema';

  @override
  String get benchmarkPhaseDisk => 'Test del disco';

  @override
  String get benchmarkPhaseNetwork => 'Test della rete';

  @override
  String get benchmarkPhaseCpu => 'Test della CPU';

  @override
  String get benchmarkPhaseDone => 'Completamento';

  @override
  String get benchmarkResultUnreadable =>
      'Non è stato possibile leggere questo risultato come JSON. Il testo originale è riportato di seguito.';

  @override
  String get benchmarkViewOnGeekbench => 'Visualizza su Geekbench';

  @override
  String get benchmarkGeekbenchPublic =>
      'Questo risultato è pubblicato tramite il collegamento qui sopra.';

  @override
  String get benchmarkSingleCore => 'Single-core';

  @override
  String get benchmarkMultiCore => 'Multi-core';

  @override
  String get benchmarkIops => 'IOPS';

  @override
  String get benchmarkSend => 'Upload';

  @override
  String get benchmarkRecv => 'Download';

  @override
  String get benchmarkLatency => 'Latenza';

  @override
  String get benchmarkVirt => 'Virtualizzazione';

  @override
  String get benchmarkRawLog => 'Registro di esecuzione';

  @override
  String benchmarkUpstream(String version) {
    return 'Basato su Yet Another Bench Script ($version)';
  }

  @override
  String get benchmarkPhaseStarting => 'Avvio';

  @override
  String get benchmarkNoOutputYet =>
      'Ancora nessun output. Prima di mostrare la prima riga, YABS verifica che google.com e icanhazip.com siano raggiungibili. Sulle reti che bloccano uno dei due siti, questa operazione può richiedere diversi minuti.';

  @override
  String get tagsEmptyTip =>
      'Nessun tag. Aggiungine uno modificando un server e apparirà qui.';

  @override
  String get benchmarkNoServers =>
      'Aggiungi prima un server, poi torna per eseguire il benchmark.';

  @override
  String get schemaTooNewTitle => 'Questi dati sono più recenti dell’app';

  @override
  String schemaTooNewBody(int stored, int supported) {
    return 'Sono stati scritti da una versione più recente di ServerBox (archiviazione v$stored); questa versione può leggere fino a v$supported. Non è stato modificato nulla.';
  }

  @override
  String get schemaTooNewReinstall =>
      'Reinstalla la versione più recente per aprire tutto come prima.';

  @override
  String get schemaTooNewExportPlain => 'Esporta senza password';

  @override
  String get schemaTooNewPlainWarn =>
      'Il file conterrà in chiaro tutte le chiavi private SSH, le password dei server e le chiavi API. Chiunque ottenga il file avrà accesso a tutto.';

  @override
  String get schemaTooNewWipe => 'Elimina tutti i dati';

  @override
  String get schemaTooNewWipeConfirm =>
      'Tutti i server, le chiavi, gli snippet e le impostazioni su questo dispositivo verranno eliminati senza possibilità di annullare l’operazione. Un backup esportato qui sarebbe l’unica copia rimasta.';

  @override
  String get schemaTooNewWipeDone =>
      'Dati eliminati. Riapri l’app per ricominciare da zero.';

  @override
  String get schemaTooNewWipeFailed =>
      'Non è stato possibile eliminare alcuni dati e questa versione non può ancora aprire ciò che rimane. Reinstalla la versione più recente per accedervi.';

  @override
  String get systemUsers => 'Utenti';

  @override
  String get userManagerLinuxOnly =>
      'La gestione degli utenti di sistema attualmente supporta solo i server Linux.';

  @override
  String get userRegularAccount => 'Normale';

  @override
  String get userCurrentAccount => 'Account corrente';

  @override
  String get userSystemAccount => 'Account di sistema';

  @override
  String get userUid => 'UID';

  @override
  String get userLoginStatus => 'Stato';

  @override
  String get userLoginEnabled => 'Accesso abilitato';

  @override
  String get userDetailAccount => 'Account';

  @override
  String get userDetailSecurity => 'Sicurezza';

  @override
  String get userSshKeys => 'SSH keys';

  @override
  String get userExpires => 'Scadenza';

  @override
  String get userNever => 'Mai';

  @override
  String get userPasswordSet => 'Impostata';

  @override
  String get userPasswordLocked => 'Bloccata';

  @override
  String get userPasswordNone => 'Nessuna';

  @override
  String get userSuperuser => 'Superuser';

  @override
  String get userOpenShell => 'Apri shell';

  @override
  String get userRootChangesWarning =>
      'Le modifiche a root hanno effetto immediato su tutte le sessioni.';

  @override
  String get userComment => 'Commento';

  @override
  String get userPrimaryGroup => 'Gruppo principale';

  @override
  String get userSupplementaryGroups => 'Gruppi supplementari';

  @override
  String get userLoginShell => 'Shell di accesso';

  @override
  String get userCreateHome => 'Crea la directory home';

  @override
  String get userMoveHome =>
      'Sposta la directory home esistente quando cambia il percorso';

  @override
  String get userRemoveHome => 'Rimuovi la directory home';

  @override
  String get userPasswordCreateTip =>
      'Lascia vuota la password per creare un account con accesso tramite password bloccato.';

  @override
  String get userPasswordEditTip =>
      'Lascia vuota la password per mantenere quella esistente.';

  @override
  String funcUnavailableFmt(String func) {
    return '$func non è disponibile con la connessione di questo server.';
  }

  @override
  String funcNeedsAgentGrant(String func, String setting) {
    return '$func richiede di attivare $setting nel Monitor agent.';
  }

  @override
  String funcNeedsAgentUpdate(String func) {
    return '$func richiede un Monitor agent più recente.';
  }

  @override
  String get portForwardRemoteNeedsAgent =>
      'Gli inoltri remoti tramite il Monitor agent richiedono una versione più recente: aggiornalo sul server.';

  @override
  String get rangeLive => 'Dal vivo';

  @override
  String get diskIo => 'I/O disco';

  @override
  String get peak => 'picco';

  @override
  String get hardware => 'Hardware';

  @override
  String get cores => 'Core';

  @override
  String get historyNoStored =>
      'Solo un agente monitor archivia la cronologia. Questa connessione conserva ciò che l\'app ha visto da quando si è connessa.';

  @override
  String get noHistoryYet => 'Nessuna misurazione';

  @override
  String get noData => 'nessun dato';

  @override
  String get from => 'Da';

  @override
  String get to => 'A';

  @override
  String get beyondRetention => 'oltre quanto questo agent ha conservato';

  @override
  String agentRetentionFmt(String kept) {
    return 'L\'agent conserva $kept';
  }

  @override
  String get agentServerTools => 'Strumenti server';

  @override
  String get agentServerToolsTip =>
      'Eseguire comandi e leggere o scrivere file sui tuoi server, collegarsi ad altri host via SSH e usare le azioni di ServerBox.';

  @override
  String get agentTerminalTools => 'Terminale';

  @override
  String get agentTerminalToolsTip =>
      'Nelle chat del terminale: leggere ciò che mostra ed eseguire comandi sul suo server.';

  @override
  String get agentToolTerminalScreen => 'Leggi lo schermo';

  @override
  String get agentProviders => 'Provider';

  @override
  String get agentProvidersTip =>
      'Chiavi API, modelli e il modello di una nuova chat';

  @override
  String get agentTools => 'Strumenti';

  @override
  String get agentToolsTip => 'Cosa può usare l\'Agent e i suoi server MCP';

  @override
  String get agentSnippetToolsTip =>
      'Elencare, aggiungere, modificare ed eliminare gli snippet. Le modifiche vengono chieste.';

  @override
  String get agentVirtToolsTip =>
      'Leggere le VM e i container caricati dalla scheda Virtualizzazione.';

  @override
  String get agentBenchmarkToolsTip =>
      'Leggere i risultati dei benchmark e, con la tua approvazione, avviarne o fermarne uno.';

  @override
  String get agentRemoteDesktopToolsTip =>
      'Elencare i profili desktop remoto e, con la tua approvazione, connettere o disconnettere.';

  @override
  String get agentSkills => 'Skills';

  @override
  String get agentSkillsTip =>
      'Istruzioni per compiti specifici, installate da GitHub o da un link';

  @override
  String get agentPermissions => 'Permessi';

  @override
  String get agentEmptyHint =>
      'Chiedi dei tuoi server, o chiedi all\'Agent di fare qualcosa su di essi.';

  @override
  String get agentTerminalEmptyHint =>
      'Chiedi di questo server. L\'Agent può leggere questo terminale ed eseguire comandi qui.';

  @override
  String oldestSampleFmt(String time) {
    return 'campione più vecchio $time';
  }

  @override
  String get rangeEndsBeforeItStarts =>
      'La fine dell\'intervallo deve essere dopo il suo inizio.';

  @override
  String get samples => 'campioni';

  @override
  String get unavailable => 'non disponibile';

  @override
  String get metricUnavailableTip =>
      'Il resto della pagina non è interessato. Controlla sull\'host il comando da cui arriva questa lettura.';

  @override
  String get waitingFirstSample => 'In attesa del primo campione';

  @override
  String atTimeFmt(String time) {
    return 'alle $time';
  }

  @override
  String get stored => 'memorizzato';

  @override
  String lastSampleFmt(String ago) {
    return 'ultimo campione $ago';
  }

  @override
  String staleSinceFmt(String ago, String time) {
    return 'Tutto qui sotto è delle $time, $ago.';
  }

  @override
  String noDataBeforeFmt(String time) {
    return 'nessun dato prima delle $time';
  }

  @override
  String loadingRangeFmt(String range) {
    return 'Caricamento di $range…';
  }

  @override
  String noStoredHistoryFor(String metric) {
    return 'Nessuna cronologia archiviata per $metric';
  }

  @override
  String devicesFmt(int count) {
    return '$count dispositivi';
  }

  @override
  String devicesBusiestFmt(int count, String name) {
    return '$count dispositivi · $name il più carico';
  }

  @override
  String devicesPlottedFmt(int plotted, int total) {
    return '$plotted di $total dispositivi';
  }

  @override
  String sensorsHottestFmt(int count, String name) {
    return '$count sensori · $name il più caldo';
  }

  @override
  String get oneDeviceAtLeast => 'Almeno un dispositivo resta nel grafico.';

  @override
  String shownOfFmt(int shown, int total, String what) {
    return '$shown di $total $what';
  }

  @override
  String countOfFmt(int count, String what) {
    return '$count $what';
  }

  @override
  String get unitDevices => 'dispositivi';

  @override
  String get unitSensors => 'sensori';

  @override
  String get unitBatteries => 'batterie';

  @override
  String get unitCommands => 'comandi';

  @override
  String get unitReadings => 'letture';

  @override
  String get unitGpus => 'GPU';

  @override
  String get hottest => 'il più caldo';

  @override
  String get oldest => 'il più vecchio';

  @override
  String get notApplicable => 'non applicabile';

  @override
  String get attributes => 'attributi';

  @override
  String get powerOnHours => 'Ore di accensione';

  @override
  String get powerCycles => 'Cicli di accensione';

  @override
  String get lifeLeft => 'Vita residua';

  @override
  String get lifetimeWrite => 'Scrittura totale';

  @override
  String get lifetimeRead => 'Lettura totale';

  @override
  String get averageErase => 'Cancellazioni medie';

  @override
  String get unsafeShutdowns => 'Spegnimenti anomali';

  @override
  String get diskAllPassed => 'tutti PASSED';

  @override
  String diskWarningFmt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avvisi',
      one: '1 avviso',
    );
    return '$_temp0';
  }

  @override
  String diskWrongOfFmt(int total, int wrong) {
    return '$wrong di $total dispositivi';
  }

  @override
  String get diskSmartSortedTip => 'Peggiori per primi';

  @override
  String readAgoFmt(String ago) {
    return 'letto $ago';
  }

  @override
  String processesFmt(int count) {
    return '$count processi';
  }

  @override
  String diskFailingFmt(int count) {
    return '$count in errore';
  }

  @override
  String get diskSmartOpenTip => 'Tocca per vedere i suoi attributi';

  @override
  String get cycle => 'Cicli';

  @override
  String get window => 'finestra';

  @override
  String ofFmt(String total) {
    return 'su $total';
  }

  @override
  String get serverDetailCards => 'Schede della pagina dettagli';

  @override
  String get connection => 'Connessione';

  @override
  String get connectionTip =>
      'Possono essere attivi entrambi. L\'ordine è l\'ordine in cui vengono contattati.';

  @override
  String get transportNoneOn =>
      'Sono entrambi disattivati: questo server non può essere connesso.';

  @override
  String get thisDevice => 'Questo dispositivo';

  @override
  String get localServerTip =>
      'Legge direttamente questo dispositivo eseguendo qui lo script di stato. SSH e Monitor HTTP non vengono usati e le loro impostazioni vengono conservate.';

  @override
  String get localServerUnsupported =>
      'Questa piattaforma non può leggere questo dispositivo come server. Linux, Windows e la versione DMG di macOS possono farlo.';

  @override
  String get remoteDesktopIntro =>
      'Apre il desktop RDP o VNC di un server nell’app. La connessione passa per la connessione SSH del server o per il suo agente Monitor, quindi la porta del desktop non deve essere raggiungibile dalla rete.';

  @override
  String get remoteDesktopIntroProfiles =>
      'Salva un profilo per ogni desktop dal pulsante Desktop remoto di un server o dalla scheda Desktop remoto.';

  @override
  String get localServerIntro =>
      'Aggiunge come server il dispositivo su cui gira ServerBox. Stato, processi, servizi, container, terminale e file funzionano senza SSH né agente Monitor.';

  @override
  String get localServerAdd => 'Aggiungi questo dispositivo';

  @override
  String get localServerIntroFooter =>
      'Si può attivare anche in seguito, nella pagina di modifica di un server, sotto Connessione.';

  @override
  String get transportSectionOff =>
      'Disattivato. I campi qui sotto restano per quando lo riattiverai.';

  @override
  String get monitorAgent => 'Agente monitor';

  @override
  String get plainHttpEditTip =>
      'Credenziali e metriche attraversano la rete non cifrate. Tienilo su una LAN o su un indirizzo Tailscale, oppure metti l\'agente dietro TLS.';

  @override
  String get behaviour => 'Comportamento';

  @override
  String get optional => 'Facoltativo';

  @override
  String get sshAdvanced => 'SSH avanzate';

  @override
  String get sshAdvancedTip =>
      'Destinazione di riserva, ProxyCommand, server di salto, trasporto file, percorso remoto';

  @override
  String get sshLegacyAlgorithms => 'Algoritmi obsoleti';

  @override
  String get sshLegacyAlgorithmsTip =>
      'Per server SSH meno recenti, come router o switch, che offrono solo una chiave host SHA-1 `ssh-rsa` o uno scambio di chiavi SHA-1. Meno sicuro; attivalo solo per gli host che lo richiedono.';

  @override
  String get appearanceAndPlace => 'Aspetto e luogo';

  @override
  String get appearanceAndPlaceTip => 'Logo, coordinate';

  @override
  String get statusCollection => 'Raccolta dello stato';

  @override
  String get statusCollectionTip =>
      'Quali comandi vengono eseguiti, comandi personalizzati, quale dispositivo leggere';

  @override
  String get tagAllTags => 'Tutti i tag';

  @override
  String get tagMatching => 'Corrispondenze';

  @override
  String get tagNewHint => 'Nuovo tag';

  @override
  String tagCreateFmt(String tag) {
    return 'Crea #$tag';
  }

  @override
  String get tagOnThisServer => 'su questo server';

  @override
  String tagServersFmt(int count) {
    return '$count server';
  }

  @override
  String tagOnThisServerFmt(int count) {
    return '$count su questo server';
  }

  @override
  String get tagMatchesTyped => 'corrisponde a quanto digitato';

  @override
  String get tagEditorTip =>
      'Digitare filtra l\'elenco; il pulsante crea il tag e lo mette su questo server in un solo passaggio. La matita lo rinomina su ogni server che lo porta. Un tag che nessun server porta sparisce al salvataggio.';

  @override
  String get tagRenamesOnSave => 'Le rinomine si applicano al salvataggio';

  @override
  String get scheduledTasks => 'Scheduled tasks';

  @override
  String get scheduledTaskLinuxOnly =>
      'La gestione delle attività pianificate attualmente supporta solo i server Linux.';

  @override
  String get scheduledTaskUnavailable =>
      'crontab non è disponibile su questo server.';

  @override
  String get scheduledTaskPreserveTip =>
      'I commenti, le variabili di ambiente e le righe non riconosciute di questo crontab vengono mantenuti.';

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
      enabled,
      locale: localeName,
      other: '$enabled attive',
      one: '1 attiva',
    );
    return '$total attività · $_temp0';
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
      'Se disattivata, la riga viene scritta come commento.';

  @override
  String scheduledTaskEmptyFmt(String user) {
    return 'Nessuna attività pianificata per $user. Le attività aggiunte qui vengono scritte nel crontab dell\'account.';
  }

  @override
  String get scheduledTaskFieldMinute => 'Minute';

  @override
  String get scheduledTaskFieldHour => 'Hour';

  @override
  String get scheduledTaskFieldDayOfMonth => 'Giorno del mese';

  @override
  String get scheduledTaskFieldMonth => 'Month';

  @override
  String get scheduledTaskFieldDayOfWeek => 'Giorno della settimana';

  @override
  String get cronErrScheduleEmpty => 'È richiesta una pianificazione.';

  @override
  String get cronErrCommandEmpty => 'È richiesto un comando.';

  @override
  String get cronErrLineBreak =>
      'Una riga di crontab non può contenere interruzioni di riga.';

  @override
  String get cronErrMacro =>
      'Una macro è composta da una sola parola, ad esempio @reboot.';

  @override
  String get cronErrFieldCount =>
      'Una pianificazione cron contiene cinque campi oppure una macro, ad esempio @reboot.';

  @override
  String get cronAtBoot => 'At boot';

  @override
  String get cronEveryMin => 'Every minute';

  @override
  String cronEveryMinsFmt(int minutes) {
    return 'Ogni $minutes minuti';
  }

  @override
  String cronHourlyAtFmt(String minute) {
    return 'Ogni ora al minuto :$minute';
  }

  @override
  String cronEveryHoursFmt(int hours) {
    return 'Ogni $hours ore';
  }

  @override
  String cronEveryHoursAtFmt(int hours, String minute) {
    return 'Ogni $hours ore al minuto :$minute';
  }

  @override
  String cronDailyAtFmt(String time) {
    return 'Ogni giorno alle $time';
  }

  @override
  String cronWeekdaysAtFmt(String time) {
    return 'Nei giorni feriali alle $time';
  }

  @override
  String cronWeekdayAtFmt(String day, String time) {
    return 'Ogni $day alle $time';
  }

  @override
  String cronMonthlyAtFmt(int day, String time) {
    return 'Il giorno $day di ogni mese alle $time';
  }

  @override
  String get monitorSettings => 'Monitor settings';

  @override
  String get monitorAgentDefault => 'Agent default';

  @override
  String get monitorNeedsRestart => 'Ha effetto dopo il riavvio dell\'agent';

  @override
  String get monitorCollection => 'Collection';

  @override
  String get extendedInterval => 'Intervallo del ciclo esteso';

  @override
  String get idlePause => 'Sospendi quando non ci sono client in ascolto';

  @override
  String get idlePauseTip =>
      'Il ciclo esteso esegue smartctl, sensors e amd-smi. Sospenderlo quando nessun client richiede dati evita di riattivare un disco per dati che nessuno sta leggendo.';

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
      'Metrica: cpu / memory / swap / disk / network / temperature. Corrispondenza: cpu0 per un singolo core, used / free / avail per la memoria, rx / tx per la rete; per disco e temperatura viene ignorata. Soglia: un operatore di confronto e un valore, ad esempio >=80%, >=70c o >10m/s.';

  @override
  String get pushChannels => 'Canali di notifica';

  @override
  String get pushType => 'Type';

  @override
  String get pushRate => 'Rate limit';

  @override
  String get pushHeaders => 'Headers';

  @override
  String get pushSecretSet => 'Impostato nell\'agent, non visualizzato';

  @override
  String get pushSecretKeep => 'Lascia vuoto per mantenerlo';

  @override
  String get pushTestTip =>
      'Invia una notifica tramite questo canale con le impostazioni attuali, salvate o meno.';

  @override
  String get pushTestSent => 'Il canale ha accettato la notifica';

  @override
  String get pushTestFailed => 'Il canale ha rifiutato la notifica';

  @override
  String get pushTestMessage => 'Notifica di prova da ServerBox Monitor';

  @override
  String get pushUnknownType =>
      'Questo agent non dispone di un mittente per questo tipo di canale, quindi le impostazioni non vengono mostrate. Puoi rimuoverlo qui oppure modificarlo nel file config.toml dell\'agent.';

  @override
  String get pushJsonInvalid => 'non è un JSON valido';

  @override
  String get dataRetention => 'Data retention';

  @override
  String get dataRetentionTip =>
      'Se disattivata, l\'agent non elimina mai nulla e il database cresce senza limiti.';

  @override
  String get retentionMetrics => 'Keep metrics';

  @override
  String get retentionAlerts => 'Keep alerts';

  @override
  String get retentionCleanup => 'Esegui la pulizia ogni';

  @override
  String get retentionMaxDbSize => 'Limite delle dimensioni del database';

  @override
  String get corsOrigins => 'Origini consentite da CORS';

  @override
  String get corsOriginsTip =>
      'Origini dalle quali un pannello web può contattare questo agent. Se vuoto, sono consentite solo richieste dalla stessa origine.';

  @override
  String get monitorNoRemoteAccess =>
      'Questo agent è configurato solo per il monitoraggio. Qui non puoi aprire un terminale, eseguire comandi o sfogliare i file. Per attivare queste funzioni, modifica [remote_access] nel config.toml dell\'agent.';

  @override
  String get alerts => 'Avvisi';

  @override
  String get online => 'online';

  @override
  String get densityCards => 'Schede';

  @override
  String get densityRows => 'Righe';

  @override
  String get densityGrid => 'Griglia';

  @override
  String get connect => 'Connetti';

  @override
  String get disconnect => 'Disconnetti';

  @override
  String get searchServerTip =>
      'Cerca nomi e indirizzi — le due informazioni richieste per prime dall’editor.';

  @override
  String get addServerTip =>
      'Compilane uno, scansiona un codice QR oppure importa un file condiviso da qualcuno.';

  @override
  String get move => 'Sposta';

  @override
  String get moveToTop => 'Sposta all\'inizio';

  @override
  String get moveToBottom => 'Sposta alla fine';

  @override
  String get groupByTag => 'Raggruppa per tag';

  @override
  String get groupByTagTip => 'I tag si impostano nell’editor del server.';

  @override
  String get connecting => 'Connessione…';

  @override
  String get authShort => 'Auth';

  @override
  String get remoteDesktopFitToWindow => 'Adatta alla finestra';

  @override
  String get remoteDesktopActualSize => 'Dimensioni effettive';

  @override
  String get remoteDesktopZoom => 'Ingrandimento';

  @override
  String get remoteDesktopViewOnly => 'Solo visualizzazione';

  @override
  String get remoteDesktopDisableViewOnly => 'Disattiva solo visualizzazione';

  @override
  String get remoteDesktopSendClipboardText => 'Invia testo degli appunti';

  @override
  String get remoteDesktopShowKeyboard => 'Mostra tastiera';

  @override
  String get remoteDesktopMoreControls => 'Altri controlli';

  @override
  String get remoteDesktopUseDirectPointer => 'Usa puntatore diretto';

  @override
  String get remoteDesktopUseTouchpadPointer => 'Usa puntatore del touchpad';

  @override
  String get remoteDesktopSendCtrlAltDelete => 'Invia Ctrl+Alt+Canc';

  @override
  String get remoteDesktopReconnect => 'Riconnetti';

  @override
  String get remoteDesktopFullScreen => 'Schermo intero';

  @override
  String get remoteDesktopExitFullScreen => 'Esci da schermo intero';

  @override
  String get remoteDesktopCloseSession => 'Chiudi sessione';

  @override
  String get remoteDesktopConnected => 'Connesso';

  @override
  String get remoteDesktopConnecting => 'Connessione in corso';

  @override
  String get remoteDesktopReconnecting => 'Riconnessione in corso';

  @override
  String get remoteDesktopDisconnected => 'Disconnesso';

  @override
  String get remoteDesktopGuideTouch => 'Touchpad';

  @override
  String get remoteDesktopGuideTouchTip =>
      'Un dito muove il puntatore come un touchpad e un tocco fa clic. Tocca con due dita per il clic destro, trascina con due dita per scorrere e pizzica per lo zoom. Tocca due volte e tieni il dito appoggiato per trascinare.';

  @override
  String get remoteDesktopGuideKeyboardTip =>
      'Apre la tastiera su schermo. Ciò che digiti viene inviato al desktop remoto.';

  @override
  String get remoteDesktopGuideViewOnlyTip =>
      'Smette di inviare puntatore e tasti, così puoi guardare senza fare clic per errore.';

  @override
  String get remoteDesktopGuideMoreTip =>
      'Qui trovi Ctrl+Alt+Canc, la riconnessione e lo schermo intero.';

  @override
  String get remoteDesktopGuidePointerTip =>
      'Anche il puntatore diretto, in cui un dito fa clic dove tocca.';

  @override
  String get remoteDesktopVncClipboardLatin1Only =>
      'Gli appunti VNC supportano solo testo Latin-1.';

  @override
  String get remoteDesktopAddProfile => 'Aggiungi profilo';

  @override
  String get remoteDesktopNoProfiles => 'Nessun profilo di desktop remoto';

  @override
  String get remoteDesktopAdd => 'Aggiungi desktop remoto';

  @override
  String get remoteDesktopEdit => 'Modifica desktop remoto';

  @override
  String get remoteDesktopTargetTip =>
      'La destinazione viene risolta dal server SSH o dall\'agente Monitor. localhost indica quella macchina.';

  @override
  String get remoteDesktopDomain => 'Dominio (facoltativo)';

  @override
  String get remoteDesktopPassword => 'Password (facoltativa)';

  @override
  String get remoteDesktopSavePassword => 'Salva password';

  @override
  String get remoteDesktopSavePasswordTip =>
      'Salvata nel database cifrato. I backup includono le password salvate e sono cifrati solo se è impostata una password di backup.';

  @override
  String get remoteDesktopShareSession => 'Condividi sessione';

  @override
  String get remoteDesktopProtocol => 'Protocollo';

  @override
  String get remoteDesktopUniqueName =>
      'I nomi dei profili devono essere univoci per questo server.';

  @override
  String get remoteDesktopVncPasswordLength =>
      'Le password VNC classiche sono limitate a 8 byte ASCII.';

  @override
  String get remoteDesktopNameRequired => 'Inserisci un nome per il profilo.';

  @override
  String get remoteDesktopHostRequired => 'Inserisci un host di destinazione.';

  @override
  String get remoteDesktopPortRequired => 'Inserisci una porta valida.';

  @override
  String get remoteDesktopUsernameRequired => 'Inserisci il nome utente RDP.';

  @override
  String get remoteDesktopNameInvalid =>
      'Il nome del profilo può avere al massimo 64 caratteri e non può contenere a capo.';

  @override
  String get remoteDesktopHostInvalid =>
      'L’host di destinazione non può contenere spazi o a capo.';

  @override
  String get remoteDesktopCredentialInvalid =>
      'Nome utente e dominio possono avere al massimo 256 caratteri e non possono contenere a capo.';

  @override
  String get remoteDesktopVncPasswordAscii =>
      'Le password VNC classiche possono contenere solo caratteri ASCII.';

  @override
  String get remoteDesktopCertificateRequired =>
      'Conferma del certificato necessaria';

  @override
  String get remoteDesktopWaiting => 'In attesa del desktop…';

  @override
  String get remoteDesktopCertificateChanged =>
      'Il certificato del desktop remoto è cambiato';

  @override
  String get remoteDesktopTrustCertificate =>
      'Considerare attendibile il certificato?';

  @override
  String get remoteDesktopCertificateChangedTip =>
      'L\'impronta del certificato non corrisponde più al valore salvato. Verifica la nuova impronta prima di sostituire la fiducia.';

  @override
  String get remoteDesktopCertificateUnverifiedTip =>
      'Il sistema non ha potuto verificare questo certificato. Verifica la sua impronta SHA-256 prima di continuare.';

  @override
  String get remoteDesktopReplaceTrust => 'Sostituisci fiducia';

  @override
  String get remoteDesktopTrustReconnect =>
      'Considera attendibile e riconnetti';

  @override
  String remoteDesktopDeleteProfile(String name) {
    return 'Eliminare il profilo di desktop remoto “$name”?';
  }

  @override
  String remoteDesktopReconnectAttempt(int attempt) {
    return 'Riconnessione ($attempt/3)…';
  }

  @override
  String remoteDesktopPreviousCertificate(String fingerprint) {
    return 'Considerato attendibile in precedenza\n$fingerprint';
  }

  @override
  String remoteDesktopCertificateSubject(String subject) {
    return 'Soggetto: $subject';
  }

  @override
  String remoteDesktopCertificateIssuer(String issuer) {
    return 'Emittente: $issuer';
  }

  @override
  String remoteDesktopCertificateValidity(String start, String end) {
    return 'Valido: $start – $end';
  }

  @override
  String get pveAuthToken => 'Token API';

  @override
  String get pveVersionLow =>
      'Questa funzionalità è attualmente nella fase di test ed è stata testata solo su PVE 8+. Usala con cautela.';

  @override
  String get pveTokenId => 'ID token';

  @override
  String get pveTokenSecret => 'Segreto del token';

  @override
  String get pveTokenTip =>
      'Crealo in PVE in Datacenter → Permessi → API Tokens. Servono VM.Audit, VM.PowerMgmt, VM.Console, VM.Snapshot, VM.Snapshot.Rollback, Datastore.Audit e Sys.Audit sui percorsi da mostrare; con la separazione dei privilegi attiva, assegnali al token stesso.';

  @override
  String pveTokenNoPrivileges(String account, String command) {
    return 'Il token $account non può vedere nulla su questo host. Un token con separazione dei privilegi non ha i permessi del suo utente; concedigliene sull\'host PVE:\n$command\noppure togli la spunta a «Privilege Separation» per il token.';
  }

  @override
  String pveUserNoPrivileges(String account, String command) {
    return '$account non può vedere nulla su questo host. Concedigli i permessi sull\'host PVE:\n$command';
  }

  @override
  String get pveTokenIdInvalid =>
      'L\'ID del token deve avere la forma user@realm!tokenid';

  @override
  String get pvePasswordAuthTip =>
      'Accede come utente SSH nel realm PAM, con la password SSH, oppure con la password PVE qui sotto quando SSH usa una chiave. Se serve, viene chiesto un codice a due fattori.';

  @override
  String get pveCertUnpinned =>
      'Nessuno confermato finora. Se non è firmato da una CA attendibile, la prossima connessione mostrerà il certificato per la conferma.';

  @override
  String get pveCertForget => 'Dimentica certificato';

  @override
  String get pveCertForgetTip =>
      'La prossima connessione mostrerà di nuovo il certificato PVE per la conferma.';

  @override
  String get virtualization => 'Virtualizzazione';

  @override
  String get virtIntro =>
      'Gestisci macchine virtuali e container su host Proxmox VE e libvirt/KVM: stato, azioni di alimentazione e console.';

  @override
  String get virtIntroPveMoved =>
      'Proxmox VE è passato dalla pagina del server a questa scheda. La scheda PVE di un server la apre qui.';

  @override
  String get virtIntroLibvirt =>
      'Un server con virsh di libvirt installato compare come host, con le sue macchine virtuali QEMU/KVM.';

  @override
  String get virtIntroTransports =>
      'Entrambi funzionano via SSH, tramite un agente Monitor o su questo dispositivo.';

  @override
  String get virtIntroTokens =>
      'PVE può accedere con un token API invece di una password. Impostalo nella pagina di modifica del server, sotto PVE.';

  @override
  String get virtIntroInBar => 'È stata aggiunta alla barra delle schede.';

  @override
  String get virtIntroInMore =>
      'Si trova in Altro. Schede home, nelle impostazioni, può spostarla nella barra delle schede.';

  @override
  String get virtGuests => 'Macchine virtuali';

  @override
  String get virtHosts => 'Host';

  @override
  String get virtCheckServer => 'Controlla questo server';

  @override
  String get virtCheckAll => 'Controlla tutti i server';

  @override
  String get virtProbeNotChecked => 'Non ancora controllato';

  @override
  String get virtProbeAbsent => 'Non è un host';

  @override
  String virtProbeContainer(String kind) {
    return 'Container $kind';
  }

  @override
  String get virtProbeContainerTip =>
      'Questo server gira in un container, quindi è un guest e non un host. Si gestisce dall\'host che lo esegue.';

  @override
  String get virtProbePve => 'PVE, non configurato';

  @override
  String virtPveSetupTip(String version) {
    return 'Su questo server è in esecuzione $version. Inserisci l\'accesso API nelle impostazioni del server (è consigliato un token API) per gestire qui le sue macchine virtuali e i suoi container.';
  }

  @override
  String get virtNoHosts => 'Nessun host di virtualizzazione';

  @override
  String get virtNoHostsTip =>
      'Un server con Proxmox VE e l\'accesso API inserito è un host, e lo è anche uno dove virsh risponde. Gli altri server si possono controllare dal selettore degli host.';

  @override
  String get virtNoGuests => 'Nessuna macchina virtuale o container';

  @override
  String get virtPaused => 'In pausa';

  @override
  String get virtStarting => 'Avvio…';

  @override
  String get virtStopping => 'Arresto…';

  @override
  String get virtRebooting => 'Riavvio…';

  @override
  String get virtMigrating => 'Migrazione…';

  @override
  String get virtBackingUp => 'Backup in corso…';

  @override
  String get virtResume => 'Riprendi';

  @override
  String get virtOverview => 'Panoramica';

  @override
  String get virtConsole => 'Console';

  @override
  String get virtConsoleNone => 'Nessuna console configurata per questo guest';

  @override
  String get virtConsoleGraphical => 'Grafica';

  @override
  String get virtVncPasswordNeeded => 'Questo display richiede una password';

  @override
  String get virtConsoleSerialTip =>
      'Apre la console seriale del guest con virsh sull\'host. Disconnetti, o Ctrl+], torna alla shell dell\'host.';

  @override
  String virtConsoleVia(String transport) {
    return 'tramite $transport';
  }

  @override
  String get virtConsoleEnterTip => 'Nessun output? Premi Invio';

  @override
  String virtConsoleAutoEnter(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds secondi',
      one: '1 secondo',
    );
    return 'Invio verrà premuto tra $_temp0 per mostrare il prompt';
  }

  @override
  String get virtConsoleEnterNow => 'Ora';

  @override
  String get virtOffTip =>
      'Avviala per vedere qui CPU, memoria, disco e rete in tempo reale.';

  @override
  String get virtAllocated => 'Allocato';

  @override
  String virtRunningCount(int running, int total) {
    return '$running in esecuzione · $total in totale';
  }

  @override
  String get virtTemplate => 'Modello';

  @override
  String get virtAutostart => 'Si avvia con l\'host';

  @override
  String get virtErrUnreachable => 'Impossibile raggiungere questo host';

  @override
  String get virtErrNotConfigured =>
      'Le impostazioni PVE di questo server sono incomplete';

  @override
  String get virtErrNotConfiguredTip =>
      'Controlla l\'indirizzo e la password o il token API nelle impostazioni del server.';

  @override
  String get virtErrAuthFailed => 'L\'host ha rifiutato l\'accesso';

  @override
  String get virtErrCertUnconfirmed => 'Conferma il certificato dell\'host';

  @override
  String get virtErrCertChanged => 'Il certificato dell\'host è cambiato';

  @override
  String get virtErrRelayNotGranted =>
      'L\'agent Monitor non inoltra le connessioni';

  @override
  String get virtErrExecNotGranted => 'L\'agent Monitor non esegue comandi';

  @override
  String get virtErrNotInstalled => 'virsh non è installato su questo server';

  @override
  String get virtErrServerRemoved => 'Questo server non esiste più';

  @override
  String get virtErrSudoRequired =>
      'sudo richiede una password per accedere a libvirt';

  @override
  String get virtErrSudoRejected => 'sudo ha rifiutato la password';

  @override
  String get virtErrInvalidResponse =>
      'L\'host ha risposto in una forma inattesa';

  @override
  String get virtErrActionFailed => 'L\'host ha rifiutato l\'azione';

  @override
  String get remoteSessionIdleTimeout => 'Chiudi quando lasciata';

  @override
  String get remoteSessionIdleTimeoutTip =>
      'Per quanto tempo un desktop remoto o la console di un guest resta connesso dopo che lo lasci. Prima della chiusura, un avviso ti dà 10 secondi per mantenerlo.';

  @override
  String get remoteSessionKeepAlive => 'Mantieni';

  @override
  String get remoteSessionClosedAway => 'Chiuso per inattività';

  @override
  String remoteSessionClosingIn(int seconds) {
    return 'Chiusura tra $seconds s';
  }

  @override
  String get virtSnapshots => 'Snapshot';

  @override
  String get virtSnapshotCreate => 'Crea snapshot';

  @override
  String get virtSnapshotNone => 'Nessuno snapshot';

  @override
  String get virtSnapshotWithMemory => 'Dischi e memoria';

  @override
  String get virtSnapshotDiskOnly => 'Solo dischi';

  @override
  String get virtSnapshotParent => 'Padre';

  @override
  String get virtSnapshotRevert => 'Ripristina';

  @override
  String get virtSnapshotMemory => 'Includi la memoria';

  @override
  String get virtSnapshotMemoryTip =>
      'Il ripristino riprende il guest da questo momento.';

  @override
  String get virtSnapshotMemoryAlways =>
      'Qui uno snapshot di un guest in esecuzione include sempre la sua memoria.';

  @override
  String get virtSnapshotMemoryOff =>
      'Il guest non è in esecuzione, quindi vengono salvati solo i dischi.';

  @override
  String get virtSnapshotNameInvalid =>
      'Prima una lettera, poi lettere, cifre, - o _; da 2 a 40 caratteri.';

  @override
  String get virtSnapshotNameTaken =>
      'Esiste già uno snapshot con questo nome.';

  @override
  String get virtSnapshotRevertTip =>
      'Il ripristino scarta tutte le modifiche fatte dopo lo snapshot.';

  @override
  String virtSnapshotRevertAsk(String guest, String snapshot) {
    return 'Ripristinare $guest a $snapshot? Tutte le modifiche da allora andranno perse.';
  }

  @override
  String virtSnapshotRevertStops(String guest) {
    return 'Questo snapshot non ha memoria: $guest verrà arrestato.';
  }

  @override
  String get virtSnapshotStartAfter => 'Avvialo dopo';

  @override
  String get virtVolumes => 'Volumi';

  @override
  String get virtNoPools => 'Nessun pool di archiviazione';

  @override
  String get virtNoNetworks => 'Nessuna rete';

  @override
  String get virtPoolInactive =>
      'Il pool non è attivo, quindi i suoi volumi non possono essere elencati.';

  @override
  String get virtShared => 'Condiviso tra i nodi';

  @override
  String get virtBackingFile => 'File di base';

  @override
  String get virtNetIsolated => 'Isolata';

  @override
  String get virtNetBridged => 'Bridge';

  @override
  String get virtNetRouted => 'Instradata';

  @override
  String get virtBridge => 'Bridge';

  @override
  String get virtPorts => 'Porte';

  @override
  String get virtAttachedGuests => 'Guest collegati';

  @override
  String get virtNoAttachedGuests => 'Nessun guest collegato';

  @override
  String get virtCreateVm => 'Nuova macchina virtuale';

  @override
  String get virtCreateLxc => 'Nuovo container';

  @override
  String get virtCreateGuest => 'Nuova macchina virtuale o nuovo container';

  @override
  String get virtKindVm => 'Macchina virtuale';

  @override
  String get virtKindLxc => 'Container';

  @override
  String get virtHostname => 'Nome host';

  @override
  String get virtInstallMedia => 'Supporto di installazione';

  @override
  String get virtNoIsos => 'Nessuna immagine ISO su questo host';

  @override
  String get virtNoTemplates =>
      'Nessun modello di container su questo host. I modelli CT di uno storage in PVE permettono di scaricarne uno.';

  @override
  String get virtNoDiskStorage =>
      'Nessuno storage di questo host accetta un nuovo disco';

  @override
  String get virtStartAfterCreate => 'Avviala dopo la creazione';

  @override
  String get virtUnprivileged => 'Container non privilegiato';

  @override
  String get virtUnprivilegedTip =>
      'Il suo root è un utente normale sull\'host.';

  @override
  String get virtSshKeys => 'Chiavi pubbliche SSH';

  @override
  String get virtCredentialsTip =>
      'Una password di root, chiavi SSH o entrambe.';

  @override
  String virtCreated(String name) {
    return '$name creato';
  }

  @override
  String virtCreatedNotStarted(String name) {
    return '$name è stato creato ma non si è avviato';
  }

  @override
  String get virtErrExists => 'Esiste già un guest o un disco con questo nome';

  @override
  String get virtCreateNameInvalidLibvirt =>
      'Lettere, cifre, ., _ e -, iniziando con una lettera o una cifra; fino a 63 caratteri.';

  @override
  String get virtCreateNameInvalidPve =>
      'Lettere, cifre e -, in parti separate da punti; fino a 63 caratteri.';

  @override
  String get virtCreateNameTaken => 'Esiste già un guest con questo nome.';

  @override
  String get virtCreateVmidTaken => 'Questo VMID è occupato.';

  @override
  String get virtCreateCoresInvalid =>
      'Più core di quanti ne consenta questo host.';

  @override
  String get virtCreateMemoryInvalid => 'Memoria insufficiente.';

  @override
  String get virtCreateStorageMissing => 'Scegli dove va il suo disco.';

  @override
  String get virtCreateDiskInvalid => 'Da 1 GiB a 64 TiB.';

  @override
  String get virtCreateTemplateMissing => 'Scegli un modello.';

  @override
  String get virtCreateCredentialsMissing =>
      'Imposta una password di root o una chiave SSH.';

  @override
  String virtCreatePasswordShort(int min) {
    return 'Almeno $min caratteri.';
  }

  @override
  String get virtCreateSshKeysInvalid =>
      'Una chiave pubblica OpenSSH per riga.';

  @override
  String get virtDeleteDisks => 'Elimina anche i suoi dischi';

  @override
  String get virtDeleteDisksPve =>
      'I suoi dischi vengono eliminati con esso; il supporto di installazione viene conservato.';

  @override
  String virtDeleted(String name) {
    return '$name eliminato';
  }

  @override
  String get pveTokenTipCreate =>
      'Creare ed eliminare guest richiede anche VM.Allocate, VM.Config.*, Datastore.AllocateSpace e SDN.Use.';

  @override
  String get pveTokenTipHardware =>
      'Modificare l\'hardware richiede VM.Config.CPU, VM.Config.Memory, VM.Config.Disk, VM.Config.CDROM, VM.Config.Network e VM.Config.Options; nuovi dischi e interfacce richiedono anche Datastore.AllocateSpace e SDN.Use. La scheda video e i dispositivi USB e PCI richiedono anche VM.Config.HWType; un dispositivo passato tramite una mappatura di risorse richiede Mapping.Use su di essa, e Mapping.Audit per elencarle.';

  @override
  String get pveTokenTipBackup =>
      'La clonazione richiede VM.Clone, il backup e il ripristino VM.Backup, e la conversione in modello VM.Allocate; le attività di backup richiedono anche Sys.Audit per leggerle e Sys.Modify su / per crearle, modificarle ed eliminarle, con Datastore.AllocateSpace dove va la copia o il backup.';

  @override
  String get virtErrConflict => 'Modificato altrove';

  @override
  String get virtErrConflictTip =>
      'Qualcuno ha modificato questa configurazione dopo che è stata letta qui, quindi non è stato cambiato nulla. È stata riletta: ripeti la modifica se serve ancora.';

  @override
  String get virtHardware => 'Hardware';

  @override
  String get virtHwAddDisk => 'Aggiungi disco';

  @override
  String get virtHwAddMount => 'Aggiungi punto di montaggio';

  @override
  String get virtHwAddNic => 'Aggiungi interfaccia di rete';

  @override
  String get virtHwAppliesOnRestart =>
      'Salvato. Avrà effetto al prossimo avvio.';

  @override
  String get virtHwAutostart => 'Avvia con l\'host';

  @override
  String get virtHwAutostartPve => 'onboot · avviati in ordine di VMID';

  @override
  String get virtHwBalloonLibvirt => 'Memoria attuale';

  @override
  String get virtHwBalloonNote =>
      'Consente all\'host di riprendersi la memoria inutilizzata del guest quando scarseggia';

  @override
  String get virtHwBoot => 'Avvio';

  @override
  String get virtHwBootOrder => 'Ordine di avvio';

  @override
  String get virtHwBootTip =>
      'Le frecce spostano un dispositivo; toccandolo si attiva o disattiva l\'avvio da esso.';

  @override
  String get virtHwCdrom => 'CD-ROM';

  @override
  String get virtHwConfigFile => 'File di configurazione';

  @override
  String get virtHwCores => 'Core';

  @override
  String get virtHwCpuTypeDefault => 'Predefinito';

  @override
  String get virtHwDeleteVolume => 'Elimina anche il volume';

  @override
  String get virtHwDetach => 'Scollega';

  @override
  String get virtHwDiskHotplug =>
      'Hot-plug: si può aggiungere anche in esecuzione';

  @override
  String get virtHwDisksLxc => 'Disco root e punti di montaggio';

  @override
  String get virtHwEject => 'Espelli';

  @override
  String get virtHwEmpty => 'Nessun supporto';

  @override
  String get virtHwFirewall => 'Firewall';

  @override
  String virtHwFree(String size) {
    return '$size liberi';
  }

  @override
  String get virtHwGrow => 'Espandi';

  @override
  String get virtHwGrowNote => 'I dischi possono solo crescere.';

  @override
  String get virtHwGrowNoteRunning =>
      'I dischi possono solo crescere. Se espanso in esecuzione, la partizione va estesa nel guest.';

  @override
  String get virtHwGuestUsed => 'Usata dal guest';

  @override
  String virtHwHostCpus(int threads, int allocated) {
    return 'Host $threads thread · $allocated assegnati';
  }

  @override
  String virtHwHostMem(String total, String allocated) {
    return 'Host $total · $allocated assegnati';
  }

  @override
  String get virtHwHotplugNow => 'Hot-plug: effettivo subito.';

  @override
  String get virtHwIssueBootEmpty => 'Seleziona almeno un dispositivo';

  @override
  String virtHwIssueCpuCount(int max) {
    return 'Da 1 a $max vCPU in totale';
  }

  @override
  String get virtHwIssueCpuOnline => 'vCPU attive: da 1 al totale';

  @override
  String get virtHwIssueDiskShrink =>
      'Più grande di ora: i dischi possono solo crescere';

  @override
  String get virtHwIssueDiskSize => 'Da 1 a 65536 GiB';

  @override
  String virtHwIssueMemory(int min, int max) {
    return 'Da $min a $max MiB';
  }

  @override
  String get virtHwIssueMemoryMin => 'Non più della memoria';

  @override
  String get virtHwIssueMountPoint => 'Un percorso assoluto, come /data';

  @override
  String get virtHwIssueStorageSpace => 'Più dello spazio libero dello storage';

  @override
  String get virtHwLater => 'Effettivo al riavvio';

  @override
  String get virtHwLess => 'Meno';

  @override
  String get virtHwLinkDown => 'Disconnessa';

  @override
  String get virtHwLinkNote =>
      'Spento, il guest vede il cavo scollegato; nessun riavvio';

  @override
  String get virtHwLinkUp => 'Connessa';

  @override
  String get virtHwMac => 'Indirizzo MAC';

  @override
  String get virtHwModel => 'Modello';

  @override
  String get virtHwMore => 'Più';

  @override
  String get virtHwMountFromPool =>
      'I punti di montaggio sono allocati direttamente da uno storage';

  @override
  String get virtHwMountPoint => 'Punto di montaggio';

  @override
  String get virtHwMoveDown => 'Sposta giù';

  @override
  String get virtHwMoveUp => 'Sposta su';

  @override
  String get virtHwNewDisk => 'Nuovo disco';

  @override
  String get virtHwNewMount => 'Nuovo punto di montaggio';

  @override
  String get virtHwNewNic => 'Nuova interfaccia di rete';

  @override
  String get virtHwNicHotplug => 'Le interfacce virtio supportano l\'hot-plug';

  @override
  String get virtHwNics => 'Interfacce di rete';

  @override
  String get virtHwNoMedia => 'Nessun supporto';

  @override
  String get virtHwNoNetworks => 'Nessuna rete o bridge qui';

  @override
  String get virtHwNoStorage => 'Nessuno storage qui accetta dischi';

  @override
  String get virtHwOnline => 'vCPU attive';

  @override
  String get virtHwPendingBanner =>
      'Alcune modifiche hardware hanno effetto al riavvio';

  @override
  String get virtHwPickNet => 'Scegli una rete';

  @override
  String get virtHwPickPool => 'Scegli uno storage e una dimensione';

  @override
  String get virtHwProcessor => 'Processore';

  @override
  String get virtHwRemove => 'Rimuovi';

  @override
  String get virtHwRemoveCdrom => 'Rimuovi CD-ROM';

  @override
  String virtHwRemoveDiskAsk(String disk, String guest) {
    return 'Rimuovere $disk da $guest?';
  }

  @override
  String virtHwRemoveNicAsk(String nic, String guest) {
    return 'Rimuovere $nic da $guest?';
  }

  @override
  String get virtHwResources => 'Risorse';

  @override
  String get virtHwRestartNow => 'Riavvia ora';

  @override
  String get virtHwRevert => 'Annulla';

  @override
  String get virtHwRevertAll => 'Annulla tutto';

  @override
  String get virtSetRenameStopped =>
      'Spegni il guest per rinominarlo: libvirt rinomina solo un guest non in esecuzione.';

  @override
  String virtSetIssueDescription(int max) {
    return 'Al massimo $max byte (UTF-8), senza caratteri di controllo.';
  }

  @override
  String get virtSetManualStart => 'Avvio manuale';

  @override
  String get virtSetProtection => 'Protezione';

  @override
  String get virtSetProtectionNote =>
      'Impedisce di eliminare il guest e di modificarne i dischi';

  @override
  String get virtSetIrreversible => 'Non si può annullare';

  @override
  String get virtSetDeleteStopFirst => 'Spegnilo prima di eliminarlo.';

  @override
  String get virtSetDeleteProtected =>
      'La protezione è attiva: disattivala prima in Generale.';

  @override
  String get virtSetDeleteAgain => 'Premi di nuovo per confermare';

  @override
  String virtSetDeleteConfirm(String name) {
    return 'Elimina $name';
  }

  @override
  String get virtSetDeleteVm => 'Elimina macchina virtuale';

  @override
  String get virtSetDeleteLxc => 'Elimina container';

  @override
  String get virtHwSockets => 'Socket';

  @override
  String get virtHwSource => 'Origine';

  @override
  String get virtHwSwap => 'Swap';

  @override
  String get virtHwTopology => 'Socket × core';

  @override
  String virtHwTopologyValue(int sockets, int cores, int threads) {
    return '$sockets socket × $cores core × $threads thread';
  }

  @override
  String virtHwTotal(String size) {
    return '$size in totale';
  }

  @override
  String get virtHwVolumeKept =>
      'Rimosso, ma il guest in esecuzione usa ancora il disco, quindi il volume è stato mantenuto. Verrà scollegato al prossimo avvio.';

  @override
  String get virtHwBus => 'Bus';

  @override
  String get virtHwCache => 'Cache';

  @override
  String get virtHwBusStopped => 'Il bus cambia solo a guest fermo.';

  @override
  String get virtHwMacGenerate => 'Genera';

  @override
  String get virtHwIssueMac =>
      'Deve essere un indirizzo MAC unicast, ad es. 52:54:00:12:34:56';

  @override
  String get virtHwIssueStopFirst => 'Ferma prima il guest';

  @override
  String get virtHwIssueStorageMissing => 'Scegli prima uno storage';

  @override
  String get virtHwIssueDevice => 'Scegli prima un dispositivo';

  @override
  String get virtHwDevices => 'CD-ROM e passthrough';

  @override
  String get virtHwDevicesEmpty => 'Passthrough USB e PCI, CD-ROM, TPM';

  @override
  String get virtHwAddDevice => 'Aggiungi dispositivo';

  @override
  String get virtHwNewDevice => 'Nuovo dispositivo';

  @override
  String get virtHwUsbHotplug => 'Il passthrough USB supporta l\'hot plug.';

  @override
  String get virtHwPci => 'Passthrough PCI';

  @override
  String get virtHwIommuOffTitle => 'L\'host non ha IOMMU';

  @override
  String get virtHwIommuOffBody =>
      'Attiva prima VT-d o AMD-Vi nel BIOS dell\'host e l\'IOMMU nel suo kernel. Fino ad allora un guest con un dispositivo PCI non si avvia.';

  @override
  String get virtHwPciTitle => 'Richiede IOMMU sull\'host';

  @override
  String get virtHwPciBody =>
      'Una volta passato, l\'host non può più usare il dispositivo e il guest non può migrare a caldo.';

  @override
  String virtHwIommuGroup(int group) {
    return 'Gruppo IOMMU $group';
  }

  @override
  String virtHwIommuShared(int count) {
    return '$count dispositivi condividono il suo gruppo IOMMU e passano insieme';
  }

  @override
  String get virtHwNoHostDevices =>
      'Nessun dispositivo da passare su questo host';

  @override
  String get virtHwMappingsOnly =>
      'Qui si possono usare solo mappature di risorse: PVE consente solo a root@pam, con la sua password, di passare un dispositivo grezzo. Crea le mappature in Datacenter → Mappature risorse.';

  @override
  String get virtHwTpmNote => 'Windows 11 richiede TPM 2.0.';

  @override
  String get virtHwDisplay => 'Display';

  @override
  String get virtHwProtocol => 'Protocollo';

  @override
  String get virtHwListen => 'Ascolto';

  @override
  String get virtHwGpu => 'Scheda video';

  @override
  String get virtHwListenAllTitle => 'La console è esposta alla rete';

  @override
  String get virtHwListenAllBody =>
      'In ascolto su tutti gli indirizzi, chiunque raggiunga l\'host può aprire la console. Tieni 127.0.0.1 e collegati tramite un tunnel SSH.';

  @override
  String get virtHwFirmware => 'Firmware';

  @override
  String get virtHwUefiSub =>
      'OVMF · supporta Secure Boot, richiesto da Windows 11';

  @override
  String get virtHwBiosSub => 'SeaBIOS · sistemi datati e dischi MBR';

  @override
  String get virtHwSecureBootNote => 'Avvia solo kernel e boot loader firmati';

  @override
  String get virtHwFirmwareWarnTitle =>
      'Non cambiare il firmware di un sistema installato';

  @override
  String get virtHwFirmwareWarnBody =>
      'Passare tra UEFI e BIOS rende un sistema installato non avviabile.';

  @override
  String get virtHwFirmwareStopped => 'Il firmware cambia solo a guest fermo.';

  @override
  String get virtHwSecureBootVars =>
      'Attivare o disattivare Secure Boot ricrea le variabili EFI; le voci di avvio salvate al loro interno vanno perse.';

  @override
  String get virtHwEfiStorage => 'Dove vanno le variabili EFI';

  @override
  String virtHwSwitchFirmwareAsk(String guest, String firmware) {
    return 'Passare $guest a $firmware?';
  }

  @override
  String get virtCloneName => 'Nuovo nome';

  @override
  String get virtCloneFull => 'Clone completo';

  @override
  String get virtCloneCopyDisks => 'Copia il contenuto dei dischi';

  @override
  String get virtCloneLinkedNote =>
      'Disattivato: un clone collegato, che dipende dai dischi del modello';

  @override
  String get virtCloneFullOnly =>
      'Solo un modello può essere clonato come clone collegato';

  @override
  String get virtCloneEmptyNote =>
      'Disattivato: nuovi dischi vuoti della stessa dimensione';

  @override
  String get virtCloneStopFirst => 'Spegnila prima di clonarla.';

  @override
  String get virtCloneFullShort => 'Completo';

  @override
  String get virtCloneLinkedShort => 'Collegato';

  @override
  String get virtCloneEmptyShort => 'Dischi vuoti';

  @override
  String get virtCloning => 'Clonazione…';

  @override
  String virtCloned(String name) {
    return 'Clonato come $name';
  }

  @override
  String get virtBackupPlan => 'Pianificazione';

  @override
  String get virtBackupPlanWhere => 'Datacenter → Backup';

  @override
  String get virtBackupNoPlanShort => 'Nessuna pianificazione';

  @override
  String get virtBackupNoPlan =>
      'Nessun job di backup pianificato include questo guest.';

  @override
  String get virtBackupKeep => 'Conserva';

  @override
  String get virtBackupJobDisabled => 'Questo job è disattivato.';

  @override
  String virtBackupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count backup',
      one: '1 backup',
    );
    return '$_temp0';
  }

  @override
  String virtSnapshotCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count snapshot',
      one: '1 snapshot',
    );
    return '$_temp0';
  }

  @override
  String get virtBackupNoStorage =>
      'Nessuno storage di questo nodo contiene backup.';

  @override
  String get virtBackupLiveTip =>
      'In esecuzione: modalità snapshot, senza fermo';

  @override
  String get virtBackupStoppedTip => 'Spento: salvato così com\'è';

  @override
  String get virtBackupNow => 'Esegui backup ora';

  @override
  String get virtBackupNotes => 'Note';

  @override
  String get virtBackupProtected =>
      'Protetto: non può essere eliminato finché la protezione non viene rimossa in PVE.';

  @override
  String virtBackupVerified(String state) {
    return 'Verifica: $state';
  }

  @override
  String get virtBackupRestoreOverwrites =>
      'Il ripristino sovrascrive i dischi attuali';

  @override
  String get virtBackupStopFirst => 'Spegnila prima di ripristinare.';

  @override
  String get virtBackupRestoreAgain =>
      'Dischi e configurazione del guest vengono sostituiti da quelli del backup.';

  @override
  String get virtBackupDeleteConfirm => 'Elimina backup';

  @override
  String get virtBackupRestoreNew => 'Ripristina come nuovo';

  @override
  String get virtBackupRestoreConfirm => 'Ripristina sopra';

  @override
  String get virtBackupDone => 'Backup completato';

  @override
  String get virtBackupDeleted => 'Backup eliminato';

  @override
  String virtBackupRestored(String time) {
    return 'Ripristinato da $time';
  }

  @override
  String pveNeedsPrivilege(
    String account,
    String privilege,
    String path,
    String command,
  ) {
    return 'A $account manca $privilege su $path. Concedilo sull\'host PVE:\n$command';
  }

  @override
  String get virtCanDelete => 'Può essere eliminato';

  @override
  String get virtInUse => 'In uso';

  @override
  String get virtOps => 'Operazioni';

  @override
  String get virtPool => 'Pool di archiviazione';

  @override
  String get virtPoolNew => 'Nuovo pool di archiviazione';

  @override
  String get virtStorageAdd => 'Aggiungi archiviazione';

  @override
  String virtPoolUsedPct(String pct) {
    return '$pct% usato';
  }

  @override
  String get virtPoolInUse =>
      'Una VM usa un volume qui, quindi il pool non può essere fermato né rimosso.';

  @override
  String get virtPoolDelete => 'Elimina pool';

  @override
  String get virtStorageRemove => 'Rimuovi archiviazione';

  @override
  String virtPoolDeleteAsk(String name) {
    return 'Rimuovere il pool $name? La definizione viene eliminata; i volumi restano dove sono.';
  }

  @override
  String virtStorageRemoveAsk(String name) {
    return 'Rimuovere l\'archiviazione $name dalla configurazione di PVE? Il contenuto resta.';
  }

  @override
  String virtPoolDeleteKeepsVolumes(int count) {
    return 'I suoi $count volumi restano sul disco.';
  }

  @override
  String get virtPoolDeleteStorage =>
      'Elimina anche la directory (solo se vuota)';

  @override
  String virtPoolStopAsk(String name) {
    return 'Fermare il pool $name? Non si potranno elencare né creare volumi finché non riparte.';
  }

  @override
  String get virtStorageClusterWide =>
      'Si applica a ogni nodo del cluster che ha questo storage.';

  @override
  String get virtStorageDisable => 'Disattiva';

  @override
  String get virtStorageEnable => 'Attiva';

  @override
  String virtStorageDisableAsk(String name) {
    return 'Disattivare l\'archiviazione $name? Le VM con dischi su di essa non partiranno finché non verrà riattivata.';
  }

  @override
  String get virtPoolLogicalNote =>
      'Si usa un gruppo di volumi esistente così com\'è; non viene formattato nulla.';

  @override
  String get virtPoolMountPoint => 'Punto di montaggio';

  @override
  String get virtPoolSourceNfs => 'Origine (host:/percorso)';

  @override
  String get virtPoolSourceVg => 'Gruppo di volumi';

  @override
  String get virtPoolSourceThin => 'Gruppo di volumi / thin pool';

  @override
  String get virtPoolSourceZfs => 'Pool ZFS';

  @override
  String get virtPoolTypeVg => 'Gruppo di volumi LVM';

  @override
  String get virtResNameEmpty => 'Inserisci un nome';

  @override
  String get virtResNotFound => 'Non è più su questo host';

  @override
  String get virtResUnsupported => 'Questo host non lo supporta';

  @override
  String get virtResNameInvalid =>
      'Nome non accettato da questo host (lettere, cifre, . _ -)';

  @override
  String get virtResSourceInvalid => 'Percorso o origine non valida';

  @override
  String get virtResTargetInvalid => 'Un percorso assoluto';

  @override
  String get virtResCidrInvalid =>
      'Un indirizzo con prefisso, es. 192.168.150.1/24';

  @override
  String get virtResDhcpInvalid =>
      'Due indirizzi della rete, in ordine, senza quello dell\'host';

  @override
  String get virtResSubnetTaken => 'Un\'altra rete qui è su questa sottorete';

  @override
  String get virtResBridgeInvalid => 'Non è un nome di interfaccia';

  @override
  String get virtResFormat => 'Questo pool non supporta quel formato';

  @override
  String get virtVolNew => 'Nuovo volume';

  @override
  String virtVolCount(int count) {
    return '$count volumi';
  }

  @override
  String get virtVolNone => 'Questo pool non ha ancora volumi.';

  @override
  String get virtVolEmptyAttach =>
      'Un nuovo volume può essere collegato in seguito a qualsiasi VM';

  @override
  String get virtVolEmptyUpload => 'Si può anche caricare direttamente un ISO';

  @override
  String get virtVolPveName =>
      'PVE nomina un volume in base alla sua VM: vm-<VMID>-disk-<N>';

  @override
  String get virtVolUsers => 'Usato da';

  @override
  String get virtVolAllocated => 'Allocato';

  @override
  String get virtVolGrowFromGuest =>
      'Lo usa una VM: ingrandiscilo dalla vista Hardware di quella VM';

  @override
  String get virtVolInUse => 'Una VM usa questo volume';

  @override
  String virtVolBackingOf(String names) {
    return 'File di base di $names';
  }

  @override
  String get virtVolIsBase =>
      'Altri volumi si basano su questo; eliminarlo li danneggerebbe';

  @override
  String get virtVolAttach => 'Collega alla VM';

  @override
  String get virtVolAttachNote =>
      'Collegato come nuovo disco, sul bus del suo primo disco';

  @override
  String virtVolAttached(String name) {
    return 'Collegato a $name';
  }

  @override
  String get virtVolInsert => 'Inserisci nel CD-ROM';

  @override
  String virtVolInserted(String name) {
    return 'Inserito nel CD-ROM di $name';
  }

  @override
  String virtVolNoCdrom(String name) {
    return '$name non ha un\'unità CD-ROM';
  }

  @override
  String virtVolDeleteAsk(String name, String pool) {
    return 'Eliminare il volume $name da $pool? Il contenuto andrà perso per sempre.';
  }

  @override
  String get virtUploadIso => 'Carica ISO';

  @override
  String virtUploadTo(String pool) {
    return 'Carica su $pool';
  }

  @override
  String virtUploadDone(String name) {
    return '$name caricato';
  }

  @override
  String get virtNetConfig => 'Configurazione';

  @override
  String get virtNetConfigFile => 'File di configurazione';

  @override
  String get virtNetInternal => 'Interna';

  @override
  String get virtNetBridgePorts => 'Porte del bridge';

  @override
  String get virtNetHostBridge => 'Bridge dell\'host';

  @override
  String get virtNetPortsHint => 'eno2; vuoto per un bridge interno';

  @override
  String get virtNetDhcpRange => 'Intervallo DHCP';

  @override
  String get virtNetDhcpTip => 'dnsmasq assegna gli indirizzi alle VM';

  @override
  String get virtNetVlanTip =>
      'Le schede di rete delle VM possono avere un tag VLAN';

  @override
  String get virtNetNatTip =>
      'Tramite l\'host: le VM escono, dall\'esterno non si entra';

  @override
  String get virtNetRoutedTip =>
      'Instradato dall\'host senza NAT: la LAN ha bisogno di una rotta di ritorno';

  @override
  String get virtNetIsolatedTip => 'Solo le VM e l\'host comunicano tra loro';

  @override
  String get virtNetBridgedTip =>
      'Le VM si uniscono a un bridge dell\'host, sulla sua rete fisica';

  @override
  String get virtNetNew => 'Nuova rete';

  @override
  String get virtNetNewBridge => 'Nuovo Linux bridge';

  @override
  String get virtNetVirtual => 'Rete virtuale';

  @override
  String get virtNetDelete => 'Elimina rete';

  @override
  String virtNetDeleteAsk(String name) {
    return 'Eliminare la rete $name? Viene fermata e la definizione rimossa.';
  }

  @override
  String virtNetDeleteAskPve(String name, String node) {
    return 'Rimuovere il bridge $name da $node? Esce ora dalla configurazione in sospeso, e dall\'host quando questa viene applicata.';
  }

  @override
  String virtNetInUse(int count) {
    return 'VM collegate: $count. Non può essere eliminata.';
  }

  @override
  String virtNetStopAsk(String name, int count) {
    return 'Fermare $name? Le $count VM collegate perdono la rete finché non riparte.';
  }

  @override
  String get virtNetInactivePve =>
      'Non attivo: un nuovo bridge attende nella configurazione in sospeso finché non viene applicata.';

  @override
  String get virtNetPveApplyNote =>
      'Salvato come modifica in sospeso: ha effetto quando la configurazione viene applicata (ifreload -a).';

  @override
  String get virtNetPendingSaved =>
      'Salvato in sospeso: applica la configurazione perché abbia effetto';

  @override
  String virtNetPendingTitle(String node) {
    return 'Modifiche di rete in sospeso su $node';
  }

  @override
  String get virtNetPendingTip =>
      'PVE tiene le modifiche di rete in interfaces.new finché non vengono applicate.';

  @override
  String get virtNetPendingShow => 'Mostra modifiche';

  @override
  String get virtNetApply => 'Applica configurazione';

  @override
  String virtNetApplyAsk(String node) {
    return 'Applicare la configurazione di rete in sospeso su $node? PVE ricarica la rete dell\'host (ifreload -a): un errore può isolare l\'host.';
  }

  @override
  String virtNetRevertAsk(String node) {
    return 'Scartare la configurazione di rete in sospeso su $node?';
  }

  @override
  String get pveTokenTipStorage =>
      'Gestire l\'archiviazione richiede Datastore.Allocate su /storage (aggiunta, disattivazione, rimozione), Datastore.AllocateSpace (volumi) e Datastore.AllocateTemplate (caricamenti); i Linux bridge e l\'applicazione della configurazione di rete richiedono Sys.Modify sul nodo.';

  @override
  String get virtCreateUnnamed => 'Senza nome';

  @override
  String get virtCreateNotChosen => 'Non scelto';

  @override
  String get virtCreateKindVmSub => 'qm · una macchina virtuale KVM completa';

  @override
  String get virtCreateKindLxcSub =>
      'pct · condivide il kernel dell\'host, più leggero';

  @override
  String get virtCloudImage => 'Immagine cloud';

  @override
  String get virtCloudImageTip =>
      'Un disco con un sistema già installato: copiato, ingrandito alla dimensione indicata in Archiviazione e configurato da cloud-init al primo avvio. L\'immagine resta com\'è.';

  @override
  String get virtNoCloudImagesLibvirt =>
      'Nessuna immagine cloud qui: metti un\'immagine qcow2 o raw in un pool (caricala in Archiviazione) che nessuna VM usi.';

  @override
  String get virtNoCloudImagesPve =>
      'Nessuna immagine cloud qui: carica un\'immagine qcow2, raw o vmdk in uno storage con il tipo di contenuto Import (PVE 8.2+).';

  @override
  String get virtCreateWindowsTitle => 'Windows 11 richiede UEFI e TPM 2.0';

  @override
  String get virtCreateWindowsBody => 'Scegli UEFI e attiva il TPM qui sopra.';

  @override
  String get virtCreateWindowsNoTpm =>
      'Questo host non ha un TPM software (swtpm): installalo per darne uno alla VM.';

  @override
  String virtCreateImageSize(String size) {
    return 'L\'immagine è di $size: il disco deve essere almeno così grande.';
  }

  @override
  String get virtCreateImageMissing => 'Scegli un\'immagine cloud.';

  @override
  String get virtCreateIncomplete =>
      'Completa prima le parti segnate in arancione.';

  @override
  String virtCreateOn(String host) {
    return 'Creato su $host';
  }

  @override
  String get virtCiTip =>
      'Un account con sudo, a cui si accede con la password, una chiave SSH o entrambe.';

  @override
  String get virtCiUserInvalid =>
      'Minuscole, cifre, _ e -, iniziando con una lettera o _';

  @override
  String get virtCiCredentialsMissing =>
      'Imposta una password o una chiave SSH.';

  @override
  String get virtCiHostnamePve => 'Il nome host è il nome della VM.';

  @override
  String get virtCiStatic => 'Statico';

  @override
  String get virtCiAddressInvalid =>
      'Un indirizzo IPv4 con il prefisso, come 10.0.0.5/24';

  @override
  String get virtCiGatewayInvalid => 'Un indirizzo IPv4, come 10.0.0.1';

  @override
  String get virtCiDnsFromDhcp => 'Vuoto: da DHCP';

  @override
  String get virtCiDnsInvalid => 'Indirizzi IP, separati da spazi o virgole';

  @override
  String get virtCiSearch => 'Dominio di ricerca';

  @override
  String get virtCiSeedNote =>
      'Scritto in una piccola ISO accanto al disco, collegata come CD-ROM ed eliminata con la VM. Si conserva solo l\'hash della password.';

  @override
  String get virtCiNoToolTitle =>
      'Nessuno strumento sull\'host per creare i dati cloud-init';

  @override
  String virtCiNoToolBody(String tools) {
    return 'Installa uno tra $tools sull\'host. Senza cloud-init l\'immagine si avvia senza un account per accedere.';
  }

  @override
  String get virtHwCloudInitNote =>
      'Ciò che cloud-init legge al primo avvio. Non è un supporto di installazione: qui non si inserisce nulla.';

  @override
  String get virtHwCdromLater =>
      'Mentre è in esecuzione, l\'unità viene aggiunta al prossimo avvio (SATA e IDE non ne accettano a caldo).';

  @override
  String virtCreateDiskKept(String size) {
    return 'Il disco è rimasto a $size, la dimensione dell\'immagine stessa, più di quanto richiesto: un disco non viene mai ridotto sotto il sistema che contiene.';
  }

  @override
  String get virtCiEditTip =>
      'Ciò che cloud-init configura in questa VM: un account con sudo, come accedervi, il nome host e l\'indirizzo.';

  @override
  String get virtCiForeignTitle =>
      'Questo seed contiene più di quanto scrive questa app';

  @override
  String get virtCiForeignBody =>
      'Le impostazioni fatte altrove (pacchetti, comandi, altri account) non sono mostrate qui. Salvare sostituisce il seed con ciò che è mostrato.';

  @override
  String get virtCiPasswordKept => 'Impostata. Lasciare vuoto per mantenerla';

  @override
  String get virtCiRemovePassword => 'Rimuovi la password';

  @override
  String get virtCiRemovePasswordNote => 'Accesso solo con chiave SSH';

  @override
  String get virtCiKeysAdded =>
      'Le chiavi vengono aggiunte all\'account. Una chiave tolta qui resta nel sistema finché non la si toglie lì, e un nuovo nome utente crea un nuovo account accanto al vecchio.';

  @override
  String get virtCiEffectTitle => 'Ha effetto al prossimo avvio';

  @override
  String get virtCiEffectLibvirt =>
      'Salvare scrive un nuovo seed con un nuovo ID d\'istanza.';

  @override
  String get virtCiEffectPve =>
      'PVE riscrive subito la sua unità cloud-init, con un ID d\'istanza ricavato da queste impostazioni: ogni modifica qui ne crea uno nuovo.';

  @override
  String get virtCiNewInstance =>
      'Al prossimo avvio cloud-init tratta il sistema come una nuova istanza: reimposta il nome host, crea l\'account se manca, ne imposta la password, aggiunge le chiavi e riscrive la configurazione di rete. Crea anche nuove chiavi host SSH, quindi i client SSH avviseranno che la chiave host è cambiata. Nulla cambia prima di quell\'avvio.';

  @override
  String get virtCiSaved => 'Salvato. Ha effetto al prossimo avvio.';

  @override
  String get virtSnapshotExternal => 'Solo dischi a caldo';

  @override
  String get virtSnapshotExternalTip =>
      'Il guest continua a funzionare. Ogni disco riceve un overlay qcow2 nel pool scelto; il guest resta su una catena.';

  @override
  String get virtSnapshotFormInternal => 'Interna (nell\'immagine)';

  @override
  String get virtSnapshotOverlayPool => 'Pool overlay';

  @override
  String get virtSnapshotOverlayBeside => 'Accanto a ogni disco';

  @override
  String get virtSnapshotExternalNoMemory =>
      'Uno snapshot esterno non contiene mai la memoria: il guest non viene fermato.';

  @override
  String get virtSnapshotChain => 'Catena dei dischi';

  @override
  String virtSnapshotChainDepth(String count) {
    return '$count livelli';
  }

  @override
  String get virtSnapshotChainFile => 'File';

  @override
  String get virtSnapshotChainActive => 'In uso ora';

  @override
  String get virtSnapshotChainBase => 'Immagine di base';

  @override
  String get virtSnapshotNoSupport =>
      'Lo storage del guest non supporta gli snapshot, quindi non se ne può creare nessuno.';

  @override
  String get virtSnapshotRevertChain =>
      'Un ripristino su una catena unisce l\'overlay in esecuzione nell\'immagine e rende inutilizzabile ogni snapshot successivo. Solo il più recente può essere ripristinato.';

  @override
  String get virtSnapshotRevertHasChildren =>
      'Rifiutato finché uno snapshot successivo poggia su questo.';

  @override
  String get virtSnapshotDiff => 'Differenze da ora';

  @override
  String get virtSnapshotDiffNone =>
      'La configurazione non è cambiata da questo snapshot.';

  @override
  String get virtSnapshotDiffShow => 'Confronta con ora';

  @override
  String get virtSnapshotDiffGroupCpu => 'Processore';

  @override
  String get virtSnapshotDiffGroupMemory => 'Memoria';

  @override
  String get virtSnapshotDiffGroupDisks => 'Dischi';

  @override
  String get virtSnapshotDiffGroupNic => 'Interfacce';

  @override
  String get virtSnapshotDiffGroupFirmware => 'Firmware';

  @override
  String get virtSnapshotDiffGroupBoot => 'Avvio';

  @override
  String get virtSnapshotDiffGroupOther => 'Altro';

  @override
  String virtSnapshotDiffValue(String after, String before) {
    return '$before → $after';
  }

  @override
  String get virtSnapshotDiffRemoved => 'rimosso';

  @override
  String get virtSnapshotDiffAdded => 'aggiunto';

  @override
  String virtSnapshotDiffAsk(String snapshot) {
    return 'Cosa cambia ripristinando $snapshot:';
  }

  @override
  String virtSnapshotDiffHost(String error) {
    return 'L\'host non ha potuto dire cosa differisce: $error';
  }

  @override
  String virtSnapshotExternalExists(String count) {
    return 'Il guest è già su $count livelli; questo snapshot ne aggiunge uno.';
  }

  @override
  String get virtToTemplate => 'Converti in modello';

  @override
  String get virtToTemplateNote =>
      'Un modello non può essere avviato né riconvertito in guest. I suoi dischi diventano immagini di base, che un clone collegato condivide.';

  @override
  String virtToTemplateConfirm(String name) {
    return 'Convertire $name in modello?';
  }

  @override
  String get virtToTemplateIrreversible =>
      'Non è annullabile: un modello non può tornare a essere un guest.';

  @override
  String get virtToTemplateStopped => 'Spegnilo prima.';

  @override
  String get virtToTemplateSnapshots =>
      'Un guest con snapshot non può diventare un modello.';

  @override
  String virtTemplateCreated(String name) {
    return '$name è ora un modello';
  }

  @override
  String get virtTemplateTip =>
      'Un modello viene eseguito solo dopo essere stato clonato.';

  @override
  String get virtCloneStorageSame => 'Come l\'origine';

  @override
  String get virtCloneNodeSame => 'Come l\'origine';

  @override
  String get virtCloneStorageContent =>
      'Questo storage non contiene dischi di VM.';

  @override
  String get virtCloneStorageShared =>
      'Copiare su un altro nodo richiede uno storage condiviso.';

  @override
  String get virtCloneNodeUnknown => 'Questo host non ha quel nodo.';

  @override
  String get virtCloneLinkedTarget =>
      'Un clone collegato condivide i dischi del modello, quindi non può indicare storage o nodo.';

  @override
  String get virtBackupJobs => 'Attività di backup';

  @override
  String get virtBackupJobsNone =>
      'Nessuna attività di backup pianificata. Aggiungine una per il backup periodico dei guest.';

  @override
  String get virtBackupJobNew => 'Nuova attività';

  @override
  String get virtBackupJobRun => 'Esegui ora';

  @override
  String get virtBackupJobRunAsk => 'Avviare ora questa attività di backup?';

  @override
  String virtBackupJobDeleteAsk(String id) {
    return 'Eliminare l\'attività di backup $id? I backup restano.';
  }

  @override
  String get virtBackupJobSaved => 'Attività salvata';

  @override
  String get virtBackupJobDeleted => 'Attività eliminata';

  @override
  String get virtBackupJobStarted => 'Attività di backup avviata';

  @override
  String get virtBackupSchedule => 'Pianificazione';

  @override
  String get virtBackupScheduleHelp =>
      'Un sottoinsieme degli eventi di calendario di systemd: 02:30, mon..fri 02:30, sat 03:00, daily, hourly, */15.';

  @override
  String get virtBackupScheduleInvalid =>
      'L\'host non accetta questa pianificazione.';

  @override
  String virtBackupScheduleNext(String times) {
    return 'Prossime esecuzioni: $times';
  }

  @override
  String get virtBackupSelection => 'Guest';

  @override
  String get virtBackupSelectionAll => 'Tutti i guest';

  @override
  String get virtBackupSelectionList => 'Guest selezionati';

  @override
  String get virtBackupSelectionNone => 'Scegli almeno un guest.';

  @override
  String get virtBackupMail => 'Notifica';

  @override
  String get virtBackupNotesTemplate => 'Note del backup';

  @override
  String virtBackupNotesTemplateTip(String vars) {
    return 'Le note vengono aggiunte a ogni backup dell\'attività. Vengono sostituiti: $vars.';
  }

  @override
  String get virtBackupPrune => 'Conservazione';

  @override
  String get virtBackupPruneTip =>
      'Le opzioni di conservazione di PVE, es. keep-last=7,keep-daily=4. Vuoto: quelle dello storage o del nodo.';

  @override
  String get virtBackupJobNode => 'Nodo';

  @override
  String get virtBackupJobNodeAny => 'Tutti i nodi';

  @override
  String get virtBackupEnabled => 'Attiva';

  @override
  String get virtBackupOptions => 'Opzioni';

  @override
  String get virtBackupProtect => 'Proteggi';

  @override
  String get virtBackupProtectTip =>
      'Un backup protetto non viene eliminato dalla conservazione e non può essere cancellato finché resta protetto.';

  @override
  String get virtBackupEditNotes => 'Note';

  @override
  String get virtBackupSaveNotes => 'Salva';

  @override
  String get virtBackupEdited => 'Backup aggiornato';

  @override
  String get virtBackupRestoreStorage => 'Ripristina su storage';

  @override
  String get virtBackupRestoreStorageSame => 'Come nel backup';

  @override
  String get virtCloneStorageMissing =>
      'Nessuno storage di questo nodo contiene dischi di VM.';

  @override
  String get virtBackupCompress => 'Compressione';

  @override
  String get virtBackupUnprotect => 'Rimuovi protezione';

  @override
  String get virtBackupModeStops =>
      'suspend e stop interrompono un guest in esecuzione durante la copia.';

  @override
  String get virtBackupScheduleValidate => 'Verifica con l\'host';

  @override
  String virtBackupSelected(int count) {
    return '$count selezionati';
  }

  @override
  String get virtBackupExcludeTip =>
      'Tutti i guest del nodo vengono inclusi. Disattivane uno per escluderlo.';

  @override
  String virtNetEditAsk(int count) {
    return 'La rete in esecuzione mantiene ciò che ha finché non viene riavviata. Il riavvio scollega le VM collegate ($count).';
  }

  @override
  String get virtNetEditAskNoGuest =>
      'La rete in esecuzione mantiene ciò che ha finché non viene riavviata.';

  @override
  String get virtNetEditRestart => 'Riavviala per applicare ora';

  @override
  String get virtNetEditRestartNote =>
      'Le VM collegate perdono la rete durante il riavvio.';

  @override
  String get virtNetEditPending =>
      'La definizione contiene una modifica che la rete in esecuzione non ha ancora recepito.';

  @override
  String get virtNetRestart => 'Riavvia';

  @override
  String virtNetRestartAsk(String name, int count) {
    return 'Riavviare $name? Le VM collegate ($count) perdono la rete finché non torna attiva.';
  }

  @override
  String virtNetRestartAskNone(String name) {
    return 'Riavviare $name? Non c\'è nulla collegato.';
  }

  @override
  String get virtNetHosts => 'Indirizzi statici';

  @override
  String get virtNetHostAdd => 'Aggiungi un indirizzo';

  @override
  String get virtNetHostMac => 'MAC';

  @override
  String get virtNetHostIp => 'Indirizzo';

  @override
  String get virtNetHostName => 'Nome (facoltativo)';

  @override
  String get virtNetHostEmpty =>
      'Nessun MAC ha un indirizzo proprio: ogni VM ne riceve uno dall\'intervallo DHCP.';

  @override
  String get virtNetHostOthers =>
      'Ogni altra VM ne riceve uno dall\'intervallo DHCP.';

  @override
  String get virtNetHostInvalid =>
      'Un MAC, un indirizzo o un nome che l\'host rifiuterebbe, oppure lo stesso MAC due volte.';

  @override
  String get virtNetManagementIface =>
      'Questa interfaccia porta l\'indirizzo dell\'host stesso. Modificarla o applicarla isolerebbe l\'host.';

  @override
  String get virtNetManagementTip =>
      'Porta il traffico di gestione dell\'host, o si trova sotto un\'interfaccia che lo porta: l\'app non la modifica.';

  @override
  String get virtNetPhysicalTip =>
      'Un\'interfaccia fisica appartiene all\'host: l\'app modifica solo i bridge.';

  @override
  String get virtNetVlanAware => 'VLAN aware';

  @override
  String get virtCiExpire => 'La password scade';

  @override
  String get virtCiExpireNote =>
      'Il primo accesso con essa deve impostarne una nuova. Solo libvirt: PVE scrive \"expire: false\" e non ha un\'opzione per questo.';

  @override
  String get virtCiSearchHint => 'lab.example dev.lab.example';

  @override
  String get virtCiSearchTip =>
      'Più domini, separati da uno spazio; resolv.conf conserva i primi.';

  @override
  String virtCiNicsTip(int count) {
    return '$count NIC nella configurazione di rete del seed; il modulo modifica la prima.';
  }

  @override
  String get virtUsbByVendor => 'Per produttore e prodotto';

  @override
  String get virtUsbByAddress => 'Per indirizzo';

  @override
  String get virtUsbAddressTip =>
      'Il dispositivo segue questo indirizzo: qualunque cosa sia collegata lì viene data alla VM. libvirt identifica un hostdev USB per numero di bus e di dispositivo.';

  @override
  String virtUsbPortNote(int bus, String port) {
    return 'bus $bus · porta $port';
  }

  @override
  String get virtSbUnsupported =>
      'I descrittori firmware dell\'host non hanno un firmware Secure Boot con chiavi registrate, quindi un dominio che lo usa non può avviarsi.';

  @override
  String get virtCreateSecureBoot => 'Secure Boot';

  @override
  String get virtCreateSecureBootNote =>
      'Vengono avviati solo kernel e bootloader firmati.';

  @override
  String virtUsbAddressNote(int bus, int device) {
    return 'bus $bus · dispositivo $device';
  }

  @override
  String get virtHwRevertPendingTitle => 'Scarta le modifiche in sospeso';

  @override
  String virtHwRevertPendingBody(String name) {
    return '$name viene riportato a ciò che sta eseguendo: la definizione viene riscritta da quella in esecuzione, e il prossimo avvio ottiene esattamente ciò che ha questo. Il file NVRAM e il firmware restano come sono.';
  }

  @override
  String virtHwRevertAllAsk(String name) {
    return 'Scartare tutte le modifiche in attesa del prossimo avvio di $name?';
  }

  @override
  String get virtBackupPlanNew => 'Nuovo piano';

  @override
  String get virtBackupPlanNewTip =>
      'Una pianificazione che esegue il backup solo di questo guest.';

  @override
  String virtBackupPlanOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Esegue il backup anche di altri $count guest',
      one: 'Esegue il backup anche di 1 altro guest',
      zero: 'Nessun altro guest',
    );
    return '$_temp0';
  }

  @override
  String get reduceMotion => 'Riduci movimento';

  @override
  String get copyLink => 'Copia link';

  @override
  String funcNeedsAgentPermission(String func) {
    return 'Il tuo account su questo Monitor agent non ha il permesso per $func. Chiedi all\'amministratore dell\'agent.';
  }

  @override
  String funcNeedsAgentHttps(String func) {
    return '$func richiede HTTPS verso questo Monitor agent, oppure HTTP consentito sia sull\'agent sia in questa app.';
  }

  @override
  String funcNeedsAgentSetup(String func) {
    return '$func non è configurato su questo Monitor agent; deve configurarlo il suo gestore.';
  }

  @override
  String get monitorFilesReadOnly =>
      'Sola lettura: questo account può sfogliare i file dell\'agent ma non modificarli.';

  @override
  String get monitorAccess => 'Accesso';

  @override
  String get monitorAccounts => 'Account';

  @override
  String get monitorRoles => 'Ruoli';

  @override
  String get monitorRole => 'Ruolo';

  @override
  String get monitorChangePassword => 'Cambia password';

  @override
  String get monitorNewPassword => 'Nuova password';

  @override
  String get monitorCurrentPassword => 'La tua password attuale';

  @override
  String get monitorReauthTip =>
      'Modificare gli accessi richiede di nuovo la tua password.';

  @override
  String get monitorPasswordTooShort => 'Almeno 8 caratteri';

  @override
  String get monitorPasswordMismatch => 'Le password non coincidono';

  @override
  String get monitorErrReauth => 'La password era errata.';

  @override
  String get monitorErrLastAdmin =>
      'L\'agent ha bisogno di almeno un account amministratore.';

  @override
  String get monitorErrConflict => 'Esiste già o è ancora in uso.';

  @override
  String get monitorErrForbidden => 'Solo un amministratore può farlo.';

  @override
  String get monitorRoleNameRule =>
      'Lettere minuscole, cifre, - e _, fino a 32 caratteri';

  @override
  String get monitorGrantShell => 'Shell e comandi';

  @override
  String get monitorGrantShellTip =>
      'Terminale, processi, servizi, container, snippet, alimentazione — con l\'account dell\'agent';

  @override
  String get monitorGrantSshTerminal => 'Terminale del pannello via SSH';

  @override
  String get monitorGrantVirt => 'Virtualizzazione';

  @override
  String get monitorGrantVirtTip =>
      'Proxmox VE, libvirt e BMC raggiunti dall’agente, nel suo pannello web';

  @override
  String get monitorGrantFiles => 'File';

  @override
  String get monitorGrantConnect => 'Connessioni in uscita';

  @override
  String get monitorGrantConnectTip =>
      'Inoltri di porte locali e dinamici, desktop remoto';

  @override
  String get monitorGrantConnectAllow =>
      'Destinazioni consentite (IP o CIDR, opzionalmente :porta o :da-a; una per riga, vuoto = ovunque)';

  @override
  String get monitorGrantListen => 'Ascolta sul server';

  @override
  String get monitorGrantListenTip => 'Inoltri di porte remoti';

  @override
  String get monitorGrantListenPublic => 'Indirizzi non loopback';

  @override
  String get monitorGrantPorts => 'Intervallo di porte (vuoto = qualsiasi)';

  @override
  String get monitorGrantOff => 'Disattivato';

  @override
  String get monitorBuiltin => 'Predefinito';

  @override
  String get monitorAdminRoleTip =>
      'Gestisce account, ruoli e impostazioni dell\'agent';

  @override
  String get monitorYou => 'Tu';

  @override
  String get monitorNoAccessToSettings =>
      'Solo un amministratore può modificare le impostazioni di questo agent.';

  @override
  String get monitorPasswordNotSaved =>
      'La password è stata cambiata sull\'agent, ma l\'app non è riuscita a salvarla. Aggiorna la password Monitor nelle impostazioni di questo server.';

  @override
  String get firewall => 'Firewall';

  @override
  String get firewallLinuxOnly =>
      'La gestione del firewall supporta i server Linux con ufw o firewalld.';

  @override
  String get firewallNeedsRoot =>
      'Leggere le regole del firewall richiede root. Inserisci la password di sudo per continuare.';

  @override
  String get firewallIncoming => 'In entrata';

  @override
  String get firewallOutgoing => 'In uscita';

  @override
  String get firewallRouted => 'Inoltrato';

  @override
  String get firewallDefaultPolicy => 'Criterio predefinito';

  @override
  String get firewallLogging => 'Registrazione';

  @override
  String get firewallRules => 'Regole';

  @override
  String get firewallRule => 'Regola';

  @override
  String get firewallAddRule => 'Aggiungi regola';

  @override
  String get firewallAnywhere => 'Ovunque';

  @override
  String firewallFromFmt(String source) {
    return 'da $source';
  }

  @override
  String get firewallFrom => 'Da';

  @override
  String get firewallTo => 'A';

  @override
  String get firewallProtocol => 'Protocollo';

  @override
  String get firewallInterface => 'Interfaccia';

  @override
  String get firewallComment => 'Commento';

  @override
  String get firewallAppProfile => 'Profilo applicazione';

  @override
  String get firewallPrepend => 'Metti prima di tutte le altre regole';

  @override
  String get firewallIpv6Off =>
      'IPv6 è disattivato (IPV6=no): le regole v6 non vengono caricate.';

  @override
  String get firewallReload => 'Ricarica';

  @override
  String get firewallNothingMatched =>
      'Inserisci una porta, un profilo applicazione, un indirizzo o un\'interfaccia.';

  @override
  String get firewallInvalidPort =>
      'Porta non valida. Usa 22, 80,443 o 6000:6010.';

  @override
  String get firewallTooManyPorts =>
      'Al massimo 15 porte; un intervallo conta come due.';

  @override
  String get firewallPortsNeedProtocol =>
      'Un elenco o un intervallo di porte richiede tcp o udp.';

  @override
  String get firewallInvalidAddress =>
      'Indirizzo non valido. Usa un indirizzo IP o una rete come 192.168.1.0/24.';

  @override
  String get firewallMixedIpVersions =>
      'Da e A devono essere entrambi IPv4 o entrambi IPv6.';

  @override
  String get firewallInvalidInterface => 'Nome dell\'interfaccia non valido.';

  @override
  String get firewallInvalidComment =>
      'Il commento non può contenere \' o interruzioni di riga.';

  @override
  String get firewallInterfaceIn => 'Interfaccia in entrata';

  @override
  String get firewallInterfaceOut => 'Interfaccia in uscita';

  @override
  String get firewallSourcePort => 'Porta di origine';

  @override
  String get firewallMoreOptions => 'Altre opzioni';

  @override
  String get firewallNoneInstalled =>
      'Né ufw né firewalld sono installati su questo server. Installane uno con il gestore di pacchetti del sistema, ad esempio `apt install ufw` o `dnf install firewalld`.';

  @override
  String get firewallKeepAccess =>
      'Mantieni prima aperte le porte di questa app';

  @override
  String firewallWillRefuseFmt(String access) {
    return '$access: le nuove connessioni di questa app verranno rifiutate. La connessione in uso resta attiva finché non cade.';
  }

  @override
  String firewallMayRefuseFmt(String access) {
    return '$access: le nuove connessioni di questa app potrebbero essere rifiutate. Dipende dall\'indirizzo o dall\'interfaccia da cui arrivano, che questa app non può conoscere.';
  }

  @override
  String firewallRateLimitedFmt(String access) {
    return '$access: le connessioni saranno limitate. Un indirizzo che ne apre 6 o più in 30 secondi viene rifiutato, e questa app può riconnettersi con quella frequenza.';
  }

  @override
  String get firewallConflict =>
      'ufw e firewalld sono entrambi attivi. Entrambi scrivono le regole del kernel, e l\'ultimo caricato decide cosa passa.';

  @override
  String get firewallDefaultZone => 'Zona predefinita';

  @override
  String get firewallZone => 'Zona';

  @override
  String get firewallTarget => 'Target';

  @override
  String get firewallMasquerade => 'Masquerade';

  @override
  String get firewallServices => 'Servizi';

  @override
  String get firewallPorts => 'Porte';

  @override
  String get firewallSources => 'Origini';

  @override
  String get firewallInterfaces => 'Interfacce';

  @override
  String get firewallRichRules => 'Rich rules';

  @override
  String get firewallForwardPorts => 'Porte inoltrate';

  @override
  String get firewallRuntimeOnly => 'solo runtime';

  @override
  String get firewallPermanentOnly => 'solo permanent';

  @override
  String get firewallThisConnection => 'questa connessione';

  @override
  String get firewallDefaultTag => 'predefinita';

  @override
  String get firewallDrift =>
      'Ciò che è in vigore differisce da ciò che è salvato. Un reload o un riavvio lo sostituisce con la configurazione salvata.';

  @override
  String firewallDriftLockoutFmt(String access) {
    return 'Dopo un reload o un riavvio, $access verrà rifiutato: la configurazione salvata non lo lascia passare.';
  }

  @override
  String get firewallSaveRuntime => 'Salva come permanent';

  @override
  String get firewallReloadLoses =>
      'Le modifiche non salvate come permanent andranno perse.';

  @override
  String get firewallPanic =>
      'La modalità panic è attiva: ogni pacchetto viene scartato.';

  @override
  String get firewallPanicOff => 'Disattiva la modalità panic';

  @override
  String get firewallStoppedNote =>
      'firewalld è fermo. Le modifiche vengono salvate e si applicano al suo avvio.';

  @override
  String get firewallInvalidSource =>
      'Origine non valida. Usa un indirizzo, una rete come 192.168.1.0/24, ipset:NOME o un indirizzo MAC.';

  @override
  String get firewallInvalidRichRule =>
      'Una rich rule inizia con \"rule\" e occupa una sola riga.';

  @override
  String get firewallInvalidForwardPort =>
      'Usa port=80:proto=tcp:toport=8080, con toport, toaddr o entrambi.';

  @override
  String get monitorSyncNeedsServer =>
      'Scegli il server il cui agente monitor conserva il backup.';

  @override
  String get monitorBackupUnsupported =>
      'Questo agente monitor non può conservare backup. Aggiorna l\'agente.';

  @override
  String get monitorBackupAdminOnly =>
      'Solo un account amministratore dell\'agente monitor può conservare backup su di esso.';

  @override
  String monitorBackupTooLarge(String max) {
    return 'Il backup supera la dimensione accettata dall\'agente monitor ($max).';
  }

  @override
  String get monitorBackupTooMany =>
      'L\'agente monitor contiene già il numero massimo di backup consentito. Eliminane prima uno.';

  @override
  String get virtCreateVmidInvalid => 'Un VMID da 100 a 999999999.';

  @override
  String get virtCreateNodeOffline => 'Quel nodo non è online.';

  @override
  String get virtCreateMediaMissing =>
      'Quel supporto di installazione non è su questo host.';

  @override
  String get virtCreateNetworkMissing =>
      'Un nuovo guest non può usare quella rete.';

  @override
  String get virtCreateNotOffered =>
      'Questo host non lo offre per una nuova VM.';

  @override
  String get virtCreateSecureBootNeedsUefi => 'Secure Boot richiede UEFI.';

  @override
  String get virtGuestNotStopped => 'Spegnilo prima.';

  @override
  String get virtGuestIsTemplate => 'È già un modello.';

  @override
  String get virtCreateImageBigger =>
      'L\'immagine è più grande del disco: rendi il disco almeno altrettanto grande.';
}
