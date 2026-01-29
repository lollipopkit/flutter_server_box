---
title: 构建指南
description: 不同平台的构建说明
---

Flutter Server Box 使用自定义构建系统 (`fl_build`) 进行跨平台构建。

## 前置条件

- Flutter SDK (stable channel)
- 平台特定工具 (iOS 需要 Xcode，Android 需要 Android Studio)
- Rust 工具链 (部分原生依赖项需要)

## 开发版构建

```bash
# 以开发模式运行
flutter run

# 在指定设备上运行
flutter run -d <device-id>
```

## 生产版构建

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
- CocoaPods
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

需要安装了 Visual Studio 的 Windows 环境。

## 构建前/后处理

`make.dart` 脚本负责处理：

- 元数据生成
- 版本字符串更新
- 平台特定的配置

## 故障排除

### 全新构建 (Clean Build)

```bash
flutter clean
dart run build_runner build --delete-conflicting-outputs
flutter pub get
```

### 版本不匹配

确保所有依赖项兼容：
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
