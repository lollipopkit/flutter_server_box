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
      'Installa da App Store, GitHub Releases, F-Droid, OpenAPK o dal CDN del progetto.',
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
