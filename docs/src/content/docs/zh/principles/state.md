---
title: 状态管理
description: 使用 Riverpod 管理 Server Box 的应用状态
---

Server Box 使用 Riverpod 管理页面状态、异步数据和服务依赖。以下是项目中常用的状态管理模式。

## 为什么使用 Riverpod？

- **编译时类型检查**：许多错误可以在编译阶段发现。
- **不依赖 `BuildContext`**：service 和业务逻辑可以在 Widget 之外访问 provider。
- **Provider 隔离**：每个 provider 可以独立测试。
- **代码生成**：减少样板代码，同时保留静态类型检查。

## Provider 架构

```text
┌─────────────────────────────────────────────┐
│ UI 层（Widget）                              │
│ ConsumerWidget / ConsumerStatefulWidget     │
│ ref.watch() / ref.read()                    │
└─────────────────────────────────────────────┘
                    ↓ 订阅或调用
┌─────────────────────────────────────────────┐
│ Provider 层                                  │
│ @riverpod、生成的 *.g.dart                   │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ Service / Store 层                          │
│ 业务逻辑和数据访问                           │
└─────────────────────────────────────────────┘
```

Widget 使用 `ref.watch` 订阅状态，状态变化后自动重建；需要执行操作时，使用 `ref.read` 调用 provider 或 notifier 方法。

## Provider 类型

### `NotifierProvider`

带 class 的 `@riverpod` 声明会生成 `NotifierProvider`，适合包含更新方法的同步状态：

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

Widget 读取状态：

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeNotifierProvider);
    return Text('当前主题：$theme');
  }
}
```

### `AsyncNotifierProvider`

用于具有 loading、data 和 error 状态的异步数据：

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

Widget 应处理 `AsyncValue` 的全部状态：

```dart
final status = ref.watch(serverStatusProvider(server));

return status.when(
  data: (value) => StatusWidget(value),
  loading: () => const LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
);
```

### `StreamProvider`

用于持续产生数据的 stream：

```dart
@riverpod
Stream<CpuUsage> cpuUsage(Ref ref, Server server) {
  final client = ref.watch(sshClientProvider(server));
  final stream = client.monitorCpu();

  ref.onDispose(client.stopMonitoring);
  return stream;
}
```

当 provider 没有监听者时，Riverpod 会释放自动管理的资源；需要手动清理的 client、timer 或 subscription 应注册到 `ref.onDispose`。

### Family Provider

带参数的 provider 会为每组参数维护独立状态：

```dart
@riverpod
Future<List<Container>> containers(Ref ref, Server server) async {
  final client = await ref.watch(sshClientProvider(server).future);
  return client.listContainers();
}
```

`containersProvider(server)` 和 `containersProvider(server2)` 对应不同的缓存状态。

## 状态更新

### 直接更新

通过 notifier 方法集中处理更新逻辑：

```dart
ref.read(settingsProvider.notifier).updateTheme(darkMode);
```

### 计算状态和派生状态

可以从已有 provider 计算结果，而不额外保存一份可变数据：

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

## 服务器级状态

带服务器 ID 参数的 `serverProvider` 为每台服务器维护独立状态。该状态包含服务器配置、连接状态、SSH client、当前状态数据和 Monitor agent 的能力信息。

```dart
final serverState = ref.watch(serverProvider(serverId));

// 执行刷新；ServerNotifier 负责连接、采集和错误处理。
await ref.read(serverProvider(serverId).notifier).refresh();
```

页面通过 provider 读取状态，连接和刷新逻辑留在 `ServerNotifier` 中。

## 响应式刷新

需要定时更新的数据可以在 provider 中创建 timer，并在销毁时取消：

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

provider 依赖其他 provider 时，使用 `ref.watch` 建立依赖；上游状态变化后，下游 provider 会重新计算：

```dart
@riverpod
Future<SystemInfo> systemInfo(Ref ref, Server server) async {
  final client = await ref.watch(sshClientProvider(server).future);
  return client.getSystemInfo();
}
```

## 状态持久化

权威本地存储是加密 SQLite 数据库 `store.db`：

- 设置和历史记录使用 `SqliteStore`。
- 服务器、private key、snippet 等具有关联关系的记录使用 entity store。
- Hive adapter 只负责从旧安装导入数据，不是当前运行时的存储后端。

```dart
final servers = Stores.server.readAll();
Stores.server.put(server);
Stores.server.deleteById(server.id);
```

Provider 管理运行时状态；需要跨启动保留的数据应通过 store 持久化，不要依赖 provider cache。

## 生命周期和性能

- 默认情况下，provider 在没有监听者时可以自动释放。
- 需要跨页面保留的 provider 才设置 `@Riverpod(keepAlive: true)`。
- 使用 `select` 只订阅需要的字段，减少无关 Widget 重建。
- Family Provider 为每组参数维护独立状态；参数应具有稳定的相等性。
- 在 `ref.onDispose` 中释放 timer、stream、SSH client 等资源。

## 实践建议

1. 将 provider 放在使用它的功能附近。
2. 优先使用 `@riverpod` 和代码生成。
3. 让每个 provider 负责单一职责。
4. 对 `AsyncValue` 的 data、loading 和 error 状态分别处理。
5. 将 UI 逻辑与业务逻辑分开。
6. 避免为派生数据创建重复的可变副本。
7. 避免不必要的 `keepAlive` 和过深的 provider 依赖图。
