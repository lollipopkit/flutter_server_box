---
title: 架构
description: Server Box 的主要架构和设计决策
---

Server Box 按职责分层组织代码，将 UI、状态协调、本地存储和外部连接分开。

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

## 关键设计

### Riverpod

Provider 负责状态和依赖关系：

- 生成的 provider 提供静态类型检查并减少样板代码
- `NotifierProvider` 处理带更新方法的同步状态
- `AsyncNotifierProvider` 处理加载和错误状态
- `StreamProvider` 暴露持续数据流
- 带参数的 provider 为不同服务器维护独立状态

### Freezed

Freezed model 提供 immutable 数据、`copyWith`、union 和 JSON 序列化支持。修改 model 后必须重新运行 code generation。

### SQLite

App 的权威本地存储是加密 SQLite 文件 `store.db`。数据按用途分为两种形态：

- **Key-value 表 `kv(store, key, value, updated_at)`**：用于设置和历史等互不相关的值。`value` 以 JSON 存储，写入值需要提供 `toJson`。
- **Entity 表**：用于服务器、private key、snippet、port forward、connection statistics 和 Agent conversation 等具有关系的数据，使用真实列、外键、约束和索引。

Drift 只负责 DDL（`lib/data/store/db.dart`）。连接由 `SqliteDb` 打开，并在那里应用数据库加密和 `foreign_keys` pragma；查询保持手写和同步，以适配当前 UI 的读取方式。

Entity 的 primary key 使用生成的 ID，用户输入的 name 只作为可唯一约束的普通列。列表和 map 字段使用 child table，以便查询和级联删除。

`Tables.syncRoots` 列出作为同步单元的表。每张都带 `updated_at` 和 `rev`；
它们的子表两者都不带，随父记录一起移动，因此 tag 不会先于它所属的服务器到达。
删除会在 `tombstone` 留下一行，否则对端会把记录的缺失读成新增并将其写回。

### 连接方式和能力

服务器可以配置 SSH、Monitor HTTP，或同时配置两者。`preferredTransport` 只决定优先尝试的连接顺序，不会禁用另一种方式；首选连接失败时，App 可以回退到另一种连接。

UI 根据 `ServerCapabilities` 判断功能是否可用，而不直接判断当前 transport：

| 能力 | SSH | Monitor HTTP |
|---|---|---|
| Shell/命令 | 支持 | 需要 `full_access` |
| 交互式终端 | 支持 | 需要 `full_access` 和 terminal endpoint |
| 文件浏览 | SFTP | 需要 `[remote_access.fs]` 和 `roots` |
| Byte stream（SFTP、端口转发） | 支持 | 不支持 |
| Monitor 连接前的历史数据 | 不提供 | 提供 |

同时配置两种方式的服务器使用能力 union，因此 SSH 提供的 SFTP 不会因为 Monitor 被设为优先而隐藏。

### 存储迁移

`SchemaVersion` 管理应用存储布局，Drift 的 `schemaVersion` 固定为 `1`。原因是应用迁移还需要读取旧 Hive box、重写 ID 和迁移引用，超出了 Drift migration 的范围。

迁移流程先由 `HiveImport` 将旧安装的 box 导入 `kv`，再由注册的 schema migration 将 key-value 数据拆分到 entity 表。旧版 Hive adapter 在 `lib/hive/legacy_adapters.dart` 中冻结，不能用当前 model 重新生成。

每次存储迁移都必须有永久 regression test，并使用被迁移版本实际写入的 bytes。当前 adapter 重新生成的 fixture 只能证明当前代码与自身一致，不能证明它还能读取旧版本数据。

## 依赖注入

服务和 store 通过三种方式组合：

1. **Provider**：向 UI 暴露依赖和状态。
2. **GetIt**：在适合服务定位的场景提供全局服务实例。
3. **Constructor injection**：在 class 之间显式传递依赖。

## 数据流

```text
用户操作
  → Widget
  → Provider
  → Service / Store
  → model 或状态更新
  → UI 重建
```

SSH 状态路径通过 SSH 执行共享 parser 脚本输出；Monitor HTTP 路径读取 Monitor agent 的 JSON，再映射为 App 的 `ServerStatus`。Monitor agent 在服务器本机使用 `sbm_native` 采样核心指标，并在较慢的扩展周期使用共享脚本获取仍需要 CLI 工具的数据。

## 平台和 Rust 集成

App 使用 Flutter 作为跨平台 UI，平台插件负责系统能力。Rust 代码通过 `crates/sbm_ffi` 和 flutter_rust_bridge 暴露给 Dart；生成的 bindings 位于 `lib/src/rust/`。

`sbm_parser` 负责纯解析函数，`sbm_native` 只供 Monitor agent 采样。两者共享状态类型，但 App 不会在远程服务器上调用 `sbm_native`。
