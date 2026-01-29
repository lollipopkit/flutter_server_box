---
title: 项目结构
description: 了解 Server Box 的代码库结构
---

Server Box 项目遵循模块化架构，具有清晰的关注点分离。

## 目录结构

```
lib/
├── core/              # 核心工具类和扩展
├── data/              # 数据层
│   ├── model/         # 按功能划分的数据模型
│   ├── provider/      # Riverpod provider
│   └── store/         # 本地存储 (Hive)
├── view/              # UI 层
│   ├── page/          # 主要页面
│   └── widget/        # 可复用组件
├── generated/         # 生成的本地化代码
├── l10n/              # 本地化 ARB 文件
└── hive/              # Hive 适配器
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

基于 Hive 的本地存储：

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

包含依赖项的自定义分支：

- `dartssh2/` - SSH 库
- `xterm/` - 终端模拟器
- `fl_lib/` - 共享工具类
- `fl_build/` - 构建系统
