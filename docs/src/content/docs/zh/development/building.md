---
title: 构建指南
description: 在不同平台构建 Server Box 和 Monitor agent
---

Flutter App 使用仓库提供的 `fl_build` 工具构建。Monitor agent 是独立的 Rust 服务，需要单独构建。

## 前置条件

- stable channel 的 Flutter SDK
- 平台 SDK：iOS 需要 Xcode，Android 需要 Android Studio 和 Android SDK，Windows 需要 Visual Studio
- Rust toolchain：App 通过 Dart build hook、`flutter_rust_bridge_hooks` 和 native assets 构建 `crates/sbm_ffi`

获取 Dart packages 前先初始化 Git submodule：

```bash
git submodule update --init --recursive
```

## 运行开发版

```bash
# 在默认设备上运行
flutter run

# 明确指定设备
flutter run -d <device-id>
```

## 发布版构建

将目标平台传给 `fl_build`：

```bash
dart run fl_build -p <platform>
```

支持的平台名称为 `ios`、`android`、`macos`、`linux` 和 `windows`。

## 平台要求

### iOS

```bash
dart run fl_build -p ios
```

需要 macOS 构建机和 Xcode。进行签名时还需要 Apple Developer 账号。

### Android

```bash
dart run fl_build -p android
```

需要 Android SDK、JDK 和用于 release signing 的 keystore。Release build 必须使用 `key.properties` 中配置的 keystore。仅本地验证时，才显式传入 `-PallowDebugReleaseSigning=true` 使用 debug signing。可重现构建和 F-Droid 构建使用 `-PallowUnsignedRelease=true`，不配置任何签名；`scripts/release/android-build-env.sh` 会导出此选项。

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

需要安装 Visual Studio，并选择 **Desktop development with C++** workload 和 ATL 支持。

## 构建 Monitor agent

Monitor agent 是独立的 server binary，构建步骤与 Flutter App 分开：

```bash
# 在仓库根目录执行
cargo build --release

# 构建网页面板
cd monitor/frontend
npm install
npm run build
```

网页面板构建后，Monitor agent 会在 `frontend/dist` 存在时提供该面板。开发时可在仓库根目录运行 `make monitor-dev`，同时启动 API（`:3770`）和 Vite dev server（`:3000`）。

release 产物由 `monitor-release.yml` workflow 构建，目前只能通过 `workflow_dispatch` 运行。Monitor 的 `monitor-v*` tag 与 App release 分开管理。Docker 构建方法见 `monitor/Dockerfile`。

## 构建前后处理

每次构建时，`fl_build` 都会重新生成 `lib/data/res/build_data.dart`，根据 Git 历史计算 build number，并将版本写入 Xcode 配置。App 名称在 `pubspec.yaml` 的 `fl_build:` 段中设置。

## 故障排除

### Clean build

```bash
flutter clean
flutter pub get
dart run build_runner build
```

`flutter clean` 会删除 `build/` 下的构建产物，也包括启用 iOS Linux engine 时所需的 engine libraries。请重新运行对应的 `scripts/build-ish-ios.sh device`、`simulator` 或 `macos` 构建目标，否则链接时会因缺少这些文件而失败。

### 依赖版本不匹配

升级依赖前先确认版本兼容：

```bash
flutter pub upgrade
```

修改带有注解的 model 后，还需要运行代码生成；详见[代码生成](/docs/zh/development/codegen/)。

## 发布清单

1. 更新 `pubspec.yaml` 中的版本号。
2. 运行代码生成和本地化生成。
3. 运行 Dart、Flutter 和 Rust 测试。
4. 为所有目标平台构建。
5. 在真实设备上验证关键功能。
6. 创建 GitHub Release。
