---
title: 状态管理
description: 使用 Riverpod 管理应用状态
---

Server Box 使用 Riverpod 和 `riverpod_generator` 管理 UI 状态、异步数据和服务依赖。

## Provider 结构

```text
UI Widget
    ↓ ref.watch / ref.read
Provider
    ↓
Service / Store
    ↓
状态更新
```

Widget 通过 `ref.watch` 订阅状态，需要执行操作时通过 `ref.read(...notifier)` 调用 provider 方法。Provider 负责协调 service 和 store，Widget 只处理展示和交互。

## Provider 类型

### `NotifierProvider`

带 class 的 `@riverpod` 声明会生成 `NotifierProvider`，适合包含更新方法的同步状态：

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

它不是 `StateProvider`。需要把更新逻辑、校验或持久化集中在 provider 中时，使用 notifier 更容易维护。

### `AsyncNotifierProvider`

用于需要加载、成功和错误状态的异步数据：

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

Widget 使用 `AsyncValue.when` 处理所有状态：

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
  return ref.watch(cpuServiceProvider).monitor(server);
}
```

如果 stream 需要额外资源，在 `ref.onDispose` 中释放：

```dart
ref.onDispose(() {
  client.stopMonitoring();
});
```

### Family Provider

带参数的 provider 会为每组参数维护独立状态，例如不同服务器的容器列表：

```dart
@riverpod
Future<List<Container>> containers(Ref ref, Server server) async {
  final client = await ref.watch(sshClientProvider(server).future);
  return client.listContainers();
}
```

`containersProvider(server)` 和 `containersProvider(server2)` 对应不同的服务器状态。

### 自动释放

默认情况下，provider 在没有监听者时可以自动释放。需要保留状态时显式设置 `keepAlive`：

```dart
@Riverpod(keepAlive: false)
class TemporaryState extends _$TemporaryState {
  // ...
}
```

选择 `keepAlive` 前先确认状态是否需要跨页面保留；不必要地保留 provider 会增加资源占用。

## 读取和更新状态

在 Widget 中订阅状态：

```dart
class ServerWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverStatusProvider(server));
    return status.when(...);
  }
}
```

调用 notifier 更新状态：

```dart
ref.read(settingsProvider.notifier).update(newSettings);
```

只监听状态的一部分时使用 `select`，避免无关字段变化导致 Widget 重建。

## 派生状态

不要重复保存可以从其他 provider 计算出来的数据。使用另一个 provider 派生结果：

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

带服务器 ID 参数的 `serverProvider` 为每台服务器维护独立状态。状态包含服务器配置、连接状态、SSH client、当前状态数据和 Monitor agent 的能力信息。连接、刷新和错误处理都由 `ServerNotifier` 负责，页面不直接管理连接生命周期。

```dart
final serverState = ref.watch(serverProvider(serverId));

// ServerNotifier 负责连接、状态采集和错误处理。
await ref.read(serverProvider(serverId).notifier).refresh();
```

## 状态持久化

权威本地存储是加密 SQLite 数据库 `store.db`。设置和历史记录使用 `SqliteStore`；服务器、snippet、private key 等具有关联关系的记录使用对应的 entity store。

```dart
final servers = Stores.server.readAll();
Stores.server.put(server);
Stores.server.deleteById(server.id);
```

Hive adapter 只用于从旧安装导入数据，不是当前运行时的存储后端。

## 实践建议

1. 将 provider 放在使用它的功能附近。
2. 优先使用代码生成的 provider。
3. 让每个 provider 负责单一职责。
4. 对 `AsyncValue` 的 data、loading 和 error 状态分别处理。
5. 在 `ref.onDispose` 中释放 stream、timer 和连接等资源。
6. 不要为派生数据额外创建可变副本。
7. 避免不必要的 `keepAlive`，让无用状态及时释放。
