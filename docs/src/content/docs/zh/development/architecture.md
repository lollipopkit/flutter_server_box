---
title: 架构
description: 架构模式与设计决策
---

Server Box 遵循整洁架构（Clean Architecture）原则，明确分离数据层、领域层和表现层。

## 分层架构

```
┌─────────────────────────────────────┐
│          表现层 (Presentation)      │
│         (lib/view/page/)            │
│  - 页面、组件、控制器                │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│         业务逻辑层 (Business Logic) │
│      (lib/data/provider/)           │
│  - Riverpod Provider                │
│  - 状态管理                         │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│           数据层 (Data)             │
│      (lib/data/model/, store/)      │
│  - 模型、存储、服务                  │
└─────────────────────────────────────┘
```

## 关键模式

### 状态管理：Riverpod

- **代码生成**：使用 `riverpod_generator` 实现类型安全的 provider
- **State Notifiers**：用于包含业务逻辑的可变状态
- **Async Notifiers**：用于处理加载中和错误状态
- **Stream Providers**：用于处理实时数据

### 不可变模型：Freezed

- 许多数据模型使用 Freezed 实现不可变性
- 使用联合类型（Union types）表示不同状态
- 在配置后提供 JSON 序列化支持
- 提供 `copyWith` 方法以便更新

### 本地存储：SQLite

一个加密文件 `store.db`，经 `package:sqlite3` 打开，读取任何数据之前先应用
`sqlite3mc` 加密。其中有两种形态，某个 store 用哪一种，取决于它的记录之间
是否存在关系：

- **`kv(store, key, value, updated_at)`** 存放 settings 和 history。这里适合保存上百条
  互不相关的偏好项，没有任何按字段的查询，新增一项应当只是一行改动。`value`
  是 JSON，因此写入这里的值必须有 `toJson`；缺少时 `SqliteStore.set` 返回
  `false` 而不是抛出。
- **实体表**存放服务器、私钥、snippet、端口转发、连接统计和 agent
  conversation，并使用真正的列、外键、`CHECK` 约束和索引。

Drift 负责 DDL（`lib/data/store/db.dart`），且仅负责 DDL：查询是手写且同步的，
因为 UI 在 build 过程中读取 store。Drift 不负责打开连接，由 `SqliteDb` 打开、
应用加密和 `foreign_keys` pragma，再把已打开的 handle 交给它。

此外，还有两项无法由键值存储表达的约定：

- **主键只能是 id，不能是用户输入的名字。** 过去重命名私钥会让所有引用它的
  服务器失联，因为私钥的 id 就是它的名字。现在 name 是普通的 `UNIQUE` 列。
- **列表或 map 字段是子表。** 这让“带此 tag 的所有服务器”成为一次查询，而不是
  解码每一行；也让 `ON DELETE CASCADE` 接手删除服务器后的清理，取代原先六处
  手写调用。

`Tables.syncRoots` 列出作为同步单元的表。每张都带 `updated_at` 和 `rev`；
它们的子表两者都不带，随父记录一起移动，因此 tag 不会先于它所属的服务器到达。
删除会在 `tombstone` 留下一行，否则对端会把记录的缺失读成新增并将其写回。

### 存储迁移

`SchemaVersion` 跟踪布局版本；Drift 自身的 `schemaVersion` 固定为 1 且不再变化，
因为迁移中的关键步骤超出 Drift migration 的表达能力。目前有三步：

- `HiveImport`（m003）把升级安装的 Hive box 复制进 `kv`，每台设备一次。它通过
  `lib/hive/legacy_adapters.dart` 中冻结的 adapter 读取，而不是通过当前模型。
  给模型新增字段会让*生成的* adapter 无法读取此前写入的任何 box。
- `KvToTablesMigration`（m004）把这些行拆进实体表，为原本以 name 为键的记录
  生成 id，并重写指向它们的每一处引用。
- `MonitorInsecureHttpMigration`（m005）为 monitor 凭据增加在可信网络上使用明文
  HTTP 的显式选择。

**存储迁移必须保留一个永久回归测试，输入是被迁移版本真实写出的字节。**
它对用户数据只有一次机会且不可重复，因此其中的 bug 表现为静默而非崩溃。
`test/fixtures/hive_v{1466,1480,1491}/` 保存了这些版本各自 adapter 生成的 box，
`test/hive_release_migration_test.dart` 对每个版本跑完前两步。使用当前 adapter
生成数据只能证明当前代码彼此一致。该测试首次运行就发现了四处字段名不匹配，
每一处都会静默丢掉一整个 store。

## 依赖注入 (DI)

服务和存储类通过以下方式注入：

1. **Provider**：向 UI 层暴露依赖
2. **GetIt**：服务定位器（在适用情况下使用）
3. **构造函数注入**：显式声明依赖关系

## 数据流

```
用户操作 → Widget → Provider → 服务/存储 → 模型更新 → UI 重构
```

1. 用户与组件交互
2. 组件调用 provider 方法
3. Provider 通过服务/存储更新状态
4. 状态更改触发 UI 重新构建
5. 组件反映最新状态

## 状态解析：共享 Rust 库

服务器状态解析（CPU、内存、磁盘、网络、温度、GPU、SMART 等）在
Rust crate `crates/sbm_parser` 中实现一次，App 经 flutter_rust_bridge
（`crates/sbm_ffi`，生成的 Dart 位于 `lib/src/rust/`）调用。
服务端 monitor 直接依赖同一 crate，两端解析行为始终一致。
解析器是纯函数：只返回原始计数；差分和滑窗计算（如网速）同样是纯函数，
FFI 边界不持有可变状态。

## 自定义依赖

项目使用了多个自定义分支以扩展功能：

- **dartssh2**：增强的 SSH 功能
- **xterm**：支持移动端的终端模拟器
- **fl_lib**：共享的 UI 组件和工具类

## 多线程处理

- **Isolates**：将繁重的计算任务移出主线程
- **computer 包**：并发处理工具
- **Async/Await**：非阻塞式 I/O 操作
