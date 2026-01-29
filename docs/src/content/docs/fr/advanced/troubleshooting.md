---
title: Problèmes courants
description: Solutions aux problèmes fréquents
---

## Problèmes de connexion

### SSH ne se connecte pas

**Symptômes :** Délai d'attente (timeout), connexion refusée, échec d'authentification

**Solutions :**

1. **Vérifier le type de serveur :** Seuls les systèmes de type Unix sont supportés (Linux, macOS, Android/Termux)
2. **Tester manuellement :** `ssh utilisateur@serveur -p port`
3. **Vérifier le pare-feu :** Le port 22 doit être ouvert
4. **Vérifier les identifiants :** Nom d'utilisateur et mot de passe/clé corrects

### Déconnexions fréquentes

**Symptômes :** Le terminal se déconnecte après une période d'inactivité

**Solutions :**

1. **Keep-alive du serveur :**
   ```bash
   # /etc/ssh/sshd_config
   ClientAliveInterval 60
   ClientAliveCountMax 3
   ```

2. **Désactiver l'optimisation de la batterie :**
   - MIUI : Batterie → "Pas de restrictions"
   - Android : Paramètres → Applications → Désactiver l'optimisation
   - iOS : Activer l'actualisation en arrière-plan

## Problèmes de saisie

### Impossible de taper certains caractères

**Solution :** Paramètres → Type de clavier → Passer à `visiblePassword`

Note : La saisie CJK (Chinois, Japonais, Coréen) peut ne pas fonctionner après ce changement.

## Problèmes de l'application

### L'application plante au démarrage

**Symptômes :** L'application ne s'ouvre pas, écran noir

**Causes :** Paramètres corrompus, particulièrement via l'éditeur JSON

**Solutions :**

1. **Effacer les données de l'application :**
   - Android : Paramètres → Applications → ServerBox → Effacer les données
   - iOS : Supprimer et réinstaller

2. **Restaurer une sauvegarde :** Importer une sauvegarde créée avant de modifier les paramètres

### Problèmes de sauvegarde/restauration

**La sauvegarde ne fonctionne pas :**
- Vérifier l'espace de stockage
- Vérifier que l'application a les permissions de stockage
- Essayer un autre emplacement

**La restauration échoue :**
- Vérifier l'intégrité du fichier de sauvegarde
- Vérifier la compatibilité de la version de l'application

## Problèmes de Widget

### Le widget ne se met pas à jour

**iOS :**
- Attendre jusqu'à 30 minutes pour le rafraîchissement automatique
- Supprimer et rajouter le widget
- Vérifier que l'URL se termine par `/status`

**Android :**
- Appuyer sur le widget pour forcer le rafraîchissement
- Vérifier que l'ID du widget correspond à la configuration dans les paramètres de l'application

**watchOS :**
- Redémarrer l'application sur la montre
- Attendre quelques minutes après un changement de configuration
- Vérifier le format de l'URL

### Le widget affiche une erreur

- Vérifier que ServerBox Monitor fonctionne sur le serveur
- Tester l'URL dans un navigateur
- Vérifier les identifiants d'authentification

## Problèmes de performance

### L'application est lente

**Solutions :**
- Réduire la fréquence de rafraîchissement dans les paramètres
- Vérifier la vitesse du réseau
- Désactiver les serveurs inutilisés

### Utilisation élevée de la batterie

**Solutions :**
- Augmenter les intervalles de rafraîchissement
- Désactiver le rafraîchissement en arrière-plan
- Fermer les sessions SSH inutilisées

## Obtenir de l'aide

Si les problèmes persistent :

1. **Rechercher dans les Issues GitHub :** https://github.com/lollipopkit/flutter_server_box/issues
2. **Créer une nouvelle Issue :** Inclure la version de l'application, la plateforme et les étapes pour reproduire le problème
3. **Consulter le Wiki :** Cette documentation et le Wiki GitHub
