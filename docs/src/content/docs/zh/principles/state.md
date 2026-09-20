---
title: 状态模型
description: Server Box 如何组织运行时状态、服务器状态和持久化数据
---

Server Box 使用 Riverpod 管理页面状态、异步数据和服务依赖。本页介绍应用持有哪些状态、它们存在哪里；provider 的声明写法和生命周期见 [Riverpod 实践](/docs/zh/development/state/)。

## 为什么使用 Riverpod？

- **编译时类型检查**：许多错误可以在编译阶段发现。
- **不依赖 `BuildContext`**：service 和业务逻辑可以在 Widget 之外访问 provider。
- **Provider 隔离**：每个 provider 可以独立测试。
- **代码生成**：减少样板代码，同时保留静态类型检查。

## 状态分层

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

Widget 使用 `ref.watch` 订阅状态，使用 `ref.read(...notifier)` 调用操作。Provider 协调 service 和 store，Widget 只负责展示和交互。

## 服务器级状态

带服务器 ID 参数的 `serverProvider(serverId)` 为每台服务器维护独立状态，包含服务器配置、连接状态、SSH client、当前状态数据和 Monitor agent 的能力信息。`ServerNotifier` 负责连接、采集和错误处理，页面读取它的状态而不是自己管理连接生命周期。

```dart
final serverState = ref.watch(serverProvider(serverId));

await ref.read(serverProvider(serverId).notifier).refresh();
```

## 与时间有关的调度

有三件事由时钟驱动，而它们各自走哪条 transport 并不是同一个答案：

- **状态轮询**由 notifier 持有的 timer 驱动，在 `ref.onDispose` 中取消；它使用领先的 transport，即 `Spix.transport`。
- **已存历史**向报告 `ServerCapabilities.storedHistory` 的那条 transport 请求，也就是 agent，而不一定是领先的那条。SSH 没有历史，因此只有 SSH 的服务器只有应用自己的滚动 buffer。
- **超出当前帧的工作**会被移出帧外：benchmark 在服务器上脱离启动并轮询，文件传输运行在独立 isolate 上——两者都可能比应用停留在前台的时间更长。
  - 命令——benchmark、服务操作、进程列表——经由 `ensureExec()`，它使用领先的 transport，失败时回退到另一条。
  - 文件传输自选后端——SSH 上的 SFTP 或 agent 的文件 API——取决于服务器能用什么提供文件，而不是由承载状态的 transport 决定。

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

Provider 管理运行时状态；需要跨启动保留的数据应通过 store 持久化，不要只依赖 provider cache。
