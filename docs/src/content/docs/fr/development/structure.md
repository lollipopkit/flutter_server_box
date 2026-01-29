---
title: Structure du projet
description: Comprendre la base de code de Flutter Server Box
---

Le projet Flutter Server Box suit une architecture modulaire avec une séparation claire des préoccupations.

## Structure des répertoires

```
lib/
├── core/              # Utilitaires de base et extensions
├── data/              # Couche de données
│   ├── model/         # Modèles de données par fonctionnalité
│   ├── provider/      # Providers Riverpod
│   └── store/         # Stockage local (Hive)
├── view/              # Couche UI
│   ├── page/          # Pages principales
│   └── widget/        # Widgets réutilisables
├── generated/         # Localisation générée
├── l10n/              # Fichiers ARB de localisation
└── hive/              # Adaptateurs Hive
```

## Couche Core (`lib/core/`)

Contient les utilitaires, les extensions et la configuration du routage :

- **Extensions** : Extensions Dart pour les types courants
- **Routes** : Configuration du routage de l'application
- **Utils** : Fonctions utilitaires partagées

## Couche Données (`lib/data/`)

### Modèles (`lib/data/model/`)

Organisés par fonctionnalité :

- `server/` - Modèles de connexion et d'état du serveur
- `container/` - Modèles de conteneurs Docker
- `ssh/` - Modèles de session SSH
- `sftp/` - Modèles de fichiers SFTP
- `app/` - Modèles spécifiques à l'application

### Providers (`lib/data/provider/`)

Providers Riverpod pour l'injection de dépendances et la gestion de l'état :

- Providers de serveur
- Providers d'état de l'UI
- Providers de service

### Stores (`lib/data/store/`)

Stockage local basé sur Hive :

- Stockage des serveurs
- Stockage des paramètres
- Stockage du cache

## Couche Vue (`lib/view/`)

### Pages (`lib/view/page/`)

Écrans principaux de l'application :

- `server/` - Pages de gestion des serveurs
- `ssh/` - Pages de terminal SSH
- `container/` - Pages de conteneurs
- `setting/` - Pages de paramètres
- `storage/` - Pages SFTP
- `snippet/` - Pages d'extraits de code (snippets)

### Widgets (`lib/view/widget/`)

Composants UI réutilisables :

- Cartes de serveur
- Graphiques d'état
- Composants de saisie (input)
- Dialogues

## Fichiers générés

- `lib/generated/l10n/` - Localisation auto-générée
- `*.g.dart` - Code généré (json_serializable, freezed, hive, riverpod)
- `*.freezed.dart` - Classes immuables Freezed

## Répertoire Packages (`/packages/`)

Contient les forks personnalisés des dépendances :

- `dartssh2/` - Bibliothèque SSH
- `xterm/` - Émulateur de terminal
- `fl_lib/` - Utilitaires partagés
- `fl_build/` - Système de construction
