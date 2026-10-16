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
    monitor: 'Monitor',
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
  gallery: {
    title: 'Ogni schermata, su ogni dispositivo.',
    subtitle:
      '31 screenshot su iPhone, iPad e macOS, richiusi per mantenere leggera la pagina finché non li apri.',
    count: '{count} screenshot',
  },
  features: {
    title: 'Uno spazio compatto per la manutenzione quotidiana.',
    subtitle:
      'Una superficie operativa focalizzata: ogni blocco corrisponde a un flusso reale di manutenzione.',
    charts: {
      title: 'Grafici di stato',
      description:
        'Controlla CPU, memoria, sensori, GPU, rete, disco e salute host da grafici mobili densi.',
    },
    workspace: {
      title: 'Spazio multipiattaforma',
      description:
        'Usa ServerBox su iOS, Android, macOS, Linux e Windows con la stessa interfaccia Flutter.',
    },
    terminal: {
      title: 'Terminale SSH e SFTP',
      description:
        'Apri sessioni terminale e file da una scheda server, con dartssh2 e xterm.dart.',
    },
    native: {
      title: 'Integrazioni native',
      description:
        'Autenticazione biometrica, notifiche, widget e watchOS mantengono vicino il contesto server.',
    },
    platforms: {
      title: 'Docker, processi, systemd',
      description:
        'Ispeziona container, processi e servizi senza uscire dal flusso di monitoraggio.',
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
      'Scegli una fonte affidabile per il tuo dispositivo. Su iOS, l’app è disponibile su App Store. Su macOS, la versione di App Store supporta solo i Mac con chip Apple; chi usa un Mac Intel può installarla da GitHub Releases o Homebrew. Sono disponibili anche download diretti per Android, Linux e Windows.',
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
  monitor: {
    meta: {
      title: 'ServerBox Monitor — l’agente che tiene d’occhio il tuo server',
      description: 'ServerBox Monitor gira sul tuo server: registra lo storico dello stato, invia avvisi al telefono, tiene aggiornati i widget e l’app Watch e offre un pannello web.',
    },
    nav: {
      why: 'Perché un agente',
      panel: 'Pannello web',
      alerts: 'Avvisi',
      access: 'Accesso',
      install: 'Installa',
    },
    hero: {
      eyebrow: 'ServerBox Monitor',
      title: 'Un campione ogni 7 secondi. Lo conserva. Lo dice al tuo telefono.',
      subtitle: 'Un piccolo agente in Rust che gira sul tuo server. Conserva lo storico in SQLite, invia avvisi, tiene aggiornati i widget di ServerBox e l’app Watch e offre un pannello web — e l’app lo raggiunge senza SSH.',
      installLabel: 'Installa su Linux con systemd o OpenRC',
      installNote: 'Gira con il tuo account, non come root.',
      copy: 'Copia',
      copied: 'Copiato',
      guide: 'Guida all’installazione',
      terminalLabel: 'L’agente in installazione, poi i suoi campionamenti',
      installed: 'installato come servizio systemctl --user',
      listening: 'in ascolto su 0.0.0.0:3770',
      sampled: 'campionato',
      cadence: 'ogni 7 s — interval_seconds, per impostazione predefinita',
      pushLabel: 'Avvisi dell’agente sulla schermata di blocco di un iPhone',
      widgetLabel: 'Un widget di ServerBox alimentato dall’agente',
    },
    keywords: {
      history: 'Storico SQLite',
      push: 'Avvisi push',
      panel: 'Pannello web',
      roles: 'Ruoli e permessi',
      docker: 'Docker',
    },
    why: {
      title: 'Cosa aggiunge l’agente a SSH',
      subtitle: 'Per guardare un server basta SSH. L’agente continua a guardare quando tu non lo fai.',
      history: {
        title: 'Lo storico di prima che aprissi l’app',
        description: 'L’agente campiona da solo e conserva i risultati, così i grafici mostrano anche la notte in cui dormivi. Quanto a lungo conservarli lo decidi tu.',
      },
      alerts: {
        title: 'Avvisi sul telefono',
        description: 'Regole su CPU, memoria, swap, disco, rete e temperatura, inviate a iOS, Bark, ServerChan o a qualsiasi webhook.',
      },
      widgets: {
        title: 'Widget e Watch sempre aggiornati',
        description: 'I widget e l’app Watch leggono dall’agente, quindi si aggiornano anche con ServerBox chiuso.',
      },
      reach: {
        title: 'Nessun SSH da aprire',
        description: 'L’app parla con l’agente via HTTP. Usalo dove SSH non è raggiungibile, oppure insieme a SSH sullo stesso server.',
      },
    },
    panel: {
      title: 'Un pannello web su ogni agente',
      subtitle: 'Ogni agente offre il proprio pannello sulla porta 3770. Oppure pubblica il pannello una volta sola e accedi a più agenti dalla stessa pagina.',
      dashboard: {
        title: 'Grafici in tempo reale e storico conservato',
        description: 'CPU, memoria, dischi, rete, GPU e sensori, in tempo reale e su tutto ciò che l’agente ha conservato — con accanto l’output dei tuoi comandi.',
      },
      terminal: {
        title: 'Terminale e file nel browser',
        description: 'Un terminale che continua a girare quando chiudi la scheda e riprende da dove era, e un esploratore limitato alle cartelle che indichi.',
      },
      machine: {
        title: 'Le parti della macchina che si muovono',
        description: 'Container Docker o Podman, servizi, processi, cron, firewall e utenti di sistema. L’agente costruisce e verifica ogni azione; il pannello si limita a chiedere.',
      },
      reach: {
        title: 'Ciò che sta accanto al server',
        description: 'Desktop RDP e VNC, BMC via Redfish e macchine virtuali su Proxmox VE o libvirt, raggiunti tramite l’agente.',
      },
    },
    alerts: {
      title: 'Avvisi dove guardi già',
      subtitle: 'Una regola è una metrica e una soglia. Quando scatta, ogni canale configurato viene avvisato.',
      rule: 'Una regola di config.toml',
      push: 'Notifica iOS',
      webhook: 'Un webhook verso un’app di chat',
      widget: 'Widget della schermata Home',
    },
    access: {
      title: 'Decidi tu cosa può fare ogni account',
      subtitle: 'Leggere lo stato è aperto a tutti gli account. Il resto si concede, e si può revocare.',
      roles: {
        title: 'Ruoli e permessi',
        description: 'Shell, file, inoltro delle porte e virtualizzazione sono permessi che un admin concede a un ruolo. Revocane uno e ciò che lo usava si chiude.',
      },
      transport: {
        title: 'TLS per tutto ciò che va oltre la lettura',
        description: 'Comandi, file e inoltri richiedono TLS o una richiesta dalla stessa macchina. TLS integrato, reverse proxy o tunnel vanno tutti bene.',
      },
      account: {
        title: 'Gira con il tuo account',
        description: 'L’installer avvia l’agente con il tuo account, quindi la shell che fornisce è quella di quell’account, non di root.',
      },
      audit: {
        title: 'Ogni accesso registrato',
        description: 'Chi, quando, da dove, cosa e con quale esito. Mai password o chiavi.',
      },
    },
    install: {
      title: 'Installa',
      subtitle: 'Tre passaggi da un server nuovo al suo stato sul tuo telefono.',
      step1: {
        title: 'Installa l’agente',
        description: 'L’installer sceglie systemd o OpenRC e scarica l’ultima versione. Aggiungi --permissions read per partire con un admin senza permessi.',
      },
      step2: {
        title: 'Accedi',
        description: 'Al primo avvio viene creato l’account admin con una password casuale, salvata accanto al database in initial-admin-credentials.txt. Cambiala, poi elimina il file:',
      },
      step3: {
        title: 'Aggiungilo a ServerBox',
        description: 'Nell’app, aggiungi il server come agente Monitor con indirizzo e account. Oppure apri il pannello sulla porta 3770.',
      },
      tabs: {
        systemd: 'systemd',
        openrc: 'OpenRC (Alpine)',
        docker: 'Docker',
      },
      dockerNote: 'Compilato da questo repository.',
    },
    cta: {
      title: 'Gratuito e open source, come l’app.',
      subtitle: 'L’agente vive nel repository di ServerBox, con la stessa licenza.',
      app: 'Scarica ServerBox',
      source: 'Sorgente dell’agente',
    },
  },
}

export default it
