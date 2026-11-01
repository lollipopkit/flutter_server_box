import type { Translation } from '../i18n-types.js'

const it: Translation = {
  meta: {
    lang: 'it',
    title: 'ServerBox — Monitoraggio dei server, SSH e strumenti di amministrazione',
    description:
      'ServerBox offre grafici di stato, terminale SSH, SFTP, Docker, gestione dei processi e di systemd, monitoraggio S.M.A.R.T., notifiche push, widget e supporto a watchOS per amministrare server Linux, Unix e Windows.',
  },
  nav: {
    features: 'Funzionalità',
    capabilities: 'Capacità',
    download: 'Scarica',
    docs: 'Documenti',
    themes: 'Temi',
    plugins: 'Plugin',
    languageLabel: 'Lingua',
  },
  hero: {
    titlePrefix: 'Stato server,',
    titleSuffix: 'in tasca.',
    subtitle:
      'Scarica l’app dall’App Store, da GitHub Releases, F-Droid o OpenAPK.',
    primaryAction: 'Scarica ServerBox',
    secondaryAction: 'Scopri le funzionalità',
  },
  screenshots: {
    label: 'Screenshot interattivi di ServerBox',
    one: 'Screenshot panoramica server ServerBox',
    two: 'Screenshot grafici ServerBox',
    three: 'Screenshot terminale ServerBox',
    four: 'Screenshot del browser file di ServerBox',
  },
  features: {
    title: 'Gli strumenti per la manutenzione quotidiana dei server, in un unico spazio.',
    subtitle:
      'Funzionalità essenziali e pratiche: ogni sezione risponde a un’esigenza concreta di gestione dei server.',
    list: {
      title: 'Elenco server',
      description:
        'Controlla lo stato della connessione e l’utilizzo di CPU, memoria, disco e rete di ogni server. Filtra per tag o visualizzali sul globo.',
    },
    charts: {
      title: 'Grafici di stato',
      description:
        'Consulta in tempo reale i grafici di CPU, memoria, swap, dischi, I/O e rete, oltre ai dati di sensori, GPU e batteria. Passa ai dati storici o seleziona una metrica per maggiori dettagli.',
    },
    terminal: {
      title: 'Terminale SSH',
      description:
        'Un terminale completo, con tasti virtuali sui telefoni, per usare programmi come htop e vim. Supporta connessioni dirette, tramite jump host e con ProxyCommand.',
    },
    files: {
      title: 'File via SFTP',
      description:
        'Sfoglia, carica, scarica e modifica i file sul posto. I file Markdown si aprono con un’anteprima formattata.',
    },
    containers: {
      title: 'Docker e Podman',
      description:
        'Visualizza i container raggruppati per progetto Compose e il loro utilizzo di CPU, memoria e rete. Avviali, arrestali, riavviali o rimuovili; consulta i log o apri una shell al loro interno. Immagini e impostazioni hanno schede dedicate.',
    },
    processes: {
      title: 'Processi',
      description:
        'Visualizza i processi e il relativo utilizzo di CPU e memoria. Ordinali come preferisci, cercali per nome, utente o PID e termina un processo direttamente dall’elenco.',
    },
    services: {
      title: 'Servizi systemd',
      description:
        'Le unità systemd in errore compaiono in cima all’elenco. Riavvia un’unità o consultane i log con un tocco.',
    },
    users: {
      title: 'Utenti e gruppi',
      description:
        'Visualizza gli account di sistema e i relativi login shell e permessi sudo. Aggiungi o elimina utenti e aggiungi, modifica o elimina gruppi.',
    },
    agent: {
      title: 'Agente IA',
      description:
        'Usa l’assistente integrato nell’app per gestire i server, collegandolo al provider di modelli, ai server MCP e alle skill che preferisci.',
    },
    bench: {
      title: 'Benchmark',
      description:
        'Esegui Yet Another Bench Script per misurare disco, rete e CPU del server e salvare i risultati. Dal menu Altro puoi accedere anche a snippet, desktop remoto e virtualizzazione.',
    },
    virt: {
      title: 'Virtualizzazione',
      description:
        'Gestisci VM e container su libvirt e Proxmox VE: avviali o arrestali, modifica vCPU, memoria e dischi e apri le console.',
    },
    themes: {
      title: 'Store dei temi',
      description:
        "Temi ufficiali con colori, sfondi e schermate di avvio propri, installati dall'app. Puoi anche crearne uno tuo.",
    },
  },
  capabilities: {
    title: 'Tutti gli strumenti. Una sola app.',
    subtitle:
      'ServerBox riunisce connessioni al terminale, trasferimenti di file, controlli dei servizi, monitoraggio hardware e notifiche native in un unico flusso di lavoro.',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android, Linux e Windows',
  },
  themes: {
    title: 'A modo tuo.',
    subtitle:
      'I temi ufficiali mostrati qui sono disponibili anche nel Negozio temi dell’app. Installali da Impostazioni → Aspetto → Negozio temi oppure scarica un pacchetto e seleziona Installa tema → File.',
    empty:
      'Non ci sono ancora temi ufficiali. Ogni tema è una cartella con un manifest.toml, che contiene palette chiare e scure, stili dei componenti, icone, sfondo e schermata iniziale. La guida spiega come creare un tema e inviarlo al Negozio temi.',
    note:
      'L’app verifica il checksum SHA-256 di ogni pacchetto del negozio prima di installarlo.',
    authoring: 'Crea un tema',
    download: 'Scarica .fsbt',
    source: 'Sorgente',
    light: 'Chiaro',
    dark: 'Scuro',
    search: 'Cerca temi',
    modeLabel: 'Modalità',
    all: 'Tutti',
    sortLabel: 'Ordina',
    sortName: 'Nome',
    sortUpdated: 'Aggiornati di recente',
    noMatch: 'Nessun tema corrisponde. Prova un altro nome o un’altra modalità.',
    storeTitle: 'Negozio temi',
    storeSubtitle:
      'Tutti i temi ufficiali di ServerBox, visualizzati come nell’app: colori, componenti, icone e schermata iniziale. Installali dal Negozio temi dell’app o scarica il pacchetto.',
    browse: 'Apri il Negozio temi',
    back: 'Tutti i temi',
    details: 'Dettagli',
    icons: 'Icone',
    tabIcons: 'Schede e stato selezionato',
    navIcons: 'Simboli',
    palette: 'Palette',
    components: 'Componenti',
    splash: 'Schermata iniziale',
    install: 'Installa',
    installSteps:
      'Nell’app, apri Impostazioni → Aspetto → Negozio temi e seleziona {name}. In alternativa, scarica il pacchetto e scegli Installa tema → File.',
    base: 'Normale',
    hovered: 'Al passaggio',
    pressed: 'Premuto',
    disabled: 'Disattivato',
    loadFailed: 'Impossibile caricare l’anteprima di questo tema.',
    retry: 'Riprova',
    previewNote:
      'Le anteprime mostrano le icone e i colori del tema; il resto dell’interfaccia è solo a scopo illustrativo.',
    iconPacks: 'Pacchetti di icone',
    iconPacksSubtitle:
      'Pacchetti di icone indipendenti dal tema, utilizzabili con quello attivo. Installali nell’app da Impostazioni → Aspetto → Negozio temi → Pacchetti di icone.',
  },
  plugins: {
    title: 'Estendi ServerBox',
    subtitle:
      'Installa i plugin ufficiali di ServerBox per aggiungere altre funzionalità all’app.',
    empty: 'Non ci sono ancora plugin ufficiali.',
    download: 'Scarica',
  },
  download: {
    title: 'Più piattaforme, più opzioni di download.',
    subtitle:
      'Scegli un canale di download affidabile. La versione iOS è disponibile sull’App Store oppure come file .ipa non firmato su GitHub Releases, da firmare autonomamente. Le versioni macOS per chip Apple e Intel sono disponibili su GitHub Releases e Homebrew. Per Android, Linux e Windows sono disponibili pacchetti scaricabili direttamente.',
    copied: 'Comando copiato',
    copyPrompt: 'Copia questo comando:',
    note:
      'Scarica i pacchetti solo da fonti attendibili. Per le notifiche lato server, i dati dei widget e il monitoraggio autonomo, installa ServerBox Monitor sui server.',
  },
  cta: {
    title: 'ServerBox è gratuito e open source, distribuito con licenza AGPLv3.',
    subtitle:
      'Scarica l’app dall’App Store, da GitHub Releases, F-Droid o OpenAPK.',
    appStoreAction: 'Apri App Store',
    githubAction: 'Scarica da GitHub Releases',
  },
  footer: {
    features: 'Funzionalità',
    capabilities: 'Capacità',
    releases: 'Release',
  },
}

export default it
