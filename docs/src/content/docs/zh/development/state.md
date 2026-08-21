---
title: 状态管理
description: 基于 Riverpod 的状态管理模式
---

Server Box 使用 Riverpod 及其代码生成工具进行状态管理。

## Provider 类型

### NotifierProvider

基于 class 的 `@riverpod` 声明生成的是 `NotifierProvider`，不是
`StateProvider`。适合使用带更新方法的状态：

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

处理加载和错误状态的异步 Provider：

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

提供数据流中的实时数据：

```dart
@riverpod
Stream<CpuUsage> cpuUsage(Ref ref, Server server) {
  return cpuService.monitor(server);
}
```

## 状态模式

### 加载状态处理

```dart
state.when(
  data: (data) => DataWidget(data),
  loading: () => LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
)
```

### Family Provider（带参数）

接收参数的 Provider：

```dart
@riverpod
List<Container> containers(Ref ref, Server server) {
  return containerService.list(server);
}
```

### 自动释放（Auto-Dispose）

当不再有监听者时自动销毁的 Provider：

```dart
@Riverpod(keepAlive: false)
class TempState extends _$TempState {
  // ...
}
```

## 最佳实践

1. **使用代码生成**：始终使用 `@riverpod` 注解。
2. **就近放置 Provider**：将 Provider 定义在消费它的 Widget 附近。
3. **避免使用单例**：优先使用 Provider 管理共享状态和依赖。
4. **保持清晰的分层**：将 UI 逻辑与业务逻辑分离。

## 在 Widget 中读取状态

```dart
class ServerWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverStatusProvider(server));
    return status.when(...);
  }
}
```

## 修改状态

```dart
ref.read(settingsProvider.notifier).update(newSettings);
```
