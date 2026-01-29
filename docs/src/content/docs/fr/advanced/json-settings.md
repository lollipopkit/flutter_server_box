---
title: Paramètres cachés (JSON)
description: Accéder aux paramètres avancés via l'éditeur JSON
---

Certains paramètres sont masqués de l'interface utilisateur mais accessibles via l'éditeur JSON.

## Accès

Appuyez longuement sur **Paramètres** dans le menu latéral pour ouvrir l'éditeur JSON.

## Paramètres cachés courants

### serverTabUseOldUI

Utiliser l'ancienne interface utilisateur pour l'onglet serveur.

```json
{"serverTabUseOldUI": true}
```

**Type :** booléen | **Par défaut :** false

### timeout

Délai d'attente de connexion en secondes.

```json
{"timeout": 10}
```

**Type :** entier | **Par défaut :** 5 | **Plage :** 1-60

### recordHistory

Enregistrer l'historique (chemins SFTP, etc.).

```json
{"recordHistory": true}
```

**Type :** booléen | **Par défaut :** true

### textFactor

Facteur de mise à l'échelle du texte.

```json
{"textFactor": 1.2}
```

**Type :** double | **Par défaut :** 1.0 | **Plage :** 0.8-1.5

## Trouver plus de paramètres

Tous les paramètres sont définis dans [`setting.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/store/setting.dart).

Recherchez :
```dart
late final settingName = StoreProperty(box, 'settingKey', defaultValue);
```

## ⚠️ Important

**Avant d'éditer :**
- **Créer une sauvegarde** - De mauvais paramètres peuvent empêcher l'ouverture de l'application
- **Éditer avec soin** - Le JSON doit être valide
- **Modifier un paramètre à la fois** - Testez chaque réglage

## Récupération

Si l'application ne s'ouvre plus après l'édition :
1. Effacer les données de l'application (dernier recours)
2. Réinstaller l'application
3. Restaurer à partir d'une sauvegarde
