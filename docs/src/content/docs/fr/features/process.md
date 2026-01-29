---
title: Processus et Services
description: Surveiller les processus et gérer les services systemd
---

## Gestion des processus

Visualisez et gérez les processus en cours d'exécution sur vos serveurs.

### Liste des processus

- Tous les processus en cours avec détails
- PID (ID du processus)
- Utilisation du processeur (CPU) et de la mémoire
- Propriétaire (utilisateur)
- Commande du processus

### Actions sur les processus

- **Tuer (Kill)** : Mettre fin aux processus
- **Filtrer** : Par nom ou utilisateur
- **Trier** : Par CPU, mémoire ou PID
- **Rechercher** : Trouver des processus spécifiques

## Services Systemd

Gérez les services systemd pour le contrôle des services.

### Liste des services

- Tous les services systemd
- État actif/inactif
- État activé/désactivé
- Description du service

### Actions sur les services

- **Démarrer** : Lancer un service arrêté
- **Arrêter** : Arrêter un service en cours d'exécution
- **Redémarrer** : Redémarrer un service
- **Activer** : Activer le démarrage automatique au boot
- **Désactiver** : Désactiver le démarrage automatique
- **Voir le statut** : Consulter l'état du service et les logs
- **Recharger** : Recharger la configuration du service

## Prérequis

- L'utilisateur SSH doit avoir les permissions appropriées
- Pour la gestion des services : un accès `sudo` peut être requis
- Visualisation des processus : les permissions utilisateur standard sont généralement suffisantes

## Conseils

- Utilisez la liste des processus pour identifier les gourmands en ressources
- Consultez les logs des services pour le dépannage
- Surveillez les services critiques avec l'actualisation automatique
