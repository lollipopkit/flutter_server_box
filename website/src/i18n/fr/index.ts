import type { Translation } from '../i18n-types.js'

const fr: Translation = {
  meta: {
    lang: 'fr',
    title: 'ServerBox — Supervision des serveurs, SSH et administration',
    description:
      'ServerBox propose des graphiques d’état, un terminal SSH, SFTP, Docker, la gestion des processus et de systemd, la supervision S.M.A.R.T., les notifications push, des widgets et la prise en charge de watchOS pour les serveurs Linux, Unix et Windows.',
  },
  nav: {
    features: 'Fonctionnalités',
    capabilities: 'Capacités',
    download: 'Télécharger',
    docs: 'Documentation',
    themes: 'Thèmes',
    plugins: 'Plugins',
    languageLabel: 'Langue',
  },
  hero: {
    titlePrefix: 'État des serveurs,',
    titleSuffix: 'dans votre poche.',
    subtitle:
      'ServerBox réunit les graphiques d’état, un terminal SSH, SFTP, Docker, la gestion des processus, systemd, la supervision S.M.A.R.T., les notifications push, des widgets et la prise en charge de watchOS dans une seule app.',
    primaryAction: 'Télécharger ServerBox',
    secondaryAction: 'Découvrir les fonctionnalités',
  },
  screenshots: {
    label: 'Captures interactives de ServerBox',
    one: 'Capture de la vue serveur ServerBox',
    two: 'Capture des graphiques ServerBox',
    three: 'Capture du terminal ServerBox',
    four: 'Capture du navigateur de fichiers ServerBox',
  },
  features: {
    title: 'Tous les outils nécessaires à la maintenance quotidienne des serveurs, réunis au même endroit.',
    subtitle:
      'Des outils pratiques et ciblés : chaque section répond à un besoin concret de maintenance des serveurs.',
    list: {
      title: 'Liste des serveurs',
      description:
        "Consultez d'un coup d'œil l'état de connexion et l'utilisation du CPU, de la mémoire, du disque et du réseau de chaque serveur. Filtrez par étiquette ou repérez-les sur le globe.",
    },
    charts: {
      title: "Graphiques d'état",
      description:
        'Consultez en temps réel les graphiques du CPU, de la mémoire, du swap, des disques, des E/S disque et du réseau, ainsi que les données des capteurs, du GPU et de la batterie. Vous pouvez aussi consulter l’historique ou sélectionner une mesure pour en voir les détails.',
    },
    terminal: {
      title: 'Terminal SSH',
      description:
        'Un terminal complet avec des touches virtuelles sur mobile, pour utiliser htop, vim et bien plus. Connectez-vous directement, via un hôte intermédiaire ou avec ProxyCommand.',
    },
    files: {
      title: 'Fichiers via SFTP',
      description:
        "Parcourez, envoyez, téléchargez et modifiez les fichiers sur place. Les fichiers Markdown s'ouvrent dans un aperçu mis en forme.",
    },
    containers: {
      title: 'Docker et Podman',
      description:
        'Consultez les conteneurs regroupés par projet Compose et leur utilisation du CPU, de la mémoire et du réseau. Démarrez-les, arrêtez-les, redémarrez-les ou supprimez-les ; consultez leurs logs ou ouvrez-y un shell. Les images et les réglages ont leurs propres onglets.',
    },
    processes: {
      title: 'Processus',
      description:
        'Consultez tous les processus et leur utilisation du CPU et de la mémoire. Triez-les, recherchez-les par nom, utilisateur ou PID, puis arrêtez-les directement depuis la liste.',
    },
    services: {
      title: 'Services systemd',
      description:
        'Les unités systemd en échec apparaissent en haut de la liste. Redémarrez une unité ou consultez ses logs en un geste.',
    },
    users: {
      title: 'Utilisateurs et groupes',
      description:
        'Consultez les comptes système, leur shell de connexion et leurs droits sudo. Ajoutez ou supprimez des utilisateurs, et ajoutez, modifiez ou supprimez des groupes.',
    },
    agent: {
      title: 'Agent IA',
      description:
        'Utilisez l’assistant intégré à l’app pour gérer vos serveurs et connectez-le aux fournisseurs de modèles, serveurs MCP et skills de votre choix.',
    },
    bench: {
      title: 'Benchmark',
      description:
        'Lancez Yet Another Bench Script pour tester le disque, le réseau et le CPU d’un serveur, puis enregistrer les résultats. Le menu Plus donne aussi accès aux snippets, au bureau à distance et à la virtualisation.',
    },
    virt: {
      title: 'Virtualisation',
      description:
        'Gérez les machines virtuelles et les conteneurs sur libvirt et Proxmox VE. Démarrez ou arrêtez les instances, ajustez les vCPU, la mémoire et les disques, et ouvrez leurs consoles.',
    },
    themes: {
      title: 'Boutique de thèmes',
      description:
        "Des thèmes officiels avec leurs couleurs, fonds et écrans de démarrage, installés depuis l'app. Vous pouvez aussi créer le vôtre.",
    },
  },
  capabilities: {
    title: 'Tous les outils. Une seule app.',
    subtitle:
      'ServerBox réunit les connexions terminal, le transfert de fichiers, l’état des services, la supervision matérielle et les notifications natives dans un même flux de travail.',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android, Linux et Windows',
  },
  themes: {
    title: 'À votre image.',
    subtitle:
      'Les thèmes officiels présentés ici sont également disponibles dans la boutique de thèmes de l’app. Installez-les depuis Réglages → Apparence → Boutique de thèmes, ou téléchargez un paquet puis choisissez Installer un thème → Fichier.',
    empty:
      'Pas encore de thème officiel. Chaque thème est un dossier contenant un manifest.toml, des palettes claires et sombres, des styles de composants, des icônes, un arrière-plan et un écran de démarrage. Le guide explique comment créer un thème et le soumettre à la boutique.',
    note:
      'L’app vérifie le SHA-256 de chaque paquet de la boutique avant de l’installer.',
    authoring: 'Créer un thème',
    download: 'Télécharger le .fsbt',
    source: 'Source',
    light: 'Clair',
    dark: 'Sombre',
    search: 'Rechercher un thème',
    modeLabel: 'Mode',
    all: 'Tous',
    sortLabel: 'Trier',
    sortName: 'Nom',
    sortUpdated: 'Mis à jour récemment',
    noMatch: 'Aucun thème ne correspond. Essayez un autre nom ou un autre mode.',
    storeTitle: 'Boutique de thèmes',
    storeSubtitle:
      'Parcourez tous les thèmes officiels de ServerBox tels qu’ils apparaissent dans l’app : couleurs, composants, icônes et écrans de démarrage. Installez un thème depuis l’app ou téléchargez son paquet.',
    browse: 'Ouvrir la boutique de thèmes',
    back: 'Tous les thèmes',
    details: 'Détails',
    icons: 'Icônes',
    tabIcons: 'Onglets, et sélectionnés',
    navIcons: 'Symboles',
    palette: 'Palette',
    components: 'Composants',
    splash: 'Écran de démarrage',
    install: 'Installer',
    installSteps:
      'Dans l’app, ouvrez « Réglages → Apparence → Boutique de thèmes » et sélectionnez {name}. Vous pouvez aussi télécharger un paquet et choisir « Installer un thème → Fichier ».',
    base: 'Normal',
    hovered: 'Survolé',
    pressed: 'Pressé',
    disabled: 'Désactivé',
    loadFailed: 'Impossible de charger l’aperçu de ce thème.',
    retry: 'Réessayer',
    previewNote:
      'L’aperçu montre uniquement les icônes et les couleurs du thème. Le reste de l’interface est donné à titre indicatif.',
    iconPacks: 'Packs d’icônes',
    iconPacksSubtitle:
      'Les packs d’icônes se choisissent séparément des thèmes et fonctionnent avec n’importe lequel. Installez-les depuis « Réglages → Apparence → Boutique de thèmes → Packs d’icônes ».',
  },
  plugins: {
    title: 'Étendez ServerBox',
    subtitle:
      'Installez les plugins officiels de ServerBox pour ajouter des fonctionnalités à l’app.',
    empty: 'Pas encore de plugin officiel.',
    download: 'Télécharger',
  },
  download: {
    title: 'Plusieurs plateformes et options de téléchargement.',
    subtitle:
      'Choisissez une source de téléchargement fiable. Téléchargez l’app iOS depuis l’App Store ou récupérez un fichier .ipa non signé sur GitHub Releases pour le signer vous-même. L’app macOS est compatible avec Apple silicon et Intel et se trouve sur GitHub Releases ou Homebrew. Les installateurs Android, Linux et Windows sont disponibles en téléchargement direct.',
    copied: 'Commande copiée',
    copyPrompt: 'Copiez cette commande :',
    note:
      'Téléchargez les paquets uniquement depuis des sources fiables. Pour les notifications push du serveur, les données des widgets et la supervision autonome, installez ServerBoxMonitor séparément sur vos serveurs.',
  },
  cta: {
    title: 'ServerBox est libre et open source sous AGPLv3.',
    subtitle:
      'Retrouvez ServerBox sur l’App Store, GitHub Releases, F-Droid ou OpenAPK.',
    appStoreAction: 'Ouvrir l’App Store',
    githubAction: 'Télécharger depuis GitHub Releases',
  },
  footer: {
    features: 'Fonctionnalités',
    capabilities: 'Capacités',
    releases: 'Versions',
  },
}

export default fr
