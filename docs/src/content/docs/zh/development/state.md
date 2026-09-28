---
title: Riverpod 实践
description: Server Box 使用的 provider、异步状态和资源生命周期写法
---

Server Box 使用 Riverpod 和 `riverpod_generator` 协调 UI 状态、异步数据与 service。App 保存哪些状态以及它们的位置，见[状态模型](/docs/zh/principles/state/)。

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

Widget 通过 `ref.watch` 订阅状态，通过 `ref.read(...notifier)` 调用 notifier 方法。Provider 协调 service 和 store；Widget 负责呈现内容和处理用户交互。

## Provider 类型

### `NotifierProvider`

同步状态需要更新方法时，可使用带 class 的 `@riverpod` 声明。生成器会创建对应的 `NotifierProvider`：

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

此模式不是 `StateProvider`。校验、持久化等状态更新逻辑应放在 notifier 中。

### `AsyncNotifierProvider`

加载需要等待或可能失败的数据时，使用 `AsyncNotifierProvider`：

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

Widget 应处理 `AsyncValue` 的所有情况：

```dart
final status = ref.watch(serverStatusProvider(server));

return status.when(
  data: (value) => StatusWidget(value),
  loading: () => const LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
);
```

### `StreamProvider`

数据会持续产生时，使用 `StreamProvider`：

```dart
@riverpod
Stream<CpuUsage> cpuUsage(Ref ref, Server server) {
  return ref.watch(cpuServiceProvider).monitor(server);
}
```

在 `ref.onDispose` 中释放 stream 使用的资源。

### Family Provider

带参数的 provider 会为每组参数保存独立状态，例如分别保存每台服务器的容器列表：

```dart
@riverpod
Future<List<Container>> containers(Ref ref, Server server) async {
  final client = await ref.watch(sshClientProvider(server).future);
  return client.listContainers();
}
```

`containersProvider(server)` 与 `containersProvider(server2)` 对应互相独立的状态。

### 自动释放

默认情况下，最后一个监听者离开后，Riverpod 可以释放 provider。只有状态必须继续存在时才设置 `keepAlive`：

```dart
@Riverpod(keepAlive: true)
class TemporaryState extends _$TemporaryState {
  // ...
}
```

不需要释放的 provider 也会继续占用其资源。

## 读取和更新状态

在 Widget 构建期间监听 provider：

```dart
class ServerWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverStatusProvider(server));
    return status.when(...);
  }
}
```

调用 notifier 执行更新：

```dart
ref.read(settingsProvider.notifier).update(newSettings);
```

Widget 只依赖某个值的一部分时使用 `select`，这样其他部分变化不会触发重建。

## 派生状态

如果某个值可以从现有 provider 计算得出，就直接派生，不要再保存第二份可变副本：

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

需要周期刷新时，先完成初次加载，再启动 timer，并在 provider 销毁时取消。初次请求结束后要检查 `ref.mounted`，避免请求期间 provider 被释放后仍遗留 timer。也不要在初次加载完成前启动 timer，否则刷新结果可能被初次请求覆盖。

```dart
@riverpod
class AutoRefreshServerStatus extends _$AutoRefreshServerStatus {
  Timer? _timer;

  @override
  Future<StatusModel> build(Server server) async {
    ref.onDispose(() => _timer?.cancel());
    final status = await fetchStatus(server);
    // The provider may be disposed while the initial request is pending.
    if (!ref.mounted) return status;
    // Start the timer after the initial request completes.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    return status;
  }

  bool _refreshing = false;

  Future<void> refresh() async {
    // Drop overlapping refreshes so an older result cannot replace a newer one.
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

除了 timer，启动流程、生命周期变化和批量操作也可能请求刷新。并发由 `ServerRefreshScheduler`（`lib/data/provider/server/refresh_scheduler.dart`）统一管理：它维护全局队列，并复用已排队或正在刷新的服务器对应的 Future。因此，同一台服务器的并发请求只触发一次刷新，且同时刷新的服务器数不会超过 `maxConcurrent`。

## 实践建议

1. 将 provider 放在使用它的功能附近。
2. 优先使用 `@riverpod` 和代码生成。
3. 为每个 provider 设定清晰且单一的职责。
4. 对 `AsyncValue` 的 data、loading 和 error 状态分别处理。
5. 在 `ref.onDispose` 中释放 stream、timer 和连接。
6. 将 UI 逻辑与业务逻辑分开。
7. 避免不必要的 `keepAlive` 和过深的 provider 依赖图。
