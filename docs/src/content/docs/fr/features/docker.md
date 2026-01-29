---
title: Gestion Docker
description: Surveiller et gérer les conteneurs Docker
---

Flutter Server Box fournit une interface intuitive pour gérer les conteneurs Docker sur vos serveurs.

## Fonctionnalités

### Liste des conteneurs

- Voir tous les conteneurs (en cours d'exécution et arrêtés)
- Affichage de l'ID et du nom du conteneur
- Informations sur l'image
- Indicateurs d'état
- Heure de création

### Actions sur les conteneurs

- **Démarrer** : Lancer les conteneurs arrêtés
- **Arrêter** : Arrêter proprement les conteneurs en cours d'exécution
- **Redémarrer** : Redémarrer les conteneurs
- **Supprimer** : Supprimer les conteneurs
- **Voir les logs** : Consulter les logs du conteneur
- **Inspecter** : Voir les détails du conteneur

### Détails du conteneur

- Variables d'environnement
- Mappages de ports
- Montages de volumes
- Configuration réseau
- Utilisation des ressources

## Prérequis

- Docker doit être installé sur votre serveur
- L'utilisateur SSH doit avoir les permissions Docker
- Pour les utilisateurs non-root, ajouter au groupe docker :
  ```bash
  sudo usermod -aG docker votre_nom_d_utilisateur
  ```

## Actions rapides

- Appui simple : Voir les détails du conteneur
- Appui long : Menu d'actions rapides
- Balayage : Démarrage/arrêt rapide
- Sélection groupée : Opérations sur plusieurs conteneurs

## Conseils

- Utilisez l'**actualisation automatique** pour surveiller les changements d'état des conteneurs
- Filtrer par conteneurs en cours d'exécution/arrêtés
- Rechercher des conteneurs par nom ou ID
