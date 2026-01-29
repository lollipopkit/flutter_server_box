---
title: Présentation de l'architecture
description: Architecture de haut niveau de l'application
---

Flutter Server Box suit une architecture en couches avec une séparation claire des préoccupations.

## Couches architecturales

```
┌─────────────────────────────────────────────────┐
│          Couche de présentation (UI)            │
│          lib/view/page/, lib/view/widget/       │
│  - Pages, Widgets, Contrôleurs                   │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│         Couche logique métier                   │
│         lib/data/provider/                      │
│  - Riverpod Providers, State Notifiers          │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│           Couche d'accès aux données            │
│         lib/data/store/, lib/data/model/        │
│  - Hive Stores, Modèles de données              │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│         Couche d'intégration externe            │
│  - SSH (dartssh2), Terminal (xterm), SFTP       │
│  - Code spécifique à la plateforme (iOS, etc.)  │
└─────────────────────────────────────────────────┘
```

## Fondations de l'application

### Point d'entrée principal

`lib/main.dart` initialise l'application :

```dart
void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### Widget racine

`MyApp` fournit :
- **Gestion des thèmes** : Commutation entre thèmes clair/sombre
- **Configuration du routage** : Structure de navigation
- **Provider Scope** : Racine de l'injection de dépendances

### Page d'accueil

`HomePage` sert de plaque tournante pour la navigation :
- **Interface par onglets** : Serveur, Snippet, Conteneur, SSH
- **Gestion de l'état** : État par onglet
- **Navigation** : Accès aux fonctionnalités

## Systèmes de base

### Gestion de l'état : Riverpod

**Pourquoi Riverpod ?**
- Sécurité au moment de la compilation
- Tests faciles
- Pas de dépendance au Build context
- Fonctionne sur toutes les plateformes

**Types de Provider utilisés :**
- `StateProvider` : État mutable simple
- `AsyncNotifierProvider` : États de chargement/erreur/données
- `StreamProvider` : Flux de données en temps réel
- Future providers : Opérations asynchrones uniques

### Persistance des données : Hive CE

**Pourquoi Hive CE ?**
- Pas de dépendances de code natif
- Stockage clé-valeur rapide
- Type-safe avec génération de code
- Pas d'annotations de champs manuelles requises

**Stores :**
- `SettingStore` : Préférences de l'application
- `ServerStore` : Configurations de serveur
- `SnippetStore` : Extraits de commande
- `KeyStore` : Clés SSH

### Modèles immuables : Freezed

**Avantages :**
- Immuabilité au moment de la compilation
- Types Union pour l'état
- Sérialisation JSON intégrée
- Extensions CopyWith

## Stratégie multiplateforme

### Système de plugins

Les plugins Flutter permettent l'intégration avec les plateformes :

| Plateforme | Méthode d'intégration |
|------------|----------------------|
| iOS | CocoaPods, Swift/Obj-C |
| Android | Gradle, Kotlin/Java |
| macOS | CocoaPods, Swift |
| Linux | CMake, C++ |
| Windows | CMake, C# |

### Fonctionnalités spécifiques aux plateformes

**iOS uniquement :**
- Widgets de l'écran d'accueil
- Activités en direct (Live Activities)
- Compagnon Apple Watch

**Android uniquement :**
- Service en arrière-plan
- Notifications push
- Accès au système de fichiers

**Bureau uniquement :**
- Intégration de la barre de menus
- Fenêtres multiples
- Barre de titre personnalisée

## Dépendances personnalisées

### Fork de dartssh2

Client SSH amélioré avec :
- Meilleur support mobile
- Gestion des erreurs améliorée
- Optimisations de performance

### Fork de xterm.dart

Émulateur de terminal avec :
- Rendu optimisé pour le mobile
- Support des gestes tactiles
- Intégration du clavier virtuel

### fl_lib

Paquet d'utilitaires partagés avec :
- Widgets communs
- Extensions
- Fonctions d'aide

## Système de construction

### Paquet fl_build

Système de construction personnalisé pour :
- Constructions multiplateformes
- Signature de code
- Regroupement des ressources (assets)
- Gestion des versions

### Processus de construction

```
make.dart (version) → fl_build (build) → Sortie plateforme
```

1. **Pré-construction** : Calculer la version à partir de Git
2. **Construction** : Compiler pour la plateforme cible
3. **Post-construction** : Paqueter et signer

## Exemple de flux de données

### Mise à jour de l'état du serveur

```
1. Le minuteur se déclenche →
2. Le Provider appelle le service →
3. Le service exécute la commande SSH →
4. La réponse est analysée en modèle →
5. L'état est mis à jour →
6. L'UI se reconstruit avec les nouvelles données
```

### Flux d'action utilisateur

```
1. L'utilisateur appuie sur un bouton →
2. Le Widget appelle une méthode du provider →
3. Le Provider met à jour l'état →
4. Le changement d'état déclenche la reconstruction →
5. Le nouvel état est reflété dans l'UI
```

## Architecture de sécurité

### Protection des données

- **Mots de passe** : Chiffrés avec flutter_secure_storage
- **Clés SSH** : Chiffrées au repos
- **Empreintes d'hôte** : Stockées de manière sécurisée
- **Données de session** : Non persistées

### Sécurité de la connexion

- **Vérification de la clé d'hôte** : Détection MITM (homme du milieu)
- **Chiffrement** : Chiffrement SSH standard
- **Pas de texte clair** : Les données sensibles ne sont jamais stockées en clair
