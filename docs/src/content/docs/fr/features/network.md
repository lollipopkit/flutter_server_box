---
title: Outils réseau
description: Outils de test et de diagnostic réseau
---

Server Box comprend plusieurs outils réseau pour les tests et diagnostics.

## iPerf

Effectuez des tests de vitesse réseau entre votre appareil et le serveur.

### Fonctionnalités

- **Vitesse d'envoi/téléchargement** : Tester la bande passante
- **Mode Serveur** : Utiliser le serveur comme serveur iPerf
- **Mode Client** : Se connecter aux serveurs iPerf
- **Paramètres personnalisés** : Durée, flux parallèles, etc.

### Utilisation

1. Ouvrez un serveur
2. Appuyez sur **iPerf**
3. Choisissez le mode serveur ou client
4. Configurez les paramètres
5. Démarrez le test

## Ping

Tester la connectivité réseau et la latence.

### Fonctionnalités

- **Ping ICMP** : Outil ping standard
- **Nombre de paquets** : Spécifier le nombre de paquets
- **Taille des paquets** : Taille de paquet personnalisée
- **Intervalle** : Temps entre les pings

### Utilisation

1. Ouvrez un serveur
2. Appuyez sur **Ping**
3. Entrez l'hôte cible
4. Configurez les paramètres
5. Commencez à pinger

## Wake on LAN

Réveillez des serveurs distants via un paquet magique.

### Fonctionnalités

- **Adresse MAC** : MAC de l'appareil cible
- **Diffusion** : Envoyer un paquet magique de diffusion (broadcast)
- **Profils enregistrés** : Stocker les configurations WoL

### Prérequis

- L'appareil cible doit prendre en charge le Wake-on-LAN
- Le WoL doit être activé dans le BIOS/UEFI
- L'appareil doit être en veille ou à l'arrêt logiciel
- L'appareil doit être sur le même réseau ou accessible via diffusion

## Conseils

- Utilisez iPerf pour diagnostiquer les goulots d'étranglement du réseau
- Pinguez plusieurs hôtes pour comparer la latence
- Enregistrez des profils WoL pour les appareils fréquemment réveillés
