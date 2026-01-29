---
title: Gestión de Estado
description: Patrones de gestión de estado basados en Riverpod
---

Server Box utiliza Riverpod con generación de código para la gestión de estado.

## Tipos de Provider

### StateProvider

Estado simple que se puede leer y escribir:

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

Estado que se carga de forma asíncrona con estados de carga/error:

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

Datos en tiempo real desde flujos (streams):

```dart
@riverpod
Stream<CpuUsage> cpuUsage(CpuUsageRef ref, Server server) {
  return cpuService.monitor(server);
}
```

## Patrones de Estado

### Estados de Carga

```dart
state.when(
  data: (data) => DataWidget(data),
  loading: () => LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
)
```

### Family Providers

Providers parametrizados:

```dart
@riverpod
List<Container> containers(ContainersRef ref, Server server) {
  return containerService.list(server);
}
```

### Auto-Dispose

Providers que se eliminan cuando ya no están referenciados:

```dart
@Riverpod(keepAlive: false)
class TempState extends _$TempState {
  // ...
}
```

## Mejores Prácticas

1. **Usar generación de código**: Usa siempre la anotación `@riverpod`
2. **Co-localizar providers**: Ponlos cerca de los widgets que los consumen
3. **Evitar singletons**: Usa providers en su lugar
4. **Capas correctas**: Mantén la lógica de UI separada de la lógica de negocio

## Leer el Estado en Widgets

```dart
class ServerWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverStatusProvider(server));
    return status.when(...);
  }
}
```

## Modificar el Estado

```dart
ref.read(settingsProvider.notifier).update(newSettings);
```
