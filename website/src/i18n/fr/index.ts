import type { Translation } from '../i18n-types.js'

const fr: Translation = {
  meta: {
    lang: 'fr',
    title: 'ServerBox — Supervision serveur, SSH et administration en une seule app',
    description:
      'Pilotez vos serveurs Linux, Unix et Windows avec graphiques en direct, terminal SSH tactile, SFTP, Docker, systemd, S.M.A.R.T., widgets et agent IA.',
  },
  nav: {
    features: 'Fonctionnalités',
    capabilities: 'Capacités',
    download: 'Télécharger',
    docs: 'Docs',
    themes: 'Thèmes',
    os: 'ServerBox OS',
    beta: 'Bêta',
    plugins: 'Plugins',
    otherApps: 'Plus',
    signIn: 'Connexion',
    languageLabel: 'Langue',
  },
  hero: {
    titlePrefix: 'Tous vos serveurs,',
    titleSuffix: 'dans votre poche.',
    subtitle:
      'Télémétrie en direct, terminal SSH pensé pour le tactile, SFTP, conteneurs et opérations assistées par IA — réunis dans un espace natif rapide sur mobile et ordinateur.',
    primaryAction: 'Télécharger',
    secondaryAction: 'Explorer',
  },
  screenshots: {
    label: 'Captures interactives de ServerBox',
    one: 'Capture de la vue serveur ServerBox',
    two: 'Capture des graphiques ServerBox',
    three: 'Capture du terminal ServerBox',
    four: 'Capture du navigateur de fichiers ServerBox',
  },
  features: {
    title: 'Taillé pour l’administration réelle.',
    subtitle:
      'Gérez les contrôles quotidiens et les urgences sans ouvrir votre ordinateur portable.',
    list: {
      title: 'Vue d’ensemble',
      description:
        'Visualisez d’un coup d’œil l’état, le CPU, la mémoire, le disque et le réseau de chaque nœud. Filtrez par tag ou localisez vos machines sur le globe 3D.',
    },
    charts: {
      title: 'Télémétrie en direct',
      description:
        'Graphiques temps réel et historiques pour CPU, mémoire, swap, E/S disque, réseau, GPU, capteurs et santé S.M.A.R.T.',
    },
    terminal: {
      title: 'Terminal SSH tactile',
      description:
        'Touches virtuelles dédiées pour maîtriser vim, tmux et htop sur mobile. Prise en charge native des bastions (jump hosts) et de ProxyCommand.',
    },
    files: {
      title: 'Gestionnaire SFTP',
      description:
        'Parcourez, transférez et éditez vos fichiers distants sur place avec aperçu Markdown mis en forme.',
    },
    containers: {
      title: 'Docker & Podman',
      description:
        'Conteneurs groupés par projet Compose avec suivi des ressources, redémarrage en un geste, lecture des logs et shell intégré.',
    },
    processes: {
      title: 'Inspecteur de processus',
      description:
        'Triez par CPU ou mémoire, filtrez par nom, utilisateur ou PID et arrêtez immédiatement les processus en fuite.',
    },
    services: {
      title: 'Services systemd',
      description:
        'Les unités en échec sont automatiquement épinglées en tête de liste pour consulter les logs et relancer le service en un geste.',
    },
    users: {
      title: 'Utilisateurs & groupes',
      description:
        'Vérifiez les comptes système, shells de connexion et droits sudo. Créez ou modifiez utilisateurs et groupes sans mémoriser les options CLI.',
    },
    agent: {
      title: 'Agent IA intégré',
      description:
        'Connectez vos fournisseurs LLM, serveurs MCP et skills pour diagnostiquer les pannes et automatiser la maintenance.',
    },
    bench: {
      title: 'Benchmark en un clic',
      description:
        'Exécutez YABS pour mesurer disque, réseau et CPU, archivez les scores et accédez aux snippets et au bureau à distance.',
    },
    virt: {
      title: 'Virtualisation',
      description:
        'Pilotez vos VM et conteneurs sur Proxmox VE et libvirt : alimentation, vCPU, mémoire, disques et console directe.',
    },
    themes: {
      title: 'Boutique de thèmes',
      description:
        'Appliquez des thèmes officiels (couleurs, icônes, fond et écran d’accueil) depuis l’app ou créez les vôtres.',
    },
  },
  capabilities: {
    title: 'Un seul flux de travail natif.',
    subtitle:
      'Fini le jonglage entre clients SSH, outils SFTP et tableaux de bord de monitoring.',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android, Linux et Windows',
  },
  os: {
    metaTitle: 'ServerBox OS (ancien ServerBox Monitor) — Le compagnon serveur de ServerBox',
    metaDescription:
      'ServerBox OS (ancien ServerBox Monitor) apporte un bureau web, plus de 40 apps Docker en un clic, la gestion ZFS/RAID, un mode Agent IA, des alertes et des sauvegardes chiffrées.',
    heroTitle: 'ServerBox OS',
    formerlyMonitor: 'Ancien ServerBox Monitor',
    navPreview: 'Démo',
    navInstall: 'Installer',
    navApp: 'App ServerBox',
    tagline: 'Votre serveur, dans le navigateur comme dans l’app.',
    subtitle:
      'Un démon léger qui dote n’importe quel serveur Linux d’un bureau complet dans le navigateur, de 40+ apps auto-hébergées et d’une synchronisation HTTPS instantanée avec ServerBox — ou démarre comme OS dédié.',
    monitorNote:
      'ServerBox OS est la nouvelle génération de ServerBox Monitor (server_box_monitor). Les installations Monitor existantes se mettent à jour sur place avec la même commande et continuent d’alimenter les alertes push, widgets, watchOS et graphiques historiques de l’app.',
    exploreAction: 'Découvrir ServerBox OS',
    installAction: 'Installer sur Linux',
    images: 'Télécharger les images',
    previewAction: 'Voir la démo',
    previewTitle: 'En fonctionnement',
    previewSubtitle:
      'Aperçu en conditions réelles : bureau multifenêtre dans le navigateur, catalogue d’apps et mode Agent IA.',
    previewPlay: 'Lire la démo de ServerBox OS',
    previewYoutube: 'Voir sur YouTube',
    featuresTitle: 'Tout côté serveur',
    featuresSubtitle: 'Un seul binaire sur la machine, accessible depuis un navigateur ou l’app mobile.',
    desk: {
      title: 'Bureau dans le navigateur',
      description:
        'Ouvrez l’adresse du serveur pour retrouver métriques, fichiers, terminal, conteneurs, processus et services dans des fenêtres dédiées.',
    },
    apps: {
      title: 'Boutique d’apps en un clic',
      description:
        'Déployez plus de 40 services via Docker Compose (Immich, Jellyfin, Gitea, Home Assistant) ainsi que Tailscale, des reverse proxies et des LLM locaux.',
    },
    storage: {
      title: 'Stockage & partage NAS',
      description:
        'Partitionnez et montez vos disques, créez des grappes RAID et pools ZFS, suivez le S.M.A.R.T. et partagez en SMB et NFS.',
    },
    agent: {
      title: 'Mode Agent autonome',
      description:
        'Confiez une mission à l’IA : elle planifie, demande confirmation avant toute commande sensible, encadre sudo et dialogue via MCP.',
    },
    alerts: {
      title: 'Alertes multicanales',
      description:
        'Règles sur CPU, mémoire, disques et services notifiées vers l’app, Telegram, Discord, ntfy, Bark, ServerChan, e-mail ou webhook.',
    },
    backups: {
      title: 'Sauvegardes chiffrées',
      description:
        'Configuration sauvegardée sur WebDAV avec chiffrement age ; volumes de conteneurs sauvegardés automatiquement sur le disque choisi.',
    },
    security: {
      title: 'Chiffré & audité',
      description:
        'Compte unique, HTTPS obligatoire pour toute modification, identifiants chiffrés au repos et journal d’audit complet.',
    },
    app: {
      title: 'Synchronisation native',
      description:
        'Ajoutez le serveur en HTTPS dans ServerBox en complément ou à la place de SSH : historique, alertes push, widgets et tâches Agent.',
    },
    installTitle: 'Deux modes de déploiement',
    installSubtitle: 'En service sur une distribution Linux existante, ou comme système complet sur machine dédiée.',
    linuxTitle: 'Sur un serveur Linux existant',
    promptUser: '# systemd : service utilisateur sous votre propre compte',
    promptOpenrc: '# OpenRC (Alpine) : enregistré par root, exécuté sous votre compte',
    promptRoot: '# systemd ou OpenRC : service système global en root',
    linuxNote:
      'Les droits correspondent au compte d’exécution. Remplacez install par upgrade ou uninstall à tout moment.',
    copy: 'Copier la commande',
    imageTitle: 'En système d’exploitation complet',
    stepWrite: 'Flashez une image sur clé USB (dd, Etcher, Ventoy) ou montez-la dans une VM.',
    stepBoot:
      'Démarrez : la console affiche l’URL web, l’empreinte TLS et l’emplacement du mot de passe initial.',
    stepInstall: 'Exécutez sbm-install <disque> pour installer définitivement le système.',
    liveNote:
      'Avant l’installation sur disque, sbOS tourne en mémoire vive (mode Live) et se réinitialise au redémarrage.',
    note: 'ServerBox OS est libre et open source sous licence AGPLv3.',
    docs: 'Docs Monitor',
    appAction: 'Obtenir l’app',
  },
  themes: {
    title: 'À votre image.',
    subtitle:
      'Prévisualisez les thèmes officiels en direct. Installez-les depuis Réglages → Apparence → Boutique de thèmes ou importez un fichier .fsbt.',
    empty:
      'Aucun thème officiel pour le moment. Consultez le guide pour créer et proposer le vôtre.',
    note:
      'Chaque paquet est vérifié par somme SHA-256 avant son installation.',
    authoring: 'Guide de création',
    download: 'Télécharger .fsbt',
    source: 'Source',
    light: 'Clair',
    dark: 'Sombre',
    search: 'Rechercher un thème ou pack',
    modeLabel: 'Mode',
    all: 'Tous',
    sortLabel: 'Trier',
    sortName: 'Nom',
    sortUpdated: 'Récents',
    noMatch: 'Aucun thème trouvé. Essayez un autre terme ou mode.',
    storeTitle: 'Boutique de thèmes',
    storeSubtitle:
      'Explorez tous les thèmes et packs d’icônes officiels rendus en direct avec leurs vraies couleurs et composants.',
    browse: 'Parcourir la boutique',
    back: 'Tous les thèmes',
    details: 'Détails',
    icons: 'Icônes',
    tabIcons: 'Onglets & état actif',
    navIcons: 'Symboles de navigation',
    palette: 'Palette de couleurs',
    components: 'Composants',
    splash: 'Écran de démarrage',
    install: 'Installation',
    installSteps:
      'Dans l’app, ouvrez « Réglages → Apparence → Boutique de thèmes » et choisissez {name}, ou importez le fichier .fsbt.',
    base: 'Normal',
    hovered: 'Survolé',
    pressed: 'Pressé',
    disabled: 'Désactivé',
    loadFailed: 'Impossible de charger l’aperçu du thème.',
    retry: 'Réessayer',
    iconPacks: 'Packs d’icônes',
    iconPacksSubtitle:
      'Combinez librement les packs d’icônes avec n’importe quel thème depuis « Réglages → Apparence → Boutique de thèmes → Packs d’icônes ».',
  },
  plugins: {
    title: 'Étendez ServerBox',
    subtitle:
      'Ajoutez de nouvelles capacités avec les plugins officiels.',
    empty: 'Aucun plugin officiel pour le moment.',
    download: 'Télécharger',
  },
  download: {
    title: 'Natif sur chaque plateforme.',
    subtitle:
      'Choisissez votre système et votre canal de distribution ci-dessous.',
    copied: 'Commande copiée',
    copyPrompt: 'Copiez cette commande :',
    note:
      'Astuce : associez ServerBox OS côté serveur pour activer les notifications push, les widgets et l’historique hors connexion SSH.',
  },
  cta: {
    title: 'Libre et open source sous AGPLv3.',
    subtitle:
      'Explorez le code sur GitHub ou téléchargez la dernière version pour votre appareil.',
    appStoreAction: 'App Store',
    githubAction: 'GitHub Releases',
  },
  pride: {
    badge: 'LGBTQ+ Friendly',
    title: 'Conçu avec Fierté.',
    description:
      'ServerBox soutient fièrement la communauté LGBTQ+. Le thème officiel Pride de la boutique inclut les variantes Rainbow, Trans et Nonbinary.',
    rainbow: 'Rainbow',
    trans: 'Trans',
    nonbinary: 'Nonbinary',
  },
  otherApps: {
    title: 'Plus de services et d’apps.',
    subtitle:
      'Services cloud et applications natives conçus avec la même exigence de rapidité et de sobriété.',
    servicesHeading: 'Services',
    appsHeading: 'Apps',
    llmapi: {
      title: 'LLM API',
      description:
        'Passerelle API unifiée pour les principaux LLM, prête pour l’agent IA de ServerBox, GPT Box ou vos propres outils.',
    },
    uptimer: {
      title: 'Uptimer',
      description:
        'Supervision légère de disponibilité et pages de statut pour vos sites, API et serveurs avec alertes instantanées.',
    },
    gptbox: {
      title: 'GPT Box',
      tag: 'iOS · Android · macOS · Linux · Windows',
      description:
        'Client natif rapide pour l’API OpenAI et les modèles compatibles, avec historique local, appels d’outils et points de terminaison personnalisés.',
      action: 'GitHub',
    },
    mfuse: {
      title: 'MFuse',
      tag: 'macOS · File Provider',
      description:
        'Montez SFTP, S3, WebDAV et vos stockages distants directement dans le Finder macOS via File Provider natif, sans extension noyau.',
      action: 'mfuse.lollipopkit.com',
    },
  },
  footer: {
    features: 'Fonctionnalités',
    capabilities: 'Capacités',
    releases: 'Versions',
  },
}

export default fr
