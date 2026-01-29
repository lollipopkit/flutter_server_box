---
title: Gestion de l'état
description: Modèles de gestion de l'état basés sur Riverpod
---

Flutter Server Box utilise Riverpod avec la génération de code pour la gestion de l'état.

## Types de Provider

### StateProvider

État simple qui peut être lu et écrit :

```dart
@riverpod
class Settings extends _$Settings {
  @override
  SettingsModel build() {
    return SettingsModel.defaults();
  }

  void update(SettingsModel newSettings) {
    state = newSettings;
  }
}
```

### AsyncNotifierProvider

État qui se charge de manière asynchrone avec des états de chargement/erreur :

```dart
@riverpod
class ServerStatus extends _$ServerStatus {
  @override
  Future<StatusModel> build(Server server) async {
    return fetchStatus(server);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => fetchStatus(server));
  }
}
```

### StreamProvider

Données en temps réel provenant de flux (streams) :

```dart
@riverpod
Stream<CpuUsage> cpuUsage(CpuUsageRef ref, Server server) {
  return cpuService.monitor(server);
}
```

## Modèles d'état

### États de chargement

```dart
state.when(
  data: (data) => DataWidget(data),
  loading: () => LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
)
```

### Family Providers

Providers paramétrés :

```dart
@riverpod
List<Container> containers(ContainersRef ref, Server server) {
  return containerService.list(server);
}
```

### Auto-Dispose

Providers qui se détruisent lorsqu'ils ne sont plus référencés :

```dart
@Riverpod(keepAlive: false)
class TempState extends _$TempState {
  // ...
}
```

## Bonnes pratiques

1. **Utiliser la génération de code** : Utilisez toujours l'annotation `@riverpod`
2. **Co-localiser les providers** : Placez-les près des widgets qui les consomment
3. **Éviter les singletons** : Utilisez des providers à la place
4. **Couches correctes** : Gardez la logique UI séparée de la logique métier

## Lire l'état dans les Widgets

```dart
class ServerWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverStatusProvider(server));
    return status.when(...);
  }
}
```

## Modifier l'état

```dart
ref.read(settingsProvider.notifier).update(newSettings);
```
