---
title: 系统架构
description: Server Box 如何组织界面、状态、存储和平台层
---

Server Box 采用分层结构，将界面、状态协调、本地数据和外部连接分别处理。这样既方便跨平台实现，也让 SSH、Monitor agent 和本机终端能够共用上层 UI。

本页介绍系统层面的模型：分层结构，以及形当大多数行为的两个决定——一台服务器可以同时暴露两种 transport，状态也可以从任一边到达。模块布局、入口、依赖注入与 Rust 集成请参阅[实现架构](/docs/zh/development/architecture/)。

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
│ lib/data/model/、lib/data/store/                │
│ model、本地存储、连接服务                       │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│ 外部集成层                                      │
│ SSH、SFTP、Monitor HTTP、平台 API               │
└─────────────────────────────────────────────────┘
```

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

## 安全架构

### 数据保护

- **密码 / SSH 密钥**：存储在加密的 SQLite 数据库中；加密密钥本身保存在平台安全存储（Keychain/Keystore）
- **主机指纹**：安全存储
- **会话数据**：不进行持久化

### 连接安全

- **主机密钥验证**：检测中间人攻击
- **加密**：标准 SSH 加密
- **不存储明文**：敏感数据不会以明文存储
