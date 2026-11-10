import type { Translation } from '../i18n-types.js'

const it: Translation = {
  meta: {
    lang: 'it',
    title: 'ServerBox — Monitoraggio server, SSH e operazioni in un’unica app',
    description:
      'Gestisci server Linux, Unix e Windows con grafici in tempo reale, terminale SSH touch, SFTP, Docker, systemd, S.M.A.R.T., widget e agente IA.',
  },
  nav: {
    features: 'Funzionalità',
    capabilities: 'Capacità',
    download: 'Scarica',
    docs: 'Docs',
    themes: 'Temi',
    os: 'ServerBox OS',
    beta: 'Beta',
    plugins: 'Plugin',
    otherApps: 'Altro',
    signIn: 'Accedi',
    languageLabel: 'Lingua',
  },
  hero: {
    titlePrefix: 'Ogni tuo server,',
    titleSuffix: 'sempre in tasca.',
    subtitle:
      'Telemetria in tempo reale, terminale SSH ottimizzato per il touch, SFTP, container e operazioni assistite dall’IA in un unico workspace nativo per mobile e desktop.',
    primaryAction: 'Scarica ServerBox',
    secondaryAction: 'Esplora le funzioni',
  },
  screenshots: {
    label: 'Screenshot interattivi di ServerBox',
    one: 'Screenshot panoramica server ServerBox',
    two: 'Screenshot grafici ServerBox',
    three: 'Screenshot terminale ServerBox',
    four: 'Screenshot del browser file di ServerBox',
  },
  features: {
    title: 'Progettato per l’operatività reale.',
    subtitle:
      'Controlli rapidi ed emergenze risolte senza dover aprire il portatile.',
    list: {
      title: 'Panoramica server',
      description:
        'Stato di connessione e carico di CPU, memoria, disco e rete a colpo d’occhio. Filtra per tag o visualizza i nodi sul globo 3D.',
    },
    charts: {
      title: 'Telemetria in tempo reale',
      description:
        'Grafici live e storici per CPU, memoria, swap, I/O disco, rete, GPU, sensori e salute S.M.A.R.T.',
    },
    terminal: {
      title: 'Terminale SSH touch',
      description:
        'Tasti virtuali dedicati per usare vim, tmux e htop comodamente dal telefono. Supporto nativo per jump host e ProxyCommand.',
    },
    files: {
      title: 'File manager SFTP',
      description:
        'Sfoglia, trasferisci e modifica i file remoti sul posto con anteprima Markdown formattata.',
    },
    containers: {
      title: 'Docker & Podman',
      description:
        'Container raggruppati per progetto Compose con metriche live, riavvio rapido, streaming dei log e shell interna.',
    },
    processes: {
      title: 'Gestione processi',
      description:
        'Ordina per CPU o memoria, cerca per nome, utente o PID e termina all’istante i processi fuori controllo.',
    },
    services: {
      title: 'Servizi systemd',
      description:
        'Le unità in errore vengono fissate automaticamente in cima alla lista per leggere i log e riavviare il servizio con un tocco.',
    },
    users: {
      title: 'Utenti e gruppi',
      description:
        'Verifica account di sistema, login shell e permessi sudo. Gestisci utenti e gruppi senza ricordare la sintassi da terminale.',
    },
    agent: {
      title: 'Agente IA integrato',
      description:
        'Collega i tuoi provider LLM, server MCP e skill per delegare diagnosi dei log e manutenzione ordinaria.',
    },
    bench: {
      title: 'Benchmark in un tocco',
      description:
        'Esegui YABS per misurare disco, rete e CPU e salvare i risultati insieme a snippet e desktop remoto.',
    },
    virt: {
      title: 'Virtualizzazione',
      description:
        'Controlla VM e container su Proxmox VE e libvirt: alimentazione, vCPU, memoria, dischi e console integrata.',
    },
    themes: {
      title: 'Store dei temi',
      description:
        'Personalizza palette, icone, sfondi e schermate di avvio dallo store integrato oppure crea il tuo tema.',
    },
  },
  capabilities: {
    title: 'Un unico flusso di lavoro nativo.',
    subtitle:
      'Basta passare continuamente tra client SSH, tool SFTP e dashboard di monitoraggio.',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android, Linux e Windows',
  },
  os: {
    metaTitle: 'ServerBox OS (ex ServerBox Monitor) — Il compagno lato server di ServerBox',
    metaDescription:
      'ServerBox OS (ex ServerBox Monitor) porta sul tuo server un desktop nel browser, oltre 40 app Docker in un clic, gestione ZFS/RAID, modalità Agent IA, avvisi e backup cifrati.',
    heroTitle: 'ServerBox OS',
    formerlyMonitor: 'Ex ServerBox Monitor',
    navPreview: 'Demo',
    navInstall: 'Installa',
    navApp: 'App ServerBox',
    tagline: 'Il tuo server, nel browser e nell’app.',
    subtitle:
      'Un singolo demone leggero che offre a qualsiasi macchina Linux un desktop completo nel browser, oltre 40 app self-hosted e sincronizzazione HTTPS con ServerBox — oppure si avvia come sistema operativo dedicato.',
    monitorNote:
      'ServerBox OS è l’evoluzione di ServerBox Monitor (server_box_monitor). Le installazioni Monitor esistenti si aggiornano sul posto con lo stesso comando e continuano a fornire avvisi push, widget, watchOS e grafici storici per l’app.',
    exploreAction: 'Scopri ServerBox OS',
    installAction: 'Installa su Linux',
    images: 'Scarica immagini',
    previewAction: 'Guarda la demo',
    previewTitle: 'Guardalo in azione',
    previewSubtitle:
      'Breve tour su un server reale: desktop nel browser, app in un clic e modalità Agent IA.',
    previewPlay: 'Riproduci il tour di ServerBox OS',
    previewYoutube: 'Guarda su YouTube',
    featuresTitle: 'Tutto ciò che serve lato server',
    featuresSubtitle: 'Un solo binario sulla macchina, accessibile da qualsiasi browser o dall’app ServerBox.',
    desk: {
      title: 'Desktop nel browser',
      description:
        'Apri l’URL del server per gestire stato, file, terminale, container, processi e servizi in finestre indipendenti.',
    },
    apps: {
      title: 'App Store in un clic',
      description:
        'Distribuisci oltre 40 servizi Docker Compose (Immich, Jellyfin, Gitea, Home Assistant) più Tailscale, reverse proxy e modelli IA locali.',
    },
    storage: {
      title: 'Storage e condivisione NAS',
      description:
        'Partiziona e monta dischi, crea array RAID e pool ZFS, controlla S.M.A.R.T. e condividi cartelle via SMB e NFS.',
    },
    agent: {
      title: 'Modalità Agent autonoma',
      description:
        'Affida un compito all’agente IA: pianifica i passaggi, chiede conferma per i comandi rischiosi, usa sudo solo col tuo permesso e dialoga via MCP.',
    },
    alerts: {
      title: 'Avvisi multicanale',
      description:
        'Regole su CPU, memoria, dischi e servizi con notifiche su app, Telegram, Discord, ntfy, Bark, ServerChan, e-mail o webhook.',
    },
    backups: {
      title: 'Backup cifrati',
      description:
        'Configurazione salvata su WebDAV con cifratura age; volumi dei container salvati automaticamente sul disco scelto.',
    },
    security: {
      title: 'Cifrato e tracciato',
      description:
        'Accesso a singolo account, HTTPS obbligatorio per le modifiche, credenziali cifrate a riposo e audit log completo.',
    },
    app: {
      title: 'Sincronizzazione con l’app',
      description:
        'Aggiungi il server via HTTPS in ServerBox al posto o insieme a SSH per grafici storici, notifiche push, widget e task Agent.',
    },
    installTitle: 'Due modi per iniziare',
    installSubtitle: 'Come servizio sulla tua distribuzione Linux o come immagine OS dedicata.',
    linuxTitle: 'Su un server Linux esistente',
    promptUser: '# systemd: servizio utente con il tuo account',
    promptOpenrc: '# OpenRC (Alpine): registrato da root, eseguito col tuo utente',
    promptRoot: '# systemd o OpenRC: servizio di sistema come root',
    linuxNote:
      'I permessi dipendono dall’account di esecuzione. Sostituisci install con upgrade o uninstall per aggiornare o rimuovere.',
    copy: 'Copia comando',
    imageTitle: 'Come sistema operativo dedicato',
    stepWrite: 'Scrivi l’immagine su chiavetta USB (dd, Etcher, Ventoy) o collegala a una VM.',
    stepBoot:
      'Avvia la macchina: la console mostra l’indirizzo web, l’impronta TLS e dove trovare la prima password.',
    stepInstall: 'Esegui sbm-install <disco> per installare definitivamente su disco.',
    liveNote:
      'Prima dell’installazione su disco, il sistema gira in modalità Live in RAM e si azzera al riavvio.',
    note: 'ServerBox OS è open source con licenza AGPLv3, proprio come l’app.',
    docs: 'Docs Monitor',
    appAction: 'Scarica l’app',
  },
  themes: {
    title: 'Fallo tuo.',
    subtitle:
      'Prova in anteprima i temi ufficiali qui sotto. Installali da Impostazioni → Aspetto → Negozio temi o importa un file .fsbt.',
    empty:
      'Nessun tema ufficiale presente. Consulta la guida per creare e inviare il tuo.',
    note:
      'Ogni pacchetto viene verificato tramite checksum SHA-256 prima dell’installazione.',
    authoring: 'Guida ai temi',
    download: 'Scarica .fsbt',
    source: 'Sorgente',
    light: 'Chiaro',
    dark: 'Scuro',
    search: 'Cerca temi o icone',
    modeLabel: 'Modalità',
    all: 'Tutti',
    sortLabel: 'Ordina',
    sortName: 'Nome',
    sortUpdated: 'Recenti',
    noMatch: 'Nessun tema trovato. Prova un altro termine o modalità.',
    storeTitle: 'Negozio temi',
    storeSubtitle:
      'Esplora tutti i temi e i pacchetti di icone ufficiali renderizzati dal vivo con colori, componenti e icone reali.',
    browse: 'Apri il Negozio temi',
    back: 'Tutti i temi',
    details: 'Dettagli',
    icons: 'Icone',
    tabIcons: 'Schede e stato attivo',
    navIcons: 'Simboli di navigazione',
    palette: 'Palette colori',
    components: 'Componenti',
    splash: 'Schermata iniziale',
    install: 'Installazione',
    installSteps:
      'Nell’app apri Impostazioni → Aspetto → Negozio temi e scegli {name}, oppure scarica il file .fsbt e seleziona Installa tema → File.',
    base: 'Normale',
    hovered: 'Al passaggio',
    pressed: 'Premuto',
    disabled: 'Disattivato',
    loadFailed: 'Impossibile caricare l’anteprima del tema.',
    retry: 'Riprova',
    iconPacks: 'Pacchetti di icone',
    iconPacksSubtitle:
      'Combina liberamente i pacchetti di icone con qualsiasi tema da Impostazioni → Aspetto → Negozio temi → Pacchetti di icone.',
  },
  plugins: {
    title: 'Estendi ServerBox',
    subtitle:
      'Aggiungi nuove funzionalità con i plugin ufficiali.',
    empty: 'Nessun plugin ufficiale disponibile.',
    download: 'Scarica',
  },
  download: {
    title: 'Nativo su ogni piattaforma.',
    subtitle:
      'Scegli il tuo sistema operativo e il canale di distribuzione preferito.',
    copied: 'Comando copiato',
    copyPrompt: 'Copia questo comando:',
    note:
      'Consiglio: abbina ServerBox OS sul server per sbloccare notifiche push, widget e grafici storici.',
  },
  cta: {
    title: 'Gratuito e open source sotto AGPLv3.',
    subtitle:
      'Esplora il codice su GitHub o scarica l’ultima versione per il tuo dispositivo.',
    appStoreAction: 'App Store',
    githubAction: 'GitHub Releases',
  },
  pride: {
    badge: 'LGBTQ+ Friendly',
    title: 'Creato con Orgoglio.',
    description:
      'ServerBox sostiene con orgoglio la comunità LGBTQ+. Il tema ufficiale Pride nello store include le varianti Rainbow, Trans e Nonbinary.',
    rainbow: 'Rainbow',
    trans: 'Trans',
    nonbinary: 'Nonbinary',
  },
  otherApps: {
    title: 'Altri servizi e app.',
    subtitle:
      'Servizi cloud e app native realizzati con la stessa attenzione a velocità, pulizia e praticità.',
    servicesHeading: 'Servizi',
    appsHeading: 'App',
    llmapi: {
      title: 'LLM API',
      description:
        'Gateway API unificato per i principali modelli LLM, pronto per l’agente IA di ServerBox, LLMBox o i tuoi strumenti.',
    },
    uptimer: {
      title: 'Uptimer',
      description:
        'Monitoraggio leggero dell’uptime e pagine di stato per siti web, API e server con avvisi immediati.',
    },
    llmbox: {
      title: 'LLMBox',
      tag: 'iOS · Android · macOS · Linux · Windows',
      description:
        'Client nativo e veloce per le API OpenAI e modelli compatibili, con cronologia locale, tool calling ed endpoint personalizzati.',
      action: 'GitHub',
    },
    mfuse: {
      title: 'MFuse',
      tag: 'macOS · File Provider',
      description:
        'Monta SFTP, S3, WebDAV e storage remoti direttamente nel Finder di macOS tramite il File Provider nativo, senza estensioni del kernel.',
      action: 'mfuse.lollipopkit.com',
    },
  },
  footer: {
    features: 'Funzionalità',
    capabilities: 'Capacità',
    releases: 'Release',
  },
}

export default it
