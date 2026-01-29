---
title: Widgets de l'écran d'accueil
description: Ajoutez des widgets d'état du serveur à votre écran d'accueil
---

Nécessite l'installation de [ServerBox Monitor](https://github.com/lollipopkit/server_box_monitor) sur vos serveurs.

## Prérequis

Installez d'abord ServerBox Monitor sur votre serveur. Consultez le [Wiki de ServerBox Monitor](https://github.com/lollipopkit/server_box_monitor/wiki/Home) pour les instructions de configuration.

Après l'installation, votre serveur doit avoir :
- Un point de terminaison HTTP/HTTPS
- Un point de terminaison API `/status`
- Une authentification facultative

## Format de l'URL

```
https://votre-serveur.com/status
```

Doit se terminer par `/status`.

## Widget iOS

### Configuration

1. Appuyez longuement sur l'écran d'accueil → Appuyez sur **+**
2. Recherchez "ServerBox"
3. Choisissez la taille du widget
4. Appuyez longuement sur le widget → **Modifier le widget**
5. Entrez l'URL se terminant par `/status`

### Notes

- Doit utiliser HTTPS (sauf pour les adresses IP locales)
- Taux de rafraîchissement maximal : 30 minutes (limite iOS)
- Ajoutez plusieurs widgets pour plusieurs serveurs

## Widget Android

### Configuration

1. Appuyez longuement sur l'écran d'accueil → **Widgets**
2. Trouvez "ServerBox" → Ajoutez à l'écran d'accueil
3. Notez le numéro d'ID du widget affiché
4. Ouvrez l'application ServerBox → Paramètres
5. Appuyez sur **Configurer le lien du widget d'accueil**
6. Ajoutez l'entrée : `Widget ID` = `URL d'état`

Exemple :
- Clé : `17`
- Valeur : `https://mon-serveur.com/status`

7. Appuyez sur le widget sur l'écran d'accueil pour le rafraîchir

## Widget watchOS

### Configuration

1. Ouvrez l'application iPhone → Paramètres
2. **Paramètres iOS** → **Application Watch**
3. Appuyez sur **Ajouter une URL**
4. Entrez l'URL se terminant par `/status`
5. Attendez que l'application de la montre se synchronise

### Notes

- Essayez de redémarrer l'application de la montre si elle ne se met pas à jour
- Vérifiez que le téléphone et la montre sont connectés

## Dépannage

### Le widget ne se met pas à jour

**iOS :** Attendez jusqu'à 30 minutes, puis supprimez et rajoutez-le.
**Android :** Appuyez sur le widget pour forcer le rafraîchissement, vérifiez l'ID dans les paramètres.
**watchOS :** Redémarrez l'application de la montre, attendez quelques minutes.

### Le widget affiche une erreur

- Vérifiez que ServerBox Monitor fonctionne
- Testez l'URL dans un navigateur
- Vérifiez que l'URL se termine par `/status`

## Sécurité

- **Utilisez toujours HTTPS** si possible
- **Adresses IP locales uniquement** sur les réseaux de confiance
