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
      'Installez depuis l’App Store, GitHub Releases, F-Droid, OpenAPK ou le CDN du projet.',
    appStoreAction: 'Ouvrir l’App Store',
    githubAction: 'Télécharger depuis GitHub Releases',
  },
  plugins: {
    metaTitle: 'Plugins ServerBox — étendre l’app sans attendre une version',
    metaDescription:
      'Les plugins ajoutent à ServerBox des pages, des cartes et des relevés d’état. Chacun est un petit module isolé qui déclare les permissions dont il a besoin, et l’app vérifie chaque paquet qu’elle télécharge.',
    title: 'Étendez l’app sans attendre une version.',
    subtitle:
      'Un plugin ajoute une page, une carte, un onglet d’accueil ou des relevés d’état. C’est un petit module, il tourne dans un bac à sable, et il ne peut faire que ce que son manifeste a demandé et que vous avez accepté.',
    how: {
      sandbox: {
        title: 'Isolé dans un bac à sable',
        description:
          'Un plugin est du JavaScript dans un runtime isolé : pas de système de fichiers, pas de réseau, aucune connexion serveur à lui. Tout ce qu’il fait, il le demande à l’app.',
      },
      permissions: {
        title: 'Il demande avant d’agir',
        description:
          'Son manifeste nomme ce dont il a besoin — exécuter une commande, joindre un hôte, voir la liste de vos serveurs — et c’est cette liste que vous acceptez à l’installation. Un appel non accordé échoue aussitôt.',
      },
      anyRepo: {
        title: 'N’importe quel dépôt, octets vérifiés',
        description:
          'L’app installe depuis n’importe quelle adresse de dépôt en HTTPS — une requête pour son arbre le plus récent — et vérifie chaque paquet avec la somme de contrôle annoncée par son fichier. Un paquet sans somme est refusé, sauf accord explicite.',
      },
    },
    listTitle: 'Dans le dépôt officiel',
    listSubtitle:
      '{count} plugins, développés dans ce dépôt et publiés séparément de l’app.',
    asks: 'Demande',
    asksNothing: 'rien',
    appearsIn: 'Apparaît dans',
    languages: 'Langues',
    source: 'Source',
    install: {
      title: 'Installer un plugin',
      stepOne: 'Dans l’app, ouvrez Réglages → Plugins → Boutique de plugins.',
      stepTwo:
        'Choisissez un plugin et appuyez sur Installer. Le dépôt officiel est déjà listé.',
      stepThree:
        'Lisez ce qu’il demande, puis acceptez. L’app vérifie le téléchargement avec la somme de contrôle du dépôt avant d’exécuter quoi que ce soit.',
      address: 'L’adresse du dépôt, si vous l’avez retirée et voulez la remettre :',
      copy: 'Copier l’adresse',
    },
    write: {
      title: 'En écrire un',
      description:
        'Un plugin est un seul module ES en TypeScript ou JavaScript, testé contre un hôte simulé avec bun test — sans app ni étape de build. Sur ordinateur, pointez l’app vers son dossier : éditer et relancer suffit.',
      sdk: 'SDK',
      examples: 'Plugins d’exemple',
      repository: 'Dépôt officiel',
    },
    home: 'Accueil',
  },
  footer: {
    features: 'Fonctions',
    capabilities: 'Capacités',
    releases: 'Versions',
  },
}

export default fr
