import type { Translation } from '../i18n-types.js'

const it: Translation = {
  meta: {
    lang: 'it',
    title: 'ServerBox — Stato server, SSH e operazioni in una app Flutter',
    description:
      'ServerBox monitora server Linux, Unix e Windows con grafici, terminale SSH, SFTP, Docker, processi, systemd, S.M.A.R.T, notifiche, widget e watchOS.',
  },
  nav: {
    features: 'Funzioni',
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
      'ServerBox riunisce grafici, terminale SSH, SFTP, Docker, processi, systemd, S.M.A.R.T, notifiche, widget e watchOS in una sola app Flutter.',
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
    title: 'Uno spazio compatto per la manutenzione quotidiana.',
    subtitle:
      'Una superficie operativa focalizzata: ogni blocco corrisponde a un flusso reale di manutenzione.',
    list: {
      title: 'Elenco server',
      description:
        'Stato della connessione e utilizzo di CPU, memoria, disco e rete di ogni server a colpo d’occhio. Filtra per tag o cercali sul globo.',
    },
    charts: {
      title: 'Grafici di stato',
      description:
        'Grafici in tempo reale di CPU, memoria, swap, dischi, I/O dei dischi e rete, oltre a sensori, GPU e batterie. Consulta lo storico o apri una metrica per i dettagli.',
    },
    terminal: {
      title: 'Terminale SSH',
      description:
        'Un terminale completo con tasti virtuali sul telefono, pronto per htop, vim e molto altro. Connettiti direttamente, tramite jump host o con un ProxyCommand.',
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
        "Tutti i processi con CPU e memoria, ordinati come preferisci e ricercabili per nome, utente o PID. Arrestane uno dall'elenco.",
    },
    services: {
      title: 'Servizi systemd',
      description:
        "Prima le unità in errore, poi tutte le altre. Riavvia un'unità o leggi i suoi log con un tocco.",
    },
    users: {
      title: 'Utenti e gruppi',
      description:
        'Visualizza gli account di sistema con shell di login e accesso a sudo evidenziati. Aggiungi o elimina utenti e aggiungi, modifica o elimina gruppi.',
    },
    agent: {
      title: 'Agente IA',
      description:
        "Un assistente nell'app che conosce i tuoi server, con i fornitori di modelli, i server MCP e le skill che scegli.",
    },
    bench: {
      title: 'Benchmark',
      description:
        'Esegui Yet Another Bench Script per misurare disco, rete e CPU di un server e conservarne i risultati. Il menu Altro permette anche di aprire snippet, desktop remoto e virtualizzazione.',
    },
    virt: {
      title: 'Virtualizzazione',
      description:
        'Macchine virtuali e container su libvirt e Proxmox VE: avviali e arrestali, modifica vCPU, memoria e dischi, apri le loro console.',
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
      'ServerBox tiene terminale, trasferimento file, servizi, salute hardware e avvisi nello stesso flusso.',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android, Linux e Windows',
  },
  themes: {
    title: 'A modo tuo.',
    subtitle:
      'I temi ufficiali di ServerBox, gli stessi offerti dal Negozio temi dell’app. Installali da Impostazioni → Aspetto → Negozio temi, oppure scarica un pacchetto e scegli Installa tema → File.',
    empty:
      'Non ci sono ancora temi ufficiali. Un tema è una cartella con un manifest.toml: colori chiari e scuri, stili dei componenti, icone, sfondo e schermata iniziale. La guida spiega come crearne uno e pubblicarlo nel Negozio temi.',
    note:
      'L’app verifica lo SHA-256 di ogni pacchetto del Negozio temi prima di installarlo.',
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
      'Tutti i temi ufficiali di ServerBox, disegnati come li disegna l’app: colori, componenti, icone e schermata iniziale. Installali dal Negozio temi dell’app o scarica il pacchetto.',
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
      'Nell’app apri Impostazioni → Aspetto → Negozio temi e scegli {name}. Oppure scarica il pacchetto e scegli Installa tema → File.',
    base: 'Normale',
    hovered: 'Al passaggio',
    pressed: 'Premuto',
    disabled: 'Disattivato',
    loadFailed: 'Impossibile caricare l’anteprima di questo tema.',
    retry: 'Riprova',
    previewNote:
      'Le anteprime mostrano icone e colori del tema; il resto dell’interfaccia è indicativo.',
    iconPacks: 'Pacchetti di icone',
    iconPacksSubtitle:
      'Icone scelte a parte dal tema e disegnate sopra quello in uso. Installale nell’app da Impostazioni → Aspetto → Negozio dei temi → Pacchetti di icone.',
  },
  plugins: {
    title: 'Plugin.',
    subtitle:
      'I plugin ufficiali di ServerBox, installati dallo store dei plugin dell’app.',
    empty: 'Non ci sono ancora plugin ufficiali.',
    download: 'Scarica',
  },
  download: {
    title: 'Ogni piattaforma, ogni sorgente.',
    subtitle:
      'Scegli una fonte affidabile per il tuo dispositivo. iOS è su App Store, oppure come .ipa non firmato su GitHub Releases da firmare da te. Le versioni macOS per chip Apple e Intel sono su GitHub Releases e Homebrew. Android, Linux e Windows hanno download diretti.',
    copied: 'Comando copiato',
    copyPrompt: 'Copia questo comando:',
    note:
      'Scarica solo da fonti attendibili. Per notifiche server, widget e monitoraggio companion, installa ServerBoxMonitor sui server.',
  },
  cta: {
    title: 'ServerBox è libero e open source sotto AGPLv3.',
    subtitle:
      'Installa da App Store, GitHub Releases, F-Droid o OpenAPK.',
    appStoreAction: 'Apri App Store',
    githubAction: 'Scarica da GitHub Releases',
  },
  footer: {
    features: 'Funzioni',
    capabilities: 'Capacità',
    releases: 'Release',
  },
}

export default it
