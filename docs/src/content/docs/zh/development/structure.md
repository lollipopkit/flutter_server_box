---
title: 项目结构
description: 了解 Server Box 的代码库结构
---

Server Box 使用 monorepo 组织代码：Flutter App 位于仓库根目录，与 Rust workspace、Monitor agent、文档站和项目网站共同维护。

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
│   └── ssh/
├── view/              # 页面和可复用 Widget
├── generated/         # 生成的本地化代码
├── l10n/              # ARB 本地化源文件
├── hive/              # 仅用于迁移的旧版 Hive adapter
└── src/rust/          # 生成的 flutter_rust_bridge bindings
```

`lib/src/rust/`、`lib/generated/` 以及 `*.g.dart`、`*.freezed.dart` 都是生成结果，不要直接编辑。

## 核心代码目录

### `lib/core/`

放置跨功能共用的 extension、路由和 utility。这里不应放置某个页面专属的业务状态。

### `lib/data/model/`

按功能组织数据模型，例如：

- `server/`：服务器配置、凭据和状态
- `container/`：Docker/Podman 容器
- `ssh/`：SSH 会话相关模型
- `sftp/`：远程文件模型
- `app/`：App 本身的配置和状态

### `lib/data/provider/`

Riverpod provider 负责依赖注入、异步状态和跨页面共享状态。Provider 通常调用 service 或 store，而不是把数据访问逻辑放进 UI Widget。

### `lib/data/store/`

本地数据层使用加密 SQLite 数据库：

- `SqliteStore`：适合设置和历史等 key-value 数据
- entity store：适合服务器、private key、snippet 等具有关系的数据
- migrations：处理跨版本存储迁移

### `lib/view/`

`page/` 放置主要页面，`widget/` 放置可复用 UI 组件，例如服务器卡片、状态图表、输入框和 dialog。

## Packages

`packages/` 中的大多数目录是通过 path dependency 引入的 fork：

- `dartssh2/`：SSH 客户端
- `xterm/`：终端模拟器
- `fl_lib/`：共享 UI 组件和 utility
- `fl_build/`：跨平台构建工具
- 其他平台插件和组件包

`packages/webui/` 是例外。它是供 Monitor 面板和项目网站共用的 Svelte 包，提供 UI 基础组件和 design token。

## Rust workspace

- `crates/sbm_parser/`：将命令输出解析为结构化服务器状态。Flutter App 的 SSH 路径通过 FFI 调用；Monitor 的脚本路径也使用它。
- `crates/sbm_native/`：仅 Monitor 使用的原生采样器，通过 syscall、procfs 或 sysfs 获取核心指标。Flutter App 通过 SSH 采集，不能在远程主机上调用该 crate。
- `crates/sbm_ffi/`：向 Flutter 暴露 Rust API，包括 parser 和 native SSH crypto；Dart bindings 生成到 `lib/src/rust/`。
- `monitor/`：独立的 Monitor agent，详细说明见 `monitor/README_zh.md`。

App 通过 SSH 获取远程主机数据，Monitor agent 则在服务器本机采样。两条路径共享部分数据模型和 parser，但不经过完全相同的采样流程。
