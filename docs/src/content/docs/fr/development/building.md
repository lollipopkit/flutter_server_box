---
title: Construction (Building)
description: Instructions de construction pour différentes plateformes
---

Server Box utilise un système de construction personnalisé (`fl_build`) pour les constructions multiplateformes.

## Prérequis

- Flutter SDK (canal stable)
- Outils spécifiques à la plateforme (Xcode pour iOS, Android Studio pour Android)
- Chaîne d'outils Rust (requise : le parseur d'état est un crate Rust intégré à l'app via flutter_rust_bridge/cargokit sur chaque plateforme)

## Construction pour le développement

```bash
# Exécuter en mode développement
flutter run

# Exécuter sur un appareil spécifique
flutter run -d <id-appareil>
```

## Construction pour la production

Le projet utilise `fl_build` pour la construction :

```bash
# Construire pour une plateforme spécifique
dart run fl_build -p <plateforme>

# Plateformes disponibles :
# - ios
# - android
# - macos
# - linux
# - windows
```

## Constructions spécifiques aux plateformes

### iOS

```bash
dart run fl_build -p ios
```

Nécessite :
- macOS avec Xcode
- CocoaPods
- Compte Apple Developer pour la signature

### Android

```bash
dart run fl_build -p android
```

Nécessite :
- Android SDK
- Java Development Kit
- Keystore pour la signature

### macOS

```bash
dart run fl_build -p macos
```

### Linux

```bash
dart run fl_build -p linux
```

### Windows

```bash
dart run fl_build -p windows
```

Nécessite Windows avec Visual Studio.

## Construire le monitor

Le monitor côté serveur est un binaire distinct, construit depuis `monitor/`. Il
ne fait partie d'aucune construction de l'app.

```bash
cd monitor

# Backend
cargo build --release

# Panneau — servi par l'agent lui-même lorsque frontend/dist existe
cd frontend && npm install && npm run build
```

`make monitor-dev` à la racine du dépôt lance les deux en mode développement :
l'API sur `:3770` et le serveur de développement vite du panneau sur `:3000`.

Les artefacts de release proviennent du workflow `monitor-release.yml`, en
`workflow_dispatch` uniquement, qui publie des tags `monitor-v*` séparés des
releases de l'app. Docker se trouve dans `monitor/Dockerfile`.

## Pré/Post Construction

Le script `make.dart` gère :

- La génération des métadonnées
- Les mises à jour de la chaîne de version
- Les configurations spécifiques aux plateformes

## Dépannage

### Nettoyage de la construction (Clean Build)

```bash
flutter clean
dart run build_runner build --delete-conflicting-outputs
flutter pub get
```

### Incompatibilité de version

Assurez-vous que toutes les dépendances sont compatibles :
```bash
flutter pub upgrade
```

## Liste de contrôle de publication (Release Checklist)

1. Mettre à jour la version dans `pubspec.yaml`
2. Exécuter la génération de code
3. Exécuter les tests
4. Construire pour toutes les plateformes cibles
5. Tester sur des appareils physiques
6. Créer une version (release) GitHub
