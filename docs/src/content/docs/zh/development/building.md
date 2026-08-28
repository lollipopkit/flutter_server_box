---
title: 构建指南
description: 在不同平台构建 Server Box 和 Monitor agent
---

Server Box 使用自定义构建工具 `fl_build` 生成各平台 App。Monitor agent 是独立的 Rust 服务，有单独的构建流程。

## 前置条件

- Flutter SDK（stable channel）
- 对应平台的开发工具：iOS 需要 Xcode，Android 需要 Android Studio 和 Android SDK，Windows 需要 Visual Studio
- Rust toolchain：App 会通过 Dart build hook、`flutter_rust_bridge_hooks` 和 native assets 构建 `crates/sbm_ffi` Rust crate

获取 Dart 依赖前，先初始化仓库中的 Git submodule：

```bash
git submodule update --init --recursive
```

## 开发版构建

```bash
# 直接运行 App
flutter run

# 在指定设备上运行
flutter run -d <device-id>
```

## 发布版构建

使用 `fl_build` 为指定平台构建：

```bash
dart run fl_build -p <platform>
```

可用平台：`ios`、`android`、`macos`、`linux`、`windows`。

## 平台要求

### iOS

```bash
dart run fl_build -p ios
```

需要运行 macOS 的构建机、已安装 Xcode，以及用于签名的 Apple Developer 账号。

### Android

```bash
dart run fl_build -p android
```

需要 Android SDK、JDK 和用于发布签名的 keystore。正式 release 构建必须使用 `key.properties` 配置的 release keystore；仅用于本地验证时，才可以显式传入 `-PallowDebugReleaseSigning=true` 使用 debug signing。可重现构建和 F-Droid 构建则传入 `-PallowUnsignedRelease=true`，完全不指定签名配置；`scripts/release/android-build-env.sh` 会导出它。

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

需要安装 Visual Studio 的 Windows 构建环境。

## 构建 Monitor agent

Monitor agent 是独立的服务端二进制，不属于 App 构建流程。

```bash
# 在仓库根目录执行
cargo build --release

# 构建网页面板
cd monitor/frontend
npm install
npm run build
```

构建完成后，agent 会在存在 `frontend/dist` 时提供网页面板。在仓库根目录运行 `make monitor-dev`，可以同时启动开发环境：API 使用 `:3770`，面板的 Vite dev server 使用 `:3000`。

release 产物由 `monitor-release.yml` workflow 构建。该 workflow 只支持 `workflow_dispatch`；Monitor 的 `monitor-v*` tag 与 App release 相互独立。Docker 构建方式见 `monitor/Dockerfile`。

## 构建前后处理

`fl_build` 每次构建都会重新生成 `lib/data/res/build_data.dart`，根据 Git 历史推导构建号，并将版本写入 Xcode 配置。`pubspec.yaml` 中的 `fl_build:` 段用于配置 App 名称。

## 故障排除

### Clean build

```bash
flutter clean
dart run build_runner build --delete-conflicting-outputs
flutter pub get
```

`flutter clean` 会删除 `build/` 下的构建产物，包括启用 iOS Linux engine 时需要的 engine libraries。此时需要重新运行相应的 `scripts/build-ish-ios.sh device`、`simulator` 或 `macos`，否则链接阶段会找不到文件。

### 依赖版本不匹配

确认依赖兼容后再升级：

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
