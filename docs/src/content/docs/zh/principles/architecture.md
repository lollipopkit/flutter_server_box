---
title: 架构概览
description: Server Box 的整体架构和组件职责
---

Server Box 采用分层结构，将界面、状态协调、本地数据和外部连接分别处理。这样既方便跨平台实现，也让 SSH、Monitor agent 和本机终端能够共用上层 UI。

## 架构分层

```text
┌─────────────────────────────────────────────────┐
│ 表现层                                          │
│ lib/view/page/、lib/view/widget/                │
│ 页面、Widget、用户交互                          │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│ 状态与业务协调层                                │
│ lib/data/provider/                              │
│ Riverpod Provider、异步状态                     │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│ 数据与服务层                                    │
│ lib/data/store/、lib/data/model/                │
│ 本地存储、model、连接服务                       │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│ 外部集成层                                      │
│ SSH、SFTP、Monitor HTTP、平台 API               │
└─────────────────────────────────────────────────┘
```

## 应用入口和导航

`lib/main.dart` 负责初始化依赖、打开本地数据库、初始化 Rust bindings，并调用 `runApp`。根组件负责主题、路由和 Riverpod `ProviderScope`。

首页通过标签页提供服务器、终端、文件和代码片段等功能。页面只负责展示和接收交互，具体状态和操作交给 provider、service 或 store。

## 状态管理：Riverpod

项目使用 `riverpod_generator` 生成类型安全的 Provider：

- `NotifierProvider`：管理带更新方法的同步状态
- `AsyncNotifierProvider`：管理异步加载、成功和错误状态
- `StreamProvider`：暴露持续产生的数据流
- Family Provider：为不同服务器或其他参数维护独立状态

Provider 不要求依赖 `BuildContext`，因此 service 和业务逻辑可以独立测试。Widget 通过 `ref.watch` 订阅状态，通过 `ref.read(...notifier)` 发起更新。

## 本地存储：加密 SQLite

App 的权威本地存储是加密 SQLite 文件 `store.db`。数据库加密密钥保存在平台安全存储中，数据库由 `SqliteDb` 打开并应用 `foreign_keys` pragma。

数据根据是否需要关系查询分为两类：

- **Key-value 表 `kv(store, key, value, updated_at)`**：用于设置和历史等互不相关的值。`value` 以 JSON 存储，写入值必须提供 `toJson`。
- **Entity 表**：用于服务器、private key、snippet、port forward、connection statistics 和 Agent conversation 等具有关联关系的数据。它们使用独立列、外键、约束和索引。

Drift 只负责 DDL（`lib/data/store/db.dart`），不会打开数据库连接，也不负责现有的同步查询。`SqliteDb` 创建连接后，将 handle 交给手写的 store 查询代码。

Entity 的 primary key 使用生成的 ID；用户输入的 name 是可唯一约束的普通列。列表和 map 字段使用 child table，以便查询和级联删除。

## 连接方式和能力模型

服务器可以配置 SSH、Monitor HTTP，或同时配置两者。`preferredTransport` 只决定连接尝试顺序；优先连接失败时，App 可以回退到另一种方式。

UI 根据 `ServerCapabilities` 判断服务器支持哪些功能，而不是直接判断当前使用的 transport：

| 能力 | SSH | Monitor HTTP |
|---|---|---|
| Shell 和命令 | 支持 | 需要 `full_access` |
| 交互式终端 | 支持 | 需要 `full_access` 和 terminal endpoint |
| 文件浏览 | SFTP | 需要 `[remote_access.fs]` 和 `roots` |
| Byte stream（SFTP、端口转发） | 支持 | 不支持 |
| App 连接前的历史数据 | 不提供 | 提供 |

同时配置两种方式时，服务器的能力取两者的 union。因此 Monitor HTTP 即使被设为优先，也不会隐藏 SSH 提供的 SFTP 或端口转发能力。

连接服务器的 byte stream 来源是另一项独立设置：SSH 文件操作默认使用 SFTP，也可以选择 SCP；仅配置 Monitor HTTP 的服务器使用 agent 的文件 API，不提供 SFTP 或端口转发。

## 状态采集和解析

服务器状态有两条采集路径：

**SSH 路径**：

```text
定时器
  → Provider
  → SSH 命令脚本
  → sbm_parser（通过 sbm_ffi）
  → ServerStatus
  → UI 重建
```

**Monitor HTTP 路径**：

```text
定时器
  → Provider 请求 /api/v1/metrics
  → 解析 MonitorMetrics JSON
  → applyMonitorMetrics
  → ServerStatus
  → UI 重建
```

App 的 SSH 路径通过 `crates/sbm_ffi` 调用共享 Rust parser。Monitor agent 在服务器本机使用 `crates/sbm_native` 获取 CPU、内存、磁盘、网络等核心指标，并在较慢的扩展周期使用共享脚本获取仍需要 CLI 工具的数据。两条路径共享部分状态模型，但采样方式、字段精度和语义可能不同，不能假定两者是完全相同的解析流程。

parser 以纯函数形式工作，只返回原始计数；差分和滑动窗口计算也由纯函数完成，FFI 边界不保存可变状态。

## 存储迁移

`SchemaVersion` 管理 App 的存储布局，Drift 的 `schemaVersion` 固定为 `1`。迁移还需要读取旧 Hive box、生成新的 ID 并重写引用，这些工作超出了 Drift migration 的范围。

迁移会先由 `HiveImport` 将旧安装的 Hive 数据导入 `kv`，再由已注册的 schema migration 将 key-value 数据拆分到 entity 表。`lib/hive/legacy_adapters.dart` 中的旧版 adapter 是冻结的读取器，不能用当前 model 重新生成。

每个存储迁移都必须保留永久 regression test，并使用旧 release 实际写出的 bytes。当前 adapter 重新生成 fixture 只能证明当前版本与自身一致，不能证明它还能读取旧版本数据。

## 依赖注入

服务和 store 使用以下方式组合：

1. **Provider**：向 UI 暴露依赖和状态。
2. **GetIt**：在适合使用 service locator 的场景提供全局服务实例。
3. **Constructor injection**：在 class 之间显式传递依赖。

## 平台和 Rust 集成

Flutter 提供跨平台 UI，平台插件负责通知、后台服务、文件系统等系统能力。Rust 代码通过 `crates/sbm_ffi` 和 flutter_rust_bridge 暴露给 Dart，生成的 bindings 位于 `lib/src/rust/`。

`crates/sbm_parser` 是共享的纯解析库；`crates/sbm_native` 仅供 Monitor agent 在服务器本机采样。App 不会在远程服务器上调用 `sbm_native`。

## 安全架构

### 数据保护

- **密码 / SSH 密钥**：存储在加密的 SQLite 数据库中；加密密钥本身保存在平台安全存储（Keychain/Keystore）
- **主机指纹**：安全存储
- **会话数据**：不进行持久化

### 连接安全

- **主机密钥验证**：检测中间人攻击
- **加密**：标准 SSH 加密
- **不存储明文**：敏感数据不会以明文存储
