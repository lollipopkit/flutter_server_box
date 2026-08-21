---
title: 项目结构
description: 了解 Server Box 的代码库结构
---

Server Box 项目是一个单一仓库（monorepo）：Flutter 应用位于仓库根目录，并与 Rust workspace、服务端监控共存。

## Monorepo 布局

```
flutter_server_box/
├── lib/               # Flutter 应用（见下文）
├── crates/
│   ├── sbm_parser/    # 共享状态解析库（单一事实来源，
│   │                  # App 经 FFI 使用，monitor 直接依赖）
│   ├── sbm_ffi/       # flutter_rust_bridge 绑定 crate
│   │                  # 原生构建集成
│   └── sbm_native/    # 各平台原生采样（仅 monitor 使用）
├── monitor/           # 服务端监控（Rust 服务 + Svelte 前端）
├── packages/          # Vendor 的 Dart fork（path 依赖），以及
│                      # webui：monitor 与 website 共用的 Svelte UI
├── docs/              # 本文档站（Astro Starlight）
├── website/           # 项目网站
└── Cargo.toml         # Rust workspace 根
```

## 应用目录结构

```
lib/
├── core/              # 核心工具类和扩展
├── data/              # 数据层
│   ├── model/         # 按功能划分的数据模型
│   ├── provider/      # Riverpod provider
│   ├── store/         # 本地存储 (SQLite)
│   ├── helper/        # 数据层辅助工具
│   ├── res/           # 资源与常量
│   └── ssh/           # SSH 会话管理
├── view/              # UI 层
│   ├── page/          # 主要页面
│   └── widget/        # 可复用组件
├── generated/         # 生成的本地化代码
├── l10n/              # 本地化 ARB 文件
├── hive/              # 用于迁移的旧版 Hive 适配器
└── src/rust/          # 生成的 flutter_rust_bridge 绑定（勿手改）
```

## 核心层 (`lib/core/`)

包含工具类、扩展和路由配置：

- **Extensions**：针对通用类型的 Dart 扩展
- **Routes**：应用路由配置
- **Utils**：共享的工具函数

## 数据层 (`lib/data/`)

### 模型 (`lib/data/model/`)

按功能模块组织：

- `server/` - 服务器连接及状态模型
- `container/` - Docker 容器模型
- `ssh/` - SSH 会话模型
- `sftp/` - SFTP 文件模型
- `app/` - 应用特定的模型

### Provider (`lib/data/provider/`)

用于依赖注入和状态管理的 Riverpod provider：

- 服务器 Provider
- UI 状态 Provider
- 服务 Provider

### 存储 (`lib/data/store/`)

基于 SQLite 的本地存储：

- 服务器存储
- 设置存储
- 缓存存储

## 视图层 (`lib/view/`)

### 页面 (`lib/view/page/`)

应用程序的主要屏幕：

- `server/` - 服务器管理页面
- `ssh/` - SSH 终端页面
- `container/` - 容器管理页面
- `setting/` - 设置页面
- `storage/` - SFTP 页面
- `snippet/` - 脚本页面

### 组件 (`lib/view/widget/`)

可复用的 UI 组件：

- 服务器卡片
- 状态图表
- 输入组件
- 对话框

## 生成的文件

- `lib/generated/l10n/` - 自动生成的本地化代码
- `*.g.dart` - 生成的代码 (json_serializable, freezed, hive, riverpod)
- `*.freezed.dart` - Freezed 不可变类

## Packages 目录 (`/packages/`)

包含依赖项的自定义 fork，在 `pubspec.yaml` 中以 path 引用：

- `dartssh2/` - SSH 库
- `xterm/` - 终端模拟器
- `fl_lib/` - 共享工具类
- `fl_build/` - 构建系统
- `circle_chart/` - 图表组件
- `plain_notification_token/` - 推送 token 插件
- `watch_connectivity/` - Apple Watch 通信

其中有一个目录不是 Dart fork：`webui/`（`@serverbox/webui`）是一个 Svelte 包，
提供共享的 UI 基础组件和设计令牌（design token），`monitor/frontend` 和 `website/` 都以
`file:` 依赖引用它。

## Rust 侧

- `crates/sbm_parser/` - 将命令原始输出解析为结构化服务器状态。
  App（经 FFI）与 monitor 共用，两端解析行为始终一致。
- `crates/sbm_native/` - 各平台的原生采样，仅 monitor 使用。它通过 syscall 或
  procfs 直接读取 cpu/内存/swap/磁盘/网络/uptime，不执行 shell 命令。App 不依赖
  它：App 通过 SSH 采集，无法在远程主机上执行 syscall。
- `crates/sbm_ffi/` - `sbm_parser` 的 flutter_rust_bridge 绑定，生成的 Dart 侧位于
  `lib/src/rust/`。
- `monitor/` - 独立的监控服务，文档见 `monitor/README_zh.md`。
