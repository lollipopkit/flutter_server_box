---
title: Fonctionnalités mobiles
description: Fonctionnalités spécifiques à iOS et Android
---

Server Box offre plusieurs fonctionnalités spécifiques aux mobiles pour les appareils iOS et Android.

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
- Recherchez "Server Box"
- Choisissez la taille du widget :
  - Petit : État d'un seul serveur
  - Moyen : Plusieurs serveurs
  - Grand : Informations détaillées

### Android

- Appui long sur l'écran d'accueil
- Appuyez sur **Widgets**
- Trouvez "Server Box"
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

Les alertes serveur (hors ligne, seuil dépassé) sont envoyées par
[ServerBox Monitor](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor)
exécuté sur vos serveurs — les règles d’alerte et les canaux de push se configurent côté Monitor.

## Fonctionnalités de l'interface mobile

- **Tirer pour actualiser** : Mettre à jour l’état du serveur
- **Mode paysage** : Meilleure expérience du terminal
- **Clavier virtuel** : Raccourcis du terminal

## Intégration de fichiers

- **Sélecteur de documents** : Choisir des fichiers locaux pour l’envoi SFTP et l’import/export de sauvegardes
- **Partage** : Exporter des fichiers vers d’autres applications
