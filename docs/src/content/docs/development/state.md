---
title: Riverpod Patterns
description: Provider, asynchronous state, and resource-lifecycle patterns used by Server Box
---

Server Box uses Riverpod and `riverpod_generator` to connect UI state,
asynchronous data, and services. For the kinds of state the App stores and
where each one lives, see [State model](/docs/principles/state/).

## Provider structure

```text
UI Widget
    │ ref.watch / ref.read
Provider
    │
Service / Store
    │
State update
```

Widgets subscribe with `ref.watch` and invoke notifier methods with
`ref.read(...notifier)`. Providers coordinate services and stores, while
Widgets handle presentation and user interaction.

## Provider types

### `NotifierProvider`

Use a class-based `@riverpod` declaration for synchronous state with update
methods. The generator creates a `NotifierProvider`:

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

This pattern is not a `StateProvider`. Keep validation, persistence, and
related state updates in the notifier.

### `AsyncNotifierProvider`

Use `AsyncNotifierProvider` when loading data can take time or fail:

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

Handle all `AsyncValue` cases in the Widget:

```dart
final status = ref.watch(serverStatusProvider(server));

return status.when(
  data: (value) => StatusWidget(value),
  loading: () => const LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
);
```

### `StreamProvider`

Use `StreamProvider` for values emitted over time:

```dart
@riverpod
Stream<CpuUsage> cpuUsage(Ref ref, Server server) {
  return ref.watch(cpuServiceProvider).monitor(server);
}
```

Release resources owned by the stream from `ref.onDispose`.

### Family providers

A parameterized provider keeps separate state for each argument set. For
example, each server can have its own container list:

```dart
@riverpod
Future<List<Container>> containers(Ref ref, Server server) async {
  final client = await ref.watch(sshClientProvider(server).future);
  return client.listContainers();
}
```

`containersProvider(server)` and `containersProvider(server2)` refer to
independent state.

### Auto-dispose

By default, Riverpod may dispose a provider after its last listener is gone.
Set `keepAlive` only when the state must outlive that point:

```dart
@Riverpod(keepAlive: true)
class TemporaryState extends _$TemporaryState {
  // ...
}
```

Keeping an unused provider alive retains its resources as well.

## Reading and updating state

Watch a provider while building a Widget:

```dart
class ServerWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverStatusProvider(server));
    return status.when(...);
  }
}
```

Call the notifier to perform an update:

```dart
ref.read(settingsProvider.notifier).update(newSettings);
```

Use `select` when a Widget depends on only part of a value. Changes to other
parts then do not rebuild it.

## Derived state

If a value can be computed from existing providers, derive it instead of
keeping a second mutable copy:

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

## Reactive refresh

For periodic refreshes, create a timer after the initial load and cancel it
when the provider is disposed. Check `ref.mounted` after awaiting the initial
request, so disposal during that request does not leave a timer behind. Do not
start the timer before the initial load completes: its result could overwrite
the first refresh.

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

Refreshes can also be requested by startup, lifecycle changes, or bulk
actions. `ServerRefreshScheduler`
(`lib/data/provider/server/refresh_scheduler.dart`) serializes the work in one
global queue and reuses the Future for a server that is already queued or
refreshing. Concurrent requests for the same server therefore start one
refresh, and no more than `maxConcurrent` servers refresh at once.

## Best practices

1. Keep providers near the feature that uses them.
2. Prefer `@riverpod` and code generation.
3. Give each provider one clear responsibility.
4. Handle the data, loading, and error states of every `AsyncValue`.
5. Release streams, timers, and connections from `ref.onDispose`.
6. Keep UI logic separate from business logic.
7. Avoid unnecessary `keepAlive` settings and deeply nested provider graphs.
