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
    docs: 'Documentation',
    themes: 'Thèmes',
    plugins: 'Plugins',
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
    four: 'Capture du navigateur de fichiers ServerBox',
  },
  features: {
    title: 'Un espace compact pour la maintenance quotidienne.',
    subtitle:
      'Une surface opérationnelle dense et directe, où chaque bloc correspond à un vrai flux de maintenance.',
    list: {
      title: 'Liste des serveurs',
      description:
        "Consultez d'un coup d'œil l'état de connexion et l'utilisation du CPU, de la mémoire, du disque et du réseau de chaque serveur. Filtrez par étiquette ou repérez-les sur le globe.",
    },
    charts: {
      title: "Graphiques d'état",
      description:
        "Graphiques en temps réel du CPU, de la mémoire, du swap, des disques, des E/S disque et du réseau, ainsi que des capteurs, GPU et batteries. Consultez l'historique ou ouvrez une mesure pour en voir les détails.",
    },
    terminal: {
      title: 'Terminal SSH',
      description:
        'Un terminal complet avec touches virtuelles sur mobile, prêt pour htop, vim et bien plus. Connectez-vous directement, via un hôte bastion ou avec un ProxyCommand.',
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
        'Tous les processus avec leur CPU et leur mémoire, triés à votre guise et recherchables par nom, utilisateur ou PID. Arrêtez-en un depuis la liste.',
    },
    services: {
      title: 'Services systemd',
      description:
        "Les unités en échec d'abord, puis le reste. Redémarrez une unité ou lisez ses logs d'un geste.",
    },
    users: {
      title: 'Utilisateurs et groupes',
      description:
        'Consultez les comptes système avec le shell de connexion et l’accès à sudo mis en évidence. Créez ou supprimez des utilisateurs, et créez, modifiez ou supprimez des groupes.',
    },
    agent: {
      title: 'Agent IA',
      description:
        "Un assistant dans l'app qui connaît vos serveurs, avec les fournisseurs de modèles, serveurs MCP et skills de votre choix.",
    },
    bench: {
      title: 'Benchmark',
      description:
        'Lancez Yet Another Bench Script pour tester le disque, le réseau et le CPU d’un serveur, puis conserver les résultats. Le menu Plus permet aussi d’ouvrir les snippets, le bureau à distance et la virtualisation.',
    },
    virt: {
      title: 'Virtualisation',
      description:
        'Machines virtuelles et conteneurs sur libvirt et Proxmox VE : démarrez-les, arrêtez-les, modifiez vCPU, mémoire et disques, ouvrez leurs consoles.',
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
      'ServerBox garde terminal, transfert de fichiers, services, santé matérielle et alertes dans le même flux.',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android, Linux et Windows',
  },
  themes: {
    title: 'À votre image.',
    subtitle:
      'Les thèmes officiels de ServerBox, les mêmes que ceux de la boutique de thèmes de l’app. Installez-les depuis Réglages → Apparence → Boutique de thèmes, ou téléchargez un paquet et choisissez Installer un thème → Fichier.',
    empty:
      'Pas encore de thème officiel. Un thème est un dossier avec un manifest.toml : couleurs claires et sombres, styles des composants, icônes, arrière-plan et écran de démarrage. Le guide explique comment en créer un et le publier dans la boutique.',
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
      'Tous les thèmes officiels de ServerBox, dessinés comme l’app les dessine : couleurs, composants, icônes et écran de démarrage. Installez-les depuis la boutique de l’app ou téléchargez le paquet.',
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
      'Dans l’app, ouvrez Réglages → Apparence → Boutique de thèmes et choisissez {name}. Ou téléchargez le paquet et choisissez Installer un thème → Fichier.',
    base: 'Normal',
    hovered: 'Survolé',
    pressed: 'Pressé',
    disabled: 'Désactivé',
    loadFailed: 'Impossible de charger l’aperçu de ce thème.',
    retry: 'Réessayer',
    previewNote:
      'Les aperçus montrent les icônes et les couleurs du thème ; le reste de l’interface est indicatif.',
    iconPacks: 'Packs d’icônes',
    iconPacksSubtitle:
      'Des icônes choisies indépendamment du thème et dessinées par-dessus celui utilisé. Installez-les dans l’app depuis Réglages → Apparence → Boutique de thèmes → Packs d’icônes.',
  },
  plugins: {
    title: 'Plugins.',
    subtitle:
      'Les plugins officiels de ServerBox, installés depuis la boutique de plugins de l’app.',
    empty: 'Pas encore de plugin officiel.',
    download: 'Télécharger',
  },
  download: {
    title: 'Toutes les plateformes, toutes les sources.',
    subtitle:
      'Choisissez une source fiable pour votre appareil. iOS est sur l’App Store, ou en .ipa non signé sur GitHub Releases, à signer vous-même. Les versions macOS pour puce Apple et Intel sont sur GitHub Releases et Homebrew. Android, Linux et Windows ont des téléchargements directs.',
    copied: 'Commande copiée',
    copyPrompt: 'Copiez cette commande :',
    note:
      'Téléchargez uniquement depuis une source de confiance. Pour les notifications serveur, widgets et surveillance compagnon, installez ServerBoxMonitor sur vos serveurs.',
  },
  cta: {
    title: 'ServerBox est libre et open source sous AGPLv3.',
    subtitle:
      'Installez depuis l’App Store, GitHub Releases, F-Droid ou OpenAPK.',
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
