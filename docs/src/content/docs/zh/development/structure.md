---
title: 项目结构
description: 了解 Server Box 的代码库组织结构
---

本仓库采用 Monorepo 结构，根目录为 Flutter 客户端，并与 Rust 工作区、Monitor 服务端、文档站及项目官网共同维护。

## Monorepo 目录结构

```text
flutter_server_box/
├── lib/               # Flutter 客户端源码
├── crates/
│   ├── sbm_parser/    # 客户端与 Monitor 共用的状态解析库
│   ├── sbm_ffi/       # flutter_rust_bridge 绑定 crate
│   └── sbm_native/    # Monitor 使用的原生系统指标采样器
├── monitor/           # Monitor（Rust 服务端 + Svelte 前端面板）
├── packages/          # 本地路径依赖的 Dart 分支包与共享 webui 组件库
├── docs/              # Astro Starlight 文档站
├── website/           # 项目官网
└── Cargo.toml         # Rust 工作区根配置
```

## Flutter 客户端目录

```text
lib/
├── core/              # 核心工具、扩展方法与路由
├── data/              # 数据模型、状态管理、存储与 SSH 会话
│   ├── model/
│   ├── provider/
│   ├── store/         # SQLite 本地存储
│   ├── helper/
│   ├── res/
│   ├── service/       # systemd/procd/OpenRC 及 cron/用户管理服务
│   └── ssh/
├── view/              # 页面与可复用 UI 组件
├── generated/         # 自动生成的本地化代码
├── l10n/              # ARB 多语言源文件
├── hive/              # 旧版 Hive 数据迁移读取器
└── src/rust/          # 自动生成的 flutter_rust_bridge 绑定代码
```

`lib/src/rust/`、`lib/generated/`、`*.g.dart` 和 `*.freezed.dart` 均为代码生成产物。如需修改，请编辑对应的源文件并重新运行生成工具，切勿手动修改生成文件。

## 核心代码说明

### `lib/core/`

存放跨模块复用的扩展方法、路由配置与通用工具函数。特定页面的业务状态应放在对应的 Provider 或 Service 中。

### `lib/data/model/`

数据模型按业务领域划分：

- `server/`：服务器配置、认证凭据与运行状态
- `container/`：Docker 与 Podman 容器模型
- `file/`：远程文件模型
- `ssh/`：SSH 会话模型
- `ai/`：AI 对话与工具命令模型
- `app/`：应用级配置与运行状态

### `lib/data/provider/`

使用 Riverpod 管理依赖注入、异步任务及跨页面共享状态。Provider 通常负责调用下层 Service 或 Store，避免在 UI 组件中直接访问存储层。

### `lib/data/store/`

本地持久化层基于加密 SQLite 数据库构建：

- `SqliteStore`：负责设置项与历史记录等键值（Key-Value）存储。
- 实体存储（Entity Stores）：负责服务器、私钥、代码片段等结构化关系数据。
- 数据迁移（Migrations）：负责跨版本升级时的本地数据格式迁移。

### `lib/view/`

`page/` 存放各主页面视图；`widget/` 存放可复用组件（如服务器卡片、状态图表、输入框与弹窗）。

## 内部包（`packages/`）

`packages/` 下的大多数学科目录是通过本地路径依赖引入的定制分支包：

- `dartssh2/`：SSH 客户端实现
- `xterm/`：终端模拟器组件
- `fl_lib/`：共享 UI 组件与通用基础库
- `fl_build/`：跨平台构建工具
- 其他平台插件与功能组件包

`packages/webui/` 供项目官网使用，是基于 Svelte 编写的 UI 基础组件与设计变量（Design Tokens）包。

## Rust 工作区

- `crates/sbm_parser/`：将命令行输出解析为结构化的服务器状态数据。Flutter 客户端通过 FFI 调用该库，Monitor 也在脚本采集模式中复用该库。
- `crates/sbm_native/`：通过系统调用、`procfs` 或 `sysfs` 在 Monitor 所在宿主机上直接采样硬件与系统指标。Flutter 客户端通过 SSH 采集远程数据，不在远程主机上调用此 crate。
- `crates/sbm_ffi/`：向 Flutter 暴露 Rust 接口（包括解析器与原生 SSH 加密原语），生成的 Dart 绑定代码位于 `lib/src/rust/`。
- `monitor/`：独立运行的 Monitor 监控服务，详见 `monitor/README_zh.md`。

Flutter 客户端通过 SSH 远程采集服务器指标，而 Monitor 则在所部署的宿主机本机采样。两者共享核心数据模型与解析逻辑，但采用各自独立的采集链路。
