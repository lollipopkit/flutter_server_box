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
  String get crashUpload => 'Invia i rapporti di arresto anomalo';

  @override
  String get crashUploadTip =>
      'Invia i rapporti di arresto anomalo allo sviluppatore. I nomi e gli indirizzi dei server noti vengono sostituiti da segnaposto. Disattivato per impostazione predefinita; puoi disattivarlo in qualsiasi momento.';

  @override
  String get crashNoticeBody =>
      'ServerBox si è chiuso inaspettatamente durante l\'ultima esecuzione. Vuoi vedere il rapporto di arresto anomalo?';

  @override
  String get crashReportTitle => 'Rapporto di arresto anomalo';

  @override
  String get crashReportHint =>
      'Questo è il registro dell\'esecuzione precedente. I nomi e gli indirizzi dei server noti sono stati sostituiti da segnaposto, ma altri dettagli possono rimanere. Leggilo attentamente prima di inviarlo.';

  @override
  String get crashReportSubmit => 'Copia e segnala';

  @override
  String get acceptBeta => 'Accetta aggiornamenti versione beta';

  @override
  String get addSystemPrivateKeyTip =>
      'Attualmente non esistono chiavi private, vuoi aggiungere quella fornita dal sistema (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Aggiunto alla lista delle attività';

  @override
  String get askAi => 'Chiedi all\'IA';

  @override
  String get askAiAwaitingResponse => 'In attesa della risposta dell\'IA...';

  @override
  String get askAiEndpointTip =>
      'Un dominio o un URL completo. Il percorso viene completato dal protocollo scelto.';

  @override
  String get askAiProtocolTip => 'Auto prova Responses, poi Chat Completions.';

  @override
  String get askAiCommandInserted => 'Comando inserito nel terminale';

  @override
  String askAiConfigMissing(Object fields) {
    return 'Configura $fields in Impostazioni.';
  }

  @override
  String get askAiDisclaimer =>
      'L\'IA potrebbe essere errata. Rivedi attentamente prima di applicare.';

  @override
  String get askAiInsertTerminal => 'Inserisci nel terminale';

  @override
  String get askAiNoResponse => 'Nessuna risposta';

  @override
  String get askAiAgentWelcome => 'Cosa facciamo su questo server?';

  @override
  String get askAiAgentPromptHint =>
      'Chiedi all\'Agente di esaminare o sistemare qualcosa...';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Analizza l’output selezionato del terminale e spiega cosa è successo';

  @override
  String get askAiTerminalContext => 'Contesto del terminale';

  @override
  String get askAiReviewNeeded => 'Da rivedere';

  @override
  String get askAiReviewAction => 'Rivedi il comando proposto';

  @override
  String get askAiReviewBeforeContinuing =>
      'Prima esamina o rifiuta il suggerimento attuale';

  @override
  String get askAiApproveRun => 'Approva ed esegui';

  @override
  String get askAiDecline => 'Rifiuta';

  @override
  String get askAiActionDeclined => 'Il comando proposto è stato rifiutato.';

  @override
  String get askAiInterrupted => 'La risposta dell\'Agente è stata interrotta.';

  @override
  String get askAiRiskReadOnly => 'Sola lettura';

  @override
  String get askAiRiskCaution => 'Modifica il sistema';

  @override
  String get askAiRiskUnvetted => 'Host non verificato';

  @override
  String get askAiRiskDestructive => 'Rischio alto';

  @override
  String get askAiHighRiskConfirmTitle =>
      'Eseguire un comando ad alto rischio?';

  @override
  String get askAiHighRiskConfirmBody =>
      'Questo comando può fare modifiche difficili da annullare. Controllalo bene.';

  @override
  String get askAiNoCommandOutput => 'Il comando è terminato senza output.';

  @override
  String get askAiOutputTruncated =>
      'L\'output lungo è stato troncato prima di essere restituito all\'Agente.';

  @override
  String get askAiAutoApproved => 'Approvato automaticamente';

  @override
  String get askAiAutoRunSafeCommands =>
      'Esegui automaticamente i comandi di sola lettura';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Viene eseguito solo se modello e controllo locale lo dicono di sola lettura';

  @override
  String get askAiSendOnEnter => 'Invio invia';

  @override
  String get askAiSendOnEnterTip =>
      'Invio invia, Maiusc+Invio a capo. Disattivato: Invio a capo, Cmd/Ctrl+Invio invia.';

  @override
  String get askAiApiKeyOptional =>
      'Lascia vuoto per locale o senza autenticazione';

  @override
  String get askAiHistory => 'Cronologia conversazioni';

  @override
  String get askAiNewConversation => 'Nuova conversazione';

  @override
  String get askAiNoHistory => 'Nessuna conversazione salvata';

  @override
  String get askAiNoHistoryMessages => 'Ancora nessun messaggio';

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
  String get askAiClearHistoryTitle =>
      'Cancellare la cronologia dell\'Agente di questo server?';

  @override
  String get askAiClearHistoryTip =>
      'Tutte le conversazioni Agent salvate per questo server saranno eliminate.';

  @override
  String get askAiRestoredReview =>
      'Questo comando viene dalla cronologia. Riesaminalo';

  @override
  String get agentWelcome => 'Cosa facciamo sui tuoi server?';

  @override
  String get agentWelcomeTip =>
      'Lascia che l’Agent diagnostichi un problema o svolga un’attività';

  @override
  String get agentPromptHint =>
      'Chiedi all\'Agente di esaminare o gestire i tuoi server...';

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
  String get agentToolFailed => 'Esecuzione dello strumento non riuscita.';

  @override
  String agentToolCallsFmt(Object count) {
    return '$count chiamate di strumento';
  }

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
  String get markUrl => 'URL del marchio';

  @override
  String get markUrlTip =>
      'Il piccolo marchio accanto al nome di un server negli elenchi. Vuoto: nessuno.\n\nNon è la stessa immagine del logo';

  @override
  String get navTabMenuTip =>
      'Tieni premuta una scheda — o fai clic destro — per connettere o disconnettere in una volta tutto ciò che contiene.';

  @override
  String nTags(Object count) {
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
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return 'Ultimo backup: $lastModified\nStato: $remoteState';
  }

  @override
  String get bgRun => 'Esegui in background';

  @override
  String get bgRunTip =>
      'Questa opzione significa solo che il programma cercherà di eseguire in background. Se può eseguire in background dipende dal fatto che il permesso sia abilitato o meno. Per le ROM Android basate su AOSP, disabilita \"Ottimizzazione batteria\" in questa app. Per MIUI/HyperOS, cambia la politica di risparmio energetico su \"Illimitato\".';

  @override
  String get trayTitle => 'Icona di stato';

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
      'Una riga per server, senza grafico. È anche ciò che Linux visualizza in ogni caso: il suo menu del pannello viene inviato tramite D-Bus, che trasporta un’etichetta ma non un layout.';

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
  String get copyPath => 'Copia percorso';

  @override
  String get cpuViewAsProgressTip =>
      'Visualizza l\'utilizzo di ogni CPU in stile barra di avanzamento (stile vecchio)';

  @override
  String get customCmd => 'Comandi personalizzati';

  @override
  String get deleteServers => 'Elimina server in blocco';

  @override
  String get deleteDirRecursive =>
      'Elimina la cartella e tutto il suo contenuto';

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
  String get distro => 'Distribuzione';

  @override
  String get diskHealth => 'Salute disco';

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
  String get dockerProjectOther => 'Altri';

  @override
  String get dockerPruneTip =>
      'Rimuovi i dati inutilizzati per liberare spazio su disco';

  @override
  String get dockerStatistics => 'Statistiche Docker';

  @override
  String get doubleColumnMode => 'Modalità a doppia colonna';

  @override
  String get doubleColumnTip =>
      'Questa opzione abilita solo la funzione, se può essere effettivamente abilitata dipende dalla larghezza del dispositivo';

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
  String fileTooLarge(Object file, Object size, Object sizeMax) {
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
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return 'Jump server non trovati per $serverName: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(Object name) {
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
  String get preferredTransport => 'Prova per prima';

  @override
  String get preferredTransportTip =>
      'Da dove viene letto lo stato e quale connessione apre per prima un comando. L\'altra resta disponibile.';

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
  String madeWithLove(Object myGithub) {
    return 'Realizzato con ❤️ da $myGithub';
  }

  @override
  String get maxConcurrency => 'Massima concorrenza';

  @override
  String get maxRetryCount => 'Numero di riconnessioni del server';

  @override
  String mismatchSystem(Object system) {
    return 'Sistema non corrispondente: $system';
  }

  @override
  String get mirror => 'Mirror';

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
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand è supportato solo sulle piattaforme desktop.';

  @override
  String get pveIgnoreCertTip =>
      'Non si consiglia di abilitare, attento ai rischi per la sicurezza! Se stai usando il certificato predefinito da PVE, devi abilitare questa opzione.';

  @override
  String get pveServerClientMissing =>
      'Il client SSH per questo server non è disponibile.';

  @override
  String get pveAddressMissing =>
      'Manca l\'indirizzo PVE. Configuralo nelle impostazioni del server.';

  @override
  String get pvePasswordRequired =>
      'È richiesta la password PVE. Impostala nelle impostazioni del server.';

  @override
  String get pveOtpRequired =>
      'Su questo server PVE è attiva l\'autenticazione a due fattori. Inserisci il codice OTP.';

  @override
  String get pveOtpChallengeExpired =>
      'La richiesta OTP è scaduta. Aggiorna e riprova.';

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
  String get pveVersionLow =>
      'Questa funzionalità è attualmente nella fase di test ed è stata testata solo su PVE 8+. Usala con cautela.';

  @override
  String get pveLoadingForwarding => 'Creazione del tunnel SSH...';

  @override
  String get pveLoadingLogin => 'Autenticazione con PVE...';

  @override
  String get pveLoadingData => 'Recupero dei dati del cluster...';

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
    Object distro,
    Object installed,
    Object latest,
    Object pm,
  ) {
    return '$distro $installed è installato, $latest è disponibile. L’aggiornamento sostituisce l’intero container: i dati $pm vanno persi';
  }

  @override
  String linuxSystemInUse(Object name) {
    return 'Chiudi i terminali su $name prima di eliminarlo';
  }

  @override
  String get rootfsSubtitle => 'Uno spazio utente Linux su questo dispositivo';

  @override
  String rootfsInstallTip(Object distro, Object version, Object size) {
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
  String selected(Object count) {
    return '$count selezionati';
  }

  @override
  String get sendTo => 'Invia a…';

  @override
  String get serverDetailOrder => 'Ordine widget pagina dettagli';

  @override
  String get serverFuncBtns => 'Pulsanti funzione server';

  @override
  String get serverOrder => 'Ordine server';

  @override
  String get serverTabEmpty => 'Ancora nessun server';

  @override
  String get serverTabRequired => 'La scheda server non può essere rimossa';

  @override
  String get shareServerRiskTip =>
      'Questo codice QR contiene le impostazioni di connessione in chiaro. Chi lo scansiona o fotografa può connettersi.';

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
  String spentTime(Object time) {
    return 'Tempo impiegato: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'Tutti i server esistono già ($duplicateCount duplicati trovati)';
  }

  @override
  String get sshConnectionModeTip =>
      'Integrato: usa il terminale dell\'app. SSH di sistema: avvia il comando ssh di sistema in un terminale esterno.';

  @override
  String get sshConnectionModeUseBuiltin => 'Usa il terminale integrato';

  @override
  String get sshConnectionModeUseSystem => 'Usa l\'SSH di sistema';

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
  String get sshHostKeyType => 'Tipo chiave host SSH';

  @override
  String get sshKnownHostKeys => 'Host conosciuti';

  @override
  String get sshKnownHostKeysTip =>
      'Le chiavi host che questa app ha accettato';

  @override
  String sshHostKeyNewDesc(Object serverName) {
    return 'È stata ricevuta una nuova chiave host SSH da $serverName. Rivedi l\'impronta digitale prima di fidarti.';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
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
  String sshConfigServersToImport(Object importCount) {
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
  String switchTo(Object val) {
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
  String get view => 'Visualizza';

  @override
  String get viewDetails => 'Visualizza dettagli';

  @override
  String get virtKeyHelpClipboard =>
      'Copia negli appunti se il terminale selezionato non è vuoto, altrimenti incolla il contenuto degli appunti nel terminale.';

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
      'Nelle impostazioni del terminale puoi riordinarli o nascondere quelli che non usi mai.';

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
  String portForward_deleteConfirmFmt(Object name) {
    return 'Eliminare $name?';
  }

  @override
  String get sponsor => 'Sponsor';

  @override
  String get sortByJoinTime => 'Per data di aggiunta';

  @override
  String get serverHistory => 'Cronologia server';

  @override
  String get portForwardBetaTitle => 'Port Forward (Beta)';

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
  String get tmuxExistingSessions => 'Sessioni esistenti';

  @override
  String get tmuxNewSession => 'Nuova sessione';

  @override
  String get tmuxWindows => 'Finestre';

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
  String tmuxPaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count riquadri',
      one: '1 riquadro',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Collegata';

  @override
  String get tmuxActive => 'Attiva';

  @override
  String tmuxActiveAt(String time) {
    return 'attiva: $time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return 'collegata: $time';
  }

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
  String get serviceEnabled => 'Abilitato all\'avvio';

  @override
  String get systemdUserScopeMissing => 'Le unità utente non sono elencate';

  @override
  String get systemdUserScopeMissingTip =>
      'Questo account non ha un bus di sessione utente sul server, quindi vengono mostrate solo le unità di sistema.';

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
  String get send => 'Invia';

  @override
  String get privacyBlur => 'Privacy in background';

  @override
  String get privacyBlurTip =>
      'Nascondi il contenuto dell\'app nel selettore app';

  @override
  String get floatReturnToTab => 'Torna alla scheda';

  @override
  String get termInFloatWindow => 'Questo terminale è nella finestra mobile';
}
