// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

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
      'Inserisci un URL di base del servizio o un endpoint completo Chat Completions o Responses. ServerBox completa il percorso in base al protocollo scelto.';

  @override
  String get askAiProtocolTip =>
      'Auto usa Responses per l\'endpoint ufficiale di OpenAI e Chat Completions per i provider compatibili.';

  @override
  String get askAiProtocolChatCompletions => 'Chat Completions';

  @override
  String get askAiProtocolResponses => 'Responses';

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
  String get askAiAgentTitle => 'Agente SSH';

  @override
  String get askAiAgentWelcome => 'Cosa facciamo su questo server?';

  @override
  String get askAiAgentWelcomeTip =>
      'Chiedi una diagnosi o un\'attività. L\'Agente propone un comando alla volta e attende la tua revisione prima di apportare modifiche.';

  @override
  String get askAiAgentPromptHint =>
      'Chiedi all\'Agente di esaminare o sistemare qualcosa...';

  @override
  String get askAiAgentSend => 'Invia all\'Agente';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Analizza il contenuto selezionato del terminale, spiega cosa è successo e proponi il passo successivo più sicuro se serve intervenire.';

  @override
  String get askAiTerminalContext => 'Contesto del terminale';

  @override
  String get askAiReviewNeeded => 'Da rivedere';

  @override
  String get askAiReviewAction => 'Rivedi il comando proposto';

  @override
  String get askAiReviewBeforeContinuing =>
      'Prima rivedi o rifiuta il comando proposto';

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
      'Questo comando può eliminare dati, arrestare servizi o essere difficile da annullare. Rivedilo con attenzione prima di eseguirlo.';

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
      'Esecuzione automatica solo quando sia il modello sia i controlli di sicurezza locali classificano il comando come di sola lettura. I comandi che modificano il sistema richiedono comunque una revisione.';

  @override
  String get askAiSendOnEnter => 'Invio invia';

  @override
  String get askAiSendOnEnterTip =>
      'Invio invia il messaggio, Maiusc+Invio va a capo. Se disattivato si invertono: Invio va a capo e Cmd/Ctrl+Invio invia.';

  @override
  String get askAiApiKeyOptional =>
      'Facoltativa per endpoint locali o senza autenticazione';

  @override
  String get askAiHistory => 'Cronologia conversazioni';

  @override
  String get askAiNewConversation => 'Nuova conversazione';

  @override
  String get askAiNoHistory =>
      'Nessuna conversazione salvata per questo server';

  @override
  String get askAiNoHistoryMessages => 'Ancora nessun messaggio';

  @override
  String get askAiUntitledConversation => 'Nuova conversazione';

  @override
  String get askAiRenameConversation => 'Rinomina conversazione';

  @override
  String get askAiDeleteConversationTitle => 'Eliminare questa conversazione?';

  @override
  String get askAiDeleteConversationTip =>
      'La conversazione verrà rimossa da questo dispositivo e non sarà possibile annullare.';

  @override
  String get askAiClearHistoryTitle =>
      'Cancellare la cronologia dell\'Agente di questo server?';

  @override
  String get askAiClearHistoryTip =>
      'Tutte le conversazioni dell\'Agente salvate per questo server verranno rimosse da questo dispositivo.';

  @override
  String get askAiRestoredReview =>
      'Ripristinato dalla cronologia. Rivedilo di nuovo prima di eseguirlo; non verrà mai eseguito da solo.';

  @override
  String get agentTitle => 'Agente';

  @override
  String get agentWelcome => 'Cosa facciamo sui tuoi server?';

  @override
  String get agentWelcomeTip =>
      'Chiedi una diagnosi o un\'attività operativa. L\'Agente usa lo stato attuale di ServerBox e propone un\'azione da rivedere alla volta.';

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
  String get agentToolServerBox => 'ServerBox';

  @override
  String get agentToolFailed => 'Esecuzione dello strumento non riuscita.';

  @override
  String agentToolCallsFmt(Object count) {
    return '$count chiamate di strumento';
  }

  @override
  String get agentFloat => 'In sovrimpressione sulle altre schede';

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
      'L\'Agente vuole aprire una connessione SSH. Digita qui la password, mai nella conversazione, dove verrebbe salvata e inviata al modello.';

  @override
  String get agentAdHocSessions => 'Connessioni temporanee';

  @override
  String get agentSaveServerTitle => 'Salva come server';

  @override
  String get agentSaveServerTip =>
      'Questo host e la password digitata verranno salvati su questo dispositivo.';

  @override
  String get agentMonitorOptional => 'Agente monitor (facoltativo)';

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
  String get remoteBackupPasswordRequired =>
      'Remote backups require a non-empty backup password';

  @override
  String get monitorHttpsRequired =>
      'Remote monitor agents require HTTPS; HTTP is allowed only on loopback.';

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
  String get fileDirGoneTip =>
      'È stata eliminata o rinominata. Usa la barra in basso per tornare indietro, andare alla home o spostarti altrove.';

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
  String get githubGist => 'GitHub Gist';

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
  String get homeWidgetUrlConfig => 'Configura url widget home';

  @override
  String get ignoreCert => 'Ignora certificato';

  @override
  String get image => 'Immagine';

  @override
  String get macDmgBody =>
      'L\'App Store richiede che questa app giri in sandbox, e un processo in sandbox non può aprire uno pseudo-terminale. Per questo la versione App Store non ha un terminale su questo Mac e non può eseguirvi snippet o comandi dell\'agent. La versione DMG è la stessa app firmata senza sandbox, e li ha.\n\nLa versione App Store continua a funzionare e ad aggiornarsi. Più avanti gli aggiornamenti potrebbero finire.\n\nLe due versioni tengono i dati in posti diversi. La versione DMG li copia al primo avvio, così server, chiavi e cronologia vengono con te. Se non riesce te lo dice, e puoi migrare con un file di backup (Backup, nelle impostazioni).';

  @override
  String get macDmgImportDenied =>
      'macOS non ha consentito di leggere i dati della versione installata in precedenza. Concedi Accesso completo al disco e riapri l\'app, oppure esporta lì un backup e ripristinalo qui.';

  @override
  String get macDmgImported =>
      'Dati della versione installata in precedenza importati.';

  @override
  String get macDmgImportFailed =>
      'Impossibile leggere i dati della versione installata in precedenza. Esporta lì un backup e ripristinalo qui.';

  @override
  String get macDmgTip =>
      'Il terminale su questo Mac e l\'esecuzione di snippet qui esistono solo nella versione DMG.';

  @override
  String get macDmgTitle => 'Versione DMG';

  @override
  String get showHiddenFiles => 'Mostra i file nascosti';

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
  String get pruneDanglingImagesTip =>
      'Rimuove solo le immagini orfane (layer senza tag).';

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
  String get onlyOneLine => 'Visualizza solo come una riga (scorrevole)';

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
  String get proxyCommandSandboxed =>
      'Questa build gira in una sandbox: il comando vede una home vuota anziché la tua, quindi tutto ciò che legge ~/.ssh (ssh -W, cloudflared) fallisce, spesso come timeout che nomina l\'host sbagliato. I comandi che usano solo la rete continuano a funzionare. La versione DMG non ha sandbox.';

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
  String rootfsUpdateTip(Object installed, Object latest) {
    return 'Alpine $installed è installato ed è disponibile $latest. L\'aggiornamento lo scarica di nuovo e sostituisce il container: tutto ciò che vi è stato installato con apk viene perso. Saltando l\'aggiornamento, quello attuale continua a funzionare.';
  }

  @override
  String get rootfsSubtitle => 'Uno spazio utente Linux su questo dispositivo';

  @override
  String rootfsInstallTip(Object version) {
    return 'Scarica Alpine Linux $version (circa 3 MB) e lo decomprime su questo dispositivo. Fornisce a questa app una shell con gestore di pacchetti e può essere eliminato in qualsiasi momento.';
  }

  @override
  String get sameIdServerExist => 'Esiste già un server con lo stesso ID';

  @override
  String get second => 's';

  @override
  String get serverFilesUnavailableTip =>
      'Raggiungibile tramite l\'SSH di questo server o tramite un agente monitor con la sua API dei file attiva.';

  @override
  String get back => 'Indietro';

  @override
  String get history => 'Cronologia';

  @override
  String get homeDir => 'Home';

  @override
  String get selectItem => 'Seleziona';

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
  String get serverTabRequired => 'La scheda server non può essere rimossa';

  @override
  String get shareServerRiskTip =>
      'Questo codice QR contiene le impostazioni di connessione del server in chiaro, password incluse. Chiunque lo scansioni o lo fotografi può connettersi a questo server.';

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
  String get sftp => 'SFTP';

  @override
  String get sftpShowFoldersFirst => 'Mostra prima le cartelle';

  @override
  String get specifyDev => 'Specifica dispositivo';

  @override
  String get specifyDevTip =>
      'Ad esempio, le statistiche del traffico di rete sono per impostazione predefinita per tutti i dispositivi. Puoi specificare un dispositivo particolare qui.';

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
  String sshHostKeyFingerprintMd5Base64(Object fingerprint) {
    return 'Impronta digitale (MD5 base64): $fingerprint';
  }

  @override
  String sshHostKeyFingerprintMd5Hex(Object fingerprint) {
    return 'Impronta digitale (SHA256): $fingerprint';
  }

  @override
  String get sshHostKeyType => 'Tipo chiave host SSH';

  @override
  String get sshKnownHostKeys => 'Chiavi host conosciute';

  @override
  String get sshKnownHostKeysTip =>
      'Chiavi host accettate da questa app. Eliminane una per essere interrogato di nuovo alla prossima connessione.';

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
  String get system => 'Sistema';

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
  String get portForwardBeta =>
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
  String get systemd => 'Systemd';

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
      'L\'orologio interroga da solo l\'agente monitor di questi server, quindi si possono scegliere solo i server con monitor configurato.';

  @override
  String get watchNoMonitorServer =>
      'Nessun server ha un agente monitor configurato';

  @override
  String get watchLegacyUrls => 'URL di stato legacy';

  @override
  String get accessoryWidgetServer =>
      'Server del widget della schermata di blocco';

  @override
  String get systemdMissing => 'Nessun systemd su questo server';

  @override
  String get systemdMissingTip =>
      '`systemctl` non è installato qui, quindi non ci sono unità da elencare.';

  @override
  String initSystemFmt(String init) {
    return 'Questa macchina sembra usare $init.';
  }

  @override
  String get systemdListFailed => 'Impossibile elencare le unità';

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
      'Consente all\'Agent di operare sulla macchina su cui gira ServerBox, non solo sui server. Qui nulla viene eseguito senza supervisione: ogni comando richiede revisione.';

  @override
  String get agentLocalExecRootfsTip =>
      'Consente all\'Agent di operare su questo dispositivo, all\'interno del container Alpine Linux installato da ServerBox. Non può vedere il file system del telefono, i dati dell\'app o i tuoi file. Ogni comando richiede comunque revisione.';

  @override
  String macDmgImportedPartly(String path) {
    return 'Dati della versione installata in precedenza importati. I file scaricati sono rimasti in $path.';
  }
}
