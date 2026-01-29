---
title: State Management
description: Riverpod-based state management patterns
---

Server Box uses Riverpod with code generation for state management.

## Provider Types

### StateProvider

Simple state that can be read and written:

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

State that loads asynchronously with loading/error states:

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

Real-time data from streams:

```dart
@riverpod
Stream<CpuUsage> cpuUsage(CpuUsageRef ref, Server server) {
  return cpuService.monitor(server);
}
```

## State Patterns

### Loading States

```dart
state.when(
  data: (data) => DataWidget(data),
  loading: () => LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
)
```

### Family Providers

Parameterized providers:

```dart
@riverpod
List<Container> containers(ContainersRef ref, Server server) {
  return containerService.list(server);
}
```

### Auto-Dispose

Providers that dispose when no longer referenced:

```dart
@Riverpod(keepAlive: false)
class TempState extends _$TempState {
  // ...
}
```

## Best Practices

1. **Use code generation**: Always use `@riverpod` annotation
2. **Co-locate providers**: Place near consuming widgets
3. **Avoid singletons**: Use providers instead
4. **Layer correctly**: Keep UI logic separate from business logic

## Reading State in Widgets

```dart
class ServerWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverStatusProvider(server));
    return status.when(...);
  }
}
```

## Modifying State

```dart
ref.read(settingsProvider.notifier).update(newSettings);
```
