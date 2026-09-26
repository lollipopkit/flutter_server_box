---
title: 系统架构
description: Server Box 如何组织界面、状态、存储和平台层
---

Server Box 将 UI、状态协调、本地存储和外部连接分层处理。SSH、Monitor agent 和本机终端因此可以共用 UI，同时把平台相关逻辑留在边缘层。

本页介绍系统模型，以及影响多数功能的两个设计选择：一台服务器可以配置两种 transport，状态也可以经由任一 transport 提供。源码目录、App 入口、依赖注入和 Rust 集成请参阅[实现架构](/docs/zh/development/architecture/)。

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

服务器可以配置 SSH、Monitor HTTP，或同时配置两者。`preferredTransport` 决定 App 优先尝试哪种连接，但不会关闭另一种；首选方式连接失败时，App 可以尝试备用方式。

UI 根据 `ServerCapabilities` 判断可用功能，不直接根据当前使用的 transport 推断：

| 能力 | SSH | Monitor HTTP |
|---|---|---|
| Shell 和命令 | 支持 | 需要 `full_access` |
| 交互式终端 | 支持 | 需要 `full_access` 和 terminal endpoint |
| 文件浏览 | SFTP | 需要 `[remote_access.fs]` 和 `roots` |
| Byte stream（SFTP、端口转发） | 支持 | 不支持 |
| App 连接前的历史数据 | 不提供 | 提供 |

同时配置两种方式时，服务器会提供两边能力的 union。例如，优先使用 Monitor HTTP 时，SSH 提供的 SFTP 和端口转发仍然可用。

文件传输协议与 transport 优先顺序分开配置。SSH 文件操作默认使用 SFTP；主机没有 SFTP subsystem 时可以选 SCP。仅配置 Monitor HTTP 的服务器使用 agent 文件 API，无法提供 SFTP 或端口转发。

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

App 的 SSH 路径通过 `crates/sbm_ffi` 调用共享 Rust parser。Monitor agent 在运行主机上用 `crates/sbm_native` 采集 CPU、内存、磁盘和网络等核心指标，并在较慢的扩展周期运行共享脚本，补充仍需 CLI 工具才能读取的值。两条路径共用部分状态模型，但采样和解析行为不同。

parser 由纯函数组成，返回原始计数。差分与时间窗口计算也使用纯函数；可变状态不会跨越 FFI 边界。

## 存储迁移

App 的存储布局由 `SchemaVersion` 管理。Drift 的 `schemaVersion` 保持为 `1`，因为 App migration 除了更新 Drift table，还要导入旧 Hive box、生成 ID 并重写引用。

升级时，`HiveImport` 先将旧安装中的 Hive 数据导入 `kv`，再由已注册的 schema migration 把关系型数据迁入 entity table。`lib/hive/legacy_adapters.dart` 中的 adapter 用于读取已发布版本的数据格式，必须保持冻结，不能用当前 model 重新生成。

每项存储迁移都要保留 regression test，并使用待迁移 release 实际写出的 bytes。用当前 adapter 生成的 fixture 只能验证当前代码自身，不能证明旧版本数据仍可读取。

## 安全

- **凭据和已信任的 host fingerprint**保存在加密 SQLite 数据库中。设置存储使用 `sshKnownHostFingerprints` 保存 fingerprint；数据库密钥保存在平台安全存储（Keychain 或 Keystore）中。
- **Session** 不会持久化。
- **App 会验证每次连接的 host key**，包括经 jump server 或 `ProxyCommand` 建立的连接。
