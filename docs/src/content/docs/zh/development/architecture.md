---
title: 实现架构
description: Server Box 的 Flutter、存储、连接和原生层实现细节
---

本页介绍代码的位置以及应用如何拼装。系统层面的模型——分层、transport 与能力、两条状态路径、迁移和安全——请参阅[系统架构](/docs/zh/principles/architecture/)。

## 分层结构

```text
┌─────────────────────────────────────┐
│ 表现层                              │
│ lib/view/                           │
│ 页面、Widget、用户交互               │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│ 状态与业务协调层                    │
│ lib/data/provider/                  │
│ Riverpod provider、异步状态          │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│ 数据与服务层                        │
│ lib/data/model/、lib/data/store/    │
│ model、本地存储、连接服务             │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│ 外部集成                            │
│ SSH、SFTP、Monitor HTTP、平台 API    │
└─────────────────────────────────────┘
```

## 应用入口

`lib/main.dart` 负责初始化依赖、打开加密的本地数据库、初始化 Rust bindings，并调用 `runApp`。根组件负责主题、路由和 Riverpod `ProviderScope`。

首页通过标签页提供服务器、终端、文件和代码片段等功能。页面只负责展示和接收交互，具体状态和操作交给 provider、service 或 store。

## 状态管理：Riverpod

项目使用 `riverpod_generator` 生成类型安全的 Provider：

- `NotifierProvider`：管理带更新方法的同步状态
- `AsyncNotifierProvider`：管理异步加载、成功和错误状态
- `StreamProvider`：暴露持续产生的数据流
- Family Provider：为不同服务器或其他参数维护独立状态

Provider 不要求依赖 `BuildContext`，因此 service 和业务逻辑可以独立测试。声明的写法和生命周期细节见 [Riverpod 实践](/docs/zh/development/state/)。

## 数据持久化：加密 SQLite

App 的权威本地存储是加密 SQLite 文件 `store.db`。`SqliteDb` 打开连接，并在那里应用数据库加密和 `foreign_keys` pragma。

数据按用途分为两种形态：

- **Key-value 表 `kv(store, key, value, updated_at)`**：用于设置和历史等互不相关的值。`value` 以 JSON 存储，经 `SqliteStore.set` 写入的值需要提供 `toJson`。
- **Entity 表**：用于服务器、private key、snippet、port forward、connection statistics 和 Agent conversation 等具有关系的数据，使用真实列、外键、约束和索引。

Drift 只负责 DDL（`lib/data/store/db.dart`），不打开连接，也不替代手写的同步查询。Entity 的 primary key 使用生成的 ID，用户输入的 name 只作为可唯一约束的普通列。列表和 map 字段使用 child table。

## 依赖注入

服务和 store 通过三种方式组合：

1. **Provider**：向 UI 暴露依赖和状态。
2. **GetIt**：在适合服务定位的场景提供全局服务实例。
3. **Constructor injection**：在 class 之间显式传递依赖。

## 平台和 Rust 集成

App 使用 Flutter 作为跨平台 UI，平台插件负责系统能力。Rust 代码通过 `crates/sbm_ffi` 和 flutter_rust_bridge 暴露给 Dart；生成的 bindings 位于 `lib/src/rust/`。

`sbm_parser` 负责纯解析函数，`sbm_native` 只供 Monitor agent 采样。两者共享状态类型，但 App 不会在远程服务器上调用 `sbm_native`。
