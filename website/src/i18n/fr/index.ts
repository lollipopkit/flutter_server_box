import type { Translation } from '../i18n-types.js'

const fr: Translation = {
  meta: {
    lang: 'fr',
    title: 'ServerBox — État des serveurs, SSH et opérations dans une app Flutter',
    description:
      'ServerBox surveille les serveurs Linux, Unix et Windows avec graphiques, terminal SSH, SFTP, Docker, processus, systemd, S.M.A.R.T, notifications, widgets et watchOS.',
  },
  nav: {
    features: 'Fonctions',
    capabilities: 'Capacités',
    download: 'Télécharger',
    docs: 'Docs',
    languageLabel: 'Langue',
  },
  hero: {
    titlePrefix: 'État des serveurs,',
    titleSuffix: 'dans votre poche.',
    subtitle:
      'ServerBox réunit graphiques, terminal SSH, SFTP, Docker, contrôle des processus, systemd, S.M.A.R.T, alertes, widgets et watchOS dans une seule app Flutter.',
    primaryAction: 'Télécharger ServerBox',
    secondaryAction: 'Voir les fonctions',
  },
  screenshots: {
    label: 'Captures interactives de ServerBox',
    one: 'Capture de la vue serveur ServerBox',
    two: 'Capture des graphiques ServerBox',
    three: 'Capture du terminal ServerBox',
    four: 'Capture des outils ServerBox',
  },
  features: {
    title: 'Un espace compact pour la maintenance quotidienne.',
    subtitle:
      'Une surface opérationnelle dense et directe, où chaque bloc correspond à un vrai flux de maintenance.',
    charts: {
      title: 'Graphiques d’état',
      description:
        'Suivez CPU, mémoire, capteurs, GPU, réseau, disque et santé de l’hôte depuis des graphiques mobiles denses.',
    },
    workspace: {
      title: 'Espace multiplateforme',
      description:
        'Utilisez ServerBox sur iOS, Android, macOS, Linux et Windows avec la même interface Flutter familière.',
    },
    terminal: {
      title: 'Terminal SSH et SFTP',
      description:
        'Ouvrez des sessions terminal et fichiers depuis une carte serveur, avec dartssh2 et xterm.dart.',
    },
    native: {
      title: 'Intégrations natives',
      description:
        'Authentification biométrique, notifications, widgets et watchOS gardent le contexte serveur à portée.',
    },
    platforms: {
      title: 'Docker, processus, systemd',
      description:
        'Inspectez conteneurs, processus et services sans quitter le flux de surveillance.',
    },
  },
  capabilities: {
    title: 'Tous les outils. Une seule app.',
    subtitle:
      'ServerBox garde terminal, transfert de fichiers, services, santé matérielle et alertes dans le même flux.',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android, Linux et Windows',
    items: {
      statusChart: 'Graphiques',
      sshTerminal: 'Terminal SSH',
      sftp: 'SFTP',
      docker: 'Docker',
      process: 'Processus',
      systemd: 'Systemd',
      smart: 'S.M.A.R.T',
      gpu: 'GPU',
      sensors: 'Capteurs',
      push: 'Notifications',
      homeWidget: 'Widget',
      watchos: 'watchOS',
    },
  },
  download: {
    title: 'Toutes les plateformes, toutes les sources.',
    subtitle:
      'Choisissez le canal adapté à votre appareil. iOS utilise l’App Store ; macOS utilise l’App Store ou Homebrew ; Android, Linux et Windows ont aussi des paquets directs.',
    copied: 'Commande copiée',
    copyPrompt: 'Copiez cette commande :',
    note:
      'Téléchargez uniquement depuis une source de confiance. Pour les notifications serveur, widgets et surveillance compagnon, installez ServerBoxMonitor sur vos serveurs.',
  },
  cta: {
    title: 'ServerBox est libre et open source sous AGPLv3.',
    subtitle:
      'Installez depuis l’App Store, GitHub Releases, F-Droid, OpenAPK ou le CDN du projet.',
    appStoreAction: 'Ouvrir l’App Store',
    githubAction: 'Télécharger depuis GitHub Releases',
  },
  footer: {
    features: 'Fonctions',
    capabilities: 'Capacités',
    releases: 'Versions',
  },
}

export default fr
