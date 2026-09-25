// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appearanceSettings => 'Aspetto';

  @override
  String get appearancePreset => 'Tema predefinito';

  @override
  String get appearanceThemeSchemaRange => 'Schema del tema supportato';

  @override
  String get appearanceThemeInstall => 'Installa tema';

  @override
  String get appearanceThemeStore => 'Negozio temi';

  @override
  String get appearanceInvalidTheme => 'Pacchetto tema o catalogo non valido';

  @override
  String get themeStoreRefreshFailed =>
      'Impossibile leggere il catalogo dei temi.';

  @override
  String themeStoreDeleteTheme(String name) {
    return 'Eliminare «$name»? I suoi file vengono rimossi da questo dispositivo. Se è il tema in uso, l\'app torna al tema predefinito.';
  }

  @override
  String themeStoreUpdatedFmt(String ago) {
    return 'aggiornato $ago';
  }

  @override
  String get themeStoreUpdatedJustNow => 'aggiornato adesso';

  @override
  String get themeStoreSortInUse => 'In uso per primi';

  @override
  String themeStoreMakeOwnFmt(String doc) {
    return 'Vuoi creare il tuo tema? Vedi [come crearne uno]($doc) — grazie per il tuo contributo!';
  }

  @override
  String appearanceThemeNeedsNewerApp(String version) {
    return 'È necessaria una versione più recente dell’app: $version';
  }

  @override
  String get appearanceFontFamilies => 'Famiglie di caratteri dell’interfaccia';

  @override
  String get appearanceFontFamiliesTip =>
      'Un nome per riga; i caratteri vengono provati in ordine.';

  @override
  String get appearanceFontImport =>
      'Importa file di caratteri per l’interfaccia';

  @override
  String get appearanceGradient => 'Sfumatura';

  @override
  String get appearanceNoBackground => 'Nessuno sfondo';

  @override
  String get appearanceIcons => 'Icone nell’app';

  @override
  String get appearanceCorners => 'Angoli';

  @override
  String get appearanceCardCorners => 'Angoli delle schede';

  @override
  String get appearanceTileCorners => 'Angoli degli elementi';

  @override
  String get appearanceButtonCorners => 'Angoli dei pulsanti';

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
  String get askAiAwaitingResponse => 'In attesa della risposta dell\'IA...';

  @override
  String get askAiEndpointTip =>
      'Un dominio o un URL completo. Il percorso viene completato dal protocollo scelto.';

  @override
  String get askAiProtocolTip => 'Auto prova Responses, poi Chat Completions.';

  @override
  String get askAiCommandInserted => 'Comando inserito nel terminale';

  @override
  String askAiConfigMissing(String fields) {
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
  String get remoteDesktop => 'Desktop remoto';

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
  String get askAiResend => 'Invia di nuovo';

  @override
  String get askAiResendTip =>
      'Tutto ciò che segue questo messaggio verrà eliminato: risposte, comandi e relativi risultati.';

  @override
  String get askAiDeleteTip =>
      'Questo messaggio e tutto ciò che lo segue verranno eliminati: risposte, comandi e relativi risultati.';

  @override
  String get askAiModelTable => 'Tabella dei modelli';

  @override
  String get askAiModelTableTip =>
      'Dimensioni del contesto per nome del modello, da models.dev. Una tabella è inclusa nell\'app; tocca per scaricarne una più recente.';

  @override
  String get askAiContextFallback => 'non presente nella tabella';

  @override
  String get askAiCompactAt => 'Riassumi al';

  @override
  String get askAiCompactAtTip =>
      'Quanto può riempirsi il contesto del modello prima che i turni precedenti vengano riassunti. Un valore più basso fa perdere prima i dettagli; uno più alto aumenta il rischio che il modello rifiuti una richiesta.';

  @override
  String get askAiContextTokens => 'Dimensioni del contesto';

  @override
  String get askAiContextTokensTip =>
      'Il numero di token che questo modello può contenere. La modalità automatica lo cerca per nome; imposta un numero se il provider offre una finestra più breve di quella supportata dal modello.';

  @override
  String get askAiConversationCompacted =>
      'I messaggi precedenti sono stati riassunti per poter continuare la conversazione.';

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
  String get askAiAllowInsecure => 'Consenti HTTP non crittografato';

  @override
  String get askAiAllowInsecureTip =>
      'Consente connessioni http:// ai modelli self-hosted su indirizzi diversi da localhost. La chiave API e l’eventuale contesto del terminale vengono inviati senza crittografia; localhost non è interessato.';

  @override
  String get askAiInsecureEndpoint =>
      'Questo endpoint usa http://. Attiva «Consenti HTTP non crittografato» nelle impostazioni AI per utilizzarlo.';

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
  String agentToolCallsFmt(int count) {
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
  String madeWithLove(String myGithub) {
    return 'Realizzato con ❤️ da $myGithub';
  }

  @override
  String get maxConcurrency => 'Massima concorrenza';

  @override
  String get maxRetryCount => 'Numero di riconnessioni del server';

  @override
  String mismatchSystem(String system) {
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
  String get preferDiskAmount => 'Priorità visualizzazione capacità disco';

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
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand è supportato solo sulle piattaforme desktop.';

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
  String get sshConnectionModeTip =>
      'Integrato: usa il terminale dell\'app. SSH di sistema: avvia il comando ssh di sistema in un terminale esterno.';

  @override
  String get sshConnectionModeUseBuiltin => 'Usa il terminale integrato';

  @override
  String get sshConnectionModeUseSystem => 'Usa l\'SSH di sistema';

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
  String portForward_deleteConfirmFmt(String name) {
    return 'Eliminare $name?';
  }

  @override
  String get sponsor => 'Sponsor';

  @override
  String get sortByJoinTime => 'Per data di aggiunta';

  @override
  String get portForwardBetaTitle => 'Inoltro porte (Beta)';

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
  String transportOrderFmt(String first, String second) {
    return 'Trascina per cambiare l\'ordine. $first viene contattato per primo; se non risponde, $second porta avanti la sessione da solo.';
  }

  @override
  String transportOnlyFmt(String name) {
    return 'È attivo solo $name, quindi non c\'è nulla su cui ripiegare.';
  }

  @override
  String get transportNoneOn =>
      'Sono entrambi disattivati: questo server non può essere connesso.';

  @override
  String get transportOffKept =>
      'disattivato — impostazioni conservate, mai contattato';

  @override
  String get transportDialledFirst => 'contattato per primo';

  @override
  String get transportFallback => 'ripiego';

  @override
  String get transportOnlyMethod => 'unico metodo';

  @override
  String get transportOff => 'disattivato';

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
  String get optionalTip =>
      'Nulla qui serve per connettersi. Aprine uno e i suoi campi prendono il posto del modulo.';

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
  String appearanceThemeModeLocked(String mode) {
    return 'Questo tema supporta solo $mode. Seleziona un altro tema per cambiare modalità.';
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
  String get reopen => 'Riapri';

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
  String get virtCreateVmidInvalid => 'Da 100 a 999999999.';

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
  String virtDeleteAsk(String name) {
    return 'Eliminare $name? Non si può annullare.';
  }

  @override
  String virtDeleteTypeName(String name) {
    return 'Digita $name per confermare';
  }

  @override
  String get virtDeleteDisks => 'Elimina anche i suoi dischi';

  @override
  String get virtDeleteDisksTip =>
      'Il supporto di installazione collegato viene conservato.';

  @override
  String get virtDeleteDisksPve =>
      'I suoi dischi vengono eliminati con esso; il supporto di installazione viene conservato.';

  @override
  String virtDeleteStopFirst(String name) {
    return '$name è in esecuzione. Va fermato prima di eliminarlo. Forzare lo spegnimento ora?';
  }

  @override
  String virtDeleted(String name) {
    return '$name eliminato';
  }

  @override
  String get pveTokenTipCreate =>
      'Creare ed eliminare guest richiede anche VM.Allocate, VM.Config.*, Datastore.AllocateSpace e SDN.Use.';

  @override
  String get pveTokenTipHardware =>
      'Modificare l\'hardware richiede VM.Config.CPU, VM.Config.Memory, VM.Config.Disk, VM.Config.CDROM, VM.Config.Network e VM.Config.Options; nuovi dischi e interfacce richiedono anche Datastore.AllocateSpace e SDN.Use.';

  @override
  String get virtErrConflict => 'Modificato altrove';

  @override
  String get virtErrConflictTip =>
      'Qualcuno ha modificato la configurazione di questo guest dopo che è stata letta qui, quindi non è stato cambiato nulla. È stata riletta: ripeti la modifica se serve ancora.';

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
  String get virtHwIssueSwap => 'Non negativo';

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
  String get virtHwPendingTip =>
      'Il guest in esecuzione mantiene il valore a sinistra; riceve quello a destra al prossimo avvio.';

  @override
  String get virtHwPendingTitle => 'In attesa del prossimo avvio';

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
}
