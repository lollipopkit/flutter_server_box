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
      'Installa da App Store, GitHub Releases, F-Droid, OpenAPK o dal CDN del progetto.',
    appStoreAction: 'Apri App Store',
    githubAction: 'Scarica da GitHub Releases',
  },
  plugins: {
    metaTitle: 'Plugin ServerBox — estendi l’app senza aspettare una release',
    metaDescription:
      'I plugin aggiungono a ServerBox pagine, schede e letture di stato. Ognuno è un piccolo modulo isolato che dichiara i permessi che gli servono, e l’app verifica ogni pacchetto che scarica.',
    title: 'Estendi l’app senza aspettare una release.',
    subtitle:
      'Un plugin aggiunge una pagina, una scheda, una tab in home o letture di stato in più. È un modulo piccolo, gira in una sandbox e può fare solo quello che il suo manifest ha chiesto e tu hai accettato.',
    how: {
      sandbox: {
        title: 'Gira in una sandbox',
        description:
          'Un plugin è JavaScript in un runtime isolato: nessun file system, nessuna rete, nessuna connessione ai server tutta sua. Tutto quello che fa, lo chiede all’app.',
      },
      permissions: {
        title: 'Chiede prima di agire',
        description:
          'Il manifest dichiara cosa gli serve — eseguire un comando, raggiungere un host, vedere l’elenco dei tuoi server — ed è quella lista che accetti all’installazione. Una chiamata non concessa fallisce subito.',
      },
      anyRepo: {
        title: 'Qualsiasi repository, byte verificati',
        description:
          'L’app installa da qualunque indirizzo di repository in HTTPS — una richiesta per il suo albero più recente — e verifica ogni pacchetto con il checksum dichiarato dal suo file. Un pacchetto senza checksum viene rifiutato, salvo consenso esplicito.',
      },
    },
    listTitle: 'Nel repository ufficiale',
    listSubtitle:
      '{count} plugin, sviluppati in questo repository e pubblicati separatamente dall’app.',
    asks: 'Chiede',
    asksNothing: 'niente',
    appearsIn: 'Compare in',
    languages: 'Lingue',
    source: 'Sorgente',
    install: {
      title: 'Installarne uno',
      stepOne: 'Nell’app apri Impostazioni → Plugin → Store dei plugin.',
      stepTwo:
        'Scegli un plugin e premi Installa. Il repository ufficiale è già in elenco.',
      stepThree:
        'Leggi cosa chiede e accetta. Prima di eseguire qualsiasi cosa l’app verifica il download con il checksum del repository.',
      address: 'L’indirizzo del repository, se l’hai rimosso e lo vuoi rimettere:',
      copy: 'Copia indirizzo',
    },
    write: {
      title: 'Scriverne uno',
      description:
        'Un plugin è un singolo modulo ES in TypeScript o JavaScript, testato contro un host finto con bun test — senza app e senza build. Su desktop puoi puntare l’app alla sua cartella: modificare e riavviare è tutto il ciclo.',
      sdk: 'SDK',
      examples: 'Plugin di esempio',
      repository: 'Repository ufficiale',
    },
    home: 'Home',
  },
  footer: {
    features: 'Funzioni',
    capabilities: 'Capacità',
    releases: 'Release',
  },
}

export default it
