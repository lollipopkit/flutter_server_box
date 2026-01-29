---
title: 状态管理
description: 如何使用 Riverpod 进行状态管理
---

了解 Server Box 中的状态管理架构。

## 为何选择 Riverpod？

**主要优势：**
- **编译时安全**：在编译阶段即可发现错误
- **无需 BuildContext**：可在任何地方访问状态
- **易于测试**：方便对 Provider 进行隔离测试
- **代码生成**：减少样板代码，确保类型安全

## Provider 架构

```
┌─────────────────────────────────────────────┐
│         UI 层 (Widgets)                     │
│  - ConsumerWidget / ConsumerStatefulWidget  │
│  - ref.watch() / ref.read()                 │
└─────────────────────────────────────────────┘
                ↓ 监听 (watches)
┌─────────────────────────────────────────────┐
│         Provider 层                         │
│  - @riverpod 注解                           │
│  - 生成的 *.g.dart 文件                      │
└─────────────────────────────────────────────┘
                ↓ 使用 (uses)
┌─────────────────────────────────────────────┐
│         Service / Store 层                  │
│  - 业务逻辑                                 │
│  - 数据访问                                 │
└─────────────────────────────────────────────┘
```

## 使用的 Provider 类型

### 1. StateProvider (简单状态)

用于简单的可观察状态：

```dart
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  ThemeMode build() {
    // 从设置中加载
    return SettingStore.themeMode;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    SettingStore.themeMode = mode;  // 持久化存储
  }
}
```

**使用示例：**
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeNotifierProvider);
    return Text('当前主题：$theme');
  }
}
```

### 2. AsyncNotifierProvider (异步状态)

用于异步加载的数据：

```dart
@riverpod
class ServerStatus extends _$ServerStatus {
  @override
  Future<StatusModel> build(Server server) async {
    // 初始加载
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

**使用示例：**
```dart
final status = ref.watch(serverStatusProvider(server));

status.when(
  data: (data) => StatusWidget(data),
  loading: () => LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
)
```

### 3. StreamProvider (实时数据)

用于持续的数据流：

```dart
@riverpod
Stream<CpuUsage> cpuUsage(CpuUsageRef ref, Server server) {
  final client = ref.watch(sshClientProvider(server));
  final stream = client.monitorCpu();

  // 当不再被监听时自动释放资源
  ref.onDispose(() {
    client.stopMonitoring();
  });

  return stream;
}
```

**使用示例：**
```dart
final cpu = ref.watch(cpuUsageProvider(server));

cpu.when(
  data: (usage) => CpuChart(usage),
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => ErrorWidget(error),
)
```

### 4. Family Provider (带参数)

可以接收参数的 Provider：

```dart
@riverpod
Future<List<Container>> containers(ContainersRef ref, Server server) async {
  final client = await ref.watch(sshClientProvider(server).future);
  return await client.listContainers();
}
```

**使用示例：**
```dart
final containers = ref.watch(containersProvider(server));

// 不同的服务器对应不同的缓存状态
final containers2 = ref.watch(containersProvider(server2));
```

## 状态更新模式

### 直接更新状态

```dart
ref.read(settingsProvider.notifier).updateTheme(darkMode);
```

### 计算状态 (Computed State)

```dart
@riverpod
int totalServers(TotalServersRef ref) {
  final servers = ref.watch(serversProvider);
  return servers.length;
}
```

### 派生状态 (Derived State)

```dart
@riverpod
List<Server> onlineServers(OnlineServersRef ref) {
  final all = ref.watch(serversProvider);
  return all.where((s) => s.isOnline).toList();
}
```

## 服务器特定状态

### 单服务器 Provider

每个服务器都有独立的状态：

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

### Provider 键 (Keys)

```dart
// 每个服务器都有唯一的 Provider
@riverpod
ServerStatus serverStatus(ServerStatusRef ref, Server server) {
  // server.id 被用作 key
}
```

## 响应式模式

### 自动刷新

```dart
@riverpod
class AutoRefreshServerStatus extends _$AutoRefreshServerStatus {
  Timer? _timer;

  @override
  Future<StatusModel> build(Server server) async {
    // 启动定时器
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

### 多 Provider 依赖

```dart
@riverpod
Future<SystemInfo> systemInfo(SystemInfoRef ref, Server server) async {
  // 先等待 SSH 客户端建立连接
  final client = await ref.watch(sshClientProvider(server).future);

  // 然后获取系统信息
  return await client.getSystemInfo();
}
```

## 状态持久化

### Hive 集成

```dart
@riverpod
class ServerStoreNotifier extends _$ServerStoreNotifier {
  @override
  List<Server> build() {
    // 从 Hive 加载
    return Hive.box<Server>('servers').values.toList();
  }

  void addServer(Server server) {
    state = [...state, server];
    // 持久化到 Hive
    Hive.box<Server>('servers').put(server.id, server);
  }

  void removeServer(String id) {
    state = state.where((s) => s.id != id).toList();
    // 从 Hive 中删除
    Hive.box<Server>('servers').delete(id);
  }
}
```

## 性能优化

- **Provider Keep-Alive**：通过 `@Riverpod(keepAlive: true)` 防止无监听者时自动销毁
- **选择性监听**：使用 `select` 仅监听状态的特定部分
- **Provider 缓存**：Family Provider 为每个参数缓存结果

## 最佳实践

1. **就近放置 Provider**：放在消费它的 Widget 附近
2. **使用代码生成**：始终使用 `@riverpod` 注解
3. **保持 Provider 专注**：遵循单一职责原则
4. **处理加载状态**：务必处理 AsyncValue 的各种状态
5. **及时销毁资源**：在 `ref.onDispose()` 中进行清理
6. **避免过深的 Provider 树**：保持 Provider 图结构扁平
