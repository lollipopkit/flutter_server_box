---
title: State Management
description: How state is managed with Riverpod
---

Understanding the state management architecture in Flutter Server Box.

## Why Riverpod?

**Key Benefits:**
- **Compile-time safety**: Catch errors at compile time
- **No BuildContext needed**: Access state anywhere
- **Easy testing**: Simple to test providers in isolation
- **Code generation**: Less boilerplate, type-safe

## Provider Architecture

```
┌─────────────────────────────────────────────┐
│         UI Layer (Widgets)                  │
│  - ConsumerWidget / ConsumerStatefulWidget  │
│  - ref.watch() / ref.read()                 │
└─────────────────────────────────────────────┘
                ↓ watches
┌─────────────────────────────────────────────┐
│         Provider Layer                      │
│  - @riverpod annotations                    │
│  - Generated *.g.dart files                 │
└─────────────────────────────────────────────┘
                ↓ uses
┌─────────────────────────────────────────────┐
│         Service / Store Layer               │
│  - Business logic                           │
│  - Data access                              │
└─────────────────────────────────────────────┘
```

## Provider Types Used

### 1. StateProvider (Simple State)

For simple, observable state:

```dart
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  ThemeMode build() {
    // Load from settings
    return SettingStore.themeMode;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    SettingStore.themeMode = mode;  // Persist
  }
}
```

**Usage:**
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeNotifierProvider);
    return Text('Theme: $theme');
  }
}
```

### 2. AsyncNotifierProvider (Async State)

For data that loads asynchronously:

```dart
@riverpod
class ServerStatus extends _$ServerStatus {
  @override
  Future<StatusModel> build(Server server) async {
    // Initial load
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

**Usage:**
```dart
final status = ref.watch(serverStatusProvider(server));

status.when(
  data: (data) => StatusWidget(data),
  loading: () => LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
)
```

### 3. StreamProvider (Real-time Data)

For continuous data streams:

```dart
@riverpod
Stream<CpuUsage> cpuUsage(CpuUsageRef ref, Server server) {
  final client = ref.watch(sshClientProvider(server));
  final stream = client.monitorCpu();

  // Auto-dispose when not watched
  ref.onDispose(() {
    client.stopMonitoring();
  });

  return stream;
}
```

**Usage:**
```dart
final cpu = ref.watch(cpuUsageProvider(server));

cpu.when(
  data: (usage) => CpuChart(usage),
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => ErrorWidget(error),
)
```

### 4. Family Providers (Parameterized)

Providers that accept parameters:

```dart
@riverpod
Future<List<Container>> containers(ContainersRef ref, Server server) async {
  final client = await ref.watch(sshClientProvider(server).future);
  return await client.listContainers();
}
```

**Usage:**
```dart
final containers = ref.watch(containersProvider(server));

// Different servers = different cached states
final containers2 = ref.watch(containersProvider(server2));
```

## State Update Patterns

### Direct State Update

```dart
ref.read(settingsProvider.notifier).updateTheme(darkMode);
```

### Computed State

```dart
@riverpod
int totalServers(TotalServersRef ref) {
  final servers = ref.watch(serversProvider);
  return servers.length;
}
```

### Derived State

```dart
@riverpod
List<Server> onlineServers(OnlineServersRef ref) {
  final all = ref.watch(serversProvider);
  return all.where((s) => s.isOnline).toList();
}
```

## Server-Specific State

### Per-Server Providers

Each server has isolated state:

```dart
@riverpod
class ServerProvider extends _$ServerProvider {
  @override
  ServerState build(Server server) {
    return ServerState.disconnected();
  }

  Future<void> connect() async {
    state = ServerState.connecting();
    try {
      final client = await genClient(server.spi);
      state = ServerState.connected(client);
    } catch (e) {
      state = ServerState.error(e.toString());
    }
  }
}
```

### Provider Keys

```dart
// Unique provider per server
@riverpod
ServerStatus serverStatus(ServerStatusRef ref, Server server) {
  // server.id used as key
}
```

## Reactive Patterns

### Auto-Refresh

```dart
@riverpod
class AutoRefreshServerStatus extends _$AutoRefreshServerStatus {
  Timer? _timer;

  @override
  Future<StatusModel> build(Server server) async {
    // Start timer
    _timer = Timer.periodic(Duration(seconds: 5), (_) {
      refresh();
    });

    ref.onDispose(() {
      _timer?.cancel();
    });

    return await fetchStatus(server);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => fetchStatus(server));
  }
}
```

### Multi-Provider Dependencies

```dart
@riverpod
Future<SystemInfo> systemInfo(SystemInfoRef ref, Server server) async {
  // Wait for SSH client first
  final client = await ref.watch(sshClientProvider(server).future);

  // Then fetch system info
  return await client.getSystemInfo();
}
```

## State Persistence

### Hive Integration

```dart
@riverpod
class ServerStoreNotifier extends _$ServerStoreNotifier {
  @override
  List<Server> build() {
    // Load from Hive
    return Hive.box<Server>('servers').values.toList();
  }

  void addServer(Server server) {
    state = [...state, server];
    // Persist to Hive
    Hive.box<Server>('servers').put(server.id, server);
  }

  void removeServer(String id) {
    state = state.where((s) => s.id != id).toList();
    // Remove from Hive
    Hive.box<Server>('servers').delete(id);
  }
}
```

## Error Handling

### Error States

```dart
@riverpod
class ConnectionManager extends _$ConnectionManager {
  @override
  ConnectionState build() {
    return ConnectionState.idle();
  }

  Future<void> connect(Server server) async {
    state = ConnectionState.connecting();
    try {
      final client = await genClient(server.spi);
      state = ConnectionState.connected(client);
    } on SocketException catch (e) {
      state = ConnectionState.error('Network error: $e');
    } on AuthenticationException catch (e) {
      state = ConnectionState.error('Auth failed: $e');
    } catch (e) {
      state = ConnectionState.error('Unknown error: $e');
    }
  }
}
```

### Error Recovery

```dart
@riverpod
class ResilientFetcher extends _$ResilientFetcher {
  int _retryCount = 0;

  @override
  Future<Data> build(Server server) async {
    return await _fetchWithRetry();
  }

  Future<Data> _fetchWithRetry() async {
    try {
      return await fetchData(server);
    } catch (e) {
      if (_retryCount < 3) {
        _retryCount++;
        await Future.delayed(Duration(seconds: 2));
        return await _fetchWithRetry();
      }
      rethrow;
    }
  }
}
```

## Performance Optimizations

### Provider Keep-Alive

```dart
@Riverpod(keepAlive: true)  // Don't dispose when no listeners
class GlobalSettings extends _$GlobalSettings {
  @override
  Settings build() {
    return Settings.defaults();
  }
}
```

### Selective Watching

```dart
// Watch only specific part of state
final name = ref.watch(serverProvider.select((s) => s.name));
```

### Provider Caching

Family providers cache results per parameter:

```dart
// Cached per server ID
final status1 = ref.watch(serverStatusProvider(server1));
final status2 = ref.watch(serverStatusProvider(server2));
// Different states, both cached
```

## Testing with Riverpod

### Provider Container

```dart
test('fetch server status', () async {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  // Override provider
  container.overrideFactory(
    sshClientProvider,
    (ref, server) => MockSshClient(),
  );

  final status = await container.read(
    serverStatusProvider(testServer).future,
  );

  expect(status, isA<StatusModel>());
});
```

## Best Practices

1. **Co-locate providers**: Place near consuming widgets
2. **Use code generation**: Always use `@riverpod`
3. **Keep providers focused**: Single responsibility
4. **Handle loading states**: Always handle AsyncValue states
5. **Dispose resources**: Use `ref.onDispose()` for cleanup
6. **Avoid deep provider trees**: Keep provider graph flat
