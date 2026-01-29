---
title: Gestion de l'état
description: Comment l'état est géré avec Riverpod
---

Comprendre l'architecture de gestion de l'état dans Flutter Server Box.

## Pourquoi Riverpod ?

**Avantages clés :**
- **Sécurité à la compilation** : Capture les erreurs lors de la compilation
- **Pas de BuildContext requis** : Accès à l'état n'importe où
- **Tests faciles** : Simple de tester les providers de manière isolée
- **Génération de code** : Moins de code répétitif, type-safe

## Architecture des Providers

```
┌─────────────────────────────────────────────┐
│         Couche UI (Widgets)                 │
│  - ConsumerWidget / ConsumerStatefulWidget  │
│  - ref.watch() / ref.read()                 │
└─────────────────────────────────────────────┘
                ↓ observe (watches)
┌─────────────────────────────────────────────┐
│         Couche Provider                     │
│  - Annotations @riverpod                    │
│  - Fichiers *.g.dart générés                │
└─────────────────────────────────────────────┘
                ↓ utilise (uses)
┌─────────────────────────────────────────────┐
│         Couche Service / Store              │
│  - Logique métier                           │
│  - Accès aux données                        │
└─────────────────────────────────────────────┘
```

## Types de Providers utilisés

### 1. StateProvider (État simple)

Pour un état simple et observable :

```dart
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  ThemeMode build() {
    // Charger depuis les paramètres
    return SettingStore.themeMode;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    SettingStore.themeMode = mode;  // Persister
  }
}
```

**Utilisation :**
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeNotifierProvider);
    return Text('Thème : $theme');
  }
}
```

### 2. AsyncNotifierProvider (État asynchrone)

Pour les données qui se chargent de manière asynchrone :

```dart
@riverpod
class ServerStatus extends _$ServerStatus {
  @override
  Future<StatusModel> build(Server server) async {
    // Chargement initial
    return await fetchStatus(server);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await fetchStatus(server);
    });
  }
}
```

**Utilisation :**
```dart
final status = ref.watch(serverStatusProvider(server));

status.when(
  data: (data) => StatusWidget(data),
  loading: () => LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
)
```

### 3. StreamProvider (Données en temps réel)

Pour les flux de données continus :

```dart
@riverpod
Stream<CpuUsage> cpuUsage(CpuUsageRef ref, Server server) {
  final client = ref.watch(sshClientProvider(server));
  final stream = client.monitorCpu();

  // Libération automatique des ressources quand non observé
  ref.onDispose(() {
    client.stopMonitoring();
  });

  return stream;
}
```

**Utilisation :**
```dart
final cpu = ref.watch(cpuUsageProvider(server));

cpu.when(
  data: (usage) => CpuChart(usage),
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => ErrorWidget(error),
)
```

### 4. Family Providers (Paramétrés)

Providers qui acceptent des paramètres :

```dart
@riverpod
Future<List<Container>> containers(ContainersRef ref, Server server) async {
  final client = await ref.watch(sshClientProvider(server).future);
  return await client.listContainers();
}
```

**Utilisation :**
```dart
final containers = ref.watch(containersProvider(server));

// Différents serveurs = différents états mis en cache
final containers2 = ref.watch(containersProvider(server2));
```

## Optimisations de performance

- **Provider Keep-Alive** : Utilisez `@Riverpod(keepAlive: true)` pour empêcher la destruction automatique quand il n'y a plus d'écouteurs.
- **Observation sélective** : Utilisez `select` pour n'observer qu'une partie spécifique de l'état.
- **Mise en cache des Providers** : Les Family providers mettent en cache les résultats par paramètre.

## Bonnes pratiques

1. **Co-localiser les providers** : Placez-les près des widgets qui les consomment.
2. **Utiliser la génération de code** : Utilisez toujours `@riverpod`.
3. **Garder les providers focalisés** : Responsabilité unique.
4. **Gérer les états de chargement** : Gérez toujours les états AsyncValue.
5. **Libérer les ressources** : Utilisez `ref.onDispose()` pour le nettoyage.
6. **Éviter les arbres de providers profonds** : Gardez le graphe des providers plat.
