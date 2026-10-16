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
    monitor: 'Monitor',
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
  gallery: {
    title: "Chaque écran, sur chaque appareil.",
    subtitle:
      "31 captures sur iPhone, iPad et macOS, repliées pour garder la page légère jusqu'à ce que vous les demandiez.",
    count: "{count} captures",
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
      'Choisissez une source fiable pour votre appareil. Sous iOS, l’application est disponible sur l’App Store. Sous macOS, l’App Store ne prend en charge que les Mac avec puce Apple ; les utilisateurs de Mac Intel peuvent l’installer depuis GitHub Releases ou Homebrew. Des téléchargements directs sont aussi proposés pour Android, Linux et Windows.',
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
  monitor: {
    meta: {
      title: 'ServerBox Monitor — l’agent qui veille sur votre serveur',
      description: 'ServerBox Monitor tourne sur votre serveur : il garde l’historique de l’état, envoie des alertes sur votre téléphone, alimente les widgets et l’app Watch, et sert un panneau web.',
    },
    nav: {
      why: 'Pourquoi un agent',
      panel: 'Panneau web',
      alerts: 'Alertes',
      access: 'Accès',
      install: 'Installer',
    },
    hero: {
      eyebrow: 'ServerBox Monitor',
      title: 'Un relevé toutes les 7 secondes. Gardé. Envoyé à votre téléphone.',
      subtitle: 'Un petit agent Rust qui tourne sur votre serveur. Il garde l’historique dans SQLite, envoie des alertes, tient à jour les widgets de ServerBox et l’app Watch, et sert un panneau web — et l’app le joint sans SSH.',
      installLabel: 'Installer sur Linux avec systemd ou OpenRC',
      installNote: 'Il tourne sous votre propre compte, pas en root.',
      copy: 'Copier',
      copied: 'Copié',
      guide: 'Guide d’installation',
      terminalLabel: 'L’agent en cours d’installation, puis ses relevés',
      installed: 'installé comme service systemctl --user',
      listening: 'à l’écoute sur 0.0.0.0:3770',
      sampled: 'relevé',
      cadence: 'toutes les 7 s — interval_seconds, par défaut',
      pushLabel: 'Des alertes de l’agent sur l’écran verrouillé d’un iPhone',
      widgetLabel: 'Un widget ServerBox alimenté par l’agent',
    },
    keywords: {
      history: 'Historique SQLite',
      push: 'Alertes push',
      panel: 'Panneau web',
      roles: 'Rôles et droits',
      docker: 'Docker',
    },
    why: {
      title: 'Ce que l’agent ajoute à SSH',
      subtitle: 'SSH suffit pour regarder un serveur. L’agent continue de regarder quand vous ne le faites pas.',
      history: {
        title: 'L’historique d’avant l’ouverture de l’app',
        description: 'L’agent relève l’état de lui-même et garde le résultat : les graphiques montrent la nuit où vous dormiez. La durée de conservation, c’est vous qui la fixez.',
      },
      alerts: {
        title: 'Des alertes sur votre téléphone',
        description: 'Des règles sur le CPU, la mémoire, le swap, le disque, le réseau et la température, envoyées vers iOS, Bark, ServerChan ou n’importe quel webhook.',
      },
      widgets: {
        title: 'Des widgets et une Watch toujours à jour',
        description: 'Les widgets et l’app Watch lisent l’agent : ils se mettent à jour même quand ServerBox est fermé.',
      },
      reach: {
        title: 'Aucun SSH à ouvrir',
        description: 'L’app parle à l’agent en HTTP. Utilisez-le là où SSH est injoignable, ou avec SSH sur le même serveur.',
      },
    },
    panel: {
      title: 'Un panneau web sur chaque agent',
      subtitle: 'Chaque agent sert son propre panneau sur le port 3770. Ou hébergez le panneau une seule fois et connectez-vous à plusieurs agents depuis une même page.',
      dashboard: {
        title: 'Graphiques en direct et historique conservé',
        description: 'CPU, mémoire, disques, réseau, GPU et capteurs, en direct et sur tout ce que l’agent a gardé — avec la sortie de vos propres commandes à côté.',
      },
      terminal: {
        title: 'Un terminal et des fichiers dans le navigateur',
        description: 'Un terminal qui continue de tourner quand l’onglet se ferme et reprend où il en était, et un explorateur limité aux dossiers que vous désignez.',
      },
      machine: {
        title: 'Les parties de la machine qui bougent',
        description: 'Conteneurs Docker ou Podman, services, processus, cron, pare-feu et utilisateurs système. L’agent construit et vérifie chaque action ; le panneau ne fait que demander.',
      },
      reach: {
        title: 'Ce qui se trouve à côté du serveur',
        description: 'Bureaux RDP et VNC, BMC via Redfish, et machines virtuelles sur Proxmox VE ou libvirt, joints à travers l’agent.',
      },
    },
    alerts: {
      title: 'Des alertes là où vous regardez déjà',
      subtitle: 'Une règle, c’est une métrique et un seuil. Quand elle se déclenche, chaque canal configuré est prévenu.',
      rule: 'Une règle de config.toml',
      push: 'Notification iOS',
      webhook: 'Un webhook vers une messagerie',
      widget: 'Widget d’écran d’accueil',
    },
    access: {
      title: 'Vous décidez de ce que chaque compte peut faire',
      subtitle: 'Lire l’état est ouvert à tous les comptes. Le reste s’accorde, et se retire.',
      roles: {
        title: 'Rôles et droits',
        description: 'Shell, fichiers, redirection de ports et virtualisation sont des droits qu’un admin accorde à un rôle. Retirez-en un, et ce qui l’utilisait se ferme.',
      },
      transport: {
        title: 'TLS pour tout ce qui dépasse la lecture',
        description: 'Les commandes, les fichiers et les relais exigent TLS ou un appel depuis la même machine. TLS intégré, proxy inverse ou tunnel : tout convient.',
      },
      account: {
        title: 'Il tourne sous votre compte',
        description: 'L’installateur lance l’agent sous votre propre compte : le shell qu’il donne est celui de ce compte, pas celui de root.',
      },
      audit: {
        title: 'Chaque accès est enregistré',
        description: 'Qui, quand, d’où, quoi et avec quel résultat. Jamais les mots de passe ni les clés.',
      },
    },
    install: {
      title: 'Installer',
      subtitle: 'Trois étapes, d’un serveur neuf à son état sur votre téléphone.',
      step1: {
        title: 'Installer l’agent',
        description: 'L’installateur choisit systemd ou OpenRC et récupère la dernière version. Ajoutez --permissions read pour démarrer avec un admin sans aucun droit.',
      },
      step2: {
        title: 'Se connecter',
        description: 'Le premier démarrage crée le compte admin avec un mot de passe aléatoire, enregistré à côté de la base dans initial-admin-credentials.txt. Changez-le, puis supprimez le fichier :',
      },
      step3: {
        title: 'L’ajouter à ServerBox',
        description: 'Dans l’app, ajoutez le serveur comme agent Monitor avec son adresse et son compte. Ou ouvrez le panneau sur le port 3770.',
      },
      tabs: {
        systemd: 'systemd',
        openrc: 'OpenRC (Alpine)',
        docker: 'Docker',
      },
      dockerNote: 'Construit depuis ce dépôt.',
    },
    cta: {
      title: 'Libre et gratuit, comme l’app.',
      subtitle: 'L’agent vit dans le dépôt de ServerBox, sous la même licence.',
      app: 'Obtenir ServerBox',
      source: 'Code de l’agent',
    },
  },
}

export default fr
