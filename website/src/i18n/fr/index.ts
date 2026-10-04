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
}

export default fr
