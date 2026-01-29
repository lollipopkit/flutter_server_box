---
title: Zustandsverwaltung
description: Riverpod-basierte Zustandsverwaltungsmuster
---

Flutter Server Box verwendet Riverpod mit Codegenerierung für die Zustandsverwaltung.

## Provider-Typen

### StateProvider

Einfacher Zustand, der gelesen und geschrieben werden kann:

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

Zustand, der asynchron mit Lade-/Fehlerzuständen geladen wird:

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

Echtzeitdaten aus Streams:

```dart
@riverpod
Stream<CpuUsage> cpuUsage(CpuUsageRef ref, Server server) {
  return cpuService.monitor(server);
}
```

## Zustandsmuster

### Ladezustände

```dart
state.when(
  data: (data) => DataWidget(data),
  loading: () => LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
)
```

### Family Provider

Parametrisierte Provider:

```dart
@riverpod
List<Container> containers(ContainersRef ref, Server server) {
  return containerService.list(server);
}
```

### Auto-Dispose

Provider, die verworfen werden, wenn sie nicht mehr referenziert werden:

```dart
@Riverpod(keepAlive: false)
class TempState extends _$TempState {
  // ...
}
```

## Best Practices

1. **Codegenerierung nutzen**: Immer die `@riverpod` Annotation verwenden.
2. **Provider lokal platzieren**: In der Nähe der Widgets platzieren, die sie nutzen.
3. **Singletons vermeiden**: Stattdessen Provider verwenden.
4. **Korrekt schichten**: UI-Logik von Business-Logik getrennt halten.

## Zustand in Widgets lesen

```dart
class ServerWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverStatusProvider(server));
    return status.when(...);
  }
}
```

## Zustand ändern

```dart
ref.read(settingsProvider.notifier).update(newSettings);
```
