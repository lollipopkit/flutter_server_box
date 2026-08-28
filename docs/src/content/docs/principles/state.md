---
title: State Management
description: How Server Box manages application state with Riverpod
---

Server Box uses Riverpod for page state, asynchronous data, and service dependencies. This page describes the state-management patterns used in the project.

## Why Riverpod?

- **Compile-time type checking**: Many errors can be caught while compiling.
- **No `BuildContext` dependency**: Services and business logic can access providers outside Widgets.
- **Provider isolation**: Providers can be tested independently.
- **Code generation**: Generated providers reduce boilerplate while preserving static typing.

## Provider architecture

```text
┌─────────────────────────────────────────────┐
│ UI layer (Widget)                            │
│ ConsumerWidget / ConsumerStatefulWidget     │
│ ref.watch() / ref.read()                    │
└─────────────────────────────────────────────┘
                    ↓ subscribe or call
┌─────────────────────────────────────────────┐
│ Provider layer                               │
│ @riverpod and generated *.g.dart             │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ Service / Store layer                        │
│ Business logic and data access               │
└─────────────────────────────────────────────┘
```

Widgets use `ref.watch` to subscribe to state and rebuild when it changes. They use `ref.read` to invoke provider or notifier methods.

## Provider types

### `NotifierProvider`

A class-based `@riverpod` declaration generates a `NotifierProvider`. It is suitable for synchronous state with update methods:

```dart
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  ThemeMode build() {
    return SettingStore.themeMode;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    SettingStore.themeMode = mode;
  }
}
```

### `AsyncNotifierProvider`

Use it for data with loading, success, and error states:

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

A Widget should handle every `AsyncValue` state:

```dart
final status = ref.watch(serverStatusProvider(server));

return status.when(
  data: (value) => StatusWidget(value),
  loading: () => const LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
);
```

### `StreamProvider`

Use it for continuously emitted data:

```dart
@riverpod
Stream<CpuUsage> cpuUsage(Ref ref, Server server) {
  final client = ref.watch(sshClientProvider(server));
  final stream = client.monitorCpu();

  ref.onDispose(client.stopMonitoring);
  return stream;
}
```

Register cleanup for clients, timers, and subscriptions with `ref.onDispose`.

### Family providers

A parameterized provider maintains independent state for each parameter set:

```dart
@riverpod
Future<List<Container>> containers(Ref ref, Server server) async {
  final client = await ref.watch(sshClientProvider(server).future);
  return client.listContainers();
}
```

`containersProvider(server)` and `containersProvider(server2)` represent different server states.

## Updating state

### Direct updates

Keep update logic in notifier methods:

```dart
ref.read(settingsProvider.notifier).updateTheme(darkMode);
```

### Computed and derived state

Derive values from existing providers instead of storing another mutable copy:

```dart
@riverpod
int totalServers(Ref ref) {
  return ref.watch(serversProvider).length;
}

@riverpod
List<Server> onlineServers(Ref ref) {
  return ref.watch(serversProvider).where((server) => server.isOnline).toList();
}
```

## Server-specific state

The actual per-server provider is `serverProvider(serverId)`. Each instance contains the server configuration, connection state, SSH client, current status, and Monitor agent access information.

```dart
final serverState = ref.watch(serverProvider(serverId));

// ServerNotifier owns connection, collection, and error handling.
await ref.read(serverProvider(serverId).notifier).refresh();
```

Pages read this state through the provider rather than managing connection lifecycles themselves.

## Reactive refresh

A provider that needs periodic refreshes can create a timer and cancel it when disposed:

```dart
@riverpod
class AutoRefreshServerStatus extends _$AutoRefreshServerStatus {
  Timer? _timer;

  @override
  Future<StatusModel> build(Server server) async {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    ref.onDispose(() => _timer?.cancel());
    return fetchStatus(server);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => fetchStatus(server));
  }
}
```

Use `ref.watch` for provider dependencies. When an upstream provider changes, Riverpod can recompute the dependent provider:

```dart
@riverpod
Future<SystemInfo> systemInfo(Ref ref, Server server) async {
  final client = await ref.watch(sshClientProvider(server).future);
  return client.getSystemInfo();
}
```

## State persistence

The authoritative local store is the encrypted SQLite database `store.db`:

- Settings and history use `SqliteStore`.
- Servers, private keys, snippets, and other related records use entity stores.
- Hive adapters only import data from old installations; Hive is not the current runtime backend.

```dart
final servers = Stores.server.readAll();
Stores.server.put(server);
Stores.server.deleteById(server.id);
```

Providers manage runtime state. Data that must survive a restart belongs in a store, not only in a provider cache.

## Lifecycle and performance

- Providers can be automatically disposed when they have no listeners.
- Use `@Riverpod(keepAlive: true)` only when state must survive across pages.
- Use `select` to subscribe to only the fields a Widget needs.
- Family parameters should have stable equality so their cached states remain predictable.
- Release timers, streams, SSH clients, and other resources from `ref.onDispose`.

## Best practices

1. Place a provider near the feature that consumes it.
2. Prefer `@riverpod` and code generation.
3. Keep each provider focused on one responsibility.
4. Handle the data, loading, and error states of every `AsyncValue`.
5. Keep UI logic separate from business logic.
6. Avoid storing duplicate mutable copies of derived data.
7. Avoid unnecessary `keepAlive` settings and deeply nested provider graphs.
