// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get acceptBeta => 'Accepter les mises à jour de la version de test';

  @override
  String get addSystemPrivateKeyTip =>
      'Actuellement, vous n\'avez aucune clé privée. Souhaitez-vous ajouter celle qui vient avec le système (~/.ssh/id_rsa) ?';

  @override
  String get added2List => 'Ajouté à la liste des tâches';

  @override
  String get askAi => 'Demander à l\'IA';

  @override
  String get askAiAwaitingResponse => 'En attente de la réponse de l\'IA...';

  @override
  String get askAiEndpointTip =>
      'Saisis une URL de base du service ou un point de terminaison complet Chat Completions ou Responses. ServerBox complète le chemin selon le protocole choisi.';

  @override
  String get askAiProtocolTip =>
      'Auto utilise Responses pour le point de terminaison officiel d\'OpenAI et Chat Completions pour les fournisseurs compatibles.';

  @override
  String get askAiProtocolChatCompletions => 'Chat Completions';

  @override
  String get askAiProtocolResponses => 'Responses';

  @override
  String get askAiCommandInserted => 'Commande insérée dans le terminal';

  @override
  String askAiConfigMissing(Object fields) {
    return 'Veuillez configurer $fields dans les paramètres.';
  }

  @override
  String get askAiDisclaimer =>
      'L\'IA peut se tromper. Utilisez-la avec prudence.';

  @override
  String get askAiInsertTerminal => 'Insérer dans le terminal';

  @override
  String get askAiNoResponse => 'Aucune réponse';

  @override
  String get askAiAgentTitle => 'Agent SSH';

  @override
  String get askAiAgentWelcome => 'Que faisons-nous sur ce serveur ?';

  @override
  String get askAiAgentWelcomeTip =>
      'Demande un diagnostic ou une tâche. L\'Agent propose une commande à la fois et attend ta relecture avant toute modification.';

  @override
  String get askAiAgentPromptHint =>
      'Demande à l\'Agent d\'inspecter ou de corriger quelque chose…';

  @override
  String get askAiAgentSend => 'Envoyer à l\'Agent';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Analyse le contenu du terminal sélectionné, explique ce qui s\'est passé et propose l\'étape suivante la plus sûre si une action est nécessaire.';

  @override
  String get askAiTerminalContext => 'Contexte du terminal';

  @override
  String get askAiReviewNeeded => 'À relire';

  @override
  String get askAiReviewAction => 'Relire la commande proposée';

  @override
  String get askAiReviewBeforeContinuing =>
      'Relis ou refuse d\'abord la commande proposée';

  @override
  String get askAiApproveRun => 'Approuver et exécuter';

  @override
  String get askAiDecline => 'Refuser';

  @override
  String get askAiActionDeclined => 'La commande proposée a été refusée.';

  @override
  String get askAiInterrupted => 'La réponse de l\'Agent a été interrompue.';

  @override
  String get askAiRiskReadOnly => 'Lecture seule';

  @override
  String get askAiRiskCaution => 'Modifie le système';

  @override
  String get askAiRiskUnvetted => 'Hôte non vérifié';

  @override
  String get askAiRiskDestructive => 'Risque élevé';

  @override
  String get askAiHighRiskConfirmTitle =>
      'Exécuter une commande à risque élevé ?';

  @override
  String get askAiHighRiskConfirmBody =>
      'Cette commande peut supprimer des données, arrêter des services ou être difficile à annuler. Relis-la attentivement avant de l\'exécuter.';

  @override
  String get askAiNoCommandOutput => 'La commande s\'est terminée sans sortie.';

  @override
  String get askAiOutputTruncated =>
      'La sortie longue a été tronquée avant d\'être renvoyée à l\'Agent.';

  @override
  String get askAiAutoApproved => 'Approuvée automatiquement';

  @override
  String get askAiAutoRunSafeCommands =>
      'Exécuter automatiquement les commandes en lecture seule';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Exécution automatique uniquement lorsque le modèle et les contrôles de sécurité locaux classent la commande en lecture seule. Les commandes qui modifient le système restent soumises à relecture.';

  @override
  String get askAiSendOnEnter => 'Entrée envoie';

  @override
  String get askAiSendOnEnterTip =>
      'Entrée envoie le message, Maj+Entrée insère un saut de ligne. Désactivé, c\'est l\'inverse : Entrée insère un saut de ligne et Cmd/Ctrl+Entrée envoie.';

  @override
  String get askAiApiKeyOptional =>
      'Facultatif pour les points de terminaison locaux ou sans authentification';

  @override
  String get askAiHistory => 'Historique des conversations';

  @override
  String get askAiNewConversation => 'Nouvelle conversation';

  @override
  String get askAiNoHistory =>
      'Aucune conversation enregistrée pour ce serveur';

  @override
  String get askAiNoHistoryMessages => 'Aucun message pour l\'instant';

  @override
  String get askAiUntitledConversation => 'Nouvelle conversation';

  @override
  String get askAiRenameConversation => 'Renommer la conversation';

  @override
  String get askAiDeleteConversationTitle => 'Supprimer cette conversation ?';

  @override
  String get askAiDeleteConversationTip =>
      'La conversation sera retirée de cet appareil, sans possibilité d\'annuler.';

  @override
  String get askAiClearHistoryTitle =>
      'Effacer l\'historique de l\'Agent pour ce serveur ?';

  @override
  String get askAiClearHistoryTip =>
      'Toutes les conversations de l\'Agent enregistrées pour ce serveur seront retirées de cet appareil.';

  @override
  String get askAiRestoredReview =>
      'Restaurée depuis l\'historique. Relis-la avant de l\'exécuter ; elle ne s\'exécutera jamais toute seule.';

  @override
  String get agentTitle => 'Agent';

  @override
  String get agentWelcome => 'Que faisons-nous sur tes serveurs ?';

  @override
  String get agentWelcomeTip =>
      'Demande un diagnostic ou une tâche d\'exploitation. L\'Agent s\'appuie sur l\'état actuel de ServerBox et propose une action relue à la fois.';

  @override
  String get agentPromptHint =>
      'Demande à l\'Agent d\'inspecter ou d\'administrer tes serveurs…';

  @override
  String get agentNoHistory =>
      'Aucune conversation globale de l\'Agent enregistrée';

  @override
  String get agentClearHistoryTitle =>
      'Effacer l\'historique global de l\'Agent ?';

  @override
  String get agentClearHistoryTip =>
      'Toutes les conversations globales de l\'Agent seront retirées de cet appareil.';

  @override
  String get agentToolShell => 'Shell';

  @override
  String get agentToolReadFile => 'Lire un fichier';

  @override
  String get agentToolWriteFile => 'Écrire un fichier';

  @override
  String get agentToolServerBox => 'ServerBox';

  @override
  String get agentToolFailed => 'Échec de l\'exécution de l\'outil.';

  @override
  String agentToolCallsFmt(Object count) {
    return '$count appels d\'outil';
  }

  @override
  String get agentFloat => 'Flotter au-dessus des autres onglets';

  @override
  String get agentToolSshConnect => 'Connexion SSH';

  @override
  String get agentToolSshDisconnect => 'Déconnecter le SSH';

  @override
  String get agentSshConnectTitle => 'Se connecter à un nouvel hôte';

  @override
  String get agentAuthMethod => 'Authentification';

  @override
  String get agentSshConnectTip =>
      'L\'Agent veut ouvrir une connexion SSH. Saisis le mot de passe ici, jamais dans la conversation, où il serait enregistré et envoyé au modèle.';

  @override
  String get agentAdHocSessions => 'Connexions temporaires';

  @override
  String get agentSaveServerTitle => 'Enregistrer comme serveur';

  @override
  String get agentSaveServerTip =>
      'Cet hôte et le mot de passe saisi seront enregistrés sur cet appareil.';

  @override
  String get agentMonitorOptional => 'Agent monitor (facultatif)';

  @override
  String get atLeastOneTab => 'Au moins un onglet doit être sélectionné';

  @override
  String get authFailTip =>
      'Échec de l\'authentification. Veuillez vérifier si le mot de passe/clé/hôte/utilisateur, etc., est incorrect.';

  @override
  String get autoBackupConflict =>
      'Un seul sauvegarde automatique peut être activé en même temps.';

  @override
  String get autoConnect => 'Connexion automatique';

  @override
  String get autoRun => 'Exécution automatique';

  @override
  String get autoUpdateHomeWidget =>
      'Mise à jour automatique du widget d\'accueil';

  @override
  String get availableTabs => 'Onglets disponibles';

  @override
  String get backupEncrypted => 'La sauvegarde est chiffrée';

  @override
  String get backupNotEncrypted => 'La sauvegarde n\'est pas chiffrée';

  @override
  String get backupPassword => 'Mot de passe de sauvegarde';

  @override
  String get backupPasswordRemoved => 'Mot de passe de sauvegarde supprimé';

  @override
  String get backupPasswordSet => 'Mot de passe de sauvegarde défini';

  @override
  String get backupPasswordTip =>
      'Définissez un mot de passe pour chiffrer les fichiers de sauvegarde. Laissez vide pour désactiver le chiffrement.';

  @override
  String get backupPasswordWrong => 'Mot de passe de sauvegarde incorrect';

  @override
  String get remoteBackupPasswordRequired =>
      'Les sauvegardes distantes nécessitent un mot de passe de sauvegarde non vide';

  @override
  String get monitorHttpsRequired =>
      'Les agents de surveillance distants nécessitent HTTPS ; HTTP n’est autorisé que sur l’interface de bouclage.';

  @override
  String get backupTip =>
      'Les données exportées peuvent être chiffrées avec un mot de passe. \nVeuillez les garder en sécurité.';

  @override
  String get icloudBackupStatusTitle => 'État de la sauvegarde';

  @override
  String get icloudBackupStatusLoading =>
      'Chargement de l\'état de la sauvegarde iCloud…';

  @override
  String get icloudBackupStatusError =>
      'Impossible de lire les métadonnées de la sauvegarde iCloud';

  @override
  String get icloudBackupStatusEmpty =>
      'Aucun fichier de sauvegarde iCloud trouvé pour l\'instant';

  @override
  String get icloudBackupStateUploading => 'Envoi en cours';

  @override
  String get icloudBackupStateConflict => 'Conflit détecté';

  @override
  String get icloudBackupStateUploaded => 'Envoyée';

  @override
  String get icloudBackupStateWaiting => 'En attente d\'iCloud';

  @override
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return 'Dernière sauvegarde : $lastModified\nÉtat : $remoteState';
  }

  @override
  String get bgRun => 'Exécution en arrière-plan';

  @override
  String get bgRunTip =>
      'Cette option signifie seulement que le programme essaiera de s\'exécuter en arrière-plan, que cela soit possible dépend de l\'autorisation activée ou non. Pour Android natif, veuillez désactiver l\'« Optimisation de la batterie » dans cette application, et pour MIUI, veuillez changer la politique d\'économie d\'énergie en « Illimité ».';

  @override
  String get clearAllStatsContent =>
      'Êtes-vous sûr de vouloir effacer toutes les statistiques de connexion des serveurs ? Cette action ne peut pas être annulée.';

  @override
  String get clearAllStatsTitle => 'Effacer toutes les statistiques';

  @override
  String clearServerStatsContent(Object serverName) {
    return 'Êtes-vous sûr de vouloir effacer les statistiques de connexion du serveur \"$serverName\" ? Cette action ne peut pas être annulée.';
  }

  @override
  String clearServerStatsTitle(Object serverName) {
    return 'Effacer les statistiques de $serverName';
  }

  @override
  String get clearThisServerStats => 'Effacer les statistiques de ce serveur';

  @override
  String get compactDatabase => 'Compacter la base de données';

  @override
  String compactDatabaseContent(Object size) {
    return 'Taille de la base de données : $size\n\nCela réorganisera la base de données pour réduire la taille du fichier. Aucune donnée ne sera supprimée.';
  }

  @override
  String get closeAfterSave => 'Enregistrer et fermer';

  @override
  String get collapseUITip =>
      'Indique si les longues listes présentées dans l\'interface utilisateur doivent être réduites par défaut.';

  @override
  String get connectionDetails => 'Détails de connexion';

  @override
  String get connectionStats => 'Statistiques de connexion';

  @override
  String get connectionStatsDesc =>
      'Voir le taux de réussite de connexion du serveur et l\'historique';

  @override
  String get containerTrySudoTip =>
      'Par exemple : Dans l\'application, l\'utilisateur est défini comme aaa, mais Docker est installé sous l\'utilisateur root. Dans ce cas, vous devez activer cette option.';

  @override
  String get containerSudoPasswordRequired =>
      'Un mot de passe sudo est requis pour accéder à Docker. Veuillez entrer votre mot de passe.';

  @override
  String get containerSudoPasswordIncorrect =>
      'Le mot de passe sudo est incorrect ou non autorisé. Veuillez réessayer.';

  @override
  String get copyPath => 'Copier le chemin';

  @override
  String get cpuViewAsProgressTip =>
      'Afficher le taux d\'utilisation de chaque CPU sous forme de barre de progression (ancien style)';

  @override
  String get customCmd => 'Commandes personnalisées';

  @override
  String get deleteServers => 'Supprimer des serveurs en lot';

  @override
  String get deleteDirRecursive => 'Supprimer le dossier et tout son contenu';

  @override
  String get desktopTerminalTip =>
      'Commande utilisée pour ouvrir l’émulateur de terminal lors du lancement de sessions SSH.';

  @override
  String get dirEmpty => 'Assurez-vous que le répertoire est vide.';

  @override
  String get discoverSshServers => 'Découvrir les serveurs SSH';

  @override
  String get discoveryFailed => 'Échec de la découverte';

  @override
  String get discoverySettings => 'Paramètres de découverte';

  @override
  String get diskHealth => 'Santé du disque';

  @override
  String get displayCpuIndex => 'Afficher l\'index CPU';

  @override
  String dl2Local(Object fileName) {
    return 'Télécharger $fileName localement ?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'Aucun conteneur en cours d\'exécution.\nCela peut être dû à :\n- L\'utilisateur d\'installation de Docker n\'est pas le même que celui configuré dans l\'application.\n- La variable d\'environnement DOCKER_HOST n\'a pas été lue correctement. Vous pouvez l\'obtenir en exécutant `echo \$DOCKER_HOST` dans le terminal.';

  @override
  String dockerImagesFmt(Object count) {
    return '$count images';
  }

  @override
  String get dockerProjectOther => 'Autres';

  @override
  String get dockerPruneTip =>
      'Supprimez les données inutilisées pour libérer de l\'espace disque';

  @override
  String get dockerStatistics => 'Statistiques Docker';

  @override
  String get doubleColumnMode => 'Mode double colonne';

  @override
  String get doubleColumnTip =>
      'Cette option n\'active que la fonctionnalité, qu\'elle puisse être activée dépend de la largeur de l\'appareil.';

  @override
  String get editVirtKeys => 'Modifier les touches virtuelles';

  @override
  String get editorHighlightTip =>
      'La performance actuelle de mise en surbrillance du code est pire et peut être désactivée en option pour s\'améliorer.';

  @override
  String get enableMdns => 'Activer mDNS';

  @override
  String get enableMdnsDesc =>
      'Utiliser mDNS/Bonjour pour découvrir les services SSH';

  @override
  String get envVars => 'Variable d’environnement';

  @override
  String get extraArgs => 'Arguments supplémentaires';

  @override
  String get fallbackSshDest => 'Destino SSH alternativo';

  @override
  String get fdroidReleaseTip =>
      'Si vous avez téléchargé cette application depuis F-Droid, il est recommandé de désactiver cette option.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'Fichier \'$file\' trop volumineux $size, max $sizeMax';
  }

  @override
  String get fileDirGone => 'Ce dossier n\'est plus là';

  @override
  String get fileDirGoneTip =>
      'Il a été supprimé ou renommé. Utilisez la barre du bas pour revenir en arrière, aller au dossier personnel ou vous rendre ailleurs.';

  @override
  String get fullScreen => 'Mode plein écran';

  @override
  String get fullScreenJitter => 'Secousse en plein écran';

  @override
  String get fullScreenJitterHelp => 'Pour éviter les brûlures d\'écran';

  @override
  String get fullScreenTip =>
      'Le mode plein écran doit-il être activé lorsque l\'appareil est orienté en mode paysage ? Cette option s\'applique uniquement à l\'onglet serveur.';

  @override
  String get githubGist => 'GitHub Gist';

  @override
  String get githubGistIdOptional => 'ID du Gist (facultatif)';

  @override
  String get githubGistToken => 'Jeton GitHub Gist';

  @override
  String get githubGistTokenEmpty => 'Le jeton est vide';

  @override
  String get goto => 'Aller à';

  @override
  String get homeTabs => 'Onglets d\'accueil';

  @override
  String get homeTabsCustomizeDesc =>
      'Personnalisez les onglets qui apparaissent sur la page d\'accueil et leur ordre';

  @override
  String get homeWidgetUrlConfig => 'Configurer l\'URL du widget d\'accueil';

  @override
  String get ignoreCert => 'Ignorer le certificat';

  @override
  String get image => 'Image';

  @override
  String get macDmgBody =>
      'L\'App Store impose que cette app tourne en bac à sable, et un processus en bac à sable ne peut pas ouvrir de pseudo-terminal. La version App Store n\'a donc pas de terminal sur ce Mac et ne peut y exécuter ni snippet ni commande d\'agent. La version DMG est la même app signée sans bac à sable, et en dispose.\n\nLa version App Store fonctionne toujours et reçoit toujours des mises à jour. Cela pourra cesser plus tard.\n\nLes deux versions rangent leurs données à des endroits différents. La version DMG les copie à son premier lancement : serveurs, clés et historique suivent. En cas d\'échec, elle le dit, et vous pouvez migrer avec un fichier de sauvegarde (Sauvegarde, dans les réglages).';

  @override
  String get macDmgImportDenied =>
      'macOS n\'a pas autorisé la lecture des données de la version précédemment installée. Accordez l\'accès complet au disque puis rouvrez l\'app, ou exportez-y une sauvegarde et restaurez-la ici.';

  @override
  String get macDmgImported =>
      'Données de la version précédemment installée importées.';

  @override
  String get macDmgImportFailed =>
      'Impossible de lire les données de la version précédemment installée. Exportez-y une sauvegarde, puis restaurez-la ici.';

  @override
  String get macDmgTip =>
      'Le terminal sur ce Mac et l\'exécution de snippets dessus n\'existent que dans la version DMG.';

  @override
  String get macDmgTitle => 'Version DMG';

  @override
  String get showHiddenFiles => 'Afficher les fichiers cachés';

  @override
  String get unused => 'Inutilisé';

  @override
  String get dangling => 'Fantôme';

  @override
  String get pruneUnusedImages => 'Nettoyer les images inutilisées';

  @override
  String get pruneDanglingImages => 'Nettoyer les images fantômes';

  @override
  String get pruneImages => 'Nettoyer les images';

  @override
  String get unusedTaggedImages => 'Étiquetées inutilisées';

  @override
  String get pruneDanglingImagesTip =>
      'Supprime uniquement les images fantômes (couches sans étiquette).';

  @override
  String get pruneUnusedImagesTip =>
      'Supprime aussi les images étiquetées qui ne sont utilisées par aucun conteneur.';

  @override
  String get includeUnusedVolumesTip =>
      'Supprime aussi les volumes utilisés par aucun conteneur.';

  @override
  String get pruneCommandPreview => 'Aperçu de la commande';

  @override
  String get pruneForceSshTip =>
      '-f ignore la confirmation interactive et reste toujours activé via SSH.';

  @override
  String get pruneVolumes => 'Nettoyer les volumes';

  @override
  String get pruneUnusedData => 'Nettoyer les données inutilisées';

  @override
  String get pull => 'Tirer';

  @override
  String get invalidHostFormat =>
      'Format d\'hôte non valide. Seuls les caractères IPv4, IPv6 et de domaine sont autorisés.';

  @override
  String get jumpServer => 'Aller au serveur';

  @override
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return 'Serveurs de rebond introuvables pour $serverName : $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(Object name) {
    return '« $name » existe déjà';
  }

  @override
  String get noJumpServerAvailable => 'Aucun serveur de rebond disponible.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Le serveur de rebond et ProxyCommand ne peuvent pas être utilisés ensemble.';

  @override
  String get keepForeground => 'Garder l\'application en premier plan !';

  @override
  String get keepStatusWhenErr => 'Conserver l\'état du dernier serveur';

  @override
  String get keepStatusWhenErrTip =>
      'Uniquement en cas d\'erreur lors de l\'exécution du script';

  @override
  String get keyAuth => 'Authentification par clé';

  @override
  String get lastFailure => 'Dernier échec';

  @override
  String get lastSuccess => 'Dernier succès';

  @override
  String get letterCache => 'Saisie clavier normale';

  @override
  String get letterCacheTip =>
      'Lorsqu\'elle est activée, la saisie passe par l\'IME normal, ce qui peut éviter les invites de clavier sécurisé dans le terminal sur certains systèmes.';

  @override
  String madeWithLove(Object myGithub) {
    return 'Fabriqué avec ❤️ par $myGithub';
  }

  @override
  String get maxConcurrency => 'Concurrence maximale';

  @override
  String get maxRetryCount => 'Nombre de reconnexions au serveur';

  @override
  String mismatchSystem(Object system) {
    return 'Système non correspondant : $system';
  }

  @override
  String get needRestart => 'Nécessite un redémarrage de l\'application';

  @override
  String get netViewType => 'Type de vue réseau';

  @override
  String get newContainer => 'Nouveau conteneur';

  @override
  String get noConnectionStatsData =>
      'Aucune donnée de statistiques de connexion';

  @override
  String get noLineChart => 'Ne pas utiliser de graphiques linéaires';

  @override
  String get noPrivateKeyTip =>
      'La clé privée n\'existe pas, elle a peut-être été supprimée ou il y a une erreur de configuration.';

  @override
  String get noPromptAgain => 'Ne pas demander à nouveau';

  @override
  String get onlyOneLine =>
      'Afficher uniquement en une seule ligne (défilement)';

  @override
  String get openLastPath => 'Ouvrir le dernier chemin';

  @override
  String get openLastPathTip =>
      'Les différents serveurs auront des journaux différents, et le journal est le chemin vers la sortie';

  @override
  String get parseContainerStatsTip =>
      'L\'analyse de l\'occupation des conteneurs Docker est relativement lente.';

  @override
  String get plugInType => 'Type d\'insertion';

  @override
  String get preferDiskAmount =>
      'Prioriser l’affichage de la capacité du disque';

  @override
  String get privateKey => 'Clé privée';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
    return 'Clé privée [$keyId] introuvable.';
  }

  @override
  String get bmcPowerOnAction => 'Allumer';

  @override
  String get bmcShutdown => 'Éteindre';

  @override
  String get bmcForceOff => 'Forcer l\'extinction';

  @override
  String get bmcRestart => 'Redémarrer';

  @override
  String get bmcPowerCycle => 'Cycle d\'alimentation';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return 'Envoyer ceci à $server ? Le service recevra « $resetType », ce qu\'il autorise pour cette action.';
  }

  @override
  String get bmcPowerDone => 'L\'état d\'alimentation a changé';

  @override
  String get bmcPowerAccepted =>
      'Accepté, mais l\'état d\'alimentation n\'a pas encore changé. Une opération propre dépend du système d\'exploitation, et certains services ne la distinguent pas.';

  @override
  String get bmcPowerUnsupported =>
      'Ce service n\'autorise rien pour cette action';

  @override
  String get bmcUnauthorized => 'Le BMC a refusé le compte';

  @override
  String get bmcPowerOn => 'Sous tension';

  @override
  String get bmcPowerOff => 'Hors tension';

  @override
  String get bmcCertRejected =>
      'Certificat refusé — vérifiez-le dans les réglages du serveur';

  @override
  String get bmcNotAService => 'Aucun service Redfish à cette adresse';

  @override
  String get bmcNoSystem => 'Le service ne signale aucun système';

  @override
  String get bmcSensorsTruncated => 'Seuls les premiers capteurs sont affichés';

  @override
  String get bmcTip =>
      'Le BMC est un ordinateur distinct sur la carte mère, joignable quand le système d\'exploitation de l\'hôte ne l\'est pas. Configuré ici, il rapporte l\'état d\'alimentation et les capteurs matériels pendant que le serveur est éteint ou bloqué. Nécessite Redfish, présent sur la plupart du matériel professionnel depuis environ 2016.';

  @override
  String get bmcCert => 'Certificat';

  @override
  String get bmcCertPinned => 'Vérifié et épinglé';

  @override
  String get bmcCertUnreviewed =>
      'Pas encore vérifié — touchez pour voir ce que présente le BMC';

  @override
  String get bmcCertReview =>
      'Les BMC utilisent des certificats auto-signés : rien ne garantit celui-ci. Comparez-le à ce qu\'affiche l\'interface web du BMC. Une fois accepté, seul ce certificat précis est approuvé.';

  @override
  String get bmcCertChanged =>
      'Ce n\'est pas le certificat accepté précédemment. Cela arrive quand le BMC régénère son certificat ou que son firmware est mis à jour — mais une interception aurait exactement la même apparence. Vérifiez avant d\'accepter.';

  @override
  String get bmcCertExpired =>
      'Ce certificat est hors de ses dates de validité.';

  @override
  String bmcCertWas(String fingerprint) {
    return 'Accepté précédemment : $fingerprint';
  }

  @override
  String get bmcAddrInvalid =>
      'L\'adresse du BMC doit être une URL, par ex. https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      'Cette version s\'exécute dans un bac à sable : la commande voit un dossier personnel vide au lieu du vôtre, donc tout ce qui lit ~/.ssh (ssh -W, cloudflared) échoue, souvent sous la forme d\'un délai d\'attente désignant le mauvais hôte. Les commandes qui n\'utilisent que le réseau fonctionnent toujours. La version DMG n\'a pas de bac à sable.';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return 'Impossible de lire le fichier de clé privée $path : $reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return 'Cette version ne peut pas lire les fichiers hors de son conteneur, la clé située à $path est donc inaccessible. Importez la clé dans les réglages, ou utilisez la version DMG.';
  }

  @override
  String get pushToken => 'Jeton d\'identification';

  @override
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand n\'est pris en charge que sur les plateformes de bureau.';

  @override
  String get pveIgnoreCertTip =>
      'Il n\'est pas recommandé de l\'activer, attention aux risques de sécurité ! Si vous utilisez le certificat par défaut de PVE, vous devez activer cette option.';

  @override
  String get pveServerClientMissing =>
      'Le client SSH de ce serveur n\'est pas disponible.';

  @override
  String get pveAddressMissing =>
      'L\'adresse PVE est manquante. Configure-la dans les réglages du serveur.';

  @override
  String get pvePasswordRequired =>
      'Le mot de passe PVE est requis. Renseigne-le dans les réglages du serveur.';

  @override
  String get pveOtpRequired =>
      'L\'authentification à deux facteurs est activée sur ce serveur PVE. Saisis le code OTP.';

  @override
  String get pveOtpChallengeExpired =>
      'Le défi OTP a expiré. Actualise et réessaie.';

  @override
  String get pveOtpCodeRequired => 'Le code OTP est requis.';

  @override
  String get pveOtpVerificationFailed =>
      'Échec de la vérification OTP. Réessaie avec un nouveau code.';

  @override
  String get pveOtpTitle => 'Vérification OTP';

  @override
  String get pveOtpLabel => 'Code OTP';

  @override
  String get pveInvalidResponseBody =>
      'La connexion PVE a renvoyé un corps de réponse non valide.';

  @override
  String get pveInvalidResponseData =>
      'La réponse de connexion PVE ne contenait pas de données valides.';

  @override
  String get pveMissingAuthTicket =>
      'La connexion PVE a réussi, mais aucun ticket d\'authentification n\'a été renvoyé.';

  @override
  String get pveVersionLow =>
      'Cette fonctionnalité est actuellement en phase de test et n\'a été testée que sur PVE 8+. Veuillez l\'utiliser avec prudence.';

  @override
  String get pveLoadingForwarding => 'Établissement du tunnel SSH…';

  @override
  String get pveLoadingLogin => 'Authentification auprès de PVE…';

  @override
  String get pveLoadingData => 'Récupération des données du cluster…';

  @override
  String get pveLoadingConnect => 'Connexion…';

  @override
  String get pvePassword => 'Mot de passe PVE';

  @override
  String get pvePasswordHint => 'Requis avec l\'authentification SSH par clé';

  @override
  String get read => 'Lire';

  @override
  String get recentConnections => 'Connexions récentes';

  @override
  String get rememberPwdInMem => 'Mémoriser le mot de passe en mémoire';

  @override
  String get rememberPwdInMemTip =>
      'Utilisé pour les conteneurs, la suspension, etc.';

  @override
  String get remotePath => 'Chemin distant';

  @override
  String rootfsUpdateTip(Object installed, Object latest) {
    return 'Alpine $installed est installé et $latest est disponible. La mise à jour le télécharge à nouveau et remplace le conteneur : tout ce qui y a été installé avec apk est perdu. Si vous l\'ignorez, le conteneur actuel continue de fonctionner.';
  }

  @override
  String get rootfsSubtitle => 'Un espace utilisateur Linux sur cet appareil';

  @override
  String rootfsInstallTip(Object version) {
    return 'Télécharge Alpine Linux $version (environ 3 Mo) et le décompresse sur cet appareil. Il donne à cette application un shell avec gestionnaire de paquets, et peut être supprimé à tout moment.';
  }

  @override
  String get sameIdServerExist => 'Un serveur avec le même ID existe déjà';

  @override
  String get second => 's';

  @override
  String get serverFilesUnavailableTip =>
      'Accessible via le SSH de ce serveur, ou via un agent monitor dont l\'API de fichiers est activée.';

  @override
  String get back => 'Retour';

  @override
  String get history => 'Historique';

  @override
  String get homeDir => 'Dossier personnel';

  @override
  String get selectItem => 'Sélectionner';

  @override
  String selected(Object count) {
    return '$count sélectionnés';
  }

  @override
  String get sendTo => 'Envoyer vers…';

  @override
  String get serverDetailOrder =>
      'Ordre des widgets de la page de détails du serveur';

  @override
  String get serverFuncBtns => 'Boutons de fonction du serveur';

  @override
  String get serverOrder => 'Ordre du serveur';

  @override
  String get serverTabRequired => 'L\'onglet serveur ne peut pas être supprimé';

  @override
  String get shareServerRiskTip =>
      'Ce QR code contient les paramètres de connexion du serveur en clair, mots de passe compris. Toute personne qui le scanne ou le photographie peut se connecter à ce serveur.';

  @override
  String get sftpDlPrepare => 'Préparation de la connexion...';

  @override
  String get sftpEditorTip =>
      'Si vide, utilisez l’éditeur de fichiers intégré de l’application. Si une valeur est présente, utilisez l’éditeur du serveur distant, par exemple `vim` (il est recommandé de détecter automatiquement selon `EDITOR`).';

  @override
  String get sftpRmrDirSummary =>
      'Utilisez `rm -r` pour supprimer un dossier en SFTP.';

  @override
  String get sftpSSHConnected => 'SFTP Connecté';

  @override
  String get sftp => 'SFTP';

  @override
  String get sftpShowFoldersFirst => 'Afficher d\'abord les dossiers';

  @override
  String get specifyDev => 'Spécifier l\'appareil';

  @override
  String get specifyDevTip =>
      'Par exemple, les statistiques de trafic réseau concernent par défaut tous les appareils. Vous pouvez spécifier ici un appareil particulier.';

  @override
  String get tempIsCelsiusTip =>
      'Une fois activé, la valeur de température est traitée en degrés Celsius et non en millicelsius. À n\'activer que si la température s\'affiche mal (par exemple 0,1 °C au lieu de 58 °C).';

  @override
  String spentTime(Object time) {
    return 'Temps écoulé : $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'Tous les serveurs existent déjà ($duplicateCount doublons trouvés)';
  }

  @override
  String get sshConnectionModeTip =>
      'Intégré : utiliser le terminal de l\'app. SSH système : lancer la commande ssh du système dans un terminal externe.';

  @override
  String get sshConnectionModeUseBuiltin => 'Utiliser le terminal intégré';

  @override
  String get sshConnectionModeUseSystem => 'Utiliser le SSH système';

  @override
  String sshConfigDuplicatesSkipped(Object duplicateCount) {
    return '$duplicateCount doublons seront ignorés';
  }

  @override
  String get sshConfigFound =>
      'Nous avons trouvé une configuration SSH sur votre système.';

  @override
  String sshConfigFoundServers(Object totalCount) {
    return '$totalCount serveurs trouvés';
  }

  @override
  String get sshConfigImport => 'Importation de configuration SSH';

  @override
  String get sshConfigImportPermission =>
      'Souhaitez-vous donner la permission de lire ~/.ssh/config et d\'importer automatiquement les paramètres du serveur ?';

  @override
  String get sshConfigImportTip =>
      'Proposer de lire ~/.ssh/config lors de la première création de serveur';

  @override
  String sshConfigImported(Object count) {
    return '$count serveurs importés depuis la configuration SSH';
  }

  @override
  String sshHostKeyChangedDesc(Object serverName) {
    return 'La clé d\'hôte SSH de $serverName a changé. Ne continuez que si vous faites confiance à ce serveur.';
  }

  @override
  String sshHostKeyFingerprintMd5Base64(Object fingerprint) {
    return 'Empreinte (MD5 Base64) : $fingerprint';
  }

  @override
  String sshHostKeyFingerprintMd5Hex(Object fingerprint) {
    return 'Empreinte (SHA256) : $fingerprint';
  }

  @override
  String get sshHostKeyType => 'Type de clé d\'hôte SSH';

  @override
  String get sshKnownHostKeys => 'Clés d\'hôte connues';

  @override
  String get sshKnownHostKeysTip =>
      'Clés d\'hôte acceptées par cette app. Supprimez-en une pour qu\'elle soit redemandée à la prochaine connexion.';

  @override
  String sshHostKeyNewDesc(Object serverName) {
    return 'Une nouvelle clé d\'hôte SSH a été reçue de $serverName. Vérifiez l\'empreinte avant de faire confiance.';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
    return 'Empreinte enregistrée : $fingerprint';
  }

  @override
  String get sshVerificationCode => 'Code de vérification';

  @override
  String get sshConfigManualSelect =>
      'Souhaitez-vous sélectionner manuellement le fichier de configuration SSH ?';

  @override
  String get sshConfigNoServers =>
      'Aucun serveur trouvé dans la configuration SSH';

  @override
  String get sshConfigPermissionDenied =>
      'Impossible d\'accéder au fichier de configuration SSH en raison des permissions macOS.';

  @override
  String sshConfigServersToImport(Object importCount) {
    return '$importCount serveurs seront importés';
  }

  @override
  String get sshTermHelp =>
      'Lorsque le terminal est défilable, faire glisser horizontalement permet de sélectionner du texte. En cliquant sur le bouton du clavier, vous activez/désactivez le clavier. L\'icône de fichier ouvre le chemin actuel SFTP. Le bouton du presse-papiers copie le contenu lorsque du texte est sélectionné, et colle le contenu du presse-papiers dans le terminal lorsqu\'aucun texte n\'est sélectionné et qu\'il y a du contenu dans le presse-papiers. L\'icône de code colle des extraits de code dans le terminal et les exécute.';

  @override
  String get sshVirtualKeyAutoOff =>
      'Activation automatique des touches virtuelles';

  @override
  String get supportFmtArgs =>
      'Les paramètres de mise en forme suivants sont pris en charge :';

  @override
  String get suspendTip =>
      'La fonction de suspension nécessite des privilèges root et le support de systemd.';

  @override
  String switchTo(Object val) {
    return 'Passer à $val';
  }

  @override
  String get syncAppSettings => 'Synchroniser les réglages de l\'app';

  @override
  String get syncAppSettingsTip =>
      'Inclure le thème, la disposition, l\'éditeur, le terminal et les autres préférences de l\'appareil dans la synchronisation automatique.';

  @override
  String get system => 'Système';

  @override
  String get termFontSizeTip =>
      'Ce paramètre affectera la taille du terminal (largeur et hauteur). Vous pouvez zoomer sur la page du terminal pour ajuster la taille de la police de la session en cours.';

  @override
  String get textScalerTip =>
      '1.0 => 100% (taille originale), fonctionne uniquement sur la partie de la police de la page du serveur, il est déconseillé de la modifier.';

  @override
  String get times => 'Fois';

  @override
  String get trySudo => 'Essayer d\'utiliser sudo';

  @override
  String get sudoPromptNotFound =>
      'Aucune invite de mot de passe sudo n\'est active.';

  @override
  String get updateServerStatusInterval =>
      'Intervalle de mise à jour de l\'état du serveur';

  @override
  String get useNoPwd => 'Aucun mot de passe ne sera utilisé';

  @override
  String get usePodmanByDefault => 'Par défaut avec Podman';

  @override
  String get used => 'Utilisé';

  @override
  String get view => 'Vue';

  @override
  String get viewDetails => 'Voir les détails';

  @override
  String get virtKeyHelpClipboard =>
      'Copiez dans le presse-papiers si le terminal sélectionné n\'est pas vide, sinon collez le contenu du presse-papiers dans le terminal.';

  @override
  String get virtKeyHelpIME => 'Activer/désactiver le clavier';

  @override
  String get virtKeyHelpSFTP => 'Ouvrir le répertoire actuel en SFTP.';

  @override
  String get waitConnection =>
      'Veuillez attendre que la connexion soit établie.';

  @override
  String get wakeLock => 'Maintenir éveillé';

  @override
  String get watchNotPaired => 'Aucune Apple Watch associée';

  @override
  String get webdavSettingEmpty => 'Le paramètre Webdav est vide';

  @override
  String get whenOpenApp => 'À l\'ouverture de l\'application';

  @override
  String get wolTip =>
      'Après avoir configuré le WOL (Wake-on-LAN), une requête WOL est envoyée chaque fois que le serveur est connecté.';

  @override
  String get write => 'Écrire';

  @override
  String get writeScriptFailTip =>
      'Échec de l\'écriture dans le script, probablement en raison d\'un manque de permissions ou que le répertoire n\'existe pas.';

  @override
  String get writeScriptTip =>
      'Après la connexion au serveur, un script sera écrit dans `~/.config/server_box` \n | `/tmp/server_box` pour surveiller l\'état du système. Vous pouvez examiner le contenu du script.';

  @override
  String get menuGitHubRepository => 'Dépôt GitHub';

  @override
  String get podmanDockerEmulationDetected =>
      'Émulation Podman Docker détectée. Veuillez passer à Podman dans les paramètres.';

  @override
  String get portForwardBeta =>
      'Cette fonctionnalité est encore en bêta. Son fonctionnement n\'est pas garanti.';

  @override
  String get portForward_startPrompt =>
      'Ajoute une règle de redirection de port pour commencer';

  @override
  String get portForward_localHost => 'Hôte local';

  @override
  String get portForward_localPort => 'Port local';

  @override
  String get portForward_remoteHost => 'Hôte distant';

  @override
  String get portForward_remotePort => 'Port distant';

  @override
  String portForward_deleteConfirmFmt(Object name) {
    return 'Supprimer $name ?';
  }

  @override
  String get sponsor => 'Soutenir';

  @override
  String get sortByJoinTime => 'Par date d\'ajout';

  @override
  String get serverHistory => 'Historique du serveur';

  @override
  String get portForwardBetaTitle => 'Transfert de port (Beta)';

  @override
  String get tmuxAutoAttach => 'Rattachement auto à tmux';

  @override
  String get tmuxAuto => 'tmux auto';

  @override
  String get tmuxAutoTip =>
      'Démarrer ou rattacher tmux automatiquement lors d\'une connexion SSH';

  @override
  String get tmuxSessionSelector => 'Sélecteur de session';

  @override
  String get tmuxSessionSelectorTip =>
      'Afficher le sélecteur de session à la connexion';

  @override
  String get tmuxDefaultSessionName => 'Nom de session par défaut';

  @override
  String get tmuxSessionName => 'Nom de la session';

  @override
  String get tmuxExistingSessions => 'Sessions existantes';

  @override
  String get tmuxNewSession => 'Nouvelle session';

  @override
  String get tmuxWindows => 'Fenêtres';

  @override
  String get tmuxNewWindow => 'Nouvelle fenêtre';

  @override
  String get tmuxNoWindowsFound => 'Aucune fenêtre trouvée';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fenêtres',
      one: '1 fenêtre',
    );
    return '$_temp0';
  }

  @override
  String tmuxPaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count panneaux',
      one: '1 panneau',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Rattachée';

  @override
  String get tmuxActive => 'Active';

  @override
  String tmuxActiveAt(String time) {
    return 'active : $time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return 'rattachée : $time';
  }

  @override
  String get tmuxSkip => 'Ignorer';

  @override
  String get tmuxNotAvailable => 'tmux n\'est pas disponible';

  @override
  String containerSegmentsMismatch(int count) {
    return 'Nombre inattendu de segments dans la réponse du conteneur : $count';
  }

  @override
  String get containerOperationInProgress =>
      'Une autre opération sur les conteneurs est déjà en cours';

  @override
  String get systemd => 'Systemd';

  @override
  String processCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count processus',
      one: '1 processus',
      zero: '0 processus',
    );
    return '$_temp0';
  }

  @override
  String get processParseUnsupportedOutput =>
      'Le format de la liste des processus n’est pas pris en charge.';

  @override
  String get processParseInvalidRows =>
      'Certaines entrées de processus n’ont pas pu être lues.';

  @override
  String get processParseInvalidWindowsJson =>
      'La réponse des processus Windows n’a pas pu être lue.';

  @override
  String get processParseInvalidWindowsRows =>
      'Certaines entrées de processus Windows n’ont pas pu être lues.';

  @override
  String get processKillTargetChanged =>
      'Le processus a changé ou s’est terminé. Actualisez la liste et réessayez.';

  @override
  String get watchServers => 'Serveurs sur la montre';

  @override
  String get watchServersTip =>
      'La montre interroge elle-même l\'agent monitor de ces serveurs ; seuls les serveurs dotés d\'un monitor peuvent donc être sélectionnés.';

  @override
  String get watchNoMonitorServer =>
      'Aucun serveur n\'a d\'agent monitor configuré';

  @override
  String get watchLegacyUrls => 'Anciennes URL de statut';

  @override
  String get accessoryWidgetServer => 'Serveur du widget d\'écran verrouillé';

  @override
  String get systemdMissing => 'Pas de systemd sur ce serveur';

  @override
  String get systemdMissingTip =>
      '`systemctl` n\'est pas installé ici, il n\'y a donc aucune unité à lister.';

  @override
  String initSystemFmt(String init) {
    return 'Cette machine semble utiliser $init.';
  }

  @override
  String get systemdListFailed => 'Impossible de lister les unités';

  @override
  String get systemdUserScopeMissing =>
      'Les unités utilisateur ne sont pas listées';

  @override
  String get systemdUserScopeMissingTip =>
      'Ce compte n\'a pas de bus de session utilisateur sur le serveur, seules les unités système sont affichées.';

  @override
  String get serverUnreachable =>
      'Impossible d\'exécuter une commande sur ce serveur';

  @override
  String get containerNoRuntime =>
      'Aucun environnement d\'exécution de conteneurs ici';

  @override
  String get containerNoRuntimeTip =>
      'Ni `docker` ni `podman` n\'a répondu sur cette machine. Si l\'un d\'eux est installé pour un autre compte, activez « Essayer d\'utiliser sudo » dans les réglages.';

  @override
  String get containerUnreadable =>
      'L\'environnement d\'exécution de conteneurs a répondu dans un format inattendu';

  @override
  String get power => 'Alimentation';

  @override
  String get continueInTerminal => 'Continuer dans le terminal';

  @override
  String get askAiRiskUnknown => 'Non classé';

  @override
  String get agentLocalExec => 'Exécuter des commandes sur cet appareil';

  @override
  String get agentLocalExecTip =>
      'Permet à l\'Agent de travailler sur la machine qui exécute ServerBox, pas seulement sur des serveurs. Rien ne s\'exécute sans surveillance ici : chaque commande doit être vérifiée.';

  @override
  String get agentLocalExecRootfsTip =>
      'Permet à l\'Agent de travailler sur cet appareil, à l\'intérieur du conteneur Alpine Linux installé par ServerBox. Il ne voit ni le système de fichiers du téléphone, ni les données de l\'application, ni vos fichiers. Chaque commande doit toujours être vérifiée.';

  @override
  String macDmgImportedPartly(String path) {
    return 'Les données de la version précédemment installée ont été importées. Les fichiers téléchargés sont restés dans $path.';
  }
}
