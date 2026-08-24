---
title: 构建指南
description: 不同平台的构建说明
---

Server Box 使用自定义构建系统 (`fl_build`) 进行跨平台构建。

## 前置条件

- Flutter SDK (stable channel)
- 平台相关工具（iOS 需要 Xcode，Android 需要 Android Studio）
- Rust 工具链（必需：`crates/sbm_ffi` Rust crate 由 Dart build hook 通过
  `flutter_rust_bridge_hooks` 和 native assets 构建进 App）

获取 Dart 依赖前，请先初始化项目内置的 Git 子模块：

```bash
git submodule update --init --recursive
```

## 开发版构建

```bash
# 以开发模式运行
flutter run

# 在指定设备上运行
flutter run -d <device-id>
```

## 发布版构建

项目使用 `fl_build` 进行构建：

```bash
# 为指定平台构建
dart run fl_build -p <platform>

# 可用平台：
# - ios
# - android
# - macos
# - linux
# - windows
```

## 平台特定构建

### iOS

```bash
dart run fl_build -p ios
```

需要：
- 安装了 Xcode 的 macOS
- 用于签名的 Apple Developer 账号

### Android

```bash
dart run fl_build -p android
```

需要：
- Android SDK
- Java Development Kit (JDK)
- 用于签名的 Keystore

### macOS

```bash
dart run fl_build -p macos
```

### Linux

```bash
dart run fl_build -p linux
```

### Windows

```bash
dart run fl_build -p windows
```

需要安装 Visual Studio 的 Windows 环境。

## 构建 monitor

服务端 monitor 是一个独立的二进制，从 `monitor/` 构建，不属于任何 App 构建流程。

```bash
cd monitor

# 后端
cargo build --release

# 面板：存在 frontend/dist 时由 agent 自己提供
cd frontend && npm install && npm run build
```

在仓库根目录执行 `make monitor-dev` 会以开发模式同时启动两者：API 在 `:3770`，
面板的 vite dev server 在 `:3000`。

release 产物来自 `monitor-release.yml` workflow，该 workflow 仅支持
`workflow_dispatch`，发布的 `monitor-v*` tag 与 App 自身的 release 相互独立。
Docker 见 `monitor/Dockerfile`。

## 构建前/后处理

`fl_build` 在每次构建时重新生成 `lib/data/res/build_data.dart`，构建号由 Git
历史推导，并把对应版本写进 Xcode 配置。`fl_build.json` 负责告诉它应用叫什么。

## 故障排除

### 干净构建（Clean Build）

```bash
flutter clean
dart run build_runner build --delete-conflicting-outputs
flutter pub get
```

### 版本不匹配

确认所有依赖项相互兼容：
```bash
flutter pub upgrade
```

## 发布清单

1. 更新 `pubspec.yaml` 中的版本号
2. 运行代码生成
3. 运行测试
4. 为所有目标平台构建
5. 在真机上测试
6. 创建 GitHub Release
