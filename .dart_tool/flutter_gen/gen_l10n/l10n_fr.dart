import 'l10n.dart';

/// The translations for French (`fr`).
class SFr extends S {
  SFr([String locale = 'fr']) : super(locale);

  @override
  String get about => 'À propos';

  @override
  String get aboutThanks => 'Merci aux personnes suivantes qui ont participé à.';

  @override
  String get add => 'Ajouter';

  @override
  String get addAServer => 'ajouter un serveur';

  @override
  String get addPrivateKey => 'Ajouter une clé privée';

  @override
  String get addSystemPrivateKeyTip => 'Actuellement, vous n\'avez aucune clé privée. Voulez-vous ajouter celle qui accompagne le système (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Ajouté à la liste des tâches';

  @override
  String get all => 'Tous';

  @override
  String get alreadyLastDir => 'Déjà dans le dernier répertoire.';

  @override
  String get alterUrl => 'Modifier l\'URL';

  @override
  String askContinue(Object msg) {
    return '$msg. Continuer?';
  }

  @override
  String get attention => 'Attention';

  @override
  String get authRequired => 'Authentification requise';

  @override
  String get auto => 'Auto';

  @override
  String get autoBackupConflict => 'Une seule sauvegarde automatique peut être activée à la fois.';

  @override
  String get autoCheckUpdate => 'Vérification automatique des mises à jour';

  @override
  String get autoConnect => 'Connexion automatique';

  @override
  String get autoUpdateHomeWidget => 'Mise à jour automatique du widget d\'accueil';

  @override
  String get backup => 'Sauvegarder';

  @override
  String get backupTip => 'Les données exportées sont simplement chiffrées. \nVeuillez les conserver en lieu sûr.';

  @override
  String get backupVersionNotMatch => 'La version de sauvegarde ne correspond pas.';

  @override
  String get battery => 'Batterie';

  @override
  String get bgRun => 'Exécuter en arrière-plan';

  @override
  String get bgRunTip => 'Ce commutateur signifie seulement que l\'application essaiera de fonctionner en arrière-plan. La possibilité de fonctionner en arrière-plan dépend de l\'activation ou non des autorisations. Pour Android, veuillez désactiver l\'option \"Optimisation de la batterie\" dans cette application, et pour Miui, veuillez changer la politique d\'économie d\'énergie en \"Illimité\".';

  @override
  String get bioAuth => 'Authentification biométrique';

  @override
  String get canPullRefresh => 'Vous pouvez tirer pour actualiser.';

  @override
  String get cancel => 'Annuler';

  @override
  String get choose => 'Choisir';

  @override
  String get chooseFontFile => 'Choisir un fichier de police';

  @override
  String get choosePrivateKey => 'Choisir la clé privée';

  @override
  String get clear => 'Effacer';

  @override
  String get clipboard => 'presse-papiers';

  @override
  String get close => 'Fermer';

  @override
  String get cmd => 'Commande';

  @override
  String get collapseUI => 'обвал';

  @override
  String get collapseUITip => 'Réduction ou non des longues listes présentes dans l\'interface utilisateur par défaut';

  @override
  String get conn => 'Connexion';

  @override
  String get connected => 'Connecté';

  @override
  String get container => 'Conteneurs';

  @override
  String get containerName => 'Nom du conteneur';

  @override
  String get containerStatus => 'Statut du conteneur';

  @override
  String get convert => 'Convertir';

  @override
  String get copy => 'Copier';

  @override
  String get copyPath => 'Copier le chemin';

  @override
  String get createFile => 'Créer un fichier';

  @override
  String get createFolder => 'Créer un dossier';

  @override
  String get dark => 'Sombre';

  @override
  String get debug => 'Déboguer';

  @override
  String get decode => 'Décoder';

  @override
  String get decompress => 'Décompresser';

  @override
  String get delete => 'Supprimer';

  @override
  String get deleteScripts => 'Supprimer également les scripts du serveur';

  @override
  String get deleteServers => 'Suppression par lot de serveurs';

  @override
  String get dirEmpty => 'Assurez-vous que le répertoire est vide.';

  @override
  String get disabled => 'Désactivé';

  @override
  String get disconnected => 'Déconnecté';

  @override
  String get disk => 'Disque';

  @override
  String get diskIgnorePath => 'Ignorer le chemin pour le disque';

  @override
  String get displayName => 'Nom affiché';

  @override
  String dl2Local(Object fileName) {
    return 'Télécharger $fileName en local?';
  }

  @override
  String get dockerEditHost => 'Modifier DOCKER_HOST';

  @override
  String get dockerEmptyRunningItems => 'Il n\'y a pas de conteneurs en cours d\'exécution.\nCela peut être dû au fait que :\n- L\'utilisateur de l\'installation Docker n\'est pas le même que le nom d\'utilisateur configuré dans l\'App.\n- La variable d\'environnement DOCKER_HOST n\'a pas été lue correctement. Vous pouvez l\'obtenir en exécutant `echo \$DOCKER_HOST` dans le terminal.';

  @override
  String dockerImagesFmt(Object count) {
    return '$count images';
  }

  @override
  String get dockerNotInstalled => 'Docker n\'est pas installé';

  @override
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount) {
    return '$runningCount en cours d\'exécution, $stoppedCount conteneurs arrêtés.';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count conteneurs en cours d\'exécution.';
  }

  @override
  String get doubleColumnMode => 'Mode double colonne';

  @override
  String get download => 'Télécharger';

  @override
  String get edit => 'Modifier';

  @override
  String get editVirtKeys => 'Modifier les touches virtuelles';

  @override
  String get editor => 'Éditeur';

  @override
  String get editorHighlightTip => 'Les performances actuelles de la coloration syntaxique du code sont médiocres et peuvent être désactivées pour améliorer les performances.';

  @override
  String get encode => 'Encoder';

  @override
  String get error => 'Erreur';

  @override
  String get exampleName => 'Nom d\'exemple';

  @override
  String get experimentalFeature => 'Fonctionnalité expérimentale';

  @override
  String get export => 'Exporter';

  @override
  String get extraArgs => 'Arg supplémentaires';

  @override
  String get failed => 'Échoué';

  @override
  String get feedback => 'Commentaires';

  @override
  String get feedbackOnGithub => 'Si vous avez des questions, merci de les poster sur Github.';

  @override
  String get fieldMustNotEmpty => 'Ces champs ne doivent pas être vides.';

  @override
  String fileNotExist(Object file) {
    return '$file n\'existe pas';
  }

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'Le fichier \'$file\' est trop volumineux $size, max $sizeMax';
  }

  @override
  String get files => 'Fichiers';

  @override
  String get finished => 'Terminé';

  @override
  String get followSystem => 'Suivre le système';

  @override
  String get font => 'Police';

  @override
  String get fontSize => 'Taille de police';

  @override
  String get force => 'Forcer';

  @override
  String foundNUpdate(Object count) {
    return '$count mise(s) à jour trouvée(s)';
  }

  @override
  String get fullScreen => 'Mode plein écran';

  @override
  String get fullScreenJitter => 'Tremblement plein écran';

  @override
  String get fullScreenJitterHelp => 'Pour éviter la rémanence d\'écran';

  @override
  String get getPushTokenFailed => 'Impossible de récupérer le jeton d\'identification';

  @override
  String get gettingToken => 'Récupération du jeton...';

  @override
  String get goBackQ => 'Revenir en arrière ?';

  @override
  String get goto => 'Aller à';

  @override
  String get highlight => 'Coloration syntaxique';

  @override
  String get homeWidgetUrlConfig => 'Configurer l\'URL du widget d\'accueil';

  @override
  String get host => 'Hôte';

  @override
  String httpFailedWithCode(Object code) {
    return 'requête échouée, code d\'état : $code';
  }

  @override
  String get icloudSynced => 'iCloud est synchronisé et certaines options peuvent nécessiter un redémarrage de l\'application pour être effectives.';

  @override
  String get image => 'Image';

  @override
  String get imagesList => 'Liste d\'images';

  @override
  String get import => 'Importer';

  @override
  String get inner => 'Interne';

  @override
  String get inputDomainHere => 'Saisissez le domaine ici';

  @override
  String get install => 'installer';

  @override
  String get installDockerWithUrl => 'Veuillez d\'abord installer https://docs.docker.com/engine/install docker.';

  @override
  String get invalidJson => 'JSON invalide';

  @override
  String get invalidVersion => 'Version invalide';

  @override
  String invalidVersionHelp(Object url) {
    return 'Veuillez vous assurer que docker est installé correctement, ou que vous n\'utilisez pas une version auto-compilée. Si vous n\'avez pas les problèmes ci-dessus, veuillez soumettre un problème sur $url.';
  }

  @override
  String get isBusy => 'Est occupé maintenant';

  @override
  String get jumpServer => 'Serveur de saut';

  @override
  String get keepForeground => 'Laisser l\'application au premier plan !';

  @override
  String get keyAuth => 'Authentification par clé';

  @override
  String get keyboardCompatibility => 'Possibilité d\'améliorer la compatibilité avec les méthodes de saisie';

  @override
  String get keyboardType => 'Type de clavier';

  @override
  String get language => 'Langue';

  @override
  String get languageName => 'Français';

  @override
  String get lastTry => 'Dernier essai';

  @override
  String get launchPage => 'Page de lancement';

  @override
  String get license => 'Licence';

  @override
  String get light => 'Clair';

  @override
  String get loadingFiles => 'Chargement des fichiers...';

  @override
  String get location => 'Emplacement';

  @override
  String get log => 'Journal';

  @override
  String get loss => 'perte';

  @override
  String madeWithLove(Object myGithub) {
    return 'Fait avec ❤️ par $myGithub';
  }

  @override
  String get manual => 'Manuel';

  @override
  String get max => 'max';

  @override
  String get maxRetryCount => 'Nombre de reconnexions du serveur';

  @override
  String get maxRetryCountEqual0 => 'Réessayera encore et encore.';

  @override
  String get min => 'min';

  @override
  String get mission => 'Mission';

  @override
  String get moveOutServerFuncBtnsHelp => 'Activé : peut être affiché sous chaque carte sur la page de l\'onglet Serveur. Désactivé : peut être affiché en haut de la page Détails du serveur.';

  @override
  String get ms => 'ms';

  @override
  String get name => 'Nom';

  @override
  String get needRestart => 'Redémarrage de l\'application nécessaire';

  @override
  String get net => 'Réseau';

  @override
  String get netViewType => 'Type de vue réseau';

  @override
  String get newContainer => 'Nouveau conteneur';

  @override
  String get noClient => 'Aucun client';

  @override
  String get noInterface => 'Aucune interface';

  @override
  String get noOptions => 'Aucune option';

  @override
  String get noResult => 'Aucun résultat';

  @override
  String get noSavedPrivateKey => 'Aucune clé privée enregistrée.';

  @override
  String get noSavedSnippet => 'Aucun extrait enregistré.';

  @override
  String get noServerAvailable => 'Aucun serveur disponible.';

  @override
  String get noTask => 'Aucune tâche';

  @override
  String get noUpdateAvailable => 'Aucune mise à jour disponible';

  @override
  String get notSelected => 'Non sélectionné';

  @override
  String get note => 'Note';

  @override
  String get nullToken => 'Jeton nul';

  @override
  String get ok => 'OK';

  @override
  String get onServerDetailPage => 'Sur la page de détails du serveur';

  @override
  String get open => 'Ouvrir';

  @override
  String get openLastPath => 'Ouvrir le dernier chemin';

  @override
  String get openLastPathTip => 'Les serveurs différents auront des journaux différents, et le journal est le chemin de sortie';

  @override
  String get paste => 'Coller';

  @override
  String get path => 'Chemin';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$percent% de $size';
  }

  @override
  String get pickFile => 'Choisir un fichier';

  @override
  String get pingAvg => 'Moy.:';

  @override
  String get pingInputIP => 'Veuillez saisir une adresse IP / un domaine cible.';

  @override
  String get pingNoServer => 'Aucun serveur pour ping.\nVeuillez ajouter un serveur dans l\'onglet serveur.';

  @override
  String get pkg => 'Pkg';

  @override
  String get platformNotSupportUpdate => 'La plateforme actuelle ne prend pas en charge la mise à jour dans l\'application. \nVeuillez le compiler à partir de la source et l\'installer.';

  @override
  String get plzEnterHost => 'Veuillez saisir l\'hôte.';

  @override
  String get plzSelectKey => 'Veuillez sélectionner une clé.';

  @override
  String get port => 'Port';

  @override
  String get preview => 'Aperçu';

  @override
  String get primaryColorSeed => 'Graine de couleur primaire';

  @override
  String get privateKey => 'Clé privée';

  @override
  String get process => 'Processus';

  @override
  String get pushToken => 'Jeton d\'identification';

  @override
  String get pwd => 'Mot de passe';

  @override
  String get read => 'Lire';

  @override
  String get reboot => 'Redémarrer';

  @override
  String get remotePath => 'Chemin distant';

  @override
  String get rename => 'Renommer';

  @override
  String reportBugsOnGithubIssue(Object url) {
    return 'Veuillez signaler les bogues sur $url';
  }

  @override
  String get restart => 'Redémarrer';

  @override
  String get restore => 'Restaurer';

  @override
  String get restoreSuccess => 'Restauration réussie. Redémarrez l\'application pour l\'appliquer.';

  @override
  String get result => 'Résultat';

  @override
  String get rotateAngel => 'Angle de rotation';

  @override
  String get run => 'Exécuter';

  @override
  String get running => 'en cours d\'exécution';

  @override
  String get save => 'Enregistrer';

  @override
  String get saved => 'Enregistré';

  @override
  String get second => 's';

  @override
  String get sequence => 'Séquence';

  @override
  String get server => 'Serveur';

  @override
  String get serverDetailOrder => 'Ordre des widgets de la page de détails';

  @override
  String get serverFuncBtns => 'Boutons de fonction du serveur';

  @override
  String get serverOrder => 'Ordre des serveurs';

  @override
  String get serverTabConnecting => 'Connexion...';

  @override
  String get serverTabEmpty => 'Il n\'y a aucun serveur.\nCliquez sur le bouton pour en ajouter un.';

  @override
  String get serverTabFailed => 'Échec';

  @override
  String get serverTabLoading => 'Chargement...';

  @override
  String get serverTabPlzSave => 'Veuillez \'enregistrer\' à nouveau cette clé privée.';

  @override
  String get serverTabUnkown => 'État inconnu';

  @override
  String get setting => 'Paramètres';

  @override
  String get sftpDlPrepare => 'Préparation de la connexion...';

  @override
  String get sftpRmrDirSummary => 'Utilisez `rm -r` pour supprimer un dossier dans SFTP.';

  @override
  String get sftpShowFoldersFirst => 'Dossiers d\'abord lors du tri';

  @override
  String get sftpSSHConnected => 'SFTP connecté';

  @override
  String get showDistLogo => 'Afficher le logo de la distribution';

  @override
  String get shutdown => 'Éteindre';

  @override
  String get size => 'Taille';

  @override
  String get snippet => 'Extrait';

  @override
  String get speed => 'Vitesse';

  @override
  String spentTime(Object time) {
    return 'Temps écoulé : $time';
  }

  @override
  String sshTip(Object url) {
    return 'Cette fonction est actuellement au stade expérimental.\n\n Veuillez signaler les bogues sur $url ou rejoignez notre développement.';
  }

  @override
  String get sshVirtualKeyAutoOff => 'Basculement automatique des touches virtuelles';

  @override
  String get start => 'Démarrer';

  @override
  String get stats => 'Statistiques';

  @override
  String get stop => 'Arrêter';

  @override
  String get stopped => 'interrompue';

  @override
  String get success => 'Succès';

  @override
  String get supportFmtArgs => 'Les paramètres de formatage suivants sont pris en charge:';

  @override
  String get suspend => 'Suspendre';

  @override
  String get suspendTip => 'La fonction de suspension nécessite des privilèges root et la prise en charge de systemd.';

  @override
  String switchTo(Object val) {
    return 'Passer à $val';
  }

  @override
  String get syncTip => 'Un redémarrage peut être nécessaire pour que certains changements prennent effet.';

  @override
  String get system => 'Système';

  @override
  String get tag => 'Étiquettes';

  @override
  String get temperature => 'Température';

  @override
  String get terminal => 'Terminal';

  @override
  String get test => 'Tester';

  @override
  String get textScaler => 'Mise à l\'échelle du texte';

  @override
  String get textScalerTip => '1.0 => 100% (taille d\'origine), fonctionne uniquement sur la partie police de caractères de la page du serveur, il n\'est pas recommandé de la modifier.';

  @override
  String get theme => 'Thème';

  @override
  String get themeMode => 'Mode du thème';

  @override
  String get time => 'L\'heure';

  @override
  String get times => 'Fois';

  @override
  String get total => 'Total';

  @override
  String get traffic => 'Trafic';

  @override
  String get ttl => 'ttl';

  @override
  String get unknown => 'Inconnu';

  @override
  String get unknownError => 'Erreur inconnue';

  @override
  String get unkownConvertMode => 'Mode de conversion inconnu';

  @override
  String get update => 'Mettre à jour';

  @override
  String get updateAll => 'Tout mettre à jour';

  @override
  String get updateIntervalEqual0 => 'Vous avez défini 0, ne mettra pas à jour automatiquement.\nImpossible de calculer l\'état du processeur.';

  @override
  String get updateServerStatusInterval => 'Intervalle de mise à jour de l\'état du serveur';

  @override
  String updateTip(Object newest) {
    return 'Mise à jour : v1.0.$newest';
  }

  @override
  String updateTipTooLow(Object newest) {
    return 'La version actuelle est trop basse, veuillez mettre à jour vers v1.0.$newest';
  }

  @override
  String get upload => 'Téléverser';

  @override
  String get upsideDown => 'À l\'envers';

  @override
  String get uptime => 'Temps de disponibilité';

  @override
  String get urlOrJson => 'URL ou JSON';

  @override
  String get useNoPwd => 'Aucun mot de passe ne sera utilisé';

  @override
  String get used => 'Utilisé';

  @override
  String get user => 'Utilisateur';

  @override
  String versionHaveUpdate(Object build) {
    return 'Trouvé : v1.0.$build, cliquez pour mettre à jour';
  }

  @override
  String versionUnknownUpdate(Object build) {
    return 'Actuel : v1.0.$build, cliquez pour vérifier les mises à jour';
  }

  @override
  String versionUpdated(Object build) {
    return 'Actuel : v1.0.$build, à jour';
  }

  @override
  String get viewErr => 'Voir l\'erreur';

  @override
  String get virtKeyHelpClipboard => 'Copier dans le presse-papiers si le terminal sélectionné n\'est pas vide, sinon coller le contenu du presse-papiers dans le terminal.';

  @override
  String get virtKeyHelpSFTP => 'Ouvrir le répertoire actuel dans SFTP.';

  @override
  String get waitConnection => 'Veuillez attendre l\'établissement de la connexion.';

  @override
  String get watchNotPaired => 'Aucune Apple Watch appairée';

  @override
  String get webdavSettingEmpty => 'La configuration Webdav est vide';

  @override
  String get whenOpenApp => 'À l\'ouverture de l\'application';

  @override
  String get willTakEeffectImmediately => 'Prendra effet immédiatement';

  @override
  String get write => 'Écrire';
}
