---
title: 项目结构
description: 了解 Server Box 的代码库结构
---

仓库采用 monorepo 布局。Flutter App 位于根目录，并与 Rust workspace、Monitor agent、文档站和项目网站一起维护。

## Monorepo 布局

```text
flutter_server_box/
├── lib/               # Flutter App
├── crates/
│   ├── sbm_parser/    # App 和 Monitor 共用的状态解析库
│   ├── sbm_ffi/       # flutter_rust_bridge binding crate
│   └── sbm_native/    # Monitor 使用的原生采样器
├── monitor/           # Monitor agent（Rust 服务 + Svelte 面板）
├── packages/          # path 依赖的 Dart fork 和共享 webui 包
├── docs/              # Astro Starlight 文档站
├── website/           # 项目网站
└── Cargo.toml         # Rust workspace 根文件
```

## Flutter App 目录

```text
lib/
├── core/              # 核心工具、extension 和路由
├── data/              # model、provider、store、SSH 会话
│   ├── model/
│   ├── provider/
│   ├── store/         # SQLite 存储
│   ├── helper/
│   ├── res/
│   ├── service/       # systemd/procd/OpenRC 及 cron/用户管理
│   └── ssh/
├── view/              # 页面和可复用 Widget
├── generated/         # 生成的本地化代码
├── l10n/              # ARB 本地化源文件
├── hive/              # 仅用于迁移的旧版 Hive adapter
└── src/rust/          # 生成的 flutter_rust_bridge bindings
```

`lib/src/rust/`、`lib/generated/`、`*.g.dart` 和 `*.freezed.dart` 都是生成结果。请修改对应源文件后重新生成，不要直接编辑这些产物。

## 核心代码目录

### `lib/core/`

存放跨功能共用的 extension、路由和 utility。页面专属的业务状态应放在对应的 provider 或 service 中。

### `lib/data/model/`

model 按功能分类：

- `server/`：服务器配置、凭据和状态
- `container/`：Docker/Podman 容器
- `file/`：远程文件模型
- `ssh/`：SSH 会话相关模型
- `ai/`：AI 会话与命令模型
- `app/`：App 本身的配置和状态

### `lib/data/provider/`

Riverpod provider 协调依赖、异步操作以及跨页面共享的状态。通常由 provider 调用 service 或 store；不要在 UI Widget 中实现数据访问。

### `lib/data/store/`

本地数据层使用加密 SQLite 数据库，各部分职责如下：

- `SqliteStore`：处理设置和历史等 key-value 数据。
- entity store：处理服务器、private key、snippet 等关系型数据。
- migrations：将存储数据升级到新版本。

### `lib/view/`

`page/` 存放主要页面；`widget/` 存放可复用组件，例如服务器卡片、状态图表、输入框和 dialog。

## Packages

`packages/` 中的大多数目录是通过本地 path dependency 引入的 fork：

- `dartssh2/`：SSH 客户端
- `xterm/`：终端模拟器
- `fl_lib/`：共享 UI 组件和 utility
- `fl_build/`：跨平台构建工具
- 其他平台插件和组件包

`packages/webui/` 由 Monitor 面板和项目网站共用，是提供 UI 基础组件与 design token 的 Svelte 包。

## Rust workspace

- `crates/sbm_parser/`：将命令输出解析为结构化服务器状态。Flutter App 通过 FFI 调用；Monitor 在脚本采集路径中使用它。
- `crates/sbm_native/`：在 Monitor agent 所在主机上采集指标，使用 syscall、procfs 或 sysfs。Flutter App 通过 SSH 获取远程数据，不会在远程主机上调用此 crate。
- `crates/sbm_ffi/`：向 Flutter 暴露 Rust API，包括 parser 和 native SSH cryptography。生成的 Dart bindings 位于 `lib/src/rust/`。
- `monitor/`：独立的 Monitor agent。详细说明见 `monitor/README_zh.md`。

App 通过 SSH 采集远程服务器数据，Monitor agent 在自身所在主机采样。两者共用部分 model 和 parser，但采集流程各自独立。
