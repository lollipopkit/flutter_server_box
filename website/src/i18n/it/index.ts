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
    four: 'Screenshot strumenti ServerBox',
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
    items: {
      statusChart: 'Grafici',
      sshTerminal: 'Terminale SSH',
      sftp: 'SFTP',
      docker: 'Docker',
      process: 'Processi',
      systemd: 'Systemd',
      smart: 'S.M.A.R.T',
      gpu: 'GPU',
      sensors: 'Sensori',
      push: 'Notifiche',
      homeWidget: 'Widget',
      watchos: 'watchOS',
    },
  },
  download: {
    title: 'Ogni piattaforma, ogni sorgente.',
    subtitle:
      'Scegli il canale adatto al dispositivo. iOS usa App Store; macOS usa App Store o Homebrew; Android, Linux e Windows hanno pacchetti diretti.',
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
