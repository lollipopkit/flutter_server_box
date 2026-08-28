---
title: State Management
description: Manage Server Box application state with Riverpod
---

Server Box uses Riverpod and `riverpod_generator` for UI state, asynchronous data, and service dependencies.

## Provider structure

```text
UI Widget
    ↓ ref.watch / ref.read
Provider
    ↓
Service / Store
    ↓
State update
```

Widgets use `ref.watch` to subscribe to state and `ref.read(...notifier)` to invoke operations. Providers coordinate services and stores; Widgets focus on presentation and interaction.

## Provider types

### `NotifierProvider`

A class-based `@riverpod` declaration generates a `NotifierProvider` for synchronous state with update methods:

```dart
@riverpod
class Settings extends _$Settings {
  @override
  SettingsModel build() => SettingsModel.defaults();

  void update(SettingsModel value) {
    state = value;
  }
}
```

It is not a `StateProvider`. Put validation, persistence, and other update logic in the notifier when they belong with the state.

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

Widgets should handle all `AsyncValue` states:

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
  return ref.watch(cpuServiceProvider).monitor(server);
}
```

Register cleanup for resources used by the stream with `ref.onDispose`.

### Family providers

A parameterized provider maintains independent state for each parameter set, such as each server's container list:

```dart
@riverpod
Future<List<Container>> containers(Ref ref, Server server) async {
  final client = await ref.watch(sshClientProvider(server).future);
  return client.listContainers();
}
```

`containersProvider(server)` and `containersProvider(server2)` represent different server states.

### Auto-dispose

By default, a provider can be disposed when it has no listeners. Use `keepAlive` only when state must survive that lifecycle:

```dart
@Riverpod(keepAlive: true)
class TemporaryState extends _$TemporaryState {
  // ...
}
```

Keeping providers alive unnecessarily consumes resources.

## Reading and updating state

Subscribe to state in a Widget:

```dart
class ServerWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverStatusProvider(server));
    return status.when(...);
  }
}
```

Call a notifier to update state:

```dart
ref.read(settingsProvider.notifier).update(newSettings);
```

Use `select` when a Widget needs only part of a state, so unrelated changes do not rebuild it.

## Derived state

Do not store another mutable copy of data that can be computed from existing providers:

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

The actual per-server provider is `serverProvider(serverId)`. Each instance contains the server configuration, connection state, SSH client, current status, and Monitor agent access information. `ServerNotifier` owns connection, collection, and error handling; pages read its state rather than managing the connection lifecycle.

```dart
final serverState = ref.watch(serverProvider(serverId));

// ServerNotifier owns connection, collection, and error handling.
await ref.read(serverProvider(serverId).notifier).refresh();
```

## Reactive refresh

A provider that needs periodic refreshes can create a timer and cancel it when disposed:

```dart
@riverpod
class AutoRefreshServerStatus extends _$AutoRefreshServerStatus {
  Timer? _timer;

  @override
  Future<StatusModel> build(Server server) async {
    ref.onDispose(() => _timer?.cancel());
    final status = await fetchStatus(server);
    // Disposed while the fetch was in flight: onDispose has already run, so a
    // timer started now is one nothing cancels.
    if (!ref.mounted) return status;
    // Started once the first fetch has landed. A tick that fired while it was
    // still running would set state that this build's own result then
    // overwrites.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    return status;
  }

  bool _refreshing = false;

  Future<void> refresh() async {
    // A tick that arrives while the previous fetch is still running is
    // dropped. Two in flight can finish out of order, and the older answer
    // would then overwrite the newer one.
    if (_refreshing) return;
    _refreshing = true;
    try {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() => fetchStatus(server));
    } finally {
      _refreshing = false;
    }
  }
}
```

Use `ref.watch` for provider dependencies. When an upstream provider changes, Riverpod can recompute dependent providers:

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

## Best practices

1. Place providers near the feature that consumes them.
2. Prefer `@riverpod` and code generation.
3. Keep each provider focused on one responsibility.
4. Handle the data, loading, and error states of every `AsyncValue`.
5. Release streams, timers, and connections from `ref.onDispose`.
6. Keep UI logic separate from business logic.
7. Avoid unnecessary `keepAlive` settings and deeply nested provider graphs.
