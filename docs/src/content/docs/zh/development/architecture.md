---
title: 实现架构
description: Server Box 的 Flutter、存储、连接和原生层实现细节
---

本页说明源码目录与 App 实现之间的对应关系。关于更完整的系统设计，包括分层、transport、能力、状态采集、迁移和安全模型，请参阅[系统架构](/docs/zh/principles/architecture/)。

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

`lib/main.dart` 初始化依赖、打开加密的本地数据库、初始化 Rust bindings，并通过 `runApp` 启动 Flutter。根 Widget 设置主题和路由，并创建用于依赖注入的 Riverpod `ProviderScope`。

首页通过标签页提供服务器、终端、文件和代码片段功能。页面负责显示状态和处理交互；provider、service 和 store 执行操作并管理状态变化。

## 状态管理：Riverpod

项目通过 `riverpod_generator` 生成带类型的 provider：

- `NotifierProvider`：管理带更新方法的同步状态
- `AsyncNotifierProvider`：管理异步加载、成功和错误状态
- `StreamProvider`：暴露持续产生的数据流
- Family Provider：为不同服务器或其他参数维护独立状态

provider 不依赖 `BuildContext`，因此 service 和业务逻辑不受 Widget tree 限制。provider 的声明方式和生命周期详见 [Riverpod 实践](/docs/zh/development/state/)。

## 数据持久化：加密 SQLite

加密 SQLite 文件 `store.db` 是 App 本地数据的权威存储。`SqliteDb` 负责打开连接、配置数据库加密并启用 `foreign_keys` pragma。

数据按用途分为两种形态：

- **Key-value 表 `kv(store, key, value, updated_at)`**：保存设置、历史等无需关系查询的数据。值以 JSON 格式存储；通过 `SqliteStore.set` 写入时需要提供 `toJson`。
- **Entity 表**：保存 server、private key、snippet、port forward、connection statistics、Agent conversation 等有关联的数据，使用独立列、外键、约束和索引。

Drift 在 `lib/data/store/db.dart` 定义 DDL。连接由 `SqliteDb` 管理，store 查询仍是手写的同步查询。Entity 的 primary key 使用生成的 ID；用户填写的 name 是普通列，并施加唯一约束。List 和 map 字段存放在 child table 中。

## 依赖注入

service 和 store 使用以下三种方式获取依赖：

1. **Provider**：向 UI 暴露依赖和状态。
2. **GetIt**：在适合服务定位的场景提供全局服务实例。
3. **Constructor injection**：在 class 之间显式传递依赖。

## 平台和 Rust 集成

Flutter 为 App 提供跨平台 UI。平台集成负责通知、后台服务、文件系统等操作系统能力。Rust API 通过 `crates/sbm_ffi` 和 flutter_rust_bridge 暴露给 Dart；生成的 bindings 位于 `lib/src/rust/`。

`crates/sbm_parser` 存放多个项目共用的解析逻辑。`crates/sbm_native` 为 Monitor agent 采集运行所在主机的指标；App 不会在远程服务器上调用 `sbm_native`。
