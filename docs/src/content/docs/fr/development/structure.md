---
title: Structure du projet
description: Comprendre la base de code de Server Box
---

Le projet Server Box suit une architecture modulaire avec une séparation claire des préoccupations.

## Disposition du monorepo

```
flutter_server_box/
├── lib/               # Application Flutter (voir ci-dessous)
├── crates/
│   ├── sbm_parser/    # Parseur d'état partagé (source unique de vérité,
│   │                  # app via FFI, monitor en dépendance directe)
│   ├── sbm_ffi/       # Crate de liaison flutter_rust_bridge + coquille
│   │                  # de plugin Flutter cargokit (même répertoire)
│   └── sbm_native/    # Échantillonnage natif par plateforme (monitor seul)
├── monitor/           # Monitor côté serveur (service Rust + frontend Svelte)
├── packages/          # Forks Dart vendorisés (dépendances par chemin), plus
│                      # webui : UI Svelte partagée par monitor et website
├── docs/              # Ce site de documentation (Astro Starlight)
├── website/           # Site du projet
└── Cargo.toml         # Racine du workspace Rust
```

## Structure des répertoires de l'app

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

Un répertoire ici n'est pas un fork Dart : `webui/` (`@serverbox/webui`) est un
paquet Svelte de primitives d'interface et de jetons de design partagés, utilisé
en dépendance `file:` par `monitor/frontend` et par `website/`.

## Côté Rust

- `crates/sbm_parser/` - Analyse la sortie brute des commandes en état de serveur structuré.
  Partagé par l'app (via FFI) et le monitor, les deux analysent donc toujours à l'identique.
- `crates/sbm_ffi/` - Fine enveloppe flutter_rust_bridge autour de `sbm_parser`.
  Le côté Dart généré se trouve dans `lib/src/rust/`.
- `crates/sbm_native/` - Échantillonnage natif par plateforme, utilisé uniquement
  par le monitor. Il lit cpu/mémoire/swap/disque/réseau/uptime directement via
  des appels système ou procfs, sans exécuter de commandes shell. L'app n'en
  dépend pas : elle collecte via SSH et ne peut pas exécuter d'appels système
  sur un hôte distant.
- `monitor/` - Service de surveillance autonome, documentation dans `monitor/README.md`.
