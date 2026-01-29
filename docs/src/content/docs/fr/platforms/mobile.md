---
title: Fonctionnalités mobiles
description: Fonctionnalités spécifiques à iOS et Android
---

Flutter Server Box offre plusieurs fonctionnalités spécifiques aux mobiles pour les appareils iOS et Android.

## Authentification biométrique

Sécurisez vos serveurs avec l'authentification biométrique :

- **iOS** : Face ID ou Touch ID
- **Android** : Authentification par empreinte digitale

Activez-la dans Paramètres > Sécurité > Authentification biométrique.

## Widgets de l'écran d'accueil

Ajoutez des widgets d'état du serveur à votre écran d'accueil pour une surveillance rapide.

### iOS

- Appui long sur l'écran d'accueil
- Appuyez sur **+** pour ajouter un widget
- Recherchez "Flutter Server Box"
- Choisissez la taille du widget :
  - Petit : État d'un seul serveur
  - Moyen : Plusieurs serveurs
  - Grand : Informations détaillées

### Android

- Appui long sur l'écran d'accueil
- Appuyez sur **Widgets**
- Trouvez "Flutter Server Box"
- Sélectionnez le type de widget

## Fonctionnement en arrière-plan

### Android

Maintenir les connexions actives en arrière-plan :

- Activer dans Paramètres > Avancé > Fonctionnement en arrière-plan
- Nécessite l'exclusion de l'optimisation de la batterie
- Notifications persistantes pour les connexions actives

### iOS

Des limitations en arrière-plan s'appliquent :

- Les connexions peuvent se mettre en pause en arrière-plan
- Reconnexion rapide au retour dans l'application
- Prise en charge de l'actualisation en arrière-plan

## Notifications Push

Recevez des notifications pour :

- Alertes de serveur hors ligne
- Avertissements d'utilisation élevée des ressources
- Alertes de fin de tâche

Configurez dans Paramètres > Notifications.

## Fonctionnalités de l'interface mobile

- **Tirer pour rafraîchir** : Mettre à jour l'état du serveur
- **Actions de glissement** : Opérations rapides sur le serveur
- **Mode paysage** : Meilleure expérience du terminal
- **Clavier virtuel** : Raccourcis pour le terminal

## Intégration de fichiers

- **Application Fichiers (iOS)** : Accès direct SFTP depuis Fichiers
- **Storage Access Framework (Android)** : Partager des fichiers avec d'autres applications
- **Sélecteur de documents** : Sélection de fichiers facile
