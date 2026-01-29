---
title: Proxmox (PVE)
description: Gestion de l'environnement de virtualisation Proxmox VE
---

Flutter Server Box inclut le support pour la gestion de la plateforme de virtualisation Proxmox VE.

## Fonctionnalités

### Gestion des VM

- **Lister les VM** : Voir toutes les machines virtuelles
- **État des VM** : Vérifier les états en cours/arrêté
- **Actions VM** : Démarrer, arrêter, redémarrer les VM
- **Détails VM** : Voir la configuration et les ressources

### Gestion des Conteneurs (LXC)

- **Lister les conteneurs** : Voir tous les conteneurs LXC
- **État des conteneurs** : Surveiller l'état des conteneurs
- **Actions conteneurs** : Démarrer, arrêter, redémarrer les conteneurs
- **Accès console** : Accès terminal aux conteneurs

### Surveillance des Nœuds

- **Utilisation des ressources** : CPU, mémoire, disque, réseau
- **État du nœud** : Vérifier la santé du nœud
- **Vue Cluster** : Aperçu du cluster multi-nœuds

## Configuration

### Ajouter un serveur PVE

1. Ajoutez le serveur comme une connexion SSH normale
2. Assurez-vous que l'utilisateur a les permissions PVE
3. Accédez aux fonctionnalités PVE depuis la page de détails du serveur

### Permissions requises

L'utilisateur PVE a besoin de :

- **VM.Audit** : Voir l'état des VM
- **VM.PowerMgmt** : Démarrer/arrêter les VM
- **VM.Console** : Accès à la console

Exemple de configuration des permissions :

```bash
pveum useradd myuser -password mypass
pveum aclmod /vms -user myuser@pve -role VMAdmin
```

## Utilisation

### Gestion des VM

1. Ouvrez le serveur avec PVE
2. Appuyez sur le bouton **PVE**
3. Visualisez la liste des VM
4. Appuyez sur une VM pour les détails
5. Utilisez les boutons d'action pour la gestion

### Gestion des Conteneurs

1. Ouvrez le serveur avec PVE
2. Appuyez sur le bouton **PVE**
3. Allez sur l'onglet Conteneurs
4. Visualisez et gérez les conteneurs LXC

### Surveillance

- Utilisation des ressources en temps réel
- Graphiques de données historiques
- Support multi-nœuds

## Fonctionnalités par statut

### Implémenté

- Liste et état des VM
- Liste et état des conteneurs
- Opérations de base sur les VM (démarrage/arrêt/redémarrage)
- Surveillance des ressources

### Prévu

- Création de VM à partir de modèles
- Gestion des instantanés (snapshots)
- Accès console
- Gestion du stockage
- Configuration réseau

## Prérequis

- **Version PVE** : 6.x ou 7.x
- **Accès** : Accès SSH à l'hôte PVE
- **Permissions** : Rôles utilisateur PVE appropriés
- **Réseau** : Connectivité à l'API PVE (via SSH)

## Conseils

- Utilisez un **utilisateur PVE dédié** avec des permissions limitées
- Surveillez l'**utilisation des ressources** pour des performances optimales
- Vérifiez l'**état des VM** avant la maintenance
- Utilisez les **instantanés** avant des changements majeurs
