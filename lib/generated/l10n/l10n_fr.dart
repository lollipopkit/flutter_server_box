import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get aboutThanks => 'Merci aux personnes suivantes qui ont participé.';

  @override
  String get acceptBeta => 'Accepter les mises à jour de la version de test';

  @override
  String get addSystemPrivateKeyTip => 'Actuellement, vous n\'avez aucune clé privée. Souhaitez-vous ajouter celle qui vient avec le système (~/.ssh/id_rsa) ?';

  @override
  String get added2List => 'Ajouté à la liste des tâches';

  @override
  String get addr => 'Adresse';

  @override
  String get alreadyLastDir => 'Déjà dans le dernier répertoire.';

  @override
  String get authFailTip => 'Échec de l\'authentification. Veuillez vérifier si le mot de passe/clé/hôte/utilisateur, etc., est incorrect.';

  @override
  String get autoBackupConflict => 'Un seul sauvegarde automatique peut être activé en même temps.';

  @override
  String get autoConnect => 'Connexion automatique';

  @override
  String get autoRun => 'Exécution automatique';

  @override
  String get autoUpdateHomeWidget => 'Mise à jour automatique du widget d\'accueil';

  @override
  String get backupTip => 'Les données exportées sont simplement chiffrées. \nVeuillez les garder en sécurité.';

  @override
  String get backupVersionNotMatch => 'La version de sauvegarde ne correspond pas.';

  @override
  String get battery => 'Batterie';

  @override
  String get bgRun => 'Exécution en arrière-plan';

  @override
  String get bgRunTip => 'Cette option signifie seulement que le programme essaiera de s\'exécuter en arrière-plan, que cela soit possible dépend de l\'autorisation activée ou non. Pour Android natif, veuillez désactiver l\'« Optimisation de la batterie » dans cette application, et pour MIUI, veuillez changer la politique d\'économie d\'énergie en « Illimité ».';

  @override
  String get closeAfterSave => 'Enregistrer et fermer';

  @override
  String get cmd => 'Commande';

  @override
  String get collapseUITip => 'Indique si les longues listes présentées dans l\'interface utilisateur doivent être réduites par défaut.';

  @override
  String get conn => 'Connexion';

  @override
  String get container => 'Conteneur';

  @override
  String get containerTrySudoTip => 'Par exemple : Dans l\'application, l\'utilisateur est défini comme aaa, mais Docker est installé sous l\'utilisateur root. Dans ce cas, vous devez activer cette option.';

  @override
  String get convert => 'Convertir';

  @override
  String get copyPath => 'Copier le chemin';

  @override
  String get cpuViewAsProgressTip => 'Afficher le taux d\'utilisation de chaque CPU sous forme de barre de progression (ancien style)';

  @override
  String get cursorType => 'Type de curseur';

  @override
  String get customCmd => 'Commandes personnalisées';

  @override
  String get customCmdDocUrl => 'https://github.com/lollipopkit/flutter_server_box/wiki#custom-commands';

  @override
  String get customCmdHint => '\"Nom de la commande\": \"Commande\"';

  @override
  String get decode => 'Décoder';

  @override
  String get decompress => 'Décompresser';

  @override
  String get deleteServers => 'Supprimer des serveurs en lot';

  @override
  String get dirEmpty => 'Assurez-vous que le répertoire est vide.';

  @override
  String get disconnected => 'Déconnecté';

  @override
  String get disk => 'Disque';

  @override
  String get diskIgnorePath => 'Chemin à ignorer pour le disque';

  @override
  String get displayCpuIndex => 'Afficher l\'index CPU';

  @override
  String dl2Local(Object fileName) {
    return 'Télécharger $fileName localement ?';
  }

  @override
  String get dockerEmptyRunningItems => 'Aucun conteneur en cours d\'exécution.\nCela peut être dû à :\n- L\'utilisateur d\'installation de Docker n\'est pas le même que celui configuré dans l\'application.\n- La variable d\'environnement DOCKER_HOST n\'a pas été lue correctement. Vous pouvez l\'obtenir en exécutant `echo \$DOCKER_HOST` dans le terminal.';

  @override
  String dockerImagesFmt(Object count) {
    return '$count images';
  }

  @override
  String get dockerNotInstalled => 'Docker non installé';

  @override
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount) {
    return '$runningCount en cours d\'exécution, $stoppedCount conteneur arrêté.';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count conteneur en cours d\'exécution.';
  }

  @override
  String get doubleColumnMode => 'Mode double colonne';

  @override
  String get doubleColumnTip => 'Cette option n\'active que la fonctionnalité, qu\'elle puisse être activée dépend de la largeur de l\'appareil.';

  @override
  String get editVirtKeys => 'Modifier les touches virtuelles';

  @override
  String get editor => 'Éditeur';

  @override
  String get editorHighlightTip => 'La performance actuelle de mise en surbrillance du code est pire et peut être désactivée en option pour s\'améliorer.';

  @override
  String get encode => 'Encoder';

  @override
  String get envVars => 'Variable d’environnement';

  @override
  String get experimentalFeature => 'Fonctionnalité expérimentale';

  @override
  String get extraArgs => 'Arguments supplémentaires';

  @override
  String get fallbackSshDest => 'Destino SSH alternativo';

  @override
  String get fdroidReleaseTip => 'Si vous avez téléchargé cette application depuis F-Droid, il est recommandé de désactiver cette option.';

  @override
  String get fgService => 'Service de premier plan';

  @override
  String get fgServiceTip => 'Après l\'activation, certains modèles d\'appareils peuvent planter. La désactivation peut empêcher certains modèles de maintenir les connexions SSH en arrière-plan. Veuillez autoriser les permissions de notification ServerBox, l\'exécution en arrière-plan et l\'auto-réveil dans les paramètres système.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'Fichier \'$file\' trop volumineux $size, max $sizeMax';
  }

  @override
  String get followSystem => 'Suivre le système';

  @override
  String get font => 'Police';

  @override
  String get fontSize => 'Taille de la police';

  @override
  String get force => 'Forcer';

  @override
  String get fullScreen => 'Mode plein écran';

  @override
  String get fullScreenJitter => 'Secousse en plein écran';

  @override
  String get fullScreenJitterHelp => 'Pour éviter les brûlures d\'écran';

  @override
  String get fullScreenTip => 'Le mode plein écran doit-il être activé lorsque l\'appareil est orienté en mode paysage ? Cette option s\'applique uniquement à l\'onglet serveur.';

  @override
  String get goBackQ => 'Revenir en arrière ?';

  @override
  String get goto => 'Aller à';

  @override
  String get hideTitleBar => 'Masquer la barre de titre';

  @override
  String get highlight => 'Mise en surbrillance du code';

  @override
  String get homeWidgetUrlConfig => 'Configurer l\'URL du widget d\'accueil';

  @override
  String get host => 'Hôte';

  @override
  String httpFailedWithCode(Object code) {
    return 'Échec de la requête, code d\'état : $code';
  }

  @override
  String get ignoreCert => 'Ignorer le certificat';

  @override
  String get image => 'Image';

  @override
  String get imagesList => 'Liste des images';

  @override
  String get init => 'Initialiser';

  @override
  String get inner => 'Interne';

  @override
  String get install => 'Installer';

  @override
  String get installDockerWithUrl => 'Veuillez d\'abord installer docker depuis https://docs.docker.com/engine/install.';

  @override
  String get invalid => 'Invalide';

  @override
  String get jumpServer => 'Aller au serveur';

  @override
  String get keepForeground => 'Garder l\'application en premier plan !';

  @override
  String get keepStatusWhenErr => 'Conserver l\'état du dernier serveur';

  @override
  String get keepStatusWhenErrTip => 'Uniquement en cas d\'erreur lors de l\'exécution du script';

  @override
  String get keyAuth => 'Authentification par clé';

  @override
  String get letterCache => 'Mise en cache des lettres';

  @override
  String get letterCacheTip => 'Recommandé de désactiver, mais après désactivation, il sera impossible de saisir des caractères CJK.';

  @override
  String get license => 'Licence';

  @override
  String get location => 'Emplacement';

  @override
  String get loss => 'Perte';

  @override
  String madeWithLove(Object myGithub) {
    return 'Fabriqué avec ❤️ par $myGithub';
  }

  @override
  String get manual => 'Manuel';

  @override
  String get max => 'max';

  @override
  String get maxRetryCount => 'Nombre de reconnexions au serveur';

  @override
  String get maxRetryCountEqual0 => 'Il va réessayer encore et encore.';

  @override
  String get min => 'min';

  @override
  String get mission => 'Mission';

  @override
  String get more => 'Plus';

  @override
  String get moveOutServerFuncBtnsHelp => 'Activé : peut être affiché sous chaque carte sur la page de l\'onglet Serveur. Désactivé : peut être affiché en haut de la page de détails du serveur.';

  @override
  String get ms => 'ms';

  @override
  String get needHomeDir => 'Si vous êtes utilisateur Synology, [consultez ici](https://kb.synology.com/DSM/tutorial/user_enable_home_service). Les utilisateurs d\'autres systèmes doivent rechercher comment créer un répertoire personnel.';

  @override
  String get needRestart => 'Nécessite un redémarrage de l\'application';

  @override
  String get net => 'Réseau';

  @override
  String get netViewType => 'Type de vue réseau';

  @override
  String get newContainer => 'Nouveau conteneur';

  @override
  String get noLineChart => 'Ne pas utiliser de graphiques linéaires';

  @override
  String get noLineChartForCpu => 'Ne pas utiliser de graphiques linéaires pour l\'unité centrale';

  @override
  String get noPrivateKeyTip => 'La clé privée n\'existe pas, elle a peut-être été supprimée ou il y a une erreur de configuration.';

  @override
  String get noPromptAgain => 'Ne pas demander à nouveau';

  @override
  String get node => 'Nœud';

  @override
  String get notAvailable => 'Indisponible';

  @override
  String get onServerDetailPage => 'Sur la page de détails du serveur';

  @override
  String get onlyOneLine => 'Afficher uniquement en une seule ligne (défilement)';

  @override
  String get onlyWhenCoreBiggerThan8 => 'Fonctionne uniquement lorsque le nombre de cœurs est > 8';

  @override
  String get openLastPath => 'Ouvrir le dernier chemin';

  @override
  String get openLastPathTip => 'Les différents serveurs auront des journaux différents, et le journal est le chemin vers la sortie';

  @override
  String get parseContainerStatsTip => 'L\'analyse de l\'occupation des conteneurs Docker est relativement lente.';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$percent% de $size';
  }

  @override
  String get permission => 'Permissions';

  @override
  String get pingAvg => 'Moy.:';

  @override
  String get pingInputIP => 'Veuillez saisir une adresse IP / un domaine cible.';

  @override
  String get pingNoServer => 'Aucun serveur à pinger.\nVeuillez ajouter un serveur dans l\'onglet serveur.';

  @override
  String get pkg => 'Pkg';

  @override
  String get plugInType => 'Type d\'insertion';

  @override
  String get port => 'Port';

  @override
  String get preview => 'Aperçu';

  @override
  String get privateKey => 'Clé privée';

  @override
  String get process => 'Processus';

  @override
  String get pushToken => 'Jeton d\'identification';

  @override
  String get pveIgnoreCertTip => 'Il n\'est pas recommandé de l\'activer, attention aux risques de sécurité ! Si vous utilisez le certificat par défaut de PVE, vous devez activer cette option.';

  @override
  String get pveLoginFailed => 'Échec de la connexion. Impossible d\'authentifier avec le nom d\'utilisateur / mot de passe de la configuration du serveur pour la connexion Linux PAM.';

  @override
  String get pveVersionLow => 'Cette fonctionnalité est actuellement en phase de test et n\'a été testée que sur PVE 8+. Veuillez l\'utiliser avec prudence.';

  @override
  String get pwd => 'Mot de passe';

  @override
  String get read => 'Lire';

  @override
  String get reboot => 'Redémarrer';

  @override
  String get rememberPwdInMem => 'Mémoriser le mot de passe en mémoire';

  @override
  String get rememberPwdInMemTip => 'Utilisé pour les conteneurs, la suspension, etc.';

  @override
  String get rememberWindowSize => 'Se souvenir de la taille de la fenêtre';

  @override
  String get remotePath => 'Chemin distant';

  @override
  String get restart => 'Redémarrer';

  @override
  String get result => 'Résultat';

  @override
  String get rotateAngel => 'Angle de rotation';

  @override
  String get route => 'Routage';

  @override
  String get run => 'Exécuter';

  @override
  String get running => 'En cours d\'exécution';

  @override
  String get sameIdServerExist => 'Un serveur avec le même ID existe déjà';

  @override
  String get save => 'Enregistrer';

  @override
  String get saved => 'Enregistré';

  @override
  String get second => 's';

  @override
  String get sensors => 'Capteurs';

  @override
  String get sequence => 'Séquence';

  @override
  String get server => 'Serveur';

  @override
  String get serverDetailOrder => 'Ordre des widgets de la page de détails du serveur';

  @override
  String get serverFuncBtns => 'Boutons de fonction du serveur';

  @override
  String get serverOrder => 'Ordre du serveur';

  @override
  String get sftpDlPrepare => 'Préparation de la connexion...';

  @override
  String get sftpEditorTip => 'Si vide, utilisez l’éditeur de fichiers intégré de l’application. Si une valeur est présente, utilisez l’éditeur du serveur distant, par exemple `vim` (il est recommandé de détecter automatiquement selon `EDITOR`).';

  @override
  String get sftpRmrDirSummary => 'Utilisez `rm -r` pour supprimer un dossier en SFTP.';

  @override
  String get sftpSSHConnected => 'SFTP Connecté';

  @override
  String get sftpShowFoldersFirst => 'Afficher d\'abord les dossiers';

  @override
  String get showDistLogo => 'Afficher le logo de la distribution';

  @override
  String get shutdown => 'Éteindre';

  @override
  String get size => 'Taille';

  @override
  String get snippet => 'Extrait';

  @override
  String get softWrap => 'Retour à la ligne souple';

  @override
  String get specifyDev => 'Spécifier l\'appareil';

  @override
  String get specifyDevTip => 'Par exemple, les statistiques de trafic réseau concernent par défaut tous les appareils. Vous pouvez spécifier ici un appareil particulier.';

  @override
  String get speed => 'Vitesse';

  @override
  String spentTime(Object time) {
    return 'Temps écoulé : $time';
  }

  @override
  String get sshTermHelp => 'Lorsque le terminal est défilable, faire glisser horizontalement permet de sélectionner du texte. En cliquant sur le bouton du clavier, vous activez/désactivez le clavier. L\'icône de fichier ouvre le chemin actuel SFTP. Le bouton du presse-papiers copie le contenu lorsque du texte est sélectionné, et colle le contenu du presse-papiers dans le terminal lorsqu\'aucun texte n\'est sélectionné et qu\'il y a du contenu dans le presse-papiers. L\'icône de code colle des extraits de code dans le terminal et les exécute.';

  @override
  String sshTip(Object url) {
    return 'Cette fonctionnalité est actuellement à l\'étape expérimentale.\n\nVeuillez signaler les bugs sur $url ou rejoindre notre développement.';
  }

  @override
  String get sshVirtualKeyAutoOff => 'Activation automatique des touches virtuelles';

  @override
  String get start => 'Démarrer';

  @override
  String get stat => 'Statistiques';

  @override
  String get stats => 'Statistiques';

  @override
  String get stop => 'Arrêter';

  @override
  String get stopped => 'Arrêté';

  @override
  String get storage => 'Stockage';

  @override
  String get supportFmtArgs => 'Les paramètres de mise en forme suivants sont pris en charge :';

  @override
  String get suspend => 'Suspendre';

  @override
  String get suspendTip => 'La fonction de suspension nécessite des privilèges root et le support de systemd.';

  @override
  String switchTo(Object val) {
    return 'Passer à $val';
  }

  @override
  String get sync => 'Sync';

  @override
  String get syncTip => 'Un redémarrage peut être nécessaire pour que certains changements prennent effet.';

  @override
  String get system => 'Système';

  @override
  String get tag => 'Étiquettes';

  @override
  String get temperature => 'Température';

  @override
  String get termFontSizeTip => 'Ce paramètre affectera la taille du terminal (largeur et hauteur). Vous pouvez zoomer sur la page du terminal pour ajuster la taille de la police de la session en cours.';

  @override
  String get terminal => 'Terminal';

  @override
  String get test => 'Tester';

  @override
  String get textScaler => 'Mise à l\'échelle du texte';

  @override
  String get textScalerTip => '1.0 => 100% (taille originale), fonctionne uniquement sur la partie de la police de la page du serveur, il est déconseillé de la modifier.';

  @override
  String get theme => 'Thème';

  @override
  String get time => 'Temps';

  @override
  String get times => 'Fois';

  @override
  String get total => 'Total';

  @override
  String get traffic => 'Trafic';

  @override
  String get trySudo => 'Essayer d\'utiliser sudo';

  @override
  String get ttl => 'TTL';

  @override
  String get unknown => 'Inconnu';

  @override
  String get unkownConvertMode => 'Mode de conversion inconnu';

  @override
  String get update => 'Mettre à jour';

  @override
  String get updateIntervalEqual0 => 'Vous avez défini à 0, la mise à jour ne se fera pas automatiquement.\nImpossible de calculer l\'état du CPU.';

  @override
  String get updateServerStatusInterval => 'Intervalle de mise à jour de l\'état du serveur';

  @override
  String get upload => 'Télécharger';

  @override
  String get upsideDown => 'À l\'envers';

  @override
  String get uptime => 'Temps d\'activité';

  @override
  String get useCdn => 'Utiliser CDN';

  @override
  String get useCdnTip => 'Il est recommandé aux utilisateurs non chinois d\'utiliser le CDN. Souhaitez-vous l\'utiliser ?';

  @override
  String get useNoPwd => 'Aucun mot de passe ne sera utilisé';

  @override
  String get usePodmanByDefault => 'Par défaut avec Podman';

  @override
  String get used => 'Utilisé';

  @override
  String get view => 'Vue';

  @override
  String get viewErr => 'Voir erreur';

  @override
  String get virtKeyHelpClipboard => 'Copiez dans le presse-papiers si le terminal sélectionné n\'est pas vide, sinon collez le contenu du presse-papiers dans le terminal.';

  @override
  String get virtKeyHelpIME => 'Activer/désactiver le clavier';

  @override
  String get virtKeyHelpSFTP => 'Ouvrir le répertoire actuel en SFTP.';

  @override
  String get waitConnection => 'Veuillez attendre que la connexion soit établie.';

  @override
  String get wakeLock => 'Maintenir éveillé';

  @override
  String get watchNotPaired => 'Aucune Apple Watch associée';

  @override
  String get webdavSettingEmpty => 'Le paramètre Webdav est vide';

  @override
  String get whenOpenApp => 'À l\'ouverture de l\'application';

  @override
  String get wolTip => 'Après avoir configuré le WOL (Wake-on-LAN), une requête WOL est envoyée chaque fois que le serveur est connecté.';

  @override
  String get write => 'Écrire';

  @override
  String get writeScriptFailTip => 'Échec de l\'écriture dans le script, probablement en raison d\'un manque de permissions ou que le répertoire n\'existe pas.';

  @override
  String get writeScriptTip => 'Après la connexion au serveur, un script sera écrit dans ~/.config/server_box pour surveiller l’état du système. Vous pouvez examiner le contenu du script.';
}
