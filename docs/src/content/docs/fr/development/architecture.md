---
title: Architecture
description: Modèles d'architecture et décisions de conception
---

Server Box suit les principes de la Clean Architecture avec une séparation claire entre les couches de données, de domaine et de présentation.

## Architecture en couches

```
┌─────────────────────────────────────┐
│          Couche Présentation        │
│         (lib/view/page/)            │
│  - Pages, Widgets, Contrôleurs      │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│         Couche Logique Métier       │
│      (lib/data/provider/)           │
│  - Providers Riverpod               │
│  - Gestion de l'état                │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│           Couche Données            │
│      (lib/data/model/, store/)      │
│  - Modèles, Stockage, Services      │
└─────────────────────────────────────┘
```

## Modèles clés

### Gestion de l'état : Riverpod

- **Génération de code** : Utilise `riverpod_generator` pour des providers type-safe
- **State Notifiers** : Pour un état mutable avec une logique métier
- **Async Notifiers** : Pour les états de chargement et d'erreur
- **Stream Providers** : Pour les données en temps réel

### Modèles immuables : Freezed

- Tous les modèles de données utilisent Freezed pour l'immuabilité
- Types Union pour la représentation de l'état
- Sérialisation JSON intégrée
- Extensions CopyWith pour les mises à jour

### Stockage local : Hive

- **hive_ce** : Édition communautaire de Hive
- Pas de `@HiveField` ou `@HiveType` manuel requis
- Adaptateurs de type auto-générés
- Stockage clé-valeur persistant

## Injection de dépendances

Les services et les stores sont injectés via :

1. **Providers** : Exposer les dépendances à l'UI
2. **GetIt** : Localisation de services (le cas échéant)
3. **Injection par constructeur** : Dépendances explicites

## Flux de données

```
Action Utilisateur → Widget → Provider → Service/Store → Mise à jour Modèle → Reconstruction UI
```

1. L'utilisateur interagit avec le widget
2. Le widget appelle une méthode du provider
3. Le provider met à jour l'état via le service/store
4. Le changement d'état déclenche la reconstruction de l'UI
5. Le nouvel état est reflété dans le widget

## Dépendances personnalisées

Le projet utilise plusieurs forks personnalisés pour étendre les fonctionnalités :

- **dartssh2** : Fonctionnalités SSH améliorées
- **xterm** : Émulateur de terminal avec support mobile
- **fl_lib** : Composants UI et utilitaires partagés

## Threading (Multi-processus)

- **Isolates** : Calculs lourds hors du thread principal
- **paquet computer** : Utilitaires multi-threading
- **Async/Await** : Opérations d'E/S non bloquantes
