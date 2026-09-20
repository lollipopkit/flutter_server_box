---
title: Riverpod 实践
description: Server Box 使用的 provider、异步状态和资源生命周期写法
---

Server Box 使用 Riverpod 和 `riverpod_generator` 管理 UI 状态、异步数据和服务依赖。应用持有哪些状态、存在哪里，见[状态模型](/docs/zh/principles/state/)。

## Provider 结构

```text
UI Widget
    │ ref.watch / ref.read
Provider
    │
Service / Store
    │
状态更新
```

Widget 使用 `ref.watch` 订阅状态，使用 `ref.read(...notifier)` 调用操作。Provider 协调 service 和 store，Widget 只负责展示和交互。

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

它不是 `StateProvider`。校验、持久化等属于状态的更新逻辑应放进 notifier。

### `AsyncNotifierProvider`

用于具有 loading、success 和 error 状态的异步数据：

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
  return ref.watch(cpuServiceProvider).monitor(server);
}
```

stream 使用的资源在 `ref.onDispose` 中释放。

### Family Provider

带参数的 provider 会为每组参数维护独立状态，例如每台服务器的容器列表：

```dart
@riverpod
Future<List<Container>> containers(Ref ref, Server server) async {
  final client = await ref.watch(sshClientProvider(server).future);
  return client.listContainers();
}
```

`containersProvider(server)` 和 `containersProvider(server2)` 对应不同的服务器状态。

### 自动释放

默认情况下，provider 在没有监听者时可以被释放。只有状态必须跨过这个生命周期时才使用 `keepAlive`：

```dart
@Riverpod(keepAlive: true)
class TemporaryState extends _$TemporaryState {
  // ...
}
```

不必要的 keepAlive 会持续占用资源。

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

Widget 只需要状态的一部分时使用 `select`，避免无关变化触发重建。

## 派生状态

可以从已有 provider 计算的数据，不要再保存一份可变副本：

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

## 响应式刷新

需要周期刷新的 provider 可以创建 timer，并在销毁时取消。顺序很重要，两个原因都写在代码里：

```dart
@riverpod
class AutoRefreshServerStatus extends _$AutoRefreshServerStatus {
  Timer? _timer;

  @override
  Future<StatusModel> build(Server server) async {
    ref.onDispose(() => _timer?.cancel());
    final status = await fetchStatus(server);
    // 请求飞行途中被销毁：onDispose 已经跑过，此时启动的 timer 没有任何东西会取消它。
    if (!ref.mounted) return status;
    // 等第一次请求落地后才启动。若在它还在运行时触发，这次 tick 写入的状态
    // 会被这次 build 自己的结果覆盖。
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    return status;
  }

  bool _refreshing = false;

  Future<void> refresh() async {
    // 上一次请求还在飞行时到达的 tick 会被丢弃。两次并发可能乱序完成，
    // 较旧的答案会覆盖较新的。
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

timer 之外也可能要求刷新——启动、生命周期边沿、批量操作。此时并发是调度器的责任而不是每个调用方的：`ServerRefreshScheduler`（`lib/data/provider/server/refresh_scheduler.dart`）持有唯一的全局队列，对已排队或正在运行的服务器共享同一个 future，因此三个调用方同时请求只会产生一次刷新，并且并发数不超过 `maxConcurrent`。

## 实践建议

1. 将 provider 放在使用它的功能附近。
2. 优先使用 `@riverpod` 和代码生成。
3. 让每个 provider 负责单一职责。
4. 对 `AsyncValue` 的 data、loading 和 error 状态分别处理。
5. 在 `ref.onDispose` 中释放 stream、timer 和连接。
6. 将 UI 逻辑与业务逻辑分开。
7. 避免不必要的 `keepAlive` 和过深的 provider 依赖图。
